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
addBus!(system; <keyword arguments>)
```

---

#### Change Parameters of the Shunt Element
The function `shuntBus!()` allows changing `conductance` and `susceptance` parameters of the shunt element connected to the bus.
```julia-repl
shuntBus!(system; label, conductance, susceptance)
```
The keywords `label` should correspond to the already defined bus label. Keywords `conductance` or `susceptance` can be omitted, then the value of the omitted parameter remains unchanged. The function also updates the field `acModel`, if field exist.

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Branch Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change branch parameters. Further, functions affect field `branch`, but also fields `acModel` and `dcModel`. More precisely, once `acModel` and `dcModel` are created, the execution of functions will automatically trigger the update of these fields.

---

#### Adding Branch
The function `addBranch!()` add the new branch. Names, descriptions and units of keywords are given in the table [branch group](@ref branchGroup). A branch can be added between already defined buses.
```julia-repl
addBranch!(system; label, from, to, status, resistance, reactance, susceptance, turnsRatio,
    shiftAngle, minAngleDifference, maxAngleDifference, longTerm, shortTerm, emergency)
```
The keywords `label`, `from`, `to`, and one of the parameters `resistance` or `reactance` are mandatory. Default keyword values are set to zero, except for keywords `status = 1`, `minAngleDifference = -2pi`, `maxAngleDifference = 2pi`.

---

#### Change Operating Status
The function `statusBranch!()` allows changing the operating `status` of the branch, from in-service to out-of-service, and vice versa.
```julia-repl
statusBranch!(system; label, status)
```
The keywords `label` should correspond to the already defined branch label.

---

#### Change Parameters
The function `parameterBranch!` allows changing `resistance`, `reactance`, `susceptance`, `turnsRatio` and `shiftAngle` parameters of the branch.
```julia-repl
parameterBranch!(system; label, resistance, reactance, susceptance, turnsRatio, shiftAngle)
```
The keywords `label` should correspond to the already defined branch label. Keywords `resistance`, `reactance`, `susceptance`, `turnsRatio` or `shiftAngle` can be omitted, then the value of the omitted parameter remains unchanged.

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Generator Functions
Functions receives the main composite type `PowerSystem` and arguments by keyword to set or change generator parameters. Further, functions affect fields `generator` and `bus`.

---

#### Adding Generators
The function `addGenerator!()` add the new generator. Names, descriptions and units of keywords are given in the table [generator group](@ref generatorGroup). A generator can be added at already defined bus.
```julia-repl
addGenerator!(system; label, bus, status, area, active, reactive, magnitude, minActive,
    maxActive, minReactive, maxReactive, lowerActive, minReactiveLower, maxReactiveLower,
    upperActive, minReactiveUpper, maxReactiveUpper, loadFollowing, reserve10minute,
    reserve30minute, reactiveTimescale, activeModel, activeStartup, activeShutdown,
    activeDataPoint, activeCoefficient, reactiveModel, reactiveStartup, reactiveShutdown,
    reactiveDataPoint, reactiveCoefficient)
```
The keywords `label` and `bus` are mandatory. Default keyword values are set to zero, except for keywords `status = 1`, `magnitude = 1.0`, `maxActive = Inf`, `minReactive = -Inf`, `maxReactive = Inf`, `activeModel = 2`, `activeDataPoint = 3`, `reactiveModel = 2`, and `reactiveDataPoint = 3`.

---

#### Change Operating Status
The function `statusGenerator!()` allows changing the operating `status` of the generator, from in-service to out-of-service, and vice versa.
```julia-repl
statusGenerator!(system; label, status)
```
The keywords `label` should correspond to the already defined generator label.

---

#### Change Power Output
The function `outputGenerator!()` allows changing `active` and `reactive` output power of the generator.
```julia-repl
outputGenerator!(system; label, active, reactive)
```
The keywords `label` should correspond to the already defined generator label. Keywords `active` or `reactive` can be omitted, then the value of the omitted parameter remains unchanged.

```@raw html
<hr style="border:1px solid #CBCDCD; opacity: 0.5">
```

## Build AC Model
The function `acModel!()` receives the main composite type `PowerSystem` and forms vectors and matrices related with AC simulations:
```julia-repl
acModel!(system)
```
The function affects field `acModel`. Once formed, the field will be automatically updated when using functions `addBranch!()`, `shuntBus!()`, `statusBranch!()` `parameterBranch!()`. We advise the reader to read the section [in-depth AC Model](@ref inDepthACModel), that explains all the data involved in the field `acModel`.

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

