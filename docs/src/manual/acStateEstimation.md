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

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
@generator(reactive = 0.1)
@wattmeter(label = "Wattmeter ? (!)")
@varmeter(label = "Varmeter ? (!)")

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

addWattmeter!(system, device; from = "Branch 1", active = 0.31)
addVarmeter!(system, device; from = "Branch 1", reactive = -0.19)

addWattmeter!(system, device; from = "Branch 3", active = 0.09)
addVarmeter!(system, device; from = "Branch 3", reactive = -0.08)

addWattmeter!(system, device; bus = "Bus 3", active = -0.05)
addVarmeter!(system, device; bus = "Bus 3", reactive = 0.0)

addWattmeter!(system, device; bus = "Bus 3", active = -0.04)
addVarmeter!(system, device; bus = "Bus 3", reactive = 0.0001)

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
Consequently, the power system becomes observable, allowing the user to proceed with forming the AC state estimation model and solving it. Ensuring the observability of the system does not guarantee obtaining accurate estimates of the state variables. Numerical ill-conditioning may adversely impact the state estimation algorithm. However, in most cases, efficient estimation becomes feasible when the system is observable. [[1]](@ref DCStateEstimationReferenceManual).

Additionally, it is worth mentioning that restoration might encounter difficulties due to the default zero pivot threshold set at `1e-5`. This threshold can be modified using the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function.

!!! note "Info"
    During the restoration step, if users define bus phasor measurements at any point, these measurements will be considered. Consequently, the system may achieve observability even if multiple islands persist.
