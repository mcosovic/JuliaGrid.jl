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
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::AC))
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow))
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::AC))
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::AC))
* [`powerTo`](@ref powerTo(::PowerSystem, ::AC))
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::AC))
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::AC))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::AC))
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::AC))
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::AC))
* [`currentTo`](@ref currentTo(::PowerSystem, ::AC))
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::AC))

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