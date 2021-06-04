
#ifndef __CALLBACK_HXX__
#define __CALLBACK_HXX__

#include <functional>

#include "rsis_types.hxx"

namespace RSIS {
namespace Threading {

class Callback {
public:
    Callback(std::function<void()> func, int frequency, int frame_offset);
    virtual ~Callback();

    RSISCmdStat Invoke();
private:
    std::function<void()> cb;
    int frequency;
    int frame_offset;
};

}
}
#endif
