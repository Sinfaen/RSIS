#ifndef __BASE_SCHEDULER_HXX__
#define __BASE_SCHEDULER_HXX__

#include <string>

#include "TimeManager.hxx"

namespace RSIS {
namespace Scheduling {

class BaseScheduler {
public:
    virtual ~BaseScheduler() = default;

    virtual std::string getDescription() = 0;

    virtual int  createThreadHandler() = 0;
    virtual void dropThreads() = 0;

    virtual RSISCmdStat init() = 0;

    virtual const Time& getTime() const = 0;
};

}
}
#endif
