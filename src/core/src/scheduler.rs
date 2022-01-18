
extern crate modellib;

use modellib::BaseModel;
use std::ffi::c_void;

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

pub trait Scheduler {
    fn clear_threads(&mut self) -> ();
    fn add_thread(&mut self, freq : f64) -> ();
    fn add_model(&mut self, model: Box<Box<dyn BaseModel + Send>>, thread: usize, divisor: i64, offset: i64) -> *mut c_void;
    fn get_num_threads(&self) -> i32;

    fn init(&mut self) -> i32;
    fn step(&mut self, steps: u64) -> i32;
    fn pause(&mut self) -> i32;
    fn end(&mut self) -> i32;

    fn get_state(&self) -> SchedulerState;
}

pub struct ScheduledObject {
    pub model : Box<dyn BaseModel + Send>,
    pub divisor : i64,
    pub offset : i64,

    pub counter : i64,
}
