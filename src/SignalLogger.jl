
module MSignalLogger

using ..MLibrary
using ..MScripting
using ..MModel

using ..CSV
using ..DataFrames

export logsignal, logsignalfile, listlogged

_loggedfields = DataFrame("model"=>Vector{String}(), "port"=>Vector{String}(), "rate"=>Vector{Float64}())

## Refactor using the DataFrames package
## this data is better consumed/output in this manner

"""
    logsignalfile(file::String)
Log the signals as specified by the input CSV file name.
```jldoctest
julia> logsignalfile("ship_logging.csv")
LOG: Logged 31 fields
```
"""
function logsignalfile(file::String) :: Nothing
    return
end

"""
    logsignal(model::ModelReference, path::String, rate::Float64)
Log the signal as specified by the input model port string.
```jldoctest
julia> m = newmodel("assert_checks", "mymodel")
julia> schedule(m, 10.0)
julia> logsignal(m, "outputs.position", 10.0)
julia> logsignal(m, "outputs.thrust",    2.0)
```
"""
function logsignal(model::String, path::String, rate::Float64) :: Nothing
    # ensure that model and path exist. Move to initialization?
    #modelinst = _getmodelinstance(model)
    #(_, _) = _parselocation(modelinst, path)
    push!(_loggedfields, (model, path, rate))
    return
end

"""
    listlogged()
Returns all signals currently being logged
```jldoctest
julia> listlogged()
```
"""
function listlogged()
    return _loggedfields
end

end
