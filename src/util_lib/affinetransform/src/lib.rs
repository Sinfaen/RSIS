// Height Sensor Model
// Rust Version


extern crate modellib;
extern crate libc;

use libc::c_void;

use modellib::BufferStruct;
use modellib::SizeCallback;
use modellib::BaseModel;
use modellib::Framework;

mod affine_transformation_interface;
use affine_transformation_interface::*;

#[repr(C)]
pub struct affine_transformation_model {
    pub intf : affine_transformation, // registered with RSIS
    // non viewable
}

impl affine_transformation_model {
    pub fn new() -> affine_transformation_model {
        affine_transformation_model {
            intf : affine_transformation::new(),
        }
    }
}

impl BaseModel for affine_transformation_model {
    fn config(&mut self) -> bool {
        true
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> bool {
        self.config()
    }
    fn step(&mut self) -> bool {
        self.intf.outputs.signal = self.intf.inputs.signal * self.intf.params.scaling + self.intf.params.bias;
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
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(affine_transformation_model::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
