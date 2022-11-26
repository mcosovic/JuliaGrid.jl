# [Build Power System Model](@id buildPowerSystemModel)

The composite type `PowerSystem` with fields `bus`, `branch`, `generator`, `acModel`, `dcModel`, and `basePower` can be created using a method:
* `powerSystem()`.

Once the model is created, it is possible to add buses, branches and generators using the functions:
* [`addBus!()`](@ref addBus!)
* [`addBranch!()`](@ref addBranch!)
* [`addGenerator!()`](@ref addGenerator!).

In addition, it is possible to manipulate the parameters of buses, branches and generators using functions:
* [`shuntBus!()`](@ref shuntBus!)
* [`statusBranch!()`](@ref statusBranch!)
* [`parameterBranch!()`](@ref parameterBranch!)
* [`statusGenerator!()`](@ref statusGenerator!)
* [`outputGenerator!()`.](@ref outputGenerator!)
The execution of these functions will automatically trigger the update of all fields affected by these functions. Changing other parameters of the power system can be done by changing variables by accessing their values in fields `bus`, `branch` and `generator` of the composite type `powerSystem`.

At any moment after the composite type `PowerSystem` is formed, it is possible to save the data describing the power system in HDF5 format:
* `savePowerSystem()`

To create vectors and matrices obtained based on the power system topology and parameters, following functions are used:
* `acModel!()`
* `dcModel!()`.
Note that, functions can be executed at any time, and when all power system buses are defined. More precisely, once the field `acModel` and `dcModel` are formed, using function `addBranch!()`, will automatically trigger the update of these fields. In contrast, adding a new bus, using `addBus!()`, requires executing the functions `acModel!()` and `dcModel!()` again. Further, the execution of the functions related to parameter manipulation of buses and branches will automatically trigger the update of the fields `acModel` and `dcModel`.

---

## Build Model
The method `powerSystem()` builds the composite type `PowerSystem` and populates fields `bus`, `branch`, `generator` and `basePower`.
```@docs
powerSystem
```

---

## Bus Functions
Functions receive the composite type `PowerSystem` and arguments by keyword to set or change bus parameters and update the field `bus`.
```@docs
addBus!
shuntBus!
```

---

## Branch Functions
Functions receive the composite type `PowerSystem` and arguments by keyword to set or change branch parameters. Further, functions update the field `branch`, but also fields `acModel` and `dcModel`. More precisely, once `acModel` and `dcModel` are created, the execution of functions will automatically trigger the update of these fields.
```@docs
addBranch!
statusBranch!
parameterBranch!
```

---

## Generator Functions
Functions receive the composite type `PowerSystem` and arguments by keyword to set or change generator parameters. Further, functions update fields `generator` and `bus`.
```@docs
addGenerator!
statusGenerator!
outputGenerator!
```

---

## [Save Model](@id saveModel)
```@docs
savePowerSystem
```

---

## Build AC or DC Model
The functions receive the composite type `PowerSystem` and form vectors and matrices related to AC or DC simulations.
```@docs
acModel!
dcModel!
```
