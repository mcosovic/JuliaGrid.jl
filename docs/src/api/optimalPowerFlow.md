# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

---

###### Build Model
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow))

###### Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::AC))
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow))
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::AC))
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::AC))
* [`powerTo`](@ref powerTo(::PowerSystem, ::AC))
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::AC))
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::AC))

###### Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::AC))
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::AC))
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::AC))
* [`currentTo`](@ref currentTo(::PowerSystem, ::AC))
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::AC))

---

## Build Model
```@docs
acOptimalPowerFlow
dcOptimalPowerFlow
```

---

## Solve Optimal Power Flow
```@docs
solve!(::PowerSystem, ::ACOptimalPowerFlow)
solve!(::PowerSystem, ::DCOptimalPowerFlow)
```

