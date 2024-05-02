# [Power System Model](@id powerSystemModelAPI)

For further information on this topic, please see the [Power System Model](@ref PowerSystemModelManual) section of the Manual. Below, we have provided a list of functions that can be used to create, save, and manipulate power system structures, as well as to build AC and DC models of power systems.

---

###### Power System
* [`powerSystem`](@ref powerSystem)
* [`savePowerSystem`](@ref savePowerSystem)
* [`acModel!`](@ref acModel!)
* [`dcModel!`](@ref dcModel!)

###### Bus
* [`addBus!`](@ref addBus!)
* [`updateBus!`](@ref updateBus!)
* [`@bus`](@ref @bus)

###### Branch
* [`addBranch!`](@ref addBranch!)
* [`updateBranch!`](@ref updateBranch!)
* [`@branch`](@ref @branch)

###### Generator
* [`addGenerator!`](@ref addGenerator!)
* [`updateGenerator!`](@ref updateGenerator!)
* [`cost!`](@ref cost!)
* [`@generator`](@ref @generator)

---

To load power system model API functionalities into the current scope, utilize the following command:
```@example LoadApi
using JuliaGrid
```

---

## Power System
```@docs
powerSystem
savePowerSystem
acModel!
dcModel!
```

---

## Bus
```@docs
addBus!
updateBus!
@bus
```

---

## Branch
```@docs
addBranch!
updateBranch!
@branch
```

---

## Generator
```@docs
addGenerator!
updateGenerator!
cost!
@generator
```