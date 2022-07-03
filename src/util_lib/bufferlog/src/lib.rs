
extern crate modellib;
extern crate libc;

use libc::c_void;

use modellib::BufferStruct;
use modellib::ConfigStatus;
use modellib::RuntimeStatus;
use modellib::SizeCallback;
use modellib::BaseModel;
use modellib::Framework;

mod bufferlog_interface;
use bufferlog_interface::*;

#[repr(C)]
pub struct bufferlog_app {
    pub intf : bufferlog, // registered with RSIS
}

impl bufferlog_app {
    pub fn new() -> bufferlog_app {
        bufferlog_app {
            intf : bufferlog::new(),
        }
    }
}

impl BaseModel for bufferlog_app {
    fn config(&mut self) -> ConfigStatus {
        ConfigStatus::OK
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        let n = self.intf.params.psrc.len();
        if self.intf.params.psrc.len() != n {
            return RuntimeStatus::ERROR
        }
        if self.intf.params.sizes.len() != n {
            return RuntimeStatus::ERROR
        }
        self.intf.data.nports = n;
        self.intf.data.index = 0;
        RuntimeStatus::OK
    }
    fn step(&mut self) -> RuntimeStatus {
        let p = &self.intf.params;
        let o = self.intf.data.index;
        unsafe {
            for i in 0..self.intf.data.nports {
                std::ptr::copy((p.psrc[i] as *mut u8),
                    (p.pdst[i] as *mut u8).offset(o), p.sizes[i] as usize);
            }
        }
        self.intf.data.index += 1;
        RuntimeStatus::OK
    }
    fn pause(&mut self) -> RuntimeStatus {
        RuntimeStatus::OK
    }
    fn stop(&mut self) -> RuntimeStatus {
        RuntimeStatus::OK
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
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(bufferlog_app::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
