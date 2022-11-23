# [AC Power Flow Analysis](@id acPowerFlowAnalysis)

The AC power flow analysis requires the main composite type `PowerSystem` with fields `bus`, `branch`, `generator`, and `acModel`. Further, JuliaGrid stores results of the AC power flow analysis in the composite type `ACResult` with subtypes:
* `bus`
* `branch`
* `generator`
* `algorithm`
* `mismatch`
* `iteration`.

Once the main composite type `PowerSystem` is created, it is possible to create composite type `ACResult` and initialize one of the algorithms for solving the AC power flow problem:
* `newtonRaphson()`
* `fastNewtonRaphsonBX()`
* `fastNewtonRaphsonXB()`
* `gaussSeidel()`.


Solving the AC power flows implies determining the voltage magnitudes and angles on all buses, and this can be done by using one of the functions below, the function should be inside a loop, which simulates the iterative process:
* `newtonRaphson!()`
* `fastNewtonRaphson!()`
* `gaussSeidel!()`.

Then, it is possible to calculate other quantities of interest using functions:
* `bus!()`
* `branch!()`
* `generator!()`

---

## Initialize Algorithm
At the beginning, it is necessary to initialize the algorithm and create the composite type `ACResult`. Depending on which iterative algorithm will be chosen for solving AC power flow problem, the initialization can be done by one of the functions:
```julia-repl
result = newtonRaphson(system)
result = fastNewtonRaphsonBX(system)
result = fastNewtonRaphsonXB(system)
result = gaussSeidel(system)
```
The function affects field `result.algorithm`, but also field `result.bus.voltage`, setting the voltage angles and magnitudes to the initial values.


## Solution
Functions `newtonRaphson!()`, `fastNewtonRaphson!()`, or `gaussSeidel!()` solves the AC power flow problem by determining the bus voltage magnitudes and angles.
```julia-repl
newtonRaphson!(system, result)
fastNewtonRaphson!(system, result)
gaussSeidel!(system, result)
```
The execution of these functions should be inside a loop to create a iterative process. The function affects fields `result.algorithm`, `result.mismatch`, `result.iteration` and `result.bus.voltage`. The field `result.mismatch` contains absolute values of active and reactive mismatches, which are used to terminate the iterative process.

---

## [In-depth Analysis] (@id acpowerflow)
The AC power flow analysis requested `acModel`, we advise the reader to read the section [in-depth AC Model](@ref inDepthACModel) which describes the model in details.

---

#### [Gauss-Seidel Method](@id gaussseidel)
Defining the injected current into the bus ``i \in \mathcal{N}`` as:
```math
	\bar{I}_{i} = \frac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^*},
```
the power flow problem which is described by the system of non-linear equations:
```math
    \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}},
```
can be written in the expanded form:
```math
  \begin{aligned}
    Y_{11} & \bar{V}_{1}  + \cdots+ Y_{1n}\bar{V}_{n} = \frac{{P}_{1} - j{Q}_{1}}{\bar{V}_{1}^*} \\
    \; \vdots & \\
    Y_{n1} & \bar{V}_{1} + \cdots+ Y_{nn}\bar{V}_{n} = \frac{{P}_{n} - j{Q}_{n}}{\bar{V}_{n}^*}.
	\end{aligned}
```
The Gauss-Seidel method directly solves the above system of equations, albeit with very slow convergence, almost linearly with the size of the system. Consequently, this method needs many iterations to achieve the desired solution [[3]](@ref refs). In general, the Gauss-Seidel method is based on the above system of equations, where the set of non-linear equations has ``n`` complex equations, and one of these equations describes the slack bus. Consequently, one of these equations can be removed resulting in the power flow problem with ``n-1`` equations.

In the following, we observe a power system with sets ``\mathcal{PV}`` and ``\mathcal{PQ}`` that contain PV and PQ buses, respectively, and exactly one slack bus ``\{V \theta\}``:
```math
  \mathcal{H} = \mathcal{PV} \cup \mathcal{PQ} \cup \{V \theta\}.
```
The method starts with initial complex bus voltages ``\bar{V}_i^{(0)}, i \in \mathcal{H}``. The iteration scheme first computes complex bus voltages for PQ buses:
```math
    \bar{V}_{i}^{(\nu + 1)} =
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^{*(\nu)}} -
    \sum\limits_{\substack{j = 1}}^{i - 1} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} -
    \sum\limits_{\substack{j = i + 1}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu)}\Bigg),
    \;\;\; i \in \mathcal{PQ},
```
where ``\nu = \{0,1,\dots,\nu_{\max}\}`` is the iteration index and ``\nu_{\max}`` is the number of iterations. Then, the solution for PV buses are obtained in two steps: we first determine the reactive power injection, then the complex bus voltage is updated:
```math
  \begin{aligned}
    Q_i^{(\nu+1)} &=
    -\Im \left\{ \bar{V}_{i}^{*(\nu + 1)} \sum\limits_{j=1}^n {Y}_{ij}\bar{V}_{j}^{(\nu+1)}\right\}, \;\;\; i \in \mathcal{PV} \\
    \bar{V}_{i}^{(\nu + 1)} &:=
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}^{(\nu + 1)}}{\bar{V}_{i}^{*(\nu + 1)}}-
    \sum\limits_{\substack{j = 1,\;j \neq i}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu + 1)} \Bigg), \;\;\; i \in \mathcal{PV}.
  \end{aligned}
```
Obtained voltage magnitude is not equal to the magnitude specified for the PV bus. Thus, it is necessary to perform the voltage correction:
```math
      \bar{V}_{i}^{(\nu+1)} := {V}_{i}^{(0)} \cfrac{\bar{V}_{i}^{(\nu+1)}}{{V}_{i}^{(\nu+1)}}, \;\;\; i \in \mathcal{PV}.
```

The iteration loop is repeated until the stopping criteria is met. Namely, after one iteration loop is done, we compute active power injection mismatch for PQ and PV buses:
```math
    \Delta P_i^{(\nu + 1)} = \Re\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - P_i, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV},
```
and reactive power injection mismatch for PQ buses:
```math
  \Delta Q_i^{(\nu + 1)} = \Im\{\bar{V}_i^{(\nu + 1)} \bar{I}_i^{*(\nu + 1)}\} - Q_i, \;\;\; i \in \mathcal{PQ}.
```
The iteration loop is stopped when conditions are met:
```math
  \begin{aligned}
    |\Delta P_i^{(\nu + 1)}| &< \epsilon, \;\;\; i \in \mathcal{PQ} \cup \mathcal{PV} \\
    |\Delta Q_i^{(\nu + 1)}| &< \epsilon, \;\;\; i \in \mathcal{PQ},
  \end{aligned}
```
where ``\epsilon`` is a predetermined stopping criteria.

---
