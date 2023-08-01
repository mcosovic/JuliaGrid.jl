# [AC Power Flow](@id ACPowerFlowTutorials)

JuliaGrid utilizes standard network components and leverages the [unified branch model](@ref UnifiedBranchModelTutorials) to perform power flow analysis, enabling the definition of load profiles, generator capacities, voltage specifications, contingency analysis, and planning.

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
addBranch!(system; from = 3, to = 4, reactance = 0.17, susceptance = 0.2)

addGenerator!(system; bus = 1)
addGenerator!(system; bus = 3, active = 40.0, reactive = 42.4)
nothing #hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl PowerFlowSolution
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` denotes the generic element associated with bus ``i \in \mathcal{N}``, and ``a_{ij}`` denotes the generic element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [Bus Types and Power Injections](@id BusTypesPowerInjectionsTutorials)
As previously demonstrated in the section on the [AC Model](@ref ACModelTutorials), we can express the network as the system of equations:
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
As demonstrated by the above equation, the bus ``i \in \mathcal{N}`` contains four unknown variables, namely the active power injection ``{P}_{i}``, reactive power injection ``{Q}_{i}``, bus voltage magnitude ``{V}_{i}``, and bus voltage angle ``{\theta}_{i}``. To solve the system of equations, two variables must be specified for each equation. Although any two variables can be selected mathematically, the choice is determined by the devices that are connected to a particular bus. The standard options are listed in the table below, and these options are used to define the bus types [[1]](@ref PowerFlowSolutionReferenceTutorials).

| Bus Type         | Label            | JuliaGrid | Known                       | Unknown                     |
|:-----------------|-----------------:|----------:|----------------------------:|----------------------------:|
| Demand           | PQ               | 1         | ``P_{i}``, ``Q_{i}``        | ``V_{i}``, ``{\theta_{i}}`` |
| Generator        | PV               | 2         | ``P_{i}``, ``V_{i}``        | ``Q_{i}``, ``{\theta_{i}}`` |
| Slack            | ``V \theta``     | 3         | ``V_{i}``, ``{\theta_{i}}`` | ``P_{i}``, ``Q_{i}``        |

Consequently, JuliaGrid operates with sets ``\mathcal{N}_{\text{pq}}`` and ``\mathcal{N}_{\text{pv}}`` that contain demand and generator buses, respectively, and exactly one slack bus in the set ``\mathcal{N}_{\text{sb}}``. The bus types are stored in the variable:
```@repl PowerFlowSolution
system.bus.layout.type
```

It should be noted that JuliaGrid cannot handle systems with multiple slack buses. Additionally, when using functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel), the bus type can be modified as discussed in the section on [Bus Type Modification](@ref BusTypeModificationManual).

Furthermore, the active power injections ``{P}_{i}`` and reactive power injections ``{Q}_{i}`` can be expressed as:
```math
  \begin{aligned}
  	P_{i} &= P_{\text{s}i} - P_{\text{d}i} \\
    Q_{i} &= Q_{\text{s}i} - Q_{\text{d}i},
  \end{aligned}
```
where ``{P}_{\text{s}i}`` and ``{Q}_{\text{s}i}`` correspond to the active and reactive power injected by the generators at the bus ``i \in \mathcal{N}``, while ``{P}_{\text{d}i}`` and ``{Q}_{\text{d}i}`` denote the active and reactive power demanded at the bus ``i \in \mathcal{N}``. We can calculate the vectors ``\mathbf{P} = [P_i] `` and ``\mathbf{Q} = [Q_i]`` using the following code:
```@repl PowerFlowSolution
𝐏 = system.bus.supply.active - system.bus.demand.active
𝐐 = system.bus.supply.reactive - system.bus.demand.reactive
```

---

## [Newton-Raphson Method](@id NewtonRaphsonMethodTutorials)
The Newton-Raphson method is commonly used in AC power flow calculations due to its quadratic rate of convergence. It provides an accurate approximation of the roots of the system of nonlinear equations:
```math
  \mathbf{f}(\mathbf{x}) = \mathbf{0}.
```
This, in turn, allows for the determination of the unknown voltage magnitudes and angles of buses, represented by the state vector ``\mathbf x = [\mathbf x_a, \mathbf x_m]^T``. The state vector comprises two components:
* ``\mathbf x_a \in \mathbb{R}^{n-1}``, which holds the bus voltage angles of demand and generator buses, represented by ``\mathbf x_a = [\theta_i]``, where ``i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``;
* ``\mathbf x_m \in \mathbb{R}^{n_{\text{pq}}}``, which holds the bus voltage magnitudes of demand buses, represented by ``\mathbf x_m = [V_i]``, where ``i \in \mathcal{N}_{\text{pq}}``, and ``n_{\text{pq}} = |\mathcal{N}_{\text{pq}}|``.

Knowing the voltage magnitudes and angles for certain types of buses is a consequence of the structure of the state vector ``\mathbf x``. Specifically, the voltage magnitude and angle at the slack bus are known, as well as the voltage magnitude at generator buses.

The complex power injection ``S_i`` at a bus ``i \in \mathcal{N}`` is a function of the complex bus voltages. Therefore, the active and reactive power injection expressions can be defined based on the real and imaginary components of the complex power as follows:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})\\
    {Q}_{i} &={V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}).
	\end{aligned}
```
Using the above equations, we can define the active power injection function for demand and generator buses as follows:
```math
    f_{P_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and the reactive power injection function for demand buses as follows:
```math
    f_{Q_i}(\mathbf x) = {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```

The active and reactive mismatches, often denoted as ``\Delta P_i(\mathbf x)`` and ``\Delta Q_i(\mathbf x)``, respectively, are defined as the functions ``f_{P_i}(\mathbf x)`` and ``f_{Q_i}(\mathbf x)``. The first terms on the right-hand side represent power injections at a bus, while the second term is constant and is obtained based on the active and reactive powers of the generators that supply a bus and active and reactive powers demanded by consumers at the same bus. Therefore, the Newton-Raphson method solves the system of nonlinear equations:
```math
  \mathbf{f(x)} =
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the first ``n - 1`` equations correspond to demand and generator buses, and the last ``n_{\text{pq}}`` equations correspond to demand buses.

---

##### Initialization
To compute the voltage magnitudes and angles of buses using the Newton-Raphson method in JuliaGrid, you must first execute the [`acModel!`](@ref acModel!) function to set up the system, followed by initializing the Newton-Raphson method using the [`newtonRaphson`](@ref newtonRaphson) function. The following code snippet demonstrates this process:
```@example PowerFlowSolution
acModel!(system)
model = newtonRaphson(system)
nothing # hide
```
This results in the creation of the starting vectors of bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\theta}^{(0)}``, as shown below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = model.voltage.magnitude
𝛉⁽⁰⁾ = model.voltage.angle
```
Here, we utilize a "flat start" approach in our method. It is important to keep in mind that when dealing with initial conditions in this manner, the Newton-Raphson method may encounter difficulties.

---

##### Iterative Process
To implement the Newton-Raphson method, the iterative approach based on the Taylor series expansion, JuliaGrid provides the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) functions. These functions are utilized to carry out the Newton-Raphson method iteratively until a stopping criterion is reached, as demonstrated in the following code snippet:
```@example PowerFlowSolution
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```

The [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function calculates the mismatch in active power injection for demand and generator buses and the mismatch in reactive power injection for demand buses at each iteration ``\nu = \{1, 2, \dots\}``. The equations used for these computations are:
```math
  f_{P_i}(\mathbf x^{(\nu-1)}) = {V}_{i}^{(\nu-1)}\sum\limits_{j=1}^n {V}_{j}^{(\nu-1)}(G_{ij}\cos\theta_{ij}^{(\nu-1)}+B_{ij}\sin\theta_{ij}^{(\nu-1)}) - {P}_{i},
  \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
as well as the reactive power injection mismatch for demand buses:
```math
    f_{Q_i}(\mathbf x^{(\nu-1)}) = {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu-1)}(G_{ij}\sin\theta_{ij}^{(\nu-1)}-B_{ij}\cos\theta_{ij}^{(\nu-1)}) - {Q}_{i},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The resulting vector from these calculations is stored in the `mismatch` variable of the `Model` composite type and can be accessed through the following line of code:
```@repl PowerFlowSolution
𝐟 = model.mismatch
```

In addition to computing the mismatches in active and reactive power injection, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function also returns the maximum absolute values of these mismatches. These maximum values are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``:
```math
    \max \{|f_{P_i}(\mathbf x^{(\nu-1)})|,\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|f_{Q_i}(\mathbf x^{(\nu-1)})|,\; i \in \mathcal{N}_{\text{pq}} \} < \epsilon.
```

Next, the function [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) computes the increments of bus voltage angle and magnitude at each iteration using the equation:
```math
  \mathbf{\Delta} \mathbf{x}^{(\nu-1)} = -\mathbf{J}(\mathbf{x}^{(\nu-1)})^{-1} \mathbf{f}(\mathbf{x}^{(\nu-1)}),
```
where ``\mathbf{\Delta} \mathbf{x} = [\mathbf \Delta \mathbf x_a, \mathbf \Delta \mathbf x_m]^T`` consists of the vector of bus voltage angle increments ``\mathbf \Delta \mathbf x_a \in \mathbb{R}^{n-1}`` and bus voltage magnitude increments ``\mathbf \Delta \mathbf x_m \in \mathbb{R}^{n_{\text{pq}}}``, and ``\mathbf{J}(\mathbf{x}) \in \mathbb{R}^{n_{\text{u}} \times n_{\text{u}}}`` is the Jacobian matrix, ``n_{\text{u}} = n + n_{\text{pq}} - 1``.  These values are stored in the `Model` composite type and can be accessed after each iteration using the following commands:
```@repl PowerFlowSolution
𝚫𝐱 = model.increment
𝐉 = model.jacobian
```

The JuliaGrid implementation of the AC power flow follows a specific order to store the increment and mismatch vectors. The first ``n-1`` elements of both vectors correspond to the demand and generator buses in the same order as they appear in the input data. This order is not obtained by first extracting the demand and then generator buses but by excluding the slack bus in the input data. The first ``n-1`` elements of the increment vector correspond to the voltage angle increments, while the first ``n-1`` elements of the mismatch vector correspond to the mismatch in active power injections. The last ``n_{\text{pq}}`` elements of the increment and mismatch vectors correspond to the demand buses in the order they appear in the input data. For the increment vector, it matches the bus voltage magnitude increments, while for the mismatch vector, it matches the mismatch in reactive power injections. As a analysis, this order defines the row and column order of the Jacobian matrix ``\mathbf{J}(\mathbf{x})``.

Finally, the function [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) adds the computed increment term to the previous solution to obtain a new solution:
```math
  \mathbf {x}^{(\nu)} = \mathbf {x}^{(\nu-1)} + \mathbf \Delta \mathbf {x}^{(\nu-1)}.
```
The bus voltage magnitudes ``\mathbf{V} = [V_i]`` and angles ``\bm{\theta} = [\theta_i]`` are then updated based on the obtained solution ``\mathbf {x}``. It is important to note that only the voltage magnitudes related to demand buses and angles related to demand and generator buses are updated; not all values are updated. Therefore, the final solution obtained by JuliaGrid is stored in the following vectors:
```@repl PowerFlowSolution
𝐕 = model.voltage.magnitude
𝛉 = model.voltage.angle
```

----

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
    \mathbf x_a &= [\theta_2,\dots,\theta_n]^T; \;\;\;\;\;\; \mathbf \Delta \mathbf x_a = [\Delta \theta_2,\dots,\Delta \theta_n]^T \\
    \mathbf x_m &= [V_2,\dots,V_{m}]^T; \;\;\; \mathbf \Delta \mathbf x_m = [\Delta V_2,\dots,\Delta V_{m}]^T.
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
  \;\vdots  & \\
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{P_n}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}} \\[10pt]
  \hline \\
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}} {\mathrm \partial \theta_2} & \cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial \theta_{n}} &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{2}} &\cdots &
  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x^{(\nu)})}}{\mathrm \partial V_{m}}\\
  \;\vdots  & \\
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
  {V}_{i}^{(\nu)}\sum\limits_{j=1}^n {V}_{j}^{(\nu)}(-G_{ij}
  \sin\theta_{ij}^{(\nu)}+B_{ij}\cos\theta_{ij}^{(\nu)}) - ({V}_{i}^{(\nu)})^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{i}^{(\nu)}} &= \sum\limits_{
  j=1}^n {V}_{j}^{(\nu)}(G_{ij}\cos
  \theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})+{V}_{i}^{(\nu)} G_{ii}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{i}}&={V}_{i}^{(\nu)}
  \sum\limits_{j=1}^n {V}_{j}^{(\nu)}
  (G_{ij}\cos\theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})- ({V}_{i}^{(\nu)})^2G_{ii}\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{i}}&=\sum\limits_{j=1
  }^n {V}_{j}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-
  B_{ij}\cos\theta_{ij}^{(\nu)})-{V}_{i}^{(\nu)} B_{ii},
  \end{aligned}
```
while non-diagonal elements of the Jacobian sub-matrices are:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{j}}&={V}_{i}^{(\nu)}{V}_{j}^{(\nu)}
  (G_{ij}\sin\theta_{ij}^{(\nu)}-B_{ij}\cos\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial V_{j}^{(\nu)}} &= {V}_{i}^{(\nu)}(G_{ij}\cos
  \theta_{ij}^{(\nu)}+B_{ij}\sin\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}
  {\mathrm \partial \theta_{j}}&={V}_{i}^{(\nu)}{V}_{j}^{(\nu)}
  (-G_{ij}\cos\theta_{ij}^{(\nu)} -B_{ij}\sin\theta_{ij}^{(\nu)})\\
  \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x^{(\nu)})}}{\mathrm
  \partial V_{j}}&={V}_{i}^{(\nu)}(G_{ij}\sin\theta_{ij}^{(\nu)}-
  B_{ij}\cos\theta_{ij}^{(\nu)}).
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
    \mathbf \Delta \mathbf x_a \\ \mathbf \Delta \mathbf x_m
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
where the iteration index has been omitted for simplicity. However, in transmission grids, there exists a strong coupling between active powers and voltage angles, as well as between reactive powers and voltage magnitudes. To achieve decoupling, two conditions must be satisfied: first, the resistance values ``r_{ij}`` of the branches must be small compared to their reactance values ``x_{ij}``, and second, the angle differences must be small, i.e., ``\theta_{ij} \approx 0`` [[3]](@ref PowerFlowSolutionReferenceTutorials). Therefore, starting from the above equation, we have:
```math
  \begin{bmatrix}
    \mathbf{J_{11}(x)} & \mathbf{0} \\ \mathbf{0} & \mathbf{J_{22}(x)}
  \end{bmatrix}
  \begin{bmatrix}
    \mathbf \Delta \mathbf x_a \\ \mathbf \Delta \mathbf x_m
  \end{bmatrix}	+
  \begin{bmatrix}
    \mathbf{f}_{P}(\mathbf x) \\ \mathbf{f}_{Q}(\mathbf x)
  \end{bmatrix} = \mathbf 0,
```
which gives the decoupled system as follows:
```math
  \begin{aligned}
    \mathbf{f}_{P}(\mathbf x) &= -\mathbf{J_{11}(x)} \mathbf \Delta \mathbf x_a \\
    \mathbf{f}_{Q}(\mathbf x) &= -\mathbf{J_{22}(x)} \mathbf \Delta \mathbf x_m.
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
    \Delta V_{n_{\text{pq}}}  \cfrac{\mathrm \partial{{f_{Q_2}}(\mathbf x)}}{\mathrm \partial V_{m}}\\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= - \Delta V_2 \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{2}} - \cdots -
    \Delta V_{m}  \cfrac{\mathrm \partial{{f_{Q_{m}}}(\mathbf x)}}{\mathrm \partial V_{m}}.
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
Next, the Jacobian elements are derived. To achieve this, we can use the expressions defined for the Newton-Raphson method. For PQ buses, the above expansions are applied as:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  {V}_{i}\sum\limits_{j=1}^n {V}_{j}(-G_{ij}
  \sin\theta_{ij}+B_{ij}\cos\theta_{ij}) - {V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}
  {\mathrm \partial \theta_{j}}&={V}_{i}{V}_{j}
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}
  {\mathrm \partial V_{i}} &= V_i\sum\limits_{j=1
  }^n {V}_{j}(G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij})-{V}_{i}^2 B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm
  \partial V_{j}} &= {V}_{i}V_j (G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij}).
  \end{aligned}
```
As the definition of reactive power is given by the equation:
```math
    {Q}_{i} ={V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}),
```
the Jacobian elements can be expressed in the following manner:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &=
  -Q_i - {V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}}
  {\mathrm \partial \theta_{j}}&={V}_{i}{V}_{j}
  (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}
  {\mathrm \partial V_{i}} &= Q_i-{V}_{i}^2 B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm
  \partial V_{j}} &= {V}_{i}V_j (G_{ij}\sin\theta_{ij}-
  B_{ij}\cos\theta_{ij}).
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
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{i}} &= -{V}_{i}^2B_{ii}\\
  \cfrac{\mathrm \partial{{f_{P_i}}(\mathbf x)}} {\mathrm \partial \theta_{j}} &= -{V}_{i}{V}_{j}B_{ij}\\
  V_i \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}} {\mathrm \partial V_{i}} &= -{V}_{i}^2B_{ii}\\
  V_j \cfrac{\mathrm \partial{{f_{Q_i}}(\mathbf x)}}{\mathrm\partial V_{j}} &=  -{V}_{i}{V}_{j}B_{ij}.
  \end{aligned}
```
Thus, the initial system of equations becomes:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= {V}_{2}^2B_{22} \Delta \theta_2 + \cdots + {V}_{2}{V}_{n}B_{2n} \Delta \theta_n \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= {V}_{2}{V}_{n}B_{n2} \Delta \theta_2 + \cdots + {V}_{n}^2B_{nn} \Delta \theta_n \\
    {f}_{Q_2}(\mathbf x) &=  {V}_{2}^2B_{22} \cfrac{\Delta V_2}{V_2} + \cdots +
     {V}_{2}V_{m}B_{2m} \cfrac{\Delta V_{m}}{V_{m}} \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= {V}_{2}V_{m}B_{m2} \cfrac{\Delta V_2}{V_2} + \cdots +
    V_{m}^2 B_{mm} \cfrac{\Delta V_{m}}{V_{m}}.
  \end{aligned}
```
Using ``V_j \approx 1``, wherein ``V_i^2 = V_iV_j, j=i``, the first part of the equations can be simplified to:
```math
  \begin{aligned}
    {f}_{P_2}(\mathbf x) &= {V}_{2}B_{22} \Delta \theta_2 + \cdots + {V}_{2}B_{2n} \Delta \theta_n \\
    & \vdots \\
    {f}_{P_n}(\mathbf x) &= {V}_{n}B_{n2} \Delta \theta_2 + \cdots + {V}_{n}B_{nn} \Delta \theta_n.
  \end{aligned}
```
Similarly, the second part of the equations can be simplified to:
```math
  \begin{aligned}
    {f}_{Q_2}(\mathbf x) &=  {V}_{2}B_{22} \Delta V_2 + \cdots +
     V_2 B_{2m} \Delta V_{m}
    \\
    & \vdots \\
    {f}_{Q_{m}}(\mathbf x) &= V_{m}B_{m2} \Delta V_2 + \cdots +
    V_{m} B_{mm} \Delta V_{m}.
  \end{aligned}
```

The fast Newton-Raphson method is ultimately based on the system of equations presented below:
```math
  \begin{aligned}
    \cfrac{{f}_{P_2}(\mathbf x)}{{V}_{2}} &= B_{22} \Delta \theta_2 + \cdots + B_{2n} \Delta \theta_n \\
    & \vdots \\
    \cfrac{{f}_{P_n}(\mathbf x)}{{V}_{n}} &= B_{n2} \Delta \theta_2 + \cdots + B_{nn} \Delta \theta_n \\
    \cfrac{{f}_{Q_2}(\mathbf x)}{{V}_{2}} &=  B_{22} \Delta V_2 + \cdots + B_{2m} \Delta V_{m} \\
    & \vdots \\
    \cfrac{{f}_{Q_{m}}(\mathbf x)}{V_{m}} &= B_{m2} \Delta V_2 + \cdots +
    B_{mm} \Delta V_{m}.
  \end{aligned}
```
This system can be rewritten as:
```math
  \begin{aligned}
    \mathbf{h}_{P}(\mathbf x) &= \mathbf{B}_1 \mathbf \Delta \mathbf x_a \\
    \mathbf{h}_{Q}(\mathbf x) &= \mathbf{B}_2 \mathbf \Delta \mathbf x_m.
  \end{aligned}
```
One of the main advantages of this approach is that the Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` are constant and need only be formed once. Furthermore, this method can be used to define both the XB and BX versions of the fast Newton-Raphson method.

---

##### XB Version
The matrix ``\mathbf{B}_1`` is formed by neglecting the resistance ``r_{ij}``, shunt susceptance ``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}``, and transformer tap ratio magnitude``\tau_{ij}``. The matrix ``\mathbf{B}_2`` is constructed by disregarding the transformer phase shift angle ``\phi_{ij}``. This approach corresponds to the standard fast Newton-Raphson method and is known to exhibit exceptional convergence properties in typical scenarios [[3]](@ref PowerFlowSolutionReferenceTutorials).

To initialize the XB version of the fast Newton-Raphson method, one can utilize the following code snippet:
```@example PowerFlowSolution
acModel!(system)
model = fastNewtonRaphsonXB(system)
nothing # hide
```

---

##### BX Version
The matrix ``\mathbf{B}_1`` ignores the shunt susceptance``\Im \{ y_{\text{sh}i} \}``, charging susceptance ``\Im \{ y_{\text{s}ij} \}``, and transformer tap ratio magnitude ``\tau_{ij}``. The matrix ``\mathbf{B}_2`` ignores the resistance ``r_{ij}`` and transformer phase shift angle ``\phi_{ij}``. In usual cases, the iteration count for the BX version is comparable to the XB scheme. However, for systems with high ``r_{ij}/x_{ij}`` ratios, the BX scheme requires considerably fewer iterations than the XB scheme to solve the power flow [[3]](@ref PowerFlowSolutionReferenceTutorials).

To initialize the BX version of the fast Newton-Raphson method, you can use the following code:
```@example PowerFlowSolution
acModel!(system)
model = fastNewtonRaphsonBX(system)
nothing # hide
```

---

##### Initialization
One of the versions of the algorithm mentioned earlier is used to initialize the fast Newton-Raphson method. This means that the algorithm computes the Jacobian matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` that correspond to the active and reactive power equations, respectively. These matrices can be accessed using the following commands:
```@repl PowerFlowSolution
𝐁₁ = model.active.jacobian
𝐁₂ = model.reactive.jacobian
```

Next, JuliaGrid utilizes the [LU factorization](https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.lu) of matrices ``\mathbf{B}_1`` and ``\mathbf{B}_2`` to compute solutions through iterations, which can be accessed using the following commands:
```@repl PowerFlowSolution
model.active.factorization
model.reactive.factorization
```

Additionally, during this stage, JuliaGrid generates the starting vectors for bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\theta}^{(0)}`` as demonstrated below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = model.voltage.magnitude
𝛉⁽⁰⁾ = model.voltage.angle
```

---

##### Iterative Process
JuliaGrid offers the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) functions to implement the fast Newton-Raphson method iterations. These functions are used iteratively until a stopping criterion is met, as shown in the code snippet below:
```@example PowerFlowSolution
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```

The functions ``\mathbf{f}_{P}(\mathbf x)`` and ``\mathbf{f}_{Q}(\mathbf x)`` remain free of approximations, with only the calculation of the state variable increments affected [[2]](@ref PowerFlowSolutionReferenceTutorials). As a result, we still use the following equations to compute the mismatches:
```math
  \begin{aligned}
    f_{P_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - {P}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}\\
    f_{Q_i}(\mathbf x) &= {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - {Q}_{i} = 0,
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
  \end{aligned}
```
Therefore, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function calculates the mismatch in active power injection for demand and generator buses and the mismatch in reactive power injection for demand buses at each iteration ``\nu = \{1, 2, \dots\}``:
```math
  {h}_{P_i}(\mathbf {x}^{(\nu-1)}) =
  \sum\limits_{j=1}^n {V}_{j}^{(\nu-1)}(G_{ij}\cos\theta_{ij}^{(\nu-1)}+B_{ij}\sin\theta_{ij}^{(\nu-1)}) - \cfrac{{P}_{i}}{{V}_{i}^{(\nu-1)}},
  \;\;\;  i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
and in reactive power injection for PQ buses as:
```math
    {h}_{Q_i}(\mathbf {x}^{(\nu-1)}) =
    \sum\limits_{j=1}^n {V}_{j}^{(\nu-1)} (G_{ij}\sin\theta_{ij}^{(\nu-1)}-B_{ij}\cos\theta_{ij}^{(\nu-1)}) - \cfrac{{Q}_{i}}{{V}_{i}^{(\nu-1)}},
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The resulting vectors from these calculations are stored in the `Model` composite type and can be accessed through the following:
```@repl PowerFlowSolution
𝐡ₚ = model.active.increment
𝐡ₒ = model.reactive.increment
```

In addition to computing the mismatches in active and reactive power injection, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function also returns the maximum absolute values of these mismatches. These maximum values are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``:
```math
    \max \{|h_{P_i}(\mathbf x^{(\nu)})|,\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|h_{Q_i}(\mathbf x^{(\nu)})|,\; i \in \mathcal{N}_{\text{pq}} \} < \epsilon.
```

Next, the function [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) computes the bus voltage angle increments:
```math
  \mathbf \Delta \mathbf x_a^{(\nu-1)} = \mathbf{B}_1^{-1} \mathbf{h}_{P}(\mathbf x_a^{(\nu-1)}, \mathbf x_m^{(\nu-1)}).
```
The vector of increments that corresponds to the active power equations can be accessed using the following command:
```@repl PowerFlowSolution
𝚫𝐱ₐ = model.active.increment
```

The solution is then updated as follows:
```math
  \mathbf x_a^{(\nu)} = \mathbf x_a^{(\nu-1)} + \mathbf \Delta \mathbf x_a^{(\nu-1)}.
```
It is important to note that only the voltage angles related to demand and generator buses are updated, while the vector of bus voltage angles of all buses is stored:
```@repl PowerFlowSolution
𝛉 = model.voltage.angle
```

The fast Newton-Raphson method then solves the equation:
```math
   \mathbf \Delta \mathbf x_m^{(\nu-1)} = \mathbf{B}_2^{-1} \mathbf{h}_{Q}(\mathbf x_a^{(\nu)}, \mathbf x_m^{(\nu-1)}).
```
The vector of increments that corresponds to the reactive power equations can be accessed using the following command:
```@repl PowerFlowSolution
𝚫𝐱ₘ = model.active.increment
```

Finally, the solution is updated as follows:
```math
  \mathbf x_m^{(\nu)} = \mathbf x_m^{(\nu-1)} + \mathbf \Delta \mathbf x_m^{(\nu-1)}.
```
Again, it is important to note that only the the voltage magnitudes of demand buses are updated, while the vector of bus voltage magnitude for all buses is stored:
```@repl PowerFlowSolution
𝐕 = model.voltage.magnitude
```

---

## [Gauss-Seidel Method](@id gaussSeidel)
By defining the complex current injection at bus ``i \in \mathcal{N}`` as:
```math
	\bar{I}_{i} = \frac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^*},
```
the power flow problem can be represented as the system of equations:
```math
    \mathbf {\bar {I}} = \mathbf{Y} \mathbf {\bar {V}}.
```
This system of equations can be expanded to ``n`` complex equations:
```math
  \begin{aligned}
    Y_{11} & \bar{V}_{1}  + \cdots+ Y_{1n}\bar{V}_{n} = \frac{{P}_{1} - j{Q}_{1}}{\bar{V}_{1}^*} \\
    \; \vdots & \\
    Y_{n1} & \bar{V}_{1} + \cdots+ Y_{nn}\bar{V}_{n} = \frac{{P}_{n} - j{Q}_{n}}{\bar{V}_{n}^*}.
	\end{aligned}
```
While the Gauss-Seidel method directly solves the system of equations, it suffers from very slow convergence, which increases almost linearly with the system size, necessitating numerous iterations to obtain the desired solution [[4]](@ref PowerFlowSolutionReferenceTutorials). Moreover, the convergence time of the Gauss-Seidel method increases significantly for large-scale systems and can face convergence issues for systems with high active power transfers. Nevertheless, power flow programs utilize both the Gauss-Seidel and Newton-Raphson methods in a complementary manner. Specifically, the Gauss-Seidel method is employed to obtain a quick approximate solution from a "flat start", while the Newton-Raphson method is utilized to obtain the final accurate solution [[5]](@ref PowerFlowSolutionReferenceTutorials).

The Gauss-Seidel method is typically based on the system of equations with ``n`` complex equations, one of which represents the slack bus. As a analysis, one equation can be eliminated, resulting in a power flow problem with ``n-1`` equations.

---

##### Initialization
JuliaGrid provides a way to utilize the Gauss-Seidel method for solving the AC power flow problem and determining the magnitudes and angles of bus voltages. To use this method, we need to execute the  [`acModel!`](@ref acModel!) function first to set up the system and then initialize the Gauss-Seidel method using the [`gaussSeidel`](@ref gaussSeidel) function. The code snippet below demonstrates this process:
```@example PowerFlowSolution
acModel!(system)
model = gaussSeidel(system)
nothing # hide
```

This results in the creation of the starting vectors of bus voltage magnitudes ``\mathbf{V}^{(0)}`` and angles ``\bm{\theta}^{(0)}``, as shown below:
```@repl PowerFlowSolution
𝐕⁽⁰⁾ = model.voltage.magnitude
𝛉⁽⁰⁾ = model.voltage.angle
```

---

##### Iterative Process
JuliaGrid offers the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) functions to implement the Gauss-Seidel method iterations. These functions are used iteratively until a stopping criterion is met, as shown in the code snippet below:
```@example PowerFlowSolution
for iteration = 1:300
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```

In contrast to the Newton-Raphson and Fast Newton-Raphson methods, the Gauss-Seidel method does not require the calculation of the mismatch in active and reactive power injection at each iteration. Instead, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function is used solely to verify the convergence criteria. At each iteration ``\nu = \{1, 2, \dots\}``, we calculate the active power injection mismatch for demand and generator buses, as shown below:
```math
    {f}_{P_i}(\mathbf x^{(\nu-1)}) = \Re\{\bar{V}_i^{(\nu - 1)} \bar{I}_i^{*(\nu - 1)}\} - P_i, \;\;\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}},
```
We also compute the reactive power injection mismatch for demand buses, given by:
```math
  {f}_{Q_i}(\mathbf x^{(\nu-1)}) = \Im\{\bar{V}_i^{(\nu - 1)} \bar{I}_i^{*(\nu - 1)}\} - Q_i, \;\;\; i \in \mathcal{N}_{\text{pq}}.
```

However, these mismatches are not stored as they are only used to obtain the maximum absolute values of these mismatches. The maximum values of these mismatches are used as termination criteria for the iteration loop if both are less than a predefined stopping criterion ``\epsilon``, as shown below:
```math
    \max \{|{f}_{P_i}(\mathbf x^{(\nu-1)})|,\; i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}} \} < \epsilon \\
    \max \{|{f}_{Q_i}(\mathbf x^{(\nu-1)})|,\; i \in \mathcal{N}_{\text{pq}} \} < \epsilon
```

After initializing complex bus voltages ``\bar{V}_i^{(0)}`` for all buses in the power system, the function [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) proceeds to compute the voltages for demand buses using the Gauss-Seidel method:
```math
    \bar{V}_{i}^{(\nu)} =
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}}{\bar{V}_{i}^{*(\nu-1)}} -
    \sum\limits_{\substack{j = 1}}^{i - 1} {Y}_{ij}\bar{V}_{j}^{(\nu)} -
    \sum\limits_{\substack{j = i + 1}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu-1)}\Bigg),
    \;\;\; i \in \mathcal{N}_{\text{pq}}.
```
The next step is to determine the solution for generator buses in two stages: first, the reactive power injection is calculated, and then the bus complex voltage is updated using the following equations:
```math
  \begin{aligned}
    Q_i^{(\nu)} &=
    -\Im \left\{ \bar{V}_{i}^{*(\nu)} \sum\limits_{j=1}^n {Y}_{ij}\bar{V}_{j}^{(\nu)}\right\}, \;\;\; i \in \mathcal{N}_{\text{pv}} \\
    \bar{V}_{i}^{(\nu )} &:=
    \cfrac{1}{{Y}_{ii}} \Bigg(\cfrac{{P}_{i} - j{Q}_{i}^{(\nu)}}{\bar{V}_{i}^{*(\nu )}}-
    \sum\limits_{\substack{j = 1,\;j \neq i}}^{n} {Y}_{ij}\bar{V}_{j}^{(\nu)} \Bigg), \;\;\; i \in \mathcal{N}_{\text{pv}}.
  \end{aligned}
```
The obtained voltage magnitude may not be equal to the magnitude specified for the generator bus, so a voltage correction step is necessary:
```math
      \bar{V}_{i}^{(\nu)} := {V}_{i}^{(0)} \cfrac{\bar{V}_{i}^{(\nu)}}{{V}_{i}^{(\nu)}}, \;\;\; i \in \mathcal{N}_{\text{pv}}.
```

JuliaGrid stores the final results in vectors that contain all bus voltage magnitudes and angles:
```@repl PowerFlowSolution
𝐕 = model.voltage.magnitude
𝛉 = model.voltage.angle
```

---

## [Power Analysis](@id ACPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of powers associated with buses, branches, and generators. Here is an example code snippet demonstrating its usage:
```@example PowerFlowSolution
power!(system, model)
nothing # hide
```

The function stores the computed powers in the rectangular coordinate system. It calculates the following powers related to buses:
* active and reactive power injections: ``\mathbf{P} = [P_i]``, ``\mathbf{Q} = [Q_i]``,
* active and reactive power injections from the generators:  ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}i}]``,
* active and reactive powers associated with shunt elements: ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]``, ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``.

It also calculates the following powers related to branches:
* active and reactive power flows at each "from" bus end: ``\mathbf{P}_{\text{i}} = [P_{ij}]``, ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``,
* active and reactive power flows at each "to" bus end: ``\mathbf{P}_{\text{j}} = [P_{ji}]``, ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``,
* active and reactive power losses: ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]``, ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``,
* reactive power injections: ``\mathbf{Q}_{\text{r}} = [ Q_{\text{r}ij}]``.

Lastly, it calculates the following powers related to generators:
* output active and reactive powers: ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``.

---

##### Active and Reactive Power Injections at Each Bus
The computation of active and reactive power injections at each bus is expressed by the following equation:
```math
    {S}_{i} = P_i + \text{j}Q_i = \bar{V}_{i}\sum\limits_{j = 1}^n {Y}_{ij}^* \bar{V}_{j}^*,\;\;\; i \in \mathcal{N}.
```
Active and reactive power injections are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl PowerFlowSolution
𝐏 = model.power.injection.active
𝐐 = model.power.injection.reactive
```

----

##### Active and Reactive Power Injections from the Generators at Each Bus
The [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function in JuliaGrid also computes the active and reactive power injections from the generators at each bus. The active power supplied by the generators to the buses can be calculated by summing the given generator active powers in the input data, except for the slack bus, which can be determined as:
```math
    P_{\text{s}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}},
```
where ``P_{\text{d}i}`` represents the active power demanded by consumers at the slack bus. The active power injections from the generators at each bus are stored as the vector, denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, can be obtained using the following command:
```@repl PowerFlowSolution
𝐏ₛ = model.power.supply.active
```

Similarly, the reactive power injections from the generators at each bus can be obtained using the following equation:
```math
    Q_{\text{s}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{pv}} \cup \mathcal{N}_{\text{sb}},
```
where ``Q_{\text{d}i}`` represents the reactive power demanded by consumers at the corresponding bus. Further, the reactive power injected by the generators at buses from ``\mathcal{N}_{\text{pq}}`` can be calculated by summing the given generator reactive powers in the input data. The vector of these reactive power injections by the generators to the buses, denoted by ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}i}]``, can be retrieved using the following command:
```@repl PowerFlowSolution
𝐐ₛ = model.power.supply.reactive
```

---

##### Active and Reactive Powers Associated with Shunt Elements at Each Bus
To obtain the active and reactive powers associated with the shunt elements at each bus, you can use the following equation:
```math
  {S}_{\text{sh}i} = {P}_{\text{sh}i} + \text{j}{Q}_{\text{sh}i} = \bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2,\;\;\; i \in \mathcal{N}.
```
The active power demanded by the shunt element at each bus is represented by the vector ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]``, while the reactive power injected or demanded by the shunt element at each bus is represented by the vector ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl PowerFlowSolution
𝐏ₛₕ = model.power.shunt.active
𝐐ₛₕ = model.power.shunt.reactive
```

---

##### Active and Reactive Power Flows at Each "From" Bus End of the Branch
The active and reactive power flows at "from" bus end ``i \in \mathcal{N}`` of the branch can be obtained using the following equation based on the [unified branch model](@ref UnifiedBranchModelTutorials):
```math
    S_{ij} = P_{ij} + \text{j}Q_{ij} = \bar{V}_{i}\left[\cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) \bar{V}_{i} - \alpha_{ij}^*{y}_{ij} \bar{V}_{j}\right]^*,\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active and reactive power flows at each "from" bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}],`` respectively, and can be retrieved using the following commands:
```@repl PowerFlowSolution
𝐏ᵢ = model.power.from.active
𝐐ᵢ = model.power.from.reactive
```

---

##### Active and Reactive Power Flows at Each "To" Bus End of the Branch
Similarly, we can determine the active and reactive power flows at the "to" bus end ``j \in \mathcal{N}`` of the branch using the equation:
```math
    {S}_{ji} = P_{ji} + \text{j}Q_{ji} = \bar{V}_{j} \left[-\alpha_{ij}{y}_{ij} \bar{V}_{i} + ({y}_{ij} + y_{\text{s}ij}) \bar{V}_{j}\right]^*,\;\;\; (i,j) \in \mathcal{E}.
```
The vectors of active and reactive power flows at the "to" bus end are stored as ``\mathbf{P}_{\text{j}} = [P_{ji}]`` and ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl PowerFlowSolution
𝐏ⱼ = model.power.to.active
𝐐ⱼ = model.power.to.reactive
```

---

##### Active and Reactive Power Losses at Each Branch
The active and reactive power losses of the branch are caused by its series impedance ``z_{ij}``. These losses can be obtained using the following equations:
```math
    \begin{aligned}
        P_{\text{l}ij} &= r_{ij}|y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j})|^2 \\
        Q_{\text{l}ij} &= x_{ij}|y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j})|^2,
    \end{aligned}
```
where ``(i,j) \in \mathcal{E}``. We can retrieve the vectors of active and reactive power losses, ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``, respectively, using the following commands:
```@repl PowerFlowSolution
𝐏ₗ = model.power.loss.active
𝐐ₗ = pmodel.power.loss.reactive
```

---

##### Reactive Power Injections by Each Branch
The branch's capacitive susceptances cause reactive power injections. We can calculate the total reactive power injected by the branch using the following equation:
```math
    Q_{\text{r}ij} = b_{\text{s}ij} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2),\;\;\; (i,j) \in \mathcal{E}.
```
To retrieve the vector of injected reactive powers ``\mathbf{Q}_{\text{r}} = [Q_{\text{r}ij}]``, use the following Julia command:
```@repl PowerFlowSolution
𝐐ᵣ = model.power.charging.reactive
```

---

##### Output Active and Reactive Powers of Each Generator
To obtain the output active powers of each generator connected to bus ``i \in \mathcal{N}_{\text{pq}} \cup \mathcal{N}_{\text{pv}}``, the given active power in the input data is utilized. For the generator connected to the slack bus, the output active power is determined using the equation:
```math
    P_{\text{g}i} = P_i + P_{\text{d}i},\;\;\; i \in \mathcal{N}_{\text{sb}}.
```
In the case of multiple generators connected to the slack bus, the first generator in the input data is assigned the obtained value of ``P_{\text{g}i}``. Then, this amount of power is reduced by the output active power of the other generators. Therefore, to get the vector of output active power of generators, i.e., ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, you can use the following command:
```@repl PowerFlowSolution
𝐏ₒ = model.power.generator.active
```

The output reactive powers of each generator located at the bus is obtained as:
```math
    Q_{\text{g}i} = Q_i + Q_{\text{d}i},\;\;\; i \in \mathcal{N}.
```
If there are multiple generators at the same bus, the reactive power is allocated proportionally among the generators based on their reactive power capabilities. To obtain the vector of output reactive power of generators`` \mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``, the following command can be used:
```@repl PowerFlowSolution
𝐐ₒ = model.power.generator.reactive
```

---

## [Current Analysis](@id ACCurrentAnalysisTutorials)
JuliaGrid offers the [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example PowerFlowSolution
current!(system, model)
nothing # hide
```

The function stores the computed currents in the polar coordinate system. It calculates the following currents related to buses:
* current injection magnitudes and angles: ``\mathbf{I} = [I_i]``, ``\bm{\psi} = [\psi_i]``.

It also calculates the following currents related to branches:
* current flow magnitudes and angles at each "from" bus end: ``\mathbf{I}_{\text{i}} = [I_{ij}]``, ``\bm{\psi}_{\text{i}} = [\psi_{ij}]``,
* current flow magnitudes and angles at each "to" bus end: ``\mathbf{I}_{\text{j}} = [I_{ji}]``, ``\bm{\psi}_{\text{j}} = [\psi_{ji}]``,
* current flow magnitudes and angles through series impedances: ``\mathbf{I}_{\text{s}} = [I_{\text{s}ij}]``, ``\bm{\psi}_{\text{s}} = [\psi_{\text{s}ij}]``.

---

##### Current Injection Magnitudes and Angles at Each Bus
To obtain the complex current injections at each bus, we use the following equation:
```math
    \bar{I}_{i} = I_i \text{e}^{\text{j}\psi_i} = \sum\limits_{j = 1}^n {Y}_{ij} \bar{V}_{j},\;\;\; i \in \mathcal{N}.
```
In JuliaGrid, these complex current injections are stored in the vector of magnitudes denoted as ``\mathbf{I} = [I_i]`` and the vector of angles represented as ``\bm{\psi} = [\psi_i]``. You can retrieve them using the following commands:
```@repl PowerFlowSolution
𝐈 = model.current.injection.magnitude
𝛙 = model.current.injection.angle
```


---

##### Current Flow Magnitudes and Angles at Each "From" Bus End of the Branch
To calculate the complex current flows at each "from" bus end ``i \in \mathcal{N}`` of the branch, the [unified branch model](@ref UnifiedBranchModelTutorials) can be utilized:
```math
    \bar{I}_{ij} = I_{ij} \text{e}^{\text{j}\psi_{ij}} = \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) \bar{V}_{i} - \alpha_{ij}^*{y}_{ij} \bar{V}_{j},\;\;\; (i,j) \in \mathcal{E}.
```
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting complex current flows, you can use the following commands:
```@repl PowerFlowSolution
𝐈ᵢ = model.current.from.magnitude
𝛙ᵢ = model.current.from.angle
```

---

##### Current Flow Magnitudes and Angles at Each "To" Bus End of the Branch
Similarly, we can obtain the complex current flows at each "to" bus end ``j \in \mathcal{N}`` of the branch using the unified branch model, given by:
```math
    \bar{I}_{ji} = I_{ji} \text{e}^{\text{j}\psi_{ji}} = -\alpha_{ij}{y}_{ij} \bar{V}_{i} + ({y}_{ij} + y_{\text{s}ij}) \bar{V}_{j},\;\;\; (i,j) \in \mathcal{E}.
```
We can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting complex current flows using the following code:
```@repl PowerFlowSolution
𝐈ⱼ = model.current.to.magnitude
𝛙ⱼ = model.current.to.angle
```

---

##### Current Flow Magnitudes and Angles at Each Branch Series Impedance
To obtain the complex current flows through each series impedance of a branch in the direction from bus ``i \in \mathcal{N}`` to bus ``j \in \mathcal{N}``, one can use the expression:
```math
    \bar{I}_{\text{s}ij} = I_{\text{s}ij} \text{e}^{\psi_{\text{s}ij}} =  y_{ij} (\alpha_{ij}\bar{V}_{i} - \bar{V}_{j}), \;\;\; (i,j) \in \mathcal{E}.
```
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{s}} = [I_{\text{s}ij}]`` and angles ``\bm{\psi}_{\text{s}} = [\psi_{\text{s}ij}]`` of the resulting complex current flows, one can use the following code:
```@repl PowerFlowSolution
𝐈ₛ = model.current.line.magnitude
𝛙ₛ = model.current.line.angle
```

---

## [References](@id PowerFlowSolutionReferenceTutorials)
[1] A. Wood and B. Wollenberg, *Power Generation, Operation, and Control*, ser. A Wiley-Interscience publication. Wiley, 1996.

[2] G. Andersson, *Modelling and analysis of electric power systems*, EEH-Power Systems Laboratory, Swiss Federal Institute of Technology (ETH), Zürich, Switzerland (2008).

[3] R. A. M. van Amerongen, "A general-purpose version of the fast decoupled load flow," *IEEE Trans. Power Syst.*, vol. 4, no. 2, pp. 760-770, May 1989.

[4] D. P. Chassin, P. R. Armstrong, D. G. Chavarria-Miranda, and R. T. Guttromson, "Gauss-seidel accelerated: implementing flow solvers on field programmable gate arrays," *in Proc. IEEE PES General Meeting*, 2006, pp. 5.

[5] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.

