# [PMU State Estimation](@id PMUStateEstimationExamples)
This example examines a 6-bus power system, illustrated in Figure 1. The goal is to estimate bus voltage magnitudes and angles using only phasor measurements.

```@raw html
<div style="text-align: center;">
    <img src="../../assets/pmuStateEstimation/6bus.svg" width="360"/>
    <p>Figure 1: The 6-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/pmuStateEstimation.jl).


The power system is defined by specifying buses and branches, with the generator assigned to the slack bus:
```@example pmuStateEstimation
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
Before running simulations, we configure the data display settings:
```@example pmuStateEstimation
show = Dict("Shunt Power" => false, "Status" => false, "Series Power" => false)
nothing # hide
```

---

## Optimal PMU Placement
Next, PMUs need to be assigned to the power system shown in Figure 1. The placement is determined using an optimal PMU placement strategy that ensures observability with the minimal number of phasor measurements:
```@example pmuStateEstimation
placement = pmuPlacement(system, HiGHS.Optimizer; print = false)
nothing # hide
```

This provides the bus configuration where PMUs should be installed:
```@repl pmuStateEstimation
placement.bus
nothing # hide
```

PMUs installed at these buses will measure bus voltage phasors and all currents in branches connected to those buses. Specifically, current phasors will be measured in the following branches:
```@repl pmuStateEstimation
placement.from
placement.to
nothing # hide
```

If users choose to generate phasor measurement values using optimal power flow or power flow analysis, the integers within bus and branch labels indicate positions in vectors where these values are stored.

Hence, Figure 2 illustrates the phasor measurement configuration, which includes bus voltage and branch current phasor measurements.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/pmuStateEstimation/6bus_phasor.svg" width="340"/>
    <p>Figure 2: The 6-bus power system with phasor measurement configuration.</p>
</div>
&nbsp;
```

Finally, phasor measurements need to be defined. The question is how to obtain measurement values. In this example, AC power flow results will be used to generate synthetic measurements.

---

## Measurement Model
To begin, let us initialize the measurement variable:
```@example pmuStateEstimation
device = measurement()
nothing # hide
```

---

##### AC Power Flow
AC power flow analysis requires generator and load data. The system configuration is shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/pmuStateEstimation/6bus_acpf.svg" width="450"/>
    <p>Figure 3: The 6-bus power system with generators and loads.</p>
</div>
&nbsp;
```

Data for loads and generators is added as follows:
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

Next, AC power flow analysis is performed to obtain bus voltages:
```@example pmuStateEstimation
acModel!(system)

powerFlow = newtonRaphson(system)
for iteration = 1:20
    stopping = mismatch!(system, powerFlow)
    if all(stopping .< 1e-8)
        println("The algorithm converged in $(iteration - 1) iterations.")
        break
    end
    solve!(system, powerFlow)
end
nothing # hide
```

---

##### Bus Voltage Phasor Measurements
To obtain bus voltage phasor measurements, the exact values and optimal PMU placement data are used. By setting `noise = true`, white Gaussian noise with a default `variance` of `1e-8` is added to the magnitude and angle values:
```@example pmuStateEstimation
@pmu(label = "!")
for (bus, idx) in placement.bus
    Vᵢ, θᵢ = powerFlow.voltage.magnitude[idx], powerFlow.voltage.angle[idx]
    addPmu!(system, device; bus = bus, magnitude = Vᵢ, angle = θᵢ, noise = true)
end
nothing # hide
```

---

##### Branch Current Phasor Measurements
To add branch current phasor measurements, the current magnitudes and angles are first computed. These values are then used to form measurements, where the exact values are used as the `noise` keyword is ignored:
```@example pmuStateEstimation
for branch in keys(placement.from)
    Iᵢⱼ, ψᵢⱼ = fromCurrent(system, powerFlow; label = branch)
    addPmu!(system, device; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ)
end
for branch in keys(placement.to)
    Iⱼᵢ, ψⱼᵢ = toCurrent(system, powerFlow; label = branch)
    addPmu!(system, device; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ)
end
nothing # hide
```
Current phasor measurements can also be generated in the same way as voltage phasors by invoking the [`current!`](@ref current!(::PowerSystem, ::AC)) function after AC state estimation has converged.

---

##### Phasor Measurements
Finally, the complete set of phasor measurements is observed, as illustrated in Figure 2:
```@example pmuStateEstimation
printPmuData(system, device; width = Dict("Label" => 15))
```

---

## Base Case Analysis
Once the measurements are obtained, the state estimation model is created:
```@example pmuStateEstimation
analysis = pmuStateEstimation(system, device)
nothing # hide
```

Next, the model is solved to obtain the WLS estimator for bus voltages, and the results are used to compute powers:
```@example pmuStateEstimation
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

This enables users to observe the estimated bus voltages along with the corresponding power values:
```@example pmuStateEstimation
printBusData(system, analysis; show)
nothing # hide
```

Users can also compare these results with those obtained from AC power flow:
```@example pmuStateEstimation
power!(system, powerFlow)
printBusData(system, powerFlow; show)
nothing # hide
```

Additionally, estimated power flows at branches can be examined:
```@example pmuStateEstimation
printBranchData(system, analysis; show)
nothing # hide
```

---

## Modifying Measurement Data
Measurement values and variances are now updated. Instead of recreating the measurement set and the PMU state estimation model from the beginning, both are modified simultaneously:
```@example pmuStateEstimation
updatePmu!(system, device, analysis; label = "From Branch 8", magnitude = 1.1)
updatePmu!(system, device, analysis; label = "From Branch 2", angle = 0.2, noise = true)

nothing # hide
```
These updates demonstrate the flexibility of JuliaGrid in modifying measurements. For the phasor measurement at `From Branch 8`, only the voltage magnitude is changed, while the angle measurement remains the same. For `From Branch 2`, only the angle value is updated by adding white Gaussian noise, while the magnitude remains unchanged.

Next, the PMU state estimation is solved again to compute the new estimate:
```@example pmuStateEstimation
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Bus-related data can now be examined:
```@example pmuStateEstimation
printBusData(system, analysis; show)
nothing # hide
```
With the updated measurement values, the estimated results deviate more significantly from the exact values obtained through AC power flow, as the modified measurements no longer align with them.

---

## Modifying Measurement Set
This setup includes the minimal number of phasor measurements required to solve the state estimation problem. If a phasor measurement is taken out-of-service, additional measurements must be added to maintain system observability. For example:
```@example pmuStateEstimation
updatePmu!(system, device; label = "From Branch 2", status = 0)
updatePmu!(system, device; label = "From Branch 8", status = 0)

addPmu!(system, device; to = "Branch 2", magnitude = 0.2282, angle = -2.9587)
addPmu!(system, device; to = "Branch 8", magnitude = 0.0414, angle = -0.2424)
nothing # hide
```
Since new measurements are being added, `analysis` is not passed to these functions. Directly modifying the existing PMU state estimation model is not possible in this case. To achieve this, users should define the new measurements beforehand with `status = 0` and then activate them by setting `status = 1`.

Next, the PMU state estimation model is created and solved:
```@example pmuStateEstimation
analysis = pmuStateEstimation(system, device)
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Bus-related data can now be examined:
```@example pmuStateEstimation
printBusData(system, analysis; show)
nothing # hide
```
By taking certain measurements out-of-service, the estimation was affected. Adding more precise measurements while maintaining observability led to an estimation that more accurately reflects the exact power system state.