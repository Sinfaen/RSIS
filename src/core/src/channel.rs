
extern crate rsisappinterface;
extern crate data_buffer;

use data_buffer::DataBuffer;
use std::any::Any;
use std::collections::HashMap;
use std::sync::{Arc, Mutex, mpsc, mpsc::Receiver, mpsc::Sender, mpsc::RecvError, mpsc::TryRecvError, mpsc::SendError};

use rsisappinterface::Framework;
use rsisappinterface::ChannelRx;
use rsisappinterface::ChannelTx;

use crate::epoch::EpochTime;

pub struct ChannelPairStorage {
    tx : Sender<DataBuffer>,
    rx : Option<Receiver<DataBuffer>>,
}

impl ChannelPairStorage {
    pub fn new() -> ChannelPairStorage {
        let (_tx, _rx) = mpsc::channel();
        ChannelPairStorage {
            tx : _tx,
            rx : Some(_rx),
        }
    }
}

pub struct MpscRx {
    rx : Receiver<DataBuffer>,
}

pub struct MpscTx {
    tx : Sender<DataBuffer>,
}

impl ChannelRx for MpscRx {
    fn recv(&mut self) -> Result<DataBuffer, RecvError> {
        self.rx.recv()
    }
    fn try_recv(&mut self) -> Result<DataBuffer, TryRecvError> {
        self.rx.try_recv()
    }
}

impl ChannelTx for MpscTx {
    fn send(&mut self, data : DataBuffer) -> Result<(), SendError<DataBuffer>> {
        self.tx.send(data)
    }
}

pub struct RSISInterface {
    map : Arc<Mutex<HashMap<i64, ChannelPairStorage>>>,
    pub time : Arc<Mutex<EpochTime>>,
}

impl RSISInterface {
    pub fn new() -> RSISInterface {
        RSISInterface {
            map : Arc::new(Mutex::new(HashMap::new())),
            time : Arc::new(Mutex::new(EpochTime::new())),
        }
    }
    pub fn clear(&mut self) {
        let mut data = self.map.lock().unwrap();
        (*data).clear();
    }
}

impl Framework for RSISInterface {
    fn as_any(&self) -> &dyn Any {
        self
    }
    fn get_simtick(&self) -> i64 {
        let mut data = self.time.lock().unwrap();
        (*data).time
    }
    fn get_simtime(&self) -> f64 {
        let mut data = self.time.lock().unwrap();
        (*data).value()
    }
    fn request_rx(&mut self, id : i64) -> Option<Box<dyn ChannelRx>> {
        let mut data = self.map.lock().unwrap();
        if !(*data).contains_key(&id) {
            (*data).insert(id, ChannelPairStorage::new());
        }
        if (*data)[&id].rx.is_some() {
            Some(Box::new(MpscRx {
                rx : (*data).get_mut(&id).unwrap().rx.take().unwrap()
            }))
        } else {
            None
        }
    }
    fn request_tx(&mut self, id : i64) -> Box<dyn ChannelTx> {
        let mut data = self.map.lock().unwrap();
        if !(*data).contains_key(&id) {
            (*data).insert(id, ChannelPairStorage::new());
        }
        Box::new(MpscTx {
            tx : (*data)[&id].tx.clone(),
        })
    }
}

impl Clone for RSISInterface {
    fn clone(&self) -> Self {
        RSISInterface {
            map : Arc::clone(&self.map),
            time : Arc::clone(&self.time),
        }
    }
}
