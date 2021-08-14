

extern crate libc;

mod rsis;

pub use rsis::Scheduler;
pub use rsis::NRTScheduler;
pub use rsis::LoadedModels;

pub use std::ffi::c_void;
pub use libc::c_char;

static mut SCHEDULER : NRTScheduler = NRTScheduler::new();
static mut MODELS : LoadedModels = LoadedModels { rust_objs: Vec::new() };

#[repr(u32)]
enum RSISStat {
    OK,
    BADARG,
    ERR
}

#[no_mangle]
pub extern "C" fn library_initialize() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn library_shutdown() -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn add_model(name : *const c_char, ptr : * mut c_void) -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn remove_model(name: *const c_char) -> u32 {
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
pub extern "C" fn set_thread(thread_id : i32, frequency : f64) -> u32 {
    return RSISStat::OK as u32;
}

#[no_mangle]
pub extern "C" fn get_thread_number() -> i32 {
    unsafe {
        SCHEDULER.get_num_threads()
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