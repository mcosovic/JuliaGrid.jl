JuliaGrid
=============

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver,  and allows a variety of display and manipulation options.

The software package, among other things, includes:
 - [AC power flow analysis](@ref acpowerflow),
 - [DC power flow analysis](@ref dcpowerflow),
 - [non-linear state estimation](@ref nonlinearse) (work in progress),
 - [linear DC state estimation](@ref lineardcse),
 - [linear state estimation with PMUs](@ref linearpmuse) (work in progress),
 - [least absolute value state estimation](@ref lav),
 - [bad data processing](@ref baddata),
 - observability analysis (beta version),
 - optimal PMU placement.
---

### Main Features
Features supported by JuliaGrid can be categorised into three main groups:
 - [**Power Flow**](@ref runpf) - performs the AC and DC power flow analysis using the executive function `runpf()`,

 - [**State Estimation**](@ref runse) - performs non-linear, DC and PMU state estimation using the executive function `runse()`,

 - [**Standalone Measurement Generator**](@ref runmg) - generates a set of measurements using the executive function `runmg()`.
---

### Installation
JuliaGrid requires Julia 1.2 and higher. To install JuliaGrid package, run the following command:
```julia-repl
pkg> add https://github.com/mcosovic/JuliaGrid.jl
```

To load the package, use the command:
```julia-repl
julia> using JuliaGrid
```
---

###  Quick Start Power Flow
```julia-repl
julia> results, system, info = runpf("dc", "case14.h5", "main", "flow", "generation")
```
```julia-repl
julia> results, = runpf("nr", "case14.xlsx", "main"; max = 20, stop = 1.0e-8)
```

###  Quick Start State Estimation
```julia-repl
julia> results, = runse("case30se.h5", "dc", "estimate"; bad = ["pass" 2 "threshold" 3.5])
```
```julia-repl
julia> results, = runse("case14se.xlsx", "pmu", "main", "estimate")
```

###  Quick Start Measurement Generator
```julia-repl
julia> measurements, system, info = rungen("case14.h5"; pmuset = "optimal", pmuvariance = ["complete" 1e-5])
```
```julia-repl
julia> measurements, = rungen("case14.h5"; legacyset = ["redundancy" 3.1], legacyvariance = ["complete" 1e-4])
```
