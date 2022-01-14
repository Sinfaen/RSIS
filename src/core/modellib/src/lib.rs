
extern crate libc;
use libc::c_char;
use libc::c_void;

pub trait BaseModel {
    fn config(&mut self) -> bool;
    fn init(&mut self) -> bool;
    fn step(&mut self) -> bool;
    fn pause(&mut self) -> bool;
    fn stop(&mut self) -> bool;
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
    fn init(&mut self) -> bool {
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
}

impl Drop for BaseModelExternal {
    fn drop(&mut self) {
        unsafe { (self.destructor_fn)(self.obj); }
    }
}

unsafe impl Send for BaseModelExternal {}

pub type ReflectClass  = extern fn(*const c_char);
pub type ReflectMember = extern fn(*const c_char, *const c_char, *const c_char, usize, *const c_char);
