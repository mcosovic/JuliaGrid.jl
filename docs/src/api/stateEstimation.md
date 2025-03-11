# [State Estimation](@id StateEstimationAPI)
For further information on this topic, please see the [AC State Estimation](@ref ACStateEstimationManual), [PMU State Estimation](@ref PMUStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for state estimation, observability analysis, or bad data processing.

To load state estimation API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid, Ipopt, HiGHS
```

---

###### Observability Analysis
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Measurement))
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Measurement))
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island))
* [`pmuPlacement`](@ref pmuPlacement)
* [`pmuPlacement!`](@ref pmuPlacement!)

###### AC State Estimation
* [`gaussNewton`](@ref gaussNewton)
* [`acLavStateEstimation`](@ref acLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NWLS{Normal}}))
* [`stateEstimation!`](@ref stateEstimation!)
* [`setInitialPoint!`](@ref setInitialPoint!(::PowerSystem, ::ACStateEstimation))
* [`stateEstimation!`](@ref stateEstimation!(::PowerSystem, ::ACStateEstimation{NWLS{T}}) where T <: Union{Normal, Orthogonal})

###### PMU State Estimation
* [`pmuStateEstimation`](@ref pmuStateEstimation)
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{LWLS{Normal}}))
* [`stateEstimation!`](@ref stateEstimation!(::PowerSystem, ::PMUStateEstimation{LWLS{T}}) where T <: Union{Normal, Orthogonal})

###### DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)
* [`dcLavStateEstimation`](@ref dcLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LWLS{Normal}}))
* [`stateEstimation!`](@ref stateEstimation!(::PowerSystem, ::DCStateEstimation{LWLS{T}}) where T <: Union{Normal, Orthogonal})

###### Bad Data Analysis
* [`residualTest!`](@ref residualTest!)

---

## Observability Analysis
```@docs
islandTopologicalFlow(::PowerSystem, ::Measurement)
islandTopological(::PowerSystem, ::Measurement)
restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)
pmuPlacement
pmuPlacement!
```

---

## AC State Estimation
```@docs
gaussNewton
acLavStateEstimation
solve!(::PowerSystem, ::ACStateEstimation{NWLS{Normal}})
setInitialPoint!(::PowerSystem, ::ACStateEstimation)
stateEstimation!(::PowerSystem, ::ACStateEstimation{NWLS{T}}) where T <: Union{Normal, Orthogonal}
```

---

## PMU State Estimation
```@docs
pmuStateEstimation
pmuLavStateEstimation
solve!(::PowerSystem, ::PMUStateEstimation{LWLS{Normal}})
stateEstimation!(::PowerSystem, ::PMUStateEstimation{LWLS{T}}) where T <: Union{Normal, Orthogonal}
```

---

## DC State Estimation
```@docs
dcStateEstimation
dcLavStateEstimation
solve!(::PowerSystem, ::DCStateEstimation{LWLS{Normal}})
stateEstimation!(::PowerSystem, ::DCStateEstimation{LWLS{T}}) where T <: Union{Normal, Orthogonal}
```

---

## Bad Data Analysis
```@docs
residualTest!
```