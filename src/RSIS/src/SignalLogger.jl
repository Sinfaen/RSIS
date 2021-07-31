
module MSignalLogger

using ..MScripting

export logsignal, logsignalfile, listlogger

"""
    logsignalfile(file::String)
Log the signals as specified by the input YAML file name.
```jldoctest
julia> logsignalfile("battleship_log_file.yml")
LOG: Logged 31 fields
```
"""
function logsignalfile(file::String) :: Nothing
    return
end

"""
    logsignal(model::String, path::String)
Log the signal as specified by the input model port string.
To log signals described in a YAML document, see `logsignalfile`
```jldoctest
julia> logsignal("mymodel", "out.thrustVector")
```
"""
function logsignal(model::String, path::String) :: Nothing
    return
end

"""
    listlogger()
Lists all signals currently being logged. The signal name is
composed of the model name, followed by a `:`, following by the
path to the signal and then the signal name itself (separate by
periods).
```jldoctest
julia> listlogger
5-element Vector{String}:
    "battleship:out.position_ecef"
    "battleship:out.orientation_ecef"
    "battleship:out.velocity_ecef"
    "battleship:data.cg_location_body"
    "battleship:data.fuel"
```
"""
function listlogger() :: Vector{String}
    println("Not implemented")
    return Vector{String}()
end

end
