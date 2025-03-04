# [State Estimation](@id StateEstimationAPI)
For further information on this topic, please see the [AC State Estimation](@ref ACStateEstimationManual), [PMU State Estimation](@ref PMUStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for state estimation, observability analysis, or bad data processing.

To load state estimation API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
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
* [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}}))
* [`acStateEstimation!`](@ref acStateEstimation!)
* [`setInitialPoint!`](@ref setInitialPoint!(::PowerSystem, ::ACStateEstimation))

###### PMU State Estimation
* [`pmuStateEstimation`](@ref pmuStateEstimation)
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{LinearWLS{Normal}}))

###### DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)
* [`dcLavStateEstimation`](@ref dcLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}}))

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
solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})
acStateEstimation!
setInitialPoint!(::PowerSystem, ::ACStateEstimation)
```

---

## PMU State Estimation
```@docs
pmuStateEstimation
pmuLavStateEstimation
solve!(::PowerSystem, ::PMUStateEstimation{LinearWLS{Normal}})
```

---

## DC State Estimation
```@docs
dcStateEstimation
dcLavStateEstimation
solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})
```

---

## Bad Data Analysis
```@docs
residualTest!
```