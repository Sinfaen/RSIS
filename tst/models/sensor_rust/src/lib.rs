// Height Sensor Model
// Rust Version


#[macro_use]
extern crate memoffset;
extern crate modellib;
extern crate libc;

use modellib::BaseModel;

use rand::distributions::Distribution;
use statrs::distribution::Normal;

mod height_sensor_interface;
use height_sensor_interface::*;

#[repr(C)]
pub struct height_sensor {
    // registered with RSIS
    pub inputs : height_sensor_in,
    pub outputs : height_sensor_out,
    pub data : height_sensor_data,
    pub params : height_sensor_params,
    // non viewable
    pub dist : Normal,
}

impl height_sensor {
    pub fn new() -> height_sensor {
        height_sensor {
            inputs : height_sensor_in::new(),
            outputs : height_sensor_out::new(),
            data : height_sensor_data::new(),
            params : height_sensor_params::new(),
            dist : Normal::new(0.0, 1.0).unwrap(),
        }
    }
}

impl BaseModel for height_sensor {
    fn config(&mut self) -> bool {
        if self.params.limits[1] < self.params.limits[0] {
            println!("Limit range must be specified as [lower, upper]");
            return false
        }
        true
    }
    fn init(&mut self) -> bool {
        self.dist = Normal::new(0.0, self.params.noise).unwrap();
        println!("Created file: {}", self.params.stats_file);
        self.config()
    }
    fn step(&mut self) -> bool {
        let mut r = rand::thread_rng();
        self.data.measurement = self.inputs.signal + self.dist.sample(&mut r);
        if self.data.measurement < self.params.limits[0] ||
            self.data.measurement > self.params.limits[1]
        {
            self.outputs.inrange = false
        } else {
            self.outputs.inrange = true
        }
        true
    }
    fn pause(&mut self) -> bool {
        true
    }
    fn stop(&mut self) -> bool {
        true
    }
}
