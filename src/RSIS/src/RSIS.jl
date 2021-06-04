

"""
Real-Time Simulation Scheduler Framework

Functions:
    initsim, pausesim, runsim
"""
module RSIS

include("Logging.jl")
include("Scripting.jl")
include("SignalLogger.jl")
include("Model.jl")

# final global variables
_models = []
_connections = []

# ===


"""
Launch RSIS GUI Window
"""
function gui()
    println("Not implemented")
end

"""
RSIS

Perform initialization actions.
"""
function initsim()
    println("Not implemented")
end

function pausesim()
    println("Not implemented")
end

"""
RSIS

Run simulation.
"""
function runsim()
    println("Not implemented")
end

end # module
