
inc_dir = include_directories('scheduler', 'thread', 'library', 'model', '../include')

thread_dep = dependency('threads')

install_headers(
    '../include/rsis.hxx',
    '../include/rsis_types.hxx',
    'model/BaseModel.hxx')

shared_library('rsis',
    'rsis.cxx',
    'rsis_defs.cxx',
    'scheduler/TimeManager.cxx',
    'scheduler/NRTScheduler.cxx',
    'thread/ThreadHandler.cxx',
    'thread/Callback.cxx',
    'library/Loader.cxx',
    'library/ModelData.cxx',
    'library/ModelRegistration.cxx',
    include_directories : inc_dir,
    dependencies : thread_dep,
    install : true)
