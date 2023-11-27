# [DC State Estimation](@id DCStateEstimationManual)
To perform the DC power flow, you first need to have the `PowerSystem` composite type that has been created with the `dc` model, alongside the `Measurement` composite type that retains measurement data. Subsequently, we can formulate the DC state estimation model encapsulated within the abstract type `DCStateEstimation` using the subsequent function:
* [`dcStateEstimation`](@ref dcStateEstimation).

For resolving the DC state estimation problem employing either the weighted least-squares (WLS) or the least absolute value (LAV) approach and obtaining bus voltage angles, utilize the following function:
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimationWLS)).

After obtaining the solution for DC state estimation, JuliaGrid offers a post-processing analysis function to compute active powers associated with buses, branches, and generators:
* [`power!`](@ref power!(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})).

Additionally, there are specialized functions dedicated to calculating specific types of active powers related to particular buses, branches, or generators:
* [`injectionPower`](@ref injectionPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})),
* [`supplyPower`](@ref supplyPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})),
* [`fromPower`](@ref fromPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})),
* [`toPower`](@ref toPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})),
* [`generatorPower`](@ref generatorPower(::PowerSystem, ::Union{DCPowerFlow, DCStateEstimation})).

It is important to note that when JuliaGrid computes powers related to generators, it utilizes bus voltage angles along with provided generator data within the `PowerSystem` composite type. This might be perceived as constraining, considering the power system is monitored solely through measurement data. Nevertheless, users are allowed the possibility to reveal powers associated with generators.

---

## [Bus Type Modification](@id DCSEBusTypeModificationManual)
Similar to the explanation provided in the [Bus Type Modification](@ref DCBusTypeModificationManual) section, when executing the [`dcStateEstimation`](@ref dcStateEstimation) function, the initially designated slack bus undergoes evaluation and may be adjusted. If the bus designated as the slack bus (`type = 3`) lacks a connected in-service generator, its type will be changed to the demand bus (`type = 1`). Conversely, the first generator bus (`type = 2`) with an active in-service generator linked to it will be reassigned as the new slack bus (`type = 3`).








