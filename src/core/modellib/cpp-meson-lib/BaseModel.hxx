
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

#include <cstddef>

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
};

void DeleteModel(BaseModel* obj);

typedef void (*ReflectClass)(const char*);
typedef void (*ReflectMember)(const char*, const char*, const char*, unsigned int, const char*);

template<typename T, typename U> size_t _offsetof(U T::*member) {
    return (char*)&((T*)nullptr->*member) - (char*)nullptr;
}

struct UTF8Data {
    void*    ptr;
    uint64_t size;
};

extern "C" {
    bool     c_ffi_interface(BaseModel* obj, void* ptrs[7]);
    UTF8Data get_utf8_string(void* ptr);
    uint32_t set_utf8_string(void* ptr, UTF8Data data);
}

#endif
