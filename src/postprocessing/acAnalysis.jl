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
    errorVoltage(analysis.voltage.magnitude)

    bus = system.bus
    branch = system.branch
    gen = system.generator

    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power
    slack = system.bus.layout.slack

    initializePower(power, bus)
    @inbounds for i = 1:bus.number
        power.shunt.active[i], power.shunt.reactive[i] = PsQs(bus, voltg, i)
        power.injection.active[i], power.injection.reactive[i] = PiQi(ac, voltg, i)

        power.supply.active[i] = bus.supply.active[i]
        if bus.layout.type[i] != 1
            power.supply.reactive[i] = power.injection.reactive[i] + bus.demand.reactive[i]
        else
            power.supply.reactive[i] = bus.supply.reactive[i]
        end
    end
    power.supply.active[slack] = power.injection.active[slack] + bus.demand.active[slack]

    initializePower(power, branch)
    @inbounds for k = 1:branch.number
        if branch.layout.status[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            power.from.active[k], power.from.reactive[k] = PijQij(ac, Vi, Vj, k)
            power.to.active[k], power.to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            power.series.active[k], power.series.reactive[k] = PlQl(ac, Vij, k)
            power.charging.active[k], power.charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end

    power.generator.active = fill(0.0, gen.number)
    power.generator.reactive = fill(0.0, gen.number)
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            idxBus = gen.layout.bus[i]
            Pi = power.injection.active[idxBus]
            Qi = power.injection.reactive[idxBus]
            service = length(bus.supply.generator[idxBus])

            if service == 1
                power.generator.active[i] = gen.output.active[i]
                power.generator.reactive[i] = Qi + bus.demand.reactive[idxBus]
                if idxBus == slack
                    power.generator.active[i] = Pi + bus.demand.active[idxBus]
                end
            else
                Qminsum = 0.0
                Qmaxsum = 0.0
                Qgensum = 0.0
                QminInf = 0.0
                QmaxInf = 0.0
                QminNew = gen.capability.minReactive[i]
                QmaxNew = gen.capability.maxReactive[i]

                idxGen = bus.supply.generator[idxBus]
                for j in idxGen
                    if !isinf(gen.capability.minReactive[j])
                        Qminsum += gen.capability.minReactive[j]
                    end
                    if !isinf(gen.capability.maxReactive[j])
                        Qmaxsum += gen.capability.maxReactive[j]
                    end
                    Qgensum += (Qi + bus.demand.reactive[idxBus]) / service
                end
                for j in idxGen
                    if isinf(gen.capability.minReactive[j])
                        Qmin = -abs(Qgensum) - abs(Qminsum) - abs(Qmaxsum)
                        if gen.capability.minReactive[j] == Inf
                            Qmin = -Qmin
                        end
                        if i == j
                            QminNew = Qmin
                        end
                        QminInf += Qmin
                    end
                    if isinf(gen.capability.maxReactive[j])
                        Qmax = abs(Qgensum) + abs(Qminsum) + abs(Qmaxsum)
                        if gen.capability.maxReactive[j] == -Inf
                            Qmax = -Qmax
                        end
                        if i == j
                            QmaxNew = Qmax
                        end
                        QmaxInf += Qmax
                    end
                end
                Qminsum += QminInf
                Qmaxsum += QmaxInf

                if basePowerMVA * abs(Qminsum - Qmaxsum) > 10 * eps(Float64)
                    power.generator.reactive[i] =
                        QminNew + ((Qgensum - Qminsum) / (Qmaxsum - Qminsum)) *
                        (QmaxNew - QminNew)
                else
                    power.generator.reactive[i] = QminNew + (Qgensum - Qminsum) / service
                end

                if idxBus == slack && idxGen[1] == i
                    power.generator.active[i] = Pi + bus.demand.active[idxBus]

                    for j = 2:service
                        power.generator.active[i] -= gen.output.active[idxGen[j]]
                    end
                else
                    power.generator.active[i] = gen.output.active[i]
                end
            end
        end
    end
end

function power!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    errorVoltage(analysis.voltage.magnitude)

    bus = system.bus
    branch = system.branch

    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power

    power.injection.active = fill(0.0, bus.number)
    power.injection.reactive = fill(0.0, bus.number)
    power.shunt.active = fill(0.0, bus.number)
    power.shunt.reactive = fill(0.0, bus.number)
    @inbounds for i = 1:bus.number
        power.shunt.active[i], power.shunt.reactive[i] = PsQs(bus, voltg, i)
        power.injection.active[i], power.injection.reactive[i] = PiQi(ac, voltg, i)
    end

    initializePower(power, branch)
    @inbounds for k = 1:branch.number
        if branch.layout.status[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            power.from.active[k], power.from.reactive[k] = PijQij(ac, Vi, Vj, k)
            power.to.active[k], power.to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            power.series.active[k], power.series.reactive[k] = PlQl(ac, Vij, k)
            power.charging.active[k], power.charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end

    power.supply.active = fill(0.0, bus.number)
    power.supply.reactive = fill(0.0, bus.number)
    @inbounds for i = 1:system.generator.number
        idxBus = system.generator.layout.bus[i]

        power.supply.active[idxBus] += analysis.power.generator.active[i]
        power.supply.reactive[idxBus] += analysis.power.generator.reactive[i]
    end
end

function power!(system::PowerSystem, analysis::Union{PMUStateEstimation, ACStateEstimation})
    errorVoltage(analysis.voltage.magnitude)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power

    initializePower(power, bus)
    @inbounds for i = 1:bus.number
        power.shunt.active[i], power.shunt.reactive[i] = PsQs(bus, voltg, i)
        power.injection.active[i], power.injection.reactive[i] = PiQi(ac, voltg, i)

        power.supply.active[i] = power.injection.active[i] + bus.demand.active[i]
        power.supply.reactive[i] = power.injection.reactive[i] + bus.demand.reactive[i]
    end

    initializePower(power, branch)
    @inbounds for k = 1:branch.number
        if branch.layout.status[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            power.from.active[k], power.from.reactive[k] = PijQij(ac, Vi, Vj, k)
            power.to.active[k], power.to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            power.series.active[k], power.series.reactive[k] = PlQl(ac, Vij, k)
            power.charging.active[k], power.charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end
end

"""
    injectionPower(system::PowerSystem, analysis::AC; label)

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
function injectionPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    PiQi(system.model.ac, analysis.voltage, idx)
end

"""
    supplyPower(system::PowerSystem, analysis::AC; label)

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
function supplyPower(system::PowerSystem, analysis::ACPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    if system.bus.layout.type[idx] != 1
        Pi, Qi = PiQi(system.model.ac, analysis.voltage, idx)
    end

    if system.bus.layout.type[idx] == 3
        supplyActive = Pi + system.bus.demand.active[idx]
    else
        supplyActive = system.bus.supply.active[idx]
    end

    if system.bus.layout.type[idx] != 1
        supplyReactive = Qi + system.bus.demand.reactive[idx]
    else
        supplyReactive = system.bus.supply.reactive[idx]
    end

    return supplyActive, supplyReactive
end

function supplyPower(system::PowerSystem, analysis::ACOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    supplyActive = 0.0
    supplyReactive = 0.0
    if haskey(system.bus.supply.generator, idx)
        @inbounds for i in system.bus.supply.generator[idx]
            supplyActive += analysis.power.generator.active[i]
            supplyReactive += analysis.power.generator.reactive[i]
        end
    end

    return supplyActive, supplyReactive
end

function supplyPower(
    system::PowerSystem,
    analysis::Union{PMUStateEstimation, ACStateEstimation};
    label::IntStr
)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    Pi, Qi = injectionPower(system, analysis; label = label)

    return Pi + system.bus.demand.active[idx], Qi + system.bus.demand.reactive[idx]
end

"""
    shuntPower(system::PowerSystem, analysis::AC; label)

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
function shuntPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    PsQs(system.bus, analysis.voltage, idx)
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
function fromPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return PijQij(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
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
function toPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return PjiQji(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
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
function chargingPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        return PcQc(system.branch, analysis.voltage, idx)
    else
        return 0.0, 0.0
    end
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
function seriesPower(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        return PlQl(system.model.ac, ViVjVij(system, analysis.voltage, idx)[3], idx)
    else
        return 0.0, 0.0
    end
end

"""
    generatorPower(system::PowerSystem, analysis::AC; label)

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
function generatorPower(system::PowerSystem, analysis::ACPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    gen = system.generator

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 1
        Pi, Qi = PiQi(system.model.ac, analysis.voltage, idxBus)

        service = length(system.bus.supply.generator[idxBus])
        if service == 1
            Pg = gen.output.active[idx]
            Qg = Qi + system.bus.demand.reactive[idxBus]

            if idxBus == system.bus.layout.slack
                Pg = Pi + system.bus.demand.active[idxBus]
            end
        else
            Qminsum = 0.0
            Qmaxsum = 0.0
            Qgensum = 0.0
            QminInf = 0.0
            QmaxInf = 0.0
            QminNew = gen.capability.minReactive[idx]
            QmaxNew = gen.capability.maxReactive[idx]

            idxGen = system.bus.supply.generator[idxBus]
            @inbounds for i in idxGen
                if !isinf(gen.capability.minReactive[i])
                    Qminsum += gen.capability.minReactive[i]
                end
                if !isinf(gen.capability.maxReactive[i])
                    Qmaxsum += gen.capability.maxReactive[i]
                end
                Qgensum += (Qi + system.bus.demand.reactive[idxBus]) / service
            end

            @inbounds for i in idxGen
                if isinf(gen.capability.minReactive[i])
                    Qmin = -abs(Qgensum) - abs(Qminsum) - abs(Qmaxsum)
                    if gen.capability.minReactive[i] == Inf
                        Qmin = -Qmin
                    end
                    if i == idx
                        QminNew = Qmin
                    end
                    QminInf += Qmin
                end
                if isinf(gen.capability.maxReactive[i])
                    Qmax = abs(Qgensum) + abs(Qminsum) + abs(Qmaxsum)
                    if gen.capability.maxReactive[i] == -Inf
                        Qmax = -Qmax
                    end
                    if i == idx
                        QmaxNew = Qmax
                    end
                    QmaxInf += Qmax
                end
            end
            Qminsum += QminInf
            Qmaxsum += QmaxInf

            basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
            if basePowerMVA * abs(Qminsum - Qmaxsum) > 10 * eps(Float64)
                Qg =
                    QminNew + ((Qgensum - Qminsum) / (Qmaxsum - Qminsum)) *
                    (QmaxNew - QminNew)
            else
                Qg = QminNew + (Qgensum - Qminsum) / service
            end

            if idxBus == system.bus.layout.slack && idxGen[1] == idx
                Pg = Pi + system.bus.demand.active[idxBus]

                for i = 2:service
                    Pg -= gen.output.active[idxGen[i]]
                end
            else
                Pg = gen.output.active[idx]
            end
        end
    else
        Pg = 0.0
        Qg = 0.0
    end

    return Pg, Qg
end

function generatorPower(system::PowerSystem, analysis::ACOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)
    idx = system.generator.label[getLabel(system.generator, label, "generator")]

    return analysis.power.generator.active[idx], analysis.power.generator.reactive[idx]
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
    errorVoltage(analysis.voltage.magnitude)

    ac = system.model.ac
    prmtr = system.branch.parameter
    voltg = analysis.voltage
    current = analysis.current

    current.injection.magnitude = fill(0.0, system.bus.number)
    current.injection.angle = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.bus.number
        current.injection.magnitude[i], current.injection.angle[i] = absang(Ii(ac, voltg, i))
    end

    current.from.magnitude = fill(0.0, system.branch.number)
    current.from.angle = fill(0.0, system.branch.number)
    current.to.magnitude = fill(0.0, system.branch.number)
    current.to.angle = fill(0.0, system.branch.number)
    current.series.magnitude = fill(0.0, system.branch.number)
    current.series.angle = fill(0.0, system.branch.number)
    @inbounds for k = 1:system.branch.number
        if system.branch.layout.status[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            current.from.magnitude[k], current.from.angle[k] = IijΨij(ac, Vi, Vj, k)
            current.to.magnitude[k], current.to.angle[k] = IjiΨji(ac, Vi, Vj, k)
            current.series.magnitude[k], current.series.angle[k] = IsΨs(ac, Vij, k)
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
function injectionCurrent(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    absang(Ii(system.model.ac, analysis.voltage, idx))
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
function fromCurrent(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return IijΨij(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
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
function toCurrent(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return IjiΨji(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
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
function seriesCurrent(system::PowerSystem, analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        return IsΨs(system.model.ac, ViVjVij(system, analysis.voltage, idx)[3], idx)
    else
        return 0.0, 0.0
    end
end

######### Privite AC Analysis Functions ##########
function ViVj(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)
    Vi = V.magnitude[i] * cis(V.angle[i])
    Vj = V.magnitude[j] * cis(V.angle[j])

    return Vi, Vj
end

function ViVjVij(system::PowerSystem, V::Polar, idx::Int64)
    prmtr = system.branch.parameter

    tij = (1 / prmtr.turnsRatio[idx]) * cis(-prmtr.shiftAngle[idx])
    Vi, Vj = ViVj(system, V, idx)

    return Vi, Vj, tij * Vi - Vj
end

function Ii(ac::ACModel, V::Polar, i::Int64)
    I = 0.0 + im * 0.0
    for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        k = ac.nodalMatrix.rowval[j]
        I += ac.nodalMatrixTranspose.nzval[j] * (V.magnitude[k] * cis(V.angle[k]))
    end

    return I
end

function PsQs(bus::Bus, V::Polar, i::Int64)
    reim(
        V.magnitude[i]^2 *
        conj(bus.shunt.conductance[i] + im * bus.shunt.susceptance[i])
    )
end

function PiQi(ac::ACModel, V::Polar, idx::Int64)
    reim(conj(Ii(ac, V, idx)) * (V.magnitude[idx] * cis(V.angle[idx])))
end

function PijQij(ac::ACModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    reim(Vi * conj(Vi * ac.nodalFromFrom[i] + Vj * ac.nodalFromTo[i]))
end

function PjiQji(ac::ACModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    reim(Vj * conj(Vi * ac.nodalToFrom[i] + Vj * ac.nodalToTo[i]))
end

function PlQl(ac::ACModel, Vij::ComplexF64, i::Int64)
    reim(Vij * conj(ac.admittance[i] * Vij))
end

function PcQc(branch::Branch, V::Polar, i::Int64)
    prmtr = branch.parameter
    τinv = 1 / prmtr.turnsRatio[i]
    Vi = V.magnitude[branch.layout.from[i]]
    Vj = V.magnitude[branch.layout.to[i]]

    reim(
        0.5 * conj(prmtr.conductance[i] + im * prmtr.susceptance[i]) *
        ((τinv * Vi)^2 + Vj^2)
    )
end

function IijΨij(ac::ACModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    absang(Vi * ac.nodalFromFrom[i] + Vj * ac.nodalFromTo[i])
end

function IjiΨji(ac::ACModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    absang(Vi * ac.nodalToFrom[i] + Vj * ac.nodalToTo[i])
end

function IsΨs(ac::ACModel, Vij::ComplexF64, i::Int64)
    absang(ac.admittance[i] * Vij)
end

function initializePower(power::ACPower, bus::Bus)
    @inbounds for field in (:injection, :supply, :shunt), component in (:active, :reactive)
        setfield!(getfield(power, field), component, fill(0.0, bus.number))
    end
end

function initializePower(power::ACPower, branch::Branch)
    @inbounds for field in (:from, :to, :charging, :series), component in (:active, :reactive)
        setfield!(getfield(power, field), component, fill(0.0, branch.number))
    end
end

function initializeCurrent(current::ACCurrent, branch::Branch)
    @inbounds for field in (:from, :to, :series), component in (:magnitude, :angle)
        setfield!(getfield(current, field), component, fill(0.0, branch.number))
    end
end