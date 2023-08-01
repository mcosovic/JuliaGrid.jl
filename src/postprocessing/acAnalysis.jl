"""
    power!(system::PowerSystem, model::ACAnalysis)

The function computes the active and reactive powers associated with buses, branches, and
generators in the AC framework.

# Updates
This function computes the following electrical quantities: 
- `injection`: active and reactive power injections at each bus,
- `supply`: active and reactive power injections from the generators at each bus,
- `shunt`: active and reactive powers associated with the shunt element at each bus,
- `from`: active and reactive power flows at each "from" bus end of the branch,
- `to`: active and reactive power flows at each "to" bus end of the branch,
- `charging`: reactive power injections by each branch,
- `loss`: active and reactive power losses at each branch,
- `generator`: output active and reactive powers of each generator.

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
    power.charging.reactive = fill(0.0, system.branch.number)
    power.loss.active = fill(0.0, system.branch.number)
    power.loss.reactive = fill(0.0, system.branch.number)
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

            power.charging.reactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[to]^2)

            currentBranch = abs(ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo))
            power.loss.active[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            power.loss.reactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]
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
    power.charging.reactive = fill(0.0, system.branch.number)
    power.loss.active = fill(0.0, system.branch.number)
    power.loss.reactive = fill(0.0, system.branch.number)
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

            power.charging.reactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[to]^2)

            currentBranch = abs(ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo))
            power.loss.active[i] = currentBranch^2 * system.branch.parameter.resistance[i]
            power.loss.reactive[i] = currentBranch^2 * system.branch.parameter.reactance[i]
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

The function returns the active and reactive power of the shunt element associated with a 
specific bus in the AC framework. The `label` keyword argument must match an existing 
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
    voltageBus = voltage.magnitude[index] * exp(im * voltage.angle[index])

    powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[index] + im * system.bus.shunt.susceptance[index]))

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

The function returns the reactive power injection associated with a specific branch in 
the AC framework. The `label` keyword argument must match an existing branch label.

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

    index = system.branch.label[label]

    if system.branch.layout.status[index] == 1
        from = system.branch.layout.from[index]
        to = system.branch.layout.to[index]

        voltageFrom = voltage.magnitude[from] * exp(im * voltage.angle[from])

        charging = 0.5 * system.branch.parameter.susceptance[index] * (abs(voltageFrom / ac.transformerRatio[index])^2 +  voltage.magnitude[to]^2)
    else
        charging = 0.0
    end

    return charging
end

"""
    powerLoss(system::PowerSystem, model::ACAnalysis; label)

The function returns the active and reactive power losses associated with a specific 
branch in the AC framework. The `label` keyword argument must match an existing branch label.

# Abstract type
The abstract type `ACAnalysis` can have the following subtypes:
- `ACPowerFlow`: computes the powers within the AC power flow,
- `ACOptimalPowerFlow`: computes the powers within the AC optimal power flow.

# Examples
```jldoctest
Compute powers after obtaining the AC power flow solution
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
loss = powerLoss(system, model; label = 2)
```

Compute powers after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
loss = powerLoss(system, model; label = 2)
```
"""
function powerLoss(system::PowerSystem, model::ACAnalysis; label)
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

        currentMagnitude = (abs(ac.admittance[index] * (voltageFrom / ac.transformerRatio[index] - voltageTo)))^2
        lossActive = currentMagnitude * system.branch.parameter.resistance[index]
        lossReactive = currentMagnitude * system.branch.parameter.reactance[index]
    else
        lossActive = 0.0
        lossReactive = 0.0
    end

    return Cartesian(lossActive, lossReactive)
end

"""
    powerGenerator(system::PowerSystem, model::ACAnalysis)

The function returns the active and reactive powers associated with a specific generator in
the AC framework. The `label` keyword argument must match an existing generator label.

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
    current.line.magnitude = fill(0.0, system.branch.number)
    current.line.angle = fill(0.0, system.branch.number)
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

            currentBranch = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            current.line.magnitude[i] = abs(currentBranch)
            current.line.angle[i] = angle(currentBranch)

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
    currentLine(system::PowerSystem, model::ACAnalysis; label)

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
line = currentLine(system, model; label = 2)
```

Compute the current after obtaining the AC optimal power flow solution:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, model)
line = currentLine(system, model; label = 2)
```
"""
function currentLine(system::PowerSystem, model::ACAnalysis; label)
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

        currentLine = ac.admittance[index] * (voltageFrom / ac.transformerRatio[index] - voltageTo)
    else
        currentLine = 0.0 + im * 0.0
    end

    return Polar(abs(currentLine), angle(currentLine))
end
