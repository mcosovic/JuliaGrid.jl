# [DC Power Flow](@id DCPowerFlowManual)
To perform the DC power flow, you first need to have the `PowerSystem` composite type that has been created with the `dc` model. Following that, you can construct the power flow model encapsulated within the `DCPowerFlow` composite type by employing the following function:
* [`dcPowerFlow`](@ref dcPowerFlow).

To solve the DC power flow problem and acquire bus voltage angles, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)).

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
addBus!(system; label = "Bus 2", type = 2, active = 0.1)
addBus!(system; label = "Bus 3", type = 2, active = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; bus = "Bus 3", active = 3.2)

dcModel!(system)

analysis = dcPowerFlow(system)
```

In this example, the slack bus (`type = 3`) corresponds to the `Bus 1`. However, this bus does not have an in-service generator connected to it. Consequently, JuliaGrid recognizes this as an error and attempts to assign a new slack bus from the available generator buses (`type = 2`) that have connected in-service generators. In this particular example, the `Bus 3` will become the new slack bus. As a result, we can observe the updated array of bus types within the defined set of buses:
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
[collect(keys(sort(system.bus.label; byvalue = true))) system.bus.layout.type]
```

!!! note "Info"
    The bus that is defined as the slack bus (`type = 3`) but lacks a connected in-service generator will have its type changed to the demand bus (`type = 1`). Meanwhile, the first generator bus (`type = 2`) with an in-service generator connected to it will be assigned as the new slack bus (`type = 3`).

---


## [Power Flow Solution](@id DCPowerFlowSolutionManual)
To solve the DC power flow problem using JuliaGrid, we start by creating the `PowerSystem` composite type and defining the DC model with the [`dcModel!`](@ref dcModel!) function. Here is an example:
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

The [`dcPowerFlow`](@ref dcPowerFlow) function can be used to establish the DC power flow problem. It factorizes the nodal matrix to prepare for determining the bus voltage angles:
```@example DCPowerFlowSolution
analysis = dcPowerFlow(system)
nothing # hide
```

To obtain the bus voltage angles, we can call the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function as follows:
```@example DCPowerFlowSolution
solve!(system, analysis)
nothing # hide
```

Once the solution is obtained, the bus voltage angles can be accessed using:
```@repl DCPowerFlowSolution
[collect(keys(sort(system.bus.label; byvalue = true)))  analysis.voltage.angle]
nothing # hide
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [DC power flow](@ref DCPowerFlowTutorials) for insights into the implementation.

---

## [Power Analysis](@id DCPowerAnalysisManual)
After obtaining the solution from the DC power flow, we can calculate powers related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function. For instance, let us consider the power system for which we obtained the DC power flow solution:
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

dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

nothing # hide
```

Now we can calculate the active powers using the following function:
```@example ComputationPowersCurrentsLosses
power!(system, analysis)

nothing # hide
```

First, let us create label arrays to display active power injections at each bus and active power flows at each "from" end of the branch:
```@example ComputationPowersCurrentsLosses
labelBus = collect(keys(sort(system.bus.label; byvalue = true)))
labelBranch = collect(keys(sort(system.branch.label; byvalue = true)))

nothing # hide
```

Next, let us convert the base power unit to megavolt-amperes (MVA):
```@example ComputationPowersCurrentsLosses
@base(system, MVA, V)

nothing # hide
```

Finally, here are the calculated active power values in megawatts (MW) corresponding to buses and branches:
```@repl ComputationPowersCurrentsLosses
[labelBus system.base.power.value * analysis.power.injection.active]
[labelBranch system.base.power.value * analysis.power.from.active]
```

!!! note "Info"
    To better understand the powers associated with buses, branches and generators that are calculated by the [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC power flow analysis](@ref DCPowerAnalysisTutorials).

To calculate specific quantities for particular components rather than calculating active powers for all components, users can make use of the provided functions below.

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
Similarly, we can compute the active power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
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

---

## [Reusing Power System Model](@id DCReusingPowerSystemModelManual)
The `PowerSystem` composite type, along with its previously established `dc` field, offers unlimited versatility. This facilitates the seamless sharing of the `PowerSystem` type across various DC power flow analyses. All fields automatically adjust when any of the functions that add components or modify their parameters are utilized:
* [`addBranch!`](@ref addBranch!),
* [`addGenerator!`](@ref addGenerator!),
* [`updateBus!`](@ref updateBus!),
* [`updateBranch!`](@ref updateBranch!),
* [`updateGenerator!`](@ref updateGenerator!).

To illustrate, let us consider a scenario where we initially establish a power system and find a solution:
```@example ReusingPowerSystem
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 2.1)

dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
```

Next, we want to find a solution in a situation where we make changes to the output power of `Generator 1`, take `Generator 2` out-of-service, and modify the active power demand at `Bus 2`. Furthermore, we deactivate `Branch 3` from its operational state and introduce a new branch called `Branch 4`. This entire process can be effortlessly accomplished by reusing the `PowerSystem` composite type and its `dc` field formed previously using the function [`dcModel!`](@ref dcModel!). As demonstrated in the following code snippet:
```@example ReusingPowerSystem
updateGenerator!(system; label = "Generator 1", active = 0.3)
updateGenerator!(system; label = "Generator 2", status = 0)
updateBus!(system; label = "Bus 2", active = 0.2)

updateBranch!(system; label = "Branch 3", status = 0)
addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 3", reactance = 0.03)

analysis = dcPowerFlow(system)
solve!(system, analysis)
```

---

## [Reusing Power Flow Model](@id DCReusingPowerFlowModelManual)
To reuse the `DCPowerFlow` composite type, you essentially skip running the [`dcPowerFlow`](@ref dcPowerFlow) function. This function is responsible for conducting bus type checks, as explained in the [Bus Type Modification](@ref DCBusTypeModificationManual) section, and for factorizing the nodal matrix. In practical terms, reusing the `DCPowerFlow` composite type involves making adjustments exclusively to demand, shunt, or generator parameters while leaving the power system's branch parameters unchanged.

However, it is important to exercise caution when modifying these parameters. For example, in the previous instance where we deactivated `Generator 1`, adjustments to the slack bus may be necessary. You can achieve this by utilizing the [`dcPowerFlow`](@ref dcPowerFlow) function. Nevertheless, our primary objective is to minimize the usage of this function and leverage its output for reusability.

To address this challenge and enable the straightforward reuse of the `DCPowerFlow` composite type without encountering unexpected errors in results, users can pass the `DCPowerFlow` type as an argument to any functions that add or modify the `PowerSystem` composite type. If the modifications are permissible and lead to the correct solutions, they will be executed and will accordingly alter the composite types.

Building upon the earlier example, we can continue to refine the power system by making changes to the output power of `Generator 1` and adjusting the active power demand at `Bus 2` within the existing system. Without invoking the [`dcPowerFlow`](@ref dcPowerFlow) function, we can move ahead to obtain a solution using the following code snippet:
```@example ReusingPowerSystem
updateGenerator!(system, analysis; label = "Generator 1", status = 1)
updateBus!(system, analysis; label = "Bus 2", active = 0.4)

solve!(system, analysis)
```

However, if the intention is to reuse the `DCPowerFlow` type once more, this time with the aim of modifying the status of `Branch 3`, it becomes apparent that in this scenario, reusing the `DCPowerFlow` type is not feasible:
```@repl ReusingPowerSystem
updateBranch!(system, analysis; label = "Branch 3", status = 0)
```

!!! info "Info"
    By providing the `DCPowerFlow` type as an argument when adding components or making updates, you inquire about the potential for reusing this type. If feasible, the `PowerSystem` composite type is updated, and if necessary, the `DCPowerFlow` type is adjusted for a valid solution. This streamlined process allows for a seamless transition to the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function without intermediate steps. JuliaGrid empowers users to modify generator and demand power while reusing the optimized `DCPowerFlow` type, which utilizes a factorized nodal matrix for efficient computation.
