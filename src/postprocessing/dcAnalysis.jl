"""
    power!(system::PowerSystem, analysis::DC)

The function calculates the active power values related to buses, branches, and generators
within the DC analysis framework.

# Updates
This function updates the `power` field of the DC abstract type by computing the following
electrical quantities:
- `injection`: active power injections at each bus;
- `supply`: active power injections from the generators at each bus;
- `from`: active power flows at each "from" bus end of the branch;
- `to`: active power flows at each "to" bus end of the branch;
- `generator`: output active powers of each generator (excluding for state estimation).

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow;
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow;
- `DCStateEstimation`: computes the powers within the DC state estimation.

# Examples
Compute powers after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
power!(system, analysis)
```

Compute powers after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
power!(system, analysis)
```

Compute powers after obtaining the DC state estimation solution:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
power!(system, analysis)
```
"""
function power!(system::PowerSystem, analysis::DCPowerFlow)
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    generator = system.generator
    voltage = analysis.voltage
    power = analysis.power
    slack = bus.layout.slack

    power.supply.active = copy(bus.supply.active)
    power.injection.active = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        power.injection.active[i] -= bus.demand.active[i]
    end

    power.injection.active[slack] = bus.shunt.conductance[slack] + dc.shiftPower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        power.injection.active[slack] += dc.nodalMatrix[row, slack] * voltage.angle[row]
    end

    power.supply.active[slack] = bus.demand.active[slack] + power.injection.active[slack]

    power.generator.active = fill(0.0, generator.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]

            if busIndex == bus.layout.slack && bus.supply.generator[busIndex][1] == i
                power.generator.active[i] = bus.shunt.conductance[busIndex] + dc.shiftPower[busIndex] + bus.demand.active[busIndex]
                for j in dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)
                    row = dc.nodalMatrix.rowval[j]
                    power.generator.active[i] += dc.nodalMatrix[row, busIndex] * voltage.angle[row]
                end

                for j = 2:length(bus.supply.generator[busIndex])
                    power.generator.active[i] -= generator.output.active[bus.supply.generator[busIndex][j]]
                end
            else
                power.generator.active[i] = generator.output.active[i]
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
        power.supply.active[system.generator.layout.bus[i]] += analysis.power.generator.active[i]
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

    power.injection.active = dc.nodalMatrix * analysis.voltage.angle + dc.shiftPower + bus.shunt.conductance
    power.supply.active = power.injection.active + bus.demand.active

    allPowerBranch(system, analysis)
end

"""
    injectionPower(system::PowerSystem, analysis::DC; label)

The function returns the active power injection associated with a specific bus in the DC
framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the power within the DC power flow;
- `DCOptimalPowerFlow`: computes the power within the DC optimal power flow;
- `DCStateEstimation`: computes the power within the DC state estimation.

# Examples
Compute the active power after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
injection = injectionPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
injection = injectionPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC state estimation solution:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
injection = injectionPower(system, analysis; label = 2)
```
"""
function injectionPower(system::PowerSystem, analysis::DCPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    voltage = analysis.voltage

    if index == system.bus.layout.slack
        injectionActive = bus.shunt.conductance[index] + dc.shiftPower[index]
        @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            injectionActive += dc.nodalMatrix[row, index] * voltage.angle[row]
        end
    else
        injectionActive = bus.supply.active[index] - bus.demand.active[index]
    end

    return injectionActive
end

function injectionPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    injectionActive = copy(-system.bus.demand.active[index])
    @inbounds for i in system.bus.supply.generator[index]
        injectionActive += analysis.power.generator.active[i]
    end

    return injectionActive
end

function injectionPower(system::PowerSystem, analysis::DCStateEstimation; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    voltage = analysis.voltage

    injectionActive = bus.shunt.conductance[index] + dc.shiftPower[index]
    @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        injectionActive += dc.nodalMatrix[row, index] * voltage.angle[row]
    end

    return injectionActive
end

"""
    supplyPower(system::PowerSystem, analysis::DC; label)

The function returns the active power injection from the generators associated with a
specific bus in the DC framework. The `label` keyword argument must match an existing bus
label.

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the power within the DC power flow,
- `DCOptimalPowerFlow`: computes the power within the DC optimal power flow;
- `DCStateEstimation`: computes the power within the DC state estimation.

# Examples
Compute the active power after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
supply = supplyPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
supply = supplyPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC state estimation solution:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
supply = supplyPower(system, analysis; label = 2)
```
"""
function supplyPower(system::PowerSystem, analysis::DCPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    voltage = analysis.voltage

    if index == system.bus.layout.slack
        supplyActive = bus.demand.active[index] + bus.shunt.conductance[index] + dc.shiftPower[index]
        @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            supplyActive += dc.nodalMatrix[row, index] * voltage.angle[row]
        end
    else
        supplyActive = bus.supply.active[index]
    end

    return supplyActive
end

function supplyPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    supplyActive = 0.0
    @inbounds for i in system.bus.supply.generator[index]
        supplyActive += analysis.power.generator.active[i]
    end

    return supplyActive
end

function supplyPower(system::PowerSystem, analysis::DCStateEstimation; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    voltage = analysis.voltage

    supplyActive = bus.shunt.conductance[index] + dc.shiftPower[index] + bus.demand.active[index]
    @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        supplyActive += dc.nodalMatrix[row, index] * voltage.angle[row]
    end

    return supplyActive
end

"""
    fromPower(system::PowerSystem, analysis::DC; label)

The function returns the active power flow at the "from" bus end associated with a specific
branch in the DC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the power within the DC power flow;
- `DCOptimalPowerFlow`: computes the power within the DC optimal power flow;
- `DCStateEstimation`: computes the power within the DC state estimation.

# Examples
Compute the active power after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
from = fromPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
from = fromPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC state estimation solution:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
from = fromPower(system, analysis; label = 2)
```
"""
function fromPower(system::PowerSystem, analysis::DC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.angle)

    branch = system.branch
    angle = analysis.voltage.angle

    return system.model.dc.admittance[index] * (angle[branch.layout.from[index]] - angle[branch.layout.to[index]] - branch.parameter.shiftAngle[index])
end

"""
    toPower(system::PowerSystem, analysis::DC; label)

The function returns the active power flow at the "to" bus end associated with a specific
branch in the DC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the power within the DC power flow;
- `DCOptimalPowerFlow`: computes the power within the DC optimal power flow;
- `DCStateEstimation`: computes the power within the DC state estimation.

# Examples
Compute the active power after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
to = toPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
to = toPower(system, analysis; label = 2)
```

Compute the active power after obtaining the DC state estimation solution:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
to = toPower(system, analysis; label = 2)
```
"""
function toPower(system::PowerSystem, analysis::DC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.angle)

    branch = system.branch
    angle = analysis.voltage.angle

    return -system.model.dc.admittance[index] * (angle[branch.layout.from[index]] - angle[branch.layout.to[index]] - branch.parameter.shiftAngle[index])
end

"""
    generatorPower(system::PowerSystem, analysis::DC; label)

This function returns the output active power associated with a specific generator in the
DC framework. The `label` keyword argument must match an existing generator label.

# Abstract type
The abstract type `DC` can have the following subtypes:
- `DCPowerFlow`: computes the power within the DC power flow;
- `DCOptimalPowerFlow`: computes the power within the DC optimal power flow.

# Examples
Compute the active power after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcPowerFlow(system)
solve!(system, analysis)
generator = generatorPower(system, analysis; label = 1)
```

Compute the active power after obtaining the DC optimal power flow
solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
generator = generatorPower(system, analysis; label = 1)
```
"""
function generatorPower(system::PowerSystem, analysis::DCPowerFlow; label)
    index = system.generator.label[getLabel(system.generator, label, "generator")]
    errorVoltage(analysis.voltage.angle)

    dc = system.model.dc
    bus = system.bus
    generator = system.generator
    voltage = analysis.voltage
    busIndex = generator.layout.bus[index]

    if generator.layout.status[index] == 1
        if busIndex == bus.layout.slack && bus.supply.generator[busIndex][1] == index
            generatorActive = bus.shunt.conductance[busIndex] + dc.shiftPower[busIndex] + bus.demand.active[busIndex]
            for j in dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)
                row = dc.nodalMatrix.rowval[j]
                generatorActive += dc.nodalMatrix[row, busIndex] * voltage.angle[row]
            end

            for i = 2:length(bus.supply.generator[busIndex])
                generatorActive -= generator.output.active[bus.supply.generator[busIndex][i]]
            end
        else
            generatorActive = generator.output.active[index]
        end
    else
        generatorActive = 0.0
    end

    return generatorActive
end

function generatorPower(system::PowerSystem, analysis::DCOptimalPowerFlow; label)
    index = system.generator.label[getLabel(system.generator, label, "generator")]
    errorVoltage(analysis.voltage.angle)

    return analysis.power.generator.active[index]
end

######### Powers at Branches ##########
function allPowerBranch(system::PowerSystem, analysis::DC)
    branch = system.branch
    voltage = analysis.voltage
    power = analysis.power

    power.from.active = copy(system.model.dc.admittance)
    power.to.active = similar(system.model.dc.admittance)
    @inbounds for i = 1:branch.number
        power.from.active[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        power.to.active[i] = -power.from.active[i]
    end
end