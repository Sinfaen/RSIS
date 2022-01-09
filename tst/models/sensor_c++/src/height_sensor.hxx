#ifndef __HEIGHT_SENSOR_HXX_
#define __HEIGHT_SENSOR_HXX_

#include "height_sensor_interface.hxx"

class height_sensor : public BaseModel {
public:
    height_sensor();
    virtual ~height_sensor();

    bool config();
    bool init();
    bool step();
    bool pause();
    bool stop();

    height_sensor_in inputs; //  
    height_sensor_out outputs; //  
    height_sensor_data data; //  
    height_sensor_params params; //  
};

#endif
