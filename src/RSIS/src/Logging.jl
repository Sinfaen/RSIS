
module MLogging

export setlogfile, logmsg

export LOG, WARNING, ERROR, CUSTOM

# globals

# types

@enum MsgType::Int32 begin
    LOG     = 0
    WARNING = 1
    ERROR   = 2
    CUSTOM  = 3
end

_msgtypetostring = Dict(zip(instances(MsgType), String.(Symbol.(instances(MsgType)))))

"""
    setlogfile(filename::String)
Set the log file corresponding to this run.
"""
function setlogfile(filename::String)
end

"""
    writelogfile()
Write the current contents of the log file to filesystem
"""
function writelogfile()
end

"""
    logmsg(message::String)
Log a message to the simulation log file
"""
function logmsg(message::String, type::MsgType)
    # TODO initial implementation
    println("[" * _msgtypetostring[type] * "]: " * message)
end

end