
module MScenario

export scenario!, savescenario
export connect, listconnections
export getconfig

using ..YAML
using ..MLibrary
using ..MModel
using ..MScripting
using ..MInterface

# Connection struct
struct Location
    model :: ModelReference
    stype :: SignalTypes
    port  :: Union{String, Int}
end

mutable struct Connections
    input_link :: Dict{String, Location}
end

"""
Contains information on the current sim scenario
"""
mutable struct Configuration
    models::Vector{String}
    connections::Dict{ModelReference, Connections}
    function Configuration()
        new(Vector{String}(), Dict{ModelReference, Connections}())
    end
end

# globals
_config = Configuration()

function getconfig() :: Configuration
    return _config
end

function _ensureconnection(app::ModelReference)
    conf = getconfig()
    if !(app in keys(conf.connections))
        conf.connections[app] = Connections(Dict{String, Location}())
    end
end

"""
    connect(outapp::ModelReference, outloc::Union{String, Int}, inapp::ModelReference, inloc::Union{String, Int})
Add a connection between an output port and an input port. The second value of the output
and input arguments represent the model ports by name. The `outputs` and `inputs` names
must not be specified.
```jldoctest
julia> connect(env_model, "pos_eci", cubesat, "position")
julia> scale_output = addjuliaapp(exp, Float32, (Float32,), "exponential scaling")
julia> connect(env_model, "power_db", scale_output, 1)
```
"""
function connect(outapp::ModelReference, outloc::Union{String, Int}, inapp::ModelReference, inloc::Union{String, Int}) :: Nothing
    inobj  = _getmodelinstance(inapp);
    outobj = _getmodelinstance(outapp);
    if isa(inobj, ModelInstance)
        in = Location(inapp, INPUT, "inputs." * inloc)
        (_, iport) = _parselocation(inobj, in.port)
    else
        in = Location(inapp, INPUT, inloc)
        (datatype, dims, _) = capp_getmeta(inobj.metaobj, INPUT, inloc)
        iport = Port("$(datatype)", dims, "")
    end
    if isa(outobj, ModelInstance)
        out = Location(outapp, OUTPUT, "outputs." * outloc)
        (_, oport) = _parselocation(outobj, out.port)
    else
        out = Location(outapp, OUTPUT, outloc)
        (datatype, dims, _) = capp_getmeta(outobj.metaobj, OUTPUT, outloc)
        oport = Port("$(datatype)", dims, "")
    end

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

    _ensureconnection(inapp)
    # Register input connection
    conf = getconfig()
    if haskey(conf.connections[inapp].input_link, in.port)
        println("Warning! Redefining input connection")
    end
    conf.connections[inapp].input_link[in.port] = out;
    return
end

"""
    listconnections()
Returns a list of all the connections within the scenario.
The first element is the output, the second is the input
"""
function listconnections() :: Vector{Tuple{Location, Location}}
    conf = getconfig()
    cncts = Vector{Tuple{Location, Location}}()
    for (model, _map) in conf.connections
        for (inapp, _oloc) in _map.input_link
            push!(cncts, (_oloc, Location(model, INPUT, inapp)))
        end
    end
    return cncts
end

"""
    listconnections(app::ModelReference)
Returns a list of input connections by app.
The first element is the output, the second is the input
"""
function listconnections(app::ModelReference) :: Vector{Tuple{Location, Location}}
    conf = getconfig()
    cncts = Vector{Tuple{Location, Location}}()
    if app in keys(conf.connections)
        for (inapp, _oloc) in conf.connections[app].input_link
            push!(cncts, (_oloc, Location(app, INPUT, inapp)))
        end
    end
    return cncts
end

"""
    scenario!(filename::String)
Load a scenario YAML file from the filepaths. Loading a
new scenario overrides the previously loaded scenario if it exists.
```jldoctest
julia> scenario!("cloudy_day_test")
julia> scenario!("closed_loop_sim.scene")
```
"""
function scenario!(filename::String) :: Nothing
    locations = search(filename)
    if length(locations) == 0
        throw(ErrorException("$(filename) not found!"))
    end

    data = YAML.load_file(locations[1])

    num_libs = 0
    num_mods = 0
    if "models" in keys(data)
        for (library, instances) in data["models"]
            load(library)
            num_libs += 1
            for (instance, _) in instances
                newmodel(library, instance)
                num_mods += 1
            end
        end
    end
    @info "Scenario loaded: $num_libs libraries, $num_mods models"
end

"""
    savescenario(filename::String; format::String)
Save the current scenario configuration to a YAML file. The
file extension defaults to '.yml'.

TODO SUPPORTED FORMATS
- yaml
- toml
- json
```jldoctest
julia> savescenario("prototype_visual_navigation")
```
"""
function savescenario(filename::String; format::String = "yaml") :: Nothing
    #
end

end
