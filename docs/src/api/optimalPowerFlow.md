# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

---

###### Build AC Optimal Power Flow
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)

###### Solve AC Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow))

###### Build DC Optimal Power Flow
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve DC Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

###### Additional Function
* [`startingPrimal!`](@ref startingPrimal!(::PowerSystem, ::ACOptimalPowerFlow)) 
---

## Build AC Optimal Power Flow
```@docs
acOptimalPowerFlow
```

---

## Solve AC Optimal Power Flow
```@docs
solve!(::PowerSystem, ::ACOptimalPowerFlow)
```

---

## Build DC Optimal Power Flow
```@docs
dcOptimalPowerFlow
```

---

## Solve DC Optimal Power Flow
```@docs
solve!(::PowerSystem, ::DCOptimalPowerFlow)
```

---

## Additional Function
```@docs
startingPrimal!(::PowerSystem, ::ACOptimalPowerFlow)
```

