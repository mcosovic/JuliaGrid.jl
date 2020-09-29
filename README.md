## JuliaGrid

[![Documentation][documentation-badge]][documentation] ![Build][build-badge]

<a href="https://mcosovic.github.io/JuliaGrid.jl/stable/"><img align="right" width="145" src="/docs/src/assets/logo2.png" /></a>

JuliaGrid is an open-source, easy-to-use simulation tool/solver for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by the Matpower, an open-source steady-state power system solver, and allows a variety of display and manipulation options.

We have tested and verified simulation tool using different scenarios to the best of our ability. As a user of this simulation tool, you can help us to improve future versions, we highly appreciate your feedback about any errors, inaccuracies, and bugs. For more information, please visit [documentation][documentation] site.

The software package provides the solution of the AC and DC power flow and optimal power flow, non-linear and DC state estimation, as well as the state estimation with PMUs, with standalone measurement generator.


### Installation
The package requires Julia 1.3 and higher, to install `JuliaGrid` package, you can run the following:
```
pkg> add https://github.com/mcosovic/JuliaGrid.jl
```


### Quick Start Power Flow
```julia-repl
results, system, info = runpf("nr", "case14.h5", "main", "flow"; max = 20, stop = 1.0e-8)
```
```julia-repl
results, = runpf("dc", "case14.h5", "main")
```


### Quick Start Optimal Power Flow
```julia-repl
results, system, info = runopf("case118.h5", "dc", "main", "flow", "generation")
```


### Quick Start State Estimation
```julia-repl
results, measurements, system, info = runse("case14se.xlsx", "dc", "main", "estimate", "error", "flow")
```
```julia-repl
results, measurements, system, info = runse("case14se.xlsx", "nonlinear", "main", "estimate"; start = "warm")
```
```julia-repl
results, = runse("case14se.xlsx", "pmu", "bad"; covariance = 1)
```
```julia-repl
data = runmg("case14.h5"; runflow = 1, legacyset = ["Pij" 10 "Pi" 7], legacyvariance = ["complete" 1e-10])
results, = runse(data, "dc", "estimate")
```


### Quick Start Measurement Generator
```julia-repl
measurements, system, info = runmg("case14.xlsx"; pmuset = "optimal")
```
```julia-repl
measurements, = runmg("case14.h5"; legacyset = "complete", pmuvariance = ["complete" 1e-5])
```


### Contributors
 - [Ognjen Kundacina][ognjen] - Schneider Electric DMS NS LLC Novi Sad, Serbia
 - [Muhamed Delalic][muhamed] - University of Sarajevo, Bosnia and Herzegovina
 - Lin Zeng - Cornell University, Ithaca, NY, USA
 - [Mirsad Cosovic][mirsad] - University of Sarajevo, Bosnia and Herzegovina


### Changelog
Major changes:
- 2020-09-29 the DC optimal power flow
- 2020-09-28 the nonlinear state estimation
- 2020-05-12 the DC state estimation with bad data and observability routines
- 2020-04-17 the power flow and measurement generator functions


[documentation-badge]: https://github.com/mcosovic/JuliaGrid.jl/workflows/Documentation/badge.svg
[build-badge]: https://github.com/mcosovic/JuliaGrid.jl/workflows/Build/badge.svg
[documentation]: https://mcosovic.github.io/JuliaGrid.jl/stable/
[mirsad]: https://www.linkedin.com/in/mirsad-cosovic-5a4972a9/
[ognjen]: https://www.linkedin.com/in/ognjen-kundacina-machine-learning-guy/
[muhamed]: https://www.linkedin.com/in/muhameddelalic/
