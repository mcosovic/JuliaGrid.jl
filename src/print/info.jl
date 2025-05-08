function infoBusUnit()
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

function infoBranchUnit()
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

function infoGeneratorUnit()
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

function infoVoltmeterUnit()
    println("📁 Voltmeter Keyword Units")
    println("└── 📂 Voltage Magnitude Measurement")
    println("    ├── magnitude: " * unitList.voltageMagnitudeLive)
    println("    └── variance: " * unitList.voltageMagnitudeLive)
end

function infoAmmeterUnit()
    println("📁 Ammeter Keyword Units")
    println("└── 📂 Current Magnitude Measurement")
    println("    ├── magnitude: " * unitList.currentMagnitudeLive)
    println("    └── variance: " * unitList.currentMagnitudeLive)
end

function infoWattmeterUnit()
    println("📁 Wattmeter Keyword Units")
    println("└── 📂 Active Power Measurement")
    println("    ├── active: " * unitList.activePowerLive)
    println("    └── variance: " * unitList.activePowerLive)
end

function infoVarmeterUnit()
    println("📁 Varmeter Keyword Units")
    println("└── 📂 Reactive Power Measurement")
    println("    ├── reactive: " * unitList.reactivePowerLive)
    println("    └── variance: " * unitList.reactivePowerLive)
end

function infoPmuUnit()
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

function infoBusTemplate()
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

function infoBranchTemplate()
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

function infoGeneratorTemplate()
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
                infoBusUnit()
            end)
        elseif field == :branch
            return esc(quote
                infoBranchUnit()
            end)
        elseif field == :generator
            return esc(quote
                infoGeneratorUnit()
            end)
        elseif field == :voltmeter
            return esc(quote
                infoVoltmeterUnit()
            end)
        elseif field == :ammeter
            return esc(quote
                infoAmmeterUnit()
            end)
        elseif field == :wattmeter
            return esc(quote
                infoWattmeterUnit()
            end)
        elseif field == :varmeter
            return esc(quote
                infoVarmeterUnit()
            end)
        elseif field == :pmu
            return esc(quote
                infoPmuUnit()
            end)
        end
    end

    if obj == :template
        if field == :bus
            return esc(quote
                infoBusTemplate()
            end)
        elseif field == :branch
            return esc(quote
                infoBranchTemplate()
            end)
        elseif field == :generator
            return esc(quote
                infoGeneratorTemplate()
            end)
        end
    end
end