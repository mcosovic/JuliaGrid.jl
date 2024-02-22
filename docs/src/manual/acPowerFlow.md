# [AC Power Flow](@id ACPowerFlowManual)
To perform the AC power flow analysis, you will first need the `PowerSystem` composite type that has been created with the `ac` model. Following that, you can construct the power flow model encapsulated within the `ACPowerFlow` abstract type by employing one of the following functions:
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

As a result, we can observe the updated array of bus types:
```@repl busType
print(system.bus.label, system.bus.layout.type)
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
@default(unit) # hide
@default(template) # hide

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
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)

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

    If there are multiple generators connected to the generator or slack bus, the initial voltage magnitude will align with the magnitude setpoint specified for the first in-service generator in the list.
---

##### Custom Starting Voltages
This method of specifying starting values has a significant advantage in that it allows the user to easily change the starting voltage magnitudes and angles, which play a crucial role in iterative methods. For instance, suppose we define our power system as follows:
```@example initializeACPowerFlowFlat
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, magnitude = 1.0, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, magnitude = 0.9, angle = -0.1)
addBus!(system; label = "Bus 3", type = 2, magnitude = 0.8, angle = -0.2)

addGenerator!(system; bus = "Bus 1", magnitude = 1.1)
addGenerator!(system; bus = "Bus 3", magnitude = 1.2)

acModel!(system)

nothing # hide
```
Now, the user can initiate a "flat start", this can be easily done as follows:
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
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Consequently, when using the Newton-Raphson method, the iteration begins with a fixed set of voltage magnitude values that remain constant throughout the iteration process. The remaining values are initialized as part of the "flat start" approach.

---

## [Power Flow Solution](@id ACPowerFlowSolutionManual)
To solve the AC power flow problem using JuliaGrid, we first need to create the `PowerSystem` composite type and define the AC model by calling the [`acModel!`](@ref acModel!) function. Here is an example:
```@example ACPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.5, magnitude = 1.0, angle = -0.2)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

@generator(active = 3.2)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", magnitude = 1.1)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", magnitude = 1.2)

acModel!(system)

nothing # hide
```

Once the AC model is defined, we can choose the method to solve the power flow problem. JuliaGrid provides four methods: [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel). For example, to use the Newton-Raphson method to solve the power flow problem, we can call the [`newtonRaphson`](@ref newtonRaphson) function as follows:
```@example ACPowerFlowSolution
analysis = newtonRaphson(system)
nothing # hide
```

!!! tip "Tip"
    By default, the user activates LU factorization to solve the system of linear equations within each iteration of the Newton-Raphson method. However, users can specifically opt for the `QR` factorization method:
    ```julia DCPowerFlowSolution
    analysis = newtonRaphson(system, QR)
    ```
    It is important to note that the capability to change the factorization method is exclusively available for the Newton-Raphson and fast Newton-Raphson methods.

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
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
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
    We recommend that the reader refer to the tutorial on [AC Power Flow Analysis](@ref ACPowerFlowTutorials), where we explain the implementation of the methods and algorithm structures in detail.

---

##### Breaking the Iterative Process
You can terminate the iterative process using the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) function. The following code shows an example of how to use the the function to break out of the iteration loop:
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

##### Combining Methods
The `PowerSystem` composite type, once created, can be shared among different methods, offering several advantages. For instance, while the Gauss-Seidel method is commonly used to swiftly derive an approximate solution, the Newton-Raphson method is favored for obtaining precise final solutions. Hence, a strategy involves employing the Gauss-Seidel method for a limited number of iterations, followed by initializing the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method, leveraging it as a starting point for further refinement:
```@example ACPowerFlowSolution
gs = gaussSeidel(system)
for iteration = 1:3
    solve!(system, gs)
end
```

Next, we can initialize the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method and start the algorithm from that point:
```@example ACPowerFlowSolution
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

---

## [Power System Update](@id ACPowerSystemAlterationManual)
After establishing the `PowerSystem` composite type using the [`powerSystem`](@ref powerSystem) function and configuring the `ac` model with [`acModel!`](@ref acModel!), users gain the capability to incorporate new branches and generators. Furthermore, they can adjust buses, branches, and generators.

Once updates are completed, users can seamlessly progress towards generating the `ACPowerFlow` type using the [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) function. Ultimately, resolving the AC power flow is achieved through the utilization of the [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)) and [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) functions:

```@example ACPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
@generator(active = 3.2)

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", magnitude = 1.1)
acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end

updateBus!(system; label = "Bus 2", active = 0.2)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 1)
updateBranch!(system; label = "Branch 1", status = 0)
addGenerator!(system; label = "Generator 2", bus = "Bus 1", active = 0.2)
updateGenerator!(system; label = "Generator 1", active = 0.3)

analysis = newtonRaphson(system)
for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end

nothing # hide
```

!!! note "Info"
    This method removes the need to restart and recreate the `PowerSystem` within the `ac` model from the beginning when implementing changes to the existing power system.

---

## [Power Flow Update](@id ACPowerFlowUpdateManual)
An advanced methodology involves users establishing the `ACPowerFlow` composite type using using [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) just once. After this initial setup, users can seamlessly integrate new branches and generators, and also have the capability to modify buses, branches, and generators, all without the need to recreate the `ACPowerFlow` type. 


This advancement extends beyond the previous scenario where recreating the `PowerSystem` and `ac` model was unnecessary, to now include the scenario where `ACPowerFlow` also does not need to be recreated. Such efficiency proves particularly beneficial in cases where JuliaGrid can reuse established Jacobian matrices or even factorizations, especially when users choose the fast Newton-Raphson method.

!!! note "Info"
    This method removes the need to restart and recreate both the `PowerSystem` within the `ac` model and the `ACPowerFlow` from the beginning when implementing changes to the existing power system.

---

##### Newton-Raphson: Reusing Jacobian Matrix
By modifying the previous example, we observe that we now create the `ACPowerFlow` type only once using the [`newtonRaphson`](@ref newtonRaphson) function. This approach allows us to circumvent the need for reinitializing the Jacobian matrix, enabling us to proceed directly with iterations:
```@example ACPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
@generator(active = 3.2)

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", magnitude = 1.1)
acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end

updateBus!(system, analysis; label = "Bus 2", active = 0.2)
addBranch!(system, analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 1)
updateBranch!(system, analysis; label = "Branch 1", status = 0)
addGenerator!(system, analysis; label = "Generator 2", bus = "Bus 1", active = 0.2)
updateGenerator!(system, analysis; label = "Generator 1", active = 0.3)

for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
nothing # hide
```

---

##### Fast Newton-Raphson: Reusing Jacobian Matrices Factorizations 
An intriguing scenario unfolds when employing the fast Newton-Raphson method. Continuing from the previous example, let us now initialize the fast Newton-Raphson method and proceed with iterations as outlined below:
```@example ACPowerFlowSolution
analysis = fastNewtonRaphsonBX(system)
for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
nothing # hide
```
Throughout this process, JuliaGrid will factorize the constant Jacobian matrices that govern the fast Newton-Raphson method. 

Now, let us make changes to the power system and proceed directly to the iteration step:
```@example ACPowerFlowSolution
updateBus!(system, analysis; label = "Bus 2", reactive = 0.02)
updateGenerator!(system, analysis; label = "Generator 1", reactive = 0.1)

for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
nothing # hide
```

!!! note "Info"
    In this scenario, JuliaGrid identifies cases where the user has not altered branch parameters affecting the Jacobian matrices. Consequently, JuliaGrid efficiently utilizes the previously performed factorizations, leading to a notably faster solution compared to recomputing the factorization process.

---

##### Fast Newton-Raphson: Sequential Jacobian Matrices Factorizations 
Continuing from the previous example, suppose we opt to adjust branch parameters by adding or updating branches. In such cases, reusing the factorized Jacobian matrices becomes impractical. In this scenario, JuliaGrid will repeat the factorization process while ensuring the delivery of an accurate solution.

Although computational gains are diminished compared to the previous case, users can still avoid recreating the `ACPowerFlow` type, as demonstrated below:
```@example ACPowerFlowSolution
addBranch!(system, analysis; label = "Branch 3", from = "Bus 1", to = "Bus 2", reactance = 1)
updateBranch!(system, analysis; label = "Branch 2", status = 0)

for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
```

!!! note "Info"
    In this context, JuliaGrid optimizes by reusing previously formed Jacobian matrices, eliminating the need to regenerate them from scratch.

---

##### Warm Start
In these scenarios, users leverage the previously created `PowerSystem` composite type with the `ac` model and also reuse the `ACPowerFlow` type, proceeding directly to the iterations. This approach offers the advantage of a "warm start", wherein the initial voltages for the subsequent iteration step align with the solution from the previous iteration step. This alignment facilitates an efficient continuation of the power flow analysis. 

Let us now make another alteration on the power system:
```@example ACPowerFlowSolution
updateBus!(system, analysis; label = "Bus 1", active = 0.1, magnitude = 0.95, angle = -0.07)
updateGenerator!(system, analysis; label = "Generator 2", reactive = 0.2, magnitude = 1.1)

nothing # hide
```

With these modifications we are not only alteration power system, but also starting voltages, for the next uses of one of the methods, these values now are:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```
Therefore, users possess the flexibility to adjust these initial values as needed by employing the `magnitude` and `angle` keywords within the [`updateBus!`](@ref updateBus!) and [`updateGenerator!`](@ref updateGenerator!) functions. 

If users prefer to set starting voltages according to the typical scenario, they can accomplish this through the [`startingVoltage!`](@ref startingVoltage!) function:
```@example ACPowerFlowSolution
startingVoltage!(system, analysis)
```
Now, we have starting voltages defined exclusively according to the `PowerSystem`. These values are exactly the same as if we executed the [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) function after all the updates we performed:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Limitations
The [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) function oversees bus type validations, as outlined in the [Bus Type Modification](@ref BusTypeModificationManual) section. Consequently, attempting to change bus types or leaving generator buses without a generator and then proceeding directly to the iteration process is not viable. 

In such scenarios, JuliaGrid will raise an error:
```@repl ACPowerFlowSolution
updateBus!(system, analysis; label = "Bus 2", type = 2)
```

Therefore, the user must follow the proper sequence by executing the [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) function instead of trying to reuse these types, for example:
```@example ACPowerFlowSolution
updateBus!(system; label = "Bus 2", type = 2)
analysis = fastNewtonRaphsonBX(system)

for iteration = 1:100
    mismatch!(system, analysis)
    solve!(system, analysis)
end
```

!!! note "Info"
    After creating the `PowerSystem` and `ACPowerFlow` types, users can add or modify buses, branches, and generators before directly proceeding to iterations. JuliaGrid automatically executes the necessary functions when adjustments lead to a valid solution. However, if modifications are incompatible, like altering bus types, JuliaGrid raises an error to prevent misleading outcomes, ensuring accuracy.

---

## [Power and Current Analysis](@id ACPowerCurrentAnalysisManual)
After obtaining the solution from the AC power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)) functions. For instance, let us consider the power system for which we obtained the AC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

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
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.to.angle)

```

!!! note "Info"
    To better understand the powers and currents associated with buses, branches and generators that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [AC Power Flow Analysis](@ref ACPowerAnalysisTutorials).

To compute specific quantities for particular components, rather than calculating powers or currents for all components, users can utilize one of the provided functions below.

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

## [Generator Reactive Power Limits](@id GeneratorReactivePowerLimitsManual)
The function [`reactiveLimit!`](@ref reactiveLimit!) can be used by the user to check if the generators' output of reactive power is within the defined limits after obtaining the solution from the AC power flow analysis. This can be done by using the example code provided:
```@example GeneratorReactivePowerLimits
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.5)
addBus!(system; label = "Bus 3", type = 2, reactive = 0.05)
addBus!(system; label = "Bus 4", type = 2, reactive = 0.05)

@branch(resistance = 0.015)
addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; from = "Bus 2", to = "Bus 3", reactance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 4", reactance = 0.004)

@generator(minReactive = -0.4, maxReactive = 0.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1")
addGenerator!(system; label = "Generator 2", bus = "Bus 3", reactive = 0.8)
addGenerator!(system; label = "Generator 3", bus = "Bus 4", reactive = 0.9)

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

After obtaining the solution of the AC power flow analysis, the [`reactiveLimit!`](@ref reactiveLimit!) function is used to internally calculate the output powers of the generators and verify if these values exceed the defined limits. Consequently, the variable `violate` indicates whether there is a violation of limits. In the provided example, it can be observed that the `Generator 2` and `Generator 3` violate the maximum limit:
```@repl GeneratorReactivePowerLimits
print(system.generator.label, violate)
```

Due to these violations of limits, the `PowerSystem` type undergoes modifications, and the output reactive power at the limit-violating generators is adjusted as follows:
```@repl GeneratorReactivePowerLimits
print(system.generator.label, system.generator.output.reactive)
```

To ensure that these values stay within the limits, the bus type must be changed from the generator bus (`type = 2`) to the demand bus (`type = 1`), as shown below:
```@repl GeneratorReactivePowerLimits
print(system.bus.label, system.bus.layout.type)
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
Looking at the following code example, we can see that the output limits of the generator are set only for `Generator 1` that is connected to the slack bus:
```@example NewSlackBus
using JuliaGrid # hide
@default(unit) # hide
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

addGenerator!(system; label = "Generator 1", bus = "Bus 1", maxReactive = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 4", reactive = 0.3)

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
print(system.bus.label, analysis.voltage.angle)
```
We can observe that the angles have been calculated based on the new slack bus. JuliaGrid offers the function to adjust these angles to match the original slack bus as follows:
```@example NewSlackBus
adjustAngle!(system, analysis; slack = "Bus 1")
```

Here, the `slack` keyword should correspond to the label of the slack bus. After executing the above code, the updated results can be viewed:
```@repl NewSlackBus
print(system.bus.label, analysis.voltage.angle)
```