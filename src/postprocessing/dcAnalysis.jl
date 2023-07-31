"""
    power!(system::PowerSystem, model::DCAnalysis)

The function calculates the active power values related to buses, branches, and generators 
within the DC analysis framework. It modifies the `power` field of the abstract type 
`DCAnalysis`.

This function computes the following electrical quantities: 
- `injection`: active power injections at each bus,
- `supply`: active power injections from the generators at each bus,
- `from`: active power flows at each "from" bus end of the branch,
- `to`: active power flows at each "to" bus end of the branch,
- `generator`: output active powers of each generator.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute powers after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

power!(system, model)
```

Compute powers after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

power!(system, model)
```
"""
function power!(system::PowerSystem, model::DCPowerFlow)
    errorVoltage(model.voltage.angle)

    dc = system.dcModel
    bus = system.bus
    generator = system.generator
    voltage = model.voltage
    power = model.power
    slack = bus.layout.slack

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

    power.generator.active = fill(0.0, generator.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]

            if busIndex == bus.layout.slack && bus.supply.generator[busIndex][1] == i
                power.generator.active[i] = bus.shunt.conductance[busIndex] + dc.shiftActivePower[busIndex] + bus.demand.active[busIndex]
                for j in dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)
                    row = dc.nodalMatrix.rowval[j]
                    power.generator.active[i] += dc.nodalMatrix[row, busIndex] * voltage.angle[row]
                end

                for j = 2:bus.supply.inService[busIndex]
                    power.generator.active[i] -= generator.output.active[bus.supply.generator[busIndex][j]]
                end
            else
                power.generator.active[i] = generator.output.active[i]
            end
        end
    end

    allPowerBranch(system, model)
end

function power!(system::PowerSystem, model::DCOptimalPowerFlow)
    errorVoltage(model.voltage.angle)
    power = model.power

    power.supply.active = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.generator.number
        power.supply.active[system.generator.layout.bus[i]] += model.power.generator.active[i]
    end

    power.injection.active = copy(power.supply.active)
    @inbounds for i = 1:system.bus.number
        power.injection.active[i] -= system.bus.demand.active[i]
    end

    allPowerBranch(system, model)
end

"""
    powerInjection(system::PowerSystem, model::DCAnalysis; label)

The function returns the active power injection associated with a specific bus in the DC
framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute the active power of a specific bus after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

injection = powerInjection(system, model; label = 2)
```

Compute the active power of a specific bus after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

injection = powerInjection(system, model; label = 2)
```
"""
function powerInjection(system::PowerSystem, model::DCPowerFlow; label)
    errorVoltage(model.voltage.angle)

    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    dc = system.dcModel
    bus = system.bus
    voltage = model.voltage

    index = system.bus.label[label]

    if index == system.bus.layout.slack
        injectionActive = bus.shunt.conductance[index] + dc.shiftActivePower[index]
        @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            injectionActive += dc.nodalMatrix[row, index] * voltage.angle[row]
        end
    else
        injectionActive = bus.supply.active[index] - bus.demand.active[index]
    end

    return injectionActive
end

function powerInjection(system::PowerSystem, model::DCOptimalPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    index = system.bus.label[label]

    injectionActive = copy(-system.bus.demand.active[index])
    @inbounds for i in system.bus.supply.generator[index]
        injectionActive += model.power.active[i]
    end

    return injectionActive
end

"""
    powerSupply(system::PowerSystem, model::DCAnalysis; label)

The function returns the active power injection from the generators associated with a 
specific bus in the DC framework. The `label` keyword argument must match an existing bus 
label.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute the active power of a specific bus after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

supply = powerSupply(system, model; label = 2)
```

Compute the active power of a specific bus after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

supply = powerSupply(system, model; label = 2)
```
"""
function powerSupply(system::PowerSystem, model::DCPowerFlow; label)
    errorVoltage(model.voltage.angle)

    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    dc = system.dcModel
    bus = system.bus
    voltage = model.voltage

    index = system.bus.label[label]

    if index == system.bus.layout.slack
        supplyActive = bus.demand.active[index] + bus.shunt.conductance[index] + dc.shiftActivePower[index]
        @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            supplyActive += dc.nodalMatrix[row, index] * voltage.angle[row]
        end
    else
        supplyActive = bus.supply.active[index]
    end
end

function powerSupply(system::PowerSystem, model::DCOptimalPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    index = system.bus.label[label]

    supplyActive = 0.0
    @inbounds for i in system.bus.supply.generator[index]
        supplyActive += model.power.active[i]
    end

    return supplyActive
end

"""
    powerFrom(system::PowerSystem, model::DCAnalysis; label)

The function returns the active power flow at the "from" bus end associated with a specific 
branch in the DC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute the active power of a specific branch after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

from = powerFrom(system, model; label = 2)
```

Compute the active power of a specific branch after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

from = powerFrom(system, model; label = 2)
```
"""
function powerFrom(system::PowerSystem, model::DCAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end

    branch = system.branch
    angle = model.voltage.angle

    index = system.branch.label[label]

    return system.dcModel.admittance[index] * (angle[branch.layout.from[index]] - angle[branch.layout.to[index]] - branch.parameter.shiftAngle[index])
end

"""
    powerTo(system::PowerSystem, model::DCAnalysis; label)

The function returns the active power flow at the "to" bus end associated with a specific 
branch in the DC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute the active power of a specific branch after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

to = powerTo(system, model; label = 2)
```

Compute the active power of a specific branch after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

to = powerTo(system, model; label = 2)
```
"""
function powerTo(system::PowerSystem, model::DCAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end

    branch = system.branch
    angle = model.voltage.angle

    index = system.branch.label[label]

    return -system.dcModel.admittance[index] * (angle[branch.layout.from[index]] - angle[branch.layout.to[index]] - branch.parameter.shiftAngle[index])
end

"""
    powerGenerator(system::PowerSystem, model::DCAnalysis; label)

This function returns the output active power associated with a specific generator in the 
DC framework. The `label` keyword argument must match an existing generator label.

# Abstract type
The abstract type `DCAnalysis` can have the following subtypes:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Examples
Compute the active power of a specific generator after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

generator = powerGenerator(system, model; label = 1)
```

Compute the active power of a specific generator after obtaining the DC optimal power flow
solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

generator = powerGenerator(system, model; label = 1)
```
"""
function powerGenerator(system::PowerSystem, model::DCPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.angle)

    dc = system.dcModel
    bus = system.bus
    generator = system.generator
    voltage = model.voltage

    index = system.generator.label[label]
    busIndex = generator.layout.bus[index]

    if generator.layout.status[index] == 1
        if busIndex == bus.layout.slack && bus.supply.generator[busIndex][1] == index
            generatorActive = bus.shunt.conductance[busIndex] + dc.shiftActivePower[busIndex] + bus.demand.active[busIndex]
            for j in dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)
                row = dc.nodalMatrix.rowval[j]
                generatorActive += dc.nodalMatrix[row, busIndex] * voltage.angle[row]
            end

            for i = 2:bus.supply.inService[busIndex]
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

function powerGenerator(system::PowerSystem, model::DCOptimalPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.angle)

    return model.power.active[system.generator.label[label]]
end

######### Powers at Branches ##########
function allPowerBranch(system::PowerSystem, model::Union{DCPowerFlow, DCOptimalPowerFlow})
    branch = system.branch
    voltage = model.voltage
    power = model.power

    power.from.active = copy(system.dcModel.admittance)
    power.to.active = similar(system.dcModel.admittance)
    @inbounds for i = 1:branch.number
        power.from.active[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        power.to.active[i] = -power.from.active[i]
    end
end

