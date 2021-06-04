
module Library
export LoadLibrary, UnloadLibrary

using Libdl

# globals
_lib = nothing
_sym = nothing

mutable struct LibFuncs
    s_init
    s_shutdown
    function LibFuncs(lib)
        new(Libdl.dlsym(lib, :RSISFramework_Initialize),
            Libdl.dlsym(lib, :RSISFramework_Shutdown))
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

function UnloadLibrary()
    global _lib
    if _lib !== nothing
        Libdl.dlclose(_lib)
        _lib = nothing
    end
    return
end

end
