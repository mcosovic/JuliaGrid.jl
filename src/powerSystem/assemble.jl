"""
    addBus!(system::PowerSystem; label, type, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

The function adds a new bus to the `PowerSystem` composite type, updating its `bus` field.

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

# Default Settings
By default, certain keywords are assigned default values: `type = 1`, `magnitude = 1.0`
per-unit, and `base = 138e3` volts. The rest of the keywords are initialized with a value of
zero. However, the user can modify these default settings by utilizing the [`@bus`](@ref @bus)
macro.

# Units
By default, the keyword parameters use per-units (pu) and radians (rad) as units, with the
exception of the `base` keyword argument, which is in volts (V). However, users have the option
to use other units instead of per-units and radians, or to specify prefixes for base voltage by
using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage) macros.

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04, angle = 0.1745, base = 132e3)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = 1, active = 25, reactive = -4, angle = 10, base = 132)
```
"""
function addBus!(system::PowerSystem;
    label::T = missing, type::T = missing,
    active::T = missing, reactive::T = missing,
    conductance::T = missing, susceptance::T = missing,
    magnitude::T = missing, angle::T = missing,
    minMagnitude::T = missing, maxMagnitude::T = missing,
    base::T = missing, area::T = missing, lossZone::T = missing)

    demand = system.bus.demand
    shunt = system.bus.shunt
    voltage = system.bus.voltage
    layout = system.bus.layout
    supply = system.bus.supply
    default = template[:bus]

    prefixPower = system.base.power.prefix
    basePower = system.base.power.value
    prefixVoltage = system.base.voltage.prefix

    system.bus.number += 1
    setLabel(system.bus, label)

    pushData!(layout.type, type, default[:type])
    if !(layout.type[end] in [1, 2, 3])
        throw(ErrorException("The value $type of the type keyword is illegal."))
    end
    if layout.type[end] == 3
        if layout.slack != 0
            throw(ErrorException("The slack bus has already been designated."))
        end
        layout.slack = system.bus.number
    end

    if ismissing(base)
        base = default[:base] * default[:baseVoltage] / prefixVoltage
    else
        base = base * factor[:baseVoltage] / prefixVoltage
    end
    push!(system.base.voltage.value, base)

    voltageScale = si2pu(prefixVoltage, base, factor[:voltageMagnitude])
    activeScale = si2pu(prefixPower, basePower, factor[:activePower])
    reactiveScale = si2pu(prefixPower, basePower, factor[:reactivePower])

    voltageScaleDef = si2pu(prefixVoltage, base, default[:voltageMagnitude])
    activeScaleDef = si2pu(prefixPower, basePower, default[:activePower])
    reactiveScaleDef = si2pu(prefixPower, basePower, default[:reactivePower])

    pushData!(demand.active, active, activeScale, default[:active], activeScaleDef)
    pushData!(demand.reactive, reactive, reactiveScale, default[:reactive], reactiveScaleDef)

    pushData!(shunt.conductance, conductance, activeScale, default[:conductance], activeScaleDef)
    pushData!(shunt.susceptance, susceptance, reactiveScaleDef, default[:susceptance], reactiveScaleDef)

    pushData!(voltage.magnitude, magnitude, voltageScale, default[:magnitude], voltageScaleDef)
    pushData!(voltage.minMagnitude, minMagnitude, voltageScale, default[:minMagnitude], voltageScaleDef)
    pushData!(voltage.maxMagnitude, maxMagnitude, voltageScale, default[:maxMagnitude], voltageScaleDef)

    pushData!(voltage.angle, angle, factor[:voltageAngle], default[:angle], default[:voltageAngle])

    pushData!(layout.area, area, default[:area])
    pushData!(layout.lossZone, lossZone, default[:lossZone])

    push!(supply.generator, Array{Int64}(undef, 0))
    push!(supply.active, 0.0)
    push!(supply.reactive, 0.0)

    if !isempty(system.model.ac.nodalMatrix)
        nilModel!(system, :acModelEmpty)
        @info("The current AC model field has been completely erased.")
    end

    if !isempty(system.model.dc.nodalMatrix)
        nilModel!(system, :dcModelEmpty)
        @info("The current DC model field has been completely erased.")
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
addBus!(system; label = 1, reactive = -0.04, base = 132e3)
```

Creating a bus template using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(pu, deg, kV)
system = powerSystem()

@bus(type = 2, active = 25, angle = 10, base = 132)
addBus!(system; label = 1, reactive = -4)
```
"""
macro bus(kwargs...)
    for key in keys(factor)
        template[:bus][key] = factor[key]
    end

    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]

        if haskey(template[:bus], parameter)
            value = kwarg.args[2]
            template[:bus][parameter] = eval(value)
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

"""
    shuntBus!(system::PowerSystem; label, conductance, susceptance)

This function enables the modification of the `conductance` and `susceptance` parameters of a
shunt element connected to a bus.

# Keywords
The keyword `label` must match an existing bus label. If either `conductance` or `susceptance`
is left out, the corresponding value will remain unchanged.

# Updates
This function modifies the `bus.shunt` field in the `PowerSystem` composite type. Moreover, it
also automatically updates the `ac` field within the `PowerSystem` type, thereby removing the
requirement to completely rebuild the vectors and matrices when adjustments are made to these
parameters.

# Units
The input units are in per-units by default, but they can be modified using the
[`@power`](@ref @power) macro.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
shuntBus!(system; label = 1, conductance = 0.04)
```
"""
function shuntBus!(system::PowerSystem; user...)
    ac = system.model.ac
    shunt = system.bus.shunt

    if !haskey(user, :label) || user[:label]::T <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.bus.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in bus labels."))
    end

    index = system.bus.label[user[:label]]
    if haskey(user, :conductance) || haskey(user, :susceptance)
        if !isempty(ac.nodalMatrix)
            ac.nodalMatrix[index, index] -= shunt.conductance[index] + im * shunt.susceptance[index]
        end

        if haskey(user, :conductance)
            activeScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:activePower])
            shunt.conductance[index] = user[:conductance] * activeScale
        end
        if haskey(user, :susceptance)
            reactiveScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:reactivePower])
            shunt.susceptance[index] = user[:susceptance] * reactiveScale
        end

        if !isempty(ac.nodalMatrix)
            ac.nodalMatrix[index, index] += shunt.conductance[index] + im * shunt.susceptance[index]
        end
    end
end

"""
    addBranch!(system::PowerSystem; label, from, to, status, resistance, reactance,
        conductance, susceptance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle,
        longTerm, shortTerm, emergency, type)

The function adds a new branch to the `PowerSystem` type and updates its `branch` field.
A branch can be added between already defined buses.

# Keywords
The branch is defined with the following keywords:
* `label`: unique label for the branch;
* `from`: from bus label, corresponds to the bus label;
* `to`: to bus label, corresponds to the bus label;
* `status`: operating status of the branch:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `resistance` (pu or Ω): series resistance;
* `reactance` (pu or Ω): series reactance;
* `conductance` (pu or S): total shunt conductance;
* `susceptance` (pu or S): total shunt susceptance;
* `turnsRatio`: transformer off-nominal turns ratio, equal to one for a line;
* `shiftAngle` (rad or deg): transformer phase shift angle, where positive value defines delay;
* `minDiffAngle` (rad or deg): minimum voltage angle difference value between from and to bus;
* `maxDiffAngle` (rad or deg): maximum voltage angle difference value between from and to bus;
* `longTerm` (pu or VA, W): long-term rating (equal to zero for unlimited);
* `shortTerm` (pu or VA, W): short-term rating (equal to zero for unlimited);
* `emergency` (pu or VA, W): emergency rating (equal to zero for unlimited);
* `type`: types of `longTerm`, `shortTerm`, and `emergency` ratings:
  * `type = 1`: apparent power flow (pu or VA);
  * `type = 2`: active power flow (pu or W);
  * `type = 3`: current magnitude (pu or VA at 1 pu voltage).

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `turnsRatio = 1.0`,
and `type = 1`. The  rest of the keywords are initialized with a value of zero. However,
the user can modify these default settings by utilizing the [`@branch`](@ref @branch) macro.

# Units
The default units for the keyword parameters are per-units (pu) and radians (rad). However,
the user can choose to use other units besides per-units and radians by utilizing macros such
as [`@power`](@ref @power), [`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

# Examples
Creating a branch using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1, active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.12, shiftAngle = 0.1745)
```

Creating a branch using a custom unit system:
```jldoctest
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1,  active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.12, shiftAngle = 10)
```
"""
function addBranch!(system::PowerSystem;
    label::T = missing, from::N, to::N, status::T = missing,
    resistance::T = missing, reactance::T = missing, susceptance::T = missing,
    conductance::T = missing, turnsRatio::T = missing, shiftAngle::T = missing,
    minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    parameter = system.branch.parameter
    rating = system.branch.rating
    voltage = system.branch.voltage
    layout = system.branch.layout
    default = template[:branch]

    prefixPower = system.base.power.prefix
    basePower = system.base.power.value

    system.branch.number += 1
    setLabel(system.branch, label)

    if from <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if to <= 0
        throw(ErrorException("The value of the to keyword must be given as a positive integer."))
    end
    if from == to
        throw(ErrorException("Keywords from and to cannot contain the same positive integer."))
    end
    if !haskey(system.bus.label, from)
        throw(ErrorException("The value $from of the from keyword is not unique."))
    end
    if !haskey(system.bus.label, to)
        throw(ErrorException("The value $to of the to keyword is not unique."))
    end
    if ismissing(status)
        status = default[:status]
    end
    if !(status in [0; 1])
        throw(ErrorException("The value $status of the status keyword is illegal, it can be in-service (1) or out-of-service (0)."))
    end

    push!(layout.from, system.bus.label[from])
    push!(layout.to, system.bus.label[to])
    push!(layout.status, status)
    pushData!(parameter.turnsRatio, turnsRatio, default[:turnsRatio])

    apparentScale = si2pu(prefixPower, basePower, factor[:apparentPower])
    apparentScaleDef = si2pu(prefixPower, basePower, default[:apparentPower])

    prefix, base = baseImpedance(system, system.base.voltage.value[layout.from[end]], parameter.turnsRatio[end])
    impedanceScale = si2pu(prefix, base, factor[:impedance])
    impedanceScaleDef = si2pu(prefix, base, default[:impedance])
    admittanceScale = si2pu(1 / prefix, 1 / base, factor[:admittance])
    admittanceScaleDef = si2pu(1 / prefix, 1 / base, default[:admittance])

    pushData!(parameter.resistance, resistance, impedanceScale, default[:resistance], impedanceScaleDef)
    pushData!(parameter.reactance, reactance, impedanceScale, default[:reactance], impedanceScaleDef)
    if parameter.resistance[end] == 0.0 && parameter.reactance[end] == 0.0
        throw(ErrorException("At least one of the keywords resistance and reactance must be defined."))
    end
    pushData!(parameter.conductance, conductance, admittanceScale, default[:conductance], admittanceScaleDef)
    pushData!(parameter.susceptance, susceptance, admittanceScale, default[:susceptance], admittanceScaleDef)
    pushData!(parameter.shiftAngle, shiftAngle, factor[:voltageAngle], default[:shiftAngle], default[:voltageAngle])

    pushData!(voltage.minDiffAngle, minDiffAngle, factor[:voltageAngle], default[:minDiffAngle], default[:voltageAngle])
    pushData!(voltage.maxDiffAngle, maxDiffAngle, factor[:voltageAngle], default[:maxDiffAngle], default[:voltageAngle])

    ratingScale = apparentScale
    ratingScaleDef = apparentScaleDef
    pushData!(rating.type, type, default[:type])
    if rating.type[end] == 2
        ratingScale = si2pu(prefixPower, basePower, factor[:activePower])
        ratingScaleDef = si2pu(prefixPower, basePower, default[:activePower])
    end
    pushData!(rating.shortTerm, shortTerm, ratingScale, default[:shortTerm], ratingScaleDef)
    pushData!(rating.emergency, emergency, ratingScale, default[:emergency], ratingScaleDef)
    pushData!(rating.longTerm, longTerm, ratingScale, default[:longTerm], ratingScaleDef)

    index = system.branch.number
    if !isempty(system.model.dc.nodalMatrix)
        nilModel!(system, :dcModelPushZeros)
        if layout.status[index] == 1
            dcParameterUpdate!(system, index)
            dcNodalShiftUpdate!(system, index)
        end
    end

    if !isempty(system.model.ac.nodalMatrix)
        nilModel!(system, :acModelPushZeros)
        if layout.status[index] == 1
            acParameterUpdate!(system, index)
            acNodalUpdate!(system, index)
        end
    end
end

"""
    @branch(kwargs...)

The macro generates a template for a branch, which can be utilized to define a branch using
the [`addBranch!`](@ref addBranch!) function.

# Keywords
To define the branch template, the `kwargs` input arguments must be provided in accordance
with the keywords specified within the [`addBranch!`](@ref addBranch!) function, along with
their corresponding values.

# Units
The default units for the keyword parameters are per-units and radians. However, the user
can choose to use other units besides per-units and radians by utilizing macros such as
[`@power`](@ref @power), [`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

# Examples
Creating a branch template using the default unit system:
```jldoctest
system = powerSystem()

@branch(reactance = 0.12, shiftAngle = 0.1745)
addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1, active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2)
```

Creating a branch template using a custom unit system:
```jldoctest
@voltage(pu, deg, kV)
system = powerSystem()

@branch(shiftAngle = 10)
addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1,  active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2, reactance = 0.12)
```
"""
macro branch(kwargs...)
    for key in keys(factor)
        template[:branch][key] = factor[key]
    end

    for kwarg in kwargs
        parameter = kwarg.args[1]

        if haskey(template[:branch], parameter)
            value = kwarg.args[2]
            template[:branch][parameter] = eval(value)
        else
            throw(ErrorException("The keyword $parameter is illegal."))
        end
    end
end

"""
    statusBranch!(system::PowerSystem; label, status)

The function alters the operational `status` of a branch within the `PowerSystem` composite type,
toggling between in-service and out-of-service.

# Keywords
The `label` keyword should correspond to the existing branch label, while the `status` keyword
modifies the operational status of the branch.

# Updates
This function modifies the `branch.layout.status` variable in the `PowerSystem` composite type.
Moreover, it also automatically updates the `ac` and `dc` fields within the `PowerSystem` type,
thereby removing the requirement to completely rebuild the vectors and matrices when the
operational status of a branch changes.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1, active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.05, reactance = 0.12)
statusBranch!(system; label = 1, status = 0)
```
"""
function statusBranch!(system::PowerSystem; label::T, status::T)
    layout = system.branch.layout

    if label <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    if !(status in [0; 1])
        throw(ErrorException("The value $status of the status keyword is illegal, it can be in-service (1) or out-of-service (0)."))
    end
    index = system.branch.label[label]

    if layout.status[index] != status
        if !isempty(system.model.dc.nodalMatrix)
            if status == 1
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end
            if status == 0
                nilModel!(system, :dcModelDeprive; index=index)
                dcNodalShiftUpdate!(system, index)
                nilModel!(system, :dcModelZeros; index=index)
            end
        end

        if !isempty(system.model.ac.nodalMatrix)
            if status == 1
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
            if status == 0
                nilModel!(system, :acModelDeprive; index=index)
                acNodalUpdate!(system, index)
                nilModel!(system, :acModelZeros; index=index)
            end
        end
    end
    layout.status[index] = status
end

"""
    parameterBranch!(system::PowerSystem; label, resistance, reactance, conductance,
        susceptance, turnsRatio, shiftAngle)

The function allows for the modification of branch parameters within the `PowerSystem` composite
type.

# Keywords
The function modifies the `resistance`, `reactance`, `conductance`, `susceptance`, `turnsRatio`,
and `shiftAngle` parameters of a branch, which is identified by its `label`. If any of these
parameters are left out, their existing values will remain unchanged.

# Updates
It updates the `branch.parameter` field of the `PowerSystem` composite type. Additionally,
this function automatically updates the `ac` and `dc` fields within the `PowerSystem` type,
thereby removing the requirement to completely rebuild the vectors and matrices when adjustments
are made to these parameters.

# Units
By default, the keyword parameters use per-units (pu) and radians (rad) as units. However,
users have the option to use other units instead of per-units and radians using the
[`@voltage`](@ref @voltage) and [`@parameter`](@ref @parameter) macros.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, type = 1, active = 0.15, reactive = 0.08)
addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.05, reactance = 0.12)
parameterBranch!(system; label = 1, susceptance = 0.062)
```
"""
function parameterBranch!(system::PowerSystem; user...)
    parameter = system.branch.parameter
    layout = system.branch.layout

    if !haskey(user, :label) || user[:label]::T <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if !haskey(system.branch.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in branch labels."))
    end

    index = system.branch.label[user[:label]]
    if haskey(user, :resistance) || haskey(user, :reactance) || haskey(user, :conductance) || haskey(user, :susceptance) || haskey(user, :turnsRatio) || haskey(user, :shiftAngle)
        if layout.status[index] == 1
            if !isempty(system.model.dc.nodalMatrix)
                nilModel!(system, :dcModelDeprive; index=index)
                dcNodalShiftUpdate!(system, index)
            end
            if !isempty(system.model.ac.nodalMatrix)
                nilModel!(system, :acModelDeprive; index=index)
                acNodalUpdate!(system, index)
            end
        end

        if haskey(user, :turnsRatio)
            parameter.turnsRatio[index] = user[:turnsRatio]::T
        end

        prefix, base = baseImpedance(system, system.base.voltage.value[layout.from[index]], system.branch.parameter.turnsRatio[index])
        impedanceScale = si2pu(prefix, base, factor[:impedance])
        admittanceScale = si2pu(1 / prefix, 1 / base, factor[:admittance])
        if haskey(user, :resistance)
            parameter.resistance[index] = user[:resistance]::T * impedanceScale
        end
        if haskey(user, :reactance)
            parameter.reactance[index] = user[:reactance]::T * impedanceScale
        end
        if haskey(user, :conductance)
            parameter.conductance[index] = user[:conductance]::T * admittanceScale
        end
        if haskey(user, :susceptance)
            parameter.susceptance[index] = user[:susceptance]::T * admittanceScale
        end
        if haskey(user, :shiftAngle)
            parameter.shiftAngle[index] = user[:shiftAngle]::T * factor[:voltageAngle]
        end

        if layout.status[index] == 1
            if !isempty(system.model.dc.nodalMatrix)
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end

            if !isempty(system.model.ac.nodalMatrix)
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
        end
    end
end

"""
    addGenerator!(system::PowerSystem; label, bus, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive,
        loadFollowing, reactiveTimescale, reserve10min, reserve30min, area)

The function is used to add a new generator to the `PowerSystem` composite type and update
its `generator` field. The generator can be added to an already defined bus.

# Keywords
The generator is defined with the following keywords:
* `label`: a unique label for the generator;
* `bus`: the label of the bus to which the generator is connected;
* `status`: the operating status of the generator:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `active` (pu or W): output active power;
* `reactive` (pu or VAr): output reactive power;
* `magnitude` (pu or V): voltage magnitude setpoint;
* `minActive` (pu or W): minimum allowed output active power value;
* `maxActive` (pu or W): maximum allowed output active power value;
* `minReactive` (pu or VAr): minimum allowed output reactive power value;
* `maxReactive` (pu or VAr): maximum allowed output reactive power value;
* `lowActive` (pu or W): lower allowed active power output value of PQ capability curve;
* `minLowReactive` (pu or VAr): minimum allowed reactive power output value at lowActive value;
* `maxLowReactive` (pu or VAr): maximum allowed reactive power output value at lowActive value;
* `upActive` (pu or W): upper allowed active power output value of PQ capability curve;
* `minUpReactive` (pu or VAr): minimum allowed reactive power output value at upActive value;
* `maxUpReactive` (pu or VAr): maximum allowed reactive power output value at upActive value;
* `loadFollowing` (pu/min or W/min): ramp rate for load following/AG;
* `reserve10min` (pu or W): ramp rate for 10-minute reserves;
* `reserve30min` (pu or W): ramp rate for 30-minute reserves;
* `reactiveTimescale` (pu/min or VAr/min): ramp rate for reactive power, two seconds timescale;
* `area`: area participation factor.

# Default Settings
By default, certain keywords are assigned default values: `status = 1` and `magnitude = 1.0`
per-unit. The rest of the keywords are initialized with a value of zero. However, the user
can modify these default settings by utilizing the [`@generator`](@ref @generator) macro.

# Units
By default, the input units are associated with per-units (pu) as shown. However, users
have the option to use other units instead of per-units using the [`@power`](@ref @power)
and [`@voltage`](@ref @voltage) macros.

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = 1, type = 2, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1, magnitude = 1.1)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(kV, deg, kV)
system = powerSystem()

addBus!(system; label = 1, type = 2, active = 25, reactive = -4, base = 132)
addGenerator!(system; label = 1, bus = 1, active = 50, reactive = 10, magnitude = 145.2)
```
"""
function addGenerator!(system::PowerSystem;
    label::T = missing, bus::N, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    output = system.generator.output
    capability = system.generator.capability
    ramping = system.generator.ramping
    cost = system.generator.cost
    voltage = system.generator.voltage
    layout = system.generator.layout
    default = template[:generator]

    prefixPower = system.base.power.prefix
    basePower = system.base.power.value
    prefixVoltage = system.base.voltage.prefix

    system.generator.number += 1
    setLabel(system.generator, label)

    if bus <= 0
        throw(ErrorException("The value of the bus keyword must be given as a positive integer."))
    end
    if !haskey(system.bus.label, bus)
        throw(ErrorException("The value $bus of the bus keyword does not exist in bus labels."))
    end

    busIndex = system.bus.label[bus]

    voltageScale = si2pu(system.base.voltage.prefix, system.base.voltage.value[busIndex], factor[:voltageMagnitude])
    activeScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:activePower])
    reactiveScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:reactivePower])

    voltageScaleDef = si2pu(prefixVoltage, system.base.voltage.value[busIndex], default[:voltageMagnitude])
    activeScaleDef = si2pu(prefixPower, basePower, default[:activePower])
    reactiveScaleDef = si2pu(prefixPower, basePower, default[:reactivePower])

    pushData!(output.active, active, activeScale, default[:active], activeScaleDef)
    pushData!(output.reactive, reactive, reactiveScale, default[:reactive], reactiveScaleDef)

    if ismissing(status)
        status = default[:status]
    end
    if status == 1
        push!(system.bus.supply.generator[busIndex], system.generator.number)
        system.bus.supply.active[busIndex] += output.active[end]
        system.bus.supply.reactive[busIndex] += output.reactive[end]
    end

    pushData!(capability.minActive, minActive, activeScale, default[:minActive], activeScaleDef)
    pushData!(capability.maxActive, maxActive, activeScale, default[:maxActive], activeScaleDef)

    pushData!(capability.minReactive, minReactive, reactiveScale, default[:minReactive], reactiveScaleDef)
    pushData!(capability.maxReactive, maxReactive, reactiveScale, default[:maxReactive], reactiveScaleDef)

    pushData!(capability.lowActive, lowActive, activeScale, default[:lowActive], activeScaleDef)
    pushData!(capability.minLowReactive, minLowReactive, reactiveScale, default[:minLowReactive], reactiveScaleDef)
    pushData!(capability.maxLowReactive, maxLowReactive, reactiveScale, default[:maxLowReactive], reactiveScaleDef)

    pushData!(capability.upActive, upActive, activeScale, default[:upActive], activeScaleDef)
    pushData!(capability.minUpReactive, minUpReactive, reactiveScale, default[:minUpReactive], reactiveScaleDef)
    pushData!(capability.maxUpReactive, maxUpReactive, reactiveScale, default[:maxUpReactive], reactiveScaleDef)

    pushData!(ramping.loadFollowing, loadFollowing, activeScale, default[:loadFollowing], activeScaleDef)
    pushData!(ramping.reserve10min, reserve10min, activeScale, default[:reserve10min], activeScaleDef)
    pushData!(ramping.reserve30min, reserve30min, activeScale, default[:reserve30min], activeScaleDef)
    pushData!(ramping.reactiveTimescale, reactiveTimescale, reactiveScale, default[:reactiveTimescale], reactiveScaleDef)

    pushData!(voltage.magnitude, magnitude, voltageScale, default[:magnitude], voltageScaleDef)

    push!(layout.bus, busIndex)
    push!(layout.status, status)
    pushData!(layout.area, area, default[:area])

    push!(cost.active.model, 0)
    push!(cost.active.polynomial, Array{Float64}(undef, 0))
    push!(cost.active.piecewise, Array{Float64}(undef, 0, 0))

    push!(cost.reactive.model, 0)
    push!(cost.reactive.polynomial, Array{Float64}(undef, 0))
    push!(cost.reactive.piecewise, Array{Float64}(undef, 0, 0))
end

"""
    @generator(kwargs...)

The macro generates a template for a generator, which can be utilized to define a generator
using the [`addGenerator!`](@ref addGenerator!) function.

# Keywords
To define the generator template, the `kwargs` input arguments must be provided in accordance
with the keywords specified within the [`addGenerator!`](@ref addGenerator!) function, along
with their corresponding values.

# Units
By default, the input units are associated with per-units (pu) as shown. However, users have
the option to use other units instead of per-units using the [`@power`](@ref @power) and
[`@voltage`](@ref @voltage) macros.

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

@generator(magnitude = 1.1)
addBus!(system; label = 1, type = 2, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(kV, deg, kV)
system = powerSystem()

@generator(magnitude = 145.2)
addBus!(system; label = 1, type = 2, active = 25, reactive = -4, base = 132)
addGenerator!(system; label = 1, bus = 1, active = 50, reactive = 10)
```
"""
macro generator(kwargs...)
    for key in keys(factor)
        template[:generator][key] = factor[key]
    end

    for kwarg in kwargs
        parameter = kwarg.args[1]

        if haskey(template[:generator], parameter)
            value = kwarg.args[2]
            template[:generator][parameter] = eval(value)
        else
            throw(ErrorException("The keyword $parameter is illegal."))
        end
    end
end

"""
    addActiveCost!(system::PowerSystem; label, model, piecewise, polynomial)

The function updates the `generator.cost` field of the `PowerSystem` type by adding costs
for the active power produced by the corresponding generator. It can add a cost to an already
defined generator.

# Keywords
The function accepts four keywords:
* `label`: corresponds to the already defined generator label;
* `model`: cost model:
  * `model = 1`: piecewise linear is being used;
  * `model = 2`: polynomial is being used;
* `piecewise`: cost model defined by input-output points given as `Array{Float64,2}`:
  * first column (pu or W): active power output of the generator;
  * second column (currency/hr): cost for the specified active power output;
* `polynomial`: n-th degree polynomial coefficients given as `Array{Float64,1}`:
  * first element (currency/puⁿhr or currency/Wⁿhr): coefficient of the n-th degree term, ...;
  * penultimate element (currency/puhr or currency/Whr): coefficient of the first degree term;
  * last element (currency/hr): constant coefficient.

# Units
By default, the input units related with active powers are per-units (pu), but they can be
modified using the macro [`@power`](@ref @power).

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
addActiveCost!(system; label = 1, model = 1, polynomial = [1100.0; 500.0; 150.0])
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
system = powerSystem()

addBus!(system; label = 1, active = 25, reactive = -4, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 50, reactive = 10)
addActiveCost!(system; label = 1, model = 1, polynomial = [0.11; 5.0; 150.0])
```
"""
function addActiveCost!(system::PowerSystem; label::T, model::T = 0,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    activeScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:activePower])
    addCost!(system, label, model, polynomial, piecewise, system.generator.cost.active, activeScale)
end

"""
    addReactiveCost!(system::PowerSystem; label, model, piecewise, polynomial)

The function updates the `generator` field of the `PowerSystem` type by adding costs for
the reactive power produced by the corresponding generator. It can add a cost to an already
defined generator.

# Keywords
The function accepts four keywords:
* `label`: corresponds to the already defined generator label;
* `model`: cost model:
  * `model = 1`: piecewise linear is being used;
  * `model = 2`: polynomial is being used;
* `piecewise`: cost model defined by input-output points given as `Array{Float64,2}`:
  * first column (pu or VAr): reactive power output of the generator;
  * second column (currency/hr): cost for the specified reactive power output;
* `polynomial`: n-th degree polynomial coefficients given as `Array{Float64,1}`:
  * first element (currency/puⁿhr or currency/VArⁿhr): coefficient of the n-th degree term, ...;
  * penultimate element (currency/puhr or currency/VArhr): coefficient of the first degree term;
  * last element (currency/hr): constant coefficient.

# Units
By default, the input units related with reactive powers are per-units (pu), but they can
be modified using the macro [`@power`](@ref @power).

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
addReactiveCost!(system; label = 1, model = 2, piecewise = [0.1085 12; 0.1477 16])
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
system = powerSystem()

addBus!(system; label = 1, active = 25, reactive = -4, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 50, reactive = 10)
addReactiveCost!(system; label = 1, model = 2, piecewise = [10.85 12; 14.77 16])
```
"""
function addReactiveCost!(system::PowerSystem; label::T, model::T = 0,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    reactiveScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:reactivePower])
    addCost!(system, label, model, polynomial, piecewise, system.generator.cost.reactive, reactiveScale)
end

function addCost!(system::PowerSystem, label, model, polynomial, piecewise, cost, scale)

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end

    if !(model in [1; 2])
        if !isempty(piecewise)
            model = 1
        end
        if !isempty(polynomial)
            model = 2
        end
    end

    index = system.generator.label[label]
    cost.model[index] = model

    if !isempty(polynomial)
        numberCoefficient = length(polynomial)
        cost.polynomial[index] = fill(0.0, numberCoefficient)
        @inbounds for i = 1:numberCoefficient
            cost.polynomial[index][i] = polynomial[i] / (scale^(numberCoefficient - i))
        end
    end

    if !isempty(piecewise)
        cost.piecewise[index] = [scale .* piecewise[:, 1] piecewise[:, 2]]
    end
end

"""
    statusGenerator!(system::PowerSystem; label, status)

The function changes the operating `status` of a generator by switching it from in-service
to out-of-service, or vice versa.

# Keywords
It has two parameters, `label` and `status`, where the `label` corresponds to the generator
label that has already been defined.

# Updates
The main purpose of the function is to update the `bus.supply` field within the `PowerSystem`
type. Additionally, the function alters the `generator.layout.status` variable.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
statusGenerator!(system; label = 1, status = 0)
```
"""
function statusGenerator!(system::PowerSystem; label::Int64, status::Int64 = 0)
    layout = system.generator.layout
    output = system.generator.output

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end

    index = system.generator.label[label]
    indexBus = layout.bus[index]

    if layout.status[index] != status
        if status == 0
            for (k, i) in enumerate(system.bus.supply.generator[indexBus])
                if i == index
                    deleteat!(system.bus.supply.generator[indexBus], k)
                    break
                end
            end
            system.bus.supply.active[indexBus] -= output.active[index]
            system.bus.supply.reactive[indexBus] -= output.reactive[index]
        end
        if status == 1
            push!(system.bus.supply.generator[indexBus], index)
            system.bus.supply.active[indexBus] += output.active[index]
            system.bus.supply.reactive[indexBus] += output.reactive[index]
        end
    end
    layout.status[index] = status
end

"""
    outputGenerator!(system::PowerSystem; label, active, reactive)

The function modifies the `active` and `reactive` output powers of a generator.

# Keywords
It has three parameters, `label`, `active`, and `reactive`, where the `label` corresponds
to the generator label that has already been defined. The `active` and `reactive` parameters
can be left, in which case their values will remain unchanged.

# Updates
The main purpose of the function is to update the `bus.supply` field within the `PowerSystem`
type. Additionally, the function alters the `generator.output` field.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04, base = 132e3)
addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
outputGenerator!(system; label = 1, active = 0.85)
```
"""
function outputGenerator!(system::PowerSystem; user...)
    layout = system.generator.layout
    output = system.generator.output

    if !haskey(user, :label) || user[:label]::Int64 <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.generator.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in generator labels."))
    end

    activeScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:activePower])
    reactiveScale = si2pu(system.base.power.prefix, system.base.power.value, factor[:reactivePower])

    index = system.generator.label[user[:label]]
    indexBus = layout.bus[index]

    if haskey(user, :active) || haskey(user, :reactive)
        if layout.status[index] == 1
            system.bus.supply.active[indexBus] -= output.active[index]
            system.bus.supply.reactive[indexBus] -= output.reactive[index]
        end

        if haskey(user, :active)
            output.active[index] = user[:active]::T * activeScale
        end
        if haskey(user, :reactive)
            output.reactive[index] = user[:reactive]::T * reactiveScale
        end

        if layout.status[index] == 1
            system.bus.supply.active[indexBus] += output.active[index]
            system.bus.supply.reactive[indexBus] += output.reactive[index]
        end
    end
end

"""
    dcModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and parameters
associated with DC analyses.

# Updates
The function modifies the `model.dc` field within the `PowerSystem` composite type, populating
the following variables:
- `nodalMatrix`: the nodal matrix;
- `admittance`: the branch admittances;
- `shiftActivePower`: the active powers related to phase-shifting transformers.

Once these variables are established, they will be automatically adjusted upon using the following
functions:
* [`addBranch!`](@ref addBranch!),
* [`statusBranch!`](@ref statusBranch!),
* [`parameterBranch!`](@ref parameterBranch!).

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)
```
"""
function dcModel!(system::PowerSystem)
    dc = system.model.dc
    layout = system.branch.layout
    parameter = system.branch.parameter

    dc.shiftActivePower = fill(0.0, system.bus.number)
    dc.admittance = fill(0.0, system.branch.number)
    nodalDiagonals = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            dc.admittance[i] = 1 / (parameter.turnsRatio[i] * parameter.reactance[i])

            from = layout.from[i]
            to = layout.to[i]

            shift = parameter.shiftAngle[i] * dc.admittance[i]
            dc.shiftActivePower[from] -= shift
            dc.shiftActivePower[to] += shift

            nodalDiagonals[from] += dc.admittance[i]
            nodalDiagonals[to] += dc.admittance[i]
        end
    end

    busIndex = collect(1:system.bus.number)
    dc.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; -dc.admittance; -dc.admittance], system.bus.number, system.bus.number)
end

######### Update DC Nodal Matrix ##########
function dcNodalShiftUpdate!(system, index::Int64)
    dc = system.model.dc
    layout = system.branch.layout
    parameter = system.branch.parameter

    from = layout.from[index]
    to = layout.to[index]
    admittance = dc.admittance[index]

    shift = parameter.shiftAngle[index] * admittance
    dc.shiftActivePower[from] -= shift
    dc.shiftActivePower[to] += shift

    dc.nodalMatrix[from, from] += admittance
    dc.nodalMatrix[to, to] += admittance
    dc.nodalMatrix[from, to] -= admittance
    dc.nodalMatrix[to, from] -= admittance
end

######### Update DC Parameters ##########
@inline function dcParameterUpdate!(system::PowerSystem, index::Int64)
    dc = system.model.dc
    parameter = system.branch.parameter

    dc.admittance[index] = 1 / (parameter.turnsRatio[index] * parameter.reactance[index])
end

"""
    acModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and parameters
associated with AC analyses.

# Updates
The function modifies the `model.ac` field within the `PowerSystem` composite type, populating
the following variables:
- `nodalMatrix`: the nodal matrix;
- `nodalMatrixTranspose`: the transpose of the nodal matrix;
- `nodalFromFrom`: the Y-parameters of the two-port branches;
- `nodalFromTo`: the Y-parameters of the two-port branches;
- `nodalToTo`: the Y-parameters of the two-port branches;
- `nodalToFrom`: the Y-parameters of the two-port branches;
- `admittance`: the branch admittances.

Once these variables are established, they will be automatically adjusted upon using the following
functions:
* [`shuntBus!`](@ref shuntBus!),
* [`addBranch!`](@ref addBranch!),
* [`statusBranch!`](@ref statusBranch!),
* [`parameterBranch!`](@ref parameterBranch!).


# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)
```
"""
function acModel!(system::PowerSystem)
    ac = system.model.ac
    layout = system.branch.layout
    parameter = system.branch.parameter

    ac.admittance = zeros(ComplexF64, system.branch.number)
    ac.nodalToTo = zeros(ComplexF64, system.branch.number)
    ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
    ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
    ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
    nodalDiagonals = complex.(system.bus.shunt.conductance, system.bus.shunt.susceptance)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            ac.admittance[i] = 1 / (parameter.resistance[i] + im * parameter.reactance[i])
            turnsRatioInv = 1 / parameter.turnsRatio[i]
            transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[i])

            ac.nodalToTo[i] = ac.admittance[i] + 0.5 * complex(parameter.conductance[i], parameter.susceptance[i])
            ac.nodalFromFrom[i] = turnsRatioInv^2 * ac.nodalToTo[i]
            ac.nodalFromTo[i] = -conj(transformerRatio) * ac.admittance[i]
            ac.nodalToFrom[i] = -transformerRatio * ac.admittance[i]

            nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
            nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
        end
    end

    busIndex = collect(1:system.bus.number)
    ac.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom], system.bus.number, system.bus.number)

    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

######### Update AC Nodal Matrix ##########
@inline function acNodalUpdate!(system::PowerSystem, index::Int64)
    ac = system.model.ac
    layout = system.branch.layout

    from = layout.from[index]
    to = layout.to[index]

    ac.nodalMatrix[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrix[to, to] += ac.nodalToTo[index]
    ac.nodalMatrixTranspose[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrixTranspose[to, to] += ac.nodalToTo[index]

    ac.nodalMatrix[from, to] += ac.nodalFromTo[index]
    ac.nodalMatrix[to, from] += ac.nodalToFrom[index]
    ac.nodalMatrixTranspose[to, from] += ac.nodalFromTo[index]
    ac.nodalMatrixTranspose[from, to] += ac.nodalToFrom[index]
end

######### Update AC Parameters ##########
@inline function acParameterUpdate!(system::PowerSystem, index::Int64)
    ac = system.model.ac
    parameter = system.branch.parameter

    ac.admittance[index] = 1 / (parameter.resistance[index] + im * parameter.reactance[index])
    turnsRatioInv = 1 / parameter.turnsRatio[index]
    transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[index])

    ac.nodalToTo[index] = ac.admittance[index] + 0.5 * complex(parameter.conductance[index], parameter.susceptance[index])
    ac.nodalFromFrom[index] = turnsRatioInv^2 * ac.nodalToTo[index]
    ac.nodalFromTo[index] = -conj(transformerRatio) * ac.admittance[index]
    ac.nodalToFrom[index] = -transformerRatio * ac.admittance[index]
end

######### Expelling Elements from the AC or DC Model ##########
function nilModel!(system::PowerSystem, flag::Symbol; index::Int64 = 0)
    dc = system.model.dc
    ac = system.model.ac

    if flag == :dcModelEmpty
        dc.nodalMatrix = spzeros(0, 0)
        dc.admittance =  Array{Float64,1}(undef, 0)
        dc.shiftActivePower = Array{Float64,1}(undef, 0)
    end

    if flag == :acModelEmpty
        ac.nodalMatrix = spzeros(0, 0)
        ac.nodalMatrixTranspose = spzeros(0, 0)
        ac.nodalToTo =  Array{ComplexF64,1}(undef, 0)
        ac.nodalFromFrom = Array{ComplexF64,1}(undef, 0)
        ac.nodalFromTo = Array{ComplexF64,1}(undef, 0)
        ac.nodalToFrom = Array{ComplexF64,1}(undef, 0)
        ac.admittance = Array{ComplexF64,1}(undef, 0)
    end

    if flag == :dcModelZeros
        dc.admittance[index] = 0.0
    end

    if flag == :acModelZeros
        ac.nodalFromFrom[index] = 0.0 + im * 0.0
        ac.nodalFromTo[index] = 0.0 + im * 0.0
        ac.nodalToTo[index] = 0.0 + im * 0.0
        ac.nodalToFrom[index] = 0.0 + im * 0.0
        ac.admittance[index] = 0.0 + im * 0.0
    end

    if flag == :dcModelPushZeros
        push!(dc.admittance, 0.0)
    end

    if flag == :acModelPushZeros
        push!(ac.admittance, 0.0 + im * 0.0)
        push!(ac.nodalToTo, 0.0 + im * 0.0)
        push!(ac.nodalFromFrom, 0.0 + im * 0.0)
        push!(ac.nodalFromTo, 0.0 + im * 0.0)
        push!(ac.nodalToFrom, 0.0 + im * 0.0)
    end

    if flag == :dcModelDeprive
        dc.admittance[index] = -dc.admittance[index]
    end

    if flag == :acModelDeprive
        ac.nodalFromFrom[index] = -ac.nodalFromFrom[index]
        ac.nodalFromTo[index] = -ac.nodalFromTo[index]
        ac.nodalToTo[index] = -ac.nodalToTo[index]
        ac.nodalToFrom[index] =-ac.nodalToFrom[index]
        ac.admittance[index] = -ac.admittance[index]
    end
end

######### Push Data ##########
function pushData!(data, keyword, scale, default, scaleDefault)
    if !ismissing(keyword)
        push!(data, keyword * scale)
    else
        push!(data, default * scaleDefault)
    end
end

function pushData!(data, keyword, default)
    if ismissing(keyword)
        keyword = default
    end
    push!(data, keyword)
end


######### Set Label ##########
function setLabel(component, label::T)
    if ismissing(label)
        if component.number > 1
            label = maximum(keys(component.label)) + 1
        else
            label = 1
        end
    else
        if label <= 0
            throw(ErrorException("The value of the label keyword must be given as a positive integer."))
        end
        if haskey(component.label, label)
            throw(ErrorException("The value $label of the label keyword is not unique."))
        end
    end
    setindex!(component.label, component.number, label)

    if !component.layout.renumbering && component.number != label
        component.layout.renumbering = true
    end
end