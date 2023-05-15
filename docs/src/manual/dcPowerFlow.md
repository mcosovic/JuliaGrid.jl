# [DC Power Flow](@id DCPowerFlowManual)
To perform the DC power flow, you first need to have the `PowerSystem` composite type that has been created with the `dcModel`. After that, create the `Model` composite type to establish the DC power flow framework using the function:
* [`dcPowerFlow`](@ref dcPowerFlow).

To solve the power flow problem and obtain bus voltage angles, use the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)).

Once you have the DC power flow solution, you can use JuliaGrid's post-processing analysis functions to calculate powers associated with buses, branches, or generators:
* [`analysisBus`](@ref analysisBus(::PowerSystem, ::DCPowerFlow))
* [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::DCPowerFlow))
* [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::DCPowerFlow)).

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

addGenerator!(system; label = 1, bus = 2, active = 3.2)

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

## [Reusable Power Flow Types](@id DCReusablePowerFlowTypesManual)
The `PowerSystem` composite type with its `dcModel` field can be utilized without restrictions and can be modified automatically using functions such as [`shuntBus!`](@ref shuntBus!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!). This facilitates sharing the `PowerSystem` type across various DC power flow analyses.

Furthermore, the `Model` composite type can be reused within the same method used to solve the DC power flow problem.

---

##### Reusable PowerSystem Type
Once you have created the power system and DC model, you can reuse them for multiple DC power flow analyses. Specifically, you can modify the structure of the power system using the [`statusBranch!`](@ref statusBranch!) and [`parameterBranch!`](@ref parameterBranch!) functions without having to recreate the system from scratch. As an example, let us say we wish to take the branch labelled 3 out-of-service from the previous example and conduct the DC power flow again:
```@example DCPowerFlowSolution
statusBranch!(system; label = 3, status = 0)

model = dcPowerFlow(system)
solve!(system, model)
nothing # hide
```

---

##### Reusable Model Type
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

---

## [Power Analysis](@id DCPowerAnalysisManual)
After obtaining the solution from the DC power flow, we can calculate powers related to buses, branches, and generators using the [`analysisBus`](@ref analysisBus(::PowerSystem, ::DCPowerFlow)), [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::DCPowerFlow)), and [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::DCPowerFlow)) functions. For instance, let us consider the power system for which we obtained the DC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 0.1)
addBus!(system; label = 3, type = 1, active = 0.05)

addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01)

addGenerator!(system; label = 1, bus = 2, active = 3.2)

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

---

##### Bus Powers
Now we can calculate the acctive powers related to buses using the following function:
```@example ComputationPowersCurrentsLosses
power = analysisBus(system, model)

nothing # hide
```
For example, to display the active power injections in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.injection.active
```

!!! note "Info"
    To better understand the powers associated with buses that are calculated by the [`analysisBus`](@ref analysisBus(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC power flow analysis](@ref DCBusPowersTutorials).

---

##### Branch Powers
Similarly, we can compute the active powers related to branches using the following function:
```@example ComputationPowersCurrentsLosses
power = analysisBranch(system, model)

nothing # hide
```
For instance, to display the active power flows at branches in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.from.active
system.base.power.value * power.to.active
```

!!! note "Info"
    To better understand the powers associated with branches that are calculated by the [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC power flow analysis](@ref DCBranchPowersTutorials).

---

##### Generator Power
Finally, we can compute the active output powers of the generators using the function:
```@example ComputationPowersCurrentsLosses
power = analysisGenerator(system, model)

nothing # hide
```
To display the active power produced by generators in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.active
```

!!! note "Info"
    To better understand the powers associated with generators that are calculated by the [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::DCPowerFlow)) function, we suggest referring to the tutorials on [DC power flow analysis](@ref DCGeneratorPowersTutorials).
