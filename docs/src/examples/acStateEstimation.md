# [AC State Estimation](@id ACStateEstimationExamples)
In this example, we analyze a 3-bus power system, shown in Figure 1. The objective is to estimate bus voltage magnitudes and angles for a given measurement configuration.

```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acStateEstimation/3bus_meter.svg" width="320" class="my-svg"/>
    <p>Figure 1: The 3-bus power system with the given measurement configuration.</p>
</div>
&nbsp;
```

The measurement set consists of `Meter 1`, `Meter 2`, and `Meter 3`, which measure active and reactive power injections and bus voltage magnitudes. `Meter 4` and `Meter 5` measure active and reactive power flows and current magnitudes.

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acStateEstimation.jl).


We define the power system, add buses and branches, and assign the generator to the slack bus:
```@example acStateEstimation
using JuliaGrid # hide
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1", magnitude = 1.01, angle = 0.0, type = 3)
addBus!(system; label = "Bus 2", magnitude = 0.92, angle = -0.04)
addBus!(system; label = "Bus 3", magnitude = 0.93, angle = -0.05)

@branch(reactance = 0.03)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3", resistance = 0.02)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2", resistance = 0.05)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", resistance = 0.04)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")
nothing # hide
```

The `magnitude` and `angle` values define the initial point for the iterative AC state estimation algorithm, while the slack bus angle (`type = 3`) remains fixed.

---

##### Display Data Settings
Before running simulations, we set `verbose` from its default silent mode (`0`) to basic output (`1`):
```@example acStateEstimation
@config(verbose = 1)
nothing # hide
```

For more detailed solver output, `verbose` can also be adjusted in the functions that solve specific analyses. Next, we configure the data display settings:
```@example acStateEstimation
show = Dict("Shunt Power" => false, "Status" => false)
nothing # hide
```

---

## Measurement Model
The first question is how to obtain measurement values. They can be predefined or generated artificially. This example explores both approaches.

One way to obtain measurement values is to solve the power system and use the resulting electrical quantities as measurement sources. Here, AC power flow computes voltages and powers, and these exact values are then used to generate measurements.

We begin by initializing the measurement variable:
```@example acStateEstimation
monitoring = measurement(system)
nothing # hide
```

---

##### AC Power Flow
AC power flow analysis requires generator and load data. Figure 2 shows the system configuration.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acStateEstimation/3bus.svg" width="350" class="my-svg"/>
    <p>Figure 2: The 3-bus power system.</p>
</div>
&nbsp;
```

We add the load and generator data:
```@example acStateEstimation
updateBus!(system; label = "Bus 2", type = 1, active = 1.1, reactive = 0.3)
updateBus!(system; label = "Bus 3", type = 1, active = 2.3, reactive = 0.2)

updateGenerator!(system; label = "Generator 1", active = 3.3, reactive = 2.1)
nothing # hide
```

Next, we run AC power flow analysis to obtain bus voltages:
```@example acStateEstimation
acModel!(system)

powerFlow = newtonRaphson(system)
powerFlow!(powerFlow)
nothing # hide
```

---

##### Bus Voltage Magnitude Measurements
First, we inspect the AC power flow results because the voltage magnitudes will be used to generate measurements:
```@example acStateEstimation
printBusData(powerFlow)
```

One way to obtain measurements is to create all bus voltage magnitude measurements with a function that uses the AC power flow results directly:
```@example acStateEstimation
@voltmeter(label = "Meter ?")
addVoltmeter!(monitoring, powerFlow; variance = 1e-4, noise = true)
nothing # hide
```

Setting `noise = true` adds white Gaussian noise with `variance = 1e-4` to the exact bus voltage magnitudes to generate measurement values:
```@example acStateEstimation
printVoltmeterData(monitoring)
nothing # hide
```

---

##### Active and Reactive Power Measurements
Active and reactive power injection measurements can be created with the same method as voltage magnitude measurements, using [`power!`](@ref power!(::AcPowerFlow)) first. Here, however, we add measurements one by one to `Meter 1`, `Meter 2`, and `Meter 3` using AC power flow data:
```@example acStateEstimation
@wattmeter(label = "Meter ?")
@varmeter(label = "Meter ?")

for (label, idx) in system.bus.label
    Pᵢ, Qᵢ = injectionPower(powerFlow; label)
    addWattmeter!(monitoring; bus = label, active = Pᵢ, variance = 1e-3, noise = true)
    addVarmeter!(monitoring; bus = label, reactive = Qᵢ, variance = 1e-4, noise = true)
end
nothing # hide
```

Next, we define active and reactive power flow measurements at both ends of `Branch 1`. We again use AC power flow data, compute the powers, and use the exact values to generate measurements. The default setting `noise = false` remains unchanged, so exact values are used:
```@example acStateEstimation
Pᵢⱼ, Qᵢⱼ = fromPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 4", from = "Branch 1", active = Pᵢⱼ)
addVarmeter!(monitoring; label = "Meter 4", from = "Branch 1", reactive = Qᵢⱼ)

Pⱼᵢ, Qⱼᵢ = toPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 5", to = "Branch 1", active = Pⱼᵢ)
addVarmeter!(monitoring; label = "Meter 5", to = "Branch 1", reactive = Qⱼᵢ)
```

This gives the set of active power measurements:
```@example acStateEstimation
printWattmeterData(monitoring)
nothing # hide
```

The reactive power measurements are:
```@example acStateEstimation
printVarmeterData(monitoring)
nothing # hide
```

---

##### Current Magnitude Measurements
Finally, we define current magnitude measurements at both ends of `Branch 1`. Here, we assume these values are known in advance and pass them directly to the functions:
```@example acStateEstimation
@ammeter(statusFrom = 0, statusTo = 0)

addAmmeter!(monitoring; label = "Meter 4", from = "Branch 1", magnitude = 1.36)
addAmmeter!(monitoring; label = "Meter 5", to = "Branch 1", magnitude = 2.37)
nothing # hide
```
For current magnitude measurements, we set `statusFrom = 0` and `statusTo = 0`, indicating that these measurements are out-of-service and do not influence state estimation. Although they do not affect the computation, they still occupy positions in the matrices and vectors used for state estimation. If they will not be put in-service later, they should be excluded from the measurement set.

The current magnitude measurements are:
```@example acStateEstimation
printAmmeterData(monitoring)
nothing # hide
```

---

## Base Case Analysis
After collecting the measurements, we solve the AC state estimation problem with the Gauss-Newton method to estimate bus voltages. The resulting estimates are then used to compute powers:
```@example acStateEstimation
analysis = gaussNewton(monitoring)
stateEstimation!(analysis; power = true, verbose = 2)
nothing # hide
```

We can then inspect the estimated bus voltages and bus power values:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

We can also inspect the branch power flows:
```@example acStateEstimation
printBranchData(analysis; show)
nothing # hide
```

Users can also retrieve measurement-device results. For example, wattmeter estimates and residuals can be displayed:
```@example acStateEstimation
printWattmeterData(analysis)
nothing # hide
```

---

## Modifying Measurement Data
We now update measurement values and variances. Instead of recreating the measurement set and the Gauss-Newton method, we modify both models together:
```@example acStateEstimation
updateVoltmeter!(analysis; label = "Meter 1", magnitude = 1.0, noise = false)
updateWattmeter!(analysis; label = "Meter 2", active = -1.1, variance = 1e-6)
updateVarmeter!(analysis; label = "Meter 3", variance = 1e-1)
nothing # hide
```
These updates demonstrate JuliaGrid’s flexibility in modifying measurements. The voltmeter measurement is generated without noise, the wattmeter value and variance are changed, and the varmeter keeps its previous value with only a variance adjustment.

Next, we run AC state estimation again without recreating the Gauss-Newton model. This enables a warm start because the initial voltage magnitudes and angles come from the base case solution:
```@example acStateEstimation
stateEstimation!(analysis; power = true)
nothing # hide
```

We can now inspect the bus data:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

---

## Modifying Measurement Set
We now modify the measurement set by including current magnitude measurements:
```@example acStateEstimation
updateAmmeter!(analysis; label = "Meter 4", status = 1)
updateAmmeter!(analysis; label = "Meter 5", status = 1)
nothing # hide
```

We then solve the AC state estimation problem again:
```@example acStateEstimation
stateEstimation!(analysis; power = true)
nothing # hide
```

We can now inspect the bus data:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

The bus voltage estimates appear suspicious, indicating bad data among the newly added ammeter measurements. To identify it, we perform bad data analysis:
```@example acStateEstimation
outlier = residualTest!(analysis; threshold = 4.0)
nothing # hide
```

The analysis detects an outlier with a high normalized residual, associated with the current magnitude measurement in `Meter 4`:
```@repl acStateEstimation
outlier.detect
outlier.maxNormalizedResidual
```

The bad data analysis function automatically removes the detected outlier. Before repeating AC state estimation, a warm start is not advisable because the previous state was computed with bad data. Instead, we reset the initial point, for example, using the values defined in the power system data:
```@example acStateEstimation
setInitialPoint!(analysis)
stateEstimation!(analysis; power = true)
nothing # hide
```

The bus data confirm that the results now align with expectations because the measurement set is free from bad data:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```