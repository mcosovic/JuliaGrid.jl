# [Measurement Model](@id measurementModelAPI)

For further information on this topic, please see the [Measurement Model] section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate with measurement devices.

---

###### Measurement Data
* [`measurement`](@ref measurement)
* [`saveMeasurement`](@ref saveMeasurement)

###### Voltmeter Functions
* [`addVoltmeter!`](@ref addVoltmeter!)
* [`updateVoltmeter!`](@ref updateVoltmeter!)
* [`@voltmeter`](@ref @voltmeter)

###### Ammeter Functions
* [`addAmmeter!`](@ref addAmmeter!)
* [`updateAmmeter!`](@ref updateAmmeter!)
* [`@ammeter`](@ref @ammeter)

###### Wattmeter Functions
* [`addWattmeter!`](@ref addWattmeter!)
* [`updateWattmeter!`](@ref updateWattmeter!)
* [`@wattmeter`](@ref @wattmeter)

###### Varmeter Functions
* [`addVarmeter!`](@ref addVarmeter!)
* [`updateVarmeter!`](@ref updateVarmeter!)
* [`@varmeter`](@ref @varmeter)

###### PMU Functions
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

## Voltmeter Functions
```@docs
addVoltmeter!(::PowerSystem, ::Measurement)
addVoltmeter!(::PowerSystem, ::Measurement, ::AC)
updateVoltmeter!
@voltmeter
```

---

## Ammeter Functions
```@docs
addAmmeter!(::PowerSystem, ::Measurement)
addAmmeter!(::PowerSystem, ::Measurement, ::AC)
updateAmmeter!
@ammeter
```

---

## Wattmeter Functions
```@docs
addWattmeter!(::PowerSystem, ::Measurement)
addWattmeter!(::PowerSystem, ::Measurement, ::AC)
updateWattmeter!
@wattmeter
```

---

## Varmeter Functions
```@docs
addVarmeter!(::PowerSystem, ::Measurement)
addVarmeter!(::PowerSystem, ::Measurement, ::AC)
updateVarmeter!
@varmeter
```

---

## PMU Functions
```@docs
addPmu!(::PowerSystem, ::Measurement)
addPmu!(::PowerSystem, ::Measurement, ::AC)
updatePmu!
@pmu
```