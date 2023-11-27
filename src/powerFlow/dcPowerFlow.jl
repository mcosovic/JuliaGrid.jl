"""
    dcPowerFlow(system::PowerSystem, factorization::Factorization)

The function sets up the framework to solve the DC power flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. 
Moreover, the `Factorization` argument is optional and can be one of the following:
  * `LU`: solves the DC power flow problem in-place using LU factorization;
  * `LDLt`: solves the DC power flow problem using LDLt factorization;
  * `QR`: solves the DC power flow problem using QR factorization.
If the user does not provide the `Factorization` composite type, the default method for 
solving the DC power flow will be LU factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as the
first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCPowerFlow` composite type, which includes the
following fields:
- `voltage`: the variable allocated to store the bus voltage angles;
- `power`: the variable allocated to store the active powers;
- `method`: the factorized nodal matrix.

# Examples
Establish the DC power flow framework that will be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
```

Establish the DC power flow framework that will be solved using the QR factorization:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system, QR)
```
"""
function dcPowerFlow(system::PowerSystem, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    if system.bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(system.model.dc.nodalMatrix)
        dcModel!(system)
    end
    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)

    return DCPowerFlow(
        PolarAngle(Float64[]),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[])
        ),
        DCPowerFlowMethod(get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))), false)
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
    bus = system.bus

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftPower[i]
    end

    if !analysis.method.done
        dcPowerFlowFactorization(system, analysis)
    end
    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, b, analysis.method.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end

########### Nodal Matrix Factorization ###########
function dcPowerFlowFactorization(system::PowerSystem, analysis::DCPowerFlow)
    dc = system.model.dc
    bus = system.bus

    analysis.method.done = true

    slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

    analysis.method.factorization = sparseFactorization(dc.nodalMatrix, analysis.method.factorization)

    @inbounds for (k, i) in enumerate(slackRange)
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = elementsRemove[k]
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
    end 
end