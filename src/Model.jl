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
export connect, listconnections
export _parselocation

using ..DataStructures
using ..MScripting
using ..MLibrary
using ..MInterface
using ..Logging
using ..MProject
using ..Unitful


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
            _type = _gettype(type)
            if !isnothing(default)
                if typeof(default) == String
                    if _type != String
                        throw(ArgumentError("Default value: $(default) is type $(typeof(default)), not $(type)"))
                    end
                else
                    if !(eltype(default) <: _type)
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

function Base.sizeof(port::Port)
    if port.iscomposite
        throw(ErrorException("Port: $(port) is a struct type"))
    else
        # note. prod(()) returns 1
        return sizeof(_gettype(port.type)) * prod(port.dimension)
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
    input_link :: Dict{String, Location}
end
_connections = Dict{ModelReference, Connections}()
function _ensureconnection(model::ModelReference)
    if !(model in keys(_connections))
        _connections[model] = Connections(Dict{String, Location}())
    end
end


function _CreateClass(name::Ptr{UInt8}) :: Nothing
    cl = unsafe_string(name)
    _data = _classdefinitions[_cur_class]
    if cl in keys(_data.structs)
        @warn "Class: $(cl) redefined."
    end
    _data.structs[cl] = ClassData()
    _data.last = cl # workaround
    return
end

function _CreateMember(cl::Ptr{UInt8}, memb::Ptr{UInt8}, def::Ptr{UInt8}, offset::UInt, units::Ptr{UInt8}) :: Nothing
    classname = unsafe_string(cl)
    member    = unsafe_string(memb)
    definition = unsafe_string(def)
    unitstr    = unsafe_string(units)
    _data = _classdefinitions[_cur_class]
    if !(classname in keys(_data.structs))
        @warn "Class: $(classname) for member: $(member) does not exist. Creating default."
        _data.structs[classname] = ClassData()
    end
    # parse definition passed as a string
    if occursin("[", definition) # array detection
        tt = split(definition[2:end-1], ";")
        dims = []
        for token in split(tt[2], ",")
            val = tryparse(Int, token)
            if isnothing(val)
                @error "Unable to parse: $(token) as a dimension"
                val = -1
            end
            push!(dims, val)
        end
        _data.structs[classname].fields[member] = (Port(String(tt[1]), Tuple(dims), unitstr, !_istypesupported(String(tt[1]))), offset)
    else
        _data.structs[classname].fields[member] = (Port(definition, (), unitstr, !_istypesupported(definition)), offset)
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
        @cfunction(_CreateMember, Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}, UInt, Ptr{UInt8})))
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
Returns a vector of all defined fields for a struct defined by a library.
```jldoctest
julia> structdefinition("cubesat", "cubesat_params")
1-element Vector{Tuple{String, String, String, UInt64}}:
 ("signal", "Float64", "kg", 0x0000000000000000)
```
"""
function structdefinition(library::String, name::String) :: Vector{Tuple{String, String, String, UInt}}
    data = _classdefinitions[library]
    if name in keys(data.structs)
        return [(_name, field[1].type, field[1].units, field[2]) for (_name, field) in data.structs[name].fields]
    else
        throw(ArgumentError("$(name) not defined!"))
    end
end

"""
    listavailable(;fullpath::Bool = false)
Returns a list of model libraries that can be loaded with
`load`. The project build directory is recursively searched
for shared libraries; file extension set by OS. Additional
library search paths can be set with `addlibpath`. Tuples of the
library name and the absolute filepath are returned.
```
julia> listavailable()
3-element Vector{Tuple{String, String}}:
 ("fsw_hr_model", "/home/foo/target/release/libfsw_hr_model.dylib")
 ("fsw_lr_model", "/home/foo/target/release/libfsw_lr_model.dylib")
 ("gravity_model", "/home/foo/target/release/libgravity_model.dylib")
```
"""
function listavailable() :: Vector{Tuple{String, String}}
    all = Vector{Tuple{String, String}}()
    if !isprojectloaded()
        @info "Load a project to see available libraries."
    else
        bdir = getprojectbuilddirectory()
        file_ext = _libraryextension()
        file_prefix = _libraryprefix()
        if isdir(bdir)
            for file in readdir(bdir)
                fe = splitext(file)
                if fe[2] == file_ext && startswith(fe[1], file_prefix)
                    push!(all, (fe[1][1+length(file_prefix):end], abspath(bdir, file)))
                end
            end
            # check additional paths
            for path in _additional_lib_paths
                #
            end
        else
            @error "Project build directory does not exist"
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
        @error "Load a project to see available libraries."
        return
    end
    bdir = getprojectbuilddirectory()
    if isdir(bdir)
        for (name, path) in listavailable()
            if name == library
                # load library
                if !LoadModelLib(library, path, namespace)
                    @info "Model library alread loaded."
                end
                GetClassData(library, namespace);
                return
            end
        end
    end
    throw(ErrorException("Could not locate library: [$library]"))
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
        @warn "Model library not previously loaded."
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

    libdata = libraryinfo(model.modulename)
    if libdata["rsis"]["type"] == "rust"
        # returned value is a Box<Box<dyn trait>>
        # ASSUMPTION: the first regular pointer of the fat pointer is what we need
        ptr = Ptr{Cvoid}(unsafe_load(Ptr{UInt64}(ptr)))
    else
        # c++, do nothing as pointer that we have is the actual pointer to the object
    end

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
            if !_istypesupported(port.type)
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

    libdata = libraryinfo(_model.modulename)

    t = _gettype(port.type)
    if length(port.dimension) == 0
        if t == String
            return get_utf8_string(ptr, libdata["rsis"]["type"])
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
    libdata = libraryinfo(_model.modulename)
    if T != String && size(value) != port.dimension
        throw(ArgumentError("Value size does not match port size: $(port.dimension)"))
    end
    t = _gettype(port.type)
    if t == String
        set_utf8_string(ptr, value, libdata["rsis"]["type"])
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
    if _gettype(oport.type) != _gettype(iport.type)
        throw(ArgumentError("Output port type: $(oport.type) does not match input port type: $(iport.type)"))
    end
    # dimension must match
    if oport.dimension != iport.dimension
        throw(ArgumentError("Output port dimension: $(oport.dimension) does not match input port dimension: $(iport.dimension)"))
    end
    # check units only if they both exist
    if !isempty(iport.units) && !isempty(oport.units)
        # simple string equality check for now
        if iport.units != oport.units
            throw(ArgumentError("Output port units: $(oport.units) does not match input port units: $(iport.units)"))
        end
    end

    _ensureconnection(in.model)
    # Register input connection
    if haskey(_connections[in.model].input_link, in.port)
        println("Warning! Redefining input connection")
    end
    _connections[in.model].input_link[in.port] = out;
    return
end

"""
    listconnections()
Returns a list of all the connections within the scenario.
The first element is the output, the second is the input
"""
function listconnections() :: Vector{Tuple{Location, Location}}
    cncts = Vector{Tuple{Location, Location}}()
    for (model, _map) in _connections
        for (_iport, _oloc) in _map.input_link
            push!(cncts, (_oloc, Location(model, _iport)))
        end
    end
    return cncts
end

"""
    listconnections(model::ModelReference)
Returns a list of input connections by model.
The first element is the output, the second is the input
"""
function listconnections(model::ModelReference) :: Vector{Tuple{Location, Location}}
    cncts = Vector{Tuple{Location, Location}}()
    if model in keys(_connections)
        for (_iport, _oloc) in _connections[model].input_link
            push!(cncts, (_oloc, Location(model, _iport)))
        end
    end
    return cncts
end

end
