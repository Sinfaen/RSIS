
#ifndef __MODEL_DATA_HXX__
#define __MODEL_DATA_HXX__

#include <memory>
#include <string>
#include <vector>

#include "BaseModel.hxx"

namespace RSIS {
namespace Model {

struct ReflectField {
    ReflectField();
    virtual ~ReflectField();

    std::string      name;
    std::vector<int> dimensions;
    size_t           offset;
    std::string      units;
    std::string      description;
};

struct ReflectClass {
    ReflectClass();
    virtual ~ReflectClass();

    std::vector<ReflectField> fields;
};

struct ModelReflection {
    ModelReflection();
    virtual ~ModelReflection();

    ReflectClass in;
    ReflectClass out;
    ReflectClass data;
    ReflectClass params;
};

class ModelData {
public:
    ModelData();
    virtual ~ModelData();

private:
    std::unique_ptr<Scheduling::BaseModel> obj;
    std::weak_ptr<ModelReflection>         reflection_data;
};

}
}

#endif
