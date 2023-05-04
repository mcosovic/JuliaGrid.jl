# [Power Flow Solution](@id powerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)
* [`dcPowerFlow`](@ref dcPowerFlow)

* [`mismatchNewtonRaphson!`](@ref mismatchNewtonRaphson!)
* [`mismatchFastNewtonRaphson!`](@ref mismatchFastNewtonRaphson!)
* [`mismatchGaussSeidel!`](@ref mismatchGaussSeidel!)

* [`solveNewtonRaphson!`](@ref solveNewtonRaphson!)
* [`solveFastNewtonRaphson!`](@ref solveFastNewtonRaphson!)
* [`solveGaussSeidel!`](@ref solveGaussSeidel!)
* [`solveDCPowerFlow!`](@ref solveDCPowerFlow!)

* [`reactivePowerLimit!`](@ref reactivePowerLimit!)
* [`adjustVoltageAngle!`](@ref adjustVoltageAngle!)

---

## Newton-Raphson Method
```@docs
newtonRaphson
mismatchNewtonRaphson!
solveNewtonRaphson!
```

---

## Fast Newton-Raphson Method
```@docs
fastNewtonRaphsonBX
fastNewtonRaphsonXB
mismatchFastNewtonRaphson!
solveFastNewtonRaphson!
```

---

## Gauss-Seidel Method
```@docs
gaussSeidel
mismatchGaussSeidel!
solveGaussSeidel!
```

---

## DC Power Flow
```@docs
dcPowerFlow
solveDCPowerFlow!
```

---

## Additional Functions
```@docs
reactivePowerLimit!
adjustVoltageAngle!
```