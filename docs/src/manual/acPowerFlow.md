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

## [Reusing PowerSystem Type](@id ACReusingPowerSystemTypeManual)
The initial application of the reusable `PowerSystem` type is simple: it can be shared among various methods, which can yield benefits. For example, the Gauss-Seidel method is commonly used for a speedy approximate solution, whereas the Newton-Raphson method is typically utilized for the precise final solution. Thus, we can execute the Gauss-Seidel method for a limited number of iterations, as exemplified below:
```@example ReusingPowerSystemType
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 2, reactive = 0.05, susceptance = 0.03)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, conductance = 0.02)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 2.3)

acModel!(system)

gs = gaussSeidel(system)
for iteration = 1:3
    solve!(system, gs)
end
```

Next, we can initialize the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method and start the algorithm from that point:
```@example ReusingPowerSystemType
analysis = newtonRaphson(system)

for i = 1:system.bus.number
    analysis.voltage.magnitude[i] = gs.voltage.magnitude[i]
    analysis.voltage.angle[i] = gs.voltage.angle[i]
end

for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

!!! note "Info"
    The functions [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) only modify the `PowerSystem` type to eliminate mistakes in the bus types as explained in the section [Bus Type Modification](@ref BusTypeModificationManual). Further, the functions [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) do not modify the `PowerSystem` type at all. Therefore, it is safe to use the same `PowerSystem` type for multiple analyses once it has been created.

Next, the `PowerSystem` composite type, including its incorporated `ac` field, can be employed without limitations. It can be automatically modified using functions like [`demandBus!`](@ref demandBus!), [`shuntBus!`](@ref shuntBus!), [`addBranch!`](@ref addBranch!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), [`addGenerator!`](@ref addGenerator!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!), allowing for seamless sharing of the `PowerSystem` type across different AC power flow analyses.   

To provide an example, let us envision a scenario where we initially set up a power system. Our objective is to observe the power system's performance under typical operational conditions and then compare it to an alternative situation. In this alternate scenario, we make adjustments to the output power of `Generator 2` and modify the active power demand at `Bus 2`. Additionally, we deactivate `Branch 3` from its operational state and introduce a new branch named `Branch 4`. This entire process can be effortlessly executed by reusing the `PowerSystem` composite type. In fact, to proceed with the previous example, you can simply execute this part of the code:
```@example ReusingPowerSystemType
outputGenerator!(system; label = "Generator 2", active = 2.5)
demandBus!(system; label = "Bus 2", active = 0.2)

statusBranch!(system; label = "Branch 3", status = 0)
addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 3", reactance = 0.03)

analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```
Please note that the [`acModel!`](@ref acModel!) function is executed only once. Each function that adds components or mutates them will automatically update the `PowerSystem` type with the `ac` field.

---

## [Reusing ACPowerFlow Type](@id ReusingACPowerFlowTypeManual)
Reusing the `ACPowerFlow` abstract type essentially involves circumventing the repetitive execution of functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel).

This can be achieved by utilizing functions like [`demandBus!`](@ref demandBus!), [`shuntBus!`](@ref shuntBus!), [`addBranch!`](@ref addBranch!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), [`addGenerator!`](@ref addGenerator!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!), albeit with some limitations. For instance, the fast Newton-Raphson algorithm utilizes constant Jacobian matrices created when the `ACPowerFlow` type is instantiated, which means that modifications using [`addBranch!`](@ref addBranch!), [`statusBranch!`](@ref statusBranch!), or [`parameterBranch!`](@ref parameterBranch!) are not feasible.

Therefore, to offer a straightforward method for reusing the `ACPowerFlow` abstract type without encountering unexpected errors in results, users can supply the `ACPowerFlow` type as an argument to any functions responsible for adding or modifying the `PowerSystem` composite type. If the modifications are permissible, they will be executed, thus altering the `PowerSystem` composite type accordingly. In contrast, JuliaGrid provides error messages to prevent potential mistakes.

Let us take a look at the following power system, where we have performed an AC power flow analysis:
```@example ReusingACPowerFlowType
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 2, reactive = 0.05, susceptance = 0.03)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, conductance = 0.02)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 2.3)
addGenerator!(system; label = "Generator 3", bus = "Bus 3", active = 0.3)

acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

For instance, we can deactivate `Generator 3` and add `Branch 4` to the previously constructed power system. Without executing the [`newtonRaphson`](@ref newtonRaphson) function, we can proceed with the iterations:
```@example ReusingACPowerFlowType
statusGenerator!(system, analysis; label = "Generator 3", status = 0)
addBranch!(system, analysis; label = "Branch 4", from = "Bus 1", to = "Bus 3")

for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

However, attempting to take` Generator 2` out-of-service is not possible, as this operation would yield incorrect results if we proceed directly to the iterations. In this case, executing the [`newtonRaphson`](@ref newtonRaphson) function is mandatory:
```@repl ReusingACPowerFlowType
statusGenerator!(system, analysis; label = "Generator 2", status = 0)
```

!!! info "Info"
    When you provide the `ACPowerFlow` type as an argument to functions responsible for adding components or making modifications, you are essentially inquiring about the feasibility of reusing the `ACPowerFlow` type. If it is possible, the `PowerSystem` composite type will be modified, enabling you to seamlessly transition to the iterations without the need for any intermediate steps.

---

## [Generator Reactive Power Limits](@id GeneratorReactivePowerLimitsManual)
The function [`reactiveLimit!`](@ref reactiveLimit!) can be used by the user to check if the generators' output of reactive power is within the defined limits after obtaining the solution from the AC power flow analysis. This can be done by using the example code provided:
```@example GeneratorReactivePowerLimits
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1, active = 0.5)
addBus!(system; label = 3, type = 2, reactive = 0.05)
addBus!(system; label = 4, type = 2, reactive = 0.05)

addBranch!(system; from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; from = 2, to = 3, resistance = 0.03, reactance = 0.04)
addBranch!(system; from = 2, to = 4, resistance = 0.03, reactance = 0.004)

@generator(minReactive = -0.4, maxReactive = 0.2)
addGenerator!(system; bus = 1)
addGenerator!(system; bus = 3, reactive = 0.8)
addGenerator!(system; bus = 4, reactive = 0.9)

acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

violate = reactiveLimit!(system, analysis)

nothing # hide
```
The output reactive power of the observed generators is subject to limits which are defined as follows:
```@repl GeneratorReactivePowerLimits
[system.generator.capability.minReactive system.generator.capability.maxReactive]
```

After obtaining the solution of the AC power flow analysis, the [`reactiveLimit!`](@ref reactiveLimit!) function is used to internally calculate the output powers of the generators and verify if these values exceed the defined limits. Consequently, the variable `violate` indicates whether there is a violation of limits. In the provided example, it can be observed that the second and third generators violate the maximum limit:
```@repl GeneratorReactivePowerLimits
violate
```

Due to these violations of limits, the `PowerSystem` type undergoes modifications, and the output reactive power at the limit-violating generators is adjusted as follows:
```@repl GeneratorReactivePowerLimits
system.generator.output.reactive
```

To ensure that these values stay within the limits, the bus type must be changed from the generator bus (`type = 2`) to the demand bus (`type = 1`), as shown below:
```@repl GeneratorReactivePowerLimits
system.bus.layout.type
```

After modifying the `PowerSystem` type as described earlier, we can run the simulation again with the following code:
```@example GeneratorReactivePowerLimits
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
Once the simulation is complete, we can verify that all generator reactive power outputs now satisfy the limits by checking the violate variable again:
```@repl GeneratorReactivePowerLimits
violate = reactiveLimit!(system, analysis)
```

!!! note "Info"
    The [`reactiveLimit!`](@ref reactiveLimit!) function changes the `PowerSystem` composite type deliberately because it is intended to help users create the power system where all reactive power outputs of the generators are within limits.

---


##### New Slack Bus
Looking at the following code example, we can see that the output limits of the generator are set only for the first generator that is connected to the slack bus:
```@example NewSlackBus
using JuliaGrid # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, reactive = 0.05)
addBus!(system; label = "Bus 2", type = 1, active = 0.5)
addBus!(system; label = "Bus 3", type = 2)
addBus!(system; label = "Bus 4", type = 2)

@branch(resistance = 0.01)
addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; from = "Bus 2", to = "Bus 3", reactance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 4", reactance = 0.004)

addGenerator!(system; bus = "Bus 1", minReactive = 0.0, maxReactive = 0.2)
addGenerator!(system; bus = "Bus 4", reactive = 0.3)

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

Upon checking the limits, we can observe that the slack bus has been transformed by executing the following code:
```@repl NewSlackBus
violate = reactiveLimit!(system, analysis)
```
Here, the generator connected to the slack bus is violating the minimum reactive power limit, which indicates the need to convert the slack bus. It is important to note that the new slack bus can be created only from the generator bus (`type = 2`). We will now perform another AC power flow analysis on the modified system using the following code:
```@example NewSlackBus
analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```

After examining the bus voltages, we will focus on the angles:
```@repl NewSlackBus
analysis.voltage.angle
```
We can observe that the angles have been calculated based on the new slack bus. JuliaGrid offers the function to adjust these angles to match the original slack bus as follows:
```@example NewSlackBus
adjustAngle!(system, analysis; slack = "Bus 1")
```
Here, the `slack` keyword should correspond to the label of the slack bus. After executing the above code, the updated results can be viewed:
```@repl NewSlackBus
analysis.voltage.angle
```