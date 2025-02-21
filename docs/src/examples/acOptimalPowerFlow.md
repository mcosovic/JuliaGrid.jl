# [AC Optimal Power Flow](@id ACOptimalPowerFlowExamples)
This example performs multiple AC optimal power flow analyses on the power system shown in Figure 1. These simulations capture quasi-steady-state conditions under varying constraints and topology changes.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/acOptimalPowerFlow/4bus.svg" width="400"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acOptimalPowerFlow.jl).

We begin by defining the units for active and reactive powers, as well as voltage magnitudes and angles, which will be used throughout this example:
```@example 4bus
using JuliaGrid, Ipopt, JuMP # hide
@default(template) # hide
@default(unit) # hide

@power(MW, MVAr)
@voltage(pu, deg)
nothing # hide
```

Next, we define bus parameters for the AC optimal power flow analysis. This includes specifying the slack bus (`type = 3`), where the bus voltage angle is set to zero by default, along with the corresponding `active` and `reactive` power loads, and shunt capacitor banks with `conductance` and `susceptance` values. The voltage magnitude limits for each bus are set using `minMagnitude` and `maxMagnitude`. With these definitions, we can begin building the power system model:
```@example 4bus
system = powerSystem()

@bus(minMagnitude = 0.95, maxMagnitude = 1.05)
addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 3", conductance = 0.1, susceptance = 8.2)
addBus!(system; label = "Bus 4", active = 50.8, reactive = 23.1)

nothing # hide
```

We define the transmission line parameters by specifying `resistance`, `reactance`, and `susceptance` values. At this stage, we do not impose any branch flow constraints, but they will be introduced later in the example:
```@example 4bus
@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 3", to = "Bus 4", turnsRatio = 0.98)

nothing # hide
```

We define the `active` and `reactive` power outputs of the generators, which serve as starting primal values for the optimization variables related to generator outputs. Reactive power outputs of the generators are limited by `minReactive` and `maxReactive`, while active power outputs vary between `minActive` and `maxActive`:
```@example 4bus
@generator(label = "Generator ?", minActive = 2.0, minReactive = -15.5, maxReactive = 15.5)
addGenerator!(system; bus = "Bus 1", active = 63.1, reactive = 8.2, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, reactive = 6.2, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, reactive = 8.5, maxActive = 22.4)
nothing # hide
```

Finally, we define the active power supply costs of the generators in polynomial form by setting `active = 2`. Then, we express the polynomial as a quadratic using the `polynomial` keyword:
```@example 4bus
cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])

nothing # hide
```

After defining the power system data, we generate an AC model that includes essential vectors and matrices for analysis, such as the nodal admittance matrix. This model is automatically updated with data changes and can be shared across different analyses:
```@example 4bus
acModel!(system)

nothing # hide
```

---

##### Display Data Settings
Before running simulations, we configure the data display settings, including the selection of displayed data elements and the numeric format for relevant power flow values.

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

To display generator-related data, we also set:
```@example 4bus
show3 = Dict("Reactive Power Capability" => false)
fmt3 = Dict("Power Output" => "%.2f")
nothing # hide
```

---

## Base Case Analysis
First, we create the AC optimal power flow model and select the Ipopt solver. Next, we solve the model to determine bus voltage magnitudes and angles, along with the active and reactive power outputs of the generators. Afterward, we compute the remaining power values for buses and branches:
```julia 4bus
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)
```
```@setup 4bus
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump)  # hide
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Once the AC optimal power flow is solved, we can review the bus-related results, including the optimal values of bus voltage magnitudes and angles:
```@example 4bus
printBusData(system, analysis; show = show1, fmt = fmt1)
```

The optimal active and reactive outputs of the generators are as follows:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
```
As we can observe from the generator data, the `Generator 1`, which has the lowest costs, generates power at the maximum value. Additionally, we can observe that `Generator 2` and `Generator 3` have the same cost functions, which dictate that these two will produce an equal amount of active power.

We enabled users to display bus, branch, or generator data related to the optimal power analysis. For instance, for generator data, we can observe that the dual variables related to `Generator 1` are different from zero, indicating that the generator's output has reached its limit:
```@example 4bus
printGeneratorConstraint(system, analysis; show = show3)
```

Finally, we can also review the results related to branches:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Thus, we obtained the active and reactive power flows, as illustrated in Figure 2.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_base_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_base_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 2: Power flows in the 4-bus power system for the base case scenario.
    </p>
</div>
```

---

## Modifying Demands
Let us now introduce a new state by updating the active and reactive power demands of consumers. These updates modify both the power system model and the AC optimal power flow model simultaneously:
```@example 4bus
updateBus!(system, analysis; label = "Bus 2", active = 25.2, reactive = 13.5)
updateBus!(system, analysis; label = "Bus 4", active = 43.3, reactive = 18.6)
nothing # hide
```

Next, we solve the AC optimal power flow again to compute the new solution without recreating the model. This step enables a warm start, as the initial primal and dual values correspond to those obtained in the base case:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Now, we observe the power output of the generators:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
```
Compared to the base case, all generators have reduced power supplies due to lower demand. It is important to note that, although one might expect `Generator 1` to continue producing at maximum output because of its lower cost, while only `Generator 2` and `Generator 3` reduce their production, this is not the case. The reason is that the optimal power flow must also satisfy power balance and bus voltage magnitude constraints.

At the end of this scenario, we can review branch-related results for a more comprehensive insight into power flows:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

The obtained results allow us to illustrate the active and reactive power flows in Figure 3.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_demand_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_demand_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 3: Power flows in the 4-bus power system with modified demands.
    </p>
</div>
```

---

## Modifying Generator Costs
We modify the cost functions for all generators, altering the objective function of the AC optimal power flow. By modifying the cost function of `Generator 1`, we shift it from being the lowest-cost to the highest-cost generator in the system. Updating both the power system model and the AC optimal power flow model simultaneously allows us to enable a warm start for the optimization problem:
```@example 4bus
cost!(system, analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 20.0; 0.0])
cost!(system, analysis; generator = "Generator 2", active = 2, polynomial = [0.8; 20.0; 0.0])
cost!(system, analysis; generator = "Generator 3", active = 2, polynomial = [0.8; 20.0; 0.0])
nothing # hide
```

Next, we solve the updated problem and calculate the resulting powers:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

The optimal active and reactive power outputs of the generators are as follows:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
```
In this scenario, we observe that, due to the increased cost of `Generator 1`, both `Generator 2` and `Generator 3` have increased their production to the maximum possible values to capitalize on their lower costs. The remaining required active power is then supplied by `Generator 1`.

We can also review the results related to branches for this scenario:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Figure 4 illustrates the power flows for this scenario. Compared to the previous scenario, Figure 4a shows that `Branch 2` has significantly lower active power flow, while `Branch 3` has become considerably more loaded.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_cost_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_cost_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 4: Power flows in the 4-bus power system with modified generator costs.
    </p>
</div>
```

---

## Adding Branch Flow Constraints
To limit active power flow, we introduce constraints on `Branch 2` and `Branch 3` by setting `type = 1`, where the active power flow at the from-bus end of these branches is limited using the `maxFromBus` keyword:
```@example 4bus
updateBranch!(system, analysis; label = "Branch 2", type = 1, maxFromBus = 15.0)
updateBranch!(system, analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)
```

Next, we recalculate the AC optimal power flow:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Now, let us observe the generator outputs:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
```
The power flow limit at `Branch 3` forces `Generator 1` to increase its active power output despite its higher cost compared to `Generator 2` and `Generator 3`, due to the need to satisfy all constraints. Additionally, we also observe a significant redistribution in the production of reactive powers.

We can review the branch data constraints and observe that the active power at the from-bus end of `Branch 3` reaches the defined limit, which leads to the power redistribution described earlier, while the power flow at `Branch 2` stays within the specified limits:
```@example 4bus
printBranchConstraint(system, analysis)
```

Finally, we can review the branch-related data to examine the redistribution of powers in detail:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Based on the obtained results, we can illustrate the power flows in Figure 5.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_flow_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_flow_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 5: Power flows in the 4-bus power system with added branch flow constraints.
    </p>
</div>
```

---

## Modifying Network Topology
At the end, we set `Branch 2` out-of-service:
```@example 4bus
updateBranch!(system, analysis; label = "Branch 2", status = 0)
```

We then recalculate the AC optimal power flow:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

We can now observe the updated generator outputs:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
```
Due to the outage of `Branch 2` and the flow limit at `Branch 3`, `Generator 1` faces difficulties supplying load at `Bus 2`, reducing its output. Consequently, the only solution is to increase the output of `Generator 2` and `Generator 3`.

Upon reviewing the branch data, we observe that the active power flows in the remaining in-service branches remain largely unchanged. This is because, following the outage of `Branch 2`, `Generator 2` and `Generator 3` have taken over the responsibility of supplying the load at `Bus 2`, effectively displacing `Generator 1`:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Figure 6 illustrates these results under the outage of `Branch 2`.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_service_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acOptimalPowerFlow/4bus_service_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 6: Power flows in the 4-bus power system with modified network topology.
    </p>
</div>
```