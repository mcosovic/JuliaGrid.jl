"""
    dcPowerFlow(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the framework to solve the DC power flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `Factorization` argument, while optional, determines the method used to solve the
linear system of equations. It can take one of the following values:
- `LU`: utilizes LU factorization (default),
- `LDLt`: utilizes LDLt factorization,
- `QR`: utilizes QR factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as
the first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCPowerFlow` type, which includes the following
fields:
- `voltage`: The variable allocated to store the bus voltage angles.
- `power`: The variable allocated to store the active powers.
- `method`: The factorized nodal matrix.

# Examples
Set up the DC power flow utilizing LU factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
```

Set up the DC power flow utilizing QR factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system, QR)
```
"""
function dcPowerFlow(system::PowerSystem, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    checkSlackBus(system)
    model!(system, system.model.dc)
    changeSlackBus!(system)

    DCPowerFlow(
        PolarAngle(
            Float64[]
        ),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[])
        ),
        DCPowerFlowMethod(
            factorized[factorization],
            -1,
            -1
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::DCPowerFlow)

The function solves the DC power flow model and calculates bus voltage angles.

# Updates
The calculated voltage angles are stored in the `voltage` field of the `DCPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCPowerFlow)
    bus = system.bus
    slack = bus.layout.slack
    dc = system.model.dc
    nodal = dc.nodalMatrix
    pf = analysis.method

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftPower[i]
    end

    if dc.model != pf.dcmodel
        pf.dcmodel = copy(dc.model)

        slackRange = nodal.colptr[slack]:(nodal.colptr[slack + 1] - 1)
        elementsRemove = nodal.nzval[slackRange]
        @inbounds for i in slackRange
            nodal[nodal.rowval[i], slack] = 0.0
            nodal[slack, nodal.rowval[i]] = 0.0
        end
        nodal[slack, slack] = 1.0

        if dc.pattern != pf.pattern
            pf.pattern = copy(dc.pattern)
            pf.factorization = factorization(nodal, pf.factorization)
        else
            pf.factorization = factorization!(nodal, pf.factorization)
        end

        @inbounds for (k, i) in enumerate(slackRange)
            nodal[nodal.rowval[i], slack] = elementsRemove[k]
            nodal[slack, nodal.rowval[i]] = elementsRemove[k]
        end
    end

    analysis.voltage.angle = solution(analysis.voltage.angle, b, pf.factorization)

    analysis.voltage.angle[slack] = 0.0
    if bus.voltage.angle[slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[slack]
        end
    end
end

"""
    powerFlow!(system::PowerSystem, analysis::DCPowerFlow, [io::IO]; power, verbose)

The function serves as a wrapper for solving DC power flow and includes the functions:
* [`solve!`](@ref solve!(::PowerSystem, ::DCPowerFlow)),
* [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)).

It computes bus voltage angles and optionally calculates power values.

# Keyword
Users can use the following keywords:
* `power`: Enables the computation of powers (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

To redirect the output display, users can pass the `IO` object as the last argument.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
powerFlow!(system, analysis; power = true, verbose = 1)
```
"""
function powerFlow!(
    system::PowerSystem,
    analysis::DCPowerFlow,
    io::IO = stdout;
    power::Bool = false,
    verbose::Int64 = template.config.verbose
)
    printTop(system, analysis, verbose, io)
    printMiddle(system, analysis, verbose, io)

    solve!(system, analysis)

    printExit(analysis, verbose, io)

    if power
        power!(system, analysis)
    end
end