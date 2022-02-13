
project('HeightSensor', ['c', 'cpp'],
    version : '1.0.0',
    default_options : [
        'cpp_std=c++17'
    ])

inc_dir = include_directories(get_option('rsis_headers'))

nj_dep = dependency('nlohmann_json', fallback : ['nlohmann_json', 'nlohmann_json_dep'])

cc = meson.get_compiler('cpp')
ext_lib = cc.find_library('librsis-cpp-extension', dirs : [meson.current_source_dir() + '/' + get_option('langext')])

shared_library('height_sensor',
    'src/height_sensor.cxx',
    'src/height_sensor_interface.cxx',
    include_directories : inc_dir,
    dependencies : [ext_lib, nj_dep])

