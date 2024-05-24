# [Setup and Print](@id configurationSetupAPI)
For further information on this topic, please see the [Power System Model](@ref PowerSystemModelManual) or [Measurement Model](@ref MeasurementModelManual) sections of the Manual. Please note that when using macros, they modify variables within the current scope.

---

###### Base Units
* [`@base`](@ref @base)

###### Input Units
* [`@power`](@ref @power)
* [`@voltage`](@ref @voltage)
* [`@current`](@ref @current)
* [`@parameter`](@ref @parameter)

###### Default Settings
* [`@default`](@ref @default)

###### Print
* [`printBus`](@ref printBus)
* [`printBranch`](@ref printBranch)
* [`printGenerator`](@ref printGenerator)

---

To load power system model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

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

## Default Settings
```@docs
@default
```

---

### Print
```@docs
printBus
printBranch
printGenerator
```