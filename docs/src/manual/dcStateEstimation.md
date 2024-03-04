# [DC State Estimation](@id DCStateEstimationManual)
To perform the DC state estimation, you first need to have the `PowerSystem` composite type that has been created with the `dc` model, alongside the `Measurement` composite type that retains measurement data. Subsequently, we can formulate the DC state estimation model encapsulated within the abstract type `DCStateEstimation` using the subsequent function:
* [`dcStateEstimation`](@ref dcStateEstimation).

For resolving the DC state estimation problem employing either the weighted least-squares (WLS) or the least absolute value (LAV) approach and obtaining bus voltage angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})).

After executing the function [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})), where the user employs the WLS method, the user has the ability to check if the measurement set contains outliers throughout bad data analysis and remove those measurements using:
* [`residualTest!`](@ref residualTest!).

Moreover, before executing the [`dcStateEstimation`](@ref dcStateEstimation) function, users can initiate observability analysis to identify observable islands and restore observability by employing:
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Wattmeter)),
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Wattmeter)),
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)).

---

After obtaining the solution for DC state estimation, JuliaGrid offers a post-processing analysis function to compute active powers associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)).

Additionally, there are specialized functions dedicated to calculating specific types of active powers related to particular buses or branches:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::DCStateEstimation)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::DCStateEstimation)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::DCStateEstimation)),
* [`toPower`](@ref toPower(::PowerSystem, ::DCStateEstimation)).

---

## [Bus Type Modification](@id DCSEBusTypeModificationManual)
Similar to the explanation provided in the [Bus Type Modification](@ref DCBusTypeModificationManual) section, when executing the [`dcStateEstimation`](@ref dcStateEstimation) function, the initially designated slack bus undergoes evaluation and may be adjusted. If the bus designated as the slack bus (`type = 3`) lacks a connected in-service generator, its type will be changed to the demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).

---

## [Observability Analysis](@id DCSEObservabilityAnalysisManual)
To initiate the power system with measurements at specific locations, follow the provided example code:
```@example DCSEObservabilityAnalysis
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)
addBus!(system; label = "Bus 4", type = 1, active = 0.05)
addBus!(system; label = "Bus 5", type = 1, active = 0.05)
addBus!(system; label = "Bus 6", type = 1, active = 0.05)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 5", reactance = 0.01)
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", reactance = 0.01)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.01)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)

device = measurement()

@wattmeter(label = "Wattmeter ?: !")
addWattmeter!(system, device; from = "Branch 1", active = 0.31, variance = 1e-4)
addWattmeter!(system, device; from = "Branch 3", active = 0.09, variance = 1e-4)
addWattmeter!(system, device; bus = "Bus 3", active = -0.05, variance = 1e-4)
addWattmeter!(system, device; bus = "Bus 3", active = -0.05, variance = 1e-4)

nothing # hide
``` 

Attempting to solve this system immediately may not be possible because the gain matrix will be singular. To avoid this situation, users can perform observability analysis. The first step is to define the observable islands. 

JuliaGrid provides users with the option to obtain two types of observable islands: flow observable islands or maximal observable islands. The choice depends on the structure of the power system and available measurements. Detecting just flow observable islands reduces complexity in the island detection function but increases complexity in the restoration function. 

---

##### Flow Observable Islands
Now, let us identify flow observable islands:
```@example DCSEObservabilityAnalysis
flowIslands = islandTopologicalFlow(system, device.wattmeter)

nothing # hide
``` 

As a result, we have identified four flow observable islands. The first island is formed by `Bus 1` and `Bus 2`, the second island is formed by `Bus 3` and `Bus 5`, while `Bus 4` and `Bus 6` constitute the third and fourth islands, respectively:
```@repl DCSEObservabilityAnalysis
flowIslands.island
nothing # hide
```

---

##### Maximal Observable Islands
Following that, we will instruct the user on obtaining maximal observable islands:
```@example DCSEObservabilityAnalysis
maxIslands = islandTopological(system, device.wattmeter)

nothing # hide
``` 

The outcome reveals the identification of two maximal observable islands:
```@repl DCSEObservabilityAnalysis
maxIslands.island
nothing # hide
```
It is evident that upon comparing this result with the flow observable islands, the merging of the two injection measurements at `Bus 3` consolidated the first, second, and third flow observable islands into a single island.

---

##### Restore Observability
To reinstate observability, the user needs to identify either flow or maximal observable islands and establish a set of pseudo-measurements. Let us create that set:
```@example DCSEObservabilityAnalysis
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudo-Wattmeter 1", bus = "Bus 1", active = 0.31)
addWattmeter!(system, pseudo; label = "Pseudo-Wattmeter 2", bus = "Bus 6", active = -0.05)
nothing # hide
``` 

!!! note "Info"
    The labels for specific pseudo-measurements must differ from those defined in the measurements stored in the `device` set. This is necessary because the next step involves adding pseudo-measurements to the `device` set.

Subsequently, the user can execute the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)) function:
```@example DCSEObservabilityAnalysis
restorationGram!(system, device, pseudo, maxIslands)
nothing # hide
``` 

This function attempts to restore observability using pseudo-measurements. As a result, the `Pseudo-Wattmeter 2` measurement restores observability, and this measurement is added to the device variable, which holds actual measurements:
```@repl DCSEObservabilityAnalysis
device.wattmeter.label
nothing # hide
```
Consequently, the power system becomes observable, allowing the user to proceed with forming the DC state estimation model and solving it. Ensuring the observability of the system does not guarantee obtaining accurate estimates of the state variables. Numerical ill-conditioning may adversely impact the state estimation algorithm. However, in most cases, efficient estimation becomes feasible when the system is observable. [[1]](@ref DCStateEstimationReferenceManual). 

Additionally, it is worth mentioning that restoration might encounter difficulties due to the default zero pivot threshold set at `1e-5`. This threshold can be modified using the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::IslandWatt)) function.

!!! note "Info"
    During the restoration step, the user can define bus voltage angles from PMUs that will also participate in the restoration step. In this case, the system can become observable even if there are still more islands.

---

## [WLS State Estimation Solution](@id DCWLSStateEstimationSolutionManual)
To solve the DC state estimation and derive WLS estimates using JuliaGrid, the process initiates by defining the composite types `PowerSystem` and `Measurement`. Here is an illustrative example:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
dcModel!(system)

device = measurement()

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 1", active = 0.13, variance = 1e-3)
addWattmeter!(system, device; bus = "Bus 3", active = -0.02, variance = 1e-2)
addWattmeter!(system, device; from = "Branch 1", active = 0.04, variance = 1e-4)
addWattmeter!(system, device; to = "Branch 2", active = -0.11, variance = 1e-4)

nothing # hide
```

The [`dcStateEstimation`](@ref dcStateEstimation) function serves to establish the DC state estimation problem:  
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(system, device)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the DC state estimation problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`.

To obtain the bus voltage angles, the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function can be invoked as shown:
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
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [[2, Sec. 3.2]](@ref DCStateEstimationReferenceManual).

Specifically, by specifying the `Orthogonal` argument in the [`dcStateEstimation`](@ref dcStateEstimation) function, JuliaGrid implements a more robust approach to obtain the WLS estimator, which proves particularly beneficial when substantial differences exist among measurement variances:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(system, device, Orthogonal)
solve!(system, analysis)
nothing # hide
```

---

## [Bad Data Detection](@id DCBadDataDetectionManual)
After acquiring the WLS solution using the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function, users can conduct bad data analysis employing the largest normalized residual test. Continuing with our defined power system and measurement set, let us introduce a new wattmeter. Upon proceeding to find the solution for this updated state:
```@example WLSDCStateEstimationSolution
addWattmeter!(system, device; from = "Branch 2", active = 4.1, variance = 1e-4)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

Following the solution acquisition, we can verify the presence of erroneous data. Detection of such data is determined by the `threshold` keyword. If the largest normalized residual's value exceeds the threshold, the measurement will be identified as bad data and consequently removed from the DC state estimation model:
```@example WLSDCStateEstimationSolution
residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

Users can examine the data obtained from the bad data analysis:
```@repl WLSDCStateEstimationSolution
analysis.outlier.detect
analysis.outlier.maxNormalizedResidual
analysis.outlier.label
```
Hence, upon detecting bad data, the `detect` variable will hold `true`. The `maxNormalizedResidual` variable retains the value of the largest normalized residual, while the `label` contains the label of the measurement identified as bad data. JuliaGrid will mark the respective measurements as out-of-service within the `Measurement` type.

Moreover, JuliaGrid will adjust the coefficient matrix and mean vector within the `DCStateEstimation` type based on measurements now designated as out-of-service. To optimize the algorithm's efficiency, JuliaGrid resets non-zero elements to zero in the coefficient matrix and mean vector. The `index` variable denotes positions within the mean vector that will be reset to zero. Additionally, it records the row index within the coefficient matrix where non-zero elements will be adjusted to zero. Here's an illustration:
```@repl WLSDCStateEstimationSolution
analysis.outlier.index
analysis.method.mean
analysis.method.coefficient
```

Hence, after removing bad data, a new estimate can be computed without considering this specific measurement:
```@example WLSDCStateEstimationSolution
solve!(system, analysis)
nothing # hide
```

---

## [LAV State Estimation Solution](@id DCLAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data processing procedures [[2, Ch. 6]](@ref DCStateEstimationReferenceManual). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example WLSDCStateEstimationSolution
using Ipopt
using JuMP  # hide

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
nothing # hide
```

---

##### Setup Starting Primal Values
In JuliaGrid, the assignment of starting primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function is executed. Starting primal values are determined based on the `voltage` fields within the `DCStateEstimation` type. By default, these values are initially established using the the initial bus voltage angles from `PowerSystem` type:
```@repl WLSDCStateEstimationSolution
print(system.bus.label, analysis.voltage.angle)
```
Users have the flexibility to customize these values according to their requirements, and they will be utilized as the starting primal values when executing the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function.

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

---

## [Measurement Set Update](@id DCMeasurementsAlterationManual)
After establishing the `Measurement` composite type using the [`measurement`](@ref measurement) function, users gain the capability to incorporate new measurement devices or update existing ones. 

Once updates are completed, users can seamlessly progress towards generating the `DCStateEstimation` type using the [`dcStateEstimation`](@ref dcStateEstimation) function. Ultimately, resolving the DC state estimation is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.1)
dcModel!(system)

device = measurement()
@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 1", active = 0.09, variance = 1e-4)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)

addWattmeter!(system, device; to = "Branch 1", active = -0.12, variance = 1e-4)
updateWattmeter!(system, device; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device; label = "Wattmeter 2", active = 0.095, noise = false)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)

nothing # hide
```

!!! note "Info"
    This method removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id DCStateEstimationUpdateManual)
An advanced methodology involves users establishing the `DCStateEstimation` composite type using [`dcStateEstimation`](@ref dcStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `DCStateEstimation` type.

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `DCStateEstimation` also does not need to be recreated. Such efficiency can be particularly advantageous in cases where JuliaGrid can reuse gain matrix factorization.

The addition of new measurements after the creation of `DCStateEstimation` is not practical in terms of reusing the `DCStateEstimation` type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

!!! note "Info"
    This method removes the need to restart and recreate both the `Measurement` and the `DCStateEstimation` from the beginning when implementing changes to the existing measurement set.

---

##### Reusing WLS Matrix Factorization 
Drawing from the preceding example, our focus now shifts to finding a solution involving modifications that entail adjusting the measurement value of the `Wattmeter 2`. It is important to note that these adjustments do not impact the variance or status of the measurement device, which can affect the gain matrix. To resolve this updated system, users can simply execute the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function:
```@example WLSDCStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.1)
dcModel!(system)

device = measurement()
@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 1", active = 0.09, variance = 1e-4)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)

updateWattmeter!(system, device, analysis; label = "Wattmeter 2", active = 0.091)

solve!(system, analysis)
nothing # hide
```

!!! note "Info"
    In this scenario, JuliaGrid will recognize instances where the user has not modified parameters that impact the gain matrix. Consequently, JuliaGrid will leverage the previously performed gain matrix factorization, resulting in a significantly faster solution compared to recomputing the factorization.

---

##### Sequential WLS Matrix Factorization
If the user opts to modify the measurement variances or status of measurement devices, reusing the gain matrix factorization becomes impractical. In this scenario, JuliaGrid will need to repeat the factorization step while ensuring the delivery of an accurate solution. 

Although computational gains are diminished compared to the previous case, users can still avoid recreating the `DCStateEstimation` type and effortlessly execute the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function, as demonstrated below:

```@example WLSDCStateEstimationSolution
updateWattmeter!(system, device, analysis; label = "Wattmeter 1", variance = 1e-2)
updateWattmeter!(system, device, analysis; label = "Wattmeter 2", status = 1)

solve!(system, analysis)
```

--- 

##### LAV State Estimation
When a user creates an optimization problem using the LAV method, they can update measurement devices without the need to recreate the model from scratch, similar to the explanation provided for the WLS state estimation. This streamlined process allows for efficient modifications while retaining the existing optimization framework:
```@example WLSDCStateEstimationSolution
using Ipopt
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.5)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.1)
dcModel!(system)

device = measurement()
@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device; bus = "Bus 2", active = -0.11, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 1", active = 0.09, variance = 1e-4)

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)

updateWattmeter!(system, device, analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device, analysis; label = "Wattmeter 2", active = -0.12)

solve!(system, analysis)

nothing # hide
```

---

## [Power Analysis](@id DCSEPowerAnalysisManual)
After obtaining the solution from the DC state estimation, calculating powers related to buses and branches is facilitated by using the [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)) function. To illustrate this with a continuation of our previous example, we can compute active powers using the following function:
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

To calculate specific quantities related to particular buses or branches, rather than computing values for all buses and branches, users can utilize one of the provided functions below.

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
Similarly, we can compute the active power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSDCStateEstimationSolution
active = fromPower(system, analysis; label = "Branch 1")
active = toPower(system, analysis; label = "Branch 1")
```

---


## [References](@id DCStateEstimationReferenceManual)
[1] G. N. Korres, *Observability analysis based on echelon form of a reduced dimensional Jacobian matrix*, IEEE Trans. Power Syst., vol. 26, no. 4, pp. 2572–2573, 2011. 

[2] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, ser. Power Engineering. Taylor & Francis, 2004.


