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

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Build Model
The method `powerSystem()` builds the main composite type `PowerSystem` and populate fields `bus`, `branch`, `generator` and `basePower`.
```@docs
powerSystem(inputFile::String)
```

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Bus Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change bus parameters, and affect field `bus`.
```@docs
addBus!
```
```@docs
shuntBus!
```

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Branch Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change branch parameters. Further, functions affect field `branch`, but also fields `acModel` and `dcModel`. More precisely, once `acModel` and `dcModel` are created, the execution of functions will automatically trigger the update of these fields.
```@docs
addBranch!
```
```@docs
statusBranch!
```
```@docs
parameterBranch!
```

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Generator Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change generator parameters. Further, functions affect fields `generator` and `bus`.
```@docs
addGenerator!
```
```@docs
statusGenerator!
```
```@docs
outputGenerator!
```

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Build AC or DC Model
The functions receives the main composite type `PowerSystem` and forms vectors and matrices related with AC or DC simulations.
```@docs
acModel!
```
```@docs
dcModel!
```

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Build DC Model
The function `dcModel!()` receives the main composite type `PowerSystem` and forms vectors and matrices related with DC simulations:
```julia-repl
dcModel!(system)
```
The function affects field `acModel`. Once formed, the field will be automatically updated when using functions `addBranch!()`, `statusBranch!()` `parameterBranch!()`. We advise the reader to read the section [in-depth DC Model](@ref inDepthDCModel), that explains all the data involved in the field `dcModel`.

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Modifying Other Parameters
Changing other parameters of the power system can be done by changing variables by accessing their values in fields `bus`, `branch` and `generator` of the main type `powerSystem`.

