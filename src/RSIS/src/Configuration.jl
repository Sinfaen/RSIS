
module MConfiguration

"""
Contains information on the current sim configuration
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

function generate_config_file()
    println("Not implemented")
end

end
