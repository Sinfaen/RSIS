
project('HeightSensor', ['c', 'cpp'],
    version : '1.0.0',
    default_options : [
        'cpp_std=c++17'
    ])

inc_dir = include_directories(get_option('rsis_headers'))

shared_library('heightSensor',
    'heightSensorLib.cxx',
    'heightSensor_Model.cxx',
    'heightSensor_interface.cxx',
    include_directories : inc_dir)
