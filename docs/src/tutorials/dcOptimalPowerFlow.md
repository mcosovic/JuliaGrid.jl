# [DC Optimal Power Flow](@id DCOptimalPowerFlowTutorials)

To begin, the `PowerSystem` composite type must be provided to JuliaGrid through the use of the [`powerSystem`](@ref powerSystem) function, as illustrated by the following example:
```@example DCOptimalPowerFlow
using JuliaGrid # hide
using JuMP, HiGHS # hide

@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, angle = 0.17)
addBus!(system; label = 2, type = 2, active = 0.1, conductance = 0.04)
addBus!(system; label = 3, type = 1, active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05, longTerm = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01, longTerm = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01, longTerm = 0.25)

addGenerator!(system; label = 1, bus = 1, active = 3.2, minActive = 0.0, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.4, minActive = 0.0, maxActive = 0.6)
addGenerator!(system; label = 3, bus = 2, active = 0.2, minActive = 0.0, maxActive = 0.3)

addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
addActiveCost!(system; label = 2, model = 2, polynomial = [832.6; 258; 30])
addActiveCost!(system; label = 3, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

nothing # hide
```

To review, we can conceptualize the bus/branch model as the graph denoted by ``\mathcal{G} = (\mathcal{N}, \mathcal{E})``, where we have the set of buses ``\mathcal{N} = \{1, \dots, n\}``, and the set of branches ``\mathcal{E} \subseteq \mathcal{N} \times \mathcal{N}`` within the power system. This can be visualized as follows:
```@repl DCOptimalPowerFlow
𝒩 = collect(keys(sort(system.bus.label)))
ℰ = [system.branch.layout.from system.branch.layout.to]
```

Moreover, we identify the set of generators as ``\mathcal{P} = \{1, \dots, n_g\}`` within the power system. For the specific example at hand, it can be represented as:
```@repl DCOptimalPowerFlow
𝒫 = collect(keys(sort(system.generator.label)))
```

!!! ukw "Notation"
    In this section, when referring to a vector ``\mathbf{a}``, we use the notation ``\mathbf{a} = [a_{i}]`` or ``\mathbf{a} = [a_{ij}]``, where ``a_i`` denotes the generic element associated with bus ``i \in \mathcal{N}`` or generator ``i \in \mathcal{P}``, while ``a_{ij}`` denotes the generic element associated with branch ``(i,j) \in \mathcal{E}``.

---

## [Optimization Problem](@id DCOptimizationProblemTutorials)
In the DC optimal power flow, the active power outputs of the generators ``\mathbf {P}_{\text{g}} = [{P}_{\text{g}i}]``, ``i \in \mathcal{P}``, are represented as linear functions of the bus voltage angles ``\boldsymbol{\theta} = [{\theta}_{i}]``, ``i \in \mathcal{N}``. Therefore, the optimization variables in this model are the active power outputs of the generators and the bus voltage angles. The DC optimal power flow problem has the form:
```math
\begin{aligned}
    & {\text{minimize}} & & \sum_{i=1}^{n_\text{g}} f_i(P_{\text{g}i}) \\
    & \text{subject\;to} & &  \theta_i - \theta_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}  \\[3pt]
    & & & h_{P_i}(\mathbf {P}_{\text{g}}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N} \\[3pt]
    & & & \theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E} \\[3pt]
    & & &  - P_{ij}^{\text{max}} \leq h_{P_{ij}}(\theta_i, \theta_j) \leq P_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E} \\[3pt]
    & & & P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P}.
\end{aligned}
```

The objective function represents the sum of the active power cost functions ``f_i(P_{\text{g}i})``, ``i \in \mathcal{P}``, for each generator, where these cost functions can be polynomial or linear piecewise functions. It is important to note that only polynomial cost functions up to the second degree are included in the objective function. If higher-degree polynomials are present, they will be excluded from the objective function by JuliaGrid.

---

##### Polynomial Active Power Cost Function
The DC optimal power flow in JuliaGrid allows the cost function ``f_i(P_{\text{g}i})`` to be represented as a polynomial of up to the second degree, making it possible to express the cost function as linear or quadratic. The possible representations are as follows:
```math
\begin{aligned}
  f_i(P_{\text{g}i}) &= a_1P_{\text{g}i} + a_0 \\
  f_i(P_{\text{g}i}) &= a_2 P_{\text{g}i}^2 + a_1P_{\text{g}i} + a_0 \\
\end{aligned}
```

When using the [`addActiveCost!`](@ref addActiveCost!) function in JuliaGrid with the `polynomial` keyword, the polynomial is formed with the coefficients arranged from the highest degree to the lowest. For instance, in the case of a quadratic polynomial, the structure will be:
```math
\text{polynomial} = [a_2, a_1, a_0].
```

Furthermore, it is worth noting that the function can be given simply as a constant with only the coefficient ``a_0``, which implies that the cost of the generator remains constant regardless of the active power outputs. In conclusion, as illustrated in Figure 1, typical scenarios involve linear or quadratic cost functions, resulting in a best-case scenario for a linear optimization problem and a worst-case scenario for a quadratic optimization problem.
```@raw html
<img src="../assets/cost_function_dc.svg" class="center" width="500"/>
<figcaption>Figure 1: The polynomial cost functions of generator active power output.</figcaption>
&nbsp;
```

---

##### Linear Piecewise Active Power Cost Function
The DC optimal power flow in JuliaGrid offers another option for defining cost functions by using linear piecewise functions as approximations of the polynomial functions, as depicted in Figure 2.
```@raw html
<img src="../assets/cost_function_piecewise_dc.svg" class="center" width="500"/>
<figcaption>Figure 2: The linear piecewise cost functions of active power output.</figcaption>
&nbsp;
```

To define the linear piecewise functions in JuliaGrid, you can use the [`addActiveCost!`](@ref addActiveCost!) function with the `piecewise` keyword. The linear piecewise function is formed using a matrix of ``m`` points, where each row contains the generator active power output and the corresponding cost value:
```math
\text{piecewise} = \begin{bmatrix}
P_{\text{g}i,1} & f_i(P_{\text{g}i,1}) \\
\vdots &\\
P_{\text{g}i,m} & f_i(P_{\text{g}i,m})
\end{bmatrix}.
```

Similar to how convex linear piecewise functions are treated in the [AC Optimal Power Flow](@ref ACOptimalPowerFlowTutorials), JuliaGrid adopts a constrained cost variable method for the linear piecewise functions. In this approach, the piecewise linear cost function is transformed into a set of linear inequality constraints using a helper variable for each segment defined by two neighboring points along the line. However, for linear piecewise functions that have only one segment defined by two points, JuliaGrid simplifies it into a standard linear function without requiring a helper variable.

For an arbitrary segment of the piecewise function defined by the points ``(P_{\text{g}i,j}, f_i(P_{\text{g}i,j}))`` and ``(P_{\text{g}i,j+1}, f_i(P_{\text{g}i,j+1}))``, the function ``f_i(P_{\text{g}i})`` can be represented by an additional inequality constraint involving the helper variable ``H_i``:
```math
H_{i} \geq \cfrac{f_i(P_{\text{g}i,j+1}) - f_i(P_{\text{g}i,j})}{P_{\text{g}i,j+1} - P_{\text{g}i,j}}(P_{\text{g}i} - P_{\text{g}i,j}) + f_i(P_{\text{g}i,j}),\;\;\;j = 1,\dots,m/2.
```
To complete the method, we simply add the helper variable ``H_{i}`` to the objective function. Using this approach, JuliaGrid efficiently handles linear piecewise cost functions, offering flexibility in capturing non-linear characteristics while maintaining the advantages of linear optimization methods. 

---

##### Formulating the Optimization Problem
Firstly, the power system is loaded and the DC model is built using the following function:
```@example DCOptimalPowerFlow
dcModel!(system)
nothing # hide
```

Next, the above optimization problem is constructed by the function [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow), and we need to specify the optimization solver as follows:
```@example DCOptimalPowerFlow
model = dcOptimalPowerFlow(system, HiGHS.Optimizer)
nothing # hide
```

---

##### Objective Function
In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active power output of the generators and the bus voltage angles is as follows:
```@repl DCOptimalPowerFlow
JuMP.objective_function(model.jump)
```
---


##### Slack Bus Constraint
The first equality constraint is linked to the slack bus, where the bus voltage angle denoted as ``\theta_i`` is fixed to a constant value ``\theta_{\text{slack}}``. It can be expressed as follows:
```math
\theta_i - \theta_{\text{slack}} = 0,\;\;\; i \in \mathcal{N_{\text{sb}}}.  
```
Here, the set ``\mathcal{N}_{\text{sb}}`` contains the index of the slack bus. This constraint is added using the `angle` keyword within the [`addBus!`](@ref addBus!) function. 

To retrieve the equality constraint from the model, you can access the variable:
```@repl DCOptimalPowerFlow
model.constraint.slack.angle
```

---

##### Active Power Balance Constraints
The second equality constraint in the optimization problem is associated with the active power balance equation denoted as ``h_{P_i}(\mathbf x)`` for each bus ``i \in \mathcal{N}``: 
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \boldsymbol{\theta}) = 0,\;\;\;  \forall i \in \mathcal{N}.
```
The equation is derived using the [unified branch model](@ref DCUnifiedBranchModelTutorials) and can be represented as:
```math
h_{P_i}(\mathbf {P}_{\text{g}}, \boldsymbol{\theta}) = \sum_{k=1}^{n_{\text{g}i}} P_{\text{g}k} - \sum_{k = 1}^n {B}_{ik} \theta_k - P_{\text{d}i} - P_{\text{sh}i} - P_{\text{tr}i}.
```
In the equation above, ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator connected to bus ``i \in \mathcal{N}``, and ``n_{\text{g}i}`` denotes the total number of generators connected to the same bus. The constant terms in these equations are determined by the active power demand at bus ``P_{\text{d}i}`` and the active power demanded by the shunt element ``P_{\text{sh}i}``, which can be defined using the `active` and `conductance` keywords within the [`addBus!`](@ref addBus!) function, respectively. If there are phase shift transformers in the system, the constant terms can also be affected by the `shiftAngle` keyword within the [`addBranch!`](@ref addBranch!) function, denoted as ``P_{\text{tr}i}``. 

To retrieve this equality constraint from the model and access the corresponding variable, you can use the following code:
```@repl DCOptimalPowerFlow
model.constraint.balance.active
```

---

##### Voltage Angle Difference Limit Constraints
The inequality constraint related to the minimum and maximum bus voltage angle difference between the "from" and "to" bus ends of each branch is defined as follows:
```math
\theta_{ij}^\text{min} \leq \theta_i - \theta_j \leq \theta_{ij}^\text{max},\;\;\; \forall (i,j) \in \mathcal{E}.
```
The values ``\theta_{ij}^\text{min}`` and ``\theta_{ij}^\text{max}`` are specified using the `minDiffAngle` and `maxDiffAngle` keywords, respectively, within the [`addBranch!`](@ref addBranch!) function. 

To retrieve this inequality constraint from the model and access the corresponding variable, you can use the following code:
```@repl DCOptimalPowerFlow
model.constraint.limit.angle
``` 

---

##### Active Power Rating Constraints
The inequality constraint concerning the active power flow rating is used to represent thermal limits on the power transmission. This constraint is defined as follows:
```math
- P_{ij}^{\text{max}} \leq h_{P_{ij}}(\theta_i, \theta_j) \leq P_{ij}^{\text{max}},\;\;\; \forall (i,j) \in \mathcal{E}. 
```
The active power flow at branch ``(i,j) \in \mathcal{E}`` can be derived using the [unified branch model](@ref DCUnifiedBranchModelTutorials) and is given by the equation:
```math
h_{P_{ij}}(\theta_i, \theta_j) = \frac{1}{\tau_{ij} x_{ij} }(\theta_i - \theta_j - \phi_{ij}).
```
Hence, this inequality constraint, with lower and upper bounds, is associated with the active power flow limits at the "to" and "from" ends of the branch, respectively. The lower and upper bounds ``P_{ij}^{\text{max}}``, ``(i,j) \in \mathcal{E}``, are defined using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function. 

To retrieve this inequality constraint from the model and access the corresponding variable, you can use the following code:
```@repl DCOptimalPowerFlow
model.constraint.rating.active
```  

---

##### Active Power Capability Constraints
The inequality constraints associated with the minimum and maximum active power outputs of the generators are defined as follows:
```math
P_{\text{g}i}^\text{min} \leq P_{\text{g}i} \leq P_{\text{g}i}^\text{max} ,\;\;\; \forall i \in \mathcal{P}.
```  
These limits ``P_{\text{g}i}^\text{min}`` and ``P_{\text{g}i}^\text{max}`` are specified using the `minActive` and `maxActive` keywords, respectively, within the [`addGenerator!`](@ref addGenerator!) function. To retrieve this equality constraint from the model, you can use the following code:  
```@repl DCOptimalPowerFlow
model.constraint.capability.active
```  

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionTutorials)
To acquire the output active power of generators and the bus voltage angles, the user must invoke the function:
```@example DCOptimalPowerFlow
JuMP.set_silent(model.jump) # hide
solve!(system, model)
nothing # hide
```

Therefore, to get the vector of output active power of generators ``\mathbf{P}_{\text{g}} = [P_{\text{g}i}]``, ``i \in \mathcal{P}``, you can use the following command:
```@repl DCOptimalPowerFlow
𝐏ₒ = model.power.active
```
Further, the resulting bus voltage angles ``\bm{\theta} = [\theta_{i}]``, ``i \in \mathcal{N}``, are saved in the vector as follows:
```@repl DCOptimalPowerFlow
𝛉 = model.voltage.angle
```

---

## [Power Analysis](@id DCOptimalPowerAnalysisTutorials)
After obtaining the solution from the DC optimal power flow, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::DCAnalysis)) function:  
```@example DCOptimalPowerFlow
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
```@repl DCOptimalPowerFlow
𝐏 = model.power.injection.active
```


##### Active Power Injections From the Generators
The active power supplied by generators to the buses can be calculated by summing the active power outputs of the generators obtained from the optimal DC power flow. This can be expressed as:
```math
    P_{\text{s}i} = \sum_{k=1}^{n_{\text{g}i}} P_{\text{g}k},\;\;\; i \in \mathcal{N}.
```
Here, ``P_{\text{g}k}`` represents the active power output of the ``k``-th generator connected to bus ``i \in \mathcal{N}``, and ``n_{\text{g}i}`` denotes the total number of generators connected to the same bus. We can obtain the vector of active power injected by generators to the buses, denoted as ``\mathbf{P}_{\text{s}} = [P_{\text{s}i}]``, using the following command:
```@repl DCOptimalPowerFlow
𝐏ₛ = model.power.supply.active
```

---

##### Active Power Flows
The active power flows at each "from" bus end ``i \in \mathcal{N}`` of the branch can be obtained using the following equations:
```math
    P_{ij} = \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}),\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows are stored as the vector ``\mathbf{P}_{\text{i}} = [P_{ij}]``, which can be retrieved using the following command:
```@repl DCOptimalPowerFlow
𝐏ᵢ = model.power.from.active
```

Similarly, the active power flows at each "to" bus end ``j \in \mathcal{N}`` of the branch can be obtained as:
```math
    P_{ji} = - P_{ij},\;\;\; (i,j) \in \mathcal{E}.
```
The resulting active power flows are stored as the vector ``\mathbf{P}_{\text{j}} = [P_{ji}]``, which can be retrieved using the following command:
```@repl DCOptimalPowerFlow
𝐏ⱼ = model.power.to.active
```


