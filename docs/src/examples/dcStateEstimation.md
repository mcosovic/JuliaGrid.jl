# [DC State Estimation](@id DCStateEstimationExamples)
In this example, we monitor a 6-bus power system, shown in Figure 1, and estimate bus voltage angles using DC state estimation.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/pmuStateEstimation/6bus_acpf.svg" width="450"/>
    <p>Figure 1: The 6-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/dcStateEstimation.jl).


We start by defining the units for voltage angles, which will be used throughout this example:
```@example dcStateEstimation
using JuliaGrid, JuMP, Ipopt # hide
@default(template) # hide
@default(unit) # hide

@voltage(pu, deg)
nothing # hide
```

Next, the power system is defined by specifying buses, branches, and generators with cost functions:
```@example dcStateEstimation
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", type = 1, active = 0.217)
addBus!(system; label = "Bus 3", type = 1, active = 0.478)
addBus!(system; label = "Bus 4", type = 2, active = 0.076)
addBus!(system; label = "Bus 5", type = 1, active = 0.112)
addBus!(system; label = "Bus 6", type = 2, active = 0.295)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.05)
addBranch!(system; label = "Branch 2", from = "Bus 2", to = "Bus 3", reactance = 0.23)
addBranch!(system; label = "Branch 3", from = "Bus 3", to = "Bus 4", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 4", to = "Bus 5", reactance = 0.17)
addBranch!(system; label = "Branch 5", from = "Bus 5", to = "Bus 6", reactance = 0.04)
addBranch!(system; label = "Branch 6", from = "Bus 1", to = "Bus 6", reactance = 0.21)
addBranch!(system; label = "Branch 7", from = "Bus 2", to = "Bus 6", reactance = 0.13)
addBranch!(system; label = "Branch 8", from = "Bus 5", to = "Bus 2", reactance = 0.34)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.8, maxActive = 2.3)
addGenerator!(system; label = "Generator 2", bus = "Bus 4", active = 0.4, maxActive = 2.3)

cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.0; 500.0; 150.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1500.0; 700.0; 140.0])

nothing # hide
```

After defining the power system data, a DC model is generated, including key matrices and vectors for analysis:
```@example dcStateEstimation
dcModel!(system)
nothing # hide
```

---

## Measurement Model
Next, we define the measurements. The question is how to obtain measurement values. In this example, synthetic measurements are generated using DC optimal power flow results.

To start, we initialize the measurement variable:
```@example dcStateEstimation
device = measurement()
nothing # hide
```

---

##### DC Optimal Power Flow
To obtain bus voltage angless, we solve the DC optimal power flow. Using these values, we compute the active power associated with buses and branches:
```@example dcStateEstimation
powerFlow = dcOptimalPowerFlow(system, Ipopt.Optimizer; verbose = 1)
solve!(system, powerFlow)
power!(system, powerFlow)
```

---

##### Active Power Injection Measurements
Active power injection measurements will be obtained from the DC optimal power flow analysis:
```@example dcStateEstimation
printBusData(system, powerFlow)
```

Next, these measurements are defined:
```@example dcStateEstimation
@wattmeter(label = "Wattmeter ?")
for (label, idx) in system.bus.label
    Pᵢ = powerFlow.power.injection.active[idx]
    addWattmeter!(system, device; bus = label, active = Pᵢ, variance = 1e-4, noise = true)
end
nothing # hide
```
Enabling `noise = true` adds white Gaussian noise with a `variance` of `1e-4` to the exact values, generating the final measurement values.

---

##### Active Power Flow Measurements
Next, we will include a certain number of active power flow measurements using the results from the DC optimal power flow analysis:
```@example dcStateEstimation
printBranchData(system, powerFlow)
```

Thus, two active power flow measurements are added:
```@example dcStateEstimation
addWattmeter!(system, device; from = "Branch 1", active = powerFlow.power.from.active[1])
addWattmeter!(system, device; from = "Branch 4", active = powerFlow.power.from.active[4])
nothing # hide
```
Here, `noise` is not set, keeping the measurement values exact.

---

##### Active Power Measurements
Finally, the complete set of measurements is displayed:
```@example dcStateEstimation
printWattmeterData(system, device)
```

Figure 2 illustrates this measurement configuration, which includes active power injection measurements at all buses and two active power flow measurements.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcStateEstimation/6bus_wattmeter.svg" width="380"/>
    <p>Figure 2: The 6-bus power system with active power measurement configuration.</p>
</div>
&nbsp;
```

---

## Base Case Analysis
After obtaining the measurements, the DC state estimation model is created:
```@example dcStateEstimation
analysis = dcStateEstimation(system, device)
nothing # hide
```

Next, the model is solved to determine the WLS estimator for bus voltage angles, and the results are used to compute power values:
```@example dcStateEstimation
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

This allows users to observe the estimated bus voltages along with the corresponding power values:
```@example dcStateEstimation
printBusData(system, analysis)
nothing # hide
```

Additionally, data related to measurement devices can be examined:
```@example dcStateEstimation
printWattmeterData(system, device, analysis)
nothing # hide
```

---

## Modifying Measurement Data
Let us now modify the measurement values. Instead of recreating the measurement set and the DC state estimation model from scratch, both are updated simultaneously:
```@example dcStateEstimation
updateWattmeter!(system, device, analysis; label = "Wattmeter 7", active = 1.1)
updateWattmeter!(system, device, analysis; label = "Wattmeter 8", active = 1.6)
nothing # hide
```
By changing these measurement values, two outliers are introduced into the dataset, which affects the estimates.

Next, the DC state estimation is solved again to compute the updated estimate:
```@example dcStateEstimation
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Bus-related data can now be examined:
```@example dcStateEstimation
printBusData(system, analysis)
nothing # hide
```
With the modified measurement values for `Wattmeter 7` and `Wattmeter 8`, the estimated results deviate more significantly from the exact values obtained through DC optimal power flow, as the altered measurements no longer align with their corresponding values.

Now, instead of using the WLS estimator, we compute the LAV estimator:
```@example dcStateEstimation
analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump)  # hide
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Bus-related data can be examined:
```@example dcStateEstimation
printBusData(system, analysis)
nothing # hide
```
As observed, the estimates obtained using the LAV method are closer to the exact values from the DC optimal power flow, as LAV is more robust to outliers compared to WLS.

---

## Modifying Measurement Set
Let us proceed with the LAV state estimation model and set two measurements to out-of-service:
```@example dcStateEstimation
updateWattmeter!(system, device, analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(system, device, analysis; label = "Wattmeter 5", status = 0)
nothing # hide
```

Recompute the LAV estimator and active power values:
```@example dcStateEstimation
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Bus-related data can now be examined:
```@example dcStateEstimation
printBusData(system, analysis)
```
As observed, while the LAV approach is more robust than WLS in handling outliers, the accuracy of the estimated values still depends on factors such as the magnitude of outliers, their number, and the positioning of meters within the power system. Removing two accurate measurements while keeping outliers in the system shows that even the LAV method cannot fully compensate for the loss of reliable data, leading to less accurate estimates.