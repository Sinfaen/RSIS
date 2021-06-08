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
    LibraryPtr();
    ~LibraryPtr();

    RSISCmdStat Load(const char * name);
    RSISCmdStat Unload();

    void *      _handle;
    CreateModel _creator;
};

class LibraryManager {
public:
    LibraryManager();
    virtual ~LibraryManager();

    RSISCmdStat LoadLibrary(std::string path);
    RSISCmdStat UnloadLibrary(std::string path);

    std::weak_ptr<LibraryPtr> getModelSymbols(std::string name);
private:
    std::map<std::string, std::shared_ptr<LibraryPtr> > _modules;
};

}
}
#endif
