
module MScheduling
using ..MLibrary
using ..MModel
using ..Unitful

export setthread, setnumthreads, schedule, threadinfo
export initsim, stepsim, endsim, setstoptime, settimelimit

mutable struct SModel
    ref::ModelReference
    frequency::Rational{Int64}
    offset::Int64
end

mutable struct SThread
    scheduled::Vector{SModel}
    frequency::Rational{Int64}
    cpuaffinity::Int32
    function SThread()
        new(Vector{SModel}(), -1.0, -1)
    end
end


# globals
_threads = Vector{SThread}()
push!(_threads, SThread())

_base_sim_frequency = Rational{Int64}(0) # must be set by init_scheduler

_max_sim_duration = Float64(-1)
_time_limits = Dict{String, Float64}()

function _resetthreads() :: Nothing
    empty!(_threads)
    return
end

function setthread(threadId::Int; frequency::Float64=1.0, cpu::Int32=-1)
    if threadId < 0 || threadId > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    _threads[threadId].frequency = frequency;
    _threads[threadId].cpuaffinity = cpu;
end

"""
    setnumthreads(num::Int)
Clears all threads, and creates the specified number of threads.
"""
function setnumthreads(num::Int) :: Nothing
    if (num < 1)
        throw(ArgumentError("$(num) is non-positive"))
    end
    _resetthreads()
    for i=1:num
        push!(_threads, SThread());
    end
    return
end

"""
    threadinfo()
Returns a vector of tuples containing thread frequencies and cpu affinities.
"""
function threadinfo() :: Vector{Tuple{Rational{Int64}, Int32}}
    return [(thread.frequency, thread.cpuaffinity) for thread in _threads]
end

"""
    schedule(model::ModelReference, frequency::Rational{Int64}; offset::Int64 = 0, thread::Int64 = 1)
Schedule a model in the current scenario, with a specified rational frequency and offset.
"""
function Base.:schedule(model::ModelReference, frequency::Rational{Int64}; offset::Int64 = 0, thread::Int64 = 1)::Nothing
    if thread < 1 || thread > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    push!(_threads[thread].scheduled, SModel(model, frequency, offset));
    return
end

"""
    schedule(model::ModelReference, frequency::Float64 = -1.0; offset::Int64 = 0, thread::Int64 = 1)
Schedule a model in the current scenario, with a specified frequency and offset.
"""
function Base.:schedule(model::ModelReference, frequency::Float64 = -1.0; offset::Int64 = 0, thread::Int64 = 1) :: Nothing
    schedule(model, Rational(frequency); offset=offset, thread=thread);
end


function _verifyfrequencies()
    for thread in _threads
        if thread.frequency < 0 # discovery
            for model in thread.scheduled
                thread.frequency = lcm(thread.frequency, model.frequency)
            end
        else
            for model in thread.scheduled
                if thread.frequency % model.frequency != 0
                    throw(ErrorException("Model: [$(model.ref.name), $(model.frequency)] does not evenly divide into [Thread $(i), $(thread.frequency)]"))
                end
            end
        end
    end
end

"""
    initsim(;blocking::Bool=false)
Verifies the scenario, and initializes the simulation.
By default returns immediately to user, unless the blocking
flag is set to true.
```jldoctest
julia> initsim()
julia> initsim(blocking = true)
```
"""
function initsim(;blocking::Bool = false) :: Nothing
    global _base_sim_frequency
    _verifyfrequencies();

    # create threads
    for (i,thread) in enumerate(_threads)
        addthread(float(thread.frequency))
        _base_sim_frequency = max(_base_sim_frequency, thread.frequency)
        @info "Thread $(i): $(Float64(thread.frequency)) Hz"
        # schedule models
        for model in thread.scheduled
            # find the connections that this model depends on, and schedule them first
            cncts = listconnections(model.ref)
            model_in = _getmodelinstance(model.ref)
            for (out, in) in cncts
                (idx_in, port_in)   = _parselocation(model_in, in.port)
                model_out = _getmodelinstance(out.model)
                (idx_out, port_out) = _parselocation(model_out, out.port)
                # get pointers from API
                dst = _get_ptr(model_in, idx_in)
                src = _get_ptr(model_out, idx_out)
                if src == 0 || dst == 0
                    @error "Null pointers detected. Connection skipped"
                    continue
                end
                # port sizes should be checked by now
                createconnection(src, dst, UInt64(sizeof(port_out)), i - 1, Int64(thread.frequency / model.frequency), model.offset)
            end
            # Convert 1 based indexing to 0 based indexing for the thread id
            schedulemodel(model.ref, i - 1, Int64(thread.frequency / model.frequency), model.offset)
        end
    end
    initscheduler()
end

"""
    stepsim(steps::Int64 = 1)
Step the simulation by the specified number of steps.
"""
function stepsim(steps::Int64 = 1)
    # TODO add state checking here
    @info "Stepping $(steps) steps"
    stepscheduler(UInt64(steps));
end

"""
    stepsim(time::Unitful.Quantity)
Step the simulation by the specified time. The first argument
must be convertable to a time value as understood by Unitful
```jldoctest
julia> stepsim(15.3u"s")
julia> stepsim(3.2u"minute")
julia> stepsim(1u"hr")
```
"""
function stepsim(time::Unitful.Quantity{T, D, U}) where {T, D, U}
    time_in_seconds = ustrip(u"s", time)
    if length(size(time_in_seconds)) != 0
        # can this logic be improved?
        throw(ArgumentError("`time` is not a scalar. Dimension: $(size(time_in_seconds))"))
    end
    steps = floor(time_in_seconds * _base_sim_frequency)
    stepsim(Int64(steps))
end

"""
    endsim()
Ends/Halts the simulation. Drops all saved ModelInstances
as they have been consumed and have reached end of life.
"""
function endsim() :: Nothing
    endscheduler()
    _base_sim_frequency = Int64(0)
    _time_limits = Dict{String, Float64}()
    return
end

"""
    setstoptime(time::Number) # seconds
Sets the maximum duration of the simulation in seconds.
If the duration is set to (-1), no limit is applied.

Note: other entities can still impose limits on the length of a
simulation, e.g. native datalogging components.
"""
function setstoptime(time::Number) :: Nothing
    if time < 0
        if time != -1
            throw(ArgumentError("Invalid duration specified: $time [s]"))
        end
    end
    _max_sim_duration = Float64(time);
    return
end

"""
    setstoptime(time::Unitful.Quantity{T, D, U})
Sets the maximum duration of the simulation in units of time.
```jldoctest
julia> setstoptime(20u"minute")
```
"""
function setstoptime(time::Unitful.Quantity{T, D, U}) where {T, D, U}
    time_in_seconds = ustrip(u"s", time)
    if length(size(time_in_seconds)) != 0
        # can this logic be improved?
        throw(ArgumentError("`time` is not a scalar. Dimension: $(size(time_in_seconds))"))
    end
    setstoptime(time_in_seconds)
end

"""
    settimelimit(name::String, time::Number)
Sets an additional time limit restraint on the simulation.
This exists to support data logging primarily, but is extended
to the user as well. Ending a simulation clears these restraints.
```jldoctest
julia> settimelimit("GITLAB_CI_TIME_LIMIT", ENV["CI_TOKEN_DURATION"])
```
"""
function settimelimit(name::String, time::Number) :: Nothing
    if name in keys(_time_limits)
        @warn "Time limit for $name being overridden"
    end
    if _time_limits < 0
        throw(ArgumentError("Time limit $name: $time is negative"))
    end
    _time_limits[name] = time;
    return
end

end
