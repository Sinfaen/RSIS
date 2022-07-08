#ifndef __HEIGHT_SENSOR_HXX_
#define __HEIGHT_SENSOR_HXX_

#include <BaseModel.hxx>
#include "height_sensor_interface.hxx"

class height_sensor_model : public BaseModel {
public:
    height_sensor_model();
    virtual ~height_sensor_model();

    ConfigStatus config();
    RuntimeStatus init();
    RuntimeStatus step();
    RuntimeStatus pause();
    RuntimeStatus stop();

    uint32_t msg_get(BufferStruct id, SizeCallback cb);
    uint32_t msg_set(BufferStruct id, BufferStruct data);
    uint8_t* get_ptr(BufferStruct id);

    height_sensor intf;
};


extern "C" {
    BaseModel* create_model();
}

#endif
