
module MScheduling
using ..MLibrary
using ..MModel

export setthread, setnumthreads, schedule
export initsim

mutable struct SModel
    ref::ModelReference
    frequency::Float64
    offset::Int64
end

mutable struct SThread
    scheduled::Vector{SModel}
    frequency::Float64
    cpuaffinity::Int32
    function SThread()
        new(Vector{SModel}(), -1.0, -1)
    end
end


# globals
_threads = Vector{SThread}()
push!(_threads, SThread())

function _resetthreads() :: Nothing
    _threads = Vector{SThread}()
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
end

"""
    schedule(model::ModelReference, frequency::Float64 = -1.0; offset::Int32 = 0, thread::Int = 1)
Schedule a model in the current scenario, with a specified frequency and offset
"""
function Base.:schedule(model::ModelReference, frequency::Float64 = -1.0; offset::Int64 = 0, thread::Int = 1)::Nothing
    if thread < 1 || thread > length(_threads)
        throw(ArgumentError("Invalid thread id"))
    end
    push!(_threads[thread].scheduled, SModel(model, frequency, offset));
    return
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
    println("Simulation initialized")
end

end
