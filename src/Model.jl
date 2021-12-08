# Model Interface
# Used for exposing models

module MModel

using Base: julia_cmd, julia_exename
using DataStructures: first
export Port, Callback
export PORT, PORTPTR, PORTPTRI
export listcallbacks, triggercallback
export load, unload, listavailable
export structnames, structdefinition
export convert_julia_type
export connect

using ..DataStructures
using ..MScripting
using ..MLibrary
using ..MLogging
using ..MProject
using ..Unitful

## globals
# DataType => [Rust datatype, C++ datatype]
_type_conversions = Dict{DataType, Vector{String}}(
    Char    => ["char", "char"],
    String  => ["String", "std::string"],
    Int8    => ["i8",   "int8_t"],
    Int16   => ["i16",  "int16_t"],
    Int32   => ["i32",  "int32_t"],
    Int64   => ["i64",  "int64_t"],
    UInt8   => ["u8",   "uint8_t"],
    UInt16  => ["u16",  "uint16_t"],
    UInt32  => ["u32",  "uint32_t"],
    UInt64  => ["u64",  "uint64_t"],
    Bool    => ["bool", "bool"],
    Float32 => ["f32",  "float"],
    Float64 => ["f64",  "double"],
    # Requires lines: ["use num_complex::Complex;", "#include <complex>"]
    Complex{Float32} => ["Complex<f32>", "std::complex<float>"],
    Complex{Float64} => ["Complex<f64>", "std::complex<double>"]
)

# Create a string -> DataType mapping for all supported datatypes
_type_map = Dict([Pair("$(_type)", _type) for _type in keys(_type_conversions)])


# Additional library paths to search
_additional_lib_paths = Vector{String}()

@enum PortType PORT=1 PORTPTR=2 PORTPTRI=3

"""
Defines a Port in a Model Interface file
"""
struct Port
    type::String
    dimension::Tuple
    units::Any
    iscomposite::Bool
    note::String
    porttype::PortType
    defaultvalue::Any

    function Port(type::String, dimension::Tuple, units::Any, composite::Bool=false; note::String="", porttype::PortType=PORT, default=nothing)
        if !composite
            if !(type in keys(_type_map))
                throw(ArgumentError("Primitive type: $type is not supported"))
            end
            if !isnothing(default)
                if typeof(default) == String
                    if _type_map[type] != String
                        throw(ArgumentError("Default value: $(default) is type $(typeof(default)), not $(type)"))
                    end
                else
                    if !(eltype(default) <: _type_map[type])
                        throw(ArgumentError("Default value: $(default) is type $(eltype(default)), not $(type)"))
                    end
                    if size(default) != dimension
                        throw(ArgumentError("Size of default value: $(value) does not match dimension $(dimension)"))
                    end
                end
            end
        end
        new(type, dimension, units, composite, note, porttype, default)
    end
end

mutable struct ClassData
    fields::OrderedDict{String, Tuple{Port, UInt}}
end
ClassData() = ClassData(OrderedDict{String, Tuple{Port, UInt}}())

mutable struct LibraryData
    structs::OrderedDict{String, ClassData}
    last::String # last is not defined for structs, so use this keepsake
end
LibraryData() = LibraryData(OrderedDict{String, ClassData}(), "")

_classdefinitions = Dict{String, LibraryData}()
_cur_class = "" # current class being defined

# Connection struct + globals
struct Location
    model :: ModelReference
    port  :: String
    # idx
end
mutable struct Connections
    output :: Dict{String, Set{Location}}
    input  :: Dict{String, Location}
end
_connections = Dict{ModelReference, Connections}()
function _ensureconnection(model::ModelReference)
    if !(model in keys(_connections))
        _connections[model] = Connections(Dict{String, Set{Location}}(), Dict{String, Location}())
    end
end


function _CreateClass(name::Ptr{UInt8}) :: Nothing
    cl = unsafe_string(name)
    _data = _classdefinitions[_cur_class]
    if cl in keys(_data.structs)
        logmsg("Class: $(cl) redefined.", WARNING)
    end
    _data.structs[cl] = ClassData()
    _data.last = cl # workaround
    return
end

function _CreateMember(cl::Ptr{UInt8}, memb::Ptr{UInt8}, def::Ptr{UInt8}, offset::UInt) :: Nothing
    classname = unsafe_string(cl)
    member    = unsafe_string(memb)
    definition = unsafe_string(def)
    _data = _classdefinitions[_cur_class]
    if !(classname in keys(_data.structs))
        logmsg("Class: $(classname) for member: $(member) does not exist. Creating default.", WARNING)
        _data.structs[classname] = ClassData()
    end
    # parse definition passed as a string
    if occursin("[", definition) # array detection
        tt = split(definition[2:end-1], ";")
        dims = []
        for token in split(tt[2], ",")
            val = tryparse(Int, token)
            if isnothing(val)
                logmsg("Unable to parse: $(token) as a dimension", ERROR)
                val = -1
            end
            push!(dims, val)
        end
        _data.structs[classname].fields[member] = (Port(String(tt[1]), Tuple(dims), "", !(String(tt[1]) in keys(_type_map))), offset)
    else
        _data.structs[classname].fields[member] = (Port(definition, (), "", !(definition in keys(_type_map))), offset)
    end
    return
end

function GetClassData(name::String, namespace::String = "") :: Nothing
    if name in keys(_classdefinitions)
        throw(ErrorException("Library $(name) already loaded."))
    end
    global _cur_class
    _cur_class = name
    _classdefinitions[_cur_class] = LibraryData()
    GetModelData(name, namespace,
        @cfunction(_CreateClass, Cvoid, (Ptr{UInt8},)),
        @cfunction(_CreateMember, Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}, UInt)))
    _cur_class = ""
    return
end

"""
    structnames(library::String)
Returns a vector of all defined structs for a library that are
reflected via the shared library API.
```jldoctest
julia> structnames("cubesat")
5-element Vector{String}:
 cubesat_inputs
 cubesat_outputs
 cubesat_data
 cubesat_params
 cubesat
```
"""
function structnames(library::String) :: Vector{String}
    return collect(keys(_classdefinitions[library].structs))
end

"""
    structdefinition(library::String, name::String)
Returns a vector of all defined fields for a class defined in a library.
```jldoctest
julia> structdefinition("cubesat", "cubesat_params")
1-element Vector{Tuple{String, String, UInt64}}:
 ("signal", "Float64", 0x0000000000000000)
```
"""
function structdefinition(library::String, name::String) :: Vector{Tuple{String, String, String, UInt}}
    data = _classdefinitions[library]
    if name in keys(data.structs)
        fields = Vector{Tuple{String, String, String, UInt}}()
        for (_name, field) in data.structs[name].fields
            push!(fields, (_name, field[1].type, field[1].units, field[2]))
        end
        return fields
    else
        throw(ArgumentError("$(name) not defined!"))
    end
end

"""
    listavailable(;fullpath::Bool = false)
Returns a list of model libraries that can be loaded with
`load`. The project build directory is recursively searched
for shared libraries; file extension set by OS. Additional
library search paths can be set with `addlibpath`. If the
`fullPath` argument is `true`, the absolute filename is
returned instead.
```
julia> listavailable()
3-element Vector{String}:
 fsw_hr_model
 fsw_lr_model
 gravity_model
julia> listavailable(fullpath = true)
3-element Vector{String}:
 /home/foo/target/release/libfsw_hr_model.dylib
 /home/foo/target/release/libfsw_lr_model.dylib
 /home/foo/target/release/libgravity_model.dylib
```
"""
function listavailable(;fullpath::Bool = false) :: Vector{String}
    all = Vector{String}()
    if !isprojectloaded()
        logmsg("Load a project to see available libraries.", LOG)
    else
        bdir = getprojectbuilddirectory()
        file_ext = _libraryextension()
        file_prefix = _libraryprefix()
        if isdir(bdir)
            if projecttype() == "Rust"
                for file in readdir(bdir)
                    fe = splitext(file)
                    if fe[2] == file_ext && startswith(fe[1], file_prefix)
                        if fullpath
                            push!(all, abspath(bdir, file))
                        else
                            push!(all, fe[1][1+length(file_prefix):end])
                        end
                    end
                end
            else # C++
                for (root, dirs, files) in walkdir(bdir)
                    for file in files
                        fe = splitext(file)
                        if fe[2] == file_ext && startswith(fe[1], file_prefix)
                            if fullpath
                                push!(all, abspath(root, file))
                            else
                                push!(all, fe[1][1+length(file_prefix):end])
                            end
                        end
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
    filename = "$(_libraryprefix())$(library)$(_libraryextension())"
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
                    GetClassData(library, namespace);
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
    # unload class definitions as well
    delete!(_classdefinitions, library)
    return
end

"""
Helper function to grab port by name in string form
"""
function _parselocation(model::ModelInstance, fieldname::String) :: Tuple{Ptr{Cvoid}, Port}
    data = _classdefinitions[model.modulename].structs
    curstruct = _classdefinitions[model.modulename].last # assumes that overarching is the last defined
    ptr = model.obj

    # returned value is a Box<Box<dyn trait>>
    ptr = Ptr{Cvoid}(unsafe_load(Ptr{UInt64}(ptr)))

    downtree = split(fieldname, ".")
    for (i, token) in enumerate(downtree)
        lasttok = (i == length(downtree))
        ref = data[curstruct]
        if !(token in keys(ref.fields))
            throw(ErrorException("$(token) is not a member of $(curstruct)"))
        end
        port = ref.fields[token][1]
        ptr += ref.fields[token][2]
        if lasttok
            if port.iscomposite
                throw(ErrorException("$(token) is not a signal"))
            end
            if !(port.type in keys(_type_map))
                throw(ErrorException("Signal $(token) has type $(port.type) which is not supported"))
            end
            # return information to caller
            return (ptr, port)
        elseif !port.iscomposite
            throw(ErrorException("$(token) is a signal but is accessed like a struct"))
        end
        curstruct = port.type
    end
    throw(ErrorException("Should not reach here. Something went terribly wrong"))
end

"""
    getindex(model::ModelReference, fieldname::String)
Attempts to get a signal and return a copy of the value. UNSAFE.
NOTE: does not correct for row-major to column-major conversion.
```jldoctest
julia> get(cubesat, "data.mass")
35.6
```
"""
function Base.:getindex(model::ModelReference, fieldname::String) :: Any
    _model = _getmodelinstance(model)
    (ptr, port) = _parselocation(_model, fieldname)
    # ATTEMPT TO LOAD DATA HERE!!!!!
    t = _type_map[port.type]
    if length(port.dimension) == 0
        if t == String
            return get_utf8_string(ptr)
        else
            return unsafe_load(Ptr{t}(ptr))
        end
    else
        # return a deepcopy so that users can't alter the model
        # TODO handle row-major to column-major conversion
        return deepcopy(unsafe_wrap(Array, Ptr{t}(ptr), port.dimension))
    end
end

"""
    setindex!(model::ModelReference, value::Any, fieldname::String)
Attempts to set a signal to value. UNSAFE. Requires value to match the
port type.
NOTE: does not correct for column-major to row-major conversion.
```jldoctest
julia> set!(cubesat, "inputs.voltage", 5.0)
```
"""
function Base.:setindex!(model::ModelReference, value::T, fieldname::String) where{T}
    _model = _getmodelinstance(model)
    (ptr, port) = _parselocation(_model, fieldname)
    if T != String && size(value) != port.dimension
        throw(ArgumentError("Value size does not match port size: $(port.dimension)"))
    end
    t = _type_map[port.type]
    if t == String
        set_utf8_string(ptr, value)
        return
    end
    if eltype(value) != t
        throw(ArgumentError("Value type does not match port type: $(port.type)"))
    end
    if length(port.dimension) == 0
        unsafe_store!(Ptr{t}(ptr), value)
    else
        arr = unsafe_wrap(Array, Ptr{t}(ptr), port.dimension)
        unsafe_copyto!(arr, 1, value, 1, length(value))
    end
    return
end

"""
    connect(output::Tuple{ModelReference, String}, input::Tuple{ModelReference, String})
Add a connection between an output port and an input port. The second value of the output
and input arguments represent the model ports by name. The `outputs` and `inputs` names
should not be specified.
```jldoctest
julia> connect((environment_model, "pos_eci"), (cubesat, "position"))
```
"""
function connect(output::Tuple{ModelReference, String}, input::Tuple{ModelReference, String}) :: Nothing
    in  = Location(input[1],  "inputs." * input[2]);
    out = Location(output[1], "outputs." * output[2]);

    _output = _getmodelinstance(out.model);
    (_, oport) = _parselocation(_output, out.port);
    _input  = _getmodelinstance(in.model);
    (_, iport) = _parselocation(_input, in.port);
    # data type must match
    if _type_map[oport.type] != _type_map[iport.type]
        throw(ArgumentError("Output port type: $(oport.type) does not match input port type: $(iport.type)"))
    end
    # dimension must match
    if oport.dimension != iport.dimension
        throw(ArgumentError("Output port dimension: $(oport.dimension) does not match input port dimension: $(iport.dimension)"))
    end
    # units must match
    # TODO

    _ensureconnection(out.model)
    _ensureconnection(in.model)
    # Register output connection
    if !haskey(_connections[out.model].output, out.port)
        _connections[out.model].output[out.port] = Set()
    end
    push!(_connections[out.model].output[out.port], in)

    # Register input connection
    if haskey(_connections[in.model].input, in.port)
        println("Warning! Redefining input connection")
    end
    _connections[in.model].input[in.port] = out;
    return
end

function convert_julia_type(juliatype::String, language::String = "Rust") :: String
    if !(juliatype in keys(_type_map))
        return juliatype
    end
    if language == "Rust"
        return _type_conversions[_type_map[juliatype]][1]
    elseif language == "C++"
        return _type_conversions[_type_map[juliatype]][2]
    else
        throw(ArgumentError("language must be [\"Rust\",\"C++\"]"))
    end
end

end
