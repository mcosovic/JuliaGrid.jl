# [Powers and Currents](@id PowerCurrentAnalysisAPI)
In the following section, we have provided a list of functions that can be utilized for post-processing analysis. Once the voltage values are obtained through power flow analysis, optimal power flow analysis, or state estimation, these functions can be used to calculate power or current values. The specific procedures for computing these values depend on the chosen analysis, which are described in separate manuals for further information.

To load power system model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### AC Powers
* [`power!`](@ref power!(::AcPowerFlow))
* [`injectionPower`](@ref injectionPower(::AC))
* [`supplyPower`](@ref supplyPower(::AcPowerFlow))
* [`shuntPower`](@ref shuntPower(::AC))
* [`fromPower`](@ref fromPower(::AC))
* [`toPower`](@ref toPower(::AC))
* [`seriesPower`](@ref seriesPower(::AC))
* [`chargingPower`](@ref chargingPower(::AC))
* [`generatorPower`](@ref generatorPower(::AcPowerFlow))

###### AC Currents
* [`current!`](@ref current!(::AC))
* [`injectionCurrent`](@ref injectionCurrent(::AC))
* [`fromCurrent`](@ref fromCurrent(::AC))
* [`toCurrent`](@ref toCurrent(::AC))
* [`seriesCurrent`](@ref seriesCurrent(::AC))

###### DC Powers
* [`power!`](@ref power!(::DcPowerFlow))
* [`injectionPower`](@ref injectionPower(::DcPowerFlow))
* [`supplyPower`](@ref supplyPower(::DcPowerFlow))
* [`fromPower`](@ref fromPower(::DC))
* [`toPower`](@ref toPower(::DC))
* [`generatorPower`](@ref generatorPower(::DcPowerFlow))

---

## [AC Powers](@id ACPowerAnalysisAPI)
```@docs
power!(::AcPowerFlow)
injectionPower(::AC)
supplyPower(::AcPowerFlow)
shuntPower(::AC)
fromPower(::AC)
toPower(::AC)
seriesPower(::AC)
chargingPower(::AC)
generatorPower(::AcPowerFlow)
```

---

## [AC Currents](@id ACCurrentAnalysisAPI)
```@docs
current!(::AC)
injectionCurrent(::AC)
fromCurrent(::AC)
toCurrent(::AC)
seriesCurrent(::AC)
```

---

## [DC Powers](@id DCPowerAnalysisAPI)
```@docs
power!(::DcPowerFlow)
injectionPower(::DcPowerFlow)
supplyPower(::DcPowerFlow)
fromPower(::DC)
toPower(::DC)
generatorPower(::DcPowerFlow)
```