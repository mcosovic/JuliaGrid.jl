# [AC Power Flow](@id ACPowerFlowExamples)
In this example, we perform several AC power flow analyses using the power system shown in Figure 1. These analyses simulate quasi-steady-state conditions where the system undergoes parameter and topology changes, demonstrating JuliaGrid's efficiency in handling such scenarios.

```@raw html
<img src="../../assets/example_4bus.svg" class="center" width="500"/>
<figcaption>Figure 1: The 4-bus power system.</figcaption>
&nbsp;
```

We begin by defining the units for active and reactive power, as well as voltage magnitude and angle, which will be used throughout this example:
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
addBus!(system; label = "Bus 2", type = 1, conductance = 0.1, susceptance = 18.2)
addBus!(system; label = "Bus 3", type = 2, active = 20.2, reactive = 10.5)
addBus!(system; label = "Bus 4", type = 1, active = 50.8, reactive = 23.1)

nothing # hide
```

Next, we refine the transmission line parameters by adding `resistance`, `reactance`, and `susceptance` values. Additionally, for transformers, we specify the off-nominal turns ratio using the `turnsRatio` keyword:
```@example 4bus

@branch(label = "Branch ?", reactance = 0.22)
addBranch!(system; from = "Bus 1", to = "Bus 2", resistance = 0.02, susceptance = 0.05)
addBranch!(system; from = "Bus 1", to = "Bus 3", resistance = 0.05, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 3", resistance = 0.04, susceptance = 0.04)
addBranch!(system; from = "Bus 2", to = "Bus 4", turnsRatio = 0.98)

nothing # hide
```

Finally, we define the `active` and `reactive` power outputs of the generators and set the voltage `magnitude` setpoints. These setpoints fix the voltage magnitudes for the slack bus (`type = 3`) and generator buses (`type = 2`):
```@example 4bus
@generator(label = "Generator ?")
addGenerator!(system; bus = "Bus 1", active = 80.1, reactive = 50.2,  magnitude = 0.98)
addGenerator!(system; bus = "Bus 3", active = 48.2, magnitude = 1.1)

nothing # hide
```


After defining the power system data, we generate an AC model that includes essential vectors and matrices for analysis, such as the nodal admittance matrix. This model is automatically updated with data changes and can be shared across different analyses:
```@example 4bus
acModel!(system)

nothing # hide
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acPowerFlow.jl).


----

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

Before displaying the data, we can select which information will be shown and which will be hidden:
```@example 4bus
show = Dict("Power Injection" => false, "Shunt Power" => false, "Series Power" => false)
nothing # hide
```

Once the AC power flow is solved, we can analyze the results related to the buses. For instance:
```@example 4bus
printBusData(system, fnr; show)
```

Similarly, the results for branches are:
```@example 4bus
printBranchData(system, fnr; show)
```

---

## Modifying Generators and Demands
We will modify the active and reactive power outputs of the generators, as well as the active and reactive powers demanded by consumers. Instead of creating a new power system model or just updating the existing one, we will update both the power system model and the fast Newton-Raphson model simultaneously:
```@example 4bus
updateBus!(system, fnr; label = "Bus 3", type = 2, active = 25.5, reactive = 15.0)
updateBus!(system, fnr; label = "Bus 4", type = 1, active = 42.0, reactive = 20.0)

updateGenerator!(system, fnr; label = "Generator 1", active = 60.0, reactive = 20.0)
updateGenerator!(system, fnr; label = "Generator 2", active = 45.1, reactive = 20.0)

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
printBranchData(system, fnr; show)
```

---

## Modifying Power System Topology
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

When the model is created, we also initialize the Newton-Raphson method, with the starting voltage magnitudes and angles corresponding to the values defined when the power system model was first created. If we want to use the results from the fast Newton-Raphson method and start the Newton-Raphson method with a warm start, we can transfer the voltage magnitudes and angles:
```@example 4bus
transferVoltage!(fnr, nr)

nothing # hide
```

Now, we can solve the AC power flow for this scenario:
```@example 4bus
acPowerFlow!(system, nr)
nothing # hide
```

To display how the power flows are distributed when one branch is out of service, we use the following:
```@example 4bus
printBranchData(system, nr; show)
```