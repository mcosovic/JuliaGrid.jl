# [Power System Model](@id powerSystemModelAPI)

For further information on this topic, please see the [Power System Model](@ref PowerSystemModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate power system structures, as well as to build AC or DC models of power systems.

---

###### Power System Data
* [`powerSystem`](@ref powerSystem)
* [`savePowerSystem`](@ref savePowerSystem)

###### Bus Functions
* [`addBus!`](@ref addBus!)
* [`demandBus!`](@ref demandBus!)
* [`shuntBus!`](@ref shuntBus!)
* [`@bus`](@ref @bus)

###### Branch Functions
* [`addBranch!`](@ref addBranch!)
* [`statusBranch!`](@ref statusBranch!)
* [`parameterBranch!`](@ref parameterBranch!)
* [`@branch`](@ref @branch)

###### Generator Functions
* [`addGenerator!`](@ref addGenerator!)
* [`statusGenerator!`](@ref statusGenerator!)
* [`outputGenerator!`](@ref outputGenerator!)
* [`addActiveCost!`](@ref addActiveCost!)
* [`addReactiveCost!`](@ref addReactiveCost!)
* [`@generator`](@ref @generator)

###### AC and DC Model
* [`acModel!`](@ref acModel!)
* [`dcModel!`](@ref dcModel!)

---

## Power System Data
```@docs
powerSystem
savePowerSystem
```

---

## Bus Functions
```@docs
addBus!
demandBus!
shuntBus!
@bus
```

---

## Branch Functions
```@docs
addBranch!
statusBranch!
parameterBranch!
@branch
```

---

## Generator Functions
```@docs
addGenerator!
statusGenerator!
outputGenerator!
addActiveCost!
addReactiveCost!
@generator
```

---

## AC and DC Model
```@docs
acModel!
dcModel!
```
