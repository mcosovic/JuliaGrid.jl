# [AC Analysis](@id ACAnalysisAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

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

## Power Analysis
```@docs
power(::PowerSystem, ::ACPowerFlow)
powerBus(::PowerSystem, ::ACPowerFlow)
powerBranch(::PowerSystem, ::ACPowerFlow)
powerGenerator(::PowerSystem, ::ACPowerFlow)
```

---

## Current Analysis
```@docs
current(::PowerSystem, ::ACPowerFlow)
currentBus(::PowerSystem, ::ACPowerFlow)
currentBranch(::PowerSystem, ::ACPowerFlow)
```