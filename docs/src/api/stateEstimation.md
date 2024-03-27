# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [PMU State Estimation](@ref PMUStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Observability Analysis
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Wattmeter))
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Wattmeter))
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt))

###### AC State Estimation
* [`gaussNewton`](@ref gaussNewton)
* [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimationWLS{NonlinearWLS}))

###### PMU State Estimation
* [`pmuPlacement`](@ref pmuPlacement)
* [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation)
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS}))

###### DC State Estimation
* [`dcWlsStateEstimation`](@ref dcWlsStateEstimation)
* [`dcLavStateEstimation`](@ref dcLavStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS}))

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
islandTopologicalFlow(::PowerSystem, ::Wattmeter)
islandTopological(::PowerSystem, ::Wattmeter)
restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)
```

---

## AC State Estimation
```@docs
gaussNewton
solve!(::PowerSystem, ::ACStateEstimationWLS{NonlinearWLS})
```

---

## PMU State Estimation
```@docs
pmuPlacement
pmuWlsStateEstimation
pmuLavStateEstimation
solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})
```

---

## DC State Estimation
```@docs
dcWlsStateEstimation
dcLavStateEstimation
solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})
```

---


## Bad Data Analysis
```@docs
residualTest!
```