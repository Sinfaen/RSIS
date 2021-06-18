
#include "Callback.hxx"

using namespace RSIS::Threading;

Callback::Callback(std::function<RSISCmdStat()> callback, double frequency, int frame_offset)
    : cb(callback), frequency(frequency), frame_offset(frame_offset)
{ }

Callback::~Callback() { }

double Callback::getFreq() {
    return frequency;
}

RSISCmdStat Callback::Invoke() {
    return cb();
}
