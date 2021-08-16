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
use modellib::ReflectClass;
use modellib::ReflectMember;
use std::ffi::c_void;

mod heightSensor_interface;
use heightSensor_interface::heightSensor;
use heightSensor_interface::reflect_all;

#[no_mangle]
pub extern "C" fn create_model() -> u32 {
    let model = heightSensor::new();
    0
}

#[no_mangle]
pub extern "C" fn reflect(_cb1 : ReflectClass, _cb2 : ReflectMember) {
    reflect_all(_cb1, _cb2);
}
