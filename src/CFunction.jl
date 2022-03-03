#
# Creates models via C function pointers
module MCFunction

using ..MsgPack

export addjuliafunction

struct CFuncModel
    cfunc :: Ptr{Nothing}
end

"""
    Internal API
Creates structure that can be passed via the C-based API
"""
function juliamodel() :: Nothing
end

"""
    addjuliafunction(func, ret_type, arg_types, name)
Creates a model that executes a Julia function. The first three
arguments are passed directly to @cfunction. The last argument
represents the name as it will be recorded within RSIS. The returned
pointer is passed to the core scheduler.

As such, be VERY careful about defining global static variables within
the passed function. Read the official Julia documentation on embedding

The input arguments and output arguments are exposed to the RSIS framework.
```jldoctest
julia> using CRC32c
julia> function crc_func(ptr::Ptr{Cvoid}, length, base)::UInt32
           arr = unsafe_wrap(Array, ptr, length))
           return crc32u(arr, base)
       end
julia> @addjuliafunction(crc_func, UInt32, (Ptr{Cvoid}, Csize_t, UInt32), "crc1")
```
"""
macro addjuliafunction(func, ret_type, arg_types, name::String)
    return :( addcfunction(@cfunction(func, ret_type, arg_types)) )
end

end
