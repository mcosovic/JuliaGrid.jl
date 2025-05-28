"""
    addBus!(system::PowerSystem;
        label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

The function adds a new bus to the `PowerSystem` type.

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

Note that all voltage values, except for base voltages, are referenced to line-to-neutral voltages,
while powers, when given in SI units, correspond to three-phase power.

# Updates
The function updates the `bus` field of the `PowerSystem` type.

# Default Settings
The default settings for certain keywords are as follows: `type = 1`, `magnitude = 1.0`,
`minMagnitude = 0.9`, `maxMagnitude = 1.1`, and `base = 138e3`. The rest of the keywords are
initialized with a value of zero. However, the user can modify these default settings by utilizing
the [`@bus`](@ref @bus) macro.

# Units
By default, the keyword parameters use per-units and radians as units, with the exception of the
`base` keyword argument, which is in volts. However, users have the option to use other units instead
of per-units and radians, or to specify prefixes for base voltage by using the [`@power`](@ref @power)
and [`@voltage`](@ref @voltage) macros.

# Examples
Adding a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, angle = 0.175, base = 132e3)
```

Adding a bus using a custom unit system:
```jldoctest
@power(MW, MVAr)
@voltage(pu, deg, kV)

system = powerSystem()

addBus!(system; label = "Bus 1", active = 25.0, angle = 10.026, base = 132.0)
```
"""
function addBus!(system::PowerSystem; kwargs...)
    bus = system.bus
    def = template.bus
    key = BusKey(; kwargs...)

    bus.number += 1
    setLabel(bus, key.label, def.label, "bus")

    add!(bus.layout.type, key.type, def.type)
    if bus.layout.type[end] ∉ (1, 2, 3)
        throw(ErrorException("The value $(key.type) of the bus type is illegal."))
    end
    if bus.layout.type[end] == 3
        if bus.layout.slack != 0
            throw(ErrorException("The slack bus has already been designated."))
        end
        bus.layout.slack = bus.number
    end

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    add!(bus.demand.active, key.active, def.active, pfx.activePower, baseInv)
    add!(bus.demand.reactive, key.reactive, def.reactive, pfx.reactivePower, baseInv)
    add!(bus.shunt.conductance, key.conductance, def.conductance, pfx.activePower, baseInv)
    add!(bus.shunt.susceptance, key.susceptance, def.susceptance, pfx.reactivePower, baseInv)

    baseVoltage = isset(key.base) ? key.base * pfx.baseVoltage : def.base
    push!(system.base.voltage.value, baseVoltage / system.base.voltage.prefix)

    baseInv = sqrt(3) / baseVoltage
    add!(bus.voltage.magnitude, key.magnitude, def.magnitude, pfx.voltageMagnitude, baseInv)
    add!(bus.voltage.minMagnitude, key.minMagnitude, def.minMagnitude, pfx.voltageMagnitude, baseInv)
    add!(bus.voltage.maxMagnitude, key.maxMagnitude, def.maxMagnitude, pfx.voltageMagnitude, baseInv)
    add!(bus.voltage.angle, key.angle, def.angle, pfx.voltageAngle, 1.0)

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
    analysis::Union{AcPowerFlow, DcPowerFlow, AcOptimalPowerFlow, DcOptimalPowerFlow};
    kwargs...
)
    throw(ErrorException("The analysis model cannot be reused when adding a bus."))
end

"""
    updateBus!(system::PowerSystem; kwargs...)

The function allows for the alteration of parameters for an existing bus.

# Keywords
To update a specific bus, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addBus!`](@ref addBus!) function, along with their respective values.
Ensure that the `label` keyword matches the `label` of the existing bus. If any keywords are omitted,
their corresponding values will remain unchanged.

# Updates
The function updates the `bus` field within the `PowerSystem` type, and in cases where parameters
impact variables in the `ac` field, it automatically adjusts the field.

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
function updateBus!(system::PowerSystem; label::IntStr, kwargs...)
    updateBusMain!(system, label, BusKey(; kwargs...))
end

function updateBusMain!(system::PowerSystem, label::IntStr, key::BusKey)
    bus = system.bus
    ac = system.model.ac
    idx = getIndex(bus, label, "bus")

    if isset(key.type)
        if bus.layout.type[idx] != key.type
            bus.layout.pattern += 1
        end

        if key.type ∈ (1, 2)
            if bus.layout.slack == idx
                bus.layout.slack = 0
            end
            bus.layout.type[idx] = key.type
        end

        if key.type == 3
            if bus.layout.slack ∉ (0, idx)
                throw(ErrorException(
                    "To set bus with label $label as the slack bus, reassign " *
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

    if isset(key.conductance) || isset(key.susceptance)
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
        system.base.voltage.value[idx] = key.base * pfx.baseVoltage / system.base.voltage.prefix
    end

    baseInv = sqrt(3) / (system.base.voltage.value[idx] * system.base.voltage.prefix)
    update!(bus.voltage.magnitude, key.magnitude, pfx.voltageMagnitude, baseInv, idx)
    update!(bus.voltage.angle, key.angle, pfx.voltageAngle, 1.0, idx)
    update!(bus.voltage.minMagnitude, key.minMagnitude, pfx.voltageMagnitude, baseInv, idx)
    update!(bus.voltage.maxMagnitude, key.maxMagnitude, pfx.voltageMagnitude, baseInv, idx)

    update!(bus.layout.area, key.area, idx)
    update!(bus.layout.lossZone, key.lossZone, idx)
end

"""
    updateBus!(analysis::Analysis; kwargs...)

The function extends the [`updateBus!`](@ref updateBus!(::PowerSystem)) function. By passing the
`Analysis` type, the function first updates the specific bus within the `PowerSystem` type using the
provided `kwargs`, and then updates the `Analysis` type with all parameters associated with that bus.

A key feature of this function is that any prior modifications made to the specified bus are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system = powerSystem("case14.h5")
analysis = newtonRaphson(system)

updateBus!(analysis; label = 2, active = 0.15, susceptance = 0.15)
```
"""
function updateBus!(analysis::PowerFlow; label::IntStr, kwargs...)
    updateBusMain!(analysis.system, label, BusKey(; kwargs...))
    _updateBus!(analysis, getIndex(analysis.system.bus, label, "bus"))
end

function _updateBus!(analysis::AcPowerFlow{NewtonRaphson}, idx::Int64)
    errorTypeConversion(analysis.system.bus.layout.pattern, analysis.method.signature[:type])

    if analysis.system.bus.layout.type[idx] == 1
        analysis.voltage.magnitude[idx] = analysis.system.bus.voltage.magnitude[idx]
    end
    analysis.voltage.angle[idx] = analysis.system.bus.voltage.angle[idx]
end

function _updateBus!(analysis::AcPowerFlow{FastNewtonRaphson}, idx::Int64)
    system = analysis.system
    errorTypeConversion(system.bus.layout.pattern, analysis.method.signature[:type])

    if system.bus.layout.type[idx] == 1
        analysis.voltage.magnitude[idx] = system.bus.voltage.magnitude[idx]

        if haskey(analysis.method.signature[:susceptance], idx)
            oldSusceptance = analysis.method.signature[:susceptance][idx]
        else
            oldSusceptance = 0.0
        end

        if system.bus.shunt.susceptance[idx] != oldSusceptance
            i = analysis.method.pq[idx]

            analysis.method.reactive.jacobian[i, i] -= oldSusceptance
            analysis.method.reactive.jacobian[i, i] += system.bus.shunt.susceptance[idx]

            analysis.method.signature[:susceptance][idx] = system.bus.shunt.susceptance[idx]
        end
    end

    analysis.voltage.angle[idx] = system.bus.voltage.angle[idx]
end

function _updateBus!(analysis::AcPowerFlow{GaussSeidel}, idx::Int64)
    system = analysis.system
    errorTypeConversion(system.bus.layout.pattern, analysis.method.signature[:type])

    if system.bus.layout.type[idx] == 1
        analysis.voltage.magnitude[idx] = system.bus.voltage.magnitude[idx]
    end

    analysis.voltage.angle[idx] = system.bus.voltage.angle[idx]
    analysis.method.voltage[idx] = analysis.voltage.magnitude[idx] * cis(analysis.voltage.angle[idx])
end

function _updateBus!(analysis::DcPowerFlow, ::Int64)
    errorTypeConversion(analysis.system.bus.layout.slack, analysis.method.signature[:slack])
end

function _updateBus!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    bus = system.bus
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    remove!(jump, con.balance.active, idx)
    remove!(jump, con.balance.reactive, idx)
    addBalance(system, jump, var, con, idx)

    remove!(jump, con.voltage.magnitude, idx)
    addMagnitude(system, jump, var.voltage.magnitude, con.voltage.magnitude, idx)

    if analysis.method.signature[:slack] == idx && bus.layout.type[idx] != 3
        unfix!(jump, var.voltage.angle[idx], con.slack.angle, idx)
        analysis.method.signature[:slack] = 0
    end

    if bus.layout.type[idx] == 3
        fix!(var.voltage.angle[idx], bus.voltage.angle[idx], con.slack.angle, idx)
        analysis.method.signature[:slack] = idx
    end
end

function _updateBus!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    remove!(jump, con.balance.active, idx)
    addBalance(system, jump, var, con, AffExpr(), idx)

    analysis.voltage.angle[idx] = system.bus.voltage.angle[idx]

    if analysis.method.signature[:slack] == idx && system.bus.layout.type[idx] != 3
        unfix!(jump, var.voltage.angle[idx], con.slack.angle, idx)
        analysis.method.signature[:slack] = 0
    end

    if system.bus.layout.type[idx] == 3
        fix!(var.voltage.angle[idx], system.bus.voltage.angle[idx], con.slack.angle, idx)
        analysis.method.signature[:slack] = idx
    end
end

"""
    @bus(kwargs...)

The macro generates a template for a bus.

# Keywords
To define the bus template, the `kwargs` input arguments must be provided in accordance with the
keywords specified within the [`addBus!`](@ref addBus!) function, along with their corresponding
values.

# Units
By default, the keyword parameters use per-units and radians as units, with the exception of the
`base` keyword argument, which is in volts. However, users have the option to use other units instead
of per-units and radians, or to specify prefixes for base voltage by using the [`@power`](@ref @power)
and [`@voltage`](@ref @voltage) macros.

# Examples
Adding a bus template using the default unit system:
```jldoctest
@bus(type = 2, active = 0.25, angle = 0.1745)

system = powerSystem()

addBus!(system; label = "Bus 1", reactive = -0.04, base = 132e3)
```

Adding a bus template using a custom unit system:
```jldoctest
@power(MW, MVAr)
@voltage(pu, deg, kV)
@bus(type = 2, active = 25.0, angle = 10.0, base = 132.0)

system = powerSystem()

addBus!(system; label = "Bus 1", reactive = -4.0)
```
"""
macro bus(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(BusTemplate, parameter)
                if parameter ∉ (:base, :type, :area, :lossZone, :label)
                    container::ContainerTemplate = getfield(template.bus, parameter)
                    if parameter in (:active, :conductance)
                        pfxLive = pfx.activePower
                    elseif parameter in (:reactive, :susceptance)
                        pfxLive = pfx.reactivePower
                    elseif parameter in (:magnitude, :minMagnitude, :maxMagnitude)
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
                        setfield!(template.bus, parameter, Float64(eval(kwarg.args[2])) * pfx.baseVoltage)
                    elseif parameter == :type
                        setfield!(template.bus, parameter, Int8(eval(kwarg.args[2])))
                    elseif parameter in (:area, :lossZone)
                        setfield!(template.bus, parameter, Int64(eval(kwarg.args[2])))
                    elseif parameter == :label
                        macroLabel(template.bus, kwarg.args[2], "[?]")
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end