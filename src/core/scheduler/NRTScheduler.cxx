#include "NRTScheduler.hxx"

using namespace RSIS::Scheduling;

NRTScheduler::NRTScheduler() {
    //
}

NRTScheduler::~NRTScheduler() {
    //
}

std::string NRTScheduler::getDescription() {
    return "Non Real-Time Scheduler.";
}
