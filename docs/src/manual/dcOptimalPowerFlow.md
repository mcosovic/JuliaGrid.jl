# [DC Optimal Power Flow](@id DCOptimalPowerFlowManual)
Similar to [AC Optimal Power Flow](@ref ACOptimalPowerFlowManual), JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, enabling users to manipulate these models using the standard functions provided by JuMP. JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the DC optimal power flow, we first need to have the `PowerSystem` type that has been created with the DC model. After that, create the `DcOptimalPowerFlow` type to establish the DC optimal power flow framework using the function:
* [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow).

---

To solve the DC optimal power flow problem and acquire generator active power outputs and bus voltage angles, users can use of the following function:
* [`solve!`](@ref solve!(::DcOptimalPowerFlow)).

After solving the DC optimal power flow, JuliaGrid provides function for computing powers:
* [`power!`](@ref power!(::DcPowerFlow)).

Alternatively, instead of using functions responsible for solving optimal power flow and computing powers, users can use the wrapper function:
* [`powerFlow!`](@ref powerFlow!(::DcOptimalPowerFlow)).

Users can also access specialized functions for computing specific types of [powers](@ref DCPowerAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## [Optimal Power Flow Model](@id DCOptimalPowerFlowModelManual)
To set up the DC optimal power flow, we begin by creating the model. To illustrate this, consider the following:
```@example dcopf
using JuliaGrid # hide
using JuMP, Ipopt

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05)

@branch(minDiffAngle = -3.1, maxDiffAngle = 3.1, minFromBus = -0.12, maxFromBus = 0.12)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

@generator(minActive = 0.0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.6, maxActive = 0.8)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.1, maxActive = 0.3)
addGenerator!(system; label = "Generator 3", bus = "Bus 2", active = 0.2, maxActive = 0.4)

cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; generator = "Generator 2", active = 1, piecewise = [8.0 11.0; 14.0 17.0])
cost!(system; generator = "Generator 3", active = 1, piecewise = [6 12.3; 8.7 16.8; 11 19])

dcModel!(system)
nothing # hide
```

Next, the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function is utilized to formulate the DC optimal power flow problem:
```@example dcopf
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
nothing # hide
```

!!! note "Info"
    All non-box two-sided constraints are modeled as intervals by default. However, users can choose to represent them as two separate constraints, one for the lower bound and one for the upper bound, by setting:
    ```julia DCPowerFlowSolution
    analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; interval = false)
    ```
    Although this approach may be less efficient in terms of model creation and could lead to longer execution times depending on the solver, it allows for precise definition of the starting dual values.

---

## [Optimization Variables](@id DCOptimizationVariablesManual)
In DC optimal power flow, generator active power outputs are linear functions of bus voltage angles. Thus, the model's variables include generator active power outputs and bus voltage angles:
```@repl dcopf
JuMP.all_variables(analysis.method.jump)
```

It is important to highlight that when dealing with piecewise linear cost functions comprising multiple segments, as exemplified in the case of `Generator 3`, JuliaGrid automatically generates helper optimization variables, such as `actwise[3]`, and formulates a set of linear constraints to appropriately handle these cost functions.

However, in instances where a piecewise linear cost function consists of only a single segment, as demonstrated by `Generator 2`, the function is modelled as a standard linear function, eliminating the necessity for additional helper optimization variables.

Please note that JuliaGrid keeps references to all variables categorized into three fields:
```@repl dcopf
fieldnames(typeof(analysis.method.variable.voltage))
fieldnames(typeof(analysis.method.variable.power))
```

---

##### Variable Names
Users have the option to define custom variable names for printing equations, which can help present them in a more compact form. For example:
```@example dcopf
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; active = "P", angle = "θ")
nothing # hide
```

---

##### Add Variables
Once the `DcOptimalPowerFlow` type is established, users can add new variables representing generator active power outputs by introducing additional generators. For example:
```@example dcopf
addGenerator!(analysis; label = "Generator 4", bus = "Bus 1", active = 0.1, maxActive = 0.2)
nothing # hide
```
This command adds both a new variable and the corresponding box constraint to the optimization model.

To confirm that the variable has been successfully added, you can use the following function:
```@repl dcopf
JuMP.is_valid(analysis.method.jump, analysis.method.variable.power.active[4])
```

---

## [Constraint Functions](@id DCConstraintFunctionsManual)
JuliGrid keeps track of all the references to internally formed constraints in the `constraint` field of the `DcOptimalPowerFlow` type. These constraints are divided into six fields:
```@repl dcopf
fieldnames(typeof(analysis.method.constraint))
```

They fall into two main categories: box constraints and non-box constraints.

!!! note "Info"
    We suggest that readers refer to the tutorial on [DC Optimal Power Flow](@ref DCOptimalPowerFlowTutorials) for insights into the implementation.

---

##### Box Constraints
The `slack` constraint is represented as an `equality` tied to the fixed voltage angle at the slack bus.

The `capability` constraints define variable bounds on active power generation and are always implemented as two separate constraints: one for the `lower` bound and one for the `upper` bound. If the bounds are equal or the generator is out-of-service, JuliaGrid models the constraint as an `equality` instead.

---

##### Non-Box Constraints
The `balance` constraints correspond to active power balance equations defined at each bus and are modeled as `equality` constraints.

The `voltage` constraints are associated with the minimum and maximum voltage angle difference between the from-bus and to-bus ends of each branch and are modeled as `interval` constraints by default. If the bounds are equal, an `equality` constraint is used instead.

The `flow` constraints, which refer to active power flow limits at the from-bus end of each branch, are also modeled as `interval` constraints by default. If the bounds are equal, an `equality` constraint is used.

If preferred, both `voltage` and `flow` constraints can be represented as two separate one-sided constraints, one for the `lower` and one for the `upper` bound, by setting the keyword argument `interval = false` when calling the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function.

Finally, the `piecewise` constraints are introduced when piecewise linear cost functions with multiple segments are defined, and they impose only `upper` bounds.


---

##### Slack Bus Constraint
The `slack` field contains a reference to the equality constraint associated with the fixed bus voltage angle value of the slack bus. This constraint is set within the [`addBus!`](@ref addBus!) function using the `angle` keyword:
```@repl dcopf
print(system.bus.label, analysis.method.constraint.slack.angle)
```

Users have the flexibility to modify this constraint by changing which bus serves as the slack bus and by adjusting the value of the bus angle. This can be achieved using the [`updateBus!`](@ref updateBus!) function, for example:
```@example dcopf
updateBus!(analysis; label = "Bus 1", angle = -0.1)
nothing # hide
```
Subsequently, the updated slack constraint can be inspected as follows:
```@repl dcopf
print(system.bus.label, analysis.method.constraint.slack.angle)
```

---

##### Generator Active Power Capability Constraints
The `capability` field contains references to the box inequality constraints associated with the minimum and maximum active power outputs of the generators. These limits are specified using the `minActive` and `maxActive` keywords within the [`addGenerator!`](@ref addGenerator!) function:
```@repl dcopf
print(system.generator.label, analysis.method.constraint.capability.active)
```

Let us now set `Generator 2` out of service using the [`updateGenerator!`](@ref updateGenerator!) function:
```@example dcopf
updateGenerator!(analysis; label = "Generator 2", status = 0)
nothing # hide
```

We can now observe that the updated constraints reflect the current state of the system:
```@repl dcopf
print(system.generator.label, analysis.method.constraint.capability.active)
```

---

##### Bus Active Power Balance Constraints
The `balance` field contains references to the equality constraints associated with the active power balance equations defined for each bus. The constant terms in these equations are determined by the `active` and `conductance` keywords within the [`addBus!`](@ref addBus!) function. Additionally, if there are phase shift transformers in the system, the constant terms can also be affected by the `shiftAngle` keyword within the [`addBranch!`](@ref addBranch!) function:
```@repl dcopf
print(system.bus.label, analysis.method.constraint.balance.active)
```

During the execution of functions that add or update power system components, these constraints are automatically adjusted to reflect the current configuration of the power system, for example:
```@example dcopf
updateBus!(analysis; label = "Bus 3", active = 0.1)
updateGenerator!(analysis; label = "Generator 2", status = 1)
nothing # hide
```

Subsequently, the updated set of active power balance constraints can be examined as follows:
```@repl dcopf
print(system.bus.label, analysis.method.constraint.balance.active)
```

---

##### Bus Voltage Angle Difference Constraints
The `voltage` field contains references to the inequality constraints associated with the minimum and maximum bus voltage angle difference between the from-bus and to-bus ends of each branch. These values are specified using the `minDiffAngle` and `maxDiffAngle` keywords within the [`addBranch!`](@ref addBranch!) function:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

!!! note "Info"
    If `minDiffAngle = -2π` and `maxDiffAngle = 2π`, or both are set to `zero` for a given branch, JuliaGrid will skip adding the corresponding inequality constraint.

Additionally, by employing the [`updateBranch!`](@ref updateBranch!) function, we have the ability to modify these constraints as follows:
```@example dcopf
updateBranch!(analysis; label = "Branch 1", minDiffAngle = -1.7, maxDiffAngle = 1.7)
nothing # hide
```

Subsequently, the updated set of voltage angle difference constraints can be examined as follows:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

---

##### Branch Active Power Flow Constraints
The `flow` field refers to the inequality constraints associated with active power flow limits at the from-bus end of each branch. These limits are set using the `minFromBus` and `maxFromBus` keywords in the [`addBranch!`](@ref addBranch!) function:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.flow.active)
```

!!! note "Info"
    If the branch flow limits are set to `minFromBus = 0.0` and `maxFromBus = 0.0` for the corresponding branch, JuliGrid will omit the corresponding inequality constraint.

By employing the [`updateBranch!`](@ref updateBranch!) function, we have the ability to modify these specific constraints, for example:
```@example dcopf
updateBranch!(analysis; label = "Branch 1", status = 0)
updateBranch!(analysis; label = "Branch 2", reactance = 0.03, maxFromBus = 0.14)
nothing # hide
```

Subsequently, the updated set of active power flow constraints can be examined as follows:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.flow.active)
```

---


##### Active Power Piecewise Constraints
In the context of active power modelling, the `piecewise` field serves as a reference to the inequality constraints related to linear piecewise cost functions. These constraints are created using the [`cost!`](@ref cost!) function with `active = 1` specified when dealing with piecewise linear cost functions comprising multiple segments. JuliaGrid takes care of establishing the appropriate inequality constraints for each segment of the piecewise linear cost:
```@repl dcopf
print(system.generator.label, analysis.method.constraint.piecewise.active)
```

It is worth noting that these constraints can also be automatically updated using the [`cost!`](@ref cost!) function, and readers can find more details in the section about the objective function.

---

##### Add Constraints
Users can easily introduce new constraints into the DC optimal power flow by using the [`addBranch!`](@ref addBranch!) function. For example, to add a new branch to an existing `PowerSystem` and corresponding `DcOptimalPowerFlow` model:
```@example dcopf
addBranch!(analysis; label = "Branch 4", from = "Bus 1", to = "Bus 2", reactance = 1)
nothing # hide
```

As a result, the flow constraints will be adjusted as follows:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.flow.active)
```

Similarly, the [`addGenerator!`](@ref addGenerator!) function adds both a new variable and its associated box constraint.

---

##### Delete Constraints
When a branch or generator is taken out-of-service, JuliaGrid automatically adjusts the optimization problem to reflect that action, which may include removing certain constraints.

In some cases, it may also be useful to remove specific constraints manually. This can be done using the [`remove!`](@ref remove!) function by specifying the constraint type: `:slack`, `:capability`, `:balance`, `:voltage`, `:flow` or `:piecewise`.

For example, to delete the constraint associated with the voltage angle difference at `Branch 2`, use:
```@example dcopf
remove!(analysis, :voltage; label = "Branch 2")
nothing # hide
```

Alternatively, instead of using a label, constraints can also be deleted by index:
```@example dcopf
remove!(analysis, :voltage; index = 4)
nothing # hide
```

After these operations, the remaining voltage angle difference constraints can be displayed as follows:
```@repl dcopf
print(system.branch.label, analysis.method.constraint.voltage.angle)
```

!!! note "Info"
    In the event that a user deletes a constraint and subsequently executes a function that updates bus, branch, or generator parameters, and if the deleted constraint is affected by these functions, JuliaGrid will automatically reinstate that constraint.

---

## [Objective Function](@id DCObjectiveFunctionManual)
The objective of the DC optimal power flow is constructed using polynomial and piecewise linear cost functions of the generators, which are defined using the [`cost!`](@ref cost!) functions. Only polynomial cost functions of up to the second degree are included in the objective. Specifically, if a higher-degree polynomial is provided, JuliaGrid will discard all terms beyond the second degree and still include the resulting truncated polynomial in the objective function.

In the provided example, the objective function that needs to be minimized to obtain the optimal values of the active power outputs of the generators and the bus voltage angles is as follows:
```@repl dcopf
JuMP.objective_function(analysis.method.jump)
```

Additionally, JuliaGrid stores the objective function in a separate variable, allowing users to access it by referencing the variable `analysis.objective`.

---

##### Update Objective Function
By utilizing the [`cost!`](@ref cost!) functions, users have the flexibility to modify the objective function by adjusting polynomial or piecewise linear cost coefficients or by changing the type of polynomial or piecewise linear function employed. For instance, consider `Generator 3`, which incorporates a piecewise cost structure with two segments. Now, we can define a polynomial function for this generator and activate it by specifying the keyword `active = 2` as shown:
```@example dcopf
cost!(analysis; generator = "Generator 3", active = 2, polynomial = [853.4; 257; 40])
```

This results in the updated objective function, which can be observed as follows:
```@repl dcopf
analysis.method.objective
```

---

## [Setup Initial Values](@id SetupStartingPrimalValuesManual)
In JuliaGrid, the assignment of initial primal and dual values for optimization variables takes place when the [`solve!`](@ref solve!(::DcOptimalPowerFlow)) function is executed.

---

##### Initial Primal Values
Initial primal values are determined based on the `generator` and `voltage` fields within the `DcOptimalPowerFlow` type. By default, these values are initially established using the active power outputs of the generators and the initial bus voltage angles:
```@repl dcopf
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```
Users have the flexibility to adjust these values according to their specifications, which will then be used as the initial primal values when executing the [`solve!`](@ref solve!(::DcOptimalPowerFlow)) function.

---

##### Using DC Power Flow
In this perspective, users have the capability to conduct the DC power flow analysis and leverage the resulting solution to configure initial primal values. Here is an illustration of how this can be achieved:
```@example dcopf
flow = dcPowerFlow(system)
powerFlow!(flow; power = true)
```

After obtaining the solution, we can use the active power outputs of the generators, along with bus voltage angles, to set the initial values:
```@example dcopf
setInitialPoint!(analysis, flow)
```

---

##### Initial Dual Values
Dual variables, often referred to as Lagrange multipliers or Kuhn-Tucker multipliers, represent the shadow prices or marginal costs associated with constraints. The assignment of initial dual values occurs when the [`solve!`](@ref solve!(::DcOptimalPowerFlow)) function is executed. By default, dual values are undefined, but users can manually assign them using the [`addDual!`](@ref addDual!) function.

If a constraint is defined as an equality, an interval, or has only a lower or upper bound, it corresponds to a single dual variable. In such cases, an initial value can be set using the `dual` keyword. For example:
```@example dcopf
addDual!(analysis, :balance; label = "Bus 1", dual = 1e-3)
nothing # hide
```

For constraints with both lower and upper bounds, users can assign initial dual values separately using the `lower` and `upper` keywords. For example:
```@example dcopf
addDual!(analysis, :capability; label = "Generator 1", lower = 500.0, upper = 0.0)
nothing # hide
```

Alternatively, dual variables can be added by specifying the constraint index instead of a label:
```@example dcopf
addDual!(analysis, :capability; index = 1, lower = 500.0, upper = 0.0)
nothing # hide
```

---

## [Optimal Power Flow Solution](@id DCOptimalPowerFlowSolutionManual)
To establish the DC optimal power flow problem, we utilize the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function. After setting up the problem, we can use the [`solve!`](@ref solve!(::DcOptimalPowerFlow)) function to compute the optimal values for the active power outputs of the generators and the bus voltage angles:
```@example dcopf
solve!(analysis)
nothing # hide
```

By executing this function, we will obtain the solution with the optimal values for the active power outputs of the generators and the bus voltage angles:
```@repl dcopf
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```

---

##### Objective Value
To obtain the objective value of the optimal power flow solution, we can use the [`objective_value`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.objective_value) function:
```@repl dcopf
JuMP.objective_value(analysis.method.jump)
```

---

##### Dual Variables
The values of the dual variables are stored in the `dual` field of the `DcOptimalPowerFlow` type. For example:
```@repl dcopf
print(system.bus.label, analysis.method.dual.balance.active)
```

---

##### Wrapper Function
JuliaGrid provides a wrapper function for DC optimal power flow analysis and also supports the computation of powers using the [powerFlow!](@ref powerFlow!(::DcOptimalPowerFlow)) function:
```@example dcopf
setInitialPoint!(analysis) # hide
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; verbose = 1)
nothing # hide
```

---

##### Print Results in the REPL
Users can utilize the functions [`printBusData`](@ref printBusData) and [`printGeneratorData`](@ref printGeneratorData) to display results. Additionally, the functions listed in the [Print Constraint Data](@ref PrintConstraintDataAPI) section allow users to print constraint data related to buses, branches, or generators in the desired units. For example:
```@example dcopf
@power(MW, MVAr)
printBusConstraint(analysis)
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
Utilizing the `DcOptimalPowerFlow` type and proceeding directly to the solver offers the advantage of a warm start. In this scenario, the initial primal and dual values for the subsequent solving step correspond to the solution obtained from the previous step.

---

##### Primal Variables
In the previous example, the following solution was obtained, representing the values of the primal variables:
```@repl dcopf
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```

---

##### Dual Variables
We also obtained all dual values. Here, we list only the dual variables for one type of constraint as an example:
```@repl dcopf
print(system.branch.label, analysis.method.dual.flow.active)
```

---

##### Modify Optimal Power Flow
Now, let us introduce changes to the power system from the previous example:
```@example dcopf
updateGenerator!(analysis; label = "Generator 2", maxActive = 0.08)
nothing # hide
```

Next, we want to solve this modified optimal power flow problem. If we use [`solve!`](@ref solve!(::DcOptimalPowerFlow)) at this point, the primal and dual initial values will be set to the previously obtained values:
```@example dcopf
powerFlow!(analysis)
nothing # hide
```

As a result, we obtain a new solution:
```@repl dcopf
print(system.generator.label, analysis.power.generator.active)
print(system.bus.label, analysis.voltage.angle)
```

---

##### Reset Primal and Dual Values
Users retain the flexibility to reset these initial primal values to their default configurations at any juncture. This can be accomplished by utilizing the active power outputs of the generators and the initial bus voltage angles extracted from the `PowerSystem` type, employing the [`setInitialPoint!`](@ref setInitialPoint!(::DcOptimalPowerFlow)) function:
```@example dcopf
setInitialPoint!(analysis)
nothing # hide
```
The primal initial values will now be identical to those that would be obtained if the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function were executed after all the updates have been applied, while all dual variable values will be removed.

---

## [Extended Formulation](@id DcExtendedFormulationManual)
The JuMP model created by JuliaGrid is stored in the `method.jump` field of the `DcOptimalPowerFlow` type. This allows users to modify the model directly using JuMP macros and functions as needed. However, when making such modifications, users become responsible for tasks like setting initial values and extracting solutions, since these changes operate outside the standard JuliaGrid workflow.

Beyond this approach, JuliaGrid also provides a way to extend the standard DC optimal power flow formulation within its own framework. This lets users take advantage of features such as warm start and automatic solution storage, as described below.

---

#### Add Variable
User-defined variables can be added to the DC optimal power flow model using the [`@addVariable`](@ref @addVariable) macro. It also allows immediate assignment of initial primal and dual values. For example:
```@example dcopf
@addVariable(analysis, 0.0 <= y <= 0.2, primal = 0.1, lower = 10.0, upper = 0.0)
nothing # hide
```

We can also define collections of variables:
```@example dcopf
@addVariable(analysis, 0.0 <= x[i = 1:2] <= 0.4, primal = [0.1, 0.2], upper = [0.0; -2.5])
nothing # hide
```

---

##### Add Constraints
Custom constraints can be added to the DC optimal power flow model using the [`@addConstraint`](@ref @addConstraint) macro. These constraints are not limited to user-defined variables; any optimization variable defined up to that point can be used. Let us focus on the voltage angle variables:
```@example dcopf
θ = analysis.method.variable.voltage.angle
nothing # hide
```

Next, a new constraint can be defined, and at the same time, an initial dual value can be specified:
```@example dcopf
@addConstraint(analysis, 0.1 <= x[1] + 2 * x[2] + y + θ[2] <= 0.2, dual = 0.0)
nothing # hide
```

Collections of constraints can also be defined:
```@example dcopf
@addConstraint(analysis, [i = 1:2], x[i] + 2 * θ[i] <= 0.6, dual = [0.0; 0.5])
nothing # hide
```

---

##### Delete Constraints
To remove a constraint, use the [`remove!`](@ref remove!) function with the `:constraint` symbol. For example, to remove the first added constraint:
```@example dcopf
remove!(analysis, :constraint; index = 1)
nothing # hide
```

---

##### Objective Function
Users can modify the objective function using the [`set_objective_function`](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.set_objective_function) function from the JuMP package. Here is an example of how it can be achieved:
```@example dcopf
expr = 1100.2 * analysis.method.variable.power.active[1]^2 - 50 * x[1] - x[2]^2 + y + 123
JuMP.set_objective_function(analysis.method.jump, analysis.method.objective - expr)
nothing # hide
```

We can now observe the updated objective function as follows:
```@repl dcopf
JuMP.objective_function(analysis.method.jump)
```

---

##### Optimal Power Flow Solution
Users can now solve the extended formulation using:
```@example dcopf
powerFlow!(analysis; verbose = 1)
nothing # hide
```

After solving, users can access the optimal values as follows:
```@repl dcopf
analysis.power.generator.active
analysis.voltage.angle
analysis.extended.solution
```

---

## [Power Analysis](@id DCOptimalPowerAnalysisManual)
After obtaining the solution from the DC optimal power flow, we can calculate powers related to buses and branches using the [`power!`](@ref power!(::DcPowerFlow)) function. For instance, let us consider the power system for which we obtained the DC optimal power flow solution:
```@example dcopfpower
using JuliaGrid, JuMP # hide
using Ipopt
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.17)
addBus!(system; label = "Bus 2", active = 0.1, conductance = 0.04)
addBus!(system; label = "Bus 3", active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, minFromBus = -0.12, maxFromBus = 0.12)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

@generator(minActive = 0.0)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, maxActive = 0.5)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 0.2, maxActive = 0.2)

cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.2; 500; 80])
cost!(system; generator = "Generator 2", active = 1, piecewise = [10.8 12.3; 14.7 16.8])

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)
nothing # hide
```

Now we can calculate the active powers using the following function:
```@example dcopfpower
power!(analysis)
nothing # hide
```

Finally, to display the active power injections and from-bus active power flows, we can use the following code:
```@repl dcopfpower
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.power.from.active)
```

!!! note "Info"
    To better understand the powers associated with buses and branches that are calculated by the [`power!`](@ref power!(::DcPowerFlow)) function, we suggest referring to the tutorials on [DC Optimal Power Flow](@ref DCOptimalPowerAnalysisTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print Power System Data](@ref PrintPowerSystemDataAPI) or [Print Power System Summary](@ref PrintPowerSystemSummaryAPI). For example, to create a bus data with the desired units, users can use the following function:
```@example dcopfpower
@voltage(pu, deg)
@power(MW, MVAr)
printBusData(analysis)
@default(unit) # hide
nothing # hide
```

---

##### Active Power Injection
To calculate active power injection associated with a specific bus, the function can be used:
```@repl dcopfpower
active = injectionPower(analysis; label = "Bus 2")
```

---

##### Active Power Injection from Generators
To calculate active power injection from the generators at a specific bus, the function can be used:
```@repl dcopfpower
active = supplyPower(analysis; label = "Bus 2")
```

---

##### Active Power Flow
Similarly, we can compute the active power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl dcopfpower
active = fromPower(analysis; label = "Branch 2")
active = toPower(analysis; label = "Branch 2")
```
