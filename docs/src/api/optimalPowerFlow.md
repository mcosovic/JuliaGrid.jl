# [Optimal Power Flow](@id OptimalPowerFlowAPI)

For further information on this topic, please see the [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual) or [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for optimal power flow analysis.

###### Build Model
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow)
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

###### Power Analysis
* [`power`](@ref power(::PowerSystem, ::ACPowerFlow))
* [`powerBus`](@ref powerBus(::PowerSystem, ::ACPowerFlow))
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::ACPowerFlow))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current`](@ref current(::PowerSystem, ::ACPowerFlow))
* [`currentBus`](@ref currentBus(::PowerSystem, ::ACPowerFlow))
* [`currentBranch`](@ref currentBranch(::PowerSystem, ::ACPowerFlow))

###### Delete Constraints
* [`deleteBalanceActive!`](@ref deleteBalanceActive!)
* [`deleteBalanceReactive!`](@ref deleteBalanceReactive!)
* [`deleteCapabilityActive!`](@ref deleteCapabilityActive!)
* [`deleteCapabilityReactive!`](@ref deleteCapabilityReactive!)
* [`deleteLimitAngle!`](@ref deleteLimitAngle!)
* [`deleteLimitMagnitude!`](@ref deleteLimitMagnitude!)
* [`deleteRatingActive!`](@ref deleteRatingActive!)
* [`deleteRatingFrom!`](@ref deleteRatingFrom!)
* [`deleteRatingTo!`](@ref deleteRatingFrom!)

---

## Build Model
```@docs
dcOptimalPowerFlow
```

---

## Solve Optimal Power Flow
```@docs
solve!(::PowerSystem, ::DCOptimalPowerFlow)
```

---

## Delete Constraints
```@docs
deleteBalanceActive!
deleteBalanceReactive!
deleteCapabilityActive!
deleteCapabilityReactive!
deleteLimitAngle!
deleteLimitMagnitude!
deleteRatingActive!
deleteRatingFrom!
deleteRatingFrom!
```