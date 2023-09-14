"""
    addGenerator!(system::PowerSystem, analysis::Analysis; label, bus, status,
        active, reactive, magnitude, minActive, maxActive, minReactive, maxReactive,
        lowActive, minLowReactive, maxLowReactive, upActive, minUpReactive, maxUpReactive,
        loadFollowing, reactiveTimescale, reserve10min, reserve30min, area)

The function adds a new generator to the `PowerSystem` composite type. The generator can
be added to an already defined bus.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined approach circumvents the necessity
for completely reconstructing vectors and matrices when adding a new generator.

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

# Updates
The function updates the `generator` field within the `PowerSystem` composite type, and in
cases where parameters impact variables in the `bus` field, it automatically adjusts the
field. Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

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

addBus!(system; label = "Bus 1", type = 2, active = 0.2, base = 132e3)

addGenerator!(system; bus = "Bus 1", active = 0.5, magnitude = 1.1)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(kV, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 20, base = 132)

addGenerator!(system; bus = "Bus 1", active = 50, magnitude = 145.2)
```
"""
function addGenerator!(system::PowerSystem;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    generator = system.generator
    default = template.generator

    system.generator.number += 1
    setLabel(generator, system.uuid, label, "generator")

    busIndex = system.bus.label[getLabel(system.bus, bus, "bus")]

    push!(generator.layout.status, unitless(status, default.status))
    checkStatus(generator.layout.status[end])

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltageInv = 1 / (system.base.voltage.value[busIndex] * system.base.voltage.prefix)

    push!(generator.output.active, topu(active, default.active, basePowerInv, prefix.activePower))
    push!(generator.output.reactive, topu(reactive, default.reactive, basePowerInv, prefix.reactivePower))

    if generator.layout.status[end] == 1
        push!(system.bus.supply.generator[busIndex], generator.number)
        system.bus.supply.active[busIndex] += generator.output.active[end]
        system.bus.supply.reactive[busIndex] += generator.output.reactive[end]
    end

    push!(generator.capability.minActive, topu(minActive, default.minActive, basePowerInv, prefix.activePower))
    push!(generator.capability.maxActive, topu(maxActive, default.maxActive, basePowerInv, prefix.activePower))

    push!(generator.capability.minReactive, topu(minReactive, default.minReactive, basePowerInv, prefix.reactivePower))
    push!(generator.capability.maxReactive, topu(maxReactive, default.maxReactive, basePowerInv, prefix.reactivePower))

    push!(generator.capability.lowActive, topu(lowActive, default.lowActive, basePowerInv, prefix.activePower))
    push!(generator.capability.minLowReactive, topu(minLowReactive, default.minLowReactive, basePowerInv, prefix.reactivePower))
    push!(generator.capability.maxLowReactive, topu(maxLowReactive, default.maxLowReactive, basePowerInv, prefix.reactivePower))

    push!(generator.capability.upActive, topu(upActive, default.upActive, basePowerInv, prefix.activePower))
    push!(generator.capability.minUpReactive, topu(minUpReactive, default.minUpReactive, basePowerInv, prefix.reactivePower))
    push!(generator.capability.maxUpReactive, topu(maxUpReactive, default.maxUpReactive, basePowerInv, prefix.reactivePower))

    push!(generator.ramping.loadFollowing, topu(loadFollowing, default.loadFollowing, basePowerInv, prefix.activePower))
    push!(generator.ramping.reserve10min, topu(reserve10min, default.reserve10min, basePowerInv, prefix.activePower))
    push!(generator.ramping.reserve30min, topu(reserve30min, default.reserve30min, basePowerInv, prefix.activePower))
    push!(generator.ramping.reactiveTimescale, topu(reactiveTimescale, default.reactiveTimescale, basePowerInv, prefix.reactivePower))

    push!(generator.voltage.magnitude, topu(magnitude, default.magnitude, baseVoltageInv, prefix.voltageMagnitude))

    push!(generator.layout.bus, busIndex)
    push!(generator.layout.area, unitless(area, default.area))

    push!(generator.cost.active.model, 0)
    push!(generator.cost.active.polynomial, Array{Float64}(undef, 0))
    push!(generator.cost.active.piecewise, Array{Float64}(undef, 0, 0))

    push!(generator.cost.reactive.model, 0)
    push!(generator.cost.reactive.polynomial, Array{Float64}(undef, 0))
    push!(generator.cost.reactive.piecewise, Array{Float64}(undef, 0, 0))
end

function addGenerator!(system::PowerSystem, analysis::DCPowerFlow;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

function addGenerator!(system::PowerSystem, analysis::ACPowerFlow;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

function addGenerator!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    generator = system.generator
    jump = analysis.jump
    constraint = analysis.constraint
    active = analysis.jump[:active]

    index = generator.label[getLabel(generator, label, "generator")]
    busIndex = generator.layout.bus[end]

    push!(active, @variable(jump, base_name = "active[$index]"))
    push!(analysis.power.generator.active, generator.output.active[end])

    if generator.layout.status[end] == 1
        changeBalance(system, analysis, busIndex; power = true, genIndex = index)

        if generator.capability.minActive[end] != generator.capability.maxActive[end]
            constraint.capability.active[index] = @constraint(jump, generator.capability.minActive[end] <= active[end] <= generator.capability.maxActive[end])
        else
            fix!(analysis.jump[:active], 0.0, constraint.capability.active, generator.number)
        end
    else
        fix!(analysis.jump[:active], 0.0, constraint.capability.active, generator.number)
    end
end

"""
    updateGenerator!(system::PowerSystem, analysis::Analysis; kwargs...)

The function allows for the alteration of parameters for an existing generator.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameter

# Keywords
To update a specific generator, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addGenerator!`](@ref addGenerator!) function, along with
their respective values. Ensure that the `label` keyword matches the label of the existing
generator you want to modify. If any keywords are omitted, their corresponding values will
remain unchanged.

# Updates
The function updates the `generator` field within the `PowerSystem` composite type, and in
cases where parameters impact variables in the `bus` field, it automatically adjusts the
field. Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addBranch!`](@ref addBranch!) function.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.2, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5)
updateGenerator!(system; label = "Generator 1", active = 0.6, reactive = 0.2)
```
"""
function updateGenerator!(system::PowerSystem;
    label::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    bus = system.bus
    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]

    if ismissing(status)
        status = generator.layout.status[index]
    end
    checkStatus(status)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    output = !ismissing(active) || !ismissing(reactive)

    if generator.layout.status[index] == 1
        if status == 0 || (status == 1 && output)
            bus.supply.active[indexBus] -= generator.output.active[index]
            bus.supply.reactive[indexBus] -= generator.output.reactive[index]
        end
        if status == 0
            for (k, i) in enumerate(bus.supply.generator[indexBus])
                if i == index
                    deleteat!(bus.supply.generator[indexBus], k)
                    break
                end
            end
        end
    end

    if output
        if !ismissing(active)
            generator.output.active[index] = topu(active, basePowerInv, prefix.activePower)
        end
        if !ismissing(reactive)
            generator.output.reactive[index] = topu(reactive, basePowerInv, prefix.reactivePower)
        end
    end

    if status == 1
        if generator.layout.status[index] == 0 || (generator.layout.status[index] == 1 && output)
            bus.supply.active[indexBus] += generator.output.active[index]
            bus.supply.reactive[indexBus] += generator.output.reactive[index]
        end
        if generator.layout.status[index] == 0
            position = searchsortedfirst(bus.supply.generator[indexBus], index)
            insert!(bus.supply.generator[indexBus], position, index)
        end
    end
    generator.layout.status[index] = status

    if !ismissing(minActive)
        generator.capability.minActive[index] = topu(minActive, basePowerInv, prefix.activePower)
    end
    if !ismissing(maxActive)
        generator.capability.maxActive[index] = topu(maxActive, basePowerInv, prefix.activePower)
    end
    if !ismissing(minReactive)
        generator.capability.minReactive[index] = topu(minReactive, basePowerInv, prefix.reactivePower)
    end
    if !ismissing(maxReactive)
        generator.capability.maxReactive[index] = topu(maxReactive, basePowerInv, prefix.reactivePower)
    end

    if !ismissing(lowActive)
        generator.capability.lowActive[index] = topu(lowActive, basePowerInv, prefix.activePower)
    end
    if !ismissing(minLowReactive)
        generator.capability.minLowReactive[index] = topu(minLowReactive, basePowerInv, prefix.reactivePower)
    end
    if !ismissing(maxLowReactive)
        generator.capability.maxLowReactive[index] = topu(maxLowReactive, basePowerInv, prefix.reactivePower)
    end

    if !ismissing(upActive)
        generator.capability.upActive[index] = topu(upActive, basePowerInv, prefix.activePower)
    end
    if !ismissing(minUpReactive)
        generator.capability.minUpReactive[index] = topu(minUpReactive, basePowerInv, prefix.reactivePower)
    end
    if !ismissing(maxUpReactive)
        generator.capability.maxUpReactive[index] = topu(maxUpReactive, basePowerInv, prefix.reactivePower)
    end

    if !ismissing(loadFollowing)
        generator.ramping.loadFollowing[index] = topu(loadFollowing, basePowerInv, prefix.activePower)
    end
    if !ismissing(reserve10min)
        generator.ramping.reserve10min[index] = topu(reserve10min, basePowerInv, prefix.activePower)
    end
    if !ismissing(reserve30min)
        generator.ramping.reserve30min[index] = topu(reserve30min, basePowerInv, prefix.activePower)
    end
    if !ismissing(reactiveTimescale)
        generator.ramping.reactiveTimescale[index] = topu(reactiveTimescale, basePowerInv, prefix.reactivePower)
    end

    if !ismissing(magnitude)
        baseVoltageInv = 1 / (system.base.voltage.value[indexBus] * system.base.voltage.prefix)
        generator.voltage.magnitude[index] = topu(magnitude, baseVoltageInv, prefix.voltageMagnitude)
    end

    if !ismissing(area)
        generator.layout.area[index] = area
    end
end

function updateGenerator!(system::PowerSystem, analysis::DCPowerFlow;
    label::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    generator = system.generator

    if !ismissing(status)
        checkStatus(status)
        index = generator.label[getLabel(generator, label, "generator")]
        indexBus = generator.layout.bus[index]
        if status == 0 && system.bus.layout.slack == indexBus && length(system.bus.supply.generator[indexBus]) == 1
            throw(ErrorException("The DC power flow model cannot be reused due to required bus type conversion."))
        end
    end

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

function updateGenerator!(system::PowerSystem, analysis::Union{NewtonRaphson, FastNewtonRaphson};
    label::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    if !ismissing(status)
        checkStatus(status)
        if status == 0 && system.bus.layout.type[indexBus] in [2, 3] && length(system.bus.supply.generator[indexBus]) == 1
            throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
        end
    end

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    if system.bus.layout.type[indexBus] in [2, 3]
        index = system.bus.supply.generator[indexBus][1]
        analysis.voltage.magnitude[indexBus] = generator.voltage.magnitude[index]
     end
end

function updateGenerator!(system::PowerSystem, analysis::GaussSeidel;
    label::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    bus = system.bus
    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    if !ismissing(status)
        checkStatus(status)
        if status == 0 && bus.layout.type[indexBus] in [2, 3] && length(bus.supply.generator[indexBus]) == 1
            throw(ErrorException("The AC power flow model cannot be reused due to required bus type conversion."))
        end
    end

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    if bus.layout.type[indexBus] in [2, 3]
        index = bus.supply.generator[indexBus][1]
        analysis.voltage.magnitude[indexBus] = generator.voltage.magnitude[index]
        analysis.method.voltage[indexBus] = generator.voltage.magnitude[index] * exp(im * angle(analysis.method.voltage[indexBus]))
     end
end

function updateGenerator!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    generator = system.generator
    jump = analysis.jump
    constraint = analysis.constraint

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    statusOld = generator.layout.status[index]

    helper = constraint.piecewise.helper

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    if !ismissing(active)
        analysis.power.generator.active[index] = generator.output.active[index]
    end

    if statusOld == 1 && generator.layout.status[index] == 0
        objExpr = objective_function(jump)
        objExpr, helperFlag = updateObjective(-objExpr, jump[:active][index], generator, index, label)

        if helperFlag
            delete!(jump, constraint.piecewise.active, index)
            add_to_expression!(objExpr, helper[index])
            drop_zeros!(objExpr)
            delete!(jump, helper, index)
        end

        delete!(jump, constraint.capability.active, index)
        if haskey(constraint.balance.active, indexBus) && !JuMP.is_valid(jump, constraint.balance.active[indexBus]) 
            JuMP.set_normalized_coefficient(constraint.balance.active[indexBus], jump[:active][index], 0)
        end
        fix!(jump[:active], 0.0, constraint.capability.active, index)

        JuMP.set_objective_function(jump, -objExpr)
    end

    if statusOld == 0 && generator.layout.status[index] == 1
        objExpr = objective_function(jump)
        objExpr, helperFlag = updateObjective(objExpr, jump[:active][index], generator, index, label)

        if helperFlag
            helper[index] = @variable(jump, base_name = "helper[$index]")
            add_to_expression!(objExpr, helper[index])

            objExpr = updatePiecewise(objExpr, analysis, generator, index, label)
            JuMP.set_objective_function(jump, objExpr)
        end

        changeBalance(system, analysis, indexBus; power = true, genIndex = index)
        if generator.capability.minActive[index] != generator.capability.maxActive[index]
            constraint.capability.active[index] =  @constraint(jump, generator.capability.minActive[index] <= jump[:active][index] <= generator.capability.maxActive[index])
        else
            fix(jump[:active][index], 0.0)
            constraint.capability.active[index] = JuMP.FixRef(jump[:active][index])
        end
    end

    if statusOld == 1 && generator.layout.status[index] == 1 && (!ismissing(minActive) || !ismissing(maxActive))
        if generator.capability.minActive[index] != generator.capability.maxActive[index]
            constraint.capability.active[index] =  @constraint(jump, generator.capability.minActive[index] <= jump[:active][index] <= generator.capability.maxActive[index])
        else
            fix(jump[:active][index], 0.0)
            constraint.capability.active[index] = JuMP.FixRef(jump[:active][index])
        end
        if haskey(constraint.balance.active, indexBus) && !JuMP.is_valid(jump, constraint.balance.active[indexBus])
            changeBalance(system, analysis, indexBus)
        end
    end
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

addBus!(system; label = "Bus 1", type = 2, active = 0.25, reactive = -0.04, base = 132e3)

@generator(magnitude = 1.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5, reactive = 0.1)
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(kV, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 25, reactive = -4, base = 132)

@generator(magnitude = 145.2)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 50, reactive = 10)
```
"""
macro generator(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]
        value::Float64 = Float64(eval(kwarg.args[2]))
        if hasfield(GeneratorTemplate, parameter)
            if !(parameter in [:area; :status])
                container::ContainerTemplate = getfield(template.generator, parameter)

                if parameter in [:active; :minActive; :maxActive; :lowActive; :upActive; :loadFollowing; :reserve10min; :reserve30min]
                    prefixLive = prefix.activePower
                elseif parameter in [:reactive; :minReactive; :maxReactive; :minLowReactive; :maxLowReactive; :minUpReactive; :maxUpReactive; :reactiveTimescale]
                    prefixLive = prefix.reactivePower
                elseif parameter == :magnitude
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
                if parameter == :status
                    setfield!(template.generator, parameter, Int8(value))
                elseif parameter == :area
                    setfield!(template.generator, parameter, Int64(value))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

"""
    cost!(system::PowerSystem, analysis::Analysis; label, cost,
        model, piecewise, polynomial)

The function either adds a new cost or modifies an existing one for the active or reactive
power generated by the corresponding generator within the `PowerSystem` composite type.
It has the capability to append a cost to an already defined generator.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined approach circumvents the necessity
for completely reconstructing vectors and matrices when adding a new branch.

# Keywords
The function accepts four keywords:
* `label`: corresponds to the already defined generator label;
* `cost`: cost type:
  * `cost = :active`: adding cost for the active power;
  * `cost = :reactive`: adding cost for the reactive power;
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

# Updates
The function updates the `generator.cost` field within the `PowerSystem` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

# Default Settings
By default, the cost type is set to c`ost = :active`. Additionally, when adding only a
`piecewise` or `polynomial` cost function, you can omit the `model` keyword, as the
appropriate model will be assigned based on the defined cost function.

# Units
By default, the input units related with active powers are per-units (pu), but they can be
modified using the macro [`@power`](@ref @power).

# Examples
Creating a bus using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, reactive = -0.04, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5)
cost!(system; label = "Generator 1", polynomial = [1100.0; 500.0; 150.0])
```

Creating a bus using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
system = powerSystem()

addBus!(system; label = "Bus 1", active = 25, reactive = -4, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 50, reactive = 10)
cost!(system; label = "Generator 1", polynomial = [0.11; 5.0; 150.0])
```
"""
function cost!(system::PowerSystem; label::L,
    cost::Symbol = :active, model::T = missing,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    index = system.generator.label[getLabel(system.generator, label, "generator")]
    container = getfield( system.generator.cost, cost)

    if cost == :active
        if prefix.activePower == 0.0
            scale = 1.0
        else
            scale = prefix.activePower / (system.base.power.prefix * system.base.power.value)
        end
    end
    if cost == :reactive
        if prefix.reactivePower == 0.0
            scale = 1.0
        else
            scale = prefix.reactivePower / (system.base.power.prefix * system.base.power.value)
        end
    end

    if !ismissing(model)
        if !(model in [1; 2])
            throw(ErrorException("The model $model is not allowed; it should be either piecewise (1) or polynomial (2)."))
        end
        container.model[index] = model
    else
        if !isempty(piecewise)
            container.model[index] = 1
        end
        if !isempty(polynomial)
            container.model[index] = 2
        end
    end

    if !isempty(polynomial)
        numberCoefficient = length(polynomial)
        container.polynomial[index] = fill(0.0, numberCoefficient)
        @inbounds for i = 1:numberCoefficient
            container.polynomial[index][i] = polynomial[i] / (scale^(numberCoefficient - i))
        end
    end

    if !isempty(piecewise)
        container.piecewise[index] = [scale .* piecewise[:, 1] piecewise[:, 2]]
    end
end

function cost!(system::PowerSystem, analysis::DCOptimalPowerFlow; label::L,
    cost::Symbol = :active, model::T = missing,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    checkUUID(system.uuid, analysis.uuid)

    generator = system.generator
    jump = analysis.jump
    constraint = analysis.constraint

    index = generator.label[getLabel(generator, label, "generator")]
    active = jump[:active][index]
    helper = constraint.piecewise.helper
    objExpr = objective_function(jump)

    if generator.layout.status[index] == 1
        objExpr, helperOld = updateObjective(-objExpr, active, generator, index, label)

        if helperOld
            delete!(jump, constraint.piecewise.active, index)
        end
    end

    cost!(system; label, cost, model, polynomial, piecewise)

    if generator.layout.status[index] == 1
        objExpr, helperNew = updateObjective(-objExpr, active, generator, index, label)

        if helperOld && !helperNew
            add_to_expression!(objExpr, -helper[index])
            drop_zeros!(objExpr)
            delete!(jump, helper, index)
        elseif helperNew && !helperOld
            helper[index] = @variable(jump, base_name = "helper[$index]")
            add_to_expression!(objExpr, helper[index])
        end

        if helperNew
            objExpr = updatePiecewise(objExpr, analysis, generator, index, label)
        end
    end

    JuMP.set_objective_function(jump, objExpr)
end