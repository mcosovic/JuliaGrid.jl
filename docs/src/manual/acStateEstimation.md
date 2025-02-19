# [AC State Estimation](@id ACStateEstimationManual)
To perform nonlinear or AC state estimation, the initial requirement is to have the `PowerSystem` type configured with the AC model, along with the `Measurement` type storing measurement data. Next, we can develop either the weighted least-squares (WLS) model, utilizing the Gauss-Newton method, or the least absolute value (LAV) model. These models are encapsulated within the `ACStateEstimation` type:
* [`gaussNewton`](@ref gaussNewton),
* [`acLavStateEstimation`](@ref acLavStateEstimation).

For resolving the AC state estimation problem and obtaining bus voltage magnitudes and angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})).

After executing the function [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})), where the user employs the Gauss-Newton method, the user has the ability to check if the measurement set contains outliers throughout bad data analysis and remove those measurements using:
* [`residualTest!`](@ref residualTest!).

Moreover, before the creating `ACStateEstimation` type, users can initiate observability analysis to identify observable islands and restore observability by employing:
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Measurement)),
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Measurement)),
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)).

---

After obtaining the AC state estimation solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::AC)).

Additionally, specialized functions are available for calculating specific types of [powers](@ref ACPowerAnalysisAPI) or [currents](@ref ACCurrentAnalysisAPI) for individual buses or branches.

---

## [Bus Type Modification](@id ACSEBusTypeModificationManual)
In AC state estimation, it is necessary to designate a slack bus, where the bus voltage angle is known. Therefore, when establishing the `ACStateEstimation` type, the initially assigned slack bus is evaluated and may be altered. If the designated slack bus (`type = 3`) lacks a connected in-service generator, it will be changed to a demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).

---

## [Observability Analysis](@id ACSEObservabilityAnalysisManual)
To initiate the power system with measurements at specific locations, follow the provided example:
```@example ACSEObservabilityAnalysis
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 3", type = 2, active = 0.5, reactive = 0.01)
addBus!(system; label = "Bus 4", type = 1, active = 0.2, reactive = 0.02)
addBus!(system; label = "Bus 5", type = 1, active = 0.3, reactive = 0.03)
addBus!(system; label = "Bus 6", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 7", type = 1, active = 0.1, reactive = 0.01)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.002)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 5", reactance = 0.02)
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", reactance = 0.03)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.05)
addBranch!(system; label = "Branch 6", from = "Bus 3", to = "Bus 5", reactance = 0.05)
addBranch!(system; label = "Branch 7", from = "Bus 6", to = "Bus 7", reactance = 0.05)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 4.2, reactive = 0.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 3", active = 0.2, reactive = 0.1)

addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", active = 1.15)
addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", reactive = -0.50)

addWattmeter!(system, device; label = "Wattmeter 2", from = "Branch 4", active = 0.20)
addVarmeter!(system, device; label = "Varmeter 2", from = "Branch 4", reactive = -0.02)

addWattmeter!(system, device; label = "Wattmeter 3", from = "Branch 5", active = -0.20)
addVarmeter!(system, device; label = "Varmeter 3", from = "Branch 5", reactive = 0.02)

addWattmeter!(system, device; label = "Wattmeter 4", bus = "Bus 2", active = -0.1)
addVarmeter!(system, device; label = "Varmeter 4", bus = "Bus 2", reactive = -0.01)

addWattmeter!(system, device; label = "Wattmeter 5", bus = "Bus 3", active = -0.30)
addVarmeter!(system, device; label = "Varmeter 5", bus = "Bus 3", reactive = 0.66)
nothing # hide
```

Attempting to solve this system immediately may not be possible because the gain matrix will be singular. To avoid this situation, users can perform observability analysis.

JuliaGrid employs standard observability analysis performed on the linear decoupled measurement model. Active power measurements from wattmeters are utilized to estimate bus voltage angles, while reactive power measurements from varmeters are used to estimate bus voltage magnitudes. This necessitates that measurements of active and reactive power come in pairs.

!!! note "Info"
    We suggest that readers refer to the tutorial on [Observability Analysis](@ref ACObservabilityAnalysisTutorials) for insights into the implementation.

However, the initial step involves defining observable islands. JuliaGrid offers users two options for obtaining observable islands: flow observable islands or maximal observable islands. The selection depends on the power system's structure and available measurements. Identifying only flow observable islands reduces complexity in the island detection function, but increases complexity in the restoration function.

---

##### Flow Observable Islands
Now, let us identify flow observable islands:
```@example ACSEObservabilityAnalysis
islands = islandTopologicalFlow(system, device)
nothing # hide
```

As a result, four flow observable islands are identified: `Bus 1` and `Bus 2` form the first island, `Bus 3` and `Bus 4` form the second island, `Bus 5` and `Bus 6` constitute the third island, while `Bus 7` forms the fourth island:
```@repl ACSEObservabilityAnalysis
islands.island
nothing # hide
```

---

##### Maximal Observable Islands
Following that, we will instruct the user on obtaining maximal observable islands:
```@example ACSEObservabilityAnalysis
islands = islandTopological(system, device)
nothing # hide
```

The outcome reveals the identification of two maximal observable islands:
```@repl ACSEObservabilityAnalysis
islands.island
nothing # hide
```
It is evident that upon comparing this result with the flow islands, the merging of the two injection measurements at `Bus 2` and `Bus 3` consolidated the first, second, and third flow observable islands into a single island.

---

##### Restore Observability
Before commencing the restoration of observability in the context of the linear decoupled measurement model and observability analysis, it is imperative to ensure that the system possesses one bus voltage magnitude measurement. This necessity arises from the fact that observable islands are identified based on wattmeters, where wattmeters are tasked with estimating voltage angles. Since one voltage angle is already known from the slack bus, the same principle should be applied to bus voltage magnitudes. Therefore, to address this requirement, we add:
```@example ACSEObservabilityAnalysis
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0)
nothing # hide
```

Subsequently, the user needs to establish a set of pseudo-measurements, where measurements must come in pairs as well. Let us create that set:
```@example ACSEObservabilityAnalysis
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudo-Wattmeter 1", bus = "Bus 1", active = 0.31)
addVarmeter!(system, pseudo; label = "Pseudo-Varmeter 1", bus = "Bus 1", reactive = -0.19)

addWattmeter!(system, pseudo; label = "Pseudo-Wattmeter 2", from = "Branch 7", active = 0.10)
addVarmeter!(system, pseudo; label = "Pseudo-Varmeter 2", from = "Branch 7", reactive = 0.01)
nothing # hide
```

!!! note "Info"
    The labels for specific pseudo-measurements must differ from those defined in the measurements stored in the `device` set. This is necessary because the next step involves adding pseudo-measurements to the `device` set.

Subsequently, the user can execute the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function:
```@example ACSEObservabilityAnalysis
restorationGram!(system, device, pseudo, islands)
nothing # hide
```

This function attempts to restore observability using pseudo-measurements. As a result, the inclusion of measurements from `Pseudo-Wattmeter 2` and `Pseudo-Varmeter 2` facilitates observability restoration, and these measurements are subsequently added to the `device` variable:
```@repl ACSEObservabilityAnalysis
device.wattmeter.label
device.varmeter.label
nothing # hide
```
Consequently, the power system becomes observable, allowing the user to proceed with forming the AC state estimation model and solving it. Ensuring the observability of the system does not guarantee obtaining accurate estimates of the state variables. Numerical ill-conditioning may adversely impact the state estimation algorithm. However, in most cases, efficient estimation becomes feasible when the system is observable [korres2011observability](@cite).

Additionally, it is worth mentioning that restoration might encounter difficulties due to the default zero pivot threshold set at `1e-5`. This threshold can be modified using the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function.

!!! note "Info"
    During the restoration step, if users define bus phasor measurements, these measurements will be considered. Consequently, the system may achieve observability even if multiple islands persist.

---

## [Weighted Least-Squares Estimator](@id ACLSStateEstimationSolutionManual)
To begin, we will define the `PowerSystem` and `Measurement` types:
```@example ACSEWLS
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1, reactive = 0.01)
addBus!(system; label = "Bus 3", type = 1, active = 2.5, reactive = 0.2)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

@voltmeter(label = "Voltmeter ? (!)")
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0, variance = 1e-4)

@ammeter(label = "Ammeter ? (!)")
addAmmeter!(system, device; from = "Branch 3", magnitude = 0.947, variance = 1e-3)
addAmmeter!(system, device; to = "Branch 2", magnitude = 1.674, variance = 1e-3)

@wattmeter(label = "Wattmeter ? (!)")
addWattmeter!(system, device; from = "Branch 1", active = 1.046, variance = 1e-4)
addWattmeter!(system, device; bus = "Bus 2", active = -0.1, variance = 2e-4)

@varmeter(label = "Varmeter ? (!)")
addVarmeter!(system, device; from = "Branch 1", reactive = 0.059, variance = 1e-4)
addVarmeter!(system, device; bus = "Bus 2", reactive = -0.01, variance = 1e-5)
nothing # hide
```

Next, to establish the AC state estimation model, we will utilize the [`gaussNewton`](@ref gaussNewton) function:
```@example ACSEWLS
analysis = gaussNewton(system, device)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the system of linear equations within each iteration of the Gauss-Newton method. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`:
    ```julia ACSEObservabilityAnalysis
    analysis = gaussNewton(system, device, LDLt)
    ```

---

##### Setup Initial Voltages
The initial voltages for the Gauss-Newton method are determined based on the specified initial voltage magnitudes and angles within the buses of the `PowerSystem` type. These values are then forwarded to the `ACStateEstimation` during the execution of the [`gaussNewton`](@ref gaussNewton) function. Therefore, the initial voltages in this example are as follows:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users have the flexibility to modify these vectors according to their own requirements in order to adjust the initial voltages. For instance, users can conduct an AC power flow analysis and utilize the obtained solution as the initial voltages for AC state estimation:
```@example ACSEWLS
powerFlow = newtonRaphson(system)
for iteration = 1:10
    mismatch!(system, powerFlow)
    solve!(system, powerFlow)
end

setInitialPoint!(powerFlow, analysis)
nothing # hide
```

---

##### State Estimator
To conduct an iterative process using the Gauss-Newton method, it is essential to include the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function inside the iteration loop. For example:
```@example ACSEWLS
for iteration = 1:20
    solve!(system, analysis)
end
nothing # hide
```

Once the state estimator is obtained, users can access the bus voltage magnitudes and angles using:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

##### Breaking the Iterative Process
The iterative process can be terminated using the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function. The following code demonstrates how to utilize this function to break out of the iteration loop:
```@example ACSEWLS
analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        println("Solution Found.")
        break
    end
end
nothing # hide
```
The [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function returns the maximum absolute values of the state variable increment, which are commonly used as a convergence criterion in the iterative Gauss-Newton algorithm.

!!! note "Info"
    We suggest that readers refer to the tutorial on [AC State Estimation](@ref ACStateEstimationTutorials) for insights into the implementation.

---

##### Inclusion of PMUs in Rectangular Coordinates
In the example above, our focus is solely on solving the AC state estimation using SCADA measurements. However, users have the option to also integrate PMUs into the AC state estimation, either in the rectangular or polar coordinate system.

The default approach is to include PMUs in the rectangular coordinate system:
```@example ACSEWLS
@pmu(label = "PMU ? (!)")
addPmu!(system, device; to = "Branch 1", magnitude = 1.05, angle = 3.047)
nothing # hide
```

In the case of the rectangular system, inclusion resolves ill-conditioned problems arising in polar coordinates due to small values of current magnitudes. However, this approach's main disadvantage is related to measurement errors, as measurement errors correspond to polar coordinates. Therefore, the covariance matrix must be transformed from polar to rectangular coordinates [zhou2006alternative](@cite). As a result, measurement errors of a single PMU are correlated, and the covariance matrix does not have a diagonal form. Despite that, the measurement error covariance matrix is usually considered as a diagonal matrix, affecting the accuracy of the state estimation.

In the example above, we specifically include PMUs where measurement error correlations are disregarded. This is evident through the precision matrix, which maintains a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(system, device);
analysis.method.precision
```

Lastly, we incorporate correlation into our model by adding a new PMU with the desired error correlation:
```@example ACSEWLS
addPmu!(system, device; bus = "Bus 3", magnitude = 0.95, angle = -0.08, correlated = true)
nothing # hide
```

Now, we can observe the precision matrix that does not hold a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(system, device);
analysis.method.precision
```

---

##### Inclusion of PMUs in Polar Coordinates
The second approach involves incorporating these measurements into the polar coordinate system. For instance:
```@example ACSEWLS
addPmu!(system, device; from = "Branch 1", magnitude = 1.048, angle = -0.057, polar = true)
nothing # hide
```

This inclusion of PMUs provides more accurate state estimates compared to rectangular inclusion, but demands longer computing time. PMUs are handled in the same manner as SCADA measurements. However, this approach is susceptible to ill-conditioned problems arising in polar coordinates due to small values of current magnitudes [korres2012state, zhou2006alternative](@cite).

!!! tip "Tip"
    It is important to note that with each individual phasor measurement, we can set the coordinate system, providing flexibility to include some in polar and some in rectangular systems. This flexibility is particularly valuable because bus voltage phasor measurements are preferably included in a polar coordinate system, while current phasor measurements are best suited to a rectangular coordinate system.

---

##### Alternative Formulation
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [aburbook; Sec. 3.2](@cite).

This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example ACSEWLS
updatePmu!(system, device; label = "PMU 2 (Bus 3)", correlated = false)
nothing # hide
```

Subsequently, by specifying the `Orthogonal` argument in the [`gaussNewton`](@ref gaussNewton) function, JuliaGrid implements a more robust approach to obtain the WLS estimator, which proves particularly beneficial when substantial differences exist among measurement variances:
```@example ACSEWLS
analysis = gaussNewton(system, device, Orthogonal)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

---

##### Print Results in the REPL
Users have the option to print the results in the REPL using any units that have been configured, such as:
```@example ACSEWLS
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
    We also provide functions to print or save state estimation results, such as estimated values and residuals. For more details, users can consult the [Power and Current Analysis](@ref ACSEPowerCurrentAnalysisManual) section of this manual.

---

## [Bad Data Processing](@id ACBadDataDetectionManual)
After acquiring the WLS solution using the Gauss-Newton method, users can conduct bad data analysis employing the largest normalized residual test. Continuing with our defined power system and measurement set, let us introduce a new measurement. Upon proceeding to find the solution for this updated state:
```@example ACSEWLS
addWattmeter!(system, device; from = "Branch 2", active = 31.1)

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

Here, we can observe the impact of the outlier on the solution:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Following the solution acquisition, we can verify the presence of erroneous data. Detection of such data is determined by the `threshold` keyword. If the largest normalized residual's value exceeds the threshold, the measurement will be identified as bad data and consequently removed from the AC state estimation model:
```@example ACSEWLS
outlier = residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

Users can examine the data obtained from the bad data analysis:
```@repl ACSEWLS
outlier.detect
outlier.maxNormalizedResidual
outlier.label
```

Hence, upon detecting bad data, the `detect` variable will hold `true`. The `maxNormalizedResidual` variable retains the value of the largest normalized residual, while the `label` contains the label of the measurement identified as bad data. JuliaGrid will mark the respective measurement as out-of-service within the `Measurement` type.

After removing bad data, a new estimate can be computed without considering this specific measurement. The user has the option to either restart the [`gaussNewton`](@ref gaussNewton) function or proceed directly to the iteration loop. However, if the latter option is chosen, using voltages obtained with outlier presence as the initial point could significantly impede algorithm convergence. To avoid this undesirable outcome, the user should first establish a new initial point and commence the iteration procedure. For instance:
```@example ACSEWLS
setInitialPoint!(system, analysis)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

Consequently, we obtain a new solution devoid of the impact of the outlier measurement:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

!!! note "Info"
    We suggest that readers refer to the tutorial on [Bad Data Processing](@ref ACBadDataTutorials) for insights into the implementation.

---

## [Least Absolute Value Estimator](@id PMULAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data processing procedures [aburbook; Ch. 6](@cite). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the `Ipopt` solver proves sufficient to obtain a solution:
```@example ACSEWLS
using Ipopt
using JuMP  # hide

analysis = acLavStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
nothing # hide
```

---

##### Setup Initial Primal Values
In JuliaGrid, the assignment of initial primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function is executed. Initial primal values are determined based on the `voltage` fields within the `ACStateEstimation` type. By default, these values are established using the initial bus voltage magnitudes and angles from `PowerSystem` type:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users have the flexibility to customize these values according to their requirements, and they will be utilized as the initial primal values when executing the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function.

---

##### Solution
To solve the formulated LAV state estimation model, simply execute the following function:
```@example ACSEWLS
solve!(system, analysis)
nothing # hide
```

Upon obtaining the solution, access the bus voltage magnitudes and angles using:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
nothing # hide
```

!!! note "Info"
    We suggest that readers refer to the tutorial on [Least Absolute Value Estimation](@ref ACLAVTutorials) for insights into the implementation.

---

## [Measurement Set Update](@id ACMeasurementsAlterationManual)
After establishing the `Measurement` type using the [`measurement`](@ref measurement) function, users gain the capability to incorporate new measurement devices or update existing ones.

Once updates are completed, users can seamlessly progress towards generating the `ACStateEstimation` type using the [`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation) function. Ultimately, resolving the AC state estimation is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function:
```@example WLSACStateEstimationSolution
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
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

@voltmeter(label = "Voltmeter ? (!)", variance = 1e-3)
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0)

@wattmeter(label = "Wattmeter ? (!)", varianceBus = 1e-2)
addWattmeter!(system, device; from = "Branch 1", active = 1.046)
addWattmeter!(system, device; bus = "Bus 2", active = -0.1)

@varmeter(label = "Varmeter ? (!)", varianceFrom = 1e-3)
addVarmeter!(system, device; from = "Branch 1", reactive = 0.059)
addVarmeter!(system, device; bus = "Bus 2", reactive = -0.01)

@pmu(label = "PMU ? (!)")
addPmu!(system, device; bus = "Bus 2", magnitude = 0.976, angle = -0.052)

analysis = gaussNewton(system, device) # <- Build ACStateEstimation for the defined model
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end

addWattmeter!(system, device; from = "Branch 3", active = 0.924)
updateWattmeter!(system, device; label = "Wattmeter 2 (Bus 2)", variance = 1e-4)

addVarmeter!(system, device; to = "Branch 3", reactive = -0.044, variance = 1e-5)
updateVarmeter!(system, device; label = "Varmeter 2 (Bus 2)", reactive = -0.011)

updatePmu!(system, device; label = "PMU 1 (Bus 2)", polar = false)

analysis = gaussNewton(system, device) # <- Build ACStateEstimation for the updated model
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

!!! note "Info"
    This concept removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id ACStateEstimationUpdateManual)
An advanced methodology involves users establishing the `ACStateEstimation` type using [`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `ACStateEstimation` type.

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `ACStateEstimation` also does not need to be recreated.

!!! tip "Tip"
    The addition of new measurements after the creation of `ACStateEstimation` is not practical in terms of reusing this type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

We can modify the prior example to achieve the same model without establishing `ACStateEstimation` twice:
```@example WLSACStateEstimationSolution
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
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.03)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.3)

@voltmeter(label = "Voltmeter ? (!)", variance = 1e-3)
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0)

@wattmeter(label = "Wattmeter ? (!)", varianceBus = 1e-2)
addWattmeter!(system, device; from = "Branch 1", active = 1.046)
addWattmeter!(system, device; bus = "Bus 2", active = -0.1)
addWattmeter!(system, device; from = "Branch 3", active = 0.924, status = 0)

@varmeter(label = "Varmeter ? (!)", varianceFrom = 1e-3)
addVarmeter!(system, device; from = "Branch 1", reactive = 0.059)
addVarmeter!(system, device; bus = "Bus 2", reactive = -0.01)
addVarmeter!(system, device; to = "Branch 3", reactive = -0.044, variance = 1e-5, status = 0)

@pmu(label = "PMU ? (!)")
addPmu!(system, device; bus = "Bus 2", magnitude = 0.976, angle = -0.052)

analysis = gaussNewton(system, device) # <- Build ACStateEstimation for the defined model
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end

updateWattmeter!(system, device, analysis; label = "Wattmeter 3 (From Branch 3)", status = 1)
updateWattmeter!(system, device, analysis; label = "Wattmeter 2 (Bus 2)", variance = 1e-4)

updateVarmeter!(system, device, analysis; label = "Varmeter 3 (To Branch 3)", status = 1)
updateVarmeter!(system, device, analysis; label = "Varmeter 2 (Bus 2)", reactive = -0.011)

updatePmu!(system, device, analysis; label = "PMU 1 (Bus 2)", polar = false)

# <- No need for re-build; we have already updated the existing ACStateEstimation instance
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

!!! note "Info"
    This concept removes the need to rebuild both the `Measurement` and the `ACStateEstimation` from the beginning when implementing changes to the existing measurement set. In the scenario of employing the WLS model, JuliaGrid can reuse the symbolic factorizations of LU or LDLt, provided that the nonzero pattern of the gain matrix remains unchanged.

---

## [Power and Current Analysis](@id ACSEPowerCurrentAnalysisManual)
After obtaining the solution from the AC state estimation, we can calculate various electrical quantities related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions. For instance, let us consider the model for which we obtained the AC state estimation solution:
```@example WLSACStateEstimationSolution
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

addWattmeter!(system, device; from = "Branch 1", active = 1.046, variance = 1e-2)
addWattmeter!(system, device; bus = "Bus 2", active = -0.1, variance = 1e-3)
addWattmeter!(system, device; from = "Branch 3", active = 0.924, variance = 1e-3)

addVarmeter!(system, device; from = "Branch 1", reactive = 0.059, variance = 1e-3)
addVarmeter!(system, device; bus = "Bus 2", reactive = -0.01, variance = 1e-2)
addVarmeter!(system, device; to = "Branch 3", reactive = -0.044, variance = 1e-3)

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
```

We can now utilize the provided functions to compute powers and currents:
```@example WLSACStateEstimationSolution
power!(system, analysis)
current!(system, analysis)
nothing # hide
```

For instance, if we want to show the active power injections and the from-bus current angles, we can employ the following code:
```@repl WLSACStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.from.angle)
```

!!! note "Info"
    To better understand the powers and currents associated with buses and branches that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [AC State Estimation](@ref ACStateEstimationTutorials).

---

##### Print Results in the REPL
Users can utilize any of the print functions outlined in the [Print API](@ref setupPrintAPI). For example, to print state estimation data related to wattmeters, we can use:
```@example WLSACStateEstimationSolution
@power(MW, pu, pu)
printWattmeterData(system, device, analysis)
@default(unit) # hide
nothing # hide
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

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = shuntPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSACStateEstimationSolution
active, reactive = fromPower(system, analysis; label = "Branch 2")
active, reactive = toPower(system, analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = chargingPower(system, analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl WLSACStateEstimationSolution
active, reactive = seriesPower(system, analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl WLSACStateEstimationSolution
magnitude, angle = injectionCurrent(system, analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the from-bus and to-bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSACStateEstimationSolution
magnitude, angle = fromCurrent(system, analysis; label = "Branch 2")
magnitude, angle = toCurrent(system, analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the from-bus end to the to-bus end, we can use the following function:
```@repl WLSACStateEstimationSolution
magnitude, angle = seriesCurrent(system, analysis; label = "Branch 2")
```