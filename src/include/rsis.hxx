#ifndef __RSIS_HXX__
#define __RSIS_HXX__

#include "rsis_types.hxx"

extern "C" {

bool RSISFramework_Initialize();
bool RSISFramework_Shutdown();

RSISCmdStat RSISFramework_SetThread(int thread_id, double frequency);

bool RSISFramework_InitScheduler(bool block);
bool RSISFramework_PauseScheduler();
bool RSISFramework_RunScheduler(bool block);

enum RSISState RSISFramework_GetState();

RSISCmdStat RSISFramework_LoadLibrary(char* library, void* handle, void* creator_func);
RSISCmdStat RSISFramework_UnloadLibrary(char* library);
RSISCmdStat RSISFramework_CreateModel(char* lib, char* name);
RSISCmdStat RSISFramework_DestroyModel(char* name);

const char * RSISFramework_GetMessage();
RSISCmdStat RSISFramework_GetSchedulerName();

}
#endif
