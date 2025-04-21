# [Measurement Model](@id MeasurementModelManual)
The JuliaGrid supports the type `Measurement` to preserve measurement data, with the following fields: `voltmeter`, `ammeter`, `wattmeter`, `varmeter`, and `pmu`. These fields contain information pertaining to measurements such as bus voltage magnitude, branch current magnitude, active power flow and injection, reactive power flow and injection measurements, and measurements of bus voltage and branch current phasors.

The type `Measurement` can be created using a function:
* [`measurement`](@ref measurement).

Additionally, the user can create both the `PowerSystem` and `Measurement` types using the wrapper function:
* [`ems`](@ref ems).

JuliaGrid supports two modes for populating the `Measurement` type: using built-in functions or using HDF5 files.

To work with HDF5 files, JuliaGrid provides the function:
* [`saveMeasurement`](@ref saveMeasurement).

---

Once the `Measurement` type has been established, we can incorporate voltmeters, ammeters, wattmeters, varmeters, and phasor measurement units (PMUs) using the following functions:
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
    The functions for updating measurement devices serve a dual purpose. While their primary function is to modify the `Measurement` type, they are also designed to accept various analysis models like AC or DC state estimation models. When feasible, these functions not only modify the `Measurement` type but also adapt the analysis model, often resulting in improved computational efficiency. Detailed instructions on utilizing this feature can be found in dedicated manuals for specific analyses.

---

Finally, the user has the capability to randomly alter the measurement set by activating or deactivating devices through the following function:
* [`status!`](@ref status!).

Furthermore, we provide users with the ability to modify each specific measurement set by utilizing the functions:
* [`statusVoltmeter!`](@ref statusVoltmeter!),
* [`statusAmmeter!`](@ref statusAmmeter!),
* [`statusWattmeter!`](@ref statusWattmeter!),
* [`statusVarmeter!`](@ref statusVarmeter!),
* [`statusPmu!`](@ref statusPmu!).

---

## [Build Model](@id BuildMeasurementModelManual)
The [`measurement`](@ref measurement) function creates an instance of the `Measurement` type. It requires a `PowerSystem` instance representing the system being observed and a string specifying the path to the relevant HDF5 measurement file. Alternatively, the `Measurement` can be created without any initial data, allowing the user to construct the measurements from scratch.

---

##### HDF5 File
In order to use the HDF5 file as input to create the `Measurement` type, it is necessary to have saved the data using the [`saveMeasurement`](@ref saveMeasurement) function beforehand. Suppose the measurement data is saved as `monitoring.h5` in the `C:\hdf5` directory, and it corresponds to the IEEE 14-bus test case with system data stored in `case14.h5`. In that case, the following code constructs the `Measurement` type:
```julia
system = powerSystem("case14.h5")
monitoring = measurement(system, "C:/hdf5/monitoring.h5")
```

The same result can also be achieved using the wrapper function [`ems`](@ref ems):
```julia
system, monitoring = ems("case14.h5", "C:/hdf5/monitoring.h5")
```

---

##### Model from Scratch
To start building a model from the ground up, the initial step involves constructing a power system, which facilitates the addition of measurement devices to buses or branches. As an illustration:
```@example buildModelScratch
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.2, variance = 1e-4, noise = true)
```

In this context, we have created the voltmeter responsible for measuring the bus voltage magnitude at `Bus 1`, with associated mean and variance values expressed in per-units:
```@repl buildModelScratch
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

Furthermore, we have established the wattmeter to measure the active power flow at the from-bus end of `Branch 1`, with corresponding mean and variance values also expressed in per-units:
```@repl buildModelScratch
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

!!! tip "Tip"
    The measurement values (i.e., means) can be generated by adding white Gaussian noise with specified `variance` values to perturb the original values. This can be achieved by setting `noise = true` within the functions used for adding devices.

---

## [Save Model](@id SaveMeasurementModelManual)
Once the `Measurement` type has been created using one of the methods outlined in [Build Model](@ref BuildMeasurementModelManual), the current data can be stored in the HDF5 file by using [`saveMeasurement`](@ref saveMeasurement) function:
```julia
saveMeasurement(monitoring; path = "C:/hdf5/monitoring.h5")
```
All electrical quantities saved in the HDF5 file are in per-units and radians.

---

## [Add Voltmeter](@id AddVoltmeterManual)
We have the option to add voltmeters to a loaded measurement type or to one created from scratch. As an example, we can initiate the `Measurement` type and then incorporate voltmeters by utilizing the [`addVoltmeter!`](@ref addVoltmeter!) function:
```@example addVoltmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 0.9, variance = 1e-4)
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.0, variance = 1e-3, noise = true)
```

In this example, we have established two voltmeters designed to measure the bus voltage magnitude at `Bus 1`. In the case of the second voltmeter, the measurement value is generated internally by introducing white Gaussian noise with the `variance` added to the `magnitude` value. As a result, we obtain the following data:
```@repl addVoltmeter
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

!!! note "Info"
    We recommend reading the documentation for the [`addVoltmeter!`](@ref addVoltmeter!) function, where we have provided a list of the keywords that can be used.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `variance` keywords are expected to be provided in per-units. However, users have the flexibility to specify these values in volts if they prefer. For instance, consider the following example:
```@example addVoltmeterSI
using JuliaGrid # hide

@voltage(kV, rad, V)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = sqrt(3) * 135e3)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 121.5, variance = 0.0135)
addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 135, variance = 0.135, noise = true)
```

In this example, we have chosen to specify `magnitude` and `variance` in kilovolts (kV). It is important to note that even though we have used kilovolts as the input units, these keywords will still be stored in the per-units:
```@repl addVoltmeterSI
[monitoring.voltmeter.magnitude.mean monitoring.voltmeter.magnitude.variance]
```

!!! note "Info"
    When users choose to input data in volts, measurement values and variances are related to line-to-neutral voltages, while the base values are defined for line-to-line voltages. Therefore, a conversion using ``\sqrt{3}`` is necessary. For more information, refer to the [Per-Unit System](@ref PerUnitSystem) section.

---

##### Print Data in the REPL
Users have the option to print the voltmeter data in the REPL using any units that have been configured:
```@example addVoltmeterSI
printVoltmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific voltmeter with:
```@example addVoltmeterSI
print(monitoring; voltmeter = 1)
```

---

## [Add Ammeter](@id AddAmmeterManual)
Users can introduce ammeters into either an existing measurement type or one that they create from the ground up by making use of the [`addAmmeter!`](@ref addAmmeter!) function, as demonstrated in the following example:
```@example addAmmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addAmmeter!(monitoring; from = "Branch 1", magnitude = 0.8, variance = 0.1, noise = true)
addAmmeter!(monitoring; to = "Branch 1", magnitude = 0.9, variance = 1e-3, square = true)
```

In this scenario, we have established one ammeter to measure the branch current magnitude at the from-bus end of `Branch 1`, as indicated by the use of the `from` keyword. Similarly, we have added an ammeter to measure the branch current magnitude at the to-bus end of the branch by utilizing the `to` keyword.

For the first ammeter, the measurement value is generated by adding white Gaussian noise with the `variance` to the `magnitude` value. In contrast, for the second ammeter, we assume that the measurement value is already known, defined by the `magnitude`. These actions result in the following outcomes:
```@repl addAmmeter
[monitoring.ammeter.magnitude.mean monitoring.ammeter.magnitude.variance]
```

The `square` keyword is used for the second ammeter to indicate that the measurement will be included in AC state estimation in squared form. This means the corresponding equation is introduced without a square root, while the measurement mean is squared, and the variance is doubled. This approach enhances the robustness of state estimation when handling such measurements.

!!! note "Info"
    We recommend reading the documentation for the [`addAmmeter!`](@ref addAmmeter!) function, where we have provided a list of the keywords that can be used.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `variance` keywords are expected to be provided in per-unit. However, users have the flexibility to express these values in amperes (A) if they prefer. Take a look at the following example:
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
```

In this example, we have opted to specify the `magnitude` and `variance` in amperes. It is worth noting that, despite using amperes as the input units, these keywords will still be stored in the per-unit system:
```@repl addAmmeterSI
[monitoring.ammeter.magnitude.mean monitoring.ammeter.magnitude.variance]
```

---

##### Print Data in the REPL
Users have the option to print the ammeter data in the REPL using any units that have been configured:
```@example addAmmeterSI
printAmmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific ammeter with:
```@example addAmmeterSI
print(monitoring; ammeter = 1)
```

---

## [Add Wattmeter](@id AddWattmeterManual)
Users can include wattmeters in either an existing measurement type or one that they create from scratch by utilizing the [`addWattmeter!`](@ref addWattmeter!) function, as demonstrated in the following example:
```@example addWattmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addWattmeter!(monitoring; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(monitoring; from = "Branch 1", active = 0.3, variance = 1e-2)
addWattmeter!(monitoring; to = "Branch 1", active = 0.1, variance = 1e-3, noise = true)
```

In this scenario, one wattmeter has been added to measure the active power injection at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two wattmeters have been introduced to measure the active power flow on both sides of `Branch 1` using the `from` and `to` keywords.

For the first and second wattmeters, we assume that the measurement values are already known, defined by the `active`. In contrast, for the third wattmeter, the measurement value is generated by adding white Gaussian noise with the `variance` to the `active` value. As a result, the measurement data is as follows:
```@repl addWattmeter
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

!!! note "Info"
    We recommend reading the documentation for the [`addWattmeter!`](@ref addWattmeter!) function, where we have provided a list of the keywords that can be used.

---

##### Customizing Input Units for Keywords
By default, the `active` and `variance` keywords are expected to be provided in per-unit values. However, users have the option to express these values in watts if they prefer, as demonstrated in the following example:
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
```

In this example, we have chosen to specify the `active` and `variance` in megawatts (MW), but even though we have used megawatts as the input units, these keywords will still be stored in the per-unit system:
```@repl addWattmeterSI
[monitoring.wattmeter.active.mean monitoring.wattmeter.active.variance]
```

---

##### Print Data in the REPL
Users have the option to print the wattmeter data in the REPL using any units that have been configured:
```@example addWattmeterSI
printWattmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific wattmeter with:
```@example addWattmeterSI
print(monitoring; wattmeter = 1)
```

---

## [Add Varmeter](@id AddVarmeterManual)
To include varmeters, the same approach as described in the [Add Wattmeter](@ref AddWattmeterManual) section can be applied, but here, we make use of the [`addVarmeter!`](@ref addVarmeter!) function, as demonstrated in the following example:
```@example addVarmeter
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addVarmeter!(monitoring; bus = "Bus 1", reactive = 0.2, variance = 1e-3)
addVarmeter!(monitoring; from = "Branch 1", reactive = 0.1, variance = 1e-2)
addVarmeter!(monitoring; to = "Branch 1", reactive = 0.05, variance = 1e-3, noise = true)
```

In this context, one varmeter has been added to measure the reactive power injection at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two varmeters have been introduced to measure the reactive power flow on both sides of `Branch 1` using the `from` and `to` keywords. As a result, the following outcomes are observed:
```@repl addVarmeter
[monitoring.varmeter.reactive.mean monitoring.varmeter.reactive.variance]
```

!!! note "Info"
    We recommend reading the documentation for the [`addVarmeter!`](@ref addVarmeter!) function, where we have provided a list of the keywords that can be used.

---

##### Customizing Input Units for Keywords
Just as we explained for the previous device, users have the flexibility to select units different from per-units. In this case, they can opt for megavolt-ampere reactive (MVAr), as illustrated in the following example:
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
```

JuliaGrid will still store the values in the per-unit system:
```@repl addVarmeterSI
[monitoring.varmeter.reactive.mean monitoring.varmeter.reactive.variance]
```

---

##### Print Data in the REPL
Users have the option to print the varmeter data in the REPL using any units that have been configured:
```@example addVarmeterSI
printVarmeterData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific varmeter with:
```@example addVarmeterSI
print(monitoring; varmeter = 1)
```

---

## [Add PMU](@id AddPMUManual)
Users have the capability to incorporate PMUs into either an existing measurement type or create one from scratch by utilizing the [`addPmu!`](@ref addPmu!) function, as demonstrated in the following example:
```@example addPmu
using JuliaGrid # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)

addPmu!(monitoring; bus = "Bus 1", magnitude = 1.1, angle = 0.1, varianceMagnitude = 0.1)
addPmu!(monitoring; from = "Branch 1", magnitude = 1.0, angle = -0.2, noise = true)
addPmu!(monitoring; to = "Branch 1", magnitude = 0.9, angle = 0.0, varianceAngle = 0.001)
```

!!! note "Info"
    While the typical understanding of a PMU encompasses a device that measures the bus voltage phasor and all branch current phasors incident to the bus, we have chosen to deconstruct this concept to offer users increased flexibility. As a result, our approach yields PMUs that measure individual phasors, each described with magnitude and angle, along with corresponding variances, all presented in the polar coordinate system.

In this context, one PMU has been added to measure the bus voltage phasor at `Bus 1`, as indicated by the use of the `bus` keyword. Additionally, two PMUs have been introduced to measure the branch current phasors on both sides of `Branch 1` using the `from` and `to` keywords.

For the first and third PMUs, we assume that the measurement values are already known, defined by the `magnitude` and `angle` keywords. However, for the second PMU, we generate the measurement value by adding white Gaussian noise with `varianceMagnitude` and `varianceAngle` to the `magnitude` and `angle` values, respectively. It is important to note that when we omit specifying variance values, we rely on their default settings, both of which are equal to `1e-8`. As a result, we observe the following outcomes:
```@repl addPmu
[monitoring.pmu.magnitude.mean monitoring.pmu.magnitude.variance]
[monitoring.pmu.angle.mean monitoring.pmu.angle.variance]
```

!!! note "Info"
    We recommend reading the documentation for the [`addPmu!`](@ref addPmu!) function, where we have provided a list of the keywords that can be used.

---

##### PMU State Estimation and Coordinate System
When users add PMUs and create a `PmuStateEstimation` type, they specify that the estimation model should rely only on PMUs. In this case, phasor measurements are always incorporated in the rectangular coordinate system. Here, the real and imaginary components of the phasor measurements become correlated, but these correlations are typically ignored [gomez2011use](@cite). To account for them, users can set the keyword `correlated = true`. For example:
```@example addPmu
using JuliaGrid # hide

addPmu!(monitoring; bus = "Bus 2", magnitude = 1, angle = 0)
addPmu!(monitoring; from = "Branch 1", magnitude = 0.9, angle = -0.3, correlated = true)
```
For the first phasor measurement, correlation is neglected, whereas for the second, it is considered.

---

##### AC State Estimation and Coordinate Systems
In AC state estimation, when users create an `AcStateEstimation` type, PMUs are by default integrated into the rectangular coordinate system, where correlations are neglected. Users can also set `correlated = true` to account for the correlation between the real and imaginary components of the phasor measurements. Additionally, in the AC state estimation model, users have the flexibility to incorporate phasor measurements in the polar coordinate system by specifying `polar = true`.

For example, let us add PMUs:
```@example addPmu
using JuliaGrid # hide

addPmu!(monitoring; bus = "Bus 2", magnitude = 1, angle = 0, polar = true, square = true)
addPmu!(monitoring; from = "Branch 1", magnitude = 0.9, angle = -0.3, correlated = true)
```

The first phasor measurement will be incorporated into the AC state estimation model using the polar coordinate system. Additionally, by setting `square = true`, the current magnitude measurement will be included in its squared form. The second PMU will be integrated into the rectangular coordinate system, where a correlation exists between the real and imaginary components.

!!! tip "Tip"
    It is noteworthy that expressing current phasor measurements in polar coordinates can lead to ill-conditioned problems due to small current magnitudes, whereas using rectangular representation can resolve this issue.

---

##### Customizing Input Units for Keywords
By default, the `magnitude` and `varianceMagnitude` keywords are expected to be provided in per-unit, while the `angle` and `varianceAngle` keywords are expected to be provided in radians. However, users have the flexibility to express these values in different units, such as volts (V) and degrees (deg) if the PMU is set to a bus, or amperes (A) and degrees (deg) if the PMU is set to a branch. This flexibility is demonstrated in the following:
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
```

In this example, we have opted to specify kilovolts (kV) and degrees (deg) for the PMU located at `Bus 1`, and amperes (A) and degrees (deg) for the PMUs located at `Branch 1`. It is important to note that regardless of the units used, the values will still be stored in per-units and radians:
```@repl addPmuSI
[monitoring.pmu.magnitude.mean monitoring.pmu.magnitude.variance]
[monitoring.pmu.angle.mean monitoring.pmu.angle.variance]
```

---

##### Print Data in the REPL
Users have the option to print the PMU data in the REPL using any units that have been configured:
```@example addPmuSI
printPmuData(monitoring)
nothing # hide
```

Additionally, users can display stored data for a specific PMU with:
```@example addPmuSI
print(monitoring; pmu = 1)
```

---

## [Add Templates](@id AddTemplatesMeasurementManual)
The functions [`addVoltmeter!`](@ref addVoltmeter!), [`addAmmeter!`](@ref addAmmeter!), [`addWattmeter!`](@ref addWattmeter!), [`addVarmeter!`](@ref addVarmeter!), and [`addPmu!`](@ref addPmu!) are employed to introduce measurement devices. In cases where specific keywords are not explicitly defined, default values are automatically assigned to certain parameters.

---

##### Default Keyword Values
When utilizing the [`addVoltmeter!`](@ref addVoltmeter!) function, the default variance is set to `variance = 1e-4` per-unit, and the voltmeter's operational status is automatically assumed to be in-service, as indicated by the setting of `status = 1`.

Similarly, for the [`addAmmeter!`](@ref addAmmeter!) function, the default variances are established at `variance = 1e-4` per-unit, and the operational statuses are configured to `status = 1`. This means that if a user places an ammeter at either the from-bus or to-bus end of a branch, the default settings are identical. However, as we will explain in the following subsection, users have the flexibility to fine-tune these default values, differentiating between the two locations.

In alignment with ammeters, the [`addWattmeter!`](@ref addWattmeter!) and [`addVarmeter!`](@ref addVarmeter!) functions feature default variances set at `variance = 1e-4` per-unit, and statuses are automatically assigned as `status = 1`, regardless of whether the wattmeter or varmeter is placed at the bus, the from-bus end, or the to-bus end. Users have the ability to customize these default values, making distinctions between the three positions of the measurement devices.

For the [`addPmu!`](@ref addPmu!) function, variances for both magnitude and angle measurements are standardized to `varianceMagnitude = 1e-8` and `varianceAngle = 1e-8` in per-units. Likewise, operational status is uniformly set to `status = 1`, regardless of whether the PMU is positioned on the bus, the from-bus end, or the to-bus end. Once more, users retain the option to tailor these default values to their specific needs, allowing for distinctions between these three locations of the measurement devices. Additionally, the coordinate system utilized for AC state estimation is consistently configured with `polar = false`, while correlation in the rectangular system is disabled with `correlated = false`.

Across all measurement devices, the method for generating measurement means is established as `noise = false`.

---

##### [Change Default Keyword Values](@id ChangeKeywordsMeasurementManual)
In JuliaGrid, users have the flexibility to customize default values and assign personalized settings using the [`@voltmeter`](@ref @voltmeter), [`@ammeter`](@ref @ammeter), [`@wattmeter`](@ref @wattmeter), [`@varmeter`](@ref @varmeter), and [`@pmu`](@ref @pmu) macros. These macros create voltmeter, ammeter, wattmeter, varmeter, and pmu templates that are employed each time functions for adding measurement devices are called. Here is an example of creating these templates with tailored default values:
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
```

For instance, when adding a wattmeter to the bus, the `varianceBus = 1e-3` will be applied, or if it is added to the from-bus end of the branch, these wattmeters will be set as out-of-service according to `statusFrom = 0`.

It is important to note that changing input units will also impact the templates accordingly.

---

##### Multiple Templates
In the case of calling the macros multiple times, the provided keywords and values will be combined into a single template for the corresponding measurement device.

---

##### Reset Templates
To reset the measurement device templates to their default settings, users can utilize the following macros:
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
JuliaGrid necessitates a unique label for each voltmeter, ammeter, wattmeter, varmeter, or pmu. These labels are stored in order dictionaries, functioning as pairs of strings and integers. The string signifies the distinct label for the particular device, while the integer tracks the internal numbering of measurement devices.

In all the previous examples, with the exception of the last one, we relied on automatic labeling by omitting the `label` keyword. This allowed JuliaGrid to independently assign unique labels to measurement devices. In such cases, JuliaGrid utilizes a sequential set of increasing integers for labeling the devices. The [last example](@ref ChangeKeywordsMeasurementManual) demonstrates the user labeling approach.

!!! tip "Tip"
    String labels improve readability, but in larger models, the overhead from using strings can become substantial. To reduce memory usage, users can configure ordered dictionaries to accept and store integers as labels:
    ```julia DCPowerFlowSolution
    @config(label = Integer)
    ```
---

##### Integer-Based Labeling
Let us take a look at the following illustration:
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

In this example, we use the macro [`@config`](@ref @config) to specify that labels will be stored as integers. It is essential to run this macro; otherwise, even if integers are used in subsequent functions, they will be stored as strings.

---

##### Automated Labeling Using Templates
Furthermore, users can create labels using templates and include the symbol `?` to insert an incremental set of integers at any position. In addition, users have the option to use the symbol `!` to insert the location of the measurement device into the label. For example:
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

To illustrate, the voltmeter labels are defined with incremental integers as follows:
```@repl LabelAutomaticTemplate
monitoring.voltmeter.label
```

Moreover, for ammeter labels, location information is employed:
```@repl LabelAutomaticTemplate
monitoring.ammeter.label
```

Lastly, for wattmeters, a combination of both approaches is used:
```@repl LabelAutomaticTemplate
monitoring.wattmeter.label
```

---

##### Retrieving Labels
Let us explore how to retrieve stored labels. Consider the following model:
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

To access the wattmeter labels, we can use the variable:
```@repl retrievingLabels
monitoring.wattmeter.label
```

If we need to obtain only labels, we can use the following code:
```@repl retrievingLabels
label = collect(keys(monitoring.wattmeter.label))
```

To isolate the wattmeters positioned either at the buses or at the ends of branches (from-bus or to-bus), users can achieve this using the following code:
```@repl retrievingLabels
label[monitoring.wattmeter.layout.bus]
label[monitoring.wattmeter.layout.from]
label[monitoring.wattmeter.layout.to]
```

Furthermore, when using the [`addWattmeter!`](@ref addWattmeter!) function, the labels for the keywords `bus`, `from`, and `to` are stored internally as numerical values. To retrieve bus labels, we can follow this procedure:
```@repl retrievingLabels
label = collect(keys(system.bus.label));
label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.bus]]
```

Similarly, to obtain labels for branches, we can use the following code:
```@repl retrievingLabels
label = collect(keys(system.branch.label));

label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.from]]
label[monitoring.wattmeter.layout.index[monitoring.wattmeter.layout.to]]
```

This procedure is applicable to all measurement devices, including voltmeters, ammeters, varmeters, and PMUs.

!!! tip "Tip"
    JuliaGrid offers the capability to print labels alongside various types of data. For instance, users can use the following code to print labels in combination with specific data:
    ```@repl retrievingLabels
    print(monitoring.wattmeter.label, monitoring.wattmeter.active.mean)
    ```

---

##### Loading and Saving Labels
When saving the measurements to an HDF5 file, the label type (strings or integers) will match the type chosen during system setup. Likewise, when loading data from an HDF5 file, the label type will be preserved as saved, regardless of what is set by the [`@config`](@ref @config) macro.


---

## [Add Multiple Devices](@id AddDeviceGroupsManual)
Users have the option to add measurement devices with data generated from one of the AC analyses, specifically, using results obtained from either AC power flow or AC optimal power flow. To do this, users simply need to provide the `AC` type as an argument to one of the functions responsible for adding measurement devices:
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

In this example, we incorporate voltmeters to all buses and ammeters to all branches on both ends of each branch. We set `noise = true` once in the template and once directly in the function, which means that measurement values are generated by adding white Gaussian noise with specified variances to perturb the values obtained from the AC power flow analysis.

For wattmeters, varmeters, and PMUs added to all buses and branches, we rely on the default setting of `noise = false` to obtain measurement values that match precisely with those obtained from the AC power flow analysis. Additionally, when including PMUs in the AC state estimation model, we opt for the polar coordinate system by setting `polar = true`.

!!! note "Info"
    It is important to note that JuliaGrid follows a specific order: it first adds bus measurements, then branch measurements. For branches, it adds measurement located at the from-bus end, and immediately after, measurement at the to-bus end. This process is repeated for all in-service branches.

---

Users have the option to employ an alternative method for adding groups of measurements, utilizing functions that add measurements individually. This approach may offer a more straightforward process. For example, to add wattmeters similarly to the procedure outlined above, we can employ the following:
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
After the addition of measurement devices to the `Measurement` type, users possess the flexibility to modify all parameters as defined in the function that added these measurement devices.

---

##### [Update Voltmeter](@id UpdateVoltmeterManual)
Users have the flexibility to modify all parameters as defined within the [`addVoltmeter!`](@ref addVoltmeter!) function. For illustration, let us continue with the example from the [Add Device Groups](@ref AddDeviceGroupsManual) section:
```@example addDeviceGroups
updateVoltmeter!(monitoring; label = "Bus 2", magnitude = 0.9, noise = false)
nothing  # hide
```
In this example, we update the measurement value of the voltmeter located at `Bus 2`, and this measurement is now generated without the inclusion of white Gaussian noise.

---

##### [Update Ammeter](@id UpdateAmmeterManual)
Similarly, users have the flexibility to modify all parameters defined within the [`addAmmeter!`](@ref addAmmeter!) function. Using the same example from the [Add Device Groups](@ref AddDeviceGroupsManual) section, for example, we have:
```@example addDeviceGroups
updateAmmeter!(monitoring; label = "From Branch 2", magnitude = 1.2, variance = 1e-4)
updateAmmeter!(monitoring; label = "To Branch 2", status = 0)
nothing  # hide
```
In this example, we make adjustments to the measurement and variance values of the ammeter located at `Branch 2`, specifically at the from-bus end. Next, we deactivate the ammeter at the same branch on the to-bus end.

---

##### [Update Wattmeter](@id UpdateWattmeterManual)
Following the same logic, users can modify all parameters defined within the [`addWattmeter!`](@ref addWattmeter!) function:
```@example addDeviceGroups
updateWattmeter!(monitoring; label = "Bus 1", active = 1.2, variance = 1e-4)
updateWattmeter!(monitoring; label = "To Branch 1", variance = 1e-6)
nothing  # hide
```
In this case, we modify the measurement and variance values for the wattmeter located at `Bus 1`. The wattmeter at `Branch 1` on the to-bus end retains its measurement value, while only the measurement variance is adjusted.

---

##### [Update Varmeter](@id UpdateVarmeterManual)
Following the same logic, users can modify all parameters defined within the [`addVarmeter!`](@ref addVarmeter!) function:
```@example addDeviceGroups
updateVarmeter!(monitoring; label = "Bus 1", reactive = 1.2)
updateVarmeter!(monitoring; label = "Bus 2", status = 0)
nothing  # hide
```
In this instance, we make adjustments to the measurement value of the varmeter located at `Bus 1`, while utilizing a previously defined variance. Furthermore, we deactivate the varmeter at `Bus 2` and designate it as out-of-service.

---

##### [Update PMU](@id UpdatePMUrManual)
Finally, users can modify all PMU parameters defined within the [`addPmu!`](@ref addPmu!) function:
```@example addDeviceGroups
updatePmu!(monitoring; label = "Bus 1", magnitude = 1.05, noise = true)
updatePmu!(monitoring; label = "From Branch 1", varianceAngle = 1e-6, polar = false)
nothing  # hide
```

In this example, we adjust the magnitude measurement value of the PMU located at `Bus 1`. Now, this measurement is generated by adding white Gaussian noise with specified variance value to perturb the `magnitude` value, while keeping the bus angle voltage value unchanged. For the PMU placed at `Branch 1` on the from-bus end, we retain the existing measurement values and only adjust the variance of the angle measurement. Additionally, we choose to include this measurement in the rectangular coordinate system for the AC state estimation.

---

## [Measurement Set](@id MeasurementSetManual)
Once measurement devices are integrated into the `Measurement` type, we empower users to create measurement sets in a randomized manner. To be more precise, users can manipulate the status of devices, activating or deactivating them according to specific settings. To illustrate this feature, let us first create a measurement set using the following example:
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
As a starting point, we create the measurement set where all devices are set to in-service mode based on default settings. In this instance, we generate the measurement set comprising 3 voltmeters, 6 ammeters, and 9 PMUs.

Subsequently, we offer users the ability to manipulate the status of in-service devices using the [`status!`](@ref status!) function. For example, within this set, if we wish to have only 12 out of the total 18 devices in-service while the rest are out-of-service, we can accomplish this as follows:
```@example measurementSet
status!(monitoring; inservice = 12)
nothing  # hide
```
Upon executing this function, 12 devices will be randomly selected to be in-service, while the remaining 6 will be set to out-of-service.

Furthermore, users can fine-tune the manipulation of specific measurements. Let us say we want to activate only 2 ammeters while deactivating the remaining ammeters:
```@example measurementSet
statusAmmeter!(monitoring; inservice = 2)
nothing  # hide
```
This action will result in 2 ammeters being in-service and 4 being out-of-service.

Users also have the option to further refine these actions by specifying devices at particular locations within the power system. For instance, we can enable 3 PMUs at buses to measure bus voltage phasors while deactivating all PMUs at branches that measure current phasors:
```@example measurementSet
statusPmu!(monitoring; inserviceBus = 3, inserviceFrom = 0, inserviceTo = 0)
nothing  # hide
```
The outcome will be that 3 PMUs are set to in-service at buses for voltage phasor measurements, while all PMUs at branches measuring current phasors will be in out-of-service mode.

---

##### Deactivating Devices
Likewise, we empower users to specify the number of devices to be set as out-of-service rather than defining the number of in-service devices. For instance, if the intention is to deactivate just 2 devices from the total measurement set, it can be achieved as follows:
```@example measurementSet
status!(monitoring; outservice = 2)
nothing  # hide
```
In this scenario 2 devices will be randomly deactivated, while the rest will remain in in-service status. Similar to the previous approach, users can apply this to specific devices or employ fine-tuning as needed.

---

##### Activating Devices Using Redundancy
Furthermore, users can take advantage of redundancy, which represents the ratio between measurement devices and state variables. For example, if we wish to have the number of measurement devices be 1.2 times greater than the number of state variables, we can utilize the following command:
```@example measurementSet
status!(monitoring; redundancy = 1.2)
nothing  # hide
```
Considering that the number of state variables is 5 (excluding the voltage angle related to the slack bus), using a redundancy value of 1.2 will result in 6 devices being set to in-service, while the remainder will be deactivated. As before, users can target specific devices or adjust settings as needed.