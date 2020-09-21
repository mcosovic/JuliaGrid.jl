## JuliaGrid

[![Documentation](https://github.com/mcosovic/JuliaGrid.jl/workflows/Documentation/badge.svg)](https://mcosovic.github.io/JuliaGrid.jl/stable/) ![Build](https://github.com/mcosovic/JuliaGrid.jl/workflows/Build/badge.svg)

<a href="https://mcosovic.github.io/JuliaGrid.jl/stable/"><img align="right" width="145" src="/docs/src/assets/logo2.png" /></a>

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver,  and allows a variety of display and manipulation options.

We have tested and verified simulation tool using different scenarios to the best of our ability. As a user of this simulation tool, you can help us to improve future versions, we highly appreciate your feedback about any errors, inaccuracies, and bugs. For more information, please visit [documentation](https://mcosovic.github.io/JuliaGrid.jl/stable/) site.

The software package provides the solution of the AC and DC power flow, non-linear and DC state estimation (work in progress), as well as the state estimation with PMUs (work in progress), with standalone measurement generator.

<p align="middle"><a href="https://mcosovic.github.io/JuliaGrid.jl/dev/man/flow/" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulepf.png" width="110"></a> <a href="https://mcosovic.github.io/JuliaGrid.jl/dev/man/estimation/" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulese.png" width="110"></a> <a href="https://mcosovic.github.io/JuliaGrid.jl/dev/man/generator/" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulemg.png" width="110"></a></p>

<!-- MATGRID includes, inter alia, the weighted least-squares and least absolute values state estimation, optimal PMU placement, and bad data processing.   -->

### Installation
The package requires Julia 1.3 and higher, to install `JuliaGrid` package, you can run the following:
```
pkg> add https://github.com/mcosovic/JuliaGrid.jl
```

###  Quick Start Power Flow
```julia-repl
julia> results, system, info = runpf("nr", "case14.h5", "main", "flow"; max = 20, stop = 1.0e-8)
```
```julia-repl
julia> results, = runpf("dc", "case14.h5", "main")
```

###  Quick Start Measurement Generator
```julia-repl
julia> measurements, system, info = runmg("case14.xlsx"; pmuset = "optimal")
```
```julia-repl
julia> measurements, = runmg("case14.h5"; legacyset = "complete", pmuvariance = ["complete" 1e-5])
```

###  Quick Start State Estimation
```julia-repl
julia> results, measurements, system, info = runse("case14se.xlsx", "dc", "main", "estimate", "error", "flow")
```
```julia-repl
data = runmg("case14.h5"; runflow = 1, legacyset = ["Pij" 10 "Pi" 7], legacyvariance = ["complete" 1e-10])
results, = runse(data, "dc", "estimate")
```
```julia-repl
results, = runse("case14se.xlsx", "pmu", "bad"; covariance = 1)
```

###  Changelog
Major changes:
- 2020-05-12 Added the DC state estimation with bad data and observability routines
- 2020-04-17 Added the power flow and measurement generator functions
