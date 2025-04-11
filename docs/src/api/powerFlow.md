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
* [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson}))
* [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson}))
* [`setInitialPoint!`](@ref setInitialPoint!(::AcPowerFlow))
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!)
* [`powerFlow!`](@ref powerFlow!(::AcPowerFlow))

###### DC Power Flow
* [`dcPowerFlow`](@ref dcPowerFlow)
* [`solve!`](@ref solve!(::DcPowerFlow))
* [`powerFlow!`](@ref powerFlow!(::DcPowerFlow))

---

## AC Power Flow
```@docs
newtonRaphson
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
mismatch!(::AcPowerFlow{NewtonRaphson})
solve!(::AcPowerFlow{NewtonRaphson})
setInitialPoint!(::AcPowerFlow)
setInitialPoint!(::AcPowerFlow, ::AC)
reactiveLimit!
adjustAngle!
powerFlow!(::AcPowerFlow)
```

---

## DC Power Flow
```@docs
dcPowerFlow
solve!(::DcPowerFlow)
powerFlow!(::DcPowerFlow)
```