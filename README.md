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
```bash
$ mkdir builddir
$ meson setup builddir
$ cd builddir
$ meson compile
```

## Local install for RSIS
```bash
$ mkdir src/RSIS/install
$ cd builddir
$ DESTDIR=../src/RSIS/install meson install
```

## Run Tests

### Entire Test Suite
```bash
$ meson test
```

### Individual Tests

