
#include <limits>
#include "TimeManager.hxx"

using namespace RSIS::Scheduling;

Time::Time()
    : step(0), epoch(0), time(0.0)
{ }

TimeManager::TimeManager()
    : frequency(1.0), delta(1.0), epoch_duration(std::numeric_limits<double>::infinity())
{ }

const Time& TimeManager::getTime() const {
    return time;
}

void TimeManager::setFrequency(double freq) {
    frequency = freq;
    delta     = 1 / frequency;
}

void TimeManager::setEpochDuration(double duration) {
    epoch_duration = duration;
}

void TimeManager::Increment() {
    time.step++;
    time.time = delta * time.step;
    if (time.time > epoch_duration) { // [[unlikely]]
        time.epoch++;
        time.time -= epoch_duration;
    }
}

void TimeManager::Reset() {
    time.step  = 0;
    time.time  = 0;
    time.epoch = 0;
}