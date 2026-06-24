# [Measurement Model](@id MeasurementModelManual)
JuliaGrid provides the `Measurement` type to store measurement data, with the following fields: `voltmeter`, `ammeter`, `wattmeter`, `varmeter`, and `pmu`. These fields contain measurement data such as bus voltage magnitude, branch current magnitude, active power flow and injection, reactive power flow and injection, and bus voltage and branch current phasors.

The type `Measurement` can be created using a function:
* [`measurement`](@ref measurement).

Additionally, the user can create both the `PowerSystem` and `Measurement` types using the wrapper function:
* [`ems`](@ref ems).

JuliaGrid supports two modes for populating the `Measurement` type: using built-in functions or using HDF5 files.

To work with HDF5 files, JuliaGrid provides the function:
* [`saveMeasurement`](@ref saveMeasurement).

---

Once the `Measurement` type is established, voltmeters, ammeters, wattmeters, varmeters, and phasor measurement units (PMUs) can be added using the following functions:
* [`addVoltmeter!`](@ref addVoltmeter!),
* [`addAmmeter!`](@ref addAmmeter!),
* [`addWattmeter!`](@ref addWattmeter!),
* [`addVarmeter!`](@ref addVarmeter!),
* [`addPmu!`](@ref addPmu!).

Also, JuliaGrid provides macros [`@voltmeter`](@ref @voltmeter), [`@ammeter`](@ref @ammeter), [`@wattmeter`](@ref @wattmeter), [`@varmeter`](@ref @varmeter), and [`@pmu`](@ref @pmu) to define templates that aid in creating measurement devices. These templates help avoid entering the same parameters repeatedly.

!!! note "Info"
    It is important to note that measurement devices associated with branches can only be incorporated if the branch is in-service. This reflects JuliaGrid's approach to mimic a network topology processor, where logical data analysis configures the energized components of the power system.

Moreover, it is feasible to modify the parameters of measurement devices. When these functions are executed, all relevant fields within the `Measurement` type will be automatically updated. These functions include:
* [`updateVoltmeter!`](@ref updateVoltmeter!),
* [`updateAmmeter!`](@ref updateAmmeter!),
* [`updateWattmeter!`](@ref updateWattmeter!),
* [`updateVarmeter!`](@ref updateVarmeter!),
* [`updatePmu!`](@ref updatePmu!).

!!! tip "Tip"
    The functions for updating measurement devices serve a dual purpose. While their primary function is to modify the `Measurement` type, they can also accept compatible state estimation models. When feasible, these functions not only modify the `Measurement` type but also adapt the analysis model, often resulting in improved computational efficiency. Dedicated manuals for specific analyses describe this feature in detail.

---

Finally, users can randomly alter the measurement set by activating or deactivating devices through the following function:
* [`status!`](@ref status!).

Furthermore, each specific measurement set can be modified using the following functions:
* [`statusVoltmeter!`](@ref statusVoltmeter!),
* [`statusAmmeter!`](@ref statusAmmeter!),
* [`statusWattmeter!`](@ref statusWattmeter!),
* [`statusVarmeter!`](@ref statusVarmeter!),
* [`statusPmu!`](@ref statusPmu!).

---

## [Build Model](@id BuildMeasurementModelManual)
The [`measurement`](@ref measurement) function creates an instance of the `Measurement` type. It requires a `PowerSystem` instance representing the system being observed and a string specifying the path to the relevant HDF5 measurement file. Alternatively, a `Measurement` object can be created without any initial data, allowing the user to construct the measurements from scratch.

---

##### HDF5 File
To use the HDF5 file as input to create the `Measurement` type, the data must first be saved using the [`saveMeasurement`](@ref saveMeasurement) function. Suppose the measurement data is saved as `monitoring.h5` in the `C:\hdf5` directory, and the corresponding IEEE 14-bus system data is saved as `case14.h5` in the same directory. In that case, the following code constructs the `Measurement` type:
```julia
system = powerSystem("C:/hdf5/case14.h5")
monitoring = measurement(system, "C:/hdf5/monitoring.h5")
```

The same result can also be achieved using the wrapper function [`ems`](@ref ems):
```julia
system, monitoring = ems("C:/hdf5/case14.h5", "C:/hdf5/monitoring.h5")
```

---

##### Model from Scratch
To start building a model from scratch, first construct a power system, then add measurement devices to buses or branches. For example:
```@example buildModelScratch
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.2, variance = 1e-4, noise = true)

nothing # hide
```

This creates a voltmeter that measures the bus voltage magnitude at `Bus 1`, with the associated mean and variance values expressed as per-unit values:
```@repl buildModelScratch
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

Similarly, this creates a wattmeter that measures the active power flow at the from-bus end of `Branch 1`, with the corresponding mean and variance values expressed as per-unit values:
```@repl buildModelScratch
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

!!! tip "Tip"
    The measurement values (i.e., means) can be generated by adding white Gaussian noise with specified `variance` values to perturb the original values. Set `noise = true` within the functions used for adding devices to generate these values.

---

## [Save Model](@id SaveMeasurementModelManual)
Once the `Measurement` type has been created using one of the methods outlined in [Build Model](@ref BuildMeasurementModelManual), the current data can be stored in an HDF5 file using the [`saveMeasurement`](@ref saveMeasurement) function:
```julia
saveMeasurement(monitoring; path = "C:/hdf5/monitoring.h5")
```
All electrical quantities saved in the HDF5 file are stored as per-unit values and radians.

---

## [Add Voltmeter](@id AddVoltmeterManual)
Users can add voltmeters to a loaded measurement type or to one created from scratch. For example, initialize the `Measurement` type and add voltmeters using the [`addVoltmeter!`](@ref addVoltmeter!) function:
```@example addVoltmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 0.9, variance = 1e-4)
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0, variance = 1e-3, noise = true)

nothing # hide
```

This example creates two voltmeters that measure the bus voltage magnitude at `Bus 1`. For the second voltmeter, the measurement value is generated internally by adding white Gaussian noise with `variance` to the `magnitude` value. The resulting data is:
```@repl addVoltmeter
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

!!! note "Info"
    See the [`addVoltmeter!`](@ref addVoltmeter!) documentation for the list of supported keywords.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `variance` keywords are expected to be provided as per-unit values. However, users can specify these values in volts if they prefer. For instance, consider the following example:
```@example addVoltmeterSI
using JuliaGrid # hide

@voltage(kV, rad, V)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = sqrt(3) * 135e3)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 121.5, variance = 0.0135)
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 135, variance = 0.135, noise = true)

nothing # hide
```

In this example, the voltage magnitude is specified in kilovolts (kV), and the variance follows the same input-unit convention. Even though kilovolts are used as the input units, these keywords are stored as per-unit values:
```@repl addVoltmeterSI
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

!!! note "Info"
    When users choose to input data in volts, measurement values and variances are related to line-to-neutral voltages, while the base values are defined for line-to-line voltages. Therefore, a conversion using ``\sqrt{3}`` is necessary. For more information, refer to the [Per-Unit System](@ref PerUnitSystem) section.

---

##### Print Data in the REPL
Users can print the voltmeter data in the REPL using any units that have been configured:
```@example addVoltmeterSI
printVoltmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific voltmeter with:
```@example addVoltmeterSI
print(monitoring; voltmeter = 1)
```

Finally, the unit system used for voltmeter-related keywords can be checked with:
```@example addVoltmeterSI
@info(unit, voltmeter)
```

---

## [Add Ammeter](@id AddAmmeterManual)
Users can add ammeters to an existing measurement type or to one created from scratch using the [`addAmmeter!`](@ref addAmmeter!) function, as demonstrated in the following example:
```@example addAmmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addAmmeter!(monitoring; from = "Branch 1", magnitude = 0.8, variance = 0.1, noise = true)
addAmmeter!(monitoring; to = "Branch 1", magnitude = 0.9, variance = 1e-3, square = true)

nothing # hide
```

This example creates one ammeter that measures the branch current magnitude at the from-bus end of `Branch 1`, as indicated by the `from` keyword. It also creates an ammeter that measures the branch current magnitude at the to-bus end of the branch using the `to` keyword.

For the first ammeter, the measurement value is generated by adding white Gaussian noise with `variance` to the `magnitude` value. For the second ammeter, the measurement value is treated as known and is defined by `magnitude`. The resulting data is:
```@repl addAmmeter
[monitoring.ammeter.magnitude.mean monitoring.ammeter.magnitude.variance]
```

The `square` keyword is used for the second ammeter to indicate that the measurement will be included in AC state estimation in squared form. This means the corresponding equation is introduced without a square root; in the AC state estimation model, the measurement mean is squared and the variance is propagated as ``v_{I^2} \approx 4z_I^2v_I``. This approach enhances the robustness of state estimation when handling such measurements.

!!! note "Info"
    See the [`addAmmeter!`](@ref addAmmeter!) documentation for the list of supported keywords.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `variance` keywords are expected to be provided as per-unit values. However, users can express these values in amperes (A), as shown in the following example:
```@example addAmmeterSI
using JuliaGrid # hide
@default(unit)  # hide
@current(A, rad)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 135e3)
addBus!(system; label = "Bus 2", base = 135e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addAmmeter!(monitoring; from = "Branch 1", magnitude = 342, variance = 43, noise = true)
addAmmeter!(monitoring; to = "Branch 1", magnitude = 385, variance = 0.43, square = true)

nothing # hide
```

In this example, the current magnitude is specified in amperes (A), and the variance follows the same input-unit convention. It is worth noting that, despite using amperes as the input units, these keywords will still be stored in the per-unit system:
```@repl addAmmeterSI
[monitoring.ammeter.magnitude.mean monitoring.ammeter.magnitude.variance]
```

---

##### Print Data in the REPL
Users can print the ammeter data in the REPL using any units that have been configured:
```@example addAmmeterSI
printAmmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific ammeter with:
```@example addAmmeterSI
print(monitoring; ammeter = 1)
```

Finally, the unit system used for ammeter-related keywords can be checked with:
```@example addAmmeterSI
@info(unit, ammeter)
```

---

## [Add Wattmeter](@id AddWattmeterManual)
Users can add wattmeters to an existing measurement type or to one created from scratch using the [`addWattmeter!`](@ref addWattmeter!) function, as demonstrated in the following example:
```@example addWattmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addWattmeter!(monitoring; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.3, variance = 1e-2)
addWattmeter!(monitoring; to = "Branch 1", active = 0.1, variance = 1e-3, noise = true)

nothing # hide
```

This example adds one wattmeter to measure the active power injection at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two wattmeters are introduced to measure the active power flow on both sides of `Branch 1` using the `from` and `to` keywords.

For the first and second wattmeters, the measurement values are treated as known and are defined by `active`. For the third wattmeter, the measurement value is generated by adding white Gaussian noise with `variance` to the `active` value. The resulting measurement data is:
```@repl addWattmeter
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

!!! note "Info"
    See the [`addWattmeter!`](@ref addWattmeter!) documentation for the list of supported keywords.

---

##### Customizing Input Units for Keywords
By default, the `active` and `variance` keywords are expected to be provided in per-unit values. However, users can express these values in watts if they prefer, as demonstrated in the following example:
```@example addWattmeterSI
using JuliaGrid # hide
@default(unit)  # hide
@power(MW, pu)

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addWattmeter!(monitoring; bus = "Bus 1", active = 60, variance = 1e-1)
addWattmeter!(monitoring; from = "Branch 1", active = 30, variance = 1)
addWattmeter!(monitoring; to = "Branch 1", active = 10, variance = 1e-1, noise = true)

nothing # hide
```

In this example, the active power is specified in megawatts (MW), and the variance follows the same input-unit convention. Even though megawatts are used as the input units, these keywords are stored in the per-unit system:
```@repl addWattmeterSI
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

---

##### Print Data in the REPL
Users can print the wattmeter data in the REPL using any units that have been configured:
```@example addWattmeterSI
printWattmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific wattmeter with:
```@example addWattmeterSI
print(monitoring; wattmeter = 1)
```

Finally, the unit system used for wattmeter-related keywords can be checked with:
```@example addWattmeterSI
@info(unit, wattmeter)
```

---

## [Add Varmeter](@id AddVarmeterManual)
To add varmeters, apply the same approach described in the [Add Wattmeter](@ref AddWattmeterManual) section, but use the [`addVarmeter!`](@ref addVarmeter!) function, as demonstrated in the following example:
```@example addVarmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVarmeter!(monitoring; bus = "Bus 1", reactive = 0.2, variance = 1e-3)
addVarmeter!(monitoring; from = "Branch 1", reactive = 0.1, variance = 1e-2)
addVarmeter!(monitoring; to = "Branch 1", reactive = 0.05, variance = 1e-3, noise = true)

nothing # hide
```

In this context, one varmeter has been added to measure the reactive power injection at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two varmeters have been introduced to measure the reactive power flow on both sides of `Branch 1` using the `from` and `to` keywords. As a result, the following outcomes are observed:
```@repl addVarmeter
[monitoring.varmeter.reactive.mean monitoring.varmeter.reactive.variance]
```

!!! note "Info"
    See the [`addVarmeter!`](@ref addVarmeter!) documentation for the list of supported keywords.

---

##### Customizing Input Units for Keywords
As with the previous device, users can select units other than per-unit values. In this case, they can use megavolt-amperes reactive (MVAr), as illustrated in the following example:
```@example addVarmeterSI
using JuliaGrid # hide
@default(unit)  # hide
@power(pu, MVAr)

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVarmeter!(monitoring; bus = "Bus 1", reactive = 20, variance = 1e-1)
addVarmeter!(monitoring; from = "Branch 1", reactive = 10, variance = 1)
addVarmeter!(monitoring; to = "Branch 1", reactive = 5, variance = 1e-1, noise = true)

nothing # hide
```

The reactive power is specified in MVAr, and the variance follows the same input-unit convention. JuliaGrid will still store the values in the per-unit system:
```@repl addVarmeterSI
[monitoring.varmeter.reactive.mean monitoring.varmeter.reactive.variance]
```

---

##### Print Data in the REPL
Users can print the varmeter data in the REPL using any units that have been configured:
```@example addVarmeterSI
printVarmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific varmeter with:
```@example addVarmeterSI
print(monitoring; varmeter = 1)
```

Finally, the unit system used for varmeter-related keywords can be checked with:
```@example addVarmeterSI
@info(unit, varmeter)
```

---

## [Add PMU](@id AddPMUManual)
Users can add PMUs to an existing measurement type or create one from scratch using the [`addPmu!`](@ref addPmu!) function, as demonstrated in the following example:
```@example addPmu
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addPmu!(monitoring; bus = "Bus 1", magnitude = 1.1, angle = 0.1, varianceMagnitude = 0.1)
addPmu!(monitoring; from = "Branch 1", magnitude = 1.0, angle = -0.2, noise = true)
addPmu!(monitoring; to = "Branch 1", magnitude = 0.9, angle = 0.0, varianceAngle = 0.001)

nothing # hide
```

!!! note "Info"
    While a PMU is typically understood as a device that measures the bus voltage phasor and all branch current phasors incident to the bus, JuliaGrid represents PMUs as individual phasor measurements to provide greater flexibility. Each phasor is described by magnitude and angle values, along with the corresponding variances, in the polar coordinate system.

In this context, one PMU has been added to measure the bus voltage phasor at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two PMUs have been introduced to measure the branch current phasors on both sides of `Branch 1` using the `from` and `to` keywords.

For the first and third PMUs, the measurement values are treated as known and are defined by the `magnitude` and `angle` keywords. For the second PMU, the measurement value is generated by adding white Gaussian noise with `varianceMagnitude` and `varianceAngle` to the `magnitude` and `angle` values, respectively. When variance values are omitted, the defaults are used, both equal to `1e-8`. The resulting data is:
```@repl addPmu
[monitoring.pmu.magnitude.mean monitoring.pmu.magnitude.variance]
[monitoring.pmu.angle.mean monitoring.pmu.angle.variance]
```

!!! note "Info"
    See the [`addPmu!`](@ref addPmu!) documentation for the list of supported keywords.

---

##### PMU State Estimation and Coordinate System
When users add PMUs and create a `PmuStateEstimation` type, they specify that the estimation model should rely only on PMUs. In this case, phasor measurements are always incorporated in the rectangular coordinate system. Here, the real and imaginary components of the phasor measurements become correlated, but these correlations are typically ignored [gomez2011use](@cite). To account for them, users can set the keyword `correlated = true`. For example:
```@example addPmu
using JuliaGrid # hide

addPmu!(monitoring; bus = "Bus 2", magnitude = 1, angle = 0)
addPmu!(monitoring; from = "Branch 1", magnitude = 0.9, angle = -0.3, correlated = true)

nothing # hide
```
For the first phasor measurement, correlation is neglected, whereas for the second, it is considered.

---

##### AC State Estimation and Coordinate Systems
In AC state estimation, when users create an `AcStateEstimation` type, PMUs are by default integrated into the rectangular coordinate system, where correlations are neglected. Users can also set `correlated = true` to account for the correlation between the real and imaginary components of the phasor measurements. Additionally, in the AC state estimation model, users can incorporate phasor measurements in the polar coordinate system by specifying `polar = true`.

For example, add PMUs:
```@example addPmu
using JuliaGrid # hide

addPmu!(monitoring; bus = "Bus 2", magnitude = 1, angle = 0, polar = true, square = true)
addPmu!(monitoring; from = "Branch 1", magnitude = 0.9, angle = -0.3, correlated = true)

nothing # hide
```

The first phasor measurement will be incorporated into the AC state estimation model using the polar coordinate system. Additionally, by setting `square = true`, the current magnitude measurement will be included in its squared form. The second PMU will be integrated into the rectangular coordinate system with correlation between the real and imaginary components enabled.

!!! tip "Tip"
    It is noteworthy that expressing current phasor measurements in polar coordinates can lead to ill-conditioned problems due to small current magnitudes, whereas using rectangular representation can resolve this issue.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `varianceMagnitude` keywords are expected to be provided in per-unit, while the `angle` and `varianceAngle` keywords are expected to be provided in radians. However, users can express these values in different units, such as volts (V) and degrees (deg) if the PMU is set to a bus, or amperes (A) and degrees (deg) if the PMU is set to a branch. This flexibility is demonstrated in the following:
```@example addPmuSI
using JuliaGrid # hide
@default(unit)  # hide
@voltage(kV, deg, V)
@current(A, deg)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 135e3)
addBus!(system; label = "Bus 2", base = 135e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addPmu!(monitoring; bus = "Bus 1", magnitude = 85.74, angle = 5.73, varianceAngle = 0.06)
addPmu!(monitoring; from = "Branch 1", magnitude = 427.67, angle = -11.46, noise = true)
addPmu!(monitoring; to = "Branch 1", magnitude = 384.91, angle = 0.0)

nothing # hide
```

In this example, kilovolts (kV) and degrees (deg) are specified for the PMU located at `Bus 1`, and amperes (A) and degrees (deg) are specified for the PMUs located at `Branch 1`. The magnitude and angle variances follow the same input-unit conventions. Regardless of the input units, the values are stored as per-unit values and radians:
```@repl addPmuSI
[monitoring.pmu.magnitude.mean monitoring.pmu.magnitude.variance]
[monitoring.pmu.angle.mean monitoring.pmu.angle.variance]
```

---

##### Print Data in the REPL
Users can print the PMU data in the REPL using any units that have been configured:
```@example addPmuSI
printPmuData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific PMU with:
```@example addPmuSI
print(monitoring; pmu = 1)
```

Finally, the unit system used for PMU-related keywords can be checked with:
```@example addPmuSI
@info(unit, pmu)
```

---

## [Add Templates](@id AddTemplatesMeasurementManual)
The functions [`addVoltmeter!`](@ref addVoltmeter!), [`addAmmeter!`](@ref addAmmeter!), [`addWattmeter!`](@ref addWattmeter!), [`addVarmeter!`](@ref addVarmeter!), and [`addPmu!`](@ref addPmu!) are used to add measurement devices. In cases where specific keywords are not explicitly defined, default values are automatically assigned to certain parameters.

---

##### Default Keyword Values
When using the [`addVoltmeter!`](@ref addVoltmeter!) function, the default variance is set to `variance = 1e-4` per-unit, and the voltmeter's operational status is automatically assumed to be in-service, as indicated by the setting of `status = 1`.

Similarly, for the [`addAmmeter!`](@ref addAmmeter!) function, the default variances are `variance = 1e-4` per-unit, and the default statuses are `status = 1`. This means that if a user places an ammeter at either the from-bus or to-bus end of a branch, the default settings are identical. The following subsection explains how to customize these defaults for each location.

As with ammeters, the [`addWattmeter!`](@ref addWattmeter!) and [`addVarmeter!`](@ref addVarmeter!) functions use default variances of `variance = 1e-4` per-unit and default statuses of `status = 1`, regardless of whether the wattmeter or varmeter is placed at the bus, the from-bus end, or the to-bus end. Users can customize these defaults for each measurement-device location.

For the [`addPmu!`](@ref addPmu!) function, the default magnitude and angle variances are `varianceMagnitude = 1e-8` and `varianceAngle = 1e-8` as per-unit values. The default status is `status = 1`, regardless of whether the PMU is placed at the bus, the from-bus end, or the to-bus end. Users can customize these defaults for each measurement-device location. For AC state estimation, the coordinate system defaults to `polar = false`, while correlation in the rectangular system is disabled with `correlated = false`.

Across all measurement devices, the method for generating measurement means is established as `noise = false`.

---

##### [Change Default Keyword Values](@id ChangeKeywordsMeasurementManual)
In JuliaGrid, users can customize default values and assign custom settings using the [`@voltmeter`](@ref @voltmeter), [`@ammeter`](@ref @ammeter), [`@wattmeter`](@ref @wattmeter), [`@varmeter`](@ref @varmeter), and [`@pmu`](@ref @pmu) macros. These macros create voltmeter, ammeter, wattmeter, varmeter, and PMU templates that are used each time functions for adding measurement devices are called. Here is an example of creating these templates with customized default values:
```@example changeDefault
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

@voltmeter(variance = 1e-4, noise = true)
addVoltmeter!(monitoring; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.0)

@ammeter(varianceFrom = 1e-3, varianceTo = 1e-4, statusTo = 0)
addAmmeter!(monitoring; label = "Ammeter 1", from = "Branch 1", magnitude = 1.1)
addAmmeter!(monitoring; label = "Ammeter 2", to = "Branch 1", magnitude = 0.9)

@wattmeter(varianceBus = 1e-3, statusFrom = 0, noise = true)
addWattmeter!(monitoring; label = "Wattmeter 1", bus = "Bus 1", active = 0.6)
addWattmeter!(monitoring; label = "Wattmeter 2", from = "Branch 1", active = 0.3)
addWattmeter!(monitoring; label = "Wattmeter 3", to = "Branch 1", active = 0.1)

@varmeter(varianceFrom = 1e-3, varianceTo = 1e-3, statusBus = 0)
addVarmeter!(monitoring; label = "Varmeter 1", bus = "Bus 1", reactive = 0.2)
addVarmeter!(monitoring; label = "Varmeter 2", from = "Branch 1", reactive = 0.1)
addVarmeter!(monitoring; label = "Varmeter 3", to = "Branch 1", reactive = 0.05)

@pmu(varianceMagnitudeBus = 1e-4, statusBus = 0, varianceAngleFrom = 1e-3)
addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 1.1, angle = -0.1)
addPmu!(monitoring; label = "PMU 2", from = "Branch 1", magnitude = 1.0, angle = -0.2)
addPmu!(monitoring; label = "PMU 3", to = "Branch 1", magnitude = 0.9, angle = 0.0)

nothing # hide
```

For instance, when adding a wattmeter to the bus, the `varianceBus = 1e-3` will be applied, or if it is added to the from-bus end of the branch, these wattmeters will be set out-of-service according to `statusFrom = 0`.

It is important to note that changing input units will also impact the templates accordingly.

Users can view the templates associated with voltmeter, ammeter, wattmeter, varmeter, or PMU keywords. For example, to check templates related to wattmeter keywords, use:
```@example changeDefault
@info(template, wattmeter)
```

---

##### Multiple Templates
In the case of calling the macros multiple times, the provided keywords and values will be combined into a single template for the corresponding measurement device.

---

##### Reset Templates
Reset the measurement device templates to their default settings with:
```@example changeDefault
@default(voltmeter)
@default(ammeter)
@default(wattmeter)
@default(varmeter)
@default(pmu)
nothing # hide
```

Additionally, users can reset all templates using the macro:
```@example changeDefault
@default(template)
nothing # hide
```

---

## [Labels](@id LabelsMeasurementManual)
JuliaGrid requires a unique label for each voltmeter, ammeter, wattmeter, varmeter, or PMU. These labels are stored in ordered dictionaries, functioning as pairs of strings and integers. The string is the device label, while the integer tracks the internal numbering of measurement devices.

All previous examples except the last one use automatic labeling by omitting the `label` keyword. In such cases, JuliaGrid assigns unique labels to measurement devices using a sequential set of increasing integers. The [last example](@ref ChangeKeywordsMeasurementManual) demonstrates user-defined labeling.

!!! tip "Tip"
    String labels improve readability, but in larger models, the overhead from using strings can become substantial. To reduce memory usage, users can configure ordered dictionaries to accept and store integers as labels:
    ```julia MeasurementIntegerLabels
    @config(label = Integer)
    ```
---

##### Integer-Based Labeling
Instead of using strings for labels, Julia provides the [`@config`](@ref @config) macro to enable storing labels as integers:
```@example LabelInteger
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide
@config(label = Integer)

system, monitoring = ems()

addBus!(system; label = 1)
addBus!(system; label = 2)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.12)

addVoltmeter!(monitoring; label = 1, bus = 1, magnitude = 1.0)

addAmmeter!(monitoring; label = 1, from = 1, magnitude = 1.1)
addAmmeter!(monitoring; label = 2, to = 1, magnitude = 0.9)

nothing # hide
```

Note that the [`@config`](@ref @config) macro must be executed first. Otherwise, even if integers are passed to the functions, labels will be stored as strings. In this example, all labels, both in the power system and in the measurement system, are stored as integers.

---

##### Integer-String-Based Labeling
In addition to using only strings or only integers, JuliaGrid supports mixed labeling. Users can fine-tune labels for all power system components as well as for all measurement devices. For example:
```@example LabelInteger
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide
@branch(label = Integer)
@ammeter(label = Integer)

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = 1, from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVoltmeter!(monitoring; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.0)

addAmmeter!(monitoring; label = 1, from = 1, magnitude = 1.1)
addAmmeter!(monitoring; label = 2, to = 1, magnitude = 0.9)

nothing # hide
```

In this example, string labels are used for buses and voltmeters, while integers are used for branches and ammeters. The same configuration can be created using the [`@config`](@ref @config) macro along with the macros for specifying power system components and measurement devices:
```@example LabelInteger
@default(unit) # hide
@default(template) # hide
@config(label = Integer)
@bus(label = String)
@voltmeter(label = String)
nothing # hide
```

---

##### Automated Labeling Using Templates
Labels can also be created using templates and the symbol `?` to insert an incremental set of integers at any position. In addition, users can use the symbol `!` to insert the location of the measurement device into the label. For example:
```@example LabelAutomaticTemplate
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

@voltmeter(label = "Voltmeter ?")
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0)
addVoltmeter!(monitoring; bus = "Bus 2", magnitude = 0.9)

@ammeter(label = "!")
addAmmeter!(monitoring; from = "Branch 1", magnitude = 1.1)
addAmmeter!(monitoring; to = "Branch 1", magnitude = 0.9)

@wattmeter(label = "Wattmeter ?: !")
addWattmeter!(monitoring; bus = "Bus 1", active = 0.6)
addWattmeter!(monitoring; from = "Branch 1", active = 0.3)

nothing # hide
```

To illustrate, the voltmeter labels are defined with incremental integers:
```@repl LabelAutomaticTemplate
monitoring.voltmeter.label
```

Moreover, for ammeter labels, location information is used:
```@repl LabelAutomaticTemplate
monitoring.ammeter.label
```

Lastly, for wattmeters, a combination of both approaches is used:
```@repl LabelAutomaticTemplate
monitoring.wattmeter.label
```

---

##### Retrieving Labels
Stored labels can be retrieved as follows. Consider the following model:
```@example retrievingLabels
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 1", reactance = 0.14)

addWattmeter!(monitoring; label = "Wattmeter 2", bus = "Bus 2", active = 0.6)
addWattmeter!(monitoring; label = "Wattmeter 1", bus = "Bus 1", active = 0.2)
addWattmeter!(monitoring; label = "Wattmeter 4", from = "Branch 1", active = 0.3)
addWattmeter!(monitoring; label = "Wattmeter 3", to = "Branch 1", active = 0.1)
addWattmeter!(monitoring; label = "Wattmeter 5", from = "Branch 2", active = 0.1)

nothing # hide
```

To access the wattmeter labels, use:
```@repl retrievingLabels
monitoring.wattmeter.label
```

To obtain only labels, use:
```@repl retrievingLabels
label = collect(keys(monitoring.wattmeter.label))
```

To isolate the wattmeters positioned either at the buses or at the ends of branches (from-bus or to-bus), users can achieve this using the following code:
```@repl retrievingLabels
label[monitoring.wattmeter.layout.bus]
label[monitoring.wattmeter.layout.from]
label[monitoring.wattmeter.layout.to]
```

Furthermore, when using the [`addWattmeter!`](@ref addWattmeter!) function, the labels for the keywords `bus`, `from`, and `to` are stored internally as numerical values. To retrieve bus labels, use:
```@repl retrievingLabels
label = collect(keys(system.bus.label));
label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.bus]]
```

Similarly, to obtain labels for branches, use:
```@repl retrievingLabels
label = collect(keys(system.branch.label));

label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.from]]
label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.to]]
```

This procedure is applicable to all measurement devices, including voltmeters, ammeters, varmeters, and PMUs.

!!! tip "Tip"
    JuliaGrid can print labels alongside various types of data. For instance, users can use the following code to print labels in combination with specific data:
    ```@repl retrievingLabels
    print(monitoring.wattmeter.label, monitoring.wattmeter.active.mean)
    ```

---

##### Managing Labels in HDF5 Imports
When saving the measurements to an HDF5 file, the label type (strings or integers) will match the type chosen during system setup. Similarly, when loading data from an HDF5 file, the label type is preserved exactly as it was saved, regardless of any settings provided by the [`@config`](@ref @config) macro or macros related to measurement devices.


---

## [Add Multiple Devices](@id AddDeviceGroupsManual)
Users can add measurement devices with data generated from one of the AC analyses, specifically, using results obtained from either AC power flow or AC optimal power flow. To do this, users simply need to provide an `AC` analysis object as an argument to one of the functions responsible for adding measurement devices:
```@example addDeviceGroups
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

@branch(resistance = 0.03, susceptance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.1)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 1.2)

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true, current = true)

@voltmeter(label = "!", noise = true)
addVoltmeter!(monitoring, analysis; variance = 1e-3)

@ammeter(label = "!")
addAmmeter!(monitoring, analysis; varianceFrom = 1e-3, statusTo = 0, noise = true)

@wattmeter(label = "!")
addWattmeter!(monitoring, analysis; varianceBus = 1e-3, statusFrom = 0)

@varmeter(label = "!")
addVarmeter!(monitoring, analysis; varianceFrom = 1e-3, statusBus = 0)

@pmu(label = "!", polar = true)
addPmu!(monitoring, analysis; varianceMagnitudeBus = 1e-3)

nothing  # hide
```

This example adds voltmeters to all buses and ammeters to both ends of each branch. It sets `noise = true` once in the template and once directly in the function, so measurement values are generated by adding white Gaussian noise with specified variances to the values obtained from the AC power flow analysis.

For wattmeters, varmeters, and PMUs added to all buses and branches, the default setting `noise = false` produces measurement values that match those obtained from the AC power flow analysis. When PMUs are included in the AC state estimation model, the polar coordinate system is selected by setting `polar = true`.

!!! note "Info"
    It is important to note that JuliaGrid follows a specific order: it first adds bus measurements, then branch measurements. For branches, it adds a measurement located at the from-bus end and, immediately after, a measurement at the to-bus end. This process is repeated for all in-service branches.

---

Groups of measurements can also be added with the functions that add measurements individually. This approach may be more straightforward. For example, to add wattmeters similarly to the procedure outlined above, use:
```@example addDeviceGroups
Pᵢ = analysis.power.injection.active
for (label, idx) in system.bus.label
    addWattmeter!(monitoring; bus = label, active = Pᵢ[idx], variance = 1e-3)
end

Pᵢⱼ = analysis.power.from.active
Pⱼᵢ = analysis.power.to.active
for (label, idx) in system.branch.label
    addWattmeter!(monitoring; from = label, active = Pᵢⱼ[idx], status = 0)
    addWattmeter!(monitoring; to = label, active = Pⱼᵢ[idx])
end

nothing  # hide
```

---

## [Update Devices](@id UpdateMeasurementDevicesManual)
After the addition of measurement devices to the `Measurement` type, users can modify all parameters as defined in the function that added these measurement devices.

---

##### [Update Voltmeter](@id UpdateVoltmeterManual)
Users can modify all parameters as defined within the [`addVoltmeter!`](@ref addVoltmeter!) function. For illustration, continue with the example from the [Add Device Groups](@ref AddDeviceGroupsManual) section:
```@example addDeviceGroups
updateVoltmeter!(monitoring; label = "Bus 2", magnitude = 0.9, noise = false)

nothing  # hide
```
This example updates the measurement value of the voltmeter located at `Bus 2`, and this measurement is now generated without the inclusion of white Gaussian noise.

---

##### [Update Ammeter](@id UpdateAmmeterManual)
Similarly, users can modify all parameters defined within the [`addAmmeter!`](@ref addAmmeter!) function. Using the same example from the [Add Device Groups](@ref AddDeviceGroupsManual) section, use:
```@example addDeviceGroups
updateAmmeter!(monitoring; label = "From Branch 2", magnitude = 1.2, variance = 1e-4)
updateAmmeter!(monitoring; label = "To Branch 2", status = 0)

nothing  # hide
```
This example adjusts the measurement and variance values of the ammeter located at `Branch 2`, specifically at the from-bus end. Next, it deactivates the ammeter at the same branch on the to-bus end.

---

##### [Update Wattmeter](@id UpdateWattmeterManual)
Following the same logic, users can modify all parameters defined within the [`addWattmeter!`](@ref addWattmeter!) function:
```@example addDeviceGroups
updateWattmeter!(monitoring; label = "Bus 1", active = 1.2, variance = 1e-4)
updateWattmeter!(monitoring; label = "To Branch 1", variance = 1e-6)

nothing  # hide
```
This example modifies the measurement and variance values for the wattmeter located at `Bus 1`. The wattmeter at `Branch 1` on the to-bus end retains its measurement value, while only the measurement variance is adjusted.

---

##### [Update Varmeter](@id UpdateVarmeterManual)
Following the same logic, users can modify all parameters defined within the [`addVarmeter!`](@ref addVarmeter!) function:
```@example addDeviceGroups
updateVarmeter!(monitoring; label = "Bus 1", reactive = 1.2)
updateVarmeter!(monitoring; label = "Bus 2", status = 0)

nothing  # hide
```
This example adjusts the measurement value of the varmeter located at `Bus 1`, while using a previously defined variance. It also deactivates the varmeter at `Bus 2` and designates it as out-of-service.

---

##### [Update PMU](@id UpdatePMUManual)
Finally, users can modify all PMU parameters defined within the [`addPmu!`](@ref addPmu!) function:
```@example addDeviceGroups
updatePmu!(monitoring; label = "Bus 1", magnitude = 1.05, noise = true)
updatePmu!(monitoring; label = "From Branch 1", varianceAngle = 1e-6, polar = false)

nothing  # hide
```

This example adjusts the magnitude measurement value of the PMU located at `Bus 1`. The measurement is generated by adding white Gaussian noise using the specified variance value to perturb the `magnitude` value, while keeping the bus voltage angle value unchanged. For the PMU placed at `Branch 1` on the from-bus end, the existing measurement values are retained and only the angle variance is adjusted. The measurement is also included in the rectangular coordinate system for the AC state estimation.

---

## [Measurement Set](@id MeasurementSetManual)
Once measurement devices are integrated into the `Measurement` type, users can create randomized measurement sets. More precisely, users can activate or deactivate devices according to specific settings. To illustrate this feature, first create a measurement set with the following example:
```@example measurementSet
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

@branch(resistance = 0.03, susceptance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.1)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 1.2)

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true, current = true)

addVoltmeter!(monitoring, analysis)
addAmmeter!(monitoring, analysis)
addPmu!(monitoring, analysis)

nothing  # hide
```

---

##### Activating Devices
As a starting point, create a measurement set where all devices are set in-service based on default settings. This example generates a measurement set comprising 3 voltmeters, 6 ammeters, and 9 PMUs.

Users can modify the status of in-service devices with the [`status!`](@ref status!) function. For example, to keep only 12 of the 18 devices in-service, use:
```@example measurementSet
status!(monitoring; inservice = 12)

nothing  # hide
```
Upon executing this function, 12 devices will be randomly selected as in-service, while the remaining 6 will be set out-of-service.

Furthermore, users can refine the status changes for specific measurements. For example, to activate only 2 ammeters while deactivating the remaining ammeters:
```@example measurementSet
statusAmmeter!(monitoring; inservice = 2)

nothing  # hide
```
This action will result in 2 ammeters being in-service and 4 being out-of-service.

Users can further refine these actions by specifying devices at particular locations within the power system. For instance, to enable 3 PMUs at buses to measure bus voltage phasors while deactivating all PMUs at branches that measure current phasors, use:
```@example measurementSet
statusPmu!(monitoring; inserviceBus = 3, inserviceFrom = 0, inserviceTo = 0)

nothing  # hide
```
The outcome will be that 3 PMUs are set in-service at buses for voltage phasor measurements, while all PMUs at branches measuring current phasors will be set out-of-service.

---

##### Deactivating Devices
Likewise, users can specify the number of devices to be set out-of-service rather than defining the number of in-service devices. For instance, to deactivate just 2 devices from the total measurement set, use:
```@example measurementSet
status!(monitoring; outservice = 2)

nothing  # hide
```
This randomly deactivates 2 devices, while the rest remain in-service. Similar to the previous approach, users can apply this to specific devices or use fine-tuning as needed.

---

##### Activating Devices Using Redundancy
Furthermore, users can use redundancy, which represents the ratio between measurement devices and state variables. For example, to set the number of measurement devices to 1.2 times greater than the number of state variables, use:
```@example measurementSet
status!(monitoring; redundancy = 1.2)

nothing  # hide
```
Considering that the number of state variables is 5 (excluding the voltage angle related to the slack bus), using a redundancy value of 1.2 will result in 6 devices being set in-service, while the remainder will be deactivated. As before, users can target specific devices or adjust settings as needed.