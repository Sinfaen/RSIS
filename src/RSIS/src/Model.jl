# Model Interface
# Used for exposing models & generating C++ interface code

module MModel

using DataStructures: first
export Model, Port, Callback
export listcallbacks, triggercallback
export generateinterface
export load, unload

using ..MScripting
using ..MLibrary
using ..MLogging
using ..Unitful

using DataStructures
using YAML

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
_type_defaults = Dict{String, Any}(
    "char"     =>   ' ',
    "int8_t"   =>     0,
    "int16_t"  =>     0,
    "int32_t"  =>     0,
    "int64_t"  =>     0,
    "uint8_t"  =>     0,
    "uint16_t" =>     0,
    "uint32_t" =>     0,
    "uint64_t" =>     0,
    "bool"     => false,
    "float"    =>     0,
    "double"   =>     0,
    "std::complex<float>"  => 0+0im,
    "std::complex<double>" => 0+0im
)

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
    load(library::String)
Load a shared library containing a model implementation
```jldoctest
julia> load("mymodel")
```
"""
function load(library::String) :: Nothing
    # Find library in search path, then pass absolute filepath
    # to core functionality
    locations = search(library)
    if length(locations) == 0
        throw(IOError("File not found: $(library)"))
    end

    if !LoadModelLib(library, locations[0])
        logmsg("Model library already loaded.", LOG)
    end
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


function createmodel(model::String)
    println("Not implemented")
    # call core::LoadModel
end

function connect(output::String, input::String)
    println("Not implemented")
end

"""
Helper function for generateinterface
Used to create model files from relevant information
"""
function pushtexttofile(directory::String, model::String, append::String, text::String)
    path = joinpath(directory, model * append)
    f_file = open(path, "w")

    write(f_file, "/* Autogenerated by RSIS Framework */\n")
    write(f_file, text)

    close(f_file)

    println("Generated: $path")
end

"""
Exception to be thrown when Model Interface is bad
"""
struct InterfaceException <: Exception
    file::String
    msg::String
end

Base.showerror(io::IO, e::InterfaceException) = print(io, "")

function grabClassDefinitions(data::OrderedDict{String,Any},
                              modelname::String,
                              order::Vector{String},
                              definitions::Dict{String, Vector{Tuple{String, Port}} })
    if !haskey(definitions, modelname)
        definitions[modelname] = Vector{Tuple{String,Port}}()
    end
    if !(modelname in keys(data))
        throw(ErrorException("Class definition: $(model) not found!"))
    end
    push!(order, modelname)
    model = data[modelname]
    for field in model
        if !isa(field.second, OrderedDict)
            throw(ErrorException("Non dictionary detected"))
        end
        _keys = keys(field.second)
        if "class" in _keys
            dims = []
            if "dims" in _keys
                dims = field.second["dims"]
            end
            if !isa(dims, Vector)
                throw(ErrorException("Dimension specified for composite $(field.first) is not a list"))
            end
            desc = ""
            if "desc" in _keys
                desc = field.second["desc"]
            end
            composite = Port(field.second["class"], Tuple(dims); note=desc, porttype=PORT)
            push!(definitions[modelname], (field.first, composite))
            grabClassDefinitions(data, field.second["class"], order, definitions)
        elseif "type" in _keys
            # this is a regular port
            dims = []
            if "dims" in _keys
                dims = field.second["dims"]
            end
            if !isa(dims, Vector)
                throw(ErrorException("Dimension specified for field $(field.first) is not a list"))
            end
            unit=nothing
            if "unit" in _keys
                u = field.second["unit"]
                try
                    unit = uparse(u)
                catch e
                    if isa(e, ArgumentError)
                        throw(ErrorException("Unit: $(u) for field $(field.first) is not defined"))
                    else
                        throw(e) # rethrow error
                    end
                end
            end
            initial = _type_defaults[field.second["type"]]
            if "value" in _keys
                initial = field.second["value"]
            end
            desc = ""
            if "desc" in _keys
                desc = field.second["desc"]
            end

            port = Port(field.second["type"], Tuple(dims), initial; units=unit, note=desc, porttype=PORT)
            push!(definitions[modelname], (field.first, port))
        else
            throw(ErrorException("Invalid model interface"))
        end
    end
end

"""
    generateinterface(interface::String)
Generate a C++ model interface from the specified interface file.
The generated files are put in the same location as the interface
file.
```jldoctest
julia> generateinterface("mymodel.yml")
Generated: mymodel_interface.hxx
Generated: mymodel_interface.cxx
Generation complete
```
"""
function generateinterface(interface::String)
    path_interface = search(interface)
    if length(path_interface) == 0
        throw(IOError("Unable to find interface file: $interface"))
    end

    data = YAML.load_file(path_interface[1], dicttype=OrderedDict{String,Any})
    if !("model" in keys(data))
        throw(ErrorException("The `model` element was not found. Aborting"))
    end

    # iterate through expected members, and grab data
    # recurse through each member
    class_order = Vector{String}()
    class_defs  = Dict{String, Vector{Tuple{String, Port}}}()
    grabClassDefinitions(data, data["model"], class_order, class_defs)

    base_dir   = dirname(path_interface[1])
    model_name = splitext(interface)[1]

    # create text
    hxx_text = "#include <cstdint>\n" *
               "#include <complex>\n" *
               "#include <BaseModel.hxx>\n\n"
    cxx_text = "#include \"$(model_name)_interface.hxx\"\n"
    global _type_map
    for i in length(class_order):-1:1
        name = class_order[i]
        fields = class_defs[class_order[i]]
        htext = "class $(name) {\n" *
                "public:\n" *
                "    $name();\n" *
                "    virtual ~$name();\n";
        ctext = "$name::$name()"
        if length(fields) != 0
            ctext = ctext * " : "
        end
        first = true;
        for (n,f) in fields
            htext = htext * "    " * f.type * " " * "$n" * "; // $(f.note) \n"
            if first
                first = false;
            else
                ctext = ctext * ", "
            end
            if f.iscomposite
                ctext = ctext * "$n()"
            else
                if length(f.dimension) == 0
                    ctext = ctext * "$n($(f.defaultvalue))"
                else
                    ctext = ctext * "$n{" * join([d for d in f.defaultvalue], ", ") *"}"
                end
            end
        end
        htext = htext * "};\n"
        ctext = ctext * "{ }\n$name::~$name() { }\n"
        hxx_text = hxx_text * htext;
        cxx_text = cxx_text * ctext;
    end

    hxx_text = hxx_text * "void Reflect_$(model_name)();\n"
    cxx_text = cxx_text * "void Reflect_$(model_name)() {\n}\n"

    # Model hxx file
    pushtexttofile(base_dir, model_name, "_interface.hxx", hxx_text)

    # Model cxx file
    pushtexttofile(base_dir, model_name, "_interface.cxx", cxx_text)

    println("Generation complete")
    return
end

end
