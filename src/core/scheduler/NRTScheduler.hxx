#ifndef __NRT_SCHEDULER_HXX__
#define __NRT_SCHEDULER_HXX__

#include "BaseScheduler.hxx"

namespace RSIS {
namespace Scheduling {

class NRTScheduler : public BaseScheduler {
public:
    NRTScheduler();
    virtual ~NRTScheduler();

    std::string getDescription();
};

}
}
#endif
