#ifndef __HEIGHT_SENSOR_HXX_
#define __HEIGHT_SENSOR_HXX_

#include <BaseModel.hxx>
#include "height_sensor_interface.hxx"

class height_sensor_model : public BaseModel {
public:
    height_sensor_model();
    virtual ~height_sensor_model();

    bool config();
    bool init();
    bool step();
    bool pause();
    bool stop();

    uint32_t msg_get(BufferStruct id, SizeCallback cb);
    uint32_t msg_set(BufferStruct id, BufferStruct data);

    height_sensor intf;
};


extern "C" {
    BaseModel* create_model();
}

#endif
