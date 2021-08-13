#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

pub trait BaseModel {
    fn config(&self);
    fn init(&self);
    fn pause(&self);
    fn run(&self);
    fn stop(&self);
}
