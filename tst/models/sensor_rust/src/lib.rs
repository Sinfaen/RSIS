// Height Sensor Model
// Rust Version


#[macro_use]
extern crate memoffset;
extern crate modellib;
extern crate libc;

use libc::c_void;

use modellib::BaseModel;

use rand::distributions::Distribution;
use statrs::distribution::Normal;

mod height_sensor_interface;
use height_sensor_interface::height_sensor;

impl BaseModel for height_sensor {
    fn config(&mut self) -> bool {
        if self.params.limits[1] < self.params.limits[0] {
            println!("Limit range must be specified as [lower, upper]");
            return false
        }
        true
    }
    fn init(&mut self) -> bool {
        self.config()
    }
    fn step(&mut self) -> bool {
        let dist = Normal::new(0.0, self.params.noise).unwrap();
        let mut r = rand::thread_rng();
        self.data.measurement = self.inputs.signal + dist.sample(&mut r);
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

#[no_mangle]
pub extern "C" fn create_model() -> *mut c_void {
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(height_sensor::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
