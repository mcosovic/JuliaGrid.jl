# [Power Flow](@id PowerFlowAPI)
For further information on this topic, please see the [AC Power Flow](@ref ACPowerFlowManual) or [DC Power Flow](@ref DCPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

To load power flow API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### AC Power Flow
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson}))
* [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson}))
* [`setInitialPoint!`](@ref setInitialPoint!(::PowerSystem, ::ACPowerFlow))
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!)
* [`powerFlow!`](@ref powerFlow!(::PowerSystem, ::ACPowerFlow, ::IOStream))

###### DC Power Flow
* [`dcPowerFlow`](@ref dcPowerFlow)
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow))
* [`powerFlow!`](@ref powerFlow!(::PowerSystem, ::DCPowerFlow, ::IOStream))

---

## AC Power Flow
```@docs
newtonRaphson
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})
solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})
setInitialPoint!(::PowerSystem, ::ACPowerFlow)
reactiveLimit!
adjustAngle!
powerFlow!(::PowerSystem, ::ACPowerFlow, ::IOStream)
```

---

## DC Power Flow
```@docs
dcPowerFlow
solve!(::PowerSystem, ::DCPowerFlow)
powerFlow!(::PowerSystem, ::DCPowerFlow, ::IOStream)
```