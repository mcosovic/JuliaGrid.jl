"""
    power(system::PowerSystem, model::ACPowerFlow)

The function computes the powers associated with buses, branches, and generators in the AC power flow
framework.

# Returns
The function returns two instances of types.

The `PowerBus` type contains the following fields:
- `injection`: the active and reactive power injections
- `supply`: the active and reactive power injected by the generators
- `shunt`: the active and reactive power associated with shunt elements.

The `CurrentBus` type contains the following field:
- `injection`: the magnitude and angle of current injections.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

power, current = analysisBus(system, model)
```
"""
function power(system::PowerSystem, model::ACPowerFlow)
    ac = system.acModel
    slack = system.bus.layout.slack

    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    injectionActive = fill(0.0, system.bus.number)
    injectionReactive = fill(0.0, system.bus.number)
    supplyActive = fill(0.0, system.bus.number)
    supplyReactive = fill(0.0, system.bus.number)
    shuntActive = fill(0.0, system.bus.number)
    shuntReactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[i] + im * system.bus.shunt.susceptance[i]))
        shuntActive[i] = real(powerShunt)
        shuntReactive[i] = imag(powerShunt)

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end

        powerInjection = conj(I) * voltageBus
        injectionActive[i] = real(powerInjection)
        injectionReactive[i] = imag(powerInjection)

        supplyActive[i] = system.bus.supply.active[i]
        if system.bus.layout.type[i] != 1
            supplyReactive[i] = injectionReactive[i] + system.bus.demand.reactive[i]
        else
            supplyReactive[i] = system.bus.supply.reactive[i]
        end
    end
    supplyActive[slack] = injectionActive[slack] + system.bus.demand.active[slack]

    fromActive = fill(0.0, system.branch.number)
    fromReactive = fill(0.0, system.branch.number)
    toActive = fill(0.0, system.branch.number)
    toReactive = fill(0.0, system.branch.number)
    shuntReactive = fill(0.0, system.branch.number)
    lossActive = fill(0.0, system.branch.number)
    lossReactive = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            f = system.branch.layout.from[i]
            t = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
            voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

            currentFrom = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            powerFrom = voltageFrom * conj(currentFrom)
            fromActive[i] = real(powerFrom)
            fromReactive[i] = imag(powerFrom)

            currentTo = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            powerTo = voltageTo * conj(currentTo)
            toActive[i] = real(powerTo)
            toReactive[i] = imag(powerTo)

            shuntReactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[t]^2)

            currentBranch = abs(ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo))
            lossActive[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            lossReactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]
        end
    end

    powerActive = fill(0.0, system.generator.number)
    powerReactive = fill(0.0, system.generator.number)
    isMultiple = false
    for i in system.generator.layout.bus
        if system.bus.supply.inService[i] > 1
            isMultiple = true
            break
        end
    end

    if isMultiple
        Qmintotal = fill(0.0, system.bus.number)
        Qmaxtotal = fill(0.0, system.bus.number)
        QminInf = fill(0.0, system.bus.number)
        QmaxInf = fill(0.0, system.bus.number)
        QminNew = copy(system.generator.capability.minReactive)
        QmaxNew = copy(system.generator.capability.maxReactive)
        Qgentotal = fill(0.0, system.bus.number)

        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                if !isinf(system.generator.capability.minReactive[i])
                    Qmintotal[j] += system.generator.capability.minReactive[i]
                end
                if !isinf(system.generator.capability.maxReactive[i])
                    Qmaxtotal[j] += system.generator.capability.maxReactive[i]
                end
                Qgentotal[j] += (injectionReactive[j] + system.bus.demand.reactive[j]) / system.bus.supply.inService[j]
            end
        end
        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                if system.generator.capability.minReactive[i] == Inf
                    QminInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                end
                if system.generator.capability.minReactive[i] == -Inf
                    QminInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                end
                if system.generator.capability.maxReactive[i] == Inf
                    QmaxInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                end
                if system.generator.capability.maxReactive[i] == -Inf
                    QmaxInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                end
            end
        end
        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                if isinf(system.generator.capability.minReactive[i])
                    Qmintotal[j] += QminInf[i]
                    QminNew[i] = QminInf[i]
                end
                if isinf(system.generator.capability.maxReactive[i])
                    Qmaxtotal[j] += QmaxInf[i]
                    QmaxNew[i] =  QmaxInf[i]
                end
            end
        end

        tempSlack = 0
        basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                if basePowerMVA * abs(Qmintotal[j] - Qmaxtotal[j]) > 10 * eps(Float64)
                    powerReactive[i] = QminNew[i] + ((Qgentotal[j] - Qmintotal[j]) / (Qmaxtotal[j] - Qmintotal[j])) * (QmaxNew[i] - QminNew[i])
                else
                    powerReactive[i] = QminNew[i] + (Qgentotal[j] - Qmintotal[j]) / system.bus.supply.inService[j]
                end

                powerActive[i] = system.generator.output.active[i]
                if j == system.bus.layout.slack
                    if tempSlack != 0
                        powerActive[tempSlack] -= powerActive[i]
                    end
                    if tempSlack == 0
                        powerActive[i] = injectionActive[j] + system.bus.demand.active[j]
                        tempSlack = i
                    end
                end
            end
        end
    else
        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                powerActive[i] = system.generator.output.active[i]
                powerReactive[i] = injectionReactive[j] + system.bus.demand.reactive[j]
                if j == system.bus.layout.slack
                    powerActive[i] = injectionActive[j] + system.bus.demand.active[j]
                end
            end
        end
    end

    return Power(
        PowerBus(
            Cartesian(injectionActive, injectionReactive),
            Cartesian(supplyActive, supplyReactive),
            Cartesian(shuntActive, shuntReactive)
        ),
        PowerBranch(
            Cartesian(fromActive, fromReactive),
            Cartesian(toActive, toReactive),
            CartesianImag(shuntReactive),
            Cartesian(lossActive, lossReactive)
        ),
        PowerGenerator(
            Cartesian(powerActive, powerReactive)
        )
    )
end

"""
    powerBus(system::PowerSystem, model::ACPowerFlow)
"""
function powerBus(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    slack = system.bus.layout.slack
    voltage = model.voltage

    index = system.bus.label[label]

    voltageBus = voltage.magnitude[index] * exp(im * voltage.angle[index])

    powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[index] + im * system.bus.shunt.susceptance[index]))
    shuntActive = real(powerShunt)
    shuntReactive = imag(powerShunt)

    I = 0.0 + im * 0.0
    for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[j]
        I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
    end

    powerInjection = conj(I) * voltageBus
    injectionActive = real(powerInjection)
    injectionReactive = imag(powerInjection)

    if system.bus.layout.type[index] == 3
        supplyActive = injectionActive + system.bus.demand.active[index]
    else
        supplyActive = system.bus.supply.active[index]
    end

    if system.bus.layout.type[index] != 1
        supplyReactive = injectionReactive + system.bus.demand.reactive[index]
    else
        supplyReactive = system.bus.supply.reactive[index]
    end

    return PowerBus(
        Cartesian(injectionActive, injectionReactive),
        Cartesian(supplyActive, supplyReactive),
        Cartesian(shuntActive, shuntReactive)
    )
end

"""
    powerBranch(system::PowerSystem, model::ACPowerFlow)
"""
function powerBranch(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    slack = system.bus.layout.slack
    voltage = model.voltage

    index = system.branch.label[label]

    if system.branch.layout.status[index] == 1
        f = system.branch.layout.from[index]
        t = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
        voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

        currentFrom = voltageFrom * ac.nodalFromFrom[index] + voltageTo * ac.nodalFromTo[index]
        powerFrom = voltageFrom * conj(currentFrom)
        fromActive = real(powerFrom)
        fromReactive = imag(powerFrom)

        currentTo = voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index]
        powerTo = voltageTo * conj(currentTo)
        toActive = real(powerTo)
        toReactive = imag(powerTo)

        shuntReactive = 0.5 * system.branch.parameter.susceptance[index] * (abs(voltageFrom / ac.transformerRatio[index])^2 +  voltage.magnitude[t]^2)

        currentBranch = abs(ac.admittance[index] * (voltageFrom / ac.transformerRatio[index] - voltageTo))
        lossActive = currentBranch^2 * system.branch.parameter.resistance[index]
        lossReactive = currentBranch^2 * system.branch.parameter.reactance[index]
    else
        fromActive = 0.0
        fromReactive = 0.0
        toActive = 0.0
        toReactive = 0.0
        shuntReactive = 0.0
        lossActive = 0.0
        lossReactive = 0.0
    end

    return PowerBranch(
        Cartesian(fromActive, fromReactive),
        Cartesian(toActive, toReactive),
        CartesianImag(shuntReactive),
        Cartesian(lossActive, lossReactive)
    )

end

"""
    powerGenerator(system::PowerSystem, model::ACPowerFlow)
"""
function powerGenerator(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.magnitude)

    isMultiple = false
    @inbounds for i in system.generator.layout.bus
        if system.bus.supply.inService[i] > 1
            isMultiple = true
            break
        end
    end

    if isMultiple
        Qmintotal = 0.0
        Qmaxtotal = fill(0.0, system.bus.number)
        QminInf = fill(0.0, system.bus.number)
        QmaxInf = fill(0.0, system.bus.number)
        QminNew = copy(system.generator.capability.minReactive)
        QmaxNew = copy(system.generator.capability.maxReactive)
        Qgentotal = fill(0.0, system.bus.number)

        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                if !isinf(system.generator.capability.minReactive[i])
                    Qmintotal[j] += system.generator.capability.minReactive[i]
                end
                if !isinf(system.generator.capability.maxReactive[i])
                    Qmaxtotal[j] += system.generator.capability.maxReactive[i]
                end
                Qgentotal[j] += (injectionReactive[j] + system.bus.demand.reactive[j]) / system.bus.supply.inService[j]
            end
        end

    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            j = system.generator.layout.bus[i]
            if system.generator.capability.minReactive[i] == Inf
                QminInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
            end
            if system.generator.capability.minReactive[i] == -Inf
                QminInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
            end
            if system.generator.capability.maxReactive[i] == Inf
                QmaxInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
            end
            if system.generator.capability.maxReactive[i] == -Inf
                QmaxInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
            end
        end
    end
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            j = system.generator.layout.bus[i]
            if isinf(system.generator.capability.minReactive[i])
                Qmintotal[j] += QminInf[i]
                QminNew[i] = QminInf[i]
            end
            if isinf(system.generator.capability.maxReactive[i])
                Qmaxtotal[j] += QmaxInf[i]
                QmaxNew[i] =  QmaxInf[i]
            end
        end
    end

    tempSlack = 0
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            j = system.generator.layout.bus[i]
            if basePowerMVA * abs(Qmintotal[j] - Qmaxtotal[j]) > 10 * eps(Float64)
                powerReactive[i] = QminNew[i] + ((Qgentotal[j] - Qmintotal[j]) / (Qmaxtotal[j] - Qmintotal[j])) * (QmaxNew[i] - QminNew[i])
            else
                powerReactive[i] = QminNew[i] + (Qgentotal[j] - Qmintotal[j]) / system.bus.supply.inService[j]
            end

            powerActive[i] = system.generator.output.active[i]
            if j == system.bus.layout.slack
                if tempSlack != 0
                    powerActive[tempSlack] -= powerActive[i]
                end
                if tempSlack == 0
                    powerActive[i] = injectionActive[j] + system.bus.demand.active[j]
                    tempSlack = i
                end
            end
        end
    end
else
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            j = system.generator.layout.bus[i]
            powerActive[i] = system.generator.output.active[i]
            powerReactive[i] = injectionReactive[j] + system.bus.demand.reactive[j]
            if j == system.bus.layout.slack
                powerActive[i] = injectionActive[j] + system.bus.demand.active[j]
            end
        end
    end
end

return Power(
    PowerBus(
        Cartesian(injectionActive, injectionReactive),
        Cartesian(supplyActive, supplyReactive),
        Cartesian(shuntActive, shuntReactive)
    ),
    PowerBranch(
        Cartesian(fromActive, fromReactive),
        Cartesian(toActive, toReactive),
        CartesianImag(shuntReactive),
        Cartesian(lossActive, lossReactive)
    ),
    PowerGenerator(
        Cartesian(powerActive, powerReactive)
    )
)
end
