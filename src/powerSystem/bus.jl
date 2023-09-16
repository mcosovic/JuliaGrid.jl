"""
    addBus!(system::PowerSystem; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

The function adds a new bus to the `PowerSystem` composite type.

# Keywords
The bus is defined with the following keywords:
* `label`: unique label for the bus;
* `type`: the bus type:
  * `type = 1`: demand bus (PQ);
  * `type = 2`: generator bus (PV);
  * `type = 3`: slack bus (Vθ);
* `active` (pu or W): the active power demand at the bus;
* `reactive` (pu or VAr): the reactive power demand at the bus;
* `conductance` (pu or W): the active power demanded of the shunt element;
* `susceptance` (pu or VAr): the reactive power injected of the shunt element;
* `magnitude` (pu or V): the initial value of the voltage magnitude;
* `angle` (rad or deg): the initial value of the voltage angle;
* `minMagnitude` (pu or V): the minimum voltage magnitude value;
* `maxMagnitude` (pu or V): the maximum voltage magnitude value;
* `base` (V): the base value of the voltage magnitude;
* `area`: the area number;
* `lossZone`: the loss zone.

# Updates
The function updates the `bus` field of the `PowerSystem` composite type.

# Default Settings
By default, certain keywords are assigned default values: `type = 1`, `magnitude = 1.0`,
`minMagnitude = 0.9`, and `maxMagnitude = 1.1`. The rest of the keywords are initialized with
a value of zero. However, the user can modify these default settings by utilizing the
[`@bus`](@ref @bus) macro.

# Units
By default, the keyword parameters use per-units (pu) and radians (rad) as units, with the
exception of the `base` keyword argument, which is in volts (V). However, users have the
option to use other units instead of per-units and radians, or to specify prefixes for base
voltage by using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage) macros.

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, angle = 0.175, base = 132e3)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", active = 25.0, angle = 10.026, base = 132.0)
```
"""
function addBus!(system::PowerSystem;
    label::L = missing, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    bus = system.bus
    default = template.bus

    bus.number += 1
    setLabel(bus, system.uuid, label, "bus")

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

    baseVoltage = tosi(base, default.base, prefix.baseVoltage)
    push!(system.base.voltage.value, baseVoltage / system.base.voltage.prefix)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltageInv = 1 / baseVoltage

    push!(bus.demand.active, topu(active, default.active, basePowerInv, prefix.activePower))
    push!(bus.demand.reactive, topu(reactive, default.reactive, basePowerInv, prefix.reactivePower))

    push!(bus.shunt.conductance, topu(conductance, default.conductance, basePowerInv, prefix.activePower))
    push!(bus.shunt.susceptance, topu(susceptance, default.susceptance, basePowerInv, prefix.reactivePower))

    push!(bus.voltage.magnitude, topu(magnitude, default.magnitude, baseVoltageInv, prefix.voltageMagnitude))
    push!(bus.voltage.minMagnitude, topu(minMagnitude, default.minMagnitude, baseVoltageInv, prefix.voltageMagnitude))
    push!(bus.voltage.maxMagnitude, topu(maxMagnitude, default.maxMagnitude, baseVoltageInv, prefix.voltageMagnitude))

    push!(bus.voltage.angle, tosi(angle, default.angle, prefix.voltageAngle))

    push!(bus.layout.area, unitless(area, default.area))
    push!(bus.layout.lossZone, unitless(lossZone, default.lossZone))

    push!(bus.supply.generator, Array{Int64}(undef, 0))
    push!(bus.supply.active, 0.0)
    push!(bus.supply.reactive, 0.0)

    if !isempty(system.model.ac.nodalMatrix)
        nilModel!(system, :acModelEmpty)
        @info("The current AC model field has been completely erased.")
    end

    if !isempty(system.model.dc.nodalMatrix)
        nilModel!(system, :dcModelEmpty)
        @info("The current DC model field has been completely erased.")
    end
end

function addBus!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    throw(ErrorException("The DC power flow model cannot be reused when adding a new bus."))
end

function addBus!(system::PowerSystem, analysis::ACPowerFlow; kwargs...)
    throw(ErrorException("The AC power flow model cannot be reused when adding a new bus."))
end

######### Query About Bus ##########
function addBus!(system::PowerSystem, analysis::DCOptimalPowerFlow; kwargs...)
    throw(ErrorException("The DC optimal power flow model cannot be reused when adding a new bus."))
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
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    bus = system.bus
    ac = system.model.ac

    index = bus.label[getLabel(bus, label, "bus")]

    if !ismissing(type)
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
    if !ismissing(active)
        bus.demand.active[index] = topu(active, basePowerInv, prefix.activePower)
    end
    if !ismissing(reactive)
        bus.demand.reactive[index] = topu(reactive, basePowerInv, prefix.reactivePower)
    end

    if !ismissing(conductance) || !ismissing(susceptance)
        if !isempty(ac.nodalMatrix)
            admittance = complex(bus.shunt.conductance[index], bus.shunt.susceptance[index])
            ac.nodalMatrix[index, index] -= admittance
            ac.nodalMatrixTranspose[index, index] -= admittance
        end

        if !ismissing(conductance)
            bus.shunt.conductance[index] = topu(conductance, basePowerInv, prefix.activePower)
        end
        if !ismissing(susceptance)
            bus.shunt.susceptance[index] = topu(susceptance, basePowerInv, prefix.reactivePower)
        end

        if !isempty(ac.nodalMatrix)
            admittance = complex(bus.shunt.conductance[index], bus.shunt.susceptance[index])
            ac.nodalMatrix[index, index] += admittance
            ac.nodalMatrixTranspose[index, index] += admittance
        end
    end

    if !ismissing(base)
        system.base.voltage.value[index] = base * prefix.baseVoltage / system.base.voltage.prefix
    end

    baseVoltageInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
    if !ismissing(magnitude)
        bus.voltage.magnitude[index] = topu(magnitude, baseVoltageInv, prefix.voltageMagnitude)
    end
    if !ismissing(angle)
        bus.voltage.angle[index] = angle * prefix.voltageAngle
    end
    if !ismissing(minMagnitude)
        bus.voltage.minMagnitude[index] = topu(minMagnitude, baseVoltageInv, prefix.voltageMagnitude)
    end
    if !ismissing(maxMagnitude)
        bus.voltage.maxMagnitude[index] = topu(maxMagnitude, baseVoltageInv, prefix.voltageMagnitude)
    end

    if !ismissing(area)
        bus.layout.area[index] = area
    end
    if !ismissing(lossZone)
        bus.layout.lossZone[index] = lossZone
    end
end

function updateBus!(system::PowerSystem, analysis::DCPowerFlow;
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if !ismissing(type) && bus.layout.slack == index && type != 3
        throw(ErrorException("The DC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)
end

function updateBus!(system::PowerSystem, analysis::NewtonRaphson;
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if !ismissing(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if !ismissing(magnitude) && bus.layout.type[index] == 1
        analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
    end
    if !ismissing(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end
end

function updateBus!(system::PowerSystem, analysis::FastNewtonRaphson;
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if !ismissing(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end
    if (!ismissing(conductance) && bus.shunt.conductance[index] != conductance) || (!ismissing(susceptance) && bus.shunt.susceptance[index] != susceptance)
        throw(ErrorException("The fast Newton-Raphson model cannot be reused when the shunt element is altered."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if !ismissing(magnitude) && bus.layout.type[index] == 1
        analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
    end
    if !ismissing(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end
end

function updateBus!(system::PowerSystem, analysis::GaussSeidel;
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]

    if !ismissing(type) && type != bus.layout.type[index]
        throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
    end

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if !ismissing(magnitude) || !ismissing(angle)
        if !ismissing(magnitude) && bus.layout.type[index] == 1
            analysis.voltage.magnitude[index] = bus.voltage.magnitude[index]
        end
        if !ismissing(angle)
            analysis.voltage.angle[index] = bus.voltage.angle[index]
        end
        analysis.method.voltage[index] = analysis.voltage.magnitude[index] * exp(im * analysis.voltage.angle[index])
    end
end

function updateBus!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    index = bus.label[getLabel(bus, label, "bus")]
    typeOld = bus.layout.type[index]

    updateBus!(system; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

    if !(ismissing(conductance)) || !(ismissing(active))
        updateBalance(system, analysis, index; rhs = true)
    end

    if !ismissing(angle)
        analysis.voltage.angle[index] = bus.voltage.angle[index]
    end

    if typeOld == 3 && bus.layout.type[index] != 3
        unfix!(analysis.jump, analysis.jump[:angle], analysis.constraint.slack.angle, index)
    end

    if bus.layout.type[index] == 3
        fix!(analysis.jump[:angle], bus.voltage.angle[index], analysis.constraint.slack.angle, index)
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
Creating a bus template using the default unit system:
```jldoctest
system = powerSystem()

@bus(type = 2, active = 0.25, angle = 0.1745)
addBus!(system; label = "Bus 1", reactive = -0.04, base = 132e3)
```

Creating a bus template using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

@bus(type = 2, active = 25.0, angle = 10.0, base = 132.0)
addBus!(system; "Bus 1", reactive = -4.0)
```
"""
macro bus(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(BusTemplate, parameter)
            if !(parameter in [:base; :angle; :type; :area; :lossZone])
                container::ContainerTemplate = getfield(template.bus, parameter)
                if parameter in [:active; :conductance]
                    prefixLive = prefix.activePower
                elseif parameter in [:reactive; :susceptance]
                    prefixLive = prefix.reactivePower
                elseif parameter in [:magnitude; :minMagnitude; :maxMagnitude]
                    prefixLive = prefix.voltageMagnitude
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                if parameter == :base
                    setfield!(template.bus, parameter, value * prefix.baseVoltage)
                elseif parameter == :angle
                    setfield!(template.bus, parameter, value * prefix.voltageAngle)
                elseif parameter == :type
                    setfield!(template.bus, parameter, Int8(value))
                elseif parameter in [:area; :lossZone]
                    setfield!(template.bus, parameter, Int64(value))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end