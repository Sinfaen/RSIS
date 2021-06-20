
#ifndef __BASE_MODEL_HXX__
#define __BASE_MODEL_HXX__

#include <string>
#include "rsis_types.hxx"

namespace RSIS {
namespace Scheduling {

class BaseModel {
public:
    virtual ~BaseModel() = default;

    virtual std::string getDescription() = 0;

    virtual RSISCmdStat configModel()  = 0;
    virtual RSISCmdStat initModel()    = 0;
    virtual RSISCmdStat stepModel()    = 0;
    virtual RSISCmdStat destroyModel() = 0;

    virtual void reflect() = 0;
private:
};
}
}
#endif
