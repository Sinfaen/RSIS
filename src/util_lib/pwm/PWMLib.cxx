
#include "PWM_Model.hxx"

extern "C" {

BaseModel* CreateModel() {
    return new PWM_Model();
}

}
