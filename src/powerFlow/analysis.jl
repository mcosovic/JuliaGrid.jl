"""
This function calculates the powers and currents associated with buses.

    bus!(system::PowerSystem, analysis::Analysis)

After the function is executed, the `bus` field within the `Analysis` type gets updated.

# AC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, analysis)
end

bus!(system, analysis)
```

# DC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = solvePowerFlow(system)
bus!(system, analysis)
```
"""
function bus!(system::PowerSystem, analysis::Analysis)
    if analysis.model.method == "DC Power Flow"
        dcBus!(system, analysis)
    end

    if analysis.model.method in ["Gauss-Seidel", "Newton-Raphson", "Fast Newton-Raphson BX", "Fast Newton-Raphson XB"]
        acBus!(system, analysis)
    end
end

function dcBus!(system::PowerSystem, analysis::Analysis)
    dc = system.dcModel
    bus = system.bus
    slack = bus.layout.slack

    power = analysis.bus.power
    voltage = analysis.bus.voltage
    errorVoltage(voltage.angle)

    power.supply.active = copy(bus.supply.active)
    power.injection.active = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        power.injection.active[i] -= bus.demand.active[i]
    end

    power.injection.active[slack] = bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
    @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
        row = dc.nodalMatrix.rowval[j]
        power.injection.active[slack] += dc.nodalMatrix[row, slack] * voltage.angle[row]
    end
    power.supply.active[slack] = bus.demand.active[slack] + power.injection.active[slack]
end

function acBus!(system::PowerSystem, analysis::Analysis)
    ac = system.acModel
    slack = system.bus.layout.slack

    voltage = analysis.bus.voltage
    power = analysis.bus.power
    current = analysis.bus.current
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)

    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)

    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)

    current.injection.magnitude = fill(0.0, system.bus.number)
    current.injection.angle = fill(0.0, system.bus.number)

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

        current.injection.magnitude[i] = abs(I)
        current.injection.angle[i] = angle(I)

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
end

"""
The function is used to calculate the powers and currents associated with branches for AC
power flow analysis and, in relation to DC power flow analysis, it only calculates active
powers.

    branch!(system::PowerSystem, analysis::Analysis)

The function is responsible for updating the `branch` field within the `Analysis` type after
it has been executed.

# AC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, analysis)
end

branch!(system, analysis)
```

# DC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = solvePowerFlow(system)
branch!(system, analysis)
```
"""
function branch!(system::PowerSystem, analysis::Analysis)
    if analysis.model.method == "DC Power Flow"
        dcBranch!(system, analysis)
    end

    if analysis.model.method in ["Gauss-Seidel", "Newton-Raphson", "Fast Newton-Raphson BX", "Fast Newton-Raphson XB"]
        acBranch!(system, analysis)
    end
end

function dcBranch!(system::PowerSystem, analysis::Analysis)
    dc = system.dcModel
    branch = system.branch

    power = analysis.branch.power
    voltage = analysis.bus.voltage
    errorVoltage(voltage.angle)

    power.from.active = copy(dc.admittance)
    power.to.active = similar(dc.admittance)
    @inbounds for i = 1:branch.number
        power.from.active[i] *= (voltage.angle[branch.layout.from[i]] - voltage.angle[branch.layout.to[i]] - branch.parameter.shiftAngle[i])
        power.to.active[i] = -power.from.active[i]
    end
end

function acBranch!(system::PowerSystem, analysis::Analysis)
    ac = system.acModel

    voltage = analysis.bus.voltage
    current = analysis.branch.current
    power = analysis.branch.power
    errorVoltage(voltage.magnitude)

    power.from.active = fill(0.0, system.branch.number)
    power.from.reactive = fill(0.0, system.branch.number)
    power.to.active = fill(0.0, system.branch.number)
    power.to.reactive = fill(0.0, system.branch.number)
    power.shunt.reactive = fill(0.0, system.branch.number)
    power.loss.active = fill(0.0, system.branch.number)
    power.loss.reactive = fill(0.0, system.branch.number)

    current.from.magnitude = fill(0.0, system.branch.number)
    current.from.angle = fill(0.0, system.branch.number)
    current.to.magnitude = fill(0.0, system.branch.number)
    current.to.angle = fill(0.0, system.branch.number)
    current.impedance.magnitude = fill(0.0, system.branch.number)
    current.impedance.angle = fill(0.0, system.branch.number)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            f = system.branch.layout.from[i]
            t = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
            voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

            currentFrom = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            current.from.magnitude[i] = abs(currentFrom)
            current.from.angle[i] = angle(currentFrom)

            currentTo = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            current.to.magnitude[i] = abs(currentTo)
            current.to.angle[i] = angle(currentTo)

            currentImpedance = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            current.impedance.magnitude[i] = abs(currentImpedance)
            current.impedance.angle[i] = angle(currentImpedance)

            powerFrom = voltageFrom * conj(currentFrom)
            power.from.active[i] = real(powerFrom)
            power.from.reactive[i] = imag(powerFrom)

            powerTo = voltageTo * conj(currentTo)
            power.to.active[i] = real(powerTo)
            power.to.reactive[i] = imag(powerTo)

            power.shunt.reactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[t]^2)

            power.loss.active[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.resistance[i]
            power.loss.reactive[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.reactance[i]
        end
    end
end


"""
The function computes powers related to generators.

    generator!(system::PowerSystem, analysis::Analysis)

Once executed, the `generator` field within the `Analysis` type is updated accordingly.

# AC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, analysis)
end

generator!(system, analysis)
```

# DC Power Flow Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = solvePowerFlow(system)
generator!(system, analysis)
```
"""
function generator!(system::PowerSystem, analysis::Analysis)
    if analysis.model.method == "DC Power Flow"
        dcGenerator!(system, analysis)
    end

    if analysis.model.method in ["Gauss-Seidel", "Newton-Raphson", "Fast Newton-Raphson BX", "Fast Newton-Raphson XB"]
        acGenerator!(system, analysis)
    end
end

function dcGenerator!(system::PowerSystem, analysis::Analysis)
    dc = system.dcModel
    generator = system.generator
    bus = system.bus
    slack = bus.layout.slack

    power = analysis.generator.power
    voltage = analysis.bus.voltage
    errorVoltage(voltage.angle)

    if isempty(analysis.bus.power.supply.active)
        supplySlack = bus.demand.active[slack] + bus.shunt.conductance[slack] + dc.shiftActivePower[slack]
        @inbounds for j in dc.nodalMatrix.colptr[slack]:(dc.nodalMatrix.colptr[slack + 1] - 1)
            row = dc.nodalMatrix.rowval[j]
            supplySlack += dc.nodalMatrix[row, slack] * voltage.angle[row]
        end
    else
        supplySlack = analysis.bus.power.supply.active[slack]
    end

    power.active = fill(0.0, generator.number)
    tempSlack = 0
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            power.active[i] = generator.output.active[i]

            if generator.layout.bus[i] == slack
                if tempSlack != 0
                    power.active[tempSlack] -= power.active[i]
                end
                if tempSlack == 0
                    power.active[i] = supplySlack
                    tempSlack = i
                end
            end
        end
    end
end

function acGenerator!(system::PowerSystem, analysis::Analysis)
    ac = system.acModel

    voltage = analysis.bus.voltage
    power = analysis.generator.power
    errorVoltage(voltage.magnitude)

    power.active = fill(0.0, system.generator.number)
    power.reactive = fill(0.0, system.generator.number)
    isMultiple = false
    for i in system.generator.layout.bus
        if system.bus.supply.inService[i] > 1
            isMultiple = true
            break
        end
    end

    if isempty(analysis.bus.power.injection.active)
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
    else
        injectionActive = analysis.bus.power.injection.active
        injectionReactive = analysis.bus.power.injection.reactive
    end

    if !isMultiple
        @inbounds for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                j = system.generator.layout.bus[i]
                power.active[i] = system.generator.output.active[i]
                power.reactive[i] = injectionReactive[j] + system.bus.demand.reactive[j]
                if j == system.bus.layout.slack
                    power.active[i] = injectionActive[j] + system.bus.demand.active[j]
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
                    power.reactive[i] = QminNew[i] + ((Qgentotal[j] - Qmintotal[j]) / (Qmaxtotal[j] - Qmintotal[j])) * (QmaxNew[i] - QminNew[i])
                else
                    power.reactive[i] = QminNew[i] + (Qgentotal[j] - Qmintotal[j]) / system.bus.supply.inService[j]
                end

                power.active[i] = system.generator.output.active[i]
                if j == system.bus.layout.slack
                    if tempSlack != 0
                        power.active[tempSlack] -= power.active[i]
                    end
                    if tempSlack == 0
                        power.active[i] = injectionActive[j] + system.bus.demand.active[j]
                        tempSlack = i
                    end
                end
            end
        end
    end
end