#ifndef __RSIS_DEFS_HXX__
#define __RSIS_DEFS_HXX__

#include <memory>
#include <thread>
#include <mutex>
#include <condition_variable>
#include "rsis_types.hxx"
#include "BaseScheduler.hxx"
#include "Loader.hxx"
#include "ModelRegistration.hxx"

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
    RSISCmdStat LoadLibrary(char * library,
                            void * handle,
                            void * creator_func);
    RSISCmdStat UnloadLibrary(char * library);
    RSISCmdStat CreateModel(char* library, char* name);
    RSISCmdStat DestroyModel(char* name);

    const char * GetMessagePtr();
    void GetSchedulerName();
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

    std::unique_ptr<Scheduling::BaseScheduler> scheduler;
    Library::LibraryManager    library_manager;
    Model::ModelRegistration   model_registration;
};

}
#endif
