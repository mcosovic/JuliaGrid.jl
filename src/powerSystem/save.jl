"""
The function saves power system data in the HDF5 file using fields `bus`,
`branch`, `generator` and `basePower` of the composite type `PowerSystem`.

    savePowerSystem(system::PowerSystem; path, reference, note)

The keyword `path::String` is mandatory in the form `"path/name.h5"`, while
keywords `reference::String` and `note::String` are optional.

# Example
```jldoctest
system = powerSystem("case14.m")
savePowerSystem(system; path = "C:/case14.h5")
```
"""
function savePowerSystem(system::PowerSystem; path::String, reference::String = "", note::String = "")
    file = h5open(path, "w")
        saveBasePower(system, file)
        label, shuntNumber = saveBus(system, file)
        transformerNumber = saveBranch(system, label, file)
        saveGenerator(system, label, file)
        saveMainAttribute(system, file, reference, note, transformerNumber, shuntNumber)
    close(file)
end

######### Save Base Power ##########
function saveBasePower(system::PowerSystem, file)
    write(file, "basePower", system.basePower)
    attrs(file["basePower"])["unit"] = "volt-ampere"
    attrs(file["basePower"])["format"] = "number"
end

######### Save Bus Data ##########
function saveBus(system::PowerSystem, file)
    demand = system.bus.demand
    shunt = system.bus.shunt
    voltage = system.bus.voltage
    layout = system.bus.layout

    label = fill(0, system.bus.number)
    slackLabel = 0
    shuntNumber = 0
    @inbounds for (key, value) in system.bus.label
        label[value] = key
        if value == layout.slackImmutable
            slackLabel = key
        end
        if shunt.conductance[value] != 0 || shunt.susceptance[value] != 0
            shuntNumber += 1
        end
    end
    write(file, "bus/layout/label", label)
    attrs(file["bus/layout/label"])["type"] = "positive integer"
    attrs(file["bus/layout/label"])["unit"] = "dimensionless"
    attrs(file["bus/layout/label"])["format"] = "expand"

    write(file, "bus/layout/slackLabel", slackLabel)
    attrs(file["bus/layout/slackLabel"])["type"] = "positive integer"
    attrs(file["bus/layout/slackLabel"])["unit"] = "dimensionless"
    attrs(file["bus/layout/slackLabel"])["format"] = "number"

    format = compresseArray(file, demand.active, "bus/demand/active")
    attrs(file["bus/demand/active"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/demand/active"])["SI unit"] = "watt (W)"
    attrs(file["bus/demand/active"])["type"] = "float"
    attrs(file["bus/demand/active"])["format"] = format

    format = compresseArray(file, demand.reactive, "bus/demand/reactive")
    attrs(file["bus/demand/reactive"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/demand/reactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["bus/demand/reactive"])["type"] = "float"
    attrs(file["bus/demand/reactive"])["format"] = format

    format = compresseArray(file, shunt.conductance, "bus/shunt/conductance")
    attrs(file["bus/shunt/conductance"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/shunt/conductance"])["SI unit"] = "watt at voltage magnitude of 1 per-unit (W)"
    attrs(file["bus/shunt/conductance"])["type"] = "float"
    attrs(file["bus/shunt/conductance"])["format"] = format

    format = compresseArray(file, shunt.susceptance, "bus/shunt/susceptance")
    attrs(file["bus/shunt/susceptance"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/shunt/susceptance"])["SI unit"] = "volt-ampere reactive at voltage magnitude of 1 per-unit (VAr)"
    attrs(file["bus/shunt/susceptance"])["type"] = "float"
    attrs(file["bus/shunt/susceptance"])["format"] = format

    format = compresseArray(file, voltage.magnitude, "bus/voltage/magnitude")
    attrs(file["bus/voltage/magnitude"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/voltage/magnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/magnitude"])["type"] = "float"
    attrs(file["bus/voltage/magnitude"])["format"] = format

    format = compresseArray(file, voltage.angle, "bus/voltage/angle")
    attrs(file["bus/voltage/angle"])["unit"] = "radian (rad)"
    attrs(file["bus/voltage/angle"])["type"] = "float"
    attrs(file["bus/voltage/angle"])["format"] = format

    format = compresseArray(file, voltage.minMagnitude, "bus/voltage/minMagnitude")
    attrs(file["bus/voltage/minMagnitude"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/voltage/minMagnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/minMagnitude"])["type"] = "float"
    attrs(file["bus/voltage/minMagnitude"])["format"] = format

    format = compresseArray(file, voltage.maxMagnitude, "bus/voltage/maxMagnitude")
    attrs(file["bus/voltage/maxMagnitude"])["unit"] = "per-unit (p.u.)"
    attrs(file["bus/voltage/maxMagnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/maxMagnitude"])["type"] = "float"
    attrs(file["bus/voltage/maxMagnitude"])["format"] = format

    format = compresseArray(file, voltage.base, "bus/voltage/base")
    attrs(file["bus/voltage/base"])["unit"] = "volt (V)"
    attrs(file["bus/voltage/base"])["type"] = "float"
    attrs(file["bus/voltage/base"])["format"] = format

    format = compresseArray(file, layout.area, "bus/layout/area")
    attrs(file["bus/layout/area"])["type"] = "positive integer"
    attrs(file["bus/layout/area"])["unit"] = "dimensionless"
    attrs(file["bus/layout/area"])["format"] = format

    format = compresseArray(file, layout.lossZone, "bus/layout/lossZone")
    attrs(file["bus/layout/lossZone"])["type"] = "positive integer"
    attrs(file["bus/layout/lossZone"])["unit"] = "dimensionless"
    attrs(file["bus/layout/lossZone"])["format"] = format

    return label, shuntNumber
end

######### Save Branch Data ##########
function saveBranch(system::PowerSystem, labelBus::Array{Int64,1}, file)
    parameter = system.branch.parameter
    rating = system.branch.rating
    voltage = system.branch.voltage
    layout = system.branch.layout

    label = fill(0, system.branch.number)
    @inbounds for (key, value) in system.branch.label
        label[value] = key
    end

    write(file, "branch/layout/label", label)
    attrs(file["branch/layout/label"])["type"] = "positive integer"
    attrs(file["branch/layout/label"])["unit"] = "dimensionless"
    attrs(file["branch/layout/label"])["format"] = "expand"

    format = compresseArray(file, parameter.resistance, "branch/parameter/resistance")
    attrs(file["branch/parameter/resistance"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/parameter/resistance"])["SI unit"] = "ohm"
    attrs(file["branch/parameter/resistance"])["type"] = "float"
    attrs(file["branch/parameter/resistance"])["format"] = format

    format = compresseArray(file, parameter.reactance, "branch/parameter/reactance")
    attrs(file["branch/parameter/reactance"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/parameter/reactance"])["SI unit"] = "ohm"
    attrs(file["branch/parameter/reactance"])["type"] = "float"
    attrs(file["branch/parameter/reactance"])["format"] = format

    format = compresseArray(file, parameter.susceptance, "branch/parameter/susceptance")
    attrs(file["branch/parameter/susceptance"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/parameter/susceptance"])["SI unit"] = "siemens (S)"
    attrs(file["branch/parameter/susceptance"])["type"] = "float"
    attrs(file["branch/parameter/susceptance"])["format"] = format

    format = compresseArray(file, parameter.turnsRatio, "branch/parameter/turnsRatio")
    attrs(file["branch/parameter/turnsRatio"])["unit"] = "dimensionless"
    attrs(file["branch/parameter/turnsRatio"])["type"] = "float"
    attrs(file["branch/parameter/turnsRatio"])["format"] = format

    format = compresseArray(file, parameter.shiftAngle, "branch/parameter/shiftAngle")
    attrs(file["branch/parameter/shiftAngle"])["unit"] = "radian (rad)"
    attrs(file["branch/parameter/shiftAngle"])["type"] = "float"
    attrs(file["branch/parameter/shiftAngle"])["format"] = format

    format = compresseArray(file, rating.longTerm, "branch/rating/longTerm")
    attrs(file["branch/rating/longTerm"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/rating/longTerm"])["SI unit"] = "volt-ampere (VA)"
    attrs(file["branch/rating/longTerm"])["type"] = "float"
    attrs(file["branch/rating/longTerm"])["format"] = format

    format = compresseArray(file, rating.shortTerm, "branch/rating/shortTerm")
    attrs(file["branch/rating/shortTerm"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/rating/shortTerm"])["SI unit"] = "volt-ampere (VA)"
    attrs(file["branch/rating/shortTerm"])["type"] = "float"
    attrs(file["branch/rating/shortTerm"])["format"] = format

    format = compresseArray(file, rating.emergency, "branch/rating/emergency")
    attrs(file["branch/rating/emergency"])["unit"] = "per-unit (p.u.)"
    attrs(file["branch/rating/emergency"])["SI unit"] = "volt-ampere (VA)"
    attrs(file["branch/rating/emergency"])["type"] = "float"
    attrs(file["branch/rating/emergency"])["format"] = format

    format = compresseArray(file, voltage.minAngleDifference, "branch/voltage/minAngleDifference")
    attrs(file["branch/voltage/minAngleDifference"])["unit"] = "radian (rad)"
    attrs(file["branch/voltage/minAngleDifference"])["type"] = "float"
    attrs(file["branch/voltage/minAngleDifference"])["format"] = format

    format = compresseArray(file, voltage.maxAngleDifference, "branch/voltage/maxAngleDifference")
    attrs(file["branch/voltage/maxAngleDifference"])["unit"] = "radian (rad)"
    attrs(file["branch/voltage/maxAngleDifference"])["type"] = "float"
    attrs(file["branch/voltage/maxAngleDifference"])["format"] = format

    format = compresseArray(file, layout.status, "branch/layout/status")
    attrs(file["branch/layout/status"])["in-service"] = 1
    attrs(file["branch/layout/status"])["out-of-service"] = 0
    attrs(file["branch/layout/status"])["unit"] = "dimensionless"
    attrs(file["branch/layout/status"])["type"] = "zero-one integer"
    attrs(file["branch/layout/status"])["format"] = format

    from = fill(0, system.branch.number)
    to = fill(0, system.branch.number)
    transformerNumber = 0
    @inbounds for i = 1:system.branch.number
        from[i] = labelBus[layout.from[i]]
        to[i] = labelBus[layout.to[i]]
        if parameter.shiftAngle[i] != 0 || parameter.turnsRatio[i] != 0
            transformerNumber += 1
        end
    end

    write(file, "branch/layout/from", from)
    attrs(file["branch/layout/from"])["type"] = "positive integer"
    attrs(file["branch/layout/from"])["unit"] = "dimensionless"
    attrs(file["branch/layout/from"])["format"] = "expand"

    write(file, "branch/layout/to", to)
    attrs(file["branch/layout/to"])["type"] = "positive integer"
    attrs(file["branch/layout/to"])["unit"] = "dimensionless"
    attrs(file["branch/layout/to"])["format"] = "expand"

    return transformerNumber
end

######### Save PGenerator Data ##########
function saveGenerator(system::PowerSystem, labelBus::Array{Int64,1}, file)
    output = system.generator.output
    capability = system.generator.capability
    rampRate = system.generator.rampRate
    cost = system.generator.cost
    voltage = system.generator.voltage
    layout = system.generator.layout

    label = fill(0, system.generator.number)
    @inbounds for (key, value) in system.generator.label
        label[value] = key
    end
    write(file, "generator/layout/label", label)
    attrs(file["generator/layout/label"])["type"] = "positive integer"
    attrs(file["generator/layout/label"])["unit"] = "dimensionless"
    attrs(file["generator/layout/label"])["format"] = "expand"

    format = compresseArray(file, output.active, "generator/output/active")
    attrs(file["generator/output/active"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/output/active"])["SI unit"] = "watt (W)"
    attrs(file["generator/output/active"])["type"] = "float"
    attrs(file["generator/output/active"])["format"] = format

    format = compresseArray(file, output.reactive, "generator/output/reactive")
    attrs(file["generator/output/reactive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/output/reactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/output/reactive"])["type"] = "float"
    attrs(file["generator/output/reactive"])["format"] = format

    format = compresseArray(file, capability.minActive, "generator/capability/minActive")
    attrs(file["generator/capability/minActive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/minActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/minActive"])["type"] = "float"
    attrs(file["generator/capability/minActive"])["format"] = format

    format = compresseArray(file, capability.maxActive, "generator/capability/maxActive")
    attrs(file["generator/capability/maxActive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/maxActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/maxActive"])["type"] = "float"
    attrs(file["generator/capability/maxActive"])["format"] = format

    format = compresseArray(file, capability.minReactive, "generator/capability/minReactive")
    attrs(file["generator/capability/minReactive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/minReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minReactive"])["type"] = "float"
    attrs(file["generator/capability/minReactive"])["format"] = format

    format = compresseArray(file, capability.maxReactive, "generator/capability/maxReactive")
    attrs(file["generator/capability/maxReactive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/maxReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxReactive"])["type"] = "float"
    attrs(file["generator/capability/maxReactive"])["format"] = format

    format = compresseArray(file, capability.lowerActive, "generator/capability/lowerActive")
    attrs(file["generator/capability/lowerActive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/lowerActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/lowerActive"])["type"] = "float"
    attrs(file["generator/capability/lowerActive"])["format"] = format

    format = compresseArray(file, capability.minReactiveLower, "generator/capability/minReactiveLower")
    attrs(file["generator/capability/minReactiveLower"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/minReactiveLower"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minReactiveLower"])["type"] = "float"
    attrs(file["generator/capability/minReactiveLower"])["format"] = format

    format = compresseArray(file, capability.maxReactiveLower, "generator/capability/maxReactiveLower")
    attrs(file["generator/capability/maxReactiveLower"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/maxReactiveLower"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxReactiveLower"])["type"] = "float"
    attrs(file["generator/capability/maxReactiveLower"])["format"] = format

    format = compresseArray(file, capability.upperActive, "generator/capability/upperActive")
    attrs(file["generator/capability/upperActive"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/upperActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/upperActive"])["type"] = "float"
    attrs(file["generator/capability/upperActive"])["format"] = format

    format = compresseArray(file, capability.minReactiveUpper, "generator/capability/minReactiveUpper")
    attrs(file["generator/capability/minReactiveUpper"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/minReactiveUpper"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minReactiveUpper"])["type"] = "float"
    attrs(file["generator/capability/minReactiveUpper"])["format"] = format

    format = compresseArray(file, capability.maxReactiveUpper, "generator/capability/maxReactiveUpper")
    attrs(file["generator/capability/maxReactiveUpper"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/capability/maxReactiveUpper"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxReactiveUpper"])["type"] = "float"
    attrs(file["generator/capability/maxReactiveUpper"])["format"] = format

    format = compresseArray(file, rampRate.loadFollowing, "generator/rampRate/loadFollowing")
    attrs(file["generator/rampRate/loadFollowing"])["unit"] = "per-unit per minute (p.u./min)"
    attrs(file["generator/rampRate/loadFollowing"])["SI unit"] = "watt per minute (W/min)"
    attrs(file["generator/rampRate/loadFollowing"])["type"] = "float"
    attrs(file["generator/rampRate/loadFollowing"])["format"] = format

    format = compresseArray(file, rampRate.reserve10minute, "generator/rampRate/reserve10minute")
    attrs(file["generator/rampRate/reserve10minute"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/rampRate/reserve10minute"])["SI unit"] = "watt (W)"
    attrs(file["generator/rampRate/reserve10minute"])["type"] = "float"
    attrs(file["generator/rampRate/reserve10minute"])["format"] = format

    format = compresseArray(file, rampRate.reserve30minute, "generator/rampRate/reserve30minute")
    attrs(file["generator/rampRate/reserve30minute"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/rampRate/reserve30minute"])["SI unit"] = "watt (W)"
    attrs(file["generator/rampRate/reserve30minute"])["type"] = "float"
    attrs(file["generator/rampRate/reserve30minute"])["format"] = format

    format = compresseArray(file, rampRate.reactiveTimescale, "generator/rampRate/reactiveTimescale")
    attrs(file["generator/rampRate/reactiveTimescale"])["unit"] = "per-unit per minute (p.u./min)"
    attrs(file["generator/rampRate/reactiveTimescale"])["SI unit"] = "volt-ampere reactive per minute (VAr/min)"
    attrs(file["generator/rampRate/reactiveTimescale"])["type"] = "float"
    attrs(file["generator/rampRate/reactiveTimescale"])["format"] = format

    if !isempty(cost.activeModel)
        format = compresseArray(file, cost.activeModel, "generator/cost/activeModel")
        attrs(file["generator/cost/activeModel"])["piecewise linear"] = 1
        attrs(file["generator/cost/activeModel"])["polynomial"] = 2
        attrs(file["generator/cost/activeModel"])["type"] = "one-two integer"
        attrs(file["generator/cost/activeModel"])["unit"] = "dimensionless"
        attrs(file["generator/cost/activeModel"])["format"] = format

        format = compresseArray(file, cost.activeStartup, "generator/cost/activeStartup")
        attrs(file["generator/cost/activeStartup"])["unit"] = "currency"
        attrs(file["generator/cost/activeStartup"])["type"] = "float"
        attrs(file["generator/cost/activeStartup"])["format"] = format

        format = compresseArray(file, cost.activeShutdown, "generator/cost/activeShutdown")
        attrs(file["generator/cost/activeShutdown"])["unit"] = "currency"
        attrs(file["generator/cost/activeShutdown"])["type"] = "float"
        attrs(file["generator/cost/activeShutdown"])["format"] = format

        format = compresseArray(file, cost.activeDataPoint, "generator/cost/activeDataPoint")
        attrs(file["generator/cost/activeDataPoint"])["type"] = "positive integer"
        attrs(file["generator/cost/activeDataPoint"])["unit"] = "dimensionless"
        attrs(file["generator/cost/activeDataPoint"])["format"] = format

        format = compresseMatrix(file, cost.activeCoefficient, "generator/cost/activeCoefficient")
        attrs(file["generator/cost/activeCoefficient"])["(model = 2) unit: even coefficient"] = "currency per hour"
        attrs(file["generator/cost/activeCoefficient"])["(model = 2) unit: odd coefficient"] = "per-unit (p.u.)"
        attrs(file["generator/cost/activeCoefficient"])["(model = 2) SI unit: odd coefficient"] = "watt (W)"
        attrs(file["generator/cost/activeCoefficient"])["(model = 1) unit"] = "dimensionless"
        attrs(file["generator/cost/activeCoefficient"])["type"] = "float"
        attrs(file["generator/cost/activeCoefficient"])["format"] = format
    end

    if !isempty(cost.reactiveModel)
        format = compresseArray(file, cost.reactiveModel, "generator/cost/reactiveModel")
        attrs(file["generator/cost/reactiveModel"])["piecewise linear"] = 1
        attrs(file["generator/cost/reactiveModel"])["polynomial"] = 2
        attrs(file["generator/cost/reactiveModel"])["unit"] = "dimensionless"
        attrs(file["generator/cost/reactiveModel"])["type"] = "one-two integer"
        attrs(file["generator/cost/reactiveModel"])["format"] = format

        format = compresseArray(file, cost.reactiveStartup, "generator/cost/reactiveStartup")
        attrs(file["generator/cost/reactiveStartup"])["unit"] = "currency"
        attrs(file["generator/cost/reactiveStartup"])["type"] = "float"
        attrs(file["generator/cost/reactiveStartup"])["format"] = format

        format = compresseArray(file, cost.reactiveShutdown, "generator/cost/reactiveShutdown")
        attrs(file["generator/cost/reactiveShutdown"])["unit"] = "currency"
        attrs(file["generator/cost/reactiveShutdown"])["type"] = "float"
        attrs(file["generator/cost/reactiveShutdown"])["format"] = format

        format = compresseArray(file, cost.reactiveDataPoint, "generator/cost/reactiveDataPoint")
        attrs(file["generator/cost/reactiveDataPoint"])["type"] = "positive integer"
        attrs(file["generator/cost/reactiveDataPoint"])["unit"] = "dimensionless"
        attrs(file["generator/cost/reactiveDataPoint"])["format"] = format

        format = compresseMatrix(file, cost.reactiveCoefficient, "generator/cost/reactiveCoefficient")
        attrs(file["generator/cost/reactiveCoefficient"])["(model = 2) unit: even coefficient"] = "currency per hour"
        attrs(file["generator/cost/reactiveCoefficient"])["(model = 2) unit: odd coefficient"] = "per-unit (p.u.)"
        attrs(file["generator/cost/reactiveCoefficient"])["(model = 2) SI unit: odd coefficient"] = "volt-ampere reactive (VAr)"
        attrs(file["generator/cost/reactiveCoefficient"])["(model = 1) unit"] = "dimensionless"
        attrs(file["generator/cost/reactiveCoefficient"])["type"] = "float"
        attrs(file["generator/cost/reactiveCoefficient"])["format"] = format
    end

    format = compresseArray(file, voltage.magnitude, "generator/voltage/magnitude")
    attrs(file["generator/voltage/magnitude"])["unit"] = "per-unit (p.u.)"
    attrs(file["generator/voltage/magnitude"])["SI unit"] = "volt (V)"
    attrs(file["generator/voltage/magnitude"])["type"] = "float"
    attrs(file["generator/voltage/magnitude"])["format"] = format

    bus = fill(0, system.generator.number)
    @inbounds for (index, value)  in enumerate(layout.bus)
        bus[index] = labelBus[value]
    end
    write(file, "generator/layout/bus", bus)
    attrs(file["generator/layout/bus"])["type"] = "positive integer"
    attrs(file["generator/layout/bus"])["unit"] = "dimensionless"
    attrs(file["generator/layout/bus"])["format"] = "expand"

    format = compresseArray(file, layout.area, "generator/layout/area")
    attrs(file["generator/layout/area"])["unit"] = "dimensionless"
    attrs(file["generator/layout/area"])["type"] = "float"
    attrs(file["generator/layout/area"])["format"] = format

    format = compresseArray(file, layout.status, "generator/layout/status")
    attrs(file["generator/layout/status"])["in-service"] = 1
    attrs(file["generator/layout/status"])["out-of-service"] = 0
    attrs(file["generator/layout/status"])["type"] = "zero-one integer"
    attrs(file["generator/layout/status"])["unit"] = "dimensionless"
    attrs(file["generator/layout/status"])["format"] = format
end

######### Save Main Attributes ##########
function saveMainAttribute(system::PowerSystem, file, reference::String, note::String, transformerNumber::Int64, shuntNumber::Int64)
    attrs(file)["number of buses"] = system.bus.number
    attrs(file)["number of shunt elements"] = shuntNumber
    attrs(file)["number of branches"] = system.branch.number
    attrs(file)["number of generators"] = system.generator.number
    attrs(file)["number of transformers"] = transformerNumber

    if !isempty(reference)
        attrs(file)["reference"] = reference
    end

    if !isempty(note)
        attrs(file)["note"] = note
    end
end

######### Array Compression ##########
function compresseArray(file, data, name::String)
    format = "compressed"
    anchor = data[1]
    @inbounds for i in eachindex(data)
        if data[i] != anchor
            format = "expand"
            break
        end
    end

    if format == "expand"
        write(file, name, data)
    else
        write(file, name, anchor)
    end

    return format
end

######### Matrix Compression ##########
function compresseMatrix(file, data::Array{Float64,2}, name::String)
    format = "compressed"
    anchor = data[1, :]
    Ncol, Nrow = size(data)
    @inbounds for col = 1:Ncol
        for row = 1:Nrow
            if data[col, row] != anchor[row]
                format = "expand"
                break
            end
        end
        if format == "expand"
            break
        end
    end

    if format == "expand"
        write(file, name, data)
    else
        write(file, name, anchor)
    end

    return format
end