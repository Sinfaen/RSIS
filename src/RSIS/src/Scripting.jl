
module MScripting

export addfilepath, removefilepath, printfilepaths, where, search, script
export script, logscripts, printscriptlog

using ..MLogging

# globals
_file_paths   = Vector{String}()

mutable struct ScriptRecord
    recording::Bool
    record::Vector{Tuple{String, String}}
end
ScriptRecord() = ScriptRecord(false, Vector{Tuple{String, String}}())

function clearrecord!(record::ScriptRecord)::Nothing
    empty!(record.record)
end

function addrecord!(record::ScriptRecord, filename::String, newfile::String)::Nothing
    push!(record.record, (filename, newfile))
end

## globals used by logscripts & printscriptlog
_script_record = ScriptRecord()

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
[LOG]:
> ./marker
> /usr/local/bin
```
"""
function printfilepaths()
    message = "\n"
    for fp in _file_paths
        message = message * "> $fp" * "\n"
    end
    logmsg(message, LOG)
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
        logmsg("Script \"" * filename * "\" not found!", ERROR)
    else
        include(found_path[1])
        if _script_record.recording
            addrecord!(_script_record, @__FILE__, filename)
        end
    end
end

"""
    where(filename::String)
Searches RSIS filepaths for input script. Print the result.
# Examples:
```jldoctest
julia> where("log_nav_data.jl")
[LOG]: /home/user1/sim/inp/nav/log_nav_data.jl
[LOG]: /home/user1/sim/logging/nav/log_nav_data.jl

julia> where("check_user_environment.jl")
[ERROR]: File not found.
```
"""
function where(filename::String)
    locations = search(filename, false)
    if length(locations) == 0
        logmsg("File not found", ERROR)
    else
        for fp in locations
            logmsg(fp, LOG)
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
`logscripts`.
```jldoctest
julia> logscripts()
julia> script("scenario_a.jl")
julia> printscriptlog()
[LOG]: Recorded `script` calls
REPL[1]       > scenario_a.jl
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

    for log in _script_record
        message = message * log[1]
        len = length(log[1])
        if len <= char_width
            message = message * (' '^(char_width - len)) * sep
        end
        message = message * sep * log[2] * "\n"
    end

    logmsg(message, LOG)

    _script_record.recording = false
    clearrecord!(_script_record)
end

end
