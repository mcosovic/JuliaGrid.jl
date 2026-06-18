"""
    power!(analysis::DC)

The function calculates the active power values related to buses, branches, and generators within
the DC analysis framework.

# Updates
This function updates the `power` field of the `DC` abstract type by computing the following
electrical quantities:
- `injection`: Active power injections at each bus.
- `supply`: Active power injections from the generators at each bus.
- `from`: Active power flows at each from-bus end of the branch.
- `to`: Active power flows at each to-bus end of the branch.
- `generator`: Output active powers of each generator (excluding for state estimation).

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

power!(analysis)
```
"""
function power!(analysis::DcPowerFlow)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    dc = system.model.dc
    bus = system.bus
    gen = system.generator
    voltg = analysis.voltage
    power = analysis.power
    slack = bus.layout.slack
    demand = bus.demand
    busGenerators = bus.supply.generator
    genStatus = gen.layout.status
    genBus = gen.layout.bus
    genActive = gen.output.active

    initialize!(power, bus.number, (:injection, :supply))
    injection = power.injection
    supply = power.supply
    busSupply = bus.supply
    @inbounds for i = 1:bus.number
        injection.active[i] = busSupply.active[i] - demand.active[i]
    end
    injection.active[slack] = Pi(bus, dc, voltg, slack)

    supply.active .= busSupply.active
    supply.active[slack] = demand.active[slack] + injection.active[slack]

    initialize!(power, gen.number, (:generator,))
    generator = power.generator
    @inbounds for i = 1:gen.number
        if genStatus[i] == 1
            idxBus = genBus[i]

            if idxBus == slack && busGenerators[idxBus][1] == i
                generator.active[i] = Pi(bus, dc, voltg, idxBus) + demand.active[idxBus]

                for j = 2:length(busGenerators[idxBus])
                    generator.active[i] -= genActive[busGenerators[idxBus][j]]
                end
            else
                generator.active[i] = genActive[i]
            end
        end
    end

    allPowerBranch(analysis)

    return nothing
end

function power!(analysis::DcOptimalPowerFlow)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    bus = system.bus
    gen = system.generator
    dc = system.model.dc
    voltg = analysis.voltage
    power = analysis.power

    initialize!(power, bus.number, (:injection, :supply))
    injection = power.injection
    supply = power.supply
    generator = power.generator
    genBus = gen.layout.bus
    @inbounds for i = 1:gen.number
        supply.active[genBus[i]] += generator.active[i]
    end

    @inbounds for i = 1:bus.number
        injection.active[i] = Pi(bus, dc, voltg, i)
    end

    allPowerBranch(analysis)

    return nothing
end

function power!(analysis::DcStateEstimation)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    dc = system.model.dc
    bus = system.bus
    power = analysis.power

    initialize!(power, bus.number, (:injection, :supply))
    injection = power.injection
    supply = power.supply
    demand = bus.demand
    conductance = bus.shunt.conductance
    shiftPower = dc.shiftPower

    mul!(injection.active, dc.nodalMatrix, analysis.voltage.angle)
    @inbounds for i = 1:bus.number
        injection.active[i] += shiftPower[i] + conductance[i]
        supply.active[i] = injection.active[i] + demand.active[i]
    end

    allPowerBranch(analysis)

    return nothing
end

"""
    injectionPower(analysis::DC; label)

The function returns the active power injection associated with a specific bus in the DC framework.
The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

injection = injectionPower(analysis; label = "Bus 2 HV")
```
"""
function injectionPower(analysis::DcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")

    if idx == bus.layout.slack
        return Pi(bus, system.model.dc, analysis.voltage, idx)
    else
        return bus.supply.active[idx] - bus.demand.active[idx]
    end
end

function injectionPower(analysis::Union{DcOptimalPowerFlow, DcStateEstimation}; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")

    Pi(bus, system.model.dc, analysis.voltage, idx)
end

"""
    supplyPower(analysis::DC; label)

The function returns the active power injection from the generators associated with a specific bus
in the DC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

supply = supplyPower(analysis; label = "Bus 2 HV")
```
"""
function supplyPower(analysis::DcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    dc = system.model.dc
    bus = system.bus
    idx = getIndex(bus, label, "bus")

    if idx == bus.layout.slack
        return Pi(bus, dc, analysis.voltage, idx) + bus.demand.active[idx]
    else
        return bus.supply.active[idx]
    end
end

function supplyPower(analysis::DcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")
    busGenerators = bus.supply.generator
    generator = analysis.power.generator

    supplyActive = 0.0
    if haskey(busGenerators, idx)
        @inbounds for i in busGenerators[idx]
            supplyActive += generator.active[i]
        end
    end

    return supplyActive
end

function supplyPower(analysis::DcStateEstimation; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")

    Pi(bus, system.model.dc, analysis.voltage, idx) + bus.demand.active[idx]
end

"""
    fromPower(analysis::DC; label)

The function returns the active power flow at the from-bus end associated with a specific branch in
the DC framework. The `label` keyword argument must match an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

from = fromPower(analysis; label = 2)
```
"""
function fromPower(analysis::DC; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    angle = analysis.voltage.angle
    branch = system.branch
    admittance = system.model.dc.admittance
    shiftAngle = branch.parameter.shiftAngle

    idx = getIndex(branch, label, "branch")
    i, j = fromto(system, idx)

    admittance[idx] * (angle[i] - angle[j] - shiftAngle[idx])
end

"""
    toPower(analysis::DC; label)

The function returns the active power flow at the to-bus end associated with a specific branch in
the DC framework. The `label` keyword argument must match an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

to = toPower(analysis; label = 2)
```
"""
function toPower(analysis::DC; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    angle = analysis.voltage.angle
    branch = system.branch
    admittance = system.model.dc.admittance
    shiftAngle = branch.parameter.shiftAngle

    idx = getIndex(branch, label, "branch")
    i, j = fromto(system, idx)

    -admittance[idx] * (angle[i] - angle[j] - shiftAngle[idx])
end

"""
    generatorPower(analysis::DC; label)

This function returns the output active power associated with a specific generator in the DC
framework. The `label` keyword argument must match an existing generator label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(analysis)

generator = generatorPower(analysis; label = 1)
```
"""
function generatorPower(analysis::DcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    dc = system.model.dc
    bus = system.bus
    gen = system.generator
    idx = getIndex(gen, label, "generator")
    idxBus = gen.layout.bus[idx]
    busGenerators = bus.supply.generator
    genActive = gen.output.active

    if gen.layout.status[idx] == 1
        if idxBus == bus.layout.slack && busGenerators[idxBus][1] == idx
            Pg = Pi(bus, dc, analysis.voltage, idxBus) + bus.demand.active[idxBus]

            for i = 2:length(busGenerators[idxBus])
                Pg -= genActive[busGenerators[idxBus][i]]
            end
        else
            Pg = genActive[idx]
        end
    else
        Pg = 0.0
    end

    return Pg
end

function generatorPower(analysis::DcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    system = analysis.system
    generator = analysis.power.generator
    idx = getIndex(system.generator, label, "generator")

    generator.active[idx]
end

######### Powers at Branches ##########
function allPowerBranch(analysis::DC)
    system = analysis.system
    branch = system.branch
    dc = system.model.dc
    shiftAngle = branch.parameter.shiftAngle
    voltg = analysis.voltage
    power = analysis.power
    from = power.from
    to = power.to
    admittance = dc.admittance
    angle = voltg.angle

    initialize!(power, branch.number, (:from, :to))
    @inbounds for k = 1:branch.number
        i, j = fromto(system, k)

        from.active[k] = admittance[k] * (angle[i] - angle[j] - shiftAngle[k])
        to.active[k] = -from.active[k]
    end

    return nothing
end

######### Injection Power ##########
function Pi(bus::Bus, dc::DcModel, voltg::Angle, i::Int64)
    P = 0.0
    nodalMatrix = dc.nodalMatrix
    colptr = nodalMatrix.colptr
    rowval = nodalMatrix.rowval
    nzval = nodalMatrix.nzval
    angle = voltg.angle

    @inbounds for j in colptr[i]:(colptr[i + 1] - 1)
        row = rowval[j]
        P += nzval[j] * angle[row]
    end

    P + bus.shunt.conductance[i] + dc.shiftPower[i]
end
