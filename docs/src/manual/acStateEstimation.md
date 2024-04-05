# [AC State Estimation](@id ACStateEstimationManual)
To perform nonlinear or AC state estimation, the initial requirement is to have the `PowerSystem` composite type configured with the AC model, along with the `Measurement` composite type storing measurement data. Next, we can develop either the weighted least-squares (WLS) model, utilizing the Gauss-Newton method, or the least absolute value (LAV) model. These models are encapsulated within the `ACStateEstimation` type:
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

Furthermore, there are specialized functions dedicated to calculating specific types of powers related to particular buses and branches:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::AC)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::ACPowerFlow)),
* [`shuntPower`](@ref shuntPower(::PowerSystem, ::AC)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::AC)),
* [`toPower`](@ref toPower(::PowerSystem, ::AC)),
* [`seriesPower`](@ref seriesPower(::PowerSystem, ::AC)),
* [`chargingPower`](@ref chargingPower(::PowerSystem, ::AC)),

Likewise, there are specialized functions dedicated to calculating specific types of currents related to particular buses or branches:
* [`injectionCurrent`](@ref injectionCurrent(::PowerSystem, ::AC)),
* [`fromCurrent`](@ref fromCurrent(::PowerSystem, ::AC)),
* [`toCurrent`](@ref toCurrent(::PowerSystem, ::AC)),
* [`seriesCurrent`](@ref seriesCurrent(::PowerSystem, ::AC)).

---

## [Bus Type Modification](@id ACSEBusTypeModificationManual)
In AC state estimation, it is necessary to designate a slack bus, where the bus voltage angle is known. Therefore, when executing the [`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation) function, the initially assigned slack bus is evaluated and may be altered. If the designated slack bus (`type = 3`) lacks a connected in-service generator, it will be changed to a demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).

---

## [Observability Analysis](@id ACSEObservabilityAnalysisManual)
To initiate the power system with measurements at specific locations, follow the provided example code:
```@example ACSEObservabilityAnalysis
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.1)
addBus!(system; label = "Bus 3", type = 1, active = 0.05)
addBus!(system; label = "Bus 4", type = 1, active = 0.05)
addBus!(system; label = "Bus 5", type = 1, active = 0.05)
addBus!(system; label = "Bus 6", type = 1, active = 0.05)

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 5", reactance = 0.01)
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", reactance = 0.01)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.01)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2, reactive = 0.1)

addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", active = 0.31)
addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", reactive = -0.19)

addWattmeter!(system, device; label = "Wattmeter 2", from = "Branch 3", active = 0.09)
addVarmeter!(system, device; label = "Varmeter 2", from = "Branch 3", reactive = -0.08)

addWattmeter!(system, device; label = "Wattmeter 3", bus = "Bus 3", active = -0.05)
addVarmeter!(system, device; label = "Varmeter 3", bus = "Bus 3", reactive = 0.0)

addWattmeter!(system, device; label = "Wattmeter 4", bus = "Bus 3", active = -0.04)
addVarmeter!(system, device; label = "Varmeter 4", bus = "Bus 3", reactive = 0.0001)

nothing # hide
```

Attempting to solve this system immediately may not be possible because the gain matrix will be singular. To avoid this situation, users can perform observability analysis. JuliaGrid employs standard observability analysis performed on the linear decoupled measurement model. Active power measurements from wattmeters are utilized to estimate bus voltage angles, while reactive power measurements from varmeters are used to estimate bus voltage magnitudes. This necessitates that measurements of active and reactive power come in pairs.

However, the initial step involves defining observable islands. JuliaGrid offers users two options for obtaining observable islands: flow observable islands or maximal observable islands. The selection depends on the power system's structure and available measurements. Identifying only flow observable islands reduces complexity in the island detection function but increases complexity in the restoration function.

---

##### Flow Observable Islands
Now, let us identify flow observable islands:
```@example ACSEObservabilityAnalysis
islands = islandTopologicalFlow(system, device)

nothing # hide
```

As a result, four flow observable islands are identified: `Bus 1` and `Bus 2` form the first island, `Bus 3` and `Bus 5` form the second island, and `Bus 4` and `Bus 6` constitute the third and fourth islands, respectively:
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
It is evident that upon comparing this result with the flow observable islands, the merging of the two injection measurements at `Bus 3` consolidated the first, second, and third flow observable islands into a single island.

---

##### Restore Observability
Before commencing the restoration of observability in the context of the linear decoupled measurement model and observability analysis, it is imperative to ensure that the system possesses one bus voltage magnitude measurement. This necessity arises from the fact that observable islands are identified based on wattmeters, where wattmeters are tasked with estimating voltage angles. Since one voltage angle is already known from the slack bus, the same principle should be applied to bus voltage magnitudes. Therefore, to address this requirement, we add:
```@example ACSEObservabilityAnalysis
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0)

nothing # hide
```

Subsequently, the user needs to establish a set of pseudomeasurements, where measurements must come in pairs as well. Let us create that set:
```@example ACSEObservabilityAnalysis
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudowattmeter 1", bus = "Bus 1", active = 0.31)
addVarmeter!(system, pseudo; label = "Pseudovarmeter 1", bus = "Bus 1", reactive = -0.19)

addWattmeter!(system, pseudo; label = "Pseudowattmeter 2", bus = "Bus 6", active = -0.05)
addVarmeter!(system, pseudo; label = "Pseudovarmeter 2", bus = "Bus 6", reactive = 0.0)

nothing # hide
```

!!! note "Info"
    The labels for specific pseudomeasurements must differ from those defined in the measurements stored in the `device` set. This is necessary because the next step involves adding pseudomeasurements to the `device` set.

Subsequently, the user can execute the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function:
```@example ACSEObservabilityAnalysis
restorationGram!(system, device, pseudo, islands)
nothing # hide
```

This function attempts to restore observability using pseudomeasurements. As a result, the inclusion of measurements from `Pseudowattmeter 2` and `Pseudovarmeter 2` facilitates observability restoration, and these measurements are subsequently added to the `device` variable:
```@repl ACSEObservabilityAnalysis
device.wattmeter.label
device.varmeter.label
nothing # hide
```
Consequently, the power system becomes observable, allowing the user to proceed with forming the AC state estimation model and solving it. Ensuring the observability of the system does not guarantee obtaining accurate estimates of the state variables. Numerical ill-conditioning may adversely impact the state estimation algorithm. However, in most cases, efficient estimation becomes feasible when the system is observable [[1]](@ref ACStateEstimationReferenceManual).

Additionally, it is worth mentioning that restoration might encounter difficulties due to the default zero pivot threshold set at `1e-5`. This threshold can be modified using the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function.

!!! note "Info"
    During the restoration step, if users define bus phasor measurements at any point, these measurements will be considered. Consequently, the system may achieve observability even if multiple islands persist.

---

## [Weighted Least-squares Estimator](@id ACLSStateEstimationSolutionManual)
To begin, we will define the `PowerSystem` and `Measurement` types. Within the measurement set, we choose to utilize measurement values by setting `noise = false`:
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

@wattmeter(label = "Wattmeter ? (!)")
addWattmeter!(system, device; from = "Branch 1", active = 1.046, noise = false)
addWattmeter!(system, device; bus = "Bus 2", active = -0.1, noise = false)

@varmeter(label = "Varmeter ? (!)")
addVarmeter!(system, device; from = "Branch 1", reactive = 0.059, noise = false)
addVarmeter!(system, device; bus = "Bus 2", reactive = -0.01, noise = false)

@ammeter(label = "Ammeter ? (!)")
addAmmeter!(system, device; from = "Branch 3", magnitude = 0.947, noise = false)
addAmmeter!(system, device; to = "Branch 2", magnitude = 1.674, noise = false)

@voltmeter(label = "Voltmeter ? (!)")
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0, noise = false)

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
    analysis = gaussNewton(system, device, QR)
    ```

---

##### Setup Starting Voltages
The initial voltages for the Gauss-Newton method are determined based on the specified initial voltage magnitudes and angles within the buses of the `PowerSystem` type. These values are then forwarded to the `ACStateEstimation` during the execution of the [`gaussNewton`] function. Therefore, the starting voltages in this example are as follows:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

Users have the flexibility to modify these vectors according to their own requirements in order to adjust the starting voltages. For instance, users can conduct an initial AC power flow analysis and utilize the obtained solution as the starting voltages for AC state estimation:
```@example ACSEWLS
powerFlow = newtonRaphson(system)
for iteration = 1:10
    mismatch!(system, powerFlow)
    solve!(system, powerFlow)
end

for i = 1:system.bus.number
    analysis.voltage.magnitude[i] = powerFlow.voltage.magnitude[i]
    analysis.voltage.angle[i] = powerFlow.voltage.angle[i]
end

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
        break
    end
end
nothing # hide
```
The [`solve!`](@ref solve!(::PowerSystem, ::ACStateEstimation{NonlinearWLS{Normal}})) function returns the maximum absolute values of the state variable increment, which are commonly used as a convergence criterion in the iterative Gauss-Newton algorithm.

---

##### Inclusion of PMUs in Polar Coordinates
In the example above, we focus on solving the AC state estimation solely with SCADA measurements. However, users can also incorporate PMUs into the AC state estimation, and several methods exist for achieving this.

The most straightforward approach is to include these measurements in the polar coordinate system. For instance:
```@example ACSEWLS
@pmu(label = "PMU ? (!)")
addPmu!(system, device; from = "Branch 1", magnitude = 1.048, angle = -0.057)

nothing # hide
```
This inclusion of PMUs provides more accurate state estimates compared to rectangular inclusion but demands longer computing time. PMUs are handled in the same manner as SCADA measurements. However, this approach is susceptible to ill-conditioned problems arising in polar coordinates due to small values of current magnitudes [[2, 3]](@ref ACStateEstimationReferenceManual).

---

##### Inclusion of PMUs in Rectangular Coordinates
The second approach to include PMUs is in the rectangular coordinate system, by setting `polar = false`:
```@example ACSEWLS
addPmu!(system, device; to = "Branch 1", magnitude = 1.05, angle = 3.04, polar = false)

nothing # hide
```

!!! note "Info"
    It is important to note that with each individual phasor measurement, we can set the coordinate system, providing flexibility to include some in polar and some in rectangular systems.

In the case of the rectangular system, inclusion resolves ill-conditioned problems arising in polar coordinates due to small values of current magnitudes. However, this approach's main disadvantage is related to measurement errors, as measurement errors correspond to polar coordinates. Therefore, the covariance matrix must be transformed from polar to rectangular coordinates [[4]](@ref ACStateEstimationReferenceManual). As a result, measurement errors of a single PMU are correlated, and the covariance matrix does not have a diagonal form. Despite that, the measurement error covariance matrix is usually considered as a diagonal matrix, affecting the accuracy of the SE.

In the example above, we specifically include PMUs where measurement error correlations are disregarded. This is evident through the precision matrix, which maintains a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(system, device);
analysis.method.precision
```

Lastly, we incorporate correlation into our model by adding new PMUs with the desired error correlation:
```@example ACSEWLS
addPmu!(system, device; bus = "Bus 3", magnitude = 1, angle = 0, polar = false, correlated = true)

nothing # hide
```

Now, we can observe the precision matrix that does not hold a diagonal form:
```@repl ACSEWLS
analysis = gaussNewton(system, device);
analysis.method.precision
```

---

##### Alternative Formulation
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [[5, Sec. 3.2]](@ref ACStateEstimationReferenceManual).

This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example ACSEWLS
updatePmu!(system, device; label = "PMU 3 (Bus 3)", correlated = false)

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

Following the solution acquisition, we can verify the presence of erroneous data. Detection of such data is determined by the `threshold` keyword. If the largest normalized residual's value exceeds the threshold, the measurement will be identified as bad data and consequently removed from the PMU state estimation model:
```@example ACSEWLS
residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

Users can examine the data obtained from the bad data analysis:
```@repl ACSEWLS
analysis.method.outlier.detect
analysis.method.outlier.maxNormalizedResidual
analysis.method.outlier.label
```

Hence, upon detecting bad data, the `detect` variable will hold `true`. The `maxNormalizedResidual` variable retains the value of the largest normalized residual, while the `label` contains the label of the measurement identified as bad data. JuliaGrid will mark the respective measurement as out-of-service within the `Measurement` type.

After removing bad data, a new estimate can be computed without considering this specific measurement. The user has the option to either restart the [`gaussNewton`](@ref gaussNewton) function or proceed directly to the iteration loop. However, if the latter option is chosen, using voltages obtained with outlier presence as the starting point could significantly impede algorithm convergence. To avoid this undesirable outcome, the user should first establish a new starting point and commence the iteration procedure. For instance:
```@example ACSEWLS
for i = 1:system.bus.number
    analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
    analysis.voltage.angle[i] = system.bus.voltage.angle[i]
end

for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
nothing # hide
```

Consequently, we obtain a new solution devoid of the impact of the outlier measurement:
Here, we can observe solutin impact with bad measurments:
```@repl ACSEWLS
print(system.bus.label, analysis.voltage.magnitude, analysis.voltage.angle)
```

---

## [References](@id ACStateEstimationReferenceManual)
[1] G. Korres, *Observability analysis based on echelon form of a reduced dimensional Jacobian matrix*, IEEE Trans. Power Syst., vol. 26, no. 4, pp. 2572–2573, 2011.

[2] G. N. Korres and N. M. Manousakis, *State estimation and observability analysis for phasor measurement unit measured systems*, IET Gener. Transm. Dis., vol. 6, no. 9, 2012.

[3] A. Gomez-Exposito, A. Abur, P. Rousseaux, A. de la Villa Jaen, and C. Gomez-Quiles, *On the use of PMUs in power system state estimation*, Proc. IEEE PSCC, 2011.

[4] M. Zhou, V. A. Centeno, J. S. Thorp, and A. G. Phadke, *An alternative for including phasor measurements in state estimators*, IEEE Trans. Power Syst., vol. 21, no. 4, 2006.

[5] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, Taylor & Francis, 2004.
