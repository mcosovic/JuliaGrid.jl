# [DC Power Flow](@id DCPowerFlowExamples)
DC power flow provides an approximate solution relative to AC power flow. Using the same power system model as in the AC power flow example, shown in Figure 1, we perform several DC power flow simulations. The scenarios represent quasi-steady-state operation with parameter and topology changes.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acPowerFlow/4bus.svg" width="400" class="my-svg"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/dcPowerFlow.jl).

We begin by defining the unit system. For DC power flow, only active power and voltage angle units are needed:
```@example 4bus
using JuliaGrid # hide
@default(template) # hide
@default(unit) # hide

@power(MW, pu)
@voltage(pu, deg)
nothing # hide
```

Next, we define the bus parameters for DC power flow analysis, including the slack bus (`type = 3`), connected `active` power loads, and shunt `conductance` values. The slack bus voltage `angle` is fixed to the specified value. With these definitions, we can build the power system model:
```@example 4bus
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.0)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)
nothing # hide
```

Next, we define branch `reactance` values. For phase-shifting transformers, we use the `shiftAngle` keyword:
```@example 4bus
@branch(reactance = 0.22)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 3")
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 2")
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3")
addBranch!(system; label = "Branch 4", from = "Bus 3", to = "Bus 4", shiftAngle = -2.3)
nothing # hide
```

Finally, we define the `active` power outputs of the generators:
```@example 4bus
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 60.1)
addGenerator!(system; label = "Generator 2", bus = "Bus 2", active = 18.2)
nothing # hide
```

Once the power system data are defined, we generate a DC model with the vectors and matrices required for analysis, including the nodal admittance matrix. This model is automatically updated when the data changes and can be reused across analyses:
```@example 4bus
dcModel!(system)
nothing # hide
```

---

##### Display Data Settings
Before running simulations, we set `verbose` to basic output (`1`):
```@example 4bus
@config(verbose = 1)
nothing # hide
```

---

## Base Case Analysis
At the start, we create a DC power flow model and compute bus voltage angles and active powers:
```@example 4bus
analysis = dcPowerFlow(system)
powerFlow!(analysis; power = true)
nothing # hide
```

Once the DC power flow is solved, we can inspect the bus results:
```@example 4bus
printBusData(analysis)
```

Similarly, we can inspect the branch results:
```@example 4bus
printBranchData(analysis)
```

The resulting active power flows are shown in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcPowerFlow/4bus_base.svg" width="450" class="my-svg"/>
    <p>Figure 2: Active power flows in the 4-bus power system for the base case scenario.</p>
</div>
&nbsp;
```

Because the DC power flow model neglects losses, the active power at the from-bus and to-bus ends of each branch is the same.

---

## Modifying Supplies and Demands
We now modify the active power outputs of the generators and the active power demands. Rather than creating a new model, we update the power system and DC power flow models simultaneously:
```@example 4bus
updateBus!(analysis; label = "Bus 2", active = 25.5)
updateBus!(analysis; label = "Bus 4", active = 42.0)

updateGenerator!(analysis; label = "Generator 1", active = 58.0)
updateGenerator!(analysis; label = "Generator 2", active = 23.0)
nothing # hide
```

Next, we run the DC power flow again without recreating the DC power flow model:
```@example 4bus
powerFlow!(analysis; power = true)
nothing # hide
```
Since these changes do not affect the nodal admittance matrix, JuliaGrid reuses its factorization from the base case and reduces the computational cost.

Finally, we display the updated branch data:
```@example 4bus
printBranchData(analysis)
```

Compared with the base case, the active power flow directions remain unchanged, but their magnitudes differ, as shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcPowerFlow/4bus_power.svg" width="400" class="my-svg"/>
    <p>Figure 3: Active power flows in the 4-bus power system with modified supplies and demands.</p>
</div>
```

---

## Modifying Network Topology
Next, we take `Branch 3` out-of-service while updating both the power system and DC power flow models:
```@example 4bus
updateBranch!(analysis; label = "Branch 3", status = 0)
nothing # hide
```

We then solve the DC power flow for the outage scenario:
```@example 4bus
powerFlow!(analysis; power = true)
nothing # hide
```

To inspect how active power flows redistribute after the outage, we print the branch data:
```@example 4bus
printBranchData(analysis)
```

Figure 4 shows the active power flows after the `Branch 3` outage.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/dcPowerFlow/4bus_service.svg" width="400" class="my-svg"/>
    <p>Figure 4: Active power flows in the 4-bus power system with modified network topology.</p>
</div>
```