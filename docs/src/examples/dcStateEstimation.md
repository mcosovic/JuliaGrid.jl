# [DC State Estimation](@id DCStateEstimationExamples)
In this example, we monitor a 6-bus power system, shown in Figure 1, and estimate bus voltage angles using DC state estimation.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/pmuStateEstimation/6bus_acpf.svg" width="450" class="my-svg"/>
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

Next, we define the power system by adding buses, branches, and generators with cost functions:
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

After defining the power system data, we generate the DC model, including the key matrices and vectors used in the analysis:
```@example dcStateEstimation
dcModel!(system)
nothing # hide
```

---

## Measurement Model
Next, we define the measurements. The question is how to obtain measurement values. In this example, synthetic measurements are generated using DC optimal power flow results.

To start, we initialize the measurement variable:
```@example dcStateEstimation
monitoring = measurement(system)
nothing # hide
```

---

##### DC Optimal Power Flow
To obtain bus voltage angles, we solve the DC optimal power flow. Using these values, we compute the active powers associated with buses and branches:
```@example dcStateEstimation
powerFlow = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(powerFlow; power = true, verbose = 1)
```

---

##### Active Power Injection Measurements
We obtain active power injection measurements from the DC optimal power flow analysis:
```@example dcStateEstimation
printBusData(powerFlow)
```

Next, we define these measurements:
```@example dcStateEstimation
@wattmeter(label = "Wattmeter ?")
for (label, idx) in system.bus.label
    Pᵢ = powerFlow.power.injection.active[idx]
    addWattmeter!(monitoring; bus = label, active = Pᵢ, variance = 1e-4, noise = true)
end
nothing # hide
```
Setting `noise = true` adds white Gaussian noise with `variance = 1e-4` to the exact values, generating the final measurement values.

---

##### Active Power Flow Measurements
Next, we include selected active power flow measurements using the DC optimal power flow results:
```@example dcStateEstimation
printBranchData(powerFlow)
```

We add two active power flow measurements:
```@example dcStateEstimation
addWattmeter!(monitoring; from = "Branch 1", active = powerFlow.power.from.active[1])
addWattmeter!(monitoring; from = "Branch 4", active = powerFlow.power.from.active[4])
nothing # hide
```
Here, `noise` is not set, so the measurement values remain exact.

---

##### Active Power Measurements
Finally, we display the complete measurement set:
```@example dcStateEstimation
printWattmeterData(monitoring)
```

Figure 2 shows the measurement configuration, including active power injection measurements at all buses and two active power flow measurements.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcStateEstimation/6bus_wattmeter.svg" width="380" class="my-svg"/>
    <p>Figure 2: The 6-bus power system with active power measurement configuration.</p>
</div>
&nbsp;
```

---

## Base Case Analysis
After obtaining the measurements, we create the DC state estimation model:
```@example dcStateEstimation
analysis = dcStateEstimation(monitoring)
nothing # hide
```

Next, we solve the model to determine the WLS estimator for bus voltage angles, then use the results to compute power values:
```@example dcStateEstimation
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can then inspect the estimated bus voltage angles and corresponding power values:
```@example dcStateEstimation
printBusData(analysis)
nothing # hide
```

We can also inspect the measurement results:
```@example dcStateEstimation
printWattmeterData(analysis)
nothing # hide
```

---

## Modifying Measurement Data
We now modify the measurement values. Instead of recreating the measurement set and the DC state estimation model, we update both together:
```@example dcStateEstimation
updateWattmeter!(analysis; label = "Wattmeter 7", active = 1.1)
updateWattmeter!(analysis; label = "Wattmeter 8", active = 1.6)
nothing # hide
```
Changing these measurement values introduces two outliers into the dataset, affecting the estimates.

Next, we solve the DC state estimation problem again to compute the updated estimate:
```@example dcStateEstimation
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the bus data:
```@example dcStateEstimation
printBusData(analysis)
nothing # hide
```
With the modified values for `Wattmeter 7` and `Wattmeter 8`, the estimates deviate more from the exact values computed by DC optimal power flow because the altered measurements no longer match their corresponding values.

We then compute the LAV estimator instead of the WLS estimator:
```@example dcStateEstimation
analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can inspect the bus data:
```@example dcStateEstimation
printBusData(analysis)
nothing # hide
```
The LAV estimates are closer to the exact DC optimal power flow values because LAV is more robust to outliers than WLS.

---

## Modifying Measurement Set
We continue with the LAV state estimation model and set two measurements out-of-service:
```@example dcStateEstimation
updateWattmeter!(analysis; label = "Wattmeter 1", status = 0)
updateWattmeter!(analysis; label = "Wattmeter 5", status = 0)
nothing # hide
```

We then recompute the LAV estimator and active power values:
```@example dcStateEstimation
stateEstimation!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the bus data:
```@example dcStateEstimation
printBusData(analysis)
```
Although LAV is more robust than WLS when handling outliers, estimate accuracy still depends on factors such as outlier magnitude, outlier count, and meter placement within the power system. Removing two accurate measurements while keeping outliers in the system shows that even LAV cannot fully compensate for the loss of reliable data, leading to less accurate estimates.