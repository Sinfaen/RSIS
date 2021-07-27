
module MProject

export loadproject, newproject

# globals

"""
    loadproject(directory::String = ".")
Load a project, defaulting to the current operating directory.
"""
function loadproject(directory::String = "") :: Nothing
    if !isdir(directory)
        throw(IOError("Directory: $(directory) does not exist."))
    end
    cd(directory)

    files = [
        "meson_options.txt",
        "meson.build",
        "RSIS_Project.toml"
    ];

    for f in files
        if !isfile(f)
            throw(IOError("File `$(f)` not found. Project load aborted.\n`newproject` can be used to regenerate project files"))
        end
    end
end

"""
    newproject(name::String)
Create a folder containing commonly necessary files for a
new RSIS project.
    - meson_options.txt
    - meson.build
    - RSIS_Project.toml
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
    
end