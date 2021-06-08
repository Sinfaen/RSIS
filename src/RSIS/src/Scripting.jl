
module MScripting

export addfilepath, removefilepath, printfilepaths, where, search
export script, getscripttree

# globals
_file_paths = Vector{String}()

"""
    addfilepath(directory::String)
Add filepath to global search list of filepaths.
"""
function addfilepath(directory::String)
    if !(directory in _file_paths)
        push!(_file_paths, directory)
    end
    return
end

"""
    removefilepath(directory::String)
Remove filepath from global search list of filepaths.
"""
function removefilepath(directory::String)
    ind = findfirst(_file_paths.== directory)
    if ind !== nothing
        deleteat!(_file_paths, ind)
    end
    return
end

"""
    printfilepaths()
Print global search
```jldoctest
julia> addfilepath("./marker")
julia> addfilepath("/usr/local/bin")
julia> addfilepath("./marker")
julia> printfilepaths()
> ./marker
> /usr/local/bin
```
"""
function printfilepaths()
    for fp in _file_paths
        println("> $fp")
    end
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
Searches RSIS filepaths for input script. Print the result.
# Examples:
```jldoctest
julia> where("log_nav_data.jl")
Found: /home/user1/sim/inp/nav/log_nav_data.jl
Found: /home/user1/sim/logging/nav/log_nav_data.jl

julia> where("check_user_environment.jl")
File not found.
```
"""
function where(filename::String)
    locations = search(filename, false)
    if length(locations) == 0
        println("File not found")
    else
        for fp in locations
            println("Found: $fp")
        end
    end
end

"""
    search(filename::String, single = true)
Searches RSIS filepaths for input script. By default,
only returns first result.
"""
function search(filename::String, single=true) :: Vector{String}
    locations = Vector{String}()
    for fp in _file_paths
        total_path = joinpath(fp, filename)
        if isfile(total_path)
            push!(locations, total_path)
            if single
                return locations
            end
        end
    end
    return locations
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

end
