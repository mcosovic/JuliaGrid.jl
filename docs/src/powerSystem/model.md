# [Power System Model](@id powerSystemModel)

The JuliaGrid supports the composite type `PowerSystem` to preserve power system data, with the following fields:
* `bus`
* `branch`
* `generator`
* `base`
* `acModel`
* `dcModel`.
The fields `bus`, `branch`, and `generator` hold data related to buses, branches, and generators, respectively. The `base` field holds base values for power and voltages, with three-phase power as the default for the base power and line-to-line voltages for base voltages. The `acModel` and `dcModel` fields store vectors and matrices calculated based on the power system's topology and parameters.

The composite type `PowerSystem` can be created using a function:
* [`powerSystem()`](@ref powerSystem).
JuliaGrid supports three modes for populating the `PowerSystem` type: using built-in functions, using HDF5 file format, and using [Matpower](https://matpower.org) case files. It is recommended to use the HDF5 format for large-scale systems. To facilitate this, JuliaGrid has the function:
* [`savePowerSystem()`](@ref savePowerSystem).
This function allows to save power systems that were either loaded from Matpower case files or created using built-in functions in the HDF5 format.

Once the `PowerSystem` type is created, you can add buses, branches, and generators using the following functions:
* [`addBus!()`](@ref addBus!)
* [`addBranch!()`](@ref addBranch!)
* [`addGenerator!()`](@ref addGenerator!).
The input data should be entered in per-units or radians, but this default setting can be changed using the [`@unit`](@ref @unit) macro.

In addition, it is possible to manipulate the parameters of buses, branches, and generators using the following functions:
* [`shuntBus!()`](@ref shuntBus!)
* [`statusBranch!()`](@ref statusBranch!)
* [`parameterBranch!()`](@ref parameterBranch!)
* [`statusGenerator!()`](@ref statusGenerator!)
* [`outputGenerator!()`](@ref outputGenerator!).
Executing these functions will automatically update all fields affected by them. You can also change other parameters of the power system by accessing and modifying the values in the `bus`, `branch`, `generator`, and `base` fields of the `PowerSystem` composite type.

To create vectors and matrices based on the power system topology and parameters, you can use the following functions:
* [`acModel!()`](@ref acModel!)
* [`dcModel!()`](@ref dcModel!).
Note that these functions can be executed at any time once all power system buses are defined. Specifically, using the [addBranch!()](@ref addBranch!) function to add a new branch will automatically update the `acModel` and `dcModel` fields. However, adding a new bus using [addBus!()](@ref addBus!) requires executing the [acModel!()](@ref acModel!) and [dcModel!()](@ref dcModel!) functions again. In addition, executing functions related to parameter manipulation of buses and branches will also automatically update the `acModel` and `dcModel` fields.

---

## Build Model
The function builds the composite type `PowerSystem` and populates `bus`, `branch`, `generator` and `base` fields.
```@docs
powerSystem
```

The function modifies the units for base power and base voltages and updates the `base` field.
```@docs
baseUnit!
```

