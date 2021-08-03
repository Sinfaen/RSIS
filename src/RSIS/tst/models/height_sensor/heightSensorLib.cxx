#include <ModelRegistration.hxx>
#include "heightSensor_Model.hxx"

using namespace RSIS::Model;

extern "C" {
BaseModel* CreateModel() {
    return new heightSensor_Model();
}

void Reflect(void* _cb1, void* _cb2) {
    ReflectModels((DefineClass_t)_cb1, (DefineMember_t)_cb2);
}

}
