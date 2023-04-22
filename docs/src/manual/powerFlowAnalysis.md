# [Power Flow Analysis](@id powerFlowAnalysisManual)

The calculation of bus voltages is essential to solving the power flow problem. The composite type `PowerSystem`, which includes `bus`, `branch`, and `generator` fields, is required to obtain a solution. Additionally, depending on the type of power flow used, either `acModel` or `dcModel` must be used.

After creating the composite type `PowerSystem`, the next step is to create the composite type `Result`, which has fields `bus`, `branch`, `generator`, and `algorithm`. In the DC power flow, `Result` is created when determining the bus voltage angles using the [`dcPowerFlow`](@ref dcPowerFlow) function. On the other hand, the AC power flow requires the iterative method to be initialized, which is when the composite type `Result` is created using one of the following functions:
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel).

To calculate bus voltages, the appropriate function can be used depending on the type of power flow and method selected. The following functions are available:
* [`newtonRaphson!`](@ref newtonRaphson!)
* [`fastNewtonRaphson!`](@ref fastNewtonRaphson!)
* [`gaussSeidel!`](@ref gaussSeidel!)
* [`dcPowerFlow`](@ref dcPowerFlow).

JuliaGrid offers a set of post-processing analysis functions for calculating powers, losses, and currents associated with buses, branches, or generators after obtaining AC or DC power flow solutions:
* [`bus!`](@ref bus!)
* [`branch!`](@ref branch!)
* [`generator!`](@ref generator!).

Finally, the package provides two additional functions. One function validates the reactive power limits of generators once the AC power flow solution has been computed. The other function adjusts the voltage angles to match the angle of an arbitrary slack bus:
* [`reactivePowerLimit!`](@ref reactivePowerLimit!)
* [`adjustVoltageAngle!`](@ref adjustVoltageAngle!).

---

## [Initialize AC Power Flow](@id initializeACManual)
To begin analysing the AC power flow in JuliaGrid, we must first establish the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function:
```@example initializeACPowerFlow
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = -0.2)
addBus!(system; label = 2, type = 2, reactive = 0.5, magnitude = 1.1, angle = -0.1)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

acModel!(system)

nothing # hide
```

Once the power system is set up, we can select one of the available methods for solving the AC power flow problem, such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Let us assume we have chosen the Newton-Raphson method. To initialize the algorithm and create a `Result` composite type, we can use the following code snippet:
```@example initializeACPowerFlow
result = newtonRaphson(system)
nothing # hide
```

During this process, all necessary variables for the iterative process are initialized and evaluated based on the initial voltages. The initial voltages are set when we add buses to the power system, where we specify the magnitude and angle of the bus voltage in polar coordinates:
```@repl initializeACPowerFlow
system.bus.voltage.magnitude
system.bus.voltage.angle
```
These values are used as the starting point for the iterative process to solve the AC power flow equations:
```@repl initializeACPowerFlow
result.bus.voltage.magnitude
result.bus.voltage.angle
```

---

##### Use Initial Custom Voltages
To modify the predefined initial values, the user can access the `bus.voltage.magnitude ` and `bus.voltage.angle` variables and change their values before creating the `Result` composite type. For instance, to initiate "flat start", the following code can be used:

```@example initializeACPowerFlow
system.bus.voltage.magnitude = fill(1.0, system.bus.number)
system.bus.voltage.angle = fill(0.0, system.bus.number)

result = newtonRaphson(system)

nothing # hide
```

After running the above code, the initial values of voltage magnitude and angle will be:
```@repl initializeACPowerFlow
result.bus.voltage.magnitude
result.bus.voltage.angle
```

---

##### Use Generator Voltage Magnitude Setpoints
To initialize the AC power flow analysis, the user can utilize generator voltage magnitude setpoints. This means that the algorithm will use the voltage magnitudes defined during the construction of the generators to initialize the algorithm. This can be achieved by using the `generatorVoltage` with the [`@enable`](@ref @enable) macro, as shown in the example below:
```@example initializeACPowerFlow
@enable(generatorVoltage)

result = newtonRaphson(system)
```

After running the above code, the initial voltage magnitudes and angles will be:
```@repl initializeACPowerFlow
result.bus.voltage.magnitude
result.bus.voltage.angle
```
Additionally, we also provide the [`@disable`](@ref @disable) macro to turn off the usage of voltage magnitudes of generators in the initialization process.

!!! note "Info"
    It is worth noting that most open-source packages use predefined voltages in conjunction with generator voltage setpoints to define initial voltages.
