#
# Creates apps/models via C function pointers & arg types
# - Useful for defining glue code (unit conversion, simple signals, etc)
module MCFunction

using ..MsgPack
using ..MLibrary

export addjuliaapp

"""
    Define information necessary for an app defined with a pure C pointer
    Supporting julia functions
"""
mutable struct JuliaAppData
    func      :: Function       # julia function being used
    cfunc     :: Ptr{Nothing}   # Pointer to compiled code
    ret_type  :: DataType       # Return data type
    arg_types :: Tuple{DataType}# Argument data types
    rmemory   :: Ref            # Memory for return value
    rmemptr   :: Ptr            # Return argument pointer
    amemory   :: Vector{Ref}    # Memory for function arguments
    amemptr   :: Vector{Ptr}    # Stores pointers to the instantiated arguments
    function JuliaAppData(func::Function, ret_type::DataType, arg_types::Tuple{DataType})
        # create expression for calling cfunction macro, and step pointer
        # not strictly necessary, but works as early type checking
        ex = :(@cfunction $func $ret_type ($(arg_types...),) )
        step_ptr = eval(macroexpand(Main, ex))

        # return value
        rmem = Ref(zero(ret_type))
        rmptr = Base.unsafe_convert(Ptr{ret_type}, rmem)

        # arguments
        amemory = Vector{Ref}()
        amemptr = Vector{Ptr}()
        for arg in arg_types
            push!(amemory, Ref(zero(arg)))
            push!(amemptr, Base.unsafe_convert(Ptr{arg}, last(amemory)))
        end

        new(func, step_ptr, ret_type, arg_types, rmem, rmptr, amemory, amemptr)
    end
end

function call_julia_func(ptr::Ptr{Cvoid}) :: UInt32
    data = unsafe_pointer_to_objref(Base.unsafe_convert(Ptr{JuliaAppData}, ptr))
    args = Tuple(Base.unsafe_load(p) for p in data.amemory)
    data.rmemory[] = data.func(args...) # call function directly and store result
    return 0 # OK
end

function MLibrary.:capp_getnmeta(obj::JuliaAppData, ptype::SignalTypes) :: Int
    if ptype == INPUT
        return length(obj.amemory)
    elseif ptype == OUTPUT
        return 1
    else
        return 0
    end
end

function MLibrary.:capp_getmeta(obj::JuliaAppData, ptype::SignalTypes, port::Int) :: Tuple{DataType, Tuple, Ptr}
    if ptype == INPUT
        if port > length(obj.amemory) || port < 0
            throw(BoundsError(obj.amemory, port))
        end
        return (obj.arg_types[port], (), obj.amemptr[port])
    elseif ptype == OUTPUT
        if port != 1
            @warn "Return data "
        end
        return (obj.ret_type, (), obj.rmemptr)
    else
        throw(ArgumentError("julia functions do not define other kinds of data"))
    end
end

_julia_apps = Dict{String, JuliaAppData}()

function do_nothing(_obj::Ptr{Cvoid}) :: UInt32
    # this function does absolutely nothing
    return 0 # OK
end

function is_type_allowed(name::DataType)
    if name <: Signed || name <: Unsigned
        return true
    end
    if name <: AbstractFloat || name <: Complex
        return true
    end
    if name == Bool || name == Char
        return true
    end
    return false
end

"""
    addjuliaapp(func, ret_type, arg_types, name)
Creates a model that executes a Julia function. The first three
arguments are passed directly to @cfunction. The last argument
represents the name as it will be recorded within RSIS. The returned
pointer is passed to the core scheduler.

Only POD data types are supported.

Be VERY careful about defining global static variables within
the passed function. Read the official Julia documentation on embedding

The input arguments and output arguments are exposed to the RSIS framework.
```jldoctest
julia> using CRC32c
julia> function crc_func(ptr::Ptr{Cvoid}, length, base)::UInt32
           arr = unsafe_wrap(Array, ptr, length))
           return crc32u(arr, base)
       end
julia> addjuliaapp(crc_func, UInt32, (Ptr{Cvoid}, Csize_t, UInt32), "crc1")
julia> func = x -> x^2 + 2x - 1
julia> addjuliaapp(func, Float64, (Float64,), "lambda function")
```
"""
function addjuliaapp(func::Function, ret_type, arg_types, name::String)
    # Check return type
    if !is_type_allowed(ret_type)
        throw(ErrorException("Invalid return type: $(ret_type)"))
    end

    # Check argument types
    for arg in arg_types
        if !is_type_allowed(arg)
            throw(ErrorException("Invalid argument type: $(arg)"))
        end
    end

    # used for config, init, pause, stop, and destructor
    do_nothing_ptr = @cfunction do_nothing UInt32 (Ptr{Cvoid},)

    # assemble the memory & pointers needed to store the input arguments and return value
    data = JuliaAppData(func, ret_type, arg_types)

    wrap_fcn = @cfunction call_julia_func UInt32 (Ptr{Cvoid},)

    # store metadata
    _julia_apps[name] = data

    # create closures to return metadata

    # call into MLibrary to call into the scheduler
    return addcapp(name,
        ["juliafunction"],
        pointer_from_objref(data),
        do_nothing_ptr, do_nothing_ptr,
        wrap_fcn, # the important one
        do_nothing_ptr, do_nothing_ptr, do_nothing_ptr, data)
end

end
