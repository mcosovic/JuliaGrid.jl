# [Build Power System Model](@id inputdata)

The main composite type `PowerSystem` with fields `bus`, `branch`, `generator`, `acModel`, `dcModel`, and `basePower` can be created using a method:
* `powerSystem()`.

Once the model is created, it is possible to add buses, branches and generators using functions:
* `addBus!()`
* `addBranch!()`
* `addGenerator!()`.

The final step is the formation and saving of vectors and matrices obtained based on the power system topology and parameters using functions:
* `acModel!()`
* `dcModel!()`.
Note that, once the field `acModel` and `dcModel` are formed, using function `addBranch!()`, will automatically trigger the update of these fields. In contrast, adding a new bus, using `addBus!()`, requires executing the functions `acModel!()` and `dcModel!()` again.

Then, it is possible to manipulate the parameters of buses, branches and generators using functions:
* `shuntBus!()`
* `statusBranch!()`
* `parameterBranch!()`
* `statusGenerator!()`
* `outputGenerator!()`.
The execution of these functions will automatically trigger the update of all subtypes affected by these functions.

---

## Build Model
The method `powerSystem()` builds the main composite type `PowerSystem` and populate fields `bus`, `branch`, `generator` and `basePower`.
```@docs
powerSystem
```

---

## Bus Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change bus parameters, and affect field `bus`.
```@docs
addBus!
shuntBus!
```

---

## Branch Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change branch parameters. Further, functions affect field `branch`, but also fields `acModel` and `dcModel`. More precisely, once `acModel` and `dcModel` are created, the execution of functions will automatically trigger the update of these fields.
```@docs
addBranch!
statusBranch!
parameterBranch!
```

---

## Generator Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change generator parameters. Further, functions affect fields `generator` and `bus`.
```@docs
addGenerator!
statusGenerator!
outputGenerator!
```

---

## Build AC or DC Model
The functions receives the main composite type `PowerSystem` and forms vectors and matrices related with AC or DC simulations.
```@docs
acModel!
dcModel!
```

---

## Modifying Other Parameters
Changing other parameters of the power system can be done by changing variables by accessing their values in fields `bus`, `branch` and `generator` of the main type `powerSystem`.

