
#include "Loader.hxx"

#include <dlfcn.h>

#ifdef WIN32

#endif

using namespace RSIS::Library;

LibraryPtr::LibraryPtr()
    : _handle(nullptr),
      _creator(nullptr)
{ }

LibraryPtr::~LibraryPtr() {
    Unload();
}

RSISCmdStat LibraryPtr::Load(const char * name) {
    _handle = dlopen(name, RTLD_NOW | RTLD_LAZY);
    if (!_handle) {
        return RSISCmdStat::ERR;
    }
    _creator = (CreateModel) dlsym(_handle, "createModel");
    return RSISCmdStat::OK;
}

RSISCmdStat LibraryPtr::Unload() {
    if (_handle == nullptr) {
        return RSISCmdStat::ERR;
    }
    if (dlclose(_handle) != 0) {
        return RSISCmdStat::ERR;
    }
    return RSISCmdStat::OK;
}

LibraryManager::LibraryManager() { }

LibraryManager::~LibraryManager() {
    for (auto& [key, ptr]: _modules) {
        if (RSISCmdStat::OK != ptr.get()->Unload()) {
            // TODO add error message
        }
    }
    _modules.clear();
}

RSISCmdStat LibraryManager::LoadLibrary(std::string name) {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        std::shared_ptr<LibraryPtr> lib = std::make_shared<LibraryPtr>();
        if (RSISCmdStat::OK != lib.get()->Load(name.c_str())) {
            return RSISCmdStat::ERR;
        }
        _modules[name] = lib;
    } else {
        // TODO add info message
    }
    return RSISCmdStat::OK;
}

RSISCmdStat LibraryManager::UnloadLibrary(std::string name) {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        return RSISCmdStat::ERR;
    }
    if (RSISCmdStat::OK != it->second.get()->Unload()) {
        return RSISCmdStat::ERR;
    }
    _modules.erase(it);
    return RSISCmdStat::OK;
}

std::weak_ptr<LibraryPtr> LibraryManager::getModelSymbols(std::string name) {
    auto it = _modules.find(name);
    if (it == _modules.end()) {
        return std::weak_ptr<LibraryPtr>();
    }
    return it->second;
}
