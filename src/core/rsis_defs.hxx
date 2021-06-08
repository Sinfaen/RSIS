#ifndef __RSIS_DEFS_HXX__
#define __RSIS_DEFS_HXX__

#include <thread>
#include <mutex>
#include <condition_variable>
#include "rsis_types.hxx"
#include "BaseScheduler.hxx"
#include "Loader.hxx"

namespace RSIS {

class RSISFramework {
public:
    RSISFramework();
    virtual ~RSISFramework();

    // Static Functions
    static void Initialize();
    static void Shutdown();
    static bool IsAlive();
    static RSISFramework* Instance();

    bool InitScheduler(bool block = false);
    bool RunScheduler(bool block = false);
    RSISCmdStat LoadLibrary(char * library);
    RSISCmdStat UnloadLibrary(char * library);
    RSISCmdStat CreateModel(char* library, char* name);
private:
    static bool           __exists;
    static RSISFramework* __global;

    std::mutex runner_mutex;
    // Protects the following variables
    std::condition_variable runner_cv;
    RSISState state;
    RSISState commanded_state;
    bool trigger;
    std::thread runner;
    std::string message;

    void MainThread();
    void BeginThread();

    Scheduling::BaseScheduler* scheduler;
    Library::LibraryManager    library_manager;
};

}
#endif
