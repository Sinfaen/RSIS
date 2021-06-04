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

}
#endif
