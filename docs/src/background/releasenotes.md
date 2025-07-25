# [Release Notes](@id ReleaseNotes)


---

## Version 0.5.2

Release Date: July 25, 2025

#### Fixed
  * Fixed an error that occurred when bad data was processed after the Peter-Wilkinson method

---

## Version 0.5.1

Release Date: July 12, 2025

#### Added
  * Introduced the `optimal` keyword in the function [`powerSystem`](@ref powerSystem) to skip importing data related to optimal power flow analyses, see [Partial Load for Faster Import](@ref PartialLoadFasterImportManual).

#### Other
  * Removed unused parameters from the `PowerSystem` type.

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
  * Wrapper functions [`powerFlow!`](@ref powerFlow!) and [`stateEstimation!`](@ref stateEstimation!).

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