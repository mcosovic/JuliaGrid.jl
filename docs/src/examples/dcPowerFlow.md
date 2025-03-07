# [DC Power Flow](@id ACPowerFlowExamples)
DC power flow provides an approximate solution compared to AC power flow. We use the same power system model as in the AC power flow analysis, shown in Figure 1, to perform several DC power flow simulations. These simulations represent quasi-steady-state conditions where the system undergoes parameter and topology changes.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/acPowerFlow/4bus.svg" width="400"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/dcPowerFlow.jl).

We begin by defining the unit system. For DC power flow, only active power and voltage angle units are relevant:
```@example 4bus
using JuliaGrid # hide
@default(template) # hide
@default(unit) # hide

@power(MW, pu)
@voltage(pu, deg)
nothing # hide
```

Next, we define the bus parameters for DC power flow analysis. This includes specifying the slack bus as `type = 3`, the connected `active` power loads, and shunt elements with `conductance` values. The voltage `angle` at the slack bus is fixed to the specified value. With these definitions, we can build the power system model:
```@example 4bus
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, angle = 0.0)
addBus!(system; label = "Bus 2", active = 20.2)
addBus!(system; label = "Bus 3", conductance = 0.1)
addBus!(system; label = "Bus 4", active = 50.8)

nothing # hide
```

Next, we define the transmission line parameters by specifying `reactance` values. For phase-shifting transformers, we include the shift angle using the `shiftAngle` keyword:
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

Once the power system data is defined, we generate a DC model that includes key vectors and matrices for analysis, such as the nodal admittance matrix. This model is automatically updated when data changes and can be shared across different analyses:
```@example 4bus
dcModel!(system)

nothing # hide
```

---

## Base Case Analysis
At the start, we create a DC power flow model, then compute bus voltage angles and active powers:
```@example 4bus
analysis = dcPowerFlow(system)
powerFlow!(system, analysis; power = true, verbose = 1)
nothing # hide
```

Once the DC power flow is solved, we can analyze the bus-related results:
```@example 4bus
printBusData(system, analysis)
```

Similarly, the results for the branches are:
```@example 4bus
printBranchData(system, analysis)
```

Thus, using bus and branch data, we obtained the active power flows, as illustrated in Figure 2.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcPowerFlow/4bus_base.svg" width="450"/>
    <p>Figure 2: Active power flows in the 4-bus power system for the base case scenario.</p>
</div>
&nbsp;
```

Note that the active power at the from-bus and to-bus ends of a branch is the same because the DC power flow model neglects losses.

---

## Modifying Supplies and Demands
We will adjust the active power outputs of generators and the active power demands of consumers. Instead of creating a new power system model or simply updating the existing one, we update both the power system and DC power flow models simultaneously:
```@example 4bus
updateBus!(system, analysis; label = "Bus 2", active = 25.5)
updateBus!(system, analysis; label = "Bus 4", active = 42.0)

updateGenerator!(system, analysis; label = "Generator 1", active = 58.0)
updateGenerator!(system, analysis; label = "Generator 2", active = 23.0)

nothing # hide
```

Next, we solve the DC power flow again to compute the new state of the power system without recreating the DC power flow model:
```@example 4bus
powerFlow!(system, analysis; power = true, verbose = 1)
nothing # hide
```
Since no modifications were made that affect the nodal admittance matrix, JuliaGrid reuses its factorization from the base case analysis, significantly reducing computational complexity.

Finally, we display the updated branch data:
```@example 4bus
printBranchData(system, analysis)
```

Compared to the base case, the directions of power flows remain unchanged, but the amounts of active power differ, as shown in Figure 3.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcPowerFlow/4bus_power.svg" width="400"/>
    <p>Figure 3: Active power flows in the 4-bus power system with modified supplies and demands.</p>
</div>
```

---

## Modifying Network Topology
Now, we take `Branch 3` out-of-service while updating both the power system and DC power flow models:
```@example 4bus
updateBranch!(system, analysis; label = "Branch 3", status = 0)

nothing # hide
```

We then solve the DC power flow for this scenario:
```@example 4bus
powerFlow!(system, analysis; power = true, verbose = 1)
nothing # hide
```

To analyze how active power flows redistribute when a branch is out of service, we use:
```@example 4bus
printBranchData(system, analysis)
```

Finally, Figure 4 illustrates the active power flows in the case of a `Branch 3` outage.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/dcPowerFlow/4bus_service.svg" width="400"/>
    <p>Figure 4: Active power flows in the 4-bus power system with modified network topology.</p>
</div>
```