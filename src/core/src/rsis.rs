
extern crate modellib;

use crate::scheduler::SchedulerState;
use crate::scheduler::Scheduler;
use crate::scheduler::ScheduledObject;

use crate::channel::RSISInterface;

pub use std::ffi::c_void;
use modellib::BaseModel;
use modellib::RuntimeStatus;
use modellib::Framework;
use std::{thread,time};
use std::sync::{Arc, Barrier, mpsc, mpsc::TryRecvError, mpsc::Receiver, mpsc::Sender, Mutex};

use crate::epoch::EpochTime;

#[derive(Copy,Clone,PartialEq)]
pub enum ThreadCommand {
    INIT,
    EXECUTE(u64),
    PAUSE,
    SHUTDOWN
}

#[derive(Copy,Clone,PartialEq)]
pub enum ThreadResult {
    OK(ThreadCommand),
    ERR(ThreadCommand, u32),
    END
}

pub struct ThreadState {
    pub frequency : f64,
    pub models : Vec<ScheduledObject>,
}

//
// Implements an optional soft-real-time scheduling,
// where the std::thread::sleep call is used to halt the
// thread for a specific period of time
pub struct NRTScheduler {
    pub threads : Vec<ThreadState>,
    pub handles : Vec<thread::JoinHandle<()>>,
    pub state   : Arc<Mutex<SchedulerState>>,

    pub runner : Option<thread::JoinHandle<()>>,
    pub runner_tx : Option<Sender<ThreadCommand>>,
    pub runner_rx : Option<Receiver<ThreadResult>>,

    pub interface : RSISInterface,

    // parameters
    pub soft_real_time : bool, // if true, enable soft real-time behavior
}

fn time_to_next_frame(start : time::Instant, width : time::Duration) -> time::Duration {
    let now = time::Instant::now();
    width - (now - start)
}

fn send_cmd_to_threads(handles : &mut Vec::<Sender<ThreadCommand>>, cmd : ThreadCommand) {
    for tx in handles.iter_mut() {
        tx.send(cmd).unwrap();
    }
}

impl NRTScheduler {
    fn start_runner(&mut self) -> (Sender<ThreadCommand>, Receiver<ThreadResult>) {
        let (mtor_tx, mtor_rx) = mpsc::channel();
        let (rtom_tx, rtom_rx) = mpsc::channel();
        let threadlen = self.threads.len();
        
        // create threads now. Add 1 for main thread
        let mut thread_state = Vec::<SchedulerState>::new();
        let mut tx_handles = Vec::<Sender<ThreadCommand>>::new();
        let mut rx_handles = Vec::<Receiver<ThreadResult>>::new();
        let barrier = Arc::new(Barrier::new(threadlen));
        for ts in &mut self.threads[..] {
            let cbarrier = Arc::clone(&barrier);
            let mut interface : Box<dyn Framework> = Box::new(RSISInterface::clone(&self.interface));
            let mut u: Vec<_> = ts.models.drain(..).collect();
            let (txx, rxx) = mpsc::channel(); // trigger channel
            let (tx, rx)   = mpsc::channel(); // response channel

            let srt = self.soft_real_time; // passed to closure
            let frame_dur = 1.0 / ts.frequency;
            let frame_sec = frame_dur.trunc();
            let frame_ns  = (frame_dur - frame_sec) / 1e9;
            let frame_width = time::Duration::new(frame_sec as u64, frame_ns as u32);

            self.handles.push(thread::spawn(move|| {
                loop {
                    let mut time = EpochTime::new();
                    match rxx.recv() {
                        Ok(ThreadCommand::INIT) => {
                            let mut ii = 0;
                            for obj in &mut u[..] {
                                match (*obj).model.init(&mut interface) {
                                    RuntimeStatus::ERROR => {
                                        tx.send(ThreadResult::ERR(ThreadCommand::INIT, ii));
                                        break;
                                    },
                                    _ => ()
                                }
                                ii += 1;
                            }
                            tx.send(ThreadResult::OK(ThreadCommand::INIT)).unwrap();
                        },
                        Ok(ThreadCommand::EXECUTE(value)) => {
                            for _ in 0..value {
                                let framestart = time::Instant::now();
                                for obj in &mut u[..] {
                                    if (*obj).counter == 0 {
                                        (*obj).model.step();
                                    }
                                    (*obj).counter += 1;
                                    if (*obj).counter == (*obj).divisor {
                                        (*obj).counter = 0;
                                    }
                                }
                                // Check for pause command
                                match rxx.try_recv() {
                                    Ok(ThreadCommand::PAUSE) => {
                                        for obj in &mut u[..] {
                                            (*obj).model.pause();
                                        }
                                        tx.send(ThreadResult::OK(ThreadCommand::PAUSE)).unwrap();
                                        break;
                                    },
                                    _ => {
                                        // do nothing
                                    }
                                }
                                // framework activities
                                time.increment(1); // increment sim time
                                if srt {
                                    // sleep to simulate soft real time
                                    thread::sleep(time_to_next_frame(framestart, frame_width));
                                } else {
                                    thread::sleep(time::Duration::ZERO);
                                }
                                cbarrier.wait();
                            }
                            // call pausing function
                            for obj in &mut u[..] {
                                (*obj).model.pause();
                            }
                            tx.send(ThreadResult::OK(ThreadCommand::EXECUTE(value))).unwrap();
                        },
                        Ok(ThreadCommand::PAUSE) => {
                            continue;
                        }
                        Ok(ThreadCommand::SHUTDOWN) => {
                            tx.send(ThreadResult::END).unwrap();
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
                        if stat == Ok(ThreadCommand::INIT) {
                            send_cmd_to_threads(&mut tx_handles, ThreadCommand::INIT);
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
                                Ok(ThreadResult::OK(_)) => {
                                    thread_state[pos] = SchedulerState::INITIALIZED;
                                },
                                Ok(ThreadResult::ERR(cmd, idx)) => {
                                    thread_state[pos] = SchedulerState::ERRORED;
                                    println!("<Thread {}, app {}> errored in init.", pos, idx);
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
                            Ok(ThreadCommand::EXECUTE(steps)) => {
                                send_cmd_to_threads(&mut tx_handles, ThreadCommand::EXECUTE(steps));
                                state = SchedulerState::RUNNING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            },
                            _ => ()
                        }
                    },
                    SchedulerState::RUNNING => {
                        match stat {
                            Ok(ThreadCommand::PAUSE) => {
                                send_cmd_to_threads(&mut tx_handles, ThreadCommand::PAUSE);
                            },
                            Ok(ThreadCommand::SHUTDOWN) => {
                                send_cmd_to_threads(&mut tx_handles, ThreadCommand::SHUTDOWN);
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
                                Ok(ThreadResult::OK(_)) => {
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
                                Ok(ThreadResult::ERR(_, _)) => {
                                    println!("Thread {} reported an error", pos);
                                    state = SchedulerState::ERRORED;
                                    let mut s = mutex_state.lock().unwrap();
                                    *s = state;
                                },
                                Ok(ThreadResult::END) => {
                                    state = SchedulerState::ENDED;
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
                            Ok(ThreadCommand::EXECUTE(steps)) => {
                                send_cmd_to_threads(&mut tx_handles, ThreadCommand::EXECUTE(steps));
                                state = SchedulerState::RUNNING;
                                let mut s = mutex_state.lock().unwrap();
                                *s = state;
                            },
                            Ok(ThreadCommand::SHUTDOWN) => {
                                send_cmd_to_threads(&mut tx_handles, ThreadCommand::SHUTDOWN);
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
                                    Ok(ThreadResult::END) => {
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
            counter: offset % divisor,
        };
        self.threads[thread].models.push(obj);
        return &self.threads[thread].models.last().unwrap().model as *const Box<dyn BaseModel + Send> as *mut c_void;
    }
    fn get_num_threads(&self) -> i32 {
        self.threads.len() as i32
    }
    fn config(&mut self, toml : String) -> i32 {
        0
    }
    fn init(&mut self) -> i32 {
        let (tx, rx) = self.start_runner();
        tx.send(ThreadCommand::INIT).unwrap(); // todo deal with unwrap
        self.runner_tx = Some(tx);
        self.runner_rx = Some(rx);
        //
        0
    }
    fn step(&mut self, steps: u64) -> i32 {
        match &self.runner_tx {
            Some(tx) => {
                tx.send(ThreadCommand::EXECUTE(steps)).unwrap();
                return 0;
            },
            _ => {
                return 1;
            }
        }
    }
    fn pause(&mut self) -> i32 {
        match &self.runner_tx {
            Some(tx) => {
                tx.send(ThreadCommand::PAUSE).unwrap();
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
                tx.send(ThreadCommand::SHUTDOWN).unwrap();
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
            interface : RSISInterface::new(),
            soft_real_time : false,
        }
    }
}
