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
```@example DCOptimalPowerFlow
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
```@repl DCOptimalPowerFlow
JuMP.all_variables(model.jump)
```

Furthermore, if there are linear piecewise cost functions with more than one segment, JuliaGrid automatically generates a helper variable for each linear piecewise cost function. Specifically, this cost function is modelled using a constrained cost variable method, where the cost function is replaced by the helper variable and the set of linear constraints.

---

##### Add Variables
The user has the ability to easily add new variables to the defined DC optimal power flow model by using the [`@variable`](https://jump.dev/JuMP.jl/stable/reference/variables/#JuMP.@variable) macro from the JuMP package. Here is an example:
```@example DCOptimalPowerFlow
JuMP.@variable(model.jump, new)
nothing # hide
```

We can verify that the new variable is included in the defined model by using the function:
```@repl DCOptimalPowerFlow
JuMP.is_valid(model.jump, new)
```

---

##### Delete Variables
To delete a variable, the [`delete`](https://jump.dev/JuMP.jl/stable/reference/constraints/#JuMP.delete) function from the JuMP package can be used:
```@example DCOptimalPowerFlow
JuMP.delete(model.jump, new)
```

After deletion, the variable is no longer part of the model:
```@repl DCOptimalPowerFlow
JuMP.is_valid(model.jump, new)
```

---

## [Constraint Functions](@id DCConstraintFunctionsManual)
JuliGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `Model` composite type. These constraints are divided into six fields:
```@repl DCOptimalPowerFlow
fieldnames(typeof(model.constraint))
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [DC optimal power flow](@ref DCOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl DCOptimalPowerFlow
model.constraint.slack.angle
```

---

##### Active Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active power balance equations defined for each bus. The constant terms in these equations are determined by the `active` and `conductance` keywords within the [`addBus!`](@ref addBus!) function. Additionally, if there are phase shift transformers in the system, the constant terms can also be affected by the `shiftAngle` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
model.constraint.balance.active
```
If you want to exclude these constraints and skip their formation, you can utilize the `balance = false` keyword within the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve active power balance constraints.

Additionally, we provide the [`deleteBalanceActive!`](@ref deleteBalanceActive!) function to delete the active power balance constraint associated with a specific bus.

---

##### Voltage Angle Difference Limit Constraints
The `limit` field contains references to the inequality constraints associated with the minimum and maximum bus voltage angle difference between the "from" and "to" bus ends of each branch. These values are specified using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
model.constraint.limit.angle
```

Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint. Additionally, if you want to exclude all voltage angle limit constraints and skip their formation, you can use the `limit = false` keyword within the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function.

Also, we provide the [`deleteLimitAngle!`](@ref deleteLimitAngle!) function to delete the voltage angle difference limit constraint associated with a specific branch.

---

##### Active Power Rating Constraints
The `rating` field contains references to the inequality constraints associated with the active power flow limits at the "from" and "to" bus ends of each branch. These limits are specified using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
model.constraint.rating.active
```
If you want to exclude these constraints and skip their formation, you can use the `rating = false` keyword within the  [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve active power rating constraints.

Also, we provide the [`deleteRatingActive!`](@ref deleteRatingActive!) function to delete the active power rating constraint associated with a specific branch.

---

##### Active Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active power outputs of the generators. These limits are specified using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function:
```@repl DCOptimalPowerFlow
model.constraint.capability.active
```
If you want to exclude these constraints and skip their formation, you can use the `capability = false` keyword within the  [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve active power capability constraints.

Finally, we provide the [`deleteCapabilityActive!`](@ref deleteCapabilityActive!) function to delete the active power capability constraint associated with a specific generator.

---

##### Active Power Piecewise Constraints
The `piecewise` field contains references to the inequality constraints associated with the linear piecewise cost function. In this case, the cost function is replaced by the helper variable and the set of linear constraints. These constraints are generated using the [`addActiveCost!`](@ref addActiveCost!) function with `model = 1` specified:
```@repl DCOptimalPowerFlow
model.constraint.piecewise.active[2]
```
Therefore, for the generator labelled as 2, there is the linear piecewise cost function with two segments. JuliaGrid sets the corresponding inequality constraints for each segment.

---

##### Add Constraints
Users can effortlessly incorporate additional constraints into the defined DC optimal power flow model using the [`@constraint`](https://jump.dev/JuMP.jl/stable/reference/constraints/#JuMP.@constraint) macro. For instance, a new constraint can be added as follows:
```@example DCOptimalPowerFlow
angle = model.jump[:angle]

JuMP.@constraint(model.jump, -2.1 <= angle[1] - angle[2] <= 2.1)
nothing # hide
```

---

##### Delete Constraints
To delete a constraint, users can utilize the [`delete`](https://jump.dev/JuMP.jl/stable/reference/constraints/#JuMP.delete) function from the JuMP package. When dealing with constraints created internally, users can utilize the constraint references stored in the `constraint` field of the `Model` type. For instance, to delete the constraint that limits the voltage angle difference for the first branch, the following code snippet can be employed:
```@example DCOptimalPowerFlow
JuMP.delete(model.jump, model.constraint.limit.angle[1])
nothing # hide
```

Furthermore, the JuliaGrid package offers a range of functions for deleting specific internally created constraints. These functions require the `PowerSystem` and `DCOptimalPowerFlow` types as arguments, along with the `label` keyword. For example, if we want to delete the voltage angle difference limit constraint related to the second bus, we can use the method mentioned earlier, or we can use:
```@example DCOptimalPowerFlow
deleteLimitAngle!(system, model; label = 2)
nothing # hide
```

We also have functions [`deleteBalanceActive!`](@ref deleteBalanceActive!), [`deleteRatingActive!`](@ref deleteRatingActive!), and [`deleteCapabilityActive!`](@ref deleteCapabilityActive!) that can be used to delete the corresponding constraints within the `label` keyword. The `label` keyword should correspond to the bus, branch, or generator label, depending on the type of constraint we want to delete.

---

## [Objective Function](@id DCObjectiveFunctionManual)
The objective function of the DC optimal power flow is constructed using polynomial and linear piecewise cost functions of the generators, which are defined using the [`addActiveCost!`](@ref addActiveCost!) functions. It is important to note that only polynomial cost functions up to the second degree are included in the objective. If there are polynomials of higher degrees, JuliaGrid will exclude them from the objective function.

In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active power outputs of the generators and the bus voltage angles is as follows:
```@repl DCOptimalPowerFlow
JuMP.objective_function(model.jump)
```

---

##### Change Objective
The objective can be modified by the user using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/reference/objectives/#JuMP.set_objective_function) function from the JuMP package. Here is an example of how it can be done:
```@example DCOptimalPowerFlow
active = model.jump[:active]
helper = model.jump[:helper]
new = JuMP.@expression(model.jump, 1100 * active[1] * active[1] + helper[1] + 80)

JuMP.set_objective_function(model.jump, new)
```

---

## [Setup Primal Starting Values](@id SetupPrimalStartingValuesManual)
There are two methods available to specify primal starting values for each variable: using the built-in function provided by JuMP or accessing and modifying values directly within the `voltage` and `power` fields of the `Model` type.

---

##### Using JuMP Functions
One approach is to utilize the [`set_start_value`](https://jump.dev/JuMP.jl/stable/reference/variables/#JuMP.set_start_value) function from the JuMP package. This allows us to set primal starting values for the active power outputs of the generators and the bus voltage angles. Here is an example:
```@example DCOptimalPowerFlow
JuMP.set_start_value.(model.jump[:active], [0.0, 0.18])
JuMP.set_start_value.(model.jump[:angle], [0.17, 0.13, 0.14])
nothing # hide
```
To inspect the primal starting values that have been set, you can use the [`start_value`](https://jump.dev/JuMP.jl/stable/reference/variables/#JuMP.start_value) function from JuMP. Here is an example of how you can inspect the starting values for the active power outputs:
We can inspect that starting values are set:
```@repl DCOptimalPowerFlow
JuMP.start_value.(model.jump[:active])
```

---

##### Using JuliaGrid Variables
Alternatively, you can rely on the [`solve!`](@ref solve!) function to assign starting values based on the `power` and `voltage` fields. By default, these values are initially defined according to the active power outputs of the generators and the initial bus voltage angles:
```@repl DCOptimalPowerFlow
model.power.active
model.voltage.angle
```
You can modify these values, and they will be used as primal starting values during the execution of the [`solve!`](@ref solve!) function.

!!! warning "Warning"
    Please note that if primal starting values are set using the `set_start_value` function or any other method prior to executing the [`solve!`](@ref solve!) function, the values in the `power` and `voltage` fields will be ignored. This is because the starting point will be considered already defined.

---

##### Using DC Power Flow
Another approach is to perform the DC power flow and use the resulting solution to set primal starting values. Here is an example of how it can be done:
```@example DCOptimalPowerFlow
flowModel = dcPowerFlow(system)
solve!(system, flowModel)
```

After obtaining the solution, we can calculate the active power outputs of the generators and utilize the bus voltage angles to set the starting values. In this case, the `power` and `voltage` fields of the `Model` type can be employed to store the new starting values:
```@example DCOptimalPowerFlow
for (key, value) in system.generator.label
    powers = powerGenerator(system, flowModel; label = key)
    model.power.active[value] = powers.output.active
end

for i = 1:system.bus.number
    model.voltage.angle[i] = flowModel.voltage.angle[i]
end
```
Also, the user can make use of the [`set_start_value`](https://jump.dev/JuMP.jl/stable/reference/variables/#JuMP.set_start_value) function to set starting values from the DC power flow.

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionManual)
To establish the DC optimal power flow problem, you can utilize the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. After setting up the problem, you can use the [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function to compute the optimal values for the active power outputs of the generators and the bus voltage angles. Here is an example:
```@example DCOptimalPowerFlow
solve!(system, model)
nothing # hide
```

By executing this function, you will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl DCOptimalPowerFlow
model.power.active
model.voltage.angle
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, you can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/reference/solutions/#JuMP.objective_value) function:
```@repl DCOptimalPowerFlow
JuMP.objective_value(model.jump)
```

---

##### Silent Solver Output
To turn off the solver output within the REPL, you can use the [`set_silent`](https://jump.dev/JuMP.jl/stable/reference/models/#JuMP.set_silent) function before calling [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function. This will suppress the solver's output:
```@example DCOptimalPowerFlow
JuMP.set_silent(model.jump)
```

---

## [Power Analysis](@id DCOptimalPowerAnalysisManual)
After obtaining the solution from the DC optimal power flow, we can calculate powers related to buses and branches using the [`power`](@ref power(::PowerSystem, ::DCPowerFlow)) function. For instance, let us consider the power system for which we obtained the DC optimal power flow solution:
```@example DCOptimalPowerFlowPower
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
JuMP.set_silent(model.jump)

solve!(system, model)

nothing # hide
```

Now we can calculate the active powers using the following function:
```@example DCOptimalPowerFlowPower
powers = power(system, model)

nothing # hide
```
It is worth noting that we compute powers related to buses and branches. In addition, the `generator` field contains the active power outputs of the generators. The values in this field are references to the `power` field of the `Model` type.

For example, to display the active power injections at each bus and active power flows at each "from" bus end of the branch, we can use the following code:
```@repl DCOptimalPowerFlowPower
powers.bus.injection.active
powers.branch.from.active
```

!!! note "Info"
    To better understand the powers associated with buses and branches that are calculated by the [`power`](@ref power(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC optimal power flow analysis](@ref DCOptimalPowerAnalysisTutorials).

---

##### Powers Related to Bus
Instead of calculating powers for all components, users have the option to compute specific quantities for particular components. In this regard, the following function can be utilized to calculate active powers associated with a specific bus:
```@example DCOptimalPowerFlowPower
powers = powerBus(system, model; label = 2)

nothing # hide
```

For instance, to display the active power injection at the bus, the following code can be used:
```@repl DCOptimalPowerFlowPower
powers.injection.active
```

---

##### Powers Related to Branch
Similarly, we can compute the active powers related to a particular branch using the following function:
```@example DCOptimalPowerFlowPower
powers = powerBranch(system, model; label = 2)

nothing # hide
```

For instance, to display the active power flow at the "from" bus end of the branch, we can use the following code:
```@repl DCOptimalPowerFlowPower
powers.from.active
```

---

##### Power Related to Generator
To maintain consistency, users can utilize the [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::DCPowerFlow)) function, which provides the active power output of the specified generator. This function retrieves the corresponding active power output from the `power` field of the `Model` type. For example:
```@example DCOptimalPowerFlowPower
powers = powerGenerator(system, model; label = 2)

nothing # hide
```

To display the output active power of the generator, we can use the following code:
```@repl DCOptimalPowerFlowPower
powers.output.active
```
