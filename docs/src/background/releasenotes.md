# [Release Notes](@id ReleaseNotes)

## Version 0.6.2

Release Date: June 26, 2026

#### Performance
  * Improved AC and DC nodal matrix construction by using a preallocated CSC builder instead of triplet assembly through `sparse`.
  * Reduced Newton-Raphson setup time and memory use by constructing the Jacobian pattern directly as a CSC matrix and filling Jacobian values through existing nonzero entries.
  * Improved Gauss-Seidel AC power flow iterations by avoiding repeated sparse diagonal lookups during voltage updates.
  * Reduced fast Newton-Raphson setup time and memory use by constructing active and reactive Jacobian patterns directly as CSC matrices.

#### Internal
  * Added shared sparse matrix construction utilities for backend model-building routines.
  * Added shared helpers for updating values of entries that are already stored in CSC sparse matrix patterns.
  * Replaced the internal power-injection sum helper that accepted an operator argument with explicit plus and minus variants.

#### Documentation
  * Polished manual, tutorial, and examples for clarity and consistency.

---

## Version 0.6.1

Release Date: June 20, 2026

#### Fixed
  * Corrected AC optimal power flow PQ capability curve constraint selection for upper and lower reactive power limits.
  * Fixed reactive piecewise cost helper naming in AC optimal power flow.
  * Removed duplicated AC optimal power flow branch-flow dual start and retrieval calls.
  * Fixed various bugs in printing functions.
  * Fixed `@addConstraint` for scalar custom constraints without an initial `dual` value.
  * Improved `addDual!` error handling for piecewise constraints when `subindex` is missing or out of range.
  * Fixed `remove!(analysis, :variable; index)` to remove bound or fixed constraints on custom variables without deleting the variables.
  * Fixed variance propagation for squared current magnitude measurements in AC state estimation.
  * Fixed AC LAV state estimation initialization to use the analysis voltage state.
  * Fixed `pmuPlacement!` to pass the PMU `square` setting when creating phasor measurements.

#### Performance
  * Reduced unnecessary allocations in power system, measurement, model, and postprocessing update paths.
  * Improved model-building and analysis update routines by avoiding redundant work and reusing existing containers where possible.

#### Internal
  * Standardized mutating helper and wrapper functions to return `nothing` when no result is intended.

#### Documentation
  * Polished manual and tutorial wording, examples, references, and release-note organization for clarity and consistency.

---


## Version 0.6.0

Release Date: June 17, 2026

#### Breaking
  * Renamed the `ChiTest.treshold` field to `ChiTest.threshold`.

#### Added
  * Added `LL` as a Cholesky-based factorization option for supported power flow and state estimation analyses.
  * Added `LL` support in bad data analysis by reusing the Cholesky factorization for selected-inverse projections.
  * Added support for optimal PMU placement that includes legacy measurements.
  * Introduced the `optimal` keyword in the function [`powerSystem`](@ref powerSystem) to skip importing data related to optimal power flow analyses, see [Partial Load for Faster Import](@ref PartialLoadFasterImportManual).
  * Exported and documented the grouped analysis type aliases [`PowerFlow`](@ref PowerFlow), [`OptimalPowerFlow`](@ref OptimalPowerFlow), and [`StateEstimation`](@ref StateEstimation).
  * Exported and documented the grouped system and measurement type aliases [`Component`](@ref Component) and [`Meter`](@ref Meter).
  * Documented that unit, template, configuration, and default macros modify global JuliaGrid settings.

#### Fixed
  * Improved `LDLt` handling for symmetric sparse systems whose stored values are not exactly numerically symmetric.
  * Improved package root detection for both installed and development checkouts.
  * Updated documentation for [optimal PMU placement](@ref optimalpmu).
  * Defined optimal PMU placement variables as binary rather than integer.
  * Fixed an error that occurred when bad data was processed after the Peter-Wilkinson method.
  * Fixed PSS/E transformer magnetizing data handling.
  * Fixed `@default(power)` to reset the apparent power live unit to per-unit.
  * Updated global settings macros to evaluate keyword values at the call site, including local variables.
  * Updated power system tests to match the current cost-function error messages.
  * Adjusted MATPOWER and PSS/E section parsing to avoid a Julia 1.12 compiler regression affecting boolean flag propagation.

#### Performance
  * Improved efficiency when updating wattmeters with DC state estimation.
  * Reduced allocations and runtime when building AC/DC power system models and detecting physical islands.
  * Reduced allocations and improved efficiency in bad data analysis routines.
  * Reduced allocations in measurement add/update paths for voltmeters, ammeters, wattmeters, varmeters, and PMUs.
  * Improved measurement status configuration routines by avoiding temporary index slices and matrix construction.
  * Reduced allocations in AC/DC postprocessing, including DC state-estimation power updates and DC injection calculations.
  * Improved AC/DC power model postprocessing by reusing existing result containers where possible.
  * Lightly optimized MATPOWER, PSS/E, and HDF5 power system load/save paths.
  * Reduced temporary allocations in selected power flow and state estimation hot paths.
  * Reduced allocations and runtime in observability island detection, especially when merging flow-observable islands.
  * Improved optimal PMU placement result assembly for large systems by avoiding repeated scans over all branches.

#### Internal
  * Removed unused parameters from the `PowerSystem` type.
  * Refined branch add/update internals to avoid unnecessary work while preserving model reuse behavior.
  * Reviewed and lightly optimized backend equation helpers.
  * Refined internal template, label, and per-unit conversion utilities for clearer dispatch and less unnecessary work.
  * Refactored template macro helpers and `@default` reset logic to reduce duplicated internal state updates.
  * Cleaned up repeated field access in postprocessing routines.

#### Testing
  * Expanded the precompile workload to cover additional commonly used analysis solve paths.
  * Sanity checked the internal cleanup with targeted power flow and state estimation.

---

## Version 0.5.0

Release Date: July 5, 2025

#### Breaking
  * Introduced a new parser for PSSE case files.
  * Added support for KLU factorization.
  * Reformulated interval constraints in optimal power flow as two separate constraints.
  * Introduced support for extending the optimal power flow formulation.
  * Implemented the Peters-Wilkinson method for solving all state estimation models.

#### Added
  * Functions to display the currently active templates.
  * Functions to show the unit system used for keyword interpretation.
  * Functions to print data associated with specific components.
  * Support for configuring label types for each group of power system components and measurement types.
  * Ability to read bus names from MATPOWER and PSSE imports.
  * Support for the `setInitialPoint!` function across all LAV estimators.

#### Fixed
  * Fixed issues related to function precompilation.
  * Corrected verbosity settings in optimization methods when the `silent` flag is enabled.

#### Other
  * Optimized memory allocation in all power flow algorithms.
  * Improved memory handling in all WLS state estimation algorithms.
  * Updated default generator output power limits.
  * Improved efficiency in merging disconnected flow islands.
  * Removed the requirement for a generator at the slack bus in state estimation models.

---

## Version 0.4.0

Release Date: April 11, 2025

#### Breaking
  * Introduced references to `PowerSystem` and `Measurement` types, allowing functions to be used with only the parent arguments.
  * Enhanced computational efficiency of LAV estimators by removing deviation variables associated with state variables.
  * Renamed type definitions for improved readability.

#### Added
  * Bad data Chi-squared test function [`chiTest`](@ref chiTest).
  * Wrapper function for creating `PowerSystem` and `Measurement` types [`ems`](@ref ems).

#### Fixed
  * Update analysis functions now correctly apply updates, even changes are made regardless of the specific type.
  * Adjusted tables and figures in the documentation for better compatibility with dark themes.

#### Other
  * Added iteration counter variables to iterative algorithms.
  * Enabled support for including current magnitude measurements in squared form for AC state estimation.

---

## Version 0.3.0

Release Date: March 10, 2025

#### Breaking
  * Allowing macros to execute at the code line where they are called.

#### Added
  * Wrapper functions `powerFlow!` and `stateEstimation!`.

#### Fixed
  * Conversions between SI units and per-unit system
  * Various bugs related to printing data.
  * Various bugs related to integer labels.

---

## Version 0.2.0

Release Date: October 17, 2024

### Added
  * Power system printing functions:
    * [`printBusData`](@ref printBusData),
    * [`printBranchData`](@ref printBranchData),
    *  [`printGeneratorData`](@ref printGeneratorData).
  * Measurement printing functions:
    * [`printVoltmeterData`](@ref printVoltmeterData),
    * [`printAmmeterData`](@ref printAmmeterData),
    * [`printWattmeterData`](@ref printWattmeterData),
    * [`printVarmeterData`](@ref printVarmeterData),
    * [`printPmuData`](@ref printPmuData).
  * Constraint printing functions:
    * [`printBusConstraint`](@ref printBusConstraint),
    * [`printBranchConstraint`](@ref printBranchConstraint),
    * [`printGeneratorConstraint`](@ref printGeneratorConstraint).
  * Integer based labeling.

---

## Version 0.1.0

Release Date: April 19, 2024

#### Breaking
  * Initial stable public release.
