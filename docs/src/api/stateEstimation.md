# [State Estimation](@id StateEstimationAPI)

For further information on this topic, please see the [AC State Estimation](@ref DCStateEstimationManual) or [DC State Estimation](@ref DCStateEstimationManual) sections of the Manual. Below, we have provided a list of functions that can be utilized for power flow analysis.

---

###### Observability Analysis
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Wattmeter))
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Wattmeter))
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt))



###### PMU State Estimation
* [`pmuStateEstimation`](@ref pmuStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS}))

###### DC State Estimation
* [`dcStateEstimation`](@ref dcStateEstimation)
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS}))

###### Bad Data Analysis
* [`residualTest!`](@ref residualTest!)

###### Utility Function
* [`pmuPlacement`](@ref pmuPlacement)

---

## Observability Analysis
```@docs
islandTopologicalFlow(::PowerSystem, ::Wattmeter)
islandTopological(::PowerSystem, ::Wattmeter)
restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)
```

---

## PMU State Estimation
```@docs
pmuStateEstimation
solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})
```

---

## DC State Estimation
```@docs
dcStateEstimation
solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})
```

---


## Bad Data Analysis
```@docs
residualTest!
```

---

## Utility Function
```@docs
pmuPlacement
```
