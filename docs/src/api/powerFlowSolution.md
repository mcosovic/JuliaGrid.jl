# [Power Flow Solution](@id powerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

###### Build Model
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)
* [`dcPowerFlow`](@ref dcPowerFlow)

###### Solve Power Flow
* [`mismatch!`](@ref mismatch!)
* [`solve!`](@ref solve!)

###### Additional Functions
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!)

---

## Build Model
```@docs
newtonRaphson(::PowerSystem)
fastNewtonRaphsonBX
fastNewtonRaphsonXB
gaussSeidel
dcPowerFlow
```

---

## Solve Power Flow
```@docs
mismatch!
solve!
```

---

## Additional Functions
```@docs
reactiveLimit!
adjustAngle!
```