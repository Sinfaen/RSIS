

#[derive(Copy, Clone)]
pub struct EpochTime {
    pub epoch    : i64,
    pub time     : i64,
    pub delta    : f64,
    pub rollover : i64,
}

impl EpochTime {
    pub fn increment(&mut self, steps : i64) -> () {
        self.time += steps;
        if self.time >= self.rollover {
            self.time -= self.rollover;
            self.epoch += 1;
        }
    }

    pub fn value(&self) -> f64 {
        self.time as f64 * self.delta
    }
    
    pub fn new() -> EpochTime {
        EpochTime {
            epoch : 0,
            time  : 0,
            delta : 1.0,
            rollover : i64::MAX,
        }
    }
}