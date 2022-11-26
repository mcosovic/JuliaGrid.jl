# [Power Flow Solution](@id powerFlowSolution)

The solution of the power flow analysis implies the determination of the bus voltages. To obtain a solution, the framework requires the composite type `PowerSystem` with fields `bus`, `branch`, `generator`. In addition, depending on whether AC or DC power flow analysis is used, `acModel` or `dcModel` is required.

JuliaGrid stores results in the composite type `Result` with fields:
* `bus`
* `branch`
* `generator`
* `algorithm`.

Once the composite type `PowerSystem` is created, it is possible to create the composite type `Result`. The composite type `Result` in the DC power flow analysis is created when determining the bus voltage angle using the function [`dcPowerFlow()`](@ref dcPowerFlow). In contrast, the AC power flow analysis first requires the initialization of the iterative method, during which the composite type `Result` is created:
* [`newtonRaphson()`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX()`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB()`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel()`](@ref gaussSeidel).

The calculation of the bus voltages, depending on the type of analysis and the selected method, can be performed using one of the functions:
* [`newtonRaphson!()`](@ref newtonRaphson!)
* [`fastNewtonRaphson!()`](@ref fastNewtonRaphson!)
* [`gaussSeidel!()`](@ref gaussSeidel!)
* [`dcPowerFlow()`](@ref dcPowerFlow).
Note that methods for solving the AC power flow problem should be called inside a loop, thus simulating an iterative process.

Then, it is possible to calculate powers related to buses, powers and currents related to branches, and powers related to generators:
* [`bus!()`](@ref bus!)
* [`branch!()`](@ref branch!)
* [`generator!()`](@ref generator!).

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