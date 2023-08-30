# [AC Power Flow](@id ACPowerFlowManual)
To perform the AC power flow analysis, you will first need the `PowerSystem` composite type that has been created with the `ac` model. Then, you can create the `ACPowerFlow` abstract type using one of the following functions:
* [`newtonRaphson`](@ref newtonRaphson),
* [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX),
* [`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB),
* [`gaussSeidel`](@ref gaussSeidel).

These functions will set up the AC power flow framework. To obtain bus voltages and solve the power flow problem, you can use the following functions:
* [`mismatch!`](@ref mismatch!(::PowerSystem, ::NewtonRaphson)),
* [`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)).

After obtaining the AC power flow solution, JuliaGrid offers post-processing analysis functions for calculating powers and currents associated with buses, branches, or generators:
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::AC)).

Furthermore, there are specialized functions dedicated to calculating specific types of powers related to particular buses, branches, or generators:
* [`powerInjection`](@ref powerInjection(::PowerSystem, ::AC)),
* [`powerSupply`](@ref powerSupply(::PowerSystem, ::ACPowerFlow)),
* [`powerShunt`](@ref powerShunt(::PowerSystem, ::AC)),
* [`powerFrom`](@ref powerFrom(::PowerSystem, ::AC)),
* [`powerTo`](@ref powerTo(::PowerSystem, ::AC)),
* [`powerCharging`](@ref powerCharging(::PowerSystem, ::AC)),
* [`powerSeries`](@ref powerSeries(::PowerSystem, ::AC)),
* [`powerGenerator`](@ref powerGenerator(::PowerSystem, ::ACPowerFlow)).

Likewise, there are specialized functions dedicated to calculating specific types of currents related to particular buses or branches:
* [`currentInjection`](@ref currentInjection(::PowerSystem, ::AC)),
* [`currentFrom`](@ref currentFrom(::PowerSystem, ::AC)),
* [`currentTo`](@ref currentTo(::PowerSystem, ::AC)),
* [`currentSeries`](@ref currentSeries(::PowerSystem, ::AC)).

Additionally, the package provides two functions for reactive power limit validation of generators and adjusting the voltage angles to match an arbitrary bus angle:
* [`reactiveLimit!`](@ref reactiveLimit!),
* [`adjustAngle!`](@ref adjustAngle!).

---

