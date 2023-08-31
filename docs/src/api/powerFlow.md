# [Power Flow](@id PowerFlowAPI)

For further information on this topic, please see the [AC Power Flow](@ref ACPowerFlowManual) or [DC Power Flow](@ref DCPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Build AC Power Flow Model
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)

###### Solve AC Power Flow
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson))

###### Additional AC Functions
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!) 

###### Build DC Power Flow Model
* [`dcPowerFlow`](@ref dcPowerFlow)

###### Solve DC Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow))
 
---

## Build AC Power Flow Model
```@docs
newtonRaphson
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
```

---

## Solve AC Power Flow
```@docs
mismatch!(::PowerSystem, ::NewtonRaphson)
solve!(::PowerSystem, ::NewtonRaphson)
```

---

## Additional AC Functions
```@docs
reactiveLimit!
adjustAngle!
```

---

## Build DC Power Flow Model
```@docs
dcPowerFlow
```

---

## Solve DC Power Flow
```@docs
solve!(::PowerSystem, ::DCPowerFlow)
```
