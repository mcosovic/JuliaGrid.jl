"""
    power(system::PowerSystem, model::DCAnalysis)

The function returns the active powers associated with buses, branches, and generators in
the DC framework.

# Abstract type
Subtypes of the abstract type `DCAnalysis` include:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Returns
The function returns the instance of the `DCPower` type, which contains the following
fields:
- The `bus` field contains powers related to buses:
  - `injection`: active power injections,
  - `supply`: active power injections from the generators.
- The `branch` field contains powers related to branches:
  - `from`: active power flows at each "from" bus end,
  - `to`: active power flows at each "to" bus end.
- The `generator` field contains powers related to generators:
  - `output`: output active powers.

# Examples
Compute powers after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

powers = power(system, model)
```

Compute powers after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

powers = power(system, model)
```
"""
function power(system::PowerSystem, model::DCPowerFlow)
    errorVoltage(model.voltage.angle)

    dc = system.dcModel
    bus = system.bus
    generator = system.generator
    voltage = model.voltage
    slack = bus.layout.slack

    supplyActive = copy(bus.supply.active)
    injectionActive = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        injectionActive[i] -= bus.demand.active[i]
    end

    injectionActive[slack] = bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        injectionActive[slack] += dc.nodalMatrix[row, slack] * voltage.angle[row]
    end

    supplyActive[slack] = bus.demand.active[slack] + injectionActive[slack]

    generatorActive = fill(0.0, generator.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]

            if busIndex == bus.layout.slack && bus.supply.generator[busIndex][1] == i
                generatorActive[i] = bus.shunt.conductance[busIndex] + dc.shiftActivePower[busIndex] + bus.demand.active[busIndex]
                for j in dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)
                    row = dc.nodalMatrix.rowval[j]
                    generatorActive[i] += dc.nodalMatrix[row, busIndex] * voltage.angle[row]
                end

                for j = 2:bus.supply.inService[busIndex]
                    generatorActive[i] -= generator.output.active[bus.supply.generator[busIndex][j]]
                end
            else
                generatorActive[i] = generator.output.active[i]
            end
        end
    end

    powerFrom, powerTo = allPowerBranch(system, model)

    return DCPower(
        DCPowerBus(
            CartesianReal(injectionActive),
            CartesianReal(supplyActive)
        ),
        DCPowerBranch(
            CartesianReal(powerFrom),
            CartesianReal(powerTo)
        ),
        DCPowerGenerator(
            CartesianReal(generatorActive)
        )
    )
end


# function power(system::PowerSystem, model::DCOptimalPowerFlow)
#     errorVoltage(model.voltage.angle)

#     dc = system.dcModel
#     bus = system.bus
#     slack = bus.layout.slack

#     supplyActive = fill(0.0, system.bus.number)
#     @inbounds for i = 1:system.generator.number
#         supplyActive[system.generator.layout.bus[i]] += model.power.active[i]
#     end

#     injectionActive = copy(supplyActive)
#     @inbounds for i = 1:bus.number
#         injectionActive[i] -= bus.demand.active[i]
#     end

#     powerFrom, powerTo = allPowerBranch(system, model)

#     return DCPower(
#         DCPowerBus(
#             CartesianReal(injectionActive),
#             CartesianReal(supplyActive)
#         ),
#         DCPowerBranch(
#             CartesianReal(powerFrom),
#             CartesianReal(powerTo)
#         ),
#         DCPowerGenerator(
#             CartesianReal(copy(model.power.active))
#         )
#     )
# end

"""
    powerBus(system::PowerSystem, model::DCAnalysis; label)

This function calculates the active powers associated with a specific bus in the DC
framework. The `label` keyword argument must match an existing bus label.

# Abstract type
Subtypes of the abstract type `DCAnalysis` include:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Returns
The function returns an instance of the `DCPowerBus` type, which contains the following
fields:
- `injection`: active power injection at the bus,
- `supply`: active power injection from the generators at the bus.


# Examples
Compute the powers of a specific bus after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

powers = powerBus(system, model; label = 2)
```

Compute the powers of a specific bus after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

powers = powerBus(system, model; label = 2)
```
"""
function powerBus(system::PowerSystem, model::DCPowerFlow; label)
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
        supplyActive = bus.demand.active[index] + injectionActive[index]
    else
        supplyActive = bus.supply.active[index]
        injectionActive = supplyActive - bus.demand.active[index]
    end

    return DCPowerBus(
            CartesianReal(injectionActive),
            CartesianReal(supplyActive)
    )
end

# function powerBus(system::PowerSystem, model::DCOptimalPowerFlow; label)
#     if !haskey(system.bus.label, label)
#         throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
#     end

#     bus = system.bus

#     index = system.bus.label[label]

#     supplyActive = 0.0
#     @inbounds for i in bus.supply.inService[index]
#         supplyActive += model.power.active[i]
#     end

#     injectionActive = supplyActive - bus.demand.active[index]

#     return DCPowerBus(
#             CartesianReal(injectionActive),
#             CartesianReal(supplyActive)
#     )
# end

"""
    powerBranch(system::PowerSystem, model::DCAnalysis; label)

This function calculates the active powers associated with a specific branch in the DC
framework. The `label` keyword argument must match an existing branch label.

# Abstract type
Subtypes of the abstract type `DCAnalysis` include:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Returns
The function returns an instance of the `DCPowerBranch` type, which contains the following
fields:
- `from`: active power flow at the "from" bus end of the branch,
- `to`: active power flow at the "to" bus end of the branch.


# Examples
Compute the powers of a specific branch after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

powers = powerBranch(system, model; label = 2)
```

Compute the powers of a specific branch after obtaining the DC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

powers = powerBranch(system, model; label = 2)
```
"""
function powerBranch(system::PowerSystem, model::DCAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end

    dc = system.dcModel
    branch = system.branch
    angle = model.voltage.angle

    index = system.branch.label[label]

    powerFrom = dc.admittance[index] * (angle[branch.layout.from[index]] - angle[branch.layout.to[index]] - branch.parameter.shiftAngle[index])
    powerTo = -powerFrom

    return DCPowerBranch(
        CartesianReal(powerFrom),
        CartesianReal(powerTo)
    )
end

"""
    powerGenerator(system::PowerSystem, model::DCAnalysis; label)

This function calculates the active powers associated with a specific generator in the DC
framework. The `label` keyword argument must match an existing generator label.

# Abstract type
Subtypes of the abstract type `DCAnalysis` include:
- `DCPowerFlow`: computes the powers within the DC power flow,
- `DCOptimalPowerFlow`: computes the powers within the DC optimal power flow.

# Returns
The function returns an instance of the `DCPowerGenerator` type, which has the following
field:
- `output`: output active power of the generator.

# Examples
Compute the powers of a specific generator after obtaining the DC power flow solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

powers = powerGenerator(system, model; label = 1)
```

Compute the powers of a specific generator after obtaining the DC optimal power flow
solution:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system)
optimize!(system, model)

powers = powerGenerator(system, model; label = 1)
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

    DCPowerGenerator(
        CartesianReal(generatorActive)
    )
end

######### Powers at Branches ##########
function allPowerBranch(system::PowerSystem, model::Union{DCPowerFlow, DCOptimalPowerFlow})
    branch = system.branch
    voltage = model.voltage

    powerFrom = copy(system.dcModel.admittance)
    powerTo = similar(system.dcModel.admittance)
    @inbounds for i = 1:branch.number
        powerFrom[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        powerTo[i] = -powerFrom[i]
    end

    return powerFrom, powerTo
end


