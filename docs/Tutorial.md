# Tutorial

## What is RSIS
RSIS is a highly experimental Julia/C++17 scheduling framework designed for building non real-time, and soft real-time simulations. Supporting hard real-time simulations is a long term goal. Users develop models in C++17, while configuring their simulations in Julia.

### Soft vs Hard Real-Time


## Why Julia and C++
One of the goals of this project is to create a framework that utilizes C++17. C/C++ are engineering juggernauts, and this framework intends to bring in more modern features of C++ while still being capable of compiling/linking to legacy code.

Julia is similar to Python, but with a heavy focus on scientific computation. This naturally lends itself to handling simulation configuration.

## Road Map
This framework is experimental and in development.
- [ ] Add Model Interface Generation
- [ ] Add Thread Generation
- [ ] Add Non Real-Time Scheduling
- [ ] Add Model Connection
- [ ] Add Logging Capability
- [ ] Add MacOS Soft Real-Time Scheduling
- [ ] Add Ubuntu Soft Real-Time Scheduling
- [ ] Add Project Environment Handling
- [ ] Add GUI
- [ ] Add MonteCarlo Capability
- [ ] Add Code Autogeneration

## Quickstart
The basic idea behind RSIS is that models developed by the user are scheduled one after another on threads, all handled via the Julia REPL. The core scheduler is developed in C++, with the Julia wrapper handling the calls to the core library and also performing configuration validation.

See [DevelopingModels](DevelopingModels.md) for more details on building models.

## Comparison to Other Simulation Frameworks
### Simulink
Simulink is based on a visual programming style, with users defining blocks and their connections. All inputs to RSIS are text-based, with a read-only GUI provided for ease of use.

Also, Simulink is proprietary. RSIS is not.

