# [DC Optimal Power Flow](@id DCOptimalPowerFlowTutorials)
To begin, let us generate the `PowerSystem`  type, as illustrated by the following example:
```@example DCOptimalPowerFlow
using JuliaGrid # hide
using JuMP, HiGHS
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, angle = 0.17)
addBus!(system; label = 2, type = 2, active = 0.1, conductance = 0.04)
addBus!(system; label = 3, type = 1, active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05, maxFromBus = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01, maxFromBus = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01, maxFromBus = 0.25)

@generator(minActive = 0.0)
addGenerator!(system; label = 1, bus = 1, active = 3.2, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, maxActive = 0.3)

cost!(system; label = 1, active = 2, polynomial = [1100.2; 500; 80])
cost!(system; label = 2, active = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl DCOptimalPowerFlow
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

Moreover, we identify the set of generators as ``\mathcal{S} = \{1, \dots, n_\text{g}\}`` within the power system:
```@repl DCOptimalPowerFlow
𝒮 = collect(keys(system.generator.label))
```

---

!!! ukw "Notation"
    Here, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element related with bus ``i \in \mathcal{N}`` or generator ``i \in \mathcal{S}``, while ``a_{ij}`` denotes the element related with branch ``(i,j) \in \mathcal{E}``.

---

## [Optimal Power Flow Model](@id DCOptimalPowerFlowModelTutorials)
In the DC optimal power flow, the active power outputs of the generators ``\mathbf {P}_{\text{g}} = [{P}_{\text{g}i}]``, ``i \in \mathcal{S}``, are represented as linear functions of the bus voltage angles ``\bm{\Theta} = [{\theta}_{i}]``, ``i \in \mathcal{N}``. Thus, the optimization variables in this model are the active power outputs of the generators and the bus voltage angles.

The DC optimal power flow model has the form:
```math
\begin{aligned}
    & {\text{minimize}} & & \sum_{i \in \mathcal{S}} f_i(P_{\text{g}i}) \\
    & \text{subject\;to} & &  \theta_i - \theta_{\text{s}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\[3pt]
    & & & h_{P_i}(\mathbf {P}_{\text{g}}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\[3pt]
    & & & \theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E} \\[3pt]
    & & &  P_{ij}^{\text{min}} \leq h_{P_{ij}}(\theta_i, \theta_j) \leq P_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\[3pt]
    & & & P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S}.
\end{aligned}
```

Essentially, the DC optimal power flow is focused on the minimization of the objective function related to the costs associated with the active power output of generators, all while ensuring the satisfaction of various constraints. This optimization task holds a crucial role in the efficient and timely management of electrical power systems. However, it is important to note that the solutions provided by the DC optimal power flow are approximate in nature.

---

##### Build Optimal Power Flow Model
To build the DC optimal power flow model, we must first load the power system and establish the DC model using:
```@example DCOptimalPowerFlow
dcModel!(system)
nothing # hide
```

Afterward, the DC optimal power flow model is created using the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function:
```@example DCOptimalPowerFlow
analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
nothing # hide
```

---

##### Optimization Variables
Hence, the variables in this model encompass the active power outputs of the generators denoted as ``\mathbf{P}_{\text{g}} = [{P}_{\text{g}i}]``, where ``i \in \mathcal{S}``, and the bus voltage angles represented by ``\bm{\Theta} = [{\theta}_{i}]``, where ``i \in \mathcal{N}``. You can access these variables using the following:
```@repl DCOptimalPowerFlow
𝐏ₒ = analysis.method.variable.active
𝚯 = analysis.method.variable.angle
```

---

## Objective Function
The objective function represents the sum of the active power cost functions ``f_i(P_{\text{g}i})``, ``i \in \mathcal{S}``, for each generator, where these cost functions can be polynomial or linear piecewise functions. It is important to note that only polynomial cost functions up to the second degree are included in the objective function. If higher-degree polynomials are present, they will be excluded from the objective function by JuliaGrid.

---

##### Polynomial Active Power Cost Function
The DC optimal power flow in JuliaGrid allows the cost function ``f_i(P_{\text{g}i})`` to be represented as a polynomial of up to the second degree, making it possible to express the cost function as linear or quadratic. The possible representations are as follows:
```math
\begin{aligned}
  f_i(P_{\text{g}i}) &= a_1P_{\text{g}i} + a_0 \\
  f_i(P_{\text{g}i}) &= a_2 P_{\text{g}i}^2 + a_1P_{\text{g}i} + a_0.
\end{aligned}
```

Furthermore, it is worth noting that the function can be given simply as a constant with only the coefficient ``a_0``, which implies that the cost of the generator remains constant regardless of the active power outputs. In conclusion, as illustrated in Figure 1, typical scenarios involve linear or quadratic cost functions, resulting in a best-case scenario for a linear optimization problem and a worst-case scenario for a quadratic optimization problem.
```@raw html
<img src="../../assets/cost_function_dc.svg" class="center" width="500"/>
<figcaption>Figure 1: The polynomial cost functions of generator active power output.</figcaption>
&nbsp;
```

When utilizing the [`cost!`](@ref cost!) function within JuliaGrid, employing the `polynomial` keyword results in the polynomial being constructed with coefficients ordered from the highest degree to the lowest. For instance, in the provided case study, we created a quadratic polynomial represented as:
```math
\begin{aligned}
  f_1(P_{\text{g}1}) &= 1100.2 P_{\text{g}1}^2 + 500 P_{\text{g}1} + 80.
\end{aligned}
```
To access these coefficients, users can utilize the variable:
```@repl DCOptimalPowerFlow
f₁ = system.generator.cost.active.polynomial[1]
```

---

##### Linear Piecewise Active Power Cost Function
The DC optimal power flow in JuliaGrid offers another option for defining cost functions by using linear piecewise functions as approximations of the polynomial functions, as depicted in Figure 2.
```@raw html
<img src="../../assets/cost_function_piecewise_dc.svg" class="center" width="500"/>
<figcaption>Figure 2: The linear piecewise cost functions of active power output.</figcaption>
&nbsp;
```

To define linear piecewise functions in JuliaGrid, users can utilize the [`cost!`](@ref cost!) function with the `piecewise` keyword. The linear piecewise function is constructed using a matrix where each row defines a single point. The first column holds the generator's active power output, while the second column corresponds to the associated cost value. For example, in the provided case study, a linear piecewise function is created and can be accessed as follows:
```@repl DCOptimalPowerFlow
f₂ = system.generator.cost.active.piecewise[2]
```

Similar to how convex linear piecewise functions are treated in the [AC Optimal Power Flow](@ref ACOptimalPowerFlowTutorials), JuliaGrid adopts a constrained cost variable method for the linear piecewise functions. In this method, the piecewise linear cost function is converted into a series of linear inequality constraints for each segment, which are defined by two adjacent points along the line, along with a helper variable specific to the piecewise function. However, for linear piecewise functions that have only one segment defined by two points, JuliaGrid simplifies it into a standard linear function without requiring a helper variable.

Consequently, for a piecewise cost function denoted as ``f_i(P_{\text{g}i})`` with ``k`` segments (where ``k > 1``), the ``j``-th segment, defined by the points ``[P_{\text{g}i,j}, f_i(P_{\text{g}i,j})]`` and ``[P_{\text{g}i,j+1}, f_i(P_{\text{g}i,j+1})]``, is characterized by the following inequality constraints:
```math
\cfrac{f_i(P_{\text{g}i,j+1}) - f_i(P_{\text{g}i,j})}{P_{\text{g}i,j+1} - P_{\text{g}i,j}}(P_{\text{g}i} - P_{\text{g}i,j}) + f_i(P_{\text{g}i,j}) \leq H_i, \;\;\; i \in \mathcal{S}, \;\;\; j = 1,\dots,k,
```
where ``H_i`` represents the helper variable. To finalize this method, we simply need to include the helper variable ``H_i`` in the objective function. This approach efficiently handles linear piecewise cost functions, providing the flexibility to capture nonlinear characteristics while still benefiting from the advantages of linear optimization techniques.

As an example, in the provided case study, the helper variable is defined as follows:
```@repl DCOptimalPowerFlow
H₂ = analysis.method.variable.actwise[2]
```

Lastly, the set of constraints introduced by the linear piecewise cost function is displayed as follows:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.piecewise.active)
```

---

##### Objective Function
As previously explained, the objective function relies on the defined polynomial or linear piecewise cost functions and represents the sum of these costs. In the provided example, the objective function that must be minimized to obtain the optimal values for the active power output of the generators and the bus voltage angles can be accessed using the following code:
```@repl DCOptimalPowerFlow
JuMP.objective_function(analysis.method.jump)
```

---

## Constraint Functions
In the following section, we will examine the various constraints defined within the DC optimal power flow model.

---

##### Slack Bus Constraint
The first equality constraint is linked to the slack bus, where the bus voltage angle denoted as ``\theta_i`` is fixed to a constant value ``\theta_{\text{s}}``. It can be expressed as follows:
```math
\theta_i - \theta_{\text{s}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}},
```
where the set ``\mathcal{N}_{\text{sb}}`` contains the index of the slack bus. To access the equality constraint from the model, we can utilize the variable:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.slack.angle)
```

---

##### Bus Active Power Balance Constraints
The second equality constraint in the optimization problem is associated with the active power balance equation:
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N}.
```

As elaborated in the [Nodal Network Equations](@ref DCNodalNetworkEquationsTutorials) section, we can express the equation as follows:
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \bm{\Theta}) = \sum_{k \in \mathcal{S}_i} P_{\text{g}k} - \sum_{k = 1}^n {B}_{ik} \theta_k - P_{\text{d}i} - P_{\text{sh}i} - P_{\text{tr}i}.
```
In this equation, the set ``\mathcal{S}_i \subseteq \mathcal{S}`` encompasses all generators connected to bus ``i \in \mathcal{N}``, and ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator within the set ``\mathcal{S}_i``. More precisely, the variable ``P_{\text{g}k}`` represents the optimization variable, as well as the bus voltage angle ``\theta_k``.

The constant terms in these equations are determined by the active power demand at bus ``P_{\text{d}i}``, the active power demanded by the shunt element ``P_{\text{sh}i}``, and power related to the shift angle of the phase transformers ``P_{\text{tr}i}``. The values representing these constant terms ``\mathbf{P}_{\text{d}} = [P_{\text{d}i}]``, ``\mathbf{P}_{\text{sh}} = [P_{\text{sh}i}]``, and ``\mathbf{P}_{\text{tr}} = [P_{\text{tr}i}]``, ``i, \in \mathcal{N}``, can be accessed:
```@repl DCOptimalPowerFlow
𝐏ₒ = system.bus.demand.active
𝐏ₛₕ = system.bus.shunt.conductance
𝐏ₜᵣ = system.model.dc.shiftPower
```

To retrieve constraints from the model, we can use:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.balance.active)
```

---

##### Bus Voltage Angle Difference Constraints
The inequality constraint related to the minimum and maximum bus voltage angle difference between the from-bus and to-bus ends of each branch is defined as follows:
```math
\theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E},
```
where ``\theta_{ij}^\text{min}`` represents the minimum, while ``\theta_{ij}^\text{max}`` represents the maximum of the angle difference between adjacent buses. The values representing the voltage angle difference, denoted as ``\bm{\Theta}_{\text{lm}} = [\theta_{ij}^\text{min}, \theta_{ij}^\text{max}]``, ``(i,j) \in \mathcal{E}``, are provided as follows:
```@repl DCOptimalPowerFlow
𝚯ₗₘ = [system.branch.voltage.minDiffAngle system.branch.voltage.maxDiffAngle]
```

To retrieve constraints from the model, we can use:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.voltage.angle)
```

---

##### Branch Active Power Flow Constraints
The inequality constraint related to active power flow is used to represent thermal limits on power transmission. This constraint is defined as follows:
```math
P_{ij}^{\text{min}} \leq h_{P_{ij}}(\theta_i, \theta_j) \leq P_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E}.
```

The branch flow limits at the from-bus, denoted as ``\mathbf{F}_{\text{f}} = [F_{ij}^\text{min}, F_{ij}^\text{max}]`` , can be retrieved as follows:
```@repl DCOptimalPowerFlow
𝐅ₒ = [system.branch.flow.minFromBus system.branch.flow.maxFromBus]
```

The active power flow at branch ``(i,j) \in \mathcal{E}`` can be derived using the [Branch Network Equations](@ref DCBranchNetworkEquationsTutorials) and is given by:
```math
h_{P_{ij}}(\theta_i, \theta_j) = \frac{1}{\tau_{ij} x_{ij} }(\theta_i - \theta_j - \phi_{ij}).
```

To retrieve constraints from the model, we can use:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.flow.active)
```

---

##### Generator Active Power Capability Constraints
The inequality constraints associated with the minimum and maximum active power outputs of the generators are defined as follows:
```math
P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S}.
```

In this representation, the lower and upper bounds are determined by the vector ``\mathbf{P}_{\text{m}} = [P_{\text{g}i}^\text{min}, P_{\text{g}i}^\text{max}]``, ``i \in \mathcal{S}``. We can access these bounds using the following variable:
```@repl DCOptimalPowerFlow
𝐏ₘ = [system.generator.capability.minActive system.generator.capability.maxActive]
```

To retrieve constraints from the model, we can use:
```@repl DCOptimalPowerFlow
print(analysis.method.constraint.capability.active)
```

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionTutorials)
To acquire the output active power of generators and the bus voltage angles, the user must invoke the function:
```@example DCOptimalPowerFlow
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)
nothing # hide
```

Therefore, to get the vector of output active power of generators ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, ``i \in \mathcal{S}``, we can use:
```@repl DCOptimalPowerFlow
𝐏ₒ = analysis.power.generator.active
```

Further, the resulting bus voltage angles ``\bm{\Theta} = [\theta_{i}]``, ``i \in \mathcal{N}``, are saved in the vector as follows:
```@repl DCOptimalPowerFlow
𝚯 = analysis.voltage.angle
```

---

## [Power Analysis](@id DCOptimalPowerAnalysisTutorials)
After obtaining the solution from the DC optimal power flow, we can calculate the powers related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::DC)) function:
```@example DCOptimalPowerFlow
power!(system, analysis)
nothing # hide
```

!!! note "Info"
    For a clear comprehension of the equations, symbols provided below, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active power injections](@ref DCBusInjectionTutorials) are stored as the vector ``\mathbf{P} = [P_i]``, and can be retrieved using the following commands:
```@repl DCOptimalPowerFlow
𝐏 = analysis.power.injection.active
```

---

##### Generator Power Injections
The active power supplied by generators to the buses can be calculated by summing the active power outputs of the generators obtained from the optimal DC power flow. This can be expressed as:
```math
    P_{\text{p}i} = \sum_{k=1}^{n_{\text{g}i}} P_{\text{g}k},\;\;\; \forall i \in \mathcal{N}.
```
Here, ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator connected to bus ``i \in \mathcal{N}``, and ``n_{\text{g}i}`` denotes the total number of generators connected to the same bus. We can obtain the vector of active powers injected by generators into the buses, denoted as ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, using the following command:
```@repl DCOptimalPowerFlow
𝐏ₚ = analysis.power.supply.active
```

---

##### Power Flows
The resulting [from-bus active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using:
```@repl DCOptimalPowerFlow
𝐏ᵢ = analysis.power.from.active
```

Similarly, the resulting [to-bus active power flows](@ref DCBranchNetworkEquationsTutorials) are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using:
```@repl DCOptimalPowerFlow
𝐏ⱼ = analysis.power.to.active
```