
project('RSiS', ['c', 'cpp'],
    version : '0.1.0',
    license : 'MIT',
    default_options : [
        # build.* options affect (native: true) targets when cross-compiling
        'c_std=c11', 'build.c_std=c11',
        'cpp_std=c++17', 'build.cpp_std=c++17'
    ])
# ninja build files not being set correctly
add_project_arguments('-std=c++17', language : 'cpp')
subdir('src')
