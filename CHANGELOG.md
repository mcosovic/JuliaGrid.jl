# JuliaGrid changelog

![Maintenance][badge-maintenance] Change inversion of sparse matrix with sparse inverse subset in the bad data routine.

![Feature][badge-feature] Add the DC state estimation with bad data detection and least absolute value estimation.

![Bugfix][badge-bugfix] Branch current exact values in measurement generator function `runmg(...)` are corrected.

![Bugfix][badge-bugfix] Measurement generator now does not generate measurement values if keywords `legacyvariance` or/and `pmuvariance` are omitted.

![Bugfix][badge-bugfix] The output of the function `runmg(...)` related to the power system is correct now.


## Version `v0.0.1`

* ![BREAKING][badge-breaking] Initial release with power flow and measurement generator.


[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg
[badge-maintenance]: https://img.shields.io/badge/Maintained%3F-no-red.svg
