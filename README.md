# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS

## Dependencies
- Julia
    - StaticArrays
    - JSON3
- C++17
- Meson
    - Ninja
    - Python3

## Test Setup
- Catch2

## Build Steps
```shell
mkdir builddir
meson setup builddir
cd builddir
meson compile
```

## Run Tests
```shell
meson test
```
