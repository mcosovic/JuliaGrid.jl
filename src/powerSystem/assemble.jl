const T = Union{Float64,Int64}

"""
The function adds a new bus to the `PowerSystem` type, updating its bus field. It 
automatically sets the bus as a demand bus, but it can be changed to a generator bus using 
the [`addGenerator!()`](@ref addGenerator!) function or to a slack bus using the 
[`slackBus!()`](@ref slackBus!) function.

    addBus!(system::PowerSystem; label, active, reactive, conductance, susceptance, 
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)
    
The bus is defined with the following parameters:
* `label`: a unique label for the bus
* `active` (pu or W): the active power demand at the bus 
* `reactive` (pu or VAr): the reactive power demand at the bus
* `conductance` (pu or W): the active power demanded of the shunt element
* `susceptance` (pu or VAr): the reactive power injected of the shunt element
* `magnitude` (pu or V): the initial value of the voltage magnitude
* `angle` (rad or deg): the initial value of the voltage angle
* `minMagnitude` (pu or V): the minimum voltage magnitude value
* `maxMagnitude` (pu or V): the maximum voltage magnitude value
* `base` (V): the base value of the voltage magnitude
* `area`: the area number
* `lossZone`: the loss zone

# Units
The input units are in per-unit (pu) and radian (rad) by default as shown, except for the 
keyword `base` which is given by default in volt (V). The unit settings, such as the 
selection between the per-unit system or the SI system with the appropriate prefixes, 
can be modified using macros [`@base`](@ref @base), [`@power`](@ref @power), and 
[`@voltage`](@ref @voltage).
 
# Examples
```jldoctest
system = powerSystem()
addBus!(system; label = 1, active = 0.25, reactive = -0.04, angle = 0.1745, base = 132e3)
```

```jldoctest
@base(MVA, kV)
@power(MW, MVAr, MVA)
@voltage(pu, deg)

system = powerSystem()
addBus!(system; label = 1, active = 25, reactive = -4, angle = 10, base = 132)
```
"""
function addBus!(system::PowerSystem; label::T, active::T = 0.0, reactive::T = 0.0,
    conductance::T = 0.0, susceptance::T = 0.0, magnitude::T = 0.0, angle::T = 0.0,
    minMagnitude::T = 0.0, maxMagnitude::T = 0.0, base::T = 0.0, area::T = 1,
    lossZone::T = 1)

    demand = system.bus.demand
    shunt = system.bus.shunt
    voltage = system.bus.voltage
    layout = system.bus.layout
    supply = system.bus.supply

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword is not unique."))
    end

    push!(system.base.voltage, base)

    system.bus.number += 1
    setindex!(system.bus.label, system.bus.number, label)
    push!(layout.type, 1)

    if system.bus.number != label
        layout.renumbering = true
    end

    basePowerInv = 1 / (unit.prefix["base power"] * system.base.power)
    baseVoltageInv = 1 / (unit.prefix["base voltage"] * base)

    activeScale = topu(unit, basePowerInv, "active power")
    reactiveScale = topu(unit, basePowerInv, "reactive power")
    voltageScale = topu(unit, baseVoltageInv, "voltage magnitude")

    push!(demand.active, active * activeScale)
    push!(demand.reactive, reactive * reactiveScale)

    push!(shunt.conductance, conductance * activeScale)
    push!(shunt.susceptance, susceptance * reactiveScale)

    push!(voltage.magnitude, magnitude * voltageScale)
    push!(voltage.angle, angle * torad(unit, "voltage angle"))
    push!(voltage.maxMagnitude, maxMagnitude * voltageScale)
    push!(voltage.minMagnitude, minMagnitude * voltageScale)

    push!(layout.area, area)
    push!(layout.lossZone, lossZone)

    push!(supply.inService, 0)
    push!(supply.active, 0.0)
    push!(supply.reactive, 0.0)

    if !isempty(system.dcModel.admittance)
        nilModel!(system, :dcModelEmpty)
    end

    if !isempty(system.acModel.admittance)
        nilModel!(system, :acModelEmpty)
    end
end

"""
The function is used to set a slack bus, and it can also be used to dynamically change the 
slack bus. 

    slackBus!(system::PowerSystem; label)

Every time the function is executed, the previous slack bus becomes a demand or generator 
bus, depending on whether the bus has a generator. The bus label should be specified using 
the `label` keyword argument and should match an already defined bus label.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
slackBus!(system; label = 1)
```
"""
function slackBus!(system::PowerSystem; label::T)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    layout = system.bus.layout
    supply = system.bus.supply

    if layout.slack != 0
        if !isempty(supply.inService) && supply.inService[layout.slack] != 0
            layout.type[layout.slack] = 2
        else
            layout.type[layout.slack] = 1
        end
    end
    layout.slack = system.bus.label[label]
    layout.type[layout.slack] = 3
end

"""
This function enables the modification of the `conductance` and `susceptance` parameters 
of a shunt element connected to a bus. 

    shuntBus!(system::PowerSystem; label, conductance, susceptance)

The `label` keyword must match an existing bus label. If either `conductance` or 
`susceptance` is left out, the corresponding value will remain unchanged. Additionally, 
this function automatically updates the `acModel` field, eliminating the need to rebuild 
the model from scratch when making changes to these parameters.

# Units
The input units are in per-units by default, but they can be modified using the 
[`@power`](@ref @power) macro.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
shuntBus!(system; label = 1, conductance = 0.04)
```
"""
function shuntBus!(system::PowerSystem; user...)
    ac = system.acModel
    shunt = system.bus.shunt

    if !haskey(user, :label) || user[:label]::T <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.bus.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in bus labels."))
    end

    index = system.bus.label[user[:label]]
    if haskey(user, :conductance) || haskey(user, :susceptance)
        ac.nodalMatrix
        if !isempty(system.acModel.admittance)
            ac.nodalMatrix[index, index] -= shunt.conductance[index] + im * shunt.susceptance[index]
        end

        basePowerInv = 1 / (unit.prefix["base power"] * system.base.power)
        if haskey(user, :conductance)
            shunt.conductance[index] = user[:conductance]::T * topu(unit, basePowerInv, "active power")
        end
        if haskey(user, :susceptance)
            shunt.susceptance[index] = user[:susceptance]::T * topu(unit, basePowerInv, "reactive power")
        end


        if !isempty(system.acModel.admittance)
            ac.nodalMatrix[index, index] += shunt.conductance[index] + im * shunt.susceptance[index]
        end
    end
end

"""
The function adds a new branch to the `PowerSystem` type and updates its branch field. 
A branch can be added between already defined buses.
    
    addBranch!(system::PowerSystem; label, from, to, status, resistance, reactance, 
        susceptance, turnsRatio, shiftAngle, longTerm, shortTerm, emergency, 
        minDiffAngle, maxDiffAngle)
    
The branch is defined with the following parameters:
* `label`: unique branch label
* `from`: from bus label, corresponds to the bus label
* `to`: to bus label, corresponds to the bus label
* `status`: operating status of the branch, in-service = 1, out-of-service = 0
* `resistance` (pu or Ω): branch resistance
* `reactance` (pu or Ω): branch reactance
* `susceptance` (pu or S): total line charging susceptance
* `turnsRatio`: transformer off-nominal turns ratio, equal to zero for a line
* `shiftAngle` (rad or deg): transformer phase shift angle, where positive value defines delay
* `longTerm` (pu or VA): short-term rating (equal to zero for unlimited)
* `shortTerm` (pu or VA): long-term rating (equal to zero for unlimited)
* `emergency` (pu or VA): emergency rating (equal to zero for unlimited)
* `minDiffAngle` (rad or deg): minimum voltage angle difference value between from and to bus
* `maxDiffAngle` (rad or deg): maximum voltage angle difference value between from and to bus

# Units
The input units are in per-units and radians by default, but they can be modified using 
the following macros [`@power`](@ref @power), [`@voltage`](@ref @voltage), and 
[`@parameter`](@ref @parameter).
    
# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, active = 0.15, reactive = 0.08)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.05, reactance = 0.12)
```
"""
function addBranch!(system::PowerSystem; label::T, from::T, to::T, status::T = 1,
    resistance::T = 0.0, reactance::T = 0.0, susceptance::T = 0.0, turnsRatio::T = 0.0,
    shiftAngle::T = 0.0, longTerm::T = 0.0, shortTerm::T = 0.0, emergency::T = 0.0,
    minDiffAngle::T = 0.0, maxDiffAngle::T = 0.0)

    parameter = system.branch.parameter
    rating = system.branch.rating
    voltage = system.branch.voltage
    layout = system.branch.layout

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if from <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if to <= 0
        throw(ErrorException("The value of the to keyword must be given as a positive integer."))
    end
    if resistance == 0.0 && reactance == 0.0
        throw(ErrorException("At least one of the keywords resistance and reactance must be defined."))
    end
    if from == to
        throw(ErrorException("Keywords from and to cannot contain the same positive integer."))
    end
    if haskey(system.branch.label, label)
        throw(ErrorException("The branch label $label is not unique."))
    end
    if !haskey(system.bus.label, from)
        throw(ErrorException("The value $from of the from keyword is not unique."))
    end
    if !haskey(system.bus.label, to)
        throw(ErrorException("The value $to of the to keyword is not unique."))
    end
    if !(status in [0; 1])
        throw(ErrorException("The value $status of the status keyword is illegal, it can be in-service (1) or out-of-service (0)."))
    end

    system.branch.number += 1

    setindex!(system.branch.label, system.branch.number, label)
    if system.branch.number != label
        layout.renumbering = true
    end

    push!(layout.from, system.bus.label[from])
    push!(layout.to, system.bus.label[to])
    push!(layout.status, status)

    basePowerInv = 1 / (unit.prefix["base power"] * system.base.power)
    apparentScale = topu(unit, basePowerInv, "apparent power")

    if turnsRatio != 0
        turnsRatioInv = 1 / turnsRatio
    else
        turnsRatioInv = 1.0
    end
    baseImpedanceInv = turnsRatioInv^2 * (unit.prefix["base power"] * system.base.power) / ((unit.prefix["base voltage"] * system.base.voltage[layout.from[end]])^2)
    impedanceScale = topu(unit, baseImpedanceInv, "impedance")
    admittanceScale = topu(unit, 1 / baseImpedanceInv, "admittance")

    push!(parameter.resistance, resistance * impedanceScale)
    push!(parameter.reactance, reactance * impedanceScale)
    push!(parameter.susceptance, susceptance * admittanceScale)
    push!(parameter.turnsRatio, turnsRatio)
    push!(parameter.shiftAngle, shiftAngle * torad(unit, "voltage angle"))

    push!(rating.longTerm, longTerm * apparentScale)
    push!(rating.shortTerm, shortTerm * apparentScale)
    push!(rating.emergency, emergency * apparentScale)

    push!(voltage.minDiffAngle, minDiffAngle * torad(unit, "voltage angle"))
    push!(voltage.maxDiffAngle, maxDiffAngle * torad(unit, "voltage angle"))

    index = system.branch.number
    if !isempty(system.dcModel.admittance)
        nilModel!(system, :dcModelPushZeros)
        if layout.status[index] == 1
            dcParameterUpdate!(system, index)
            dcNodalShiftUpdate!(system, index)
        end
    end

    if !isempty(system.acModel.admittance)
        nilModel!(system, :acModelPushZeros)
        if layout.status[index] == 1
            acParameterUpdate!(system, index)
            acNodalUpdate!(system, index)
        end
    end
end

"""
The function enables the switching of the operational `status` of a branch, identified by 
its `label`, within the `PowerSystem` system between in-service and out-of-service. 

    statusBranch!(system::PowerSystem; label, status)

This function updates the `acModel` and `dcModel` fields automatically when the operating 
status of a branch is changed, thus eliminating the need to rebuild the model from scratch.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, active = 0.15, reactive = 0.08)

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
        if !isempty(system.dcModel.admittance)
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

        if !isempty(system.acModel.admittance)
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
This function enables the alteration of the `resistance`, `reactance`, `susceptance`, 
`turnsRatio` and `shiftAngle` parameters of a branch, identified by its `label`, within 
the `PowerSystem`.

    parameterBranch!(system::PowerSystem; label, resistance, reactance, susceptance, 
        turnsRatio, shiftAngle)

If any of these parameters are omitted, their current values will be retained. Additionally, 
this function updates the `acModel` and `dcModel` fields automatically, removing the need 
to rebuild the model from scratch.
        
# Units
The input units are in per-units by default, but they can be modified using the following 
macros [`@parameter`](@ref @parameter) and [`@voltage`](@ref @voltage).

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, active = 0.15, reactive = 0.08)

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
    if haskey(user, :resistance) || haskey(user, :reactance) || haskey(user, :susceptance) || haskey(user, :turnsRatio) || haskey(user, :shiftAngle)
        if layout.status[index] == 1
            if !isempty(system.dcModel.admittance)
                nilModel!(system, :dcModelDeprive; index=index)
                dcNodalShiftUpdate!(system, index)
            end
            if !isempty(system.acModel.admittance)
                nilModel!(system, :acModelDeprive; index=index)
                acNodalUpdate!(system, index)
            end
        end

        if haskey(user, :turnsRatio)
            parameter.turnsRatio[index] = user[:turnsRatio]::T
        end

        if parameter.turnsRatio[index] != 0
            turnsRatioInv = 1 / parameter.turnsRatio[index]
        else
            turnsRatioInv = 1.0
        end
        baseImpedanceInv = turnsRatioInv^2 * (unit.prefix["base power"] * system.base.power) / ((unit.prefix["base voltage"] * system.base.voltage[layout.from[end]])^2)
        impedanceScale = topu(unit, baseImpedanceInv, "impedance")
        
        if haskey(user, :resistance)
            parameter.resistance[index] = user[:resistance]::T * impedanceScale
        end
        if haskey(user, :reactance)
            parameter.reactance[index] = user[:reactance]::T * impedanceScale
        end
        if haskey(user, :susceptance)
            parameter.susceptance[index] = user[:susceptance]::T * topu(unit, 1 / baseImpedanceInv, "admittance")
        end
        if haskey(user, :shiftAngle)
            parameter.shiftAngle[index] = user[:shiftAngle]::T * torad(unit, "voltage angle")
        end

        if layout.status[index] == 1
            if !isempty(system.dcModel.admittance)
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end

            if !isempty(system.acModel.admittance)
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
        end
    end
end

"""
The function is used to add a new generator to the `PowerSystem` type and update its 
`generator` field. The generator can be added to an already defined bus. 

    addGenerator!(system::PowerSystem; label, bus, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive, 
        maxLowReactive, upActive, minUpReactive, maxUpReactive,
        loadFollowing, reactiveTimescale, reserve10min, reserve30min, area)

The generator is defined with the following parameters:
* `label`: a unique label for the generator 
* `bus`: the label of the bus to which the generator is connected
* `status`: the operating status of the generator, in-service = 1, out-of-service = 0
* `active` (pu or W): output active power
* `reactive` (pu or VAr): output reactive power
* `magnitude` (pu or V): voltage magnitude setpoint
* `minActive` (pu or W): minimum allowed output active power value
* `maxActive` (pu or W): maximum allowed output active power value
* `minReactive` (pu or VAr): minimum allowed output reactive power value
* `maxReactive` (pu or VAr): maximum allowed output reactive power value
* `lowActive` (pu or W): lower allowed active power output value of PQ capability curve
* `minLowReactive` (pu or VAr): minimum allowed reactive power output value at lowActive value
* `maxLowReactive` (pu or VAr): maximum allowed reactive power output value at lowActive value
* `upActive` (pu or W): upper allowed active power output value of PQ capability curve
* `minUpReactive` (pu or VAr): minimum allowed reactive power output value at upActive value
* `maxUpReactive` (pu or VAr): maximum allowed reactive power output value at upActive value
* `loadFollowing` (pu or W per min): ramp rate for load following/AG
* `reserve10min` (pu or W): ramp rate for 10-minute reserves
* `reserve30min` (pu or W): ramp rate for 30-minute reserves
* `reactiveTimescale`  (pu or VAr per min): ramp rate for reactive power, two seconds timescale
* `area`: area participation factor

# Units
The input units are realted to per-units by default, but they can be modified using macros 
[`@power`](@ref @power) and [`@voltage`](@ref @voltage).

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)

addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
```
"""
function addGenerator!(system::PowerSystem; label::T, bus::T, area::T = 0.0, status::T = 1, 
    active::T = 0.0, reactive::T = 0.0, magnitude::T = 0.0, minActive::T = 0.0, 
    maxActive::T = 0.0, minReactive::T = 0.0, maxReactive::T = 0.0, lowActive::T = 0.0, 
    minLowReactive::T = 0.0, maxLowReactive::T = 0.0, upActive::T = 0.0, 
    minUpReactive::T = 0.0, maxUpReactive::T = 0.0, loadFollowing::T = 0.0,
    reserve10min::T = 0.0, reserve30min::T = 0.0, reactiveTimescale::T = 0.0)

    output = system.generator.output
    capability = system.generator.capability
    ramping = system.generator.ramping
    cost = system.generator.cost
    voltage = system.generator.voltage
    layout = system.generator.layout

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if bus <= 0
        throw(ErrorException("The value of the bus keyword must be given as a positive integer."))
    end
    if haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword is not unique."))
    end
    if !haskey(system.bus.label, bus)
        throw(ErrorException("The value $bus of the bus keyword does not exist in bus labels."))
    end

    busIndex = system.bus.label[bus]

    basePowerInv = 1 / (unit.prefix["base power"] * system.base.power)
    activeScale = topu(unit, basePowerInv, "active power")
    reactiveScale = topu(unit, basePowerInv, "reactive power")

    baseVoltageInv = 1 / (unit.prefix["base voltage"] * system.base.voltage[busIndex])
    voltageScale = topu(unit, baseVoltageInv, "voltage magnitude")

    system.generator.number += 1
    setindex!(system.generator.label, system.generator.number, label)

    busIndex = system.bus.label[bus]
    if status == 1
        if system.bus.layout.type[busIndex] != 3
            system.bus.layout.type[busIndex] = 2
        end
        system.bus.supply.inService[busIndex] += 1
        system.bus.supply.active[busIndex] += active * activeScale
        system.bus.supply.reactive[busIndex] += reactive * reactiveScale
    end

    push!(output.active, active * activeScale)
    push!(output.reactive, reactive * reactiveScale)

    push!(capability.minActive, minActive * activeScale)
    push!(capability.maxActive, maxActive * activeScale)
    push!(capability.minReactive, minReactive * reactiveScale)
    push!(capability.maxReactive, maxReactive * reactiveScale)
    push!(capability.lowActive, lowActive * activeScale)
    push!(capability.minLowReactive, minLowReactive * reactiveScale)
    push!(capability.maxLowReactive, maxLowReactive * reactiveScale)
    push!(capability.upActive, upActive * activeScale)
    push!(capability.minUpReactive, minUpReactive * reactiveScale)
    push!(capability.maxUpReactive, maxUpReactive * reactiveScale)

    push!(ramping.loadFollowing, loadFollowing * activeScale)
    push!(ramping.reserve10min, reserve10min * activeScale)
    push!(ramping.reserve30min, reserve30min * activeScale)
    push!(ramping.reactiveTimescale, reactiveTimescale * reactiveScale)

    push!(voltage.magnitude, magnitude * voltageScale)

    push!(layout.bus, busIndex)
    push!(layout.area, area)
    push!(layout.status, status)

    push!(cost.active.model, 0)
    push!(cost.active.polynomial, Array{Float64}(undef, 0))
    push!(cost.active.piecewise, Array{Float64}(undef, 0, 0))

    push!(cost.reactive.model, 0)
    push!(cost.reactive.polynomial, Array{Float64}(undef, 0))
    push!(cost.reactive.piecewise, Array{Float64}(undef, 0, 0))
end

"""
The function updates the `generator` field of the `PowerSystem` type by adding costs for 
the active power produced by the corresponding generators. It can add a cost to an already 
defined generator.

    addActiveCost!(system::PowerSystem; label, model, piecewise, polynomial)

The function takes in four keywords as arguments:
* `label`: corresponds to the already defined generator label
* `model`: cost model, piecewise linear = 1, polynomial = 2
* `piecewise`: cost model defined by input-output points given as `Array{Float64,2}`:
  * matrix first column holds the values of active power in per-unit (pu) or watt (W),
  * matrix second column holds the cost, expressed in currency per hour, that is determined for the given active power. 
* `polynomial`: second-degree polynomial coefficients given as `Array{Float64,1}`:
  * the first element is a square term, given in units of ``(currency/pu)^2`` or ``(currency/W)^2``,  
  * the second element is a linear term, given in units of ``(currency/pu)`` or ``(currency/W)``,
  * the third element is a constant term, given in units of currency.

# Units
By default, the input units related with active powers are per-units, but they can be 
modified using the macro [`@power`](@ref @power).

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)

addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
addActiveCost!(system; label = 1, model = 1, polynomial = [5601.0; 85.1; 43.2])
```
"""
function addActiveCost!(system::PowerSystem; label::T, model::T = 0,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    addCost!(system, label, model, polynomial, piecewise, system.generator.cost.active)
end

function addReactiveCost!(system::PowerSystem; label::T, model::T = 0,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    addCost!(system, label, model, polynomial, piecewise, system.generator.cost.reactive)
end

function addCost!(system::PowerSystem, label, model, polynomial, piecewise, cost)

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

    basePowerInv = 1 / (unit.prefix["base power"] * system.base.power)
    activeScale = topu(unit, basePowerInv, "active power")

    index = system.generator.label[label]
    cost.model[index] = model

    cost.polynomial[index] = [polynomial[1] / activeScale^2, polynomial[2] / activeScale, polynomial[3]]
    cost.piecewise[index] = [activeScale .* piecewise[:, 1] piecewise[:, 2]]
end
# """
# The function allows changing the operating `status` of the generator, from in-service
# to out-of-service, and vice versa.

#     statusGenerator!(system::PowerSystem; label, status)

# The keywords `label` should correspond to the already defined generator label. The function
# also updates the variable `system.bus.layout.type`. Namely, if the bus is not slack, and if
# all generators are out-of-service, the bus will be declared PQ type. Otherwise, if at least
# one generator is in-service, the bus will be declared PV type.

# # Example
# ```jldoctest
# system = powerSystem()

# addBus!(system; label = 1, active = 0.25, reactive = -0.04)

# addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
# statusGenerator!(system; label = 1, status = 0)
# ```
# """
# function statusGenerator!(system::PowerSystem; label::Int64, status::Int64 = 0)
#     layout = system.generator.layout
#     output = system.generator.output

#     if label <= 0
#         throw(ErrorException("The value of the label keyword must be given as a positive integer."))
#     end
#     if !haskey(system.generator.label, label)
#         throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
#     end

#     index = system.generator.label[label]
#     indexBus = layout.bus[index]

#     if layout.status[index] != status
#         if status == 0
#             system.bus.supply.inService[indexBus] -= 1
#             system.bus.supply.active[indexBus] -= output.active[index]
#             system.bus.supply.reactive[indexBus] -= output.reactive[index]
#             if system.bus.supply.inService[indexBus] == 0 && system.bus.layout.type[indexBus] != 3
#                 system.bus.layout.type[indexBus] = 1
#             end
#         end
#         if status == 1
#             system.bus.supply.inService[indexBus] += 1
#             system.bus.supply.active[indexBus] += output.active[index]
#             system.bus.supply.reactive[indexBus] += output.reactive[index]
#             if system.bus.layout.type[indexBus] != 3
#                 system.bus.layout.type[indexBus] = 2
#             end
#         end
#     end
#     layout.status[index] = status
# end

# """
# The function allows changing `active` and `reactive` output power of the generator.

#     outputGenerator!(system::PowerSystem; label, active, reactive)

# The keywords `label` should correspond to the already defined generator label. Keywords `active`
# or `reactive` can be omitted, then the value of the omitted parameter remains unchanged.

# # Example
# ```jldoctest
# system = powerSystem()

# addBus!(system; label = 1, active = 0.25, reactive = -0.04)

# addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
# outputGenerator!(system; label = 1, active = 0.85)
# ```
# """
# function outputGenerator!(system::PowerSystem; user...)
#     layout = system.generator.layout
#     output = system.generator.output

#     if !haskey(user, :label) || user[:label]::Int64 <= 0
#         throw(ErrorException("The value of the label keyword must be given as a positive integer."))
#     end
#     if !haskey(system.generator.label, user[:label])
#         throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in generator labels."))
#     end

#     index = system.generator.label[user[:label]]
#     indexBus = layout.bus[index]

#     if haskey(user, :active) || haskey(user, :reactive)
#         if layout.status[index] == 1
#             system.bus.supply.active[indexBus] -= output.active[index]
#             system.bus.supply.reactive[indexBus] -= output.reactive[index]
#         end

#         if haskey(user, :active)
#             output.active[index] = user[:active]::Float64
#         end
#         if haskey(user, :reactive)
#             output.reactive[index] = user[:reactive]::Float64
#         end

#         if layout.status[index] == 1
#             system.bus.supply.active[indexBus] += output.active[index]
#             system.bus.supply.reactive[indexBus] += output.reactive[index]
#         end
#     end
# end

"""
The function generates vectors and matrices based on the power system topology and 
parameters associated with DC analysis. We advise the reader to read the section 
[in-depth DC Model](@ref inDepthDCModel), which explains all the data involved in the 
field `dcModel`.

    dcModel!(system::PowerSystem)

The function updates the field `dcModel`. Once formed, the field will be automatically
updated when using functions [`addBranch!()`](@ref addBranch!), 
[`statusBranch!()`](@ref statusBranch!), [`parameterBranch!()`](@ref parameterBranch!).

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)
```
"""
function dcModel!(system::PowerSystem)
    dc = system.dcModel
    layout = system.branch.layout
    parameter = system.branch.parameter

    dc.shiftActivePower = fill(0.0, system.bus.number)
    dc.admittance = fill(0.0, system.branch.number)
    nodalDiagonals = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            if parameter.turnsRatio[i] == 0
                dc.admittance[i] = 1 / parameter.reactance[i]
            else
                dc.admittance[i] = 1 / (parameter.turnsRatio[i] * parameter.reactance[i])
            end

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

# ######### Update DC Nodal Matrix ##########
# function dcNodalShiftUpdate!(system, index::Int64)
#     dc = system.dcModel
#     layout = system.branch.layout
#     parameter = system.branch.parameter

#     from = layout.from[index]
#     to = layout.to[index]
#     admittance = dc.admittance[index]

#     shift = parameter.shiftAngle[index] * admittance
#     dc.shiftActivePower[from] -= shift
#     dc.shiftActivePower[to] += shift

#     dc.nodalMatrix[from, from] += admittance
#     dc.nodalMatrix[to, to] += admittance
#     dc.nodalMatrix[from, to] -= admittance
#     dc.nodalMatrix[to, from] -= admittance
# end

# ######### Update DC Parameters ##########
# @inline function dcParameterUpdate!(system::PowerSystem, index::Int64)
#     dc = system.dcModel
#     parameter = system.branch.parameter

#     if parameter.turnsRatio[index] == 0
#         dc.admittance[index] = 1 / parameter.reactance[index]
#     else
#         dc.admittance[index] = 1 / (parameter.turnsRatio[index] * parameter.reactance[index])
#     end
# end

"""
The function generates vectors and matrices based on the power system topology and 
parameters associated with AC analysis. We advise the reader to read the section 
[in-depth AC Model](@ref inDepthACModel), which explains all the data involved in the 
field `acModel`.

    acModel!(system::PowerSystem)

The function updates the field `acModel`. Once formed, the field will be automatically
updated when using functions [`addBranch!()`](@ref addBranch!), [`shuntBus!()`](@ref shuntBus!),
[`statusBranch!()`](@ref statusBranch!), [`parameterBranch!()`](@ref parameterBranch!).

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)
```
"""
function acModel!(system::PowerSystem)
    ac = system.acModel
    layout = system.branch.layout
    parameter = system.branch.parameter

    ac.transformerRatio  = zeros(ComplexF64, system.branch.number)
    ac.admittance = zeros(ComplexF64, system.branch.number)
    ac.nodalToTo = zeros(ComplexF64, system.branch.number)
    ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
    ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
    ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
    nodalDiagonals = zeros(ComplexF64, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            ac.admittance[i] = 1 / (parameter.resistance[i] + im * parameter.reactance[i])

            if parameter.turnsRatio[i] == 0
                ac.transformerRatio[i] = exp(im * parameter.shiftAngle[i])
            else
                ac.transformerRatio[i] = parameter.turnsRatio[i] * exp(im * parameter.shiftAngle[i])
            end

            transformerRatioConj = conj(ac.transformerRatio[i])
            ac.nodalToTo[i] = ac.admittance[i] + im * 0.5 * parameter.susceptance[i]
            ac.nodalFromFrom[i] = ac.nodalToTo[i] / (transformerRatioConj * ac.transformerRatio[i])
            ac.nodalFromTo[i] = -ac.admittance[i] / transformerRatioConj
            ac.nodalToFrom[i] = -ac.admittance[i] / ac.transformerRatio[i]

            nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
            nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
        end
    end

    for i = 1:system.bus.number
        nodalDiagonals[i] += system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i]
    end

    busIndex = collect(1:system.bus.number)
    ac.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom], system.bus.number, system.bus.number)

    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

# ######### Update AC Nodal Matrix ##########
# @inline function acNodalUpdate!(system::PowerSystem, index::Int64)
#     ac = system.acModel
#     layout = system.branch.layout

#     from = layout.from[index]
#     to = layout.to[index]

#     ac.nodalMatrix[from, from] += ac.nodalFromFrom[index]
#     ac.nodalMatrix[to, to] += ac.nodalToTo[index]
#     ac.nodalMatrixTranspose[from, from] += ac.nodalFromFrom[index]
#     ac.nodalMatrixTranspose[to, to] += ac.nodalToTo[index]

#     ac.nodalMatrix[from, to] += ac.nodalFromTo[index]
#     ac.nodalMatrix[to, from] += ac.nodalToFrom[index]
#     ac.nodalMatrixTranspose[to, from] += ac.nodalFromTo[index]
#     ac.nodalMatrixTranspose[from, to] += ac.nodalToFrom[index]
# end

# ######### Update AC Parameters ##########
# @inline function acParameterUpdate!(system::PowerSystem, index::Int64)
#     ac = system.acModel
#     parameter = system.branch.parameter

#     ac.admittance[index] = 1 / (parameter.resistance[index] + im * parameter.reactance[index])

#     if parameter.turnsRatio[index] == 0
#         ac.transformerRatio[index] = exp(im * parameter.shiftAngle[index])
#     else
#         ac.transformerRatio[index] = parameter.turnsRatio[index] * exp(im * parameter.shiftAngle[index])
#     end

#     transformerRatioConj = conj(ac.transformerRatio[index])
#     ac.nodalToTo[index] = ac.admittance[index] + im * 0.5 * parameter.susceptance[index]
#     ac.nodalFromFrom[index] = ac.nodalToTo[index] / (transformerRatioConj * ac.transformerRatio[index])
#     ac.nodalFromTo[index] = -ac.admittance[index] / transformerRatioConj
#     ac.nodalToFrom[index] = -ac.admittance[index] / ac.transformerRatio[index]
# end

# ######### Expelling Elements from the AC or DC Model ##########
# function nilModel!(system::PowerSystem, flag::Symbol; index::Int64 = 0)
#     dc = system.dcModel
#     ac = system.acModel

#     if flag == :dcModelEmpty
#         dc.nodalMatrix = spzeros(1, 1)
#         dc.admittance =  Array{Float64,1}(undef, 0)
#         dc.shiftActivePower = Array{Float64,1}(undef, 0)
#     end

#     if flag == :acModelEmpty
#         ac.nodalMatrix = spzeros(1, 1)
#         ac.nodalMatrixTranspose = spzeros(1, 1)
#         ac.nodalToTo =  Array{ComplexF64,1}(undef, 0)
#         ac.nodalFromFrom = Array{ComplexF64,1}(undef, 0)
#         ac.nodalFromTo = Array{ComplexF64,1}(undef, 0)
#         ac.nodalToFrom = Array{ComplexF64,1}(undef, 0)
#         ac.admittance = Array{ComplexF64,1}(undef, 0)
#         ac.transformerRatio = Array{ComplexF64,1}(undef, 0)
#     end

#     if flag == :dcModelZeros
#         dc.admittance[index] = 0.0
#     end

#     if flag == :acModelZeros
#         ac.nodalFromFrom[index] = 0.0 + im * 0.0
#         ac.nodalFromTo[index] = 0.0 + im * 0.0
#         ac.nodalToTo[index] = 0.0 + im * 0.0
#         ac.nodalToFrom[index] = 0.0 + im * 0.0
#         ac.admittance[index] = 0.0 + im * 0.0
#         ac.transformerRatio[index] = 0.0 + im * 0.0
#     end

#     if flag == :dcModelPushZeros
#         push!(dc.admittance, 0.0)
#     end

#     if flag == :acModelPushZeros
#         push!(ac.admittance, 0.0 + im * 0.0)
#         push!(ac.nodalToTo, 0.0 + im * 0.0)
#         push!(ac.nodalFromFrom, 0.0 + im * 0.0)
#         push!(ac.nodalFromTo, 0.0 + im * 0.0)
#         push!(ac.nodalToFrom, 0.0 + im * 0.0)
#         push!(ac.transformerRatio, 0.0 + im * 0.0)
#     end

#     if flag == :dcModelDeprive
#         dc.admittance[index] = -dc.admittance[index]
#     end

#     if flag == :acModelDeprive
#         ac.nodalFromFrom[index] = -ac.nodalFromFrom[index]
#         ac.nodalFromTo[index] = -ac.nodalFromTo[index]
#         ac.nodalToTo[index] = -ac.nodalToTo[index]
#         ac.nodalToFrom[index] =-ac.nodalToFrom[index]
#         ac.admittance[index] = -ac.admittance[index]
#         ac.transformerRatio[index] = -ac.transformerRatio[index]
#     end
# end