# [DC State Estimation](@id DCStateEstimationManual)
To perform the DC power flow, you first need to have the `PowerSystem` composite type that has been created with the `dc` model, alongside the `Measurement` composite type that retains measurement data. Subsequently, we can formulate the DC state estimation model encapsulated within the abstract type `DCStateEstimation` using the subsequent function:
* [`dcStateEstimation`](@ref dcStateEstimation).

For resolving the DC state estimation problem employing either the weighted least-squares (WLS) or the least absolute value (LAV) approach and obtaining bus voltage angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS)).

After obtaining the solution for DC state estimation, JuliaGrid offers a post-processing analysis function to compute active powers associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::DCStateEstimation)).

Additionally, there are specialized functions dedicated to calculating specific types of active powers related to particular buses or branches:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::DCStateEstimation)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::DCStateEstimation)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::DCStateEstimation)),
* [`toPower`](@ref toPower(::PowerSystem, ::DCStateEstimation)),

---

## [Bus Type Modification](@id DCSEBusTypeModificationManual)
Similar to the explanation provided in the [Bus Type Modification](@ref DCBusTypeModificationManual) section, when executing the [`dcStateEstimation`](@ref dcStateEstimation) function, the initially designated slack bus undergoes evaluation and may be adjusted. If the bus designated as the slack bus (`type = 3`) lacks a connected in-service generator, its type will be changed to the demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).

---

## [WLS State Estimation Solution](@id WLSStateEstimationSolutionManual)
To solve the DC state estimation and derive weighted least-squares (WLS) estimates using JuliaGrid, the process initiates by defining the composite types `PowerSystem` and `Measurement`. Here is an illustrative example:
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
    Here, the user triggers LU factorization as the default method for solving the DC state estimation problem. However, the user also has the option to select alternative factorization methods such as `LDLt` or `QR`, for instance.

To obtain the bus voltage angles, the [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS)) function can be invoked as shown:
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
    We recommend that readers refer to the tutorial on [DC State Estimation] for insights into the implementation.

---

##### Orthogonal Factorization
When users opt for orthogonal factorization, specifying the `QR` argument in the [`dcStateEstimation`](@ref dcStateEstimation) function, they are not solely choosing to solve the WLS problem using QR factorization. Instead, JuliaGrid implements a more robust approach to obtain the WLS estimator, especially beneficial when significant differences exist among measurement variances [[1, Sec. 3.2]](@ref DCStateEstimationReferenceManual). To derive this estimator, execute the following sequence of functions:
```@example WLSDCStateEstimationSolution
analysis = dcStateEstimation(system, device, QR)
solve!(system, analysis)
nothing # hide
```

---

## [LAV State Estimation Solution](@id LAVtateEstimationSolutionManual)
The LAV method presents an alternative estimation technique known for its increased robustness compared to WLS. While the WLS method relies on specific assumptions regarding measurement errors, robust estimators like LAV are designed to maintain unbiasedness even in the presence of various types of measurement errors and outliers. This characteristic often eliminates the need for extensive bad data processing procedures [[1, Ch. 6]](@ref DCStateEstimationReferenceManual). However, it is important to note that achieving robustness typically involves increased computational complexity.

To obtain an LAV estimator, users need to employ one of the [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) listed in the JuMP documentation. In many common scenarios, the Ipopt solver proves sufficient to obtain a solution:
```@example WLSDCStateEstimationSolution
using Ipopt

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
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
active = fromPower(system, analysis; label = "Branch 2")
active = toPower(system, analysis; label = "Branch 2")
```

---

## [References](@id DCStateEstimationReferenceManual)
[1] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, ser. Power Engineering. Taylor & Francis, 2004.






