
#ifndef __TIME_MANAGER_HXX__
#define __TIME_MANAGER_HXX__

#include <cstdint>

namespace RSIS {
namespace Scheduling {

struct Time {
    Time();
    int64_t step;
    int64_t epoch;
    double  time;
};

class TimeManager {
public:
    TimeManager();
    virtual ~TimeManager() = default;

    const Time& getTime() const;

    void setFrequency(double freq);
    void setEpochDuration(double duration);

    void Increment();
    void Reset();
protected:
    Time    time;
    double  frequency;
    double  delta;
    double  epoch_duration;
};

}
}
#endif
