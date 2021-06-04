
#ifndef __THREAD_HANDLER_HXX__
#define __THREAD_HANDLER_HXX__

#include <thread>
#include <vector>

#include "rsis_types.hxx"
#include "Callback.hxx"

namespace RSIS {
namespace Threading {

class ThreadHandler {
public:
    ThreadHandler();
    virtual ~ThreadHandler();

    RSISCmdStat addCallback(Callback cb);
private:
    std::thread _thread;
    std::vector<Callback> _callbacks;

    double frequency;
};
}
}
#endif
