# [Observability Analysis](@id ObservabilityAnalysisManual)
Observability analysis can preceeds to AC state estimation and DC state estimation. The observability analysis determines the existence and uniqueness of the solution. In cases where a unique solution is not guaranteed, it identifies observable islands and prescribes an additional set of measurements to achieve full observability.

Users can perform observability analysis to detect two types of islands, flow and maximal observable islands:
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Measurement)),
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Measurement)).

Once islands are identified, observability can be restored by applying:
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)).

The optimal PMU placement algorithm can also be viewed from the perspective of observability, as it determines the minimal set of PMUs required to make the system observable and guarantee a unique solution in AC and PMU state estimation, regardless of other measurements:
* [`pmuPlacement`](@ref pmuPlacement).

---

## Identification of Observable Islands
The first step in the observability analysis process is to define observable islands. JuliaGrid offers two distinct options for identifying these islands: flow observable islands and maximal observable islands. The choice depends on the power system's structure and available measurements. Identifying only flow observable islands simplifies the island detection process but makes the restoration function more complex.

Let us begin by defining a power system with measurements at specific locations:
```@example ACSEObservabilityAnalysis
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")
addBus!(system; label = "Bus 7")

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.002)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 5", reactance = 0.02)
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", reactance = 0.03)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.05)
addBranch!(system; label = "Branch 6", from = "Bus 3", to = "Bus 5", reactance = 0.05)
addBranch!(system; label = "Branch 7", from = "Bus 6", to = "Bus 7", reactance = 0.05)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")

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

Attempting to solve this system directly using AC or DC state estimation may not be feasible, as the gain matrix would be singular. To prevent this issue, users can first conduct an observability analysis.

JuliaGrid employs standard observability analysis performed on the linear decoupled measurement model. Active power measurements from wattmeters are utilized to estimate bus voltage angles, while reactive power measurements from varmeters are used to estimate bus voltage magnitudes. This necessitates that measurements of active and reactive power come in pairs.

!!! note "Info"
    We suggest that readers refer to the tutorial on [Observability Analysis](@ref ACObservabilityAnalysisTutorials) for insights into the implementation.

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

## Observability Restoration
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

## Optimal PMU Placement
First, we define the power system:
```@example PMUOptimalPlacement
using JuliaGrid # hide
@default(unit) # hide
@default(template) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")

@branch(resistance = 0.02, conductance = 1e-4, susceptance = 0.04)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", reactance = 0.01)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")

nothing # hide
```

---

##### Optimal Solution
Upon defining the `PowerSystem` type, JuliaGrid provides the possibility to determine the minimal number of PMUs required for system observability using the [`pmuPlacement`](@ref pmuPlacement) function:
```@example PMUOptimalPlacement
using GLPK

placement = pmuPlacement(system, GLPK.Optimizer)
nothing # hide
```

The `placement` variable contains data regarding the optimal placement of measurements. In this instance, installing a PMU at `Bus 2` renders the system observable:
```@repl PMUOptimalPlacement
keys(placement.bus)
```

This PMU installed at `Bus 2` will measure the bus voltage phasor at the corresponding bus and all current phasors at the branches incident to `Bus 2` located at the from-bus or to-bus ends:
```@repl PMUOptimalPlacement
keys(placement.from)
keys(placement.to)
```

!!! note "Info"
    We suggest that readers refer to the tutorial on [Optimal PMU Placement](@ref optimalpmu) for insights into the implementation.

----

##### Phasor Measurements
Using the obtained data, phasor measurements can be created to provide a unique state estimator for both AC and PMU state estimation:
```@example PMUOptimalPlacement
device = measurement()

addPmu!(system, device; bus = "Bus 2", magnitude = 1.02, angle = 0.01)
addPmu!(system, device; from = "Branch 3", magnitude = 0.49, angle = 0.07)
addPmu!(system, device; to = "Branch 1", magnitude = 0.47, angle = -0.54)
addPmu!(system, device; to = "Branch 2", magnitude = 1.17, angle = 0.16)
```

!!! note "Info"
    For different approaches to defining measurements after determining the optimal PMU placement, refer to the [PMU State Estimation](@ref PhasorMeasurementsManual) manual.


