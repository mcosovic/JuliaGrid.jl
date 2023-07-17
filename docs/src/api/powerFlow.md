# [Power Flow](@id PowerFlowAPI)

For further information on this topic, please see the [AC Power Flow](@ref ACPowerFlowManual) or [DC Power Flow](@ref DCPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

###### Build Model
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)
* [`dcPowerFlow`](@ref dcPowerFlow)

###### Solve Power Flow
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson))

###### Power Analysis
* [`power`](@ref power(::PowerSystem, ::ACPowerFlow))
* [`powerBus`](@ref powerBus(::PowerSystem, ::ACPowerFlow))
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::ACPowerFlow))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current`](@ref current(::PowerSystem, ::ACPowerFlow))
* [`currentBus`](@ref currentBus(::PowerSystem, ::ACPowerFlow))
* [`currentBranch`](@ref currentBranch(::PowerSystem, ::ACPowerFlow))

###### Additional Functions
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!)

---

## Build Model
```@docs
newtonRaphson
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
dcPowerFlow
```

---

## Solve Power Flow
```@docs
mismatch!(::PowerSystem, ::NewtonRaphson)
solve!(::PowerSystem, ::NewtonRaphson)
solve!(::PowerSystem, ::DCPowerFlow)
```

---

## Additional Functions
```@docs
reactiveLimit!
adjustAngle!
```