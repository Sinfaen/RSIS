
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

namespace RSIS {
namespace Scheduling {

class BaseModel {
public:
    virtual ~BaseModel() = default;

    virtual void configModel()  = 0;
    virtual void initModel()    = 0;
    virtual void stepModel()    = 0;
    virtual void destroyModel() = 0;
private:
};
}
}
#endif
