# [Power Flow Solution](@id powerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)

* [`mismatch!`](@ref mismatch!)
* [`solvePowerFlow!`](@ref solvePowerFlow!)
* [`solvePowerFlow`](@ref solvePowerFlow)

* [`reactivePowerLimit!`](@ref reactivePowerLimit!)
* [`adjustVoltageAngle!`](@ref adjustVoltageAngle!)

---

## Newton-Raphson Method
```@docs
newtonRaphson
```

---

## Fast Newton-Raphson Method
```@docs
fastNewtonRaphsonBX
fastNewtonRaphsonXB
```

---

## Gauss-Seidel Method
```@docs
gaussSeidel
```

---

## AC Power Flow Solution
```@docs
mismatch!
solvePowerFlow!
```

---

## DC Power Flow Solution
```@docs
solvePowerFlow
```

---

## Additional Functions
```@docs
reactivePowerLimit!
adjustVoltageAngle!
```