
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

#include <cstdint>

struct BufferStruct {
    uint8_t* ptr;
    uint64_t size;
};

typedef uint8_t* (*SizeCallback)(uint64_t);

/**
 * Abstract base class for all C++ models that can be scheduled
 */
class BaseModel {
public:
    virtual ~BaseModel() = 0;

    virtual bool config() = 0;
    virtual bool init()   = 0;
    virtual bool step()   = 0;
    virtual bool pause()  = 0;
    virtual bool stop()   = 0;

    virtual uint32_t msg_get(BufferStruct id, SizeCallback cb) = 0;
    virtual uint32_t msg_set(BufferStruct id, BufferStruct data) = 0;
};

void DeleteModel(BaseModel* obj);

extern "C" {
    bool c_ffi_interface(BaseModel* obj, void* ptrs[7]);
    uint32_t meta_get(void* ptr, BufferStruct id, SizeCallback cb);
    uint32_t meta_set(void* ptr, BufferStruct id, BufferStruct data);
}

#endif
