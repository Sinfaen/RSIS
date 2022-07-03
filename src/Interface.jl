
module MInterface

using ..MDefines

export convert_julia_type, _gettype, _istypesupported, _type_default

struct InterfaceData
    type::DataType
    rust::Union{Missing, String}
    cpp ::Union{Missing, String}
    fortran::Union{Missing, String}
    default::Any
end

_type_conversions = Dict{String, InterfaceData}(
    "Char"    => InterfaceData(Char, "char", "char", "character", ' '),
    "String"  => InterfaceData(String, "String", "std::string", "character (len=:), allocatable", ""),
    "Int8"    => InterfaceData(Int8, "i8",   "int8_t",  "integer (int8)",  0),
    "Int16"   => InterfaceData(Int16, "i16",  "int16_t", "integer (int16)", 0),
    "Int32"   => InterfaceData(Int32, "i32",  "int32_t", "integer (int32)", 0),
    "Int64"   => InterfaceData(Int64, "i64",  "int64_t", "integer (int64)", 0),
    "UInt8"   => InterfaceData(UInt8, "u8",   "uint8_t",  missing, UInt8(0)),
    "UInt16"  => InterfaceData(UInt16, "u16",  "uint16_t", missing, UInt16(0)),
    "UInt32"  => InterfaceData(UInt32, "u32",  "uint32_t", missing, UInt32(0)),
    "UInt64"  => InterfaceData(UInt64, "u64",  "uint64_t", missing, UInt64(0)),
    "Csize_t" => InterfaceData(Csize_t, "usize", "std::size_t", missing, Csize_t(0)),
    "Cptrdiff_t" => InterfaceData(Cptrdiff_t, "isize", "std::ptrdiff_t", missing, Cptrdiff_t(0)),
    "Bool"    => InterfaceData(Bool, "bool", "bool", "logical", false),
    "Float32" => InterfaceData(Float32, "f32",  "float",  "real (real32)", 0),
    "Float64" => InterfaceData(Float64, "f64",  "double", "real (real64)", 0),
    "Complex{Float32}" => InterfaceData(Complex{Float32}, "Complex<f32>", "std::complex<float>",  "complex*8",  0+0im),
    "Complex{Float64}" => InterfaceData(Complex{Float64}, "Complex<f64>", "std::complex<double>", "complex*16", 0+0im)
)

function _istypesupported(name::String) :: Bool
    return name in keys(_type_conversions)
end

function _gettype(name::String) :: DataType
    if _istypesupported(name)
        return _type_conversions[name].type
    else
        throw(ArgumentError("Primitive type: $name is not supported"))
    end
end

function _type_default(name::String) :: Any
    return _type_conversions[name]
end

function _julia_type(name::String, ProjectType::RUST)
    return _type_conversions[name].rust
end

function _julia_type(name::String, ProjectType::CPP)
    return _type_conversions[name].cpp
end

function _julia_type(name::String, ProjectType::FORTRAN)
    return _type_conversions[name].fortran
end

function convert_julia_type(juliatype::String, language::ProjectType) :: String
    if !(juliatype in keys(_type_conversions))
        return juliatype
    end
    t = _julia_type(juliatype, language)
    if ismissing(t)
        throw(ErrorException("language $(language) does not support requested type $(juliatype)"))
    end
    return t
end

end
