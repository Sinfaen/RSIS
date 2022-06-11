
module MSignalIO

using ..MLibrary
using ..MScripting
using ..MModel
using ..MScheduling

using ..CSV
using ..DataFrames

export logsignal, logsignalfile, listlogged
export setlogfilelimit, generate_log_structures

_loggedfields = Dict{String, Dict{String, Float64}}()

_log_file_size = 100 # 100 MB

"""
    setlogfilelimit(limit::Float64)
Set the maximum size of a log (per thread) in MB.

TODO: refactor to use Unitful
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

    # iterate over threads
    # make a map of modelreferences to threads
    mapping = Dict{String, Int}()
    tinfo = threadinfo()
    for i in 1:nrow(tinfo)
        # get schedule info for that thread
        s = scheduleinfo(i)
        for (m, _) in eachrow(s)
            mapping[m.name] = i
        end
    end

    ratemodels = Dict{Int, Dict{Float64, Vector{ModelReference}}}()
    for (app, data) in _loggedfields
        # check to see that the model is scheduled at all
        ref = ModelReference(app)
        if !(app in keys(mapping))
            @warn "Model: $app not scheduled. Skipping all logged signals"
            continue
        end

        modelinst = _getmodelinstance(ref) # checks to see if it exists at all
        thread = mapping[ref.name]

        if !(thread in keys(ratemodels))
            ratemodels[thread] = Dict{Float64, Vector{ModelReference}}()
        end

        # go through ports that are going to be logged
        for (location, rate) in data
            # ensure that the model exists, grab port info
            (_, port) = _parselocation(modelinst, location)

            # if a rate doesn't exist, create it
            if !(rate in keys(ratemodels[thread]))
                ratemodels[thread][rate] = Vector{ModelReference}()
            end
            bl = newmodel("bufferlog", "_bl_$(thread)_$(rate)")
            push!(ratemodels[thread][rate], bl)
            @info "Created logger for Thread $(thread), rate $(rate)"
        end
    end

    # go through each rate model and schedule it
end

end
