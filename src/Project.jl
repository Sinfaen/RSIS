
module MProject

export loadproject, newproject, projectinfo, projecttype
export build!, clean!
export isprojectloaded, getprojectdirectory, getprojectbuilddirectory

using ..Logging
using ..MScripting
using ..MModel
using ..MDefines
using ..TOML
using ..MVersion

# globals
mutable struct ProjectInfo
    loaded::Bool
    directory::String
    type::ProjectType
    function ProjectInfo()
        new(false, "", RUST())
    end
end

function _builddir(ProjectType::RUST, target::BuildTarget)
    return joinpath("target", "$(target)")
end

function _builddir(ProjectType::CPP, target::BuildTarget)
    return "build_$(target)"
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
    elseif projectdata["rsisproject"]["type"] == "cpp"
        _loaded_project.type = CPP()
    elseif projectdata["rsisproject"]["type"] == "fortran"
        _loaded_project.type = FORTRAN()
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

    @info projectinfo()
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

function projecttype() :: ProjectType
    if !isprojectloaded()
        throw(ErrorException("No project loaded"))
    end
    return _loaded_project.type
end

"""
Generate a TOML tag file alongside the model with associated
metadata
"""
function _generate_tagfile(proj::ProjectInfo, target::BuildTarget)
    data = Dict(
        "rsisapp" => Dict(
            "type"   => "$(proj.type)",
            "target" => "$(target)"
        ),
        "rsis" => Dict(
            "version" => versioninfo()
        )
    );
end

function _build(ProjectType::RUST, target::BuildTarget)
    if target isa DEBUG
        run(`cargo build`)
    else
        run(`cargo build --release`)
    end
end

function _build(ProjectType::CPP, target::BuildTarget)
    st = "$(target)"
    if !isdir("build_$st")
        run(`meson setup build_$st -Dbuildtype=$st --prefix=/`)
    end
    cd("build_$st")
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
    return
end

"""
    clean!()
Destroy build directory(s).
"""
function clean!() :: Nothing
    if !isprojectloaded()
        println("No project loaded. Aborting")
    end

    cd(_loaded_project.directory)
    rm(_builddir(_loaded_project.type); recursive=true)
end

end