
extern crate modellib;

use modellib::BaseModel;
use std::{thread,time};
use std::sync::{Arc, Barrier, mpsc, mpsc::Receiver, mpsc::Sender, Mutex};

#[derive(Copy,Clone,PartialEq)]
pub enum SchedulerState {
    CONFIG       = 0,
    INITIALIZING = 1,
    INITIALIZED  = 2,
    RUNNING      = 3,
    PAUSED       = 4,
    ENDED        = 5,
    ERRORED      = 6,
}

#[derive(Copy,Clone,PartialEq)]
pub enum ThreadMsg {
    // command
    INIT,
    EXECUTE(u64),
    SHUTDOWN,
    // result
    RUNNING,
    OK,
    ERR,
    END
}

pub trait Scheduler {
    fn clear_threads(&mut self) -> ();
    fn add_thread(&mut self, freq : f64) -> ();
    fn add_model(&mut self, model: Box<Box<dyn BaseModel + Send>>, thread: usize, divisor: i64, offset: i64) -> i32;
    fn get_num_threads(&self) -> i32;

    fn init(&mut self) -> i32;
    fn step(&mut self, steps: i64) -> i32;
    fn end(&mut self) -> i32;

    fn get_state(&self) -> SchedulerState;
}

pub struct ScheduledObject {
    pub model : Box<dyn BaseModel + Send>,
    pub divisor : i64,
    pub offset : i64,
}

pub struct ThreadState {
    pub frequency : f64,
    pub models : Vec<ScheduledObject>,
}

pub struct NRTScheduler {
    pub threads : Vec<ThreadState>,
    pub handles : Vec<thread::JoinHandle<()>>,
    pub state   : Arc<Mutex<SchedulerState>>,

    pub runner : Option<thread::JoinHandle<()>>,
    pub runner_tx : Option<Sender<ThreadMsg>>,
    pub runner_rx : Option<Receiver<ThreadMsg>>,
}

impl NRTScheduler {
    fn start_runner(&mut self) -> (Sender<ThreadMsg>, Receiver<ThreadMsg>) {
        let (mtor_tx, mtor_rx) = mpsc::channel();
        let (rtom_tx, rtom_rx) = mpsc::channel();
        let threadlen = self.threads.len();
        
        // create threads now. Add 1 for main thread
        let mut thread_state = Vec::<SchedulerState>::new();
        let mut tx_handles = Vec::<Sender<ThreadMsg>>::new();
        let mut rx_handles = Vec::<Receiver<i32>>::new();
        let barrier = Arc::new(Barrier::new(threadlen));
        for ts in &mut self.threads[..] {
            let c = Arc::clone(&barrier);
            let mut u: Vec<_> = ts.models.drain(..).collect();
            let (txx, rxx) = mpsc::channel(); // trigger channel
            let (tx, rx) = mpsc::channel(); // response channel
            self.handles.push(thread::spawn(move|| {
                loop {
                    match rxx.recv() {
                        Ok(ThreadMsg::INIT) => {
                            let mut status = 0;
                            for obj in &mut u[..] {
                                if !(*obj).model.init() {
                                    status = 1;
                                }
                            }
                            tx.send(status).unwrap();
                        },
                        Ok(ThreadMsg::EXECUTE(value)) => {
                            for _ in 0..value {
                                for obj in &mut u[..] {
                                    (*obj).model.step();
                                }
                                c.wait();
                            }
                        },
                        _ => ()
                    }
                }
                println!("thread spawn end");
            }));
            tx_handles.push(txx);
            rx_handles.push(rx);
            thread_state.push(SchedulerState::CONFIG);
        }
        
        let mutex_state = Arc::clone(&self.state);
        let mut state = SchedulerState::CONFIG;
        self.runner = Some(thread::spawn(move|| {
            loop {
                let stat = mtor_rx.try_recv();
                match state {
                    SchedulerState::CONFIG => {
                        if stat == Ok(ThreadMsg::INIT) {
                            for tx in tx_handles.iter_mut() {
                                tx.send(ThreadMsg::INIT).unwrap();
                            }
                            state = SchedulerState::INITIALIZING;
                            let mut s = mutex_state.lock().unwrap();
                            *s = state;
                        }
                    },
                    SchedulerState::INITIALIZING => {
                        // poll state
                        let mut alldone = true;
                        for (pos, rx) in rx_handles.iter_mut().enumerate() {
                            match rx.try_recv() {
                                Ok(_) => {
                                    thread_state[pos] = SchedulerState::INITIALIZED;
                                },
                                _ => (),
                            }
                            if thread_state[pos] != SchedulerState::INITIALIZED {
                                alldone = false;
                            }
                            if alldone {
                                state = SchedulerState::INITIALIZED;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            }
                        }
                    },
                    SchedulerState::INITIALIZED => {
                        match stat {
                            Ok(ThreadMsg::EXECUTE(steps)) => {
                                for tx in tx_handles.iter_mut() {
                                    tx.send(ThreadMsg::EXECUTE(steps)).unwrap();
                                }
                            },
                            _ => ()
                        }
                    },
                    _ => ()
                }
                thread::sleep(time::Duration::from_millis(10)); // sleep to prevent hogging the cpu
            }
        }));
        return (mtor_tx, rtom_rx);
    }
}

impl Scheduler for NRTScheduler {
    fn clear_threads(&mut self) -> () {
        self.threads.clear();
    }
    fn add_thread(&mut self, freq : f64) -> (){
        self.threads.push(ThreadState {
            frequency: freq,
            models: Vec::new(),
        })
    }
    fn add_model(&mut self, model : Box<Box<dyn BaseModel + Send>>, thread: usize, divisor: i64, offset: i64) -> i32 {
        if thread > self.threads.len() {
            return 1
        }
        let obj = ScheduledObject {
            model: *model,
            divisor: divisor,
            offset: offset,
        };
        self.threads[thread].models.push(obj);
        0
    }
    fn get_num_threads(&self) -> i32 {
        self.threads.len() as i32
    }
    fn init(&mut self) -> i32 {
        let (tx, rx) = self.start_runner();
        tx.send(ThreadMsg::INIT).unwrap(); // todo deal with unwrap
        self.runner_tx = Some(tx);
        self.runner_rx = Some(rx);
        //
        0
    }
    fn step(&mut self, steps: i64) -> i32 {
        0
    }
    fn end(&mut self) -> i32 {
        0
    }
    fn get_state(&self) -> SchedulerState {
        let s = self.state.lock().unwrap();
        *s
    }
}

impl NRTScheduler {
    pub fn new() -> NRTScheduler {
        NRTScheduler {
            threads: Vec::<ThreadState>::new(),
            handles: Vec::new(),
            state  : Arc::new(Mutex::new(SchedulerState::CONFIG)),
            runner : None,
            runner_tx : None,
            runner_rx : None,
        }
    }
}
