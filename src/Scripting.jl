
module MScripting

export addfilepath, removefilepath, clearfilepaths, listfilepaths, where, search, script
export script, logscripts, printscriptlog

using ..Logging

# globals
_file_paths   = Vector{String}()

mutable struct ScriptRecord
    recording::Bool
    record::Vector{Tuple{String, String}}
end
ScriptRecord() = ScriptRecord(false, Vector{Tuple{String, String}}())

function clearrecord!(record::ScriptRecord)::Nothing
    empty!(record.record)
    return
end

function addrecord!(record::ScriptRecord, filename::String, newfile::String)::Nothing
    push!(record.record, (basename(filename), newfile))
    return
end

## globals used by logscripts & printscriptlog
_script_record = ScriptRecord()

"""
    addfilepath(directory::String)
Add filepath to global search list of filepaths. All paths are resolved to
absolute paths. Relative paths are searched against pre-existing filepaths
with the first existing match added.
"""
function addfilepath(directory::String) :: Nothing
    if isabspath(directory)
        if directory in _file_paths
            @warn "File Path directory already added"
        else
            push!(_file_paths, directory)
        end
    else
        # search pre-existing paths for directory
        found = false
        if isdir(joinpath(pwd(), directory))
            found = true
            push!(_file_paths, joinpath(pwd(), directory))
        else
            for dir in _file_paths
                relpath = joinpath(dir, directory)
                if isdir(relpath)
                    found = true
                    push!(_file_paths, relpath)
                end
            end
        end
        if !found
            @warn "Could not resolve: $directory"
        end
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
    clearfilepaths()
Empties the global file path list.
"""
function clearfilepaths() :: Nothing
    global _file_paths
    _file_paths = Vector{String}();
    return
end

"""
    listfilepaths()
Returns a list of global search file paths
```jldoctest
julia> addfilepath("./marker")
julia> addfilepath("/usr/local/bin")
julia> addfilepath("./marker")
julia> listfilepaths()
2-element Vector{String}:
 ./marker
 /usr/local/bin
```
"""
function listfilepaths() :: Vector{String}
    return copy(_file_paths)
end

"""
    script(filename::String, printpath::bool)

Searches filepaths for input script and passes first instance to 'include'.
Example:
```jldoctest
julia> script("setup_filepaths.jl")
julia> script("foo.jl")
[ERROR]: File "foo.jl" not found!
```
"""
function script(filename::String) :: Nothing
    found_path = search(filename)
    if length(found_path) == 0
        @error "Script \"$(filename)\" not found!"
    else
        if _script_record.recording
            addrecord!(_script_record, @__FILE__, filename)
        end
        include(found_path[1])
    end
    return
end

"""
    where(filename::String)
Searches RSIS filepaths for input script. Print the result.
# Examples:
```jldoctest
julia> where("log_nav_data.jl")
[ Info: /home/user1/sim/inp/nav/log_nav_data.jl
[ Info: /home/user1/sim/logging/nav/log_nav_data.jl

julia> where("check_user_environment.jl")
┌ Error: File not found
└ @ RSIS.MScripting ~/rsis/src/Scripting.jl:146
```
"""
function where(filename::String)
    locations = search(filename, false)
    if length(locations) == 0
        @error "File not found"
    else
        for fp in locations
            @info fp
        end
    end
end

"""
    search(filename::String, single = true)
Searches RSIS filepaths for input script. By default,
only returns first result. The current working directory
is searched first.
"""
function search(filename::String, single=true) :: Vector{String}
    locations = Vector{String}()
    if isfile(filename)
        push!(locations, filename)
    end
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
    logscripts()

Starts a record of all calls to `script`. See `printscriptlog` for more details
"""
function logscripts() :: Nothing
    _script_record.recording = true
    return
end

"""
    printscriptlog()

Prints all calls to `script` that have been recorded since the last call to
`logscripts`. This function is defined in `Scripting.jl`, so all caller files
called `Scripting.jl` are replaced with `REPL` when printed
```jldoctest
julia> logscripts()
julia> script("scenario_a.jl")
julia> printscriptlog()
[LOG]: Recorded `script` calls
REPL          > scenario_a.jl
scenario_a.jl > load_connect_models.jl
scenario_a.jl > schedule_models.jl
scenario_a.jl > setup_sim.jl
setup_sim.jl  > logging.jl
logging.jl    > log_trajectory.jl
```
"""
function printscriptlog() :: Nothing
    message = "Recorded `script` calls\n"
    sep = " > "

    # attempt to line up all ' > ' on the same column, at a maximum index of 30
    char_width = 0
    for log in _script_record.record
        char_width = max(char_width, length(log[1]))
    end
    char_width = min(30, char_width)

    for log in _script_record.record
        _file = log[1]
        if _file == "Scripting.jl"
            _file = "REPL"
        end
        message = message * _file
        len = length(log[1])
        if len <= char_width
            message = message * (' '^(char_width - len))
        end
        message = message * sep * log[2] * "\n"
    end

    @info message

    _script_record.recording = false
    clearrecord!(_script_record)
    return
end

end
