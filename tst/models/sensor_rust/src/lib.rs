#[cfg(test)]
mod height_sensor {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

extern crate modellib;
extern crate libc;

use modellib::BaseModel;
use std::ffi::c_void;

mod heightSensor_interface;
use heightSensor_interface::heightSensor;

#[no_mangle]
pub extern "C" fn create_model() -> u32 {
    let model = heightSensor::new();
    0
}

impl BaseModel for heightSensor {
    fn config(&mut self) -> bool {
        if self.params.limits[1] < self.params.limits[0] {
            return false
        }
        true
    }
    fn init(&mut self) -> bool {
        true
    }
    fn step(&mut self) -> bool {
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