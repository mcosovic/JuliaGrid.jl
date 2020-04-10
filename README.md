## JuliaGrid

<a href="https://github.com/mcosovic/MATGRID/wiki/MATGRID"><img align="right" width="145" src="/src/doc/logo_julia.png" /></a>

JuliaGrid is an easy-to-use simulation tool for researchers and educators provided as a Julia package, with source code released under MIT License. JuliaGrid is inspired by Matpower and allows a variety of display and manipulation options.

We have tested and verified simulation tool using different scenarios to the best of our ability. As a user of this simulation tool, you can help us to improve future versions, we highly appreciate your feedback about any errors, inaccuracies, and bugs. For more information, please visit our [wiki](https://github.com/mcosovic/MATGRID/wiki/MATGRID) site.

The software package provides the solution of the AC and DC power flow, non-linear and DC state estimation, as well as the state estimation with PMUs, with standalone measurement generator.

<p align="middle"><a href="https://github.com/mcosovic/MATGRID/wiki/Power-Flow" itemprop="contentUrl" data-size="600x400"> <img src="/src/doc/modulepf.png" width="110"></a> <a href="https://github.com/mcosovic/MATGRID/wiki/State-Estimation" itemprop="contentUrl" data-size="600x400"> <img src="/src/doc/modulese.png" width="110"></a> <a href="https://github.com/mcosovic/MATGRID/wiki/Measurement-Generator" itemprop="contentUrl" data-size="600x400"> <img src="/src/doc/modulemg.png" width="110"></a></p>

<!-- MATGRID includes, inter alia, the weighted least-squares and least absolute values state estimation, optimal PMU placement, and bad data processing.   -->

###  Quickstart Power Flow
```
bus, branch, generator = runpf("dc", "case14.h5, "main", "flow")
bus, branch, generator = runpf("nr", "case14.h5, "main"; max = 20, stop = 1.0e-8)
```

<!-- ###  Fast Run State Estimation
```
runse('ieee118_186', 'nonlinear', 'estimate');
runse('ieee118_186', 'dc', 'estimate');
runse('ieee14_20', 'pmu', 'pmuOptimal', 'estimate');
```

###  Changelog
Major changes:
- 2019-04-21 the DC state estimation with observability analysis and bad data processing optimized for large-scale systems
- 2019-04-08 Added the DC observability analysis with identification of observable islands
- 2019-04-03 Added observability analysis (DC state estimation only , beta version, please treat the results with attention)
- 2019-03-28 Added Gauss-Seidel, decoupled Newton-Raphson and fast decoupled Newton-Raphson algorithm
- 2019-03-21 Added least absolute value (LAV) state estimation
- 2019-03-19 Added bad data processing -->
