#ifndef __REGISTRATION_HXX__
#define __REGISTRATION_HXX__

#include <memory>
#include <unordered_map>

#include "rsis_types.hxx"
#include "ModelData.hxx"
#include "Loader.hxx"

namespace RSIS {
namespace Model {

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

}
}

#endif
