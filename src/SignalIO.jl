
module MSignalIO

using ..Unitful
using ..MLibrary
using ..MScripting
using ..MModel
using ..MScheduling
using ..MInterface

using ..CSV
using ..DataFrames

export logsignal, logsignalfile, listlogged
export setlogfilelimit, generate_log_structures
export getlogdata
export readsignal, generate_read_structures

_loggedfields = Dict{String, Dict{String, Float64}}()
_readfields   = Dict{String, Dict{String, Float64}}()

_log_file_size = 100 # 100 MB

mutable struct SignalBuffer{T <: Number}
    app :: ModelReference
    path :: String
    memory :: Vector{T}
    function SignalBuffer{T}(app, path, nval :: Int) where T <: Number
        new(app, path, zeros(T, nval))
    end
end

mutable struct DataBuffer
    logger :: ModelReference
    memory :: Vector{SignalBuffer}
    function DataBuffer(mod)
        new(mod, Vector{SignalBuffer}())
    end
end

mutable struct ThreadLogging
    rates :: Dict{Float64, DataBuffer}
    function ThreadLogging()
        new(Dict{Float64, DataBuffer}())
    end
end

_log_memory = Dict{Int, ThreadLogging}()
_read_tmp = Dict{String, Vector{Number}}()
_read_memory = Dict{Int, ThreadLogging}()

"""
    setlogfilelimit(limit::Float64)
Set the maximum size of a log (per thread) in MB.
```jldoctest
julia> setlogfilelimit(800.0) # MB. max CI artifact size
```
"""
function setlogfilelimit(limit::Float64) :: Nothing
    if limit < 0
        throw(ErrorException("File size limit specified: $limit, is negative"))
    end
    _log_file_size = limit;
    return
end

## Refactor using the DataFrames package
## this data is better consumed/output in this manner

"""
    logsignalfile(file::String)
Log the signals as specified by the input CSV file name.
```jldoctest
julia> logsignalfile("ship_logging.csv")
LOG: Logged 31 fields
```
"""
function logsignalfile(file::String) :: Nothing
    return
end

"""
    logsignal(model::ModelReference, path::String, rate::Float64)
Log the signal as specified by the input model port string. If
the rate is not specified, logging will occur at the rate that the
model is scheduled.
```jldoctest
julia> m = newmodel("assert_checks", "mymodel")
julia> schedule(m, 10.0)
julia> logsignal(m, "outputs.position", 10.0)
julia> logsignal(m, "outputs.thrust",    2.0)
```
"""
function logsignal(model::String, path::String, rate::Number = 0) :: Nothing
    # ensure that model and path exist. Move to initialization?
    if !(model in keys(_loggedfields))
        _loggedfields[model] = Dict{String, Float64}()
    end
    _loggedfields[model][path] = Float64(rate);
    return
end

function logsignal(model::ModelReference, path::String, rate::Number = 0) :: Nothing
    logsignal(model.name, path, rate)
end

"""
    listlogged()
Returns all signals currently being logged
```jldoctest
julia> listlogged()
```
"""
function listlogged()
    loggedfields = DataFrame("model" => Vector{String}(), "port" => Vector{String}(), "rate" => Vector{Float64}())
    for (app, data) in _loggedfields
        for (location, rate) in data
            push!(loggedfields, (app, location, rate))
        end
    end
    return loggedfields
end

function generate_log_structures()
    if length(keys(_loggedfields)) == 0
        return
    end

    @info "Initializing DataLogging"
    load("bufferlog") # load this utility if it doesn't already exist

    end_time = ustrip(getstoptime())
    if end_time < 0 # set to -1 for infinite simulation
        @error "DataLogging is currently constrained to simulations with defined end times"
        return
    end

    # iterate over threads
    # make a map of modelreferences to threads
    mapping = Dict{String, Tuple{Int, Rational}}()
    tinfo = threadinfo()
    for i in 1:nrow(tinfo)
        # get schedule info for that thread
        s = scheduleinfo(i)
        for (m, f) in eachrow(s)
            mapping[m.name] = (i, f)
        end
    end

    ratemodels = Dict{Int, Dict{Float64, ModelReference}}()
    for (app, data) in _loggedfields
        # check to see that the model is scheduled at all
        ref = ModelReference(app)
        if !(app in keys(mapping))
            @warn "Model: $app not scheduled. Skipping all logged signals"
            continue
        end

        modelinst = _getmodelinstance(ref) # checks to see if it exists at all
        thread = mapping[ref.name][1]

        if !(thread in keys(ratemodels))
            ratemodels[thread] = Dict{Float64, Vector{ModelReference}}()
        end

        # go through ports that are going to be logged
        for (location, rate) in data
            # ensure that the model exists, grab port info
            (indices, port) = _parselocation(modelinst, location)

            # check that the logging rate fits into the model scheduled rate
            lrate = Rational(rate)
            if mapping[ref.name][2] % lrate != 0
                @warn "Model [$app][$(mapping[ref.name][2]) Hz] incompatible with logging [$location][$rate Hz]. Skipping"
                continue
            end

            # if a rate doesn't exist, create a bufferlog model for it
            if !(rate in keys(ratemodels[thread]))
                ratemodels[thread][rate] = newmodel("bufferlog", "_bl_$(thread)_$(rate)")
            end
            rapp = ratemodels[thread][rate] # grab reference

            # get the threadlogging object
            if !(thread in keys(_log_memory))
                _log_memory[thread] = ThreadLogging()
            end
            tl = _log_memory[thread]

            # get the threadlogging rate model
            if !(rate in keys(tl.rates))
                tl.rates[rate] = DataBuffer(rapp)
            end
            db = tl.rates[rate]

            # create the memory needed for logging
            porttype = _gettype(port.type)
            ntimepoints = Int(ceil(end_time * rate))
            mem = SignalBuffer{(porttype)}(ref, location, ntimepoints)
            push!(db.memory, mem)

            # add the signal info to the bufferlog model
            rapp["params.psrc"] = push!(rapp["params.psrc"], _get_ptr(modelinst, indices))
            rapp["params.pdst"] = push!(rapp["params.pdst"], UInt64(pointer(mem.memory)))
            tsize = sizeof(porttype) * prod(port.dimension)
            rapp["params.sizes"] = push!(rapp["params.sizes"], Csize_t(tsize))
            rapp["params.ndata"] = ntimepoints
        end
    end

    # go through each rate model, and schedule it
    for (thread, rates) in ratemodels
        for (rate, app) in rates
            schedule(app, rate, thread = thread)
            @info "Created logger for Thread $(thread), rate $(rate)"
        end
    end
end

function generate_read_structures()
    if length(keys(_readfields)) == 0
        return
    end

    @info "Initializing DataReading"
    load("bufferread") # load this utility if it doesn't already exist

    # iterate over threads
    # make a map of modelreferences to threads
    mapping = Dict{String, Tuple{Int, Rational}}()
    tinfo = threadinfo()
    for i in 1:nrow(tinfo)
        # get schedule info for that thread
        s = scheduleinfo(i)
        for (m, f) in eachrow(s)
            mapping[m.name] = (i, f)
        end
    end

    max_time = typemax(Float64) # seconds

    rateapps = Dict{Int, Dict{Float64, ModelReference}}()
    for (app, data) in _readfields
        # check to see that the app is scheduled at all
        ref = ModelReference(app)
        if !(app in keys(mapping))
            @warn "App: $app not scheduled. Skipping all read signals"
            continue
        end

        modelinst = _getmodelinstance(ref) # checks to see if it exists at all
        thread = mapping[ref.name][1]

        if !(thread in keys(rateapps))
            rateapps[thread] = Dict{Float64, Vector{ModelReference}}()
        end

        # go through ports that are going to be read
        for (location, rate) in data
            # ensure that the model exists, grab port info
            (indices, port) = _parselocation(modelinst, location)

            # check that the read rate fits into the model scheduled rate
            lrate = Rational(rate)
            if mapping[ref.name][2] % lrate != 0
                @warn "App [$app][$(mapping[ref.name][2]) Hz] incompatible with logging [$location][$rate Hz]. Skipping"
                continue
            end

            # if a rate doesn't exist, create a bufferread app for it
            if !(rate in keys(rateapps[thread]))
                rateapps[thread][rate] = newmodel("bufferread", "_br_$(thread)_$(rate)")
            end
            rapp = rateapps[thread][rate] # grab reference

            # get the threadlogging object
            if !(thread in keys(_read_memory))
                _log_memory[thread] = ThreadLogging()
            end
            tl = _log_memory[thread]

            # get the threadlogging rate model
            if !(rate in keys(tl.rates))
                tl.rates[rate] = DataBuffer(rapp)
            end
            db = tl.rates[rate]

            # create the memory needed for logging from the referenced data
            readdata = _read_tmp[app]
            porttype = _gettype(port.type)
            mem = SignalBuffer{(porttype)}(ref, location, length(readdata))
            mem.memory = convert(Vector{(porttype)}, readdata)
            push!(db.memory, mem)

            # set time limits
            max_time = min(max_time, length(readdata) / rate)

            # add the signal info to the bufferlog model
            rapp["params.psrc"] = push!(rapp["params.psrc"], UInt64(pointer(mem.memory)))
            rapp["params.pdst"] = push!(rapp["params.pdst"], _get_ptr(modelinst, indices))
            tsize = sizeof(porttype) * prod(port.dimension)
            rapp["params.sizes"] = push!(rapp["params.sizes"], Csize_t(tsize))
        end
    end

    # go through each rate model, and schedule it before all other apps
    # on that thread
    for (thread, rates) in rateapps
        for (rate, app) in rates
            schedule(app, rate, thread = thread, index = 1)
            @info "Created reader for Thread $(thread), rate $(rate)"
        end
    end

    # set time limit on the sim
    settimelimit("datareader", max_time)
end

"""
    getlogdata()
Returns references to allocated memory storing logged data
"""
function getlogdata() :: Dict{Float64, DataFrame}
    refs = Dict{Float64, DataFrame}()
    for (~, tl) in _log_memory
        for (rate, db) in tl.rates
            if !(rate in keys(refs))
                refs[rate] = DataFrame()
            end
            for sb in db.memory
                name = Symbol("$(sb.app):$(sb.path)")
                refs[rate][!, name] = sb.memory
            end
        end
    end
    return refs
end

"""
    readsignal(app::ModelReference, path::String, rate::Float64)
Read into the signal as specified by the input app port string. If
the rate is not specified, logging will occur at the rate that the
app is scheduled.
```jldoctest
julia> n = newmodel("sensorsim", "simulated sensors")
julia> schedule(n, 100.0)
julia> readsignal(n, "inputs.acc_body", 100.0, baseline_acceleration)
julia> readsignal(n, "inputs.range_tgt", 20.0, baseline_range)
```
"""
function readsignal(app::String, path::String, rate::Number, data::Vector{<:Number}) :: Nothing
    # ensure that model and path exist. Move to initialization?
    if !(app in keys(_readfields))
        _readfields[app] = Dict{String, Float64}()
    end
    _readfields[app][path] = Float64(rate)

    # store data reference
    _read_tmp[app] = data
    return
end

function readsignal(app::ModelReference, path::String, rate::Number, data::Vector{<:Number}) :: Nothing
    readsignal(app.name, path, rate, data)
end

end
