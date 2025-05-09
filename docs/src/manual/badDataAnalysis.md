# [Bad Data Analysis](@id BadDataManual)
After computing the weighted least-squares (WLS) estimator, users can perform bad data analysis. There are two tests available: the Chi-squared test for detecting bad data, and the largest normalized residual test, which can be used not only for detection but also for identifying and removing bad data:
* [`chiTest`](@ref chiTest),
* [`residualTest!`](@ref residualTest!).

---

## [Chi-Squared Test](@id ChiTestManual)
The Chi-squared test is the method used to detect the presence of bad data or outliers in the measurement set. If the Chi-squared test indicates the presence of bad data, users can proceed with the largest normalized residual test, which will identify and remove outlier from the measurement set.

!!! note "Info"
    Readers can refer to the [Chi-Squared Test](@ref ChiTestTutorials) tutorial for implementation insights.

To begin, we will define the `PowerSystem` and `Measurement` types:
```@example ACSEWLS
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

@branch(resistance = 0.14, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.25)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.35)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.16)

addWattmeter!(monitoring; label = "Wattmeter 1", from = "Branch 1", active = 0.71)
addWattmeter!(monitoring; label = "Wattmeter 2", bus = "Bus 3", active = -1.50)

addVarmeter!(monitoring; label = "Varmeter 1", from = "Branch 1", reactive = 0.21)
addVarmeter!(monitoring; label = "Varmeter 2", bus = "Bus 3", reactive = -0.20)

addPmu!(monitoring; label = "PMU 1", bus = "Bus 2", magnitude = 0.84, angle = -0.17)
addPmu!(monitoring; label = "PMU 2", bus = "Bus 3", magnitude = 0.85, angle = -0.17)
nothing # hide
```
---

Now, let us create the state estimation model `AcStateEstimation` and compute the WLS estimator:
```@example ACSEWLS
analysis = gaussNewton(monitoring)
stateEstimation!(analysis; verbose = 1)
nothing # hide
```

Next, we aim to detect bad data in the measurement set using the Chi-squared test:
```@example ACSEWLS
chi = chiTest(analysis)
nothing # hide
```

We obtained the detection flag for bad data:
```@repl ACSEWLS
chi.detect
nothing # hide
```

It indicates the presence of outliers in the measurement set. At this point, it is advisable to proceed with the largest normalized residual test. The same test can also be performed for DC state estimation, as well as for state estimation using only PMUs.

---

## [Largest Normalized Residual Test](@id ResidualTestManual)
The largest normalized residual test identifies bad data based on a predefined threshold. Specifically, if the largest normalized residual exceeds the threshold, the corresponding measurement is flagged as bad data, marked as out of service within the `Measurement` type, and removed from the state estimation model. This allows users to solve the state estimation problem immediately without rebuilding the state estimation model.

!!! note "Info"
    Readers can refer to the [Largest Normalized Residual Test](@ref ResidualTestTutorials) tutorial for implementation insights.

After using the Chi-squared test to detect the presence of bad data in the measurement set, let us now identify outliers and remove them:
```@example ACSEWLS
outlier = residualTest!(analysis; threshold = 4.0)
nothing # hide
```

Bad data detection is determined by the `threshold` keyword. If the largest normalized residual value exceeds the `threshold`, the measurement will be identified as bad data and removed from the AC state estimation model. As a result, we have the following information:
```@repl ACSEWLS
outlier.detect
outlier.maxNormalizedResidual
outlier.label
```

Hence, upon detecting bad data, the `detect` variable will be set to `true`. The `maxNormalizedResidual` variable will store the value of the largest normalized residual, and the `label` will contain the label of the measurement identified as bad data. JuliaGrid will mark the corresponding measurement as out-of-service within the `Measurement` type:
```@repl ACSEWLS
print(monitoring.wattmeter.label, monitoring.wattmeter.active.status)
```

Moreover, JuliaGrid resets the non-zero elements to zero in the Jacobian matrix and mean vector within the state estimation type for measurements now designated as out-of-service, effectively removing the impact of the corresponding measurement:
```@repl ACSEWLS
analysis.method.jacobian
analysis.method.mean
```

After removing bad data, a new estimate can be computed without considering the specific measurement, allowing direct continuation to the iteration loop. In this case, the Gauss-Newton method would take the initial point using voltages obtained with outlier presence, which could significantly impede algorithm convergence. To avoid this undesirable outcome, the user should first establish a new initial point and then commence the iteration procedure:
```@example ACSEWLS
setInitialPoint!(analysis)
stateEstimation!(analysis; verbose = 1)
nothing # hide
```

---

##### PMU State Estimation
In general, the procedures for AC state estimation also apply to PMU state estimation. Let us highlight some specific aspects of this estimation type. First, new phasor measurements are added to the system, and the WLS estimator is obtained using PMU data only:
```@example ACSEWLS
addPmu!(monitoring; label = "PMU 3", from = "Branch 1", magnitude = 0.73, angle = 0.35)
addPmu!(monitoring; label = "PMU 4", bus = "Bus 1", magnitude = 1.0, angle = 0.01)

analysis = pmuStateEstimation(monitoring)
stateEstimation!(analysis)
nothing # hide
```

Next, perform bad data analysis:
```@example ACSEWLS
outlier = residualTest!(analysis; threshold = 4.0)
nothing # hide
```

Users can examine the results of the bad data analysis:
```@repl ACSEWLS
outlier.detect
outlier.label
```

As before, the identified measurement is set out-of-service within the `Measurement` type. This corresponds to resetting non-zero elements to zero in the coefficient matrix and mean vector, effectively removing its impact:
```@repl ACSEWLS
analysis.method.mean
analysis.method.coefficient
```

This allows the WLS estimator to be recomputed without the influence of the outlier phasor measurement:
```@example ACSEWLS
stateEstimation!(analysis)
nothing # hide
```

---

##### DC State Estimation
For DC state estimation, users can follow the same steps as previously described. To illustrate, let us restore `Wattmeter 2` and perform bad data analysis:
```@example ACSEWLS
updateWattmeter!(monitoring; label = "Wattmeter 2", status = 1)

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)

outlier = residualTest!(analysis; threshold = 2.0)
nothing # hide
```

Detecting bad data:
```@repl ACSEWLS
outlier.detect
outlier.label
```

As before, the state estimation model is updated, enabling the user to recompute the WLS estimator:
```@repl ACSEWLS
analysis.method.mean
analysis.method.coefficient

stateEstimation!(analysis)
nothing # hide
```