
#include <iostream>
#include "rsis.hxx"
#include "rsis_defs.hxx"

using namespace RSIS;

extern "C" {

/**
 * Initialize the RSiS Framework
 * 
 * @returns True if initialization was successful.
 */
bool RSISFramework_Initialize() {
    RSISFramework::Initialize();
    return RSISFramework::IsAlive();
}

/**
 * Shuts down the RSiS Framework
 * 
 * @returns True if framework successfully shut off.
 */
bool RSISFramework_Shutdown() {
    RSISFramework::Shutdown();
    return !RSISFramework::IsAlive();
}

/**
 * Trigger the Init process of the simulation
 *
 * @param[in] block Block until initialization is done
 * @returns Initialization trigger success
 */
bool RSISFramework_InitScheduler(bool block) {
    if (!RSISFramework::IsAlive()) {
        return false;
    }
    return RSISFramework::Instance()->InitScheduler(block);
}

/**
 * Trigger the Run process of the simulation
 * 
 * @param[in] block Block until simulation is done
 * @returns Run trigger success
 */
bool RSISFramework_RunScheduler(bool block) {
    if (!RSISFramework::IsAlive()) {
        return false;
    }
    return RSISFramework::Instance()->RunScheduler(block);
}

/**
 * Get current state of RSIS simulation
 * 
 * @returns Current state of simulation
 */
enum RSISState RSISFramework_GetState() {
    if (!RSISFramework::IsAlive()) {
        return RSISState::NOSTATE;
    }
    return RSISState::CONFIG;
}

} // extern C
