# [AC Power Flow](@id ACPowerFlowExamples)
In this example, we perform several AC power flow analyses using the power system shown in Figure 1. These analyses simulate quasi-steady-state conditions where the system undergoes parameter and topology changes, demonstrating JuliaGrid's efficiency in handling such scenarios.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/examples/acPowerFlow/4bus.svg" width="400" class="my-svg"/>
    <p>Figure 1: The 4-bus power system.</p>
</div>
&nbsp;
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acPowerFlow.jl).

We begin by defining the units for active and reactive powers, as well as voltage magnitudes and angles, which will be used throughout this example:
```@example 4bus
using JuliaGrid # hide
@default(template) # hide
@default(unit) # hide

@power(MW, MVAr)
@voltage(pu, deg)
nothing # hide
```

Next, we define the bus parameters for AC power flow analysis. This includes specifying the `type` of each bus, the connected `active` and `reactive` power loads, and shunt capacitor banks with `conductance` and `susceptance` values. The bus voltage `magnitude` and `angle` serve as initial values for the iterative power flow algorithm. Note that for the slack bus (`type = 3`), the angle is fixed to the specified value. With these definitions, we can start to build the power system model:
```@example 4bus
system = powerSystem()

@bus(magnitude = 1.1, angle = -5.7)
addBus!(system; label = "Bus 1", type = 3, angle = 0.0)
addBus!(system; label = "Bus 2", type = 2, active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 3", type = 1, conductance = 0.1, susceptance = 8.2)
addBus!(system; label = "Bus 4", type = 1, active = 50.8, reactive = 23.1)
nothing # hide
```

Next, we refine the transmission line parameters by adding `resistance`, `reactance`, and `susceptance` values. Additionally, for transformers, we specify the off-nominal turns ratio using the `turnsRatio` keyword:
```@example 4bus

@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 3", to = "Bus 4", turnsRatio = 0.98)
nothing # hide
```

Finally, we define the `active` and `reactive` power outputs of the generators and the voltage `magnitude` setpoints. These setpoints fix the voltage magnitudes for the slack bus (`type = 3`) and generator buses (`type = 2`):
```@example 4bus
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 60.1, reactive = 40.2,  magnitude = 0.98)
addGenerator!(system; bus = "Bus 2", active = 18.2, magnitude = 1.01)
nothing # hide
```


After defining the power system data, we generate an AC model with the vectors and matrices required for analysis, including the nodal admittance matrix. This model is automatically updated when the data changes and can be reused across analyses:
```@example 4bus
acModel!(system)
nothing # hide
```

---

##### Display Data Settings
Before running simulations, we set `verbose` from silent mode (`0`) to basic output (`1`):
```@example 4bus
@config(verbose = 1)
nothing # hide
```

For more detailed solver output, `verbose` can also be set when calling the power flow solver. Next, we configure the data display settings, including the selection of displayed data elements and the numeric format for relevant power flow values.

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

---

## Base Case Analysis
At the start, we create a fast Newton-Raphson XB model:
```@example 4bus
fnr = fastNewtonRaphsonXB(system)
nothing # hide
```

Then, we solve the AC power flow and compute bus voltages together with active and reactive powers:
```@example 4bus
powerFlow!(fnr; power = true, verbose = 2)
nothing # hide
```

Once the AC power flow is solved, we can inspect the bus results. For instance:
```@example 4bus
printBusData(fnr; show = show1, fmt = fmt1)
```

Similarly, we can inspect the branch results:
```@example 4bus
printBranchData(fnr; show = show2, fmt = fmt2)
```

The resulting active and reactive power flows are shown in Figure 2.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_base_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_base_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 2: Power flows in the 4-bus power system for the base case scenario.
    </p>
</div>
&nbsp;
```

The branch data also shows the series power losses caused by the series resistance and reactance of each branch. Note that the active power at the from-bus and to-bus ends of a branch differs by the active power loss. Reactive power does not follow the same pattern because branch susceptances provide partial compensation.

---

## Modifying Supplies and Demands
We now modify the active and reactive power outputs of the generators and the active and reactive demands. Rather than creating a new model, we update the power system and fast Newton-Raphson models simultaneously:
```@example 4bus
updateBus!(fnr; label = "Bus 2", active = 25.5, reactive = 15.0)
updateBus!(fnr; label = "Bus 4", active = 42.0, reactive = 20.0)

updateGenerator!(fnr; label = "Generator 1", active = 58.0, reactive = 20.0)
updateGenerator!(fnr; label = "Generator 2", active = 23.1, reactive = 20.0)

nothing # hide
```

Next, we run the AC power flow again without recreating the fast Newton-Raphson model. This call also warm-starts the fast Newton-Raphson method because the initial voltage magnitudes and angles come from the base-case solution:
```@example 4bus
powerFlow!(fnr; power = true)
nothing # hide
```
Since these changes do not affect the Jacobian matrices, JuliaGrid reuses the Jacobian factorizations from the base case and reduces the computational cost.

Finally, we display the updated branch data:
```@example 4bus
printBranchData(fnr; show = show2, fmt = fmt2)
```

Compared with the base case, the active power flow directions remain unchanged, but their magnitudes differ. The reactive power values also change, and the flow at the `Bus 1` side of `Branch 1` reverses, as shown in Figure 3.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_power_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_power_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 3: Power flows in the 4-bus power system with modified supplies and demands.
    </p>
</div>
```

---

## Modifying Network Topology
Next, we take `Branch 3` out-of-service. Although we could update the power system and fast Newton-Raphson models simultaneously, we use the Newton-Raphson method here to demonstrate flexibility. Therefore, we update only the power system model:
```@example 4bus
updateBranch!(system; label = "Branch 3", status = 0)
nothing # hide
```

Next, we create the Newton-Raphson model:
```@example 4bus
nr = newtonRaphson(system)
nothing # hide
```

When the model is created, the Newton-Raphson method is initialized with the voltage magnitudes and angles defined in the original power system model. To warm-start it from the fast Newton-Raphson solution, we transfer the voltage magnitudes and angles:
```@example 4bus
setInitialPoint!(nr, fnr)
nothing # hide
```

We can now solve the AC power flow for this scenario:
```@example 4bus
powerFlow!(nr; power = true)
nothing # hide
```

To inspect the power flow distribution after the outage, we print the branch data:
```@example 4bus
printBranchData(nr; show = show2, fmt = fmt2)
```

Compared with the previous cases, the reactive power flow at the `Bus 1` side of `Branch 1` reverses because of the `Branch 3` outage, as shown in Figure 4.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_service_active.svg" class="my-svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/examples/acPowerFlow/4bus_service_reactive.svg" class="my-svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 4: Power flows in the 4-bus power system with modified network topology.
    </p>
</div>
```