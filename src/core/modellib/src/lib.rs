
extern crate libc;
use libc::c_char;

pub trait BaseModel {
    fn config(&mut self) -> bool;
    fn init(&mut self) -> bool;
    fn step(&mut self) -> bool;
    fn pause(&mut self) -> bool;
    fn stop(&mut self) -> bool;
}

pub type ReflectClass  = extern fn(*const c_char);
pub type ReflectMember = extern fn(*const c_char, *const c_char, *const c_char, usize);
