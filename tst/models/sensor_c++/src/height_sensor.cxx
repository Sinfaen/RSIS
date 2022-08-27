#include "height_sensor.hxx"
#include <iostream>

height_sensor_model::height_sensor_model() { }

height_sensor_model::~height_sensor_model() { }

ConfigStatus height_sensor_model::config() {
    if (intf.params.limits[1] < intf.params.limits[0]) {
        std::cout << "Limit range must be specified as [lower, upper]" << std::endl;
        return ConfigStatus::ERROR;
    }
    return ConfigStatus::OK;
}

RuntimeStatus height_sensor_model::init() {
    generator = std::mt19937(); // random seed
    dist = std::normal_distribution<double>(0.0, intf.params.noise);
    std::cout << "Created file: " << intf.params.stats_file << std::endl;
    switch (config()) {
        case ConfigStatus::OK:
        case ConfigStatus::INTERFACEUPDATE:
            return RuntimeStatus::OK;
        default:
            return RuntimeStatus::ERROR;
    }
}

RuntimeStatus height_sensor_model::step() {
    intf.data.measurement = dist(generator);
    intf.outputs.inrange = !(intf.data.measurement < intf.params.limits[0] ||
                             intf.data.measurement > intf.params.limits[1]);
    return RuntimeStatus::OK;
}

RuntimeStatus height_sensor_model::pause() {
    return RuntimeStatus::OK;
}

RuntimeStatus height_sensor_model::stop() {
    return RuntimeStatus::OK;
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
