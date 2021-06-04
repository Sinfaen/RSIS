
#include "Callback.hxx"

using namespace RSIS::Threading;

Callback::Callback(std::function<void()> callback, int frequency, int frame_offset)
    : cb(callback), frequency(frequency), frame_offset(frame_offset)
{ }

Callback::~Callback() { }

RSISCmdStat Callback::Invoke() {
    return RSISCmdStat::ERR;
}
