# [AC Optimal Power Flow](@id ACOptimalPowerFlowManual)

JuliaGrid utilizes the [JuMP](https://jump.dev/JuMP.jl/stable/) package to construct optimal power flow models, allowing users to manipulate these models using the standard functions provided by JuMP. As a result, JuliaGrid supports popular [solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/) mentioned in the JuMP documentation to solve the optimization problem.

To perform the AC optimal power flow, you first need to have the `PowerSystem` composite type that has been created with the `ac` model. After that, create the `ACOptimalPowerFlow` composite type to establish the AC optimal power flow framework using the function:
* [`acOptimalPowerFlow`](@ref acOptimalPowerFlow).

To solve the AC optimal power flow problem and acquire bus voltage magnitudes and angles, and generator active and reactive power outputs, make use of the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)).

After obtaining the AC optimal power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses and branches:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::ACPowerFlow)).

Furthermore, there are specialized functions dedicated to calculating specific types of powers related to particular buses, branches, or generators:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::AC)),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::ACPowerFlow)),
* [`shuntPower`](@ref shuntPower(::PowerSystem, ::AC)),
* [`fromPower`](@ref fromPower(::PowerSystem, ::AC)),
* [`toPower`](@ref toPower(::PowerSystem, ::AC)),
* [`seriesPower`](@ref seriesPower(::PowerSystem, ::AC)),
* [`chargingPower`](@ref chargingPower(::PowerSystem, ::AC)),
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::ACPowerFlow)).

Likewise, there are specialized functions dedicated to calculating specific types of currents related to particular buses or branches:
* [`injectionCurrent`](@ref injectionCurrent(::PowerSystem, ::AC)),
* [`fromCurrent`](@ref fromCurrent(::PowerSystem, ::AC)),
* [`toCurrent`](@ref toCurrent(::PowerSystem, ::AC)),
* [`seriesCurrent`](@ref seriesCurrent(::PowerSystem, ::AC)).

---

## [Optimal Power Flow Model](@id ACOptimalPowerFlowModelManual)
To set up the AC optimal power flow, we begin by creating the model. To illustrate this, consider the following example:
```@example ACOptimalPowerFlow
using JuliaGrid # hide
using JuMP, Ipopt
@default(unit) # hide
@default(template) # hide

system = powerSystem()

@bus(minMagnitude = 0.9, maxMagnitude = 1.1)
addBus!(system; label = 1, type = 3, magnitude = 1.05, angle = 0.17)
addBus!(system; label = 2, active = 0.1, reactive = 0.01, conductance = 0.04)
addBus!(system; label = 3, active = 0.05, reactive = 0.02)

@branch(minDiffAngle = -pi, maxDiffAngle = pi, resistance = 0.5, susceptance = 0.01)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 1.0, longTerm = 0.15)
addBranch!(system; label = 2, from = 1, to = 3, reactance = 1.0, longTerm = 0.10)
addBranch!(system; label = 3, from = 2, to = 3, reactance = 1.0, longTerm = 0.25)

@generator(minActive = 0.0, minReactive = -0.1, maxReactive = 0.1)
addGenerator!(system; label = 1, bus = 1, active = 3.2, reactive = 0.5, maxActive = 0.5)
addGenerator!(system; label = 2, bus = 2, active = 0.2, reactive = 0.1, maxActive = 0.2)

cost!(system; label = 1, active = 2, polynomial = [1100.2; 500; 80])
cost!(system; label = 2, active = 1, piecewise =  [10.8 12.3; 14.7 16.8; 18 18.1])

cost!(system; label = 1, reactive = 2, polynomial = [0.5])
cost!(system; label = 2, reactive = 1, piecewise = [2.8 6.3; 3.7 8.8; 18 18.1])

acModel!(system)

nothing # hide
```

