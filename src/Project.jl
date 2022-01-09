
module MProject

export loadproject, newproject, projectinfo, projecttype
export build!, clean!
export isprojectloaded, getprojectdirectory, getprojectbuilddirectory

using ..MLogging
using ..MScripting
using ..TOML

abstract type ProjectType end
struct RUST <: ProjectType end
struct CPP  <: ProjectType end
struct FORTRAN <: ProjectType end

Base.print(io::IO, ::RUST) = print(io, "rust")
Base.print(io::IO, ::CPP)  = print(io, "cpp")
Base.print(io::IO, ::FORTRAN) = print(io, "fortran")

# globals
mutable struct ProjectInfo
    loaded::Bool
    builddirexists::Bool
    directory::String
    type::ProjectType
    target::String
    function ProjectInfo()
        new(false, false, "", RUST(), "debug")
    end
end

function _libdir(ProjectType::RUST)
    return joinpath("target", _loaded_project.target)
end

function _libdir(ProjectType::CPP)
    return "build"
end

function _libdir(ProjectType::FORTRAN)
    return "build"
end

function builddir(proj::ProjectInfo)
    return joinpath(proj.directory, _libdir(proj.type))
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

function checkbuilddirectory(proj::ProjectInfo) :: Nothing
    if proj.loaded
        proj.builddirexists = isdir(builddir(proj))
    else
        proj.builddirexists = false
    end
    return
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
    if projectdata["rsisproject"]["type"] == "rust"
        _loaded_project.type = RUST()
    elseif projectdata["rsisproject"]["type"] == "cpp"
        _loaded_project.type = CPP()
    elseif projectdata["rsisproject"]["type"] == "fortran"
        _loaded_project.type = FORTRAN()
    else
        throw(ErrorException("Invalid language type in `rsisproject.toml`"))
    end

    if "filepaths" in keys(projectdata["rsisproject"])
        for path in projectdata["rsisproject"]["filepaths"]
            addfilepath(path)
        end
    end

    checkbuilddirectory(_loaded_project)
    _loaded_project.directory = _dir
    _loaded_project.loaded    = true
    logmsg(projectinfo(), LOG)
    return
end

function _newproj(ProjectType::RUST) :: Nothing
    run(`cargo init --lib`)
end

function _newproj(ProjectType::CPP) :: Nothing
    run(`meson setup builddir`)
end

function _newproj(ProjectType::FORTRAN) :: Nothing
    run(`fpm new --lib`)
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
        print("Generate a new project anyways? [y/n]: ")
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
    if language == "rust"
        _loaded_project.type = RUST()
    elseif language == "cpp"
        _loaded_project.type = CPP()
    elseif language == "fortran"
        _loaded_project = FORTRAN()
    else
        throw(ArgumentError("`language` must be one of the following: [\"rust\", \"cpp\", \"fortran\"]"))
    end
    _newproj(_loaded_project.type)
end

function projectinfo() :: String
    if !isprojectloaded()
        return "No project is loaded"
    end
    return "$(_loaded_project.type) Project loaded at: $(_loaded_project.directory)"
end

function projecttype() :: String
    if !isprojectloaded()
        throw(ErrorException("No project loaded"))
    end
    return "$(_loaded_project.type)"
end

"""
    buildtarget!(target::String)
Set the build target of the project, which affects further builds.
"""
function buildtarget!(target::String)
    if target != "debug" && target != "release"
        throw(ArgumentError("Unknown `target`: $(target). Must be debug or release"))
    end
    _loaded_project.target = target;
end

function _build(ProjectType::RUST)
    if (_loaded_project.target == "debug")
        run(`cargo build`)
    else
        run(`cargo build --release`)
    end
end

function _build(ProjectType::CPP)
    run(`meson build`)
    cd(builddir(_loaded_project))
    run(`meson compile`)
    cd(_loaded_project.directory)
end

function _build(ProjectType::FORTRAN)
    run(`fpm build`)
end

"""
    build!()
Compile a loaded RSIS project. Actions are dependent on the
type of the project.
"""
function build!() :: Nothing
    if !isprojectloaded()
        println("No project loaded. Aborting")
        return
    end
    if _loaded_project.target == "debug" || _loaded_project.target == "release"
        cd(_loaded_project.directory)
        _build(_loaded_project.type)
    else
        throw(ArgumentError("Invalid `target` specified. Must be debug or release"))
    end
    return
end

"""
    clean!()
Destroy build directory.
"""
function clean!() :: Nothing
    if !isprojectloaded()
        println("No project loaded. Aborting")
    end

    cd(_loaded_project.directory)
    rm(_libdir(_loaded_project.type); recursive=true)
end

end