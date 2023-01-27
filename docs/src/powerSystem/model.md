# [Power System Model](@id powerSystemModel)

The JuliaGrid supports the composite type `PowerSystem` to preserve power system data, with the following fields: `bus`, `branch`, `generator`, `base`, `acModel`, and `dcModel`. The fields `bus`, `branch`, and `generator` hold data related to buses, branches, and generators, respectively. The `base` field stores base values for power and voltages, with the default being three-phase power measured in volt-amperes (VA) for the base power and line-to-line voltages measured in volts (V) for base voltages. The macro command [`@base`](@ref @base) can be used to change the default unit settings for the base quantities of the composite type `PowerSystem` before it is created. Finally, the `acModel` and `dcModel` fields store vectors and matrices calculated based on the power system's topology and parameters.

The composite type `PowerSystem` can be created using a function:
* [`powerSystem()`](@ref powerSystem).
JuliaGrid supports three modes for populating the `PowerSystem` type: using built-in functions, using HDF5 file format, and using [Matpower](https://matpower.org) case files. It is recommended to use the HDF5 format for large-scale systems. To facilitate this, JuliaGrid has the function:
* [`savePowerSystem()`](@ref savePowerSystem).
This function allows to save power systems that were either loaded from Matpower case files or created using built-in functions in the HDF5 format.

Once the `PowerSystem` type is created, you can add buses, branches, and generators using the following functions:
* [`addBus!()`](@ref addBus!)
* [`addBranch!()`](@ref addBranch!)
* [`addGenerator!()`](@ref addGenerator!).
In addition, it is possible to manipulate the parameters of buses, branches, and generators using the following functions:
* [`slackBus!()`](@ref slackBus!)
* [`shuntBus!()`](@ref shuntBus!)
* [`statusBranch!()`](@ref statusBranch!)
* [`parameterBranch!()`](@ref parameterBranch!)
* [`statusGenerator!()`](@ref statusGenerator!)
* [`outputGenerator!()`](@ref outputGenerator!).
Executing these functions will automatically update all fields affected by them. You can also change other parameters of the power system by accessing and modifying the values in the `bus`, `branch`, `generator`, and `base` fields of the `PowerSystem` composite type. The input electrical quantities should be entered in per-units or radians, but this default setting can be altered using the following macros [`@power`](@ref @power), [`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

To create vectors and matrices based on the power system topology and parameters, you can use the following functions:
* [`acModel!()`](@ref acModel!)
* [`dcModel!()`](@ref dcModel!).
Note that these functions can be executed at any time once all power system buses are defined. Specifically, using the [`addBranch!()`](@ref addBranch!) function to add a new branch will automatically update the `acModel` and `dcModel` fields. However, adding a new bus using [`addBus!()`](@ref addBus!) requires executing the [`acModel!()`](@ref acModel!) and [`dcModel!()`](@ref dcModel!) functions again. In addition, executing functions related to parameter manipulation of buses and branches will also automatically update the `acModel` and `dcModel` fields.

---

## Build Model
```@docs
powerSystem
```

---

## Save Model
```@docs
savePowerSystem
```

---

## Bus Functions
```@docs
addBus!
slackBus!
shuntBus!
```

---

## Branch Functions
```@docs
addBranch!
statusBranch!
parameterBranch!
```

---

## Generator Functions
```@docs
addGenerator!
addActiveCost!
addReactiveCost!
statusGenerator!
outputGenerator!
```

---

## AC and DC Model
```@docs
dcModel!
acModel!
```

---

## Units
```@docs
@base
@power
@voltage
@parameter
```
