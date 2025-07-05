# [AC Optimal Power Flow](@id ACOptimalPowerFlowManual)
JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the AC optimal power flow, we first need to have the `PowerSystem` type that has been created with the AC model. After that, create the `AcOptimalPowerFlow` type to establish the AC optimal power flow framework using the function:
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow).

---

To solve the AC optimal power flow problem and obtain generator active and reactive power outputs, as well as bus voltage magnitudes and angles, users can use the following function:
* [`solve!`](@ref solve!(::AcOptimalPowerFlow)).

After solving the AC optimal power flow, JuliaGrid provides functions for computing powers and currents:
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AcPowerFlow)).

Alternatively, instead of using functions responsible for solving optimal power flow and computing powers and currents, users can use the wrapper function:
* [`powerFlow!`](@ref powerFlow!(::AcOptimalPowerFlow)).

Users can also access specialized functions for computing specific types of [powers](@ref ACPowerAnalysisAPI) or [currents](@ref ACCurrentAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## [Optimal Power Flow Model](@id ACOptimalPowerFlowModelManual)
To set up the AC optimal power flow, we begin by creating the model. To illustrate this, consider the following:
```@example acopf
using JuliaGrid # hide
using JuMP, Ipopt
@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = "Bus 1", type = 3, active = 0.1, angle = -0.1)
addBus!(system; label = "Bus 2", reactive = 0.01, magnitude = 1.1)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, reactance = 0.5, type = 1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", maxFromBus = 0.15)

@generator(maxActive = 0.5, minReactive = -0.1, maxReactive = 0.1, status = 0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.4, reactive = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, reactive = 0.1)

cost!(system; generator = "Generator 1", active = 2, polynomial = [800.0; 200.0; 80.0])
cost!(system; generator = "Generator 2", active = 1, piecewise = [10 12.3; 14.7 16.8; 18 19])

cost!(system; generator = "Generator 1", reactive = 2, polynomial = [2.0])
cost!(system; generator = "Generator 2", reactive = 1, piecewise = [2.0 4.0; 6.0 8.0])

acModel!(system)
nothing # hide
```

Next, the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function is utilized to formulate the AC optimal power flow problem:
```@example acopf
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
nothing # hide
```

!!! note "Info"
    All non-box two-sided constraints are modeled as intervals by default. However, users can choose to represent them as two separate constraints, one for the lower bound and one for the upper bound, by setting:
    ```julia DCPowerFlowSolution
    analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; interval = false)
    ```
    Although this approach may be less efficient in terms of model creation and could lead to longer execution times depending on the solver, it allows for precise definition of the starting dual values.

---

## [Optimization Variables](@id ACOptimizationVariablesManual)
In the AC optimal power flow model, the active and reactive power outputs of the generators are expressed as nonlinear functions of the bus voltage magnitudes and angles. As a result, the variables in this model include the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles:
```@repl acopf
JuMP.all_variables(analysis.method.jump)
```

It is important to note that this is not a comprehensive set of optimization variables. When the cost function is defined as a piecewise linear function comprising multiple segments, as illustrated in the case of the active power output cost for `Generator 2`, JuliaGrid automatically generates helper optimization variables named `actwise` and `reactwise`, and formulates a set of linear constraints to effectively address these cost functions. For the sake of simplicity, we initially assume that `Generator 2` is out-of-service. Consequently, the helper variable is not included in the set of optimization variables. However, as we progress through this manual, we will activate the generator, introducing the helper variable and additional constraints to the optimization model.

It is worth emphasizing that in instances where a piecewise linear cost function consists of only a single segment, as demonstrated by the reactive power output cost of `Generator 2`, the function is modeled as a standard linear function, avoiding the need for additional helper optimization variables.

Please be aware that JuliaGrid maintains references to all variables, which are categorized into six fields:
```@repl acopf
fieldnames(typeof(analysis.method.variable.voltage))
fieldnames(typeof(analysis.method.variable.power))
```

---

##### Variable Names
Users have the option to define custom variable names for printing equations, which can help present them in a more compact form. For example:
```@example acopf
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; magnitude = "V", angle = "θ")
nothing # hide
```

---

##### Add Variables
Once the `AcOptimalPowerFlow` type is established, users can add new variables representing generator active power outputs by introducing additional generators. For example:
```@example acopf
addGenerator!(analysis; label = "Generator 3", bus = "Bus 1", maxActive = 0.2, status = 1)
nothing # hide
```
This command adds both a new variables and the corresponding box constraints to the optimization model.

To confirm that the variable has been successfully added, you can use the following function:
```@repl acopf
JuMP.is_valid(analysis.method.jump, analysis.method.variable.power.active[3])
JuMP.is_valid(analysis.method.jump, analysis.method.variable.power.reactive[3])
```

---

## [Constraint Functions](@id ACConstraintFunctionsManual)
JuliaGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `AcOptimalPowerFlow` type. These constraints are divided into six fields:
```@repl acopf
fieldnames(typeof(analysis.method.constraint))
```

They fall into two main categories: box constraints and non-box constraints.

!!! note "Info"
    We suggest that readers refer to the tutorial on [AC Optimal Power Flow](@ref ACOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Box Constraints
The `slack` constraint is represented as an `equality` tied to the fixed voltage angle at the slack bus.

The `capability` constraints define variable bounds on both active and reactive power generation and are always implemented as two separate constraints: one for the `lower` bound and one for the `upper` bound. If the bounds are equal, or if the generator is out-of-service, JuliaGrid models the constraint as an `equality` instead.

The `magnitude` field of the `voltage` constraints defines bounds on bus voltage magnitude values and is also implemented using a `lower` and an `upper` bound. If the bounds are equal, JuliaGrid models the constraint as an `equality` instead.

---

##### Non-Box Constraints
The `balance` constraints correspond to the active and reactive power balance equations defined at each bus and are modeled as `equality` constraints.

The `angle` field of the `voltage` constraints are associated with the minimum and maximum voltage angle difference between the from-bus and to-bus ends of each branch and are modeled as `interval` constraints by default. If the bounds are equal, an `equality` constraint is used instead.

The `flow` constraints, which refer to branch flow limits at both ends of each branch, are also modeled as `interval` constraints by default. If the bounds are equal, an `equality` constraint is used.

If preferred, both the `angle` field of the `voltage` constraints and the `flow` constraints can be represented as two separate one-sided constraints, one for the `lower` and one for the `upper` bound, by setting the keyword argument `interval = false` when calling the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function.

Finally, the `piecewise` constraints are introduced when piecewise linear cost functions with multiple segments are defined, and they impose only `upper` bounds.

---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl acopf
print(system.bus.label, analysis.method.constraint.slack.angle)
```

Users have the flexibility to modify this constraint by changing which bus serves as the slack bus and by adjusting the value of the bus angle. This can be achieved using the [`updateBus!`](@ref updateBus!) function, for example:
```@example acopf
updateBus!(analysis; label = "Bus 1", type = 1)
updateBus!(analysis; label = "Bus 2", type = 3, angle = -0.2)
nothing # hide
```

Subsequently, the updated slack constraint can be inspected as follows:
```@repl acopf
print(system.bus.label, analysis.method.constraint.slack.angle)
```

---

##### Bus Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active and reactive power balance equations defined for each bus. These constraints ensure that the total active and reactive power injected by the generators matches the total active and reactive power demanded at each bus.

The constant term in the active power balance equations is determined by the `active` keyword within the [`addBus!`](@ref addBus!) function, which defines the active power demanded at the bus. We can access the references to the active power balance constraints using the following code snippet:
```@repl acopf
print(system.bus.label, analysis.method.constraint.balance.active)
```

Similarly, the constant term in the reactive power balance equations is determined by the `reactive` keyword within the [`addBus!`](@ref addBus!) function, which defines the reactive power demanded at the bus. We can access the references to the reactive power balance constraints using the following code snippet:
```@repl acopf
print(system.bus.label, analysis.method.constraint.balance.reactive)
```

During the execution of functions that add or update power system components, these constraints are automatically adjusted to reflect the current configuration of the power system, for example:
```@example acopf
updateBus!(analysis; label = "Bus 2", active = 0.5)
updateBranch!(analysis; label = "Branch 1", reactance = 0.25)
nothing # hide
```

The updated set of active power balance constraints can be examined as follows:
```@repl acopf
print(system.bus.label, analysis.method.constraint.balance.active)
```

---

##### Bus Voltage Constraints
The `voltage` field contains references to the inequality constraints associated with the voltage magnitude and voltage angle difference limits. These constraints ensure that the bus voltage magnitudes and the angle differences between the from-bus and to-bus ends of each branch are within specified limits.

The minimum and maximum bus voltage magnitude limits are set using the `minMagnitude` and `maxMagnitude` keywords within the [`addBus!`](@ref addBus!) function. The constraints associated with these limits can be accessed using:
```@repl acopf
print(system.bus.label, analysis.method.constraint.voltage.magnitude)
```

The minimum and maximum voltage angle difference limits between the from-bus and to-bus ends of each branch are set using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function. The constraints associated with these limits can be accessed using the following code snippet:
```@repl acopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

!!! note "Info"
    Please note that if the limit constraints are set to `minDiffAngle = -2π` and `maxDiffAngle = 2π` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

By employing the [`updateBus!`](@ref updateBus!) and [`updateBranch!`](@ref updateBranch!) functions, users have the ability to modify these constraints:
```@example acopf
updateBus!(analysis; label = "Bus 1", minMagnitude = 1.0, maxMagnitude = 1.0)
updateBranch!(analysis; label = "Branch 1", minDiffAngle = -1.7, maxDiffAngle = 1.7)
nothing # hide
```

Subsequently, the updated set of constraints can be examined as follows:
```@repl acopf
print(system.bus.label, analysis.method.constraint.voltage.magnitude)
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

---

##### [Branch Flow Constraints](@id ACBranchFlowConstraintsManual)
The `flow` field refers to inequality constraints that enforce limits on the apparent power flow, active power flow, or current flow magnitude at the from-bus and to-bus ends of each branch. The type of constraint applied is specified using the `type` keyword in the [`addBranch!`](@ref addBranch!) function:
* `type = 1` active power flow,
* `type = 2` apparent power flow,
* `type = 3` apparent power flow with a squared inequality constraint,
* `type = 4` current flow magnitude,
* `type = 5` current flow magnitude with a squared inequality constraint.

!!! tip "Tip"
    Squared versions of constraints typically make the optimization problem numerically more robust. However, they often result in slower convergence compared to their non-squared counterparts used in the constraints.

These limits are specified using the `minFromBus`, `maxFromBus`, `minToBus` and `maxToBus` keywords within the [`addBranch!`](@ref addBranch!) function. By default, these limit keywords are associated with apparent power (`type = 3`).

However, in the example, we configured it to use active power flow by setting `type = 1`. To access the flow constraints of branches at the from-bus end, we can utilize the following code snippet:
```@repl acopf
print(system.branch.label, analysis.method.constraint.flow.from)
```

!!! note "Info"
    If the branch flow limits are set to `minFromBus = 0.0` and `maxFromBus = 0.0` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint at the from-bus end of the branch. The same applies to the to-bus end if `minToBus = 0.0` and `maxToBus = 0.0` are set.

Additionally, by employing the [`updateBranch!`](@ref updateBranch!) function, we have the ability to modify these specific constraints:
```@example acopf
updateBranch!(analysis; label = "Branch 1", minFromBus = -0.15, maxToBus = 0.15)
nothing # hide
```

The updated set of flow constraints can be examined as follows:
```@repl acopf
print(system.branch.label, analysis.method.constraint.flow.from)
print(system.branch.label, analysis.method.constraint.flow.to)
```

!!! tip "Tip"
    In typical scenarios, `minFromBus` is equal to `minToBus`, and `maxFromBus` is equal to `maxToBus`. However, we allow these values to be defined separately for greater flexibility, enabling, among other things, the option to apply constraints on only one side of the branch.

---

##### Generator Power Capability Constraints
The `capability` field contains references to the inequality constraints associated with the minimum and maximum active and reactive power outputs of the generators.

The constraints associated with the minimum and maximum active power output limits of the generators are defined using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access the constraints associated with these limits, we can use the following code snippet:
```@repl acopf
print(system.generator.label, analysis.method.constraint.capability.active)
```

Similarly, the constraints associated with the minimum and maximum reactive power output limits of the generators are specified using the `minReactive` and `maxReactive` keywords within the [`addGenerator!`](@ref addGenerator!) function. To access these constraints, we can use the following code snippet:
```@repl acopf
print(system.generator.label, analysis.method.constraint.capability.reactive)
```

As demonstrated, the active and reactive power outputs of `Generator 1` and `Generator 2` are currently fixed at zero due to previous actions that set these generators out-of-service. However, we can modify these specific constraints by utilizing the [`updateGenerator!`](@ref updateGenerator!) function, as shown below:
```@example acopf
updateGenerator!(analysis; label = "Generator 1", status = 1)
updateGenerator!(analysis; label = "Generator 2", status = 1, minActive = 0.1)
nothing # hide
```

Subsequently, the updated set of constraints can be examined as follows:
```@repl acopf
print(system.generator.label, analysis.method.constraint.capability.active)
print(system.generator.label, analysis.method.constraint.capability.reactive)
```

!!! note "Info"
    This representation may not fully capture the generator's power output behavior due to the tradeoff between active and reactive power outputs. JuliaGrid can incorporate this tradeoff in its optimization model. For more information, see the tutorial on [Power Capability Constraints](@ref ACPowerCapabilityConstraintsTutorials).

---

##### Power Piecewise Constraints
In cost modeling, the `piecewise` field serves as a reference to the inequality constraints associated with piecewise linear cost functions. These constraints are defined using the [`cost!`](@ref cost!) function with `active = 1` or `reactive = 1`.

In our example, only the active power cost of `Generator 2` is modeled as a piecewise linear function with two segments, and JuliaGrid takes care of setting up the appropriate inequality constraints for each segment:
```@repl acopf
print(system.generator.label, analysis.method.constraint.piecewise.active)
```

It is worth noting that these constraints can also be automatically updated using the [`cost!`](@ref cost!) function. Readers can find more details in the section discussing the objective function.

As mentioned at the beginning, piecewise linear cost functions with multiple segments will also introduce helper variables that are added to the objective function. In this specific example, the helper variable is:
```@repl acopf
analysis.method.variable.power.actwise[2]
```

---

##### Add Constraints
Users can effortlessly introduce additional constraints into the defined AC optimal power flow model by utilizing the [`addBranch!`](@ref addBranch!) functions. Specifically, if a user wishes to include a new branch or generator in an already defined `PowerSystem` and `AcOptimalPowerFlow` type:
```@example acopf
addBranch!(analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 1)
nothing # hide
```

This will affect all constraints related to branches, but it will also update balance constraints to configure the optimization model to match the current state of the power system. For example, we can observe the following updated constraints:
```@repl acopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

Similarly, the [`addGenerator!`](@ref addGenerator!) function adds both new variables and its associated box constraints.

---

##### Delete Constraints
When a branch or generator is taken out-of-service, JuliaGrid automatically adjusts the optimization problem to reflect that action, which may include removing certain constraints.

In some cases, users may also want to manually remove specific constraints. This can be done using the [`remove!`](@ref remove!) function by specifying the constraint type: `:slack`, `:capability`, `:balance`, `:voltage`, `:flow`, or `:piecewise`.

For constraint types such as `:capability`, `:balance`, and `:piecewise`, users must also specify whether the constraint targets `:active` or `:reactive` power. Similarly, for `:voltage`, the options are `:magnitude` or `:angle`, and for `:flow`, the options are `:from` or `:to`.

For example, to delete the constraint associated with the voltage angle difference at `Branch 2`, use:
```@example acopf
remove!(analysis, :voltage, :angle; label = "Branch 2")
nothing # hide
```

Alternatively, instead of using a label, constraints can also be deleted by index:
```@example acopf
remove!(analysis, :voltage, :angle; index = 4)
nothing # hide
```

After these operations, the remaining voltage angle difference constraints can be displayed as follows:
```@repl acopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

!!! note "Info"
    In the event that a user deletes a constraint and subsequently executes a function that updates bus, branch, or generator parameters, and if the deleted constraint is affected by these functions, JuliaGrid will automatically reinstate that constraint.

---


## [Objective Function](@id ACObjectiveFunctionManual)
The objective function of the AC optimal power flow is formulated using polynomial and piecewise linear cost functions associated with the generators, defined using the [`cost!`](@ref cost!) functions.

In the provided example, the objective function to be minimized in order to obtain optimal values for the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles, is as follows:
```@repl acopf
JuMP.objective_function(analysis.method.jump)
```

The objective function is stored in the variable `analysis.objective`, where it is organized to separate its quadratic and nonlinear components.

---

##### Update Objective Function
By utilizing the [`cost!`](@ref cost!) functions, users have the flexibility to modify the objective function by adjusting polynomial or piecewise linear coefficients or by changing the type of polynomial or piecewise linear function employed. For example, consider `Generator 1`, which employs a quadratic polynomial cost function for active power. We can redefine the cost function for this generator as a cubic polynomial and thereby define a nonlinear objective function:
```@example acopf
cost!(analysis; generator = "Generator 1", active = 2, polynomial = [63; 25; 4; 0.5])
nothing # hide
```

This leads to an updated objective function, which can be examined as follows:
```@repl acopf
JuMP.objective_function(analysis.method.jump)
```

---

## [Setup Initial Values](@id AcSetupPrimalStartingValuesManual)
In JuliaGrid, the assignment of initial primal and dual values for optimization variables and constraints takes place when the [`solve!`](@ref solve!(::AcOptimalPowerFlow)) function is executed.

---

##### Initial Primal Values
Initial primal values are determined based on the `generator` and `voltage` fields within the `AcOptimalPowerFlow` type. By default, these values are initially established using the active and reactive power outputs of the generators and the initial bus voltage magnitudes and angles:
```@repl acopf
generator = analysis.power.generator;
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```
Users have the flexibility to adjust these values according to their specifications, which will then be used as the initial primal values when executing the [`solve!`](@ref solve!(::AcOptimalPowerFlow)) function.

---

##### Using AC Power Flow
In this perspective, users have the capability to conduct the AC power flow analysis and leverage the resulting solution to configure initial primal values. Here is an illustration of how this can be achieved:
```@example acopf
flow = newtonRaphson(system)
powerFlow!(flow; power = true)
```

After obtaining the solution, we can use the active and reactive power outputs of the generators, along with bus voltage magnitudes and angles, to set the initial values:
```@example acopf
setInitialPoint!(analysis, flow)
```

---

##### Initial Dual Values
Dual variables, often referred to as Lagrange multipliers or Kuhn-Tucker multipliers, represent the shadow prices or marginal costs associated with constraints. The assignment of initial dual values occurs when the [`solve!`](@ref solve!(::AcOptimalPowerFlow)) function is executed. By default, dual values are undefined, but users can manually assign them using the [`addDual!`](@ref addDual!) function.

If a constraint is defined as an equality, an interval, or has only a lower or upper bound, it corresponds to a single dual variable. In such cases, an initial value can be set using the `dual` keyword. For example:
```@example acopf
addDual!(analysis, :balance, :active; label = "Bus 1", dual = 1e-3)
nothing # hide
```

For constraints with both lower and upper bounds, users can assign initial dual values separately using the `lower` and `upper` keywords. For example:
```@example acopf
addDual!(analysis, :capability, :reactive; label = "Generator 1", lower = 500.0, upper = 0.0)
nothing # hide
```

Alternatively, dual variables can be added by specifying the constraint index instead of a label:
```@example acopf
addDual!(analysis, :capability, :reactive; index = 1, lower = 500.0, upper = 0.0)
nothing # hide
```

---

## [Optimal Power Flow Solution](@id AcOptimalPowerFlowSolutionManual)
To establish the AC optimal power flow problem, we utilize the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function. After setting up the problem, we can use the [`solve!`](@ref solve!(::AcOptimalPowerFlow)) function to compute the optimal values for the active and reactive power outputs of the generators and the bus voltage magnitudes angles:
```@example acopf
solve!(analysis)
```

By executing this function, we will obtain the solution with the optimal values for the active and reactive power outputs of the generators, as well as the bus voltage magnitudes and angles.
```@repl acopf
generator = analysis.power.generator;
print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, we can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.objective_value) function:
```@repl acopf
JuMP.objective_value(analysis.method.jump)
```

---

##### Dual Variables
The values of the dual variables are stored in the `dual` field of the `AcOptimalPowerFlow` type. For example:
```@repl acopf
print(system.bus.label, analysis.method.dual.balance.active)
```

---

##### Wrapper Function
JuliaGrid provides a wrapper function for AC optimal power flow analysis and also supports the computation of powers and currents using the [powerFlow!](@ref powerFlow!(::AcOptimalPowerFlow)) function:
```@example acopf
setInitialPoint!(analysis) # hide
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; verbose = 1)
nothing # hide
```

---

##### Print Results in the REPL
Users can utilize the functions [`printBusData`](@ref printBusData) and [`printGeneratorData`](@ref printGeneratorData) to display results. Additionally, the functions listed in the [Print Constraint Data](@ref PrintConstraintDataAPI) section allow users to print constraint data related to buses, branches, or generators in the desired units. For example:
```@example acopf
show = Dict("Active Power Balance" => false)
printBusConstraint(analysis; show)
nothing # hide
```

Next, users can easily customize the print results for specific constraint, for example:
```julia
printBusConstraint(analysis; label = "Bus 1", header = true)
printBusConstraint(analysis; label = "Bus 2", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file as follows:
```julia
open("bus.txt", "w") do file
    printBusConstraint(analysis, file)
end
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printBusConstraint(analysis, io; style = false)
CSV.write("constraint.csv", CSV.File(take!(io); delim = "|"))
```

---

## Primal and Dual Warm Start
Utilizing the `AcOptimalPowerFlow` type and proceeding directly to the solver offers the advantage of a warm start. In this scenario, the initial primal and dual values for the subsequent solving step correspond to the solution obtained from the previous step, including any user-defined data previously integrated in JuliaGrid.

---

##### Primal Variables
In the previous example, the following solution was obtained, representing the values of the primal variables:
```@repl acopf
generator = analysis.power.generator;

print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Dual Variables
We also obtained all dual values. Here, we list only the dual variables for one type of constraint as an example:
```@repl acopf
print(system.generator.label, analysis.method.dual.capability.reactive)
```
---

##### Modify Optimal Power Flow
Now, let us introduce changes to the power system from the previous example:
```@example acopf
updateGenerator!(analysis; label = "Generator 3", maxActive = 0.05)
nothing # hide
```

Next, we want to solve this modified optimal power flow problem. If we use [`solve!`](@ref solve!(::AcOptimalPowerFlow)) at this point, the primal and dual initial values will be set to the previously obtained values:
```@example acopf
powerFlow!(analysis, verbose = 1)
nothing # hide
```

As a result, we obtain a new solution:
```@repl acopf
generator = analysis.power.generator;

print(system.generator.label, generator.active, generator.reactive)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Reset Primal and Dual Values
Users retain the flexibility to reset initial primal and dual values to their default configurations at any juncture. This can be accomplished by utilizing the active and reactive power outputs of the generators and the initial bus voltage magnitudes and angles extracted from the `PowerSystem` type, employing the [`setInitialPoint!`](@ref setInitialPoint!(::AcOptimalPowerFlow)) function:
```@example acopf
setInitialPoint!(analysis)
nothing # hide
```
The primal initial values will now be identical to those that would be obtained if the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function were executed after all the updates have been applied, while all dual variable values will be removed.

---

## [Extended Formulation](@id AcExtendedFormulationManual)
The JuMP model created by JuliaGrid is stored in the `method.jump` field of the `AcOptimalPowerFlow` type. This allows users to modify the model directly using JuMP macros and functions as needed. However, when making such modifications, users become responsible for tasks like setting initial values and extracting solutions, since these changes operate outside the standard JuliaGrid workflow.

Beyond this approach, JuliaGrid also provides a way to extend the standard AC optimal power flow formulation within its own framework. This lets users take advantage of features such as warm start and automatic solution storage, as described below.

---

##### Add Variable
User-defined variables can be added to the DC optimal power flow model using the [`@addVariable`](@ref @addVariable) macro. It also allows immediate assignment of initial primal and dual values. For example:
```@example acopf
@addVariable(analysis, 0.0 <= y <= 0.2, primal = 0.1, lower = 10.0, upper = 0.0)
nothing # hide
```

We can also define collections of variables:
```@example acopf
@addVariable(analysis, 0.0 <= x[i = 1:2] <= 0.4, primal = [0.1, 0.2], upper = [0.0; -2.5])
nothing # hide
```

---

##### Add Constraints
Custom constraints can be added to the DC optimal power flow model using the [`@addConstraint`](@ref @addConstraint) macro. These constraints are not limited to user-defined variables; any optimization variable defined up to that point can be used. Let us focus on the voltage angle variables:
```@example acopf
θ = analysis.method.variable.voltage.angle
nothing # hide
```

Next, a new constraint can be defined, and at the same time, an initial dual value can be specified:
```@example acopf
@addConstraint(analysis, 0.1 <= x[1] + 2 * x[2] + y + θ[2] <= 1.2, dual = 0.0)
nothing # hide
```

Collections of constraints can also be defined:
```@example acopf
@addConstraint(analysis, [i = 1:2], x[i] + 2 * θ[i] <= 0.6, dual = [0.0; 0.5])
nothing # hide
```

---

##### Delete Constraints
To remove a constraint, use the [`remove!`](@ref remove!) function with the `:constraint` symbol. For example, to remove the first added constraint:
```@example acopf
remove!(analysis, :constraint; index = 1)
nothing # hide
```

---

##### Objective Function
Users can modify the objective function using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_objective_function) function from the JuMP package. In JuliaGrid, the original objective is stored in the `objective` field of the `AcOptimalPowerFlow` type, which can be accessed and customized as needed. This makes it possible to simultaneously remove nonlinear components and adjust the quadratic part of the objective function:
```@example acopf
expr = 50 * x[1] - x[2]^2 + y + 123
JuMP.set_objective_function(analysis.method.jump, analysis.method.objective.quadratic - expr)
nothing # hide
```

We can now observe the updated objective function as follows:
```@repl acopf
JuMP.objective_function(analysis.method.jump)
```

---

##### Optimal Power Flow Solution
Users can now solve the extended formulation using:
```@example acopf
powerFlow!(analysis; verbose = 1)
nothing # hide
```

After solving, users can access the optimal values as follows:
```@repl acopf
analysis.power.generator.active
analysis.power.generator.reactive
analysis.voltage.magnitude
analysis.voltage.angle
analysis.extended.solution
```

---

## [Power and Current Analysis](@id ACOptimalPowerCurrentAnalysisManual)
After obtaining the solution from the AC optimal power flow, we can calculate various electrical quantities related to buses and branches using the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AC)) functions. For instance, let us consider the power system for which we obtained the AC optimal power flow solution:
```@example acopfpower
using JuliaGrid, JuMP # hide
using Ipopt

@default(unit) # hide
@default(template) # hide
system = powerSystem()

@bus(minMagnitude = 0.9, maxMagnitude = 1.1)
addBus!(system; label = "Bus 1", type = 3, magnitude = 1.05, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, reactive = 0.01, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05, reactive = 0.02)

@branch(resistance = 0.5, reactance = 1.0, conductance = 1e-4, susceptance = 0.01)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", maxFromBus = 0.15)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", maxFromBus = 0.10)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", maxFromBus = 0.25)

@generator(maxActive = 0.5, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.5)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, reactive = 0.1)

cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; generator = "Generator 2", active = 1, piecewise = [10 12.3; 14.7 16.8; 18 19])

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)
nothing # hide
```

We can now utilize the following functions to calculate powers and currents:
```@example acopfpower
power!(analysis)
current!(analysis)
nothing # hide
```

For instance, if we want to show the active power injections and the from-bus current magnitudes, we can employ:
```@repl acopfpower
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.from.magnitude)
```

!!! note "Info"
    To better understand the powers and current associated with buses and branches that are calculated by the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AC)) functions, we suggest referring to the tutorials on [AC Optimal Power Flow](@ref ACOptimalPowerFlowTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print Power System Data](@ref PrintPowerSystemDataAPI) or [Print Power System Summary](@ref PrintPowerSystemSummaryAPI). For example, to create a bus data with the desired units, users can use the following function:
```@example acopfpower
@voltage(pu, deg)
@power(MW, MVAr)
show = Dict("Power Generation" => false, "Current Injection" => false)
printBusData(analysis; show)
@default(unit) # hide
nothing # hide
```

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl acopfpower
active, reactive = injectionPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl acopfpower
active, reactive = supplyPower(analysis; label = "Bus 2")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl acopfpower
active, reactive = shuntPower(analysis; label = "Bus 2")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl acopfpower
active, reactive = fromPower(analysis; label = "Branch 2")
active, reactive = toPower(analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the total active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl acopfpower
active, reactive = chargingPower(analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl acopfpower
active, reactive = seriesPower(analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl acopfpower
magnitude, angle = injectionCurrent(analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the from-bus and to-bus ends of the specific branch by using:
```@repl acopfpower
magnitude, angle = fromCurrent(analysis; label = "Branch 2")
magnitude, angle = toCurrent(analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the from-bus end to the to-bus end, we can use the following function:
```@repl acopfpower
magnitude, angle = seriesCurrent(analysis; label = "Branch 2")
```