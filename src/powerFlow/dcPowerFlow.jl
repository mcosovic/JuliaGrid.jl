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

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return DCPowerFlow(
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
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
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
    dc = system.model.dc

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftPower[i]
    end

    if system.model.dc.model != analysis.method.dcmodel
        analysis.method.dcmodel = copy(system.model.dc.model)

        slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
        elementsRemove = dc.nodalMatrix.nzval[slackRange]
        @inbounds for i in slackRange
            dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
            dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
        end
        dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

        if dc.pattern != analysis.method.pattern
            analysis.method.pattern = copy(system.model.dc.pattern)
            analysis.method.factorization = sparseFactorization(dc.nodalMatrix, analysis.method.factorization)
        else
            analysis.method.factorization = sparseFactorization!(dc.nodalMatrix, analysis.method.factorization)
        end

        @inbounds for (k, i) in enumerate(slackRange)
            dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = elementsRemove[k]
            dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
        end
    end

    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, b, analysis.method.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end