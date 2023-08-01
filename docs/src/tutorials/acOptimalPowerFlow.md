# [AC Optimal Power Flow](@id ACOptimalPowerFlowTutorials)

To begin, the `PowerSystem` composite type must be provided to JuliaGrid through the use of the [`powerSystem`](@ref powerSystem) function, as illustrated by the following example:
```@example ACOptimalPowerFlow
using JuliaGrid # hide
using JuMP, Ipopt # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(minMagnitude = 0.9, maxMagnitude = 1.1)
addBus!(system; label = 1, type = 3, magnitude = 1.05, angle = 0.17)
addBus!(system; label = 2, active = 0.1, reactive = 0.01, conductance = 0.04)
addBus!(system; label = 3, active = 0.05, reactive = 0.02)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, resistance = 0.5, susceptance = 0.01)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 1.0, longTerm = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 1.0, longTerm = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 1.0, longTerm = 0.25)

@generator(minActive = 0.0, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.5, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, reactive = 0.1, maxActive = 0.2)

addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
addActiveCost!(system; label = 2, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

addReactiveCost!(system; label = 1, model = 2, polynomial = [30.2; 20; 5])
addReactiveCost!(system; label = 2, model = 2, polynomial = [10.3; 5.1; 1.2])

nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system. This can be visualized as follows:
```@repl ACOptimalPowerFlow
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

Moreover, we identify the set of generators as ``\mathcal{P} = \{1, \dots, n_g\}`` within the power system. For the specific example at hand, it can be represented as:
```@repl ACOptimalPowerFlow
𝒫 = collect(keys(sort(system.generator.label)))
```

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` denotes the generic element associated with bus ``i \in \mathcal{N}`` or generator ``i \in \mathcal{P}``, while ``a_{ij}`` denotes the generic element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [Optimization Problem](@id ACOptimizationProblemTutorials)
In the AC optimal power flow model, the active power outputs of the generators denoted as ``\mathbf {P}_{\text{g}} = [{P}_{\text{g}i}]``, ``i \in \mathcal{P}``, and reactive power outputs represented as ``\mathbf {Q}_{\text{g}} = [{Q}_{\text{g}i}]``, ``i \in \mathcal{P}``, are expressed as nonlinear functions of the bus voltage magnitudes ``\mathbf {V} = [{V}_{i}]``, ``i \in \mathcal{N}``, and angles ``\boldsymbol{\theta} = [{\theta}_{i}]``, ``i \in \mathcal{N}``. Consequently, the optimization variables in this model consist of the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles. The AC optimal power flow problem can be formulated as follows:
```math
\begin{aligned}
    & {\text{minimize}} & & \sum_{i=1}^{n_\text{g}} \left [ f_i(P_{\text{g}i}) + f_i(Q_{\text{g}i}) \right ] \\
    & \text{subject\;to} & &  V_i - V_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\
    & & &  \theta_i - \theta_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\[4pt]
    & & & h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\
    & & & h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\[4pt]
    & & & V_{i}^\text{min} \leq V_i \leq V_{i}^\text{max},\;\;\; \forall i \in \mathcal{N} \\
    & & & \theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E} \\[4pt]
    & & & h_{ij}(\mathbf {V}, \boldsymbol{\theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\
    & & & h_{ji}(\mathbf {V}, \boldsymbol{\theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\[4pt]
    & & & P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P} \\
    & & & Q_{\text{g}i}^\text{min} \leq Q_{\text{g}i} \leq Q_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P}.
\end{aligned}
```
The objective of the problem is to minimize the combined cost of active and reactive power outputs from all generators. Each generator, denoted by ``i \in \mathcal{P}``, is associated with cost functions ``f_i(P_{\text{g}i})`` and ``f_i(Q_{\text{g}i})``, representing the cost of generating active and reactive power, respectively. These cost functions may take the form of polynomial or linear piecewise functions. Typically, the AC optimal power flow focuses on minimizing the cost of active power outputs only, but for comprehensive analysis, we also consider the costs associated with reactive power outputs.

---

##### Polynomial Cost Function
In the following analysis, we will focus on the cost function of generating active power, denoted as ``f_i(P_{\text{g}i})``. However, please note that the same analysis can be applied to the cost function ``f_i(Q_{\text{g}i})`` for reactive power.

In the AC optimal power flow using JuliaGrid, the cost function ``f_i(P_{\text{g}i})`` can accept an ``n``-th degree polynomial form:
```math
f_i(P_{\text{g}i}) = \sum_{k=0}^n a_k P_{\text{g}i}^k.
```
When using the [`addActiveCost!`](@ref addActiveCost!) or [`addReactiveCost!`](@ref addReactiveCost!) function in JuliaGrid with the `polynomial` keyword, the polynomial is formed with the coefficients arranged from the highest degree to the lowest:
```math
\text{polynomial} = [a_n, \dots, a_1, a_0].
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
As depicted in Figure 1, typical scenarios involve linear, quadratic, or cubic cost functions, but the flexibility of the polynomial representation allows for other degrees as well.

---

##### Linear Piecewise Cost Function
The second option for defining cost functions in the AC optimal power flow is to use linear piecewise functions as approximations of the polynomial functions, as illustrated in Figure 2.
```@raw html
<img src="../../assets/cost_function_piecewise.svg" class="center" width="750"/>
<figcaption>Figure 2: The linear piecewise cost functions of active power output.</figcaption>
&nbsp;
```

In JuliaGrid, you can use the [`addActiveCost!`](@ref addActiveCost!) or [`addReactiveCost!`](@ref addReactiveCost!) function with the `piecewise` keyword to define the linear piecewise functions. The linear piecewise function is formed using a matrix of ``m`` points, where each row contains the generator active power output and the corresponding cost value:
```math
\text{piecewise} = \begin{bmatrix}
P_{\text{g}i,1} & f_i(P_{\text{g}i,1}) \\
\vdots &\\
P_{\text{g}i,m} & f_i(P_{\text{g}i,m})
\end{bmatrix}.
```
By providing these ``m`` points, you can define the cost function of the active power output for each generator using linear segments, which serves as an approximation to the original polynomial cost function. This approach offers flexibility in capturing the non-linear nature of the cost functions while maintaining simplicity in the optimization process.

JuliaGrid handles convex linear piecewise functions using a constrained cost variable method. In this approach, the piecewise linear cost function is replaced by a helper variable and a set of linear inequality constraints for each segment of the function defined by two neighboring points along the line. However, for linear piecewise functions that have only one segment defined by two points, JuliaGrid transforms it into a standard linear function without introducing a helper variable.

For an arbitrary segment of the piecewise function defined by the points ``(P_{\text{g}i,j}, f_i(P_{\text{g}i,j}))`` and ``(P_{\text{g}i,j+1}, f_i(P_{\text{g}i,j+1}))``, the function ``f_i(P_{\text{g}i})`` can be described as follows:   
```math
f_i(P_{\text{g}i}) = \cfrac{f_i(P_{\text{g}i,j+1}) - f_i(P_{\text{g}i,j})}{P_{\text{g}i,j+1} - P_{\text{g}i,j}}(P_{\text{g}i} - P_{\text{g}i,j}) + f_i(P_{\text{g}i,j}),\;\;\;j = 1,\dots,m/2,
```
where ``P_{\text{g}i,j} < P_{\text{g}i} \leq P_{\text{g}i,j+1}``. The corresponding inequality constraint for this function is formed using the helper cost variable ``H_{i}``:
```math
H_{i} \geq \cfrac{f_i(P_{\text{g}i,j+1}) - f_i(P_{\text{g}i,j})}{P_{\text{g}i,j+1} - P_{\text{g}i,j}}(P_{\text{g}i} - P_{\text{g}i,j}) + f_i(P_{\text{g}i,j}),\;\;\;j = 1,\dots,m/2.
```
It is important to note that the helper variable ``H_{i}`` remains the same over all segments of the ``i``-th piecewise cost function defined for the generator ``i \in \mathcal{P}``. To complete the method, we simply add the helper variable ``H_{i}`` to the objective function.

---

##### Formulating the Optimization Problem
Firstly, the power system is loaded and the AC model is built using the following function:
```@example ACOptimalPowerFlow
acModel!(system)
nothing # hide
```

Next, the above optimization problem is constructed by the function [`acOptimalPowerFlow`](@ref acOptimalPowerFlow), and we need to specify the optimization solver as follows:
```@example ACOptimalPowerFlow
model = acOptimalPowerFlow(system, Ipopt.Optimizer)
nothing # hide
```

---

##### Objective Function
In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active and reactive power outputs of the generators and the bus voltage magnitudes and angles is as follows:
```@repl ACOptimalPowerFlow
JuMP.objective_function(model.jump)
```
---

##### Slack Bus Constraints
The first two equality constraints are associated with the slack bus. These constraints fix both the bus voltage magnitude (denoted as ``V_i``) and the bus voltage angle (denoted as ``\theta_i``) to constant values ``V_{\text{slack}}`` and ``\theta_{\text{slack}}``, respectively. The constraints can be expressed as follows:
```math
\begin{aligned}
V_i - V_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\
\theta_i - \theta_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}.  \\
\end{aligned}
```
Here, the set ``\mathcal{N}_{\text{sb}}`` contains the index of the slack bus. These constraints are implemented using the `magnitude` and `angle` keywords within the [`addBus!`](@ref addBus!) function, where the bus is defined as a slack bus (`type = 3`).

To retrieve the equality constraints from the model, you can access the corresponding variables using the following code:
```@repl ACOptimalPowerFlow
model.constraint.slack.magnitude
model.constraint.slack.angle
```

---

##### Active and Reactive Power Balance Constraints
The third equality constraint in the optimization problem is associated with the active power balance equation denoted as ``h_{P_i}(\mathbf x)`` for each bus ``i \in \mathcal{N}``: 
```math
\begin{aligned}
h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\
\end{aligned}
```

The active power balance equation is derived using the [unified branch model](@ref UnifiedBranchModelTutorials) and can be represented as:
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}) - \sum_{k=1}^{n_{\text{g}i}} P_{\text{g}k} + P_{\text{d}i}
```
In the equation above, ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator connected to bus ``i \in \mathcal{N}``, and ``n_{\text{g}i}`` denotes the total number of generators connected to the same bus. The active power demand at bus ``i \in \mathcal{N}`` is denoted as ``P_{\text{d}i}``, and it is determined by the `active` keyword within the [`addBus!`](@ref addBus!) function.

You can access the references to the active power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.balance.active
```

Similarly, the next constraint in the optimization problem is associated with the reactive power balance equation denoted as ``h_{Q_i}(\mathbf x)`` for each bus ``i \in \mathcal{N}``: 
```math
\begin{aligned}
h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\
\end{aligned}
```
The reactive power balance equation is derived using the [unified branch model](@ref UnifiedBranchModelTutorials) and can be represented as:
```math
h_{Q_i}(\mathbf {Q}_{\text{g}}, \mathbf {V}, \boldsymbol{\theta}) = {V}_{i}\sum\limits_{j=1}^n {V}_{j} (G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) - \sum_{k=1}^{n_{\text{g}i}} Q_{\text{g}k} + Q_{\text{d}i}
```
In the equation above, ``Q_{\text{g}k}`` represents the reactive power output of the ``k``-th generator connected to bus ``i \in \mathcal{N}``. The reactive power demand at bus ``i \in \mathcal{N}`` is denoted as ``Q_{\text{d}i}``, and it is determined by the `reactive` keyword within the [`addBus!`](@ref addBus!) function.

You can access the references to the reactive power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.balance.reactive
```

---

##### Voltage Magnitude and Voltage Angle Difference Limit Constraints
The inequality constraints associated with the voltage magnitude ensure that the bus voltage magnitudes are within specified limits:
```math
V_{i}^\text{min} \leq V_i \leq V_{i}^\text{max},\;\;\; \forall i \in \mathcal{N} 
```
The minimum and maximum bus voltage magnitude limits are set using the `minMagnitude` and `maxMagnitude` keywords within the [`addBus!`](@ref addBus!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.limit.magnitude
```

The inequality constraint related to the minimum and maximum bus voltage angle difference between the "from" and "to" bus ends of each branch is defined as follows:
```math
\theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E}.
```
The values ``\theta_{ij}^\text{min}`` and ``\theta_{ij}^\text{max}`` are specified using the `minDiffAngle` and `maxDiffAngle` keywords, respectively, within the [`addBranch!`](@ref addBranch!) function. 

To retrieve this inequality constraint from the model and access the corresponding variable, you can use the following code:
```@repl ACOptimalPowerFlow
model.constraint.limit.angle
``` 

---

##### Rating Constraints
The inequality constraints related to the branch ratings can be associated with the limits on apparent power flow, active power flow, or current magnitude at the "from" and "to" bus ends of each branch. The type of constraint applied is determined by the `type` keyword within the [`addBranch!`](@ref addBranch!) function. Specifically, `type = 1` is used for apparent power flow, `type = 2` for active power flow, and `type = 3` for current magnitude. These constraints can be expressed using the equations ``h_{ij}(\mathbf {V}, \boldsymbol{\theta})`` and ``h_{ji}(\mathbf {V}, \boldsymbol{\theta})``, representing the rating constraints at the "from" and "to" bus ends of each branch ``(i,j) \in \mathcal{E}``, respectively:
```math
\begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta}) \leq F_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E}.
\end{aligned}
```
Here, ``F_{ij}^{\text{max}}`` represents the specified limit, which is defined using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function. These rating constraints ensure that the power flow or current in each branch does not exceed the specified limits, helping to maintain the security and reliability of the power system.


By default, the rating constraints are associated with the apparent power flow (`type = 1`) at the "from" and "to" bus ends of each branch. These constraints are defined using the following equations:
```math
\begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta}) = \sqrt{  A_{ij} V_i^4 + B_{ij} V_i^2 V_j^2 - 2 V_i^3 V_j [C_{ij} \cos(\theta_{ij} - \phi_{ij}) - D_{ij} \sin(\theta_{ij} - \phi_{ij})] } \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta}) = \sqrt{  A_{ji} V_j^4 + B_{ji} V_i^2 V_j^2 - 2 V_i V_j^3 [C_{ji} \cos(\theta_{ij} - \phi_{ij}) + D_{ij} \sin(\theta_{ij} - \phi_{ij})] },
\end{aligned}
```
where:
```math
\begin{aligned}
    A_{ij} = \cfrac{g_{ij}^2 + (b_{ij} + b_{\text{s}i})^2}{\tau_{ij}^4},\;\;\; B_{ij} = \cfrac{g_{ij}^2 + b_{ij}^2}{\tau_{ij}^2},\;\;\; C_{ij} = \cfrac{g_{ij}^2 + b_{ij}(b_{ij} + b_{\text{s}i})}{\tau_{ij}^3},\;\;\; D_{ij} = \cfrac{g_{ij}^2 b_{\text{s}i}}{\tau_{ij}^3}\\
    A_{ji} = g_{ij}^2 + (b_{ij} + b_{\text{s}i})^2,\;\;\; B_{ji} = \cfrac{g_{ij}^2 + b_{ij}^2}{\tau_{ij}^2},\;\;\;C_{ji} = \cfrac{g_{ij}^2 + b_{ij}(b_{ij} + b_{\text{s}i})}{\tau_{ij}},\;\;\; D_{ji} = \cfrac{g_{ij} b_{\text{s}i}}{\tau_{ij}}.
 \end{aligned}
```

Since the quantity under the square root is always positive, these constraints are implemented by squaring them for computational efficiency. Thus, the squared rating constraints for the apparent power flow at the "from" and "to" bus ends of each branch can be expressed as follows:
```math
\begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta})^2 \leq (F_{ij}^{\text{max}})^2, \;\;\; \forall (i,j) \in \mathcal{E} \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta})^2 \leq (F_{ij}^{\text{max}})^2, \;\;\; \forall (i,j) \in \mathcal{E}.
\end{aligned}
```

To access the rating constraints of branches at the "from" bus end, you can use the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.rating.from
```

Similarly, to acces the "to" bus end rating constraints of branches you can use the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.rating.to
```


The second option is to define the `longTerm` keyword for the active power flow constraints (`type = 2`) at the "from" and "to" bus ends of each branch. In this case, the constraints are implemented without squaring the equations, but rather as they are originally defined:
```math
  \begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta}) &=
    \cfrac{g_{ij}}{\tau_{ij}^2} V_{i}^2 -
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right]V_{i}V_{j} \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta}) &= g_{ij} V_{j}^2 -  
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij}- \phi_{ij})\right] V_{i} V_j.
  \end{aligned}    
```

The last option involves defining the `longTerm` keyword for the current magnitude constraints (`type = 3`) at the "from" and "to" bus ends of each branch. In this case, the constraints are implemented as follows:
```math
  \begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta}) &= \sqrt{ A_{ij}V_i^2 + B_{ij}V_j^2 - 2V_iV_j[C_{ij} \cos(\theta_{ij} - \phi_{ij}) - D_{ij}\sin(\theta_{ij} - \phi_{ij})]} \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta}) &= \sqrt{ A_{ji}V_i^2 + B_{ji}V_j^2 - 2V_iV_j[C_{ji} \cos(\theta_{ij} - \phi_{ij}) + D_{ji}\sin(\theta_{ij} - \phi_{ij})]},
  \end{aligned}    
```
where:
```math
  \begin{aligned}
    A_{ij} &= \cfrac{g_{ij}^2+(b_{ij}+b_{si})^2}{\tau_{ij}^4}; \;\;\; B_{ij} =  \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2}; \;\;\;    
    C_{ij} = \cfrac{g_{ij}^2+b_{ij}(b_{ij}+b_{si})}{\tau_{ij}^3}; \;\;\; D_{ij} = \cfrac{g_{ij}b_{si}}{\tau_{ij}^3}\\
    A_{ji} &= \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2}; \;\;\; B_{ji} = g_{ij}^2+(b_{ij}+b_{si})^2; \;\;\;
    C_{ji} = \cfrac{g_{ij}^2+b_{ij}(b_{ij}+b_{si})}{\tau_{ij}}; \;\;\; D_{ji} = \cfrac{g_{ij}b_{si}}{\tau_{ij}}.
  \end{aligned}
```
Likewise, for the apparent power, these constraints are formulated as squared inequalities, as follows:
```math
\begin{aligned}
    h_{ij}(\mathbf {V}, \boldsymbol{\theta})^2 \leq (F_{ij}^{\text{max}})^2, \;\;\; \forall (i,j) \in \mathcal{E} \\
    h_{ji}(\mathbf {V}, \boldsymbol{\theta})^2 \leq (F_{ij}^{\text{max}})^2, \;\;\; \forall (i,j) \in \mathcal{E}.
\end{aligned}
```

---

##### Active and Reactive Power Capability Constraints
The next set of constraints pertains to the minimum and maximum limits of active and reactive power outputs of the generators. These constraints ensure that the power outputs of the generators remain within specified bounds:
```math
P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P}. 
```

To define the constraints regarding the minimum ``P_{\text{g}i}^\text{min}`` and maximum ``P_{\text{g}i}^\text{max}`` active power output limits of the generators, you can use the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access these constraints, you can utilize the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.capability.active
```

Similarly, constraints related to the minimum and maximum limits of reactive power outputs of the generators ensure that the reactive powers remain within specified boundaries:
```math
Q_{\text{g}i}^\text{min} \leq Q_{\text{g}i} \leq Q_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P}.
```

To define the constraints concerning the minimum ``Q_{\text{g}i}^\text{min}`` and maximum ``Q_{\text{g}i}^\text{max}`` reactive power output limits of the generators, you can utilize the `minReactive` and `maxReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access these constraints, you can use the following code snippet:
```@repl ACOptimalPowerFlow
model.constraint.capability.reactive
```

These capability limits of the generators define the feasible region, represented as a gray area in Figure 3, which forms the solution space for the active and reactive output powers of the generators.
```@raw html
<img src="../../assets/pq_curve.svg" class="center" width="350"/>
<figcaption>Figure 3: The feasible region created by the active and reactive power capability constraints.</figcaption>
&nbsp;
```

However, this representation might not be the most accurate depiction of the generator's output power behavior. In reality, there exists a tradeoff between the active and reactive power outputs of the generators [[1]](@ref ACOptimalPowerFlowSolutionReferenceTutorials). Specifically, when a generator operates at its maximum active power ``P_{\text{g}i}^\text{max}``, ``i \in \mathcal{P}``, it may not be able to produce the maximum ``Q_{\text{g}i}^\text{max}`` or minimum ``Q_{\text{g}i}^\text{min}`` reactive power. To capture this tradeoff, we introduce the ability to include additional upper and lower constraints on the feasible region, leading to its reduction as shown in Figure 4.
```@raw html
<img src="../../assets/pq_curve_sloped.svg" class="center" width="350"/>
<figcaption>Figure 4: The feasible region created by the active and reactive power capability constraints with additional upper and lower constraints.</figcaption>
&nbsp;
```

To incorporate the new constraints into the system, we introduce two additional sets of points per generator. The first set, denoted by ``P_{\text{g}i}^\text{low}``, ``Q_{\text{g}i,\text{low}}^\text{min}``, and ``Q_{\text{g}i,\text{low}}^\text{max}``, can be defined using the `lowActive`, `minLowReactive`, and `maxLowReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. The second set, denoted by ``P_{\text{g}i}^\text{up}``, ``Q_{\text{g}i,\text{up}}^\text{min}``, and ``Q_{\text{g}i,\text{up}}^\text{max}``, can be defined using the `upActive`, `minUpReactive`, and `maxUpReactive` keywords within the same function.

To define this new two constraints we need to introduce ``P_{\text{g}i}^\text{low}`` with ``Q_{\text{g}i,\text{low}}^\text{min}`` and ``Q_{\text{g}i,\text{low}}^\text{max}``, and these values can be defined using `lowActive`, `minLowReactive`, and `maxLowReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. Next, we need to define ``P_{\text{g}i}^\text{up}`` with ``Q_{\text{g}i,\text{up}}^\text{min}`` and ``Q_{\text{g}i,\text{up}}^\text{max}`` using `upActive`, `minUpReactive`, and `maxUpReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. 

Using these points, we can construct two additional capability constraints per generator:
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
    s_2 = \sqrt{(Q_{\text{g}i,\text{up}}^\text{min} - Q_{\text{g}i,\text{low}}^\text{min})^2 + (P_{\text{g}i}^\text{low} - P_{\text{g}i}^\text{up})^2}
\end{aligned}
```

These additional constraints and scaling factors allow us to accurately represent the tradeoff between active and reactive power outputs of the generators while maintaining numerical stability.

---

## [Optimal Power Flow Solution](@id ACOptimalPowerFlowSolutionTutorials)
To obtain the optimal values of active and reactive power outputs for generators and the bus voltage magnitudes and angles, the user needs to invoke the following function:
```@example ACOptimalPowerFlow
JuMP.set_silent(model.jump) # hide
solve!(system, model)
nothing # hide
```

After solving the AC optimal power flow problem, you can retrieve the vectors of output active and reactive power for generators, denoted as ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]`` and ``\mathbf{Q}_{\text{g}} = [Q_{\text{g}i}]``, where ``i \in \mathcal{P}``, using the following commands:
```@repl ACOptimalPowerFlow
𝐏ₒ = model.power.active
𝐐ₒ = model.power.reactive
```

Similarly, the resulting bus voltage magnitudes and angles, represented by ``\mathbf{V} = [V_{i}]`` and ``\bm{\theta} = [\theta_{i}]``, where ``i \in \mathcal{N}``, are stored in the vectors as follows:
```@repl ACOptimalPowerFlow
𝐕 = model.voltage.magnitude
𝛉 = model.voltage.angle
```

By accessing these vectors, you can analyze and utilize the optimal power flow solution for further studies or operational decision-making in the power system.

---

## [Power Analysis](@id ACOptimalPowerAnalysisTutorials)
Once the computation of voltage magnitudes and angles at each bus is completed, various electrical quantities can be determined. JuliaGrid offers the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function, which enables the calculation of powers associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACOptimalPowerFlow
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

##### Active and Reactive Power Injections at Each Bus
The computation of active and reactive power injections at each bus is expressed by the following equation:
```math
    {S}_{i} = P_i + \text{j}Q_i = \bar{V}_{i}\sum\limits_{j = 1}^n {Y}_{ij}^* \bar{V}_{j}^*,\;\;\; i \in \mathcal{N}.
```
Active and reactive power injections are stored as the vectors ``\mathbf{P} = [P_i]`` and ``\mathbf{Q} = [Q_i]``, respectively, and can be retrieved using the following commands:
```@repl ACOptimalPowerFlow
𝐏 = model.power.injection.active
𝐐 = model.power.injection.reactive
```

---

##### Active and Reactive Power Injections from the Generators at Each Bus
The [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) function in JuliaGrid also provides the computation of active and reactive power injections from the generators at each bus. To calculate the active power supplied by generators to the buses, one can simply sum the active power outputs of the generators obtained from the optimal AC power flow. This can be represented as follows:
```math
    P_{\text{s}i} = \sum_{k=1}^{n_{\text{g}i}} P_{\text{g}k},\;\;\; i \in \mathcal{N}.
```
The active power injections from the generators at each bus are stored as a vector denoted by ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, and can be obtained using the following command:
```@repl ACOptimalPowerFlow
𝐏ₛ = model.power.supply.active
```

Similarly, we can obtain the reactive power supplied by generators to the buses:
```math
    Q_{\text{s}i} = \sum_{k=1}^{n_{\text{g}i}} Q_{\text{g}k},\;\;\; i \in \mathcal{N}.
```
The vector of these reactive power injections by the generators to the buses, denoted by ``\mathbf{Q}_{\text{s}} = [Q_{\text{s}i}]``, can be retrieved using the following command:
```@repl ACOptimalPowerFlow
𝐐ₛ = model.power.supply.reactive
```

---

##### Active and Reactive Powers Associated with Shunt Elements at Each Bus
To obtain the active and reactive powers associated with the shunt elements at each bus, you can use the following equation:
```math
  {S}_{\text{sh}i} = {P}_{\text{sh}i} + \text{j}{Q}_{\text{sh}i} = \bar{V}_{i}\bar{I}_{\text{sh}i}^* = {y}_{\text{sh}i}^*|\bar{V}_{i}|^2,\;\;\; i \in \mathcal{N}.
```
The active power demanded by the shunt element at each bus is represented by the vector ``\mathbf{P}_{\text{sh}} = [{P}_{\text{sh}i}]``, while the reactive power injected or demanded by the shunt element at each bus is represented by the vector ``\mathbf{Q}_{\text{sh}} = [{Q}_{\text{sh}i}]``. To retrieve these powers in JuliaGrid, use the following commands:
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
𝐏ₗ = model.power.loss.active
𝐐ₗ = model.power.loss.reactive
```

---

##### Reactive Power Injections by Each Branch
The branch's capacitive susceptances cause reactive power injections. We can calculate the total reactive power injected by the branch using the following equation:
```math
    Q_{\text{r}ij} = b_{\text{s}ij} (|\alpha_{ij}\bar{V}_{i}|^2 - |\bar{V}_{j}|^2),\;\;\; (i,j) \in \mathcal{E}.
```
To retrieve the vector of injected reactive powers ``\mathbf{Q}_{\text{r}} = [Q_{\text{r}ij}]``, use the following Julia command:
```@repl ACOptimalPowerFlow
𝐐ᵣ = model.power.charging.reactive
```

---

## Current Analysis
JuliaGrid offers the [`current!`](@ref current!(::PowerSystem, ::ACAnalysis)) function, which enables the calculation of currents associated with buses and branches. Here is an example code snippet demonstrating its usage:
```@example ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
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
```@repl ACOptimalPowerFlow
𝐈ₛ = model.current.line.magnitude
𝛙ₛ = model.current.line.angle
```

---

## [References](@id ACOptimalPowerFlowSolutionReferenceTutorials)
[1] R. D. Zimmerman, C. E. Murillo-Sanchez, *MATPOWER User’s Manual*, Version 7.0. 2019.

