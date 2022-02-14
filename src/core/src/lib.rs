

extern crate libc;

mod rsis;
mod scheduler;
mod epoch;
mod connection;
mod channel;

pub use scheduler::Scheduler;
pub use rsis::NRTScheduler;


use modellib::BaseModel;
use modellib::BaseModelExternal;
use modellib::BoolCallback;
use modellib::VoidCallback;

use connection::Connection;

pub use std::ffi::c_void;
pub use libc::c_char;

static mut SCHEDULERS : Vec<Box<dyn Scheduler>> = vec![];

#[repr(u32)]
enum RSISStat {
    OK,
    BADARG,
    ERR
}

#[no_mangle]
pub extern "C" fn library_initialize() -> u32 {
    unsafe {
        SCHEDULERS.push(Box::new(NRTScheduler::new()));
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn library_shutdown() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn set_scheduler(id : u32) -> u32 {
    let stat = match id {
        0 => RSISStat::OK,
        _ => RSISStat::ERR
    };
    stat as u32
}

#[no_mangle]
pub extern "C" fn clear_threads() -> u32 {
    unsafe {
        SCHEDULERS.get_mut(0).unwrap().clear_threads();
        return RSISStat::OK as u32;
    }
}

#[no_mangle]
pub extern "C" fn new_thread(frequency : f64) -> u32 {
    unsafe {
        SCHEDULERS.get_mut(0).unwrap().add_thread(frequency);
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn add_model(thread: i64, ptr: *mut c_void, divisor: i64, offset: i64) -> *mut c_void {
    if ptr.is_null() {
        return 0 as *mut c_void;
    }
    if thread < 0 {
        return 0 as *mut c_void;
    }
    unsafe {
        // notes for C++ programmers. Rust dyn traits are "fat", they're actually
        // implemented as two pointers. That's why the double box procedure must be
        // used to pass a dyn trait object through FFI
        let boxed_trait: Box<Box<dyn BaseModel + Send>> = Box::from_raw(ptr as *mut Box<dyn BaseModel + Send>);
        return SCHEDULERS.get_mut(0).unwrap().add_model(boxed_trait, thread as usize, divisor, offset);
    }
}

#[no_mangle]
pub extern "C" fn add_model_by_callbacks(thread: i64,
    objp: *mut c_void, configp: *mut c_void, initp:*mut c_void, stepp: *mut c_void, pausep: *mut c_void, stopp: *mut c_void, destp: *mut c_void, divisor: i64, offset: i64) -> *mut c_void
{
    if objp.is_null() || configp.is_null() || initp.is_null() || stepp.is_null() || pausep.is_null() || stopp.is_null() || destp.is_null() {
        return 0 as *mut c_void; // prevent seg fault later on
    }
    // construct BaseModelExternal
    unsafe {
        let obj = BaseModelExternal {
            obj : objp,
            config_fn : std::mem::transmute::<*mut c_void, BoolCallback>(configp),
            init_fn   : std::mem::transmute::<*mut c_void, BoolCallback>(initp),
            step_fn   : std::mem::transmute::<*mut c_void, BoolCallback>(stepp),
            pause_fn  : std::mem::transmute::<*mut c_void, BoolCallback>(pausep),
            stop_fn   : std::mem::transmute::<*mut c_void, BoolCallback>(stopp),
            destructor_fn : std::mem::transmute::<*mut c_void, VoidCallback>(destp),
        };
        let boxed_trait : Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(obj));
        return SCHEDULERS.get_mut(0).unwrap().add_model(boxed_trait, thread as usize, divisor, offset);
    }
}

#[no_mangle]
pub extern "C" fn add_connection(src: *mut u8, dst: *mut u8, size: usize, thread: i64, divisor: i64, offset: i64) -> u32 {
    if src.is_null() || dst.is_null() || size == 0 {
        return RSISStat::BADARG as u32;
    }
    let obj = Connection {
        src : src as *mut i8,
        dst : dst as *mut i8,
        size : size,
    };
    unsafe {
        let boxed_trait : Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(obj));
        let ptr = SCHEDULERS.get_mut(0).unwrap().add_model(boxed_trait, thread as usize, divisor, offset);
        if ptr.is_null() {
            return RSISStat::ERR as u32;
        }
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn remove_model(id: i32) -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn init_scheduler() -> u32 {
    unsafe {
        if SCHEDULERS.get_mut(0).unwrap().init() != 0 {
            return RSISStat::ERR as u32;
        }
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn step_scheduler(steps: u64) -> u32 {
    unsafe {
        if SCHEDULERS.get_mut(0).unwrap().step(steps) != 0 {
            return RSISStat::ERR as u32;
        }
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn pause_scheduler() -> u32 {
    unsafe {
        if SCHEDULERS.get_mut(0).unwrap().pause() != 0 {
            return RSISStat::ERR as u32;
        }
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn run_scheduler() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn end_scheduler() -> u32 {
    unsafe {
        SCHEDULERS.get_mut(0).unwrap().end();
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn get_thread_number() -> i32 {
    unsafe {
        SCHEDULERS.get_mut(0).unwrap().get_num_threads()
    }
}

#[no_mangle]
pub extern "C" fn get_scheduler_state() -> i32 {
    unsafe {
        SCHEDULERS.get_mut(0).unwrap().get_state() as i32
    }
}

#[no_mangle]
pub extern "C" fn get_scheduler_name() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn get_message() -> u32 {
    return RSISStat::OK as u32;
}

// Utility methods, not related to running the scheduler and framework

#[repr(C, align(8))]
pub struct UTF8Data {
    ptr : *const c_void,
    size : u64,
}

#[no_mangle]
pub extern "C" fn config_scheduler(data : UTF8Data) -> u32 {
    unsafe {
        let slice = std::slice::from_raw_parts(data.ptr as *const u8, data.size as usize);
        match std::str::from_utf8(slice) {
            Ok(value) => {
                SCHEDULERS.get_mut(0).unwrap().config(value.to_string());
                return RSISStat::OK as u32;
            },
            Err(_) => {
                return RSISStat::ERR as u32;
            }
        }
    }
}
