# [DC Power Flow Analysis](@id DCPowerFlowAnalysisTutorials)

JuliaGrid employs standard network components and the [unified branch model](@ref DCUnifiedBranchModelTutorials) to obtain the DC power flow solution. To begin, the `PowerSystem` composite type must be provided to JuliaGrid through the use of the [`powerSystem`](@ref powerSystem) function, as illustrated by the following example:
```@example PowerFlowSolutionDC
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@power(MW, MVAr, MVA)
@voltage(pu, deg, V)

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 21.7)
addBus!(system; label = 3, type = 2, conductance = 2.1)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.06)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.21)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.17, turnsRatio = 0.96)

addGenerator!(system; label = 1, bus = 3, active = 40.0)
nothing #hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl PowerFlowSolutionDC
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` denotes the generic element associated with bus ``i \in \mathcal{N}``, and ``a_{ij}`` denotes the generic element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [DC Power Flow Solution](@id DCPowerFlowSolutionTutorials)
As discussed in section [DC Model](@ref DCModelTutorials), the DC power flow problem can be represented by a set of linear equations given by:
```math
  \mathbf {P} = \mathbf{B} \bm {\theta} + \mathbf{P_\text{tr}} + \mathbf{P}_\text{sh}.
```

---

##### Implementation
JuliaGrid offers a set of functions to solve the DC power flow problem and obtain the bus voltage angles. Firstly, the power system is loaded and the DC model is built using the following code sequence:
```@example PowerFlowSolutionDC
dcModel!(system)
nothing # hide
```

Next, the DC power flow solution is obtained through a non-iterative approach by solving the system of linear equations:
```math
    \bm {\theta} = \mathbf{B}^{-1}(\mathbf {P} - \mathbf{P_\text{tr}} - \mathbf{P}_\text{sh}).
```
This can be accomplished with the following code in JuliaGrid:
```@example PowerFlowSolutionDC
result = solvePowerFlow(system)
nothing # hide
```

It is important to note that the slack bus voltage angle is excluded from the vector ``\bm{\theta}`` only during the computation step. As a result, the corresponding elements in the vectors ``\mathbf {P}``, ``\mathbf{P_\text{tr}}``, ``\mathbf{P}_\text{sh}``, and the corresponding row and column of the matrix ``\mathbf{B}`` are removed. It is worth mentioning that this process is handled internally, and the stored elements remain unchanged.

Finally, the resulting bus voltage angles are saved in the vector as follows:
```@repl PowerFlowSolutionDC
𝛉 = result.bus.voltage.angle
```

---


## [Bus Powers](@id DCBusPowersTutorials)
JuliaGrid's [`bus!`](@ref bus!) function can be used to compute powers associated with buses, which fills the `bus` field of the `Result` type. Here is an example code snippet:
```@example PowerFlowSolutionDC
bus!(system, result)
nothing # hide
```

To obtain the active power injection at bus ``i \in \mathcal{N}``, we can refer to section [DC Model](@ref DCModelTutorials), which provides the following expression:
```math
   P_i = \sum_{j = 1}^n {B}_{ij} \theta_j + P_{\text{tr}i} + P_{\text{sh}i},\;\;\; i \in \mathcal{N}.
```
Active power injections are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl PowerFlowSolutionDC
𝐏 = result.bus.power.injection.active
```

The active power supplied by generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\text{s}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, can be obtained using the following command:
```@repl PowerFlowSolutionDC
𝐏ₛ = result.bus.power.supply.active
```

---

## [Branch Powers](@id DCBranchPowersTutorials)
To compute powers associated with branches, JuliaGrid provides the [`branch!`](@ref branch!) function, which populates the `branch` field of the `Result` type. Here is an example code snippet:
```@example PowerFlowSolutionDC
branch!(system, result)
nothing # hide
```

The active power flows at from bus end ``i \in \mathcal{N}`` can be obtained using the following equations:
```math
    P_{ij} = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows at from bus end are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using the following command:
```@repl PowerFlowSolutionDC
𝐏ᵢ = result.branch.power.from.active
```

Similarly, the active power flows at to bus end ``j \in \mathcal{N}`` can be obtained as:
```math
    P_{ji} = - P_{ij},\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows at to bus end are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using the following command:
```@repl PowerFlowSolutionDC
𝐏ⱼ = result.branch.power.to.active
```

---

## [Generator Powers](@id DCGeneratorPowersTutorials)
To compute powers associated with generators, JuliaGrid provides the [`generator!`](@ref generator!) function, which populates the `generator` field of the `Result` type. Here is an example code snippet:
```@example PowerFlowSolutionDC
generator!(system, result)
nothing # hide
```

The active power output of a generator located at bus ``i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{pq}}`` is equal to the active power specified in the input data. If there are multiple generators, their active power outputs are also equal to the active power specified in the input data. However, the active power output of a generator located at the slack bus is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators. Therefore, to get the vector of output active power of generators, i.e., ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, you can use the following command:
```@repl PowerFlowSolutionDC
𝐏ₒ = result.generator.power.active
```