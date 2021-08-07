# Real-time SImulation Scheduler Framework

The RSIS Framework is used to build Real-Time simulations.

## Getting Started
- [Tutorial](docs/Tutorial.md)

## Systems
- MacOS
- Ubuntu (WSL2)

## Dependencies
- Julia
    - DataStructures
    - Unitful
    - YAML
- Rust

### Optional Dependencies
C++ Projects
- Meson

## Build Steps
```bash
$ mkdir builddir
$ meson setup builddir --prefix=/install --libdir=lib
$ cd builddir
$ meson compile
```

## Local install for RSIS
```bash
$ cd builddir
$ meson install --destdir ../
```

## Run Tests

### Entire Test Suite
```bash
$ meson test
```

### Individual Tests

