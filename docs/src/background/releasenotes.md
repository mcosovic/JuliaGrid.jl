# [Release Notes](@id ReleaseNotes)

---

## Version 0.4.0

Release Date: April 11, 2025

#### Breaking
  * Introduced references to `PowerSystem` and `Measurement` types, allowing functions to be used with only the parent arguments.
  * Enhanced computational efficiency of LAV estimators by removing deviation variables associated with state variables.
  * Renamed type definitions for improved readability.

#### Added
  * Bad data Chi-squared test function:
    * [`chiTest`](@ref chiTest).
  * Wrapper function for creating `PowerSystem` and `Measurement` types:
    * [`ems`](@ref ems).

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
  * Wrapper functions:
    * [`powerFlow!`](@ref powerFlow!)
    * [`stateEstimation!`](@ref stateEstimation!)

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