
module MLibrary
export LoadLibrary, UnloadLibrary

using Libdl

# globals
_lib = nothing # library pointer
_sym = nothing # symbol loading

mutable struct LibFuncs
    s_init
    s_shutdown
    s_setthread
    s_initscheduler
    s_pausescheduler
    s_runscheduler
    function LibFuncs(lib)
        new(Libdl.dlsym(lib, :RSISFramework_Initialize),
            Libdl.dlsym(lib, :RSISFramework_Shutdown),
            Libdl.dlsym(lib, :RSISFramework_SetThread),
            Libdl.dlsym(lib, :RSISFramework_InitScheduler),
            Libdl.dlsym(lib, :RSISFramework_PauseScheduler),
            Libdl.dlsym(lib, :RSISFramework_RunScheduler))
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

end
