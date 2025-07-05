# [Public Types](@id PublicTypesAPI)
This section introduces the public types available in JuliaGrid. These types are designed to model and represent key components of power systems, measurements, and analyses.

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
* [`KLU`](@ref JuliaGrid.KLU)
* [`QR`](@ref JuliaGrid.QR)

###### Power Flow
* [`AcPowerFlow`](@ref AcPowerFlow)
* [`NewtonRaphson`](@ref NewtonRaphson)
* [`FastNewtonRaphson`](@ref FastNewtonRaphson)
* [`GaussSeidel`](@ref GaussSeidel)
* [`DcPowerFlow`](@ref DcPowerFlow)

###### Optimal Power Flow
* [`AcOptimalPowerFlow`](@ref AcOptimalPowerFlow)
* [`DcOptimalPowerFlow`](@ref DcOptimalPowerFlow)

###### Observability Analysis
* [`Island`](@ref Island)
* [`PmuPlacement`](@ref PmuPlacement)

###### State Estimation
* [`AcStateEstimation`](@ref AcStateEstimation)
* [`PmuStateEstimation`](@ref PmuStateEstimation)
* [`DcStateEstimation`](@ref DcStateEstimation)
* [`GaussNewton`](@ref GaussNewton)
* [`WLS`](@ref WLS)
* [`LAV`](@ref LAV)
* [`WlsMethod`](@ref WlsMethod)
* [`Normal`](@ref Normal)
* [`Orthogonal`](@ref Orthogonal)
* [`PetersWilkinson`](@ref PetersWilkinson)

###### Bad Data Analysis
* [`ChiTest`](@ref ChiTest)
* [`ResidualTest`](@ref ResidualTest)

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
JuliaGrid.KLU
JuliaGrid.QR
```

---

## Power Flow
```@docs
AcPowerFlow
NewtonRaphson
FastNewtonRaphson
GaussSeidel
DcPowerFlow
```

---

## Optimal Power Flow
```@docs
AcOptimalPowerFlow
DcOptimalPowerFlow
```

---

## Observability Analysis
```@docs
Island
PmuPlacement
```

---

## State Estimation
```@docs
AcStateEstimation
PmuStateEstimation
DcStateEstimation
GaussNewton
WLS
LAV
WlsMethod
Normal
Orthogonal
PetersWilkinson
```

---

## Bad Data Analysis
```@docs
ChiTest
ResidualTest
```