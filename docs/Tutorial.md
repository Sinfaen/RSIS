# Tutorial

## What is RSIS
RSIS is a highly experimental Julia/Rust scheduling framework designed for building non real-time, and soft real-time simulations. Supporting hard real-time simulations is a long term goal. Users develop models in Rust, while configuring their simulations in Julia.

### Soft vs Hard Real-Time


## Why Julia and Rust
Rust is a relatively new systems engineering language focusing heavily on speed and memory safety. The real-time simulation world is dominated by C & C++, and I want to help expose this world to Rust.

Julia is similar to Python, but with a heavy focus on scientific computation. This naturally lends itself to handling simulation configuration.

## Road Map
This framework is experimental and in development.
- [ ] Add C++ and Fortran model language support
- [x] Add Model Interface Generation
- [ ] Add Thread Generation
- [ ] Add Non Real-Time Scheduling
- [ ] Add Model Connection
- [ ] Add Logging Capability
- [ ] Add Data Replay Capability
- [x] Add Project Environment Handling
- [ ] Add MacOS Soft Real-Time Scheduling
- [ ] Add Ubuntu Soft Real-Time Scheduling
- [ ] Add GUI
- [ ] Add MonteCarlo Capability
- [ ] Add Code Autogeneration

## Quickstart
The basic idea behind RSIS is that models developed by the user are scheduled one after another on threads, all handled via the Julia REPL. The core scheduler is developed in Rust, with the Julia wrapper handling the calls to the core library and also performing configuration validation.

See [DevelopingModels](DevelopingModels.md) for more details on building models.

## Comparison to Other Simulation Frameworks
### Simulink
Simulink is based on a visual programming style, with users defining blocks and their connections. All inputs to RSIS are text-based, with a read-only GUI provided for ease of use.

Also, Simulink is proprietary. RSIS is not.

### Trick
Trick is an open-source C based framework developed by NASA.
