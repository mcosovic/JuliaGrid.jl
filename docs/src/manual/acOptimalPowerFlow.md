# [AC Optimal Power Flow](@id ACOptimalPowerFlowManual)

JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the AC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `acModel`. After that, create the `Model` composite type to establish the AC optimal power flow framework using the function:
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow).

To solve the AC optimal power flow problem and acquire bus voltage magnitudes and angles, and generator active and reactive power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)).

After obtaining the AC optimal power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses, branches, or generators:
* [`power`](@ref power(::PowerSystem, ::ACOptimalPowerFlow)),
* [`current`](@ref current(::PowerSystem, ::ACOptimalPowerFlow)).

Moreover, there exist specific functions dedicated to calculating powers and currents related to a particular bus, branch, or generator:
* [`powerBus`](@ref powerBus(::PowerSystem, ::ACOptimalPowerFlow)),
* [`powerBranch`](@ref powerBranch(::PowerSystem, ::ACOptimalPowerFlow)),
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACOptimalPowerFlow)),
* [`currentBus`](@ref currentBus(::PowerSystem, ::ACOptimalPowerFlow)),
* [`currentBranch`](@ref currentBranch(::PowerSystem, ::ACOptimalPowerFlow)).

---

## [Optimization Variables](@id ACOptimizationVariablesManual)
To set up the AC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
```@example ACOptimalPowerFlow
using JuliaGrid # hide
using JuMP, HiGHS # hide

system = powerSystem()

@bus(magnitude = 1.0)
addBus!(system; label = 1, type = 3, magnitude = 1.01, angle = 0.17)
addBus!(system; label = 2, type = 2, active = 0.1, conductance = 0.04)
addBus!(system; label = 3, type = 1, active = 0.05)

@branch(minDiffAngle = -pi, maxDiffAngle = pi)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.05, longTerm = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 0.01, longTerm = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 0.01, longTerm = 0.25)

addGenerator!(system; label = 1, bus = 1, active = 3.2, minActive = 0.0, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, minActive = 0.0, maxActive = 0.2)

addActiveCost!(system; label = 1, model = 2, polynomial = [1100.2; 500; 80])
addActiveCost!(system; label = 2, model = 1, piecewise =  [10.85 12.3; 14.77 16.8; 18 18.1])

acModel!(system)

model = acOptimalPowerFlow(system, HiGHS.Optimizer)

nothing # hide
```
