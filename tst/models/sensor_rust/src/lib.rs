#[cfg(test)]
mod height_sensor {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

extern crate modellib;
extern crate libc;

#[macro_use]
extern crate memoffset;

use modellib::BaseModel;

mod heightSensor_interface;
use heightSensor_interface::height_sensor;

impl BaseModel for height_sensor {
    fn config(&mut self) -> bool {
        if self.params.limits[1] < self.params.limits[0] {
            println!("Limit range must be specificed as [lower, upper]");
            return false
        }
        true
    }
    fn init(&mut self) -> bool {
        if self.config() {
            println!("height sensor connected - (fake message)");
            return true;
        }
        return false;
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