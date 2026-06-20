# [DC Power Flow](@id DCPowerFlowTutorials)
JuliaGrid employs standard network components and the [Unified Branch Model](@ref UnifiedBranchModelTutorials) to obtain the DC power flow solution. To begin, let us generate the `PowerSystem` type, as illustrated by the following example:
```@example PowerFlowSolutionDC
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide
@config(label = Integer)
@power(MW, MVAr)
@voltage(pu, deg)

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
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal G = (\mathcal N, \mathcal E)``, where we have the set of buses ``\mathcal N = \{1, \dots, n\}``, and the set of branches ``\mathcal E \subseteq \mathcal N \times \mathcal N`` within the power system:
```@repl PowerFlowSolutionDC
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf a``, we use the notation ``\mathbf a = [a_{i}]`` or ``\mathbf a = [a_{ij}]``, where ``a_i`` represents the element associated with bus ``i \in \mathcal N``, and ``a_{ij}`` represents the element associated with branch ``(i,j) \in \mathcal E``.

---

## Bus Types
In the context of [Bus Types](@ref BusTypesTutorials), demand and generator buses are treated identically in the DC power flow model. The only bus type that matters is the slack bus, whose voltage angle is known.

JuliaGrid verifies the slack bus during initialization, and its assignment can be adjusted within the [`dcPowerFlow`](@ref dcPowerFlow) function. Specifically, if a bus is labeled as the slack bus (`type = 3`) but does not have a connected in-service generator, it will be reclassified as a demand bus (`type = 1`). In that case, the first generator bus (`type = 2`) with a connected in-service generator is promoted to the slack bus (`type = 3`).

---

## [Power Flow Solution](@id DCPowerFlowSolutionTutorials)
As discussed in section [DC Model](@ref DCModelTutorials), the DC power flow problem can be represented by a set of linear equations:
```math
  \mathbf P = \mathbf B \bm \Theta + \mathbf{P}_\mathrm{tr} + \mathbf{P}_\mathrm{sh}.
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
    \bm \Theta = \mathbf{B}^{-1}(\mathbf P - \mathbf{P}_\mathrm{tr} - \mathbf{P}_\mathrm{sh}).
```

JuliaGrid begins the process by establishing the DC power flow framework:
```@example PowerFlowSolutionDC
analysis = dcPowerFlow(system)
nothing # hide
```

The subsequent step involves performing the LU factorization of the nodal matrix ``\mathbf B = \mathbf L \mathbf U`` and computing the bus voltage angles using:
```@example PowerFlowSolutionDC
solve!(analysis)
nothing # hide
```

!!! tip "Tip"
    By default, JuliaGrid utilizes LU factorization as the primary method to factorize the nodal matrix. The available factorization methods are LL, LDLt, LU, KLU and QR.

The factorization of the nodal matrix can be accessed using:
```@repl PowerFlowSolutionDC
𝐋 = analysis.method.factorization.L
𝐔 = analysis.method.factorization.U
```

It is important to note that the slack bus voltage angle is excluded from the vector ``\bm \Theta`` only during the computation step. Consequently, the corresponding elements in the vectors ``\mathbf P``, ``\mathbf{P}_\mathrm{tr}``, ``\mathbf{P}_\mathrm{sh}``, and the corresponding row and column of the matrix ``\mathbf B`` are removed. It is worth mentioning that this process is handled internally, and the stored elements remain unchanged.

Finally, the resulting bus voltage angles are saved in the vector as follows:
```@repl PowerFlowSolutionDC
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id DCPowerAnalysisTutorials)
After obtaining the solution from the DC power flow, we can calculate powers related to buses, branches, and generators using the [`power!`](@ref power!(::DcPowerFlow)) function:
```@example PowerFlowSolutionDC
power!(analysis)
nothing # hide
```

!!! note "Info"
    For a clear comprehension of the equations, symbols provided below, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active power injections](@ref DCBusInjectionTutorials) are stored as the vector ``\mathbf P = [P_i]``, and can be retrieved using the following commands:
```@repl PowerFlowSolutionDC
𝐏 = analysis.power.injection.active
```

---

##### Generator Power Injections
The active power supplied by generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\mathrm{p}i} = P_i + P_{\mathrm{d}i},\;\;\; i \in \mathcal{N}_\mathrm{sb},
```
where ``P_{\mathrm{d}i}`` represents the active power demanded by consumers at the slack bus. The vector of active powers injected by generators into the buses, denoted by ``\mathbf{P}_\mathrm{p} = [P_{\mathrm{p}i}]``, can be obtained using the following command:
```@repl PowerFlowSolutionDC
𝐏ₚ = analysis.power.supply.active
```

---

##### Power Flows
The resulting [from-bus active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_\mathrm{i} = [P_{ij}]``, which can be retrieved using:
```@repl PowerFlowSolutionDC
𝐏ᵢ = analysis.power.from.active
```

Similarly, the resulting [to-bus active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_\mathrm{j} = [P_{ji}]``, which can be retrieved using:
```@repl PowerFlowSolutionDC
𝐏ⱼ = analysis.power.to.active
```

---

##### Generator Power Outputs
The output active power of each generator located at a non-slack bus is equal to the active power specified in the input data. If there are multiple generators, their output active powers are also equal to the active powers specified in the input data. However, the total active power supplied by generators at the slack bus will be:
```math
    P_{\mathrm{p}i} = P_i + P_{\mathrm{d}i}, \;\;\; i \in \mathcal{N}_\mathrm{sb}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\mathrm{p}i}``. Then, this amount of power is reduced by the output active power of the other generators.

To retrieve the vector of active power outputs of generators, denoted as ``\mathbf{P}_\mathrm{g} = [P_{\mathrm{g}i}]``, ``i \in \mathcal S``, where the set ``\mathcal S`` represents the set of generators, users can utilize the following command:
```@repl PowerFlowSolutionDC
𝐏ₒ = analysis.power.generator.active
```