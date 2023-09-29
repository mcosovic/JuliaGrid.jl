"""
    dcPowerFlow(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input, which is utilized to establish
the structure for solving the DC power flow.

If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as the
first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCPowerFlow` composite type, which includes the
following fields:
- `voltage`: the variable allocated to store the bus voltage angles;
- `power`: the variable allocated to store the active powers;
- `factorization`: the factorized nodal matrix.
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
```
"""
function dcPowerFlow(system::PowerSystem)
    dc = system.model.dc
    bus = system.bus

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end

    if isempty(bus.supply.generator[bus.layout.slack])
        changeSlackBus!(system)
    end

    slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

    nondiagonalMatrix = false
    @inbounds for i = 1:bus.number
        if dc.nodalMatrix.rowval[i] != i
            nondiagonalMatrix = true
            break
        end
    end

    if nondiagonalMatrix
        factorization = factorize(dc.nodalMatrix)
    else
        factorization = cholesky(dc.nodalMatrix)
    end

    @inbounds for (k, i) in enumerate(slackRange)
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = elementsRemove[k]
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
    end

    return DCPowerFlow(
        PolarAngle(Float64[]),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[])
        ),
        factorization,
        system.uuid
    )
end

"""
    solve!(system::PowerSystem, analysis::DCPowerFlow)

By computing the bus voltage angles, the function solves the DC power flow problem.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DCPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCPowerFlow)
    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftPower[i]
    end

    analysis.voltage.angle = analysis.factorization \ b
    analysis.voltage.angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end