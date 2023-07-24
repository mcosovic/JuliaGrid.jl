"""
    power(system::PowerSystem, model::ACAnalysis)

The function returns the active and reactive powers associated with buses, branches, and
generators in the AC framework.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Returns
The function returns the instance of the `Power` type, which contains the following fields:
- The `bus` field contains powers related to buses:
  - `injection`: active and reactive power injections,
  - `supply`: active and reactive power injections from the generators,
  - `shunt`: active and reactive powers associated with shunt elements.
- The `branch` field contains powers related to branches:
  - `from`: active and reactive power flows at each "from" bus end,
  - `to`: active and reactive power flows at each "to" bus end,
  - `shunt`: reactive power injections by each branch,
  - `loss`: active and reactive power losses.
- The `generator` field contains powers related to generators:
 - `output`: output active and reactive powers.


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

powers = power(system, model)
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
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i])
            fromActive[i] = real(powerFrom)
            fromReactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i])
            toActive[i] = real(powerTo)
            toReactive[i] = imag(powerTo)

            shuntReactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[to]^2)

            currentBranch = abs(ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo))
            lossActive[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            lossReactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]
        end
    end

    powerActive = fill(0.0, system.generator.number)
    powerReactive = fill(0.0, system.generator.number)
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]
            inService = system.bus.supply.inService[busIndex]

            if inService == 1
                powerActive[i] = system.generator.output.active[i]
                powerReactive[i] = injectionReactive[busIndex] + system.bus.demand.reactive[busIndex]
                if busIndex == system.bus.layout.slack
                    powerActive[i] = injectionActive[busIndex] + system.bus.demand.active[busIndex]
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
                    Qgentotal += (injectionReactive[busIndex] + system.bus.demand.reactive[busIndex]) / inService
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
                    powerReactive[i] = QminNew + ((Qgentotal - Qmintotal) / (Qmaxtotal - Qmintotal)) * (QmaxNew - QminNew)
                else
                    powerReactive[i] = QminNew + (Qgentotal - Qmintotal) / inService
                end

                if busIndex == system.bus.layout.slack && generatorIndex[1] == i
                    powerActive[i] = injectionActive[busIndex] + system.bus.demand.active[busIndex]

                    for j = 2:inService
                        powerActive[i] -= system.generator.output.active[generatorIndex[j]]
                    end
                else
                    powerActive[i] = system.generator.output.active[i]
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

function power(system::PowerSystem, model::ACOptimalPowerFlow)
    ac = system.acModel
    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    injectionActive = fill(0.0, system.bus.number)
    injectionReactive = fill(0.0, system.bus.number)
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
    end

    fromActive = fill(0.0, system.branch.number)
    fromReactive = fill(0.0, system.branch.number)
    toActive = fill(0.0, system.branch.number)
    toReactive = fill(0.0, system.branch.number)
    shuntReactive = fill(0.0, system.branch.number)
    lossActive = fill(0.0, system.branch.number)
    lossReactive = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i])
            fromActive[i] = real(powerFrom)
            fromReactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i])
            toActive[i] = real(powerTo)
            toReactive[i] = imag(powerTo)

            shuntReactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[to]^2)

            currentBranch = abs(ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo))
            lossActive[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            lossReactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]
        end
    end

    supplyActive = fill(0.0, system.bus.number)
    supplyReactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.generator.number
        busIndex = system.generator.layout.bus[i]

        supplyActive[busIndex] += model.power.active[i]
        supplyReactive[busIndex] += model.power.reactive[i]
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
            Cartesian(model.power.active, model.power.reactive)
        )
    )
end


"""
    powerBus(system::PowerSystem, model::ACAnalysis, label)

The function returns the active and reactive powers associated associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Returns
The function returns the instance of the `PowerBus` type, which contains the following
fields:
- `injection`: active and reactive power injections at the bus,
- `supply`: active and reactive power injections from the generators at the bus,
- `shunt`: active and reactive powers associated with shunt element at the bus.


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

powers = powerBus(system, model; label = 1)
```
"""
function powerBus(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.bus.label[label]
    voltageBus = voltage.magnitude[index] * exp(im * voltage.angle[index])

    powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[index] + im * system.bus.shunt.susceptance[index]))

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
        Cartesian(real(powerShunt), imag(powerShunt))
    )
end

function powerBus(system::PowerSystem, model::ACOptimalPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.bus.label[label]
    voltageBus = voltage.magnitude[index] * exp(im * voltage.angle[index])

    powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[index] + im * system.bus.shunt.susceptance[index]))

    I = 0.0 + im * 0.0
    for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[j]
        I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
    end
    powerInjection = conj(I) * voltageBus
    injectionActive = real(powerInjection)
    injectionReactive = imag(powerInjection)

    supplyActive = 0.0
    supplyReactive = 0.0
    @inbounds for i in system.bus.supply.generator[index]
        supplyActive += model.power.active[i]
        supplyReactive += model.power.reactive[i]
    end

    return PowerBus(
        Cartesian(injectionActive, injectionReactive),
        Cartesian(supplyActive, supplyReactive),
        Cartesian(real(powerShunt), imag(powerShunt))
    )
end

"""
    powerBranch(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive powers associated with a specific branch in
the AC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Returns
The function returns the instance of the `PowerBranch` type, which contains the following
fields:
- `from`: active and reactive power flows at the "from" bus end of the branch,
- `to`: active and reactive power flows at the "to" bus end of the branch,
- `shunt`: reactive power injection by the branch,
- `loss`: active and reactive power losses at the branch.

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

powers = powerBranch(system, model; label = 2)
```
"""
function powerBranch(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.branch.label[label]

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        powerFrom = voltageFrom * conj(voltageFrom * ac.nodalFromFrom[index] + voltageTo * ac.nodalFromTo[index])
        powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index])

        shuntReactive = 0.5 * system.branch.parameter.susceptance[index] * (abs(voltageFrom / ac.transformerRatio[index])^2 +  voltage.magnitude[to]^2)

        currentMagnitude = (abs(ac.admittance[index] * (voltageFrom / ac.transformerRatio[index] - voltageTo)))^2
        lossActive = currentMagnitude * system.branch.parameter.resistance[index]
        lossReactive = currentMagnitude * system.branch.parameter.reactance[index]
    else
        powerFrom = 0.0 + im * 0.0
        powerTo = 0.0 + im * 0.0
        shuntReactive = 0.0
        lossActive = 0.0
        lossReactive = 0.0
    end

    return PowerBranch(
        Cartesian(real(powerFrom), imag(powerFrom)),
        Cartesian(real(powerTo), imag(powerTo)),
        CartesianImag(shuntReactive),
        Cartesian(lossActive, lossReactive)
    )
end

"""
    powerGenerator(system::PowerSystem, model::ACAnalysis)

The function returns the active and reactive powers associated with a specific generator in
the AC framework. The `label` keyword argument must match an existing generator label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Returns
The function returns the instance of the `PowerGenerator` type, which contains the following
field:
- `output`: output active and reactive powers of the generator.


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

powers = powerGenerator(system, model; label = 1)
```
"""
function powerGenerator(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.generator.label[label]
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

        inService = system.bus.supply.inService[busIndex]
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

    return PowerGenerator(
        Cartesian(powerActive, powerReactive)
    )
end

function powerGenerator(system::PowerSystem, model::ACOptimalPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.angle)

    index = system.generator.label[label]

    return PowerGenerator(
        Cartesian(model.power.active[index], model.power.reactive[index])
    )
end

"""
    current(system::PowerSystem, model::ACAnalysis)

The function returns the currents in the polar coordinate system associated with buses and
branches in the AC framework.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the currents within the AC power flow,
- `ACOptimalPowerFlow`: computes the currents within the AC optimal power flow.

# Returns
The function returns the instance of the `Current` type, which contains the following fields:
- The `bus` field contains currents related to buses:
  - `injection`: current injection magnitudes and angles.
- The `branch` field contains powers related to branches:
  - `from`: current flow magnitudes and angles at each "from" bus end,
  - `to`: current flow magnitudes and angles at each "to" bus end,
  - `branch`: current flow magnitudes and angles through series impedances.


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

currents = current(system, model)
```
"""
function current(system::PowerSystem, model::ACAnalysis)
    ac = system.acModel

    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    injectionMagnitude = fill(0.0, system.bus.number)
    injectionAngle = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
        end

        injectionMagnitude[i] = abs(I)
        injectionAngle[i] = angle(I)
    end

    fromMagnitude = fill(0.0, system.branch.number)
    fromAngle = fill(0.0, system.branch.number)
    toMagnitude = fill(0.0, system.branch.number)
    toAngle = fill(0.0, system.branch.number)
    branchMagnitude = fill(0.0, system.branch.number)
    branchAngle = fill(0.0, system.branch.number)
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            from = system.branch.layout.from[i]
            to = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
            voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

            currentFrom = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            fromMagnitude[i] = abs(currentFrom)
            fromAngle[i] = angle(currentFrom)

            currentTo = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            toMagnitude[i] = abs(currentTo)
            toAngle[i] = angle(currentTo)

            currentBranch = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            branchMagnitude[i] = abs(currentBranch)
            branchAngle[i] = angle(currentBranch)

        end
    end

    return Current(
        CurrentBus(
            Polar(injectionMagnitude, injectionAngle),
        ),
        CurrentBranch(
            Polar(fromMagnitude, fromAngle),
            Polar(toMagnitude, toAngle),
            Polar(branchMagnitude, branchAngle)
        ),
    )
end

"""
    currentBus(system::PowerSystem, model::ACAnalysis; label)

The function returns the currents in the polar coordinate system associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the currents within the AC power flow,
- `ACOptimalPowerFlow`: computes the currents within the AC optimal power flow.

# Returns
The function returns the instance of the `CurrentBus` type, which contains the following
field:
- `injection`: current injection magnitude and angle at the bus.

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

currents = currentBus(system, model; label = 1)
```
"""
function currentBus(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage
    index = system.bus.label[label]

    I = 0.0 + im * 0.0
    for i in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[i]
        I += ac.nodalMatrixTranspose.nzval[i] * voltage.magnitude[k] * exp(im * voltage.angle[k])
    end

    return CurrentBus(
            Polar(abs(I), angle(I))
        )
end

"""
    currentBranch(system::PowerSystem, model::ACAnalysis; label)

The function returns the currents in the polar coordinate system associated with a specific
branch in the AC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the currents within the AC power flow,
- `ACOptimalPowerFlow`: computes the currents within the AC optimal power flow.

# Returns
The function returns the instance of the `CurrentBranch` type, which contains the following
fields:
- `from`: current flow magnitude and angle at the "from" bus end of the branch,
- `to`: current flow magnitudes and angles at the "to" bus end of the branch,
- `branch`: current flow magnitude and angle through series impedance of the branch.


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

currents = currentBranch(system, model; label = 2)
```
"""
function currentBranch(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.branch.label[label]
    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])

        currentFrom = voltageFrom * ac.nodalFromFrom[index] + voltageTo * ac.nodalFromTo[index]
        currentTo = voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index]
        currentBranch = ac.admittance[index] * (voltageFrom / ac.transformerRatio[index] - voltageTo)
    else
        currentFrom = 0.0 + im * 0.0
        currentTo = 0.0 + im * 0.0
        currentBranch = 0.0 + im * 0.0
    end

    return CurrentBranch(
        Polar(abs(currentFrom), angle(currentFrom)),
        Polar(abs(currentTo), angle(currentTo)),
        Polar(abs(currentBranch), angle(currentBranch))
    )
end
