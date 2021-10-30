
extern crate modellib;

pub use std::ffi::c_void;
use modellib::BaseModel;
use std::{thread,time};
use std::sync::{Arc, Barrier, mpsc, mpsc::TryRecvError, mpsc::Receiver, mpsc::Sender, Mutex};

use crate::epoch::EpochTime;

#[derive(Copy,Clone,PartialEq)]
pub enum SchedulerState {
    CONFIG       = 0,
    INITIALIZING = 1,
    INITIALIZED  = 2,
    RUNNING      = 3,
    PAUSED       = 4,
    ENDING       = 5,
    ENDED        = 6,
    ERRORED      = 7,
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
    fn add_model(&mut self, model: Box<Box<dyn BaseModel + Send>>, thread: usize, divisor: i64, offset: i64) -> *mut c_void;
    fn get_num_threads(&self) -> i32;

    fn init(&mut self) -> i32;
    fn step(&mut self, steps: u64) -> i32;
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
        let mut rx_handles = Vec::<Receiver<ThreadMsg>>::new();
        let barrier = Arc::new(Barrier::new(threadlen));
        for ts in &mut self.threads[..] {
            let c = Arc::clone(&barrier);
            let mut u: Vec<_> = ts.models.drain(..).collect();
            let (txx, rxx) = mpsc::channel(); // trigger channel
            let (tx, rx) = mpsc::channel(); // response channel
            self.handles.push(thread::spawn(move|| {
                loop {
                    let mut time = EpochTime::new();
                    match rxx.recv() {
                        Ok(ThreadMsg::INIT) => {
                            let mut status = ThreadMsg::OK;
                            for obj in &mut u[..] {
                                if !(*obj).model.init() {
                                    status = ThreadMsg::ERR;
                                }
                            }
                            tx.send(status).unwrap();
                        },
                        Ok(ThreadMsg::EXECUTE(value)) => {
                            for _ in 0..value {
                                for obj in &mut u[..] {
                                    (*obj).model.step();
                                }
                                time.increment(1);
                                c.wait();
                            }
                            tx.send(ThreadMsg::OK).unwrap();
                        },
                        Ok(ThreadMsg::SHUTDOWN) => {
                            tx.send(ThreadMsg::END).unwrap();
                            break;
                        },
                        _ => ()
                    }
                }
            }));
            tx_handles.push(txx);
            rx_handles.push(rx);
            thread_state.push(SchedulerState::CONFIG);
        }
        
        let mutex_state = Arc::clone(&self.state);
        let mut state = SchedulerState::CONFIG;
        self.runner = Some(thread::spawn(move|| {
            let mut thread_state_received = vec![false; threadlen];
            let mut thread_rcv_num = 0;
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
                                Ok(ThreadMsg::OK) => {
                                    thread_state[pos] = SchedulerState::INITIALIZED;
                                },
                                Ok(ThreadMsg::ERR) => {
                                    thread_state[pos] = SchedulerState::ERRORED;
                                    println!("Thread {} reported an error in initialization.", pos);
                                },
                                _ => (),
                            }
                            if thread_state[pos] != SchedulerState::INITIALIZED {
                                alldone = false;
                            }
                        }
                        if alldone {
                            state = SchedulerState::INITIALIZED;
                            println!("Scenario Initialized");
                        } else {
                            state = SchedulerState::ERRORED;
                            println!("Scenario Initialization Failed");
                        }
                        {
                            let mut s = mutex_state.lock().unwrap();
                            *s = state;
                        }
                    },
                    SchedulerState::INITIALIZED => {
                        match stat {
                            Ok(ThreadMsg::EXECUTE(steps)) => {
                                for tx in tx_handles.iter_mut() {
                                    tx.send(ThreadMsg::EXECUTE(steps)).unwrap();
                                }
                                state = SchedulerState::RUNNING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            },
                            _ => ()
                        }
                    },
                    SchedulerState::RUNNING => {
                        match stat {
                            Ok(ThreadMsg::SHUTDOWN) => {
                                for tx in tx_handles.iter_mut() {
                                    tx.send(ThreadMsg::SHUTDOWN).unwrap();
                                }
                                state = SchedulerState::ENDING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                                continue;
                            },
                            _ => ()
                        }
                        // poll state
                        for (pos, rx) in rx_handles.iter_mut().enumerate() {
                            match rx.try_recv() {
                                Ok(ThreadMsg::OK) => {
                                    if !thread_state_received[pos] {
                                        thread_state_received[pos] = true;
                                        thread_rcv_num += 1;
                                    }
                                    if thread_rcv_num == threadlen {
                                        thread_rcv_num = 0;
                                        for state in thread_state_received.iter_mut() {
                                            *state = false;
                                        }

                                        state = SchedulerState::PAUSED;
                                        let mut s = mutex_state.lock().unwrap();
                                        *s = state;
                                    }
                                },
                                Ok(ThreadMsg::ERR) => {
                                    println!("Thread {} reported an error", pos);
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadMsg::END) => {
                                    state = SchedulerState::ENDED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadMsg::INIT) => {
                                    println!("Unexpected received init status");
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadMsg::EXECUTE(_)) => {
                                    println!("Unexpectedly received execute status");
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadMsg::SHUTDOWN) => {
                                    println!("Unexpectedly received shutdown status");
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadMsg::RUNNING) => {
                                    println!("Unexpectedly received shutdown status");
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Err(TryRecvError::Disconnected) => {
                                    println!("Channel is disconnected");
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Err(TryRecvError::Empty) => () // nothing received yet
                            }
                        }
                    },
                    SchedulerState::PAUSED => {
                        match stat {
                            Ok(ThreadMsg::EXECUTE(steps)) => {
                                for tx in tx_handles.iter_mut() {
                                    tx.send(ThreadMsg::EXECUTE(steps)).unwrap();
                                }
                                state = SchedulerState::RUNNING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            },
                            Ok(ThreadMsg::SHUTDOWN) => {
                                for tx in tx_handles.iter_mut() {
                                    tx.send(ThreadMsg::SHUTDOWN).unwrap();
                                }
                                state = SchedulerState::ENDING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            },
                            _ => ()
                        }
                    },
                    SchedulerState::ENDING => {
                        // poll waiting for threads to report finished
                        let mut end_received = vec![false; threadlen];
                        let mut end_num = 0;
                        loop {
                            for (pos, rx) in rx_handles.iter_mut().enumerate() {
                                match rx.try_recv() {
                                    Ok(ThreadMsg::END) => {
                                        if !end_received[pos] {
                                            end_received[pos] = true;
                                            end_num += 1;
                                        }
                                        if end_num == threadlen {
                                            state = SchedulerState::ENDED;
                                            let mut s = mutex_state.lock().unwrap();
                                            *s = state;

                                            println!("Simulation completed. {} threads exited successfully.", threadlen);
                                            return;
                                        }
                                    },
                                    _ => ()
                                }
                            }
                            thread::sleep(time::Duration::from_millis(20)); // sleep to prevent hogging the cpu
                        }
                    },
                    _ => ()
                }
                thread::sleep(time::Duration::from_millis(20)); // sleep to prevent hogging the cpu
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
    fn add_model(&mut self, model : Box<Box<dyn BaseModel + Send>>, thread: usize, divisor: i64, offset: i64) -> *mut c_void {
        if thread > self.threads.len() {
            return 0 as *mut c_void;
        }
        let obj = ScheduledObject {
            model: *model,
            divisor: divisor,
            offset: offset,
        };
        self.threads[thread].models.push(obj);
        return &self.threads[thread].models.last().unwrap().model as *const Box<dyn BaseModel + Send> as *mut c_void;
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
    fn step(&mut self, steps: u64) -> i32 {
        match &self.runner_tx {
            Some(tx) => {
                tx.send(ThreadMsg::EXECUTE(steps)).unwrap();
                return 0;
            },
            _ => {
                return 1;
            }
        }
    }
    fn end(&mut self) -> i32 {
        match &self.runner_tx {
            Some(tx) => {
                tx.send(ThreadMsg::SHUTDOWN).unwrap();
            },
            _ => {
                return 1;
            }
        }
        return 0;
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
