# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS
- Ubuntu

## Dependencies
- Julia
    - DataStructures
    - Unitful
    - YAML
- C++17
- Meson
    - Ninja
    - Python3

## Build Steps
```bash
$ mkdir builddir
$ meson setup builddir
$ meson configure builddir --prefix install
$ cd builddir
$ meson compile
```

## Local install for RSIS
```bash
$ cd builddir
$ meson install --destdir ../src/RSIS
```

## Run Tests

### Entire Test Suite
```bash
$ meson test
```

### Individual Tests

