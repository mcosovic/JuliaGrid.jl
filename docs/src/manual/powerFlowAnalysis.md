# [Power Flow Analysis](@id PowerFlowAnalysisManual)

The calculation of bus voltages is essential to solving the power flow problem. The composite type `PowerSystem`, which includes `bus`, `branch`, and `generator` fields, is required to obtain a solution. Additionally, depending on the type of power flow used, either `acModel` or `dcModel` must be used.

After creating the composite type `PowerSystem`, the next step is to create the composite type `Result`, which has fields `bus`, `branch`, `generator`, and `algorithm`. To initialize the iterative method for the AC power flow, the `Result` composite type must be created using any of the following functions:
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel).

To solve the AC power flow problem and obtain bus voltages, the following functions can be employed:
* [`mismatch!`](@ref mismatch!)
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

## [Bus Type Modification](@id BusTypeModificationManual)
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

## [Setup Starting Voltages](@id SetupStartingVoltagesManual)
To begin analysing the AC power flow in JuliaGrid, we must first establish the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Once the power system is set up, we can select one of the available methods for solving the AC power flow problem, such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming we have selected the Newton-Raphson method, we can use the following code snippet:
```@example initializeACPowerFlow
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 1, bus = 2, magnitude = 1.1)
addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```

Here, in this code snippet, the function [`newtonRaphson`](@ref newtonRaphson) generates starting voltage vectors in polar coordinates, where the magnitudes and angles are constructed as:
```@repl initializeACPowerFlow
result.bus.voltage.magnitude
result.bus.voltage.angle
```
The starting values for the voltage angles are defined based on the initial values given within the buses:
```@repl initializeACPowerFlow
system.bus.voltage.angle
```
On the other hand, the starting voltage magnitudes are determined by a combination of the initial values specified within the buses and the setpoints provided within the generators:
```@repl initializeACPowerFlow
system.bus.voltage.magnitude
system.generator.voltage.magnitude
```
!!! note "Info"
    The rule governing the specification of starting voltage magnitudes is simple. If a bus has an in-service generator and is declared the generator bus (`type = 2`), then the starting voltage magnitudes are specified using the setpoint provided within the generator. This is because the generator bus has known values of voltage magnitude that are specified within the generator.

Finally, let us add the generator at the slack bus using the following code snippet:
```@example initializeACPowerFlowSlack
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 1, bus = 2, magnitude = 1.1)
addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)
addGenerator!(system; label = 3, bus = 1, magnitude = 1.3)

acModel!(system)

result = newtonRaphson(system)

nothing # hide
```
The starting voltages are now as follows:
```@repl initializeACPowerFlowSlack
result.bus.voltage.magnitude
```
!!! note "Info"
    Thus, if an in-service generator exists on the slack bus, the starting value of the voltage magnitude is specified using the setpoints provided within the generators. This is a consequence of the fact that the slack bus has a known voltage magnitude. If a generator exists on the slack bus, its value is used, otherwise, the value is defined based on the initial voltage magnitude specified within the bus.

---

##### Custom Starting Voltages
This method of specifying starting values has a significant advantage in that it allows the user to easily change the starting voltage magnitudes and angles, which play a crucial role in iterative methods. For instance, suppose we define our power system as follows:
```@example initializeACPowerFlowFlat
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = 2, type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = 3, type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; label = 2, bus = 3, magnitude = 1.2)

acModel!(system)

nothing # hide
```
Now, the user can initiate a "flat start" without interfering with the input data. This can be easily done as follows:
```@example initializeACPowerFlowFlat
for i = 1:system.bus.number
    system.bus.voltage.magnitude[i] = 1.0
    system.bus.voltage.angle[i] = 0.0
end

result = newtonRaphson(system)
nothing # hide
```
The starting voltage values are:
```@repl initializeACPowerFlowFlat
result.bus.voltage.magnitude
result.bus.voltage.angle
```
Thus, we start with a set of voltage magnitude values that are constant throughout iteration, and the rest of the values correspond to the "flat start".

---

## [AC Power Flow Solution](@id ACPowerFlowSolutionManual)
To solve the AC power flow problem using JuliaGrid, we first need to create the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Here is an example:
```@example ACPowerFlowSolution
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

acModel!(system)

nothing # hide
```

Once the AC model is defined, we can choose the method to solve the power flow problem. JuliaGrid provides four methods: [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel). For example, to use the Newton-Raphson method to solve the power flow problem, we can call the newtonRaphson [`newtonRaphson`](@ref newtonRaphson) as follows:
```@example ACPowerFlowSolution
result = newtonRaphson(system)
nothing # hide
```
This function sets up the desired method for an iterative process based on two functions: [mismatch!](@ref mismatch!) and [solvePowerFlow!](@ref solvePowerFlow!). The [mismatch!](@ref mismatch!) function calculates the active and reactive power injection mismatches using the given voltage magnitudes and angles, while [solvePowerFlow!](@ref solvePowerFlow!) computes the new voltage magnitudes and angles.

To perform an iterative process with the Newton-Raphson or Fast Newton-Raphson methods in JuliaGrid, the [`mismatch!`](@ref mismatch!) function must be included inside the iteration loop. For instance:
```@example ACPowerFlowSolution
result = newtonRaphson(system)
for iteration = 1:100
    mismatch!(system, result)
    solvePowerFlow!(system, result)
end
nothing # hide
```
After the process is completed, the solution to the AC power flow problem can be accessed as follows:
```@repl ACPowerFlowSolution
result.bus.voltage.magnitude
result.bus.voltage.angle
```

In contrast, the iterative loop of the Gauss-Seidel method does not require the [`mismatch!`](@ref mismatch!) function:
```@example ACPowerFlowSolution
result = gaussSeidel(system)
for iteration = 1:100
    solvePowerFlow!(system, result)
end
nothing # hide
```
In these examples, the algorithms run until the specified number of iterations is reached.

---

##### Breaking the Iterative Process
You can terminate the iterative process using the [`mismatch!`](@ref mismatch!) function, which is why mismatches are computed separately. The following code shows an example of how to use the [`mismatch!`](@ref mismatch!) function to break out of the iteration loop:
```@example ACPowerFlowSolution
result = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end
nothing # hide
```
The [mismatch!](@ref mismatch!) function returns the maximum values of active and reactive power injection mismatches, which are commonly used as a convergence criterion in iterative AC power flow algorithms. Note that the [`mismatch!`](@ref mismatch!) function can also be used to terminate the loop when using the Gauss-Seidel method, even though it is not required.

!!! tip "Tip"
    To ensure an accurate count of iterations, it is important for the user to place the iteration counter after the condition expressions within the if construct. Counting the iterations before this point can result in an incorrect number of iterations, as it leads to an additional iteration being performed.

---

## [DC Power Flow Solution](@id DCPowerFlowSolutionManual)
To solve the DC power flow problem using JuliaGrid, we start by creating the `PowerSystem` composite type and defining the DC model with the [dcModel!](@ref dcModel!) function. Here's an example:
```@example DCPowerFlowSolution
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

dcModel!(system)

nothing # hide
```
Next, we can solve the DC problem by calling the [`solvePowerFlow`](@ref solvePowerFlow) function, which also returns the `Result` composite type:
```@example DCPowerFlowSolution
result = solvePowerFlow(system)
nothing # hide
```
The bus voltage angles obtained can be accessed as follows:
```@repl DCPowerFlowSolution
result.bus.voltage.angle
nothing # hide
```

---

## [Reusable Power System Model](@id ReusablePowerSystemModel)
After creating the power system, the AC and/or DC models can be generated for it, and they can then be reused for different types of power flow analysis, as demonstrated by creating the power system and its models once again:
```@example ReusablePowerSystemType
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 1.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.0)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.0)

acModel!(system)
dcModel!(system)

nothing # hide
```

Applying different methods sequentially can be beneficial. For example, the Gauss-Seidel method is often used to obtain a quick approximate solution, while the Newton-Raphson method is typically used to obtain the final accurate solution. Therefore, we can run the Gauss-Seidel method for just a few iterations, as shown below:
```@example ReusablePowerSystemType
resultGS = gaussSeidel(system)
for iteration = 1:3
    solvePowerFlow!(system, resultGS)
end
```
The resulting voltages are:
```@repl ReusablePowerSystemType
resultGS.bus.voltage.magnitude
resultGS.bus.voltage.angle
```

Next, we can initialize the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method and start the algorithm from that point:
```@example ReusablePowerSystemType
result = newtonRaphson(system)
for i = 1:system.bus.number
    result.bus.voltage.magnitude[i] = resultGS.bus.voltage.magnitude[i]
    result.bus.voltage.angle[i] = resultGS.bus.voltage.angle[i]
end

for iteration = 1:100
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end
```
The final solutions are:
```@repl ReusablePowerSystemType
result.bus.voltage.magnitude
result.bus.voltage.angle
```

It can be noted that in the given example, the same `PowerSystem` composite type is repeatedly utilized. Additionally, the same type can also be employed in the context of DC power flow analysis:
```@example ReusablePowerSystemType
resultDC = solvePowerFlow(system)
nothing # hide
```
The bus voltage angles are:
```@repl ReusablePowerSystemType
resultDC.bus.voltage.angle
```
!!! note "Info"
    The functions [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) only modify the `PowerSystem` type to eliminate mistakes in the bus types as explained in the section [Bus Type Modification](@ref BusTypeModificationManual). Further, the functions [`mismatch!`](@ref mismatch!), [`solvePowerFlow!`](@ref solvePowerFlow!), and [`solvePowerFlow`](@ref solvePowerFlow) do not modify the `PowerSystem` type at all.

---

## [Post-Processing Analysis](@id PostProcessingAnalysisModel)
After obtaining the solution from the AC or DC power flow analysis, we can calculate various electrical quantities related to buses, branches, and generators using the [`bus!`](@ref bus!), [`branch!`](@ref branch!), and [`generator!`](@ref generator!) functions. Let us set up an AC power flow analysis:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 1.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.0)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 2, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.0)

acModel!(system)

result = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

nothing # hide
```

Once the power flow analysis is completed using the Newton-Raphson method, we can use the above-mentioned functions to compute the relevant data for buses, branches, and generators. Here is an example code snippet that demonstrates this process:
```@example ComputationPowersCurrentsLosses
bus!(system, result)
branch!(system, result)
generator!(system, result)

nothing # hide
```

Each of these functions is responsible for populating the corresponding fields of the `Result` type, such as `bus`, `branch`, or `generator`. For instance, we can compute the active and reactive power injections in megawatts (MW) and megavolt-ampere reactive (MVAr) using the code snippet below:
```@repl ComputationPowersCurrentsLosses
@base(system, MVA, V);
system.base.power.value * result.bus.power.injection.active
system.base.power.value * result.bus.power.injection.reactive
```

---

## [Generator Reactive Power Limits](@id GeneratorReactivePowerLimitsManual)
After obtaining the solution from the AC power flow analysis, user can check whether the output of reactive power of the generators is within the defined limits using function [`reactivePowerLimit!`](@ref reactivePowerLimit!):
```@example GeneratorReactivePowerLimits
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 1.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.0)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 2, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.0)

acModel!(system)

result = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

violate = reactivePowerLimit!(system, result)

nothing # hide
```
