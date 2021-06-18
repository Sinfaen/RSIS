#ifndef __LOADER_HXX__
#define __LOADER_HXX__

#include <vector>
#include <string>
#include <map>
#include <memory>

#include "rsis_types.hxx"
#include "BaseModel.hxx"

namespace RSIS {
namespace Library {

typedef Scheduling::BaseModel* (*CreateModel)(char *);

struct LibraryPtr {
    void *      _handle;
    CreateModel _creator;
};

class LibraryManager {
public:
    LibraryManager();
    virtual ~LibraryManager();

    RSISCmdStat LoadLibrary(std::string name, std::shared_ptr<LibraryPtr> lib);
    RSISCmdStat UnloadLibrary(std::string name);

    std::weak_ptr<LibraryPtr> getModelSymbols(std::string name) const;
private:
    std::map<std::string, std::shared_ptr<LibraryPtr> > _modules;
};

}
}
#endif
