JuliaGrid
=============

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver,  and allows a variety of display and manipulation options.

The software package, among other things, includes:
 - AC power flow analysis,
 - DC power flow analysis,
 - non-linear state estimation (work in progress),
 - linear DC state estimation (work in progress),
 - linear state estimation with PMUs only (work in progress),
 - least absolute value state estimation (work in progress),
 - optimal PMU placement,
 - bad data processing (work in progress).
---

### Main Features
Features supported by JuliaGrid can be categorised into three main groups:
 - **Power Flow** - performs the AC and DC power flow analysis using the executive function `runpf(...)`;

 - **State Estimation** - performs non-linear, DC and PMU state estimation using the executive function `runse(...)`, where measurement variances and sets can be changed (work in progress);

 - **Standalone Measurement Generator** - generates a set of measurements according to the AC power flow analysis or predefined user data using the executive function `runmg(...)`.
---

### Installation
JuliaGrid requires Julia 1.2 and higher. To install JuliaGrid package, run the following command:
```julia-repl
pkg> add https://github.com/mcosovic/JuliaGrid
```

To load the package, use the command:
```julia-repl
julia> using JuliaGrid
```
---

###  Quick Start Power Flow
```julia-repl
julia> results = runpf("dc", "case14.h5", "main", "flow")
```
```julia-repl
julia> results = runpf("nr", "case14.xlsx", "main"; max = 20, stop = 1.0e-8)
```

###  Quick Start Measurement Generator
```julia-repl
julia> results = rungen("case14.h5"; pmuset = "optimal", pmuvariance = ["all" 1e-5])
```
```julia-repl
julia> results = rungen("case14.h5"; legacyset = ["redundancy" 3.1], legacyvariance = ["all" 1e-4])
```
