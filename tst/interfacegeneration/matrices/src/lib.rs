
extern crate modellib;
extern crate libc;

use libc::c_void;

use modellib::BufferStruct;
use modellib::SizeCallback;
use modellib::BaseModel;
use modellib::Framework;

mod matrixtest_interface;
use matrixtest_interface::*;

#[repr(C)]
pub struct matrices_test {
    pub intf : matrixtest, // registered with RSIS
    // non viewable
}

impl matrices_test {
    pub fn new() -> matrices_test {
        matrices_test {
            intf : matrixtest::new(),
        }
    }
}

impl BaseModel for matrices_test {
    fn config(&mut self) -> bool {
        true
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> bool {
        self.config()
    }
    fn step(&mut self) -> bool {
        true
    }
    fn pause(&mut self) -> bool {
        true
    }
    fn stop(&mut self) -> bool {
        true
    }
    fn msg_get(&self, id : BufferStruct, cb : SizeCallback) -> u32 {
        handle_msg_get(&self.intf, id, cb)
    }
    fn msg_set(&mut self, id : BufferStruct, data : BufferStruct) -> u32 {
        handle_msg_set(&mut self.intf, id, data)
    }
    fn get_ptr(&self, id : BufferStruct) -> *const u8 {
        get_pointer(&self.intf, id)
    }
}

#[no_mangle]
pub extern "C" fn create_model() -> *mut c_void {
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(matrices_test::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
