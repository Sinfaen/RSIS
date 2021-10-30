

extern crate libc;

mod rsis;
mod epoch;

pub use rsis::Scheduler;
pub use rsis::NRTScheduler;


use modellib::BaseModel;

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
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn run_scheduler() -> u32 {
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
pub extern "C" fn get_utf8_string(ptr : *mut c_void) -> UTF8Data {
    // convert pointer to string object
    unsafe {
        let str_ptr = ptr as *mut String;
        // TODO use into_raw_parts when it is stabilized
        UTF8Data {
            ptr : (*str_ptr).as_ptr() as *const c_void,
            size : (*str_ptr).len() as u64,
        }
    }
}

#[no_mangle]
pub extern "C" fn set_utf8_string(ptr : *mut c_void, data : UTF8Data) -> u32 {
    // create a new string
    unsafe {
        let str_ptr = ptr as *mut String;
        let slice = std::slice::from_raw_parts(data.ptr as *const u8, data.size as usize);
        match std::str::from_utf8(slice) {
            Ok(value) => {
                (*str_ptr) = value.to_string();
                return RSISStat::OK as u32;
            },
            Err(_) => {
                return RSISStat::ERR as u32;
            }
        }
    }
}
