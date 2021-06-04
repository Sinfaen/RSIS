#ifndef __BASE_SCHEDULER_HXX__
#define __BASE_SCHEDULER_HXX__

#include <string>

namespace RSIS {
namespace Scheduling {

class BaseScheduler {
public:
    virtual ~BaseScheduler() = default;

    virtual std::string getDescription() = 0;
protected:
};

}
}
#endif
