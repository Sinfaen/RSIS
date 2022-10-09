
extern crate rsisappinterface;
extern crate libc;

use libc::c_void;

use rsisappinterface::BufferStruct;
use rsisappinterface::ConfigStatus;
use rsisappinterface::RuntimeStatus;
use rsisappinterface::SizeCallback;
use rsisappinterface::BaseModel;
use rsisappinterface::Framework;

mod bufferread_interface;
use bufferread_interface::*;

#[repr(C)]
pub struct bufferread_app {
    pub intf : bufferread, // registered with RSIS
}

impl bufferread_app {
    pub fn new() -> bufferread_app {
        bufferread_app {
            intf : bufferread::new(),
        }
    }
}

impl BaseModel for bufferread_app {
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
    fn step(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        let p = &self.intf.params;
        let ind = self.intf.data.index;
        unsafe {
            for i in 0..self.intf.data.nports {
                let byte_offset = ind * p.sizes[i] as isize;
                std::ptr::copy((p.psrc[i] as *mut u8).offset(byte_offset),
                    p.pdst[i] as *mut u8, p.sizes[i] as usize);
            }
        }
        self.intf.data.index += 1;
        if self.intf.data.index >= self.intf.params.ndata {
            RuntimeStatus::FINISHED
        } else {
            RuntimeStatus::OK
        }
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
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(bufferread_app::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
