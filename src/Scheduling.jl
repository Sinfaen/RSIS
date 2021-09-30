
module MScheduling
using ..MLibrary
using ..MModel

export setthread, setnumthreads, schedule, threadinfo
export initsim

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
    _verifyfrequencies();

    # create threads
    for (i,thread) in enumerate(_threads)
        addthread(float(thread.frequency))
        println("Thread $(i): $(Float64(thread.frequency)) Hz")
        # schedule models
        for model in thread.scheduled
            schedulemodel(model.ref, i, Int64(model.frequency / thread.frequency), model.offset)
        end
    end
    initscheduler()
    println("Simulation initialized")
end

end
