#

module MInterfaceGeneration

using ..DataStructures
using ..Unitful
using ..YAML
using ..MScripting
using ..MLogging
using ..MModel
using ..MProject

export generateinterface

# globals
_type_defaults = Dict{String, Any}(
    "char"    => ' ',
    "String"  => "",
    "Int8"    => 0,
    "Int16"   => 0,
    "Int32"   => 0,
    "Int64"   => 0,
    "UInt8"   => 0,
    "UInt16"  => 0,
    "UInt32"  => 0,
    "UInt64"  => 0,
    "Bool"    => false,
    "Float32" => 0,
    "Float64" => 0,
    "Complex{Float32}" => 0+0im,
    "Complex{Float64}" => 0+0im
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

        println("Generated: $path")
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
            unit=nothing
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
            initial = _type_defaults[field.second["type"]]
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
Generated: mymodel_interface.hxx
Generated: mymodel_interface.cxx
Generation complete
julia> generateinterface("mymodel.yml"; interface = "rust")
Generated: mymodel_interface.rs
Generation complete
julia> generateinterface("mymodel.yml"; interface = "fortran")
Generated: mymodel_interface.f90
Generation complete
```
"""
function generateinterface(interface::String; language::String = "")
    templates = Vector{Tuple{String, String}}()
    if language == ""
        language = projecttype()
    end
    if language == "cpp"
        push!(templates, ("_interface.hxx", joinpath(@__DIR__, "templates", "header_cpp.template")))
        push!(templates, ("_interface.cxx", joinpath(@__DIR__, "templates", "source_cpp.template")))
    elseif language == "rust"
        push!(templates, ("_interface.rs", joinpath(@__DIR__, "templates", "rust.template")))
    elseif language == "fortran"
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

    # create text
    if language == "cpp"
        words["HEADER_GUARD"] = uppercase(model_name)
        words["HEADER_FILE"]  = "$(model_name)_interface.hxx"
        words["MODEL_FILE"]   = "$(data["model"]).hxx"
        hxx_text = ""
        cxx_text = ""
        for name in class_order
            if name == data["model"]
                continue
            end
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
                htext = htext * "    $(convert_julia_type(f.type, language)) $n"
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
        end
        words["CLASS_DEFINES"]     = hxx_text
        words["CLASS_DEFINITIONS"] = cxx_text

        # Add reflection generation
        rtext = ""
        for name in class_order
            fields = class_defs[name]
            rtext = rtext * "void Reflect_$(name)(ReflectClass _class, ReflectMember _member) {\n"
            rtext = rtext * "_class(\"$(name)\");\n"
            txt = ""
            for (fieldname, f) in fields
                txt = txt * "_member(\"$(name)\", \"$(fieldname)\", \"int\", _offsetof(&$(name)::$(fieldname)));\n"
            end
            rtext = rtext * txt * "}\n\n"
        end
        words["REFLECT_DEFINITIONS"] = rtext

        words["REFLECT_CALLS"] = join(["Reflect_$(name)(_class, _member);" for name in class_order], "\n")
        words["METADATA_TOML"] = """
        [rsis]
        name = "$(data["model"])"
        type = "$(language)" """
    else
        rs_text = ""
        cs_text = ""
        reflect = ""
        ref_all = "#[no_mangle]\npub extern \"C\" fn reflect(_cb1 : ReflectClass, _cb2 : ReflectMember) {\n"
        # generate constructors & structs
        for name in class_order
            if name == data["model"]
                continue
            end
            fields = class_defs[name]
            txt = "#[repr(C)]\npub struct $(name) {\n"
            cs  = "impl $(name) {\n    pub fn new() -> $(name) {\n" *
                  "        $(name) {\n"
            for (n,f) in fields
                if length(f.dimension) == 0
                    txt = txt * "    pub $n : $(convert_julia_type(f.type, language)),\n"
                    if f.iscomposite
                        cs = cs * "            $(n) : $(f.type)::new(),\n"
                    elseif f.type == "String"
                        cs = cs * "            $(n) : \"$(f.defaultvalue)\".to_string(),\n"
                    else
                        cs = cs * "            $(n) : $(f.defaultvalue),\n"
                    end
                else
                    txt = txt * "    pub $n : [$(convert_julia_type(f.type, language)); $(join(f.dimension, ","))],\n"
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
        end
        # generate other values
        for name in class_order
            if name == data["model"]
                prepend = "crate::"
            else
                prepend = ""
            end
            fields = class_defs[name]
            ref = "pub fn reflect_$(name)(_cb1 : ReflectClass, _cb2 : ReflectMember) {\n" *
                  "    let cl = CString::new(\"$(name)\").unwrap();\n" *
                  "    _cb1(cl.as_ptr());\n"
            ref_all = ref_all * "    reflect_$(name)(_cb1, _cb2);\n"
            for (n,f) in fields
                if length(f.dimension) == 0
                    ref = ref * "    let f_$(n) = CString::new(\"$(n)\").unwrap();\n" *
                                "    let d_$(n) = CString::new(\"$(f.type)\").unwrap();\n" *
                                "    _cb2(cl.as_ptr(), f_$(n).as_ptr(), d_$(n).as_ptr(), offset_of!($(prepend)$(name), $(n)));\n"
                else
                    ref = ref * "    let f_$(n) = CString::new(\"$(n)\").unwrap();\n" *
                                "    let d_$(n) = CString::new(\"[$(f.type); $(join(["$(d)" for d in f.dimension], ","))]\").unwrap();\n" *
                                "    _cb2(cl.as_ptr(), f_$(n).as_ptr(), d_$(n).as_ptr(), offset_of!($(prepend)$(name), $(n)));\n"
                end
            end
            ref = ref * "}\n"
            reflect = reflect * ref
        end
        ref_all = ref_all * "}\n"
        words["STRUCT_DEFINITIONS"] = rs_text
        words["CONSTRUCTOR_DEFINITIONS"] = cs_text
        words["REFLECT_DEFINITIONS"] = reflect * ref_all
        words["METADATA_TOML"] = """
        [rsis]
        name = \\"$(data["model"])\\"
        type = \\"$(language)\\" """
    end
    words["STRUCT_NAME"] = last(class_order)

    pushtexttofile(base_dir, model_name, words, templates)

    println("Generation complete")
    return
end

end
