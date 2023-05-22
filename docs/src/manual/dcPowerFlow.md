# [DC Power Flow](@id DCPowerFlowManual)
To perform the DC power flow, you first need to have the `PowerSystem` composite type that has been created with the `dcModel`. After that, create the `Model` composite type to establish the DC power flow framework using the function:
* [`dcPowerFlow`](@ref dcPowerFlow).

To solve the DC power flow problem and acquire bus voltage angles, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)).

After obtaining the solution for DC power flow, JuliaGrid offers a post-processing analysis function to compute powers associated with buses, branches, and generators:
* [`power`](@ref power(::PowerSystem, ::DCAnalysis)).

Moreover, there exist specific functions dedicated to calculating powers related to a particular bus, branch, or generator:
* [`powerBus`](@ref powerBus(::PowerSystem, ::DCAnalysis))
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::DCAnalysis))
* [`powerGenerator`](@ref powerBranch(::PowerSystem, ::DCAnalysis)).

---

## [Bus Type Modification](@id DCBusTypeModificationManual)
During the initialization process, the designated slack bus, which is initially set, undergoes examination and can be altered using the [`dcPowerFlow`](@ref dcPowerFlow) function. Here is an example:
```julia
system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 2, active = 0.1)
addBus!(system; label = 3, type = 2, active = 0.05)

addGenerator!(system; label = 1, bus = 3, active = 3.2)

dcModel!(system)

model = dcPowerFlow(system)
```

In this example, the slack bus (`type = 3`) corresponds to the bus labelled as 1. However, this bus does not have an in-service generator connected to it. Consequently, JuliaGrid recognizes this as an error and attempts to assign a new slack bus from the available generator buses (`type = 2`) that have connected in-service generators. In this particular example, the bus labeled as 3 will become the new slack bus.

!!! note "Info"
    The bus that is defined as the slack bus (`type = 3`) but lacks a connected in-service generator will have its type changed to the demand bus (`type = 1`). Meanwhile, the first generator bus (`type = 2`) with an active generator connected to it will be assigned as the new slack bus `(type = 3`).

---

## [Power Flow Solution](@id DCPowerFlowSolutionManual)
To solve the DC power flow problem using JuliaGrid, we start by creating the `PowerSystem` composite type and defining the DC model with the [`dcModel!`](@ref dcModel!) function. Here is an example:
```@example DCPowerFlowSolution
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 0.1)
addBus!(system; label = 3, type = 1, active = 0.05)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01)

addGenerator!(system; label = 1, bus = 1, active = 3.2)

dcModel!(system)

nothing # hide
```

The [`dcPowerFlow`](@ref dcPowerFlow) function can be used to establish the DC power flow problem. It factorizes the nodal matrix to prepare for determining the bus voltage angles:
```@example DCPowerFlowSolution
model = dcPowerFlow(system)
nothing # hide
```

To obtain the bus voltage angles, we can call the [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)) function as follows:
```@example DCPowerFlowSolution
solve!(system, model)
nothing # hide
```

Once the solution is obtained, the bus voltage angles can be accessed using:
```@repl DCPowerFlowSolution
model.voltage.angle
nothing # hide
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [DC power flow](@ref DCPowerFlowTutorials) for insights into the implementation.

---

## [Reusing Created Types](@id DCReusingCreatedTypesManual)
The `PowerSystem` composite type with its `dcModel` field can be utilized without restrictions and can be modified automatically using functions such as [`shuntBus!`](@ref shuntBus!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!). This facilitates sharing the `PowerSystem` type across various DC power flow analyses.

Additionally, the `Model` composite type can be reused to solve the DC power flow problem again in scenarios involving functions such as [`shuntBus!`](@ref shuntBus!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!), or when there is a need to modify the demand throughout the system.

---

##### PowerSystem Composite Type
Once you have created the power system and DC model, you can reuse them for multiple DC power flow analyses. Specifically, you can modify the structure of the power system using the [`statusBranch!`](@ref statusBranch!) and [`parameterBranch!`](@ref parameterBranch!) functions without having to recreate the system from scratch. As an example, let us say we wish to take the branch labelled 3 out-of-service from the previous example and conduct the DC power flow again:
```@example DCPowerFlowSolution
statusBranch!(system; label = 3, status = 0)

model = dcPowerFlow(system)
solve!(system, model)
nothing # hide
```

---

##### Model Composite Type
The `Model` composite type contains a factorized nodal matrix, which means that users can reuse it when only modifying shunt or generator parameters and keeping the power system's branch parameters the same. This allows for more efficient computations as the factorization step is not repeated.

Therefore, by using only the functions [`shuntBus!`](@ref shuntBus!), [`statusGenerator!`](@ref statusGenerator!) and [`outputGenerator!`](@ref outputGenerator!), the `Model` composite type can be reused. For example, to change the output of the generator and compute the bus voltage angles again, one can use the following code:
```@example DCPowerFlowSolution
outputGenerator!(system; label = 1, active = 0.5)

solve!(system, model)
nothing # hide
```
Here, the previously factorized nodal matrix is utilized to obtain the new solution, which is more efficient than repeating the factorization step.
 
Additionally, users can change the active power demand at the buses by directly accessing the `PowerSystem` type. They can again reuse the `Model` composite type and factorized nodal matrix, as demonstrated below:
```@example DCPowerFlowSolution
system.bus.demand.active[2] = 0.15

solve!(system, model)
nothing # hide
```

!!! warning "Warning"
    Please be aware that you should not leave the slack bus without generators by using the [`statusGenerator!`](@ref statusGenerator!) function, as it can lead to incorrect results when reusing the `Model` composite type. In such cases, it is necessary to create the new `Model` type where the new slack bus is designated.

---

## [Power Analysis](@id DCPowerAnalysisManual)
After obtaining the solution from the DC power flow, we can calculate powers related to buses, branches, and generators using the [`power`](@ref power(::PowerSystem, ::DCAnalysis)) function. For instance, let us consider the power system for which we obtained the DC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 0.1)
addBus!(system; label = 3, type = 1, active = 0.05)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01)

addGenerator!(system; label = 1, bus = 1, active = 3.2)

dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

nothing # hide
```

After that, we can convert the base power unit to megavolt-amperes (MVA) to display the results in that unit as follows:
```@example ComputationPowersCurrentsLosses
@base(system, MVA, V)

nothing # hide
```

Now we can calculate the active powers using the following function:
```@example ComputationPowersCurrentsLosses
powers = power(system, model)

nothing # hide
```

For example, to display the active power injections and flows in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * powers.bus.injection.active
system.base.power.value * powers.branch.from.active
```

!!! note "Info"
    To better understand the powers associated with buses, branches and generators that are calculated by the [`power`](@ref power(::PowerSystem, ::DCAnalysis)) function, we suggest referring to the tutorials on [DC power flow analysis](@ref DCBusPowersTutorials).

---

##### Bus Powers
Instead of calculating powers for all components, users have the option to compute specific quantities for particular components. In this regard, the following function can be utilized to calculate active powers associated with a specific bus:
```@example ComputationPowersCurrentsLosses
powers = powerBus(system, model; label = 1)

nothing # hide
```
For instance, to display the active power injections in megawatts (MW), the following code can be used:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * powers.injection.active
```

---

##### Branch Powers
Similarly, we can compute the active powers related to a particular branch using the following function:
```@example ComputationPowersCurrentsLosses
powers = powerBranch(system, model; label = 2)

nothing # hide
```
For instance, to display the active power flows at branches in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * powers.from.active
```

---

##### Generator Power
Finally, we can compute the active output power of a particular generator using the function:
```@example ComputationPowersCurrentsLosses
powers = powerGenerator(system, model; label = 1)

nothing # hide
```
To display the active power produced by generators in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * powers.output.active
```

