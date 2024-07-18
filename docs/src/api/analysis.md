# [Power and Current Analysis](@id PowerCurrentAnalysisAPI)
In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis, optimal power flow analysis, or state estimation, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.

To load power system model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### AC Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::AC))
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::ACPowerFlow))
* [`shuntPower`](@ref shuntPower(::PowerSystem, ::AC))
* [`fromPower`](@ref fromPower(::PowerSystem, ::AC))
* [`toPower`](@ref toPower(::PowerSystem, ::AC))
* [`seriesPower`](@ref seriesPower(::PowerSystem, ::AC))
* [`chargingPower`](@ref chargingPower(::PowerSystem, ::AC))
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::ACPowerFlow))

###### AC Current Analysis
* [`current!`](@ref current!(::PowerSystem, ::AC))
* [`injectionCurrent`](@ref injectionCurrent(::PowerSystem, ::AC))
* [`fromCurrent`](@ref fromCurrent(::PowerSystem, ::AC))
* [`toCurrent`](@ref toCurrent(::PowerSystem, ::AC))
* [`seriesCurrent`](@ref seriesCurrent(::PowerSystem, ::AC))

###### DC Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow))
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::DCPowerFlow))
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::DCPowerFlow))
* [`fromPower`](@ref fromPower(::PowerSystem, ::DC))
* [`toPower`](@ref toPower(::PowerSystem, ::DC))
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::DCPowerFlow))

---

## [AC Power Analysis](@id ACPowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::ACPowerFlow)
injectionPower(::PowerSystem, ::AC)
supplyPower(::PowerSystem, ::ACPowerFlow)
shuntPower(::PowerSystem, ::AC)
fromPower(::PowerSystem, ::AC)
toPower(::PowerSystem, ::AC)
seriesPower(::PowerSystem, ::AC)
chargingPower(::PowerSystem, ::AC)
generatorPower(::PowerSystem, ::ACPowerFlow)
```

---

## [AC Current Analysis](@id ACCurrentAnalysisAPI)
```@docs
current!(::PowerSystem, ::AC)
injectionCurrent(::PowerSystem, ::AC)
fromCurrent(::PowerSystem, ::AC)
toCurrent(::PowerSystem, ::AC)
seriesCurrent(::PowerSystem, ::AC)
```

---

## [DC Power Analysis](@id DCPowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::DCPowerFlow)
injectionPower(::PowerSystem, ::DCPowerFlow)
supplyPower(::PowerSystem, ::DCPowerFlow)
fromPower(::PowerSystem, ::DC)
toPower(::PowerSystem, ::DC)
generatorPower(::PowerSystem, ::DCPowerFlow)
```