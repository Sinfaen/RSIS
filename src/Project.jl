
module MProject

export loadproject, exitproject, newproject, projectinfo, projecttype, projectlibname
export build!, clean!, release
export isprojectloaded, getprojectdirectory, getprojectbuilddirectory

using ..Logging
using ..DataStructures
using ..MLibrary
using ..MScripting
using ..MModel
using ..MDefines
using ..TOML
using ..YAML
using ..MVersion

# globals
mutable struct ProjectInfo
    loaded::Bool
    directory::String
    type::ProjectType
    name::String
    function ProjectInfo()
        new(false, "", RUST(), "")
    end
end

function _builddir(ProjectType::RUST, target::BuildTarget)
    return joinpath("target", "$(target)")
end

function _builddir(ProjectType::CPP, target::BuildTarget)
    # Meson can't build both debug and release in the same directory
    return "build"
end

function _builddir(ProjectType::FORTRAN, target::BuildTarget)
    return "build_$(target)" # TODO
end

function builddir(proj::ProjectInfo, target::BuildTarget)
    return joinpath(proj.directory, _builddir(proj.type, target))
end

_loaded_project = ProjectInfo()

function isprojectloaded() :: Bool
    return _loaded_project.loaded
end

function getprojectdirectory() :: String
    return _loaded_project.directory
end

function getprojectbuilddirectory() :: String
    return builddir(_loaded_project)
end

"""
    loadproject(directory::String = ".")
Load a project, defaulting to the current operating directory.
"""
function loadproject(directory::String = ".") :: Nothing
    _dir = abspath(directory)
    if !isdir(_dir)
        throw(ErrorException("Directory: $(directory) does not exist."))
    end
    cd(_dir)

    if !isfile("rsisproject.toml")
        throw(ErrorException("`rsisproject.toml` not found. `newproject` can be used to regenerate project files"))
        return
    end
    _f = open("rsisproject.toml")
    projectdata = TOML.parse(_f)
    close(_f)
    if !("rsisproject" in keys(projectdata))
        throw(ErrorException("Invalid `rsisproject.toml` file. Key: [rsisproject] not found"))
        return
    end

    if !("type" in keys(projectdata["rsisproject"]))
        throw(ErrorException("`type` key not found in `rsisproject.toml`"))
    end

    # All good here, start doing stuff
    if projectdata["rsisproject"]["type"]     == "rust"
        _loaded_project.type = RUST()
        open("Cargo.toml") do f
            cargo = TOML.parse(f)
            _loaded_project.name = cargo["package"]["name"]
        end
    elseif projectdata["rsisproject"]["type"] == "cpp"
        _loaded_project.type = CPP()
        _loaded_project.name = projectdata["rsisproject"]["name"] # not easy to get out of the meson setup
    elseif projectdata["rsisproject"]["type"] == "fortran"
        _loaded_project.type = FORTRAN()
        open("fpm.toml") do f
            fpm = TOML.parse(f)
            _loaded_project.name = fpm["name"]
        end
    else
        throw(ErrorException("Invalid language type in `rsisproject.toml`"))
    end

    _loaded_project.directory = _dir
    _loaded_project.loaded    = true

    # Let the rest of the framework tie into this
    clearfilepaths()
    if "filepaths" in keys(projectdata["rsisproject"])
        for path in projectdata["rsisproject"]["filepaths"]
            addfilepath(path)
        end
    end

    clearlibpaths()
    addlibpath(builddir(_loaded_project, DEBUG()); force = true)
    addlibpath(builddir(_loaded_project, RELEASE()); force = true)
    addlibpath(joinpath(homedir(), "rsis-$(versioninfo())", "apps"); force = true);

    @info projectinfo()
    return
end

function exitproject() :: Nothing
    global _loaded_project
    _loaded_project = ProjectInfo();
    @info "Exited project"
end

function _newproj(name::String, ProjectType::RUST) :: Nothing
    run(`cargo init --lib`)
    tml = OrderedDict("rsisproject"=> OrderedDict("type"=> "rust", "filepaths" => ["src"]))
    open("rsisproject.toml", "w") do io
        TOML.print(io, tml)
    end
end

function _newproj(name::String, ProjectType::CPP) :: Nothing
    run(`meson setup build`)
    tml = Dict("rsisproject"=> Dict("type"=> "cpp", "filepaths" => ["src"]))
    open("rsisproject.toml", "w") do io
        TOML.print(io, tml)
    end
end

function _newproj(name::String, ProjectType::FORTRAN) :: Nothing
    run(`fpm new --lib`)
    tml = Dict("rsisproject"=> Dict("type"=> "fortran", "filepaths" => ["src"]))
    open("rsisproject.toml", "w") do io
        TOML.print(io, tml)
    end
end

"""
    newproject(name::String; language::String = "rust")
Create a folder containing commonly necessary files for a
new RSIS project.
```jldoctest
julia> newproject("wave_model") # Defaults to rust
julia> newproject("integrate_avionics"; language = "cpp")
julia> newproject("legacy_model"; language = "fortran")
```
"""
function newproject(name::String; language::String = "rust") :: Nothing
    if isdir(name)
        println("Folder with name: `$(name)`` already exists")
        print("Attempt to generate a new project anyways? [y/n]: ")
        answer = readline()
        if answer != "y"
            println("Project generation aborted.")
            return
        end
    else
        mkdir(name)
    end
    cd(name)

    # Generate new project files
    global _loaded_project
    if language == "rust"
        _loaded_project.type = RUST()
    elseif language == "cpp"
        _loaded_project.type = CPP()
    elseif language == "fortran"
        _loaded_project = FORTRAN()
    else
        throw(ArgumentError("`language` must be one of the following: [\"rust\", \"cpp\", \"fortran\"]"))
    end
    _newproj(name, _loaded_project.type) # language specific actions
    yml = OrderedDict("model" => name,
        "$(name)_in" => nothing,
        "$(name)_out" => nothing,
        "$(name)_data" => nothing,
        "$(name)_params" => nothing,
        "$(name)" => OrderedDict(
            "inputs" => Dict("class" => "$(name)_in"),
            "outputs" => Dict("class" => "$(name)_out"),
            "data" => Dict("class" => "$(name)_data"),
            "params" => Dict("class" => "$(name)_params")
        ))
    YAML.write_file(joinpath("src", "$(name).yml"), yml)
    @info "Generated Project [$name]"
    loadproject(".")
end

"""
    projectinfo()
Returns a brief description of the loaded project.
```jldoctest
julia> projectinfo()
"rust Project loaded at: /home/abc1234/myproject"
```
"""
function projectinfo() :: String
    if !isprojectloaded()
        return "No project is loaded"
    end
    return "$(_loaded_project.type) Project loaded at: $(_loaded_project.directory)"
end

function projectlibname() :: String
    if !isprojectloaded()
        throw(ErrorException("No project loaded"))
    end
    return _loaded_project.name
end

function projecttype() :: ProjectType
    if !isprojectloaded()
        throw(ErrorException("No project loaded"))
    end
    return _loaded_project.type
end

function _get_tagfile_name(projectname::String, target::String) :: String
    return "rsis_$(projectname).app.$(target).toml";
end

"""
Generate a TOML tag file alongside the model with associated
metadata
"""
function _generate_tagfile(proj::ProjectInfo, target::BuildTarget) :: Nothing
    data = Dict(
        "binary" => Dict(
            "file"  => _libraryprefix() * proj.name * _libraryextension(),
            "target" => "$(target)"
        ),
        "rsis-package" => Dict(
            "version" => versioninfo()
        )
    );
    filename = _get_tagfile_name(proj.name, "$target")
    if proj.type == RUST()
        folder = joinpath("target", "$(target)")
    elseif proj.type == CPP()
        folder = "build"
    else # Fortran
        folder = joinpath("target", "$(target)"); # ??
    end
    open(joinpath(proj.directory, folder, filename), "w") do io
        TOML.print(io, data);
        # grab meta file and append it
        metafile = search("$(proj.name).meta")
        if length(metafile) == 0
            @warn "Unable to locate meta file"
        else
            addtext = read(metafile[1], String)
            write(io, addtext)
        end
    end
    return;
end

function _build(ProjectType::RUST, target::BuildTarget)
    if target isa DEBUG
        run(`cargo build`)
    else
        run(`cargo build --release`)
    end
end

function _build(ProjectType::CPP, target::BuildTarget)
    # Meson doesn't support debug & release in the same buil directory
    st = "$(target)"
    if !isdir("build")
        run(`meson setup build -Dbuildtype=$st --prefix=/`)
    end
    cd("build")
    run(`meson compile`)
    cd(_loaded_project.directory)
end

function _build(ProjectType::FORTRAN, target::BuildTarget)
    run(`fpm build`)
end

"""
    build!(;target::String = "debug")
Compile a loaded RSIS project. Actions are dependent on the
type of the project.
"""
function build!(;target::String = "debug") :: Nothing
    if !isprojectloaded()
        @error "No project loaded. Aborting"
        return
    end
    if target == "debug"
        tt = DEBUG()
    elseif target == "release"
        tt = RELEASE()
    else
        throw(ArgumentError("target must be either [debug,release]"))
    end
    cd(_loaded_project.directory)
    _build(_loaded_project.type, tt)
    _generate_tagfile(_loaded_project, tt)
    println("Completed building $(_loaded_project.name)")
    return
end

"""
    clean!()
Destroy build directory(s).
"""
function clean!(;target::String = "debug") :: Nothing
    if !isprojectloaded()
        println("No project loaded. Aborting")
    end
    if target == "debug"
        tt = DEBUG()
    elseif target == "release"
        tt = RELEASE()
    else
        throw(ArgumentError("target must be either [debug,release]"))
    end

    cd(_loaded_project.directory)
    rm(_builddir(_loaded_project.type, tt); recursive=true)
end

"""
    release(library)
Releases the project library to a directory.
Defaults to <user home directory>/rsis-<version>/apps, 
"""
function release(library::String = "", releasedir::String = "") :: Nothing
    if isempty(library)
        library = projectlibname()
    end
    if isempty(releasedir)
        releasedir = joinpath(homedir(), "rsis-$(versioninfo())", "apps")
    end
    (tagfile, type, path) = appsearch(library; fullname = true)[1]
    open(joinpath(path, tagfile), "r") do io
        data = TOML.parse(io);
        libname = data["binary"]["file"]
        if !isdir(releasedir)
            mkpath(releasedir)
            @info "Created $releasedir"
        end
        cp(joinpath(path, libname), joinpath(releasedir, libname); force = true)
        cp(joinpath(path, tagfile), joinpath(releasedir, tagfile); force = true)
        @info "Released $library to $releasedir"
    end
    return;
end

end