"""
    savePowerSystem(system::PowerSystem; path::String, reference::String, note::String)

The function saves the power system's data in the HDF5 file using the fields `bus`, `branch`,
`generator`, and `base` from the `PowerSystem` composite type.

# Keywords
The location and file name of the HDF5 file is specified by the mandatory keyword `path` in 
the format of `"path/name.h5"`. Additional information can be provided by the optional 
keywords `reference` and `note`, which can be saved along with the power system data.

# View HDF5 File
To view the saved HDF5 file, you can use the [HDFView](https://www.hdfgroup.org/downloads/hdfview/)
software.

# Example
```jldoctest
system = powerSystem("case14.m")
savePowerSystem(system; path = "D:/case14.h5")
```
"""
function savePowerSystem(system::PowerSystem; path::String, reference::String = "", note::String = "")
    file = h5open(path, "w")
        saveBase(system, file)
        label, shuntNumber = saveBus(system, file)
        transformerNumber = saveBranch(system, label, file)
        saveGenerator(system, label, file)
        saveMainAttribute(system, file, reference, note, transformerNumber, shuntNumber)
    close(file)
end

######### Save Base Power ##########
function saveBase(system::PowerSystem, file)
    write(file, "base/power", system.base.power.value * system.base.power.prefix)
    attrs(file["base/power"])["unit"] = "volt-ampere (VA)"
    attrs(file["base/power"])["format"] = "number"

    format = compresseArray(file, system.base.voltage.value * system.base.voltage.prefix, "base/voltage")
    attrs(file["base/voltage"])["unit"] = "volt (V)"
    attrs(file["base/voltage"])["type"] = "float"
    attrs(file["base/voltage"])["format"] = format

end

######### Save Bus Data ##########
function saveBus(system::PowerSystem, file)
    demand = system.bus.demand
    shunt = system.bus.shunt
    voltage = system.bus.voltage
    layout = system.bus.layout

    label = fill(0, system.bus.number)
    shuntNumber = 0
    @inbounds for (key, value) in system.bus.label
        label[value] = key
        if shunt.conductance[value] != 0 || shunt.susceptance[value] != 0
            shuntNumber += 1
        end
    end
    
    write(file, "bus/layout/label", label)
    attrs(file["bus/layout/label"])["type"] = "positive integer"
    attrs(file["bus/layout/label"])["unit"] = "dimensionless"
    attrs(file["bus/layout/label"])["format"] = "expand"

    write(file, "bus/layout/type", layout.type)
    attrs(file["bus/layout/type"])["demand bus (PQ)"] = 1
    attrs(file["bus/layout/type"])["generator bus (PV)"] = 2
    attrs(file["bus/layout/type"])["slack bus"] = 3
    attrs(file["bus/layout/type"])["type"] = "positive integer"
    attrs(file["bus/layout/type"])["unit"] = "dimensionless"
    attrs(file["bus/layout/type"])["format"] = "expand"

    format = compresseArray(file, demand.active, "bus/demand/active")
    attrs(file["bus/demand/active"])["unit"] = "per-unit (pu)"
    attrs(file["bus/demand/active"])["SI unit"] = "watt (W)"
    attrs(file["bus/demand/active"])["type"] = "float"
    attrs(file["bus/demand/active"])["format"] = format

    format = compresseArray(file, demand.reactive, "bus/demand/reactive")
    attrs(file["bus/demand/reactive"])["unit"] = "per-unit (pu)"
    attrs(file["bus/demand/reactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["bus/demand/reactive"])["type"] = "float"
    attrs(file["bus/demand/reactive"])["format"] = format

    format = compresseArray(file, shunt.conductance, "bus/shunt/conductance")
    attrs(file["bus/shunt/conductance"])["unit"] = "per-unit (pu)"
    attrs(file["bus/shunt/conductance"])["SI unit"] = "watt at voltage magnitude of 1 per-unit (W)"
    attrs(file["bus/shunt/conductance"])["type"] = "float"
    attrs(file["bus/shunt/conductance"])["format"] = format

    format = compresseArray(file, shunt.susceptance, "bus/shunt/susceptance")
    attrs(file["bus/shunt/susceptance"])["unit"] = "per-unit (pu)"
    attrs(file["bus/shunt/susceptance"])["SI unit"] = "volt-ampere reactive at voltage magnitude of 1 per-unit (VAr)"
    attrs(file["bus/shunt/susceptance"])["type"] = "float"
    attrs(file["bus/shunt/susceptance"])["format"] = format

    format = compresseArray(file, voltage.magnitude, "bus/voltage/magnitude")
    attrs(file["bus/voltage/magnitude"])["unit"] = "per-unit (pu)"
    attrs(file["bus/voltage/magnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/magnitude"])["type"] = "float"
    attrs(file["bus/voltage/magnitude"])["format"] = format

    format = compresseArray(file, voltage.angle, "bus/voltage/angle")
    attrs(file["bus/voltage/angle"])["unit"] = "radian (rad)"
    attrs(file["bus/voltage/angle"])["type"] = "float"
    attrs(file["bus/voltage/angle"])["format"] = format

    format = compresseArray(file, voltage.minMagnitude, "bus/voltage/minMagnitude")
    attrs(file["bus/voltage/minMagnitude"])["unit"] = "per-unit (pu)"
    attrs(file["bus/voltage/minMagnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/minMagnitude"])["type"] = "float"
    attrs(file["bus/voltage/minMagnitude"])["format"] = format

    format = compresseArray(file, voltage.maxMagnitude, "bus/voltage/maxMagnitude")
    attrs(file["bus/voltage/maxMagnitude"])["unit"] = "per-unit (pu)"
    attrs(file["bus/voltage/maxMagnitude"])["SI unit"] = "volt (V)"
    attrs(file["bus/voltage/maxMagnitude"])["type"] = "float"
    attrs(file["bus/voltage/maxMagnitude"])["format"] = format

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
    attrs(file["branch/parameter/resistance"])["unit"] = "per-unit (pu)"
    attrs(file["branch/parameter/resistance"])["SI unit"] = "ohm"
    attrs(file["branch/parameter/resistance"])["type"] = "float"
    attrs(file["branch/parameter/resistance"])["format"] = format

    format = compresseArray(file, parameter.reactance, "branch/parameter/reactance")
    attrs(file["branch/parameter/reactance"])["unit"] = "per-unit (pu)"
    attrs(file["branch/parameter/reactance"])["SI unit"] = "ohm"
    attrs(file["branch/parameter/reactance"])["type"] = "float"
    attrs(file["branch/parameter/reactance"])["format"] = format

    format = compresseArray(file, parameter.susceptance, "branch/parameter/susceptance")
    attrs(file["branch/parameter/susceptance"])["unit"] = "per-unit (pu)"
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

    format = compresseArray(file, voltage.minDiffAngle, "branch/voltage/minDiffAngle")
    attrs(file["branch/voltage/minDiffAngle"])["unit"] = "radian (rad)"
    attrs(file["branch/voltage/minDiffAngle"])["type"] = "float"
    attrs(file["branch/voltage/minDiffAngle"])["format"] = format

    format = compresseArray(file, voltage.maxDiffAngle, "branch/voltage/maxDiffAngle")
    attrs(file["branch/voltage/maxDiffAngle"])["unit"] = "radian (rad)"
    attrs(file["branch/voltage/maxDiffAngle"])["type"] = "float"
    attrs(file["branch/voltage/maxDiffAngle"])["format"] = format

    format = compresseArray(file, rating.longTerm, "branch/rating/longTerm")
    attrs(file["branch/rating/longTerm"])["unit"] = "per-unit (pu)"
    attrs(file["branch/rating/longTerm"])["SI unit"] = "volt-ampere (VA) or watt (W)"
    attrs(file["branch/rating/longTerm"])["type"] = "float"
    attrs(file["branch/rating/longTerm"])["format"] = format

    format = compresseArray(file, rating.shortTerm, "branch/rating/shortTerm")
    attrs(file["branch/rating/shortTerm"])["unit"] = "per-unit (pu)"
    attrs(file["branch/rating/shortTerm"])["SI unit"] = "volt-ampere (VA) or watt (W)"
    attrs(file["branch/rating/shortTerm"])["type"] = "float"
    attrs(file["branch/rating/shortTerm"])["format"] = format

    format = compresseArray(file, rating.emergency, "branch/rating/emergency")
    attrs(file["branch/rating/emergency"])["unit"] = "per-unit (pu)"
    attrs(file["branch/rating/emergency"])["SI unit"] = "volt-ampere (VA) or watt (W)"
    attrs(file["branch/rating/emergency"])["type"] = "float"
    attrs(file["branch/rating/emergency"])["format"] = format

    format = compresseArray(file, rating.type, "branch/rating/type")
    attrs(file["branch/rating/type"])["apparent power flow"] = 1
    attrs(file["branch/rating/type"])["active power flow"] = 2
    attrs(file["branch/rating/type"])["current magnitude"] = 3
    attrs(file["branch/rating/type"])["unit"] = "dimensionless"
    attrs(file["branch/rating/type"])["type"] = "one-two-three integer"
    attrs(file["branch/rating/type"])["format"] = format

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

######### Save Generator Data ##########
function saveGenerator(system::PowerSystem, labelBus::Array{Int64,1}, file)
    output = system.generator.output
    capability = system.generator.capability
    ramping = system.generator.ramping
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
    attrs(file["generator/output/active"])["unit"] = "per-unit (pu)"
    attrs(file["generator/output/active"])["SI unit"] = "watt (W)"
    attrs(file["generator/output/active"])["type"] = "float"
    attrs(file["generator/output/active"])["format"] = format

    format = compresseArray(file, output.reactive, "generator/output/reactive")
    attrs(file["generator/output/reactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/output/reactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/output/reactive"])["type"] = "float"
    attrs(file["generator/output/reactive"])["format"] = format

    format = compresseArray(file, capability.minActive, "generator/capability/minActive")
    attrs(file["generator/capability/minActive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/minActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/minActive"])["type"] = "float"
    attrs(file["generator/capability/minActive"])["format"] = format

    format = compresseArray(file, capability.maxActive, "generator/capability/maxActive")
    attrs(file["generator/capability/maxActive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/maxActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/maxActive"])["type"] = "float"
    attrs(file["generator/capability/maxActive"])["format"] = format

    format = compresseArray(file, capability.minReactive, "generator/capability/minReactive")
    attrs(file["generator/capability/minReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/minReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minReactive"])["type"] = "float"
    attrs(file["generator/capability/minReactive"])["format"] = format

    format = compresseArray(file, capability.maxReactive, "generator/capability/maxReactive")
    attrs(file["generator/capability/maxReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/maxReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxReactive"])["type"] = "float"
    attrs(file["generator/capability/maxReactive"])["format"] = format

    format = compresseArray(file, capability.lowActive, "generator/capability/lowActive")
    attrs(file["generator/capability/lowActive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/lowActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/lowActive"])["type"] = "float"
    attrs(file["generator/capability/lowActive"])["format"] = format

    format = compresseArray(file, capability.minLowReactive, "generator/capability/minLowReactive")
    attrs(file["generator/capability/minLowReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/minLowReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minLowReactive"])["type"] = "float"
    attrs(file["generator/capability/minLowReactive"])["format"] = format

    format = compresseArray(file, capability.maxLowReactive, "generator/capability/maxLowReactive")
    attrs(file["generator/capability/maxLowReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/maxLowReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxLowReactive"])["type"] = "float"
    attrs(file["generator/capability/maxLowReactive"])["format"] = format

    format = compresseArray(file, capability.upActive, "generator/capability/upActive")
    attrs(file["generator/capability/upActive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/upActive"])["SI unit"] = "watt (W)"
    attrs(file["generator/capability/upActive"])["type"] = "float"
    attrs(file["generator/capability/upActive"])["format"] = format

    format = compresseArray(file, capability.minUpReactive, "generator/capability/minUpReactive")
    attrs(file["generator/capability/minUpReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/minUpReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/minUpReactive"])["type"] = "float"
    attrs(file["generator/capability/minUpReactive"])["format"] = format

    format = compresseArray(file, capability.maxUpReactive, "generator/capability/maxUpReactive")
    attrs(file["generator/capability/maxUpReactive"])["unit"] = "per-unit (pu)"
    attrs(file["generator/capability/maxUpReactive"])["SI unit"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/capability/maxUpReactive"])["type"] = "float"
    attrs(file["generator/capability/maxUpReactive"])["format"] = format

    format = compresseArray(file, ramping.loadFollowing, "generator/ramping/loadFollowing")
    attrs(file["generator/ramping/loadFollowing"])["unit"] = "per-unit per minute (pu/min)"
    attrs(file["generator/ramping/loadFollowing"])["SI unit"] = "watt per minute (W/min)"
    attrs(file["generator/ramping/loadFollowing"])["type"] = "float"
    attrs(file["generator/ramping/loadFollowing"])["format"] = format

    format = compresseArray(file, ramping.reserve10min, "generator/ramping/reserve10min")
    attrs(file["generator/ramping/reserve10min"])["unit"] = "per-unit (pu)"
    attrs(file["generator/ramping/reserve10min"])["SI unit"] = "watt (W)"
    attrs(file["generator/ramping/reserve10min"])["type"] = "float"
    attrs(file["generator/ramping/reserve10min"])["format"] = format

    format = compresseArray(file, ramping.reserve30min, "generator/ramping/reserve30min")
    attrs(file["generator/ramping/reserve30min"])["unit"] = "per-unit (pu)"
    attrs(file["generator/ramping/reserve30min"])["SI unit"] = "watt (W)"
    attrs(file["generator/ramping/reserve30min"])["type"] = "float"
    attrs(file["generator/ramping/reserve30min"])["format"] = format

    format = compresseArray(file, ramping.reactiveTimescale, "generator/ramping/reactiveTimescale")
    attrs(file["generator/ramping/reactiveTimescale"])["unit"] = "per-unit per minute (pu/min)"
    attrs(file["generator/ramping/reactiveTimescale"])["SI unit"] = "volt-ampere reactive per minute (VAr/min)"
    attrs(file["generator/ramping/reactiveTimescale"])["type"] = "float"
    attrs(file["generator/ramping/reactiveTimescale"])["format"] = format

    format = compresseArray(file, cost.active.model, "generator/cost/active/model")
    attrs(file["generator/cost/active/model"])["piecewise linear"] = 1
    attrs(file["generator/cost/active/model"])["polynomial"] = 2
    attrs(file["generator/cost/active/model"])["type"] = "one-two integer"
    attrs(file["generator/cost/active/model"])["unit"] = "dimensionless"
    attrs(file["generator/cost/active/model"])["format"] = format

    format = savePolynomial(file, cost.active.polynomial, "generator/cost/active/polynomial")
    attrs(file["generator/cost/active/polynomial"])["unit"] = "determined at the output active power given in watt (W)"
    attrs(file["generator/cost/active/polynomial"])["type"] = "float"
    attrs(file["generator/cost/active/polynomial"])["format"] = format

    format = savePiecewise(file, cost.active.piecewise, "generator/cost/active/piecewise")
    attrs(file["generator/cost/active/piecewise"])["unit: even term"] = "currency per hour"
    attrs(file["generator/cost/active/piecewise"])["unit: odd term"] = "per-unit (pu)"
    attrs(file["generator/cost/active/piecewise"])["SI unit: odd term"] = "watt (W)"
    attrs(file["generator/cost/active/piecewise"])["type"] = "float"
    attrs(file["generator/cost/active/piecewise"])["format"] = format

    format = compresseArray(file, cost.reactive.model, "generator/cost/reactive/model")
    attrs(file["generator/cost/reactive/model"])["piecewise linear"] = 1
    attrs(file["generator/cost/reactive/model"])["polynomial"] = 2
    attrs(file["generator/cost/reactive/model"])["type"] = "one-two integer"
    attrs(file["generator/cost/reactive/model"])["unit"] = "dimensionless"
    attrs(file["generator/cost/reactive/model"])["format"] = format

    format = savePolynomial(file, cost.reactive.polynomial, "generator/cost/reactive/polynomial")
    attrs(file["generator/cost/reactive/polynomial"])["unit"] = "determined at the output reactive power given in volt-ampere reactive (VAr)"
    attrs(file["generator/cost/reactive/polynomial"])["type"] = "float"
    attrs(file["generator/cost/reactive/polynomial"])["format"] = format

    format = savePiecewise(file, cost.reactive.piecewise, "generator/cost/reactive/piecewise")
    attrs(file["generator/cost/reactive/piecewise"])["unit: even term"] = "currency per hour"
    attrs(file["generator/cost/reactive/piecewise"])["unit: odd term"] = "per-unit (pu)"
    attrs(file["generator/cost/reactive/piecewise"])["SI unit: odd term"] = "volt-ampere reactive (VAr)"
    attrs(file["generator/cost/reactive/piecewise"])["type"] = "float"
    attrs(file["generator/cost/reactive/piecewise"])["format"] = format

    format = compresseArray(file, voltage.magnitude, "generator/voltage/magnitude")
    attrs(file["generator/voltage/magnitude"])["unit"] = "per-unit (pu)"
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

    if !isempty(data)
        anchor = data[1]
        @inbounds for i in eachindex(data)
            if data[i] != anchor
                format = "expand"
                break
            end
        end
    else
        anchor = data
    end

    if format == "expand"
        write(file, name, data)
    else
        write(file, name, anchor)
    end

    return format
end

######### Save Polynomial Cost Terms ##########
function savePolynomial(file, data, name::String)
    format = "empty"

    highestPolynomial  = 0
    index = Array{Int64,1}(undef, 0)
    @inbounds for i in eachindex(data)
        if !isempty(data[i])
            highestPolynomial = max(highestPolynomial, length(data[i]))
            push!(index, i)
        end
    end

    polynomial = zeros(highestPolynomial + 2, length(index))
    @inbounds for (k, i) in enumerate(index)
        polynomial[1, k] = i
        polynomial[2, k] = length(data[i])
        for j = 1:length(data[i])
            polynomial[j + 2, k] = data[i][j]
        end
    end

    if highestPolynomial > 0
        format = "expand"
    end

    write(file, name, polynomial)

    return format
end

######### Save Piecewise Cost Terms ##########
function savePiecewise(file, data, name::String)
    costNumber = size(data, 1)
    format = "empty"

    numberPiecewise = 0
    @inbounds for i = 1:costNumber
        if !isempty(data[i])
            format = "expand"
            numberPiecewise += size(data[i], 1)
        end
    end

    piecewise = zeros(numberPiecewise, 3)

    point = 1
    @inbounds for i = 1:costNumber
        if !isempty(data[i])
            for j = 1:size(data[i], 1)
                piecewise[point, 1] = i
                piecewise[point, 2] = data[i][j, 1]
                piecewise[point, 3] = data[i][j, 2]
                point += 1
            end
        end
    end

    write(file, name, piecewise)

    return format
end