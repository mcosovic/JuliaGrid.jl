# [AC Power Flow](@id ACPowerFlowTutorials)
JuliaGrid uses standard network components and the [Unified Branch Model](@ref UnifiedBranchModelTutorials) for power flow analysis, allowing load profiles, generator capacities, voltage specifications, contingency analysis, and planning to be defined efficiently.

To begin, the `PowerSystem` composite type must be provided to JuliaGrid through the use of the [`powerSystem`](@ref powerSystem) function, as illustrated by the following example:
```@example PowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@power(MW, MVAr, MVA)
@voltage(pu, deg, V)

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 21.7, reactive = 12.7)
addBus!(system; label = 3, type = 1, active = 11.2, reactive = -3.0)
addBus!(system; label = 4, type = 2, conductance = 2.1, susceptance = 1.2)

addBranch!(system; from = 1, to = 2, resistance = 0.02, reactance = 0.06)
addBranch!(system; from = 1, to = 3, resistance = 0.05, reactance = 0.21)
addBranch!(system; from = 2, to = 3, resistance = 0.13, reactance = 0.26)
addBranch!(system; from = 3, to = 4, reactance = 0.17, susceptance = 0.2, conductance = 1e-4)

addGenerator!(system; bus = 1)
addGenerator!(system; bus = 3, active = 40.0, reactive = 42.4)
nothing #hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl PowerFlowSolution
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

---

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element associated with bus ``i \in \mathcal{N}``, and ``a_{ij}`` represents the element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [Nodal Network Equations](@id FlowNodalNetworkEquationsTutorials)
As previously demonstrated in the section on the [Nodal Network Equations](@ref NodalNetworkEquationsTutorials), we observe the system of equations:
```math
  \mathbf{\bar {I}} = \mathbf{Y} \mathbf{\bar {V}}.
```

The complex current injection at the bus ``i \in \mathcal{N}`` is defined as:
```math
  \bar{I}_{i} = \cfrac{S_{i}^*}{\bar{V}_{i}^*},
```
where ``\bar{V}_{i} = V_i \text{e}^{\text{j}\theta_{i}}``. Thus, for any given bus ``i \in \mathcal{N}``, we can express it as:
```math
  \cfrac{S_{i}^*}{\bar{V}_{i}^*} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```

The complex power injection denoted by ``S_i`` comprises of both the active power ``P_i`` and reactive power ``Q_i``. This relationship can be represented as follows:
```math
  \cfrac{P_i - \text{j}Q_i}{\bar{V}_{i}} = \sum_{j = 1}^n Y_{ij} \bar {V}_j.
```

With the recognition that ``Y_{ij} =  G_{ij} + \text{j}B_{ij}`` and ``\bar{V}_{j} = V_j \text{e}^{\text{j}\theta_{j}}``, and by defining ``\theta_{ij} = \theta_{i} - \theta_{j}``,  we can break down the above equation into its real and imaginary parts, resulting in two equations that describe bus ``i \in \mathcal{N}`` as follows:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})V_j\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j.
	\end{aligned}
```

As demonstrated by the above equations, the bus ``i \in \mathcal{N}`` contains four unknown variables, namely the active power injection ``{P}_{i}``, reactive power injection ``{Q}_{i}``, bus voltage magnitude ``{V}_{i}``, and bus voltage angle ``{\theta}_{i}``.

To solve these equations, it is necessary to specify two known variables. Although any two variables can be selected mathematically, the choice is determined by the devices that are connected to a particular bus. The standard options are listed in the table below, and these options are used to define the bus types [[1]](@ref PowerFlowSolutionReferenceTutorials).

| Bus Type         | Label     | Known                       | Unknown                     |
|:-----------------|----------:|----------------------------:|----------------------------:|
| Demand           | 1         | ``P_{i}``, ``Q_{i}``        | ``V_{i}``, ``{\theta_{i}}`` |
| Generator        | 2         | ``P_{i}``, ``V_{i}``        | ``Q_{i}``, ``{\theta_{i}}`` |
| Slack            | 3         | ``V_{i}``, ``{\theta_{i}}`` | ``P_{i}``, ``Q_{i}``        |

Consequently, JuliaGrid operates with sets ``\mathcal{N}_{\text{pq}}`` and ``\mathcal{N}_{\text{pv}}`` that contain demand and generator buses, respectively, and exactly one slack bus in the set ``\mathcal{N}_{\text{sb}}``. The bus types are stored in the variable:
```@repl PowerFlowSolution
system.bus.layout.type
```

It should be noted that JuliaGrid cannot handle systems with multiple slack buses. Additionally, when using functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel), the bus type can be modified as discussed in the section on [Bus Type Modification](@ref BusTypeModificationManual).

Furthermore, the active power injections ``{P}_{i}`` and reactive power injections ``{Q}_{i}`` can be expressed as:
```math
  \begin{aligned}
  	P_{i} &= P_{\text{p}i} - P_{\text{d}i} \\
    Q_{i} &= Q_{\text{p}i} - Q_{\text{d}i},
  \end{aligned}
```
where ``{P}_{\text{d}i}`` and ``{Q}_{\text{d}i}`` denote the active and reactive power demanded at the bus ``i \in \mathcal{N}``, while ``{P}_{\text{p}i}`` and ``{Q}_{\text{p}i}`` correspond to the active and reactive power produced by the generators at the bus ``i \in \mathcal{N}``.

To provide a more comprehensive understanding, it is important to note that each bus ``i \in \mathcal{N}`` has the capacity to host multiple generators. This scenario can be conceptualized by introducing the set ``\mathcal{S}_i``, which encompasses all generators connected to bus ``i \in \mathcal{N}``. With this perspective, we can calculate the values of ``{P}_{\text{p}i}`` and ``{Q}_{\text{p}i}`` as follows:
```math
  \begin{aligned}
  	P_{\text{p}i} &= \sum_{k \in \mathcal{S}_i} P_{\text{g}k}\\
    Q_{\text{p}i} &=  \sum_{k \in \mathcal{S}_i} Q_{\text{g}k},
  \end{aligned}
```
where ``P_{\text{g}k}`` and ``Q_{\text{g}k}`` represent the active and reactive power outputs of the ``k``-th generator within the set ``\mathcal{S}_i``.

As a way to summarize, the power injection vectors, represented as ``\mathbf{P} = [P_i] `` and ``\mathbf{Q} = [Q_i]`` can be computed based on the following variables and expressions:
```@repl PowerFlowSolution
𝐏 = system.bus.supply.active - system.bus.demand.active
𝐐 = system.bus.supply.reactive - system.bus.demand.reactive
```
When the active or reactive power values are positive, ``P_i > 0`` or ``Q_i > 0``, it signifies that power is being supplied into the power system from the specific bus. This indicates that the generators connected to this bus are producing more power than what the connected load is consuming. Conversely, negative values, ``P_i < 0`` or ``Q_i < 0``, indicate that the bus is drawing in active or reactive power from the power system. This suggests that the load's demand is exceeding the output from the generators.

---

## [Newton-Raphson Method](@id NewtonRaphsonMethodTutorials)
The Newton-Raphson method is commonly used in AC power flow calculations due to its quadratic rate of convergence. It provides an accurate approximation of the roots of the system of nonlinear equations:
```math
  \mathbf{f}(\mathbf{x}) = \mathbf{0}.
```
This, in turn, allows for the determination of the unknown voltage magnitudes and angles of buses, represented by the state vector ``\mathbf x = [\mathbf x_\text{a}, \mathbf x_\text{m}]^T``. The state vector comprises two components:
* ``\mathbf x_\text{a} \in \mathbb{R}^{n-1}``, which holds the bus voltage angles of demand and generator buses, represented by ``\mathbf x_\text{a} = [\theta_i]``, where ``i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``,
* ``\mathbf x_\text{m} \in \mathbb{R}^{n_{\text{pq}}}``, which holds the bus voltage magnitudes of demand buses, represented by ``\mathbf x_\text{m} = [V_i]``, where ``i \in \mathcal{N}_{\text{pq}}``, and ``n_{\text{pq}} = |\mathcal{N}_{\text{pq}}|``.

Knowing the voltage magnitudes and angles for certain types of buses is a consequence of the structure of the state vector ``\mathbf x``. Specifically, the voltage magnitude and angle at the slack bus are known, as well as the voltage magnitude at generator buses.

As detailed in the [Nodal Network Equations](@ref FlowNodalNetworkEquationsTutorials) section of this manual, the expressions for active and reactive power injection are as follows:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})V_j\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j.
	\end{aligned}
```

Using the above equations, we can define the active power injection function for demand and generator buses:
```math
  f_{P_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})V_j - {P}_{i} = 0,
  \;\;\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and the reactive power injection function for demand buses:
```math
  f_{Q_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j - {Q}_{i} = 0,
  \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
```

The active and reactive mismatches, often denoted as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``, respectively, are defined as the functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)``. The first terms on the right-hand side represent power injections at a bus, while the second term is constant and is obtained based on the active and reactive powers of the generators that supply a bus and active and reactive powers demanded by consumers at the same bus. Therefore, the Newton-Raphson method solves the system of nonlinear equations:
```math
  \mathbf{f(x)} =
  \begin{bmatrix}
    \mathbf{f}_{\text{P}}(\mathbf x) \\ \mathbf{f}_{\text{Q}}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the first ``n - 1`` equations correspond to demand and generator buses, and the last ``n_{\text{pq}}`` equations correspond to demand buses.

---

##### Initialization
To compute the voltage magnitudes and angles of buses using the Newton-Raphson method in JuliaGrid, you must first execute the [`acModel!`](@ref acModel!) function to set up the system, followed by initializing the Newton-Raphson method using the [`newtonRaphson`](@ref newtonRaphson) function. The following code snippet demonstrates this process:
```@example PowerFlowSolution
acModel!(system)
analysis = newtonRaphson(system)
nothing # hide
```
This results in the creation of the starting vectors of bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\Theta}^{(0)}``, as shown below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = analysis.voltage.magnitude
𝚯⁽⁰⁾ = analysis.voltage.angle
```
Here, we utilize a "flat start" approach in our method. It is important to keep in mind that when dealing with initial conditions in this manner, the Newton-Raphson method may encounter difficulties.

---

##### Iterative Process
To implement the Newton-Raphson method, the iterative approach based on the Taylor series expansion, JuliaGrid provides the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson}::ACPowerFlow{NewtonRaphson})) and [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) functions. These functions are utilized to carry out the Newton-Raphson method iteratively until a stopping criterion is reached, as demonstrated in the following code snippet:
```@example PowerFlowSolution
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

The [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function calculates the mismatch in active power injection for demand and generator buses and the mismatch in reactive power injection for demand buses at each iteration ``\nu = \{1, 2, \dots\}``. The equations used for these computations are:
```math
  f_{P_i}(\mathbf x^{(\nu-1)}) = {V}_{i}^{(\nu-1)}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}^{(\nu-1)}+B_{ij}\sin\theta_{ij}^{(\nu-1)}){V}_{j}^{(\nu-1)} - {P}_{i},
  \;\;\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
as well as the reactive power injection mismatch for demand buses:
```math
  f_{Q_i}(\mathbf x^{(\nu-1)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}^{(\nu-1)}-B_{ij}\cos\theta_{ij}^{(\nu-1)}){V}_{j}^{(\nu-1)} - {Q}_{i},
  \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
```
The resulting vector from these calculations is stored in the `mismatch` variable of the `ACPowerFlow` abstract type and can be accessed through the following line of code:
```@repl PowerFlowSolution
𝐟 = analysis.method.mismatch
```

In addition to computing the mismatches in active and reactive power injection, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function also returns the maximum absolute values of these mismatches. These maximum values are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``:
```math
  \max \{|f_{P_i}(\mathbf x^{(\nu-1)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
  \max \{|f_{Q_i}(\mathbf x^{(\nu-1)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \} < \epsilon.
```

Next, the function [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) computes the increments of bus voltage angle and magnitude at each iteration using:
```math
  \mathbf{\Delta} \mathbf{x}^{(\nu-1)} = -\mathbf{J}(\mathbf{x}^{(\nu-1)})^{-1} \mathbf{f}(\mathbf{x}^{(\nu-1)}),
```
where ``\mathbf{\Delta} \mathbf{x} = [\mathbf \Delta \mathbf x_\text{a}, \mathbf \Delta \mathbf x_\text{m}]^T`` consists of the vector of bus voltage angle increments ``\mathbf \Delta \mathbf x_\text{a} \in \mathbb{R}^{n-1}`` and bus voltage magnitude increments ``\mathbf \Delta \mathbf x_\text{m} \in \mathbb{R}^{n_{\text{pq}}}``, and ``\mathbf{J}(\mathbf{x}) \in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is the Jacobian matrix, ``n_{\text{u}} = n + n_{\text{pq}} - 1``.

!!! tip "Tip"
    By default, JuliaGrid uses LU factorization as the primary method for factorizing the Jacobian matrix ``\mathbf{J} = \mathbf{L}\mathbf{U}``, aiming to compute the increments. Nevertheless, users have the flexibility to opt for QR factorization as an alternative method.

These values are stored in the `ACPowerFlow` abstract type and can be accessed after each iteration:
```@repl PowerFlowSolution
𝚫𝐱 = analysis.method.increment
𝐉 = analysis.method.jacobian
𝐋 = analysis.method.factorization.L
𝐔 = analysis.method.factorization.U
```

The JuliaGrid implementation of the AC power flow follows a specific order to store the increment ``\mathbf{\Delta} \mathbf{x}`` and mismatch ``\mathbf{f(x)}`` vectors. The first ``n-1`` elements of both vectors correspond to the demand and generator buses in the same order as they appear in the input data. The first ``n-1`` elements of the increment vector ``\mathbf{\Delta} \mathbf{x}`` correspond to the voltage angle increments ``\mathbf \Delta \mathbf x_\text{a}``, while the first ``n-1`` elements of the mismatch vector ``\mathbf{f(x)}`` correspond to the mismatch in active power injections ``\mathbf{f}_{\text{P}}(\mathbf x)``.

The last ``n_{\text{pq}}`` elements of the increment ``\mathbf{\Delta} \mathbf{x}`` and mismatch ``\mathbf{f(x)}`` vectors correspond to the demand buses in the order they appear in the input data. For the increment vector ``\mathbf{\Delta} \mathbf{x}``, it matches the bus voltage magnitude increments ``\mathbf \Delta \mathbf x_\text{m}``, while for the mismatch vector ``\mathbf{f(x)}``, it matches the mismatch in reactive power injections ``\mathbf{f}_{\text{Q}}(\mathbf x)``.

These specified orders dictate the row and column order of the Jacobian matrix ``\mathbf{J}(\mathbf{x})``.

Finally, the function [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) adds the computed increment term to the previous solution to obtain a new solution:
```math
  \mathbf {x}^{(\nu)} = \mathbf {x}^{(\nu-1)} + \mathbf \Delta \mathbf {x}^{(\nu-1)}.
```
The bus voltage magnitudes ``\mathbf{V} = [V_i]`` and angles ``\bm{\Theta} = [\theta_i]`` are then updated based on the obtained solution ``\mathbf {x}``. It is important to note that only the voltage magnitudes related to demand buses and angles related to demand and generator buses are updated; not all values are updated. Therefore, the final solution obtained by JuliaGrid is stored in the following vectors:
```@repl PowerFlowSolution
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

##### Jacobian Matrix
To complete the tutorial on the Newton-Raphson method, we will now describe the Jacobian matrix and provide the equations involved in its evolution. Without loss of generality, we assume that the slack bus is the first bus, followed by the set of demand buses and the set of generator buses:
```math
  \begin{aligned}
    \mathcal{N}_{\text{sb}} &= \{ 1 \} \\
    \mathcal{N}_{\text{pq}} &= \{2, \dots, m\} \\
    \mathcal{N}_{\text{pv}} &= \{m + 1,\dots, n\},
  \end{aligned}
```
where ``\mathcal{N} = \mathcal{N}_{\text{sb}} \cup \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``. Therefore, we can express:
```math
  \begin{aligned}
    \mathbf x_\text{a} &= [\theta_2,\dots,\theta_n]^T, \;\;\;\;\;\; \mathbf \Delta \mathbf x_\text{a} = [\Delta \theta_2,\dots,\Delta \theta_n]^T \\
    \mathbf x_\text{m} &= [V_2,\dots,V_{m}]^T, \;\;\; \mathbf \Delta \mathbf x_\text{m} = [\Delta V_2,\dots,\Delta V_{m}]^T.
  \end{aligned}
```

The Jacobian matrix ``\mathbf{J(x^{(\nu)})} \in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is:
```math
  \mathbf{J(x^{(\nu)})}=
  \left[
  \begin{array}{ccc|ccc}
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}\\
  \;\vdots & \\
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}} \\[10pt]
  \hline \\
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}\\
  \;\vdots & \\
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}
  \end{array}
  \right].
```
The Jacobian matrix can be expressed using four block matrices:
```math
	\mathbf{J(x^{(\nu)})} =
  \begin{bmatrix}
    \mathbf{J_{11}(x^{(\nu)})} &\mathbf{J_{12}(x^{(\nu)})} \\ \mathbf{J_{21}(x^{(\nu)})} &
	   \mathbf{J_{22}(x^{(\nu)})}
  \end{bmatrix},
```
where diagonal elements of the Jacobian sub-matrices are defined as follows:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}^{(\nu)}\sum\limits_{j=1}^n (-G_{ij}\sin\theta_{ij}^{(\nu)}+B_{ij}\cos\theta_{ij}^{(\nu)}){V}_{j}^{(\nu)} - B_{ii}({V}_{i}^{(\nu)})^2\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{i}^{(\nu)}} &=
  \sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)}){V}_{j}^{(\nu)} + G_{ii}{V}_{i}^{(\nu)}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}^{(\nu)} \sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)}){V}_{j}^{(\nu)} - G_{ii}({V}_{i}^{(\nu)})^2\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{i}} &=
  \sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)}){V}_{j}^{(\nu)} - B_{ii}{V}_{i}^{(\nu)},
  \end{aligned}
```
while non-diagonal elements of the Jacobian sub-matrices are:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{j}} &=
  (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)}){V}_{i}^{(\nu)}{V}_{j}^{(\nu)}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{j}^{(\nu)}} &=
  (G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)}){V}_{i}^{(\nu)}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{j}} &=
  -(G_{ij}\cos\theta_{ij}^{(\nu)} + B_{ij}\sin\theta_{ij}^{(\nu)}){V}_{i}^{(\nu)}{V}_{j}^{(\nu)}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}{\mathrm\partial V_{j}} &=
  (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)}){V}_{i}^{(\nu)}.
  \end{aligned}
```

---

## [Fast Newton-Raphson Method](@id FastNewtonRaphsonMethodTutorials)
Although the fast Newton-Raphson method may converge more slowly than the traditional Newton-Raphson method, the shorter solution time for the updates often compensates for this slower convergence, resulting in a shorter overall solution time. This is particularly true for systems that are not heavily loaded, where a shorter overall solution time is almost always achieved. It is important to note that if the algorithm converges, it will converge to a correct solution [[2]](@ref PowerFlowSolutionReferenceTutorials).

The fast Newton-Raphson method involves decoupling the power flow equations. Namely, the Newton-Raphson method is based on the equations:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x)} &\mathbf{J_{12}(x)} \\ \mathbf{J_{21}(x)} &
	   \mathbf{J_{22}(x)}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf \Delta \mathbf x_\text{a} \\ \mathbf \Delta \mathbf x_\text{m}
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{\text{P}}(\mathbf x) \\ \mathbf{f}_{\text{Q}}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the iteration index has been omitted for simplicity. However, in transmission grids, there exists a strong coupling between active powers and voltage angles, as well as between reactive powers and voltage magnitudes. To achieve decoupling, two conditions must be satisfied: first, the resistance values ``r_{ij}`` of the branches must be small compared to their reactance values ``x_{ij}``, and second, the angle differences must be small, i.e., ``\theta_{ij} \approx 0`` [[3]](@ref PowerFlowSolutionReferenceTutorials). Therefore, starting from the above equation, we have:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x)} & \mathbf{0} \\ \mathbf{0} & \mathbf{J_{22}(x)}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf \Delta \mathbf x_\text{a} \\ \mathbf \Delta \mathbf x_\text{m}
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{\text{P}}(\mathbf x) \\ \mathbf{f}_{\text{Q}}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
which gives the decoupled system as follows:
```math
  \begin{aligned}
    \mathbf{f}_{\text{P}}(\mathbf x) &= -\mathbf{J_{11}(x)} \mathbf \Delta \mathbf x_\text{a} \\
    \mathbf{f}_{\text{Q}}(\mathbf x) &= -\mathbf{J_{22}(x)} \mathbf \Delta \mathbf x_\text{m}.
  \end{aligned}
```

To examine the problem, it is helpful to express it as:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= -\Delta \theta_2\cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x)}} {\mathrm \partial \theta_2} - \cdots -
    \Delta \theta_n \cfrac{\mathrm \partial{{f_{P_2}}(\mathbf x)}}{\mathrm \partial \theta_{n}} \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= -\Delta \theta_2\cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x)}} {\mathrm \partial \theta_2} - \cdots -
    \Delta \theta_n \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}{\mathrm \partial \theta_{n}}\\
    {f}_{Q_2}(\mathbf x) &= - \Delta V_2 \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
    \Delta V_{n_{\text{pq}}} \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{m}}\\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= - \Delta V_2 \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
    \Delta V_{m} \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{m}}.
  \end{aligned}
```

Firstly, the second part of the expressions is expanded as follows:
```math
  \begin{aligned}
  {f}_{Q_2}(\mathbf x) &=
  -\cfrac{\Delta V_2}{V_2}V_2 \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
  \cfrac{\Delta V_{m}}{V_{m}} V_{m}
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{m}}\\
  & \vdots \\
  {f}_{Q_{m}}(\mathbf x) &=
  - \cfrac{\Delta V_2}{V_2}V_2 \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
  \cfrac{\Delta V_{m}}{V_{m}} V_{m}
  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{m}}.
  \end{aligned}
```

Next, the Jacobian elements are derived. To achieve this, we can use the expressions defined for the Newton-Raphson method. For demand buses, the above expansions are applied as:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}\sum\limits_{j=1}^n (-G_{ij}\sin\theta_{ij}+B_{ij}\cos\theta_{ij}){V}_{j} - B_{ii}{V}_{i}^2\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}){V}_{i}{V}_{j}\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
  V_i\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}){V}_{j} - B_{ii}{V}_{i}^2\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm\partial V_{j}} &=
   (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) V_i V_j.
  \end{aligned}
```

As the definition of reactive power is given by the equation:
```math
  {Q}_{i} ={V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j,
```
the Jacobian elements can be expressed in the following manner:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  -Q_i - B_{ii}{V}_{i}^2\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}{\mathrm \partial \theta_{j}} &=
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) V_i V_j\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm \partial V_{i}} &=
  Q_i - B_{ii} V_i^2\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm\partial V_{j}} &=
  (G_{ij}\sin\theta_{ij} - B_{ij}\cos\theta_{ij}) V_i V_j.
  \end{aligned}
```

The decoupled model is established through the following approximations:
```math
  \begin{aligned}
    \sin(\theta_{ij}) \approx 0 \\
    \cos(\theta_{ij}) \approx 1 \\
    Q_i << B_{ii}V_i^2.
  \end{aligned}
```

Thus, when the approximations are made, the Jacobian elements are simplified, resulting in the decoupled model where the Jacobian elements are:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &= -B_{ii}{V}_{i}^2\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{j}} &= -B_{ij}{V}_{i}{V}_{j}\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}} {\mathrm \partial V_{i}} &= -B_{ii}{V}_{i}^2\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm\partial V_{j}} &= -B_{ij}{V}_{i}{V}_{j}.
  \end{aligned}
```

Thus, the initial system of equations becomes:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= B_{22} \Delta \theta_2 {V}_{2}^2 + \cdots + B_{2n} \Delta \theta_n {V}_{2}{V}_{n} \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= B_{n2} \Delta \theta_2 {V}_{2}{V}_{n} + \cdots + B_{nn} \Delta \theta_n {V}_{n}^2 \\
    {f}_{Q_2}(\mathbf x) &= B_{22} \cfrac{\Delta V_2}{V_2} {V}_{2}^2 + \cdots + B_{2m} \cfrac{\Delta V_{m}}{V_{m}} {V}_{2}V_{m} \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= B_{m2} \cfrac{\Delta V_2}{V_2} {V}_{2}V_{m} + \cdots + B_{mm} \cfrac{\Delta V_{m}}{V_{m}} V_{m}^2.
  \end{aligned}
```
Using ``V_j \approx 1``, wherein ``V_i^2 = V_iV_j, j=i``, the first part of the equations can be simplified to:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= B_{22} \Delta \theta_2 {V}_{2} + \cdots + B_{2n} \Delta \theta_n {V}_{2}\\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= B_{n2} \Delta \theta_2 {V}_{n} + \cdots + B_{nn} \Delta \theta_n {V}_{n}.
  \end{aligned}
```
Similarly, the second part of the equations can be simplified to:
```math
  \begin{aligned}
    {f}_{Q_2}(\mathbf x) &= B_{22} {V}_{2} \Delta V_2 + \cdots + B_{2m} V_2 \Delta V_{m}
    \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= B_{m2} V_{m} \Delta V_2 + \cdots + B_{mm} V_{m} \Delta V_{m}.
  \end{aligned}
```

The fast Newton-Raphson method is ultimately based on the system of equations presented below:
```math
  \begin{aligned}
    \cfrac{{f}_{P_2}(\mathbf x)}{{V}_{2}} &= B_{22} \Delta \theta_2 + \cdots + B_{2n} \Delta \theta_n \\
    & \vdots \\
    \cfrac{{f}_{P_n}(\mathbf x)}{{V}_{n}} &= B_{n2} \Delta \theta_2 + \cdots + B_{nn} \Delta \theta_n \\
    \cfrac{{f}_{Q_2}(\mathbf x)}{{V}_{2}} &= B_{22} \Delta V_2 + \cdots + B_{2m} \Delta V_{m} \\
    & \vdots \\
    \cfrac{{f}_{Q_{m}}(\mathbf x)}{V_{m}} &= B_{m2} \Delta V_2 + \cdots +
    B_{mm} \Delta V_{m}.
  \end{aligned}
```
This system can be written as:
```math
  \begin{aligned}
    \mathbf{h}_{\text{P}}(\mathbf x) &= \mathbf{B}_1 \mathbf \Delta \mathbf x_\text{a} \\
    \mathbf{h}_{\text{Q}}(\mathbf x) &= \mathbf{B}_2 \mathbf \Delta \mathbf x_\text{m}.
  \end{aligned}
```
One of the main advantages of this approach is that the Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are constant and need only be formed once. Furthermore, this method can be used to define both the XB and BX versions of the fast Newton-Raphson method.

---

##### XB Version
The matrix ``\mathbf{B}_1`` is formed by neglecting the resistance ``r_{ij}``, shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}``, and transformer tap ratio magnitude ``\tau_{ij}``. The matrix ``\mathbf{B}_2`` is constructed by disregarding the transformer phase shift angle ``\phi_{ij}``. This approach corresponds to the standard fast Newton-Raphson method and is known to exhibit exceptional convergence properties in typical scenarios [[3]](@ref PowerFlowSolutionReferenceTutorials).

To initialize the XB version of the fast Newton-Raphson method, one can utilize the following code snippet:
```@example PowerFlowSolution
acModel!(system)
analysis = fastNewtonRaphsonXB(system)
nothing # hide
```

---

##### BX Version
The matrix ``\mathbf{B}_1`` ignores the shunt susceptance``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}``, and transformer tap ratio magnitude ``\tau_{ij}``. The matrix ``\mathbf{B}_2`` ignores the resistance ``r_{ij}`` and transformer phase shift angle ``\phi_{ij}``. In usual cases, the iteration count for the BX version is comparable to the XB scheme. However, for systems with high ``r_{ij}/x_{ij}`` ratios, the BX scheme requires considerably fewer iterations than the XB scheme to solve the power flow [[3]](@ref PowerFlowSolutionReferenceTutorials).

To initialize the BX version of the fast Newton-Raphson method, you can use the following code:
```@example PowerFlowSolution
acModel!(system)
analysis = fastNewtonRaphsonBX(system)
nothing # hide
```

---

##### Initialization
When a user creates the fast Newton-Raphson method in JuliaGrid, the Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are formed to correspond to the active and reactive power equations, respectively:
```@repl PowerFlowSolution
𝐁₁ = analysis.method.active.jacobian
𝐁₂ = analysis.method.reactive.jacobian
```

Additionally, during this stage, JuliaGrid generates the starting vectors for bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\Theta}^{(0)}`` as demonstrated below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = analysis.voltage.magnitude
𝚯⁽⁰⁾ = analysis.voltage.angle
```

---

##### Iterative Process
JuliaGrid offers the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) and [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) functions to implement the fast Newton-Raphson method iterations. These functions are used iteratively until a stopping criterion is met, as shown in the code snippet below:
```@example PowerFlowSolution
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

The functions ``\mathbf{f}_{\text{P}}(\mathbf x)`` and ``\mathbf{f}_{\text{Q}}(\mathbf x)`` remain free of approximations, with only the calculation of the state variable increments affected [[2]](@ref PowerFlowSolutionReferenceTutorials). As a result, we still use the following equations to compute the mismatches:
```math
  \begin{aligned}
    f_{P_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})V_j - {P}_{i} = 0,
    \;\;\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}\\
    f_{Q_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j - {Q}_{i} = 0,
    \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
  \end{aligned}
```
Therefore, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function calculates the mismatch in active power injection for demand and generator buses and the mismatch in reactive power injection for demand buses at each iteration ``\nu = \{1, 2, \dots\}``:
```math
  \begin{aligned}
    h_{P_i}(\mathbf {x}^{(\nu-1)}) &=
    \sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}^{(\nu-1)}+B_{ij}\sin\theta_{ij}^{(\nu-1)}){V}_{j}^{(\nu-1)} - \cfrac{{P}_{i}}{{V}_{i}^{(\nu-1)}},
    \;\;\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \\
    h_{Q_i}(\mathbf {x}^{(\nu-1)}) &=
    \sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}^{(\nu-1)}-B_{ij}\cos\theta_{ij}^{(\nu-1)}){V}_{j}^{(\nu-1)} - \cfrac{{Q}_{i}}{{V}_{i}^{(\nu-1)}},
    \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
  \end{aligned}
```

The resulting vectors from these calculations are stored in the `ACPowerFlow` abstract type and can be accessed through the following:
```@repl PowerFlowSolution
𝐡ₚ = analysis.method.active.increment
𝐡ₒ = analysis.method.reactive.increment
```

In addition to computing the mismatches in active and reactive power injection, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function also returns the maximum absolute values of these mismatches. These maximum values are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``:
```math
  \max \{|h_{P_i}(\mathbf x^{(\nu)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
  \max \{|h_{Q_i}(\mathbf x^{(\nu)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \} < \epsilon.
```

Next, the function [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) computes the bus voltage angle increments:
```math
  \mathbf \Delta \mathbf x_\text{a}^{(\nu-1)} = \mathbf{B}_1^{-1} \mathbf{h}_{\text{P}}(\mathbf x^{(\nu-1)}).
```

To obtain the voltage angle increments, JuliaGrid initially performs LU factorization on the Jacobian matrix ``\mathbf{B}_1 = \mathbf{L}_1\mathbf{U}_1``. This factorization is executed only once and is utilized in each iteration of the algorithm:
```@repl PowerFlowSolution
𝐋₁ = analysis.method.active.factorization.L
𝐔₁ = analysis.method.active.factorization.U
```

!!! tip "Tip"
    By default, JuliaGrid uses LU factorization as the primary method for factorizing Jacobian matrix. Nevertheless, users have the flexibility to opt for QR factorization as an alternative method.


The vector of increments that corresponds to the active power equations can be accessed using:
```@repl PowerFlowSolution
𝚫𝐱ₐ = analysis.method.active.increment
```

The solution is then updated as follows:
```math
  \mathbf x_\text{a}^{(\nu)} = \mathbf x_\text{a}^{(\nu-1)} + \mathbf \Delta \mathbf x_\text{a}^{(\nu-1)}.
```
It is important to note that only the voltage angles related to demand and generator buses are updated, while the vector of bus voltage angles of all buses is stored:
```@repl PowerFlowSolution
𝚯 = analysis.voltage.angle
```

The fast Newton-Raphson method then solves the equation:
```math
  \mathbf \Delta \mathbf x_\text{m}^{(\nu-1)} = \mathbf{B}_2^{-1} \mathbf{h}_{\text{Q}}(\mathbf x^{(\nu)}).
```

Similarly to the previous instance, JuliaGrid initially executes LU factorization on the Jacobian matrix ``\mathbf{B}_2 = \mathbf{L}_2\mathbf{U}_2``. However, it provides the flexibility for users to opt for QR factorization instead. This factorization occurs only once and is utilized in each iteration of the fast Newton-Raphson algorithm:
```@repl PowerFlowSolution
𝐋₂ = analysis.method.reactive.factorization.L
𝐔₂ = analysis.method.reactive.factorization.U
```

The vector of increments that corresponds to the reactive power equations can be accessed using:
```@repl PowerFlowSolution
𝚫𝐱ₘ = analysis.method.active.increment
```

Finally, the solution is updated as follows:
```math
  \mathbf x_\text{m}^{(\nu)} = \mathbf x_\text{m}^{(\nu-1)} + \mathbf \Delta \mathbf x_\text{m}^{(\nu-1)}.
```
Again, it is important to note that only the the voltage magnitudes of demand buses are updated, while the vector of bus voltage magnitude for all buses is stored:
```@repl PowerFlowSolution
𝐕 = analysis.voltage.magnitude
```

---

## [Gauss-Seidel Method](@id GaussSeidelMethodTutorials)
As elaborated in the [Nodal Network Equations](@ref FlowNodalNetworkEquationsTutorials) section of this manual, each bus is associated with the balance equation expressed as:
```math
  \sum_{j = 1}^n Y_{ij} \bar {V}_j = \cfrac{P_i - \text{j}Q_i}{\bar{V}_{i}}, \;\;\; \forall i \in \mathcal{N}.
```
In its expanded form, this can be written as:
```math
  \begin{aligned}
    Y_{11} & \bar{V}_{1} + \cdots+ Y_{1n}\bar{V}_{n} = \frac{{P}_{1} - j{Q}_{1}}{\bar{V}_{1}^*} \\
    \; \vdots & \\
    Y_{n1} & \bar{V}_{1} + \cdots+ Y_{nn}\bar{V}_{n} = \frac{{P}_{n} - j{Q}_{n}}{\bar{V}_{n}^*}.
	\end{aligned}
```

While the Gauss-Seidel method directly solves the system of equations, it suffers from very slow convergence, which increases almost linearly with the system size, necessitating numerous iterations to obtain the desired solution [[4]](@ref PowerFlowSolutionReferenceTutorials). Moreover, the convergence time of the Gauss-Seidel method increases significantly for large-scale systems and can face convergence issues for systems with high active power transfers. Nevertheless, power flow programs utilize both the Gauss-Seidel and Newton-Raphson methods in a complementary manner. Specifically, the Gauss-Seidel method is employed to obtain a quick approximate solution from a "flat start", while the Newton-Raphson method is utilized to obtain the final accurate solution [[5]](@ref PowerFlowSolutionReferenceTutorials).

The Gauss-Seidel method is usually applied to a system of ``n`` complex equations, where one represents the slack bus. Consequently, one equation can be eliminated, resulting in a power flow problem with ``n-1`` equations.

---

##### Initialization
JuliaGrid provides a way to utilize the Gauss-Seidel method for solving the AC power flow problem and determining the magnitudes and angles of bus voltages. To use this method, we need to execute the [`acModel!`](@ref acModel!) function first to set up the system and then initialize the Gauss-Seidel method using the [`gaussSeidel`](@ref gaussSeidel) function. The code snippet below demonstrates this process:
```@example PowerFlowSolution
acModel!(system)
analysis = gaussSeidel(system)
nothing # hide
```

This results in the creation of the starting vectors of bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\Theta}^{(0)}``, as shown below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = analysis.voltage.magnitude
𝚯⁽⁰⁾ = analysis.voltage.angle
```

---

##### Iterative Process
JuliaGrid offers the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) and [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) functions to implement the Gauss-Seidel method iterations. These functions are used iteratively until a stopping criterion is met, as shown in the code snippet below:
```@example PowerFlowSolution
for iteration = 1:300
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

In contrast to the Newton-Raphson and fast Newton-Raphson methods, the Gauss-Seidel method does not require the calculation of the mismatch in active and reactive power injection at each iteration. Instead, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function is used solely to verify the convergence criteria. At each iteration ``\nu = \{1, 2, \dots\}``, we calculate the active power injection mismatch for demand and generator buses, as shown below:
```math
  {f}_{P_i}(\mathbf x^{(\nu-1)}) = \Re\{\bar{V}_i^{(\nu - 1)} \bar{I}_i^{*(\nu - 1)}\} - P_i, \;\;\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}.
```
We also compute the reactive power injection mismatch for demand buses, given by:
```math
  {f}_{Q_i}(\mathbf x^{(\nu-1)}) = \Im\{\bar{V}_i^{(\nu - 1)} \bar{I}_i^{*(\nu - 1)}\} - Q_i, \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
```

However, these mismatches are not stored as they are only used to obtain the maximum absolute values of these mismatches. The maximum values of these mismatches are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``, as shown below:
```math
  \max \{|{f}_{P_i}(\mathbf x^{(\nu-1)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
  \max \{|{f}_{Q_i}(\mathbf x^{(\nu-1)})|,\; \forall i \in \mathcal{N}_{\text{pq}} \} < \epsilon.
```

After initializing complex bus voltages ``\bar{V}_i^{(0)}`` for all buses in the power system, the function [`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) proceeds to compute the voltages for demand buses using the Gauss-Seidel method:
```math
  \bar{V}_{i}^{(\nu)} =
  \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^{*(\nu-1)}} -
  \sum\limits_{\substack{j = 1}}^{i - 1} {Y}_{ij}\bar{V}_{j}^{(\nu)} -
  \sum\limits_{\substack{j = i + 1}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu-1)}\Bigg),
  \;\;\; \forall i \in \mathcal{N}_{\text{pq}}.
```
The next step is to determine the solution for generator buses in two stages: first, the reactive power injection is calculated, and then the bus complex voltage is updated using the following equations:
```math
  \begin{aligned}
    Q_i^{(\nu)} &=
    -\Im \left\{ \bar{V}_{i}^{*(\nu)} \sum\limits_{j=1}^n {Y}_{ij}\bar{V}_{j}^{(\nu)}\right\}, \;\;\; \forall i \in \mathcal{N}_{\text{pv}} \\
    \bar{V}_{i}^{(\nu )} &:=
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}^{(\nu)}}{\bar{V}_{i}^{*(\nu )}}-
    \sum\limits_{\substack{j = 1,\;j \neq i}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu)} \Bigg), \;\;\; \forall i \in \mathcal{N}_{\text{pv}}.
  \end{aligned}
```
The obtained voltage magnitude may not be equal to the magnitude specified for the generator bus, so a voltage correction step is necessary:
```math
  \bar{V}_{i}^{(\nu)} := {V}_{i}^{(0)} \cfrac{\bar{V}_{i}^{(\nu)}}{{V}_{i}^{(\nu)}}, \;\;\; \forall i \in \mathcal{N}_{\text{pv}}.
```

JuliaGrid stores the final results in vectors that contain all bus voltage magnitudes and angles:
```@repl PowerFlowSolution
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id ACPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of powers associated with buses, branches, and generators. Here is an example code snippet demonstrating its usage:
```@example PowerFlowSolution
power!(system, analysis)
nothing # hide
```

The function stores the computed powers in the rectangular coordinate system. It calculates the following powers related to buses, branches, and generators:

| Bus                                                         | Active                                          | Reactive                                        |
|:------------------------------------------------------------|:------------------------------------------------|:------------------------------------------------|
| [Injections](@ref BusInjectionsTutorials)                   | ``\mathbf{P} = [P_i]``                          | ``\mathbf{Q} = [Q_i]``                          |
| [Generator injections](@ref GeneratorPowerInjectionsManual) | ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``     | ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``     |
| [Shunt elements](@ref BusShuntElementTutorials)             | ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` | ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]`` |


| Branch                                                     | Active                                       | Reactive                                     |
|:-----------------------------------------------------------|:---------------------------------------------|:---------------------------------------------|
| [From-bus end flows](@ref BranchNetworkEquationsTutorials) | ``\mathbf{P}_{\text{i}} = [P_{ij}]``         | ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``         |
| [To-bus end flows](@ref BranchNetworkEquationsTutorials)   | ``\mathbf{P}_{\text{j}} = [P_{ji}]``         | ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``         |
| [Shunt elements](@ref BranchShuntElementsTutorials)        | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` |
| [Series elements](@ref BranchSeriesElementTutorials)       | ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` | ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]`` |

| Generator                                   | Active                                       | Reactive                                     |
|:--------------------------------------------|:---------------------------------------------|:---------------------------------------------|
| [Outputs](@ref GeneratorPowerOutputsManual) | ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``  | ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``  |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active and reactive power injections](@ref BusInjectionsTutorials) are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl PowerFlowSolution
𝐏 = analysis.power.injection.active
𝐐 = analysis.power.injection.reactive
```

----

##### [Generator Power Injections](@id GeneratorPowerInjectionsManual)
The [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function in JuliaGrid also computes the active and reactive power injections from the generators at each bus. The active power supplied by the generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
  P_{\text{p}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The active power injections from the generators at each bus are stored as the vector, denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, can be obtained using:
```@repl PowerFlowSolution
𝐏ₚ = analysis.power.supply.active
```

The calculation of reactive power injection from the generators at generator or slack buses can be achieved using the subsequent equation:
```math
  Q_{\text{p}i} = Q_i + Q_{\text{d}i},\;\;\; \forall i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{sb}},
```
where ``Q_{\text{d}i}`` represents the reactive power demanded by consumers at the corresponding bus. Further, the reactive power injected by the generators at buses from ``\mathcal{N}_{\text{pq}}`` can be calculated by summing the given generator reactive powers in the input data. The vector of these reactive power injections by the generators to the buses, denoted by ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``, can be retrieved using the following command:
```@repl PowerFlowSolution
𝐐ₚ = analysis.power.supply.reactive
```

---

##### Power at Bus Shunt Elements
[Active and reactive powers](@ref BusShuntElementTutorials) associated with the shunt elements at each bus are represented by the vectors ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` and ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl PowerFlowSolution
𝐏ₛₕ = analysis.power.shunt.active
𝐐ₛₕ = analysis.power.shunt.reactive
```

---

##### Power Flows
The resulting [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at each from-bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}],`` respectively, and can be retrieved using the following commands:
```@repl PowerFlowSolution
𝐏ᵢ = analysis.power.from.active
𝐐ᵢ = analysis.power.from.reactive
```

The vectors of [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at the to-bus end are stored as ``\mathbf{P}_{\text{j}} = [P_{ji}]`` and ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl PowerFlowSolution
𝐏ⱼ = analysis.power.to.active
𝐐ⱼ = analysis.power.to.reactive
```

---

##### Power at Branch Shunt Elements
[Active and reactive powers](@ref BranchShuntElementsTutorials) associated with the branch shunt elements at each branch are represented by the vectors ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` and ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}ij}]``. We can retrieve these values using the following code:
```@repl PowerFlowSolution
𝐏ₛ = analysis.power.charging.active
𝐐ₛ = analysis.power.charging.reactive
```

---

##### Power at Branch Series Elements
[Active and reactive powers](@ref BranchSeriesElementTutorials) associated with the branch series element at each branch are represented by the vectors ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``. We can retrieve these values using the following code:
```@repl PowerFlowSolution
𝐏ₗ = analysis.power.series.active
𝐐ₗ = analysis.power.series.reactive
```

---

##### [Generator Power Outputs](@id GeneratorPowerOutputsManual)
To obtain the output active powers of each generator connected to bus ``i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``, the given active power in the input data is utilized. For the generator connected to the slack bus, the output active power is determined using the equation:
```math
  P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators.

To retrieve the vector of active power outputs of generators, denoted as ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, ``i \in \mathcal{S}``, where the set ``\mathcal{S}`` represents the set of generators, users can utilize the following command:
```@repl PowerFlowSolution
𝐏ₒ = analysis.power.generator.active
```

The output reactive powers of each generator located at the bus is obtained as:
```math
  Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}.
```
If there are multiple generators at the same bus, the reactive power is allocated proportionally among the generators based on their reactive power capabilities.

To retrieve the vector of reactive power outputs of generators, denoted as ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``, ``i \in \mathcal{S}``, users can utilize:
```@repl PowerFlowSolution
𝐐ₒ = analysis.power.generator.reactive
```

---

## [Current Analysis](@id ACCurrentAnalysisTutorials)
JuliaGrid offers the [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example PowerFlowSolution
current!(system, analysis)
nothing # hide
```

The function stores the computed currents in the polar coordinate system. It calculates the following currents related to buses and branches:

| Bus                                       | Magnitude              | Angle                    |
|:------------------------------------------|:-----------------------|:-------------------------|
| [Injections](@ref BusInjectionsTutorials) | ``\mathbf{I} = [I_i]`` | ``\bm{\psi} = [\psi_i]`` |

| Branch                                                     | Magnitude                                    | Angle                                          |
|:-----------------------------------------------------------|:---------------------------------------------|:-----------------------------------------------|
| [From-bus end flows](@ref BranchNetworkEquationsTutorials) | ``\mathbf{I}_{\text{i}} = [I_{ij}]``         | ``\bm{\psi}_{\text{i}} = [\psi_{ij}]``         |
| [To-bus end flows](@ref BranchNetworkEquationsTutorials)   | ``\mathbf{I}_{\text{j}} = [I_{ji}]``         | ``\bm{\psi}_{\text{j}} = [\psi_{ji}]``         |
| [Series elements](@ref BranchSeriesElementTutorials)       | ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` | ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Current Injections
In JuliaGrid, [complex current injections](@ref BusInjectionsTutorials) are stored in the vector of magnitudes denoted as ``\mathbf{I} = [I_i]`` and the vector of angles represented as ``\bm{\psi} = [\psi_i]``. You can retrieve them using the following commands:
```@repl PowerFlowSolution
𝐈 = analysis.current.injection.magnitude
𝛙 = analysis.current.injection.angle
```

---

##### Current Flows
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting [complex current flows](@ref BranchNetworkEquationsTutorials), you can use the following commands:
```@repl PowerFlowSolution
𝐈ᵢ = analysis.current.from.magnitude
𝛙ᵢ = analysis.current.from.angle
```

Similarly, we can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting c[omplex current flows](@ref BranchNetworkEquationsTutorials) using the following code:
```@repl PowerFlowSolution
𝐈ⱼ = analysis.current.to.magnitude
𝛙ⱼ = analysis.current.to.angle
```

---

##### Current at Branch Series Elements
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` and angles ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` of the resulting [complex current flows](@ref BranchSeriesElementTutorials), one can use the following code:
```@repl PowerFlowSolution
𝐈ₗ = analysis.current.series.magnitude
𝛙ₗ = analysis.current.series.angle
```

---

## [References](@id PowerFlowSolutionReferenceTutorials)
[1] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, Wiley, 1996.

[2] G. Andersson, *Modelling and analysis of electric power systems*, EEH-Power Systems Laboratory, Swiss Federal Institute of Technology (ETH), Zürich, Switzerland (2008).

[3] R. A. M. van Amerongen, "A general-purpose version of the fast decoupled load flow," *IEEE Trans. Power Syst.*, vol. 4, no. 2, pp. 760-770, May 1989.

[4] D. P. Chassin, P. R. Armstrong, D. G. Chavarria-Miranda, and R. T. Guttromson, "Gauss-seidel accelerated: implementing flow solvers on field programmable gate arrays," *in Proc. IEEE PES General Meeting*, 2006, pp. 5.

[5] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.

