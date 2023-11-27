# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [AC Power Flow](@ref ACPowerFlowManual) or [DC Power Flow](@ref DCPowerFlowManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Build DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)

###### Solve DC State Estimation
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS))

---

## Build DC State Estimation
```@docs
dcStateEstimation
```

---

## Solve DC State Estimation
```@docs
solve!(::PowerSystem, ::DCStateEstimationWLS)
```
