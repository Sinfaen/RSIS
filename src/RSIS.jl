

"""
Real-Time Simulation Scheduler Framework

Top level script that assembles all of the various underlying scripts
together into a single module.
"""
module RSIS

using TOML
using YAML
using CSV

using DataStructures
using DataFrames

using Unitful
using Unitful.DefaultSymbols

using Logging

include("Logging.jl")
using .MLogging

include("RSIS_Lib.jl")
using .MLibrary
export getscheduler, libraryinfo
export newmodel, getmodel, deletemodel!, listmodels, listmodelsbytag, listlibraries
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

include("Interface.jl")
using .MInterface

include("Model.jl") # pulls in MLogging, MProject, MScripting, MLibrary
using .MModel
export load, unload, listavailable
export structnames, structdefinition
export connect, listconnections
export addlibpath, clearlibpaths

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
export logsignal, logsignalfile, listlogged

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
