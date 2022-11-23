# [DC Power Flow Analysis](@id dcPowerFlowAnalysis)

The DC power flow analysis requires the main composite type `PowerSystem` with fields `bus`, `branch`, `generator`, and `dcModel`. Further, JuliaGrid stores results of the DC power flow analysis in the composite type `DCResult` with fields:
* `bus`
* `branch`
* `generator`.

Once the main composite type `PowerSystem` is created, it is possible to create composite type `DCResult` and compute voltage angles using the function:
* `dcPowerFlow()`

Then, it is possible to calculate other quantities of interest using functions:
* `bus!()`
* `branch!()`
* `generator!()`

---

## Solution
```@docs
dcPowerFlow
```

---

## Compute Powers
The functions receive the composite types `PowerSystem` and `DCResult`.
```@docs
bus!
branch!
generator!
```

---


## [In-depth Analysis] (@id dcpowerflow)
The DC power flow analysis requested field `dcModel`, we advise the reader to read the section [in-depth DC Model](@ref inDepthDCModel) which describes the model in details.

---

#### Solution
The DC power flow solution is obtained through non-iterative procedure by solving the linear problem:
```math
    \bm {\theta} = \mathbf{B}^{-1}(\mathbf {P} - \mathbf{P_\text{gs}} - \mathbf{P}_\text{sh}).
```
Note that the slack bus voltage angle is known in advance. Respectively, corresponding elements in vectors ``\mathbf {P}``, ``\mathbf{P_\text{gs}}``, ``\mathbf{P}_\text{sh}``, and corresponding column of the matrix ``\mathbf{B}`` will be removed, in the process of calculating the solution. In JuliaGrid, the DC power flow solution is stored as:
```julia-repl
julia> result.bus.voltage.angle
```

---

#### Powers Related to the Buses
Active power injection into the bus ``i \in \mathcal{H}`` can be simply obtained as:
```math
   P_i = \sum_{j \in \mathcal{H}_i} {B}_{ij} \theta_j + P_{\text{gs}i} + g_{\text{sh}i}.
```
In JuliaGrid, the vector that keeps injected active powers into all buses is given as:
```julia-repl
julia> result.bus.power.injection.active
```

Total active power supply from generators into the bus ``i \in \mathcal{H}`` is determined using Tellegen's theorem:
```math
     P_{\text{g}i} = {P}_{i} + {P}_{\text{d}i}.
```
In JuliaGrid, the vector that keeps active powers supply from generators into all buses is given as:
```julia-repl
julia> result.bus.power.supply.active
```

---

#### Powers Related to the Branches
Active power flow at the branch ``(i,j) \in \mathcal{E}`` from bus ``i`` to bus ``j`` is obtained as:
```math
  \begin{aligned}
    P_{ij} &= \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij})\\
  \end{aligned}
```
In JuliaGrid, the vector that keeps active powers at all branches from/to bus is given as:
```julia-repl
julia> result.branch.power.fromBus.active
```
Active power flow at the branch ``(i,j) \in \mathcal{E}`` from bus ``j`` to bus ``i`` is obtained as:
```math
  \begin{aligned}
    P_{ji} &= - P_{ij}.
  \end{aligned}
```
In JuliaGrid, the vector that keeps active powers at all branches to/from bus is given as:
```julia-repl
julia> result.branch.power.toBus.active
```

---

#### Powers Related to the Generators
Active power output of the generator is the same as in the input data, except for the slack bus that is equal to ``P_{\text{g}i}``, where ``i`` is the slack bus. If there are several generators on the slack bus, the first generator in the series will take over part of the power which is needed to balance the system. In JuliaGrid, the vector that keeps active power outputs of the all generators is given as:
```julia-repl
julia> result.generator.power.active
```
