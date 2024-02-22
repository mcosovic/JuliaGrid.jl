# [Power Flow](@id PowerFlowAPI)

For further information on this topic, please see the [AC Power Flow](@ref ACPowerFlowManual) or [DC Power Flow](@ref DCPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### AC Power Flow
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson))


###### DC Power Flow
* [`dcPowerFlow`](@ref dcPowerFlow)
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow))

###### Utility Functions
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!) 
* [`startingVoltage!`](@ref startingVoltage!) 

---

## AC Power Flow
```@docs
newtonRaphson
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
mismatch!(::PowerSystem, ::NewtonRaphson)
solve!(::PowerSystem, ::NewtonRaphson)
```

---

## DC Power Flow
```@docs
dcPowerFlow
solve!(::PowerSystem, ::DCPowerFlow)
```

---

## Utility Functions
```@docs
reactiveLimit!
adjustAngle!
startingVoltage!
```
