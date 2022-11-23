######### General Struct ##########
mutable struct PolarAngle
    angle::Array{Float64,1}
end

mutable struct CartesianReal
    active::Array{Float64,1}
end

######### Bus ##########
mutable struct DCBusPower
    injection::CartesianReal
    supply::CartesianReal
end

mutable struct DCBus
    voltage::PolarAngle
    power::DCBusPower
end

######### Branch ##########
mutable struct DCBranchPower
    fromBus::CartesianReal
    toBus::CartesianReal
end

mutable struct DCBranch
    power::DCBranchPower
end

######### Generator ##########
mutable struct DCGenerator
    power::CartesianReal
end

######### DC Power Flow ##########
struct DCResult
    bus::DCBus
    branch::DCBranch
    generator::DCGenerator
end

"""
The function solves the DC power flow problem by determining the bus voltage angles,
and returns the composite type `DCResult`.

    dcPowerFlow(system::PowerSystem)

The function affects field `result.bus.voltage.angle`.

# Example
```jldoctest
system = powerSystem("case14.h5")
result = dcPowerFlow(system)
```
"""
function dcPowerFlow(system::PowerSystem)
    dc = system.dcModel
    bus = system.bus
    slack = bus.layout.slackIndex

    slackRange = dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], slack] = 0.0
        dc.nodalMatrix[slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[slack, slack] = 1.0

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftActivePower[i]
    end

    angle = dc.nodalMatrix \ b
    angle[slack] = 0.0

    if bus.voltage.angle[slack] != 0.0
        @inbounds for i = 1:bus.number
            angle[i] += bus.voltage.angle[slack]
        end
    end

    @inbounds for (k, i) in enumerate(slackRange)
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], slack] = elementsRemove[k]
        dc.nodalMatrix[slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
    end

    return DCResult(
        DCBus(PolarAngle(angle), DCBusPower(CartesianReal(Float64[]), CartesianReal(Float64[]))),
        DCBranch(DCBranchPower(CartesianReal(Float64[]), CartesianReal(Float64[]))),
        DCGenerator(CartesianReal(Float64[]))
        )
end

"""
The function computes active power flow for each branch according to the solution of the
DC power flow analysis.

    branch!(system::PowerSystem, result::DCResult)

The function affects field `result.branch.power`.

# Example
```jldoctest
branch!(system, result)
```
"""
function branch!(system::PowerSystem, result::DCResult)
    dc = system.dcModel
    branch = system.branch

    power = result.branch.power
    voltage = result.bus.voltage
    errorVoltage(voltage.angle)

    power.fromBus.active = copy(dc.admittance)
    power.toBus.active = similar(dc.admittance)
    @inbounds for i = 1:branch.number
        power.fromBus.active[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        power.toBus.active[i] = -power.fromBus.active[i]
    end
end

"""
The function computes active power injection and total supply of the generators for each bus according to the solution of the DC power flow analysis.

    bus!(system::PowerSystem, result::DCResult)

The function affects field `result.bus.power`.

# Example
```jldoctest
bus!(system, result)
```
"""
function bus!(system::PowerSystem, result::DCResult)
    dc = system.dcModel
    bus = system.bus
    slack = bus.layout.slackIndex

    power = result.bus.power
    voltage = result.bus.voltage
    errorVoltage(voltage.angle)

    power.supply.active = copy(bus.supply.active)
    power.injection.active = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        power.injection.active[i] -= bus.demand.active[i]
    end

    power.injection.active[slack] = bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        power.injection.active[slack] += dc.nodalMatrix[row, slack] * voltage.angle[row]
    end
    power.supply.active[slack] = bus.demand.active[slack] + power.injection.active[slack]
end

"""
The function computes active power output for each generator according to the solution of the
DC power flow analysis.

    generator!(system::PowerSystem, result::DCResult)

The function affects field `result.generator.power`.

# Example
```jldoctest
generator!(system, result)
```
"""
function generator!(system::PowerSystem, result::DCResult)
    dc = system.dcModel
    generator = system.generator
    bus = system.bus
    slack = bus.layout.slackIndex

    power = result.generator.power
    voltage = result.bus.voltage
    errorVoltage(voltage.angle)

    if isempty(result.bus.power.supply.active)
        supplySlack = bus.demand.active[slack] + bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
        @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            supplySlack += dc.nodalMatrix[row, slack] * voltage.angle[row]
        end
    else
        supplySlack = result.bus.power.supply.active[slack]
    end

    power.active = fill(0.0, generator.number)
    tempSlack = 0
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            power.active[i] = generator.output.active[i]

            if generator.layout.bus[i] == slack
                if tempSlack != 0
                    power.active[tempSlack] -= power.active[i]
                end
                if tempSlack == 0
                    power.active[i] = supplySlack
                    tempSlack = i
                end
            end
        end
    end
end