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

    initialize!(power, bus.number, (:injection,))
    @inbounds for i = 1:bus.number
        power.injection.active[i] = bus.supply.active[i] - demand.active[i]
    end
    power.injection.active[slack] = Pi(bus, dc, voltg, slack)

    power.supply.active = copy(bus.supply.active)
    power.supply.active[slack] = demand.active[slack] + power.injection.active[slack]

    initialize!(power, gen.number, (:generator,))
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

    allPowerBranch(analysis)
end

function power!(analysis::DcOptimalPowerFlow)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    power = analysis.power

    initialize!(power, system.bus.number, (:injection, :supply))
    @inbounds for i = 1:system.generator.number
        power.supply.active[system.generator.layout.bus[i]] += power.generator.active[i]
    end

    @inbounds for i = 1:system.bus.number
        power.injection.active[i] = power.supply.active[i] - system.bus.demand.active[i]
    end

    allPowerBranch(analysis)
end

function power!(analysis::DcStateEstimation)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    dc = system.model.dc
    bus = system.bus
    power = analysis.power

    power.injection.active =
        dc.nodalMatrix * analysis.voltage.angle + dc.shiftPower + bus.shunt.conductance

    power.supply.active = power.injection.active + bus.demand.active

    allPowerBranch(analysis)
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

injection = injectionPower(analysis; label = 2)
```
"""
function injectionPower(analysis::DcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    if idx == system.bus.layout.slack
        return Pi(system.bus, system.model.dc, analysis.voltage, idx)
    else
        return system.bus.supply.active[idx] - system.bus.demand.active[idx]
    end
end

function injectionPower(analysis::DcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    Pi = copy(-system.bus.demand.active[idx])
    if haskey(system.bus.supply.generator, idx)
        @inbounds for i in system.bus.supply.generator[idx]
            Pi += analysis.power.generator.active[i]
        end
    end

    return Pi
end

function injectionPower(analysis::DcStateEstimation; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    Pi(system.bus, system.model.dc, analysis.voltage, idx)
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

supply = supplyPower(analysis; label = 2)
```
"""
function supplyPower(analysis::DcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    dc = system.model.dc
    bus = system.bus

    if idx == system.bus.layout.slack
        return Pi(bus, dc, analysis.voltage, idx) + bus.demand.active[idx]
    else
        return bus.supply.active[idx]
    end
end

function supplyPower(analysis::DcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    supplyActive = 0.0
    if haskey(system.bus.supply.generator, idx)
        @inbounds for i in system.bus.supply.generator[idx]
            supplyActive += analysis.power.generator.active[i]
        end
    end

    return supplyActive
end

function supplyPower(analysis::DcStateEstimation; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    bus = system.bus

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
    admittance = system.model.dc.admittance
    shiftAngle = system.branch.parameter.shiftAngle

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
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
    admittance = system.model.dc.admittance
    shiftAngle = system.branch.parameter.shiftAngle

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
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

function generatorPower(analysis::DcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    idx = system.generator.label[getLabel(system.generator, label, "generator")]

    analysis.power.generator.active[idx]
end

######### Powers at Branches ##########
function allPowerBranch(analysis::DC)
    system = analysis.system
    dc = system.model.dc
    shiftAngle = system.branch.parameter.shiftAngle
    voltg = analysis.voltage
    power = analysis.power

    initialize!(power, system.branch.number, (:from, :to))
    @inbounds for k = 1:system.branch.number
        i, j = fromto(system, k)

        power.from.active[k] = dc.admittance[k] * (voltg.angle[i] - voltg.angle[j] - shiftAngle[k])
        power.to.active[k] = -power.from.active[k]
    end
end

######### Injection Power ##########
function Pi(bus::Bus, dc::DcModel, voltg::Angle, i::Int64)
    P = 0.0
    @inbounds for j in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        P += dc.nodalMatrix[row, i] * voltg.angle[row]
    end

    P + bus.shunt.conductance[i] + dc.shiftPower[i]
end