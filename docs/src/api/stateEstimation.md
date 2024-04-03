# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [PMU State Estimation](@ref PMUStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Observability Analysis
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Measurement))
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Measurement))
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island))

###### AC State Estimation
* [`gaussNewton`](@ref gaussNewton)
* [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}}))

###### PMU State Estimation
* [`pmuPlacement`](@ref pmuPlacement)
* [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation)
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{LinearWLS{Normal}}))

###### DC State Estimation
* [`dcWlsStateEstimation`](@ref dcWlsStateEstimation)
* [`dcLavStateEstimation`](@ref dcLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}}))

###### Bad Data Analysis
* [`residualTest!`](@ref residualTest!)

---

To load state estimation API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

## Observability Analysis
```@docs
islandTopologicalFlow(::PowerSystem, ::Measurement)
islandTopological(::PowerSystem, ::Measurement)
restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)
```

---

## AC State Estimation
```@docs
gaussNewton
acLavStateEstimation
solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})
```

---

## PMU State Estimation
```@docs
pmuPlacement
pmuWlsStateEstimation
pmuLavStateEstimation
solve!(::PowerSystem, ::PMUStateEstimation{LinearWLS{Normal}})
```

---

## DC State Estimation
```@docs
dcWlsStateEstimation
dcLavStateEstimation
solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})
```

---


## Bad Data Analysis
```@docs
residualTest!
```