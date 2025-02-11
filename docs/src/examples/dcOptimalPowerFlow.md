# [DC Optimal Power Flow](@id DCOptimalPowerFlowExamples)
This example utilizes the power system shown in Figure 1. Similar to the AC optimal power flow, we adjust constraints and modify the topology to highlight JuliaGrid’s ability to efficiently handle such scenarios.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/4busopt.svg" width="400"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/dcOptimalPowerFlow.jl).

We start by defining the unit system. Since DC optimal power flow considers only active powers and voltage angles, we specify the relevant units:
```@example 4bus
using JuliaGrid, Ipopt, JuMP # hide
@default(template) # hide
@default(unit) # hide

@power(MW, pu)
@voltage(pu, deg)
nothing # hide
```

Next, we define bus parameters for the analysis. This includes setting the slack bus (`type = 3`), where the voltage angle is fixed at zero, and specifying `active` power loads and shunt elements with `conductance` values. With these definitions, we construct the power system model:
```@example 4bus
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)

nothing # hide
```

We then define transmission line parameters by specifying `reactance` values. For phase-shifting transformer, we include the shift angle using the `shiftAngle` keyword. Additionally, we set bus voltage angle difference constraints between the from-bus and to-bus ends of each branch using `minDiffAngle` and `maxDiffAngle` keywords:
```@example 4bus
@branch(reactance = 0.22, minDiffAngle = -4.2, maxDiffAngle = 4.2)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", shiftAngle = -2.3)

nothing # hide
```
At this stage, no active power flow constraints are imposed, but they will be introduced later in the example.


Next, we define the `active` power outputs of the generators, which serve as initial values for the optimization variables. Generator outputs are constrained using `minActive` and `maxActive` keywords:
```@example 4bus
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 63.1, minActive = 10.0, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, minActive = 7.0, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, minActive = 7.0, maxActive = 22.4)
nothing # hide
```

Finally, we define the active power supply costs of the generators in polynomial form by setting `active = 2`. Then, we express the polynomial as a quadratic using the `polynomial` keyword:
```@example 4bus
cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])

nothing # hide
```

Once the power system data is defined, we generate a DC model that includes key matrices and vectors for analysis, such as the nodal admittance matrix. This model is automatically updated when data changes and can be shared across multiple analyses:
```@example 4bus
dcModel!(system)

nothing # hide
```

---

##### Display Data Settings
Before running simulations, we configure the numeric format for specific data type of interest including active power flow at branches and generator outputs:

```@example 4bus
fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Power Output" => "%.2f")
nothing # hide
```

---

## Base Case Analysis
We begin by creating the DC optimal power flow model and selecting the Ipopt solver. After solving the model, we determine the bus voltage angles and the active power outputs of the generators. Next, we compute the active powers across buses and branches:
```julia 4bus
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)
```
```@setup 4bus
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump)  # hide
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Once the DC optimal power flow is solved, we review bus-related results, including the optimal bus voltage angles:
```@example 4bus
printBusData(system, analysis)
```

We observe that the voltage angle difference constraint at `Branch 1` reaches its upper limit. This can also be confirmed by examining the branch constraint data, where the associated dual variable takes a nonzero value:
```@example 4bus
printBranchConstraint(system, analysis; label = "Branch 1", header = true, footer = true)
```

The optimal active power outputs of the generators are:
```@example 4bus
printGeneratorData(system, analysis; fmt)
```

All generators operate within their active power limits, as confirmed by the generator constraint data, where all dual variables remain zero:
```@example 4bus
printGeneratorConstraint(system, analysis)
```
Furthermore, `Generator 1`, with the lowest cost, supplies most of the power, while `Generator 2` and `Generator 3` produce equal power amounts due to identical cost functions.

Finally, we review the results related to branch flows:
```@example 4bus
printBranchData(system, analysis; fmt)
```

Thus, we obtained the active power flows, as illustrated in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcopt4bus_base.svg" width="450"/>
    <p>Figure 2: Active power flows in the 4-bus power system for the base case scenario.</p>
</div>
```

---

## Modifying Demands
Let us now introduce a new state by updating the active power demands of consumers. These updates modify both the power system model and the DC optimal power flow model simultaneously:
```@example 4bus
updateBus!(system, analysis; label = "Bus 2", active = 25.2)
updateBus!(system, analysis; label = "Bus 4", active = 43.3)
nothing # hide
```

Next, we solve the DC optimal power flow again to compute the new solution without recreating the model. This step enables a warm start, as the initial primal and dual values correspond to those obtained in the base case:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Now, we observe the power output of the generators:
```@example 4bus
printGeneratorData(system, analysis; fmt)
```
Compared to the base case, `Generator 1` increases output, while `Generator 2` and `Generator 3` reduce production to their minimum limits. Meanwhile, all voltage angle difference constraints remain within limits:
```@example 4bus
printBranchConstraint(system, analysis)
```

At the end of this scenario, we can review branch-related results for a more comprehensive insight into power flows:
```@example 4bus
printBranchData(system, analysis; fmt)
```

The obtained results allow us to illustrate the active power flows in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcopt4bus_demand.svg" width="450"/>
    <p>Figure 3: Active power flows in the 4-bus power system with modified demands.</p>
</div>
```

---

## Modifying Generator Costs
We adjust the cost functions for `Generator 1` and `Generator 3`, making `Generator 1` the highest-cost generator and `Generator 3` the lowest-cost one in the system. By updating both the power system model and the AC optimal power flow model simultaneously, we enable a warm start for solving this new scenario:
```@example 4bus
cost!(system, analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 40.0; 0.0])
cost!(system, analysis; generator = "Generator 3", active = 2, polynomial = [0.5; 10.0; 0.0])
nothing # hide
```

Next, we solve the updated problem and calculate the resulting powers:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

The optimal active power outputs of the generators are as follows:
```@example 4bus
printGeneratorData(system, analysis; fmt)
```
In this scenario, we observe that, due to the higher cost of `Generator 1`, its output decreases, while the outputs of `Generator 2` and `Generator 3` increase. Notably, `Generator 3` now produces a higher amount of power compared to `Generator 2` due to its lower cost. While one might expect `Generator 1` to decrease supplies more drastically and `Generator 3` to increase more dramatically, this is not the case due to the need to satisfy other constraints, such as active power balance at each bus.

We can also review the results related to branches for this scenario:
```@example 4bus
printBranchData(system, analysis; fmt)
```

Figure 4 illustrates the power flows for this scenario. Compared to the previous scenario, Figure 4 shows that `Branch 2` has significantly lower active power flow, while `Branch 3` has become considerably more loaded.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcopt4bus_cost.svg" width="450"/>
    <p>Figure 4: Active power flows in the 4-bus power system with modified generator costs.</p>
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
printGeneratorData(system, analysis; fmt)
```
The power flow limit at `Branch 3` forces `Generator 1` to increase its active power output despite its higher cost compared to `Generator 2` and `Generator 3`, due to the need to satisfy all constraints.

We can review the branch data and observe that the active power at the from-bus end of `Branch 3` reaches the defined limit, while the power flow at `Branch 2` stays within the specified limits:
```@example 4bus
printBranchData(system, analysis; fmt)
```

Based on the obtained results, we can illustrate the power flows in Figure 5.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcopt4bus_flow.svg" width="450"/>
    <p>Figure 5: Active power flows in the 4-bus power system with added branch flow constraints.</p>
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
printGeneratorData(system, analysis; fmt)
```
Due to the outage of `Branch 2` and the flow limit at `Branch 3`, `Generator 1` faces difficulties supplying load at `Bus 2`, reducing its output. Consequently, the only solution is to increase the output of `Generator 2` and `Generator 3`.

Upon reviewing the branch data, we observe that the active power flows in the remaining in-service branches remain largely unchanged. This is because, following the outage of `Branch 2`, `Generator 2` and `Generator 3` have taken over the responsibility of supplying the load at `Bus 2`, effectively displacing `Generator 1`:
```@example 4bus
printBranchData(system, analysis; fmt)
```

Figure 6 illustrates these results under the outage of `Branch 2`.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcopt4bus_service.svg" width="450"/>
    <p>Figure 6: Active power flows in the 4-bus power system with modified network topology.</p>
</div>
```