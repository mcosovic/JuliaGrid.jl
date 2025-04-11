# [Optimal Power Flow](@id OptimalPowerFlowAPI)
For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

To load optimal power flow API functionalities into the current scope, one can employ the following command:
```@example LoadApi
using JuliaGrid, Ipopt
```

---

###### AC Optimal Power Flow
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)
* [`solve!`](@ref solve!(::AcOptimalPowerFlow))
* [`setInitialPoint!`](@ref setInitialPoint!(::AcOptimalPowerFlow))
* [`powerFlow!`](@ref powerFlow!(::AcOptimalPowerFlow))

###### DC Optimal Power Flow
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)
* [`solve!`](@ref solve!(::DcOptimalPowerFlow))
* [`setInitialPoint!`](@ref setInitialPoint!(::DcOptimalPowerFlow))
* [`powerFlow!`](@ref powerFlow!(::DcOptimalPowerFlow))

---

## AC Optimal Power Flow
```@docs
acOptimalPowerFlow
solve!(::AcOptimalPowerFlow)
setInitialPoint!(::AcOptimalPowerFlow)
setInitialPoint!(::AcOptimalPowerFlow, ::AC)
powerFlow!(::AcOptimalPowerFlow)
```

---

## DC Optimal Power Flow
```@docs
dcOptimalPowerFlow
solve!(::DcOptimalPowerFlow)
setInitialPoint!(::DcOptimalPowerFlow)
setInitialPoint!(::DcOptimalPowerFlow, ::DC)
powerFlow!(::DcOptimalPowerFlow)
```