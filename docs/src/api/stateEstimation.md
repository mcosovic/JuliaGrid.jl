# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [AC State Estimation](@ref DCStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Observability Analysis
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Wattmeter))
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Wattmeter))
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt))

###### Optimal PMU Placement
* [`pmuPlacment`](@ref pmuPlacment)

###### Build PMU State Estimation
* [`pmuStateEstimation`](@ref pmuStateEstimation)

###### Solve PMU State Estimation
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS}))

###### Build DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)

###### Solve DC State Estimation
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS}))

###### Bad Data Analysis
* [`residualTest!`](@ref residualTest!)

---

## Observability Analysis
```@docs
islandTopologicalFlow(::PowerSystem, ::Wattmeter)
islandTopological(::PowerSystem, ::Wattmeter)
restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)
```

---

## Optimal PMU Placement
```@docs
pmuPlacment
```

---

## Build PMU State Estimation
```@docs
pmuStateEstimation
```

---

## Solve PMU State Estimation
```@docs
solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})
```

---

## Build DC State Estimation
```@docs
dcStateEstimation
```

---

## Solve DC State Estimation
```@docs
solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})
```

---

## Bad Data Analysis
```@docs
residualTest!
```