
# Provides the RSIS core framework access to the Logging module
# TODO: support the event framework
module MLogging

export clear_event_mapping, add_event_mapping

using ..Logging

# globals
_event_map = Dict{Int64, String}();

# types
function clear_event_mapping()
    _event_map = Dict{Int64, String}();
end

function add_event_mapping(id::Int64, message::String) :: Nothing
    if id in keys(_event_map)
        @warn "ID($id) overwritten"
    end
    _event_map[id] = message;
end

end