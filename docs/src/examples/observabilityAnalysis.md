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

We define the power system and add buses and branches:
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

Observability analysis and optimal PMU placement are independent of branch parameters, measurement values, and variances.

---

## Identification of Observable Islands
Next, we define the measurement model. JuliaGrid uses standard observability analysis based on the linear decoupled measurement model. Wattmeter active power measurements estimate bus voltage angles, while varmeter reactive power measurements estimate bus voltage magnitudes. In this example, four meters monitor the 6-bus power system, as shown in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_meter.svg" width="420" class="my-svg"/>
    <p>Figure 2: The 6-bus power system monitoring with four power meters.</p>
</div>
&nbsp;
```

The island detection step relies only on wattmeters, so defining wattmeters alone is sufficient when the goal is to identify observable islands. For observability restoration followed by state estimation, varmeters are also needed. Therefore, the four meters represent both wattmeters and varmeters:
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

AC state estimation cannot be solved with these measurements because the gain matrix would be singular. The same issue occurs with DC state estimation. To address this, observability analysis adds non-redundant measurements to ensure a nonsingular gain matrix and a unique state estimator.

Observability analysis begins by identifying observable islands. JuliaGrid can identify both flow-observable and maximal-observable islands, either of which can serve as the foundation for restoration. Here, we explore both types.

First, we determine the flow-observable islands:
```@example 6bus
islands = islandTopologicalFlow(monitoring)
nothing # hide
```

The result identifies four flow-observable islands:
```@repl 6bus
islands.island
nothing # hide
```

The first observable island consists of `Bus 1` and `Bus 2`, the second contains `Bus 3`, the third includes `Bus 4` and `Bus 6`, and `Bus 5` forms the fourth island, as shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_flow.svg" width="430" class="my-svg"/>
    <p>Figure 3: Flow-observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

We can also identify maximal-observable islands:
```@example 6bus
islands = islandTopological(monitoring)
nothing # hide
```

The result identifies two maximal-observable islands:
```@repl 6bus
islands.island
nothing # hide
```

The measurements from `Meter 2` and `Meter 3` merge the first, second, and third flow-observable islands into one, as shown in Figure 4.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_maximal.svg" width="430" class="my-svg"/>
    <p>Figure 4: Maximal-observable islands in the 6-bus power system.</p>
</div>
&nbsp;
```

For island identification, detecting flow-observable islands requires less computational effort than identifying maximal-observable islands. For observability restoration, however, using flow islands tends to be more computationally demanding than using maximal islands.

---

## Observability Restoration
Observability restoration requires a new set of measurements, called pseudo-measurements. These typically hold historical data about electrical quantities. We define this set:
```@example 6bus
pseudo = measurement(system)

addWattmeter!(pseudo; label = "Pseudo 1", from = "Branch 5", active = 0.3)
addVarmeter!(pseudo; label = "Pseudo 1", from = "Branch 5", reactive = 0.1)

addWattmeter!(pseudo; label = "Pseudo 2", bus = "Bus 5", active = 0.3)
addVarmeter!(pseudo; label = "Pseudo 2", bus = "Bus 5", reactive = -0.2)
nothing # hide
```

Next, we invoke the observability restoration function:
```@example 6bus
restorationGram!(monitoring, pseudo, islands)
nothing # hide
```
This function identifies the minimal set of pseudo-measurements needed to make the system observable. In this case, it selects `Pseudo 2` and transfers it to the measurement model.

The final wattmeter set used to measure active power is:
```@example 6bus
printWattmeterData(monitoring)
```

Likewise, the final varmeter set used to measure reactive power is:
```@example 6bus
printVarmeterData(monitoring)
```

Adding the `Pseudo 2` measurement makes the system observable, which we confirm by identifying a single observable island:
```@example 6bus
islands = islandTopological(monitoring)
nothing # hide
```

```@repl 6bus
islands.island
nothing # hide
```

To proceed with AC state estimation, one additional step is needed. The system must include at least one bus voltage magnitude measurement because observable islands are identified using wattmeters, which estimate voltage angles. Since the slack bus voltage angle is already known, an analogous reference is needed for bus voltage magnitudes. To satisfy this condition, we add the following measurement:
```@example 6bus
addVoltmeter!(monitoring; label = "Pseudo 3", bus = "Bus 1", magnitude = 1.0)
nothing # hide
```

Figure 5 shows the measurement configuration that makes the 6-bus power system observable and ensures a unique state estimator.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_pseudo.svg" width="420" class="my-svg"/>
    <p>Figure 5: Measurement configuration that makes the 6-bus power system observable.</p>
</div>
```

---

## Optimal PMU Placement
The PMU placement algorithm determines the minimum number of PMUs required to make the system observable. Here, we analyze a 6-bus power system without power meters and identify the smallest PMU set needed for full observability and a unique state estimator:
```julia 6bus
pmu = measurement(system)
placement = pmuPlacement(pmu, HiGHS.Optimizer)
```
```@setup 6bus
pmu = measurement(system)
placement = pmuPlacement(pmu, HiGHS.Optimizer)
nothing # hide
```

We retrieve the optimal PMU locations with:
```@repl 6bus
keys(placement.bus)
nothing # hide
```

Figure 6 shows the PMU configuration that ensures observability and guarantees a unique state estimator. Each installed PMU measures the bus voltage phasor and the current phasors of all connected branches.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/observability/6bus_pmu.svg" width="420" class="my-svg"/>
    <p>Figure 6: PMU configuration that makes the 6-bus power system observable.</p>
</div>
&nbsp;
```

The phasor measurement configuration includes voltage phasor measurements at `Bus 2`, `Bus 3`, and `Bus 4`, along with current phasor measurements at the from-bus ends of the branches:
```@repl 6bus
keys(placement.from)
nothing # hide
```
To complete the measurement setup, the set also includes current phasor measurements at the to-bus ends of the branches:
```@repl 6bus
keys(placement.to)
nothing # hide
```

These variables provide a convenient way to define phasor measurement values, whether based on AC power flow or AC optimal power flow analyses, as shown in the [PMU state estimation](@ref PMUStateEstimationExamples) example.

Users can also specify phasor measurement values manually:
```@example 6bus
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

This phasor measurement set ensures system observability and guarantees a unique state estimator. Display the defined phasor measurements with:
```@example 6bus
printPmuData(pmu)
```