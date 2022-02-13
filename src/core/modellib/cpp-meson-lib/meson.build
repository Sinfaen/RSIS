
project('rsis-cpp-extension', ['c', 'cpp'],
    version : '1.0.0',
    default_options : [ 'cpp_std=c++17'])

shared_library('rsis-cpp-extension', 'BaseModel.cxx',
    install : true,
    install_dir : '.')
install_headers('BaseModel.hxx', subdir : 'rsis-cpp')
