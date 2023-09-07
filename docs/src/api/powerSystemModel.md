# [Power System Model](@id powerSystemModelAPI)

For further information on this topic, please see the [Power System Model](@ref PowerSystemModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate power system structures, as well as to build AC or DC models of power systems.

---

###### Power System Data
* [`powerSystem`](@ref powerSystem)
* [`savePowerSystem`](@ref savePowerSystem)

###### Bus Functions
* [`addBus!`](@ref addBus!)
* [`updateBus!`](@ref updateBus!)
* [`@bus`](@ref @bus)

###### Branch Functions
* [`addBranch!`](@ref addBranch!)
* [`updateBranch!`](@ref updateBranch!)
* [`@branch`](@ref @branch)

###### Generator Functions
* [`addGenerator!`](@ref addGenerator!)
* [`updateGenerator!`](@ref updateGenerator!)
* [`cost!`](@ref cost!)
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
updateBus!
@bus
```

---

## Branch Functions
```@docs
addBranch!
updateBranch!
@branch
```

---

## Generator Functions
```@docs
addGenerator!
updateGenerator!
cost!
@generator
```

---

## AC and DC Model
```@docs
acModel!
dcModel!
```
