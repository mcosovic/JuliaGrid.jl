# [PMU State Estimation](@id PMUStateEstimationExamples)
In this example, we analyze a 6-bus power system, shown in Figure 1. The goal is to estimate bus voltage magnitudes and angles from phasor measurements only.

```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/pmuStateEstimation/6bus.svg" width="360" class="my-svg"/>
    <p>Figure 1: The 6-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/pmuStateEstimation.jl).


We define the power system by adding buses, branches, and a generator at the slack bus:
```@example pmuStateEstimation
using JuliaGrid, HiGHS # hide
@default(template) # hide
@default(unit) # hide

system, monitoring = ems()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")
addBus!(system; label = "Bus 5")
addBus!(system; label = "Bus 6")

@branch(resistance = 0.02)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.23)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 4", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 4", to = "Bus 5", reactance = 0.17)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.04)
addBranch!(system; label = "Branch 6", from = "Bus 1", to = "Bus 6", reactance = 0.21)
addBranch!(system; label = "Branch 7", from = "Bus 2", to = "Bus 6", reactance = 0.13)
addBranch!(system; label = "Branch 8", from = "Bus 5", to = "Bus 2", reactance = 0.34)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")
nothing # hide
```

---

##### Display Data Settings
Before running simulations, we configure which data elements to display:
```@example pmuStateEstimation
show = Dict("Shunt Power" => false, "Status" => false, "Series Power" => false)
nothing # hide
```

---

## Optimal PMU Placement
Next, we assign PMUs to the power system using an optimal placement strategy that ensures observability with the minimum number of PMUs:
```@example pmuStateEstimation
placement = pmuPlacement(monitoring, HiGHS.Optimizer; verbose = 1)
nothing # hide
```

This gives the bus locations where PMUs should be installed:
```@repl pmuStateEstimation
placement.bus
nothing # hide
```

PMUs installed at these buses measure bus voltage phasors and all currents in branches connected to those buses. The corresponding branch current phasors are:
```@repl pmuStateEstimation
placement.from
placement.to
nothing # hide
```

When phasor measurement values are generated from optimal power flow or power flow analysis, the integers in bus and branch labels indicate the vector positions where these values are stored.

Figure 2 shows the resulting phasor measurement configuration, including bus voltage and branch current phasor measurements.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/pmuStateEstimation/6bus_phasor.svg" width="340" class="my-svg"/>
    <p>Figure 2: The 6-bus power system with phasor measurement configuration.</p>
</div>
&nbsp;
```

Finally, we define the phasor measurements. The remaining question is how to obtain their values. In this example, we use AC power flow results to generate synthetic measurements.

---

##### AC Power Flow
AC power flow analysis requires generator and load data. Figure 3 shows the system configuration.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/pmuStateEstimation/6bus_acpf.svg" width="450" class="my-svg"/>
    <p>Figure 3: The 6-bus power system with generators and loads.</p>
</div>
&nbsp;
```

We add load and generator data as follows:
```@example pmuStateEstimation
updateBus!(system; label = "Bus 2", type = 1, active = 0.217, reactive = 0.127)
updateBus!(system; label = "Bus 3", type = 1, active = 0.478, reactive = -0.039)
updateBus!(system; label = "Bus 4", type = 2, active = 0.076, reactive = 0.016)
updateBus!(system; label = "Bus 5", type = 1, active = 0.112, reactive = 0.075)
updateBus!(system; label = "Bus 6", type = 1, active = 0.295, reactive = 0.166)

updateGenerator!(system; label = "Generator 1", active = 2.324, reactive = -0.169)
addGenerator!(system; label = "Generator 2", bus = "Bus 4", active = 0.412, reactive = 0.234)
nothing # hide
```

Next, we run AC power flow analysis to obtain bus voltages:
```@example pmuStateEstimation
acModel!(system)

powerFlow = newtonRaphson(system)
powerFlow!(powerFlow; verbose = 1)
nothing # hide
```

---

##### Bus Voltage Phasor Measurements
To obtain bus voltage phasor measurements, we use the exact values and optimal PMU placement data. Setting `noise = true` adds white Gaussian noise with the default `variance` of `1e-8` to the magnitude and angle values:
```@example pmuStateEstimation
@pmu(label = "!")
for (bus, idx) in placement.bus
    Vᵢ, θᵢ = powerFlow.voltage.magnitude[idx], powerFlow.voltage.angle[idx]
    addPmu!(monitoring; bus = bus, magnitude = Vᵢ, angle = θᵢ, noise = true)
end
nothing # hide
```

---

##### Branch Current Phasor Measurements
To add branch current phasor measurements, we first compute current magnitudes and angles, then use those values to form measurements. Here, the exact values are used because the `noise` keyword is ignored:
```@example pmuStateEstimation
for branch in keys(placement.from)
    Iᵢⱼ, ψᵢⱼ = fromCurrent(powerFlow; label = branch)
    addPmu!(monitoring; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ)
end
for branch in keys(placement.to)
    Iⱼᵢ, ψⱼᵢ = toCurrent(powerFlow; label = branch)
    addPmu!(monitoring; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ)
end
nothing # hide
```
Current phasor measurements can also be generated like voltage phasors by calling the [`current!`](@ref current!(::AC)) function after AC state estimation has converged.

Bus voltage and branch current measurements can also be formed by calling the [pmuPlacement!](@ref pmuPlacement!) function, as shown in the [PMU State Estimation](@ref PhasorMeasurementsManual) manual.

---

##### Phasor Measurements
Finally, we inspect the complete phasor measurement set shown in Figure 2:
```@example pmuStateEstimation
printPmuData(monitoring; width = Dict("Label" => 15))
```

---

## Base Case Analysis
Once the measurements are defined, we create the state estimation model:
```@example pmuStateEstimation
analysis = pmuStateEstimation(monitoring)
nothing # hide
```

Next, we solve the model to obtain the WLS estimate for bus voltages and compute the resulting powers:
```@example pmuStateEstimation
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can inspect the estimated bus voltages together with the corresponding power values:
```@example pmuStateEstimation
printBusData(analysis; show)
nothing # hide
```

We can also compare these results with those obtained from AC power flow:
```@example pmuStateEstimation
power!(powerFlow)
printBusData(powerFlow; show)
nothing # hide
```

We can also inspect the estimated branch power flows:
```@example pmuStateEstimation
printBranchData(analysis; show)
nothing # hide
```

---

## Modifying Measurement Data
Next, we update measurement values and variances. Instead of recreating the measurement set and PMU state estimation model, we modify both simultaneously:
```@example pmuStateEstimation
updatePmu!(analysis; label = "From Branch 8", magnitude = 1.1)
updatePmu!(analysis; label = "From Branch 2", angle = 0.2, noise = true)

nothing # hide
```
These updates show how JuliaGrid can modify individual measurement fields. For the phasor measurement at `From Branch 8`, only the magnitude changes, while the angle remains the same. For `From Branch 2`, only the angle is updated by adding white Gaussian noise, while the magnitude remains unchanged.

Next, we solve the PMU state estimation again to compute the new estimate:
```@example pmuStateEstimation
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the bus data:
```@example pmuStateEstimation
printBusData(analysis; show)
nothing # hide
```
With the updated measurement values, the estimates deviate more from the exact values obtained through AC power flow because the modified measurements no longer align with them.

---

## Modifying Measurement Set
Excluding phasor measurements obtained from optimal placement should be done with caution because it can easily make the system unobservable. In this example, we set two measurements out-of-service and immediately add two measurements to maintain observability:
```@example pmuStateEstimation
updatePmu!(monitoring; label = "From Branch 2", status = 0)
updatePmu!(monitoring; label = "From Branch 8", status = 0)

addPmu!(monitoring; to = "Branch 2", magnitude = 0.2282, angle = -2.9587)
addPmu!(monitoring; to = "Branch 8", magnitude = 0.0414, angle = -0.2424)
nothing # hide
```
Because new measurements are added, `analysis` is not passed to these functions. Directly modifying the existing PMU state estimation model is not possible in this case. To do this, define the new measurements beforehand with `status = 0` and then activate them by setting `status = 1`.

Next, we create and solve the PMU state estimation model:
```@example pmuStateEstimation
analysis = pmuStateEstimation(monitoring)
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the bus data:
```@example pmuStateEstimation
printBusData(analysis; show)
nothing # hide
```
Taking some measurements out-of-service affects the estimate. Adding more precise measurements while maintaining observability gives an estimate that more accurately reflects the exact power system state.