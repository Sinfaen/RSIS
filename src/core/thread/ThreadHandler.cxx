
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
RSISCmdStat ThreadHandler::addCallback(std::unique_ptr<Callback> cb) {
    if (cb.get()->getFreq() > frequency) {
        return RSISCmdStat::ERR;
    }
    _callbacks.push_back(std::move(cb));
    return RSISCmdStat::OK;
}

RSISCmdStat ThreadHandler::executeCallbacks() {
    for (auto it = _callbacks.begin(); it != _callbacks.end(); ++it) {
        if (RSISCmdStat::OK != it->get()->Invoke()) {
            return RSISCmdStat::ERR;
        }
    }
    return RSISCmdStat::OK;
}
