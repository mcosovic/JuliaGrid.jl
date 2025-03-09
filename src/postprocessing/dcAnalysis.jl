"""
    power!(system::PowerSystem, analysis::DC)

The function calculates the active power values related to buses, branches, and generators
within the DC analysis framework.

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
solve!(system, analysis)

power!(system, analysis)
```
"""
function power!(system::PowerSystem, analysis::DCPowerFlow)
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    gen = system.generator
    voltg = analysis.voltage
    power = analysis.power
    slack = bus.layout.slack
    demand = bus.demand

    power.supply.active = copy(bus.supply.active)
    power.injection.active = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        power.injection.active[i] -= demand.active[i]
    end

    power.injection.active[slack] = Pi(bus, dc, voltg, slack)
    power.supply.active[slack] = demand.active[slack] + power.injection.active[slack]

    power.generator.active = fill(0.0, gen.number)
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            idxBus = system.generator.layout.bus[i]

            if idxBus == bus.layout.slack && bus.supply.generator[idxBus][1] == i
                power.generator.active[i] = Pi(bus, dc, voltg, idxBus) + demand.active[idxBus]

                for j = 2:length(bus.supply.generator[idxBus])
                    power.generator.active[i] -=
                    gen.output.active[bus.supply.generator[idxBus][j]]
                end
            else
                power.generator.active[i] = gen.output.active[i]
            end
        end
    end

    allPowerBranch(system, analysis)
end

function power!(system::PowerSystem, analysis::DCOptimalPowerFlow)
    errorVoltage(analysis.voltage.angle)

    power = analysis.power

    power.supply.active = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.generator.number
        power.supply.active[system.generator.layout.bus[i]] += power.generator.active[i]
    end

    power.injection.active = copy(power.supply.active)
    @inbounds for i = 1:system.bus.number
        power.injection.active[i] -= system.bus.demand.active[i]
    end

    allPowerBranch(system, analysis)
end

function power!(system::PowerSystem, analysis::DCStateEstimation)
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    power = analysis.power

    power.injection.active =
        dc.nodalMatrix * analysis.voltage.angle + dc.shiftPower + bus.shunt.conductance

    power.supply.active = power.injection.active + bus.demand.active

    allPowerBranch(system, analysis)
end

"""
    injectionPower(system::PowerSystem, analysis::DC; label)

The function returns the active power injection associated with a specific bus in the DC
framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

injection = injectionPower(system, analysis; label = 2)
```
"""
function injectionPower(system::PowerSystem, analysis::DCPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    if idx == system.bus.layout.slack
        return Pi(system.bus, system.model.dc, analysis.voltage, idx)
    else
        return system.bus.supply.active[idx] - system.bus.demand.active[idx]
    end
end

function injectionPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    Pi = copy(-system.bus.demand.active[idx])
    if haskey(system.bus.supply.generator, idx)
        @inbounds for i in system.bus.supply.generator[idx]
            Pi += analysis.power.generator.active[i]
        end
    end

    return Pi
end

function injectionPower(system::PowerSystem, analysis::DCStateEstimation; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    Pi(system.bus, system.model.dc, analysis.voltage, idx)
end

"""
    supplyPower(system::PowerSystem, analysis::DC; label)

The function returns the active power injection from the generators associated with a
specific bus in the DC framework. The `label` keyword argument must match an existing bus
label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

supply = supplyPower(system, analysis; label = 2)
```
"""
function supplyPower(system::PowerSystem, analysis::DCPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    dc = system.model.dc
    bus = system.bus

    if idx == system.bus.layout.slack
        return Pi(bus, dc, analysis.voltage, idx) + bus.demand.active[idx]
    else
        return bus.supply.active[idx]
    end
end

function supplyPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    supplyActive = 0.0
    if haskey(system.bus.supply.generator, idx)
        @inbounds for i in system.bus.supply.generator[idx]
            supplyActive += analysis.power.generator.active[i]
        end
    end

    return supplyActive
end

function supplyPower(system::PowerSystem, analysis::DCStateEstimation; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    bus = system.bus

    Pi(bus, system.model.dc, analysis.voltage, idx) + bus.demand.active[idx]
end

"""
    fromPower(system::PowerSystem, analysis::DC; label)

The function returns the active power flow at the from-bus end associated with a
specific branch in the DC framework. The `label` keyword argument must match an existing
branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

from = fromPower(system, analysis; label = 2)
```
"""
function fromPower(system::PowerSystem, analysis::DC; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    angle = analysis.voltage.angle
    admittance = system.model.dc.admittance
    shiftAngle = system.branch.parameter.shiftAngle

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
    i, j = fromto(system, idx)

    admittance[idx] * (angle[i] - angle[j] - shiftAngle[idx])
end

"""
    toPower(system::PowerSystem, analysis::DC; label)

The function returns the active power flow at the to-bus end associated with a specific
branch in the DC framework. The `label` keyword argument must match an existing branch
label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

to = toPower(system, analysis; label = 2)
```
"""
function toPower(system::PowerSystem, analysis::DC; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    angle = analysis.voltage.angle
    admittance = system.model.dc.admittance
    shiftAngle = system.branch.parameter.shiftAngle

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
    i, j = fromto(system, idx)

    -admittance[idx] * (angle[i] - angle[j] - shiftAngle[idx])
end

"""
    generatorPower(system::PowerSystem, analysis::DC; label)

This function returns the output active power associated with a specific generator in the
DC framework. The `label` keyword argument must match an existing generator label.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)

generator = generatorPower(system, analysis; label = 1)
```
"""
function generatorPower(system::PowerSystem, analysis::DCPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    idx = system.generator.label[getLabel(system.generator, label, "generator")]

    dc = system.model.dc
    bus = system.bus
    gen = system.generator
    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 1
        if idxBus == bus.layout.slack && bus.supply.generator[idxBus][1] == idx
            Pg = Pi(bus, dc, analysis.voltage, idxBus) + bus.demand.active[idxBus]

            for i = 2:length(bus.supply.generator[idxBus])
                Pg -= gen.output.active[bus.supply.generator[idxBus][i]]
            end
        else
            Pg = gen.output.active[idx]
        end
    else
        Pg = 0.0
    end

    return Pg
end

function generatorPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.generator.label[getLabel(system.generator, label, "generator")]

    analysis.power.generator.active[idx]
end

######### Powers at Branches ##########
function allPowerBranch(system::PowerSystem, analysis::DC)
    shiftAngle = system.branch.parameter.shiftAngle
    voltg = analysis.voltage
    power = analysis.power

    power.from.active = copy(system.model.dc.admittance)
    power.to.active = similar(system.model.dc.admittance)
    @inbounds for k = 1:system.branch.number
        i, j = fromto(system, k)

        power.from.active[k] *= (voltg.angle[i] - voltg.angle[j] - shiftAngle[k])
        power.to.active[k] = -power.from.active[k]
    end
end

######### Injection Power ##########
function Pi(bus::Bus, dc::DCModel, voltg::PolarAngle, i::Int64)
    P = 0.0
    @inbounds for j in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        P += dc.nodalMatrix[row, i] * voltg.angle[row]
    end

    P + bus.shunt.conductance[i] + dc.shiftPower[i]
end