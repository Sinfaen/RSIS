
#include "ModelRegistration.hxx"

using namespace RSIS::Model;
using namespace RSIS::Library;

ModelRegistration::ModelRegistration() { }
ModelRegistration::~ModelRegistration() {
    // TODO
}

RSISCmdStat ModelRegistration::CreateModel(const LibraryManager& lib_mgr, std::string library, std::string name) {
    auto it = models.find(name);
    if (it == models.end()) {
        return RSISCmdStat::ERR;
    }
    std::weak_ptr<Library::LibraryPtr> symbols = lib_mgr.getModelSymbols(library);

    return RSISCmdStat::OK;
}

RSISCmdStat ModelRegistration::DestroyModel(std::string name) {
    auto it = models.find(name);
    if (it == models.end()) {
        return RSISCmdStat::ERR;
    }
    return RSISCmdStat::OK;
}
