# [DC Power Flow](@id DCPowerFlowTutorials)

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
addBus!(system; label = 3, type = 2, conductance = 0.07)

addBranch!(system; from = 1, to = 2, reactance = 0.26)
addBranch!(system; from = 1, to = 3, reactance = 0.38)
addBranch!(system; from = 2, to = 3, reactance = 0.17, turnsRatio = 0.97)

addGenerator!(system; bus = 1, active = 2.0)
addGenerator!(system; bus = 1, active = 4.0)
addGenerator!(system; bus = 3, active = 5.0)
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

## [Power Flow Solution](@id DCPowerFlowSolutionTutorials)
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

The DC power flow solution is obtained through a non-iterative approach by solving the system of linear equations:
```math
    \bm {\theta} = \mathbf{B}^{-1}(\mathbf {P} - \mathbf{P_\text{tr}} - \mathbf{P}_\text{sh}).
```

The initial step taken by JuliaGrid is to factorize the nodal matrix ``\mathbf{B}`` using the function:
```@example PowerFlowSolutionDC
model = dcPowerFlow(system)
nothing # hide
```

The factorization of the nodal matrix can be accessed using:
```@repl PowerFlowSolutionDC
model.factorization
using SparseArrays
sparse(model.factorization.L)
```

This enables the user to modify any of the vectors ``\mathbf {P}``, ``\mathbf{P_\text{tr}}``, and ``\mathbf{P}_\text{sh}`` and reuse the factorization. This approach is more efficient compared to solving the system of equations from the beginning, as it saves computation time.

To acquire the bus voltage angles, the user must invoke the function:
```@example PowerFlowSolutionDC
solve!(system, model)
nothing # hide
```

It is important to note that the slack bus voltage angle is excluded from the vector ``\bm{\theta}`` only during the computation step. As a analysis, the corresponding elements in the vectors ``\mathbf {P}``, ``\mathbf{P_\text{tr}}``, ``\mathbf{P}_\text{sh}``, and the corresponding row and column of the matrix ``\mathbf{B}`` are removed. It is worth mentioning that this process is handled internally, and the stored elements remain unchanged.

Finally, the resulting bus voltage angles are saved in the vector as follows:
```@repl PowerFlowSolutionDC
𝛉 = model.voltage.angle
```

---

## [Power Analysis](@id DCPowerAnalysisTutorials)
After obtaining the solution from the DC power flow, we can calculate powers related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::DCAnalysis)) function:
```@example PowerFlowSolutionDC
power!(system, model)
nothing # hide
```

---

##### Active Power Injections
To obtain the active power injections at each bus ``i \in \mathcal{N}``, we can refer to section [DC Model](@ref DCModelTutorials), which provides the following expression:
```math
   P_i = \sum_{j = 1}^n {B}_{ij} \theta_j + P_{\text{tr}i} + P_{\text{sh}i},\;\;\; i \in \mathcal{N}.
```
Active power injections are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl PowerFlowSolutionDC
𝐏 = model.power.injection.active
```

---

##### Active Power Injections From the Generators
The active power supplied by generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\text{s}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The vector of active power injected by generators to the buses, denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, can be obtained using the following command:
```@repl PowerFlowSolutionDC
𝐏ₛ = model.power.supply.active
```

---

##### Active Power Flows
The active power flows at each "from" bus end ``i \in \mathcal{N}`` of the branch can be obtained using the following equations:
```math
    P_{ij} = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using the following command:
```@repl PowerFlowSolutionDC
𝐏ᵢ = model.power.from.active
```

Similarly, the active power flows at each "to" bus end ``j \in \mathcal{N}`` of the branch can be obtained as:
```math
    P_{ji} = - P_{ij},\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using the following command:
```@repl PowerFlowSolutionDC
𝐏ⱼ = model.power.to.active
```

---

##### Generator Output Active Powers
The output active power of each generator located at bus ``i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{pq}}`` is equal to the active power specified in the input data. If there are multiple generators, their output active powers are also equal to the active powers specified in the input data. However, the output active power of a generator located at the slack bus is determined as:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators. Therefore, to get the vector of output active power of generators, i.e., ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, you can use the following command:
```@repl PowerFlowSolutionDC
𝐏ₒ = model.power.generator.active
```