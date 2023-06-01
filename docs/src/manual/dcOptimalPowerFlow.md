# [DC Optimal Power Flow](@id DCOptimalPowerFlowManual)
JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the DC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `dcModel`. After that, create the `Model` composite type to establish the DC optimal power flow framework using the function:
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow).

To solve the DC optimal power flow problem and acquire bus voltage angles and generator active power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)).

After obtaining the solution for DC optimal power flow, JuliaGrid offers a post-processing analysis function to compute powers associated with buses, branches, and generators:
* [`power`](@ref power(::PowerSystem, ::DCOptimalPowerFlow)).

Moreover, there exist specific functions dedicated to calculating powers related to a particular bus, branch, or generator:
* [`powerBus`](@ref powerBus(::PowerSystem, ::DCOptimalPowerFlow)),
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::DCOptimalPowerFlow)),
* [`powerGenerator`](@ref powerBranch(::PowerSystem, ::DCOptimalPowerFlow)).

---

## [Optimization Variables](@id DCOptimizationVariablesManual)
To set up the DC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
```@example DCOptimalPowerFlowConstraint
using JuliaGrid # hide
using JuMP, HiGHS # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, angle = 0.17)
addBus!(system; label = 2, type = 2, active = 0.1, conductance = 0.04)
addBus!(system; label = 3, type = 1, active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05, longTerm = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01, longTerm = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01, longTerm = 0.25)

addGenerator!(system; label = 1, bus = 1, active = 3.2, minActive = 0.0, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, minActive = 0.0, maxActive = 0.2)

addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
addActiveCost!(system; label = 2, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

dcModel!(system)

model = dcOptimalPowerFlow(system, HiGHS.Optimizer)

nothing # hide
```

In the DC optimal power flow, the active power outputs of the generators are represented as linear functions of the bus voltage angles. Therefore, the variables in this model are the active power outputs of the generators and the bus voltage angles:
```@repl DCOptimalPowerFlowConstraint
JuMP.all_variables(model.jump)
```

Furthermore, if there are linear piecewise cost functions with more than one segment, JuliaGrid automatically generates a helper variable for each linear piecewise cost function. Specifically, this cost function is modeled using a constrained cost variable method, where the cost function is replaced by thr helper variable and the set of linear constraints.

---

## [Setup Primal Starting Values](@id SetupPrimalStartingValuesManual)
There are two methods available to specify primal starting values for each variable: using the built-in function provided by JuMP or accessing and modifying values directly within the `voltage` and `power` fields of the `Model` type.

---

##### Using JuMP Functions
One approach is to utilize the `set_start_value` function from the JuMP package. This allows us to set primal starting values for the active power outputs of the generators and the bus voltage angles. Here is an example:
```@example DCOptimalPowerFlowConstraint
JuMP.set_start_value.(model.jump[:active], [0.0, 0.18])
JuMP.set_start_value.(model.jump[:angle], [0.17, 0.13, 0.14])
nothing # hide
```
To inspect the primal starting values that have been set, you can use the `start_value` function from JuMP. Here is an example of how you can inspect the starting values for the active power outputs:
We can inspect that starting values are set:
```@repl DCOptimalPowerFlowConstraint
JuMP.start_value.(model.jump[:active])
```

---

##### Using JuliaGrid Variables
Alternatively, you can rely on the [`solve!`](@ref solve!) function to assign starting values based on the `voltage` and `power` fields. By default, these values are initially defined according to the active power outputs of the generators and the initial bus voltage angles:
```@repl DCOptimalPowerFlowConstraint
model.power.active
model.voltage.angle
```
You can modify these values, and they will be used as primal starting values during the execution of the [`solve!`](@ref solve!) function.

!!! warning "Warning"
    Please note that if primal starting values are set using the `set_start_value` function or any other method prior to executing the [`solve!`](@ref solve!) function, the values in the `voltage` and `power` fields will be ignored. This is because the starting point will be considered already defined.

---

## [Constraint Functions](@id DCConstraintFunctionsManual)
JuliGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `Model` composite type. These constraints are divided into six fields:
```@repl DCOptimalPowerFlowConstraint
fieldnames(typeof(model.constraint))
```

---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl DCOptimalPowerFlowConstraint
model.constraint.slack.angle
```

---

##### Active Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active power balance equations defined for each bus. The constant terms in these equations are determined by the `active` and `conductance` keywords within the [`addBus!`](@ref addBus!) function. Additionally, if there are phase shift transformers in the system, the constant terms can also be affected by the `shiftAngle` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlowConstraint
model.constraint.balance.active
```

---

##### Voltage Angle Limit Constraints
The `limit` field contains references to the inequality constraints associated with the minimum and maximum bus voltage angle difference between the "from" and "to" bus ends of each branch. These values are specified using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlowConstraint
model.constraint.limit.angle
```

Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

---

##### Active Power Rating Constraints
The `rating` field contains references to the inequality constraints associated with the active power flow limits at the "from" and "to" bus ends of each branch. These limits are specified using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlowConstraint
model.constraint.rating.active
```

---

##### Active Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active power outputs of the generators. These limits are specified using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function:
```@repl DCOptimalPowerFlowConstraint
model.constraint.capability.active
```

---

##### Active Power Piecewise Constraints
The `piecewise` field contains references to the inequality constraints associated with the linear piecewise cost function. In this case, the cost function is replaced by the helper variable and the set of linear constraints. These constraints are generated using the [`addActiveCost!`](@ref addActiveCost!) function with `model = 1` specified:
```@repl DCOptimalPowerFlowConstraint
model.constraint.piecewise.active[2]
```
Therefore, for the generator labelled as 2, there is the linear piecewise cost function with two segments. JuliaGrid sets the corresponding inequality constraints for each segment.

---

## [Objective Function](@id DCObjectiveFunctionManual)
The objective function of the DC optimal power flow is constructed using polynomial and linear piecewise cost functions of the generators, which are defined using the [`addActiveCost!`](@ref addActiveCost!) functions. It is important to note that only polynomial cost functions up to the second degree are included in the objective. If there are polynomials of higher degrees, JuliaGrid will exclude them from the objective function.

In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active power outputs of the generators and the bus voltage angles is as follows:
```@repl DCOptimalPowerFlowConstraint
JuMP.objective_function(model.jump)
```

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionManual)
To establish the DC optimal power flow problem, you can utilize the [`dcOptimalPowerFlow`](@ref dcPowerFlow) function. After setting up the problem, you can use the [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function to compute the optimal values for the active power outputs of the generators and the bus voltage angles. Here is an example:
```@example DCOptimalPowerFlowConstraint
solve!(system, model)
nothing # hide
```

By executing this function, you will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl DCOptimalPowerFlowConstraint
model.power.active
model.voltage.angle
```
