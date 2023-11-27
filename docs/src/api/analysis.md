# [Power and Current Analysis](@id PowerCurrentAnalysisAPI)

In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis or optimal power flow analysis, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.

---

###### AC Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow))

###### AC Power Breakdown Analysis
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

###### AC Current Breakdown Analysis
* [`injectionCurrent`](@ref injectionCurrent(::PowerSystem, ::AC))
* [`fromCurrent`](@ref fromCurrent(::PowerSystem, ::AC))
* [`toCurrent`](@ref toCurrent(::PowerSystem, ::AC))
* [`seriesCurrent`](@ref seriesCurrent(::PowerSystem, ::AC))

###### DC Power Analysis
* [`power!`](@ref power!(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation}))

###### DC Power Breakdown Analysis
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation}))
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation}))
* [`fromPower`](@ref fromPower(::PowerSystem, ::DC))
* [`toPower`](@ref toPower(::PowerSystem, ::DC))
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation}))


---

## [AC Power Analysis](@id ACPowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::ACPowerFlow)
```

---

## [AC Power Breakdown Analysis](@id ACPowerBreakdownAnalysisAPI)
```@docs
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
```

---

## [AC Current Breakdown Analysis](@id ACCurrentBreakdownAnalysisAPI)
```@docs
injectionCurrent(::PowerSystem, ::AC)
fromCurrent(::PowerSystem, ::AC)
toCurrent(::PowerSystem, ::AC)
seriesCurrent(::PowerSystem, ::AC)
```

---

## [DC Power Analysis](@id DCPowerAnalysisAPI)
```@docs
power!(::PowerSystem, ::DCPowerFlow)
```

---

## [DC Power Breakdown Analysis](@id DCPowerBreakdownAnalysisAPI)
```@docs
injectionPower(::PowerSystem, ::DCPowerFlow)
supplyPower(::PowerSystem, ::DCPowerFlow)
fromPower(::PowerSystem, ::DC)
toPower(::PowerSystem, ::DC)
generatorPower(::PowerSystem, ::DCPowerFlow)
```
