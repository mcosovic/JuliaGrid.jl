JuliaGrid
=============

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver, and allows a variety of display and manipulation options.

The software package, among other things, includes:
 - [AC power flow analysis](@ref acpowerflow),
 - [DC power flow analysis](@ref dcpowerflow),
 - DC optimal power flow analysis,
 - [non-linear state estimation](@ref nonlinearse),
 - [linear DC state estimation](@ref lineardcse),
 - [linear state estimation with PMUs](@ref linearpmuse),
 - [least absolute value state estimation](@ref lav),
 - [bad data processing](@ref baddata),
 - [observability analysis](@ref observability),
 - [optimal PMU placement](@ref optimalpmu).
---

### Main Features
Features supported by JuliaGrid can be categorised into three main groups:
 - [**Power Flow**](@ref runpf) - performs the AC and DC power flow analysis using the executive function `runpf()`,

  - [**Optimal Power Flow**](@ref runopf) - performs the DC and AC optimal power flow analysis using the executive function `runopf()`,

 - [**State Estimation**](@ref runse) - performs non-linear, DC and PMU state estimation using the executive function `runse()`,

 - [**Standalone Measurement Generator**](@ref runmg) - generates a set of measurements using the executive function `runmg()`.
---


### Installation
JuliaGrid requires Julia 1.3 and higher. To install JuliaGrid package, run the following command:
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
results, system, info = runpf("dc", "case14.h5", "main", "flow", "generation")
```
```julia-repl
results, = runpf("nr", "case14.xlsx", "main"; max = 20, stop = 1.0e-8)
```
---


###  Quick Start Optimal Power Flow
```julia-repl
results, system, info = runopf("case118.h5", "dc", "main", "flow", "generation")
```
---


###  Quick Start State Estimation
```julia-repl
results, = runse("case14se.xlsx", "nonlinear", "main", "estimate"; start = "warm")
```
```julia-repl
results, = runse("case30se.h5", "dc", "estimate"; bad = ["pass" 2 "threshold" 3.5])
```
```julia-repl
results, = runse("case14se.xlsx", "pmu", "main", "estimate")
```
---


###  Quick Start Measurement Generator
```julia-repl
measurements, system, info = runmg("case14.h5"; pmuset = "optimal", pmuvariance = ["complete" 1e-5])
```
```julia-repl
measurements, = runmg("case14.h5"; legacyset = ["redundancy" 3.1], legacyvariance = ["complete" 1e-4])
```
