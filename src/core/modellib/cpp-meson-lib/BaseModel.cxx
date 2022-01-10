
#include <string>
#include "BaseModel.hxx"

BaseModel::~BaseModel() {
    // nothing to do here
}

void DeleteModel(BaseModel* obj) {
    delete obj;
}

bool run_config(BaseModel* obj) {
    return obj->config();
}

bool run_init(BaseModel* obj) {
    return obj->init();
}

bool run_step(BaseModel* obj) {
    return obj->step();
}

bool run_pause(BaseModel* obj) {
    return obj->pause();
}

bool run_stop(BaseModel* obj) {
    return obj->stop();
}

bool c_ffi_interface(BaseModel* obj, void* ptrs[7]) {
    if (obj == nullptr) {
        return false;
    }
    ptrs[0] = (void*) &run_init;
    ptrs[1] = (void*) &run_config;
    ptrs[3] = (void*) &run_step;
    ptrs[4] = (void*) &run_pause;
    ptrs[5] = (void*) &run_stop;
    ptrs[6] = (void*) &DeleteModel;
    return true;
}

UTF8Data get_utf8_string(void* ptr) {
    UTF8Data data;
    std::string* sobj = (std::string*) ptr;
    data.ptr  = (void*) sobj->c_str();
    data.size = sobj->size();
    return data;
}

uint32_t set_utf8_string(void* ptr, UTF8Data data) {
    std::string* sobj = (std::string*) ptr;
    *sobj = std::string((const char*) data.ptr, data.size);
    return 0;
}
