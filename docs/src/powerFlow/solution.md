# [Power Flow Solution](@id powerFlowSolution)

The solution of the power flow implies the calculation of the bus voltages. To obtain a solution, the framework requires the composite type `PowerSystem` with fields `bus`, `branch`, and `generator`. In addition, depending on whether AC or DC power flow is used, `acModel` or `dcModel` is required.

JuliaGrid stores results in the composite type `Result` with fields:
* `bus`
* `branch`
* `generator`
* `algorithm`.

Once the composite type `PowerSystem` is created, it is possible to create the composite type `Result`. The composite type `Result` in the DC power flow is created when determining the bus voltage angles using the function [`dcPowerFlow()`](@ref dcPowerFlow). In contrast, the AC power flow requires the initialization of the iterative method, during which the composite type `Result` is created:
* [`newtonRaphson()`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX()`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB()`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel()`](@ref gaussSeidel).

The calculation of the bus voltages, depending on the type of power flow and the selected method, can be performed using one of the functions:
* [`newtonRaphson!()`](@ref newtonRaphson!)
* [`fastNewtonRaphson!()`](@ref fastNewtonRaphson!)
* [`gaussSeidel!()`](@ref gaussSeidel!)
* [`dcPowerFlow()`](@ref dcPowerFlow).
Note that methods for solving the AC power flow problem should be called inside a loop, thus simulating an iterative process.

In addition, JuliaGrid has an additional set of functions for [power flow analysis](@ref powerFlowAnalysis), which includes determining the powers and currents related to buses, branches or generators:
* [`bus!()`](@ref bus!)
* [`branch!()`](@ref branch!)
* [`generator!()`](@ref generator!).

JuliaGrid also provides the function that checks [reactive power limits of the generators](@ref generatorReactivePowerLimits), once the solution of the AC power flow is obtained:
* [`reactivePowerLimit!()`](@ref reactivePowerLimit!)

---

## Newton-Raphson Method
```@docs
newtonRaphson
newtonRaphson!
```

---

## Fast Newton-Raphson Method
```@docs
fastNewtonRaphsonBX
fastNewtonRaphsonXB
fastNewtonRaphson!
```

---

## Gauss-Seidel Method
```@docs
gaussSeidel
gaussSeidel!
```

---

## DC Power Flow Solution
```@docs
dcPowerFlow
```