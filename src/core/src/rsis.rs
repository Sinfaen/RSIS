
extern crate modellib;

use modellib::BaseModel;


pub trait Scheduler {
    fn clear_threads(&mut self) -> ();
    fn add_thread(&mut self, freq : f64) -> ();
    fn add_model(&mut self, model : Box<Box<dyn BaseModel>>) -> i32;
    fn get_num_threads(&self) -> i32;

    fn init(&mut self) -> i32;
    fn step(&mut self) -> i32;
    fn end(&mut self) -> i32;
}

pub struct ThreadState {
    pub frequency : f64,
}

pub struct NRTScheduler {
    pub threads : Vec<ThreadState>,
    pub models : Vec<Box<dyn BaseModel>>
}

impl Scheduler for NRTScheduler {
    fn clear_threads(&mut self) -> () {
        self.threads.clear();
    }
    fn add_thread(&mut self, freq : f64) -> (){
        self.threads.push(ThreadState {
            frequency: freq
        })
    }
    fn add_model(&mut self, model : Box<Box<dyn BaseModel>>) -> i32 {
        self.models.push(*model);
        0
    }
    fn get_num_threads(&self) -> i32 {
        self.threads.len() as i32
    }
    fn init(&mut self) -> i32 {
        for model in &mut self.models[0..] {
            if !(*model).init() {
                return 1;
            }
        }
        0
    }
    fn step(&mut self) -> i32 {
        0
    }
    fn end(&mut self) -> i32 {
        0
    }
}

impl NRTScheduler {
    pub fn new() -> NRTScheduler {
        NRTScheduler {
            threads: Vec::<ThreadState>::new(),
            models: Vec::new(),
        }
    }
}
