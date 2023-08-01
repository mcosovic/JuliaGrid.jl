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
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::ACAnalysis))
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow))
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::ACAnalysis))
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::ACAnalysis))
* [`powerTo`](@ref powerTo(::PowerSystem, ::ACAnalysis))
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::ACAnalysis))
* [`powerLoss`](@ref powerLoss(::PowerSystem, ::ACAnalysis))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::ACAnalysis))
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::ACAnalysis))
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::ACAnalysis))
* [`currentTo`](@ref currentTo(::PowerSystem, ::ACAnalysis))
* [`currentLine`](@ref currentLine(::PowerSystem, ::ACAnalysis))

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