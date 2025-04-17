# [Observability Analysis](@id ObservabilityAnalysisExamples)
In this example, we analyze a 6-bus power system, shown in Figure 1. The initial objective is to conduct an observability analysis to identify observable islands and restore observability. Later, we examine optimal PMU placement to ensure system observability using only phasor measurements.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus.svg" width="410" class="my-svg"/>
    <p>Figure 1: The 6-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/observability.jl).

We define the power system, specify buses and branches, and assign the generator to the slack bus:
```@example 6bus
using JuliaGrid, HiGHS # hide
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")

@branch(reactance = 0.22)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 4")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 5")
addBranch!(system; label = "Branch 5", from = "Bus 3", to = "Bus 4")
addBranch!(system; label = "Branch 6", from = "Bus 4", to = "Bus 6")
nothing # hide
```

Notably, observability analysis and optimal PMU placement are independent of branch parameters, as well as measurement values and variances.

---

## Identification of Observable Islands
Next, we define the measurement model. JuliaGrid employs standard observability analysis based on the linear decoupled measurement model. Active power measurements from wattmeters are used to estimate bus voltage angles, while reactive power measurements from varmeters estimate bus voltage magnitudes. In this example, the 6-bus power system is monitored by four meters, as shown in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_meter.svg" width="420" class="my-svg"/>
    <p>Figure 2: The 6-bus power system monitoring with four power meters.</p>
</div>
&nbsp;
```

Notably, the island detection step relies only on wattmeters, meaning that if the goal is simply to identify observable islands, defining wattmeters alone is sufficient. However, for observability restoration followed by state estimation, varmeters are also needed. Therefore, the four meters represent both wattmeters and varmeters:
```@example 6bus
monitoring = measurement(system)

addWattmeter!(monitoring; label = "Meter 1", from = "Branch 1", active = 1.1)
addVarmeter!(monitoring; label = "Meter 1", from = "Branch 1", reactive = -0.5)

addWattmeter!(monitoring; label = "Meter 2", bus = "Bus 2", active = -0.1)
addVarmeter!(monitoring; label = "Meter 2", bus = "Bus 2", reactive = -0.1)

addWattmeter!(monitoring; label = "Meter 3", bus = "Bus 4", active = -0.3)
addVarmeter!(monitoring; label = "Meter 3", bus = "Bus 4", reactive = 0.6)

addWattmeter!(monitoring; label = "Meter 4", to = "Branch 6", active = 0.2)
addVarmeter!(monitoring; label = "Meter 4", to = "Branch 6", reactive = 0.3)
nothing # hide
```

Attempting to solve AC state estimation with these measurements would not be possible, as the gain matrix would be singular. The same issue arises with DC state estimation. To prevent this, users can perform observability analysis, which adds non-redundant measurements to ensure a nonsingular gain matrix and a unique state estimator.

Observability analysis begins with identifying observable islands. We have the ability to identify both flow-observable and maximal-observable islands, each of which can be used as the foundation for the restoration step. To provide a comprehensive analysis, we will explore both types of islands.

In the first step, we focus on determining the flow-observable islands:
```@example 6bus
islands = islandTopologicalFlow(monitoring)
nothing # hide
```

As the result, four flow-observable islands are identified:
```@repl 6bus
islands.island
nothing # hide
```

The first observable island consists of `Bus 1` and `Bus 2`, the second island is formed by `Bus 3`, the third island includes `Bus 4` and `Bus 6`, while `Bus 5` constitutes the fourth island, as shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_flow.svg" width="430" class="my-svg"/>
    <p>Figure 3: Flow-observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

In addition to flow islands, we can also identify maximal-observable islands:
```@example 6bus
islands = islandTopological(monitoring)
nothing # hide
```

The results reveal the identification of two-maximal observable islands:
```@repl 6bus
islands.island
nothing # hide
```

As observed, the monitorings `Meter 2` and `Meter 3` together merge the first, second, and third flow-observable islands into one, as shown in Figure 4.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_maximal.svg" width="430" class="my-svg"/>
    <p>Figure 4: Maximal-observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

From the standpoint of island identification, detecting flow-observable islands requires less computational effort compared to identifying maximal-observable islands. However, when it comes to restoring observability, the process involving flow islands tends to be more computationally demanding than with maximal islands.

---

## Observability Restoration
To perform the observability restoration step, a new set of measurements, called pseudo-measurements, is needed. These typically hold historical data about electrical quantities. Let us define this set:
```@example 6bus
pseudo = measurement(system)

addWattmeter!(pseudo; label = "Pseudo 1", from = "Branch 5", active = 0.3)
addVarmeter!(pseudo; label = "Pseudo 1", from = "Branch 5", reactive = 0.1)

addWattmeter!(pseudo; label = "Pseudo 2", bus = "Bus 5", active = 0.3)
addVarmeter!(pseudo; label = "Pseudo 2", bus = "Bus 5", reactive = -0.2)
nothing # hide
```

Next, we can invoke the observability restoration function:
```@example 6bus
restorationGram!(monitoring, pseudo, islands)
nothing # hide
```
This function identifies the minimal set of pseudo-measurements needed to make the system observable, which in this case is `Pseudo 2`. This pseudo-measurement is then transferred to the measurement model.

As a result, the final set of wattmeters used for measuring active power consists of:
```@example 6bus
printWattmeterData(monitoring)
```

Likewise, the final set of varmeters used for measuring reactive power consists of:
```@example 6bus
printVarmeterData(monitoring)
```

As we can see, adding the `Pseudo 2` measurement makes the system observable, which we can confirm by identifying observable islands with only one island:
```@example 6bus
islands = islandTopological(monitoring)
nothing # hide
```

```@repl 6bus
islands.island
nothing # hide
```

To proceed with the AC state estimation algorithm, we need one additional step to make the state estimation solvable. Specifically, it is crucial to ensure that the system has at least one bus voltage magnitude measurement. This requirement stems from the fact that observable islands are identified using wattmeters, which estimate voltage angles. Since the voltage angle at the slack bus is already known, the same approach should be applied to bus voltage magnitudes. To fulfill this condition, we add the following measurement:
```@example 6bus
addVoltmeter!(monitoring; label = "Pseudo 3", bus = "Bus 1", magnitude = 1.0)
nothing # hide
```

Figure 5 illustrates the measurement configuration that makes our 6-bus power system observable and ensures a unique state estimator.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_pseudo.svg" width="420" class="my-svg"/>
    <p>Figure 5: Measurement configuration that makes the 6-bus power system observable.</p>
</div>
```

---

## Optimal PMU Placement
The goal of the PMU placement algorithm is to determine the minimal number of PMUs required to make the system observable. In this case, we analyze a 6-bus power system without power meters and identify the smallest set of PMUs needed for full observability, ensuring a unique state estimator:
```julia 6bus
placement = pmuPlacement(system, HiGHS.Optimizer)
```
```@setup 6bus
placement = pmuPlacement(system, HiGHS.Optimizer)
nothing # hide
```

The optimal PMU locations can be retrieved with:
```@repl 6bus
keys(placement.bus)
nothing # hide
```

Figure 6 illustrates the PMU configuration that ensures observability and guarantees a unique state estimator. Each installed PMU measures the bus voltage phasor and the current phasors of all connected branches.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_pmu.svg" width="420" class="my-svg"/>
    <p>Figure 6: PMU configuration that makes the 6-bus power system observable.</p>
</div>
&nbsp;
```

The configuration of phasor measurements includes voltage phasor measurements at `Bus 2`, `Bus 3`, and `Bus 4`. Additionally, there is a set of current phasor measurements at the from-bus ends of the branches, as shown below:
```@repl 6bus
keys(placement.from)
nothing # hide
```
To complete the measurement setup, the set should also include current phasor measurements at the to-bus ends of the branches, as specified in the following:
```@repl 6bus
keys(placement.to)
nothing # hide
```

These variables provide users with a convenient way to define phasor measurement values, whether based on AC power flow or AC optimal power flow analyses, which have been explored in [PMU state estimation](@ref PMUStateEstimationExamples) example.

However, users have the option to manually specify phasor measurement values:
```@example 6bus
pmu = measurement(system)

addPmu!(pmu; label = "PMU 1-1", bus = "Bus 2", magnitude = 1.1, angle = -0.2)
addPmu!(pmu; label = "PMU 1-2", to = "Branch 1", magnitude = 1.2, angle = -2.7)
addPmu!(pmu; label = "PMU 1-3", from = "Branch 2", magnitude = 0.6, angle = 0.3)
addPmu!(pmu; label = "PMU 1-4", from = "Branch 3", magnitude = 0.6, angle = 0.7)

addPmu!(pmu; label = "PMU 2-1", bus = "Bus 3", magnitude = 1.2, angle = -0.3)
addPmu!(pmu; label = "PMU 2-2", to = "Branch 2", magnitude = 0.6, angle = -2.8)
addPmu!(pmu; label = "PMU 2-3", from = "Branch 4", magnitude = 0.3, angle = -2.8)

addPmu!(pmu; label = "PMU 3-1", bus = "Bus 4", magnitude = 1.2, angle = -0.3)
addPmu!(pmu; label = "PMU 3-2", to = "Branch 3", magnitude = 0.6, angle = -2.3)
addPmu!(pmu; label = "PMU 3-3", to = "Branch 4", magnitude = 0.3, angle = 0.3)
addPmu!(pmu; label = "PMU 3-4", from = "Branch 6", magnitude = 0.2, angle = 1.9)

nothing # hide
```

This set of phasor measurements ensures system observability and guarantees a unique state estimator. The defined phasor measurements can be displayed using:
```@example 6bus
printPmuData(pmu)
```