# [Setup and Print](@id setupPrintAPI)
For further information on this topic, please see the [Power System Model](@ref PowerSystemModelManual) or [Measurement Model](@ref MeasurementModelManual) sections of the Manual. Please note that when using macros, they modify variables within the current scope. Print functions can be used to print results to the REPL, or users can redirect the output to print results to a text file, for example.

To load power system model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### Base Units
* [`@base`](@ref @base)

###### Input Units
* [`@power`](@ref @power)
* [`@voltage`](@ref @voltage)
* [`@current`](@ref @current)
* [`@parameter`](@ref @parameter)

###### Label Types
* [`@label`](@ref @label)

###### Default Settings
* [`@default`](@ref @default)

###### Print Power System Data
* [`printBusData`](@ref printBusData)
* [`printBranchData`](@ref printBranchData)
* [`printGeneratorData`](@ref printGeneratorData)

###### Print Power System Summary
* [`printBusSummary`](@ref printBusSummary)
* [`printBranchSummary`](@ref printBranchSummary)
* [`printGeneratorSummary`](@ref printGeneratorSummary)

###### Print Measurement Data
* [`printVoltmeterData`](@ref printVoltmeterData)
* [`printAmmeterData`](@ref printAmmeterData)
* [`printWattmeterData`](@ref printWattmeterData)
* [`printVarmeterData`](@ref printVarmeterData)
* [`printPmuData`](@ref printPmuData)

###### Print Constraint Data
* [`printBusConstraint`](@ref printBusConstraint)
* [`printBranchConstraint`](@ref printBranchConstraint)
* [`printGeneratorConstraint`](@ref printGeneratorConstraint)

---

## Base Units
```@docs
@base
```

---

## Input Units
```@docs
@power
@voltage
@current
@parameter
```

---

## Label Types
```@docs
@label
```

---

## Default Settings
```@docs
@default
```

---

## [Print Power System Data](@id PrintPowerSystemDataAPI)
```@docs
printBusData
printBranchData
printGeneratorData
```

---

## [Print Power System Summary](@id PrintPowerSystemSummaryAPI)
```@docs
printBusSummary
printBranchSummary
printGeneratorSummary
```

---

## Print Measurement Data
```@docs
printVoltmeterData
printAmmeterData
printWattmeterData
printVarmeterData
printPmuData
```

---

## [Print Constraint Data](@id PrintConstraintDataAPI)
```@docs
printBusConstraint
printBranchConstraint
printGeneratorConstraint
```