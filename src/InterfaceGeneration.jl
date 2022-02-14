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
    "Bool"    => "is_boolean",
    "Float32" => "is_number_float",
    "Float64" => "is_number_float",
    "Complex{Float32}" => "is_number_float",
    "Complex{Float64}" => "is_number_float"
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
            # this is a regular port
            dims = []
            if "dims" in _keys
                dims = field.second["dims"]
            end
            if !isa(dims, Vector)
                throw(ErrorException("Dimension specified for field $(field.first) is not a list"))
            end
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
            initial = _type_default(field.second["type"])
            if "value" in _keys
                initial = field.second["value"]
            end
            desc = ""
            if "desc" in _keys
                desc = field.second["desc"]
            end

            port = Port(field.second["type"], Tuple(dims), unit, false; note=desc, porttype=PORT, default=initial)
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
                htext = htext * "    $(convert_julia_type(f.type, _language)) $n"
                if length(f.dimension) != 0
                    htext = htext * "[$(join(f.dimension, "]["))]"
                end
                htext = htext * "; // $(f.note) \n"
                if first
                    first = false;
                else
                    ctext = ctext * ", "
                end
                if f.iscomposite
                    ctext = ctext * "$n()"
                elseif f.type == "String"
                    ctext = ctext * "$n(\"$(f.defaultvalue)\")"
                else
                    if length(f.dimension) == 0
                        ctext = ctext * "$n($(f.defaultvalue))"
                    else
                        ctext = ctext * "$n{$(join([d for d in f.defaultvalue], ", "))}"
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
                    stxt = stxt * "{ json v = obj.$(n); return json::to_msgpack(v); }\n"
                    # deserialization
                    dtxt = dtxt * "{ json j = json::from_msgpack(data);\n"
                    if length(f.dimension) == 0
                        dtxt = dtxt * "            if (!j.is_primitive() || !j.$(_nlohmann_type_check[f.type])()) { return false; }\n" 
                        dtxt = dtxt * "            obj.$(n) = j.get<$(convert_julia_type(f.type, _language))>(); return true;\n        }\n"
                    else # static 1D arrays only for now
                        dtxt = dtxt * "            if (!j.is_array() || j.size() != $(f.dimension[1])) { return false; }\n"
                        dtxt = dtxt * "            for (int i = 0; i < $(f.dimension[1]); ++i) {\n"
                        dtxt = dtxt * "                if (!j[i].$(_nlohmann_type_check[f.type])()) { return false; }\n"
                        dtxt = dtxt * "                obj.$(n)[i] = j[i].get<$(convert_julia_type(f.type, _language))>(); return true;\n            }\n        }\n"
                    end
                    # pointer
                    ptxt = ptxt * "{ return (uint8_t*) &obj.$(n); }\n"
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
                if length(f.dimension) == 0
                    txt = txt * "    pub $n : $(convert_julia_type(f.type, _language)),\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : $(f.type)::new(),\n"
                    elseif f.type == "String"
                        cs = cs * "            $(n) : \"$(f.defaultvalue)\".to_string(),\n"
                    else
                        cs = cs * "            $(n) : $(f.defaultvalue),\n"
                    end
                else
                    txt = txt * "    pub $n : [$(convert_julia_type(f.type, _language)); $(join(f.dimension, ","))],\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : [$(join(["$(n)::new()" for d in f.dimension], ", "))],\n"
                    else
                        cs = cs * "            $(n) : [$(join([d for d in f.defaultvalue], ", "))],\n"
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
                    stxt = stxt * "rmp_serde::to_vec(&obj.$(n)),\n"
                    # deserialization
                    dtxt = dtxt * "{\n            match rmp_serde::decode::from_read(data) {\n" 
                    dtxt = dtxt * "                Ok(val) => obj.$(n) = val,\n"
                    dtxt = dtxt * "                Err(e) => return Some(e),\n            }\n        },\n"
                    d_any_non_composite = true
                    # pointer
                    ptxt = ptxt * "Some(std::ptr::addr_of!(obj.$(n)) as *const u8),\n"
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
