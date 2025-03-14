# [PMU State Estimation](@id PMUStateEstimationManual)
To perform linear state estimation solely based on PMU data, the initial requirement is to have the `PowerSystem` type configured with the AC model, along with the `Measurement` type storing measurement data. Subsequently, we can formulate either the weighted least-squares (WLS) or the least absolute value (LAV) PMU state estimation model encapsulated within the type `PMUStateEstimation` using:
* [`pmuStateEstimation`](@ref pmuStateEstimation),
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation).

---

To obtain bus voltages and solve the PMU state estimation problem, users can use the wrapper function:
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{WLS{Normal}})).

After solving the PMU state estimation, JuliaGrid provides functions for computing powers and currents:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::AC)).

Alternatively, instead of using functions responsible for solving state estimation and computing powers and currents, users can use the wrapper function:
* [`stateEstimation!`](@ref stateEstimation!(::PowerSystem, ::PMUStateEstimation{WLS{T}}) where T <: Union{Normal, Orthogonal}).

Users can also access specialized functions for computing specific types of [powers](@ref ACPowerAnalysisAPI) or [currents](@ref ACCurrentAnalysisAPI) for individual buses, branches, or generators within the power system.

---

## [Phasor Measurements](@id PhasorMeasurementsManual)
Let us define the `PowerSystem` type and perform the AC power flow analysis solely for generating data to artificially create measurement values:
```@example PMUOptimalPlacement
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, active = 0.5)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

@generator(reactive = 0.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 2.1)

analysis = newtonRaphson(system)
powerFlow!(system, analysis)
nothing # hide
```

---

##### Optimal PMU Placment
After defining the `PowerSystem` type, the next step is to define the `Measurement` type:
```@example PMUOptimalPlacement
device = measurement()
nothing # hide
```

JuliaGrid allows users to determine the minimum number of PMUs needed for observability while also generating phasor measurements based on results from AC power flow through the [`pmuPlacement!`](@ref pmuPlacement!) function:
```@example PMUOptimalPlacement
using HiGHS

@pmu(label = "PMU ? (!)")
placement = pmuPlacement!(system, device, analysis, HiGHS.Optimizer)
nothing # hide
```
Note that users can also generate phasor measurements using results from AC optimal power flow.


The `placement` variable contains data regarding the optimal placement of measurements. In this instance, installing a PMU at `Bus 2` renders the system observable:
```@repl PMUOptimalPlacement
keys(placement.bus)
```

This PMU installed at `Bus 2` will measure the bus voltage phasor at the corresponding bus and all current phasors at the branches incident to `Bus 2` located at the from-bus or to-bus ends:
```@repl PMUOptimalPlacement
keys(placement.from)
keys(placement.to)
```

Finally, we can observe the obtained set of measurement values:
```@repl PMUOptimalPlacement
print(device.pmu.label, device.pmu.magnitude.mean, device.pmu.angle.mean)
```

---

## [Weighted Least-Squares Estimator](@id PMUWLSStateEstimationSolutionManual)
Let us continue with the previous example, where we defined the `PowerSystem` and `Measurement` types. To establish the PMU state estimation model, we will use the [`pmuStateEstimation`](@ref pmuStateEstimation) function:
```@example PMUOptimalPlacement
analysis = pmuStateEstimation(system, device)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the PMU state estimation problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`:
    ```julia PMUOptimalPlacement
    analysis = pmuStateEstimation(system, device, QR)
    ```

To obtain the bus voltage magnitudes and angles, the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{WLS{Normal}})) function can be invoked as shown:
```@example PMUOptimalPlacement
solve!(system, analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage magnitudes and angles using:
```@repl PMUOptimalPlacement
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [PMU State Estimation](@ref PMUStateEstimationTutorials) for insights into the implementation.

---

##### Correlated Measurement Errors
In the above approach, we assume that measurement errors from a single PMU are uncorrelated. This assumption leads to the covariance matrix and its inverse matrix (i.e., precision matrix) maintaining a diagonal form:
```@repl PMUOptimalPlacement
analysis.method.precision
```

While this approach is suitable for many scenarios, linear PMU state estimation relies on transforming from polar to rectangular coordinate systems. Consequently, measurement errors from a single PMU become correlated due to this transformation. This correlation results in the covariance matrix, and hence the precision matrix, no longer maintaining a diagonal form but instead becoming a block diagonal matrix.

To accommodate this, users have the option to consider correlation when adding each PMU to the `Measurement` type. For instance, let us add a new PMU while considering correlation:
```@example PMUOptimalPlacement
addPmu!(system, device; bus = "Bus 3", magnitude = 1.01, angle = -0.005, correlated = true)
nothing # hide
```

Following this, we recreate the WLS state estimation model:
```@example PMUOptimalPlacement
analysis = pmuStateEstimation(system, device)
nothing # hide
```

Upon inspection, it becomes evident that the precision matrix no longer maintains a diagonal structure:
```@repl PMUOptimalPlacement
analysis.method.precision
```

Subsequently, we can address this new scenario and observe the solution:
```@repl PMUOptimalPlacement
solve!(system, analysis)
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Alternative Formulation
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite).

This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example PMUOptimalPlacement
updatePmu!(system, device; label = "PMU 5 (Bus 3)", correlated = false)
nothing # hide
```

Subsequently, by specifying the `Orthogonal` argument in the [`pmuStateEstimation`](@ref pmuStateEstimation) function, JuliaGrid implements a more robust approach to obtain the WLS estimator, which proves particularly beneficial when substantial differences exist among measurement variances:
```@example PMUOptimalPlacement
analysis = pmuStateEstimation(system, device, Orthogonal)
solve!(system, analysis)
nothing # hide
```

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example PMUOptimalPlacement
@voltage(pu, deg)
printBusData(system, analysis)
@default(unit) # hide
```

Next, users can easily customize the print results for specific buses, for example:
```julia
printBusData(system, analysis; label = "Bus 1", header = true)
printBusData(system, analysis; label = "Bus 2")
printBusData(system, analysis; label = "Bus 3", footer = true)
```

---

##### Save Results to a File
Users can also redirect print output to a file. For example, data can be saved in a text file as follows:
```julia
open("bus.txt", "w") do file
    printBusData(system, analysis, file)
end
```

!!! tip "Tip"
    We also provide functions to print or save state estimation results, such as estimated values and residuals. For more details, users can consult the [Power and Current Analysis](@ref PMUSEPowerCurrentAnalysisManual) section of this manual.

---

## [Least Absolute Value Estimator](@id PMULAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data analysis procedures [aburbook; Ch. 6](@cite). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example PMUOptimalPlacement
using Ipopt
using JuMP  # hide

analysis = pmuLavStateEstimation(system, device, Ipopt.Optimizer; verbose = 1)
nothing # hide
```

---

##### Setup Initial Primal Values
In JuliaGrid, the assignment of initial primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{WLS{Normal}})) function is executed. Initial primal values are determined based on the `voltage` fields within the `PMUStateEstimation` type. By default, these values are initially established using the initial bus voltage magnitudes and angles from `PowerSystem` type:
```@repl PMUOptimalPlacement
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users have the flexibility to customize these values according to their requirements, and they will be utilized as the initial primal values when executing the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{WLS{Normal}})) function. It is important to note that JuliaGrid utilizes the provided data to set initial primal values in the rectangular coordinate system. Additionally, the [setInitialPoint!](@ref setInitialPoint!(::PowerSystem, ::ACStateEstimation)) function allows users to configure the initial point as required.

---

##### Solution
To solve the formulated LAV state estimation model, simply execute the following function:
```@example PMUOptimalPlacement
solve!(system, analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage magnitudes and angles using:
```@repl PMUOptimalPlacement
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    Readers can refer to the [Least Absolute Value Estimation](@ref PMUSELAVTutorials) tutorial for implementation insights.

---

## [Measurement Set Update](@id PMUMeasurementsAlterationManual)
After establishing the `Measurement` type using the [`measurement`](@ref measurement) function, users gain the capability to incorporate new measurement devices or update existing ones.

Once updates are completed, users can seamlessly progress towards generating the `PMUStateEstimation` type using the [`pmuStateEstimation`](@ref pmuStateEstimation) or [`pmuLavStateEstimation`](@ref pmuLavStateEstimation) function. Ultimately, resolving the PMU state estimation is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimation{WLS{Normal}})) function:
```@example WLSPMUStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement() # <- Initialize the Measurement instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 3", type = 1, active = 2.5, reactive = 0.2)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

@pmu(label = "PMU ?")
addPmu!(system, device; bus = "Bus 1", magnitude = 1.0, angle = 0.0)
addPmu!(system, device; bus = "Bus 2", magnitude = 0.98, angle = -0.023)
addPmu!(system, device; from = "Branch 2", magnitude = 0.5, angle = -0.05)

analysis = pmuStateEstimation(system, device) # <- Build PMUStateEstimation for the model
solve!(system, analysis)

addPmu!(system, device; to = "Branch 2", magnitude = 0.5, angle = 3.1)
updatePmu!(system, device; label = "PMU 1", varianceMagnitude = 1e-8)
updatePmu!(system, device; label = "PMU 3", status = 0)

analysis = pmuStateEstimation(system, device) # <- Build PMUStateEstimation for new model
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id PMUStateEstimationUpdateManual)
An advanced methodology involves users establishing the `PMUStateEstimation` type using [`pmuStateEstimation`](@ref pmuStateEstimation) or [`pmuLavStateEstimation`](@ref pmuLavStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `PMUStateEstimation` type.

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `PMUStateEstimation` also does not need to be recreated.

!!! tip "Tip"
    The addition of new measurements after the creation of `PMUStateEstimation` is not practical in terms of reusing the `PMUStateEstimation` type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

We can modify the prior example to achieve the same model without establishing `PMUStateEstimation` twice:
```@example WLSPMUStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement() # <- Initialize the Measurement instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 3", type = 1, active = 2.5, reactive = 0.2)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

@pmu(label = "PMU ?")
addPmu!(system, device; bus = "Bus 1", magnitude = 1.0, angle = 0.0)
addPmu!(system, device; bus = "Bus 2", magnitude = 0.98, angle = -0.023)
addPmu!(system, device; from = "Branch 2", magnitude = 0.5, angle = -0.05)
addPmu!(system, device; to = "Branch 2", magnitude = 0.5, angle = 3.1, status = 0)

analysis = pmuStateEstimation(system, device) # <- Build PMUStateEstimation for the model
solve!(system, analysis)

updatePmu!(system, device, analysis; label = "PMU 1", varianceMagnitude = 1e-8)
updatePmu!(system, device, analysis; label = "PMU 3", status = 0)
updatePmu!(system, device, analysis; label = "PMU 4", status = 1)

# <- No need for re-build; we have already updated the existing PMUStateEstimation instance
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to rebuild both the `Measurement` and the `PMUStateEstimation` from the beginning when implementing changes to the existing measurement set. In the scenario of employing the WLS model, JuliaGrid can reuse the symbolic factorizations of LU or LDLt, provided that the nonzero pattern of the gain matrix remains unchanged.

---

## [Power and Current Analysis](@id PMUSEPowerCurrentAnalysisManual)
After obtaining the solution from the PMU state estimation, we can calculate various electrical quantities related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions. For instance, let us consider the model for which we obtained the PMU state estimation solution:
```@example PMUStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3, susceptance = 0.002)
addBus!(system; label = "Bus 2", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 3", type = 1, active = 2.5, reactive = 0.2)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

addPmu!(system, device; bus = "Bus 1", magnitude = 1.0, angle = 0.0)
addPmu!(system, device; bus = "Bus 2", magnitude = 0.97, angle = -0.051)
addPmu!(system, device; from = "Branch 2", magnitude = 1.66, angle = -0.15)
addPmu!(system, device; to = "Branch 2", magnitude = 1.67, angle = 2.96)

analysis = pmuStateEstimation(system, device)
solve!(system, analysis)
```

We can now utilize the provided functions to compute powers and currents:
```@example PMUStateEstimationSolution
power!(system, analysis)
current!(system, analysis)
nothing # hide
```

For instance, if we want to show the active power injections and the from-bus current magnitudes, we can employ the following code:
```@repl PMUStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.from.magnitude)
```

!!! note "Info"
    To better understand the powers and currents associated with buses and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [PMU State Estimation](@ref PMUPowerAnalysisTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print API](@ref setupPrintAPI). For example, to print state estimation data related to PMUs, we can use:
```@example PMUStateEstimationSolution
@voltage(pu, deg)
show = Dict("Voltage Angle" => false, "Current Angle" => false)
printPmuData(system, device, analysis; show)
@default(unit) # hide
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printPmuData(system, device, analysis, io; style = false)
CSV.write("bus.csv", CSV.File(take!(io); delim = "|"))
```

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl PMUStateEstimationSolution
active, reactive = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl PMUStateEstimationSolution
active, reactive = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl PMUStateEstimationSolution
active, reactive = shuntPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl PMUStateEstimationSolution
active, reactive = fromPower(system, analysis; label = "Branch 2")
active, reactive = toPower(system, analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl PMUStateEstimationSolution
active, reactive = chargingPower(system, analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl PMUStateEstimationSolution
active, reactive = seriesPower(system, analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl PMUStateEstimationSolution
magnitude, angle = injectionCurrent(system, analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl PMUStateEstimationSolution
magnitude, angle = fromCurrent(system, analysis; label = "Branch 2")
magnitude, angle = toCurrent(system, analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the from-bus end to the to-bus end, we can use the following function:
```@repl PMUStateEstimationSolution
magnitude, angle = seriesCurrent(system, analysis; label = "Branch 2")
```