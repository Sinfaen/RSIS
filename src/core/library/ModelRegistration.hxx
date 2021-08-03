#ifndef __REGISTRATION_HXX__
#define __REGISTRATION_HXX__

#include <memory>
#include <unordered_map>
#include <cstdint>

#include "rsis_types.hxx"
#include "ModelData.hxx"
#include "Loader.hxx"

namespace RSIS {
namespace Model {


/**
 * Function pointer typedef for Julia function to define classes
 * @param[in] char* Class name
 */
typedef void (*DefineClass_t)(const char*);

/**
 * Function pointer typdef for Julia function to define members
 * @param[in] char* Class name
 * @param[in] char* Member name
 * @param[in] char* Full type definition
 * @param[in] int32 Byte offset
 */
typedef void (*DefineMember_t)(const char*, const char*, const char*, int32_t);

class ModelRegistration {
public:
    ModelRegistration();
    virtual ~ModelRegistration();

    RSISCmdStat CreateModel (const Library::LibraryManager& lib_mgr,
                                std::string library,
                                std::string name);
    RSISCmdStat DestroyModel(std::string name);
private:
    std::unordered_map<std::string, std::unique_ptr<ModelData> >       models;
    std::unordered_map<std::string, std::unique_ptr<ModelReflection> > reflection;
};

class RCB {
public:
    RCB(DefineClass_t classdef, DefineMember_t membdef);

    void NewClass(std::string name);
    void NewMember(std::string cl, std::string memb, std::string def, int32_t offset);
private:
    DefineClass_t _class;
    DefineMember_t _memb;
};

}
}

#endif
