# [Public Types](@id PublicTypesAPI)
This section introduces the public types available in JuliaGrid. These types are designed to model and represent key components of power systems, measurements, and analyses, enabling users to efficiently simulate, optimize, and analyze various scenarios.

To load public types into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### Power System Model
* [`PowerSystem`](@ref PowerSystem)
* [`Bus`](@ref Bus)
* [`Branch`](@ref Branch)
* [`Generator`](@ref Generator)
* [`BaseData`](@ref BaseData)
* [`Model`](@ref JuliaGrid.Model)

###### Measurement Model
* [`Measurement`](@ref Measurement)
* [`Voltmeter`](@ref Voltmeter)
* [`Ammeter`](@ref Ammeter)
* [`Wattmeter`](@ref Wattmeter)
* [`Varmeter`](@ref Varmeter)
* [`PMU`](@ref PMU)

###### Analysis
* [`Analysis`](@ref Analysis)
* [`AC`](@ref AC)
* [`DC`](@ref DC)
* [`LDLt`](@ref JuliaGrid.LDLt)
* [`LU`](@ref JuliaGrid.LU)
* [`QR`](@ref JuliaGrid.QR)

###### Power Flow
* [`ACPowerFlow`](@ref ACPowerFlow)
* [`NewtonRaphson`](@ref NewtonRaphson)
* [`FastNewtonRaphson`](@ref FastNewtonRaphson)
* [`GaussSeidel`](@ref GaussSeidel)
* [`DCPowerFlow`](@ref DCPowerFlow)

###### Optimal Power Flow
* [`ACOptimalPowerFlow`](@ref ACOptimalPowerFlow)
* [`DCOptimalPowerFlow`](@ref DCOptimalPowerFlow)

###### Observability Analysis
* [`Island`](@ref Island)
* [`PMUPlacement`](@ref PMUPlacement)

###### State Estimation
* [`ACStateEstimation`](@ref ACStateEstimation)
* [`PMUStateEstimation`](@ref PMUStateEstimation)
* [`DCStateEstimation`](@ref DCStateEstimation)
* [`LWLS`](@ref LWLS)
* [`NWLS`](@ref NWLS)
* [`LAV`](@ref LAV)
* [`Normal`](@ref Normal)
* [`Orthogonal`](@ref Orthogonal)

---

## Power System Model
```@docs
PowerSystem
Bus
Branch
Generator
BaseData
JuliaGrid.Model
```

---

## Measurement Model
```@docs
Measurement
Voltmeter
Ammeter
Wattmeter
Varmeter
PMU
```

---

## Analysis
```@docs
Analysis
AC
DC
JuliaGrid.LDLt
JuliaGrid.LU
JuliaGrid.QR
```

---

## Power Flow
```@docs
ACPowerFlow
NewtonRaphson
FastNewtonRaphson
GaussSeidel
DCPowerFlow
```

---

## Optimal Power Flow
```@docs
ACOptimalPowerFlow
DCOptimalPowerFlow
```

---

## Observability Analysis
```@docs
Island
PMUPlacement
```

---

## State Estimation
```@docs
ACStateEstimation
PMUStateEstimation
DCStateEstimation
LWLS
NWLS
LAV
Normal
Orthogonal
```