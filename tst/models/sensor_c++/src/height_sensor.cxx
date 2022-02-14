#include "height_sensor.hxx"

height_sensor_model::height_sensor_model() {
    //
}

height_sensor_model::~height_sensor_model() { }

bool height_sensor_model::config() {
    return true;
}

bool height_sensor_model::init() {
    return true;
}

bool height_sensor_model::step() {
    return true;
}

bool height_sensor_model::pause() {
    return true;
}

bool height_sensor_model::stop() {
    return true;
}

uint32_t height_sensor_model::msg_get(BufferStruct id, SizeCallback cb) {
    return handle_msg_get(intf, id, cb);
}
uint32_t height_sensor_model::msg_set(BufferStruct id, BufferStruct data) {
    return handle_msg_set(intf, id, data);
}
uint8_t* height_sensor_model::get_ptr(BufferStruct id) {
    return get_pointer(intf, id);
}

BaseModel* create_model() {
    return new height_sensor_model();
}
