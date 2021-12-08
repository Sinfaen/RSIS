

"""
Real-Time Simulation Scheduler Framework

Top level script that assembles all of the various underlying scripts
together into a single module.
"""
module RSIS

using DataStructures

using Unitful
using Unitful.DefaultSymbols

using TOML
using YAML

include("Logging.jl")
using .MLogging
export setlogfile, logmsg

include("RSIS_Lib.jl")
using .MLibrary
export getscheduler
export newmodel, deletemodel!, listmodels, listmodelsbytag, listlibraries
export ModelInstance
export simstatus, SchedulerState

include("Scripting.jl")
using .MScripting
export addfilepath, removefilepath, printfilepaths, where, search
export script, logscripts, printscriptlog

include("Project.jl") # pulls in MLogging, MScripting
using .MProject
export newproject, loadproject, projectinfo, build!, clean!
export getprojectdirectory, getprojectbuilddirectory

include("Model.jl") # pulls in MLogging, MProject, MScripting, MLibrary
using .MModel
export load, unload, listavailable
export structnames, structdefinition
export connect

include("InterfaceGeneration.jl")
using .MInterfaceGeneration
export generateinterface

include("Scheduling.jl")
using .MScheduling
export setthread, setnumthreads, threadinfo
export initsim, stepsim, endsim, setsimduration

include("Scenario.jl")
using .MScenario # pulls in MModel, MScripting
export scenario!, savescenario

include("SignalLogger.jl")
using .MSignalLogger
export logsignal, logsignalfile, listlogger

# final global variables

# ===

function __init__()
    LoadLibrary()
    nothing
end


"""
Launch RSIS GUI Window
"""
function gui()
    println("Not implemented")
end

end # module
