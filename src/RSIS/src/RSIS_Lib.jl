
module MLibrary
using Base: Int32
export LoadLibrary, UnloadLibrary, InitLibrary, ShutdownLibrary
export getscheduler

using Libdl

# globals
_lib = nothing # library pointer
_sym = nothing # symbol loading

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

"""
    LoadLibrary()
Load the RSIS shared library
"""
function LoadLibrary()
    global _lib
    global _sym
    _lib = Libdl.dlopen("librsis.dylib")
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
