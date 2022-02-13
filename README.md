# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS
- Ubuntu (WSL2)
- Windows

## Required Dependencies
- Julia
    - DataStructures
    - DataFrames
    - Unitful
    - YAML
    - CSV
    - MsgPack
- Rust
    - rmp-serde
    - rmpv
    - num-complex

### Optional Dependencies
| Function | Dependency |
| -------- | ---------- |
| C++ Development | Meson (>= 0.61.1) |
| C++ Models | nlohmann-json (>= 3.10.5) |
| Fortran Development | Fortran Package Manager (fpm) TODO UPDATE |
| GUI | Stipple, Genie (TODO) |

## Core Library Build Steps
```bash
$ cd utilities
$ julia -L build.jl -e "build(release=true, clean=true)"
```
