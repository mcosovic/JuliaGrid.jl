# [Power Flow Solution](@id powerFlowSolutionAPI)

For further information on this topic, please see the [Power System Analysis](@ref PowerSystemModelManual) section of the Manual.

---

## API Index

###### Newton-Raphson Method
* [`newtonRaphson`](@ref newtonRaphson)
* [`mismatchNewtonRaphson!`](@ref mismatchNewtonRaphson!)
* [`solveNewtonRaphson!`](@ref solveNewtonRaphson!)

###### Fast Newton-Raphson Method
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`mismatchFastNewtonRaphson!`](@ref mismatchFastNewtonRaphson!)
* [`solveFastNewtonRaphson!`](@ref solveFastNewtonRaphson!)

###### Gauss-Seidel Method
* [`gaussSeidel`](@ref gaussSeidel)
* [`mismatchGaussSeidel!`](@ref mismatchGaussSeidel!)
* [`solveGaussSeidel!`](@ref solveGaussSeidel!)

###### DC Power Flow
* [`dcPowerFlow`](@ref dcPowerFlow)
* [`solveDCPowerFlow!`](@ref solveDCPowerFlow!)

###### Additional Functions
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