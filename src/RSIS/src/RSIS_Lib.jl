
module MLibrary
using Base: Int32
export LoadLibrary, UnloadLibrary, InitLibrary, ShutdownLibrary
export getscheduler

using Libdl

# globals
_lib = nothing # library pointer
_sym = nothing # symbol loading
_models = Dict{String, Any}()

@enum RSISCmdStat::Int32 begin
    OK  = 0
    ERR = 1
end

mutable struct LibFuncs
    s_init
    s_shutdown
    s_setthread
    s_initscheduler
    s_pausescheduler
    s_runscheduler
    s_getmessage
    s_getschedulername
    function LibFuncs(lib)
        new(Libdl.dlsym(lib, :RSISFramework_Initialize),
            Libdl.dlsym(lib, :RSISFramework_Shutdown),
            Libdl.dlsym(lib, :RSISFramework_SetThread),
            Libdl.dlsym(lib, :RSISFramework_InitScheduler),
            Libdl.dlsym(lib, :RSISFramework_PauseScheduler),
            Libdl.dlsym(lib, :RSISFramework_RunScheduler),
            Libdl.dlsym(lib, :RSISFramework_GetMessage),
            Libdl.dlsym(lib, :RSISFramework_GetSchedulerName))
    end
end

mutable struct LibModel
    s_lib
    s_createmodel
    function LibModel(libfile::String)
        lib = Libdl.dlopen(libfile)
        new(lib,
            Libdl.dlsym(lib, :CreateModel))
    end
end

"""
    LoadLibrary()
Load the RSIS shared library
"""
function LoadLibrary()
    global _lib
    global _sym
    libpath = joinpath(@__DIR__, "..", "install", "lib", "librsis.dylib")
    _lib = Libdl.dlopen(libpath)
    _sym = LibFuncs(_lib)
    InitLibrary(_sym)
    return
end

"""
    UnloadLibrary()
Unload the RSIS shared library
"""
function UnloadLibrary()
    global _lib
    if _lib !== nothing
        Libdl.dlclose(_lib)
        _lib = nothing
        _sym = nothing
    end
    return
end

function LoadModelLib(name::String, filename::String)
    global _models
    if !(name in keys(_models))
        _models[name] = LibModel(filename)
    end
end

function UnloadModelLib(name::String)
    global _models
    if name in keys(_models)
        Libdl.dlclose(_models[name].s_lib)
        delete!(_models, name)
    end
end

function InitLibrary(symbols::LibFuncs)
    #
    stat = ccall(symbols.s_init, UInt8, ())
    if stat ≠ 1
        error("Failed to initialize library");
    end
end

function ShutdownLibrary(symbols::LibFuncs)
    #
    stat = ccall(symbols.s_shutdown, UInt8, ())
    if stat ≠ 1
        error("Failed to shutdown library");
    end
end

function getscheduler()
    global _sym
    stat = ccall(_sym.s_getschedulername, RSISCmdStat, ())
    if stat ≠ OK
        error("Failed to grab scheduler name")
    end
    msgptr = ccall(_sym.s_getmessage, Cstring, ())
    println(unsafe_string(msgptr))
end

end
