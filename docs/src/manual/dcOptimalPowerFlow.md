# [DC Optimal Power Flow](@id DCOptimalPowerFlowManual)
Similar to [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual), JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, enabling users to manipulate these models using the standard functions provided by JuMP. JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the DC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `dc` model. After that, create the `DCOptimalPowerFlow` composite type to establish the DC optimal power flow framework using the function:
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow).

To solve the DC optimal power flow problem and acquire bus voltage angles and generator active power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)).

After obtaining the solution for DC optimal power flow, JuliaGrid offers a post-processing analysis function to compute powers associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)).

Additionally, there are specialized functions dedicated to calculating specific types of active powers related to particular buses or branches:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::DCPowerFlow)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::DCPowerFlow)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::DCPowerFlow)),
* [`toPower`](@ref toPower(::PowerSystem, ::DCPowerFlow)).

---

## [Optimal Power Flow Model](@id DCOptimalPowerFlowModelManual)
To set up the DC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
```@example DCOptimalPowerFlow
using JuliaGrid # hide
using JuMP, HiGHS

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05)

@branch(minDiffAngle = -3.1, maxDiffAngle = 3.1, longTerm = 0.12)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

@generator(minActive = 0.0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.6, maxActive = 0.8)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.1, maxActive = 0.3)
addGenerator!(system; label = "Generator 3", bus = "Bus 2", active = 0.2, maxActive = 0.4)

cost!(system; label = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; label = "Generator 2", active = 1, piecewise =  [8.0 11.0; 14.0 17.0])
cost!(system; label = "Generator 3", active = 1, piecewise =  [6.8 12.3; 8.7 16.8; 11.2 19.8])

dcModel!(system)

nothing # hide
```

Next, the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function is utilized to formulate the DC optimal power flow problem:
```@example DCOptimalPowerFlow
analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)

nothing # hide
```

---

## [Optimization Variables](@id DCOptimizationVariablesManual)
In the DC optimal power flow, the active power outputs of the generators are represented as linear functions of the bus voltage angles. Therefore, the variables in this model are the active power outputs of the generators and the bus voltage angles:
```@repl DCOptimalPowerFlow
JuMP.all_variables(analysis.jump)
```

Furthermore, it is important to highlight that when dealing with linear piecewise cost functions comprising multiple segments, as exemplified in the case of `Generator 3`, JuliaGrid automatically generates helper optimization variables, such as `actwise[3]`, and formulates a set of linear constraints to appropriately handle these cost functions. However, in instances where a linear piecewise cost function consists of only a single segment, as demonstrated by `Generator 2`, the function is modelled as a standard linear function, eliminating the necessity for additional helper optimization variables.

Please note that JuliaGrid keeps references to all variables categorized into three fields:
```@repl DCOptimalPowerFlow
fieldnames(typeof(analysis.variable))
```

---

##### Add Variables
The user has the ability to easily add new variables to the defined DC optimal power flow model by using the [`@variable`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@variable) macro from the JuMP package. Here is an example:
```@example DCOptimalPowerFlow
JuMP.@variable(analysis.jump, newVariable)
nothing # hide
```

We can verify that the new variable is included in the defined model by using the function:
```@repl DCOptimalPowerFlow
JuMP.is_valid(analysis.jump, newVariable)
```

---

##### Delete Variables
To delete a variable, the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function from the JuMP package can be used:
```@example DCOptimalPowerFlow
JuMP.delete(analysis.jump, newVariable)
```

After deletion, the variable is no longer part of the model:
```@repl DCOptimalPowerFlow
JuMP.is_valid(analysis.jump, newVariable)
```

---

## [Constraint Functions](@id DCConstraintFunctionsManual)
JuliGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `DCOptimalPowerFlow` composite type. These constraints are divided into six fields:
```@repl DCOptimalPowerFlow
fieldnames(typeof(analysis.constraint))
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [DC optimal power flow](@ref DCOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl DCOptimalPowerFlow
print(system.bus.label, analysis.constraint.slack.angle)
```

Users have the flexibility to modify this constraint by changing which bus serves as the slack bus and adjusting the value of the bus angle. This can be achieved using the [`updateBus!`](@ref updateBus!) function, for example:
```@example DCOptimalPowerFlow
updateBus!(system, analysis; label = "Bus 1", angle = -0.1)
nothing # hide
```
Subsequently, the updated slack constraint can be inspected as follows:
```@repl DCOptimalPowerFlow
print(system.bus.label, analysis.constraint.slack.angle)
```

---

##### Active Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active power balance equations defined for each bus. The constant terms in these equations are determined by the `active` and `conductance` keywords within the [`addBus!`](@ref addBus!) function. Additionally, if there are phase shift transformers in the system, the constant terms can also be affected by the `shiftAngle` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
print(system.bus.label, analysis.constraint.balance.active)
```

Users possess the flexibility to adjust these constraints using any of the following functions: [`updateBus!`](@ref updateBus!), [`updateBranch!`](@ref updateBranch!), or [`updateGenerator!`](@ref updateGenerator!). An example of this flexibility is illustrated below:
```@example DCOptimalPowerFlow
updateBus!(system, analysis; label = "Bus 3", active = 0.1)
updateGenerator!(system, analysis; label = "Generator 2", status = 0)
nothing # hide
```
Subsequently, the updated set of active power balance constraints can be examined as follows:
```@repl DCOptimalPowerFlow
print(system.bus.label, analysis.constraint.balance.active)
```

---

##### Voltage Angle Difference Constraints
The `voltage` field contains references to the inequality constraints associated with the minimum and maximum bus voltage angle difference between the "from" and "to" bus ends of each branch. These values are specified using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
print(system.branch.label, analysis.constraint.voltage.angle)
```

Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

Additionally, by employing the [`updateBranch!`](@ref updateBranch!) function, you have the ability to modify these specific constraints as follows:
```@example DCOptimalPowerFlow
updateBranch!(system, analysis; label = "Branch 1", minDiffAngle = -1.7, maxDiffAngle = 1.7)
nothing # hide
```

Subsequently, the updated set of voltage angle difference constraints can be examined as follows:
```@repl DCOptimalPowerFlow
print(system.branch.label, analysis.constraint.voltage.angle)
```

---

##### Active Power Flow Constraints
The `flow` field contains references to the inequality constraints associated with the active power flow limits at the "from" and "to" bus ends of each branch. These limits are specified using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl DCOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.active)
```
Please note that if the limit constraints are set to `longTerm = 0.0` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

Additionally, by employing the [`updateBranch!`](@ref updateBranch!) function, you have the ability to modify these specific constraints, for example:
```@example DCOptimalPowerFlow
updateBranch!(system, analysis; label = "Branch 1", status = 0)
updateBranch!(system, analysis; label = "Branch 2", reactance = 0.03, longTerm = 0.14)
nothing # hide
```

Subsequently, the updated set of active power flow constraints can be examined as follows:
```@repl DCOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.active)
```

---

##### Active Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active power outputs of the generators. These limits are specified using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function:
```@repl DCOptimalPowerFlow
print(system.generator.label, analysis.constraint.capability.active)
```

As demonstrated, the active power output of `Generator 2` is currently fixed at zero due to the earlier action of setting this generator out-of-service. Consequently, you can adjust these specific constraints using the [`updateGenerator!`](@ref updateGenerator!) function, for example:
```@example DCOptimalPowerFlow
updateGenerator!(system, analysis; label = "Generator 2", status = 1, maxActive = 0.5)
nothing # hide
```

Subsequently, the updated set of active power capability constraints can be examined as follows:
```@repl DCOptimalPowerFlow
print(system.generator.label, analysis.constraint.capability.active)
```

It is important to note that by bringing back `Generator 2` into service, it will also have an impact on the balance constraint, which will once again be influenced by the generator's output.

---

##### Active Power Piecewise Constraints
In the context of active power modelling, the `piecewise` field serves as a reference to the inequality constraints related to linear piecewise cost functions. These constraints are created using the [`cost!`](@ref cost!) function with `active = 1` specified when dealing with linear piecewise cost functions comprising multiple segments. JuliaGrid takes care of establishing the appropriate inequality constraints for each segment of the linear piecewise cost:
```@repl DCOptimalPowerFlow
print(system.generator.label, analysis.constraint.piecewise.active)
```

It is worth noting that these constraints can also be automatically updated using the [`cost!`](@ref cost!) function, and readers can find more details in the section about the objective function.

---

##### Add Constraints
Users can effortlessly introduce additional constraints into the defined DC optimal power flow model by utilizing the [`addBranch!`](@ref addBranch!) or [`addGenerator!`](@ref addGenerator!) functions. Specifically, if a user wishes to include a new branch or generator in an already defined `PowerSystem` and `DCOptimalPowerFlow` type, using these functions will automatically add and update all constraints:
```@example DCOptimalPowerFlow
addBranch!(system, analysis; label = "Branch 4", from = "Bus 1", to = "Bus 2", reactance = 1)
addGenerator!(system, analysis; label = "Generator 4", bus = "Bus 1", maxActive = 0.2)
nothing # hide
```

As a result, the flow and capability constraints will be adjusted as follows:
```@repl DCOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.active)
print(system.generator.label, analysis.constraint.capability.active)
```

---

##### Add User-Defined Constraints
Users also have the option to include their custom constraints within the established DC optimal power flow model by employing the [`@constraint`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@constraint) macro. For example, the addition of a new constraint can be achieved as follows:
```@example DCOptimalPowerFlow
JuMP.@constraint(analysis.jump, 0.0 <= analysis.jump[:active][4] <= 0.3)
nothing # hide
```

---

##### Delete Constraints
To delete a constraint, users can make use of the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function from the JuMP package. When handling constraints that have been internally created, users can refer to the constraint references stored in the `constraint` field of the `DCOptimalPowerFlow` type.

For example, if the intention is to eliminate constraints related to the capability of `Generator 4`, the following code snippet can be employed:
```@example DCOptimalPowerFlow
JuMP.delete(analysis.jump, analysis.constraint.capability.active[4])
nothing # hide
```

!!! note "Info"
    In the event that a user deletes a constraint and subsequently executes a function that updates bus, branch, or generator parameters, and if the deleted constraint is affected by these functions, JuliaGrid will automatically reinstate that constraint. Users should exercise caution when deleting constraints, as this action is considered potentially harmful since it operates independently of power system data.

---

## [Objective Function](@id DCObjectiveFunctionManual)
The objective function of the DC optimal power flow is constructed using polynomial and linear piecewise cost functions of the generators, which are defined using the [`cost!`](@ref cost!) functions. It is important to note that only polynomial cost functions up to the second degree are included in the objective. If there are polynomials of higher degrees, JuliaGrid will exclude them from the objective function.

In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active power outputs of the generators and the bus voltage angles is as follows:
```@repl DCOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

Additionally, JuliaGrid stores the objective function in a separate variable, allowing users to access it by referencing the variable `analysis.objective`.

---

##### Update Objective Function
By utilizing the [`cost!`](@ref cost!) functions, users have the flexibility to modify the objective function by adjusting polynomial or linear piecewise cost coefficients or by changing the type of polynomial or linear piecewise function employed. For instance, consider `Generator 3`, which incorporates a piecewise cost structure with three segments. In essence, this structure generates a helper variable with additional constraints. Now, let us define a polynomial function for this generator and set it to use `active = 2` as follows:
```@example DCOptimalPowerFlow
cost!(system, analysis; label = "Generator 3", active = 2, polynomial = [853.4; 257; 40])
```

This results in the updated objective function, which can be observed as follows:
```@repl DCOptimalPowerFlow
analysis.objective
```

---

##### User-Defined Objective Function
Users can modify the objective function using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_objective_function) function from the JuMP package. This operation is considered destructive because it is independent of power system data; however, in certain scenarios, it may be more straightforward than using the [`cost!`](@ref cost!) function for updates. Moreover, using this methodology, users can combine a defined function with a newly defined expression. Here is an example of how it can be achieved:
```@example DCOptimalPowerFlow
expr = 100.2 * analysis.variable.active[1] * analysis.variable.active[1] + 123

JuMP.set_objective_function(analysis.jump, analysis.objective - expr)
```

You can now observe the updated objective function as follows:
```@repl DCOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

---

## [Setup Primal Starting Values](@id SetupPrimalStartingValuesManual)
In JuliaGrid, the assignment of primal starting values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function is executed. Primal starting values are determined based on the `voltage` and `power` fields within the `DCOptimalPowerFlow` type. By default, these values are initially established using the active power outputs of the generators and the initial bus voltage angles:
```@repl DCOptimalPowerFlow
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```
You have the flexibility to adjust these values to your specifications, and they will be utilized as the primal starting values when you run the [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function.

---

##### Using DC Power Flow
In this perspective, users have the capability to conduct the DC power flow analysis and leverage the resulting solution to configure primal starting values. Here is an illustration of how this can be achieved:
```@example DCOptimalPowerFlow
flow = dcPowerFlow(system)
solve!(system, flow)
```

After obtaining the solution, we can calculate the active power outputs of the generators and utilize the bus voltage angles to set the starting values. In this case, the `power` and `voltage` fields of the `DCOptimalPowerFlow` type can be employed to store the new starting values:
```@example DCOptimalPowerFlow
for (key, value) in system.generator.label
    analysis.power.generator.active[value] = generatorPower(system, flow; label = key)
end

for i = 1:system.bus.number
    analysis.voltage.angle[i] = flow.voltage.angle[i]
end
```

---

##### Using DC Optimal Power Flow
Performing repeated executions of the DC optimal power flow problem, and opting to reuse the existing `DCOptimalPowerFlow` type without generating a new instance offers the benefit of a "warm start". In such a situation, the initial primal values for the subsequent solving step align with the solution achieved in the prior step. Additional information can be found in the section dedicated to [Reusing the Optimal Power Flow Model](@ref DCReusingOptimalPowerFlowModelManual).

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionManual)
To establish the DC optimal power flow problem, you can utilize the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. After setting up the problem, you can use the [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function to compute the optimal values for the active power outputs of the generators and the bus voltage angles. Also, to turn off the solver output within the REPL, we use the [`set_silent`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_silent) function before calling [`solve!`](@ref solve!(::PowerSystem, ::DCOptimalPowerFlow)) function. Here is an example:
```@example DCOptimalPowerFlow
JuMP.set_silent(analysis.jump)
solve!(system, analysis)
nothing # hide
```

By executing this function, you will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl DCOptimalPowerFlow
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, you can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.objective_value) function:
```@repl DCOptimalPowerFlow
JuMP.objective_value(analysis.jump)
```

---

## [Power Analysis](@id DCOptimalPowerAnalysisManual)
After obtaining the solution from the DC optimal power flow, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function. For instance, let us consider the power system for which we obtained the DC optimal power flow solution:
```@example DCOptimalPowerFlowPower
using JuliaGrid # hide
using JuMP, HiGHS

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, longTerm = 0.12)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

@generator(minActive = 0.0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, maxActive = 0.5)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, maxActive = 0.2)

cost!(system; label = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; label = "Generator 2", active = 1, piecewise =  [10.8 12.3; 14.7 16.8])

dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)

JuMP.set_silent(analysis.jump)
solve!(system, analysis)

nothing # hide
```

Now we can calculate the active powers using the following function:
```@example DCOptimalPowerFlowPower
power!(system, analysis)
nothing # hide
```

Finally, to display the active power injections at each bus and active power flows at each "from" bus end of the branch, we can use the following code:
```@repl DCOptimalPowerFlowPower
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.power.from.active)
```

!!! note "Info"
    To better understand the powers associated with buses and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC optimal power flow analysis](@ref DCOptimalPowerAnalysisTutorials).

To calculate specific quantities for particular components rather than calculating active powers for all components, users can make use of the provided functions below.

---

##### Active Power Injection
To calculate active power injection associated with a specific bus, the function can be used:
```@repl DCOptimalPowerFlowPower
active = injectionPower(system, analysis; label = "Bus 2")
```

---

##### Active Power Injection from Generators
To calculate active power injection from the generators at a specific bus, the function can be used:
```@repl DCOptimalPowerFlowPower
active = supplyPower(system, analysis; label = "Bus 2")
```

---

##### Active Power Flow
Similarly, we can compute the active power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl DCOptimalPowerFlowPower
active = fromPower(system, analysis; label = "Branch 2")
active = toPower(system, analysis; label = "Branch 2")
```

---

## [Reusing Power System Model](@id DCOptimalReusingPowerSystemModelManual)
Similar to what we discussed in the section [Reusing Power System Model](@ref DCReusingPowerSystemModelManual) concerning DC power flow, the `PowerSystem` composite type, along with its previously established `dc` field, offers remarkable versatility. This versatility extends to the use of the `PowerSystem` type in various DC analyses. As demonstrated when we employ initial conditions from DC power flow for DC optimal power flow, the `PowerSystem` type seamlessly integrates across different analysis types.

Furthermore, all fields within the `PowerSystem` type automatically adjust when any of the functions responsible for adding components or modifying their parameters are used. These functions encompass:
* [`addBranch!`](@ref addBranch!),
* [`addGenerator!`](@ref addGenerator!),
* [`updateBus!`](@ref updateBus!),
* [`updateBranch!`](@ref updateBranch!),
* [`updateGenerator!`](@ref updateGenerator!).

This implies that users have the flexibility to add or update parameters after creating the `PowerSystem` composite type. Subsequently, they can utilize [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) to establish a DC optimal power flow model. However, as consistently emphasized throughout this manual, it is significantly more advantageous to reuse the optimal power flow model instead.

---

## [Reusing Optimal Power Flow Model](@id DCReusingOptimalPowerFlowModelManual)
Efficiently modelling and solving large-scale power systems requires reusing the `DCOptimalPowerFlow` type, avoiding the need to run [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow). Constructing an optimal power flow model can be time-consuming, especially for large systems. By creating the `DCOptimalPowerFlow` composite type once, users can easily adapt it to changes in the power system's structure, saving computational resources and time. This simplifies dynamic power system modifications without recreating the entire optimization model.

As demonstrated in this manual, this is achieved by using the `DCOptimalPowerFlow` type as an argument in functions that add or update components within the `PowerSystem` composite type. If these changes are valid and provide accurate solutions, these functions will automatically adjust the composite types, ensuring smooth integration for dynamic power system adjustments while maintaining the integrity of the DC optimal power flow analysis.

---

##### Primal Starting Values
Utilizing the `DCOptimalPowerFlow` type and proceeding directly to the solver offers the advantage of a "warm start". In this scenario, the primal starting values for the subsequent solving step correspond to the solution obtained from the previous step.

In the previous example, we obtained the following solution:
```@repl DCOptimalPowerFlowPower
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```

Now, let us introduce changes to the power system from the previous example and solve it. The primal starting values will now be set to the values shown above.
```@example DCOptimalPowerFlowPower
updateGenerator!(system, analysis; label = "Generator 2", maxActive = 0.08)
solve!(system, analysis)
```

As a result, we obtain a new solution:
```@repl DCOptimalPowerFlowPower
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```