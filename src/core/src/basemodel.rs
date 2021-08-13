
pub trait BaseModel {
    fn config(&self);
    fn init(&self);
    fn pause(&self);
    fn run(&self);
    fn stop(&self);
}
