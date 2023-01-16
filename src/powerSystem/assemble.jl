"""
The function adds a new bus and updates the `bus` field.

    addBus!(system::PowerSystem; label, active, reactive, conductance, susceptance,
        magnitude, angle, minMagnitude, maxMagnitude, base, area, lossZone)

Descriptions, types and units of keywords are given below:
* `label::Int64` - unique bus label
* `active::Float64` - active power demand
* `reactive::Float64` - reactive power demand
* `conductance::Float64` - active power demanded of the shunt element
* `susceptance` - reactive power injected of the shunt element
* `magnitude::Float64` -::Float64 initial value of the voltage magnitude
* `angle::Float64` - initial value of the voltage angle
* `minMagnitude::Float64` -  minimum voltage magnitude value
* `maxMagnitude::Float64` - maximum voltage magnitude value
* `base::Float64` - base value of the voltage magnitude
* `area::Int64` - area number
* `lossZone::Int64` - loss zone

The function automatically defines the bus as the demand bus. The defined bus can become a
generator bus by creating a generator using the function [`addGenerator!()`](@ref addGenerator!).
That is, the slack bus using the function [`slackBus()`](@ref slackBus!).

# Units


# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
```
"""
function addBus!(system::PowerSystem; label::Int64,
    active::Float64 = 0.0, reactive::Float64 = 0.0,
    conductance::Float64 = 0.0, susceptance::Float64 = 0.0,
    magnitude::Float64 = 0.0, angle::Float64 = 0.0,
    minMagnitude::Float64 = 0.0, maxMagnitude::Float64 = 0.0,
    base::Float64 = 0.0, area::Int64 = 0, lossZone::Int64 = 0)

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
The function sets a slack bus. The function can also be used to dynamically change the slack
bus in the system. Namely, every time the function is executed, the previous slack bus becomes
demenad or generator bus, depending on whether the bus has a generator.

    slackBus!(system::PowerSystem; label::Int64)

The keyword `label` should correspond to the already defined bus label.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
slackBus!(system; label = 1)
```
"""
function slackBus!(system::PowerSystem; label::Int64)
    if !haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in bus labels."))
    end

    layout = system.bus.layout
    supply = system.bus.supply

    if layout.slackIndex != 0
        if !isempty(supply.inService) && supply.inService[layout.slackIndex] != 0
            layout.type[layout.slackIndex] = 2
        else
            layout.type[layout.slackIndex] = 1
        end
    end
    layout.slackIndex = system.bus.label[label]
    layout.type[layout.slackIndex] = 3
end

"""
The function allows changing `conductance` and `susceptance` parameters of the shunt element
connected to the bus.

    shuntBus!(system::PowerSystem; label::Int64, conductance::Float64, susceptance::Float64)

The keyword `label` should correspond to the already defined bus label. Keywords `conductance`
or `susceptance` can be omitted, then the value of the omitted parameter remains unchanged.

The usefulness of the function is that its execution automatically updates the field `acModel`.
That is, when changing these parameters, it is not necessary to create this model from scratch.

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

    if !haskey(user, :label) || user[:label]::Int64 <= 0
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
            shunt.conductance[index] = user[:conductance]::Float64 * topu(unit, basePowerInv, "active power")
        end
        if haskey(user, :susceptance)
            shunt.susceptance[index] = user[:susceptance]::Float64 * topu(unit, basePowerInv, "reactive power")
        end


        if !isempty(system.acModel.admittance)
            ac.nodalMatrix[index, index] += shunt.conductance[index] + im * shunt.susceptance[index]
        end
    end
end

"""
The function adds a new branch and updates the field `system.branch`. A branch can be added
between already defined buses.

    addBranch!(system::PowerSystem; label::Int64, from::Int64, to::Int64,
        resistance::Float64 = 0.0, reactance::Float64 = 0.0, susceptance::Float64 = 0.0,
        turnsRatio::Float64 = 0.0, shiftAngle::Float64 = 0.0,
        longTerm::Float64 = 0.0, shortTerm::Float64 = 0.0, emergency::Float64 = 0.0,
        minAngleDifference::Float64 = -2*pi, maxAngleDifference::Float64 = 2*pi,
        status::Int64 = 1)

Descriptions, types and units of keywords are given below:
* `label` - unique branch label (positive integer)
* `from` - from bus label, corresponds to the bus label
* `to` - to bus label, corresponds to the bus label
* `resistance` - branch resistance (per-unit)
* `reactance` - branch reactance (per-unit)
* `susceptance` - total line charging susceptance (per-unit)
* `turnsRatio` - transformer off-nominal turns ratio, equal to zero for a line
* `shiftAngle` - transformer phase shift angle, where positive value defines delay (radian)
* `longTerm` - short-term rating (equal to zero for unlimited)
* `shortTerm` - long-term rating (equal to zero for unlimited)
* `emergency` - emergency rating (equal to zero for unlimited)
* `minAngleDifference` - minimum voltage angle difference value between from and to bus (radian)
* `maxAngleDifference` - maximum voltage angle difference value between from and to bus (radian)
* `status` -  operating status of the branch, in-service = 1, out-of-service = 0

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, active = 0.15, reactive = 0.08)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.05, reactance = 0.12)
```
"""
function addBranch!(system::PowerSystem; label::Int64, from::Int64, to::Int64,
    resistance::Float64 = 0.0, reactance::Float64 = 0.0, susceptance::Float64 = 0.0,
    turnsRatio::Float64 = 0.0, shiftAngle::Float64 = 0.0,
    longTerm::Float64 = 0.0, shortTerm::Float64 = 0.0, emergency::Float64 = 0.0,
    minAngleDifference::Float64 = -2 * pi, maxAngleDifference::Float64 = 2 * pi,
    status::Int64 = 1)

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

    push!(parameter.resistance, resistance)
    push!(parameter.reactance, reactance)
    push!(parameter.susceptance, susceptance)
    push!(parameter.turnsRatio, turnsRatio)
    push!(parameter.shiftAngle, shiftAngle)

    push!(rating.longTerm, longTerm)
    push!(rating.shortTerm, shortTerm)
    push!(rating.emergency, emergency)

    push!(voltage.minAngleDifference, minAngleDifference)
    push!(voltage.maxAngleDifference, maxAngleDifference)

    push!(layout.from, system.bus.label[from])
    push!(layout.to, system.bus.label[to])
    push!(layout.status, status)

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
The function allows changing the operating `status` of the branch, from in-service to
out-of-service, and vice versa.

    statusBranch!(system::PowerSystem; label::Int64, status::Int64)

The keywords `label` should correspond to the already defined branch label.

The usefulness of the function is that its execution automatically updates the fields `acModel`
and `dcModel`. That is, when changing the operating `status` of the branch, it is not necessary
to create models from scratch.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)
addBus!(system; label = 2, active = 0.15, reactive = 0.08)

addBranch!(system; label = 1, from = 1, to = 2, resistance = 0.05, reactance = 0.12)
statusBranch!(system; label = 1, status = 0)
```
"""
function statusBranch!(system::PowerSystem; label::Int64, status::Int64)
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
                nilModel!(system, :dcModelDeprive; index = index)
                dcNodalShiftUpdate!(system, index)
                nilModel!(system, :dcModelZeros; index = index)
            end
        end

        if !isempty(system.acModel.admittance)
            if status == 1
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
            if status == 0
                nilModel!(system, :acModelDeprive; index = index)
                acNodalUpdate!(system, index)
                nilModel!(system, :acModelZeros; index = index)
            end
        end
    end
    layout.status[index] = status
end

"""
The function allows changing `resistance`, `reactance`, `susceptance`, `turnsRatio` and
`shiftAngle` parameters of the branch.

    parameterBranch!(system::PowerSystem; label::Int64,
        resistance::Float64, reactance::Float64, susceptance::Float64,
        turnsRatio::Float64, shiftAngle::Float64)

The keywords `label` should correspond to the already defined branch label. Keywords `resistance`,
`reactance`, `susceptance`, `turnsRatio` or `shiftAngle` can be omitted, and then the value of
the omitted parameter remains unchanged.

The usefulness of the function is that its execution automatically updates the fields `acModel`
and `dcModel`. That is, when changing these parameters, it is not necessary to create models
from scratch.

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

    if !haskey(user, :label) || user[:label]::Int64 <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if !haskey(system.branch.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in branch labels."))
    end

    index = system.branch.label[user[:label]]
    if haskey(user, :resistance) || haskey(user, :reactance) || haskey(user, :susceptance) || haskey(user, :turnsRatio) || haskey(user, :shiftAngle)
        if layout.status[index] == 1
            if !isempty(system.dcModel.admittance)
                nilModel!(system, :dcModelDeprive; index = index)
                dcNodalShiftUpdate!(system, index)
            end
            if !isempty(system.acModel.admittance)
                nilModel!(system, :acModelDeprive; index = index)
                acNodalUpdate!(system, index)
            end
        end

        if haskey(user, :resistance)
            parameter.resistance[index] = user[:resistance]::Float64
        end
        if haskey(user, :reactance)
            parameter.reactance[index] = user[:reactance]::Float64
        end
        if haskey(user, :susceptance)
            parameter.susceptance[index] = user[:susceptance]::Float64
        end
        if haskey(user, :turnsRatio)
            parameter.turnsRatio[index] = user[:turnsRatio]::Float64
        end
        if haskey(user, :shiftAngle)
            parameter.shiftAngle[index] = user[:shiftAngle]::Float64
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
The function adds a new generator and updates the field `system.generator`. A generator can be
added to an already defined bus.

    addGenerator!(system::PowerSystem; label::Int64, bus::Int64,
        active::Float64 = 0.0, reactive::Float64 = 0.0, magnitude::Float64 = 0.0,
        minActive::Float64 = 0.0, maxActive::Float64 = Inf,
        minReactive::Float64 = -Inf, maxReactive::Float64 = Inf,
        lowerActive::Float64 = 0.0,
        minReactiveLower::Float64 = 0.0, maxReactiveLower::Float64 = 0.0,
        upperActive::Float64 = 0.0,
        minReactiveUpper::Float64 = 0.0, maxReactiveUpper::Float64 = 0.0,
        loadFollowing::Float64 = 0.0, reactiveTimescale::Float64 = 0.0
        reserve10minute::Float64 = 0.0, reserve30minute::Float64 = 0.0,
        area::Float64 = 0.0, status::Int64 = 1)

Descriptions, types and units of keywords are given below:
* `label` - unique generator label (positive integer)
* `bus` - bus label to which the generator is connected
* `active` - output active power (per-unit)
* `reactive` - output reactive power (per-unit)
* `magnitude` - voltage magnitude setpoint (per-unit)
* `minActive` - minimum allowed output active power value (per-unit)
* `maxActive` - maximum allowed output active power value (per-unit)
* `minReactive` - minimum allowed output reactive power value (per-unit)
* `maxReactive` - maximum allowed output reactive power value (per-unit)
* `lowerActive` - lower allowed active power output value of PQ capability curve (per-unit)
* `minReactiveLower` - minimum allowed reactive power output value at lowerActive value (per-unit)
* `maxReactiveLower` - maximum allowed reactive power output value at lowerActive value (per-unit)
* `upperActive` - upper allowed active power output value of PQ capability curve (per-unit)
* `minReactiveUpper` - minimum allowed reactive power output value at upperActive value (per-unit)
* `maxReactiveUpper` - maximum allowed reactive power output value at upperActive value (per-unit)
* `loadFollowing` - ramp rate for load following/AG (per-unit/minute)
* `reserve10minute` - ramp rate for 10-minute reserves (per-unit)
* `reserve30minute` - ramp rate for 30-minute reserves (per-unit)
* `reactiveTimescale` - ramp rate for reactive power, two seconds timescale (per-unit/minute)
* `area` - area participation factor
* `status` - operating status, in-service = 1, out-of-service = 0

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)

addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
```
"""
function addGenerator!(system::PowerSystem; label::Int64, bus::Int64, area::Float64 = 0.0,
    status::Int64 = 1, active::Float64 = 0.0, reactive::Float64 = 0.0, magnitude::Float64 = 1.0,
    minActive::Float64 = 0.0, maxActive::Float64 = Inf64, minReactive::Float64 = -Inf64,
    maxReactive::Float64 = Inf64, lowerActive::Float64 = 0.0, minReactiveLower::Float64 = 0.0,
    maxReactiveLower::Float64 = 0.0, upperActive::Float64 = 0.0, minReactiveUpper::Float64 = 0.0,
    maxReactiveUpper::Float64 = 0.0, loadFollowing::Float64 = 0.0, reserve10minute::Float64 = 0.0,
    reserve30minute::Float64 = 0.0, reactiveTimescale::Float64 = 0.0)

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

    system.generator.number += 1
    setindex!(system.generator.label, system.generator.number, label)

    busIndex = system.bus.label[bus]
    if status == 1
        if system.bus.layout.type[busIndex] != 3
            system.bus.layout.type[busIndex] = 2
        end
        system.bus.supply.inService[busIndex] += 1
        system.bus.supply.active[busIndex] += active
        system.bus.supply.reactive[busIndex] += reactive
    end

    push!(output.active, active)
    push!(output.reactive, reactive)

    push!(capability.minActive, minActive)
    push!(capability.maxActive, maxActive)
    push!(capability.minReactive, minReactive)
    push!(capability.maxReactive, maxReactive)
    push!(capability.lowerActive, lowerActive)
    push!(capability.minReactiveLower, minReactiveLower)
    push!(capability.maxReactiveLower, maxReactiveLower)
    push!(capability.upperActive, upperActive)
    push!(capability.minReactiveUpper, minReactiveUpper)
    push!(capability.maxReactiveUpper, maxReactiveUpper)

    push!(ramping.loadFollowing, loadFollowing)
    push!(ramping.reserve10minute, reserve10minute)
    push!(ramping.reserve30minute, reserve30minute)
    push!(ramping.reactiveTimescale, reactiveTimescale)

    push!(voltage.magnitude, magnitude)

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
The function adds costs for active power produced by the corresponding generators and updates
the field `system.generator.cost.active`. A cost can be added to an already defined generator.

    addActiveCost!(system::PowerSystem; label::Int64, model::Int64 = 0,
        piecewise:Array{Float64,2}, polynomial::Array{Float64,1})

Descriptions, types and units of keywords are given below:
* `label` - correspond to the already defined generator label
* `model` - cost model, piecewise linear = 1, polynomial = 2
* `piecewise` - cost model is defined according to input-output points, where the first column
of the matrix corresponds to values of active powers (per-unit), while the second column
corresponds to cost for supplying the indicated load (currency/hour)
* `polynomial::Array{Float64,1}` - the second-degree polynomial coefficients, where the first
element corresponds to the square term, the second element to a linear term, and third element
is the constant term

Note that the polynomial coefficients should be scaled to reflect the power change in per-unit
values. More precisely, if the coefficients are known, and the active powers are given in MW,
then the known square coefficient should be multiplied by the square of the base power given in
MVA and passed as such to the variable `polynomial`. Likewise, the linear coefficient should
be multiplied with base power given in MVA and and passed as such to the same variable.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = 1, active = 0.25, reactive = -0.04)

addGenerator!(system; label = 1, bus = 1, active = 0.5, reactive = 0.1)
addActiveCost!(system; label = 1, model = 1, polynomial = [5601.0; 85.1; 43.2])
```

"""
function addActiveCost!(system::PowerSystem; label::Int64, model::Int64 = 0,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    addCost!(system, label, model, polynomial, piecewise, system.generator.cost.active)
end

function addReactiveCost!(system::PowerSystem; label::Int64, model::Int64 = 0,
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

    index = system.generator.label[label]
    cost.model[index] = model
    cost.polynomial[index] = polynomial
    cost.piecewise[index] = piecewise
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

# """
# We advise the reader to read the section [in-depth DC Model](@ref inDepthDCModel),
# which explains all the data involved in the field `dcModel`.

#     dcModel!(system::PowerSystem)

# The function updates the field `dcModel`. Once formed, the field will be automatically
# updated when using functions [`addBranch!()`](@ref addBranch!), [`statusBranch!()`](@ref statusBranch!),
# [`parameterBranch!()`](@ref parameterBranch!).

# # Example
# ```jldoctest
# system = powerSystem("case14.h5")
# dcModel!(system)
# ```
# """
# function dcModel!(system::PowerSystem)
#     dc = system.dcModel
#     layout = system.branch.layout
#     parameter = system.branch.parameter

#     dc.shiftActivePower = fill(0.0, system.bus.number)
#     dc.admittance = fill(0.0, system.branch.number)
#     nodalDiagonals = fill(0.0, system.bus.number)
#     @inbounds for i = 1:system.branch.number
#         if layout.status[i] == 1
#             if parameter.turnsRatio[i] == 0
#                 dc.admittance[i] = 1 / parameter.reactance[i]
#             else
#                 dc.admittance[i] = 1 / (parameter.turnsRatio[i] * parameter.reactance[i])
#             end

#             from = layout.from[i]
#             to = layout.to[i]

#             shift = parameter.shiftAngle[i] * dc.admittance[i]
#             dc.shiftActivePower[from] -= shift
#             dc.shiftActivePower[to] += shift

#             nodalDiagonals[from] += dc.admittance[i]
#             nodalDiagonals[to] += dc.admittance[i]
#         end
#     end

#     busIndex = collect(1:system.bus.number)
#     dc.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
#         [nodalDiagonals; -dc.admittance; -dc.admittance], system.bus.number, system.bus.number)
# end

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

# """
# We advise the reader to read the section [in-depth AC Model](@ref inDepthACModel),
# which explains all the data involved in the field `acModel`.

#     acModel!(system::PowerSystem)

# The function updates the field `acModel`. Once formed, the field will be automatically
# updated when using functions [`addBranch!()`](@ref addBranch!), [`shuntBus!()`](@ref shuntBus!),
# [`statusBranch!()`](@ref statusBranch!), [`parameterBranch!()`](@ref parameterBranch!).

# # Example
# ```jldoctest
# system = powerSystem("case14.h5")
# acModel!(system)
# ```
# """
# function acModel!(system::PowerSystem)
#     ac = system.acModel
#     layout = system.branch.layout
#     parameter = system.branch.parameter

#     ac.transformerRatio  = zeros(ComplexF64, system.branch.number)
#     ac.admittance = zeros(ComplexF64, system.branch.number)
#     ac.nodalToTo = zeros(ComplexF64, system.branch.number)
#     ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
#     ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
#     ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
#     nodalDiagonals = zeros(ComplexF64, system.bus.number)
#     @inbounds for i = 1:system.branch.number
#         if layout.status[i] == 1
#             ac.admittance[i] = 1 / (parameter.resistance[i] + im * parameter.reactance[i])

#             if parameter.turnsRatio[i] == 0
#                 ac.transformerRatio[i] = exp(im * parameter.shiftAngle[i])
#             else
#                 ac.transformerRatio[i] = parameter.turnsRatio[i] * exp(im * parameter.shiftAngle[i])
#             end

#             transformerRatioConj = conj(ac.transformerRatio[i])
#             ac.nodalToTo[i] = ac.admittance[i] + im * 0.5 * parameter.susceptance[i]
#             ac.nodalFromFrom[i] = ac.nodalToTo[i] / (transformerRatioConj * ac.transformerRatio[i])
#             ac.nodalFromTo[i] = -ac.admittance[i] / transformerRatioConj
#             ac.nodalToFrom[i] = -ac.admittance[i] / ac.transformerRatio[i]

#             nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
#             nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
#         end
#     end

#     for i = 1:system.bus.number
#         nodalDiagonals[i] += system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i]
#     end

#     busIndex = collect(1:system.bus.number)
#     ac.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
#         [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom], system.bus.number, system.bus.number)

#     ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
# end

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