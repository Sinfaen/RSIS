
// Connections are used to allow data transfer between model inputs and outputs
// via pointers. This is done to allow the dynamic nature of Julia based simulations
// In the future, I want to have the ability to autocode an entire simulation into
// "pure" rust code (with C++ and Fortran code being included via libraries), where
// these connection objects will not be necessary

// Connections are implemented via the BaseModel trait interface
// It is up to the Julia interface to add these in the correct order,
// and create these as efficiently as possible

use modellib::BaseModel;
use std::ptr;

pub struct Connection {
    pub src : *mut i8,
    pub dst : *mut i8,
    pub size : usize,
}

impl BaseModel for Connection {
    fn config(&mut self) -> bool {
        true
    }
    fn init(&mut self) -> bool {
        true
    }
    fn step(&mut self) ->  bool {
        unsafe {
            ptr::copy(self.src, self.dst, self.size);
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

unsafe impl Send for Connection {}