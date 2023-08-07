# [Power and Current Analysis](@id PowerCurrentAnalysisAPI)

In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis or optimal power flow analysis, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.


###### Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::ACAnalysis))
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow))
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::ACAnalysis))
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::ACAnalysis))
* [`powerTo`](@ref powerTo(::PowerSystem, ::ACAnalysis))
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::ACAnalysis))
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::ACAnalysis))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::ACAnalysis))
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::ACAnalysis))
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::ACAnalysis))
* [`currentTo`](@ref currentTo(::PowerSystem, ::ACAnalysis))
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::ACAnalysis))

---

## [Power Analysis](@id PowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::ACPowerFlow)
power!(::PowerSystem, ::DCPowerFlow)
powerInjection(::PowerSystem, ::ACAnalysis)
powerInjection(::PowerSystem, ::DCPowerFlow)
powerSupply(::PowerSystem, ::ACPowerFlow)
powerSupply(::PowerSystem, ::DCPowerFlow)
powerShunt(::PowerSystem, ::ACAnalysis)
powerFrom(::PowerSystem, ::ACAnalysis)
powerFrom(::PowerSystem, ::DCAnalysis)
powerTo(::PowerSystem, ::ACAnalysis)
powerTo(::PowerSystem, ::DCAnalysis)
powerCharging(::PowerSystem, ::ACAnalysis)
powerSeries(::PowerSystem, ::ACAnalysis)
powerGenerator(::PowerSystem, ::ACPowerFlow)
powerGenerator(::PowerSystem, ::DCPowerFlow)
```

---

## [Current Analysis](@id CurrentAnalysisAPI)
```@docs
current!(::PowerSystem, ::ACAnalysis)
currentInjection(::PowerSystem, ::ACAnalysis)
currentFrom(::PowerSystem, ::ACAnalysis)
currentTo(::PowerSystem, ::ACAnalysis)
currentSeries(::PowerSystem, ::ACAnalysis)
```