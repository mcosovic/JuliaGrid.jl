"""
    addBus!(system::PowerSystem;
        label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

The function adds a new bus to the `PowerSystem` composite type.

# Keywords
The bus is defined with the following keywords:
* `label`: Unique label for the bus.
* `type`: Bus type:
  * `type = 1`: demand bus (PQ),
  * `type = 2`: generator bus (PV),
  * `type = 3`: slack bus (Vθ).
* `active` (pu or W): Active power demand at the bus.
* `reactive` (pu or VAr): Reactive power demand at the bus.
* `conductance` (pu or W): Active power demanded of the shunt element.
* `susceptance` (pu or VAr): Reactive power injected/demanded of the shunt element.
* `magnitude` (pu or V): Initial value of the bus voltage magnitude.
* `angle` (rad or deg): Initial value of the bus voltage angle.
* `minMagnitude` (pu or V): Minimum bus voltage magnitude value.
* `maxMagnitude` (pu or V): Maximum bus voltage magnitude value.
* `base` (V): Line-to-line voltage base value.
* `area`: Area number.
* `lossZone`: Loss zone.

Note that all voltage values, except for base voltages, are referenced to line-to-neutral
voltages, while powers, when given in SI units, correspond to three-phase power.

# Updates
The function updates the `bus` field of the `PowerSystem` composite type.

# Default Settings
The default settings for certain keywords are as follows: `type = 1`, `magnitude = 1.0`,
`minMagnitude = 0.9`, `maxMagnitude = 1.1`, and `base = 138e3`. The rest of the keywords
are initialized with a value of zero. However, the user can modify these default settings
by utilizing the [`@bus`](@ref @bus) macro.

# Units
By default, the keyword parameters use per-units (pu) and radians (rad) as units, with the
exception of the `base` keyword argument, which is in volts (V). However, users have the
option to use other units instead of per-units and radians, or to specify prefixes for base
voltage by using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage) macros.

# Examples
Adding a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, angle = 0.175, base = 132e3)
```

Adding a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", active = 25.0, angle = 10.026, base = 132.0)
```
"""
function addBus!(system::PowerSystem; label::IntStrMiss = missing, kwargs...)
    bus = system.bus
    demand = bus.demand
    shunt = bus.shunt
    voltg = bus.voltage
    def = template.bus
    key = buskwargs(; kwargs...)

    bus.number += 1
    setLabel(bus, label, def.label, "bus")

    add!(bus.layout.type, key.type, def.type)
    if !(bus.layout.type[end] in [1, 2, 3])
        throw(ErrorException("The value $(key.type) of the bus type is illegal."))
    end
    if bus.layout.type[end] == 3
        if bus.layout.slack != 0
            throw(ErrorException("The slack bus has already been designated."))
        end
        bus.layout.slack = bus.number
    end

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    add!(demand.active, key.active, def.active, pfx.activePower, baseInv)
    add!(demand.reactive, key.reactive, def.reactive, pfx.reactivePower, baseInv)
    add!(shunt.conductance, key.conductance, def.conductance, pfx.activePower, baseInv)
    add!(shunt.susceptance, key.susceptance, def.susceptance, pfx.reactivePower, baseInv)

    if isset(key.base)
        baseVoltage = key.base * pfx.baseVoltage
    else
        baseVoltage = def.base
    end
    push!(system.base.voltage.value, baseVoltage / system.base.voltage.prefix)

    baseInv = sqrt(3) / baseVoltage
    add!(voltg.magnitude, key.magnitude, def.magnitude, pfx.voltageMagnitude, baseInv)
    add!(voltg.minMagnitude, key.minMagnitude, def.minMagnitude, pfx.voltageMagnitude, baseInv)
    add!(voltg.maxMagnitude, key.maxMagnitude, def.maxMagnitude, pfx.voltageMagnitude, baseInv)
    add!(voltg.angle, key.angle, def.angle, pfx.voltageAngle, 1.0)

    add!(bus.layout.area, key.area, def.area)
    add!(bus.layout.lossZone, key.lossZone, def.lossZone)

    push!(bus.supply.active, 0.0)
    push!(bus.supply.reactive, 0.0)

    if !isempty(system.model.ac.nodalMatrix)
        acModelEmpty!(system.model.ac)
        @info("The AC model has been completely erased.")
    end

    if !isempty(system.model.dc.nodalMatrix)
        dcModelEmpty!(system.model.dc)
        @info("The DC model has been completely erased.")
    end
end

function addBus!(
    system::PowerSystem,
    analysis::Union{ACPowerFlow, DCPowerFlow, ACOptimalPowerFlow, DCOptimalPowerFlow};
    kwargs...
)
    throw(ErrorException("The analysis model cannot be reused when adding a bus."))
end

"""
    updateBus!(system::PowerSystem, [analysis::Analysis]; kwargs...)

The function allows for the alteration of parameters for an existing bus.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific bus, provide the necessary `kwargs` input arguments in accordance with
the keywords specified in the [`addBus!`](@ref addBus!) function, along with their
respective values. Ensure that the `label` keyword matches the `label` of the existing bus
you want to modify. If any keywords are omitted, their corresponding values will remain
unchanged.

# Updates
The function updates the `bus` field within the `PowerSystem` composite type, and in cases
where parameters impact variables in the `ac` field, it automatically adjusts the field.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addBus!`](@ref addBus!) function.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
updateBus!(system; label = "Bus 1", active = 0.15, susceptance = 0.15)
```
"""
function updateBus!(system::PowerSystem; label::IntStrMiss, kwargs...)
    bus = system.bus
    baseVoltg = system.base.voltage
    ac = system.model.ac
    key = buskwargs(; kwargs...)

    idx = bus.label[getLabel(bus, label, "bus")]

    if isset(key.type)
        if key.type in [1; 2]
            if bus.layout.slack == idx
                bus.layout.slack = 0
            end
            bus.layout.type[idx] = key.type
        end
        if key.type == 3
            if bus.layout.slack != 0 && bus.layout.slack != idx
                throw(ErrorException(
                    "To set bus with label " * label * " as the slack bus, reassign " *
                    "the current slack bus to either a generator or demand bus.")
                )
            end
            bus.layout.type[idx] = 3
            bus.layout.slack = idx
        end
    end

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    update!(bus.demand.active, key.active, pfx.activePower, baseInv, idx)
    update!(bus.demand.reactive, key.reactive, pfx.reactivePower, baseInv, idx)

    if isset(key.conductance, key.susceptance)
        if !isempty(ac.nodalMatrix)
            ac.model += 1

            admittance = complex(bus.shunt.conductance[idx], bus.shunt.susceptance[idx])
            ac.nodalMatrix[idx, idx] -= admittance
            ac.nodalMatrixTranspose[idx, idx] -= admittance
        end

        update!(bus.shunt.conductance, key.conductance, pfx.activePower, baseInv, idx)
        update!(bus.shunt.susceptance, key.susceptance, pfx.reactivePower, baseInv, idx)

        if !isempty(ac.nodalMatrix)
            admittance = complex(bus.shunt.conductance[idx], bus.shunt.susceptance[idx])
            ac.nodalMatrix[idx, idx] += admittance
            ac.nodalMatrixTranspose[idx, idx] += admittance
        end
    end

    if isset(key.base)
        baseVoltg.value[idx] = key.base * pfx.baseVoltage / baseVoltg.prefix
    end

    baseInv = sqrt(3) / (baseVoltg.value[idx] * baseVoltg.prefix)
    update!(bus.voltage.magnitude, key.magnitude, pfx.voltageMagnitude, baseInv, idx)
    update!(bus.voltage.angle, key.angle, pfx.voltageAngle, 1.0, idx)
    update!(bus.voltage.minMagnitude, key.minMagnitude, pfx.voltageMagnitude, baseInv, idx)
    update!(bus.voltage.maxMagnitude, key.maxMagnitude, pfx.voltageMagnitude, baseInv, idx)

    update!(bus.layout.area, key.area, idx)
    update!(bus.layout.lossZone, key.lossZone, idx)
end

function updateBus!(
    system::PowerSystem,
    analysis::ACPowerFlow{NewtonRaphson};
    label::IntStrMiss,
    kwargs...
)
    key = buskwargs(; kwargs...)

    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    if isset(key.type) && key.type != system.bus.layout.type[idx]
        errorTypeConversion()
    end

    updateBus!(system; label, key...)

    if isset(key.magnitude) && system.bus.layout.type[idx] == 1
        analysis.voltage.magnitude[idx] = system.bus.voltage.magnitude[idx]
    end
    if isset(key.angle)
        analysis.voltage.angle[idx] = system.bus.voltage.angle[idx]
    end
end

function updateBus!(
    system::PowerSystem,
    analysis::ACPowerFlow{FastNewtonRaphson};
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    key = buskwargs(; kwargs...)

    idx = bus.label[getLabel(bus, label, "bus")]

    if isset(key.type) && key.type != bus.layout.type[idx]
        errorTypeConversion()
    end

    if isset(key.susceptance) && bus.layout.type[idx] == 1
        oldSusceptance = bus.shunt.susceptance[idx]
    end

    updateBus!(system; label, key...)

    if isset(key.magnitude) && bus.layout.type[idx] == 1
        analysis.voltage.magnitude[idx] = bus.voltage.magnitude[idx]
    end
    if isset(key.angle)
        analysis.voltage.angle[idx] = bus.voltage.angle[idx]
    end

    if isset(key.susceptance) && bus.layout.type[idx] == 1
        if oldSusceptance != bus.shunt.susceptance[idx]
            i = analysis.method.pq[idx]
            analysis.method.reactive.jacobian[i, i] -= oldSusceptance
            analysis.method.reactive.jacobian[i, i] += bus.shunt.susceptance[idx]
        end
    end
end

function updateBus!(
    system::PowerSystem,
    analysis::ACPowerFlow{GaussSeidel};
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    volt = analysis.voltage
    key = buskwargs(; kwargs...)

    idx = bus.label[getLabel(bus, label, "bus")]

    if isset(key.type) && key.type != bus.layout.type[idx]
        errorTypeConversion()
    end

    updateBus!(system; label, key...)

    if isset(key.magnitude, key.angle)
        if isset(key.magnitude) && bus.layout.type[idx] == 1
            volt.magnitude[idx] = bus.voltage.magnitude[idx]
        end
        if isset(key.angle)
            volt.angle[idx] = bus.voltage.angle[idx]
        end
        analysis.method.voltage[idx] = volt.magnitude[idx] * cis(volt.angle[idx])
    end
end

function updateBus!(
    system::PowerSystem,
    analysis::DCPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    key = buskwargs(; kwargs...)

    idx = system.bus.label[getLabel(system.bus, label, "bus")]

    if isset(key.type) && system.bus.layout.slack == idx && key.type != 3
        errorTypeConversion()
    end

    updateBus!(system; label, key...)
end

function updateBus!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    key = buskwargs(; kwargs...)

    idx = bus.label[getLabel(bus, label, "bus")]
    typeOld = bus.layout.type[idx]

    updateBus!(system; label, key...)

    activeupd = isset(key.conductance, key.susceptance, key.active)
    reactvupd = isset(key.conductance, key.susceptance, key.reactive)

    if activeupd || reactvupd
        updateBalance(system, analysis, idx; active = activeupd, reactive = reactvupd)
    end

    if isset(key.magnitude)
        analysis.voltage.magnitude[idx] = bus.voltage.magnitude[idx]
    end
    if isset(key.angle)
        analysis.voltage.angle[idx] = bus.voltage.angle[idx]
    end

    if isset(key.minMagnitude, key.maxMagnitude)
        remove!(jump, constr.voltage.magnitude, idx)
        addMagnitude(system, jump, variable.magnitude, constr.voltage.magnitude, idx)
    end

    if typeOld == 3 && bus.layout.type[idx] != 3
        unfix!(jump, variable.angle[idx], constr.slack.angle, idx)
    end

    if bus.layout.type[idx] == 3
        fix!(variable.angle[idx], bus.voltage.angle[idx], constr.slack.angle, idx)
    end
end

function updateBus!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    constr = analysis.method.constraint
    variable = analysis.method.variable

    key = buskwargs(; kwargs...)

    idx = bus.label[getLabel(bus, label, "bus")]
    typeOld = bus.layout.type[idx]

    updateBus!(system; label, key...)

    if isset(key.conductance, key.active)
        updateBalance(system, analysis, idx; rhs = true)
    end

    if isset(key.angle)
        analysis.voltage.angle[idx] = bus.voltage.angle[idx]
    end

    if typeOld == 3 && bus.layout.type[idx] != 3
        unfix!(analysis.method.jump, variable.angle[idx], constr.slack.angle, idx)
    end

    if bus.layout.type[idx] == 3
        fix!(variable.angle[idx], bus.voltage.angle[idx], constr.slack.angle, idx)
    end
end

"""
    @bus(kwargs...)

The macro generates a template for a bus, which can be utilized to define a bus using the
[`addBus!`](@ref addBus!) function.

# Keywords
To define the bus template, the `kwargs` input arguments must be provided in accordance with
the keywords specified within the [`addBus!`](@ref addBus!) function, along with their
corresponding values.

# Units
By default, the keyword parameters use per-units (pu) and radians (rad) as units, with the
exception of the `base` keyword argument, which is in volts (V). However, users have the
option to use other units instead of per-units and radians, or to specify prefixes for base
voltage by using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage) macros.

# Examples
Adding a bus template using the default unit system:
```jldoctest
system = powerSystem()

@bus(type = 2, active = 0.25, angle = 0.1745)
addBus!(system; label = "Bus 1", reactive = -0.04, base = 132e3)
```

Adding a bus template using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

@bus(type = 2, active = 25.0, angle = 10.0, base = 132.0)
addBus!(system; label = "Bus 1", reactive = -4.0)
```
"""
macro bus(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]

        if hasfield(BusTemplate, parameter)
            if !(parameter in [:base; :type; :area; :lossZone; :label])
                container::ContainerTemplate = getfield(template.bus, parameter)
                if parameter in [:active; :conductance]
                    pfxLive = pfx.activePower
                elseif parameter in [:reactive; :susceptance]
                    pfxLive = pfx.reactivePower
                elseif parameter in [:magnitude; :minMagnitude; :maxMagnitude]
                    pfxLive = pfx.voltageMagnitude
                elseif parameter == :angle
                    pfxLive = pfx.voltageAngle
                end
                if pfxLive != 0.0
                    setfield!(container, :value, pfxLive * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, true)
                end
            else
                if parameter == :base
                    setfield!(
                        template.bus, parameter,
                        Float64(eval(kwarg.args[2])) * pfx.baseVoltage
                    )
                elseif parameter == :type
                    setfield!(template.bus, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter in [:area; :lossZone]
                    setfield!(template.bus, parameter, Int64(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?")
                        setfield!(template.bus, parameter, label)
                    else
                        errorTemplateSymbol()
                    end
                end
            end
        else
            errorTemplateKeyword(parameter)
        end
    end
end

##### Bus Keywords #####
function buskwargs(;
    type::IntMiss = missing,
    active::FltIntMiss = missing,
    reactive::FltIntMiss = missing,
    conductance::FltIntMiss = missing,
    susceptance::FltIntMiss = missing,
    magnitude::FltIntMiss = missing,
    angle::FltIntMiss = missing,
    minMagnitude::FltIntMiss = missing,
    maxMagnitude::FltIntMiss = missing,
    base::FltIntMiss = missing,
    area::IntMiss = missing,
    lossZone::FltIntMiss = missing
)
    (
    type = type,
    active = active, reactive = reactive,
    conductance = conductance, susceptance = susceptance,
    magnitude = magnitude, angle = angle,
    minMagnitude = minMagnitude, maxMagnitude = maxMagnitude,
    base = base, area = area, lossZone = lossZone
    )
end