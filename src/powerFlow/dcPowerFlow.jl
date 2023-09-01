######### DC Power Flow ##########
struct DCPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    factorization::SuiteSparse.CHOLMOD.Factor{Float64}
    uuid::UUID
end

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

    setting[system.uuid.value]["dcPowerFlow"] = 1

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
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftActivePower[i]
    end

    analysis.voltage.angle = analysis.factorization \ b
    analysis.voltage.angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end

######### Query About Bus ##########
function addBus!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    checkUUID(system.uuid, analysis.uuid)
    throw(ErrorException("The DCPowerFlow cannot be reused when adding a new bus."))
end

######### Query About Deamnd Bus ##########
function demandBus!(system::PowerSystem, analysis::DCPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    demandBus!(system::PowerSystem; user...)
end

######### Query About Shunt Bus ##########
function shuntBus!(system::PowerSystem, analysis::DCPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    shuntBus!(system::PowerSystem; user...)
end

######### Query About Branch ##########
function addBranch!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    checkUUID(system.uuid, analysis.uuid)
    throw(ErrorException("The DCPowerFlow cannot be reused when adding a new branch."))
end

######### Query About Status Branch ##########
function statusBranch!(system::PowerSystem, analysis::DCPowerFlow; label::L, status::T)
    checkUUID(system.uuid, analysis.uuid)
    throw(ErrorException("The DCPowerFlow cannot be reused when the branch status is altered."))
end

######### Query About Parameter Branch ##########
function parameterBranch!(system::PowerSystem, analysis::DCPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    throw(ErrorException("The DCPowerFlow cannot be reused when the branch parameters are altered."))
end

######### Query About Generator ##########
function addGenerator!(system::PowerSystem, analysis::DCPowerFlow;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)
    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

######### Query About Status Generator ##########
function statusGenerator!(system::PowerSystem, analysis::DCPowerFlow; label::L, status::Int64 = 0)
    checkUUID(system.uuid, analysis.uuid)
    checkStatus(status)
    statusGenerator!(system; label, status)

    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end
end

######### Query About Output Generator ##########
function outputGenerator!(system::PowerSystem, analysis::DCPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    outputGenerator!(system; user...)
end