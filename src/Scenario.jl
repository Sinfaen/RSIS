
module MScenario

export scenario!, savescenario

using ..YAML
using ..MModel
using ..MScripting

"""
Contains information on the current sim scenario
"""
mutable struct Configuration
    models::Vector{String}
    connections::Vector{String}
    function Configuration()
        new(Vector{String}(), Vector{String}())
    end
end

# globals
_config = Configuration()

"""
    scenario!(filename::String)
Load a scenario YAML file from the filepaths. The file
extension defaults to '.yml'. Loading a new scenario overrides
the previously loaded scenario if it exists.
```jldoctest
julia> scenario!("cloudy_day_test")
julia> scenario!("closed_loop_sim.scene")
```
"""
function scenario!(filename::String) :: Nothing
    locations = search(filename)
    if length(locations) == 0
        throw(ErrorException("$(filename) not found!"))
    end

    data = YAML.load_file(locations[1])

    if "models" in keys(data)
        for model in data["models"]
            # TODO
            println(model)
        end
    else
        println("No models specified. Is there something wrong here?")
    end
end

"""
    savescenario(filename::String)
Save the current scenario configuration to a YAML file. The
file extension defaults to '.yml'.
```jldoctest
julia> savescenario("prototype_visual_navigation")
```
"""
function savescenario(filename::String) :: Nothing
    #
end

end
