# [DC Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionAPI)

For further information on this topic, please see the [DC Optimal Power Flow](@ref DCOptimalPowerFlowManual) section of the Manual.

---

## API Index

###### Build Model
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

###### Delete Constraints
* [`deleteBalance!`](@ref deleteBalance!(::PowerSystem, ::DCOptimalPowerFlow))
* [`deleteLimit!`](@ref deleteLimit!(::PowerSystem, ::DCOptimalPowerFlow))
* [`deleteRating!`](@ref deleteRating!(::PowerSystem, ::DCOptimalPowerFlow))
* [`deleteCapability!`](@ref deleteCapability!(::PowerSystem, ::DCOptimalPowerFlow))


###### Power Analysis
Please refer to the [DC Analysis](@ref DCAnalysisAPI) section of the API.

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
deleteBalance!(::PowerSystem, ::DCOptimalPowerFlow)
deleteLimit!(::PowerSystem, ::DCOptimalPowerFlow)
deleteRating!(::PowerSystem, ::DCOptimalPowerFlow)
deleteCapability!(::PowerSystem, ::DCOptimalPowerFlow)
```