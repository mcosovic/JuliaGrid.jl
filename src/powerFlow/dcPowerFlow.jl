export DCPowerFlow

######### DC Power Flow ##########
struct DCPowerFlow <: DCAnalysis
    voltage::PolarAngle
    power::DCPower
    factorization::Union{Factorization, Diagonal}
end

"""
    dcPowerFlow(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input, which is utilized to establish
the structure for solving the DC power flow.

If the DC model was not created, the function will automatically initiate an update of the
`dcModel` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as the
first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCPowerFlow` type, which includes the following 
filled fields:
- `voltage`: the variable allocated to store the bus voltage angles,
- `power`: the variable allocated to store the active powers,
- `factorization`: the factorized nodal matrix.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
```
"""
function dcPowerFlow(system::PowerSystem)
    dc = system.dcModel
    bus = system.bus

    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end

    if bus.supply.inService[bus.layout.slack] == 0
        changeSlackBus!(system)
    end

    slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

    factorization = factorize(dc.nodalMatrix)
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
        factorization
    )
end

"""
    solve!(system::PowerSystem, model::DCPowerFlow)

By computing the bus voltage angles, the function solves the DC power flow problem.
The resulting bus voltage angles are stored in the `voltage` field of the `DCPowerFlow` 
type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)
```
"""
function solve!(system::PowerSystem, model::DCPowerFlow)
    bus = system.bus

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.dcModel.shiftActivePower[i]
    end

    model.voltage.angle = model.factorization \ b
    model.voltage.angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            model.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end