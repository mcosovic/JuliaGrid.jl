# [AC Optimal Power Flow](@id ACOptimalPowerFlowManual)

JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the AC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `ac` model. After that, create the `ACOptimalPowerFlow` composite type to establish the AC optimal power flow framework using the function:
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow).

To solve the AC optimal power flow problem and acquire bus voltage magnitudes and angles, and generator active and reactive power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)).

After obtaining the AC optimal power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)).

Furthermore, there are specialized functions dedicated to calculating specific types of powers related to particular buses or branches:
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::AC)),
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow)),
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::AC)),
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::AC)),
* [`powerTo`](@ref powerTo(::PowerSystem, ::AC)),
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::AC)),
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::AC)),

Likewise, there are specialized functions dedicated to calculating specific types of currents related to particular buses or branches:
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::AC)),
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::AC)),
* [`currentTo`](@ref currentTo(::PowerSystem, ::AC)),
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::AC)).

---

## [Optimization Variables](@id ACOptimizationVariablesManual)
To set up the AC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
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

acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

nothing # hide
```

In the AC optimal power flow model, the active and reactive power outputs of the generators are expressed as nonlinear functions of the bus voltage magnitudes and angles. As a result, the variables in this model include the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles:
```@repl ACOptimalPowerFlow
JuMP.all_variables(analysis.jump)
```

Additionally, when dealing with linear piecewise cost functions that have more than one segment, JuliaGrid automatically generates a helper variable for each linear segment. This is done using a constrained cost variable approach, where the original cost function is replaced by the helper variable and a set of linear constraints.

Please note that in the given example, we include reactive cost functions for each generator for the sake of completeness. However, in typical scenarios, only active cost functions are considered.

---

##### Add Variables
The user has the ability to easily add new variables to the defined AC optimal power flow model by using the [`@variable`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@variable) macro from the JuMP package. Here is an example:
```@example ACOptimalPowerFlow
JuMP.@variable(analysis.jump, new)
nothing # hide
```

We can verify that the new variable is included in the defined model by using the function:
```@repl ACOptimalPowerFlow
JuMP.is_valid(analysis.jump, new)
```

---

##### Delete Variables
To delete a variable, the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function from the JuMP package can be used:
```@example ACOptimalPowerFlow
JuMP.delete(analysis.jump, new)
```

After deletion, the variable is no longer part of the model:
```@repl ACOptimalPowerFlow
JuMP.is_valid(analysis.jump, new)
```

---

## [Constraint Functions](@id ACConstraintFunctionsManual)
JuliGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `ACOptimalPowerFlow` composite type. These constraints are divided into six fields:
```@repl ACOptimalPowerFlow
fieldnames(typeof(analysis.constraint))
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [AC optimal power flow](@ref ACOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Slack Bus Constraints
The `slack` field within the model contains references to the equality constraints that enforce fixed values for the bus voltage magnitude and angle at the slack bus. These constraints are set when adding the slack bus using the [`addBus!`](@ref addBus!) function, specifically by specifying the `magnitude` and `angle` keywords. To access the references to these constraints, you can use the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.slack.magnitude
analysis.constraint.slack.angle
```

---

##### Active and Reactive Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active and reactive power balance equations defined for each bus. These constraints ensure that the total active and reactive power injected by the generators matches the total active and reactive power demanded at each bus.

The constant term in the active power balance equations is determined by the `active` keyword within the [`addBus!`](@ref addBus!) function, which defines the active power demanded at the bus. You can access the references to the active power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.balance.active
```

Similarly, the constant term in the reactive power balance equations is determined by the `reactive` keyword within the [`addBus!`](@ref addBus!) function, which defines the reactive power demanded at the bus. You can access the references to the reactive power balance constraints using the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.balance.reactive
```

If you want to exclude these constraints and skip their formation, you can utilize the `balance = false` keyword within the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve active and reactive power balance constraints.

---

##### Voltage Magnitude and Voltage Angle Difference Limit Constraints
The `limit` field within the model contains references to the inequality constraints associated with the voltage magnitude and voltage angle difference limits. These constraints ensure that the bus voltage magnitudes and the angle differences between the "from" and "to" bus ends of each branch are within specified limits.

The minimum and maximum bus voltage magnitude limits are set using the `minMagnitude` and `maxMagnitude` keywords within the [`addBus!`](@ref addBus!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.limit.magnitude
```

Similarly, the minimum and maximum voltage angle difference limits between the "from" and "to" bus ends of each branch are set using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.limit.angle
```
Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

Furthermore, if you want to exclude all limit constraints and skip their formation, you can use the `limit = false` keyword within the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function.

---

##### Rating Constraints
The `rating` field contains references to the inequality constraints associated with the apparent power flow, active power flow, or current magnitude limits at the "from" and "to" bus ends of each branch. The type which one of the constraint will be apllied is defined according to the `type` keyword within the [`addBranch!`](@ref addBranch!) function, `type = 1` for the apparent power flow, `type = 2` for the active power flow, or `type = 3` for the current magnitude. These limits are specified using the `longTerm` keyword within the [`addBranch!`](@ref addBranch!) function.


By default, the `longTerm` keyword is associated with apparent power (`type = 1`). To access the rating constraints of branches at the "from" bus end, you can use the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.rating.from
```

Similarly, to acces the "to" bus end rating constraints of branches you can use the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.rating.to
```

If you want to exclude these constraints and skip their formation, you can use the `rating = false` keyword within the  [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve rating constraints.

---

##### Active and Reactive Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active and reactive power outputs of the generators.

The constraints associated with the minimum and maximum active power output limits of the generators are defined using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access the constraints associated with these limits, you can use the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.capability.active
```

Similarly, the constraints associated with the minimum and maximum reactive power output limits of the generators are specified using the `minReactive` and `maxReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access these constraints, you can use the following code snippet:
```@repl ACOptimalPowerFlow
analysis.constraint.capability.reactive
```

If you want to exclude these constraints and skip their formation, you can use the `capability = false` keyword within the  [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. By specifying this keyword, you indicate that the problem does not involve power capability constraints.

---

##### Active and Reactive Power Piecewise Constraints
The `piecewise` field contains references to the inequality constraints associated with the linear piecewise cost function. In this particular case, we are dealing with a single linear piecewise cost function associated with the active power. This function is defined using the [`addActiveCost!`](@ref addActiveCost!) function, specifying `model = 1`. Consequently, the original cost function is replaced by a helper variable, and a set of linear constraints is established:
```@repl ACOptimalPowerFlow
analysis.constraint.piecewise.active[2]
```
As a result, for the generator labeled as 2, there exists a linear piecewise cost function comprising two segments. JuliaGrid defines the corresponding inequality constraints for each of these segments.

---

##### Add Constraints
Users can effortlessly incorporate additional constraints into the defined AC optimal power flow model using the [`@constraint`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.@constraint) macro. For instance, a new constraint can be added as follows:
```@example ACOptimalPowerFlow
angle = analysis.jump[:angle]

JuMP.@constraint(analysis.jump, -2.1 <= angle[1] - angle[2] <= 2.1)
nothing # hide
```

---

##### Delete Constraints
To delete a constraint, users can utilize the [`delete`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.delete) function from the JuMP package. When dealing with constraints created internally, users can utilize the constraint references stored in the `constraint` field of the `ACOptimalPowerFlow` type. For instance, to delete the first constraint that limits the voltage angle difference, the following code snippet can be employed:
```@example ACOptimalPowerFlow
JuMP.delete(analysis.jump, analysis.constraint.limit.angle[1])
nothing # hide
```

Additionally, if you need to delete constraints based on labels associated with buses, branches, or generators, you can easily define an index for the constraint using the labels stored in a dictionary. For example, let us say you want to delete the voltage angle difference limit constraint related to the second branch:
```@example ACOptimalPowerFlow
index = system.branch.label[2]
JuMP.delete(analysis.jump, analysis.constraint.limit.angle[index])
nothing # hide
```

It is worth noting that if the labels assigned to the buses, branches, or generators follow an increasing ordered set of integers, both approaches to deleting constraints are equivalent.

---

## [Objective Function](@id ACObjectiveFunctionManual)
The objective function of the AC optimal power flow is constructed using polynomial and linear piecewise cost functions of the generators, which are defined using the [`addActiveCost!`](@ref addActiveCost!) and [`addReactiveCost!`](@ref addReactiveCost!) functions.

In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active and reactive power outputs of the generators and the bus voltage magnitudes and angles is as follows:
```@repl ACOptimalPowerFlow
JuMP.objective_function(analysis.jump)
```

---

##### Change Objective
The objective can be modified by the user using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_objective_function) function from the JuMP package. Here is an example of how it can be done:
```@example ACOptimalPowerFlow
active = analysis.jump[:active]
helperActive = analysis.jump[:helperActive]
new = JuMP.@expression(analysis.jump, 1100.2 * active[1]^2 + 500 * active[1] + helperActive[1])

JuMP.set_objective_function(analysis.jump, new)
```

---

## [Setup Primal Starting Values](@id ACSetupPrimalStartingValuesManual)
There are two methods available to specify primal starting values for each variable: using the built-in function provided by JuMP or accessing and modifying values directly within the `voltage` and `power` fields of the `ACOptimalPowerFlow` type.

---

##### Using JuMP Functions
One approach is to utilize the [`set_start_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_start_value) function from the JuMP package. This allows us to set primal starting values for the active power outputs of the generators and the bus voltage angles. Here is an example:
```@example ACOptimalPowerFlow
JuMP.set_start_value.(analysis.jump[:active], [0.0, 0.18])
JuMP.set_start_value.(analysis.jump[:reactive], [0.5, 0.1])
JuMP.set_start_value.(analysis.jump[:magnitude], [1.05, 1.0, 1.0])
JuMP.set_start_value.(analysis.jump[:angle], [0.17, 0.13, 0.14])
nothing # hide
```

To inspect the primal starting values that have been set, you can use the [`start_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.start_value) function from JuMP. Here is an example of how you can inspect the starting values for the active power outputs:
We can inspect that starting values are set:
```@repl ACOptimalPowerFlow
JuMP.start_value.(analysis.jump[:active])
```

---

##### Using JuliaGrid Variables
Alternatively, you can rely on the [`solve!`](@ref solve!) function to assign starting values based on the `power` and `voltage` fields. By default, these values are initially defined according to the active and reactive power outputs of the generators and the initial bus voltage magnitudes and angles:
```@repl ACOptimalPowerFlow
[analysis.power.generator.active analysis.power.generator.reactive]
[analysis.voltage.magnitude analysis.voltage.angle]
```
You can modify these values, and they will be used as primal starting values during the execution of the [`solve!`](@ref solve!) function.

!!! warning "Warning"
    Please note that if primal starting values are set using the `set_start_value` function or any other method prior to executing the [`solve!`](@ref solve!) function, the values in the `power` and `voltage` fields will be ignored. This is because the starting point will be considered already defined.

---

##### Using AC Power Flow
Another approach is to perform the AC power flow and use the resulting solution to set primal starting values. Here is an example of how it can be done:
```@example ACOptimalPowerFlow
powerFlow = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, powerFlow)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, powerFlow)
end
```

After obtaining the solution, we can calculate the active and reactive power outputs of the generators and utilize the bus voltage magnitudes and angles to set the starting values. In this case, the `power` and `voltage` fields of the `ACOptimalPowerFlow` type can be employed to store the new starting values:
```@example ACOptimalPowerFlow
for (key, value) in system.generator.label
    generator = powerGenerator(system, powerFlow; label = key)
    analysis.power.generator.active[value] = generator.active
    analysis.power.generator.reactive[value] = generator.reactive
end

for i = 1:system.bus.number
    analysis.voltage.magnitude[i] = powerFlow.voltage.magnitude[i]
    analysis.voltage.angle[i] = powerFlow.voltage.angle[i]
end
```
Also, the user can make use of the [`set_start_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#set_start_value) function to set starting values from the AC power flow.

---

## [Optimal Power Flow Solution](@id ACOptimalPowerFlowSolutionManual)
To establish the AC optimal power flow problem, you can utilize the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. After setting up the problem, you can use the [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function to compute the optimal values for the active and reactive power outputs of the generators and the bus voltage magnitudes angles. Here is an example:
```@example ACOptimalPowerFlow
solve!(system, analysis)
nothing # hide
```

By executing this function, you will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl ACOptimalPowerFlow
[analysis.power.generator.active analysis.power.generator.reactive]
[analysis.voltage.magnitude analysis.voltage.angle]
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, you can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.objective_value) function:
```@repl ACOptimalPowerFlow
JuMP.objective_value(analysis.jump)
```

---

##### Silent Solver Output
To turn off the solver output within the REPL, you can use the [`set_silent`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_silent) function before calling [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)) function. This will suppress the solver's output:
```@example ACOptimalPowerFlow
JuMP.set_silent(analysis.jump)
```

---

## [Power and Current Analysis](@id ACOptimalPowerCurrentAnalysisManual)
After obtaining the solution from the AC optimal power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions. For instance, let us consider the power system for which we obtained the AC optimal power flow solution:
```@example ACOptimalPowerFlowPower
using JuliaGrid # hide
using JuMP, Ipopt # hide

system = powerSystem()

@bus(minMagnitude = 0.9, maxMagnitude = 1.1)
addBus!(system; label = 1, type = 3, magnitude = 1.05, angle = 0.17)
addBus!(system; label = 2, active = 0.1, reactive = 0.01, conductance = 0.04)
addBus!(system; label = 3, active = 0.05, reactive = 0.02)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, conductance = 1e-4, susceptance = 0.01)
addBranch!(system; from = 1, to = 2, resistance = 0.5, reactance = 1.0, longTerm = 0.15)
addBranch!(system; from = 1, to = 3, resistance = 0.5, reactance = 1.0, longTerm = 0.10)
addBranch!(system; from = 2, to = 3, resistance = 0.5, reactance = 1.0, longTerm = 0.25)

@generator(minActive = 0.0, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.5, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, reactive = 0.1, maxActive = 0.2)

addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
addActiveCost!(system; label = 2, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

addReactiveCost!(system; label = 1, model = 2, polynomial = [30.2; 20; 5])
addReactiveCost!(system; label = 2, model = 2, polynomial = [10.3; 5.1; 1.2])

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
analysis.power.injection.active
analysis.current.from.magnitude
```

!!! note "Info"
    To better understand the powers and current associated with buses and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [AC optimal power flow analysis](@ref ACOptimalPowerAnalysisTutorials).

To calculate specific quantities for particular components rather than calculating powers or currents for all components, users can make use of the provided functions below.

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@example ACOptimalPowerFlowPower
injection = powerInjection(system, analysis; label = 1)
nothing # hide
```

Consequently, the outcomes will be as follows:
```@repl ACOptimalPowerFlowPower
injection.active
injection.reactive
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@example ACOptimalPowerFlowPower
supply = powerSupply(system, analysis; label = 1)
nothing # hide
```

The outcomes will be as follows:
```@repl ACOptimalPowerFlowPower
supply.active
supply.reactive
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@example ACOptimalPowerFlowPower
shunt = powerShunt(system, analysis; label = 2)
nothing # hide
```

The outcomes will be as follows:
```@repl ACOptimalPowerFlowPower
shunt.active
shunt.reactive
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@example ACOptimalPowerFlowPower
from = powerFrom(system, analysis; label = 2)
to = powerTo(system, analysis; label = 2)
nothing # hide
```

The results at the "from" bus end are as follows:
```@repl ACOptimalPowerFlowPower
from.active
from.reactive
```

Similarly, the results at "to" bus end will be as follows:
```@repl ACOptimalPowerFlowPower
to.active
to.reactive
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@example ACOptimalPowerFlowPower
charging = powerCharging(system, analysis; label = 1)
nothing # hide
```

The outcomes for the charging admittance at the "from" bus end are provided below:
```@repl ACOptimalPowerFlowPower
charging.from.active
charging.from.reactive
```

Likewise, the outcomes for the charging admittance at the "to" bus end are as follows:
```@repl ACOptimalPowerFlowPower
charging.to.active
charging.to.reactive
```

Active powers indicate active losses within the branch's charging or shunt admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the particular branch, the function can be used:
```@example ACOptimalPowerFlowPower
series = powerSeries(system, analysis; label = 2)
nothing # hide
```

The outcomes will be as follows:
```@repl ACOptimalPowerFlowPower
series.active
series.reactive
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@example ACOptimalPowerFlowPower
injection = currentInjection(system, analysis; label = 1)
nothing # hide
```

Consequently, the outcomes will be as follows:
```@repl ACOptimalPowerFlowPower
injection.magnitude
injection.angle
```

---

##### Current Flow
We can compute the current flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@example ACOptimalPowerFlowPower
from = currentFrom(system, analysis; label = 2)
to = currentTo(system, analysis; label = 2)
nothing # hide
```

The results at the "from" bus end are as follows:
```@repl ACOptimalPowerFlowPower
from.magnitude
from.angle
```

Similarly, the results at "to" bus end will be as follows:
```@repl ACOptimalPowerFlowPower
to.magnitude
to.angle
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the "from" bus end to the "to" bus end, you can use the following function:
```@example ACOptimalPowerFlowPower
series = currentSeries(system, analysis; label = 2)
nothing # hide
```

The results are as follows:
```@repl ACOptimalPowerFlowPower
series.magnitude
series.angle
```
