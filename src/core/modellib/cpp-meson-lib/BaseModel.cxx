
#include <string>
#include "BaseModel.hxx"

BaseModel::~BaseModel() {
    // nothing to do here
}

void DeleteModel(BaseModel* obj) {
    delete obj;
}

uint32_t run_config(BaseModel* obj) {
    return static_cast<uint32_t>(obj->config());
}

uint32_t run_init(BaseModel* obj) {
    return static_cast<uint32_t>(obj->init());
}

uint32_t run_step(BaseModel* obj) {
    return static_cast<uint32_t>(obj->step());
}

uint32_t run_pause(BaseModel* obj) {
    return static_cast<uint32_t>(obj->pause());
}

uint32_t run_stop(BaseModel* obj) {
    return static_cast<uint32_t>(obj->stop());
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

uint32_t meta_get(void* ptr, BufferStruct id, SizeCallback cb) {
    BaseModel* app = (BaseModel*) ptr;
    return app->msg_get(id, cb);
}

uint32_t meta_set(void* ptr, BufferStruct id, BufferStruct data) {
    BaseModel* app = (BaseModel*) ptr;
    return app->msg_set(id, data);
}

uint8_t* get_ptr(void* ptr, BufferStruct id) {
    BaseModel* app = (BaseModel*) ptr;
    return app->get_ptr(id);
}
