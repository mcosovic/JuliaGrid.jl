# JuliaGrid changelog

![featureadd] built-in parser for Matpower input cases

## Version `v0.0.5`

![bugfix] the nonlinear state estimation Jacobian slack column

![docs] maintenance run settings

![docs] the DC optimal power flow run settings

![featureadd] the DC optimal power flow

## Version `v0.0.4`

![featureadd] the nonlinear state estimation

![maintenanceyes] the DC state estimation without remove slack column

![maintenanceyes] the DC power flow without remove row/column from Ybus

![featureadd] the belief propagation observability method

![maintenanceyes] connected components of sparse matrices using SimpleWeightedGraph

![sourceadd] the belief propagation observability method

![featureadd] the topological island detection method based on the multi-stage procedure

![maintenanceyes] the bus numbering

## Version `v0.0.3`

![featureadd] the linear state estimation with PMUs and bad data routine

![breaking] the stable version of the DC state estimation with all routines

![breaking] the stable version of the power flow

![breaking] the stable version of the measurement generator

![docs] the observability analysis

![maintenanceyes] speed-up the observability analysis

![docs] bad data processing and least absolute value method

![bugfix] pseudo-measurements are included in error metrics

![bugfix] least absolute value objective function

![bugfix] active power flow and injection measurement values in the DC state estimation

![docs] theoretical background: state estimation

![docs] theoretical background: network equations and power flow

![docs] input data

![maintenanceyes] improved memory usage

![bugfix] bus injection power in the DC power flow

![bugfix] Pshift in the DC Ybus matrix

![maintenanceyes] `runse(...)` function accepts output variables from `runmg(...)`, and generating sets is now done exclusively using the function `runmg(...)`

![maintenanceyes] changed the inversion of a sparse matrix with the sparse inverse subset in the bad data routine, case_ACTIVSg10k -> built-in inversion 43.105664 seconds; sparseinv 0.360591 seconds


## Version `v0.0.2`

![featureadd] the observability analysis in the DC state estimation framework

![maintenanceyes] type stability checked

![featureadd] the DC state estimation with bad data detection and least absolute value estimation

![bugfix] branch current exact values in measurement generator function `runmg(...)`

![bugfix] measurement generator does not generate measurement values if keywords `legacyvariance` or/and `pmuvariance` are omitted

![bugfix] the output of the function `runmg(...)` related to the power system


## Version `v0.0.1`

![breaking] initial release with power flow and measurement generator


[breaking]: https://img.shields.io/badge/breaking-red.svg
[featureadd]: https://img.shields.io/badge/feature-add-brightgreen.svg
[maintenanceyes]: https://img.shields.io/badge/maintenance-yes-green.svg
[bugfix]: https://img.shields.io/badge/bug-fix-red.svg
[docs]: https://img.shields.io/badge/docs-update-blue.svg
[sourceadd]: https://img.shields.io/badge/source%20code-add-brightgreen
