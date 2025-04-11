# [Measurement Model](@id measurementModelAPI)
For further information on this topic, please see the [Measurement Model](@ref MeasurementModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate with measurement devices.

To load measurement model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

###### Measurement Data
* [`measurement`](@ref measurement)
* [`ems`](@ref ems)
* [`saveMeasurement`](@ref saveMeasurement)
* [`status!`](@ref status!)

###### Voltmeter
* [`addVoltmeter!`](@ref addVoltmeter!)
* [`updateVoltmeter!`](@ref updateVoltmeter!)
* [`statusVoltmeter!`](@ref statusVoltmeter!)
* [`@voltmeter`](@ref @voltmeter)

###### Ammeter
* [`addAmmeter!`](@ref addAmmeter!)
* [`updateAmmeter!`](@ref updateAmmeter!)
* [`statusAmmeter!`](@ref statusAmmeter!)
* [`@ammeter`](@ref @ammeter)

###### Wattmeter
* [`addWattmeter!`](@ref addWattmeter!)
* [`updateWattmeter!`](@ref updateWattmeter!)
* [`statusWattmeter!`](@ref statusWattmeter!)
* [`@wattmeter`](@ref @wattmeter)

###### Varmeter
* [`addVarmeter!`](@ref addVarmeter!)
* [`updateVarmeter!`](@ref updateVarmeter!)
* [`statusVarmeter!`](@ref statusVarmeter!)
* [`@varmeter`](@ref @varmeter)

###### PMU
* [`addPmu!`](@ref addPmu!)
* [`updatePmu!`](@ref updatePmu!)
* [`statusPmu!`](@ref statusPmu!)
* [`@pmu`](@ref @pmu)

---

## Measurement Data
```@docs
measurement
ems
saveMeasurement
status!
```

---

## Voltmeter
```@docs
addVoltmeter!(::Measurement)
addVoltmeter!(::Measurement, ::AC)
updateVoltmeter!
statusVoltmeter!
@voltmeter
```

---

## Ammeter
```@docs
addAmmeter!(::Measurement)
addAmmeter!(::Measurement, ::AC)
updateAmmeter!
statusAmmeter!
@ammeter
```

---

## Wattmeter
```@docs
addWattmeter!(::Measurement)
addWattmeter!(::Measurement, ::AC)
updateWattmeter!
statusWattmeter!
@wattmeter
```

---

## Varmeter
```@docs
addVarmeter!(::Measurement)
addVarmeter!(::Measurement, ::AC)
updateVarmeter!
statusVarmeter!
@varmeter
```

---

## PMU
```@docs
addPmu!(::Measurement)
addPmu!(::Measurement, ::AC)
updatePmu!
statusPmu!
@pmu
```