# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

###### Build Model
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow))

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

