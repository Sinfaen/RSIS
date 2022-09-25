#

module MInterfaceGeneration

using ..DataStructures
using ..Unitful
using ..YAML
using ..TOML
using ..MDefines
using ..MScripting
using ..MInterface
using ..MModel
using ..MProject

export generateinterface

# globals
_nlohmann_type_check = Dict(
    "Char"    => "is_string",
    "String"  => "is_string",
    "Int8"    => "is_number_integer",
    "Int16"   => "is_number_integer",
    "Int32"   => "is_number_integer",
    "Int64"   => "is_number_integer",
    "UInt8"   => "is_number_unsigned",
    "UInt16"  => "is_number_unsigned",
    "UInt32"  => "is_number_unsigned",
    "UInt64"  => "is_number_unsigned",
    "Csize_t" => "is_number_unsigned",
    "Cptrdiff_t" => "is_number_integer",
    "Bool"    => "is_boolean",
    "Float32" => "is_number_float",
    "Float64" => "is_number_float",
    "ComplexF32" => "is_number_float",
    "ComplexF64" => "is_number_float"
)

"""
Helper function for generateinterface
Used to create model files from relevant information
"""
function pushtexttofile(directory::String, model::String, words::Dict{String,String}, templates::Vector{Tuple{String, String}})
    key = r"({{(.*)}})"
    for template in templates
        path = joinpath(directory, model * template[1])
        f_file = open(path, "w")

        # read template
        temp = open(template[2], "r")
        for line in readlines(temp)
            # word substitution
            if occursin(key, line)
                copy = line
                matched = match(key, copy)
                copy = replace(copy, Regex(matched.captures[1]) => words[matched.captures[2]])
                write(f_file, copy)
            else
                write(f_file, line)
            end
            write(f_file, "\n")
        end

        close(temp)
        close(f_file)

        @info "Generated $path"
    end
end

function getValueFromYaml(etype::DataType, dimension::Tuple, obj::Any) :: Any
    if isempty(dimension) # scalar value
        if etype <: Complex
            if isa(obj, Vector) && length(obj) == 2
                try
                    return etype(obj[1], obj[2])
                catch e
                    throw(ErrorException("Failed to create complex value from $(obj). Message: $(e)"))
                end
            else
                throw(ErrorException("Unable to create complex value from $(obj)"))
            end
        else
            try
                return etype(obj)
            catch e
                throw(ErrorException("Failed to create $(etype) from provided value: $(obj). Message: $(e)"))
            end
        end
    else # arrays
        if !isa(obj, Vector)
            throw(ErrorException("Unable to create array values from provided initializer: $(obj)"))
        end
        if dimension == [-1]
            # handle 1D variable length arrays
            return [getValueFromYaml(etype, (), obj[i]) for i = 1:length(obj)]
        else
            # static N-Dimensional arrays
            if length(obj) != prod(dimension)
                throw(ErrorException("Array value $(obj) does not match expected dimension: $(dimension)"))
            end
            data = [getValueFromYaml(etype, (), obj[i]) for i = 1:length(obj)]
            return reshape(data, dimension...)
        end
    end
end

function ndarr_to_string_rowmajor(arr_1d::Array, dimension::Tuple, bracketl::Char, bracketr::Char, format::Function) :: String
    if length(dimension) == 1 # last axis
        return bracketl * join([format(a) for a in arr_1d], ",") * bracketr;
    else
        return bracketl * join([ndarr_to_string_rowmajor(arr_1d[ii, :], dimension[2:end], bracketl, bracketr, format) for ii in 1:dimension[1]], ",") * bracketr;
    end
end

function grabClassDefinitions(data::OrderedDict{String,Any},
                              modelname::String,
                              order::Vector{String},
                              definitions::Dict{String, Vector{Tuple{String, Port}} }) :: String
    if !haskey(definitions, modelname)
        definitions[modelname] = Vector{Tuple{String,Port}}()
    end
    if !(modelname in keys(data))
        throw(ErrorException("Class definition: $(model) not found!"))
    end
    model = data[modelname]
    if isnothing(model)
        return modelname
    end
    for field in model
        name = field.first
        if !isa(field.second, OrderedDict)
            throw(ErrorException("Non dictionary detected"))
        end
        _keys = keys(field.second)
        if "class" in _keys
            dims = []
            if "dims" in _keys
                dims = field.second["dims"]
            end
            if !isa(dims, Vector)
                throw(ErrorException("Dimension specified for composite $(field.first) is not a list"))
            end
            desc = ""
            if "desc" in _keys
                desc = field.second["desc"]
            end
            composite = Port(field.second["class"], Tuple(dims), "", true; note=desc)
            push!(definitions[modelname], (field.first, composite))
            newmodelname = grabClassDefinitions(data, field.second["class"], order, definitions)
            push!(order, newmodelname)
        elseif "type" in _keys
            # this is a regular port. Dimensions
            dims = []
            if "dims" in _keys
                dims = field.second["dims"]
            end
            if !isa(dims, Vector)
                throw(ErrorException("Dimension specified for field $(field.first) is not a list"))
            end
            isscalar = dims == []
            variablelength = dims == [-1] # check for variable 1D arrays

            unit=""
            if "unit" in _keys
                u = field.second["unit"]
                try
                    unit = uparse(u)
                catch e
                    if isa(e, ArgumentError)
                        throw(ErrorException("Unit: $(u) for field $(field.first) is not defined"))
                    else
                        throw(e) # rethrow error
                    end
                end
            end

            # default value
            initial = _type_default(field.second["type"]).default
            _type = _gettype(field.second["type"])
            if !isscalar # array value
                if variablelength
                    initial = _type[]
                else
                    A = zeros(_type, Tuple(dims))
                    fill!(A, initial)
                    initial = A
                end
            end
            if "value" in _keys
                # Check that the value is the correct type,size, or is convertible
                # call the vector function wrapper
                initial = getValueFromYaml(_type, Tuple(dims), field.second["value"])
            end
            desc = ""
            if "desc" in _keys
                desc = field.second["desc"]
            end

            meta = Set{String}()
            if "opts" in _keys
                _opts = field.second["opts"]
                if isa(_opts, Vector)
                    meta = Set{String}(_opts)
                else
                    push!(meta, _opts)
                end
            end

            port = Port(field.second["type"], Tuple(dims), unit, false; note=desc, porttype=PORT, default=initial, meta=meta)
            push!(definitions[modelname], (field.first, port))
        else
            throw(ErrorException("Invalid model interface"))
        end
    end
    return modelname
end

"""
    generateinterface(interface::String; language::String = "")
Generate a model interface from the specified interface file. Rust, C++,
and Fortran model interfaces can be generated. The generated files
are put in the same location as the interface file.
```jldoctest
julia> generateinterface("mymodel.yml") # interface = "cpp"
[Info: Generated mymodel_interface.hxx
[Info: Generated mymodel_interface.cxx
[Info: Generation complete
julia> generateinterface("mymodel.yml"; interface = "rust")
[Info: Generated mymodel_interface.rs
[Info: Generation complete
julia> generateinterface("mymodel.yml"; interface = "fortran")
[Info: Generated mymodel_interface.f90
[Info: Generation complete
```
"""
function generateinterface(interface::String; language::String = "")
    templates = Vector{Tuple{String, String}}()
    if language == ""
        language = "$(projecttype())"
    end
    if language == "cpp"
        _language = CPP()
        push!(templates, ("_interface.hxx", joinpath(@__DIR__, "templates", "header_cpp.template")))
        push!(templates, ("_interface.cxx", joinpath(@__DIR__, "templates", "source_cpp.template")))
    elseif language == "rust"
        _language = RUST()
        push!(templates, ("_interface.rs", joinpath(@__DIR__, "templates", "rust.template")))
    elseif language == "fortran"
        _language = FORTRAN()
        push!(templates, ("_interface.f90", joinpath(@__DIR__, "templates", "f90.template")))
    else
        error(ArgumentError("[\"rust\",\"cpp\",\"fortran\"] are the only valid language options"))
    end
    words = Dict{String, String}()

    path_interface = search(interface)
    if length(path_interface) == 0
        throw(ErrorException("Unable to find interface file: $interface"))
    end

    data = YAML.load_file(path_interface[1], dicttype=OrderedDict{String,Any})
    if !("model" in keys(data))
        throw(ErrorException("The `model` element was not found. Aborting"))
    end

    # iterate through expected members, and grab data
    # recurse through each member
    class_order = Vector{String}()
    class_defs  = Dict{String, Vector{Tuple{String, Port}}}()
    grabClassDefinitions(data, data["model"], class_order, class_defs)
    push!(class_order, data["model"])

    base_dir   = dirname(path_interface[1])
    model_name = splitext(interface)[1]

    metadata = Dict{String, Any}()
    metadata["rsis"] = Dict("name" => data["model"], "type" => language)

    # create text
    if language == "cpp"
        words["HEADER_GUARD"] = uppercase(model_name)
        words["HEADER_FILE"]  = "$(model_name)_interface.hxx"
        words["MODEL_FILE"]   = "$(data["model"]).hxx"
        hxx_text = ""
        cxx_text = ""
        d_text = ""
        s_text = ""
        p_text = ""
        for name in class_order
            fields = class_defs[name]
            htext = "class $(name) {\n" *
                    "public:\n" *
                    "    $name();\n" *
                    "    virtual ~$name();\n";
            ctext = "$name::$name()"
            if length(fields) != 0
                ctext = ctext * " : "
            end
            first = true;
            for (n,f) in fields
                if (-1,) == f.dimension
                    if f.iscomposite
                        throw(ErrorException("Vector cannot contain structs for now"))
                    end
                    htext = htext * "    std::vector<$(convert_julia_type(f.type, _language))> $n"
                else
                    htext = htext * "    $(convert_julia_type(f.type, _language)) $n"
                    if length(f.dimension) != 0
                        htext = htext * "[$(join(f.dimension, "]["))]"
                    end
                end
                htext = htext * "; // $(f.note) \n"
                if first
                    first = false;
                else
                    ctext = ctext * ", "
                end
                if f.iscomposite
                    ctext = ctext * "$n()"
                else
                    if length(f.dimension) == 0
                        ctext = ctext * "$n($(_print_value_cpp(f.defaultvalue)))"
                    else # c++11 supports initializer lists for vectors
                        ctext = ctext * "$n$(ndarr_to_string_rowmajor(f.defaultvalue, size(f.defaultvalue), '{', '}', _print_value_cpp))"
                    end
                end
            end
            htext = htext * "};\n"
            ctext = ctext * "{ }\n$name::~$name() { }\n"
            hxx_text = hxx_text * htext;
            cxx_text = cxx_text * ctext;

            # generate meta access code
            metadata[name] = Dict{String, Any}()
            stxt = "bytes s_$(name)(const $(name)& obj, std::vector<uint32_t>::iterator& it, std::vector<uint32_t>::iterator& end, bool& error) {\n    if (it == end) { error = true; return bytes(); }\n    switch (*it++) {\n"
            dtxt = "bool d_$(name)($(name)& obj, std::vector<uint32_t>::iterator& it, bytes& data, std::vector<uint32_t>::iterator& end) {\n    if (it == end) { return false; }\n    switch (*it++) {\n"
            ptxt = "std::optional<uint8_t*> p_$(name)(const $(name)& obj, std::vector<uint32_t>::iterator& it, std::vector<uint32_t>::iterator& end) {\n    if (it == end) { return {}; }\n    switch (*it++) {\n"
            for (ii, (n, f)) in enumerate(fields)
                stxt = stxt * "        case $(ii - 1): "
                dtxt = dtxt * "        case $(ii - 1): "
                ptxt = ptxt * "        case $(ii - 1): "
                cpptype = convert_julia_type(f.type, _language)
                if f.iscomposite
                    # serialization
                    stxt = stxt * "{ return s_$(f.type)(obj.$(n), it, end, error); }\n"
                    # deserialization
                    dtxt = dtxt * "{ return d_$(f.type)(obj.$(n), it, data, end); }\n"
                    # pointer
                    ptxt = ptxt * "{ return p_$(f.type)(obj.$(n), it, end); }\n"
                    metadata[name][n] = Dict("id" => ii - 1, "class" => f.type)
                else
                    # serialization
                    if (-1,) == f.dimension || length(f.dimension) == 0 || length(f.dimension) == 1
                        stxt = stxt * "{ json v = obj.$(n); return json::to_msgpack(v); }\n"
                    else # multidimensional arrays
                        stxt = stxt * "{ $(cpptype)(&a)[$(prod(f.dimension))] = ($(cpptype)(&)[$(prod(f.dimension))])obj.$(n); "
                        stxt = stxt * "json v; for(auto it = std::begin(a); it != std::end(a); ++it) { v.push_back(json(*it)); } return json::to_msgpack(v); }\n"
                    end
                    # deserialization
                    dtxt = dtxt * "{ json j = json::from_msgpack(data);\n"
                    if (-1,) == f.dimension
                        dtxt = dtxt * "            if (!j.is_array()) { return false; } obj.$(n).clear(); \n"
                        dtxt = dtxt * "            for (auto& element : j) {\n"
                        dtxt = dtxt * "                if (!element.$(_nlohmann_type_check[f.type])()) { return false; }\n"
                        dtxt = dtxt * "                obj.$(n).push_back(element.get<$(cpptype)>()); return true;\n            }\n        }\n"
                    elseif length(f.dimension) == 0
                        dtxt = dtxt * "            if (!j.is_primitive() || !j.$(_nlohmann_type_check[f.type])()) { return false; }\n" 
                        dtxt = dtxt * "            obj.$(n) = j.get<$(cpptype)>(); return true;\n        }\n"
                    else # multidimensional arrays
                        dtxt = dtxt * "            if (!j.is_array() || j.size() != $(prod(f.dimension))) { return false; }\n"
                        dtxt = dtxt * "            for (int i = 0; i < $(prod(f.dimension)); ++i) {\n"
                        dtxt = dtxt * "                if (!j[i].$(_nlohmann_type_check[f.type])()) { return false; }\n"
                        dtxt = dtxt * "                (($(cpptype)*)obj.$(n))[i] = j[i].get<$(cpptype)>(); return true;\n            }\n        }\n"
                    end
                    # pointer
                    if (-1,) == f.dimension
                        ptxt = ptxt * "{ return (uint8_t*) obj.$(n).data(); }\n"
                    else
                        ptxt = ptxt * "{ return (uint8_t*) &obj.$(n); }\n"
                    end
                    metadata[name][n] = Dict("id" => ii - 1, "type" => f.type, "dims" => collect(f.dimension), "unit" => "$(f.units)")
                end
            end
            stxt = stxt * "        default:\n            error = true; return bytes();\n"
            stxt = stxt * "    }\n}\n"
            dtxt = dtxt * "        default: return false;\n    }\n}\n"
            ptxt = ptxt * "        default: return {};\n    }\n}\n"
            s_text = s_text * stxt;
            d_text = d_text * dtxt;
            p_text = p_text * ptxt;
        end
        words["CLASS_DEFINES"]     = hxx_text
        words["CLASS_DEFINITIONS"] = cxx_text
        words["SERIALIZATION"] = s_text
        words["DESERIALIZATION"] = d_text
        words["POINTER"] = p_text
    else
        rs_text = ""
        cs_text = ""
        d_text = ""
        s_text = ""
        p_text = ""
        # generate constructors & structs
        for name in class_order
            fields = class_defs[name]
            txt = "#[repr(C)]\npub struct $(name) {\n"
            cs  = "impl $(name) {\n    pub fn new() -> $(name) {\n        $(name) {\n"
            for (n,f) in fields
                if length(f.dimension) == 0 # scalar
                    txt = txt * "    pub $n : $(convert_julia_type(f.type, _language)),\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : $(f.type)::new(),\n"
                    else
                        cs = cs * "            $(n) : $(_print_value_rust(f.defaultvalue)),\n"
                    end
                elseif f.dimension[1] == -1 # variable length one dimensional array
                    txt = txt * "    pub $n : Vec<$(convert_julia_type(f.type, _language))>,\n"
                    if f.iscomposite
                        throw(ErrorException("Variable length arrays cannot be structs"))
                    end
                    cs = cs * "            $(n) : vec!($(join([_print_value_rust(d) for d in f.defaultvalue], ", "))),\n"
                # fixed size array, simple version. Strings shortcut to this as well
                # Multidimensional arrays are flattened
                elseif "simplearray" in f.meta
                    nelements = prod(f.dimension)
                    txt = txt * "    pub $n : [$(convert_julia_type(f.type, _language)); $(nelements)],\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : [$(join(["$(n)::new()" for d in 1:nelements], ", "))],\n"
                    else
                        cs = cs * "            $(n) : [$(join([_print_value_rust(d) for d in f.defaultvalue], ", "))],\n"
                    end
                # fixed size array, n-dimensional version
                else
                    txt = txt * "    pub $n : Array<$(convert_julia_type(f.type, _language)), ndarray::Ix$(length(f.dimension))>,\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : [$(join(["$(n)::new()" for d in f.dimension], ", "))],\n"
                    else
                        cs = cs * "            $(n) : array!" * ndarr_to_string_rowmajor(f.defaultvalue, size(f.defaultvalue), '[', ']', _print_value_rust) * ",\n"
                    end
                end
            end
            txt = txt * "}\n"
            rs_text = rs_text * txt
            cs  = cs  * "        }\n    }\n}\n"
            cs_text = cs_text * cs

            # generate meta access code
            metadata[name] = Dict{String, Any}()
            stxt = "pub fn s_$(name)(obj : &$(name), mut ii : Iter<'_, u32>) -> Result<Vec<u8>, rmp_serde::encode::Error> {\n    match ii.next() {\n"
            dtxt = "pub fn d_$(name)(obj : &mut $(name), mut ii : Iter<'_, u32>, data : &[u8]) -> Option<rmp_serde::decode::Error> {\n    match ii.next() {\n"
            ptxt = "pub fn p_$(name)(obj : &$(name), mut ii : Iter<'_, u32>) -> Option<*const u8> {\n    match ii.next() {\n"
            d_any_non_composite = false
            for (ii, (n, f)) in enumerate(fields)
                stxt = stxt * "        Some($(ii - 1)) => return "
                dtxt = dtxt * "        Some($(ii - 1)) => "
                ptxt = ptxt * "        Some($(ii - 1)) => return "
                if f.iscomposite
                    # serialization
                    stxt = stxt * "s_$(f.type)(&obj.$(n), ii),\n"
                    # deserialization
                    dtxt = dtxt * "return d_$(f.type)(&mut obj.$(n), ii, data),\n"
                    # pointer
                    ptxt = ptxt * "p_$(f.type)(&obj.$(n), ii),\n"
                    metadata[name][n] = Dict("id" => ii - 1, "class" => f.type)
                else
                    # serialization
                    if length(f.dimension) != 0 && !("simplearray" in f.meta)
                        stxt = stxt * "rmp_serde::to_vec(&obj.$(n).as_slice()),\n"
                    else
                        stxt = stxt * "rmp_serde::to_vec(&obj.$(n)),\n"
                    end
                    # deserialization
                    dtxt = dtxt * "{\n            match rmp_serde::decode::from_read(data) {\n" 
                    dtxt = dtxt * "                Ok(val) => obj.$(n) = val,\n"
                    dtxt = dtxt * "                Err(e) => return Some(e),\n            }\n        },\n"
                    d_any_non_composite = true
                    # pointer
                    if (-1,) == f.dimension || (length(f.dimension) != 0 && !("simplearray" in f.meta))
                        # variable length array & multidimensional arrays
                        ptxt = ptxt * "Some(obj.$(n).as_ptr() as *const u8),\n"
                    else
                        ptxt = ptxt * "Some(std::ptr::addr_of!(obj.$(n)) as *const u8),\n"
                    end
                    metadata[name][n] = Dict("id" => ii - 1, "type" => f.type, "dims" => collect(f.dimension), "unit" => "$(f.units)")
                end
            end
            stxt = stxt * "        _ => return Err(rmp_serde::encode::Error::Syntax(\"Invalid index\".to_string())),\n    }\n}\n"
            s_text = s_text * stxt;

            dtxt = dtxt * "        _ => return Some(rmp_serde::decode::Error::Syntax(\"Invalid index\".to_string())),\n"
            if d_any_non_composite
                dtxt = dtxt * "    }\n    None\n}\n"
            else
                dtxt = dtxt * "    }\n}\n"
            end
            d_text = d_text * dtxt;

            ptxt = ptxt * "        _ => return None,\n    }\n}\n"
            p_text = p_text * ptxt;
        end
        words["STRUCT_DEFINITIONS"] = rs_text
        words["CONSTRUCTOR_DEFINITIONS"] = cs_text
        words["SERIALIZATION"] = s_text
        words["DESERIALIZATION"] = d_text
        words["POINTER"] = p_text
    end
    words["NAME"] = data["model"]
    open(joinpath([base_dir, "$(projectlibname()).meta"]), "w") do io
        TOML.print(io, metadata)
    end

    pushtexttofile(base_dir, model_name, words, templates)

    @info "Generation complete"
    return
end

end
