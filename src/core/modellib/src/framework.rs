extern crate data_buffer;

use data_buffer::DataBuffer;
use std::sync::{mpsc::RecvError, mpsc::TryRecvError, mpsc::SendError};

pub trait ChannelRx {
    fn recv(&mut self) -> Result<DataBuffer, RecvError>;
    fn try_recv(&mut self) -> Result<DataBuffer, TryRecvError>;
}

pub trait ChannelTx {
    fn send(&mut self, data : DataBuffer) -> Result<(), SendError<DataBuffer>>;
}

pub trait Framework : Send {
    fn request_rx(&mut self, id : i64) -> Option<Box<dyn ChannelRx>>;
    fn request_tx(&mut self, id : i64) -> Box<dyn ChannelTx>;
}

