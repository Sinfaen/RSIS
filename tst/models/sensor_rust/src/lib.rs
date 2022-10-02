// Height Sensor Model
// Rust Version

extern crate rsisappinterface;
extern crate libc;

use libc::c_void;

use rsisappinterface::BufferStruct;
use rsisappinterface::ConfigStatus;
use rsisappinterface::RuntimeStatus;
use rsisappinterface::SizeCallback;
use rsisappinterface::BaseModel;
use rsisappinterface::Framework;

use rand::distributions::Distribution;
use statrs::distribution::Normal;

mod height_sensor_interface;
use height_sensor_interface::*;

#[repr(C)]
pub struct height_sensor_model {
    pub intf : height_sensor, // registered with RSIS
    // non viewable
    pub dist : Normal,
}

impl height_sensor_model {
    pub fn new() -> height_sensor_model {
        height_sensor_model {
            intf : height_sensor::new(),
            dist : Normal::new(0.0, 1.0).unwrap(),
        }
    }
}

impl BaseModel for height_sensor_model {
    fn config(&mut self) -> ConfigStatus {
        if self.intf.params.limits[1] < self.intf.params.limits[0] {
            println!("Limit range must be specified as [lower, upper]");
            return ConfigStatus::ERROR
        }
        ConfigStatus::OK
    }
    fn init(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        self.dist = Normal::new(0.0, self.intf.params.noise).unwrap();
        println!("Created file: {}", self.intf.params.stats_file);
        match self.config() {
            ConfigStatus::OK | ConfigStatus::INTERFACEUPDATE => {
                return RuntimeStatus::OK
            },
            ConfigStatus::ERROR => {
                return RuntimeStatus::ERROR
            }
        }
    }
    fn step(&mut self, _interface : &mut Box<dyn Framework>) -> RuntimeStatus {
        let mut r = rand::thread_rng();
        self.intf.data.measurement = self.intf.inputs.signal + self.dist.sample(&mut r);
        if self.intf.data.measurement < self.intf.params.limits[0] ||
            self.intf.data.measurement > self.intf.params.limits[1]
        {
            self.intf.outputs.inrange = false
        } else {
            self.intf.outputs.inrange = true
        }
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
    let obj: Box<Box<dyn BaseModel + Send>> = Box::new(Box::new(height_sensor_model::new()));
    Box::into_raw(obj) as *mut Box<dyn BaseModel + Send> as *mut c_void
}
