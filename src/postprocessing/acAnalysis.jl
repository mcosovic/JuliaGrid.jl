"""
    power!(analysis::AC)

The function computes the active and reactive powers associated with buses, branches, and generators
for AC analysis.

# Updates
This function updates the `power` field of the `AC` abstract type by computing the following
electrical quantities:
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
powerFlow!(analysis)

power!(analysis)
```
"""
function power!(analysis::AcPowerFlow)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    branch = system.branch
    gen = system.generator

    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power
    slack = bus.layout.slack

    initialize!(power, bus.number, (:injection, :supply, :shunt))
    shunt = power.shunt
    injection = power.injection
    supply = power.supply
    busSupply = bus.supply
    demand = bus.demand
    busType = bus.layout.type
    @inbounds for i = 1:bus.number
        shunt.active[i], shunt.reactive[i] = PsQs(bus, voltg, i)
        injection.active[i], injection.reactive[i] = PiQi(ac, voltg, i)

        supply.active[i] = busSupply.active[i]
        if busType[i] != 1
            supply.reactive[i] = injection.reactive[i] + demand.reactive[i]
        else
            supply.reactive[i] = busSupply.reactive[i]
        end
    end
    supply.active[slack] = injection.active[slack] + demand.active[slack]

    initialize!(power, branch.number, (:from, :to, :charging, :series))
    from = power.from
    to = power.to
    series = power.series
    charging = power.charging
    branchStatus = branch.layout.status
    @inbounds for k = 1:branch.number
        if branchStatus[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            from.active[k], from.reactive[k] = PijQij(ac, Vi, Vj, k)
            to.active[k], to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            series.active[k], series.reactive[k] = PlQl(ac, Vij, k)
            charging.active[k], charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end

    initialize!(power, gen.number, (:generator,))
    generator = power.generator
    basePowerMVA = system.base.power.value * system.base.power.prefix * 1e-6
    genStatus = gen.layout.status
    genBus = gen.layout.bus
    genActive = gen.output.active
    minReactive = gen.capability.minReactive
    maxReactive = gen.capability.maxReactive
    busGenerators = bus.supply.generator
    demandActive = bus.demand.active
    demandReactive = bus.demand.reactive
    @inbounds for i = 1:gen.number
        if genStatus[i] == 1
            idxBus = genBus[i]
            Pi = injection.active[idxBus]
            Qi = injection.reactive[idxBus]
            idxGen = busGenerators[idxBus]
            service = length(idxGen)

            if service == 1
                generator.active[i] = genActive[i]
                generator.reactive[i] = Qi + demandReactive[idxBus]
                if idxBus == slack
                    generator.active[i] = Pi + demandActive[idxBus]
                end
            else
                Qminsum = 0.0
                Qmaxsum = 0.0
                Qgensum = Qi + demandReactive[idxBus]
                QminInf = 0.0
                QmaxInf = 0.0
                QminNew = minReactive[i]
                QmaxNew = maxReactive[i]

                for j in idxGen
                    if !isinf(minReactive[j])
                        Qminsum += minReactive[j]
                    end
                    if !isinf(maxReactive[j])
                        Qmaxsum += maxReactive[j]
                    end
                end
                for j in idxGen
                    if isinf(minReactive[j])
                        Qmin = -abs(Qgensum) - abs(Qminsum) - abs(Qmaxsum)
                        if minReactive[j] == Inf
                            Qmin = -Qmin
                        end
                        if i == j
                            QminNew = Qmin
                        end
                        QminInf += Qmin
                    end
                    if isinf(maxReactive[j])
                        Qmax = abs(Qgensum) + abs(Qminsum) + abs(Qmaxsum)
                        if maxReactive[j] == -Inf
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
                    generator.reactive[i] =
                        QminNew + ((Qgensum - Qminsum) / (Qmaxsum - Qminsum)) *
                        (QmaxNew - QminNew)
                else
                    generator.reactive[i] = QminNew + (Qgensum - Qminsum) / service
                end

                if idxBus == slack && idxGen[1] == i
                    generator.active[i] = Pi + demandActive[idxBus]

                    for j = 2:service
                        generator.active[i] -= genActive[idxGen[j]]
                    end
                else
                    generator.active[i] = genActive[i]
                end
            end
        end
    end
end

function power!(analysis::AcOptimalPowerFlow)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    branch = system.branch

    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power

    initialize!(power, bus.number, (:injection, :supply, :shunt))
    shunt = power.shunt
    injection = power.injection
    @inbounds for i = 1:bus.number
        shunt.active[i], shunt.reactive[i] = PsQs(bus, voltg, i)
        injection.active[i], injection.reactive[i] = PiQi(ac, voltg, i)
    end

    initialize!(power, branch.number, (:from, :to, :charging, :series))
    from = power.from
    to = power.to
    series = power.series
    charging = power.charging
    branchStatus = branch.layout.status
    @inbounds for k = 1:branch.number
        if branchStatus[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            from.active[k], from.reactive[k] = PijQij(ac, Vi, Vj, k)
            to.active[k], to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            series.active[k], series.reactive[k] = PlQl(ac, Vij, k)
            charging.active[k], charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end

    gen = system.generator
    genBus = gen.layout.bus
    generator = power.generator
    supply = power.supply
    @inbounds for i = 1:gen.number
        idxBus = genBus[i]

        supply.active[idxBus] += generator.active[i]
        supply.reactive[idxBus] += generator.reactive[i]
    end
end

function power!(analysis::Union{PmuStateEstimation, AcStateEstimation})
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    voltg = analysis.voltage
    power = analysis.power

    initialize!(power, bus.number, (:injection, :supply, :shunt))
    shunt = power.shunt
    injection = power.injection
    supply = power.supply
    demand = bus.demand
    @inbounds for i = 1:bus.number
        shunt.active[i], shunt.reactive[i] = PsQs(bus, voltg, i)
        injection.active[i], injection.reactive[i] = PiQi(ac, voltg, i)

        supply.active[i] = injection.active[i] + demand.active[i]
        supply.reactive[i] = injection.reactive[i] + demand.reactive[i]
    end

    initialize!(power, branch.number, (:from, :to, :charging, :series))
    from = power.from
    to = power.to
    series = power.series
    charging = power.charging
    branchStatus = branch.layout.status
    @inbounds for k = 1:branch.number
        if branchStatus[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            from.active[k], from.reactive[k] = PijQij(ac, Vi, Vj, k)
            to.active[k], to.reactive[k] = PjiQji(ac, Vi, Vj, k)
            series.active[k], series.reactive[k] = PlQl(ac, Vij, k)
            charging.active[k], charging.reactive[k] = PcQc(branch, voltg, k)
        end
    end
end

"""
    injectionPower(analysis::AC; label)

The function returns the active and reactive power injections associated with a specific bus in the
AC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = injectionPower(analysis; label = "Bus 1 HV")
```
"""
function injectionPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system

    PiQi(system.model.ac, analysis.voltage, getIndex(system.bus, label, "bus"))
end

"""
    supplyPower(analysis::AC; label)

The function returns the active and reactive power injections from the generators associated with a
specific bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = supplyPower(analysis; label = "Bus 1 HV")
```
"""
function supplyPower(analysis::AcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")
    busType = bus.layout.type[idx]

    if busType != 1
        Pi, Qi = PiQi(system.model.ac, analysis.voltage, idx)
    end

    if busType == 3
        supplyActive = Pi + bus.demand.active[idx]
    else
        supplyActive = bus.supply.active[idx]
    end

    if busType != 1
        supplyReactive = Qi + bus.demand.reactive[idx]
    else
        supplyReactive = bus.supply.reactive[idx]
    end

    return supplyActive, supplyReactive
end

function supplyPower(analysis::AcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    idx = getIndex(bus, label, "bus")
    busGenerators = bus.supply.generator
    generator = analysis.power.generator

    supplyActive = 0.0
    supplyReactive = 0.0
    if haskey(busGenerators, idx)
        @inbounds for i in busGenerators[idx]
            supplyActive += generator.active[i]
            supplyReactive += generator.reactive[i]
        end
    end

    return supplyActive, supplyReactive
end

function supplyPower(analysis::Union{PmuStateEstimation, AcStateEstimation}; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    demand = bus.demand
    idx = getIndex(bus, label, "bus")

    Pi, Qi = PiQi(system.model.ac, analysis.voltage, idx)

    return Pi + demand.active[idx], Qi + demand.reactive[idx]
end

"""
    shuntPower(analysis::AC; label)

The function returns the active and reactive power values of the shunt element associated with a
specific bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = shuntPower(analysis; label = "Bus 9 LV")
```
"""
function shuntPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus

    PsQs(bus, analysis.voltage, getIndex(bus, label, "bus"))
end

"""
    fromPower(analysis::AC; label)

The function returns the active and reactive power flows at the from-bus end associated with a
specific branch in the AC framework. The `label` keyword argument must match an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = fromPower(analysis; label = 2)
```
"""
function fromPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return PijQij(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
end

"""
    toPower(analysis::AC; label)

The function returns the active and reactive power flows at the to-bus end associated with a specific
branch in the AC framework. The `label` keyword argument must match an existing branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = toPower(analysis; label = 2)
```
"""
function toPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return PjiQji(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
end

"""
    chargingPower(analysis::AC; label)

The function returns the active and reactive power values associated with the charging admittances
of a specific branch in the AC framework. The `label` keyword argument must correspond to an existing
branch label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = chargingPower(analysis; label = 2)
```
"""
function chargingPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        return PcQc(branch, analysis.voltage, idx)
    else
        return 0.0, 0.0
    end
end

"""
    seriesPower(analysis::AC; label)

The function returns the active and reactive power losses across the series impedance of a specific
branch within the AC framework. The `label` keyword argument should correspond to an existing branch
label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = seriesPower(analysis; label = 2)
```
"""
function seriesPower(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        return PlQl(system.model.ac, Vij(system, analysis.voltage, idx), idx)
    else
        return 0.0, 0.0
    end
end

"""
    generatorPower(analysis::AC; label)

The function returns the active and reactive powers associated with a specific generator in the AC
framework. The `label` keyword argument must match an existing generator label.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

active, reactive = generatorPower(analysis; label = 1)
```
"""
function generatorPower(analysis::AcPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    gen = system.generator
    genActive = gen.output.active
    minReactive = gen.capability.minReactive
    maxReactive = gen.capability.maxReactive
    demandActive = bus.demand.active
    demandReactive = bus.demand.reactive
    busGenerators = bus.supply.generator
    slack = bus.layout.slack

    idx = getIndex(gen, label, "generator")
    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 1
        Pi, Qi = PiQi(system.model.ac, analysis.voltage, idxBus)

        idxGen = busGenerators[idxBus]
        service = length(idxGen)
        if service == 1
            Pg = genActive[idx]
            Qg = Qi + demandReactive[idxBus]

            if idxBus == slack
                Pg = Pi + demandActive[idxBus]
            end
        else
            Qminsum = 0.0
            Qmaxsum = 0.0
            Qgensum = Qi + demandReactive[idxBus]
            QminInf = 0.0
            QmaxInf = 0.0
            QminNew = minReactive[idx]
            QmaxNew = maxReactive[idx]

            @inbounds for i in idxGen
                if !isinf(minReactive[i])
                    Qminsum += minReactive[i]
                end
                if !isinf(maxReactive[i])
                    Qmaxsum += maxReactive[i]
                end
            end

            @inbounds for i in idxGen
                if isinf(minReactive[i])
                    Qmin = -abs(Qgensum) - abs(Qminsum) - abs(Qmaxsum)
                    if minReactive[i] == Inf
                        Qmin = -Qmin
                    end
                    if i == idx
                        QminNew = Qmin
                    end
                    QminInf += Qmin
                end
                if isinf(maxReactive[i])
                    Qmax = abs(Qgensum) + abs(Qminsum) + abs(Qmaxsum)
                    if maxReactive[i] == -Inf
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
                Qg = QminNew + ((Qgensum - Qminsum) / (Qmaxsum - Qminsum)) * (QmaxNew - QminNew)
            else
                Qg = QminNew + (Qgensum - Qminsum) / service
            end

            if idxBus == slack && idxGen[1] == idx
                Pg = Pi + demandActive[idxBus]

                for i = 2:service
                    Pg -= genActive[idxGen[i]]
                end
            else
                Pg = genActive[idx]
            end
        end
    else
        Pg = 0.0
        Qg = 0.0
    end

    return Pg, Qg
end

function generatorPower(analysis::AcOptimalPowerFlow; label::IntStr)
    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    generator = analysis.power.generator
    idx = getIndex(system.generator, label, "generator")

    return generator.active[idx], generator.reactive[idx]
end

"""
    current!(analysis::AC)

The function computes the currents in the polar coordinate system associated with buses and branches
in the AC framework.

# Updates
This function updates the `current` field of the `AC` abstract type by computing the following
electrical quantities:
- `injection`: Current injections at each bus.
- `from`: Current flows at each from-bus end of the branch.
- `to`: Current flows at each to-bus end of the branch.
- `series`: Current flows through the series impedance of the branch in the direction from-bus to-bus end.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

current!(analysis)
```
"""
function current!(analysis::AC)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    voltg = analysis.voltage
    current = analysis.current

    initialize!(current, bus.number, (:injection,))
    injection = current.injection
    @inbounds for i = 1:bus.number
        injection.magnitude[i], injection.angle[i] = absang(Ii(ac, voltg, i))
    end

    initialize!(current, branch.number, (:from, :to, :series))
    from = current.from
    to = current.to
    series = current.series
    branchStatus = branch.layout.status
    @inbounds for k = 1:branch.number
        if branchStatus[k] == 1
            Vi, Vj, Vij = ViVjVij(system, voltg, k)

            from.magnitude[k], from.angle[k] = IijΨij(ac, Vi, Vj, k)
            to.magnitude[k], to.angle[k] = IjiΨji(ac, Vi, Vj, k)
            series.magnitude[k], series.angle[k] = IsΨs(ac, Vij, k)
        end
    end
end

"""
    injectionCurrent(analysis::AC; label)

The function returns the current injection in the polar coordinate system associated with a specific
bus in the AC framework. The `label` keyword argument must match an existing bus label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

magnitude, angle = injectionCurrent(analysis; label = "Bus 1 HV")
```
"""
function injectionCurrent(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    idx = getIndex(system.bus, label, "bus")

    absang(Ii(system.model.ac, analysis.voltage, idx))
end

"""
    fromCurrent(analysis::AC; label)

The function returns the current in the polar coordinate system at the from-bus end associated with
a specific branch in the AC framework. The `label` keyword argument must match an existing branch
label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

magnitude, angle = fromCurrent(analysis; label = 2)
```
"""
function fromCurrent(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return IijΨij(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
end

"""
    toCurrent(analysis::AC; label)

The function returns the current in the polar coordinate system at the to-bus end associated with a
specific branch in the AC framework. The `label` keyword argument must match an existing branch label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

magnitude, angle = toCurrent(analysis; label = 2)
```
"""
function toCurrent(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        Vi, Vj = ViVj(system, analysis.voltage, idx)
        return IjiΨji(system.model.ac, Vi, Vj, idx)
    else
        return 0.0, 0.0
    end
end

"""
    seriesCurrent(analysis::AC; label)

The function returns the current in the polar coordinate system through series impedance associated
with a specific branch in the direction from the from-bus end to the to-bus end of the branch within
the AC framework. The `label` keyword argument must  match an existing branch label.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

magnitude, angle = seriesCurrent(analysis; label = 2)
```
"""
function seriesCurrent(analysis::AC; label::IntStr)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    branch = system.branch
    idx = getIndex(branch, label, "branch")

    if branch.layout.status[idx] == 1
        return IsΨs(system.model.ac, Vij(system, analysis.voltage, idx), idx)
    else
        return 0.0, 0.0
    end
end

######### AC Analysis Functions ##########
@inline function ViVj(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)
    magnitude = V.magnitude
    angle = V.angle

    magnitude[i] * cis(angle[i]), magnitude[j] * cis(angle[j])
end

@inline function ViVjVij(system::PowerSystem, V::Polar, idx::Int64)
    prmtr = system.branch.parameter

    tij = (1 / prmtr.turnsRatio[idx]) * cis(-prmtr.shiftAngle[idx])
    Vi, Vj = ViVj(system, V, idx)

    Vi, Vj, tij * Vi - Vj
end

@inline function Vij(system::PowerSystem, V::Polar, idx::Int64)
    branch = system.branch
    prmtr = branch.parameter
    i = branch.layout.from[idx]
    j = branch.layout.to[idx]
    magnitude = V.magnitude
    angle = V.angle

    tij = (1 / prmtr.turnsRatio[idx]) * cis(-prmtr.shiftAngle[idx])

    tij * (magnitude[i] * cis(angle[i])) - magnitude[j] * cis(angle[j])
end

function Ii(ac::AcModel, V::Polar, i::Int64)
    I = 0.0 + im * 0.0
    colptr = ac.nodalMatrix.colptr
    rowval = ac.nodalMatrix.rowval
    nzval = ac.nodalMatrixTranspose.nzval
    magnitude = V.magnitude
    angle = V.angle

    @inbounds for j in colptr[i]:(colptr[i + 1] - 1)
        k = rowval[j]
        I += nzval[j] * (magnitude[k] * cis(angle[k]))
    end

    I
end

@inline function PsQs(bus::Bus, V::Polar, i::Int64)
    shunt = bus.shunt
    magnitude = V.magnitude

    reim(magnitude[i]^2 * conj(complex(shunt.conductance[i], shunt.susceptance[i])))
end

@inline function PiQi(ac::AcModel, V::Polar, idx::Int64)
    magnitude = V.magnitude
    angle = V.angle

    reim(conj(Ii(ac, V, idx)) * (magnitude[idx] * cis(angle[idx])))
end

@inline function PijQij(ac::AcModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    reim(Vi * conj(Vi * ac.nodalFromFrom[i] + Vj * ac.nodalFromTo[i]))
end

@inline function PjiQji(ac::AcModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    reim(Vj * conj(Vi * ac.nodalToFrom[i] + Vj * ac.nodalToTo[i]))
end

@inline function PlQl(ac::AcModel, Vij::ComplexF64, i::Int64)
    reim(Vij * conj(ac.admittance[i] * Vij))
end

@inline function PcQc(branch::Branch, V::Polar, i::Int64)
    prmtr = branch.parameter
    layout = branch.layout
    magnitude = V.magnitude
    τinv = 1 / prmtr.turnsRatio[i]
    Vi = magnitude[layout.from[i]]
    Vj = magnitude[layout.to[i]]

    reim(0.5 * conj(prmtr.conductance[i] + im * prmtr.susceptance[i]) * ((τinv * Vi)^2 + Vj^2))
end

@inline function IijΨij(ac::AcModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    absang(Vi * ac.nodalFromFrom[i] + Vj * ac.nodalFromTo[i])
end

@inline function IjiΨji(ac::AcModel, Vi::ComplexF64, Vj::ComplexF64, i::Int64)
    absang(Vi * ac.nodalToFrom[i] + Vj * ac.nodalToTo[i])
end

@inline function IsΨs(ac::AcModel, Vij::ComplexF64, i::Int64)
    absang(ac.admittance[i] * Vij)
end

function initialize!(power::Union{AcPower, AcCurrent, DcPower}, n::Int64, fields::Tuple{Vararg{Symbol}})
    @inbounds for field in fields
        fieldData = getfield(power, field)
        for component in propertynames(fieldData)
            compData = getfield(fieldData, component)
            if isempty(compData)
                resize!(compData, n)
                fill!(compData, 0.0)
            else
                fill!(compData, 0.0)
                m = lastindex(compData)
                if m < n
                    resize!(compData, n)
                    @inbounds for i = (m + 1):n
                        compData[i] = 0.0
                    end
                elseif m > n
                    resize!(compData, n)
                end
            end
        end
    end
end
