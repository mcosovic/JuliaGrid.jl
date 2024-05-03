"""
    addBus!(system::PowerSystem; label, type, active, reactive, conductance, susceptance,
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
* `base` (V): Voltage base value.
* `area`: Area number.
* `lossZone`: Loss zone.

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
function addBus!(system::PowerSystem;
    label::L = missing, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    default = template.bus

    bus.number += 1
    setLabel(bus, label, default.label, "bus")

    push!(bus.layout.type, unitless(type, default.type))
    if !(bus.layout.type[end] in [1, 2, 3])
        throw(ErrorException("The value $type of the type keyword is illegal."))
    end
    if bus.layout.type[end] == 3
        if bus.layout.slack != 0
            throw(ErrorException("The slack bus has already been designated."))
        end
        bus.layout.slack = bus.number
    end

    if isset(base)
        baseVoltage = base * prefix.baseVoltage
    else
        baseVoltage = default.base
    end

    push!(system.base.voltage.value, baseVoltage / system.base.voltage.prefix)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltageInv = 1 / baseVoltage

    push!(bus.demand.active, topu(active, default.active, prefix.activePower, basePowerInv))
    push!(bus.demand.reactive, topu(reactive, default.reactive, prefix.reactivePower, basePowerInv))

    push!(bus.shunt.conductance, topu(conductance, default.conductance, prefix.activePower, basePowerInv))
    push!(bus.shunt.susceptance, topu(susceptance, default.susceptance, prefix.reactivePower, basePowerInv))

    push!(bus.voltage.magnitude, topu(magnitude, default.magnitude, prefix.voltageMagnitude, baseVoltageInv))
    push!(bus.voltage.minMagnitude, topu(minMagnitude, default.minMagnitude, prefix.voltageMagnitude, baseVoltageInv))
    push!(bus.voltage.maxMagnitude, topu(maxMagnitude, default.maxMagnitude, prefix.voltageMagnitude, baseVoltageInv))

    push!(bus.voltage.angle, topu(angle, default.angle, prefix.voltageAngle, 1.0))

    push!(bus.layout.area, unitless(area, default.area))
    push!(bus.layout.lossZone, unitless(lossZone, default.lossZone))

    push!(bus.supply.generator, Array{Int64}(undef, 0))
    push!(bus.supply.active, 0.0)
    push!(bus.supply.reactive, 0.0)

    if !isempty(system.model.ac.nodalMatrix)
        acModelEmpty!(system.model.ac)
        @info("The current AC model has been completely erased.")
    end

    if !isempty(system.model.dc.nodalMatrix)
        dcModelEmpty!(system.model.dc)
        @info("The current DC model has been completely erased.")
    end
end

function addBus!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    throw(ErrorException("The DC power flow model cannot be reused when adding a new bus."))
end

function addBus!(system::PowerSystem, analysis::ACPowerFlow; kwargs...)
    throw(ErrorException("The AC power flow model cannot be reused when adding a new bus."))
end

function addBus!(system::PowerSystem, analysis::DCOptimalPowerFlow; kwargs...)
    throw(ErrorException("The DC optimal power flow model cannot be reused when adding a new bus."))
end

function addBus!(system::PowerSystem, analysis::DCStateEstimation; kwargs...)
    throw(ErrorException("The DC state estimation model cannot be reused when adding a new bus."))
end

"""
    updateBus!(system::PowerSystem, analysis::Analysis; kwargs...)

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
function updateBus!(system::PowerSystem;
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    ac = system.model.ac

    index = bus.label[getLabel(bus, label, "bus")]

    if isset(type)
        if type in [1; 2]
            if bus.layout.slack == index
                bus.layout.slack = 0
            end
            bus.layout.type[index] = type
        end
        if type == 3
            if bus.layout.slack != 0 && bus.layout.slack != index
                throw(ErrorException("To set bus with label $label as the slack bus, reassign the current slack bus to either a generator or demand bus."))
            end
            bus.layout.type[index] = 3
            bus.layout.slack = index
        end
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if isset(active)
        bus.demand.active[index] = topu(active, prefix.activePower, basePowerInv)
    end
    if isset(reactive)
        bus.demand.reactive[index] = topu(reactive, prefix.reactivePower, basePowerInv)
    end

    if isset(conductance) || isset(susceptance)
        if !isempty(ac.nodalMatrix)
            ac.model += 1

            admittance = complex(bus.shunt.conductance[index], bus.shunt.susceptance[index])
            ac.nodalMatrix[index, index] -= admittance
            ac.nodalMatrixTranspose[index, index] -= admittance
        end

        if isset(conductance)
            bus.shunt.conductance[index] = topu(conductance, prefix.activePower, basePowerInv)
        end
        if isset(susceptance)
            bus.shunt.susceptance[index] = topu(susceptance, prefix.reactivePower, basePowerInv)
        end

        if !isempty(ac.nodalMatrix)
            admittance = complex(bus.shunt.conductance[index], bus.shunt.susceptance[index])
            ac.nodalMatrix[index, index] += admittance
            ac.nodalMatrixTranspose[index, index] += admittance
        end
    end

    if isset(base)
        system.base.voltage.value[index] = base * prefix.baseVoltage / system.base.voltage.prefix
    end

    baseVoltageInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
    if isset(magnitude)
        bus.voltage.magnitude[index] = topu(magnitude, prefix.voltageMagnitude, baseVoltageInv)
    end
    if isset(angle)
        bus.voltage.angle[index] = topu(angle, prefix.voltageAngle, 1.0)
    end
    if isset(minMagnitude)
        bus.voltage.minMagnitude[index] = topu(minMagnitude, prefix.voltageMagnitude, baseVoltageInv)
    end
    if isset(maxMagnitude)
        bus.voltage.maxMagnitude[index] = topu(maxMagnitude, prefix.voltageMagnitude, baseVoltageInv)
    end

    if isset(area)
        bus.layout.area[index] = area
    end
    if isset(lossZone)
        bus.layout.lossZone[index] = lossZone
    end
end

function updateBus!(system::PowerSystem, analysis::DCPowerFlow;
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if isset(type) && bus.layout.slack == index && type != 3
        throw(ErrorException("The DC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)
end

function updateBus!(system::PowerSystem, analysis::ACPowerFlow{NewtonRaphson};
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if isset(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if isset(magnitude) && bus.layout.type[index] == 1
        analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
    end
    if isset(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end
end

function updateBus!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson};
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    method = analysis.method
    index = bus.label[getLabel(bus, label, "bus")]

    if isset(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end

    if isset(susceptance) && bus.layout.type[index] == 1
        oldSusceptance = bus.shunt.susceptance[index]
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if isset(magnitude) && bus.layout.type[index] == 1
        analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
    end
    if isset(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end

    if isset(susceptance) && bus.layout.type[index] == 1 && oldSusceptance != bus.shunt.susceptance[index]
        method.reactive.jacobian[method.pq[index], method.pq[index]] -= oldSusceptance
        method.reactive.jacobian[method.pq[index], method.pq[index]] += bus.shunt.susceptance[index]
    end
end

function updateBus!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel};
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if isset(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if isset(magnitude) || isset(angle)
        if isset(magnitude) && bus.layout.type[index] == 1
            analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
        end
        if isset(angle)
            analysis.voltage.angle[index] = bus.voltage.angle[index]
        end
        analysis.method.voltage[index] = analysis.voltage.magnitude[index] * exp(im * analysis.voltage.angle[index])
    end
end

function updateBus!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]
    typeOld = bus.layout.type[index]

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if isset(conductance) || isset(active)
        updateBalance(system, analysis, index; rhs = true)
    end

    if isset(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end

    if typeOld == 3 && bus.layout.type[index] != 3
        unfix!(analysis.method.jump, analysis.method.variable.angle[index], analysis.method.constraint.slack.angle, index)
    end

    if bus.layout.type[index] == 3
        fix!(analysis.method.variable.angle[index], bus.voltage.angle[index], analysis.method.constraint.slack.angle, index)
    end
end

function updateBus!(system::PowerSystem, analysis::ACOptimalPowerFlow;
    label::L, type::A = missing,
    active::A = missing, reactive::A = missing,
    conductance::A = missing, susceptance::A = missing,
    magnitude::A = missing, angle::A = missing,
    minMagnitude::A = missing, maxMagnitude::A = missing,
    base::A = missing, area::A = missing, lossZone::A = missing)

    bus = system.bus
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = bus.label[getLabel(bus, label, "bus")]
    typeOld = bus.layout.type[index]

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
    magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    activeUpdate = isset(conductance) || isset(susceptance) || isset(active)
    reactiveupdate = isset(conductance) || isset(susceptance) || isset(reactive)
    if activeUpdate || reactiveupdate
        updateBalance(system, analysis, index; active = activeUpdate, reactive = reactiveupdate)
    end

    if isset(magnitude)
        analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
    end
    if isset(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end

    if isset(minMagnitude) || isset(maxMagnitude)
        remove!(jump, constraint.voltage.magnitude, index)
        addMagnitude(system, jump, variable.magnitude, constraint.voltage.magnitude, index)
    end

    if typeOld == 3 && bus.layout.type[index] != 3
        unfix!(jump, variable.angle[index], constraint.slack.angle, index)
    end

    if bus.layout.type[index] == 3
        fix!(variable.angle[index], bus.voltage.angle[index], constraint.slack.angle, index)
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
                    prefixLive = prefix.activePower
                elseif parameter in [:reactive; :susceptance]
                    prefixLive = prefix.reactivePower
                elseif parameter in [:magnitude; :minMagnitude; :maxMagnitude]
                    prefixLive = prefix.voltageMagnitude
                elseif parameter == :angle
                    prefixLive = prefix.voltageAngle
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, true)
                end
            else
                if parameter == :base
                    setfield!(template.bus, parameter, Float64(eval(kwarg.args[2])) * prefix.baseVoltage)
                elseif parameter == :type
                    setfield!(template.bus, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter in [:area; :lossZone]
                    setfield!(template.bus, parameter, Int64(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?")
                        setfield!(template.bus, parameter, label)
                    else
                        throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                    end
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end