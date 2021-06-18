
#include "Loader.hxx"

using namespace RSIS::Library;

LibraryManager::LibraryManager() { }

LibraryManager::~LibraryManager() { }

RSISCmdStat LibraryManager::LoadLibrary(std::string name, std::shared_ptr<LibraryPtr> lib) {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        _modules[name] = lib;
    } else {
        // TODO add info message
        return RSISCmdStat::ERR;
    }
    return RSISCmdStat::OK;
}

RSISCmdStat LibraryManager::UnloadLibrary(std::string name) {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        return RSISCmdStat::ERR;
    }
    _modules.erase(it);
    return RSISCmdStat::OK;
}

std::weak_ptr<LibraryPtr> LibraryManager::getModelSymbols(std::string name) const {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        return std::weak_ptr<LibraryPtr>(); // null value
    }
    return it->second;
}
