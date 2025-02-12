# [Observability Analysis](@id ObservabilityAnalysisExamples)
In this example, we analyze a 6-bus power system, shown in Figure 1, monitored by four power meters. The objective is to perform an observability analysis to identify observable islands and restore observability.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/obs6bus.svg" width="400"/>
    <p>Figure 1: The 6-bus power system monitoring with four power meters.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/observability.jl).

First, we define the power system model by specifying buses and branches:
```@example 6bus
using JuliaGrid # hide
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")

@branch(reactance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 4")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4")
addBranch!(system; label = "Branch 5", from = "Bus 3", to = "Bus 5")
addBranch!(system; label = "Branch 6", from = "Bus 4", to = "Bus 6")

nothing # hide
```

Next, we define the measurement model. JuliaGrid employs standard observability analysis based on the linear decoupled measurement model. Active power measurements from wattmeters are used to estimate bus voltage angles, while reactive power measurements from varmeters estimate bus voltage magnitudes. Thus, each of the four meters in Figure 1 represents both a wattmeter and a varmeter. Notably, the island detection step relies only on wattmeters, meaning that if the goal is simply to identify observable islands, defining wattmeters alone is sufficient. However, for observability restoration followed by state estimation, varmeters are also needed. Therefore, in this example, we define both wattmeters and varmeters in pairs:
```@example 6bus
device = measurement()

addWattmeter!(system, device; label = "Meter 1: Acative", from = "Branch 1", active = 1.1)
addVarmeter!(system, device; label = "Meter 1: Reactive", from = "Branch 1", reactive = -0.5)

addWattmeter!(system, device; label = "Meter 2: Acative", bus = "Bus 2", active = -0.1)
addVarmeter!(system, device; label = "Meter 2: Reactive", bus = "Bus 2", reactive = -0.1)

addWattmeter!(system, device; label = "Meter 3: Acative", bus = "Bus 4", active = -0.3)
addVarmeter!(system, device; label = "Meter 3: Reactive", bus = "Bus 4", reactive = 0.6)

addWattmeter!(system, device; label = "Meter 4: Acative", to = "Branch 6", active = 0.2)
addVarmeter!(system, device; label = "Meter 4: Reactive", to = "Branch 6", reactive = -0.2)

nothing # hide
```

---

## Identification of Observable Islands
With JuliaGrid, we have the ability to identify both flow observable and maximal observable islands, each of which can be used as the foundation for the restoration step. To provide a comprehensive analysis, we will explore both types of islands. In the first step, we focus on determining the flow observable islands:
```@example 6bus
islands = islandTopologicalFlow(system, device)
nothing # hide
```

As a result, four flow observable islands are identified: `Bus 1` and `Bus 2` form the first island, `Bus 3` forms the second island, `Bus 4` and `Bus 6` constitute the third island, while `Bus 5` forms the fourth island:
```@repl 6bus
islands.island
nothing # hide
```

This is illustrated in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/obs6bus_flow.svg" width="430"/>
    <p>Figure 2: Flow observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

In addition to flow islands, we can also identify maximal observable islands:
```@example 6bus
islands = islandTopological(system, device)
nothing # hide
```

The results reveal the identification of two maximal observable islands:
```@repl 6bus
islands.island
nothing # hide
```

As observed, the devices `Meter 2` and `Meter 3` together merge the first, second, and third flow observable islands into one, as shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/obs6bus_maximal.svg" width="430"/>
    <p>Figure 3: Maximal observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

From the standpoint of island identification, detecting power flow islands requires less computational effort compared to identifying maximal observable islands. However, when it comes to restoring observability, the process involving power flow islands tends to be more computationally demanding than with maximal observable islands.

---

## Observability Restoration
To perform the observability restoration step, a new set of measurements, called pseudo-measurements, is needed. These typically hold historical data about electrical quantities. Let us define this set:
```@example 6bus
pseudo = measurement()

addWattmeter!(system, pseudo; label = "Pseudo 1: Active", from = "Branch 4", active = 0.3)
addVarmeter!(system, pseudo; label = "Pseudo 1: Reactive", from = "Branch 4", reactive = 0.1)

addWattmeter!(system, pseudo; label = "Pseudo 2: Active", bus = "Bus 5", active = 0.3)
addVarmeter!(system, pseudo; label = "Pseudo 2: Reactive", bus = "Bus 5", reactive = -0.2)
nothing # hide
```

Next, we can invoke the observability restoration function:
```@example 6bus
restorationGram!(system, device, pseudo, islands)
nothing # hide
```

This function will identify a minimal set of pseudo-measurements required to make the system observable and transfer them to the measurement model:
```@repl 6bus
device.wattmeter.label
device.varmeter.label
```

As we can see, adding the `Pseudo 2` measurement makes the system observable, which we can confirm by identifying observable islands with only one island:
```@example 6bus
islands = islandTopological(system, device)
nothing # hide
```
```@repl 6bus
islands.island
nothing # hide
```

To proceed with the nonlinear state estimation algorithm, we need one additional step to make the state estimation solvable. Specifically, it is crucial to ensure that the system has at least one bus voltage magnitude measurement. This requirement stems from the fact that observable islands are identified using wattmeters, which estimate voltage angles. Since the voltage angle at the slack bus is already known, the same approach should be applied to bus voltage magnitudes. To fulfill this condition, we add the following measurement:
```@example 6bus
addVoltmeter!(system, device; label = "Pseudo 3", bus = "Bus 1", magnitude = 1.0)
nothing # hide
```

Finally, Figure 4 illustrates the measurement configuration that makes our 6-bus power system observable and ensures a unique state estimator.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/obs6bus_psudo.svg" width="430"/>
    <p>Figure 4: Measurement configuration that makes the 6-bus power system observable.</p>
</div>
```



