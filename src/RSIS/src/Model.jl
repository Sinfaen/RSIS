# Model Interface
# Used for exposing models

module MModel

using DataStructures: first
export Model, Port, Callback
export PORT, PORTPTR, PORTPTRI
export listcallbacks, triggercallback
export load, unload, listavailable

using ..MScripting
using ..MLibrary
using ..MLogging
using ..MProject
using ..Unitful

# globals
_type_map = Dict{String, DataType}(
    "char"     =>   Char,
    "int8_t"   =>   Int8,
    "int16_t"  =>  Int16,
    "int32_t"  =>  Int32,
    "int64_t"  =>  Int64,
    "uint8_t"  =>  UInt8,
    "uint16_t" => UInt16,
    "uint32_t" => UInt32,
    "uint64_t" => UInt64,
    "bool"     =>   Bool,
    "float"    => Float32,
    "double"   => Float64,
    "std::complex<float>"  => Complex{Float32},
    "std::complex<double>" => Complex{Float64}
)

_additional_lib_paths = Vector{String}()

@enum PortType PORT=1 PORTPTR=2 PORTPTRI=3

"""
Defines a Port in a Model Interface file
"""
struct Port
    type::String
    dimension::Tuple
    defaultvalue::Any
    units::Any
    note::String
    porttype::PortType
    iscomposite::Bool

    # primitive type definition
    function Port(type::String, dimension::Tuple, defaultvalue::Any; units::Any=nothing, note::String="", porttype::PortType=PORT)
        if !(type in keys(_type_map))
            throw(ArgumentError("Provided type: $type is not supported"))
        end
        if !(eltype(defaultvalue) <: _type_map[type])
            throw(ArgumentError("Provided type: $type is not the same or a supertype of default value: $(eltype(defaultvalue))"))
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
        new(type, dimension, defaultvalue, units, note, porttype, false)
    end

    # composite definition
    function Port(type::String, dimension::Tuple; note::String="", porttype::PortType=PORT)
        # don't check type, must be done elsewhere
        new(type, dimension, nothing, nothing, note, porttype, true)
    end
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
julia> mymodel = createmodel("MyModel", "mymodel", group="test")
julia> listcallbacks(mymodel)
mymodel (MyModel) callbacks:
    > stepModel
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

"""
    listavailable()
Returns a list of model libraries that can be loaded with
`load`. The project build directory is recursively searched
for shared libraries; file extension set by OS. Additional
library search paths can be set with `addlibpath`.
```
julia> listavailable()
3-element Vector{String}:
 fsw_hr_model
 fsw_lr_model
 gravity_model
```
"""
function listavailable() :: Vector{String}
    all = Vector{String}()
    if !isprojectloaded()
        logmsg("Load a project to see available libraries.", LOG)
    else
        bdir = getprojectbuilddirectory()
        file_ext = _libraryextension()
        if isdir(bdir)
            for (root, dirs, files) in walkdir(bdir)
                for file in files
                    fe = splitext(file)
                    if fe[2] == file_ext && startswith(fe[1], "lib")
                        push!(all, fe[1][4:end])
                    end
                end
            end
            # check additional paths
            for path in _additional_lib_paths
                #
            end
        else
            logmsg("Project build directory does not exist", ERROR)
        end
    end
    return all
end

"""
    load(library::String; namespace::String="")
Load a shared library containing a model implementation.
If a namespace is defined, any reflection data defined during
the load process is defined within that namespace, allowing
for multiple models to define classes with the same name.
```jldoctest
julia> load("mymodel")
julia> load("anothermodel"; namespace="TEST")
```
"""
function load(library::String; namespace::String="") :: Nothing
    # Find library in search path, then pass absolute filepath
    # to core functionality
    filename = "lib$(library)$(_libraryextension())"
    if !isprojectloaded()
        logmsg("Load a project to see available libraries.", ERROR)
        return
    end
    bdir = getprojectbuilddirectory()
    if isdir(bdir)
        for (root, dirs, files) in walkdir(bdir)
            for file in files
                if file == filename
                    # load library
                    if !LoadModelLib(library, joinpath(root, file), namespace)
                        logmsg("Model library alread loaded.", LOG)
                    end
                    return
                end
            end
        end
    else
        logmsg("Project build directory does not exist", ERROR)
    end
    throw(ErrorException("File not found: $(library) [$(filename)]"))
end

"""
    unload(library::String)
Unload a shared library containing a model implementation
```jldoctest
julia> load("mymodel")
julia> unload("mymodel")
julia> unload("mymodel")
Model library not previously loaded.
```
"""
function unload(library::String) :: Nothing
    if !UnloadModelLib(library)
        logmsg("Model library not previously loaded.", WARNING)
    end
end

function connect(output::String, input::String)
    println("Not implemented")
end

end
