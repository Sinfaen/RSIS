#include "heightSensor_Model.hxx"

extern "C" {
BaseModel* CreateModel() {
    return new heightSensor_Model();
}

}
