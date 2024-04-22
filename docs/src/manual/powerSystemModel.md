# [Power System Model](@id PowerSystemModelManual)

The JuliaGrid supports the composite type `PowerSystem` to preserve power system data, with the following fields: `bus`, `branch`, `generator`, `base`, and `model`. The fields `bus`, `branch`, and `generator` hold data related to buses, branches, and generators, respectively. The `base` field stores base values for power and voltages, with the default being three-phase power measured in volt-amperes for the base power and line-to-line voltages measured in volts for base voltages. Within the `model` field, there are `ac` and `dc` subfields that store vectors and matrices pertinent to the power system's topology and parameters, and these are utilized in either the AC or DC framework.

The composite type `PowerSystem` can be created using a function:
* [`powerSystem`](@ref powerSystem).
JuliaGrid supports three modes for populating the `PowerSystem` type: using built-in functions, using HDF5 file format, and using [Matpower](https://matpower.org) case files.

It is recommended to use the HDF5 format for large-scale systems. To facilitate this, JuliaGrid has the function:
* [`savePowerSystem`](@ref savePowerSystem).

Upon creation of the `PowerSystem` type, users can generate vectors and matrices based on the power system topology and parameters using the following functions:
* [`acModel!`](@ref acModel!),
* [`dcModel!`](@ref dcModel!).

---

Once the `PowerSystem` type is created, user can add buses, branches, generators, or manage costs associated with the output powers of the generators, using the following functions:
* [`addBus!`](@ref addBus!),
* [`addBranch!`](@ref addBranch!),
* [`addGenerator!`](@ref addGenerator!),
* [`cost!`](@ref cost!).

JuliaGrid also provides macros [`@bus`](@ref @bus), [`@branch`](@ref @branch), and [`@generator`](@ref @generator) to define templates that aid in creating buses, branches, and generators. These templates help avoid entering the same parameters repeatedly.

Moreover, it is feasible to modify the parameters of buses, branches, and generators. When these functions are executed, all relevant fields within the `PowerSystem` composite type will be automatically updated, encompassing the `ac` and `dc` fields as well. These functions include:
* [`updateBus!`](@ref updateBus!),
* [`updateBranch!`](@ref updateBranch!),
* [`updateGenerator!`](@ref updateGenerator!).

!!! tip "Tip"
    The functions [`addBranch!`](@ref addBranch!), [`addGenerator!`](@ref addGenerator!), [`updateBus!`](@ref updateBus!), [`updateBranch!`](@ref updateBranch!), [`updateGenerator!`](@ref updateGenerator!), and [`cost!`](@ref cost!) serve a dual purpose. While their primary function is to modify the `PowerSystem` composite type, they are also designed to accept various analysis models like AC or DC power flow models. When feasible, these functions not only modify the `PowerSystem` type but also adapt the analysis model, often resulting in improved computational efficiency. Detailed instructions on utilizing this feature can be found in dedicated manuals for specific analyses.

---

## [Build Model](@id BuildModelManual)
The [`powerSystem`](@ref powerSystem) function generates the `PowerSystem` composite type and requires a string-formatted path to either Matpower cases or HDF5 files as input. Alternatively, the `PowerSystem` can be created without any initial data by initializing it as empty, allowing the user to construct the power system from scratch.

---

##### Matpower or HDF5 File
For example, to create the `PowerSystem` type using the Matpower case file for the IEEE 14-bus test case, which is named `case14.m` and located in the folder `C:\matpower`, the following Julia code can be used:
```julia
system = powerSystem("C:/matpower/case14.m")
```

In order to use the HDF5 file as input to create the `PowerSystem` type, it is necessary to have saved the data using the [`savePowerSystem`](@ref savePowerSystem) function beforehand. As an example, let us say we saved the power system as `case14.h5` in the directory `C:\hdf5`. In this case, the following Julia code can be used to construct the `PowerSystem` type:
```julia
system = powerSystem("C:/hdf5/case14.h5")
```

!!! tip "Tip"
    It is recommended to load the power system from the HDF5 file to reduce the loading time.

---

##### Model from Scratch
Alternatively, the model can be build from the scratch using built-in functions, for example:
```@example buildModelScratch
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1, base = 345e3)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, base = 345e3)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
```

---

##### Internal Unit System
The `PowerSystem` composite type stores all electrical quantities in per-units and radians, except for the base values of power and voltages. The base power value is expressed in volt-amperes, while the base voltages are given in volts.

---

##### Change Base Unit Prefixes
As an example, if we execute the previous code snippet, we can retrieve the base power and base voltage values and units as shown below:
```@repl buildModelScratch
system.base.power.value, system.base.power.unit
system.base.voltage.value, system.base.voltage.unit
```

By using the [`@base`](@ref @base) macro, users can change the prefixes of the base units. For instance, if the user wishes to convert base power and base voltage values to megavolt-amperes (MVA) and kilovolts (kV) respectively, they can execute the following macro:
```@example buildModelScratch
@base(system, MVA, kV)
nothing # hide
```
Upon execution of the macro, the base power and voltage values and units will be modified accordingly:
```@repl buildModelScratch
system.base.power.value, system.base.power.unit
system.base.voltage.value, system.base.voltage.unit
```

Therefore, by using the [`@base`](@ref @base) macro to modify the prefixes of the base units, users can convert the output data from various analyses to specific units with the desired prefixes.

---

## [Save Model](@id SaveModelManual)
Once the `PowerSystem` type has been created using one of the methods outlined in [Build Model](@ref BuildModelManual), the current data can be stored in the HDF5 file by using [`savePowerSystem`](@ref savePowerSystem) function:
```julia
savePowerSystem(system; path = "C:/matpower/case14.h5", reference = "IEEE 14-bus test case")
```
All electrical quantities saved in the HDF5 file are in per-units and radians, except for base values for power and voltages, which are given in volt-amperes and volts. It is important to note that even if the user modifies the base units using the [`@base`](@ref @base) macro, the units will still be saved in the default settings.

---


## [Add Bus](@id AddBusManual)
We have the option to add buses to a loaded power system or to one created from scratch. As an illustration, we can initiate the `PowerSystem` type and then incorporate two buses by utilizing the [`addBus!`](@ref addBus!) function:
```@example addBus
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1, base = 345e3)
addBus!(system; label = "Bus 2", type = 1, angle = -0.034907, base = 345e3)
```

In this case, we have created two buses where the active power demanded by the consumer at `Bus 1` is specified in per-units, which are the same units used to store electrical quantities:
```@repl addBus
system.bus.demand.active
```

It is worth noting that the `base` keyword is used to specify the base voltages, and its default input unit is in volts (V).
```@repl addBus
system.base.voltage.value, system.base.voltage.unit
```

Finally, we set the bus voltage angle in radians for the `Bus 2` to its initial value:
```@repl addBus
system.bus.voltage.angle
```

!!! note "Info"
    We recommend reading the documentation for the [`addBus!`](@ref addBus!) function, where we have provided a list of all the keywords that can be used.

---

##### Customizing Input Units for Keywords
Typically, all keywords associated with electrical quantities are expected to be provided in per-units (pu) and radians (rad) by default, with the exception of base voltages, which should be specified in volts (V). However, users can choose to use different units than the default per-units and radians or modify the prefix of the base voltage unit by using macros such as the following:
```@example addBusUnit
using JuliaGrid # hide

@power(MW, MVAr, pu)
@voltage(pu, deg, kV)
nothing # hide
```
This practical example showcases the customization approach. For keywords tied to active powers, the unit is set as megawatts (MW), while reactive powers employ megavolt-amperes reactive (MVAr). Apparent power, on the other hand, employs per-units (pu). As for keywords concerning voltage magnitude, per-units (pu) remain the choice, but voltage angle mandates degrees (deg). Lastly, the input unit for base voltage is elected to be kilovolts (kV). This unit configuration will be applied throughout subsequent function calls after the unit definitions are established.


Now we can create identical two buses as before using new system of units as follows:
```@example addBusUnit
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 10.0, base = 345.0)
addBus!(system; label = "Bus 2", type = 1, angle = -2.0, base = 345.0)
```
As can be observed, electrical quantities will continue to be stored in per-units and radians format:
```@repl addBusUnit
[system.bus.demand.active system.bus.voltage.angle]
```

The base voltage values will still be stored in volts (V) since we only changed the input unit prefix, and did not modify the internal unit prefix, as shown below:
```@repl addBusUnit
system.base.voltage.value, system.base.voltage.unit
```
To modify the internal unit prefix, the following macro can be used:
```@example addBusUnit
@base(system, VA, kV)
nothing # hide
```
After executing this macro, the base voltage values will be stored in kilovolts (kV):
```@repl addBusUnit
system.base.voltage.value, system.base.voltage.unit
```

---

## [Add Branch](@id AddBranchManual)
The branch can only be added once buses are defined, and the `from` and `to` keywords must match the bus labels already defined. For example:
```@example addBranch
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1)
addBus!(system; label = "Bus 2", type = 1, angle = -0.2)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
```
Here, we created the branch from `Bus 1` to `Bus 2` with following parameter:
```@repl addBranch
system.branch.parameter.reactance
```
!!! note "Info"
    It is recommended to consult the documentation for the [`addBranch!`](@ref addBranch!) function, where we have provided a list of all the keywords that can be used.

---

##### Customizing Input Units for Keywords
To use units other than per-units (pu) and radians (rad), macros can be employed to change the input units. For example, if the need arises to use ohms (Ω), the macros below can be employed:
```@example addBranchUnit
using JuliaGrid # hide
@parameter(Ω, pu)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1)
addBus!(system; label = "Bus 2", type = 1, angle = -0.2)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 22.8528)
```
Still, all electrical quantities are stored in per-units, and the same branch as before is created:
```@repl addBranchUnit
system.branch.parameter.reactance
```

It is important to note that, when working with impedance and admittance values in ohms (Ω) and siemens (S) that are related to a transformer, the assignment must be based on the primary side of the transformer.

---

## [Add Generator](@id AddGeneratorManual)
After defining the buses, generators can be added to the power system. Each generator must have a unique label, and the `bus` keyword should correspond to the unique label of the bus it is connected to. For instance:
```@example addGenerator
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")

addGenerator!(system; label = "Generator 1", bus = "Bus 2", active = 0.5, reactive = 0.1)

nothing # hide
```

In the above code, we add the generator to the `Bus 2`, with active and reactive power outputs set to:
```@repl addGenerator
[system.generator.output.active system.generator.output.reactive]
```
Similar to buses and branches, the input units can be changed to units other than per-units using different macros.

!!! note "Info"
    It is recommended to refer to the documentation for the [`addGenerator!`](@ref addGenerator!) function, where we have provided a list of all the keywords that can be used.

---

## [Add Templates](@id AddTemplatesManual)
The functions [`addBus!`](@ref addBus!), [`addBranch!`](@ref addBranch!), and [`addGenerator!`](@ref addGenerator!) are used to add bus, branch, and generator to the power system, respectively. If certain keywords are not specified, default values are assigned to some parameters.

---

##### Default Keyword Values
Regarding the [`addBus!`](@ref addBus!) function, the bus type is automatically configured as a demand bus with `type = 1`. The initial bus voltage magnitude is set to `magnitude = 1.0` per-unit, while the base voltage is established as `base = 138e3` volts. Additionally, the minimum and maximum bus voltage magnitudes are set to `minMagnitude = 0.9` per-unit and `maxMagnitude = 1.1` per-unit, respectively.

Transitioning to the [`addBranch!`](@ref addBranch!) function, the default operational status is `status = 1`, indicating that the branch is in-service. The off-nominal turns ratio for the transformer is specified as `turnsRatio = 1.0`, and the phase shift angle is set to `shiftAngle = 0.0`, collectively defining the line configuration with these standard settings. The flow rating is also configured as `type = 1`. Moreover, the minimum and maximum voltage angle differences between the from-bus and to-bus ends are set to `minDiffAngle = -2pi` and `maxDiffAngle = 2pi`, respectively.

Similarly, the [`addGenerator!`](@ref addGenerator!) function designates an operational generator by employing `status = 1`, and it sets `magnitude = 1.0` per-unit, denoting the desired voltage magnitude setpoint.

The remaining parameters are initialized with default values of zero.

---

##### Change Default Keyword Values
In JuliaGrid, users have the flexibility to adjust default values and assign customized values using the [`@bus`](@ref @bus), [`@branch`](@ref @branch), and [`@generator`](@ref @generator) macros. These macros create bus, branch, and generator templates that are used every time the [`addBus!`](@ref addBus!), [`addBranch!`](@ref addBranch!), and [`addGenerator!`](@ref addGenerator!) functions are called. For instance, the code block shows an example of creating bus, branch, and generator templates with customized default values:
```@example CreateBusTemplate
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

@bus(type = 2, active = 0.1)
addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2", type = 1, active = 0.5)

@branch(reactance = 0.12)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.06)

@generator(magnitude = 1.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.6)
addGenerator!(system; label = "Generator 2", bus = "Bus 1", active = 0.2)

nothing # hide
```

This code example involves two uses of the [`addBus!`](@ref addBus!) and [`addBranch!`](@ref addBranch!) functions. In the first use, the functions rely on the default values set by the templates created with the [`@bus`](@ref @bus) and [`@branch`](@ref @branch) macros. In contrast, the second use passes specific values that match the keywords used in the templates. As a result, the templates are ignored:
```@repl CreateBusTemplate
system.bus.layout.type
[system.bus.demand.active system.branch.parameter.reactance]
```

In the given example, the [`@generator`](@ref @generator) macro is utilized instead of repeatedly specifying the `magnitude` keyword in the [`addGenerator!`](@ref addGenerator!) function. This macro creates a generator template with a default value for `magnitude`, which is automatically applied every time the [`addGenerator!`](@ref addGenerator!) function is called. Therefore, it eliminates the requirement to set the magnitude value for each individual generator:
```@repl CreateBusTemplate
system.generator.voltage.magnitude
```
---

##### Customizing Input Units for Keywords
The JuliaGrid requires users to specify electrical quantity-related keywords in per-units (pu) and radians (rad) by default. However, it provides macros, such as [`@power`](@ref @power), that allow users to specify other units:
```@example CreateBusTemplateUnits
using JuliaGrid # hide

system = powerSystem()

@power(MW, MVAr, MVA)
@bus(active = 100, reactive = 200)
addBus!(system; label = "Bus 1")

@power(pu, pu, pu)
addBus!(system; label = "Bus 2", active = 0.5)

nothing # hide
```

In this example, we create the bus template and one bus using SI power units, and then we switch to per-units and add the second bus. It is important to note that once the template is defined in any unit system, it remains valid regardless of subsequent unit system changes. The resulting power values are:
```@repl CreateBusTemplateUnits
[system.bus.demand.active system.bus.demand.reactive]
```
Thus, JuliaGrid automatically tracks the unit system used to create templates and provides the appropriate conversion to per-units and radians. Even if the user switches to a different unit system later on, the previously defined template will still be valid.

---

##### Multiple Templates
In the case of calling the [`@bus`](@ref @bus), [`@branch`](@ref @branch), or [`@generator`](@ref @generator) macros multiple times, the provided keywords and values will be combined into a single template for the corresponding component (bus, branch, or generator), which will be used for generating the component.

---

##### Reset Templates
To reset the bus, branch, and generator templates to their default settings, users can utilize the following macros:
```@example CreateBusTemplateUnits
@default(bus)
@default(branch)
@default(generator)
nothing # hide
```

Additionally, users can reset all templates using the macro:
```@example CreateBusTemplateUnits
@default(template)
nothing # hide
```

---

## [Labels](@id LabelsManual)
As we shown above, JuliaGrid mandates a distinctive label for every bus, branch, or generator. These labels are stored in orderdictionaries, functioning as pairs of strings and integers. The string signifies the exclusive label for the specific component, whereas the integer maintains an internal numbering of buses, branches, or generators.

In contrast to the simple labeling approach, JuliaGrid offers several additional methods for labeling. The choice of method depends on the specific needs and can potentially be more straightforward.

---

##### Integer-Based Labeling
If users prefer to utilize integers as labels in various functions, this is acceptable. However, it is important to note that despite using integers, these labels are still stored as strings. Let us take a look at the following illustration:
```@example LabelInteger
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.1)
addBus!(system; label = 2, type = 1, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.12)

addGenerator!(system; label = 1, bus = 2, active = 0.5, reactive = 0.1)

nothing # hide
```

In this example, we create two buses labelled as `1` and `2`. The branch is established between these two buses with a unique branch label of `1`. Finally, the generator is connected to the bus labelled `2` and has its distinct label set to `1`.

---

##### Automated Labeling
Users also possess the option to omit the `label` keyword, allowing JuliaGrid to independently allocate unique labels for buses, branches, or generators. In such instances, JuliaGrid employs an ordered set of incremental integers for labeling components. To illustrate, consider the subsequent example:
```@example LabelAutomatic
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; type = 3, active = 0.1)
addBus!(system; type = 1, angle = -0.2)

addBranch!(system; from = 1, to = 2, reactance = 0.12)

addGenerator!(system; bus = 2, active = 0.5, reactive = 0.1)

nothing # hide
```
This example presents the same power system as before. In the previous example, we used an ordered set of increasing integers for labels, in line with JuliaGrid's automatic labeling behavior when the label keyword is omitted.

---

##### Automated Labeling Using Templates
Additionally, users have the ability to generate labels through templates and employ the symbol `?` to insert an incremental set of integers at any location. For instance:
```@example LabelAutomaticTemplate
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(label = "Bus ? HV")
addBus!(system; type = 3, active = 0.1)
addBus!(system; type = 1, angle = -0.2)

@branch(label = "Branch ?")
addBranch!(system; from = "Bus 1 HV", to = "Bus 2 HV", reactance = 0.12)

@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 2 HV", active = 0.5, reactive = 0.1)

nothing # hide
```
In this this example, two buses are generated and labeled as `Bus 1 HV` and `Bus 2 HV`, along with one branch and one generator labeled as `Branch 1` and `Generator 1`, respectively.

---

##### Retrieving Labels
Finally, we will outline how users can retrieve stored labels. Let us consider the following power system creation:
```@example RetrieveLabels
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 3")

addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 1", reactance = 0.8)
addBranch!(system; label = "Branch 1", from = "Bus 2", to = "Bus 3", reactance = 0.5)

addGenerator!(system; label = "Generator 2", bus = "Bus 1")
addGenerator!(system; label = "Generator 1", bus = "Bus 3")

nothing # hide
```

For instance, the bus labels can be accessed using the variable:
```@repl RetrieveLabels
system.bus.label
```

If the objective is to obtain labels in the same order as the bus definitions sequence, users can utilize the following:
```@repl RetrieveLabels
label = collect(keys(system.bus.label))
```

This approach can also be extended to branch and generator labels by making use of the variables present within the `PowerSystem` composite type, namely `system.branch.label` or `system.generator.label`.

Moreover, the `from` and `to` keywords associated with branches are stored based on internally assigned numerical values linked to bus labels. These values are stored in variables:
```@repl RetrieveLabels
[system.branch.layout.from system.branch.layout.to]
```
To recover the original `from` and `to` labels, we can utilize the following method:
```@repl RetrieveLabels
[label[system.branch.layout.from] label[system.branch.layout.to]]
```

Similarly, the `bus` keywords related to generators are saved based on internally assigned numerical values corresponding to bus labels and can be accessed using:
```@repl RetrieveLabels
system.generator.layout.bus
```
To recover the original `bus` labels, we can utilize the following method:
```@repl RetrieveLabels
label[system.generator.layout.bus]
```

!!! tip "Tip"
    JuliaGrid offers the capability to print labels alongside various types of data, such as power system parameters, voltages, powers, currents, or constraints used in optimal power flow analyses. For instance, users can use the following code to print labels in combination with specific data:
    ```@repl RetrieveLabels
    print(system.branch.label, system.branch.parameter.reactance)
    ```

---

## [AC and DC Model](@id ACDCModelManual)
When we constructed the power system, we can create an AC and/or DC model, which include vectors and matrices related to the power system's topology and parameters. The following code snippet demonstrates this:
```@example ACDCModel
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, susceptance = 0.05)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 0.1745)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.008, reactance = 0.05)

acModel!(system)
dcModel!(system)

nothing # hide
```

!!! tip "Tip"
    In many instances throughout the JuliaGrid documentation, we explicitly mention these functions by their names, although it is not mandatory. If a user begins any of the various AC or DC analyses without having previously established the AC or DC model using the [`acModel!`](@ref acModel!) or [`dcModel!`](@ref dcModel!) function, the respective function for setting the analysis will automatically create the AC or DC model.

The nodal matrices are one of the components of both the AC and DC models and are stored in the variables:
```@repl ACDCModel
system.model.ac.nodalMatrix
system.model.dc.nodalMatrix
```

!!! note "Info"
    The AC model is used for performing AC power flow, AC optimal power flow, nonlinear state estimation, or state estimation with PMUs, whereas the DC model is essential for various DC or linear analyses. Consequently, once these models are developed, they can be applied to various types of simulations. We recommend that the reader refer to the tutorial on [AC and DC models](@ref ACDCModelTutorials).

---

##### New Branch Triggers Model Update
We can execute the [`acModel!`](@ref acModel!) and [`dcModel!`](@ref dcModel!) functions after defining the final number of buses, and each new branch added will trigger an update of the AC and DC vectors and matrices. Here is an example:
```@example ACDCModelUpdate
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, susceptance = 0.05)

acModel!(system)
dcModel!(system)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 0.1745)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.008, reactance = 0.05)

nothing # hide
```
For example, the nodal matrix in the DC framework has the same values as before:
```@repl ACDCModelUpdate
system.model.dc.nodalMatrix
```

!!! tip "Tip"
    It is not fully recommended to create AC and DC models before adding a large number of branches if the execution time of functions is important. Instead, triggering updates to the AC and DC models using the [`addBranch!`](@ref addBranch!) function is useful for power systems that require the addition of several branches. This update avoids the need to recreate vectors and matrices from scratch.

---

##### New Bus Triggers Model Erasure
The AC and DC models must be defined when a finite number of buses are defined, otherwise, adding a new bus will delete them. For example, if we attempt to add a new bus to the `PowerSystem` type that was previously created, the current AC and DC models will be completely erased:
```@repl ACDCModelUpdate
addBus!(system; label = "Bus 4", type = 2)
system.model.ac.nodalMatrix
system.model.dc.nodalMatrix
```

---

## [Update Bus](@id UpdateBusManual)
Once a bus has been added to the `PowerSystem` composite type, users have the flexibility to modify all parameters defined within the [`addBus!`](@ref addBus!) function. This means that when the [`updateBus!`](@ref updateBus!) function is used, the `PowerSystem` type within AC and DC models that have been created is updated. This eliminates the need to recreate the AC and DC models from scratch.

To illustrate, let us consider the following power system:
```@example updateSystem
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.1, conductance = 0.01)
addBus!(system; label = "Bus 2", type = 2, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, susceptance = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.05)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5)
addGenerator!(system; label = "Generator 2", bus = "Bus 1", active = 0.2)

acModel!(system)
dcModel!(system)

nothing # hide
```

For instance, the nodal matrix in the AC framework has the following form:
```@repl updateSystem
system.model.ac.nodalMatrix
```

Now, let us add a shunt element to `Bus 2`:
```@example updateSystem
updateBus!(system; label = "Bus 2", conductance = 0.4, susceptance = 0.5)

nothing # hide
```

As we can observe, executing the function triggers an update of the AC nodal matrix:
```@repl updateSystem
system.model.ac.nodalMatrix
```

---

## [Update Branch](@id UpdateBranchManual)
Once a branch has been added to the `PowerSystem` composite type, users have the flexibility to modify all parameters defined within the [`addBranch!`](@ref addBranch!) function. This means that when the [`updateBranch!`](@ref updateBranch!) function is used, the `PowerSystem` type within AC and DC models that have been created is updated. This eliminates the need to recreate the AC and DC models from scratch.

To illustrate, let us continue with the previous example and modify the parameters of `Branch 1` as follows:
```@example updateSystem
updateBranch!(system; label = "Branch 1", resistance = 0.012, reactance = 0.3)

nothing # hide
```
We can observe the update in the AC nodal matrix:
```@repl updateSystem
system.model.ac.nodalMatrix
```

Next, let us switch the status of `Branch 2` from in-service to out-of-service:
```@example updateSystem
updateBranch!(system; label = "Branch 2", status = 0)

nothing # hide
```

As before, the updated AC nodal matrix takes the following form:
```@repl updateSystem
system.model.ac.nodalMatrix
```

---

##### Drop Zeros
After the last execution of the [`updateBranch!`](@ref updateBranch!) function, the nodal matrices will contain zeros, as demonstrated in the code example. If needed, the user can remove these zeros using the `dropZeros!` function, as shown below:
```@example updateSystem
dropZeros!(system.model.ac)

nothing # hide
```

!!! note "Info"
    It is worth mentioning that in simulations conducted with the JuliaGrid package, the precision of the outcomes remains unaffected even if zero entries are retained. However, we recommend users utilize this function instead of `dropzeros!` from the SuiteSparse package to ensure seamless functioning of all JuliaGrid functionalities.

---

## [Update Generator](@id UpdateGeneratorManual)
Finally, users can update all generator parameters defined within the [`addGenerator!`](@ref addGenerator!) function using the [`updateGenerator!`](@ref updateGenerator!) function. The execution of this function will affect all variables within the `PowerSystem` type.

In short, in addition to the `generator` field, JuliaGrid also retains variables associated with generators within the `bus` field. As an example, let us examine one of these variables and its values derived from a previous example:
```@repl updateSystem
system.bus.supply.active
```

Next, we will change the active output power of `Generator 1`:
```@example updateSystem
updateGenerator!(system; label = "Generator 1", active = 0.9)

nothing # hide
```

As we can see, executing the function triggers an update of the observed variable:
```@repl updateSystem
system.bus.supply.active
```

Hence, this function ensures the adjustment of generator parameters and updates all fields of the `PowerSystem` composite type affected by them.

---

## [Add and Update Costs](@id AddUpdateCostsManual)
The [`cost!`](@ref cost!) function is responsible for adding and updating costs associated with the active or reactive power produced by the corresponding generator. These costs are added only if the corresponding generator is defined.

To start, let us create an example of a power system using the following code:
```@example addActiveCost
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")

addGenerator!(system; label = "Generator 1", bus = "Bus 2")

nothing # hide
```

---

##### Polynomial Cost
Let us define a quadratic polynomial cost function for the active power produced by the `Generator 1`:
```@example addActiveCost
cost!(system; label = "Generator 1", active = 2, polynomial = [1100.0; 500.0; 150.0])
```
In essence, what we have accomplished is the establishment of a cost function depicted as ``f(P_{\text{g}1}) = 1100 P_{\text{g}1}^2 + 500 P_{\text{g}1} + 150`` through the code provided. In general, when constructing a polynomial cost function, the coefficients must be ordered from the highest degree to the lowest.


The default input units are in per-units (pu), with coefficients of the cost function having units of currency/pu²hr for 1100, currency/puhr for 500, and currency/hr for 150. Therefore, the coefficients are stored exactly as entered:
```@repl addActiveCost
system.generator.cost.active.polynomial
```
By setting `active = 2` within the function, we express our intent to specify the active power cost using the `active` key. By using a value of `2`, we signify our preference for employing a quadratic polynomial cost model for the associated generator. This flexibility proves invaluable when we have previously defined a piecewise linear cost function for the same generator. In such cases, we can set `active = 1` to utilize the piecewise linear cost function to represent the cost of the corresponding generators. Thus, we retain the freedom to choose between these two cost functions according to the requirements of our simulation. Additionally, users have the option to define both piecewise and polynomial costs within a single function call, further enhancing the versatility of the implementation.

---

##### Piecewise Linear Cost
We can also create a piecewise linear cost function, for example, let us create the reactive power cost function for the same generator using the following code:
```@example addActiveCost
cost!(system; label = "Generator 1", reactive = 1, piecewise = [0.11 12.3; 0.15 16.8])
nothing # hide
```
The first column denotes the generator's output reactive powers in per-units, while the second column specifies the corresponding costs for the specified reactive power in currency/hr. Thus, the data is stored exactly as entered:
```@repl addActiveCost
system.generator.cost.reactive.piecewise
```

---

##### Customizing Input Units for Keywords
Changing input units from per-units (pu) can be particularly useful since cost functions are usually related to SI units of powers. Let us set active powers in megawatts (MW) and reactive powers in megavolt-amperes reactive (MVAr) :
```@example addActiveCost
@power(MW, MVAr, pu)

nothing # hide
```

Now, we can add the quadratic polynomial function using megawatts:
```@example addActiveCost
cost!(system; label = "Generator 1", active = 2, polynomial = [0.11; 5.0; 150.0])
```
After inspecting the resulting cost data, we can see that it is the same as before:
```@repl addActiveCost
system.generator.cost.active.polynomial
```

Similarly, we can define the linear piecewise cost using megavolt-amperes reactive:
```@example addActiveCost
cost!(system; label = "Generator 1", reactive = 1, piecewise = [11.0 12.3; 15.0 16.8])
nothing # hide
```
Upon inspection, we can see that the stored data is the same as before:
```@repl addActiveCost
system.generator.cost.reactive.piecewise
```

!!! tip "Tip"
    The [`cost!`](@ref cost!) function not only adds costs but also allows users to update previously defined cost functions. This functionality is particularly valuable in optimal power flow analyses, as it allows users to modify generator power costs without the need to recreate models from scratch.