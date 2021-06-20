#ifndef __NRT_SCHEDULER_HXX__
#define __NRT_SCHEDULER_HXX__

#include <vector>
#include <memory>
#include "ThreadHandler.hxx"
#include "BaseScheduler.hxx"

namespace RSIS {
namespace Scheduling {

class NRTScheduler : public BaseScheduler {
public:
    NRTScheduler();
    virtual ~NRTScheduler();

    std::string getDescription();

    int  createThreadHandler();
    void dropThreads();

    RSISCmdStat init();
    const Time& getTime() const;
protected:
    std::vector<std::shared_ptr<Threading::ThreadHandler> > _handles;
    TimeManager timeMgr;
};

}
}
#endif
