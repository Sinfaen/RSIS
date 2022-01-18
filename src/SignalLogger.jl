
module MSignalLogger

using ..MLibrary
using ..MScripting
using ..MModel
using ..MScheduling

using ..CSV
using ..DataFrames

export logsignal, logsignalfile, listlogged
export setlogfilelimit

_loggedfields = DataFrame("model"=>Vector{String}(), "port"=>Vector{String}(), "rate"=>Vector{Float64}())

_log_file_size = 100 # 100 MB

"""
    setlogfilelimit(limit::Float64)
Set the maximum size of a log (per thread) in MB.

TODO: refactor to use Unitful
```jldoctest
julia> setlogfilelimit(800.0) # MB. max CI artifact size
```
"""
function setlogfilelimit(limit::Float64) :: Nothing
    if limit < 0
        throw(ErrorException("File size limit specified: $limit, is negative"))
    end
    _log_file_size = limit;
    return
end

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
