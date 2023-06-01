# [DC Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

###### Build Model
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow)

###### Solve Optimal Power Flow
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow))

###### Delete Constraints
* [`deleteBalance!`](@ref deleteBalance!(::DCOptimalPowerFlow))
* [`deleteLimit!`](@ref deleteLimit!(::DCOptimalPowerFlow))
* [`deleteRating!`](@ref deleteRating!(::DCOptimalPowerFlow))
* [`deleteCapability!`](@ref deleteCapability!(::DCOptimalPowerFlow))

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
deleteBalance!(::DCOptimalPowerFlow)
deleteLimit!(::DCOptimalPowerFlow)
deleteRating!(::DCOptimalPowerFlow)
deleteCapability!(::DCOptimalPowerFlow)
```