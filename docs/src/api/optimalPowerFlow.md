# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

---

###### AC Optimal Power Flow
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow))

###### DC Optimal Power Flow
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

###### Utility Function
* [`startingPrimal!`](@ref startingPrimal!(::PowerSystem, ::ACOptimalPowerFlow)) 

---

To load optimal power flow API functionalities into the current scope, one can employ the following command:
```@example LoadApi
using JuliaGrid, Ipopt, HiGHS
```

---

## AC Optimal Power Flow
```@docs
acOptimalPowerFlow
solve!(::PowerSystem, ::ACOptimalPowerFlow)
```

---

## DC Optimal Power Flow
```@docs
dcOptimalPowerFlow
solve!(::PowerSystem, ::DCOptimalPowerFlow)
```

---

## Utility Function
```@docs
startingPrimal!(::PowerSystem, ::ACOptimalPowerFlow)
```

