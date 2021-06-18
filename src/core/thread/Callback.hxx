
#ifndef __CALLBACK_HXX__
#define __CALLBACK_HXX__

#include <functional>

#include "rsis_types.hxx"

namespace RSIS {
namespace Threading {

class Callback {
public:
    Callback(std::function<RSISCmdStat()> func, double frequency, int frame_offset);
    virtual ~Callback();

    RSISCmdStat Invoke();

    double getFreq();
private:
    std::function<RSISCmdStat()> cb;
    double frequency;
    int frame_offset;
};

}
}
#endif
