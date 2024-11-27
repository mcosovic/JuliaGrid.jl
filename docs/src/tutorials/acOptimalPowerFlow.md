# [AC Optimal Power Flow](@id ACOptimalPowerFlowTutorials)
To begin, let us generate the `PowerSystem` type, as illustrated by the following example:
```@example ACOptimalPowerFlow
using JuliaGrid # hide
using JuMP, Ipopt
@default(unit) # hide
@default(template) # hide

@labels(Integer)

system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = 1, type = 3, active = 0.1, angle = -0.1)
addBus!(system; label = 2, reactive = 0.01, magnitude = 1.1)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, reactance = 0.5, type = 1)
addBranch!(system; label = 1, from = 1, to = 2, maxFromBus = 0.15, maxToBus = 0.15)

@generator(maxActive = 0.5, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = 1, bus = 1, active = 0.4, reactive = 0.2)
addGenerator!(system; label = 2, bus = 2, active = 0.2, reactive = 0.1)

cost!(system; label = 1, active = 2, polynomial = [900.0; 500.0; 80.0; 5.0])
cost!(system; label = 2, active = 1, piecewise =  [10.8 12.3; 14.7 16.8; 18 18.1])

cost!(system; label = 1, reactive = 1, piecewise = [10.0 20.0; 20.0 40.0])
cost!(system; label = 2, reactive = 2, polynomial = [2.0])
nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system:
```@repl ACOptimalPowerFlow
𝒩 = collect(keys(system.bus.label))
ℰ = [𝒩[system.branch.layout.from] 𝒩[system.branch.layout.to]]
```

Moreover, we identify the set of generators as ``\mathcal{S} = \{1, \dots, n_\text{g}\}`` within the power system:
```@repl ACOptimalPowerFlow
𝒮 = collect(keys(system.generator.label))
```

---

!!! ukw "Notation"
    Here, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` represents the element related with bus ``i \in \mathcal{N}`` or generator ``i \in \mathcal{S}``, while ``a_{ij}`` denotes the element related with branch ``(i,j) \in \mathcal{E}``.

---

## [Optimal Power Flow Model](@id ACOptimalPowerFlowModelTutorials)
In the AC optimal power flow model, the active and reactive power outputs of the generators, denoted as ``\mathbf {P}_{\text{g}} = [{P}_{\text{g}i}]`` and ``\mathbf {Q}_{\text{g}} = [{Q}_{\text{g}i}]``, where ``i \in \mathcal{S}``, are expressed as nonlinear functions of the bus voltage magnitudes and angles, denoted as ``\mathbf {V} = [{V}_{i}]`` and ``\bm{\Theta} = [{\theta}_{i}]``, where ``i \in \mathcal{N}``. Consequently, the optimization variables encompass the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles.

The AC optimal power flow problem can be formulated as follows:
```math
\begin{aligned}
    & {\text{minimize}} & & \sum_{i \in \mathcal{S}} \left [ f_i(P_{\text{g}i}) + f_i(Q_{\text{g}i}) \right ] \\
    & \text{subject\;to} & & \theta_i - \theta_{\text{s}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\[5pt]
    & & & h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\
    & & & h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\[5pt]
    & & & V_{i}^\text{min} \leq V_i \leq V_{i}^\text{max},\;\;\; \forall i \in \mathcal{N} \\
    & & & \theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E} \\[5pt]
    & & & F_{ij}^{\text{min}} \leq h_{ij}(\mathbf {V}, \bm{\Theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\
    & & & F_{ji}^{\text{min}} \leq h_{ji}(\mathbf {V}, \bm{\Theta}) \leq F_{ji}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\[5pt]
    & & & P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S} \\
    & & & Q_{\text{g}i}^\text{min} \leq Q_{\text{g}i} \leq Q_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S}.
\end{aligned}
```

In essence, the AC optimal power flow aims to minimize the objective function associated with the costs of generator's active and reactive power output while ensuring the fulfillment of all constraints. This optimization task plays a pivotal role in effectively managing electrical power systems. By striking a balance between cost reduction and constraint adherence, the AC optimal power flow contributes to efficient and reliable electricity supply in complex grid environments.

---

##### Build Optimal Power Flow Model
To build the AC optimal power flow model, we must first load the power system and establish the AC model:
```@example ACOptimalPowerFlow
acModel!(system)
nothing # hide
```

Afterward, the AC optimal power flow model is created using the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function:
```@example ACOptimalPowerFlow
analysis = acOptimalPowerFlow(
  system, Ipopt.Optimizer; active = "Pg", reactive = "Qg", magnitude = "V", angle = "θ"
)
nothing # hide
```

---

##### Optimization Variables
The variables within this model encompass the active and reactive power outputs of the generators, denoted as ``\mathbf{P}_{\text{g}} = [{P}_{\text{g}i}]`` and ``\mathbf{Q}_{\text{g}} = [{Q}_{\text{g}i}]``, where ``i \in \mathcal{S}``, and the bus voltage magnitudes and angles represented by ``\mathbf{V} = [V_{i}]`` and ``\bm{\Theta} = [{\theta}_{i}]``, where ``i \in \mathcal{N}``. We can access these variables using the following code:
```@repl ACOptimalPowerFlow
𝐏ₒ = analysis.method.variable.active
𝐐ₒ = analysis.method.variable.reactive
𝐕 = analysis.method.variable.magnitude
𝚯 = analysis.method.variable.angle
```

---

## Objective Function
The objective function represents the sum of the active and reactive power cost functions ``f_i(P_{\text{g}i})`` and ``f_i(Q_{\text{g}i})``, where ``i \in \mathcal{S}``, for each generator, where these cost functions can be polynomial or linear piecewise. Typically, the AC optimal power flow focuses on minimizing the cost of active power outputs only, but for comprehensive analysis, we also consider the costs associated with reactive power outputs.

---

##### Polynomial Cost Function
In the following analysis, we will focus on the cost function of generating active power, denoted as ``f_i(P_{\text{g}i})``. However, please note that the same analysis can be applied to the cost function ``f_i(Q_{\text{g}i})`` for reactive power.

In the AC optimal power flow, the cost function ``f_i(P_{\text{g}i})`` can be represented as an ``n``-th degree polynomial:
```math
f_i(P_{\text{g}i}) = \sum_{k=0}^n a_k P_{\text{g}i}^k.
```

Typically, cost functions are represented as linear, quadratic, or cubic, as shown in Figure 1:
```math
\begin{aligned}
  f_i(P_{\text{g}i}) &= a_1P_{\text{g}i} + a_0 \\
  f_i(P_{\text{g}i}) &= a_2 P_{\text{g}i}^2 + a_1P_{\text{g}i} + a_0 \\
  f_i(P_{\text{g}i}) &= a_3 P_{\text{g}i}^3 + a_2 P_{\text{g}i}^2 + a_1P_{\text{g}i} + a_0. \\
\end{aligned}
```

```@raw html
<img src="../../assets/cost_function.svg" class="center" width="750"/>
<figcaption>Figure 1: The polynomial cost functions of generator active power output.</figcaption>
&nbsp;
```

When using the [`cost!`](@ref cost!) function in JuliaGrid and specifying the `polynomial` keyword, the polynomial is constructed with coefficients arranged in descending order of their degrees, from the highest degree to the lowest. For example, in the case study provided, we generated a cubic polynomial cost function for the active output power of `Generator 1`, which is represented as:
```math
\begin{aligned}
  f_1(P_{\text{g}1}) &= 900 P_{\text{g}1}^3 + 500 P_{\text{g}1}^2 + 80 P_{\text{g}1} + 5.
\end{aligned}
```
To access these coefficients, users can utilize the variable:
```@repl ACOptimalPowerFlow
f₁ = system.generator.cost.active.polynomial[1]
```

---

##### Linear Piecewise Cost Function
The second option for defining cost functions in the AC optimal power flow is to use linear piecewise functions as approximations of the polynomial functions, as illustrated in Figure 2.
```@raw html
<img src="../../assets/cost_function_piecewise.svg" class="center" width="750"/>
<figcaption>Figure 2: The linear piecewise cost functions of generator active power output.</figcaption>
&nbsp;
```

To define linear piecewise functions in JuliaGrid, users can utilize the [`cost!`](@ref cost!) function with the `piecewise` keyword. The linear piecewise function is constructed using a matrix where each row defines a single point. The first column holds the generator's active or reactive power output, while the second column corresponds to the associated cost value. For example, in the provided case study, a linear piecewise function is created and can be accessed as follows:
```@repl ACOptimalPowerFlow
f₂ = system.generator.cost.active.piecewise[2]
```

JuliaGrid handles convex linear piecewise functions using a constrained cost variable method. In this approach, the piecewise linear cost function is replaced by a helper variable and a set of linear inequality constraints for each segment of the function defined by two neighboring points along the line. However, for linear piecewise functions that have only one segment defined by two points, JuliaGrid transforms it into a standard linear function without introducing a helper variable.

Hence, for a piecewise cost function denoted as ``f_i(P_{\text{g}i})`` with ``k`` segments (where ``k > 1``), the ``j``-th segment, defined by the points ``[P_{\text{g}i,j}, f_i(P_{\text{g}i,j})]`` and ``[P_{\text{g}i,j+1}, f_i(P_{\text{g}i,j+1})]``, is characterized by the following inequality constraints:
```math
\cfrac{f_i(P_{\text{g}i,j+1}) - f_i(P_{\text{g}i,j})}{P_{\text{g}i,j+1} - P_{\text{g}i,j}}(P_{\text{g}i} - P_{\text{g}i,j}) + f_i(P_{\text{g}i,j}) \leq H_i, \;\;\; i \in \mathcal{S}, \;\;\; j = 1,\dots,k,
```
where ``H_i`` represents the helper variable. To finalize this method, we simply need to include the helper variable ``H_i`` in the objective function. This approach efficiently handles linear piecewise cost functions, providing the flexibility to capture nonlinear characteristics while still benefiting from the advantages of linear optimization techniques.

As an example, in the provided case study, the helper variable is defined as follows:
```@repl ACOptimalPowerFlow
H₂ = analysis.method.variable.actwise[2]
```

Lastly, the set of constraints introduced by the linear piecewise cost function is displayed as follows:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.piecewise.active)
```

---

##### Objective Function
As previously explained, the objective function relies on the defined polynomial or linear piecewise cost functions and represents the sum of these costs. In the provided example, the objective function that must be minimized to obtain the optimal values for the active and reactive power outputs of the generators and the bus voltage magnitudes and angles can be accessed using the following:
```@repl ACOptimalPowerFlow
JuMP.objective_function(analysis.method.jump)
```

---

## Constraint Functions
In the following section, we will examine the various constraints defined within the AC optimal power flow model.

---

##### Slack Bus Constraint
The first equality constraint is linked to the slack bus, where the bus voltage angle denoted as ``\theta_i`` is fixed to a constant value ``\theta_{\text{s}}``. It can be expressed as follows:
```math
\theta_i - \theta_{\text{s}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}},
```
where the set ``\mathcal{N}_{\text{sb}}`` contains the index of the slack bus. To access the equality constraint from the model, we can utilize the variable:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.slack.angle)
```

---

##### Bus Power Balance Constraints
The second equality constraint in the optimization problem is associated with the active power balance equation:
```math
\begin{aligned}
h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N}.
\end{aligned}
```

As elaborated in the [Bus Injections](@ref BusInjectionsTutorials) section, we can express the equation as follows:
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = {V}_{i}\sum\limits_{j=1}^n (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})V_j - \sum_{k \in \mathcal{S}_i} P_{\text{g}k} + P_{\text{d}i}.
```

In this equation, the set ``\mathcal{S}_i \subseteq \mathcal{S}`` encompasses all generators connected to bus ``i \in \mathcal{N}``, and ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator within the set ``\mathcal{S}_i``. More Precisely, the variable ``P_{\text{g}k}`` represents the optimization variable, along with the bus voltage angles ``\theta_{ij} = \theta_i - \theta_j`` and the bus voltage magnitudes ``V_i`` and ``V_j``.

The constant term is determined by the active power demand ``P_{\text{d}i}`` at bus ``i \in \mathcal{N}``. The values representing this constant term, denoted as ``\mathbf{P}_{\text{d}} = [P_{\text{d}i}]``, ``i, \in \mathcal{N}``, can be accessed using the following:
```@repl ACOptimalPowerFlow
𝐏ₒ = system.bus.demand.active
```

We can access the references to the active power balance constraints using the following snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.balance.active)
```

---

Similarly, the next constraint in the optimization problem is associated with the reactive power balance equation:
```math
\begin{aligned}
h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = 0,\;\;\;  \forall i \in \mathcal{N}.
\end{aligned}
```

As elaborated in the [Bus Injections](@ref BusInjectionsTutorials) section, we can express the equation as follows:
```math
h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \bm{\Theta}) = {V}_{i}\sum\limits_{j=1}^n (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})V_j - \sum_{k \in \mathcal{S}_i} Q_{\text{g}k} + Q_{\text{d}i}.
```

As mentioned earlier for active power, ``Q_{\text{g}k}`` represents the reactive power output of the ``k``-th generator within the set ``\mathcal{S}_i``. The variable ``Q_{\text{g}k}`` serves as an optimization variable, as well as the bus voltage angles ``\theta_{ij} = \theta_i - \theta_j``, and the bus voltage magnitudes ``V_i`` and ``V_j``.

The constant term is determined by the reactive power demand ``Q_{\text{d}i}`` at bus ``i \in \mathcal{N}``. The values representing this constant term, denoted as ``\mathbf{Q}_{\text{d}} = [Q_{\text{d}i}]``, ``i, \in \mathcal{N}``, can be accessed using the following:
```@repl ACOptimalPowerFlow
𝐐ₒ = system.bus.demand.reactive
```

We can access the references to the reactive power balance constraints using the following snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.balance.reactive)
```

---

##### Bus Voltage Constraints
The inequality constraints associated with the voltage magnitude ensure that the bus voltage magnitudes are within specified limits:
```math
V_{i}^\text{min} \leq V_i \leq V_{i}^\text{max},\;\;\; \forall i \in \mathcal{N},
```
where ``V_{i}^\text{min}`` represents the minimum voltage magnitude, and ``V_{i}^\text{max}`` represents the maximum voltage magnitude for bus ``i \in \mathcal{N}``. The values representing these voltage magnitude limits, denoted as ``\mathbf{V}_{\text{lm}} = [V_{i}^\text{min}, V_{i}^\text{max}]``, ``i \in \mathcal{N}``, can be accessed using the following:
```@repl ACOptimalPowerFlow
𝐕ₗₘ = [system.bus.voltage.minMagnitude system.bus.voltage.maxMagnitude]
```

To retrieve this inequality constraint from the model, we can use the following:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.voltage.magnitude)
```

---

The inequality constraint related to the minimum and maximum bus voltage angle difference between the from-bus and to-bus ends of each branch is defined as follows:
```math
\theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E},
```
where ``\theta_{ij}^\text{min}`` represents the minimum, while ``\theta_{ij}^\text{max}`` represents the maximum of the angle difference between adjacent buses. The values representing the voltage angle difference, denoted as ``\bm{\Theta}_{\text{lm}} = [\theta_{ij}^\text{min}, \theta_{ij}^\text{max}]``, ``(i,j) \in \mathcal{E}``, are provided as follows:
```@repl ACOptimalPowerFlow
𝚯ₗₘ = [system.branch.voltage.minDiffAngle system.branch.voltage.maxDiffAngle]
```

To retrieve this inequality constraint from the model, we can use the following:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.voltage.angle)
```

---

##### Branch Flow Constraints
The inequality constraints related to the branch flow ratings can be associated with the limits on apparent power flow, active power flow, or current magnitude at the from-bus and to-bus ends of each branch. The type of constraint applied is determined by the `type` keyword within the [`addBranch!`](@ref addBranch!) function.

The `type` value defines the constraint as follows: `type = 1` applies to active power flow; `type = 2` and `type = 3` apply to apparent power flow; and `type = 4` and `type = 5` apply to current magnitude. When `type = 3` or `type = 5` is selected, squared inequality constraints are used. These constraints typically provide a more numerically robust optimization problem but often result in slower convergence compared to the non-squared versions.

These constraints are mathematically expressed through the equations ``h_{ij}(\mathbf {V}, \bm{\Theta})`` and ``h_{ji}(\mathbf {V}, \bm{\Theta})``, representing the rating constraints at the from-bus and to-bus ends of each branch, respectively:
```math
\begin{aligned}
    F_{ij}^{\text{min}} \leq h_{ij}(\mathbf {V}, \bm{\Theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\
    F_{ji}^{\text{min}} \leq h_{ji}(\mathbf {V}, \bm{\Theta}) \leq F_{ji}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E}.
\end{aligned}
```

The branch flow limits at the from-bus and to-bus ends, denoted as ``\mathbf{F}_{\text{f}} = [F_{ij}^\text{min}, F_{ij}^\text{max}]`` and ``\mathbf{F}_{\text{t}} = [F_{ji}^\text{min}, F_{ji}^\text{max}]``, ``(i,j) \in \mathcal{E}``, can be retrieved as follows:
```@repl ACOptimalPowerFlow
𝐅ₒ = [system.branch.flow.minFromBus system.branch.flow.maxFromBus]
𝐅ₜ = [system.branch.flow.minToBus system.branch.flow.maxToBus]
```

---

The first option is to define the limit keywords for active power flow constraints (`type = 1`) at the from-bus and to-bus ends of each branch:
```math
  \begin{aligned}
    h_{ij}(\mathbf {V}, \bm{\Theta}) &=
    \cfrac{ g_{ij} + g_{\text{s}ij}}{\tau_{ij}^2} V_{i}^2 -
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right]V_{i}V_{j} \\
    h_{ji}(\mathbf {V}, \bm{\Theta}) &= (g_{ij} + g_{\text{s}ij}) V_{j}^2 -
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij}- \phi_{ij})\right] V_{i} V_j.
  \end{aligned}
```

In our example, we have chosen to utilize this type of flow constraints. To access the flow constraints of branches at the from-bus end, you can use the following code snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.flow.from)
```

Similarly, to access the to-bus end flow constraints of branches you can use the following code snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.flow.to)
```

---

The second option applies constraints to the apparent power flow (`type = 2`). This constraint at the from-bus is specified as:
```math
    h_{ij}(\mathbf {V}, \bm{\Theta}) = \sqrt{  A_{ij} V_i^4 + B_{ij} V_i^2 V_j^2 - 2 [C_{ij} \cos(\theta_{ij} - \phi_{ij}) - D_{ij} \sin(\theta_{ij} - \phi_{ij})]V_i^3 V_j},
```
where:
```math
  \begin{gathered}
    A_{ij} = \cfrac{(g_{ij} + g_{\text{s}i})^2+(b_{ij}+b_{\text{s}i})^2}{\tau_{ij}^4}, \;\;\; B_{ij} =  \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2} \\
    C_{ij} = \cfrac{g_{ij}(g_{ij}+g_{\text{s}i})+b_{ij}(b_{ij}+b_{\text{s}i})}{\tau_{ij}^3}, \;\;\; D_{ij} = \cfrac{g_{ij}b_{\text{s}i} - b_{ij}g_{\text{s}i}}{\tau_{ij}^3}.
  \end{gathered}
```

Furthermore, this constraint at the to-bus is specified as:
```math
    h_{ji}(\mathbf {V}, \bm{\Theta}) = \sqrt{  A_{ji} V_j^4 + B_{ji} V_i^2 V_j^2 - 2 [C_{ji} \cos(\theta_{ij} - \phi_{ij}) + D_{ij} \sin(\theta_{ij} - \phi_{ij})]V_i V_j^3  },
```
where:
```math
  \begin{gathered}
    A_{ji} = (g_{ij} + g_{\text{s}i})^2+(b_{ij}+b_{\text{s}i})^2, \;\;\; B_{ji} = \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2} \\
    C_{ji} = \cfrac{g_{ij}(g_{ij}+g_{\text{s}i})+b_{ij}(b_{ij}+b_{\text{s}i})}{\tau_{ij}}, \;\;\; D_{ji} = \cfrac{g_{ij}b_{\text{s}i} - b_{ij}g_{\text{s}i}}{\tau_{ij}}.
  \end{gathered}
```

If users choose `type = 3`, it means that the equations are squared (i.e., the square root is omitted), and the limit values will also be squared accordingly.

---

The last option involves defining the limit keywords for current magnitude constraints (`type = 3`) at the from-bus and to-bus ends of each branch. In this case, the constraints are implemented as follows:
```math
  \begin{aligned}
    h_{ij}(\mathbf {V}, \bm{\Theta}) &= \sqrt{A_{ij}V_i^2 + B_{ij}V_j^2 - 2[C_{ij} \cos(\theta_{ij} - \phi_{ij}) - D_{ij}\sin(\theta_{ij} - \phi_{ij})]V_iV_j} \\
    h_{ji}(\mathbf {V}, \bm{\Theta}) &= \sqrt{A_{ji}V_j^2 + B_{ji}V_i^2 - 2[C_{ji} \cos(\theta_{ij} - \phi_{ij}) + D_{ji}\sin(\theta_{ij} - \phi_{ij})]V_iV_j}.
  \end{aligned}
```

If users choose `type = 5`, it means that the equations are squared (i.e., the square root is omitted), and the limit values will also be squared accordingly.

---

##### [Generator Power Capability Constraints](@id ACPowerCapabilityConstraintsTutorials)
The next set of constraints pertains to the minimum and maximum limits of active and reactive power outputs of the generators. These constraints ensure that the power outputs of the generators remain within specified bounds:
```math
P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S}.
```

In this representation, the lower and upper limits are determined by the vector ``\mathbf{P}_{\text{m}} = [P_{\text{g}i}^\text{min}, P_{\text{g}i}^\text{max}]``, ``i \in \mathcal{S}``. We can access these bounds using the following:
```@repl ACOptimalPowerFlow
𝐏ₘ = [system.generator.capability.minActive, system.generator.capability.maxActive]
```

To access these constraints, you can utilize the following snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.capability.active)
```

---

Similarly, constraints related to the minimum and maximum limits of reactive power outputs of the generators ensure that the reactive powers remain within specified boundaries:
```math
Q_{\text{g}i}^\text{min} \leq Q_{\text{g}i} \leq Q_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{S}.
```

Thus, the lower and upper limits are determined by the vector ``\mathbf{Q}_{\text{m}} = [Q_{\text{g}i}^\text{min}, Q_{\text{g}i}^\text{max}]``, ``i \in \mathcal{S}``. We can access these bounds using the following:
```@repl ACOptimalPowerFlow
𝐐ₘ = [system.generator.capability.minReactive system.generator.capability.maxReactive]
```

To access these constraints, you can use the following snippet:
```@repl ACOptimalPowerFlow
print(analysis.method.constraint.capability.reactive)
```

---

These capability limits of the generators define the feasible region, represented as a gray area in Figure 3, which forms the solution space for the active and reactive output powers of the generators.
```@raw html
<img src="../../assets/pq_curve.svg" class="center" width="350"/>
<figcaption>Figure 3: The feasible region created by the active and reactive power capability constraints.</figcaption>
&nbsp;
```

However, this representation might not be the most accurate depiction of the generator's output power behavior. In reality, there exists a tradeoff between the active and reactive power outputs of the generators [zimmerman2016matpower](@cite). Specifically, when a generator operates at its maximum active power ``P_{\text{g}i}^\text{max}``, it may not be able to produce the maximum ``Q_{\text{g}i}^\text{max}`` or minimum ``Q_{\text{g}i}^\text{min}`` reactive power. To capture this tradeoff, we introduce the ability to include additional upper and lower constraints on the feasible region, leading to its reduction as shown in Figure 4.
```@raw html
<img src="../../assets/pq_curve_sloped.svg" class="center" width="350"/>
<figcaption>Figure 4: The feasible region created by the active and reactive power capability constraints with additional upper and lower constraints.</figcaption>
&nbsp;
```

If a user wishes to incorporate the tradeoff between active and reactive power outputs into the optimization model, they can define the points shown in Figure 4 within the [`addGenerator!`](@ref addGenerator!) function using the following keywords:

| Keyword           | Coordinate                              |
|:------------------|:----------------------------------------|
| `lowActive`       | ``P_{\text{g}i}^\text{low}``            |
| `minLowReactive`  | ``Q_{\text{g}i,\text{low}}^\text{min}`` |
| `maxLowReactive`  | ``Q_{\text{g}i,\text{low}}^\text{max}`` |
| `upActive`        | ``P_{\text{g}i}^\text{up}``             |
| `minUpReactive`   | ``Q_{\text{g}i,\text{up}}^\text{min}``  |
| `maxUpReactive`   | ``Q_{\text{g}i,\text{up}}^\text{max}``  |

When using these points, JuliaGrid constructs two additional capability constraints per generator as follows:
```math
\begin{aligned}
    (Q_{\text{g}i,\text{low}}^\text{max} - Q_{\text{g}i,\text{up}}^\text{max})P_{\text{g}i} + (P_{\text{g}i}^\text{up} - P_{\text{g}i}^\text{low})Q_{\text{g}i}
    \leq (Q_{\text{g}i,\text{low}}^\text{max} - Q_{\text{g}i,\text{up}}^\text{max})P_{\text{g}i}^\text{low} +  (P_{\text{g}i}^\text{up} - P_{\text{g}i}^\text{low})Q_{\text{g}i,\text{low}}^\text{max} \\
    (Q_{\text{g}i,\text{up}}^\text{min} - Q_{\text{g}i,\text{low}}^\text{min})P_{\text{g}i} + (P_{\text{g}i}^\text{low} - P_{\text{g}i}^\text{up})Q_{\text{g}i}
    \leq (Q_{\text{g}i,\text{up}}^\text{min} - Q_{\text{g}i,\text{low}}^\text{min})P_{\text{g}i}^\text{low} +  (P_{\text{g}i}^\text{low} - P_{\text{g}i}^\text{up})Q_{\text{g}i,\text{low}}^\text{min}.
\end{aligned}
```

To ensure numerical stability, these constraints are normalized by introducing two scaling factors:
```math
\begin{aligned}
    s_1 = \sqrt{(Q_{\text{g}i,\text{low}}^\text{max} - Q_{\text{g}i,\text{up}}^\text{max})^2 + (P_{\text{g}i}^\text{up} - P_{\text{g}i}^\text{low})^2}\\
    s_2 = \sqrt{(Q_{\text{g}i,\text{up}}^\text{min} - Q_{\text{g}i,\text{low}}^\text{min})^2 + (P_{\text{g}i}^\text{low} - P_{\text{g}i}^\text{up})^2}.
\end{aligned}
```

When these constraints exist in the system, users can access them using the following variables:
```@example ACOptimalPowerFlow
analysis.method.constraint.capability.upper
analysis.method.constraint.capability.lower
nothing # hide
```

These additional capability constraints allow us to accurately represent the tradeoff between active and reactive power outputs of the generators while maintaining numerical stability.

---

## [Optimal Power Flow Solution](@id ACOptimalPowerFlowSolutionTutorials)
To obtain the optimal values of active and reactive power outputs for generators and the bus voltage magnitudes and angles, the user needs to invoke the following function:
```@example ACOptimalPowerFlow
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)
nothing # hide
```

After solving the AC optimal power flow problem, you can retrieve the vectors of output active and reactive power for generators, denoted as ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]`` and ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``, where ``i \in \mathcal{S}``, using the following commands:
```@repl ACOptimalPowerFlow
𝐏ₒ = analysis.power.generator.active
𝐐ₒ = analysis.power.generator.reactive
```

Similarly, the resulting bus voltage magnitudes and angles, represented by ``\mathbf{V} = [V_{i}]`` and ``\bm{\Theta} = [\theta_{i}]``, where ``i \in \mathcal{N}``, are stored in the vectors as follows:
```@repl ACOptimalPowerFlow
𝐕 = analysis.voltage.magnitude
𝚯 = analysis.voltage.angle
```

By accessing these vectors, you can analyze and utilize the optimal power flow solution for further studies or operational decision-making in the power system.

---

## [Power Analysis](@id ACOptimalPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of powers associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACOptimalPowerFlow
power!(system, analysis)
nothing # hide
```

The function stores the computed powers in the rectangular coordinate system. It calculates the following powers related to buses and branches:

| Bus                                                            | Active                                          | Reactive                                        |
|:---------------------------------------------------------------|:------------------------------------------------|:------------------------------------------------|
| [Injections](@ref BusInjectionsTutorials)                      | ``\mathbf{P} = [P_i]``                          | ``\mathbf{Q} = [Q_i]``                          |
| [Generator injections](@ref OptGeneratorPowerInjectionsManual) | ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``     | ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``     |
| [Shunt elements](@ref BusShuntElementTutorials)                | ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` | ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]`` |

| Branch                                                     | Active                                       | Reactive                                     |
|:-----------------------------------------------------------|:---------------------------------------------|:---------------------------------------------|
| [From-bus end flows](@ref BranchNetworkEquationsTutorials) | ``\mathbf{P}_{\text{i}} = [P_{ij}]``         | ``\mathbf{Q}_{\text{i}} = [Q_{ij}]``         |
| [To-bus end flows](@ref BranchNetworkEquationsTutorials)   | ``\mathbf{P}_{\text{j}} = [P_{ji}]``         | ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``         |
| [Shunt elements](@ref BranchShuntElementsTutorials)        | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` | ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` |
| [Series elements](@ref BranchSeriesElementTutorials)       | ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` | ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]`` |

!!! note "Info"
    For a clear comprehension of the equations, symbols presented in this section, as well as for a better grasp of power directions, please refer to the [Unified Branch Model](@ref UnifiedBranchModelTutorials).

---

##### Power Injections
[Active and reactive power injections](@ref BusInjectionsTutorials) are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl ACOptimalPowerFlow
𝐏 = analysis.power.injection.active
𝐐 = analysis.power.injection.reactive
```

---

##### [Generator Power Injections](@id OptGeneratorPowerInjectionsManual)
The [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function in JuliaGrid also provides the computation of active and reactive power injections from the generators at each bus. To calculate the active power supplied by generators to the buses, one can simply sum the active power outputs of the generators obtained from the AC optimal power flow. This can be represented as:
```math
    P_{\text{p}i} = \sum_{k \in \mathcal{S}_i} P_{\text{g}k},\;\;\; \forall i \in \mathcal{N},
```
where the set ``\mathcal{S}_i \subseteq \mathcal{S}`` encompasses all generators connected to bus ``i \in \mathcal{N}``. The active power injections from the generators at each bus are stored as a vector denoted by ``\mathbf{P}_{\text{p}} = [P_{\text{p}i}]``, and can be obtained using:
```@repl ACOptimalPowerFlow
𝐏ₚ = analysis.power.supply.active
```

Similarly, we can obtain the reactive power supplied by generators to the buses:
```math
    Q_{\text{p}i} = \sum_{k \in \mathcal{S}_i} Q_{\text{g}k},\;\;\; \forall  i \in \mathcal{N}.
```
The vector of these reactive power injections by the generators to the buses, denoted by ``\mathbf{Q}_{\text{p}} = [Q_{\text{p}i}]``, can be retrieved using the following command:
```@repl ACOptimalPowerFlow
𝐐ₚ = analysis.power.supply.reactive
```

---

##### Power at Bus Shunt Elements
[Active and reactive powers](@ref BusShuntElementTutorials) associated with the shunt elements at each bus are represented by the vectors ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]`` and ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl ACOptimalPowerFlow
𝐏ₛₕ = analysis.power.shunt.active
𝐐ₛₕ = analysis.power.shunt.reactive
```

---

##### Power Flows
The resulting [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at each from-bus end are stored as the vectors ``\mathbf{P}_{\text{i}} = [P_{ij}]`` and ``\mathbf{Q}_{\text{i}} = [Q_{ij}],`` respectively, and can be retrieved using the following commands:
```@repl ACOptimalPowerFlow
𝐏ᵢ = analysis.power.from.active
𝐐ᵢ = analysis.power.from.reactive
```

Similarly, the vectors of [active and reactive power flows](@ref BranchNetworkEquationsTutorials) at the to-bus end are stored as ``\mathbf{P}_{\text{j}} = [P_{ji}]`` and ``\mathbf{Q}_{\text{j}} = [Q_{ji}]``, respectively, and can be retrieved using the following code:
```@repl ACOptimalPowerFlow
𝐏ⱼ = analysis.power.to.active
𝐐ⱼ = analysis.power.to.reactive
```

---

##### Power at Branch Shunt Elements
[Active and reactive powers](@ref BranchShuntElementsTutorials) associated with the branch shunt elements at each branch are represented by the vectors ``\mathbf{P}_{\text{s}} = [P_{\text{s}ij}]`` and ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}ij}]``. We can retrieve these values using the following code:
```@repl ACOptimalPowerFlow
𝐏ₛ = analysis.power.charging.active
𝐐ₛ = analysis.power.charging.reactive
```

---

##### Power at Branch Series Elements
[Active and reactive powers](@ref BranchSeriesElementTutorials) associated with the branch series element at each branch are represented by the vectors ``\mathbf{P}_{\text{l}} = [P_{\text{l}ij}]`` and ``\mathbf{Q}_{\text{l}} = [Q_{\text{l}ij}]``. We can retrieve these values using the following code:
```@repl ACOptimalPowerFlow
𝐏ₗ = analysis.power.series.active
𝐐ₗ = analysis.power.series.reactive
```

---

## Current Analysis
JuliaGrid offers the [`current!`](@ref current!(::PowerSystem, ::AC)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
𝐈 = analysis.current.injection.magnitude
𝛙 = analysis.current.injection.angle
```

---

##### Current Flows
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{i}} = [I_{ij}]`` and angles ``\bm{\psi}_{\text{i}} = [\psi_{ij}]`` for the resulting [complex current flows](@ref BranchNetworkEquationsTutorials), you can use the following commands:
```@repl ACOptimalPowerFlow
𝐈ᵢ = analysis.current.from.magnitude
𝛙ᵢ = analysis.current.from.angle
```

Similarly, we can obtain the vectors of magnitudes ``\mathbf{I}_{\text{j}} = [I_{ji}]`` and angles ``\bm{\psi}_{\text{j}} = [\psi_{ji}]`` of the resulting [complex current flows](@ref BranchNetworkEquationsTutorials) using the following code:
```@repl ACOptimalPowerFlow
𝐈ⱼ = analysis.current.to.magnitude
𝛙ⱼ = analysis.current.to.angle
```

---

##### Current at Branch Series Elements
To obtain the vectors of magnitudes ``\mathbf{I}_{\text{l}} = [I_{\text{l}ij}]`` and angles ``\bm{\psi}_{\text{l}} = [\psi_{\text{l}ij}]`` of the resulting [complex current flows](@ref BranchSeriesElementTutorials), one can use the following code:
```@repl ACOptimalPowerFlow
𝐈ₗ = analysis.current.series.magnitude
𝛙ₗ = analysis.current.series.angle
```