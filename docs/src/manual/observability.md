# [Observability Analysis](@id ObservabilityAnalysisManual)
Prior to applying the AC or DC state estimation algorithm, the observability analysis determines the existence and uniqueness of the solution for the underlying system of equations. Observability analysis is commonly performed on the linear decoupled
measurement model, where active power measurments from wattmeters are used to estimate bus voltage angles, and reactive power measurments from varmeters are used to estimate bus voltage magnitudes. Hence, to perform the observability analysis, we first need to have the `PowerSystem` composite type that has been created with the AC or DC model, alongside the `Measurement` composite type that retains measurement data.

Then, users can initiate observability analysis to identify observable islands and restore observability by employing:
* [`islandTopologicalFlow`](@ref islandTopologicalFlow(::PowerSystem, ::Wattmeter)),
* [`islandTopological`](@ref islandTopological(::PowerSystem, ::Wattmeter)),
* [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)).


---

## [Decoupled Model](@id DecoupledModelManual)
As usual assumption, we observe decoupled model where measurments of active and reactive power comes in pair, this means that observability analysis can be done only using wattmeters, thus let us define this scenario:
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

@varmeter(label = "Varmeter ?: !")
addVarmeter!(system, device; from = "Branch 1", reactive = 0.31, variance = 1e-4)
addVarmeter!(system, device; from = "Branch 3", reactive = 0.09, variance = 1e-4)
addVarmeter!(system, device; bus = "Bus 3", reactive = -0.05, variance = 1e-4)
addVarmeter!(system, device; bus = "Bus 3", reactive = -0.05, variance = 1e-4)

@voltmeter(label = "Varmeter ?: !")
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.0, variance = 1e-4)

nothing # hide
```

Attempting to solve this system immediately may not be possible because the gain matrix will be singular. To avoid this situation, users can perform observability analysis. The first step is to define the observable islands.

JuliaGrid provides users with the option to obtain two types of observable islands: flow observable islands or maximal observable islands. The choice depends on the structure of the power system and available measurements. Detecting just flow observable islands reduces complexity in the island detection function but increases complexity in the restoration function.

!!! tip "Tip"
    In the case of the decaoupled model, where we carry out observability analysis only using wattmeters, we need one voltmeter that measure bus voltage magnitude to ensure that system will be solvable after observability analysis is done.

----

##### Flow Observable Islands
Now, let us identify flow observable islands:
```@example DCSEObservabilityAnalysis
flowIslands = islandTopologicalFlow(system, device.wattmeter)

nothing # hide
```

As a result, four flow observable islands are identified: `Bus 1` and `Bus 2` form the first island, `Bus 3` and `Bus 5` form the second island, and `Bus 4` and `Bus 6` constitute the third and fourth islands, respectively:
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

addVarmeter!(system, pseudo; label = "Pseudo-Varmeter 1", bus = "Bus 1", reactive = 0.31)
addVarmeter!(system, pseudo; label = "Pseudo-Varmeter 2", bus = "Bus 6", reactive = -0.05)
nothing # hide
```

!!! note "Info"
    The labels for specific pseudo-measurements must differ from those defined in the measurements stored in the `device` set. This is necessary because the next step involves adding pseudo-measurements to the `device` set.

Subsequently, the user can execute the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function:
```@example DCSEObservabilityAnalysis
restorationGram!(system, device, pseudo, maxIslands)
nothing # hide
```

This function attempts to restore observability using pseudo-measurements. As a result, the `Pseudo-Wattmeter 2` measurement restores observability, and this measurement is added to the `device` variable:
```@repl DCSEObservabilityAnalysis
device.wattmeter.label
nothing # hide
```
Consequently, the power system becomes observable, allowing the user to proceed with forming the DC state estimation model and solving it. Ensuring the observability of the system does not guarantee obtaining accurate estimates of the state variables. Numerical ill-conditioning may adversely impact the state estimation algorithm. However, in most cases, efficient estimation becomes feasible when the system is observable. [[1]](@ref DCStateEstimationReferenceManual).

Additionally, it is worth mentioning that restoration might encounter difficulties due to the default zero pivot threshold set at `1e-5`. This threshold can be modified using the [`restorationGram!`](@ref restorationGram!(::PowerSystem, ::Measurement, ::Measurement, ::Island)) function.

!!! note "Info"
    During the restoration step, the user can define bus voltage angles from PMUs that will also participate in the restoration step. In this case, the system can become observable even if there are still more islands.

---


## [Observable Islands](@id ObservableIslandsManual)
JuliaGrid provides users with the option to obtain two types of observable islands: flow observable islands or maximal observable islands. The choice depends on the structure of the power system and available measurements. Detecting just flow observable islands reduces complexity in the island detection function but increases complexity in the restoration function.

---

##### Flow Observable Islands
Now, let us identify flow observable islands by passing wattmeters and varmetters to the function whereby the user guarantees that the measurements come in pairs:
```@example DCSEObservabilityAnalysis
flowIslands = islandTopologicalFlow(system, device.wattmeter, device.varmeter)

nothing # hide
```
