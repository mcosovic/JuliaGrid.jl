# JuliaGrid changelog

![Maintenance][badge-maintenance-yes] changed inversion of sparse matrix with sparse inverse subset in the bad data routine, case_ACTIVSg10k inv(Matrix(G)) 43.105664 seconds (9 allocations: 1.495 GiB, 0.04% gc time); sparseinv 0.360591 seconds (20.28 k allocations: 73.570 MiB, 62.08% gc time)

## Version `v0.0.2`

![Feature][badge-feature] added the observability analysis in the DC state estimation framework

![Maintenance][badge-maintenance-yes] type stability checked

![Feature][badge-feature] added the DC state estimation with bad data detection and least absolute value estimation

![Bugfix][badge-bugfix] branch current exact values in measurement generator function `runmg(...)` are corrected

![Bugfix][badge-bugfix] measurement generator now does not generate measurement values if keywords `legacyvariance` or/and `pmuvariance` are omitted

![Bugfix][badge-bugfix] the output of the function `runmg(...)` related to the power system is correct now.


## Version `v0.0.1`

* ![BREAKING][badge-breaking] Initial release with power flow and measurement generator.


[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg
[badge-maintenance-no]: https://img.shields.io/badge/Maintained%3F-no-red.svg
[badge-maintenance-yes]: https://img.shields.io/badge/Maintained%3F-yes-green.svg
