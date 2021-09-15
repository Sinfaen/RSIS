

extern crate libc;

mod rsis;

pub use rsis::Scheduler;
pub use rsis::NRTScheduler;

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
pub extern "C" fn add_model(thread: i64, ptr: * mut c_void, divisor: i64, offset: i64) -> u32 {
    if ptr.is_null() {
        return RSISStat::BADARG as u32;
    }
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn remove_model(id: i32) -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn init_scheduler() -> u32 {
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
pub extern "C" fn get_scheduler_name() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn get_message() -> u32 {
    return RSISStat::OK as u32;
}
