"""
    dcPowerFlow(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the framework to solve the DC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations. It can
take one of the following values:
- `LL`: Utilizes Cholesky factorization.
- `LDLt`: Utilizes LDLt factorization.
- `LU`: Utilizes LU factorization (default).
- `KLU`: Utilizes KLU factorization.
- `QR`: Utilizes QR factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the `dc` field
within the `PowerSystem` composite type. Additionally, if the slack bus lacks an in-service generator,
JuliaGrid considers it a mistake and defines a new slack bus as the first generator bus with an
in-service generator in the bus type list.

# Returns
The function returns an instance of the [`DcPowerFlow`](@ref DcPowerFlow) type.

# Examples
Set up the DC power flow utilizing LU factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
```

Set up the DC power flow utilizing KLU factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system, KLU)
```
"""
function dcPowerFlow(system::PowerSystem, ::Type{T} = LU) where {T <: Union{LL, LDLt, LU, KLU, QR}}
    checkSlackBus(system)
    model!(system, system.model.dc)
    changeSlackBus!(system)

    DcPowerFlow(
        Angle(
            Float64[]
        ),
        DcPower(
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[])
        ),
        DcPowerFlowMethod{T}(
            selectFactorization(T),
            Float64[],
            DcPowerFlowSignature(
                copy(system.model.revision.topology),
                -1,
                -1,
                copy(system.model.revision.slack)
            )
        ),
        system
    )
end

"""
    solve!(analysis::DcPowerFlow)

The function solves the DC power flow model and calculates bus voltage angles.

# Updates
The calculated voltage angles are stored in the `voltage` field of the `DcPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)
```
"""
function solve!(analysis::DcPowerFlow{T}) where T
    system = analysis.system
    bus = system.bus
    dc = system.model.dc
    revision = system.model.revision
    pf = analysis.method

    resize!(pf.rhs, bus.number)
    @inbounds for i = 1:bus.number
        pf.rhs[i] = bus.supply.active[i] -
            bus.demand.active[i] - bus.shunt.conductance[i] - dc.shiftPower[i]
    end

    if revision.topology != pf.signature.topology
        errorTypeConversion()
    end

    slackChanged = revision.slack != pf.signature.slack
    if revision.dcModel != pf.signature.dcModel || slackChanged
        pf.signature.dcModel = copy(revision.dcModel)
        pf.signature.slack = copy(revision.slack)

        removeIdx, removeVal = removeRowColumn(dc.nodalMatrix, bus.layout.slack)
        dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

        if revision.dcPattern == pf.signature.dcPattern && !slackChanged
            pf.factorization = factorization!(dc.nodalMatrix, pf.factorization, T)
        else
            pf.signature.dcPattern = copy(revision.dcPattern)
            pf.factorization = factorization(dc.nodalMatrix, pf.factorization, T)
        end

        restoreRowColumn!(dc.nodalMatrix, removeIdx, removeVal, bus.layout.slack)
    end

    fillState!(analysis.voltage, bus.number)
    solution!(analysis.voltage.angle, pf.factorization, pf.rhs)

    addSlackAngle!(system, analysis)
end

"""
    powerFlow!(analysis::DcPowerFlow; power, verbose)

The function serves as a wrapper for solving DC power flow and includes the functions:
* [`solve!`](@ref solve!(::DcPowerFlow{T}) where T),
* [`power!`](@ref power!(::DcPowerFlow)).

It computes bus voltage angles and optionally calculates power values.

# Keywords
Users can use the following keywords:
* `power`: Enables the computation of powers (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
powerFlow!(analysis; power = true, verbose = 1)
```
"""
function powerFlow!(
    analysis::DcPowerFlow;
    power::Bool = false,
    verbose::Int64 = template.config.verbose
)
    system = analysis.system

    printTop(system, analysis, verbose)
    printMiddle(system, analysis, verbose)

    solve!(analysis)

    printExit(analysis, verbose)

    if power
        power!(analysis)
    end
end
