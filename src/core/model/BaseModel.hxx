
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

#include <string>

namespace RSIS {
namespace Scheduling {

class BaseModel {
public:
    virtual ~BaseModel() = default;

    virtual bool config() = 0;
    virtual bool init()   = 0;
    virtual bool pause()  = 0;
    virtual bool step()   = 0;
    virtual bool stop()   = 0;

private:
};
}
}
#endif
