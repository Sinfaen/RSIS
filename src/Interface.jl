
module MInterface

using ..MDefines

export convert_julia_type, _gettype, _istypesupported, _type_default

struct InterfaceData
    rust::Union{Missing, String}
    cpp ::Union{Missing, String}
    fortran::Union{Missing, String}
    default::Any
end

_type_conversions = Dict{DataType, InterfaceData}(
    Char    => InterfaceData("char", "char", "character", ' '),
    String  => InterfaceData("String", "std::string", "character (len=:), allocatable", ""),
    Int8    => InterfaceData("i8",   "int8_t",  "integer (int8)",  0),
    Int16   => InterfaceData("i16",  "int16_t", "integer (int16)", 0),
    Int32   => InterfaceData("i32",  "int32_t", "integer (int32)", 0),
    Int64   => InterfaceData("i64",  "int64_t", "integer (int64)", 0),
    UInt8   => InterfaceData("u8",   "uint8_t",  missing, UInt8(0)),
    UInt16  => InterfaceData("u16",  "uint16_t", missing, UInt16(0)),
    UInt32  => InterfaceData("u32",  "uint32_t", missing, UInt32(0)),
    UInt64  => InterfaceData("u64",  "uint64_t", missing, UInt64(0)),
    Bool    => InterfaceData("bool", "bool", "logical", false),
    Float32 => InterfaceData("f32",  "float",  "real (real32)", 0),
    Float64 => InterfaceData("f64",  "double", "real (real64)", 0),
    Complex{Float32} => InterfaceData("Complex<f32>", "std::complex<float>",  "complex*8",  0+0im),
    Complex{Float64} => InterfaceData("Complex<f64>", "std::complex<double>", "complex*16", 0+0im)
)

# Create a string -> DataType mapping for all supported datatypes
_type_map = Dict([Pair("$(_type)", _type) for _type in keys(_type_conversions)])

function _istypesupported(name::String) :: Bool
    return name in keys(_type_map)
end

function _gettype(name::String) :: DataType
    if _istypesupported(name)
        return _type_map[name]
    else
        throw(ArgumentError("Primitive type: $name is not supported"))
    end
end

function _type_default(name::String) :: Any
    return _type_conversions[_type_map[name]]
end

function _julia_type(name::DataType, ProjectType::RUST)
    return _type_conversions[name].rust
end

function _julia_type(name::DataType, ProjectType::CPP)
    return _type_conversions[name].cpp
end

function _julia_type(name::DataType, ProjectType::FORTRAN)
    return _type_conversions[name].fortran
end

function convert_julia_type(juliatype::String, language::ProjectType) :: String
    if !(juliatype in keys(_type_map))
        return juliatype
    end
    t = _julia_type(_gettype(juliatype), language)
    if ismissing(t)
        throw(ErrorException("language $(language) does not support requested type $(juliatype)"))
    end
    return t
end

end
