# [Power Flow Analysis](@id powerFlowAnalysis)

After obtaining the bus voltages, it becomes possible to calculate the powers and currents associated with buses and branches, as well as the powers related to generators. This can be done using the following functions: 
* [`bus!()`](@ref bus!)
* [`branch!()`](@ref branch!)
* [`generator!()`](@ref generator!).

It's important to note that complex currents are stored in the polar coordinate system, while complex powers are stored in the rectangular coordinate system within JuliaGrid.

---

## Bus
```@docs
bus!
```

---

## Branch
```@docs
branch!
```
---

## Generator
```@docs
generator!
```
