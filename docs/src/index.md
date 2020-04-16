# JuliaGrid

JuliaGrid is an easy-to-use simulation tool for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by Matpower and allows a variety of display and manipulation options.

The software package, inter alia, includes:
 - AC power flow analysis,
 - DC power flow analysis,
 - non-linear state estimation,
 - linear DC state estimation,
 - linear state estimation with PMUs only,
 - least absolute value state estimation,
 - optimal PMU placement,
 - bad data processing.

## Functions

There are three main functions:
 - **Power Flow** - using the executive function `runpf(...)` runs the AC and DC power flow analysis;

 - **State Estimation** - using the executive function `runse(...)` runs the non-linear, DC and PMU state estimation, where measurement variances and sets can be changed;

 - **Standalone Measurement Generator** - using the executive function `runmg(...)` generates a set of measurements according to the AC power flow analysis.

## Installation
The package requires Julia 1.1 and higher, to install JuliaGrid package, you can run the following:
```julia-repl
pkg> add https://github.com/mcosovic/JuliaGrid
```

To load the package, use the command:
```julia-repl
julia> using JuliaGrid
```

##  Quick Start Power Flow
```julia-repl
julia> bus, branch, generator = runpf("dc", "case14.h5, "main", "flow")
julia> bus, branch, generator = runpf("nr", "case14.h5, "main"; max = 20, stop = 1.0e-8)
```
