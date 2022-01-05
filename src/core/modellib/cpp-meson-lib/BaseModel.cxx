
#include "BaseModel.hxx"

BaseModel::~BaseModel() {
    // nothing to do here
}

void DeleteModel(BaseModel* obj) {
    delete obj;
}
