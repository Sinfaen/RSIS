
mod framework;

extern crate libc;
use libc::c_void;

pub use framework::Framework;
pub use framework::ChannelRx;
pub use framework::ChannelTx;

#[repr(C, align(8))]
pub struct BufferStruct {
    pub ptr : *const u8,
    pub size : usize,
}

pub trait BaseModel {
    fn config(&mut self) -> bool;
    fn init(&mut self, interface : &mut Box<dyn Framework>) -> bool;
    fn step(&mut self) -> bool;
    fn pause(&mut self) -> bool;
    fn stop(&mut self) -> bool;

    fn msg_get(&self, id : BufferStruct, data : BufferStruct) -> u32;
    fn msg_set(&mut self, id : BufferStruct, data : BufferStruct) -> u32;
}

pub type BoolCallback = unsafe extern "C" fn(obj : *mut c_void) -> bool;
pub type VoidCallback = unsafe extern "C" fn(obj : *mut c_void);

/// Used for wrapping models that come from other language, like C++ and Fortran
pub struct BaseModelExternal {
    pub obj : *mut c_void,
    pub config_fn : BoolCallback,
    pub init_fn : BoolCallback,
    pub step_fn : BoolCallback,
    pub pause_fn : BoolCallback,
    pub stop_fn : BoolCallback,
    pub destructor_fn : VoidCallback,
}

impl BaseModel for BaseModelExternal {
    fn config(&mut self) -> bool {
        unsafe { (self.config_fn)(self.obj) }
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> bool {
        unsafe { (self.init_fn)(self.obj) }
    }
    fn step(&mut self) ->  bool {
        unsafe { (self.step_fn)(self.obj) }
    }
    fn pause(&mut self) -> bool {
        unsafe { (self.pause_fn)(self.obj) }
    }
    fn stop(&mut self) -> bool {
        unsafe { (self.stop_fn)(self.obj) }
    }
    fn msg_get(&self, _id : BufferStruct, _data : BufferStruct) -> u32 {
        1
    }
    fn msg_set(&mut self, _id : BufferStruct, _data : BufferStruct) -> u32 {
        1
    }
}

impl Drop for BaseModelExternal {
    fn drop(&mut self) {
        unsafe { (self.destructor_fn)(self.obj); }
    }
}

unsafe impl Send for BaseModelExternal {}

#[no_mangle]
pub extern "C" fn meta_get(ptr : *mut c_void, id : BufferStruct, data : BufferStruct) -> u32 {
    let app : Box<Box<dyn BaseModel + Send>> = unsafe { Box::from_raw(ptr as *mut Box<dyn BaseModel + Send>) };
    let stat = (*app).msg_get(id, data);
    Box::into_raw(app); // release ownership of the box
    stat
}

#[no_mangle]
pub extern "C" fn meta_set(ptr : *mut c_void, id : BufferStruct, data : BufferStruct) -> u32 {
    let mut app : Box<Box<dyn BaseModel + Send>> = unsafe { Box::from_raw(ptr as *mut Box<dyn BaseModel + Send>) };
    let stat = (*app).msg_set(id, data);
    Box::into_raw(app); // release ownership of the box
    stat
}
