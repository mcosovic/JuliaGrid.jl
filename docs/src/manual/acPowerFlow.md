# [AC Power Flow](@id ACPowerFlowManual)
To perform the AC power flow analysis, you will first need the `PowerSystem` composite type that has been created with the `ac` model. Then, you can create the `ACPowerFlow` abstract type using one of the following functions:
* [`newtonRaphson`](@ref newtonRaphson),
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX),
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB),
* [`gaussSeidel`](@ref gaussSeidel).

These functions will set up the AC power flow framework. To obtain bus voltages and solve the power flow problem, you can use the following functions:
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)),
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)).

After obtaining the AC power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses, branches, or generators:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::AC)).

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

Additionally, the package provides two functions for reactive power limit validation of generators and adjusting the voltage angles to match an arbitrary bus angle:
* [`reactiveLimit!`](@ref reactiveLimit!),
* [`adjustAngle!`](@ref adjustAngle!).

---

## [Bus Type Modification](@id BusTypeModificationManual)
Depending on how the system is constructed, the types of buses that are initially set are checked and can be changed during the initialization process, using one of the available functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming the Newton-Raphson method has been chosen, to explain the details, we can observe a power system with only buses and generators. The following code snippet can be used:
```julia
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2)
addBus!(system; label = "Bus 3", type = 2)

addGenerator!(system; bus = "Bus 2")

acModel!(system)

analysis = newtonRaphson(system)
```

Initially, the `Bus 1` is set as the slack bus (`type = 3`), and the `Bus 2` and `Bus 3` are generator buses (`type = 2`). However, the `Bus 3` does not have a generator, and JuliaGrid considers this a mistake and changes the corresponding bus to a demand bus (`type = 1`).

After this step, JuliaGrid verifies the slack bus. Initially, the slack bus (`type = 3`) corresponds to `Bus 1`, but since it does not have an in-service generator connected to it, JuliaGrid recognizes it as an error. Therefore, JuliaGrid assigns a new slack bus from the available generator buses (`type = 2`) that have connected in-service generators. In this specific example, `Bus 2` becomes the new slack bus.

```@setup busType
using JuliaGrid
@default(unit)
@default(template)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2)
addBus!(system; label = "Bus 3", type = 2)

addGenerator!(system; bus = "Bus 2")

acModel!(system)

analysis = newtonRaphson(system)
```

As a result, we can observe the updated array of bus types within the defined set of buses:
```@repl busType
[collect(keys(sort(system.bus.label; byvalue = true))) system.bus.layout.type]
```

Note that, if a bus is initially defined as the demand bus (`type = 1`) and later a generator is added to it, the bus type will not be changed to the generator bus (`type = 2`). Instead, it will remain as a demand bus.

!!! note "Info"
    The type of only those buses that are defined as generator buses (`type = 2`) but do not have a connected in-service generator will be changed to demand buses (`type = 1`).

    The bus that is defined as the slack bus (`type = 3`) but lacks a connected in-service generator will have its type changed to the demand bus (`type = 1`). Meanwhile, the first generator bus (`type = 2`) with an in-service generator connected to it will be assigned as the new slack bus (`type = 3`).

---

## [Setup Starting Voltages](@id SetupStartingVoltagesManual)
To begin analysing the AC power flow in JuliaGrid, we must first establish the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Once the power system is set up, we can select one of the available methods for solving the AC power flow problem, such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming we have selected the Newton-Raphson method, we can use the following code snippet:
```@example initializeACPowerFlow
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = "Bus 3", type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; bus = "Bus 1", magnitude = 1.3)
addGenerator!(system; bus = "Bus 2", magnitude = 1.1)
addGenerator!(system; bus = "Bus 3", magnitude = 1.2)

acModel!(system)

analysis = newtonRaphson(system)

nothing # hide
```

Here, in this code snippet, the function [`newtonRaphson`](@ref newtonRaphson) generates starting voltage vectors in polar coordinates, where the magnitudes and angles are constructed as:
```@repl initializeACPowerFlow
[analysis.voltage.magnitude analysis.voltage.angle]
```
The starting voltage magnitudes are determined by a combination of the initial values specified within the buses and the setpoints provided within the generators:
```@repl initializeACPowerFlow
[system.bus.voltage.magnitude system.generator.voltage.magnitude]
```

On the other hand, the starting values for the voltage angles are defined based on the initial values given within the buses:
```@repl initializeACPowerFlow
system.bus.voltage.angle
```

!!! note "Info"
    The rule governing the specification of starting voltage magnitudes is simple. If a bus has an in-service generator and is declared the generator bus (`type = 2`), then the starting voltage magnitudes are specified using the setpoint provided within the generator. This is because the generator bus has known values of voltage magnitude that are specified within the generator.

    On the other hand, the slack bus (`type = 3`) always requires an in-service generator. The starting value of the voltage magnitude at the slack bus is determined exclusively by the setpoints provided within the generators connected to it. This is a result of the slack bus having a known voltage magnitude that must be maintained.

---

##### Custom Starting Voltages
This method of specifying starting values has a significant advantage in that it allows the user to easily change the starting voltage magnitudes and angles, which play a crucial role in iterative methods. For instance, suppose we define our power system as follows:
```@example initializeACPowerFlowFlat
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = "Bus 3", type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; bus = "Bus 1", magnitude = 1.1)
addGenerator!(system; bus = "Bus 3", magnitude = 1.2)

acModel!(system)

nothing # hide
```
Now, the user can initiate a "flat start" without interfering with the input data. This can be easily done as follows:
```@example initializeACPowerFlowFlat
for i = 1:system.bus.number
    system.bus.voltage.magnitude[i] = 1.0
    system.bus.voltage.angle[i] = 0.0
end

analysis = newtonRaphson(system)
nothing # hide
```
The starting voltage values are:
```@repl initializeACPowerFlowFlat
[analysis.voltage.magnitude analysis.voltage.angle]
```

Consequently, when using the Newton-Raphson method, the iteration begins with a fixed set of voltage magnitude values that remain constant throughout the process. The remaining values are initialized as part of the "flat start" approach.

---

## [Power Flow Solution](@id ACPowerFlowSolutionManual)
To solve the AC power flow problem using JuliaGrid, we first need to create the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Here is an example:
```@example ACPowerFlowSolution
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.01, reactance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, reactance = 0.01)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.01, reactance = 0.20)

addGenerator!(system; bus = "Bus 1", active = 3.2, magnitude = 1.1)
addGenerator!(system; bus = "Bus 2", active = 3.2, magnitude = 1.2)

acModel!(system)

nothing # hide
```

Once the AC model is defined, we can choose the method to solve the power flow problem. JuliaGrid provides four methods: [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel). For example, to use the Newton-Raphson method to solve the power flow problem, we can call the [`newtonRaphson`](@ref newtonRaphson) function as follows:
```@example ACPowerFlowSolution
analysis = newtonRaphson(system)
nothing # hide
```
This function sets up the desired method for an iterative process based on two functions: [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)). The [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function calculates the active and reactive power injection mismatches using the given voltage magnitudes and angles, while [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) computes the voltage magnitudes and angles.

To perform an iterative process with the Newton-Raphson or fast Newton-Raphson methods in JuliaGrid, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function must be included inside the iteration loop. For instance:
```@example ACPowerFlowSolution
for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
nothing # hide
```

Upon completion of the AC power flow analysis, the solution is conveyed through the bus voltage magnitudes and angles. Here are the values corresponding to the buses:
```@repl ACPowerFlowSolution
label = collect(keys(sort(system.bus.label; byvalue = true)));

[label analysis.voltage.magnitude analysis.voltage.angle]
```

In contrast, the iterative loop of the Gauss-Seidel method does not require the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function:
```@example ACPowerFlowSolution
analysis = gaussSeidel(system)
for iteration = 1:100
    solve!(system, analysis)
end
nothing # hide
```
In these examples, the algorithms run until the specified number of iterations is reached.

!!! note "Info"
    We recommend that the reader refer to the tutorial on [AC power flow analysis](@ref ACPowerFlowTutorials), where we explain the implementation of the methods and algorithm structures in detail.

---

##### Breaking the Iterative Process
You can terminate the iterative process using the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function, which is why mismatches are computed separately. The following code shows an example of how to use the the function to break out of the iteration loop:
```@example ACPowerFlowSolution
analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
nothing # hide
```
The [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function returns the maximum absolute values of active and reactive power injection mismatches, which are commonly used as a convergence criterion in iterative AC power flow algorithms. Note that the function can also be used to terminate the loop when using the Gauss-Seidel method, even though it is not required.

!!! tip "Tip"
    To ensure an accurate count of iterations, it is important for the user to place the iteration counter after the condition expressions within the if construct. Counting the iterations before this point can result in an incorrect number of iterations, as it leads to an additional iteration being performed.

---

## [Power and Current Analysis](@id ACPowerCurrentAnalysisManual)
After obtaining the solution from the AC power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)) functions. For instance, let us consider the power system for which we obtained the AC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, susceptance = 0.03)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, conductance = 0.02)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

nothing # hide
```

We can now utilize the provided functions to compute powers and currents. The following functions can be used for this purpose:
```@example ComputationPowersCurrentsLosses
power!(system, analysis)
current!(system, analysis)
nothing # hide
```

For instance, if we want to show the active power injections at each bus and the current flow angles at each "to" bus end of the branch, we can employ the following code:
```@repl ComputationPowersCurrentsLosses
[collect(keys(sort(system.bus.label; byvalue = true))) analysis.power.injection.active]
[collect(keys(sort(system.branch.label; byvalue = true))) analysis.current.to.angle]

```

!!! note "Info"
    To better understand the powers associated with buses, branches and generators that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [AC power flow analysis](@ref ACPowerAnalysisTutorials).

To calculate specific quantities for particular components rather than calculating powers or currents for all components, users can make use of the provided functions below.

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = shuntPower(system, analysis; label = "Bus 3")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl ComputationPowersCurrentsLosses
active, reactive = fromPower(system, analysis; label = "Branch 2")
active, reactive = toPower(system, analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = chargingPower(system, analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging or shunt admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the particular branch, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = seriesPower(system, analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Generator Active and Reactive Power Output
We can compute the active and reactive power output of a particular generator using the function:
```@repl ComputationPowersCurrentsLosses
active, reactive = generatorPower(system, analysis; label = "Generator 1")
```

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = injectionCurrent(system, analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = fromCurrent(system, analysis; label = "Branch 2")
magnitude, angle = toCurrent(system, analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the "from" bus end to the "to" bus end, you can use the following function:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = seriesCurrent(system, analysis; label = "Branch 2")
```

---