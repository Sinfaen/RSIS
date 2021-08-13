
pub trait Scheduler {
    fn get_num_threads(&self) -> i32;
}

pub struct NRTScheduler {
    num_threads : i32
}

impl Scheduler for NRTScheduler {
    fn get_num_threads(&self) -> i32 {
        self.num_threads
    }
}

impl NRTScheduler {
    pub const fn new() -> NRTScheduler {
        NRTScheduler { num_threads: 0 }
    }
}
