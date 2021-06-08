
#include "rsis_defs.hxx"

#include "NRTScheduler.hxx"
#include <iostream>

using namespace RSIS;

bool           RSISFramework::__exists = false;
RSISFramework* RSISFramework::__global = nullptr;

/**
 * Default Constructor
 */
RSISFramework::RSISFramework()
    : state(RSISState::NOSTATE),
      commanded_state(RSISState::NOSTATE),
      trigger(false),
      scheduler(new Scheduling::NRTScheduler())
{
    //
}

RSISFramework::~RSISFramework() {
    //
}

void RSISFramework::Initialize() {
    __global = new RSISFramework();
    if (nullptr != __global) {
        __exists = true;
    }
}

void RSISFramework::Shutdown() {
    if (__exists) {
        delete __global;
        __exists = false;
        __global = nullptr;
    }
}

bool RSISFramework::IsAlive() {
    return __exists;
}

RSISFramework* RSISFramework::Instance() {
    return __global;
}

/**
 * Trigger initialization in the runner thread
 * 
 * @param[in] block Block execution until initilization is done
 */
bool RSISFramework::InitScheduler(bool block) {
    BeginThread();
    {
        std::lock_guard<std::mutex> lk(runner_mutex);
        trigger = true;
        commanded_state = RSISState::INIT;
    }
    runner_cv.notify_one();
    trigger = false;

    if (block) {
        std::unique_lock<std::mutex> lk (runner_mutex);
        // wait for runner to complete initialization
        runner_cv.wait(lk, [this] { return this->state != RSISState::INIT; });
    }
    runner_cv.notify_one();

    return scheduler != nullptr;
}

bool RSISFramework::RunScheduler(bool block) {
    // TODO TEMPORARY IMPLEMENTATION
    return scheduler != nullptr;
}

void RSISFramework::MainThread() {
    {
        std::unique_lock<std::mutex> lk (runner_mutex);
        state = RSISState::CONFIG;
        // wait for init call
        runner_cv.wait(lk, [this] { return this->trigger; });
        // immediately let go of the mutex
    }
    runner_cv.notify_one();

    // begin initialization of the models
    // scheduler->init
    // Check for halt signal

    // Initialization done, notify owner
    {
        std::unique_lock<std::mutex> lk (runner_mutex);
        state = RSISState::READY;
        message = "Initialization completed successfully";

        // wait for run trigger
        runner_cv.wait(lk, [this] { return this->trigger; });
        
        // if the user wants to end the simulation, do so now
        if (RSISState::END == commanded_state) {
            lk.unlock();
            runner_cv.notify_one();
            return;
        }
        // otherwise, beging running
        state = RSISState::RUN;
    }
    runner_cv.notify_one();

    // run the simulation
    // scheduler->run

    // Check for pause or halt signal

    // Simulation done, notify owner
    {
        std::lock_guard<std::mutex> lk {runner_mutex};
        state = RSISState::END;
        message = "Simulation run completed";
    }
    runner_cv.notify_one();
}

/**
 * Start runner thread
 */
void RSISFramework::BeginThread() {
    runner = std::thread([this] { this->MainThread(); });
}

RSISCmdStat RSISFramework::LoadLibrary(char* library) {
    return library_manager.LoadLibrary(library);
}

RSISCmdStat RSISFramework::UnloadLibrary(char * library) {
    return library_manager.UnloadLibrary(library);
}
