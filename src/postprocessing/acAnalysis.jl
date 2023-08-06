"""
    power!(system::PowerSystem, model::ACAnalysis)

The function computes the active and reactive powers associated with buses, branches, and
generators in the AC framework.

# Updates
This function updates the `power` field of the `Model` composite type by computing the 
following electrical quantities:  
- `injection`: active and reactive power injections at each bus,
- `supply`: active and reactive power injections from the generators at each bus,
- `shunt`: active and reactive power values associated with shunt element at each bus,
- `from`: active and reactive power flows at the "from" end of each branch,
- `to`: active and reactive power flows at the "to" end of each branch,
- `charging`: active and reactive power values linked with branch charging admittances for each branch,
- `series` active and reactive power losses through each branch series impedance,
- `generator`: produced active and reactive power outputs of each generator.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
power!(system, model)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
power!(system, model)
```
"""
function power!(system::PowerSystem, model::ACPowerFlow)
    ac = system.acModel
    slack = system.bus.layout.slack
    parameter = system.branch.parameter

    voltage = model.voltage
    power = model.power
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
    power.charging.from.active = fill(0.0, system.branch.number)
    power.charging.from.reactive = fill(0.0, system.branch.number)
    power.charging.to.active = fill(0.0, system.branch.number)
    power.charging.to.reactive = fill(0.0, system.branch.number)
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

            currentBranch = abs(ac.admittance[i] * (voltageFrom * transformerRatio - voltageTo))
            power.series.active[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            power.series.reactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]

            admittanceConj = 0.5 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            fromShunt = (turnsRatioInv * voltage.magnitude[from])^2 * admittanceConj
            power.charging.from.active[i] = real(fromShunt)
            power.charging.from.reactive[i] = imag(fromShunt)

            toShunt = voltage.magnitude[to]^2 * admittanceConj
            power.charging.to.active[i] = real(toShunt)
            power.charging.to.reactive[i] = imag(toShunt)
        end
    end

    power.generator.active = fill(0.0, system.generator.number)
    power.generator.reactive = fill(0.0, system.generator.number)
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            busIndex = system.generator.layout.bus[i]
            inService = system.bus.supply.inService[busIndex]

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

function power!(system::PowerSystem, model::ACOptimalPowerFlow)
    ac = system.acModel
    voltage = model.voltage
    power = model.power
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)
    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[i] + im * system.bus.shunt.susceptance[i]))
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
    power.pimodel.series.active = fill(0.0, system.branch.number)
    power.pimodel.series.reactive = fill(0.0, system.branch.number)
    power.pimodel.from.active = fill(0.0, system.branch.number)
    power.pimodel.from.reactive = fill(0.0, system.branch.number)
    power.pimodel.to.active = fill(0.0, system.branch.number)
    power.pimodel.to.reactive = fill(0.0, system.branch.number)
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

            currentBranch = abs(ac.admittance[i] * (voltageFrom * transformerRatio - voltageTo))
            power.pimodel.series.active[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            power.pimodel.series.reactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]

            fromShunt = 0.5 * (turnsRatioInv * voltage.magnitude[from])^2 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            power.pimodel.from.active[i] = real(fromShunt)
            power.pimodel.from.reactive[i] = imag(fromShunt)

            toShunt = 0.5 * voltage.magnitude[to]^2 * conj(system.branch.parameter.conductance[i] + im * system.branch.parameter.susceptance[i])
            power.pimodel.to.active[i] = real(toShunt)
            power.pimodel.to.reactive[i] = imag(toShunt)
        end
    end

    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.generator.number
        busIndex = system.generator.layout.bus[i]

        power.supply.active[busIndex] += model.power.generator.active[i]
        power.supply.reactive[busIndex] += model.power.generator.reactive[i]
    end
end

"""
    powerInjection(system::PowerSystem, model::ACAnalysis, label)

The function returns the active and reactive power injections associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
injection = powerInjection(system, model; label = 1)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
injection = powerInjection(system, model; label = 1)
```
"""
function powerInjection(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage
    index = system.bus.label[label]

    I = 0.0 + im * 0.0
    for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        k = ac.nodalMatrix.rowval[j]
        I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
    end
    powerInjection = conj(I) * voltage.magnitude[index] * exp(im * voltage.angle[index])

    return Cartesian(real(powerInjection), imag(powerInjection))
end

"""
    powerSupply(system::PowerSystem, model::ACAnalysis, label)

The function returns the active and reactive power injections from the generators associated
with a specific bus in the AC framework. The `label` keyword argument must match an existing 
bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
supply = powerSupply(system, model; label = 1)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
supply = powerSupply(system, model; label = 1)
```
"""
function powerSupply(system::PowerSystem, model::ACPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage

    index = system.bus.label[label]

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
    
    return Cartesian(supplyActive, supplyReactive)
end

function powerSupply(system::PowerSystem, model::ACOptimalPowerFlow; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)
    index = system.bus.label[label]

    supplyActive = 0.0
    supplyReactive = 0.0
    @inbounds for i in system.bus.supply.generator[index]
        supplyActive += model.power.generator.active[i]
        supplyReactive += model.power.generator.reactive[i]
    end

    return Cartesian(supplyActive, supplyReactive)
end

"""
    powerShunt(system::PowerSystem, model::ACAnalysis, label)

The function returns the active and reactive power values of the shunt element associated 
with a specific bus in the AC framework. The `label` keyword argument must match an existing 
bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
supply = powerShunt(system, model; label = 1)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
supply = powerShunt(system, model; label = 1)
```
"""
function powerShunt(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end
    errorVoltage(model.voltage.magnitude)
    voltage = model.voltage

    index = system.bus.label[label]
    powerShunt = voltage.magnitude[index]^2 * conj(system.bus.shunt.conductance[index] + im * system.bus.shunt.susceptance[index])

    return Cartesian(real(powerShunt), imag(powerShunt))
end

"""
    powerFrom(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive power flows at the "from" bus end associated 
with a specific branch in the AC framework. The `label` keyword argument must match an 
existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
from = powerFrom(system, model; label = 2)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
from = powerFrom(system, model; label = 2)
```
"""
function powerFrom(system::PowerSystem, model::ACAnalysis; label)
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
    else
        powerFrom = 0.0 + im * 0.0
    end

    return Cartesian(real(powerFrom), imag(powerFrom))
end

"""
    powerTo(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive power flows at the "to" bus end associated 
with a specific branch in the AC framework. The `label` keyword argument must match an 
existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution:
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
to = powerTo(system, model; label = 2)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
to = powerTo(system, model; label = 2)
```
"""
function powerTo(system::PowerSystem, model::ACAnalysis; label)
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

        powerTo = voltageTo * conj(voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index])
    else
        powerTo = 0.0 + im * 0.0
    end

    return Cartesian(real(powerTo), imag(powerTo))
end

"""
    powerCharging(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive power values associated with the charging 
admittances of a specific branch in the AC framework. The 'label' keyword argument must 
correspond to an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the power within the AC power flow,
- `ACOptimalPowerFlow`: computes the power within the AC optimal power flow.

# Examples
Compute the reactive power after obtaining the AC power flow solution:
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
charging = powerCharging(system, model; label = 2)
```

Compute the reactive power after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
charging = powerCharging(system, model; label = 2)
```
"""
function powerCharging(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage
    parameter = system.branch.parameter
    index = system.branch.label[label]

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]
        admittanceConj = 0.5 * conj(system.branch.parameter.conductance[index] + im * system.branch.parameter.susceptance[index])

        fromShunt = (voltage.magnitude[from] / parameter.turnsRatio[index])^2 * admittanceConj
        fromActive = real(fromShunt)
        fromReactive = imag(fromShunt)

        toShunt = voltage.magnitude[to]^2 * admittanceConj
        toActive = real(toShunt)
        toeRactive = imag(toShunt)
    else
        fromActive = 0.0
        fromReactive = 0.0
        toActive = 0.0
        toeRactive = 0.0
    end

    return Charging(
        Cartesian(fromActive, fromReactive),
        Cartesian(toActive, toeRactive)
    )
end

"""
    powerSeries(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive power losses across the series impedance of 
a specific branch within the AC framework. The `label` keyword argument should correspond 
to an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the power within the AC power flow,
- `ACOptimalPowerFlow`: computes the power within the AC optimal power flow.

# Examples
Compute the reactive power after obtaining the AC power flow solution:
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
series = powerSeries(system, model; label = 2)
```

Compute the reactive power after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
series = powerSeries(system, model; label = 2)
```
"""
function powerSeries(system::PowerSystem, model::ACAnalysis; label)
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    errorVoltage(model.voltage.magnitude)

    ac = system.acModel
    voltage = model.voltage
    parameter = system.branch.parameter
    index = system.branch.label[label]

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])
        voltageTo = voltage.magnitude[to] * exp(im * voltage.angle[to])
        transformerRatio = exp(-im * parameter.shiftAngle[index]) / parameter.turnsRatio[index]

        voltageSeries = transformerRatio * voltageFrom - voltageTo
        series = voltageSeries * conj(ac.admittance[index] * voltageSeries)
        seriesActive = real(series)
        seriesReactive = imag(series)
    else
        seriesActive = 0.0
        seriesReactive = 0.0
    end

    return Cartesian(seriesActive,seriesReactive)
end

"""
    powerGenerator(system::PowerSystem, model::ACAnalysis)

The function returns the active and reactive powers associated with a specific generator 
in the AC framework. The `label` keyword argument must match an existing generator label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
Compute powers after obtaining the AC power flow solution
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
output = powerGenerator(system, model; label = 1)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
output = powerGenerator(system, model; label = 1)
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

    return Cartesian(powerActive, powerReactive)
end

function powerGenerator(system::PowerSystem, model::ACOptimalPowerFlow; label)
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end
    errorVoltage(model.voltage.angle)

    index = system.generator.label[label]

    return Cartesian(model.power.generator.active[index], model.power.generator.reactive[index])
end

"""
    current!(system::PowerSystem, model::ACAnalysis)

The function computes the currents in the polar coordinate system associated with buses and
branches in the AC framework.

# Updates
This function calculates various electrical quantities in the polar coordinate system:
- `injection`: current injections at each bus,
- `from`: current flows at each "from" bus end of the branch,
- `to`: current flows at each "to" bus end of the branch,
- `line`: current flows through the series impedance of the branch in the direction from the "from" bus end to the "to" bus end of the branch.     

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the currents within the AC power flow,
- `ACOptimalPowerFlow`: computes the currents within the AC optimal power flow.

# Examples
Compute currents after obtaining the AC power flow solution:
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
current!(system, model)
```

Compute currents after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
current!(system, model)
```
"""
function current!(system::PowerSystem, model::ACAnalysis)
    ac = system.acModel

    voltage = model.voltage
    current = model.current
    errorVoltage(voltage.magnitude)

    current.injection.magnitude = fill(0.0, system.bus.number)
    current.injection.angle = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.magnitude[k] * exp(im * voltage.angle[k])
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
    currentInjection(system::PowerSystem, model::ACAnalysis; label)

The function returns the current in the polar coordinate system associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the current within the AC power flow,
- `ACOptimalPowerFlow`: computes the current within the AC optimal power flow.

# Examples
Compute the current after obtaining the AC power flow solution:
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
injection = currentInjection(system, model; label = 1)
```

Compute the current after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
injection = currentInjection(system, model; label = 1)
```
"""
function currentInjection(system::PowerSystem, model::ACAnalysis; label)
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

    return Polar(abs(I), angle(I))
end

"""
    currentFrom(system::PowerSystem, model::ACAnalysis; label)

The function returns the current in the polar coordinate system at the "from" bus end 
associated with a specific branch in the AC framework. The `label` keyword argument must 
match an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the current within the AC power flow,
- `ACOptimalPowerFlow`: computes the current within the AC optimal power flow.

# Examples
Compute the current after obtaining the AC power flow solution:
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
from = currentFrom(system, model; label = 2)
```

Compute the current after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
from = currentFrom(system, model; label = 2)
```
"""
function currentFrom(system::PowerSystem, model::ACAnalysis; label)
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
    else
        currentFrom = 0.0 + im * 0.0
    end

    return Polar(abs(currentFrom), angle(currentFrom))
end

"""
    currentTo(system::PowerSystem, model::ACAnalysis; label)

The function returns the current in the polar coordinate system at the "to" bus end 
associated with a specific branch in the AC framework. The `label` keyword argument must 
match an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the current within the AC power flow,
- `ACOptimalPowerFlow`: computes the current within the AC optimal power flow.

# Examples
Compute the current after obtaining the AC power flow solution:
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
to = currentTo(system, model; label = 2)
```

Compute the current after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
to = currentTo(system, model; label = 2)
```
"""
function currentTo(system::PowerSystem, model::ACAnalysis; label)
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

        currentTo = voltageFrom * ac.nodalToFrom[index] + voltageTo * ac.nodalToTo[index]
    else
        currentTo = 0.0 + im * 0.0
    end

    return Polar(abs(currentTo), angle(currentTo))
end

"""
    currentSeries(system::PowerSystem, model::ACAnalysis; label)

The function returns the current in the polar coordinate system through series impedance 
associated with a specific branch in the direction from the "from" bus end to the "to" bus 
end of the branch within the AC framework. The `label` keyword argument must  match an 
existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the current within the AC power flow,
- `ACOptimalPowerFlow`: computes the current within the AC optimal power flow.

# Examples
Compute the current after obtaining the AC power flow solution:
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
line = currentSeries(system, model; label = 2)
```

Compute the current after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
line = currentSeries(system, model; label = 2)
```
"""
function currentSeries(system::PowerSystem, model::ACAnalysis; label)
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
        transformerRatio = (1 / system.branch.parameter.turnsRatio[index]) * exp(-im * system.branch.parameter.shiftAngle[index])
        
        currentSeries = ac.admittance[index] * (transformerRatio * voltageFrom - voltageTo)
    else
        currentSeries = 0.0 + im * 0.0
    end

    return Polar(abs(currentSeries), angle(currentSeries))
end
