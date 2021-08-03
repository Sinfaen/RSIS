
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

RCB::RCB(DefineClass_t classdef, DefineMember_t membdef)
    : _class(classdef), _memb(membdef)
{ }

void RCB::NewClass(std::string name) {
    _class((char*) name.c_str());
}

void RCB::NewMember(std::string cl, std::string memb, std::string def, int32_t offset) {
    _memb((char*)cl.c_str(), (char*)memb.c_str(), (char*)def.c_str(), offset);
}
