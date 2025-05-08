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
                voltmeterTemplate()
            end)
        elseif field == :ammeter
            return esc(quote
                ammeterTemplate()
            end)
        elseif field == :wattmeter
            return esc(quote
                wattmeterTemplate()
            end)
        elseif field == :varmeter
            return esc(quote
                varmeterTemplate()
            end)
        elseif field == :pmu
            return esc(quote
                pmuTemplate()
            end)
        end
    end
end