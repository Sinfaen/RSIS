#[cfg(test)]
mod height_sensor {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

extern crate modellib;

use modellib::BaseModel;
use std::ffi::c_void;

#[no_mangle]
pub extern "C" fn create_model() -> u32 {
    0
}

#[no_mangle]
pub extern "C" fn Reflect(_cb1 : * mut c_void, _cb2 : * mut c_void) -> u32 {
    0
}