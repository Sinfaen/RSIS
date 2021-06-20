#include "NRTScheduler.hxx"

using namespace RSIS::Scheduling;
using namespace RSIS::Threading;

NRTScheduler::NRTScheduler() {
    //
}

NRTScheduler::~NRTScheduler() {
    //
}

std::string NRTScheduler::getDescription() {
    return "Non Real-Time Scheduler.";
}

int NRTScheduler::createThreadHandler() {
    _handles.push_back(std::make_shared<ThreadHandler>());
    return _handles.size() - 1;
}

void NRTScheduler::dropThreads() {
    _handles.clear();
}

RSISCmdStat NRTScheduler::init() {
    return RSISCmdStat::OK;
}

const Time& NRTScheduler::getTime() const {
    return timeMgr.getTime();
}
