# [Measurement Model](@id measurementModelAPI)

For further information on this topic, please see the [Measurement Model](@ref MeasurementModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate with measurement devices.

---

###### Measurement Data
* [`measurement`](@ref measurement)
* [`saveMeasurement`](@ref saveMeasurement)

###### Voltmeter
* [`addVoltmeter!`](@ref addVoltmeter!)
* [`updateVoltmeter!`](@ref updateVoltmeter!)
* [`@voltmeter`](@ref @voltmeter)

###### Ammeter
* [`addAmmeter!`](@ref addAmmeter!)
* [`updateAmmeter!`](@ref updateAmmeter!)
* [`@ammeter`](@ref @ammeter)

###### Wattmeter
* [`addWattmeter!`](@ref addWattmeter!)
* [`updateWattmeter!`](@ref updateWattmeter!)
* [`@wattmeter`](@ref @wattmeter)

###### Varmeter
* [`addVarmeter!`](@ref addVarmeter!)
* [`updateVarmeter!`](@ref updateVarmeter!)
* [`@varmeter`](@ref @varmeter)

###### PMU
* [`addPmu!`](@ref addPmu!)
* [`updatePmu!`](@ref updatePmu!)
* [`@pmu`](@ref @pmu)

---

## Measurement Data
```@docs
measurement
saveMeasurement
```

---

## Voltmeter
```@docs
addVoltmeter!(::PowerSystem, ::Measurement)
addVoltmeter!(::PowerSystem, ::Measurement, ::AC)
updateVoltmeter!
@voltmeter
```

---

## Ammeter
```@docs
addAmmeter!(::PowerSystem, ::Measurement)
addAmmeter!(::PowerSystem, ::Measurement, ::AC)
updateAmmeter!
@ammeter
```

---

## Wattmeter
```@docs
addWattmeter!(::PowerSystem, ::Measurement)
addWattmeter!(::PowerSystem, ::Measurement, ::AC)
updateWattmeter!
@wattmeter
```

---

## Varmeter
```@docs
addVarmeter!(::PowerSystem, ::Measurement)
addVarmeter!(::PowerSystem, ::Measurement, ::AC)
updateVarmeter!
@varmeter
```

---

## PMU
```@docs
addPmu!(::PowerSystem, ::Measurement)
addPmu!(::PowerSystem, ::Measurement, ::AC)
updatePmu!
@pmu
```