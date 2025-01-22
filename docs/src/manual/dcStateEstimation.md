# [DC State Estimation](@id DCStateEstimationManual)
To perform the DC state estimation, we first need to have the `PowerSystem` type that has been created with the DC model, alongside the `Measurement` type that retains measurement data. Subsequently, we can formulate either the weighted least-squares (WLS) or the least absolute value (LAV) DC state estimation model encapsulated within the type `DCStateEstimation` using:
* [`dcStateEstimation`](@ref dcStateEstimation),
* [`dcLavStateEstimation`](@ref dcLavStateEstimation).

For resolving the DC state estimation problem and obtaining bus voltage angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})).

After executing the function [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})), where the user employs the WLS method, the user has the ability to check if the measurement set contains outliers throughout bad data analysis and remove those measurements using:
* [`residualTest!`](@ref residualTest!).

Moreover, before creating the `DCStateEstimation` type, users can initiate observability analysis to identify observable islands and restore observability by employing:
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Measurement)),
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Measurement)),
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)).
For more detailed information, users can refer to the [Observability Analysis](@ref ACSEObservabilityAnalysisManual) section within AC state estimation documentation. It is worth noting that when the system becomes observable within the AC model, it will also be observable within the DC state estimation model.

---

After obtaining the solution for DC state estimation, JuliaGrid offers a post-processing analysis function to compute active powers associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)).

Additionally, specialized functions are available for calculating specific types of [powers](@ref DCPowerAnalysisAPI) for individual buses or branches.

---

## [Bus Type Modification](@id DCSEBusTypeModificationManual)
Just like in the [Bus Type Modification](@ref DCBusTypeModificationManual) section, when establishing the `DCStateEstimation` type, the initially assigned slack bus is evaluated and may be altered. If the designated slack bus (`type = 3`) lacks a connected in-service generator, it will be changed to a demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).

---

## [Weighted Least-Squares Estimator](@id DCWLSStateEstimationSolutionManual)
To solve the DC state estimation and derive WLS estimates using JuliaGrid, the process initiates by defining `PowerSystem` and `Measurement` types. Here is an illustrative example:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.2)
addBus!(system; label = "Bus 3", type = 1, active = 0.4)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.2)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(system, device; bus = "Bus 3", active = -0.4, variance = 1e-2)
addWattmeter!(system, device; from = "Branch 1", active = 0.18, variance = 1e-4)
addWattmeter!(system, device; to = "Branch 2", active = -0.42, variance = 1e-4)
nothing # hide
```

The [`dcStateEstimation`](@ref dcStateEstimation) function serves to establish the DC state estimation problem:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(system, device)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the DC state estimation problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`:
    ```julia WLSDCStateEstimationSolution
    analysis = dcStateEstimation(system, device, LDLt)
    ```

To obtain the bus voltage angles, the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function can be invoked as shown:
```@example WLSDCStateEstimationSolution
solve!(system, analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage angles using:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    We recommend that readers refer to the tutorial on [DC State Estimation](@ref DCSEModelTutorials) for insights into the implementation.

---

##### Alternative Formulation
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite).

Specifically, by specifying the `Orthogonal` argument in the [`dcStateEstimation`](@ref dcStateEstimation) function, JuliaGrid implements a more robust approach to obtain the WLS estimator, which proves particularly beneficial when substantial differences exist among measurement variances:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(system, device, Orthogonal)
solve!(system, analysis)
nothing # hide
```

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example WLSDCStateEstimationSolution
@voltage(pu, deg, V)
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
    We also provide functions to print state estimation results, such as estimated values and residuals. For more details, users can consult the [Power Analysis](@ref DCSEPowerAnalysisManual) section of this manual.

---

## [Bad Data Processing](@id DCBadDataDetectionManual)
After acquiring the WLS solution using the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function, users can conduct bad data analysis employing the largest normalized residual test. Continuing with our defined power system and measurement set, let us introduce a new wattmeter. Upon proceeding to find the solution for this updated state:
```@example WLSDCStateEstimationSolution
addWattmeter!(system, device; from = "Branch 2", active = 4.1, variance = 1e-4)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

Following the solution acquisition, we can verify the presence of erroneous data. Detection of such data is determined by the `threshold` keyword. If the largest normalized residual's value exceeds the threshold, the measurement will be identified as bad data and consequently removed from the DC state estimation model:
```@example WLSDCStateEstimationSolution
outlier = residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

Users can examine the data obtained from the bad data analysis:
```@repl WLSDCStateEstimationSolution
outlier.detect
outlier.maxNormalizedResidual
outlier.label
```

Hence, upon detecting bad data, the `detect` variable will hold `true`. The `maxNormalizedResidual` variable retains the value of the largest normalized residual, while the `label` contains the label of the measurement identified as bad data. JuliaGrid will mark the respective measurements as out-of-service within the `Measurement` type.

Moreover, JuliaGrid will adjust the coefficient matrix and mean vector within the `DCStateEstimation` type based on measurements now designated as out-of-service. To optimize the algorithm's efficiency, JuliaGrid resets non-zero elements to zero in the coefficient matrix and mean vector, effectively removing the impact of the corresponding measurement on the solution:
```@repl WLSDCStateEstimationSolution
analysis.method.mean
analysis.method.coefficient
```

Hence, after removing bad data, a new estimate can be computed without considering this specific measurement:
```@example WLSDCStateEstimationSolution
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    We suggest that readers refer to the tutorial on [Bad Data Processing](@ref DCSEBadDataTutorials) for insights into the implementation.

---

## [Least Absolute Value Estimator](@id DCLAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data processing procedures [aburbook; Ch. 6](@cite). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example WLSDCStateEstimationSolution
using Ipopt
using JuMP  # hide

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
nothing # hide
```

---

##### Setup Starting Primal Values
In JuliaGrid, the assignment of starting primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function is executed. Starting primal values are determined based on the `voltage` fields within the `DCStateEstimation` type. By default, these values are initially established using the initial bus voltage angles from `PowerSystem` type:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
```
Users have the flexibility to customize these values according to their requirements, and they will be utilized as the starting primal values when executing the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function.

---

##### Solution
To solve the formulated LAV state estimation model, simply execute the following function:
```@example WLSDCStateEstimationSolution
solve!(system, analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage angles using:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    We suggest that readers refer to the tutorial on [Least Absolute Value Estimation](@ref DCSELAVTutorials) for insights into the implementation.

---

## [Measurement Set Update](@id DCMeasurementsAlterationManual)
After establishing the `Measurement` type using the [`measurement`](@ref measurement) function, users gain the capability to incorporate new measurement devices or update existing ones.

Once updates are completed, users can seamlessly progress towards generating the `DCStateEstimation` type using the [`dcStateEstimation`](@ref dcStateEstimation) or [`dcLavStateEstimation`](@ref dcLavStateEstimation) function. Ultimately, resolving the DC state estimation is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement() # <- Initialize the Measurement instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.1)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 1", active = 0.09, variance = 1e-4)

analysis = dcStateEstimation(system, device) # <- Build DCStateEstimation for the model
solve!(system, analysis)

addWattmeter!(system, device; to = "Branch 1", active = -0.12, variance = 1e-4)
updateWattmeter!(system, device; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device; label = "Wattmeter 2", active = 0.1, noise = false)

analysis = dcStateEstimation(system, device) # <- Build DCStateEstimation for new model
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id DCStateEstimationUpdateManual)
An advanced methodology involves users establishing the `DCStateEstimation` type using [`dcStateEstimation`](@ref dcStateEstimation) or [`dcLavStateEstimation`](@ref dcLavStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `DCStateEstimation` type.

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `DCStateEstimation` also does not need to be recreated. Such efficiency can be particularly advantageous in cases where JuliaGrid can reuse gain matrix factorization.

!!! tip "Tip"
    The addition of new measurements after the creation of `DCStateEstimation` is not practical in terms of reusing this type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

We can modify the prior example to achieve the same model without establishing `DCStateEstimation` twice:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement() # <- Initialize the Measurement instance

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.1)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 1", active = 0.09, variance = 1e-4)
addWattmeter!(system, device; to = "Branch 1", active = -0.12, variance = 1e-4, status = 0)

analysis = dcStateEstimation(system, device) # <- Build DCStateEstimation for the model
solve!(system, analysis)

updateWattmeter!(system, device, analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device, analysis; label = "Wattmeter 2", active = 0.1)
updateWattmeter!(system, device, analysis; label = "Wattmeter 3", status = 1, noise = false)

# <- No need for re-build; we have already updated the existing DCStateEstimation instance
solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    This concept removes the need to rebuild both the `Measurement` and the `DCStateEstimation` from the beginning when implementing changes to the existing measurement set. In the scenario of employing the WLS model, JuliaGrid can reuse the symbolic factorizations of LU or LDLt, provided that the nonzero pattern of the gain matrix remains unchanged.

---

##### Reusing Weighted Least-Squares Matrix Factorization
Drawing from the preceding example, our focus now shifts to finding a solution involving modifications that entail adjusting the measurement value of the `Wattmeter 2`. It is important to note that these adjustments do not impact the variance or status of the measurement device, which can affect the gain matrix. To resolve this updated system, users can simply execute the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{LinearWLS{Normal}})) function:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

updateWattmeter!(system, device, analysis; label = "Wattmeter 2", active = 0.091)

solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    In this scenario, JuliaGrid will recognize instances where the user has not modified parameters that impact the gain matrix. Consequently, JuliaGrid will leverage the previously performed gain matrix factorization, resulting in a significantly faster solution compared to recomputing the factorization.

---

## [Power Analysis](@id DCSEPowerAnalysisManual)
After obtaining the solution from the DC state estimation, calculating powers related to buses and branches is facilitated by using the [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)) function. For instance, let us consider the model for which we obtained the DC state estimation solution:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3, conductance = 1e-3)
addBus!(system; label = "Bus 2", type = 1, active = 0.2)
addBus!(system; label = "Bus 3", type = 1, active = 0.4)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.2)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

addWattmeter!(system, device; bus = "Bus 1", active = 0.6, variance = 1e-3)
addWattmeter!(system, device; bus = "Bus 3", active = -0.4, variance = 1e-2)
addWattmeter!(system, device; from = "Branch 1", active = 0.18, variance = 1e-4)
addWattmeter!(system, device; to = "Branch 2", active = -0.42, variance = 1e-4)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

We can compute active powers using the following function:
```@example WLSDCStateEstimationSolution
power!(system, analysis)
nothing # hide
```

For example, active power injections corresponding to buses are:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
```

!!! note "Info"
    To better understand the powers associated with buses, and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)) function, we suggest referring to the tutorials on.

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print API](@ref setupPrintAPI) related to the DC analysis. For example, to print state estimation data related to wattmeters, we can use:
```@example WLSDCStateEstimationSolution
@power(MW, pu, pu)
printWattmeterData(system, device, analysis)
@default(unit) # hide
```

---

##### Save Results to a CSV File
For CSV output, users should first generate a simple table with `style = false`, and then save it to a CSV file:
```julia
using CSV

io = IOBuffer()
printWattmeterData(system, device, analysis, io; style = false)
CSV.write("bus.csv", CSV.File(take!(io); delim = "|"))
```

---

##### Active Power Injection
To calculate active power injection associated with a specific bus, the function can be used:
```@repl WLSDCStateEstimationSolution
active = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active Power Injection from Generators
To calculate active power injection from the generators at a specific bus, the function can be used:
```@repl WLSDCStateEstimationSolution
active = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active Power Flow
Similarly, we can compute the active power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSDCStateEstimationSolution
active = fromPower(system, analysis; label = "Branch 1")
active = toPower(system, analysis; label = "Branch 1")
```