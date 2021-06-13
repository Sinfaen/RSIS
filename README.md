# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS

## Dependencies
- Julia
    - Unitful
- C++17
- Meson
    - Ninja
    - Python3

## Build Steps
```shell
mkdir builddir
meson setup builddir
cd builddir
meson compile
```

## Run Tests

### Entire Test Suite
```shell
meson test
```

### Individual Tests

