# [AC Power Flow](@id ACPowerFlowExamples)
In this example, we will perform several AC power flow analyses, effectively simulating quasi-steady-state conditions where the power system undergoes parameter and topology changes. These examples demonstrate JuliaGrid's efficiency in handling such scenarios.

Building on the previously created [minimal working power system dataset](@ref MinimalWorkingDatasetExamples), we first define the bus parameters for AC power flow analysis. This includes specifying the `type` of each bus and the connected `active` and `reactive` power loads. The initial bus voltage values default to `magnitude = 1.0` and `angle = 0.0`, but users can modify these values if needed:
```@setup 4bus
using JuliaGrid, JuMP, Ipopt # hide
@default(template) # hide
@default(unit) # hide

system = powerSystem()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBus!(system; label = "Bus 3")
addBus!(system; label = "Bus 4")

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.06)
addBranch!(system; label = "Branch 2", from = "Bus 1", to = "Bus 3", reactance = 0.22)
addBranch!(system; label = "Branch 3", from = "Bus 2", to = "Bus 3", reactance = 0.19)
addBranch!(system; label = "Branch 4", from = "Bus 2", to = "Bus 4", reactance = 0.32)

addGenerator!(system; label = "Generator 1", bus = "Bus 1")
addGenerator!(system; label = "Generator 2", bus = "Bus 3")

nothing # hide
```
```@example 4bus
updateBus!(system; label = "Bus 1", type = 3)
updateBus!(system; label = "Bus 2", type = 1, magnitude = 0.91, angle = -0.01)
updateBus!(system; label = "Bus 3", type = 2, active = 0.2, reactive = 0.1)
updateBus!(system; label = "Bus 4", type = 1, active = 0.5, reactive = 0.2)

nothing # hide
```

Next, we enhance the transmission line parameters by including additional details such as `resistance`, `susceptance`, and the transformer off-nominal turns ratio specified using the `turnsRatio` keyword:
```@example 4bus
updateBranch!(system; label = "Branch 1", resistance = 0.02, susceptance = 0.05)
updateBranch!(system; label = "Branch 2", resistance = 0.05, susceptance = 0.04)
updateBranch!(system; label = "Branch 3", resistance = 0.04, susceptance = 0.04)
updateBranch!(system; label = "Branch 4", turnsRatio = 0.98)

nothing # hide
```

Finally, we define the `active` and `reactive` power outputs of the generators and set the voltage magnitude setpoints, with the default value being `magnitude = 1.0` unless specified otherwise:
```@example 4bus
updateGenerator!(system; label = "Generator 1", active = 2.3, reactive = 0.4)
updateGenerator!(system; label = "Generator 2", active = 0.4, magnitude = 1.1)

nothing # hide
```

Now, we create an AC model that includes power system topology and parameters, as well as the nodal admittance matrix. Once generated for a specific power system, this model can be shared across different analyses and is automatically updated when power system data changes:
```@example 4bus
acModel!(system)

nothing # hide
```

!!! note "Info"
    Users can download a Julia script containing the scenarios from this section using the following [link](https://github.com/mcosovic/JuliaGrid.jl/raw/refs/heads/master/docs/src/examples/analyses/acPowerFlow.jl).

---

##### AC Power Flow Analysis Wrapper Function
We can define a wrapper function to perform AC power flow analysis. Using JuliaGrid's built-in functions, this function computes bus voltage magnitudes and angles. Once the algorithm converges, it then calculates the powers associated with buses, branches, and generators:
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
At the start, we use the fast Newton-Raphson XB method to solve the AC power flow. This method is chosen because we intend to modify generator and demand parameters. JuliaGrid efficiently reuses the factorization of Jacobian matrices in these cases, which significantly reduces computational complexity. Therefore, we define the model for this method:
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
printBusData(system, fnr; show = Dict("Shunt Power" => false))
```

Among the active and reactive power values, we now focus on the power flows at the from-bus and to-bus ends of the branches. The results are:
```@example 4bus
show = Dict("Shunt Power" => false, "Series Power" => false)
printBranchData(system, fnr; show)
```

---

## Modifying Generators and Demands
We will modify the active and reactive power outputs of the generators, as well as the active and reactive powers demanded by consumers. Instead of creating a new power system model or just updating the existing one, we will update both the power system model and the fast Newton-Raphson model simultaneously:
```@example 4bus
updateBus!(system, fnr; label = "Bus 3", type = 2, active = 0.3, reactive = 0.0)
updateBus!(system, fnr; label = "Bus 4", type = 1, active = 0.1, reactive = 0.1)

updateGenerator!(system, fnr; label = "Generator 1", active = 2.0, reactive = 0.2)
updateGenerator!(system, fnr; label = "Generator 2", active = 1.2, reactive = 0.2)

nothing # hide
```

Next, we run the AC power flow again to compute the new state of the power system, without having to recreate the fast Newton-Raphson model. Additionally, this step will start the fast Newton-Raphson method with a warm start, as the initial voltage magnitudes and angles will correspond to the solution from the base case analysis:
```@example 4bus
acPowerFlow!(system, fnr)
nothing # hide
```

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

When the model is created, we also initialize the method, with the starting voltage magnitudes and angles corresponding to the values defined when the power system model was first created. If we want to use the results from the fast Newton-Raphson method and start the Newton-Raphson method with a warm start, we can transfer the voltage magnitudes and angles:
```@example 4bus
transferVoltage!(fnr, nr)

nothing # hide
```

Now, we can solve the power flow and calculate the powers for this scenario:
```@example 4bus
acPowerFlow!(system, nr)
nothing # hide
```

To display how the power flow is distributed when one branch is out of service, we use the following:
```@example 4bus
printBranchData(system, nr; show)
```