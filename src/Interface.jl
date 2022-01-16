
module MInterface

export convert_julia_type, _gettype, _istypesupported

# DataType => [Rust datatype, C++ datatype, Fortran datatype]
_type_conversions = Dict{DataType, Vector{Union{Missing,String}}}(
    Char    => ["char", "char", "character"],
    String  => ["String", "std::string", "character (len=:), allocatable"],
    Int8    => ["i8",   "int8_t",  "integer (int8)"],
    Int16   => ["i16",  "int16_t", "integer (int16)"],
    Int32   => ["i32",  "int32_t", "integer (int32)"],
    Int64   => ["i64",  "int64_t", "integer (int64)"],
    UInt8   => ["u8",   "uint8_t",  missing],
    UInt16  => ["u16",  "uint16_t", missing],
    UInt32  => ["u32",  "uint32_t", missing],
    UInt64  => ["u64",  "uint64_t", missing],
    Bool    => ["bool", "bool", "logical"],
    Float32 => ["f32",  "float",  "real (real32)"],
    Float64 => ["f64",  "double", "real (real64)"],
    Complex{Float32} => ["Complex<f32>", "std::complex<float>",  "complex*8"],
    Complex{Float64} => ["Complex<f64>", "std::complex<double>", "complex*16"]
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

function convert_julia_type(juliatype::String, language::String = "rust") :: String
    if !(juliatype in keys(_type_map))
        return juliatype
    end
    t = missing
    if language == "rust"
        t = _type_conversions[_type_map[juliatype]][1]
    elseif language == "cpp"
        t = _type_conversions[_type_map[juliatype]][2]
    elseif language == "fortran"
        t = _type_conversions[_type_map[juliatype]][3]
    else
        throw(ArgumentError("language must be [\"rust\",\"cpp\"]"))
    end
    if ismissing(t)
        throw(ErrorException("language $(language) does not support requested type $(juliatype)"))
    end
    return t
end

end
