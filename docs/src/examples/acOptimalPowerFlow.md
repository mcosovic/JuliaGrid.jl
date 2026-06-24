# [AC Optimal Power Flow](@id ACOptimalPowerFlowExamples)
In this example, we perform multiple AC optimal power flow analyses using the power system shown in Figure 1. The scenarios represent quasi-steady-state operation with changing constraints and topology.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acOptimalPowerFlow/4bus.svg" width="400" class="my-svg"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acOptimalPowerFlow.jl).

We begin by defining the units for active and reactive powers, voltage magnitudes, and voltage angles used throughout this example:
```@example 4bus
using JuliaGrid, Ipopt, JuMP # hide
@default(template) # hide
@default(unit) # hide

@power(MW, MVAr)
@voltage(pu, deg)
nothing # hide
```

Next, we define bus parameters for the AC optimal power flow analysis, including the slack bus (`type = 3`), active and reactive power loads, and shunt capacitor banks with `conductance` and `susceptance` values. We set voltage magnitude limits using `minMagnitude` and `maxMagnitude`. With these definitions, we begin building the power system model:
```@example 4bus
system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 3", conductance = 0.1, susceptance = 8.2)
addBus!(system; label = "Bus 4", active = 50.8, reactive = 23.1)
nothing # hide
```

Next, we define branch `resistance`, `reactance`, and `susceptance` values. We leave branch flow constraints unset for now and introduce them later in the example:
```@example 4bus
@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 3", to = "Bus 4", turnsRatio = 0.98)
nothing # hide
```

We define the `active` and `reactive` power outputs of the generators, which serve as initial primal values for the generator output variables. Reactive outputs are limited by `minReactive` and `maxReactive`, while active outputs vary between `minActive` and `maxActive`:
```@example 4bus
@generator(label = "Generator ?", minActive = 2.0, minReactive = -15.5, maxReactive = 15.5)
addGenerator!(system; bus = "Bus 1", active = 63.1, reactive = 8.2, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, reactive = 6.2, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, reactive = 8.5, maxActive = 22.4)
nothing # hide
```

Finally, we define active power generation costs in polynomial form by setting `active = 2`. We then specify quadratic cost functions using the `polynomial` keyword:
```@example 4bus
cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])
nothing # hide
```

After defining the power system data, we generate an AC model with the vectors and matrices required for analysis, including the nodal admittance matrix:
```@example 4bus
acModel!(system)
nothing # hide
```

---

##### Display Data Settings
Before running simulations, we configure which data elements to display and the numeric format for power values.

For bus-related data, we set:
```@example 4bus
show1 = Dict("Power Injection" => false)
fmt1 = Dict("Power Generation" => "%.2f", "Power Demand" => "%.2f", "Shunt Power" => "%.2f")
nothing # hide
```

Similarly, for branch-related data, we choose:
```@example 4bus
show2 = Dict("Shunt Power" => false, "Status" => false)
fmt2 = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Series Power" => "%.2f")
nothing # hide
```

For generator-related data, we also set:
```@example 4bus
show3 = Dict("Reactive Power Capability" => false)
fmt3 = Dict("Power Output" => "%.2f")
nothing # hide
```

---

## Base Case Analysis
First, we create the AC optimal power flow model with the `Ipopt` solver. We then solve the model to determine bus voltage magnitudes and angles and generator active and reactive power outputs. Finally, we compute the remaining bus and branch power values:
```@setup 4bus
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)
```
```@example 4bus
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis, power = true, verbose = 1)
```

Once the AC optimal power flow is solved, we inspect the bus results, including the optimal voltage magnitudes and angles:
```@example 4bus
printBusData(analysis; show = show1, fmt = fmt1)
```

The optimal generator active and reactive power outputs are:
```@example 4bus
printGeneratorData(analysis; fmt = fmt3)
```
The generator data show that `Generator 1`, which has the lowest cost, produces power at its maximum output. Since `Generator 2` and `Generator 3` have identical cost functions, they produce equal active power.

Users can also display bus, branch, or generator constraints from the optimal power flow analysis. For example, the nonzero dual variables for `Generator 1` indicate that its output has reached the limit:
```@example 4bus
printGeneratorConstraint(analysis; show = show3)
```

Finally, we inspect the branch results:
```@example 4bus
printBranchData(analysis; show = show2, fmt = fmt2)
```

The resulting active and reactive power flows are shown in Figure 2.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_base_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_base_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 2: Power flows in the 4-bus power system for the base case scenario.
    </p>
</div>
```

---

## Modifying Demands
Next, we update the active and reactive power demands. These changes modify both the power system model and the AC optimal power flow model:
```@example 4bus
updateBus!(analysis; label = "Bus 2", active = 25.2, reactive = 13.5)
updateBus!(analysis; label = "Bus 4", active = 43.3, reactive = 18.6)
nothing # hide
```

We then solve the AC optimal power flow again without recreating the model. This enables a warm start because the initial primal and dual values come from the base case:
```@example 4bus
powerFlow!(analysis, power = true, verbose = 1)
nothing # hide
```

We can now inspect the generator power outputs:
```@example 4bus
printGeneratorData(analysis; fmt = fmt3)
```
Compared with the base case, all generators reduce their power output because demand is lower. Although `Generator 1` has the lowest cost, it no longer operates at maximum output because the optimal power flow must also satisfy power balance and bus voltage magnitude constraints.

We then inspect the branch results for additional insight into power flows:
```@example 4bus
printBranchData(analysis; show = show2, fmt = fmt2)
```

The resulting active and reactive power flows are shown in Figure 3.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_demand_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_demand_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 3: Power flows in the 4-bus power system with modified demands.
    </p>
</div>
```

---

## Modifying Generator Costs
We modify the cost functions for all generators, which changes the objective function of the AC optimal power flow. The updated cost function shifts `Generator 1` from the lowest-cost to the highest-cost generator in the system. Updating both models enables a warm start for the optimization problem:
```@example 4bus
cost!(analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 20.0; 0.0])
cost!(analysis; generator = "Generator 2", active = 2, polynomial = [0.8; 20.0; 0.0])
cost!(analysis; generator = "Generator 3", active = 2, polynomial = [0.8; 20.0; 0.0])
nothing # hide
```

Next, we solve the updated problem and compute the resulting powers:
```@example 4bus
powerFlow!(analysis, power = true, verbose = 1)
nothing # hide
```

The optimal generator active and reactive power outputs are:
```@example 4bus
printGeneratorData(analysis; fmt = fmt3)
```
In this scenario, the increased cost of `Generator 1` causes `Generator 2` and `Generator 3` to increase production to their maximum outputs. `Generator 1` then supplies the remaining active power.

We can also inspect the branch results for this scenario:
```@example 4bus
printBranchData(analysis; show = show2, fmt = fmt2)
```

Figure 4 shows the power flows for this scenario. Compared with the previous scenario, `Branch 2` has significantly lower active power flow, while `Branch 3` becomes more heavily loaded.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_cost_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_cost_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 4: Power flows in the 4-bus power system with modified generator costs.
    </p>
</div>
```

---

## Adding Branch Flow Constraints
To limit active power flow, we add constraints to `Branch 2` and `Branch 3` by setting `type = 1` and specifying the from-bus limit with `maxFromBus`:
```@example 4bus
updateBranch!(analysis; label = "Branch 2", type = 1, maxFromBus = 15.0)
updateBranch!(analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)
nothing # hide
```

Next, we solve the updated AC optimal power flow:
```@example 4bus
powerFlow!(analysis, power = true, verbose = 1)
nothing # hide
```

We can now inspect the generator outputs:
```@example 4bus
printGeneratorData(analysis; fmt = fmt3)
```

The power flow limit on `Branch 3` forces `Generator 1` to increase its active power output despite its higher cost than `Generator 2` and `Generator 3`. The solution also shows a significant redistribution of reactive power production.

The branch constraints show that active power at the from-bus end of `Branch 3` reaches the defined limit, causing the redistribution described above. The power flow on `Branch 2` remains within its specified limit:
```@example 4bus
printBranchConstraint(analysis)
```

Finally, we inspect the branch data to examine the power redistribution in detail:
```@example 4bus
printBranchData(analysis; show = show2, fmt = fmt2)
```

The resulting power flows are shown in Figure 5.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_flow_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_flow_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 5: Power flows in the 4-bus power system with added branch flow constraints.
    </p>
</div>
```

---

## Modifying Network Topology
Finally, we set `Branch 2` out-of-service:
```@example 4bus
updateBranch!(analysis; label = "Branch 2", status = 0)
```

We then solve the updated AC optimal power flow:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the updated generator outputs:
```@example 4bus
printGeneratorData(analysis; fmt = fmt3)
```

Because `Branch 2` is out-of-service and `Branch 3` is flow-limited, `Generator 1` has less ability to supply the load at `Bus 2`, so its output decreases. As a result, `Generator 2` and `Generator 3` increase their output.

The branch data show that active power flows in the remaining in-service branches remain largely unchanged. After the outage of `Branch 2`, `Generator 2` and `Generator 3` supply the load at `Bus 2`, effectively displacing `Generator 1`:
```@example 4bus
printBranchData(analysis; show = show2, fmt = fmt2)
```

Figure 6 shows the resulting power flows with `Branch 2` out-of-service.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_service_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acOptimalPowerFlow/4bus_service_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 6: Power flows in the 4-bus power system with modified network topology.
    </p>
</div>
```