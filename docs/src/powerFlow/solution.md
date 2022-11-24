# [Power Flow Analysis](@id dcPowerFlowAnalysis)

The power flow analysis requires the composite type `PowerSystem` with fields `bus`, `branch`, `generator`. In addition, depending on whether AC or DC power flow analysis is used, `acModel` or `dcModel` is required.

JuliaGrid stores results in the composite type `Result` with fields:
* `bus`
* `branch`
* `generator`
* `algorithm`.

Once the composite type `PowerSystem` is created, it is possible to create the composite type `Result`. The composite type `Result` in the DC power flow analysis is created when determining the bus voltages using the function `dcPowerFlow()`. In contrast, the AC power flow analysis first requires the initialization of the iterative method, during which the composite type `Result` is created:
* `newtonRaphson()`
* `fastNewtonRaphsonBX()`
* `fastNewtonRaphsonXB()`
* `gaussSeidel()`.

The calculation of the bus voltages, depending on the type of analysis and the selected method, can be performed using one of the functions:
* `newtonRaphson!()`
* `fastNewtonRaphson!()`
* `gaussSeidel!()`
* `dcPowerFlow()`.
Note that the methods for solving the AC power flow problem should be called inside a loop, thus simulating an iterative process.

Then, it is possible to calculate other quantities of interest using functions:
* `bus!()`
* `branch!()`
* `generator!()`.

---

## Newton-Raphson Method
Functions receive the composite type `PowerSystem`.
```@docs
newtonRaphson
newtonRaphson!
```

---

## Fast Newton-Raphson Method
Functions receive the composite type `PowerSystem`.
```@docs
fastNewtonRaphsonBX
fastNewtonRaphsonXB
fastNewtonRaphson!
```

---

## Gauss-Seidel Method
Functions receive the composite type `PowerSystem`.
```@docs
gaussSeidel
gaussSeidel!
```

---

## DC Power Flow Solution
The function receives the composite type `PowerSystem`, and returns the composite type `Result`.
```@docs
dcPowerFlow
```
