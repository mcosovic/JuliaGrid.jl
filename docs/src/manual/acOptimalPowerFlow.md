# [AC Optimal Power Flow](@id ACOptimalPowerFlowManual)

JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the AC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `ac` model. After that, create the `ACOptimalPowerFlow` composite type to establish the AC optimal power flow framework using the function:
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow).

To solve the AC optimal power flow problem and acquire bus voltage magnitudes and angles, and generator active and reactive power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)).

After obtaining the AC optimal power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)).

Furthermore, there are specialized functions dedicated to calculating specific types of powers related to particular buses, branches, or generators:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::AC)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::ACPowerFlow)),
* [`shuntPower`](@ref shuntPower(::PowerSystem, ::AC)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::AC)),
* [`toPower`](@ref toPower(::PowerSystem, ::AC)),
* [`seriesPower`](@ref seriesPower(::PowerSystem, ::AC)),
* [`chargingPower`](@ref chargingPower(::PowerSystem, ::AC)),
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::ACPowerFlow)).

Likewise, there are specialized functions dedicated to calculating specific types of currents related to particular buses or branches:
* [`injectionCurrent`](@ref injectionCurrent(::PowerSystem, ::AC)),
* [`fromCurrent`](@ref fromCurrent(::PowerSystem, ::AC)),
* [`toCurrent`](@ref toCurrent(::PowerSystem, ::AC)),
* [`seriesCurrent`](@ref seriesCurrent(::PowerSystem, ::AC)).

---

## [Optimal Power Flow Model](@id ACOptimalPowerFlowModelManual)
To set up the AC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
```@example ACOptimalPowerFlow
using JuliaGrid # hide
using JuMP, Ipopt
@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = "Bus 1", type = 3, active = 0.1, angle = -0.1)
addBus!(system; label = "Bus 2", reactive = 0.01, magnitude = 1.1)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, reactance = 0.5, type = 2)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", longTerm = 0.15)

@generator(maxActive = 0.5, minReactive = -0.1, maxReactive = 0.1, status = 0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.4, reactive = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, reactive = 0.1)

cost!(system; label = "Generator 1", active = 2, polynomial = [800.0; 200.0; 80.0])
cost!(system; label = "Generator 2", active = 1, piecewise =  [10.8 12.3; 14.7 16.8; 18 18.1])

cost!(system; label = "Generator 1", reactive = 2, polynomial = [2.0])
cost!(system; label = "Generator 2", reactive = 1, piecewise = [2.0 4.0; 6.0 8.0])

acModel!(system)

nothing # hide
```

Next, the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function is utilized to formulate the AC optimal power flow problem:
```@example ACOptimalPowerFlow
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

nothing # hide
```

---

## [Optimization Variables](@id ACOptimizationVariablesManual)
In the AC optimal power flow model, the active and reactive power outputs of the generators are expressed as nonlinear functions of the bus voltage magnitudes and angles. As a result, the variables in this model include the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles:
```@repl ACOptimalPowerFlow
JuMP.all_variables(analysis.jump)
```

It is important to note that this is not a comprehensive set of optimization variables. When the cost function is defined as a linear piecewise function comprising multiple segments, as illustrated in the case of the active power output cost for `Generator 2`, JuliaGrid automatically generates helper optimization variables named `actwise` and `reactwise`, and formulates a set of linear constraints to effectively address these cost functions. It is worth emphasizing that in instances where a linear piecewise cost function consists of only a single segment, as demonstrated by the reactive power output cost of `Generator 2`, the function is modelled as a standard linear function, obviating the need for additional helper optimization variables.

For the sake of simplicity, we initially assume that both generators are out-of-service. Consequently, the helper variable is not included in the set of optimization variables. However, as we progress through this manual, we will activate the generators, introducing helper variables and additional constraints to the optimization model.

Please be aware that JuliaGrid maintains references to all variables, which are categorized into six fields:
```@repl ACOptimalPowerFlow
fieldnames(typeof(analysis.variable))
```

---

##### Add Variables
The user has the ability to easily add new variables to the defined AC optimal power flow model by using the [`@variable`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@variable) macro from the JuMP package. Here is an example:
```@example ACOptimalPowerFlow
JuMP.@variable(analysis.jump, newVariable)
nothing # hide
```

We can verify that the new variable is included in the defined model by using the function:
```@repl ACOptimalPowerFlow
JuMP.is_valid(analysis.jump, newVariable)
```

---

##### Delete Variables
The variable can be deleted, but this operation is only applicable if the objective function is either affine or quadratic. To achieve this, you can utilize the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function provided by the JuMP package, as demonstrated below:
```@example ACOptimalPowerFlow
JuMP.delete(analysis.jump, newVariable)
```

After deletion, the variable is no longer part of the model:
```@repl ACOptimalPowerFlow
JuMP.is_valid(analysis.jump, newVariable)
```

---

## [Constraint Functions](@id DCConstraintFunctionsManual)
JuliaGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `ACOptimalPowerFlow` composite type. These constraints are divided into six fields:
```@repl ACOptimalPowerFlow
fieldnames(typeof(analysis.constraint))
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [AC optimal power flow](@ref ACOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.slack.angle)
```

Users have the flexibility to modify this constraint by changing which bus serves as the slack bus and by adjusting the value of the bus angle. This can be achieved using the [`updateBus!`](@ref updateBus!) function, for example:
```@example ACOptimalPowerFlow
updateBus!(system, analysis; label = "Bus 1", type = 1)
updateBus!(system, analysis; label = "Bus 2", type = 3, angle = -0.2)
nothing # hide
```

Subsequently, the updated slack constraint can be inspected as follows:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.slack.angle)
```

---

##### Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active and reactive power balance equations defined for each bus. These constraints ensure that the total active and reactive power injected by the generators matches the total active and reactive power demanded at each bus.

The constant term in the active power balance equations is determined by the `active` keyword within the [`addBus!`](@ref addBus!) function, which defines the active power demanded at the bus. You can access the references to the active power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.balance.active)
```

Similarly, the constant term in the reactive power balance equations is determined by the `reactive` keyword within the [`addBus!`](@ref addBus!) function, which defines the reactive power demanded at the bus. You can access the references to the reactive power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.balance.reactive)
```

During the execution of functions that add or update power system components, these constraints are automatically adjusted to reflect the current configuration of the power system. An example of this adaptability is demonstrated below:
```@example ACOptimalPowerFlow
updateBus!(system, analysis; label = "Bus 2", active = 0.5)
updateBranch!(system, analysis; label = "Branch 1", reactance = 0.25)
nothing # hide
```

For example, the updated set of active power balance constraints can be examined as follows:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.balance.active)
```

---

##### Voltage Constraints
The `voltage` field within the model contains references to the inequality constraints associated with the voltage magnitude and voltage angle difference limits. These constraints ensure that the bus voltage magnitudes and the angle differences between the "from" and "to" bus ends of each branch are within specified limits.

The minimum and maximum bus voltage magnitude limits are set using the `minMagnitude` and `maxMagnitude` keywords within the [`addBus!`](@ref addBus!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.voltage.magnitude)
```

Similarly, the minimum and maximum voltage angle difference limits between the "from" and "to" bus ends of each branch are set using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl ACOptimalPowerFlow
print(system.branch.label, analysis.constraint.voltage.angle)
```
Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

Additionally, by employing the [`updateBus!`](@ref updateBus!) and [`updateBranch!`](@ref updateBranch!) functions, user has the ability to modify these specific constraints as follows:
```@example ACOptimalPowerFlow
updateBus!(system, analysis; label = "Bus 1", minMagnitude = 1.0, maxMagnitude = 1.0)
updateBranch!(system, analysis; label = "Branch 1", minDiffAngle = -1.7, maxDiffAngle = 1.7)
nothing # hide
```

Subsequently, the updated set of constraints can be examined as follows:
```@repl ACOptimalPowerFlow
print(system.bus.label, analysis.constraint.voltage.magnitude)
print(system.branch.label, analysis.constraint.voltage.angle)
```

---

##### Flow Constraints
The `flow` field contains references to the inequality constraints associated with the apparent power flow, active power flow, or current magnitude limits at the "from" and "to" bus ends of each branch. The type which one of the constraint will be applied is defined according to the `type` keyword within the [`addBranch!`](@ref addBranch!) function, `type = 1` for the apparent power flow, `type = 2` for the active power flow, or `type = 3` for the current magnitude. These limits are specified using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function.

By default, the `longTerm` keyword is linked to apparent power (`type = 1`). However, in the example, we configured it to use active power flow by setting `type = 2`. To access the flow constraints of branches at the "from" bus end, you can utilize the following code snippet:
```@repl ACOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.from)
```

Similarly, to access the "to" bus end flow constraints of branches you can use the following code snippet:
```@repl ACOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.to)
```
Please note that if the flow constraints are set to `longTerm = 0.0` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

Additionally, by employing the [`updateBranch!`](@ref updateBranch!) function, you have the ability to modify these specific constraints, for example:
```@example ACOptimalPowerFlow
updateBranch!(system, analysis; label = "Branch 1", reactance = 0.8, longTerm = 0.14)
nothing # hide
```

The updated set of flow constraints can be examined as follows:
```@repl ACOptimalPowerFlow
print(system.branch.label, analysis.constraint.flow.from)
print(system.branch.label, analysis.constraint.flow.to)
```

---

##### Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active and reactive power outputs of the generators.

The constraints associated with the minimum and maximum active power output limits of the generators are defined using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access the constraints associated with these limits, you can use the following code snippet:
```@repl ACOptimalPowerFlow
print(system.generator.label, analysis.constraint.capability.active)
```

Similarly, the constraints associated with the minimum and maximum reactive power output limits of the generators are specified using the `minReactive` and `maxReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access these constraints, you can use the following code snippet:
```@repl ACOptimalPowerFlow
print(system.generator.label, analysis.constraint.capability.reactive)
```

As demonstrated, the active and reactive power outputs of `Generator 1` and `Generator 2` are currently fixed at zero due to previous actions that set these generators out-of-service. However, you can modify these specific constraints by utilizing the [`updateGenerator!`](@ref updateGenerator!) function, as shown below:
```@example ACOptimalPowerFlow
updateGenerator!(system, analysis; label = "Generator 1", status = 1)
updateGenerator!(system, analysis; label = "Generator 2", status = 1, minActive = 0.1)
nothing # hide
```

Subsequently, the updated set of constraints can be examined as follows:
```@repl ACOptimalPowerFlow
print(system.generator.label, analysis.constraint.capability.active)
print(system.generator.label, analysis.constraint.capability.reactive)
```

---

##### Power Piecewise Constraints
In the context of cost modelling, the `piecewise` field acts as a reference to the inequality constraints associated with linear piecewise cost functions. These constraints are established using the [`cost!`](@ref cost!) function, with `active = 1` or `reactive = 1` specified when working with linear piecewise cost functions that consist of multiple segments. In our example, only the active power cost of `Generator 2` is modelled as a linear piecewise function with two segments, and JuliaGrid takes care of setting up the appropriate inequality constraints for each segment:
```@repl ACOptimalPowerFlow
print(system.generator.label, analysis.constraint.piecewise.active)
```

It is worth noting that these constraints can also be automatically updated using the [`cost!`](@ref cost!) function. Readers can find more details in the section discussing the objective function. 

As mentioned at the beginning, a linear piecewise cost functions with multiple segments will also introduce helper variables that are added to the objective function. In this specific example, the helper variable is:   
```@repl ACOptimalPowerFlow
analysis.variable.actwise[2]
```

---


##### Add Constraints
Users can effortlessly introduce additional constraints into the defined AC optimal power flow model by utilizing the [`addBranch!`](@ref addBranch!) or [`addGenerator!`](@ref addGenerator!) functions. Specifically, if a user wishes to include a new branch or generator in an already defined `PowerSystem` and `ACOptimalPowerFlow` type, using these functions will automatically add and update all constraints:
```@example ACOptimalPowerFlow
addBranch!(system, analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 1)
addGenerator!(system, analysis; label = "Generator 3", bus = "Bus 2", active = 2, status = 1)
nothing # hide
```

This will affect all constraints related to branches and generators, but it will also update balance constraints to configure the optimization model to match the current state of the power system. For example, you can observe the following updated constraints:
```@repl ACOptimalPowerFlow
print(system.branch.label, analysis.constraint.voltage.angle)
print(system.generator.label, analysis.constraint.capability.active)
```

---

##### Add User-Defined Constraints
Users also have the option to include their custom constraints within the established AC optimal power flow model by employing the [`@constraint`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@constraint) macro. For example, the addition of a new constraint can be achieved as follows:
```@example ACOptimalPowerFlow
JuMP.@constraint(analysis.jump, 0.0 <= analysis.variable.active[3] <= 0.3)
nothing # hide
```

---

##### Delete Constraints
To delete a constraint, users can make use of the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function from the JuMP package. When handling constraints that have been internally created, users can refer to the constraint references stored in the `constraint` field of the `ACOptimalPowerFlow` type.

For example, if the intention is to eliminate constraints related to the capability of `Generator 3`, the following code snippet can be employed:
```@example ACOptimalPowerFlow
JuMP.delete(analysis.jump, analysis.constraint.capability.active[3])
nothing # hide
```

!!! note "Info"
    In the event that a user deletes a constraint and subsequently executes a function that updates bus, branch, or generator parameters, and if the deleted constraint is affected by these functions, JuliaGrid will automatically reinstate that constraint. Users should exercise caution when deleting constraints, as this action is considered potentially harmful since it operates independently of power system data.

---

## [Objective Function](@id ACObjectiveFunctionManual)
The objective function of the AC optimal power flow is formulated using polynomial and linear piecewise cost functions associated with the generators, defined using the [`cost!`](@ref cost!) functions.

In the provided example, the objective function to be minimized in order to obtain optimal values for the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles, is as follows:
```@repl ACOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

JuliaGrid also stores the objective function in a separate variable, which can be accessed by referring to the variable `analysis.objective`. In this variable, the objective function is organized in a way that separates the quadratic and nonlinear components of the objective function.

---

##### Update Objective Function
By utilizing the [`cost!`](@ref cost!) functions, users have the flexibility to modify the objective function by adjusting polynomial or linear piecewise cost coefficients or by changing the type of polynomial or linear piecewise function employed. For instance, consider `Generator 1`, which originally employs a quadratic polynomial cost function for active power. You can redefine the cost function for this generator as a cubic polynomial and thereby define a nonlinear objective function, as shown below:
```@example ACOptimalPowerFlow
cost!(system, analysis; label = "Generator 1", active = 2, polynomial = [631; 257; 40; 5.0])
nothing # hide
```

This leads to an updated objective function, which can be examined as follows:
```@repl ACOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

---

##### User-Defined Objective Function
Users can modify the objective function using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_objective_function) function from the JuMP package. This operation is considered destructive because it is independent of power system data; however, in certain scenarios, it may be more straightforward than using the [`cost!`](@ref cost!) function for updates. Moreover, using this methodology, users can combine a defined function with a newly defined expression.

In this context, we can utilize the saved objective function within the `objective` field of the `ACOptimalPowerFlow` type. For example, you can easily eliminate nonlinear parts and alter the quadratic component of the objective as follows:
```@example ACOptimalPowerFlow
expr = 5.0 * analysis.variable.active[1] * analysis.variable.active[1]
JuMP.set_objective_function(analysis.jump, analysis.objective.quadratic - expr)
```

You can now observe the updated objective function as follows:
```@repl ACOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

---

## [Setup Primal Starting Values](@id ACSetupPrimalStartingValuesManual)
In JuliaGrid, the assignment of starting primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function is executed. Starting primal values are determined based on the `generator` and `voltage` fields within the `ACOptimalPowerFlow` type. By default, these values are initially established using the active and reactive power outputs of the generators and the initial bus voltage magnitudes angles:
```@repl ACOptimalPowerFlow
generator = analysis.power.generator;
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```
You have the flexibility to adjust these values to your specifications, and they will be utilized as the starting primal values when you run the [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function.

---

##### Using AC Power Flow
In this perspective, users have the capability to conduct the AC power flow analysis and leverage the resulting solution to configure starting primal values. Here is an illustration of how this can be achieved:
```@example ACOptimalPowerFlow
flow = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, flow)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, flow)
end
```

After obtaining the solution, we can calculate the active power outputs of the generators and utilize the bus voltage angles to set the starting values. In this case, the `generator` and `voltage` fields of the `ACOptimalPowerFlow` type can be employed to store the new starting values:
```@example ACOptimalPowerFlow
for (key, value) in system.generator.label
    active, reactive = generatorPower(system, flow; label = key)
    analysis.power.generator.active[value] = active
    analysis.power.generator.reactive[value] = reactive
end

for i = 1:system.bus.number
    analysis.voltage.magnitude[i] = flow.voltage.magnitude[i]
    analysis.voltage.angle[i] = flow.voltage.angle[i]
end
```

---

##### Using AC Optimal Power Flow
Performing repeated executions of the AC optimal power flow problem, and opting to reuse the existing `ACOptimalPowerFlow` type without generating a new instance offers the benefit of a "warm start". In such a situation, the initial primal values for the subsequent solving step align with the solution achieved in the prior step. Additional information can be found in the section dedicated to [Reusing the Optimal Power Flow Model](@ref ACReusingOptimalPowerFlowModelManual).

---

## [Optimal Power Flow Solution](@id ACOptimalPowerFlowSolutionManual)
To establish the AC optimal power flow problem, you can utilize the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. After setting up the problem, you can use the [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function to compute the optimal values for the active and reactive power outputs of the generators and the bus voltage magnitudes angles. Also, to turn off the solver output within the REPL, we use the [`set_silent`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_silent) function before calling [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function. Here is an example:
```julia ACOptimalPowerFlow
JuMP.set_silent(analysis.jump)
solve!(system, analysis)
```
```@setup ACOptimalPowerFlow
JuMP.set_silent(analysis.jump)
solve!(system, analysis)
nothing # hide
```

By executing this function, you will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl ACOptimalPowerFlow
generator = analysis.power.generator;
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, you can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.objective_value) function:
```@repl ACOptimalPowerFlow
JuMP.objective_value(analysis.jump)
```

---

## [Power and Current Analysis](@id ACOptimalPowerCurrentAnalysisManual)
After obtaining the solution from the AC optimal power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions. For instance, let us consider the power system for which we obtained the AC optimal power flow solution:
```@example ACOptimalPowerFlowPower
using JuliaGrid # hide
using JuMP, Ipopt

@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(minMagnitude = 0.9, maxMagnitude = 1.1)
addBus!(system; label = "Bus 1", type = 3, magnitude = 1.05, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, reactive = 0.01, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05, reactive = 0.02)

@branch(resistance = 0.5, reactance = 1.0, conductance = 1e-4, susceptance = 0.01)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", longTerm = 0.15)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", longTerm = 0.10)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", longTerm = 0.25)

@generator(maxActive = 0.5, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.5)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, reactive = 0.1)

cost!(system; label = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; label = "Generator 2", active = 1, piecewise =  [10.8 12.3; 14.7 16.8; 18 18.1])

acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

JuMP.set_silent(analysis.jump)
solve!(system, analysis)

nothing # hide
```

We can now utilize the provided functions to compute powers and currents. The following functions can be used for this purpose:
```@example ACOptimalPowerFlowPower
power!(system, analysis)
current!(system, analysis)
nothing # hide
```

For instance, if we want to show the active power injections at each bus and the current flow magnitudes at each "from" bus end of the branch, we can employ the following code:
```@repl ACOptimalPowerFlowPower
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.from.magnitude)
```

!!! note "Info"
    To better understand the powers and current associated with buses and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [AC optimal power flow analysis](@ref ACOptimalPowerFlowTutorials).

To calculate specific quantities for particular components rather than calculating powers or currents for all components, users can make use of the provided functions below.

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl ACOptimalPowerFlowPower
active, reactive = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl ACOptimalPowerFlowPower
active, reactive = supplyPower(system, analysis; label = "Bus 2")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl ACOptimalPowerFlowPower
active, reactive = shuntPower(system, analysis; label = "Bus 2")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl ACOptimalPowerFlowPower
active, reactive = fromPower(system, analysis; label = "Branch 2")
active, reactive = toPower(system, analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the total active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl ACOptimalPowerFlowPower
active, reactive = chargingPower(system, analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging or shunt admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the particular branch, the function can be used:
```@repl ACOptimalPowerFlowPower
active, reactive = seriesPower(system, analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl ACOptimalPowerFlowPower
magnitude, angle = injectionCurrent(system, analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl ACOptimalPowerFlowPower
magnitude, angle = fromCurrent(system, analysis; label = "Branch 2")
magnitude, angle = toCurrent(system, analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the "from" bus end to the "to" bus end, you can use the following function:
```@repl ACOptimalPowerFlowPower
magnitude, angle = seriesCurrent(system, analysis; label = "Branch 2")
```

---

## [Reusing Power System Model](@id ACOptimalReusingPowerSystemModelManual)
Similar to what we discussed in the section [Reusing Power System Model](@ref ACReusingPowerSystemModelManual) concerning AC power flow, the `PowerSystem` composite type, along with its previously established `ac` field, offers remarkable versatility. This versatility extends to the use of the `PowerSystem` type in various AC analyses. As demonstrated when we employ initial conditions from AC power flow for AC optimal power flow, the `PowerSystem` type seamlessly integrates across different analysis types.

Furthermore, all fields within the `PowerSystem` type automatically adjust when any of the functions responsible for adding components or modifying their parameters are used. These functions encompass:
* [`addBranch!`](@ref addBranch!),
* [`addGenerator!`](@ref addGenerator!),
* [`updateBus!`](@ref updateBus!),
* [`updateBranch!`](@ref updateBranch!),
* [`updateGenerator!`](@ref updateGenerator!).

This implies that users have the flexibility to add or update parameters after creating the `PowerSystem` composite type. Subsequently, they can utilize [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) to establish a AC optimal power flow model. However, as consistently emphasized throughout this manual, it is significantly more advantageous to reuse the optimal power flow model instead.

---

## [Reusing Optimal Power Flow Model](@id ACReusingOptimalPowerFlowModelManual)
Efficiently modelling and solving large-scale power systems requires reusing the `ACOptimalPowerFlow` type, avoiding the need to run [`acOptimalPowerFlow`](@ref acOptimalPowerFlow). Constructing an optimal power flow model can be time-consuming, especially for large systems. By creating the `ACOptimalPowerFlow` composite type once, users can easily adapt it to changes in the power system's structure, saving computational resources and time. This simplifies dynamic power system modifications without recreating the entire optimization model.

As demonstrated in this manual, this is achieved by using the `ACOptimalPowerFlow` type as an argument in functions that add or update components within the `PowerSystem` composite type. If these changes are valid and provide accurate solutions, these functions will automatically adjust the composite types, ensuring smooth integration for dynamic power system adjustments while maintaining the integrity of the DC optimal power flow analysis.

---

##### Starting Primal Values
Utilizing the `ACOptimalPowerFlow` type and proceeding directly to the solver offers the advantage of a "warm start". In this scenario, the starting primal values for the subsequent solving step correspond to the solution obtained from the previous step.

In the previous example, we obtained the following solution:
```@repl ACOptimalPowerFlowPower
generator = analysis.power.generator;
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Now, let us introduce changes to the power system from the previous example and solve it. The primal starting values will now be set to the values shown above.
```@example ACOptimalPowerFlowPower
updateGenerator!(system, analysis; label = "Generator 2", maxActive = 0.08)
solve!(system, analysis)
```

As a result, we obtain a new solution:
```@repl ACOptimalPowerFlowPower
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users retain the flexibility to reset these initial primal values to their default configurations at any juncture. This can be accomplished by utilizing the active and reactive power outputs of the generators and the initial bus voltage magnitudes and angles extracted from the `PowerSystem` composite type, employing the [`startingPrimal!`](@ref startingPrimal!) function:
```@example ACOptimalPowerFlowPower
startingPrimal!(system, analysis)
```

These values are precisely identical to what we would obtain if we executed the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function following all the updates we performed:
```@repl ACOptimalPowerFlowPower
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```