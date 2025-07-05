# [DC Power Flow](@id DCPowerFlowManual)
To perform the DC power flow, we first need to have the `PowerSystem` type that has been created with the DC model. Following that, we can construct the power flow model encapsulated within the `DcPowerFlow` type by employing the following function:
* [`dcPowerFlow`](@ref dcPowerFlow).

---

To solve the DC power flow problem and acquire bus voltage angles, users can use the following function:
* [`solve!`](@ref solve!(::DcPowerFlow)).

Once the DC power flow solution is obtained, JuliaGrid provides a function for computing powers:
* [`power!`](@ref power!(::DcPowerFlow)).

Alternatively, instead of using functions responsible for solving power flow and computing powers, users can use the wrapper function:
* [`powerFlow!`](@ref powerFlow!(::DcPowerFlow)).

Users can also access specialized functions for computing specific types of [powers](@ref DCPowerAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## [Power Flow Solution](@id DCPowerFlowSolutionManual)
To solve the DC power flow problem using JuliaGrid, we start by creating the `PowerSystem` type and defining the DC model with the [`dcModel!`](@ref dcModel!) function. Here is an example:
```@example DCPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

dcModel!(system)
nothing # hide
```

The [`dcPowerFlow`](@ref dcPowerFlow) function can be used to establish the DC power flow problem:
```@example DCPowerFlowSolution
analysis = dcPowerFlow(system)
nothing # hide
```

!!! tip "Tip"
    By default, the user activates `LU` factorization to solve the system of linear equations. Users may also choose the `LDLt`, `QR` or `KLU` factorization methods explicitly:
    ```julia DCPowerFlowSolution
    analysis = dcPowerFlow(system, KLU)
    ```
    The `KLU` method, using the Gilbert-Peierls algorithm, can significantly speed up power flow computations [davisklu](@cite).

To obtain the bus voltage angles, we can call the [`solve!`](@ref solve!(::DcPowerFlow)) function as follows:
```@example DCPowerFlowSolution
solve!(analysis)
nothing # hide
```

Once the solution is obtained, the bus voltage angles can be accessed using:
```@repl DCPowerFlowSolution
print(system.bus.label, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    For implementation insights, we suggest referring to the tutorial on [DC Power Flow Analysis](@ref DCPowerFlowTutorials).

---

##### Wrapper Function
JuliaGrid provides a wrapper function for DC power flow analysis and also supports the computation of powers using the [powerFlow!](@ref powerFlow!(::DcPowerFlow)) function:
```@example DCPowerFlowSolution
analysis = dcPowerFlow(system)
powerFlow!(analysis; verbose = 2)
nothing # hide
```

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example DCPowerFlowSolution
@voltage(pu, deg)
printBusData(analysis)
nothing # hide
```

Next, users can easily customize the print results for specific buses, for example:
```julia
printBusData(analysis; label = "Bus 1", header = true)
printBusData(analysis; label = "Bus 2")
printBusData(analysis; label = "Bus 3", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file as follows:
```julia
open("bus.txt", "w") do file
    printBusData(analysis, file)
end
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printBusData(analysis, io; style = false)
CSV.write("bus.csv", CSV.File(take!(io); delim = "|"))
```

---

## [Power System Update](@id DCPowerSystemAlterationManual)
We begin by creating the `PowerSystem` type with the [`powerSystem`](@ref powerSystem) function. The DC model is then configured using [`dcModel!`](@ref dcModel!) function. After that, we initialize the `DcPowerFlow` type through the [`dcPowerFlow`](@ref dcPowerFlow) function and solve the resulting power flow problem:
```@example DCPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 2.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

dcModel!(system)

analysis = dcPowerFlow(system)
powerFlow!(analysis)
nothing # hide
```

Next, we modify the existing `PowerSystem` type within the DC model using add and update functions. Then, we create a new `DcPowerFlow` type based on the modified system and solve the power flow problem:
```@example DCPowerFlowSolution
updateBus!(system; label = "Bus 2", active = 0.4)

addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.3)
updateBranch!(system; label = "Branch 1", status = 0)

addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 1.5)
updateGenerator!(system; label = "Generator 1", active = 1.9)

analysis = dcPowerFlow(system)
powerFlow!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `PowerSystem` within the `dc` field from the beginning when implementing changes to the existing power system.

---

## [Power Flow Update](@id DCPowerFlowUpdateManual)
An advanced methodology involves users establishing the `DcPowerFlow` type just once. After this initial setup, users can integrate new branches and generators, and also have the capability to modify buses, branches, and generators, all without the need to recreate the `DcPowerFlow` type. This is particularly beneficial when the previously computed nodal matrix factorization can be reused.

Let us now revisit our defined `PowerSystem` and `DcPowerFlow` types:
```@example DCPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 2.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

dcModel!(system)

analysis = dcPowerFlow(system)
powerFlow!(analysis)
nothing # hide
```

Next, we modify the existing `PowerSystem` within the DC model as well as the `DcPowerFlow` type using add and update functions. We then immediately proceed to solve the power flow problem:
```@example DCPowerFlowSolution
updateBus!(analysis; label = "Bus 2", active = 0.4)

addBranch!(analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.3)
updateBranch!(analysis; label = "Branch 1", status = 0)

addGenerator!(analysis; label = "Generator 2", bus = "Bus 2", active = 1.5)
updateGenerator!(analysis; label = "Generator 1", active = 1.9)

powerFlow!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate both the `PowerSystem` within the `dc` field and the `DcPowerFlow` from the beginning when implementing changes to the existing power system. Additionally, JuliaGrid can reuse symbolic factorizations of LU or LDLt, as long as the nonzero pattern of the nodal matrix remains consistent between power system configurations.

---

##### Reusing Matrix Factorization
Drawing from the preceding example, our focus now shifts to finding a solution involving modifications that entail adjusting the active power demand at `Bus 2`, introducing a new generator at `Bus 2`, and fine-tuning the output power of `Generator 1`. It is important to note that these adjustments do not impact the branches, leaving the nodal matrix unchanged. To resolve this updated system, users can simply execute the [`powerFlow!`](@ref powerFlow!(::DcPowerFlow)) function:
```@example DCPowerFlowSolution

updateBus!(analysis; label = "Bus 2", active = 0.2)
addGenerator!(analysis; label = "Generator 3", bus = "Bus 2", active = 0.3)
updateGenerator!(analysis; label = "Generator 1", active = 2.1)

powerFlow!(analysis)
nothing # hide
```

In this scenario, JuliaGrid will recognize instances where the user has not modified branch parameters affecting the nodal matrix. Consequently, JuliaGrid will leverage the previously performed nodal matrix factorization, resulting in a significantly faster solution compared to recomputing the factorization.

---

##### Limitations
Attempting to change the slack bus or leaving the existing slack bus without a connected generator, and then proceeding directly to the power flow calculation, is not feasible. In such cases, JuliaGrid will raise an error:
```@repl DCPowerFlowSolution
updateGenerator!(analysis; label = "Generator 1", status = 0)
```

To resolve this, the user must recreate the `DcPowerFlow` type rather than attempting to reuse the existing one:
```julia DCPowerFlowSolution
updateGenerator!(system; label = "Generator 1", status = 0)

analysis = dcPowerFlow(system)
powerFlow!(analysis)
```

---

## [Power Analysis](@id DCPowerAnalysisManual)
After obtaining the solution, we can calculate powers related to buses, branches, and generators using the [`power!`](@ref power!(::DcPowerFlow)) function. For example, let us consider the power system for which we obtained the DC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

analysis = dcPowerFlow(system)
powerFlow!(analysis)
nothing # hide
```

Now we can calculate the active powers using the following function:
```@example ComputationPowersCurrentsLosses
power!(analysis)
nothing # hide
```

Next, let us convert the base power unit to megavolt-amperes (MVA):
```@example ComputationPowersCurrentsLosses
@base(system, MVA, V)
nothing # hide
```

Finally, here are the calculated active power values in megawatts (MW) corresponding to buses and branches:
```@repl ComputationPowersCurrentsLosses
print(system.bus.label, system.base.power.value * analysis.power.injection.active)
print(system.branch.label, system.base.power.value * analysis.power.from.active)
```

!!! note "Info"
    To better understand the powers associated with buses, branches, and generators that are calculated by the [`power!`](@ref power!(::DcPowerFlow)) function, we suggest referring to the tutorials on [DC Power Flow Analysis](@ref DCPowerAnalysisTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print Power System Data](@ref PrintPowerSystemDataAPI) or [Print Power System Summary](@ref PrintPowerSystemSummaryAPI). For example, users have the option to print the results in the REPL using any units that have been configured:
```@example ComputationPowersCurrentsLosses
@power(MW, pu)
printBranchData(analysis)
@default(unit) # hide
nothing # hide
```

---

##### Active Power Injection
To calculate active power injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active = injectionPower(analysis; label = "Bus 1")
```

---

##### Active Power Injection from Generators
To calculate active power injection from the generators at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active = supplyPower(analysis; label = "Bus 1")
```

---

##### Active Power Flow
Similarly, we can compute the active power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl ComputationPowersCurrentsLosses
active = fromPower(analysis; label = "Branch 2")
active = toPower(analysis; label = "Branch 2")
```

---

##### Generator Active Power Output
Finally, we can compute the active power output of a particular generator using the function:
```@repl ComputationPowersCurrentsLosses
active = generatorPower(analysis; label = "Generator 1")
@voltage(pu, pu, V) # hide
@power(pu, pu, pu) # hide
```