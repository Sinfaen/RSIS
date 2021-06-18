
#ifndef __THREAD_HANDLER_HXX__
#define __THREAD_HANDLER_HXX__

#include <thread>
#include <vector>
#include <memory>

#include "rsis_types.hxx"
#include "Callback.hxx"

namespace RSIS {
namespace Threading {

class ThreadHandler {
public:
    ThreadHandler();
    virtual ~ThreadHandler();

    RSISCmdStat addCallback(std::unique_ptr<Callback> cb);

    RSISCmdStat executeCallbacks();
private:
    std::thread _thread;
    std::vector<std::unique_ptr<Callback> > _callbacks;

    double frequency;
};
}
}
#endif
