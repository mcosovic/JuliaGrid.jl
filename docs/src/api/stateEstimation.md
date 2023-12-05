# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [AC State Estimation](@ref DCStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Build DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)

###### Solve DC State Estimation
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS))

###### Bad Data Analysis
* [`badData!`](@ref badData!)

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

---

## Bad Data Analysis
```@docs
badData!
```