# [DC Optimal Power Flow](@id DCOptimalPowerFlowExamples)
This example uses the power system shown in Figure 1. As in the AC optimal power flow example, we adjust constraints and modify the topology to show how JuliaGrid efficiently handles these scenarios.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acOptimalPowerFlow//4bus.svg" width="400" class="my-svg"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/dcOptimalPowerFlow.jl).

We start by defining the unit system. Since DC optimal power flow considers only active power and voltage angles, we specify the relevant units:
```@example 4bus
using JuliaGrid, Ipopt, JuMP # hide
@default(template) # hide
@default(unit) # hide

@power(MW, pu)
@voltage(pu, deg)
nothing # hide
```

Next, we define the bus parameters, including the slack bus (`type = 3`), where the voltage angle is fixed at zero, active power loads, and shunt conductance values. With these definitions, we construct the power system model:
```@example 4bus
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)
nothing # hide
```

We then define the transmission line parameters by specifying `reactance` values. For the phase-shifting transformer, we set the shift angle with `shiftAngle`. We also impose bus voltage angle difference constraints between the from-bus and to-bus ends of each branch with `minDiffAngle` and `maxDiffAngle`:
```@example 4bus
@branch(reactance = 0.2, minDiffAngle = -4.1, maxDiffAngle = 4.1)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", shiftAngle = -2.3)
nothing # hide
```
At this stage, no active power flow constraints are imposed; they are introduced later in the example.

Next, we define the generator `active` power outputs, which serve as initial values for the optimization variables. The outputs are constrained with `minActive` and `maxActive`:
```@example 4bus
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 63.1, minActive = 10.0, maxActive = 65.5)
addGenerator!(system; bus = "Bus 2", active = 3.0, minActive = 7.0, maxActive = 20.5)
addGenerator!(system; bus = "Bus 2", active = 4.1, minActive = 7.0, maxActive = 22.4)
nothing # hide
```

Finally, we define the generator active power supply costs in polynomial form by setting `active = 2`. The quadratic coefficients are specified with `polynomial`:
```@example 4bus
cost!(system; generator = "Generator 1", active = 2, polynomial = [0.04; 20.0; 0.0])
cost!(system; generator = "Generator 2", active = 2, polynomial = [1.00; 20.0; 0.0])
cost!(system; generator = "Generator 3", active = 2, polynomial = [1.00; 20.0; 0.0])
nothing # hide
```

Once the power system data are defined, we generate the DC model, including the key matrices and vectors used in the analysis:
```@example 4bus
dcModel!(system)
nothing # hide
```

---

##### Display Data Settings
Before running simulations, we configure the numeric format for selected data, including branch active power flows and generator outputs:
```@example 4bus
fmt = Dict("From-Bus Power" => "%.2f", "To-Bus Power" => "%.2f", "Power Output" => "%.2f")
nothing # hide
```

---

## Base Case Analysis
First, we create the DC optimal power flow model with the `Ipopt` solver. The optimization variables are bus voltage angles and generator active power outputs, denoted as `θ` and `Pg`:
```@example 4bus
analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer; angle = "θ", active = "Pg")
nothing # hide
```

We can then print the optimization problem:
```@repl 4bus
print(analysis.method.jump)
```

We solve the DC optimal power flow model to obtain the bus voltage angles and generator active power outputs, then compute the remaining bus and branch active powers:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
```

After obtaining the solution, we inspect the bus results, including the optimal voltage angles:
```@example 4bus
printBusData(analysis)
```

The voltage angle difference constraint on `Branch 1` reaches its upper limit. The branch constraint data confirm this with a nonzero associated dual variable:
```@example 4bus
printBranchConstraint(analysis; label = "Branch 1", header = true, footer = true)
```

The optimal generator active power outputs are:
```@example 4bus
printGeneratorData(analysis; fmt)
```

The generator constraint data confirm that all generators operate within their active power limits, with all dual variables equal to zero:
```@example 4bus
printGeneratorConstraint(analysis)
```
Because `Generator 1` has the lowest cost, it supplies most of the power. `Generator 2` and `Generator 3` produce equal active power because they have identical cost functions.

Finally, we inspect the branch flow results:
```@example 4bus
printBranchData(analysis; fmt)
```

The resulting active power flows are shown in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcOptimalPowerFlow/4bus_base.svg" width="450" class="my-svg"/>
    <p>Figure 2: Active power flows in the 4-bus power system for the base case scenario.</p>
</div>
```

---

## Modifying Demands
Next, we update the active power demands. These changes modify both the power system model and the DC optimal power flow model:
```@example 4bus
updateBus!(analysis; label = "Bus 2", active = 25.2)
updateBus!(analysis; label = "Bus 4", active = 43.3)
nothing # hide
```

We then solve the DC optimal power flow again without recreating the model. This enables a warm start because the initial primal and dual values come from the base case:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the generator power outputs:
```@example 4bus
printGeneratorData(analysis; fmt)
```
Compared with the base case, `Generator 1` increases its output, while `Generator 2` and `Generator 3` reduce production to their minimum limits. All voltage angle difference constraints remain within their limits:
```@example 4bus
printBranchConstraint(analysis)
```

We then inspect the branch results for additional insight into power flows:
```@example 4bus
printBranchData(analysis; fmt)
```

The resulting active power flows are shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcOptimalPowerFlow/4bus_demand.svg" width="450" class="my-svg"/>
    <p>Figure 3: Active power flows in the 4-bus power system with modified demands.</p>
</div>
```

---

## Modifying Generator Costs
We adjust the cost functions for `Generator 1` and `Generator 3`, making `Generator 1` the highest-cost generator and `Generator 3` the lowest-cost generator in the system. Updating both models enables a warm start for this scenario:
```@example 4bus
cost!(analysis; generator = "Generator 1", active = 2, polynomial = [2.0; 40.0; 0.0])
cost!(analysis; generator = "Generator 3", active = 2, polynomial = [0.5; 10.0; 0.0])
nothing # hide
```

Next, we solve the updated problem and compute the resulting powers:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
nothing # hide
```

The optimal generator active power outputs are:
```@example 4bus
printGeneratorData(analysis; fmt)
```
In this scenario, the higher cost of `Generator 1` decreases its output, while `Generator 2` and `Generator 3` increase their output. Because `Generator 3` has the lowest cost, it produces more active power than `Generator 2`. Although `Generator 1` might be expected to reduce output further and `Generator 3` to increase output more, the solution must also satisfy constraints such as active power balance at each bus.

We can also inspect the branch results for this scenario:
```@example 4bus
printBranchData(analysis; fmt)
```

Figure 4 shows the power flows for this scenario. Compared with the previous scenario, `Branch 2` has significantly lower active power flow, while `Branch 3` becomes more heavily loaded.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcOptimalPowerFlow/4bus_cost.svg" width="450" class="my-svg"/>
    <p>Figure 4: Active power flows in the 4-bus power system with modified generator costs.</p>
</div>
```

---

## Adding Branch Flow Constraints
To limit active power flow, we add constraints to `Branch 2` and `Branch 3` by setting `type = 1` and specifying the from-bus limit with `maxFromBus`:
```@example 4bus
updateBranch!(analysis; label = "Branch 2", type = 1, maxFromBus = 15.0)
updateBranch!(analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)
```

Next, we solve the updated DC optimal power flow:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the generator outputs:
```@example 4bus
printGeneratorData(analysis; fmt)
```
The power flow limit on `Branch 3` forces `Generator 1` to increase its active power output despite its higher cost than `Generator 2` and `Generator 3`.

The branch data show that active power at the from-bus end of `Branch 3` reaches the defined limit, while the power flow on `Branch 2` remains within its specified limit:
```@example 4bus
printBranchData(analysis; fmt)
```

The resulting active power flows are shown in Figure 5.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcOptimalPowerFlow/4bus_flow.svg" width="450" class="my-svg"/>
    <p>Figure 5: Active power flows in the 4-bus power system with added branch flow constraints.</p>
</div>
```

---

## Modifying Network Topology
Finally, we set `Branch 2` out-of-service:
```@example 4bus
updateBranch!(analysis; label = "Branch 2", status = 0)
```

We then solve the updated DC optimal power flow:
```@example 4bus
powerFlow!(analysis; power = true, verbose = 1)
nothing # hide
```

We can now inspect the updated generator outputs:
```@example 4bus
printGeneratorData(analysis; fmt)
```
Because `Branch 2` is out-of-service and `Branch 3` is flow-limited, `Generator 1` has less ability to supply the load at `Bus 2`, so its output decreases. As a result, `Generator 2` and `Generator 3` increase their output.

The branch data show that active power flows in the remaining in-service branches remain largely unchanged. After the outage of `Branch 2`, `Generator 2` and `Generator 3` supply the load at `Bus 2`, effectively displacing `Generator 1`:
```@example 4bus
printBranchData(analysis; fmt)
```

Figure 6 shows the resulting active power flows with `Branch 2` out-of-service.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcOptimalPowerFlow/4bus_service.svg" width="450" class="my-svg"/>
    <p>Figure 6: Active power flows in the 4-bus power system with modified network topology.</p>
</div>
```