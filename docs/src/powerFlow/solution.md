# [Power Flow Solution](@id powerFlowSolution)

The calculation of bus voltages is essential to solving the power flow problem. The composite type `PowerSystem`, which includes `bus`, `branch`, and `generator` fields, is required to obtain a solution. Additionally, depending on the type of power flow used, either `acModel` or `dcModel` must be used.

After creating the composite type `PowerSystem`, the next step is to create the composite type `Result`, which has fields `bus`, `branch`, `generator`, and `algorithm`. In the DC power flow, `Result` is created when determining the bus voltage angles using the [`dcPowerFlow()`](@ref dcPowerFlow) function. On the other hand, the AC power flow requires the iterative method to be initialized, which is when the composite type `Result` is created using one of the following functions:
* [`newtonRaphson()`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX()`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB()`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel()`](@ref gaussSeidel).

To calculate bus voltages, the appropriate function can be used depending on the type of power flow and method selected. The following functions are available:
* [`newtonRaphson!()`](@ref newtonRaphson!)
* [`fastNewtonRaphson!()`](@ref fastNewtonRaphson!)
* [`gaussSeidel!()`](@ref gaussSeidel!)
* [`dcPowerFlow()`](@ref dcPowerFlow).
Note that when solving the AC power flow problem, the methods should be called inside a loop to simulate an iterative process.

Additionally, JuliaGrid offers a range of functions for conducting [power flow analysis](@ref powerFlowAnalysis), which involves calculating the powers and currents associated with buses, branches, or generators. These functions include:
* [`bus!()`](@ref bus!)
* [`branch!()`](@ref branch!)
* [`generator!()`](@ref generator!).

The JuliaGrid package also includes a function for verifying the reactive power limits of generators after the AC power flow solution has been obtained:
* [`reactivePowerLimit!()`](@ref reactivePowerLimit!).

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