# [AC Power Flow](@id ACPowerFlowManual)
To perform the AC power flow analysis, we will first need the `PowerSystem` type that has been created with the AC model. Following that, we can construct the power flow model encapsulated within the `AcPowerFlow` type by employing one of the following functions:
* [`newtonRaphson`](@ref newtonRaphson),
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX),
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB),
* [`gaussSeidel`](@ref gaussSeidel).

---

To obtain bus voltages and solve the power flow problem, users can implement an iterative process using functions:
* [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})),
* [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson})).

After solving the AC power flow, JuliaGrid provides functions for computing powers and currents:
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

Alternatively, instead of designing their own iteration process and computing powers and currents, users can use the wrapper function:
* [`powerFlow!`](@ref powerFlow!(::AcPowerFlow)).

Users can also access specialized functions for computing specific types of [powers](@ref ACPowerAnalysisAPI) and [currents](@ref ACCurrentAnalysisAPI) for individual buses, branches, or generators within the power system.

---

Finally, the package provides two functions for reactive power limit validation of generators and adjusting the voltage angles to match an arbitrary bus angle:
* [`reactiveLimit!`](@ref reactiveLimit!),
* [`adjustAngle!`](@ref adjustAngle!).

---

## [Bus Type Modification](@id BusTypeModificationManual)
Depending on how the system is constructed, the types of buses that are initially set are checked and can be changed during the construction of the `AcPowerFlow` type.

To explain the details, we consider a power system and assume that the Newton-Raphson method has been chosen:
```julia
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2)
addBus!(system; label = "Bus 3", type = 2)

addGenerator!(system; bus = "Bus 2")

analysis = newtonRaphson(system)
```

Initially, `Bus 1` is set as the slack bus (`type = 3`), and `Bus 2` and `Bus 3` are generator buses (`type = 2`). However, `Bus 3` does not have a generator, and JuliaGrid considers this a mistake and changes the corresponding bus to a demand bus (`type = 1`).

After this step, JuliaGrid verifies the slack bus. Initially, the slack bus (`type = 3`) corresponds to `Bus 1`, but since it does not have an in-service generator connected to it, JuliaGrid recognizes it as another mistake. Therefore, JuliaGrid assigns a new slack bus from the available generator buses (`type = 2`) that have connected in-service generators. In this specific example, `Bus 2` becomes the new slack bus.

```@setup busType
using JuliaGrid
@default(unit)
@default(template)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 2)
addBus!(system; label = "Bus 3", type = 2)

addGenerator!(system; bus = "Bus 2")

analysis = newtonRaphson(system)
```

As a result, we can observe the updated array of bus types:
```@repl busType
print(system.bus.label, system.bus.layout.type)
```

Note that, if a bus is initially defined as the demand bus (`type = 1`) and later a generator is added to it, the bus type will not be changed to the generator bus (`type = 2`). Instead, it will remain as a demand bus.

!!! note "Info"
    Only the type of these buses that are defined as generator buses (`type = 2`) but do not have a connected in-service generator will be changed to demand buses (`type = 1`).

    The bus that is defined as the slack bus (`type = 3`) but lacks a connected in-service generator will have its type changed to the demand bus (`type = 1`). Meanwhile, the first generator bus (`type = 2`) with an in-service generator connected to it will be assigned as the new slack bus (`type = 3`).

---

## [Setup Initial Voltages](@id SetupInitialVoltagesManual)
Let us create the `PowerSystem` type and select the Newton-Raphson method:
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

analysis = newtonRaphson(system)
nothing # hide
```

Here, the function [`newtonRaphson`](@ref newtonRaphson) initializes voltages in polar coordinates.

The initial voltage magnitudes are set to:
```@repl initializeACPowerFlow
print(system.bus.label, analysis.voltage.magnitude)
```

This vector is created based on the bus types by selecting voltage magnitude values from the `PowerSystem` type, using the vectors:
```@repl initializeACPowerFlow
[system.bus.voltage.magnitude system.generator.voltage.magnitude]
```

The initial voltage angles are set to:
```@repl initializeACPowerFlow
print(system.bus.label, analysis.voltage.angle)
```

This vector is derived from the voltage angle values in the `PowerSystem` type:
```@repl initializeACPowerFlow
system.bus.voltage.angle
```

!!! note "Info"
    The rule governing the specification of initial voltage magnitudes is simple. If a bus has an in-service generator and is declared the generator bus (`type = 2`), then the initial voltage magnitudes are specified using the setpoint provided within the generator. This is because the generator bus has known values of voltage magnitude that are specified within the generator.

    On the other hand, the slack bus (`type = 3`) always requires an in-service generator. The initial value of the voltage magnitude at the slack bus is determined exclusively by the setpoints provided within the generators connected to it. This is a result of the slack bus having a known voltage magnitude that must be maintained.

    If there are multiple generators connected to the generator or slack bus, the initial voltage magnitude will align with the magnitude setpoint specified for the first in-service generator in the list.

---

##### Custom Initial Voltages
This method of specifying initial values has a significant advantage in that it allows the user to easily change the initial voltage magnitudes and angles, which play a crucial role in iterative methods. For instance, suppose we define our power system as follows:
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
nothing # hide
```

Now, the user can initiate a flat start, this can be easily done as follows:
```@example initializeACPowerFlowFlat
for i = 1:system.bus.number
    system.bus.voltage.magnitude[i] = 1.0
    system.bus.voltage.angle[i] = 0.0
end

analysis = newtonRaphson(system)
nothing # hide
```

The initial voltage values are:
```@repl initializeACPowerFlowFlat
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Consequently, the iteration begins with a fixed set of voltage magnitude values that remain constant throughout the iteration process. The remaining values are initialized as part of the flat start approach.

---

## [Power Flow Solution](@id ACPowerFlowSolutionManual)
To start, we will create a power system and define the AC model by invoking the [`acModel!`](@ref acModel!) function:
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

Once the AC model is defined, we can choose the method to solve the power flow problem. JuliaGrid provides four methods: [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), and [`gaussSeidel`](@ref gaussSeidel).

For example, to use the Newton-Raphson method to solve the power flow problem, we can use:
```@example ACPowerFlowSolution
analysis = newtonRaphson(system)
nothing # hide
```

!!! tip "Tip"
    By default, the user activates LU factorization to solve the system of linear equations within each iteration of the Newton-Raphson method. However, users can specifically opt for the `QR` factorization method:
    ```julia DCPowerFlowSolution
    analysis = newtonRaphson(system, QR)
    ```
    The capability to change the factorization method is exclusively available for the Newton-Raphson and fast Newton-Raphson methods.

This function sets up the desired method for an iterative process based on two functions: [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) and [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson})). The [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) function calculates the active and reactive power injection mismatches using the given voltage magnitudes and angles, while [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson})) computes the voltage magnitudes and angles.

To perform an iterative process with the Newton-Raphson or fast Newton-Raphson methods in JuliaGrid, the [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) function must be included inside the iteration loop. For instance:
```@example ACPowerFlowSolution
for iteration = 1:100
    mismatch!(analysis)
    solve!(analysis)
end
nothing # hide
```

Upon completion of the AC power flow analysis, the solution is conveyed through the bus voltage magnitudes and angles. Here are the values corresponding to the buses:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

In contrast, the iterative loop of the Gauss-Seidel method does not require the [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) function:
```@example ACPowerFlowSolution
analysis = gaussSeidel(system)
for iteration = 1:100
    solve!(analysis)
end
nothing # hide
```
In these examples, the algorithms run until the specified number of iterations is reached.

!!! note "Info"
    We recommend that the reader refer to the tutorial on [AC Power Flow Analysis](@ref ACPowerFlowTutorials), where we explain the implementation of the methods and algorithm structures in detail.

---

##### Breaking the Iterative Process
We can terminate the iterative process using the [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) function. The following code shows an example of how to use the function to break out of the iteration loop:
```@example ACPowerFlowSolution
@voltage(pu, rad, V) # hide
analysis = newtonRaphson(system)
for iteration = 1:100
    stopping = mismatch!(analysis)
    if all(stopping .< 1e-8)
        println("Solution found in $(analysis.method.iteration) iterations.")
        break
    end
    solve!(analysis)
end
nothing # hide
```

The [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})) function returns the maximum absolute values of active and reactive power injection mismatches, which are commonly used as a convergence criterion in iterative AC power flow algorithms.

---

##### Wrapper Function
JuliaGrid provides a wrapper function for AC power flow analysis that manages the iterative solution process and also supports the computation of powers and currents using the [powerFlow!](@ref powerFlow!(::AcPowerFlow)) function. Hence, it offers a way to solve AC power flow with reduced implementation effort:
```@example ACPowerFlowSolution
setInitialPoint!(analysis) # hide
analysis = newtonRaphson(system)
powerFlow!(analysis; verbose = 3)
nothing # hide
```

!!! note "Info"
    Users can choose any of the approaches presented in this section to solve AC power flow based on their needs. Additionally, users can review the algorithm used in the wrapper function within the [AC Power Flow](@ref ACPowerFlowTutorials) tutorial section. For example, they can refer to the [Newton-Raphson algorithm](@ref NewtonRaphsonAlgorithmTutorials).

---

##### Combining Methods
The `PowerSystem` type, once created, can be shared among different methods, offering several advantages.

For instance, while the Gauss-Seidel method is commonly used to swiftly derive an approximate solution, the Newton-Raphson method is favored for obtaining precise final solutions. Hence, a strategy involves employing the Gauss-Seidel method for a limited number of iterations, followed by initializing the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method, leveraging it as a starting point for further refinement:
```@example ACPowerFlowSolution
gs = gaussSeidel(system)
for iteration = 1:5
    solve!(gs)
end
```

Next, we can initialize the Newton-Raphson method with the voltages obtained from the Gauss-Seidel method and start the algorithm from that point:
```@example ACPowerFlowSolution
analysis = newtonRaphson(system)

setInitialPoint!(analysis, gs)
powerFlow!(analysis)
```

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example ACPowerFlowSolution
@voltage(pu, deg)
printBusData(analysis)
nothing # hide
```

Next, users can easily customize the print results for specific buses, for example:
```julia
printBusData(analysis; label = "Bus 1", header = true)
printBusData(analysis; label = "Bus 2")
printBusData(analysis; label = "Bus 3", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file as follows:
```julia
open("bus.txt", "w") do file
    printBusData(analysis, file)
end
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printBusData(analysis, io; style = false)
CSV.write("bus.csv", CSV.File(take!(io); delim = "|"))
```

---

## [Power System Update](@id ACPowerSystemAlterationManual)
We begin by creating the `PowerSystem` type with the [`powerSystem`](@ref powerSystem) function. The AC model is then configured using [`acModel!`](@ref acModel!) function. After that, we initialize the `AcPowerFlow` type through the [`newtonRaphson`](@ref newtonRaphson) function and solve the resulting power flow problem:
```@example ACPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", magnitude = 1.1, active = 3.2)

acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)
```

Next, we modify the existing `PowerSystem` type within the AC model using add and update functions. Then, we create a new `AcPowerFlow` type based on the modified system and solve the power flow problem:
```@example ACPowerFlowSolution
updateBus!(system; label = "Bus 2", active = 0.2)

addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.3)
updateBranch!(system; label = "Branch 1", status = 0)

addGenerator!(system; label = "Generator 2", bus = "Bus 1", active = 0.2)
updateGenerator!(system; label = "Generator 1", active = 0.3)

analysis = newtonRaphson(system)
powerFlow!(analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `PowerSystem` within the `ac` field from the beginning when implementing changes to the existing power system.

---

## [Power Flow Update](@id ACPowerFlowUpdateManual)
An advanced methodology involves users establishing the `AcPowerFlow` type just once. After this initial setup, users can integrate new branches and generators, and also have the capability to modify buses, branches, and generators, all without the need to recreate the `AcPowerFlow` type. This is particularly beneficial when previously constructed Jacobian matrices or factorizations can be reused, especially in combination with the fast Newton-Raphson method.

Let us now revisit our defined `PowerSystem` and `AcPowerFlow` types:
```@example ACPowerFlowSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5, magnitude = 0.9, angle = 0.0)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05, magnitude = 1.1, angle = -0.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", magnitude = 1.1, active = 3.2)

acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)
```

Next, we modify the existing `PowerSystem` within the AC model as well as the `AcPowerFlow` type using add and update functions. We then immediately proceed to solve the power flow problem:
```@example ACPowerFlowSolution
updateBus!(analysis; label = "Bus 2", active = 0.2)

addBranch!(analysis; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.3)
updateBranch!(analysis; label = "Branch 1", status = 0)

addGenerator!(analysis; label = "Generator 2", bus = "Bus 1", active = 0.2)
updateGenerator!(analysis; label = "Generator 1", active = 0.3)

powerFlow!(analysis)
```

!!! note "Info"
    This concept removes the need to restart and recreate both the `PowerSystem` within the `ac` field and the `AcPowerFlow` from the beginning when implementing changes to the existing power system.

---

##### Warm Start
This approach of reusing `AcPowerFlow` offers the advantage of a warm start, where the initial voltages for the next power flow computation step match the solution from the previous run. This alignment enables a more efficient continuation of the power flow analysis.

As a result, for the next power flow run, the initial voltage magnitudes and angles will be:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

If users prefer to reset the initial voltages and instead use the values defined in the `PowerSystem` type, they can do so using the [`setInitialPoint!`](@ref setInitialPoint!) function:
```@example ACPowerFlowSolution
setInitialPoint!(analysis)
```

Now, the initial voltages are set exclusively based on the values defined in the `PowerSystem` type:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users also have the flexibility to adjust these initial values manually using the magnitude and angle keywords in the [`updateBus!`](@ref updateBus!) and [`updateGenerator!`](@ref updateGenerator!) functions:
```@example ACPowerFlowSolution
updateGenerator!(analysis; label = "Generator 1", magnitude = 1.15)
updateBus!(analysis; label = "Bus 2", magnitude = 1.08, angle = -0.1)
nothing # hide
```

The updated initial point for the next power flow run is then:
```@repl ACPowerFlowSolution
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---


##### Fast Newton-Raphson Using Reused Jacobian Matrix Factorizations
One of the key advantages of reusing the `AcPowerFlow` type becomes evident when applying the fast Newton-Raphson method. Continuing from the previous example, we first create the fast Newton-Raphson model and perform the power flow calculation:
```@example ACPowerFlowSolution
analysis = fastNewtonRaphsonBX(system)
powerFlow!(analysis)
nothing # hide
```

Next, we modify the supply and demand values and solve the power flow again:
```@example ACPowerFlowSolution
updateBus!(analysis; label = "Bus 2", active = 0.2, reactive = 0.02)
updateGenerator!(analysis; label = "Generator 1", active = 3.1, reactive = 0.1)

powerFlow!(analysis)
nothing # hide
```

In this scenario, JuliaGrid detects that the parameters affecting the Jacobian matrices remain unchanged. As a result, it reuses the previously computed factorizations, leading to significantly faster power flow computation compared to recomputing the factorization from scratch.

---

##### Limitations
The [`newtonRaphson`](@ref newtonRaphson), [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX), [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB), or [`gaussSeidel`](@ref gaussSeidel) function oversees bus type validations, as outlined in the [Bus Type Modification](@ref BusTypeModificationManual) section. Consequently, attempting to change bus types or leaving generator buses without a generator and then proceeding directly to the iteration process is not viable.

In such scenarios, JuliaGrid will raise an error:
```@repl ACPowerFlowSolution
updateBus!(analysis; label = "Bus 2", type = 2)
```

To resolve this, the user must recreate the `AcPowerFlow` type rather than attempting to reuse the existing one:
```@example ACPowerFlowSolution
updateBus!(system; label = "Bus 2", type = 2)

analysis = fastNewtonRaphsonBX(system)
powerFlow!(analysis)
```

---

## [Power and Current Analysis](@id ACPowerCurrentAnalysisManual)
After obtaining the solution from the AC power flow, we can calculate various electrical quantities related to buses, branches, and generators using the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AcPowerFlow)) functions. For instance, let us consider the power system for which we obtained the AC power flow solution:
```@example ComputationPowersCurrentsLosses
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.6)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.1, susceptance = 0.03)
addBus!(system; label = "Bus 3", type = 1, conductance = 0.02)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.1)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.4)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 1.0, reactive = 0.2)

analysis = newtonRaphson(system)
powerFlow!(analysis)
nothing # hide
```

We can now utilize the provided functions to compute powers and currents:
```@example ComputationPowersCurrentsLosses
power!(analysis)
current!(analysis)
nothing # hide
```

For instance, if we want to show the active power injections and the to-bus current angles, we can employ the following code:
```@repl ComputationPowersCurrentsLosses
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.to.angle)
```

!!! note "Info"
    For a better understanding of the powers and currents from buses, branches, and generators obtained by the [`power!`](@ref power!(::AcPowerFlow)) and [`current!`](@ref current!(::AC)) functions, refer to the [AC Power Flow Analysis](@ref ACPowerFlowTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print Power System Data](@ref PrintPowerSystemDataAPI) or [Print Power System Summary](@ref PrintPowerSystemSummaryAPI). For example, to create a bus summary with the desired units, users can use the following function:
```@example ComputationPowersCurrentsLosses
@voltage(pu, deg)
@power(MW, MVAr)
printBusSummary(analysis)
@default(unit) # hide
nothing # hide
```

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = injectionPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = supplyPower(analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = shuntPower(analysis; label = "Bus 3")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the from-bus and to-bus ends of the specific branch by utilizing the functions provided below:
```@repl ComputationPowersCurrentsLosses
active, reactive = fromPower(analysis; label = "Branch 2")
active, reactive = toPower(analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = chargingPower(analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl ComputationPowersCurrentsLosses
active, reactive = seriesPower(analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Generator Active and Reactive Power Output
We can compute the active and reactive power output of a particular generator using the function:
```@repl ComputationPowersCurrentsLosses
active, reactive = generatorPower(analysis; label = "Generator 1")
```

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = injectionCurrent(analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = fromCurrent(analysis; label = "Branch 2")
magnitude, angle = toCurrent(analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the from-bus end to the to-bus end, we can use the following function:
```@repl ComputationPowersCurrentsLosses
magnitude, angle = seriesCurrent(analysis; label = "Branch 2")
```

---

## [Generator Reactive Power Limits](@id GeneratorReactivePowerLimitsManual)
The function [`reactiveLimit!`](@ref reactiveLimit!) can be used to check if the generators' output of reactive power is within the defined limits after obtaining the solution from the AC power flow analysis:
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

analysis = newtonRaphson(system)
powerFlow!(analysis)

violate = reactiveLimit!(analysis)
nothing # hide
```

The output reactive power of the observed generators is subject to limits which are defined as follows:
```@repl GeneratorReactivePowerLimits
[system.generator.capability.minReactive system.generator.capability.maxReactive]
```

After obtaining the solution of the AC power flow analysis, the [`reactiveLimit!`](@ref reactiveLimit!) function is used to internally calculate the output powers of the generators and verify if these values exceed the defined limits. Consequently, the variable `violate` indicates whether there is a violation of limits.

In the provided example, it can be observed that the `Generator 2` and `Generator 3` violate the maximum limit:
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
powerFlow!(analysis)
nothing # hide
```

Once the simulation is complete, we can verify that all generator reactive power outputs now satisfy the limits by checking the violate variable again:
```@repl GeneratorReactivePowerLimits
violate = reactiveLimit!(analysis)
```

!!! note "Info"
    The [`reactiveLimit!`](@ref reactiveLimit!) function changes the `PowerSystem` type deliberately because it is intended to help users create the power system where all reactive power outputs of the generators are within limits.

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

analysis = newtonRaphson(system)
powerFlow!(analysis)
nothing # hide
```

Upon checking the limits, we can observe that the slack bus has been transformed by executing the following code:
```@repl NewSlackBus
violate = reactiveLimit!(analysis)
```

Here, the generator connected to the slack bus is violating the minimum reactive power limit, which indicates the need to convert the slack bus. It is important to note that the new slack bus can be created only from the generator bus (`type = 2`). We will now perform another AC power flow analysis on the modified system using the following:
```@example NewSlackBus
analysis = newtonRaphson(system)
powerFlow!(analysis)
```

After examining the bus voltages, we will focus on the angles:
```@repl NewSlackBus
print(system.bus.label, analysis.voltage.angle)
```

We can observe that the angles have been calculated based on the new slack bus. JuliaGrid offers the function to adjust these angles to match the original slack bus as follows:
```@example NewSlackBus
adjustAngle!(analysis; slack = "Bus 1")
```

After executing the above code, the updated results can be viewed:
```@repl NewSlackBus
print(system.bus.label, analysis.voltage.angle)
```