# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

---

###### Build AC Optimal Power Flow Model
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)

###### Solve AC Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow))

###### Build DC Optimal Power Flow Model
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve DC Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

---

## Build AC Optimal Power Flow Model
```@docs
acOptimalPowerFlow
```

---

## Solve AC Optimal Power Flow
```@docs
solve!(::PowerSystem, ::ACOptimalPowerFlow)
```

---

## Build DC Optimal Power Flow Model
```@docs
dcOptimalPowerFlow
```

---

## Solve DC Optimal Power Flow
```@docs
solve!(::PowerSystem, ::DCOptimalPowerFlow)
```