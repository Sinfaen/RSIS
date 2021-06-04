
#include "ThreadHandler.hxx"

using namespace RSIS::Threading;

ThreadHandler::ThreadHandler() {
    //
}

ThreadHandler::~ThreadHandler() {
    //
}

/**
 * Add callback to execute on thread
 *
 * @param[in] cb Callback to execute
 * @returns Success/Failure status
 */
RSISCmdStat ThreadHandler::addCallback(Callback cb) {
    return RSISCmdStat::ERR;
}
