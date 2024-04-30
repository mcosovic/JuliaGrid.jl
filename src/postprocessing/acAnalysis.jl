"""
    power!(system::PowerSystem, analysis::AC)

The function computes the active and reactive powers associated with buses, branches, and
generators for AC analysis.

# Updates
This function updates the `power` field of the `AC` abstract type by computing the
following electrical quantities:
- `injection`: Active and reactive power bus injections.
- `supply`: Active and reactive power bus injections from the generators.
- `shunt`: Active and reactive power values associated with shunt element at each bus.
- `from`: Active and reactive power flows at the from-bus end of each branch.
- `to`: Active and reactive power flows at the to-bus end of each branch.
- `charging`: Active and reactive power values linked with branch charging admittances for each branch.
- `series` Active and reactive power losses through each branch series impedance.
- `generator`: Produced active and reactive power outputs of each generator (not for state estimation).

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)
```
"""
function power!(system::PowerSystem, analysis::ACPowerFlow)
    ac = system.model.ac
    slack = system.bus.layout.slack
    parameter = system.branch.parameter

    voltage = analysis.voltage
    power = analysis.power
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)
    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)
    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltage.magnitude[i]^2 * conj(system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i])
        power.shunt.active[i] = real(powerShunt)
        power.shunt.reactive[i] = imag(powerShunt)

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end

        powerInjection = conj(I) * voltageBus
        power.injection.active[i] = real(powerInjection)
        power.injection.reactive[i] = imag(powerInjection)

        power.supply.active[i] = system.bus.supply.active[i]
        if system.bus.layout.type[i] != 1
            power.supply.reactive[i] = power.injection.reactive[i] + system.bus.demand.reactive[i]
        else
            power.supply.reactive[i] = system.bus.supply.reactive[i]
        end
    end
    power.supply.active[slack] = power.injection.active[slack] + system.bus.demand.active[slack]

    power.from.active = fill(0.0, system.branch.number)
    power.from.reactive = fill(0.0, system.branch.number)
    power.to.active = fill(0.0, system.branch.number)
    power.to.reactive = fill(0.0, system.branch.number)
    power.charging.active = fill(0.0, system.branch.number)
    power.charging.reactive = fill(0.0, system.branch.number)
    power.series.active = fill(0.0, system.branch.number)
    power.series.reactive = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i])
            power.from.active[i] = real(powerFrom)
            power.from.reactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i])
            power.to.active[i] = real(powerTo)
            power.to.reactive[i] = imag(powerTo)

            turnsRatioInv = 1 / parameter.turnsRatio[i]
            transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[i])

            voltageSeries = transformerRatio * voltageFrom - voltageTo
            series = voltageSeries * conj(ac.admittance[i] * voltageSeries)
            power.series.active[i] = real(series)
            power.series.reactive[i] = imag(series)

            admittanceConj = 0.5 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            charging = admittanceConj * ((turnsRatioInv * voltage.magnitude[from])^2 + voltage.magnitude[to]^2)
            power.charging.active[i] = real(charging)
            power.charging.reactive[i] = imag(charging)
        end
    end

    power.generator.active = fill(0.0, system.generator.number)
    power.generator.reactive = fill(0.0, system.generator.number)
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]
            inService = length(system.bus.supply.generator[busIndex])

            if inService == 1
                power.generator.active[i] = system.generator.output.active[i]
                power.generator.reactive[i] = power.injection.reactive[busIndex] + system.bus.demand.reactive[busIndex]
                if busIndex == system.bus.layout.slack
                    power.generator.active[i] = power.injection.active[busIndex] + system.bus.demand.active[busIndex]
                end
            else
                Qmintotal = 0.0
                Qmaxtotal = 0.0
                Qgentotal = 0.0
                QminInf = 0.0
                QmaxInf = 0.0
                QminNew = system.generator.capability.minReactive[i]
                QmaxNew = system.generator.capability.maxReactive[i]

                generatorIndex = system.bus.supply.generator[busIndex]
                for j in generatorIndex
                    if !isinf(system.generator.capability.minReactive[j])
                        Qmintotal += system.generator.capability.minReactive[j]
                    end
                    if !isinf(system.generator.capability.maxReactive[j])
                        Qmaxtotal += system.generator.capability.maxReactive[j]
                    end
                    Qgentotal += (power.injection.reactive[busIndex] + system.bus.demand.reactive[busIndex]) / inService
                end
                for j in generatorIndex
                    if isinf(system.generator.capability.minReactive[j])
                        Qmin = -abs(Qgentotal) - abs(Qmintotal) - abs(Qmaxtotal)
                        if system.generator.capability.minReactive[j] == Inf
                            Qmin = -Qmin
                        end
                        if i == j
                            QminNew = Qmin
                        end
                        QminInf += Qmin
                    end
                    if isinf(system.generator.capability.maxReactive[j])
                        Qmax = abs(Qgentotal) + abs(Qmintotal) + abs(Qmaxtotal)
                        if system.generator.capability.maxReactive[j] == -Inf
                            Qmax = -Qmax
                        end
                        if i == j
                            QmaxNew = Qmax
                        end
                        QmaxInf += Qmax
                    end
                end
                Qmintotal += QminInf
                Qmaxtotal += QmaxInf

                if basePowerMVA * abs(Qmintotal - Qmaxtotal) > 10 * eps(Float64)
                    power.generator.reactive[i] = QminNew + ((Qgentotal - Qmintotal) / (Qmaxtotal - Qmintotal)) * (QmaxNew - QminNew)
                else
                    power.generator.reactive[i] = QminNew + (Qgentotal - Qmintotal) / inService
                end

                if busIndex == system.bus.layout.slack && generatorIndex[1] == i
                    power.generator.active[i] = power.injection.active[busIndex] + system.bus.demand.active[busIndex]

                    for j = 2:inService
                        power.generator.active[i] -= system.generator.output.active[generatorIndex[j]]
                    end
                else
                    power.generator.active[i] = system.generator.output.active[i]
                end
            end
        end
    end
end

function power!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    ac = system.model.ac
    voltage = analysis.voltage
    power = analysis.power
    parameter = system.branch.parameter
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)
    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i]))
        power.shunt.active[i] = real(powerShunt)
        power.shunt.reactive[i] = imag(powerShunt)

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end

        powerInjection = conj(I) * voltageBus
        power.injection.active[i] = real(powerInjection)
        power.injection.reactive[i] = imag(powerInjection)
    end

    power.from.active = fill(0.0, system.branch.number)
    power.from.reactive = fill(0.0, system.branch.number)
    power.to.active = fill(0.0, system.branch.number)
    power.to.reactive = fill(0.0, system.branch.number)
    power.charging.active = fill(0.0, system.branch.number)
    power.charging.reactive = fill(0.0, system.branch.number)
    power.series.active = fill(0.0, system.branch.number)
    power.series.reactive = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i])
            power.from.active[i] = real(powerFrom)
            power.from.reactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i])
            power.to.active[i] = real(powerTo)
            power.to.reactive[i] = imag(powerTo)

            turnsRatioInv = 1 / parameter.turnsRatio[i]
            transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[i])

            voltageSeries = transformerRatio * voltageFrom - voltageTo
            series = voltageSeries * conj(ac.admittance[i] * voltageSeries)
            power.series.active[i] = real(series)
            power.series.reactive[i] = imag(series)

            admittanceConj = 0.5 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            charging = admittanceConj * ((turnsRatioInv * voltage.magnitude[from])^2 + voltage.magnitude[to]^2)
            power.charging.active[i] = real(charging)
            power.charging.reactive[i] = imag(charging)
        end
    end

    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.generator.number
        busIndex = system.generator.layout.bus[i]

        power.supply.active[busIndex] += analysis.power.generator.active[i]
        power.supply.reactive[busIndex] += analysis.power.generator.reactive[i]
    end
end

function power!(system::PowerSystem, analysis::Union{PMUStateEstimation, ACStateEstimation})
    ac = system.model.ac
    voltage = analysis.voltage
    power = analysis.power
    parameter = system.branch.parameter
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)
    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)
    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i]))
        power.shunt.active[i] = real(powerShunt)
        power.shunt.reactive[i] = imag(powerShunt)

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end

        powerInjection = conj(I) * voltageBus
        power.injection.active[i] = real(powerInjection)
        power.injection.reactive[i] = imag(powerInjection)

        power.supply.active[i] = power.injection.active[i] + system.bus.demand.active[i]
        power.supply.reactive[i] = power.injection.reactive[i] + system.bus.demand.reactive[i]
    end

    power.from.active = fill(0.0, system.branch.number)
    power.from.reactive = fill(0.0, system.branch.number)
    power.to.active = fill(0.0, system.branch.number)
    power.to.reactive = fill(0.0, system.branch.number)
    power.charging.active = fill(0.0, system.branch.number)
    power.charging.reactive = fill(0.0, system.branch.number)
    power.series.active = fill(0.0, system.branch.number)
    power.series.reactive = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i])
            power.from.active[i] = real(powerFrom)
            power.from.reactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i])
            power.to.active[i] = real(powerTo)
            power.to.reactive[i] = imag(powerTo)

            turnsRatioInv = 1 / parameter.turnsRatio[i]
            transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[i])

            voltageSeries = transformerRatio * voltageFrom - voltageTo
            series = voltageSeries * conj(ac.admittance[i] * voltageSeries)
            power.series.active[i] = real(series)
            power.series.reactive[i] = imag(series)

            admittanceConj = 0.5 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            charging = admittanceConj * ((turnsRatioInv * voltage.magnitude[from])^2 + voltage.magnitude[to]^2)
            power.charging.active[i] = real(charging)
            power.charging.reactive[i] = imag(charging)
        end
    end
end

"""
    injectionPower(system::PowerSystem, analysis::AC, label)

The function returns the active and reactive power injections associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = injectionPower(system, analysis; label = 1)
```
"""
function injectionPower(system::PowerSystem, analysis::AC; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    I = 0.0 + im * 0.0
    for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[j]
        I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
    end
    powerInjection = conj(I) * voltage.magnitude[index] * exp(im * voltage.angle[index])

    return real(powerInjection), imag(powerInjection)
end

"""
    supplyPower(system::PowerSystem, analysis::AC, label)

The function returns the active and reactive power injections from the generators
associated with a specific bus in the AC framework. The `label` keyword argument must
match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = supplyPower(system, analysis; label = 1)
```
"""
function supplyPower(system::PowerSystem, analysis::ACPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.bus.layout.type[index] != 1
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end
        powerInjection = conj(I) * voltage.magnitude[index] * exp(im * voltage.angle[index])
    end

    if system.bus.layout.type[index] == 3
        supplyActive = real(powerInjection) + system.bus.demand.active[index]
    else
        supplyActive = system.bus.supply.active[index]
    end

    if system.bus.layout.type[index] != 1
        supplyReactive = imag(powerInjection) + system.bus.demand.reactive[index]
    else
        supplyReactive = system.bus.supply.reactive[index]
    end

    return supplyActive, supplyReactive
end

function supplyPower(system::PowerSystem, analysis::ACOptimalPowerFlow; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.magnitude)

    supplyActive = 0.0
    supplyReactive = 0.0
    @inbounds for i in system.bus.supply.generator[index]
        supplyActive += analysis.power.generator.active[i]
        supplyReactive += analysis.power.generator.reactive[i]
    end

    return supplyActive, supplyReactive
end

function supplyPower(system::PowerSystem, analysis::Union{PMUStateEstimation, ACStateEstimation}; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    active, reactive = injectionPower(system, analysis; label = label)

    return active + system.bus.demand.active[index], reactive + system.bus.demand.reactive[index]
end

"""
    shuntPower(system::PowerSystem, analysis::AC, label)

The function returns the active and reactive power values of the shunt element associated
with a specific bus in the AC framework. The `label` keyword argument must match an
existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = shuntPower(system, analysis; label = 9)
```
```
"""
function shuntPower(system::PowerSystem, analysis::AC; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.magnitude)

    powerShunt = analysis.voltage.magnitude[index]^2 * conj(system.bus.shunt.conductance[index] + im * system.bus.shunt.susceptance[index])

    return real(powerShunt), imag(powerShunt)
end

"""
    fromPower(system::PowerSystem, analysis::AC; label)

The function returns the active and reactive power flows at the from-bus end associated
with a specific branch in the AC framework. The `label` keyword argument must match an
existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = fromPower(system, analysis; label = 2)
```
"""
function fromPower(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[index] + voltageTo * ac.nodalFromTo[index])
    else
        powerFrom = 0.0 + im * 0.0
    end

    return real(powerFrom), imag(powerFrom)
end

"""
    toPower(system::PowerSystem, analysis::AC; label)

The function returns the active and reactive power flows at the to-bus end associated
with a specific branch in the AC framework. The `label` keyword argument must match an
existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = toPower(system, analysis; label = 2)
```
"""
function toPower(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index])
    else
        powerTo = 0.0 + im * 0.0
    end

    return real(powerTo), imag(powerTo)
end

"""
    chargingPower(system::PowerSystem, analysis::AC; label)

The function returns the active and reactive power values associated with the charging
admittances of a specific branch in the AC framework. The `label` keyword argument must
correspond to an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = chargingPower(system, analysis; label = 2)
```
"""
function chargingPower(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    voltage = analysis.voltage
    parameter = system.branch.parameter

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]
        admittanceConj = 0.5 * conj(system.branch.parameter.conductance[index] + im * system.branch.parameter.susceptance[index])

        charging = admittanceConj * ((voltage.magnitude[from] / parameter.turnsRatio[index])^2 + voltage.magnitude[to]^2)
    else
        charging = 0.0 + im * 0.0
    end

    return real(charging), imag(charging)
end

"""
    seriesPower(system::PowerSystem, analysis::AC; label)

The function returns the active and reactive power losses across the series impedance of
a specific branch within the AC framework. The `label` keyword argument should correspond
to an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = seriesPower(system, analysis; label = 2)
```
"""
function seriesPower(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage
    parameter = system.branch.parameter

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])
        transformerRatio = exp(-im * parameter.shiftAngle[index]) / parameter.turnsRatio[index]

        voltageSeries = transformerRatio * voltageFrom - voltageTo
        series = voltageSeries * conj(ac.admittance[index] * voltageSeries)
    else
        series = 0.0 + im * 0.0
    end

    return real(series), imag(series)
end

"""
    generatorPower(system::PowerSystem, analysis::AC)

The function returns the active and reactive powers associated with a specific generator
in the AC framework. The `label` keyword argument must match an existing generator label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
active, reactive = generatorPower(system, analysis; label = 1)
```
"""
function generatorPower(system::PowerSystem, analysis::ACPowerFlow; label)
    index = system.generator.label[getLabel(system.generator, label, "generator")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage
    busIndex = system.generator.layout.bus[index]

    if system.generator.layout.status[index] == 1
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[busIndex]:(ac.nodalMatrix.colptr[busIndex + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end
        powerInjection = conj(I) * voltage.magnitude[busIndex] * exp(im * voltage.angle[busIndex])
        injectionActive = real(powerInjection)
        injectionReactive = imag(powerInjection)

        inService = length(system.bus.supply.generator[busIndex])
        if inService == 1
            powerActive = system.generator.output.active[index]
            powerReactive = injectionReactive + system.bus.demand.reactive[busIndex]
            if busIndex == system.bus.layout.slack
                powerActive = injectionActive + system.bus.demand.active[busIndex]
            end
        else
            Qmintotal = 0.0
            Qmaxtotal = 0.0
            Qgentotal = 0.0
            QminInf = 0.0
            QmaxInf = 0.0
            QminNew = system.generator.capability.minReactive[index]
            QmaxNew = system.generator.capability.maxReactive[index]

            generatorIndex = system.bus.supply.generator[busIndex]
            @inbounds for i in generatorIndex
                if !isinf(system.generator.capability.minReactive[i])
                    Qmintotal += system.generator.capability.minReactive[i]
                end
                if !isinf(system.generator.capability.maxReactive[i])
                    Qmaxtotal += system.generator.capability.maxReactive[i]
                end
                Qgentotal += (injectionReactive + system.bus.demand.reactive[busIndex]) / inService
            end

            @inbounds for i in generatorIndex
                if isinf(system.generator.capability.minReactive[i])
                    Qmin = -abs(Qgentotal) - abs(Qmintotal) - abs(Qmaxtotal)
                    if system.generator.capability.minReactive[i] == Inf
                        Qmin = -Qmin
                    end
                    if i == index
                        QminNew = Qmin
                    end
                    QminInf += Qmin
                end
                if isinf(system.generator.capability.maxReactive[i])
                    Qmax = abs(Qgentotal) + abs(Qmintotal) + abs(Qmaxtotal)
                    if system.generator.capability.maxReactive[i] == -Inf
                        Qmax = -Qmax
                    end
                    if i == index
                        QmaxNew = Qmax
                    end
                    QmaxInf += Qmax
                end
            end
            Qmintotal += QminInf
            Qmaxtotal += QmaxInf

            basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
            if basePowerMVA * abs(Qmintotal - Qmaxtotal) > 10 * eps(Float64)
                powerReactive = QminNew + ((Qgentotal - Qmintotal) / (Qmaxtotal - Qmintotal)) * (QmaxNew - QminNew)
            else
                powerReactive = QminNew + (Qgentotal - Qmintotal) / inService
            end

            if busIndex == system.bus.layout.slack && generatorIndex[1] == index
                powerActive = injectionActive + system.bus.demand.active[busIndex]

                for i = 2:inService
                    powerActive -= system.generator.output.active[generatorIndex[i]]
                end
            else
                powerActive = system.generator.output.active[index]
            end
        end
    else
        powerActive = 0.0
        powerReactive = 0.0
    end

    return powerActive, powerReactive
end

function generatorPower(system::PowerSystem, analysis::ACOptimalPowerFlow; label)
    index = system.generator.label[getLabel(system.generator, label, "generator")]
    errorVoltage(analysis.voltage.angle)

    return analysis.power.generator.active[index], analysis.power.generator.reactive[index]
end

"""
    current!(system::PowerSystem, analysis::AC)

The function computes the currents in the polar coordinate system associated with buses
and branches in the AC framework.

# Updates
This function calculates various electrical quantities in the polar coordinate system:
- `injection`: Current injections at each bus.
- `from`: Current flows at each from-bus end of the branch.
- `to`: Current flows at each to-bus end of the branch.
- `series`: Current flows through the series impedance of the branch in the direction from the from-bus end to the to-bus end of the branch.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)
```
"""
function current!(system::PowerSystem, analysis::AC)
    ac = system.model.ac

    voltage = analysis.voltage
    current = analysis.current
    errorVoltage(voltage.magnitude)

    current.injection.magnitude = fill(0.0, system.bus.number)
    current.injection.angle = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * (voltage.magnitude[k] * exp(im * voltage.angle[k]))
        end

        current.injection.magnitude[i] = abs(I)
        current.injection.angle[i] = angle(I)
    end

    current.from.magnitude = fill(0.0, system.branch.number)
    current.from.angle = fill(0.0, system.branch.number)
    current.to.magnitude = fill(0.0, system.branch.number)
    current.to.angle = fill(0.0, system.branch.number)
    current.series.magnitude = fill(0.0, system.branch.number)
    current.series.angle = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            currentFrom = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            current.from.magnitude[i] = abs(currentFrom)
            current.from.angle[i] = angle(currentFrom)

            currentTo = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            current.to.magnitude[i] = abs(currentTo)
            current.to.angle[i] = angle(currentTo)

            transformerRatio = (1 / system.branch.parameter.turnsRatio[i]) * exp(-im * system.branch.parameter.shiftAngle[i])
            currentBranch = ac.admittance[i] * (transformerRatio * voltageFrom - voltageTo)
            current.series.magnitude[i] = abs(currentBranch)
            current.series.angle[i] = angle(currentBranch)
        end
    end
end

"""
    injectionCurrent(system::PowerSystem, analysis::AC; label)

The function returns the current injection in the polar coordinate system associated with
a specific bus in the AC framework. The `label` keyword argument must match an existing
bus label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
magnitude, angle = injectionCurrent(system, analysis; label = 1)
```
"""
function injectionCurrent(system::PowerSystem, analysis::AC; label)
    index = system.bus.label[getLabel(system.bus, label, "bus")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    I = 0.0 + im * 0.0
    for i in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[i]
        I += ac.nodalMatrixTranspose.nzval[i] * (voltage.magnitude[k] * exp(im * voltage.angle[k]))
    end

    return abs(I), angle(I)
end

"""
    fromCurrent(system::PowerSystem, analysis::AC; label)

The function returns the current in the polar coordinate system at the from-bus end
associated with a specific branch in the AC framework. The `label` keyword argument must
match an existing branch label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
magnitude, angle = fromCurrent(system, analysis; label = 2)
```
"""
function fromCurrent(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        currentFrom = voltageFrom * ac.nodalFromFrom[index] + voltageTo * ac.nodalFromTo[index]
    else
        currentFrom = 0.0 + im * 0.0
    end

    return abs(currentFrom), angle(currentFrom)
end

"""
    toCurrent(system::PowerSystem, analysis::AC; label)

The function returns the current in the polar coordinate system at the to-bus end
associated with a specific branch in the AC framework. The `label` keyword argument must
match an existing branch label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
magnitude, angle = toCurrent(system, analysis; label = 2)
```
"""
function toCurrent(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        currentTo = voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index]
    else
        currentTo = 0.0 + im * 0.0
    end

    return abs(currentTo), angle(currentTo)
end

"""
    seriesCurrent(system::PowerSystem, analysis::AC; label)

The function returns the current in the polar coordinate system through series impedance
associated with a specific branch in the direction from the from-bus end to the to-bus
end of the branch within the AC framework. The `label` keyword argument must  match an
existing branch label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
magnitude, angle = seriesCurrent(system, analysis; label = 2)
```
"""
function seriesCurrent(system::PowerSystem, analysis::AC; label)
    index = system.branch.label[getLabel(system.branch, label, "branch")]
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    voltage = analysis.voltage

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])
        transformerRatio = (1 / system.branch.parameter.turnsRatio[index]) * exp(-im * system.branch.parameter.shiftAngle[index])

        currentSeries = ac.admittance[index] * (transformerRatio * voltageFrom - voltageTo)
    else
        currentSeries = 0.0 + im * 0.0
    end

    return abs(currentSeries), angle(currentSeries)
end