

"""
Real-Time Simulation Scheduler Framework

Top level script that assembles all of the various underlying scripts
together into a single module.
"""
module RSIS

using Artifacts

using TOML
using YAML
using CSV
using MsgPack

using DataStructures
using DataFrames

using Unitful
using Unitful.DefaultSymbols

using Logging

module MVersion
export versioninfo
function versioninfo()
    return "0.2.3" # what is a better option?
end
end

include("RSIS_Lib.jl")
using .MLibrary
export getscheduler
export newmodel, getmodel, deletemodel!, listmodels, listmodelsbytag, listlibraries
export ModelInstance
export simstatus, SchedulerState

include("Scripting.jl")
using .MScripting
export addfilepath, removefilepath, clearfilepaths, listfilepaths, where, search
export script, logscripts, printscriptlog

include("Defines.jl")
using .MDefines

include("Interface.jl")
using .MInterface

include("Model.jl") # pulls in MLogging, MScripting, MLibrary, MInterface
using .MModel
export load, unload, appsearch, describe
export structnames, structdefinition
export connect, listconnections
export addlibpath, clearlibpaths

include("Project.jl") # pulls in MLogging, MScripting, MModel
using .MProject
export newproject, loadproject, exitproject, projectinfo, projectlibname, build!, clean!
export getprojectdirectory, getprojectbuilddirectory, release

include("InterfaceGeneration.jl")
using .MInterfaceGeneration
export generateinterface

include("Events.jl")
using .MEvents
export clear_event_map, add_event_map

include("Scheduling.jl")
using .MScheduling
export setthread, setnumthreads, threadinfo, scheduleinfo
export initsim, stepsim, endsim, setstoptime, settimelimit
export getstoptime
export register_scheduler_callback

include("Scenario.jl")
using .MScenario # pulls in MModel, MScripting
export scenario!, savescenario

include("SignalIO.jl")
using .MSignalIO
export logsignal, logsignalfile, listlogged, getlogdata
export setlogfilelimit, generate_log_structures

# final global variables

# ===

function __init__() :: Nothing
    LoadLibrary()

    # Add callbacks for supported utilities
    register_scheduler_callback(generate_log_structures, 10)
end


"""
Launch RSIS GUI Window
"""
function gui()
    println("Not implemented")
end

end # module
