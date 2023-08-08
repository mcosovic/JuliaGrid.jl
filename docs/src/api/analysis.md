# [Power and Current Analysis](@id PowerCurrentAnalysisAPI)

In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis or optimal power flow analysis, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.


###### Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::AC))
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow))
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::AC))
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::AC))
* [`powerTo`](@ref powerTo(::PowerSystem, ::AC))
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::AC))
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::AC))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::AC))
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::AC))
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::AC))
* [`currentTo`](@ref currentTo(::PowerSystem, ::AC))
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::AC))

---

## [Power Analysis](@id PowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::ACPowerFlow)
power!(::PowerSystem, ::DCPowerFlow)
powerInjection(::PowerSystem, ::AC)
powerInjection(::PowerSystem, ::DCPowerFlow)
powerSupply(::PowerSystem, ::ACPowerFlow)
powerSupply(::PowerSystem, ::DCPowerFlow)
powerShunt(::PowerSystem, ::AC)
powerFrom(::PowerSystem, ::AC)
powerFrom(::PowerSystem, ::DC)
powerTo(::PowerSystem, ::AC)
powerTo(::PowerSystem, ::DC)
powerCharging(::PowerSystem, ::AC)
powerSeries(::PowerSystem, ::AC)
powerGenerator(::PowerSystem, ::ACPowerFlow)
powerGenerator(::PowerSystem, ::DCPowerFlow)
```

---

## [Current Analysis](@id CurrentAnalysisAPI)
```@docs
current!(::PowerSystem, ::AC)
currentInjection(::PowerSystem, ::AC)
currentFrom(::PowerSystem, ::AC)
currentTo(::PowerSystem, ::AC)
currentSeries(::PowerSystem, ::AC)
```