
module MLogging

export setlogfile, logmsg

# globals

# types

@enum MsgType::Int32 begin
    LOG     = 0
    WARNING = 1
    ERROR   = 2
    CUSTOM  = 3
end

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
end

end