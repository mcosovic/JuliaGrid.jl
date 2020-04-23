## JuliaGrid

[![Documentation](https://github.com/mcosovic/JuliaGrid.jl/workflows/Documentation/badge.svg)](https://mcosovic.github.io/JuliaGrid.jl/dev/)

<a href="https://mcosovic.github.io/JuliaGrid.jl/dev/"><img align="right" width="145" src="/docs/src/assets/logo2.png" /></a>

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver,  and allows a variety of display and manipulation options.

We have tested and verified simulation tool using different scenarios to the best of our ability. As a user of this simulation tool, you can help us to improve future versions, we highly appreciate your feedback about any errors, inaccuracies, and bugs. For more information, please visit [documentation](https://mcosovic.github.io/JuliaGrid/dev/) site.

The software package provides the solution of the AC and DC power flow, non-linear and DC state estimation (work in progress), as well as the state estimation with PMUs (work in progress), with standalone measurement generator.

<p align="middle"><a href="https://mcosovic.github.io/JuliaGrid.jl/dev/man/flow/" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulepf.png" width="110"></a> <a href="" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulese.png" width="110"></a> <a href="https://mcosovic.github.io/JuliaGrid.jl/dev/man/generator/" itemprop="contentUrl" data-size="600x400"> <img src="/docs/src/assets/modulemg.png" width="110"></a></p>

<!-- MATGRID includes, inter alia, the weighted least-squares and least absolute values state estimation, optimal PMU placement, and bad data processing.   -->

### Installation
The package requires Julia 1.3 and higher, to install `JuliaGrid` package, you can run the following:
```
pkg> add https://github.com/mcosovic/JuliaGrid
```

###  Quick Start Power Flow
```julia-repl
julia> bus, branch, generator = runpf("dc", "case14.h5, "main", "flow")
```
```julia-repl
julia> bus, branch, generator = runpf("nr", "case14.h5, "main"; max = 20, stop = 1.0e-8)
```

###  Quick Start Measurement Generator
```julia-repl
julia> runmg("case14.xlsx"; pmuset = "optimal")
```
```julia-repl
julia> runmg("case14.h5"; legacyset = "all", pmuvariance = ["all" 1e-5])
```

###  Changelog
Major changes:
- 2020-04-17 Added power flow and measurement generator functions
