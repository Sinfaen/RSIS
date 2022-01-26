# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS
- Ubuntu (WSL2)
- Windows

## Dependencies
- Julia
    - DataStructures
    - DataFrames
    - Unitful
    - YAML
- Rust
    - num-complex

### Optional Dependencies
C++ Projects
- Meson (>= 0.61.1)
Fortran Projects
- fpm (Fortran Package Manager)

## Core Library Build Steps
```bash
$ cd utilities
$ julia -L build.jl -e "build()"
```
