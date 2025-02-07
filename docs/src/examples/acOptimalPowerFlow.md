# [AC Optimal Power Flow](@id ACOptimalPowerFlowExamples)
This example performs multiple AC optimal power flow analyses on the power system shown in Figure 1. These simulations capture quasi-steady-state conditions under varying constraints and topology changes.
```@raw html
<div style="text-align: center;">
    <img src="../../assets/4busopt.svg" width="400"/>
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

Next, we define bus parameters for the AC optimal power flow analysis. This includes specifying the slack bus (`type = 3`), where the bus voltage angle is set to the default value of 0.0, along with the corresponding `active` and `reactive` power loads, and shunt capacitor banks with `conductance` and `susceptance` values. The voltage magnitude limits for each bus are set using `minMagnitude` and `maxMagnitude`. With these definitions, we can begin building the power system model:
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
First, we create the AC optimal power flow model and select the Ipopt solver. Next, we solve the model to calculate the bus voltages and the active and reactive power outputs of the generators. Afterward, we compute the remaining powers related to buses and branches:
```julia 4bus
JuMP.set_silent(analysis.method.jump)
solve!(system, analysis)
```
```@setup 4bus
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
JuMP.set_silent(analysis.method.jump)  # hide
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

Once the AC optimal power flow is solved, we can review the results related to buses, including the optimal bus voltage values:
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

For the obtained optimal values of bus voltages and generator outputs, the objective function, defined according to polynomial costs, reaches its minimum value:
```@example 4bus
JuMP.objective_value(analysis.method.jump)
```

Finally, we can also review the results related to branches:
```@example 4bus
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Thus, we obtained the active and reactive power flows, as illustrated in Figure 2.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acopt4bus_base_active.svg"/>
        <p>Figure 2a: Active power flows for the base case.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acopt4bus_base_reactive.svg"/>
        <p>Figure 2b: Reactive power flows for the base case.</p>
    </div>
</div>
```

---

## Modifying Cost Funstion
Now, we modify the cost function for `Generator 1`, updating both the power system model and the AC optimal power flow model simultaneously:
```@example 4bus
cost!(system, analysis; generator = "Generator 1", active = 2, polynomial = [2.00; 20.0; 0])
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
In this scenario, we can observe that due to the increased cost of `Generator 1`, `Generator 2` and `Generator 3` have increased their production to the maximum possible values to take advantage of the lower costs. The remaining required active power is provided by `Generator 1`.

We can also review the results related to buses and branches for this scenario:
```@example 4bus
printBusData(system, analysis; show = show1, fmt = fmt1)
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Figure 3 shows the active and reactive power flows for this scenario.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acopt4bus_cost_active.svg"/>
        <p>Figure 3a: Active power flows for the case with modifed generator cost.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acopt4bus_cost_reactive.svg"/>
        <p>Figure 3b: Reactive power flows for the case with modifed generator cost.</p>
    </div>
</div>
```

---

## Add Branch Flow Constraint
We now add an active power flow constraint to `Branch 3` using `type = 1`, where we limit the active power flow at the from-bus end with the `maxFromBus` keyword:
```@example 4bus
updateBranch!(system, analysis; label = "Branch 3", type = 1, maxFromBus = 15.0)
```

Next, we recalculate the AC optimal power flow:
```@example 4bus
solve!(system, analysis)
power!(system, analysis)
nothing # hide
```

We can then observe the updated results:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Compared to the previous scenario, the power flow limit at `Branch 3` forces `Generator 1` to increase active power output despite its higher cost, as shown in Figure 4a. Although one might expect `Generator 2` or `Generator 3` to supply more active power through `Branch 2` to reduce the contribution of `Generator 1`, this is not possible due to bus power balance constraints. Additionally, we also observe significant changes in reactive power flows under these new conditions, as illustrated in Figure 4b.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acopt4bus_flow_active.svg"/>
        <p>Figure 4a: Active power flows for the case with branch flow constraint.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acopt4bus_flow_reactive.svg"/>
        <p>Figure 4b: Reactive power flows for the case with branch flow constraint.</p>
    </div>
</div>
```

---

## Modifying Power System Topology
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

Next, we observe the updated results:
```@example 4bus
printGeneratorData(system, analysis; fmt = fmt3)
printBranchData(system, analysis; show = show2, fmt = fmt2)
```

Thus, `Generator 1` can no longer supply load at `Bus 2` due to the outage of `Branch 2` and the flow limit at `Branch 3`. This leads to a reduction in its output, while the only viable solution is to increase the output of `Generator 2` and `Generator 3`, as shown in Figure 5a.  Additionally, we also observe changes in reactive power flows under these new conditions, as illustrated in Figure 5b.
```@raw html
<div class="image-container">
    <div class="image-item">
        <img src="../../assets/acopt4bus_service_active.svg"/>
        <p>Figure 5a: Active power flows with modified power system topology.</p>
    </div>
    <div class="image-item">
        <img src="../../assets/acopt4bus_service_reactive.svg"/>
        <p>Figure 5b: Reactive power flows with modified power system topology.</p>
    </div>
</div>
```