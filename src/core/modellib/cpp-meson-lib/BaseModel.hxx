
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

#include <cstdint>

struct BufferStruct {
    uint8_t* ptr;
    uint64_t size;
};

typedef uint8_t* (*SizeCallback)(uint64_t);

enum class ConfigStatus {
    OK,
    ERROR,
    INTERFACEUPDATE
};

enum class RuntimeStatus {
    OK,
    ERROR,
};

/**
 * Abstract base class for all C++ models that can be scheduled
 */
class BaseModel {
public:
    virtual ~BaseModel() = 0;

    virtual ConfigStatus  config() = 0;
    virtual RuntimeStatus init()   = 0;
    virtual RuntimeStatus step()   = 0;
    virtual RuntimeStatus pause()  = 0;
    virtual RuntimeStatus stop()   = 0;

    virtual uint32_t msg_get(BufferStruct id, SizeCallback cb) = 0;
    virtual uint32_t msg_set(BufferStruct id, BufferStruct data) = 0;
    virtual uint8_t* get_ptr(BufferStruct id) = 0;
};

void DeleteModel(BaseModel* obj);

extern "C" {
    bool c_ffi_interface(BaseModel* obj, void* ptrs[7]);
    uint32_t meta_get(void* ptr, BufferStruct id, SizeCallback cb);
    uint32_t meta_set(void* ptr, BufferStruct id, BufferStruct data);
    uint8_t* get_ptr(void* ptr, BufferStruct id);
}

#endif
