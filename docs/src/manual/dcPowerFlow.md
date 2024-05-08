# [DC Power Flow](@id DCPowerFlowManual)
To perform the DC power flow, we first need to have the `PowerSystem` type that has been created with the DC model. Following that, we can construct the power flow model encapsulated within the `DCPowerFlow` type by employing the following function:
* [`dcPowerFlow`](@ref dcPowerFlow).

To solve the DC power flow problem and acquire bus voltage angles, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)).

---

After obtaining the solution for DC power flow, JuliaGrid offers a post-processing analysis function to compute active powers associated with buses, branches, and generators:
* [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)).

Additionally, there are specialized functions dedicated to calculating specific types of active powers related to particular buses, branches, or generators:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::DCPowerFlow)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::DCPowerFlow)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::DCPowerFlow)),
* [`toPower`](@ref toPower(::PowerSystem, ::DCPowerFlow)),
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::DCPowerFlow)).

---

## [Bus Type Modification](@id DCBusTypeModificationManual)
During the initialization process, the designated slack bus, which is initially set, undergoes examination and can be altered using the [`dcPowerFlow`](@ref dcPowerFlow) function. Here is an example:
```julia
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2)
addBus!(system; label = "Bus 3", type = 2)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; label = "Generator 1", bus = "Bus 3")

dcModel!(system)
analysis = dcPowerFlow(system)
```

In this example, the slack bus (`type = 3`) corresponds to the `Bus 1`. However, this bus does not have an in-service generator connected to it. Consequently, JuliaGrid recognizes this as an error and attempts to assign a new slack bus from the available generator buses (`type = 2`) that have connected in-service generators. In this particular example, the `Bus 3` will become the new slack bus. As a result, we can observe the updated array of bus types:
```@setup busType
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 0.1)
addBus!(system; label = "Bus 3", type = 2, active = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; bus = "Bus 3", active = 3.2)

dcModel!(system)
analysis = dcPowerFlow(system)
```

```@repl busType
print(system.bus.label, system.bus.layout.type)
```

!!! note "Info"
    The bus that is defined as the slack bus (`type = 3`) but lacks a connected in-service generator will have its type changed to the demand bus (`type = 1`). Meanwhile, the first generator bus (`type = 2`) with an in-service generator connected to it will be assigned as the new slack bus (`type = 3`).

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
    Here, the user triggers LU factorization as the default method for solving the DC power flow problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`, for instance:
    ```julia DCPowerFlowSolution
    analysis = dcPowerFlow(system, LDLt)
    ```

To obtain the bus voltage angles, we can call the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function as follows:
```@example DCPowerFlowSolution
solve!(system, analysis)
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

## [Power System Update](@id DCPowerSystemAlterationManual)
After establishing the `PowerSystem` type using the [`powerSystem`](@ref powerSystem) function and configuring the DC model with [`dcModel!`](@ref dcModel!), users gain the capability to incorporate new branches and generators. Furthermore, they can adjust buses, branches, and generators.

Once updates are completed, users can progress towards generating the `DCPowerFlow` type using the [`dcPowerFlow`](@ref dcPowerFlow) function. Ultimately, resolving the DC power flow is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function:
```@example DCPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem() # <- Initialize the PowerSystem instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 2.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

dcModel!(system)
analysis = dcPowerFlow(system) # <- Build DCPowerFlow for the defined power system
solve!(system, analysis)

updateBus!(system; label = "Bus 2", active = 0.4)

addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.15)
updateBranch!(system; label = "Branch 1", status = 0)

addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 1.5)
updateGenerator!(system; label = "Generator 1", active = 1.9)

analysis = dcPowerFlow(system) # <- Build DCPowerFlow for the updated power system
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This method removes the need to restart and recreate the `PowerSystem` within the `dc` field from the beginning when implementing changes to the existing power system.

---

## [Power Flow Update](@id DCPowerFlowUpdateManual)
An advanced methodology involves users establishing the `DCPowerFlow` type using [`dcPowerFlow`](@ref dcPowerFlow) just once. After this initial setup, users can integrate new branches and generators, and also have the capability to modify buses, branches, and generators, all without the need to recreate the `DCPowerFlow` type.

This advancement extends beyond the previous scenario where recreating the `PowerSystem` and DC model was unnecessary, to now include the scenario where `DCPowerFlow` also does not need to be recreated. Such efficiency can be particularly advantageous in cases where JuliaGrid can reuse nodal matrix factorization.

By modifying the previous example, we observe that we now create the `DCPowerFlow` type only once:
```@example DCPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem() # <- Initialize the PowerSystem instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 2.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

dcModel!(system)
analysis = dcPowerFlow(system) # <- Build DCPowerFlow for the defined power system
solve!(system, analysis)

updateBus!(system, analysis; label = "Bus 2", active = 0.4)

addBranch!(system, analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = .1)
updateBranch!(system, analysis; label = "Branch 1", status = 0)

addGenerator!(system, analysis; label = "Generator 2", bus = "Bus 2", active = 1.5)
updateGenerator!(system, analysis; label = "Generator 1", active = 1.9)

# <- No need for re-build; we have already updated the existing DCPowerFlow instance
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This method removes the need to restart and recreate both the `PowerSystem` within the `dc` field and the `DCPowerFlow` from the beginning when implementing changes to the existing power system. Additionally, JuliaGrid can reuse symbolic factorizations of LU or LDLt, as long as the nonzero pattern of the nodal matrix remains consistent between power system configurations.

---

##### Reusing Matrix Factorization
Drawing from the preceding example, our focus now shifts to finding a solution involving modifications that entail adjusting the active power demand at `Bus 2`, introducing a new generator at `Bus 2`, and fine-tuning the output power of `Generator 1`. It is important to note that these adjustments do not impact the branches leaving the nodal matrix unchanged. To resolve this updated system, users can simply execute the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function:
```@example DCPowerFlowSolution

updateBus!(system, analysis; label = "Bus 2", active = 0.2)
addGenerator!(system, analysis; label = "Generator 3", bus = "Bus 2", active = 0.3)
updateGenerator!(system, analysis; label = "Generator 1", active = 2.1)

solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    In this scenario, JuliaGrid will recognize instances where the user has not modified branch parameters affecting the nodal matrix. Consequently, JuliaGrid will leverage the previously performed nodal matrix factorization, resulting in a significantly faster solution compared to recomputing the factorization.

---

##### Limitations
The [`dcPowerFlow`](@ref dcPowerFlow) function oversees bus type validations, as detailed in the [Bus Type Modification](@ref DCBusTypeModificationManual) section. Consequently, if a user intends to change the slack bus or leaves an existing slack bus without a generator, proceeding directly to the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function is not feasible.

In these instances, JuliaGrid will raise an error:
```@repl DCPowerFlowSolution
updateGenerator!(system, analysis; label = "Generator 1", status = 0)
```

Now, the user must execute the [`dcPowerFlow`](@ref dcPowerFlow) function instead of attempting to reuse the `DCPowerFlow` type:
```julia DCPowerFlowSolution
updateGenerator!(system; label = "Generator 1", status = 0)

analysis = dcPowerFlow(system)
solve!(system, analysis)
```

!!! note "Info"
    After creating the `PowerSystem` and `DCPowerFlow` types, users can add or modify buses, branches, and generators before directly using the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function. JuliaGrid automatically executes the necessary functions when adjustments lead to a valid solution. However, if modifications are incompatible, like changing the slack bus, JuliaGrid raises an error to prevent misleading outcomes, ensuring accuracy.

---

## [Power Analysis](@id DCPowerAnalysisManual)
After obtaining the solution, we can calculate powers related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function. For example, let us consider the power system for which we obtained the DC power flow solution:
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
solve!(system, analysis)

nothing # hide
```

Now we can calculate the active powers using the following function:
```@example ComputationPowersCurrentsLosses
power!(system, analysis)

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
    To better understand the powers associated with buses, branches and generators that are calculated by the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC Power Flow Analysis](@ref DCPowerAnalysisTutorials).

To compute specific quantities for particular components, rather than calculating powers or currents for all components, users can utilize one of the provided functions below.

---

##### Active Power Injection
To calculate active power injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active Power Injection from Generators
To calculate active power injection from the generators at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active Power Flow
Similarly, we can compute the active power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl ComputationPowersCurrentsLosses
active = fromPower(system, analysis; label = "Branch 2")
active = toPower(system, analysis; label = "Branch 2")
```

---

##### Generator Active Power Output
Finally, we can compute the active power output of a particular generator using the function:
```@repl ComputationPowersCurrentsLosses
active = generatorPower(system, analysis; label = "Generator 1")
```