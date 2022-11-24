# [Power Flow Analysis](@id dcPowerFlowAnalysis)

The power flow analysis requires the main composite type `PowerSystem` with fields `bus`, `branch`, `generator`. In addition, depending on whether AC or DC power flow analysis is used, `acModel` or `dcModel` is required.

JuliaGrid stores results in the main composite type `Result` with fields:
* `bus`
* `branch`
* `generator`
* `algorithm`

Once the main composite type `PowerSystem` is created, it is possible to create main composite type `Result`. The AC power flow analysis requires the initialization of the algorithm, which creates the composite type `Result` also:
* `newtonRaphson()`
* `fastNewtonRaphsonBX()`
* `fastNewtonRaphsonXB()`
* `gaussSeidel()`.
The composite type `Result` in DC power flow analysis is created when determining the bus voltages.

The calculation of the bus voltages, depending on the type of analysis and the selected algorithm, can be performed using one of the functions:
* `dcPowerFlow()`
* `newtonRaphson!()`
* `fastNewtonRaphson!()`
* `gaussSeidel!()`.
Note that the methods for solving AC power flow problem should be called inside a loop, thus simulating an iterative process.

Then, it is possible to calculate other quantities of interest using functions:
* `bus!()`
* `branch!()`
* `generator!()`

---

## Gauss-Seidel Method
Functions receive the composite type `PowerSystem`.
```@docs
gaussSeidel
gaussSeidel!
```

<!-- ---

## Power Flow Solution
The functions receive the composite types `PowerSystem` and `Result`.
```@docs
gaussSeidel!
newtonRaphson!
fastNewtonRaphson!
dcPowerFlow
``` -->

