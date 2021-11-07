// Height Sensor Model
// Rust Version


#[macro_use]
extern crate memoffset;
extern crate modellib;
extern crate libc;

use modellib::BaseModel;

mod affine_transformation_interface;
use affine_transformation_interface::*;

#[repr(C)]
pub struct affine_transformation {
    // registered with RSIS
    pub inputs : affine_transformation_in,
    pub outputs : affine_transformation_out,
    pub data : affine_transformation_data,
    pub params : affine_transformation_params,
    // non viewable
}

impl affine_transformation {
    pub fn new() -> affine_transformation {
        affine_transformation {
            inputs : affine_transformation_in::new(),
            outputs : affine_transformation_out::new(),
            data : affine_transformation_data::new(),
            params : affine_transformation_params::new(),
        }
    }
}

impl BaseModel for affine_transformation {
    fn config(&mut self) -> bool {
        true
    }
    fn init(&mut self) -> bool {
        self.config()
    }
    fn step(&mut self) -> bool {
        self.outputs.output = self.inputs.input * self.params.scaling + self.params.bias;
        true
    }
    fn pause(&mut self) -> bool {
        true
    }
    fn stop(&mut self) -> bool {
        true
    }
}
