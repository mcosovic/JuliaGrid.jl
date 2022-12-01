# [Power Flow Analysis](@id powerFlowAnalysis)

Once the bus voltages are obtained, it is possible to calculate powers and currents related to buses and branches, and powers related to generators:
* [`bus!()`](@ref bus!)
* [`branch!()`](@ref branch!)
* [`generator!()`](@ref generator!).

Note that the JuliaGrid stores complex currents in the polar coordinate system, while complex powers are stored in the rectangle coordinate system.

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
