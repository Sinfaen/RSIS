
#ifndef __REFLECTION_HXX__
#define __REFLECTION_HXX__

#include <cstddef>
#include <functional>
#include <vector>

namespace RSIS {
namespace Reflection {

/*
Example Usage:

#include "RSIS/Reflection.hxx"
using RSIS::Reflection;

void Reflect_InStruct(cb_class, cb_field) {
    cb_class("InStruct");
    cb_field("matrix", "InStruct", "Int8", {3,3}, offsetof(InStruct, matrix), false);
    cb_field("orient", "InStruct", "Complex{Float64}", {}, offsetof(InStruct, orient), false);
}
void Reflect_MIn(cb_class, cb_field) {
    Reflect_InStruct(cb_class, cb_field);
    cb_class("ModelIn");
    cb_field("flag", "ModelIn", "Bool", {}, offsetof(ModelIn, flag), false);
    cb_field("data", "ModelIn", "InStruct", {2}, offsetof(ModelIn, data), false);
}
void MetaData(cb_class, cb_field) {
    Reflect_MIn(cb_class, cb_field);
    cb_class("Model");
    cb_field("in", "ModelIn", offsetof(Model, in));
}
*/

typedef std::function<void(char*)> RegisterClass;
typedef std::function<void(char*, char*, char*, std::vector<int>, size_t, bool)> RegisterField;

}
}

#endif
