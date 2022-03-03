# Model Interface
# Used for exposing models

module MModel

using Base: julia_cmd, julia_exename
using DataStructures: first
export Port, Callback
export PORT, PORTPTR, PORTPTRI
export listcallbacks, triggercallback
export load, unload, appsearch, describe
export structnames, structdefinition
export addlibpath, clearlibpaths
export _parselocation

using ..DataFrames
using ..DataStructures
using ..MsgPack
using ..MCFunction
using ..MScripting
using ..MLibrary
using ..MInterface
using ..Logging
using ..TOML
using ..Unitful


# Additional library paths to search
_additional_lib_paths = OrderedSet{String}()

@enum PortType PORT=1 PORTPTR=2 PORTPTRI=3

# add support for complex data types in MsgPack
# - deserialization doesn't currently work right, unsure how to fix it
MsgPack.msgpack_type(::Type{Complex{Float32}}) = MsgPack.ArrayType()
MsgPack.msgpack_type(::Type{Complex{Float64}}) = MsgPack.ArrayType()
MsgPack.to_msgpack(::MsgPack.ArrayType, arr::Complex{Float32}) = [real(arr), imag(arr)]
MsgPack.to_msgpack(::MsgPack.ArrayType, arr::Complex{Float64}) = [real(arr), imag(arr)]
MsgPack.from_msgpack(::Type{Complex{Float32}}, arr::Vector{Float32}) = Complex{Float32}(arr[1], arr[2])
MsgPack.from_msgpack(::Type{Complex{Float64}}, arr::Vector{Float64}) = Complex{Float64}(arr[1], arr[2])

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
    meta::Set{String}

    function Port(type::String, dimension::Tuple, units::Any, composite::Bool=false; note::String="", porttype::PortType=PORT, default=nothing, meta::Set{String}=Set{String}())
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
                    if (-1,) == dimension
                        if length(size(default)) != 1
                            throw(ArgumentError("Size of default value: $(default) does not fit into a one-dimensional vector"))
                        end
                    elseif size(default) != dimension
                        throw(ArgumentError("Size of default value: $(default) does not match dimension $(dimension)"))
                    end
                end
            end
            if _type == String && dimension != ()
                push!(meta, "simplearray") # flatten immediately
            end
        end
        new(type, dimension, units, composite, note, porttype, default, meta)
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
    fields::Dict{String, Tuple{UInt, Port}}
end
ClassData() = ClassData(Dict{String, Tuple{UInt, Port}}())

mutable struct LibraryData
    structs::Dict{String, ClassData}
    toplevel::String
end
LibraryData() = LibraryData(Dict{String, ClassData}(), "")

_classdefinitions = Dict{String, LibraryData}()


function _recurse_data_tree(classdef::LibraryData, data::Dict{String, Any}, dname::String) :: Nothing
    if dname in keys(classdef.structs)
        return
    end
    dat = ClassData()
    for (name, tags) in data[dname]
        if !("id" in keys(tags))
            @error "Corrupt metadata"
            continue
        end
        if "class" in keys(tags)
            _recurse_data_tree(classdef, data, tags["class"]) # go down subtree
            dat.fields[name] = (UInt(tags["id"]), Port(tags["class"], (), "", !_istypesupported(tags["class"])))
        elseif "type" in keys(tags)
            if !("unit" in keys(tags) && "dims" in keys(tags))
                @error "Corrupt field metadata"
                continue
            end
            dat.fields[name] = (UInt(tags["id"]), Port(tags["type"], Tuple(tags["dims"]), tags["unit"], !_istypesupported(tags["type"])))
        else
            @error "Invalid metadata detected"
        end
    end
    classdef.structs[dname] = dat
    return
end

function GetClassData(name::String, namespace::String, data::Dict{String, Any}) :: Nothing
    if name in keys(_classdefinitions)
        @error "Library $(name) already loaded. Metadata overwrite/corruption may occur"
    end
    ldata = LibraryData()
    _recurse_data_tree(ldata, data, data["rsis"]["name"])
    ldata.toplevel = data["rsis"]["name"]
    _classdefinitions[name] = ldata
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
    structnames(model::ModelReference)
Returns a vector of all defined structs for the library that
is associated with the instantiated model.
"""
function structnames(model::ModelReference) :: Vector{String}
    obj = _getmodelinstance(model)
    return structnames(obj.modulename)
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
        terms = [(_name, field[2].type, field[2].units, field[1]) for (_name, field) in data.structs[name].fields]
        sort!(terms, by=x->x[4])
        return terms
    else
        throw(ArgumentError("$(name) not defined!"))
    end
end

function structdefinition(app::ModelInstance, name::String) :: Vector{Tuple{String, String, String, UInt}}
    return structdefinition(app.modulename, name)
end
function structdefinition(app::ModelReference, name::String) :: Vector{Tuple{String, String, String, UInt}}
    return structdefinition(_getmodelinstance(app), name)
end

"""
    describe(model::ModelInstance, location::String; maxitems)
Print out app interface in a user-friendly fashion.
* maxdepth - limit to number of items printed to screen
"""
function DataFrames.:describe(app::ModelReference, location::String = ""; maxitems::Int = 50) :: Nothing
    _app = _getmodelinstance(app)
    if isa(_app, ModelInstance)
        describe(_app, location; maxitems = maxitems)
    else
        describe(_app; maxitems = maxitems)
    end
end

function DataFrames.:describe(obj::ModelInstance, location::String; maxitems::Int) :: Nothing
    tokens = split(location, ".")

    # start at the root of the tree
    loc = _classdefinitions[obj.modulename].toplevel
    data = _classdefinitions[obj.modulename].structs
    if tokens[1] != ""
        for tok in tokens
            ref = data[loc]
            if !(tok in keys(ref.fields))
                throw(ErrorException("$(tok) is not a member of $(loc)"))
            end
            port = ref.fields[tok][2]
            if !port.iscomposite
                throw(ErrorException("$(tok) is a signal but is accessed further"))
            end
            loc = port.type
        end
    end

    # assemble printout
    elements = structdefinition(obj, loc)
    ref = data[loc]

    table = DataFrame("Port" => Vector{String}(), "Type" => Vector{String}(), "Value" => Vector{String}(), "Units" => Vector{String}())
    for ii = 1:min(length(elements), maxitems)
        name = elements[ii][1]
        port = ref.fields[name][2]
        if port.iscomposite
            push!(table, (elements[ii][1], "Struct", "", ""))
        else
            push!(table, (elements[ii][1], port.type, "$(obj[location *"."*name])", "$(elements[ii][3])"))
        end
    end
    if length(elements) > maxitems
        push!(table, ("...", "...", "...", "..."))
    end
    @info table
end
function DataFrames.:describe(obj::CFunctionInstance; maxitems::Int) :: Nothing
    table = DataFrame("Port" => Vector{String}(), "Type" => Vector{String}(), "Value" => Vector{String}(), "Units" => Vector{String}())
    for sigtype = [OUTPUT, INPUT, DATA, PARAM]
        for ii = 1:capp_getnmeta(obj.metaobj, sigtype)
            (dt, _, ptr) = capp_getmeta(obj.metaobj, sigtype, ii)
            val = Base.unsafe_load(ptr)
            push!(table, ("$(sigtype)$(ii)", "$(dt)", "$val", ""))
            if ii + 1 > maxitems
                push!(table, ("...", "...", "...", "..."))
                break
            end
        end
    end
    @info table
end

"""
    addlibpath(directory::String; force::Bool = false)
Adds an external directory to the library search path. Relative paths
are resolved against the current working directory. If `force`
is specified, add the path if it doesn't exist
```jldoctest
julia> loadproject("programs/project1")
julia> addlibpath("/home/foo/release_area")
julia> appsearch()
2-element Vector{Tuple{String,String}}
 ("model1", "/home/foo/programs/project1/debug/target/libmodel1.so")
 ("extmod", "/home/foo/release_area/libextmod.so")
```
"""
function addlibpath(directory::String; force::Bool = false) :: Nothing
    if isabspath(directory)
        path = directory
    else
        path = joinpath(pwd(), directory)
    end
    if force || isdir(path)
        push!(_additional_lib_paths, path)
    else
        @warn "Path: $path does not exist"
    end
    return
end

function clearlibpaths() :: Nothing
    global _additional_lib_paths
    _additional_lib_paths = OrderedSet{String}()
    return
end

"""
    appsearch(app::String; fullname::Bool)
Searches for apps that can be loaded. With no arguments, it will
return a list of model libraries that can be loaded with
`load`. The project build directory is recursively searched
for shared libraries; file extension set by OS. Additional
library search paths can be set with `addlibpath`. Tuples of the
library tag name, build type, and tag filepath are returned.
The tag file must exist alongside the library.

If a name is specified, it will only search for the specified
app and throw an exception if not found. If the fullname argument
is specified, the full name of the tag file will be returned.
```
julia> appsearch()
3-element Vector{Tuple{String, String, String}}:
 ("fsw_hr_model", "debug", "/home/foo/target/debug")
 ("fsw_lr_model", "release", "/home/foo/target/release")
 ("gravity_model", "debug", "/home/foo/target/debug")
```
"""
function appsearch(app::String = ""; fullname::Bool = false) :: Vector{Tuple{String, String, String}}
    all = Vector{Tuple{String, String, String}}()
    file_ext    = _libraryextension()
    file_prefix = _libraryprefix()

    single_search = !isempty(app)

    dpat = r"^rsis_(.*)\.app\.debug\.toml";
    rpat = r"^rsis_(.*)\.app\.release\.toml";

    for dir in collect(_additional_lib_paths)
        if isdir(dir)
            for file in readdir(dir)
                if single_search && !occursin(Regex(app), file)
                    continue
                end
                # check for toml tag file
                found   = false
                tagname = file
                type    = "debug"
                if occursin(dpat, file)
                    found = true
                    tagname = if fullname file else match(dpat, file)[1] end
                elseif occursin(rpat, file)
                    found = true
                    type = "release"
                    tagname = if fullname file else match(rpat, file)[1] end
                end
                if found
                    push!(all, (tagname, type, abspath(dir)))
                    if single_search
                        return all;
                    end
                end
            end
        end
    end
    if single_search
        throw(ErrorException("Failed to find library: [$app]"))
    end
    return all
end

"""
    load(library::String; namespace::String="", type::String="")
Load a shared library containing a model implementation.
If a namespace is defined, any reflection data defined during
the load process is defined within that namespace, allowing
for multiple models to define classes with the same name.

If both debug and release versions of a model exist, they can be chosen
via the `specify` argument. The default option is the first model found on
the path.
```jldoctest
julia> load("mymodel")
[ Info: Loaded mymodel
julia> load("anothermodel"; namespace="TEST")
[ Info: Loaded anothermodel => [TEST]
julia> load("coreapp"; specify="release")
```
"""
function load(library::String; namespace::String="", specify::String="") :: Nothing
    # Find library in search path, then pass absolute filepath to core functionality
    (tagfile, type, path) = appsearch(library; fullname = true)[1]

    # load tag file to get file name
    if isempty(specify) || specify == type
        open(joinpath(path, tagfile), "r") do io
            data = TOML.parse(io);
            # TODO add check on reported rsis version
            file = data["binary"]["file"]
            # load library
            if !LoadModelLib(library, joinpath(path, file), data, namespace)
                @info "Model library already loaded."
            else
                GetClassData(library, namespace, data)
                @info "Loaded $(file): $(type)$(if isempty(namespace) "" else " => [$(namespace)]" end)"
            end
        end
        return
    end
end

"""
    unload(library::String)
Unload a shared library containing a model implementation
```jldoctest
julia> load("mymodel")
julia> unload("mymodel")
julia> unload("mymodel")
┌ Warning: Model library not previously loaded
└ @ RSIS.MModel ~/rsis/src/Model.jl:324
```
"""
function unload(library::String) :: Nothing
    if !UnloadModelLib(library)
        @warn "Model library not previously loaded"
    end
    # unload class definitions as well
    delete!(_classdefinitions, library)
    return
end

"""
Helper function to grab MessagePack index by name
ModelInstance only
"""
function _parselocation(model::ModelInstance, fieldname::String) :: Tuple{Vector{UInt32}, Port}
    data = _classdefinitions[model.modulename].structs
    curstruct = _classdefinitions[model.modulename].toplevel

    indices = Vector{UInt32}()

    downtree = split(fieldname, ".")
    for (i, token) in enumerate(downtree)
        lasttok = (i == length(downtree))
        ref = data[curstruct]
        if !(token in keys(ref.fields))
            throw(ErrorException("$(token) is not a member of $(curstruct)"))
        end
        port = ref.fields[token][2]
        push!(indices, ref.fields[token][1])
        if lasttok
            if port.iscomposite
                throw(ErrorException("$(token) is not a signal"))
            end
            if !_istypesupported(port.type)
                throw(ErrorException("Signal $(token) has type $(port.type) which is not supported"))
            end
            # return information to caller
            return (indices, port)
        elseif !port.iscomposite
            throw(ErrorException("$(token) is a signal but is accessed like a struct"))
        end
        curstruct = port.type
    end
    throw(ErrorException("Should not reach here. Please contact the developers"))
end

"""
Copy of function meant to catch infrastructure errors
this function should not be called
"""
function _parselocation(model::CFunctionInstance, idx::Int) :: Tuple{Vector{UInt32}, Port}
    #
end

_messagepack_buffer = Vector{UInt8}()
function _setup_buffer(size::UInt) :: Ptr{UInt8}
    global _messagepack_buffer
    _messagepack_buffer = zeros(UInt8, size)
    pointer(_messagepack_buffer)
end

"""
    getindex(model::ModelReference, fieldname::String)
Attempts to get a signal and return a copy of the value.
Internally relies on MessagePack API.
Supports ModelInstance(s) only
```jldoctest
julia> cubesat["data.mass"]
35.6
```
"""
function Base.:getindex(model::ModelReference, fieldname::String) :: Any
    app = _getmodelinstance(model)
    return app[fieldname]
end

function Base.:getindex(app::ModelInstance, fieldname::String)::Any
    if !isa(app, ModelInstance)
        throw(ErrorException("The function arguments of this app are accessed with integer values"))
    end
    (idx, port) = _parselocation(app, fieldname)
    t = _gettype(port.type)

    # Call into the app API with the requested index and a memory setup callback
    # The app will execute the callback to ensure that a buffer of the correct
    # size exists in the Julia environent for the app to fill it with the
    # packed MessagePack structure, and then copy it into the buffer
    _meta_get(app, idx, @cfunction(_setup_buffer, Ptr{UInt8}, (UInt,)))
    if port.dimension == ()
        return unpack(_messagepack_buffer, _gettype(port.type))
    elseif port.dimension == (-1,) || length(port.dimension) == 1
        return unpack(_messagepack_buffer, Vector{_gettype(port.type)})
    else
        data = unpack(_messagepack_buffer, Vector{_gettype(port.type)})
        return reshape(data, reverse(port.dimension))' # convert row major to column
    end
end

"""
    getindex(model::ModelReference, signal::SignalTypes, fieldid::Int)
Attempts to get a signal and return a copy of the value.
Supports CFunctionInstance(s) only
```jldoctest
julia> transfer_fn = addjuliaapp(x->x^2 - x, Float32, (Float32,), "quadratic")
julia> transfer_fn[INPUT, 1] = 45.1f0
```
"""
function Base.:getindex(model::ModelReference, signal::SignalTypes, fieldid::Int) :: Any
    obj = _getmodelinstance(model)
    if !isa(obj, CFunctionInstance)
        throw(ErrorException("The function arguments of this type are accessed with string values"))
    end
    (_, dims, ptr) = capp_getmeta(obj.metaobj, signal, fieldid)
    if dims != ()
        @error "Non-scalar values are unsupported. Returning first value"
    end
    return Base.unsafe_load(ptr)
end

"""
    setindex!(model::ModelReference, value::Any, fieldname::String)
Attempts to set a signal to value, performing type and size checks.
Relies on internal MessagePack API.
```jldoctest
julia> set!(cubesat, "inputs.voltage", 5.0)
```
"""
function Base.:setindex!(model::ModelReference, value::Any, fieldname::String)
    _model = _getmodelinstance(model)
    if !isa(_model, ModelInstance)
        throw(ErrorException("The function arguments of this app are accessed with integer values"))
    end
    (idx, port) = _parselocation(_model, fieldname)
    t = _gettype(port.type)
    if value isa String
        if String != t
            throw(ArgumentError("Value type $(t) does not match port type: $(port.type)"))
        end
    else
        if eltype(value) != t
            throw(ArgumentError("Value type $(t) does not match port type: $(port.type)"))
        end
        if (-1,) == port.dimension # variable length array
            if length(size(value)) != 1
                throw(ArgumentError("Value size $(size(value)) is not a 1d vector"))
            end
        elseif size(value) != port.dimension
            throw(ArgumentError("Value size $(size(value)) does not match port size: $(port.dimension)"))
        end
        if length(port.dimension) > 1 # nd array
            value = reshape(value', prod(port.dimension)) # column major to row major
        end
    end
    _meta_set(model, idx, pack(value))
    return
end


"""
    setindex!(model::ModelReference, value::Any, signal::SignalTypes, fieldid::Int)
Attempts to set a signal to value.
Supports CFunctionInstance(s) only.
Warning: does not do it's own datatype checking on the value
```jldoctest
julia> transfer_fn = addjuliaapp(x->x^2 - x, Float32, (Float32,), "quadratic")
julia> transfer_fn[INPUT, 1] = 45.1f0
julia> transfer_fn[INPUT, 1]
45.1f0
```
"""
function Base.:setindex!(model::ModelReference, value::Any, signal::SignalTypes, fieldid::Int)
    obj = _getmodelinstance(model)
    if !isa(obj, CFunctionInstance)
        throw(ErrorException("The function arguments of this type are accessed with string values"))
    end
    (_, dims, ptr) = capp_getmeta(obj.metaobj, signal, fieldid)
    if dims != ()
        @error "Non-scalar values are unsupported. Setting first value"
    end
    Base.unsafe_store!(ptr, value)
    return
end

end
