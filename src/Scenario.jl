
module MScenario

export scenario!, savescenario

using ..YAML
using ..MLibrary
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
Load a scenario YAML file from the filepaths. Loading a
new scenario overrides the previously loaded scenario if it exists.
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

    num_libs = 0
    num_mods = 0
    if "models" in keys(data)
        for (library, instances) in data["models"]
            load(library)
            num_libs += 1
            for (instance, _) in instances
                newmodel(library, instance)
                num_mods += 1
            end
        end
    end
    @info "Scenario loaded: $num_libs libraries, $num_mods models"
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
