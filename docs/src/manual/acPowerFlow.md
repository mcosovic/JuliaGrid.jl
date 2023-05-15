# [AC Power Flow](@id ACPowerFlowManual)
To conduct an AC power flow analysis, you will first need the `PowerSystem` composite type that has been created with the `acModel`. Then, you can create the `Model` composite type using one of the following functions:
* [`newtonRaphson`](@ref newtonRaphson)
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX)
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB)
* [`gaussSeidel`](@ref gaussSeidel)

These functions will set up the AC power flow framework. To obtain bus voltages and solve the power flow problem, you can use the following functions:
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)).

After obtaining the AC power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers, losses, and currents associated with buses, branches, or generators:
* [`analysisBus`](@ref analysisBus(::PowerSystem, ::ACPowerFlow))
* [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::ACPowerFlow))
* [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::ACPowerFlow)).

Additionally, the package provides two functions for reactive power limit validation of generators and adjusting the voltage angles to match an arbitrary bus angle:
* [`reactiveLimit!`](@ref reactiveLimit!)
* [`adjustAngle!`](@ref adjustAngle!).

---

## [Bus Type Modification](@id BusTypeModificationManual)
Depending on how the system is constructed, the types of buses that are initially set are checked and can be changed during the initialization process, using one of the available functions such as [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel). Assuming the Newton-Raphson method has been chosen, to explain the details, we can observe a power system with only buses and generators. The following code snippet can be used:
```@example busType
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 2)
addBus!(system; label = 3, type = 2)

addGenerator!(system; label = 1, bus = 2)

acModel!(system)

model = newtonRaphson(system)

nothing # hide
```
Initially, the bus labelled with 1 is set as the slack bus (`type = 3`), and the buses with labels 2 and 3 are generator buses (`type = 2`). However, the bus labelled with 3 does not have a generator, and JuliaGrid considers this a mistake and changes the corresponding bus to a demand bus (`type = 1`):
```@repl busType
system.bus.layout.type
```

In contrast, if a bus is initially defined as the demand bus (`type = 1`) and later a generator is added to it, the bus type will not be changed to the generator bus (`type = 2`). Instead, it will remain as a demand bus:
```@example busTypeStay
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3)
addBus!(system; label = 2, type = 1)
addBus!(system; label = 3, type = 2)

addGenerator!(system; label = 1, bus = 2)

acModel!(system)

model = newtonRaphson(system)

nothing # hide
```

In this example, the bus labelled with 2 remains the demand bus (`type = 1`) even though it has the generator:
```@repl busTypeStay
system.bus.layout.type
```
!!! note "Info"
    The type of only those buses that are defined as generator buses (`type = 2`) but do not have a connected in-service generator will be changed to demand buses (`type = 1`).

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

model = newtonRaphson(system)

nothing # hide
```

Here, in this code snippet, the function [`newtonRaphson`](@ref newtonRaphson) generates starting voltage vectors in polar coordinates, where the magnitudes and angles are constructed as:
```@repl initializeACPowerFlow
model.voltage.magnitude
model.voltage.angle
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

Finally, we can add a generator to the slack bus of the previously created power system and then reinitialize the Newton-Raphson method:
```@example initializeACPowerFlow
addGenerator!(system; label = 3, bus = 1, magnitude = 1.3)

model = newtonRaphson(system)
nothing # hide
```
The starting voltages are now as follows:
```@repl initializeACPowerFlow
model.voltage.magnitude
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

model = newtonRaphson(system)
nothing # hide
```
The starting voltage values are:
```@repl initializeACPowerFlowFlat
model.voltage.magnitude
model.voltage.angle
```
Thus, we start with the set of voltage magnitude values that are constant throughout iteration, and the rest of the values correspond to the "flat start".

---

## [Power Flow Solution](@id ACPowerFlowSolutionManual)
To solve the AC power flow problem using JuliaGrid, we first need to create the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Here is an example:
```@example ACPowerFlowSolution
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.01, reactance = 0.20)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

acModel!(system)

nothing # hide
```

Once the AC model is defined, we can choose the method to solve the power flow problem. JuliaGrid provides four methods: [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel). For example, to use the Newton-Raphson method to solve the power flow problem, we can call the [`newtonRaphson`](@ref newtonRaphson) function as follows:
```@example ACPowerFlowSolution
model = newtonRaphson(system)
nothing # hide
```
This function sets up the desired method for an iterative process based on two functions: [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)). The [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function calculates the active and reactive power injection mismatches using the given voltage magnitudes and angles, while [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) computes the new voltage magnitudes and angles.

To perform an iterative process with the Newton-Raphson or Fast Newton-Raphson methods in JuliaGrid, the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function must be included inside the iteration loop. For instance:
```@example ACPowerFlowSolution
for iteration = 1:100
    mismatch!(system, model)
    solve!(system, model)
end
nothing # hide
```
After the process is completed, the solution to the AC power flow problem can be accessed as follows:
```@repl ACPowerFlowSolution
model.voltage.magnitude
model.voltage.angle
```

In contrast, the iterative loop of the Gauss-Seidel method does not require the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson))) function:
```@example ACPowerFlowSolution
model = gaussSeidel(system)
for iteration = 1:100
    solve!(system, model)
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
model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
nothing # hide
```
The [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function returns the maximum absolute values of active and reactive power injection mismatches, which are commonly used as a convergence criterion in iterative AC power flow algorithms. Note that the function can also be used to terminate the loop when using the Gauss-Seidel method, even though it is not required.

!!! tip "Tip"
    To ensure an accurate count of iterations, it is important for the user to place the iteration counter after the condition expressions within the if construct. Counting the iterations before this point can result in an incorrect number of iterations, as it leads to an additional iteration being performed.

---

## [Reusable Power Flow Types](@id ACReusablePowerFlowTypesManual)
The `PowerSystem` composite type with its `acModel` field can be used without limitations, and can be modified automatically using functions like [`shuntBus!`](@ref shuntBus!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), [`statusGenerator!`](@ref statusGenerator!), and [`outputGenerator!`](@ref outputGenerator!) functions. This allows the `PowerSystem` type to be shared across different analyses.

Additionally, the `Model` composite type can also be reused within the same method that solves the AC power flow problem.

Let us create the power system with its existing model once again:
```@example ReusablePowerSystemType
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = 2, type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = 3, type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.01, reactance = 0.20)

addGenerator!(system; label = 1, bus = 2, active = 3.2, magnitude = 1.2)

acModel!(system)

nothing # hide
```

---

##### Reusable PowerSystem Type
The initial application of the reusable `PowerSystem` type is simple: it can be shared among various methods, which can yield benefits. For example, the Gauss-Seidel method is commonly used for a speedy approximate solution, whereas the Newton-Raphson method is typically utilized for the precise final solution. Thus, we can execute the Gauss-Seidel method for a limited number of iterations, as exemplified below:
```@example ReusablePowerSystemType
gsModel = gaussSeidel(system)
for iteration = 1:3
    solve!(system, gsModel)
end
```

Next, we can initialize the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method and start the algorithm from that point:
```@example ReusablePowerSystemType
nrModel = newtonRaphson(system)

for i = 1:system.bus.number
    nrModel.voltage.magnitude[i] = gsModel.voltage.magnitude[i]
    nrModel.voltage.angle[i] = gsModel.voltage.angle[i]
end

for iteration = 1:100
    stopping = mismatch!(system, nrModel)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, nrModel)
end
```

Another way to utilize the reusable `PowerSystem` type is to make modifications to the power system parameters using built-in functions. For instance, we can alter the resistance of the branch labelled as 3, while still using the `PowerSystem` that was created earlier:
```@example ReusablePowerSystemType
parameterBranch!(system; label = 1, resistance = 0.06)

model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```

!!! note "Info"
    The functions [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) only modify the `PowerSystem` type to eliminate mistakes in the bus types as explained in the section [Bus Type Modification](@ref BusTypeModificationManual). Further, the functions [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) do not modify the `PowerSystem` type at all. Therefore, it is safe to use the same `PowerSystem` type for multiple analyses once it has been created.

---

##### Reusable Model Type
As we have seen, the `PowerSystem` type can be reused and modified using various functions, and the question now is whether we can do the same with the `Model` composite type. In fact, in the previous code snippet, we did not need to recreate the `Model` type after changing the resistance of the branch labelled 3. Thus, once the `Model` type is created, users can modify the power system's structure using functions [`shuntBus!`](@ref shuntBus!), [`statusBranch!`](@ref statusBranch!), [`parameterBranch!`](@ref parameterBranch!), and [`outputGenerator!`](@ref outputGenerator!), without having to recreate the `Model` type from scratch.

For instance, if the branch labelled 3 needs to be put out-of-service in the previously mentioned example, the AC power flow can be executed again by running the following code snippet:
```@example ReusablePowerSystemType
statusBranch!(system; label = 3, status = 0)

for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```
Here, the previously created `PowerSystem` and `Model` types are reused. This approach ensures that the algorithm has the "warm start" since the Newton-Raphson method starts with voltages obtained from the step where the branch was in-service.

!!! warning "Warning"
    It is important to note that this approach is only possible with the Newton-Raphson and Gauss-Seidel methods since these methods involve the power system structure inside the iteration loop. On the other hand, the fast Newton-Raphson algorithm has constant Jacobian matrices created when the `Model` type is created, which means that any modifications to the power system require creating the `Model` type again.

---

## [Power and Current Analysis](@id ACPowerCurrentAnalysisManual)
After obtaining the solution from the AC power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`analysisBus`](@ref analysisBus(::PowerSystem, ::ACPowerFlow)), [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::ACPowerFlow)), and [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::ACPowerFlow)) functions. For instance, let us consider the power system for which we obtained the AC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5)
addBus!(system; label = 2, type = 1, reactive = 0.05)
addBus!(system; label = 3, type = 1, active = 0.5)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 2, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)

addGenerator!(system; label = 1, bus = 2, active = 3.2)

acModel!(system)

model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

nothing # hide
```

After that, we can convert the base power unit to megavolt-amperes (MVA) to display the results in that unit as follows:
```@example ComputationPowersCurrentsLosses
@base(system, MVA, V)

nothing # hide
```

---

##### Bus Powers and Currents
Now we can calculate the powers and currents related to buses using the following function:
```@example ComputationPowersCurrentsLosses
power, current = analysisBus(system, model)

nothing # hide
```
For example, to display the active and reactive power injections in megawatts (MW) and megavolt-ampere reactive (MVAr), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.injection.active
system.base.power.value * power.injection.reactive
```

!!! note "Info"
    We note that for a detailed explanation of all the electrical quantities related to buses computed by the [`analysisBus`](@ref analysisBus(::PowerSystem, ::ACPowerFlow)) function, we recommend referring to the tutorials on [AC power flow analysis](@ref BusPowersCurrentsTutorials).

---

##### Branch Powers and Currents
Similarly, we can compute the powers and currents related to branches using the following function:
```@example ComputationPowersCurrentsLosses
power, current = analysisBranch(system, model)

nothing # hide
```
For instance, to display the active power flows at branches in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.from.active
system.base.power.value * power.to.active
```

!!! note "Info"
    We note that for a detailed explanation of all the electrical quantities related to branches computed by the [`analysisBranch`](@ref analysisBranch(::PowerSystem, ::ACPowerFlow)) function, we recommend referring to the tutorials on [AC power flow analysis](@ref BranchPowersCurrentsTutorials).

---

##### Generator Powers
Finally, we can compute the output powers of the generators using the function:
```@example ComputationPowersCurrentsLosses
power = analysisGenerator(system, model)

nothing # hide
```
For example, to display the active power produced by generators in megawatts (MW), we can use the following code:
```@repl ComputationPowersCurrentsLosses
system.base.power.value * power.active
```

!!! note "Info"
    We note that for a detailed explanation of all the electrical quantities related to generators computed by the [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::ACPowerFlow)) function, we recommend referring to the tutorials on [AC power flow analysis](@ref GeneratorPowersTutorials).

---

## [Generator Reactive Power Limits](@id GeneratorReactivePowerLimitsManual)
The function [`reactiveLimit!`](@ref reactiveLimit!) can be used by the user to check if the generators' output of reactive power is within the defined limits after obtaining the solution from the AC power flow analysis. This can be done by using the example code provided:
```@example GeneratorReactivePowerLimits
using JuliaGrid # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.5, reactive = 0.05)
addBus!(system; label = 2, type = 1, active = 0.5)
addBus!(system; label = 3, type = 2)
addBus!(system; label = 4, type = 2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)
addBranch!(system; label = 4, from = 2, to = 4, resistance = 0.03, reactance = 0.004)

@generator(minReactive = 0.0, maxReactive = 0.2)
addGenerator!(system; label = 1, bus = 3, active = 0.8, reactive = 0.1)
addGenerator!(system; label = 2, bus = 4, reactive = 0.3)

acModel!(system)

model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

power = analysisGenerator(system, model)
violate = reactiveLimit!(system, model, power)

nothing # hide
```
The output reactive power of the observed generators is subject to limits which are defined as follows:
```@repl GeneratorReactivePowerLimits
[system.generator.capability.minReactive system.generator.capability.maxReactive]
```

Once the solution of the AC power flow analysis is obtained, the [`analysisGenerator`](@ref analysisGenerator(::PowerSystem, ::ACPowerFlow)) function can be called to compute the reactive power output of generators:
```@repl GeneratorReactivePowerLimits
power.reactive
```

The variable `violate` indicates the violation of limits, where the first generator violates the minimum limit and the second generator violates the maximum limit, as shown below:
```@repl GeneratorReactivePowerLimits
violate
```
As a result of these limit violations, the `PowerSystem` type is changed, and the output reactive powers at the violated limits are set as follows:
```@repl GeneratorReactivePowerLimits
system.generator.output.reactive
```
To ensure that these values stay within the limits, the bus type must be changed from the generator bus (`type = 2`) to the demand bus (`type = 1`), as shown below:
```@repl GeneratorReactivePowerLimits
system.bus.layout.type
```

After modifying the `PowerSystem` type as described earlier, we can run the simulation again with the following code:
```@example GeneratorReactivePowerLimits
model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

power = analysisGenerator(system, model)
nothing # hide
```
Once the simulation is complete, we can verify that all generator reactive power outputs now satisfy the limits by checking the violate variable again:
```@repl GeneratorReactivePowerLimits
violate = reactiveLimit!(system, model, power)
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

addBus!(system; label = 1, type = 3, active = 0.5, reactive = 0.05)
addBus!(system; label = 2, type = 1, active = 0.5)
addBus!(system; label = 3, type = 2)
addBus!(system; label = 4, type = 2)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.01, reactance = 0.05)
addBranch!(system; label = 2, from = 1, to = 3, resistance = 0.02, reactance = 0.01)
addBranch!(system; label = 3, from = 2, to = 3, resistance = 0.03, reactance = 0.04)
addBranch!(system; label = 4, from = 2, to = 4, resistance = 0.03, reactance = 0.004)

addGenerator!(system; label = 1, bus = 1, minReactive = 0.0, maxReactive = 0.2)
addGenerator!(system; label = 2, bus = 4, reactive = 0.3)

acModel!(system)

model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

power = analysisGenerator(system, model)
nothing # hide
```

Upon checking the limits, we can observe that the slack bus has been transformed by executing the following code:
```@repl NewSlackBus
violate = reactiveLimit!(system, model, power)
```
Here, the generator connected to the slack bus is violating the minimum reactive power limit, which indicates the need to convert the slack bus. It is important to note that the new slack bus can be created only from the generator bus (`type = 2`). We will now perform another AC power flow analysis on the modified system using the following code:
```@example NewSlackBus
model = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```

After examining the bus voltages, we will focus on the angles:
```@repl NewSlackBus
model.voltage.angle
```
We can observe that the angles have been calculated based on the new slack bus. JuliaGrid offers the function to adjust these angles to match the original slack bus as follows:
```@example NewSlackBus
adjustAngle!(system, model; slack = 1)
```
Here, the `slack` keyword should correspond to the label of the slack bus. After executing the above code, the updated results can be viewed:
```@repl NewSlackBus
model.voltage.angle
```