
inc_dir = include_directories('scheduler', 'thread', 'library', 'model', '../include')

shared_library('rsis',
    'rsis.cxx',
    'rsis_defs.cxx',
    'scheduler/NRTScheduler.cxx',
    'thread/ThreadHandler.cxx',
    'thread/Callback.cxx',
    'library/Loader.cxx',
    include_directories : inc_dir)
