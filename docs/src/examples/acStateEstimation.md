# [AC State Estimation](@id ACStateEstimationExamples)
In this example, we analyze a 3-bus power system, shown in Figure 1. The objective is to estimate bus voltage magnitudes and angles for a given measurement configuration.

```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acStateEstimation/3bus_meter.svg" width="320" class="my-svg"/>
    <p>Figure 1: The 3-bus power system with the given measurement configuration.</p>
</div>
&nbsp;
```

The measurement set consists of `Meter 1`, `Meter 2`, and `Meter 3`, each measuring active and reactive power injection as well as bus voltage magnitude. Additionally, `Meter 4` and `Meter 5` measure active and reactive power flows along with current magnitudes.

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acStateEstimation.jl).


We define the power system, specify buses and branches, and assign the generator to the slack bus:
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

The `magnitude` and `angle` values define the initial point for the iterative AC state estimation algorithm, while the angle of the slack bus (`type = 3`) remains fixed at the specified value.

---

##### Display Data Settings
Before running simulations, we set the `verbose` keyword from its default silent mode (`0`) to basic output (`1`):
```@example acStateEstimation
@config(verbose = 1)
nothing # hide
```

However, if we need more detailed solver output, the `verbose` setting can be adjusted within the functions responsible for solving specific analyses. Next, we configure the data display settings:
```@example acStateEstimation
show = Dict("Shunt Power" => false, "Status" => false)
nothing # hide
```

---

## Measurement Model
The first question is how to obtain measurement data, specifically values. These can either be predefined or generated artificially. This example explores different approaches for defining measurement data.

One way to obtain measurement data is by solving the power system to determine exact electrical quantities, which will serve as the source for measurements. More precisely, AC power flow analysis is used to compute voltages and powers, and these exact values are then used to generate measurement data.

To begin, let us initialize the measurement variable:
```@example acStateEstimation
monitoring = measurement(system)
nothing # hide
```

---

##### AC Power Flow
AC power flow analysis requires generator and load data. The system configuration is shown in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acStateEstimation/3bus.svg" width="350" class="my-svg"/>
    <p>Figure 2: The 3-bus power system.</p>
</div>
&nbsp;
```

Data for loads and generators is added as follows:
```@example acStateEstimation
updateBus!(system; label = "Bus 2", type = 1, active = 1.1, reactive = 0.3)
updateBus!(system; label = "Bus 3", type = 1, active = 2.3, reactive = 0.2)

updateGenerator!(system; label = "Generator 1", active = 3.3, reactive = 2.1)
nothing # hide
```

Next, AC power flow analysis is performed to obtain bus voltages:
```@example acStateEstimation
acModel!(system)

powerFlow = newtonRaphson(system)
powerFlow!(powerFlow)
nothing # hide
```

---

##### Bus Voltage Magnitude Measurements
First, let us examine the results obtained from AC power flow, as these voltage magnitude values will be used to generate measurements:
```@example acStateEstimation
printBusData(powerFlow)
```

One way to obtain measurements is by creating all bus voltage magnitude measurements using a function that directly utilizes the results from AC power flow:
```@example acStateEstimation
@voltmeter(label = "Meter ?")
addVoltmeter!(monitoring, powerFlow; variance = 1e-4, noise = true)
nothing # hide
```

By setting `noise = true`, white Gaussian noise with `variance = 1e-4` is added to the exact bus voltage magnitude values to generate measurement values:
```@example acStateEstimation
printVoltmeterData(monitoring)
nothing # hide
```

---

##### Active and Reactive Power Measurements
Active and reactive power injection measurements can be created using the same method as for voltage magnitude measurements, where we first utilize the function [`power!`](@ref power!(::AcPowerFlow)). However, in this case, we take a different approach, adding measurements one by one to `Meter 1`, `Meter 2`, and `Meter 3` using data from AC power flow:
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

Next, we define active and reactive power flow measurements at `Branch 1` for both the from-bus and to-bus ends. Again, we use data from AC power flow, computing the powers and using exact values to generate measurements. The default setting `noise = false` remains unchanged, meaning exact values are used:
```@example acStateEstimation
Pᵢⱼ, Qᵢⱼ = fromPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 4", from = "Branch 1", active = Pᵢⱼ)
addVarmeter!(monitoring; label = "Meter 4", from = "Branch 1", reactive = Qᵢⱼ)

Pⱼᵢ, Qⱼᵢ = toPower(powerFlow; label = "Branch 1")
addWattmeter!(monitoring; label = "Meter 5", to = "Branch 1", active = Pⱼᵢ)
addVarmeter!(monitoring; label = "Meter 5", to = "Branch 1", reactive = Qⱼᵢ)
```

As a result, we obtain the set of active power measurements:
```@example acStateEstimation
printWattmeterData(monitoring)
nothing # hide
```

The set of reactive power measurements can be viewed as follows:
```@example acStateEstimation
printVarmeterData(monitoring)
nothing # hide
```

---

##### Current Magnitude Measurements
Finally, current magnitude measurements need to be defined at `Branch 1` for both the from-bus and to-bus ends. Here, we assume these values are known in advance and provide them directly to the functions:
```@example acStateEstimation
@ammeter(statusFrom = 0, statusTo = 0)

addAmmeter!(monitoring; label = "Meter 4", from = "Branch 1", magnitude = 1.36)
addAmmeter!(monitoring; label = "Meter 5", to = "Branch 1", magnitude = 2.37)
nothing # hide
```
For current magnitude measurements, we set `statusFrom = 0` and `statusTo = 0`, indicating that these measurements are out-of-service and do not influence state estimation. However, even though they do not impact the computation, they still occupy positions in the matrices and vectors used for state estimation. If there is no plan to put these measurements in-service later, it is advisable to exclude them from the measurement set.

The obtained set of current magnitude measurements is:
```@example acStateEstimation
printAmmeterData(monitoring)
nothing # hide
```

---

## Base Case Analysis
After collecting the measurements, we solve the AC state estimation by initializing the Gauss-Newton method and running the iterative algorithm to estimate bus voltages. The obtained results are then used to compute powers:
```@example acStateEstimation
analysis = gaussNewton(monitoring)
stateEstimation!(analysis; power = true, verbose = 2)
nothing # hide
```

This allows users to observe estimated bus voltages along with power values associated with buses:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

Power flows at branches can also be examined:
```@example acStateEstimation
printBranchData(analysis; show)
nothing # hide
```

Additionally, users can retrieve results related to measurement devices. For instance, estimated values and corresponding residuals for wattmeters can be displayed:
```@example acStateEstimation
printWattmeterData(analysis)
nothing # hide
```

---

## Modifying Measurement Data
Measurement values and variances will now be updated. Instead of recreating the measurement set and the Gauss-Newton method from the beginning, both models will be modified simultaneously:
```@example acStateEstimation
updateVoltmeter!(analysis; label = "Meter 1", magnitude = 1.0, noise = false)
updateWattmeter!(analysis; label = "Meter 2", active = -1.1, variance = 1e-6)
updateVarmeter!(analysis; label = "Meter 3", variance = 1e-1)
nothing # hide
```
These updates demonstrate the flexibility of JuliaGrid in modifying measurements. For the voltmeter, we now generate a measurement without adding noise, for the wattmeter, we change both the value and variance, while the varmeter retains its previous value with only a variance adjustment.

Next, AC state estimation is run again to compute the new estimate without recreating the Gauss-Newton model. Additionally, this step initializes the iterative algorithm with a warm start, as the initial voltage magnitudes and angles correspond to the solution from the base case analysis:
```@example acStateEstimation
stateEstimation!(analysis; power = true)
nothing # hide
```

Bus-related data can now be examined:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

---

## Modifying Measurement Set
Now, we modify the measurement set by including current magnitude measurements:
```@example acStateEstimation
updateAmmeter!(analysis; label = "Meter 4", status = 1)
updateAmmeter!(analysis; label = "Meter 5", status = 1)
nothing # hide
```

We then solve the AC state estimation again:
```@example acStateEstimation
stateEstimation!(analysis; power = true)
nothing # hide
```

Bus-related data can now be examined:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```

The bus voltage estimates appear suspicious, indicating the presence of bad data among the newly added ammeter measurements. To address this, we perform bad data analysis:
```@example acStateEstimation
outlier = residualTest!(analysis; threshold = 4.0)
nothing # hide
```

An outlier with a significantly high normalized residual is detected, specifically related to the current magnitude measurements in `Meter 4`:
```@repl acStateEstimation
outlier.detect
outlier.maxNormalizedResidual
```

The bad data analysis function automatically removes the detected outlier. Before repeating the AC state estimation, using a warm start is not advisable, as the previous state was obtained in the presence of bad data. Instead, it is useful to reset the initial point, for example, by using the values defined within the power system data:
```@example acStateEstimation
setInitialPoint!(analysis)
stateEstimation!(analysis; power = true)
nothing # hide
```

Observing the bus-related data, we can confirm that the results now align with expectations, as the measurement set is free from bad data:
```@example acStateEstimation
printBusData(analysis; show)
nothing # hide
```