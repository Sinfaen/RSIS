
// Connections are used to allow data transfer between model inputs and outputs
// via pointers. This is done to allow the dynamic nature of Julia based simulations
// In the future, I want to have the ability to autocode an entire simulation into
// "pure" rust code (with C++ and Fortran code being included via libraries), where
// these connection objects will not be necessary

// Connections are implemented via the BaseModel trait interface
// It is up to the Julia interface to add these in the correct order,
// and create these as efficiently as possible

use rsisappinterface::BaseModel;
use rsisappinterface::BufferStruct;
use rsisappinterface::ConfigStatus;
use rsisappinterface::RuntimeStatus;
use rsisappinterface::SizeCallback;
use rsisappinterface::Framework;
use std::ptr;

pub struct Connection {
    pub src : *mut i8,
    pub dst : *mut i8,
    pub size : usize,
}

impl BaseModel for Connection {
    fn config(&mut self) -> ConfigStatus {
        ConfigStatus::OK
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        RuntimeStatus::OK
    }
    fn step(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        unsafe {
            ptr::copy(self.src, self.dst, self.size);
        }
        RuntimeStatus::OK
    }
    fn pause(&mut self) -> RuntimeStatus {
        RuntimeStatus::OK
    }
    fn stop(&mut self) -> RuntimeStatus {
        RuntimeStatus::OK
    }
    fn msg_get(&self, _id : BufferStruct, _cb : SizeCallback) -> u32 {
        1
    }
    fn msg_set(&mut self, _id : BufferStruct, _data : BufferStruct) -> u32 {
        1
    }
    fn get_ptr(&self, _id : BufferStruct) -> *const u8 {
        0 as *const u8
    }
}

unsafe impl Send for Connection {}
