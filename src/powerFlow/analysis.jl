"""
The function returns the active powers associated with buses in the DC power flow framework.

    analysisBus(system::PowerSystem, model::DCPowerFlow)

In particular, it computes the active power injections and active power injected by generators.    

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

power = analysisBus(system, model)
```
"""
function analysisBus(system::PowerSystem, model::DCPowerFlow)
    dc = system.dcModel
    bus = system.bus
    slack = bus.layout.slack

    errorVoltage(model.voltage.angle)

    powerSupply = copy(bus.supply.active)
    powerInjection = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        powerInjection[i] -= bus.demand.active[i]
    end

    powerInjection[slack] = bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        powerInjection[slack] += dc.nodalMatrix[row, slack] * model.voltage.angle[row]
    end
    powerSupply[slack] = bus.demand.active[slack] + powerInjection[slack]

    return PowerBus(Cartesian(powerInjection, Float64[]), Cartesian(powerSupply, Float64[]), Cartesian(Float64[], Float64[]))
end

"""
The function returns the powers and currents associated with buses in the AC power flow 
framework.

    analysisBus(system::PowerSystem, model::ACPowerFlow)

In particular, it computes the power injections, power injected by the generators, power 
associated with shunt elements, and current injections.  

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
function analysisBus(system::PowerSystem, model::ACPowerFlow)
    ac = system.acModel
    slack = system.bus.layout.slack

    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    powerInjectionActive = fill(0.0, system.bus.number)
    powerInjectionReactive = fill(0.0, system.bus.number)

    supplyActive = fill(0.0, system.bus.number)
    supplyReactive = fill(0.0, system.bus.number)

    shuntActive = fill(0.0, system.bus.number)
    shuntReactive = fill(0.0, system.bus.number)

    currentInjectionMagnitude = fill(0.0, system.bus.number)
    currentInjectionAngle = fill(0.0, system.bus.number)

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

        currentInjectionMagnitude[i] = abs(I)
        currentInjectionAngle[i] = angle(I)

        powerInjection = conj(I) * voltageBus
        powerInjectionActive[i] = real(powerInjection)
        powerInjectionReactive[i] = imag(powerInjection)

        supplyActive[i] = system.bus.supply.active[i]
        if system.bus.layout.type[i] != 1
            supplyReactive[i] = powerInjectionReactive[i] + system.bus.demand.reactive[i]
        else
            supplyReactive[i] = system.bus.supply.reactive[i]
        end
    end
    supplyActive[slack] = powerInjectionActive[slack] + system.bus.demand.active[slack]

    return PowerBus(Cartesian(powerInjectionActive, powerInjectionReactive), Cartesian(supplyActive, supplyReactive), Cartesian(shuntActive, shuntReactive)),
        CurrentBus(Polar(currentInjectionMagnitude, currentInjectionAngle))
end

"""
The function returns the active powers associated with branches in the DC power flow 
framework.

    analysisBranch(system::PowerSystem, model::DCPowerFlow)

In particular, it computes the active power flows at from and to bus ends. 

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

power = analysisBranch(system, model)
```
"""
function analysisBranch(system::PowerSystem, model::DCPowerFlow)
    dc = system.dcModel
    branch = system.branch

    voltage = model.voltage
    errorVoltage(voltage.angle)

    powerFrom = copy(dc.admittance)
    powerTo = similar(dc.admittance)
    @inbounds for i = 1:branch.number
        powerFrom[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        powerTo[i] = -powerFrom[i]
    end

    return PowerBranch(Cartesian(powerFrom, Float64[]), Cartesian(powerTo, Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[]))
end

"""
The function returns the powers and currents associated with branches in the AC power flow 
framework.

    analysisBranch(system::PowerSystem, model::ACPowerFlow)

In particular, it computes the power flows at from and to bus ends, power losses, reactive 
power injections, current flows at from and to bus ends, and current flow through series 
impedances.

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

power, current = analysisBranch(system, model)
```
"""
function analysisBranch(system::PowerSystem, model::ACPowerFlow)
    ac = system.acModel

    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    fromActive = fill(0.0, system.branch.number)
    fromReactive = fill(0.0, system.branch.number)
    toActive = fill(0.0, system.branch.number)
    toReactive = fill(0.0, system.branch.number)
    shuntReactive = fill(0.0, system.branch.number)
    lossActive = fill(0.0, system.branch.number)
    lossReactive = fill(0.0, system.branch.number)

    fromMagnitude = fill(0.0, system.branch.number)
    fromAngle = fill(0.0, system.branch.number)
    toMagnitude = fill(0.0, system.branch.number)
    toAngle = fill(0.0, system.branch.number)
    impedanceMagnitude = fill(0.0, system.branch.number)
    impedanceAngle = fill(0.0, system.branch.number)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            f = system.branch.layout.from[i]
            t = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
            voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

            currentFrom = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            fromMagnitude[i] = abs(currentFrom)
            fromAngle[i] = angle(currentFrom)

            currentTo = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            toMagnitude[i] = abs(currentTo)
            toAngle[i] = angle(currentTo)

            currentImpedance = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            impedanceMagnitude[i] = abs(currentImpedance)
            impedanceAngle[i] = angle(currentImpedance)

            powerFrom = voltageFrom * conj(currentFrom)
            fromActive[i] = real(powerFrom)
            fromReactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(currentTo)
            toActive[i] = real(powerTo)
            toReactive[i] = imag(powerTo)

            shuntReactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[t]^2)

            lossActive[i] = impedanceMagnitude[i]^2 * system.branch.parameter.resistance[i]
            lossReactive[i] = impedanceMagnitude[i]^2 * system.branch.parameter.reactance[i]
        end
    end

    return PowerBranch(Cartesian(fromActive, fromReactive), Cartesian(toActive, toReactive), CartesianImag(shuntReactive), Cartesian(lossActive, lossReactive)),
        CurrentBranch(Polar(fromMagnitude, fromAngle), Polar(toMagnitude, toAngle), Polar(impedanceMagnitude, impedanceAngle))
end

"""
The function returns powers related to generators in the DC power flow framework.

    analysisGenerator(system::PowerSystem, model::DCPowerFlow)

In particular, it computes the active power output of the generators.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)

power = analysisGenerator(system, model)
```
"""
function analysisGenerator(system::PowerSystem, model::DCPowerFlow)
    dc = system.dcModel
    generator = system.generator
    bus = system.bus
    slack = bus.layout.slack

    voltage = model.voltage
    errorVoltage(voltage.angle)

    supplySlack = bus.demand.active[slack] + bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        supplySlack += dc.nodalMatrix[row, slack] * voltage.angle[row]
    end

    powerActive = fill(0.0, generator.number)
    tempSlack = 0
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            powerActive[i] = generator.output.active[i]

            if generator.layout.bus[i] == slack
                if tempSlack != 0
                    powerActive[tempSlack] -= powerActive[i]
                end
                if tempSlack == 0
                    powerActive[i] = supplySlack
                    tempSlack = i
                end
            end
        end
    end

    return PowerGenerator(powerActive, Float64[])
end


"""
The function return powers related to generators for the AC power flow analysis.

    analysisGenerator(system::PowerSystem, model::ACPowerFlow)

In particular, it computes the power output of the generators.

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

power = analysisGenerator(system, model)
```
"""
function analysisGenerator(system::PowerSystem, model::ACPowerFlow)
    ac = system.acModel

    voltage = model.voltage
    errorVoltage(voltage.magnitude)

    powerActive = fill(0.0, system.generator.number)
    powerReactive = fill(0.0, system.generator.number)
    isMultiple = false
    for i in system.generator.layout.bus
        if system.bus.supply.inService[i] > 1
            isMultiple = true
            break
        end
    end

    injectionActive = fill(0.0, system.bus.number)
    injectionReactive = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += conj(ac.nodalMatrixTranspose.nzval[j]) * conj(voltage.magnitude[k] * exp(im * voltage.angle[k]))
        end
        powerInjection = I * voltageBus
        injectionActive[i] = real(powerInjection)
        injectionReactive[i] = imag(powerInjection)
    end

    if !isMultiple
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
    end

    return PowerGenerator(powerActive, powerReactive)
end