# Model Interface
# Used for exposing models & generating C++ interface code

module MModel

export Model, Port, Callback
export listcallbacks, triggercallback

"""
Used to define a Port in a Model Interface file
"""
struct Port
    type::Type
    dimension::Tuple
    defaultvalue::Any
    units::String
    description::String

    function ModelPort(type, dimension, defaultvalue, units, description)
        if eltype(defaultvalue) != type
            error("Default value does not match type")
        end
        _size = size(defaultvalue)
        if length(dimension) != length(_size)
            error("Provided dimension, [$dimension], does not match: $defaultvalue")
        end
        for i = 1:length(dimension)
            if dimension[i] != _size[i]
                error("Provided dimension, [$dimension], does not match: $defaultvalue")
            end
        end
        new(type, dimension, defaultvalue, units, description)
    end
end

"""
Used to define a Port Pointer in a Model Interface file
"""
struct PortPointer
end

"""
"""
struct Callback
    name::String
end

"""
References instantiated model in the simulation framework
"""
mutable struct Model
    name::String
    in::Vector{Any}
    out::Vector{Any}
    data::Vector{Any}
    params::Vector{Any}

    callbacks::Vector{Callback}
end

"""
    listcallbacks(model::Model)
List all callbacks provided by model instance
```jldoctest
julia> listcallbacks(mymodel)
mymodel callbacks:
    > configModel
    > initModel
    > stepModel
    > destroyModel
    > step_1Hz
```
"""
function listcallbacks(model::Model)
    name = model.name
    println("$name callbacks:")
    for i in eachindex(model.callbacks)
        cb = model.callbacks[i].name
        println("    > $cb")
    end
end

"""
    triggercallback(model::Model, callback::String)
Trigger a specified callback in a model instance.
```jldoctest
julia> triggercallback(mymodel, "step_1Hz")
[mymodel.step_1Hz] executed successfully.
```
"""
function triggercallback(model::Model, callback::String)
    println("Not implemented")
end

end
