function busUnit()
    println("📁 Bus Keyword Units")
    println("├── 📂 Demand Power")
    println("│   ├── active: " * unitList.activePowerLive)
    println("│   └── reactive: " * unitList.reactivePowerLive)
    println("├── 📂 Shunt Power")
    println("│   ├── conductance: " * unitList.activePowerLive)
    println("│   └── susceptance: " * unitList.reactivePowerLive)
    println("├── 📂 Initial Voltage")
    println("│   ├── magnitude: " * unitList.voltageMagnitudeLive)
    println("│   └── angle: " * unitList.voltageAngleLive)
    println("├── 📂 Voltage Magnitude Limit")
    println("│   ├── minMagnitude: " * unitList.voltageMagnitudeLive)
    println("│   └── maxMagnitude: " * unitList.voltageMagnitudeLive)
    println("└── 📂 Base Voltage")
    println("    └── base: " * unitList.voltageBaseLive)
end

function branchUnit()
    println("📁 Branch Keyword Units")
    println("├── 📂 Parameter")
    println("│   ├── resistance: " * unitList.impedanceLive)
    println("│   ├── reactance: " * unitList.impedanceLive)
    println("│   ├── conductance: " * unitList.admittanceLive)
    println("│   ├── susceptance: " * unitList.admittanceLive)
    println("│   └── shiftAngle: " * unitList.voltageAngleLive)
    println("├── 📂 Voltage Angle Difference Limit")
    println("│   ├── minDiffAngle: " * unitList.voltageAngleLive)
    println("│   └── maxDiffAngle: " * unitList.voltageAngleLive)
    println("└── 📂 Flow Limit")
    println("    ├── minFromBus")
    println("    ├── maxFromBus")
    println("    ├── minToBus")
    println("    └─┐ maxToBus")
    println("      ├── type ∈ [1]: ", unitList.activePowerLive)
    println("      ├── type ∈ [2, 3]: ", unitList.apparentPowerLive)
    println("      └── type ∈ [4, 5]: ", unitList.currentMagnitudeLive)
end

function generatorUnit()
    println("📁 Generator Keyword Units")
    println("├── 📂 Output Power")
    println("│   ├── active: " * unitList.activePowerLive)
    println("│   └── reactive: " * unitList.reactivePowerLive)
    println("├── 📂 Output Power Limit")
    println("│   ├── minActive: " * unitList.activePowerLive)
    println("│   ├── maxActive: " * unitList.activePowerLive)
    println("│   ├── minReactive: " * unitList.reactivePowerLive)
    println("│   └── maxReactive: " * unitList.reactivePowerLive)
    println("├── 📂 Capability Curve")
    println("│   ├── lowActive: " * unitList.activePowerLive)
    println("│   ├── minLowReactive: " * unitList.reactivePowerLive)
    println("│   ├── maxLowReactive: " * unitList.reactivePowerLive)
    println("│   ├── upActive: " * unitList.activePowerLive)
    println("│   ├── minUpReactive: " * unitList.reactivePowerLive)
    println("│   └── maxUpReactive: " * unitList.reactivePowerLive)
    println("├── 📂 Voltage")
    println("│   └── magnitude: " * unitList.voltageMagnitudeLive)
    println("├── 📂 Active Power Cost")
    println("│   ├── piecewise: ", unitList.activePowerLive,  ", \$/hr")
    println("│   └── polynomial: \$/", unitList.activePowerLive, "ⁿ-hr")
    println("└── 📂 Reactive Power Cost")
    println("    ├── piecewise: ", unitList.reactivePowerLive,  ", \$/hr")
    println("    └── polynomial: \$/", unitList.reactivePowerLive, "ⁿ-hr")
end

function voltmeterUnit()
    println("📁 Voltmeter Keyword Units")
    println("└── 📂 Voltage Magnitude Measurement")
    println("    ├── magnitude: " * unitList.voltageMagnitudeLive)
    println("    └── variance: " * unitList.voltageMagnitudeLive)
end

function ammeterUnit()
    println("📁 Ammeter Keyword Units")
    println("└── 📂 Current Magnitude Measurement")
    println("    ├── magnitude: " * unitList.currentMagnitudeLive)
    println("    └── variance: " * unitList.currentMagnitudeLive)
end

function wattmeterUnit()
    println("📁 Wattmeter Keyword Units")
    println("└── 📂 Active Power Measurement")
    println("    ├── active: " * unitList.activePowerLive)
    println("    └── variance: " * unitList.activePowerLive)
end

function varmeterUnit()
    println("📁 Varmeter Keyword Units")
    println("└── 📂 Reactive Power Measurement")
    println("    ├── reactive: " * unitList.reactivePowerLive)
    println("    └── variance: " * unitList.reactivePowerLive)
end

function pmuUnit()
    println("📁 PMU Keyword Units")
    println("├── 📂 Voltage Phasor Measurement")
    println("│   ├── magnitude: " * unitList.voltageMagnitudeLive)
    println("│   ├── varianceMagnitude: " * unitList.voltageMagnitudeLive)
    println("│   ├── angle: " * unitList.voltageAngleLive)
    println("│   └── varianceAngle: " * unitList.voltageAngleLive)
    println("└── 📂 Current Phasor Measurement")
    println("    ├── magnitude: " * unitList.currentMagnitudeLive)
    println("    ├── varianceMagnitude: " * unitList.currentMagnitudeLive)
    println("    ├── angle: " * unitList.currentAngleLive)
    println("    └── varianceAngle: " * unitList.currentAngleLive)
end

function busTemplate()
    println("📁 Bus Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.bus.key == String ? template.bus.label : template.bus.key)
    println("├── 📂 Demand Power")
    println("│   ├── active: ", infoTpl(template.bus.active, pfx, unitList, :activePower)...)
    println("│   └── reactive: ", infoTpl(template.bus.reactive, pfx, unitList, :reactivePower)...)
    println("├── 📂 Shunt Power")
    println("│   ├── conductance: ", infoTpl(template.bus.conductance, pfx, unitList, :activePower)...)
    println("│   └── susceptance: ", infoTpl(template.bus.susceptance, pfx, unitList, :reactivePower)...)
    println("├── 📂 Initial Voltage")
    println("│   ├── magnitude: ", infoTpl(template.bus.magnitude, pfx, unitList, :voltageMagnitude)... )
    println("│   └── angle: ", infoTpl(template.bus.angle, pfx, unitList, :voltageAngle)... )
    println("├── 📂 Voltage Magnitude Limit")
    println("│   ├── minMagnitude: ", infoTpl(template.bus.minMagnitude, pfx, unitList, :voltageMagnitude)...)
    println("│   └── maxMagnitude: ", infoTpl(template.bus.maxMagnitude, pfx, unitList, :voltageMagnitude)...)
    println("├── 📂 Base Voltage")
    println("│   └── base: ", template.bus.base / pfx.baseVoltage, " [" * unitList.voltageBaseLive * "]")
    println("└── 📂 Layout")
    println("    ├── type: ", template.bus.type)
    println("    ├── area: ", template.bus.area)
    println("    └── lossZone: ", template.bus.lossZone)
end

function branchTemplate()
    if template.branch.type == 1
        flowType = :activePower
    elseif template.branch.type in (2, 3)
        flowType = :apparentPower
    elseif template.branch.type in (4, 5)
        flowType = :currentMagnitude
    end

    println("📁 Branch Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.branch.key == String ? template.branch.label : template.branch.key)
    println("├── 📂 Parameter")
    println("│   ├── resistance: ", infoTpl(template.branch.resistance, pfx, unitList, :impedance)...)
    println("│   ├── reactance: ", infoTpl(template.branch.reactance, pfx, unitList, :impedance)...)
    println("│   ├── conductance: ", infoTpl(template.branch.conductance, pfx, unitList, :admittance)...)
    println("│   ├── susceptance: ", infoTpl(template.branch.susceptance, pfx, unitList, :admittance)...)
    println("│   ├── turnsRatio: ", template.branch.turnsRatio)
    println("│   └── shiftAngle: ", infoTpl(template.branch.shiftAngle, pfx, unitList, :voltageAngle)...)
    println("├── 📂 Voltage Angle Difference Limit")
    println("│   ├── minDiffAngle: ", infoTpl(template.branch.minDiffAngle, pfx, unitList, :voltageAngle)...)
    println("│   └── maxDiffAngle: ", infoTpl(template.branch.maxDiffAngle, pfx, unitList, :voltageAngle)...)
    println("├── 📂 Flow Limit")
    println("│   ├── minFromBus ", infoTpl(template.branch.minFromBus, pfx, unitList, flowType)...)
    println("│   ├── maxFromBus: ", infoTpl(template.branch.maxFromBus, pfx, unitList, flowType)...)
    println("│   ├── minToBus: ", infoTpl(template.branch.minToBus, pfx, unitList, flowType)...)
    println("│   ├── maxToBus: ", infoTpl(template.branch.maxToBus, pfx, unitList, flowType)...)
    println("│   └── type: ", template.branch.type)
    println("└── 📂 Layout")
    println("    └── status: ", template.branch.status)
end

function generatorTemplate()
    println("📁 Generator Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.generator.key == String ? template.generator.label : template.generator.key)
    println("├── 📂 Output Power")
    println("│   ├── active: ", infoTpl(template.generator.active, pfx, unitList, :activePower)...)
    println("│   └── reactive: ", infoTpl(template.generator.reactive, pfx, unitList, :reactivePower)...)
    println("├── 📂 Output Power Limit")
    println("│   ├── minActive: ", infoTpl(template.generator.minActive, pfx, unitList, :activePower)...)

    val, unit = infoTpl(template.generator.maxActive, pfx, unitList, :activePower)
    isnan(val) && (val = "5 active[i]"; unit = "")
    println("│   ├── maxActive: ", val, unit)

    val, unit = infoTpl(template.generator.minReactive, pfx, unitList, :reactivePower)
    isnan(val) && (val = "-5 reactive[i]"; unit = "")
    println("│   ├── minReactive: ", val, unit)

    val, unit = infoTpl(template.generator.maxReactive, pfx, unitList, :reactivePower)
    isnan(val) && (val = "5 reactive[i]"; unit = "")
    println("│   └── maxReactive: ", val, unit)

    println("├── 📂 Capability Curve")
    println("│   ├── lowActive: ", infoTpl(template.generator.lowActive, pfx, unitList, :activePower)...)
    println("│   ├── minLowReactive: ", infoTpl(template.generator.minLowReactive, pfx, unitList, :reactivePower)...)
    println("│   ├── maxLowReactive: ", infoTpl(template.generator.maxLowReactive, pfx, unitList, :reactivePower)...)
    println("│   ├── upActive: ", infoTpl(template.generator.upActive, pfx, unitList, :activePower)...)
    println("│   ├── minUpReactive: ", infoTpl(template.generator.minUpReactive, pfx, unitList, :reactivePower)...)
    println("│   └── maxUpReactive: ", infoTpl(template.generator.maxUpReactive, pfx, unitList, :reactivePower)...)
    println("├── 📂 Voltage")
    println("│   └── magnitude: ", infoTpl(template.generator.magnitude, pfx, unitList, :voltageMagnitude)...)
    println("└── 📂 Layout")
    println("    └── status: ", template.generator.status)
end

function voltmeterTemplate()
    println("📁 Voltmeter Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.voltmeter.key == String ? template.voltmeter.label : template.voltmeter.key)
    println("├── 📂 Voltage Magnitude Measurement")
    println("│   ├── variance: ", infoTpl(template.voltmeter.variance, pfx, unitList, :voltageMagnitude)...)
    println("│   ├── status: ", template.voltmeter.status)
    println("└── 📂 Setting")
    println("    └── noise: ", template.voltmeter.noise)
end

function ammeterTemplate()
    println("📁 Ammeter Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.ammeter.key == String ? template.ammeter.label : template.ammeter.key)
    println("├── 📂 From-Bus Current Magnitude Measurement")
    println("│   ├── varianceFrom: ", infoTpl(template.ammeter.varianceFrom, pfx, unitList, :currentMagnitude)...)
    println("│   └── statusFrom: ", template.ammeter.statusFrom)
    println("├── 📂 To-Bus Current Magnitude Measurement")
    println("│   ├── varianceTo: ", infoTpl(template.ammeter.varianceTo, pfx, unitList, :currentMagnitude)...)
    println("│   └── statusTo: ", template.ammeter.statusTo)
    println("└── 📂 Setting")
    println("    ├── noise: ", template.ammeter.noise)
    println("    └── square: ", template.ammeter.square)
end

function wattmeterTemplate()
    println("📁 Wattmeter Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.wattmeter.key == String ? template.wattmeter.label : template.wattmeter.key)
    println("├── 📂 Active Power Injection Measurement")
    println("│   ├── varianceBus: ", infoTpl(template.wattmeter.varianceBus, pfx, unitList, :activePower)...)
    println("│   └── statusBus: ", template.wattmeter.statusBus)
    println("├── 📂 From-Bus Active Power Flow Measurement")
    println("│   ├── varianceFrom: ", infoTpl(template.wattmeter.varianceFrom, pfx, unitList, :activePower)...)
    println("│   └── statusFrom: ", template.wattmeter.statusFrom)
    println("├── 📂 To-Bus Active Power Flow Measurement")
    println("│   ├── varianceTo: ", infoTpl(template.wattmeter.varianceTo, pfx, unitList, :activePower)...)
    println("│   └── statusTo: ", template.wattmeter.statusTo)
    println("└── 📂 Setting")
    println("    └── noise: ", template.wattmeter.noise)
end

function varmeterTemplate()
    println("📁 Varmeter Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.varmeter.key == String ? template.varmeter.label : template.varmeter.key)
    println("├── 📂 Reactive Power Injection Measurement")
    println("│   ├── varianceBus: ", infoTpl(template.varmeter.varianceBus, pfx, unitList, :reactivePower)...)
    println("│   └── statusBus: ", template.varmeter.statusBus)
    println("├── 📂 From-Bus Reactive Power Flow Measurement")
    println("│   ├── varianceFrom: ", infoTpl(template.varmeter.varianceFrom, pfx, unitList, :reactivePower)...)
    println("│   └── statusFrom: ", template.varmeter.statusFrom)
    println("├── 📂 To-Bus Reactive Power Flow Measurement")
    println("│   ├── varianceTo: ", infoTpl(template.varmeter.varianceTo, pfx, unitList, :reactivePower)...)
    println("│   └── statusTo: ", template.varmeter.statusTo)
    println("└── 📂 Setting")
    println("    └── noise: ", template.varmeter.noise)
end

function pmuTemplate()
    println("📁 PMU Template")
    println("├── 📂 Label")
    println("│   └── label: ", template.pmu.key == String ? template.pmu.label : template.pmu.key)
    println("├── 📂 Voltage Phasor Measurement")
    println("│   ├── varianceMagnitudeBus: ", infoTpl(template.pmu.varianceMagnitudeBus, pfx, unitList, :voltageMagnitude)...)
    println("│   ├── varianceAngleBus: ", infoTpl(template.pmu.varianceAngleBus, pfx, unitList, :voltageAngle)...)
    println("│   └── statusBus: ", template.pmu.statusFrom)
    println("├── 📂 From-Bus Current Phasor Measurement")
    println("│   ├── varianceMagnitudeFrom: ", infoTpl(template.pmu.varianceMagnitudeFrom, pfx, unitList, :currentMagnitude)...)
    println("│   ├── varianceAngleFrom: ", infoTpl(template.pmu.varianceAngleFrom, pfx, unitList, :currentAngle)...)
    println("│   └── statusFrom: ", template.pmu.statusFrom)
    println("├── 📂 To-Bus Current Phasor Measurement")
    println("│   ├── varianceMagnitudeTo: ", infoTpl(template.pmu.varianceMagnitudeTo, pfx, unitList, :currentMagnitude)...)
    println("│   ├── varianceAngleTo: ", infoTpl(template.pmu.varianceAngleTo, pfx, unitList, :currentAngle)...)
    println("│   └── statusTo: ", template.pmu.statusTo)
    println("└── 📂 Setting")
    println("    ├── noise: ", template.pmu.noise)
    println("    ├── correlated: ", template.pmu.correlated)
    println("    ├── polar: ", template.pmu.polar)
    println("    └── square: ", template.pmu.square)
end

function infoTpl(container::ContainerTemplate, pfx::PrefixLive, unitList::UnitList, field::Symbol)
    if container.pu
        return container.value, " [pu]"
    else
        prefix = getfield(pfx, field)
        if prefix != 0.0
            return container.value / prefix, " [" * getfield(unitList, Symbol(string(field, "Live"))) * "]"
        else
            return container.value, " [" * getfield(unitList, field)[1] * "]"
        end
    end
end

import Base.@info
macro info(obj, field)
    if obj == :unit
        if field == :bus
            return esc(quote
                JuliaGrid.busUnit()
            end)
        elseif field == :branch
            return esc(quote
                JuliaGrid.branchUnit()
            end)
        elseif field == :generator
            return esc(quote
                JuliaGrid.generatorUnit()
            end)
        elseif field == :voltmeter
            return esc(quote
                JuliaGrid.voltmeterUnit()
            end)
        elseif field == :ammeter
            return esc(quote
                JuliaGrid.ammeterUnit()
            end)
        elseif field == :wattmeter
            return esc(quote
                JuliaGrid.wattmeterUnit()
            end)
        elseif field == :varmeter
            return esc(quote
                JuliaGrid.varmeterUnit()
            end)
        elseif field == :pmu
            return esc(quote
                JuliaGrid.pmuUnit()
            end)
        end
    end

    if obj == :template
        if field == :bus
            return esc(quote
                JuliaGrid.busTemplate()
            end)
        elseif field == :branch
            return esc(quote
                JuliaGrid.branchTemplate()
            end)
        elseif field == :generator
            return esc(quote
                JuliaGrid.generatorTemplate()
            end)
        elseif field == :voltmeter
            return esc(quote
                JuliaGrid.voltmeterTemplate()
            end)
        elseif field == :ammeter
            return esc(quote
                JuliaGrid.ammeterTemplate()
            end)
        elseif field == :wattmeter
            return esc(quote
                JuliaGrid.wattmeterTemplate()
            end)
        elseif field == :varmeter
            return esc(quote
                JuliaGrid.varmeterTemplate()
            end)
        elseif field == :pmu
            return esc(quote
                JuliaGrid.pmuTemplate()
            end)
        end
    end
end

function print(
    system::PowerSystem;
    bus::IntStrMiss = missing,
    branch::IntStrMiss = missing,
    generator::IntStrMiss = missing
)
    if isset(bus)
        printBus(system, bus)
    elseif isset(branch)
        printBranch(system, branch)
    elseif isset(generator)
        printGenerator(system, generator)
    end
end

function printBus(system::PowerSystem, bus::IntStr)
    idx = getIndex(system.bus, bus, "bus")
    type = system.bus.layout.type

    println("📁 " * "$bus")

    if checkprint(system.bus.demand, idx)
        println("├── 📂 Demand Power")
        println("│   ├── Active: ", system.bus.demand.active[idx])
        println("│   └── Reactive: ", system.bus.demand.reactive[idx])
    end

    if checkprint(system.bus.supply, idx)
        println("├── 📂 Supply Power")
        println("│   ├── Active: ", system.bus.supply.active[idx])
        println("│   └── Reactive: ", system.bus.supply.reactive[idx])
    end

    if checkprint(system.bus.shunt, idx)
        println("├── 📂 Shunt Power")
        println("│   ├── Conductance: ", system.bus.shunt.conductance[idx])
        println("│   └── Susceptance: ", system.bus.shunt.susceptance[idx])
    end

    println("├── 📂 Initial Voltage")
    println("│   ├── Magnitude: ", system.bus.voltage.magnitude[idx])
    println("│   └── Angle: ", system.bus.voltage.angle[idx])
    println("├── 📂 Voltage Magnitude Limit")
    println("│   ├── Minimum: ", system.bus.voltage.minMagnitude[idx])
    println("│   └── Maximum: ", system.bus.voltage.maxMagnitude[idx])
    println("├── 📂 Base Voltage")
    println("│   ├── Value: ", system.base.voltage.value[idx])
    println("│   └── Unit: ", system.base.voltage.unit)
    println("└── 📂 Layout")
    println("    ├── Type: ", type[idx] == 1 ? "demand" : type[idx] == 2 ? "generator" : "slack")
    println("    ├── Area: ", system.bus.layout.area[idx])
    println("    ├── Loss Zone: ", system.bus.layout.lossZone[idx])
    println("    └── Index: ", idx)
end

function printBranch(system::PowerSystem, branch::IntStr)
    idx = getIndex(system.branch, branch, "branch")

    if system.branch.flow.type[idx] == 1
        flowType = "Active Power Limit"
    elseif system.branch.flow.type[idx] in (2, 3)
        flowType = "Apparent Power Limit"
    elseif system.branch.flow.type[idx] in (4, 5)
        flowType = "Current Magnitude Limit"
    end

    println("📁 " * "$branch")
    println("├── 📂 Parameter")
    println("│   ├── Resistance: ", system.branch.parameter.resistance[idx])
    println("│   ├── Reactance: ", system.branch.parameter.reactance[idx])
    println("│   ├── Conductance: ", system.branch.parameter.conductance[idx])
    println("│   ├── Susceptance: ", system.branch.parameter.susceptance[idx])
    println("│   ├── Turns Ratio: ", system.branch.parameter.turnsRatio[idx])
    println("│   └── Phase Shift Angle: ", system.branch.parameter.shiftAngle[idx])

    if checkprint(system.branch.flow, idx)
        println("├── 📂 " * flowType)
        println("│   ├── From-Bus Minimum: ", system.branch.flow.minFromBus[idx])
        println("│   ├── From-Bus Maximum: ", system.branch.flow.maxFromBus[idx])
        println("│   ├── To-Bus Minimum: ", system.branch.flow.minToBus[idx])
        println("│   ├── To-Bus Maximum: ", system.branch.flow.maxToBus[idx])
    end

    if system.branch.voltage.minDiffAngle[idx] > -2π || system.branch.voltage.maxDiffAngle[idx] < 2π
        println("├── 📂 Voltage Angle Difference Limit")
        println("│   ├── Minimum: ", system.branch.voltage.minDiffAngle[idx])
        println("│   └── Maximum: ", system.branch.voltage.maxDiffAngle[idx])
    end

    println("└── 📂 Layout")
    println("    ├── From-Bus: ", getLabel(system.bus.label, system.branch.layout.from[idx]))
    println("    ├── To-Bus: ", getLabel(system.bus.label, system.branch.layout.to[idx]))
    println("    ├── Status: ", system.branch.layout.status[idx])
    println("    └── Index: ", idx)
end

function printGenerator(system::PowerSystem, generator::IntStr)
    idx = getIndex(system.generator, generator, "generator")

    p = system.generator.cost.active
    q = system.generator.cost.reactive
    c = system.generator.capability

    println("📁 " * "$generator")
    println("├── 📂 Output Power")
    println("│   ├── Active: ", system.generator.output.active[idx])
    println("│   └── Reactive: ", system.generator.output.reactive[idx])

    if c.minActive[idx] != 0.0 || c.maxActive[idx] != Inf || c.minReactive[idx] != -Inf || c.maxReactive[idx] != Inf
        println("├── 📂 Output Power Limit")
        println("│   ├── Minimum Active: ", c.minActive[idx])
        println("│   ├── Maximum Active: ", c.maxActive[idx])
        println("│   ├── Minimum Reactive: ", c.minReactive[idx])
        println("│   └── Maximum Reactive: ", c.maxReactive[idx])
    end

    if any(x -> x != 0, (
        c.lowActive[idx], c.minLowReactive[idx], c.maxLowReactive[idx],
        c.upActive[idx], c.minUpReactive[idx], c.maxUpReactive[idx]))

        println("├── 📂 Capability Curve")
        println("│   ├── Low Active: ", c.lowActive[idx])
        println("│   ├── Minimum Reactive: ", c.minLowReactive[idx])
        println("│   ├── Maximum Reactive: ", c.maxLowReactive[idx])
        println("│   ├── Up Active: ", c.upActive[idx])
        println("│   ├── Minimum Reactive: ", c.minUpReactive[idx])
        println("│   └── Maximum Reactive: ", c.maxUpReactive[idx])
    end

    println("├── 📂 Voltage")
    println("│   └── Magnitude: ", system.generator.voltage.magnitude[idx])

    if haskey(p.polynomial, idx) || haskey(p.piecewise, idx)
        println("├── 📂 Active Power Cost")
        println("│   ├── Polynomial: ", get(p.polynomial, idx, "undefined"))
        println("│   ├── Piecewise: ", get(p.piecewise, idx, "undefined"))
        println("│   ├── In-Use: ", p.model[idx] == 1 ? "piecewise" : p.model[idx] == 2 ? "polynomial" : "undefined")
    end

    if haskey(q.polynomial, idx) || haskey(q.piecewise, idx)
        println("├── 📂 Reactive Power Cost")
        println("│   ├── Polynomial: ", get(q.polynomial, idx, "undefined"))
        println("│   ├── Piecewise: ", get(q.piecewise, idx, "undefined"))
        println("│   ├── In-Use: ", q.model[idx] == 1 ? "piecewise" : q.model[idx] == 2 ? "polynomial" : "undefined")
    end

    println("└── 📂 Layout")
    println("    ├── Bus: ", getLabel(system.bus.label, system.generator.layout.bus[idx]))
    println("    ├── Status: ", system.generator.layout.status[idx])
    println("    └── Index: ", idx)
end


function print(
    monitoring::Measurement;
    voltmeter::IntStrMiss = missing,
    ammeter::IntStrMiss = missing,
    wattmeter::IntStrMiss = missing,
    varmeter::IntStrMiss = missing,
    pmu::IntStrMiss = missing
)
    if isset(voltmeter)
        printVoltmeter(monitoring, voltmeter)
    elseif isset(ammeter)
        printAmmeter(monitoring, ammeter)
    elseif isset(wattmeter)
        printWattmeter(monitoring, wattmeter)
    elseif isset(varmeter)
        printVarmeter(monitoring, varmeter)
    elseif isset(pmu)
        printPmu(monitoring, pmu)
    end
end

function printVoltmeter(monitoring::Measurement, voltmeter::IntStr)
    idx = getIndex(monitoring.voltmeter, voltmeter, "voltmeter")

    println("📁 " * "$voltmeter")
    println("├── 📂 Voltage Magnitude Measurement")
    println("│   ├── Mean: ", monitoring.voltmeter.magnitude.mean[idx])
    println("│   ├── Variance: ", monitoring.voltmeter.magnitude.variance[idx])
    println("│   └── Status: ", monitoring.voltmeter.magnitude.status[idx])
    println("└── 📂 Layout")
    println("    ├── Bus: ", getLabel(monitoring.system.bus.label, monitoring.voltmeter.layout.index[idx]))
    println("    └── Index: ", idx)
end

function printAmmeter(monitoring::Measurement, ammeter::IntStr)
    idx = getIndex(monitoring.ammeter, ammeter, "ammeter")
    label = getLabel(monitoring.system.branch.label, monitoring.ammeter.layout.index[idx])

    println("📁 " * "$ammeter")
    println("├── 📂 Current Magnitude Measurement")
    println("│   ├── Mean: ", monitoring.ammeter.magnitude.mean[idx])
    println("│   ├── Variance: ", monitoring.ammeter.magnitude.variance[idx])
    println("│   └── Status: ", monitoring.ammeter.magnitude.status[idx])
    println("└── 📂 Layout")

    if monitoring.ammeter.layout.from[idx]
        println("    ├── From-Bus: ", label)
    else
        println("    ├── To-Bus: ", label)
    end

    println("    └── Index: ", idx)
end

function printWattmeter(monitoring::Measurement, wattmeter::IntStr)
    idx = getIndex(monitoring.wattmeter, wattmeter, "wattmeter")

    if monitoring.wattmeter.layout.bus[idx]
        label = getLabel(monitoring.system.bus.label, monitoring.wattmeter.layout.index[idx])
    else
        label = getLabel(monitoring.system.branch.label, monitoring.wattmeter.layout.index[idx])
    end

    println("📁 " * "$wattmeter")
    println("├── 📂 Active Power Measurement")
    println("│   ├── Mean: ", monitoring.wattmeter.active.mean[idx])
    println("│   ├── Variance: ", monitoring.wattmeter.active.variance[idx])
    println("│   └── Status: ", monitoring.wattmeter.active.status[idx])
    println("└── 📂 Layout")

    if monitoring.wattmeter.layout.bus[idx]
        println("    ├── Bus: ", label)
    elseif monitoring.wattmeter.layout.from[idx]
        println("    ├── From-Bus: ", label)
    else
        println("    ├── To-Bus: ", label)
    end

    println("    └── Index: ", idx)
end

function printVarmeter(monitoring::Measurement, varmeter::IntStr)
    idx = getIndex(monitoring.varmeter, varmeter, "varmeter")

    if monitoring.varmeter.layout.bus[idx]
        label = getLabel(monitoring.system.bus.label, monitoring.varmeter.layout.index[idx])
    else
        label = getLabel(monitoring.system.branch.label, monitoring.varmeter.layout.index[idx])
    end

    println("📁 " * "$varmeter")
    println("├── 📂 Reactive Power Measurement")
    println("│   ├── Mean: ", monitoring.varmeter.reactive.mean[idx])
    println("│   ├── Variance: ", monitoring.varmeter.reactive.variance[idx])
    println("│   └── Status: ", monitoring.varmeter.reactive.status[idx])
    println("└── 📂 Layout")

    if monitoring.varmeter.layout.bus[idx]
        println("    ├── Bus: ", label)
    elseif monitoring.varmeter.layout.from[idx]
        println("    ├── From-Bus: ", label)
    else
        println("    ├── To-Bus: ", label)
    end

    println("    └── Index: ", idx)
end

function printPmu(monitoring::Measurement, pmu::IntStr)
    idx = getIndex(monitoring.pmu, pmu, "pmu")

    if monitoring.pmu.layout.bus[idx]
        label = getLabel(monitoring.system.bus.label, monitoring.pmu.layout.index[idx])
    else
        label = getLabel(monitoring.system.branch.label, monitoring.pmu.layout.index[idx])
    end

    println("📁 " * "$pmu")

    if monitoring.pmu.layout.bus[idx]
        println("├── 📂 Voltage Magnitude Measurement")
    else
        println("├── 📂 Current Magnitude Measurement")
    end

    println("│   ├── Mean: ", monitoring.pmu.magnitude.mean[idx])
    println("│   ├── Variance: ", monitoring.pmu.magnitude.variance[idx])
    println("│   └── Status: ", monitoring.pmu.magnitude.status[idx])

    if monitoring.pmu.layout.bus[idx]
        println("├── 📂 Voltage Angle Measurement")
    else
        println("├── 📂 Current Angle Measurement")
    end

    println("│   ├── Mean: ", monitoring.pmu.angle.mean[idx])
    println("│   ├── Variance: ", monitoring.pmu.angle.variance[idx])
    println("│   └── Status: ", monitoring.pmu.angle.status[idx])

    println("└── 📂 Layout")

    if monitoring.pmu.layout.bus[idx]
        println("    ├── Bus: ", label)
    elseif monitoring.pmu.layout.from[idx]
        println("    ├── From-Bus: ", label)
    else
        println("    ├── To-Bus: ", label)
    end

    println("    ├── Polar: ", monitoring.pmu.layout.polar[idx])
    println("    ├── Correlated: ", monitoring.pmu.layout.correlated[idx])
    println("    └── Index: ", idx)
end