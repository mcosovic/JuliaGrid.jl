# [Power Flow Analysis](@id powerFlowAnalysisManual)

The calculation of bus voltages is essential to solving the power flow problem. The composite type `PowerSystem`, which includes `bus`, `branch`, and `generator` fields, is required to obtain a solution. Additionally, depending on the type of power flow used, either `acModel` or `dcModel` must be used.

After creating the composite type `PowerSystem`, the next step is to create the composite type `Result`, which has fields `bus`, `branch`, `generator`, and `algorithm`. To initialize the iterative method for the AC power flow, the `Result` composite type must be created using any of the following functions:
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel).

To solve the AC power flow problem and obtain bus voltages, the following functions can be employed:
* [`mismatchPowerFlow!`](@ref mismatchPowerFlow!)
* [`solvePowerFlow!`](@ref solvePowerFlow!).

 On the other hand, for the DC power flow, the `Result` composite type is created when determining the bus voltage angles through the use of the function:
* [`solvePowerFlow`](@ref solvePowerFlow).

JuliaGrid offers a set of post-processing analysis functions for calculating powers, losses, and currents associated with buses, branches, or generators after obtaining AC or DC power flow solutions:
* [`bus!`](@ref bus!)
* [`branch!`](@ref branch!)
* [`generator!`](@ref generator!).

Finally, the package provides two additional functions. One function validates the reactive power limits of generators once the AC power flow solution has been computed. The other function adjusts the voltage angles to match the angle of an arbitrary slack bus:
* [`reactivePowerLimit!`](@ref reactivePowerLimit!)
* [`adjustVoltageAngle!`](@ref adjustVoltageAngle!).

---

## Bus Type Modification
Depending on how the system is constructed, the types of buses that are initially set are checked and can be changed during the initialization process, using one of the available functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming the Newton-Raphson method has been chosen, to explain the details, we can observe a power system with only buses and generators. The following code snippet can be used:
```@example busType
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 2)
addBus!(system; label = 3, type = 2)

addGenerator!(system; label = 1, bus = 2)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```
Initially, the bus labelled with 1 is set as the slack bus (`type = 3`), and the buses with labels 2 and 3 are generator buses (`type = 2`). However, the bus labelled with 3 does not have a generator, and JuliaGrid considers this a mistake and changes the corresponding bus to a demand bus (`type = 1`):
```@repl busType
system.bus.layout.type
```

In contrast, if a bus is initially defined as a demand bus (`type = 1`) and later a generator is added to it, the bus type will not be changed to a generator bus (`type = 2`). Instead, it will remain as a demand bus:
```@example busTypeStay
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1)
addBus!(system; label = 3, type = 2)

addGenerator!(system; label = 1, bus = 2)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```

In this example, the bus labelled with 2 remains a demand bus (`type = 1`) even though it has a generator:
```@repl busTypeStay
system.bus.layout.type
```
!!! note "Info"
    Only buses that are defined as generator buses (`type = 2`) but do not have a in-service generator connected to them will have their type changed to a demand bus (`type = 1`).

---

## Initialize AC Power Flow
To begin analysing the AC power flow in JuliaGrid, we must first establish the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Once the power system is set up, we can select one of the available methods for solving the AC power flow problem, such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming we have selected the Newton-Raphson method, we can use the following code snippet:
```@example initializeACPowerFlow
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 1, bus = 2, magnitude = 1.1)
addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```

Here, in this code snippet, the function [`newtonRaphson`](@ref newtonRaphson) generates initial voltage vectors in polar coordinates, where the magnitudes and angles are constructed as:
```@repl initializeACPowerFlow
result.bus.voltage.magnitude
result.bus.voltage.angle
```
The initial values for the voltage angles are defined based on the values given within the buses:
```@repl initializeACPowerFlow
system.bus.voltage.angle
```
On the other hand, the initial voltage magnitudes are determined by a combination of the values specified within the buses and the setpoints provided within the generators:
```@repl initializeACPowerFlow
system.bus.voltage.magnitude
system.generator.voltage.magnitude
```
!!! note "Info"
    The rule governing the specification of initial voltage magnitudes is simple. If a bus has an in-service generator and is declared as a generator bus (`type = 2`), then the initial voltage magnitudes are specified using the setpoint provided within the generator. This is because the generator bus has known values of voltage magnitude that are specified within the generator, and this initial value also represents the solution for the corresponding bus.

Finally, let us add the generator at the slack bus using the following code snippet:
```@example initializeACPowerFlowSlack
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 1, bus = 2, magnitude = 1.1)
addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)
addGenerator!(system; label = 3, bus = 1, magnitude = 1.3)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```
The initial voltages are now as follows:
```@repl initializeACPowerFlowSlack
result.bus.voltage.magnitude
```
!!! note "Info"
    Thus, if an in-service generator exists on the slack bus, the initial value of the voltage magnitude is specified using the setpoints provided within the generators, and this initial value represents the solution for the slack bus. This is a consequence of the fact that the slack bus has a known voltage magnitude. If a generator exists on the slack bus, its value is used, otherwise, the value is defined based on the voltage magnitude specified within the bus.

---

##### Use Initial Custom Voltages
This method of specifying initial values has a significant advantage in that it allows the user to easily change the initial voltage magnitudes and angles, which play a crucial role in iterative methods. For instance, suppose we define our power system as follows:
```@example initializeACPowerFlowFlat
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)

acModel!(system)

nothing # hide
```
Now, the user can initiate the system with a "flat start" without interfering with the input data. This can be easily done as follows:
```@example initializeACPowerFlowFlat
system.bus.voltage.magnitude = fill(1.0, system.bus.number)
system.bus.voltage.angle = fill(0.0, system.bus.number)

result = newtonRaphson(system)
nothing # hide
```
The initial voltage values are:
```@repl initializeACPowerFlowFlat
result.bus.voltage.magnitude
result.bus.voltage.angle
```
Thus, we start with a set of voltage magnitude values that are constant throughout iteration, and the rest of the values correspond to the "flat start".

---