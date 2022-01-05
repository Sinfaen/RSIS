#include "height_sensor.hxx"

height_sensor::height_sensor() {
    //
}

height_sensor::~height_sensor() { }

bool height_sensor::config() {
    return true;
}

bool height_sensor::init() {
    return true;
}

bool height_sensor::step() {
    return true;
}

bool height_sensor::pause() {
    return true;
}

bool height_sensor::stop() {
    return true;
}

extern "C" {
BaseModel* CreateModel() {
    return new height_sensor();
}

void Reflect(void* _cb1, void* _cb2) {
    ReflectModels((ReflectClass)_cb1, (ReflectMember)_cb2);
}

}
