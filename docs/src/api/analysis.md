# [Power and Current Analysis](@id PowerCurrentAnalysisAPI)

In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis or optimal power flow analysis, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.


###### Power Analysis
* [`power`](@ref power(::PowerSystem, ::ACPowerFlow))
* [`powerBus`](@ref powerBus(::PowerSystem, ::ACPowerFlow))
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::ACPowerFlow))
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow))

###### Current Analysis
* [`current`](@ref current(::PowerSystem, ::ACPowerFlow))
* [`currentBus`](@ref currentBus(::PowerSystem, ::ACPowerFlow))
* [`currentBranch`](@ref currentBranch(::PowerSystem, ::ACPowerFlow))


---

## [Power Analysis](@id PowerAnalysisAPI)
```@docs
power(::PowerSystem, ::ACPowerFlow)
power(::PowerSystem, ::DCPowerFlow)
powerBus(::PowerSystem, ::ACPowerFlow)
powerBus(::PowerSystem, ::DCPowerFlow)
powerBranch(::PowerSystem, ::ACPowerFlow)
powerBranch(::PowerSystem, ::DCAnalysis)
powerGenerator(::PowerSystem, ::ACPowerFlow)
powerGenerator(::PowerSystem, ::DCPowerFlow)
```

---

## [Current Analysis](@id CurrentAnalysisAPI)
```@docs
current(::PowerSystem, ::ACPowerFlow)
currentBus(::PowerSystem, ::ACPowerFlow)
currentBranch(::PowerSystem, ::ACPowerFlow)
```