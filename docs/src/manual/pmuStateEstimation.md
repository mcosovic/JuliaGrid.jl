# [PMU State Estimation](@id PMUStateEstimationManual)
To perform linear state estimation solely based on PMU data, the initial requirement is to have the `PowerSystem` composite type configured with the AC model, along with the `Measurement` composite type storing measurement data. Subsequently, we can formulate either the weighted least-squares (WLS) or the least absolute value (LAV) PMU state estimation model encapsulated within the abstract type `PMUStateEstimation` using:
* [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation),
* [`pmuLavStateEstimation`](@ref pmuLavStateEstimation),

For resolving the PMU state estimation problem and obtaining bus voltage magnitudes and angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})).

After executing the function [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})), where the user employs the WLS method, the user has the ability to check if the measurement set contains outliers throughout bad data analysis and remove those measurements using:
* [`residualTest!`](@ref residualTest!).

Moreover, before the creating `PMUStateEstimation` type, users can initiate an optimal PMU placement algorithm to determine the minimal set of PMUs required for an observable system: 
* [`pmuPlacement`](@ref pmuPlacement).

---

After obtaining the PMU state estimation solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses and branches:
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

## [Optimal PMU Placement](@id OptimalPMUPlacementManual)
Let us define the `PowerSystem` composite type and perform the AC power flow analysis solely for generating data to artificially create measurement values:
```@example PMUOptimalPlacement
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide
@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
@generator(reactive = 0.1)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, active = 0.5)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 2.1)
acModel!(system)

analysis = newtonRaphson(system)
for iteration = 1:10
    mismatch!(system, analysis)
    solve!(system, analysis)
end

nothing # hide
```

---

##### Optimal Solution
Upon defining the `PowerSystem` composite type, JuliaGrid provides the possibility to determine the minimal number of PMUs required for system observability using the [`pmuPlacement`](@ref pmuPlacement) function:
```@example PMUOptimalPlacement
using GLPK

placement = pmuPlacement(system, GLPK.Optimizer)

nothing # hide
```

The `placement` variable contains data regarding the optimal placement of measurements. In this instance, installing a PMU at `Bus 2` renders the system observable:  
```@repl PMUOptimalPlacement
placement.bus
```

This PMU installed at `Bus 2` will measure the bus voltage phasor at the corresponding bus and all current phasors at the branches incident to `Bus 2` located at the "from" or "to" bus ends:
```@repl PMUOptimalPlacement
placement.from
placement.to
```

---

##### Measurement Data
Utilizing PMU placement and AC power flow data, which serves as the source for measurement values in this scenario, we can construct the `Measurement` composite type as follows:
```@example PMUOptimalPlacement
device = measurement()

@pmu(label = "PMU ? (!)")
for (bus, k) in placement.bus
    Vᵢ, θᵢ = analysis.voltage.magnitude[k], analysis.voltage.angle[k]
    addPmu!(system, device; bus = bus, magnitude = Vᵢ, angle = θᵢ, noise = false)
end
for branch in keys(placement.from)
    Iᵢⱼ, ψᵢⱼ = fromCurrent(system, analysis; label = branch)
    addPmu!(system, device; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ, noise = false)
end
for branch in keys(placement.to)
    Iⱼᵢ, ψⱼᵢ = toCurrent(system, analysis; label = branch)    
    addPmu!(system, device; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ, noise = false) 
end

nothing # hide
```

For example, we can observe the obtained set of measurement values:
```@repl PMUOptimalPlacement
print(device.pmu.label, device.pmu.magnitude.mean)
print(device.pmu.label, device.pmu.angle.mean)
```

---


## [Weighted Least-squares Estimator](@id PMUWLSStateEstimationSolutionManual)
Let us continue with the previous example, where we defined the `PowerSystem` and `Measurement` types. To establish the PMU state estimation model, we will use the [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation) function: 
```@example PMUOptimalPlacement
analysis = pmuWlsStateEstimation(system, device)
nothing # hide
```

!!! tip "Tip"
    Here, the user triggers LU factorization as the default method for solving the PMU state estimation problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`:
    ```julia PMUOptimalPlacement
    analysis = pmuWlsStateEstimation(system, device, QR)
    ```  

To obtain the bus voltage magnitudes and angles, the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})) function can be invoked as shown:
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
addPmu!(system, device; bus = "Bus 1", magnitude = 1, angle = 0, correlated = true)

nothing # hide
```

Following this, we recreate the WLS state estimation model:
```@example PMUOptimalPlacement
analysis = pmuWlsStateEstimation(system, device)
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
The resolution of the WLS state estimation problem using the conventional method typically progresses smoothly. However, it is widely acknowledged that in certain situations common to real-world systems, this method can be vulnerable to numerical instabilities. Such conditions might impede the algorithm from finding a satisfactory solution. In such cases, users may opt for an alternative formulation of the WLS state estimation, namely, employing an approach called orthogonal factorization [[1, Sec. 3.2]](@ref PMUStateEstimationReferenceManual).

This approach is suitable when measurement errors are uncorrelated, and the precision matrix remains diagonal. Therefore, as a preliminary step, we need to eliminate the correlation, as we did previously:
```@example PMUOptimalPlacement
updatePmu!(system, device; label = "PMU 5 (Bus 1)", correlated = false)

nothing # hide
```

Subsequently, by specifying the `Orthogonal` argument in the [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation) function, JuliaGrid implements a more robust approach to obtain the WLS estimator, which proves particularly beneficial when substantial differences exist among measurement variances:
```@example PMUOptimalPlacement
analysis = pmuWlsStateEstimation(system, device, Orthogonal)
solve!(system, analysis)
nothing # hide
```

---

## [Bad Data Processing](@id PMUBadDataDetectionManual)
After acquiring the WLS solution using the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})) function, users can conduct bad data analysis employing the largest normalized residual test. Continuing with our defined power system and measurement set, let us introduce a new phasor measurement. Upon proceeding to find the solution for this updated state:
```@example PMUOptimalPlacement
addPmu!(system, device; bus = "Bus 3", magnitude = 3.2, angle = 0.0, noise = false)

analysis = pmuWlsStateEstimation(system, device)
solve!(system, analysis)
nothing # hide
```

Following the solution acquisition, we can verify the presence of erroneous data. Detection of such data is determined by the `threshold` keyword. If the largest normalized residual's value exceeds the threshold, the measurement will be identified as bad data and consequently removed from the PMU state estimation model:
```@example PMUOptimalPlacement
residualTest!(system, device, analysis; threshold = 4.0)
nothing # hide
```

Users can examine the data obtained from the bad data analysis:
```@repl PMUOptimalPlacement
analysis.outlier.detect
analysis.outlier.maxNormalizedResidual
analysis.outlier.label
```

Hence, upon detecting bad data, the `detect` variable will hold `true`. The `maxNormalizedResidual` variable retains the value of the largest normalized residual, while the `label` contains the label of the measurement identified as bad data. JuliaGrid will mark the respective phasor measurement as out-of-service within the `Measurement` type.

Moreover, JuliaGrid will adjust the coefficient matrix and mean vector within the `PMUStateEstimation` type based on measurements now designated as out-of-service. To optimize the algorithm's efficiency, JuliaGrid resets non-zero elements to zero in the coefficient matrix and mean vector:
```@repl PMUOptimalPlacement
analysis.method.mean
analysis.method.coefficient
```

After removing bad data, a new estimate can be computed without considering this specific phasor measurement:
```@example PMUOptimalPlacement
solve!(system, analysis)
nothing # hide
```

---

## [Least Absolute Value Estimator](@id PMULAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data processing procedures [[1, Ch. 6]](@ref PMUStateEstimationReferenceManual). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example PMUOptimalPlacement
using Ipopt
using JuMP  # hide

analysis = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
nothing # hide
```

---

##### Setup Starting Primal Values
In JuliaGrid, the assignment of starting primal values for optimization variables takes place when the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})) function is executed. Starting primal values are determined based on the `voltage` fields within the `PMUStateEstimation` type. By default, these values are initially established using the the initial bus voltage magnitudes and angles from `PowerSystem` type:
```@repl PMUOptimalPlacement
print(system.bus.label, analysis.voltage.magnitude)
print(system.bus.label, analysis.voltage.angle)
```

Users have the flexibility to customize these values according to their requirements, and they will be utilized as the starting primal values when executing the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS{LinearWLS})) function. It is important to note that JuliaGrid utilizes the provided data to set starting primal values in the rectangular coordinate system.

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

---

## [Measurement Set Update](@id PMUMeasurementsAlterationManual)
After establishing the `Measurement` composite type using the [`measurement`](@ref measurement) function, users gain the capability to incorporate new measurement devices or update existing ones. 

Once updates are completed, users can seamlessly progress towards generating the `PMUStateEstimation` type using the [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation) or [`pmuLavStateEstimation`](@ref pmuLavStateEstimation) function. Ultimately, resolving the PMU state estimation is achieved through the utilization of the [`solve!`](@ref solve!(::PowerSystem, ::PMUStateEstimationWLS{LinearWLS})) function:
```@example WLSPMUStateEstimationSolution
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, active = 0.5)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.04)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
acModel!(system)

device = measurement()
@pmu(label = "PMU ?")
addPmu!(system, device; bus = "Bus 1", magnitude = 1.0, angle = 0.0, noise = false)
addPmu!(system, device; bus = "Bus 2", magnitude = 0.98, angle = -0.023)
addPmu!(system, device; from = "Branch 2", magnitude = 0.5, angle = -0.05)

analysis = pmuWlsStateEstimation(system, device)
solve!(system, analysis)

addPmu!(system, device; to = "Branch 2", magnitude = 0.5, angle = 3.1)
updatePmu!(system, device; label = "PMU 1", varianceMagnitude = 1e-8, varianceAngle = 1e-8)
updatePmu!(system, device; label = "PMU 3", statusMagnitude = 0, statusAngle = 0)

analysis = pmuWlsStateEstimation(system, device)
solve!(system, analysis)

nothing # hide
```

!!! note "Info"
    This method removes the need to restart and recreate the `Measurement` type from the beginning when implementing changes to the existing measurement set.

---

## [State Estimation Update](@id PMUStateEstimationUpdateManual)
An advanced methodology involves users establishing the `PMUStateEstimation` composite type using [`pmuWlsStateEstimation`](@ref pmuWlsStateEstimation) or [`pmuLavStateEstimation`](@ref pmuLavStateEstimation) just once. After this initial setup, users can seamlessly modify existing measurement devices without the need to recreate the `PMUStateEstimation` type. 

This advancement extends beyond the previous scenario where recreating the `Measurement` type was unnecessary, to now include the scenario where `PMUStateEstimation` also does not need to be recreated. 

The addition of new measurements after the creation of `PMUStateEstimation` is not practical in terms of reusing the `PMUStateEstimation` type. Instead, we recommend that users create a final set of measurements and then utilize update functions to manage devices, either putting them in-service or out-of-service throughout the process.

!!! note "Info"
    This method removes the need to restart and recreate both the `Measurement` and the `PMUStateEstimation` from the beginning when implementing changes to the existing measurement set. Next, JuliaGrid can reuse symbolic factorizations of LU or LDLt, as long as the nonzero pattern of the gain matrix remains consistent.

---

Continious previus example, we demonstrated the approche where we reuse `PMUStateEstimation` type:
```@example WLSPMUStateEstimationSolution
updatePmu!(system, device, analysis; label = "PMU 2", magnitude = 0.99, angle = 3.05)
updatePmu!(system, device, analysis; label = "PMU 3", statusMagnitude = 1, statusAngle = 1)

solve!(system, analysis)

nothing # hide
```

--- 

##### Least Absolute Value Estimator
When a user creates an optimization problem using the LAV method, they can update measurement devices without the need to recreate the model from scratch, similar to the explanation provided for the WLS state estimation. This streamlined process allows for efficient modifications while retaining the existing optimization framework:
```@example WLSPMUStateEstimationSolution
using Ipopt
using JuliaGrid # hide
using JuMP # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
addBus!(system; label = "Bus 1", type = 3, active = 0.5)
addBus!(system; label = "Bus 2", type = 1, reactive = 0.05)
addBus!(system; label = "Bus 3", type = 1, active = 0.5)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.04)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 3.2)
acModel!(system)

device = measurement()
@pmu(label = "PMU ?")
addPmu!(system, device; bus = "Bus 1", magnitude = 1.0, angle = 0.0, noise = false)
addPmu!(system, device; bus = "Bus 2", magnitude = 0.98, angle = -0.023)
addPmu!(system, device; from = "Branch 2", magnitude = 0.5, angle = -0.05)

analysis = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump) # hide
solve!(system, analysis)

updatePmu!(system, device, analysis; label = "PMU 2", magnitude = 0.99, angle = 3.05)
updatePmu!(system, device, analysis; label = "PMU 3", statusMagnitude = 1, statusAngle = 1)

solve!(system, analysis)

nothing # hide
```

---

## [Power and Current Analysis](@id PMUSEPowerCurrentAnalysisManual)
After obtaining the solution from the PMU state estimation, we can calculate various electrical quantities related to buses and branches using the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions. For instance, To illustrate this with a continuation of our previous example, we can compute powers and currents using the following functions:
```@example WLSPMUStateEstimationSolution
power!(system, analysis)
current!(system, analysis)
nothing # hide
```

For instance, if we want to show the active power injections at each bus and the current flow angles at each "to" bus end of the branch, we can employ the following code:
```@repl WLSPMUStateEstimationSolution
print(system.bus.label, analysis.power.injection.active)
print(system.branch.label, analysis.current.to.angle)
```

!!! note "Info"
    To better understand the powers and currents associated with buses and generators that are calculated by the [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)) and [`current!`](@ref current!(::PowerSystem, ::AC)) functions, we suggest referring to the tutorials on [PMU State Estimation].

To compute specific quantities for particular components, rather than calculating powers or currents for all components, users can utilize one of the provided functions below.

---

##### Active and Reactive Power Injection
To calculate the active and reactive power injection associated with a specific bus, the function can be used:
```@repl WLSPMUStateEstimationSolution
active, reactive = injectionPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power Injection from Generators
To calculate the active and reactive power injection from the generators at a specific bus, the function can be used:
```@repl WLSPMUStateEstimationSolution
active, reactive = supplyPower(system, analysis; label = "Bus 1")
```

---

##### Active and Reactive Power at Shunt Element
To calculate the active and reactive power associated with shunt element at a specific bus, the function can be used:
```@repl WLSPMUStateEstimationSolution
active, reactive = shuntPower(system, analysis; label = "Bus 3")
```

---

##### Active and Reactive Power Flow
Similarly, we can compute the active and reactive power flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSPMUStateEstimationSolution
active, reactive = fromPower(system, analysis; label = "Branch 2")
active, reactive = toPower(system, analysis; label = "Branch 2")
```

---

##### Active and Reactive Power at Charging Admittances
To calculate the active and reactive power linked with branch charging admittances of the particular branch, the function can be used:
```@repl WLSPMUStateEstimationSolution
active, reactive = chargingPower(system, analysis; label = "Branch 1")
```

Active powers indicate active losses within the branch's charging admittances. Moreover, charging admittances injected reactive powers into the power system due to their capacitive nature, as denoted by a negative sign.

---

##### Active and Reactive Power at Series Impedance
To calculate the active and reactive power across the series impedance of the branch, the function can be used:
```@repl WLSPMUStateEstimationSolution
active, reactive = seriesPower(system, analysis; label = "Branch 2")
```

The active power also considers active losses originating from the series resistance of the branch, while the reactive power represents reactive losses resulting from the impedance's inductive characteristics.

---

##### Current Injection
To calculate the current injection associated with a specific bus, the function can be used:
```@repl WLSPMUStateEstimationSolution
magnitude, angle = injectionCurrent(system, analysis; label = "Bus 1")
```

---

##### Current Flow
We can compute the current flow at both the "from" and "to" bus ends of the specific branch by utilizing the provided functions below:
```@repl WLSPMUStateEstimationSolution
magnitude, angle = fromCurrent(system, analysis; label = "Branch 2")
magnitude, angle = toCurrent(system, analysis; label = "Branch 2")
```

---

##### Current Through Series Impedance
To calculate the current passing through the series impedance of the branch in the direction from the "from" bus end to the "to" bus end, we can use the following function:
```@repl WLSPMUStateEstimationSolution
magnitude, angle = seriesCurrent(system, analysis; label = "Branch 2")
```

---

## [References](@id PMUStateEstimationReferenceManual)
[1] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, Taylor & Francis, 2004.




