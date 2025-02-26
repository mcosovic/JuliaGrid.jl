# [AC Power Flow](@id ACPowerFlowExamples)
In this example, we perform several AC power flow analyses using the power system shown in Figure 1. These analyses simulate quasi-steady-state conditions where the system undergoes parameter and topology changes, demonstrating JuliaGrid's efficiency in handling such scenarios.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/acPowerFlow/4bus.svg" width="400"/>
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

Next, we define the bus parameters for AC power flow analysis This includes specifying the `type` of each bus, the connected `active` and `reactive` power loads, and shunt capacitor banks with `conductance` and `susceptance` values. The bus voltage `magnitude` and `angle` serve as initial values for the iterative power flow algorithm. Note that for the slack bus (`type = 3`), the angle is fixed to the specified value. With these definitions, we can start to build the power system model:
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

Finally, we define the `active` and `reactive` power outputs of the generators and set the voltage `magnitude` setpoints. These setpoints fix the voltage magnitudes for the slack bus (`type = 3`) and generator buses (`type = 2`):
```@example 4bus
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 60.1, reactive = 40.2,  magnitude = 0.98)
addGenerator!(system; bus = "Bus 2", active = 18.2, magnitude = 1.01)

nothing # hide
```


After defining the power system data, we generate an AC model that includes essential vectors and matrices for analysis, such as the nodal admittance matrix. This model is automatically updated with data changes and can be shared across different analyses:
```@example 4bus
acModel!(system)

nothing # hide
```

---

##### AC Power Flow Analysis Wrapper Function
Throughout the simulations below, AC power flow is run multiple times. To avoid repeatedly calling multiple JuliaGrid built-in functions, we define a wrapper function that performs the AC power flow analysis, allowing us to call a single function each time. This wrapper function computes bus voltage magnitudes and angles. Once the algorithm converges, it then calculates the powers at buses, branches, and generators:
```@example 4bus
function acPowerFlow!(system::PowerSystem, analysis::ACPowerFlow)
    for iteration = 1:20
        stopping = mismatch!(system, analysis)
        if all(stopping .< 1e-8)
            println("The algorithm converged in $(iteration - 1) iterations.")
            break
        end
        solve!(system, analysis)
    end
    power!(system, analysis)
end
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

---

## Base Case Analysis
At the start, we use the fast Newton-Raphson XB method to solve the AC power flow:
```@example 4bus
fnr = fastNewtonRaphsonXB(system)
nothing # hide
```

Next, we run the iterative algorithm to calculate bus voltages and active and reactive powers:
```@example 4bus
acPowerFlow!(system, fnr)
nothing # hide
```

Once the AC power flow is solved, we can analyze the results related to the buses. For instance:
```@example 4bus
printBusData(system, fnr; show = show1, fmt = fmt1)
```

Similarly, the results for branches are:
```@example 4bus
printBranchData(system, fnr; show = show2, fmt = fmt2)
```

Thus, using bus and branch data, we obtained the active and reactive power flows, as illustrated in Figure 2.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_base_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_base_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 2: Power flows in the 4-bus power system for the base case scenario.
    </p>
</div>
&nbsp;
```

Additionally, the branch data shows the series power losses, which result from the series resistance and reactance of each branch. Note that the active power at the from-bus and to-bus ends of a branch differs by the active power loss. However, this does not apply to reactive power, as branch susceptances provide partial compensation.

---

## Modifying Supplies and Demands
We will modify the active and reactive power outputs of the generators, as well as the active and reactive powers demanded by consumers. Instead of creating a new power system model or just updating the existing one, we will update both the power system model and the fast Newton-Raphson model simultaneously:
```@example 4bus
updateBus!(system, fnr; label = "Bus 2", active = 25.5, reactive = 15.0)
updateBus!(system, fnr; label = "Bus 4", active = 42.0, reactive = 20.0)

updateGenerator!(system, fnr; label = "Generator 1", active = 58.0, reactive = 20.0)
updateGenerator!(system, fnr; label = "Generator 2", active = 23.1, reactive = 20.0)

nothing # hide
```

Next, we run the AC power flow again to compute the new state of the power system, without having to recreate the fast Newton-Raphson model. Additionally, this step will start the fast Newton-Raphson method with a warm start, as the initial voltage magnitudes and angles will correspond to the solution from the base case analysis:
```@example 4bus
acPowerFlow!(system, fnr)
nothing # hide
```
Since no power system changes were introduced that affect the Jacobian matrices, JuliaGrid reuses the Jacobian matrix factorizations from the base case analysis, significantly reducing computational complexity.

Finally, we can display the relevant data:
```@example 4bus
printBranchData(system, fnr; show = show2, fmt = fmt2)
```

Compared to the base case, the directions of active power flows remain unchanged, but their magnitudes differ. For reactive power, the values change, and the flow at `Branch 1` on the `Bus 1` side reverses, as shown in Figure 3.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_power_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_power_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 3: Power flows in the 4-bus power system with modified supplies and demands.
    </p>
</div>
```

---

## Modifying Network Topology
Next, we will take `Branch 3` out of service. Although we could update the power system model and the fast Newton-Raphson method simultaneously, to demonstrate flexibility, we will solve this scenario using the Newton-Raphson method. As a result, we will only update the power system model:
```@example 4bus
updateBranch!(system; label = "Branch 3", status = 0)

nothing # hide
```

Now, let us define the Newton-Raphson model:
```@example 4bus
nr = newtonRaphson(system)
nothing # hide
```

When the model is created, we also initialize the Newton-Raphson method, with the initial voltage magnitudes and angles corresponding to the values defined when the power system model was first created. If we want to use the results from the fast Newton-Raphson method and start the Newton-Raphson method with a warm start, we can transfer the voltage magnitudes and angles:
```@example 4bus
setInitialPoint!(fnr, nr)
nothing # hide
```

Now, we can solve the AC power flow for this scenario:
```@example 4bus
acPowerFlow!(system, nr)
nothing # hide
```

To display how the power flows are distributed when one branch is out of service, we use the following:
```@example 4bus
printBranchData(system, nr; show = show2, fmt = fmt2)
```

Compared to the previous cases, we observe that the reactive power flow at `Branch 1` on the `Bus 1` side reverses direction due to the outage of `Branch 3`, as shown in Figure 4.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_service_active.svg"/>
        <p>(a) Active powers.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acPowerFlow/4bus_service_reactive.svg"/>
        <p>(b) Reactive powers.</p>
    </div>
    <p style="text-align: center; margin-top: -5px;">
    Figure 4: Power flows in the 4-bus power system with modified network topology.
    </p>
</div>
```