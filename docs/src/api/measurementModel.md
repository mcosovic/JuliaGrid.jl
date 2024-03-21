# [Measurement Model](@id measurementModelAPI)

For further information on this topic, please see the [Measurement Model](@ref MeasurementModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate with measurement devices.

---

###### Measurement Data
* [`measurement`](@ref measurement)
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
* [`statusAmmeter!`](@ref addAmmeter!)
* [`@ammeter`](@ref @ammeter)

###### Wattmeter
* [`addWattmeter!`](@ref addWattmeter!)
* [`updateWattmeter!`](@ref updateWattmeter!)
* [`statusWattmeter!`](@ref addWattmeter!)
* [`@wattmeter`](@ref @wattmeter)

###### Varmeter
* [`addVarmeter!`](@ref addVarmeter!)
* [`updateVarmeter!`](@ref updateVarmeter!)
* [`statusVarmeter!`](@ref addVarmeter!)
* [`@varmeter`](@ref @varmeter)

###### PMU
* [`addPmu!`](@ref addPmu!)
* [`updatePmu!`](@ref updatePmu!)
* [`statusPmu!`](@ref addPmu!)
* [`@pmu`](@ref @pmu)

---

To load measurement model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

## Measurement Data
```@docs
measurement
saveMeasurement
status!
```

---

## Voltmeter
```@docs
addVoltmeter!(::PowerSystem, ::Measurement)
addVoltmeter!(::PowerSystem, ::Measurement, ::AC)
updateVoltmeter!
statusVoltmeter!
@voltmeter
```

---

## Ammeter
```@docs
addAmmeter!(::PowerSystem, ::Measurement)
addAmmeter!(::PowerSystem, ::Measurement, ::AC)
updateAmmeter!
statusAmmeter!
@ammeter
```

---

## Wattmeter
```@docs
addWattmeter!(::PowerSystem, ::Measurement)
addWattmeter!(::PowerSystem, ::Measurement, ::AC)
updateWattmeter!
statusWattmeter!
@wattmeter
```

---

## Varmeter
```@docs
addVarmeter!(::PowerSystem, ::Measurement)
addVarmeter!(::PowerSystem, ::Measurement, ::AC)
updateVarmeter!
statusVarmeter!
@varmeter
```

---

## PMU
```@docs
addPmu!(::PowerSystem, ::Measurement)
addPmu!(::PowerSystem, ::Measurement, ::AC)
updatePmu!
statusPmu!
@pmu
```