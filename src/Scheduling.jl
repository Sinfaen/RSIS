
module MScheduling
using ..MLibrary
using ..MModel
using ..Unitful
using ..DataFrames

export setthread, setnumthreads, schedule, threadinfo, scheduleinfo
export initsim, stepsim, endsim, setstoptime, settimelimit, gettimelimit
export getstoptime
export register_scheduler_callback

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
_steptime_start = 0 # index of when last or current step started at in sim time
_simtime_finish = 0 # index

_max_sim_duration = Float64(-1)
_time_limits = Dict{String, Float64}()

_callbacks = Dict{Int, Vector{Function}}()

function _resetthreads() :: Nothing
    empty!(_threads)
    return
end

function setthread(threadId::Int; frequency::Float64=1.0, cpu::Int32=-1)
    if threadId < 0 || threadId > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    if simstatus() != CONFIG
        throw(ErrorException("Number of threads can only be changed from the CONFIG state"))
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
    if simstatus() != CONFIG
        throw(ErrorException("Number of threads can only be changed from the CONFIG state"))
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
function threadinfo() :: DataFrame
    return DataFrame("Frequency" => [thread.frequency for thread in _threads], 
        "Affinity" => [thread.cpuaffinity for thread in _threads])
end

"""
    schedule(model::ModelReference,
        frequency::Rational{Int64};
        offset::Int64 = 0,
        thread::Int64 = 1,
        index::Int64 = -1)
Schedule an app in the current scenario, with a specified rational frequency and offset.
If the index is not -1, then the app will be scheduled at a specific point in the
pre-existing schedule.
"""
function Base.:schedule(model::ModelReference, frequency::Rational{Int64}; offset::Int64 = 0, thread::Int64 = 1, index = -1)::Nothing
    if thread < 1 || thread > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    if simstatus() != CONFIG
        throw(ErrorException("Models can only be scheduled from the CONFIG state"))
    end
    if index == -1
        push!(_threads[thread].scheduled, SModel(model, frequency, offset))
        @info "Schedule $(model) > Thread $(thread) Index $(length(_threads[thread].scheduled))"
    else
        insert!(_threads[thread].scheduled, index, SModel(model, frequency, offset))
        @info "Schedule $(model) > Thread $(thread) inserted into Index $(index)"
    end
    return
end

"""
    schedule(model::ModelReference,
        frequency::Real = -1.0;
        offset::Int64 = 0,
        thread::Int64 = 1,
        index::Int64 = -1)
Schedule an app in the current scenario, with a specified frequency and offset.
If index is not -1, the app will be scheduled at a specific location in the existing
schedule.
"""
function Base.:schedule(model::ModelReference, frequency::Real = -1.0; offset::Int64 = 0, thread::Int64 = 1, index::Int64 = -1) :: Nothing
    schedule(model, Rational(frequency); offset=offset, thread=thread, index=index);
end

"""
    scheduleinfo(thread::Int64)
Returns the list of scheduled models for a specific thread
"""
function scheduleinfo(thread::Int64) :: DataFrame
    if thread < 1 || thread > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    schedule = _threads[thread].scheduled
    return DataFrame("Model" => [sm.ref for sm in schedule], 
        "Rate" => [sm.frequency for sm in schedule])
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
    initsim(;block::Bool=false)
Verifies the scenario, and initializes the simulation.
By default returns immediately to user, unless the blocking
flag is set to true.
```jldoctest
julia> initsim()
julia> initsim(block = true)
```
"""
function initsim(;block::Bool = false) :: Nothing
    global _base_sim_frequency
    global _steptime_start
    global _simtime_finish
    global _time_limits
    stat = simstatus()
    if stat == CONFIG
        @info "Initializing simulation"
    else
        throw(ErrorException("Sim cannot be initialized from $(stat) state"))
    end
    # call callbacks
    for key in sort!(collect(keys(_callbacks)))
        for cb in _callbacks[key]
            cb() # call the callback
        end
    end

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

    _steptime_start = 0 # index
    _simtime_finish = -1 # index
    if !isempty(_time_limits)
        _simtime_finish = minimum(collect(values(_time_limits)))
        @info "Setting max simulation time to $(_simtime_finish) [s]"
        _simtime_finish = floor(Int, _simtime_finish * _base_sim_frequency) # convert to index
    end

    if block
        while simstatus() == INITIALIZING
            sleep(0.1) # seconds
        end
    end
end

"""
    stepsim(steps::Int64 = 1; blocking:Bool = false)
Step the simulation by the specified number of steps.
If the blocking keyword is `true`, then the function will loop while waiting
for the scheduler status to change to anything besides RUNNING.
"""
function stepsim(steps::Int64 = 1; blocking::Bool = false)
    global _steptime_start
    global _simtime_finish
    stat = simstatus()
    if stat == INITIALIZED || stat == PAUSED
        @info "Stepping $(steps) steps"
    else
        throw(ErrorException("Sim cannot be stepped from $(stat) state"))
    end

    # apply maximum sim time rules, unless it's infinite
    if _simtime_finish > 0 && _steptime_start + steps > _simtime_finish
        steps = _simtime_finish - _steptime_start
        @warn "Limiting execution to $(steps) steps"
    end
    _steptime_start += steps

    # call into the core library
    stepscheduler(UInt64(steps));

    # if set to block, don't return until we're not RUNNING anymore
    if blocking
        while true
            stat = simstatus()
            if stat == INITIALIZED || stat == PAUSED
                sleep(0.1) # seconds
            else
                break
            end
        end
        while simstatus() == RUNNING
            sleep(0.1) # seconds
        end
    end
end

"""
    stepsim(time::Unitful.Quantity; block::Bool)
Step the simulation by the specified time. The first argument
must be convertable to a time value as understood by Unitful.
If the blocking keyword is `true`, then the function will loop while waiting
for the scheduler status to change to anything besides RUNNING.
```jldoctest
julia> stepsim(15.3u"s")
julia> stepsim(3.2u"minute")
julia> stepsim(1u"hr"; block=True)
```
"""
function stepsim(time::Unitful.Quantity{T, D, U}; block::Bool = false) where {T, D, U}
    time_in_seconds = ustrip(u"s", time)
    if length(size(time_in_seconds)) != 0
        # can this logic be improved?
        throw(ArgumentError("`time` is not a scalar. Dimension: $(size(time_in_seconds))"))
    end
    steps = floor(time_in_seconds * _base_sim_frequency)
    stepsim(Int64(steps); blocking = block)
end

"""
    endsim()
Ends/Halts the simulation. Drops all saved ModelInstances
as they have been consumed and have reached end of life.
"""
function endsim() :: Nothing
    # always present the capability to end the simulation
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
    global _base_sim_frequency
    if time < 0
        if time != -1
            throw(ArgumentError("Invalid duration specified: $time [s]"))
        end
    end
    settimelimit("__duration", time )
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
    getstoptime()
Get the maximum time set for the simulation
"""
function getstoptime()
    return gettimelimit("__duration") * u"s"
end

"""
    settimelimit(name::String, time::Real)
Sets an additional time limit restraint on the simulation.
This exists to support data logging primarily, but is extended
to the user as well. Ending a simulation clears these restraints.
```jldoctest
julia> settimelimit("GITLAB_CI_TIME_LIMIT", ENV["CI_TOKEN_DURATION"])
```
"""
function settimelimit(name::String, time::Real; warn::Bool = true) :: Nothing
    if warn && name in keys(_time_limits)
        @warn "Time limit for $name being overridden"
    end
    if time < 0
        throw(ArgumentError("Time limit $name: $time is negative"))
    end
    _time_limits[name] = time;
    return
end

function gettimelimit(name::String) :: Float64
    if name in keys(_time_limits)
        return _time_limits[name]
    else
        return -1
    end
end

"""
    register_scheduler_callback(cb::Function, priority::Int)
Registers a callback to call during initsim.

Used for allowing modules to create model on the fly.
"""
function register_scheduler_callback(cb::Function, priority::Int) :: Nothing
    global _callbacks
    if !(priority in keys(_callbacks))
        _callbacks[priority] = Vector{Function}()
    end
    push!(_callbacks[priority], cb);
    return
end

end
