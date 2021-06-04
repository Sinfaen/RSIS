
# globals
_file_paths = []

"""
Add filepath to global search list of filepaths.
"""
function addfilepath(directory::String)

end

"""
"""
function removefilepath(directory::String)
end

"""
    printfilepaths()
Print global search
"""
function printfilepaths()
    println(_file_paths)
end

"""
    script(filename::String, printpath::bool)

Searches filepaths for input script and passes first instance to 'include'
"""
function script(filename::String, printpath = false)
    found_path = filename
    # search file paths
    include(found_path)
end

"""
    where(filename::String)
Searches RSIS filepaths for input script.
# Examples:
```jldoctest
julia> where("log_nav_data.jl")
Found: /home/user1/sim/inp/nav/log_nav_data.jl
Found: /home/user1/sim/logging/nav/log_nav_data.jl

julia> where("check_user_environment.jl")
File not found.
```
"""
function where(filename::String) :: String
    #
end

"""
    getscripttree(filename::String, level::Int = -1)
Print all scripts called by provided script.
Output is structured in a tree-like format.

# Example:
```jldoctest
julia> getscripttree("scenario_a.jl")
scenario_a.jl
|- load_connect_models.jl
|- schedule_models.jl
|- setup_sim.jl
|  |- logging.jl
|  |  |- log_trajectory.jl [WARNING - File not found]
```
"""
function getscripttree(filename::String, level::Int = -1)
    #
end
