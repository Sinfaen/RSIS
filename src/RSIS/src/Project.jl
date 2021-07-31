
module MProject

export loadproject, newproject, projectinfo
export build!, clean!
export isprojectloaded, getprojectdirectory, getprojectbuilddirectory

using ..MLogging

# globals
mutable struct ProjectInfo
    loaded::Bool
    builddirexists::Bool
    directory::String
    bname::String
    function ProjectInfo()
        new(false, false, "", "builddir")
    end
end

function builddir(proj::ProjectInfo)
    return joinpath(proj.directory, proj.bname)
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

function createbuilddirectory(proj::ProjectInfo) :: Nothing
    if !proj.builddirexists
        mkdir(builddir(proj))
        proj.builddirexists = true
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
        throw(IOError("Directory: $(directory) does not exist."))
    end
    cd(_dir)

    files = [
        "meson_options.txt",
        "meson.build"
        #"RSIS_Project.toml"
    ];

    for f in files
        if !isfile(f)
            throw(IOError("File `$(f)` not found. Project load aborted.\n`newproject` can be used to regenerate project files"))
        end
    end

    checkbuilddirectory(_loaded_project)
    _loaded_project.directory = _dir
    _loaded_project.loaded    = true
    logmsg(projectinfo(), LOG)
    return
end

"""
    newproject(name::String)
Create a folder containing commonly necessary files for a
new RSIS project.
    - meson_options.txt
    - meson.build
"""
function newproject(name::String) :: Nothing
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
end

function projectinfo() :: String
    if !_loaded_project.loaded
        return "No project is loaded"
    end
    return "Project loaded at: $(_loaded_project.directory)"
end

"""
    build!()
Compile a loaded RSIS project. Equivalent to executing the
following commands:
meson: `cd builddir; meson compile; cd ..`
"""
function build!() :: Nothing
    if !_loaded_project.loaded
        println("No project loaded. Aborting")
        return
    end

    createbuilddirectory(_loaded_project)
    cd(builddir(proj))
    run(`meson compile`)
    cd(_loaded_project.directory)
end

"""
    clean!()
Destroy build directory.
"""
function clean!() :: Nothing
    if !_loaded_project.loaded
        println("No project loaded. Aborting")
    end

    cd(_loaded_project.directory)
    rm("builddir"; recursive=true)
end

end