#

module MInterfaceGeneration

using ..DataStructures
using ..Unitful
using ..YAML
using ..MScripting
using ..MLogging
using ..MModel

export generateinterface

# globals
_type_defaults = Dict{String, Any}(
    "char"     =>   ' ',
    "int8_t"   =>     0,
    "int16_t"  =>     0,
    "int32_t"  =>     0,
    "int64_t"  =>     0,
    "uint8_t"  =>     0,
    "uint16_t" =>     0,
    "uint32_t" =>     0,
    "uint64_t" =>     0,
    "bool"     => false,
    "float"    =>     0,
    "double"   =>     0,
    "std::complex<float>"  => 0+0im,
    "std::complex<double>" => 0+0im
)

"""
Helper function for generateinterface
Used to create model files from relevant information
"""
function pushtexttofile(directory::String, model::String, append::String, text::String)
    path = joinpath(directory, model * append)
    f_file = open(path, "w")

    write(f_file, "/* Autogenerated by RSIS Framework */\n")
    write(f_file, text)

    close(f_file)

    println("Generated: $path")
end

"""
Exception to be thrown when Model Interface is bad
"""
struct InterfaceException <: Exception
    file::String
    msg::String
end

Base.showerror(io::IO, e::InterfaceException) = print(io, "")

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
            composite = Port(field.second["class"], Tuple(dims); note=desc, porttype=PORT)
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

            port = Port(field.second["type"], Tuple(dims), initial; units=unit, note=desc, porttype=PORT)
            push!(definitions[modelname], (field.first, port))
        else
            throw(ErrorException("Invalid model interface"))
        end
    end
    return modelname
end

"""
    generateinterface(interface::String)
Generate a C++ model interface from the specified interface file.
The generated files are put in the same location as the interface
file.
```jldoctest
julia> generateinterface("mymodel.yml")
Generated: mymodel_interface.hxx
Generated: mymodel_interface.cxx
Generation complete
```
"""
function generateinterface(interface::String)
    path_interface = search(interface)
    if length(path_interface) == 0
        throw(IOError("Unable to find interface file: $interface"))
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
    hxx_text = "#ifndef __$(uppercase(model_name))__\n" *
               "#define __$(uppercase(model_name))__\n" *
               "#include <cstdint>\n" *
               "#include <complex>\n" *
               "#include <ModelRegistration.hxx>\n\n"
    cxx_text = "#include \"$(model_name)_interface.hxx\"\n"

    for i in 1:length(class_order)
        name = class_order[i]
        fields = class_defs[class_order[i]]
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
            htext = htext * "    " * f.type * " " * "$n"
            if length(f.dimension) != 0
                htext = htext * "[" * join(f.dimension, "][") * "]"
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
                    ctext = ctext * "$n($(f.defaultvalue))"
                else
                    ctext = ctext * "$n{" * join([d for d in f.defaultvalue], ", ") *"}"
                end
            end
        end
        htext = htext * "};\n"
        ctext = ctext * "{ }\n$name::~$name() { }\n"
        hxx_text = hxx_text * htext;
        cxx_text = cxx_text * ctext;
    end

    hxx_text = hxx_text * "void Reflect_$(model_name)(RSIS::Model::DefineClass_t _class, RSIS::Model::DefineMember_t _member);\n" * "#endif\n"
    cxx_text = cxx_text * "void Reflect_$(model_name)(RSIS::Model::DefineClass_t _class, RSIS::Model::DefineMember_t _member) {\n}\n"

    # Add reflection generation

    # Model hxx file
    pushtexttofile(base_dir, model_name, "_interface.hxx", hxx_text)

    # Model cxx file
    pushtexttofile(base_dir, model_name, "_interface.cxx", cxx_text)

    println("Generation complete")
    return
end

end
