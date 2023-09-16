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

