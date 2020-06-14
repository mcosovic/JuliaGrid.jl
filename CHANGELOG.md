# JuliaGrid changelog

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
