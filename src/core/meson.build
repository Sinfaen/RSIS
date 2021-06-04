
inc_dir = include_directories('scheduler', 'thread', '../include')

shared_library('rsis',
    'rsis.cxx',
    'rsis_defs.cxx',
    'scheduler/NRTScheduler.cxx',
    'thread/ThreadHandler.cxx',
    'thread/Callback.cxx',
    include_directories : inc_dir)
