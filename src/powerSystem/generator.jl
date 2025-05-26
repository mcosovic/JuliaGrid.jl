"""
    addGenerator!(system::PowerSystem;
        label, bus, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive,
        lowActive, minLowReactive, maxLowReactive, upActive, minUpReactive, maxUpReactive,
        loadFollowing, reactiveRamp, reserve10min, reserve30min, area)

The function adds a new generator to the `PowerSystem` type. The generator can be added to an already
defined bus.

# Keywords
The generator is defined with the following keywords:
* `label`: Unique label for the generator.
* `bus`: Label of the bus to which the generator is connected.
* `status`: Operating status of the generator:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.
* `active` (pu or W): Output active power.
* `reactive` (pu or VAr): Output reactive power.
* `magnitude` (pu or V): Voltage magnitude setpoint.
* `minActive` (pu or W): Minimum allowed active power output value.
* `maxActive` (pu or W): Maximum allowed active power output value.
* `minReactive` (pu or VAr): Minimum allowed reactive power output value.
* `maxReactive` (pu or VAr): Maximum allowed reactive power output value.
* `lowActive` (pu or W): Lower allowed active power output value of PQ capability curve.
* `minLowReactive` (pu or VAr): Minimum allowed reactive power output value at `lowActive` value.
* `maxLowReactive` (pu or VAr): Maximum allowed reactive power output value at `lowActive` value.
* `upActive` (pu or W): Upper allowed active power output value of PQ capability curve.
* `minUpReactive` (pu or VAr): Minimum allowed reactive power output value at `upActive` value.
* `maxUpReactive` (pu or VAr): Maximum allowed reactive power output value at `upActive` value.
* `loadFollowing` (pu/min or W/min): Ramp rate for load following/AG.
* `reserve10min` (pu or W): Ramp rate for 10-minute reserves.
* `reserve30min` (pu or W): Ramp rate for 30-minute reserves.
* `reactiveRamp` (pu/min or VAr/min): Ramp rate for reactive power, two seconds timescale.
* `area`: Area participation factor.

Note that voltage magnitude values are referenced to line-to-neutral voltages, while powers, when
given in SI units, correspond to three-phase power.

# Updates
The function updates the `generator` field within the `PowerSystem` type, and in cases where
parameters impact variables in the `bus` field, it automatically adjusts the field.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `magnitude = 1.0`,
`maxActive = 5 active`, `minReactive = -5 reactive`, and `maxReactive = 5 reactive`. The rest of the
keywords are initialized with a value of zero. However, the user can modify these default settings
by utilizing the [`@generator`](@ref @generator) macro.

# Units
By default, the input units are associated with per-units as shown. However, users have the option to
use other units instead of per-units using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage)
macros.

# Examples
Adding a generator using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.2, base = 132e3)

addGenerator!(system; bus = "Bus 1", active = 0.5, magnitude = 1.1)
```

Adding a generator using a custom unit system:
```jldoctest
@power(MW, MVAr)
@voltage(kV, deg, kV)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 20, base = 132)

addGenerator!(system; bus = "Bus 1", active = 50, magnitude = 145.2)
```
"""
function addGenerator!(system::PowerSystem; bus::IntStr, kwargs...)
    addGeneratorMain!(system, bus, GeneratorKey(; kwargs...))
end

function addGeneratorMain!(system::PowerSystem, bus::IntStr, key::GeneratorKey)
    gen = system.generator
    cbt = gen.capability
    def = template.generator

    gen.number += 1
    setLabel(gen, key.label, def.label, "generator")
    busIdx = getIndex(system.bus, bus, "bus")

    add!(gen.layout.status, key.status, def.status)
    checkStatus(gen.layout.status[end])

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    add!(gen.output.active, key.active, def.active, pfx.activePower, baseInv)
    add!(gen.output.reactive, key.reactive, def.reactive, pfx.reactivePower, baseInv)

    add!(cbt.minActive, key.minActive, def.minActive, pfx.activePower, baseInv, 0.0)
    add!(cbt.maxActive, key.maxActive, def.maxActive, pfx.activePower, baseInv, gen.output.active[end])
    add!(cbt.minReactive, key.minReactive, def.minReactive, pfx.reactivePower, baseInv, -gen.output.reactive[end])
    add!(cbt.maxReactive, key.maxReactive, def.maxReactive, pfx.reactivePower, baseInv, gen.output.reactive[end])

    add!(cbt.lowActive, key.lowActive, def.lowActive, pfx.activePower, baseInv)
    add!(cbt.minLowReactive, key.minLowReactive, def.minLowReactive, pfx.reactivePower, baseInv)
    add!(cbt.maxLowReactive, key.maxLowReactive, def.maxLowReactive, pfx.reactivePower, baseInv)
    add!(cbt.upActive, key.upActive, def.upActive, pfx.activePower, baseInv)
    add!(cbt.minUpReactive, key.minUpReactive, def.minUpReactive, pfx.reactivePower, baseInv)
    add!(cbt.maxUpReactive, key.maxUpReactive, def.maxUpReactive, pfx.reactivePower, baseInv)

    add!(gen.ramping.loadFollowing, key.loadFollowing, def.loadFollowing, pfx.activePower, baseInv)
    add!(gen.ramping.reserve10min, key.reserve10min, def.reserve10min, pfx.activePower, baseInv)
    add!(gen.ramping.reserve30min, key.reserve30min, def.reserve30min, pfx.activePower, baseInv)
    add!(gen.ramping.reactiveRamp, key.reactiveRamp, def.reactiveRamp, pfx.reactivePower, baseInv)

    if gen.layout.status[end] == 1
        addGenInBus!(system, busIdx, gen.number)
        gen.layout.inservice += 1

        system.bus.supply.active[busIdx] += gen.output.active[end]
        system.bus.supply.reactive[busIdx] += gen.output.reactive[end]
    end

    baseInv = sqrt(3) / (system.base.voltage.value[busIdx] * system.base.voltage.prefix)
    add!(gen.voltage.magnitude, key.magnitude, def.magnitude, pfx.voltageMagnitude, baseInv)

    push!(gen.layout.bus, busIdx)
    add!(gen.layout.area, key.area, def.area)

    push!(gen.cost.active.model, 0)
    push!(gen.cost.reactive.model, 0)
end

"""
    addGenerator!(analysis::Analysis; kwargs...)

The function extends the [`addGenerator!`](@ref addGenerator!(::PowerSystem)) function. When the
`Analysis` type is passed, the function first adds the specified generator to the `PowerSystem` type
using the provided `kwargs`, and then adds the same generator to the `Analysis` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
analysis = newtonRaphson(system)

addGenerator!(analysis; bus = 1, active = 0.5, reactive = 0.2)
```
"""
function addGenerator!(analysis::PowerFlow; bus::IntStr, kwargs...)
    addGeneratorMain!(analysis.system, bus, GeneratorKey(; kwargs...))
    _addGenerator!(analysis)
end

function _addGenerator!(analysis::AcPowerFlow)
    errorTypeConversion(analysis.system.bus.layout.pattern, analysis.method.signature[:type])
end

function _addGenerator!(analysis::DcPowerFlow)
    errorTypeConversion(analysis.system.bus.layout.slack, analysis.method.signature[:slack])
end

function _addGenerator!(analysis::AcOptimalPowerFlow)
    system = analysis.system
    gen = system.generator
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    idx = gen.number
    idxBus = gen.layout.bus[end]

    push!(var.power.active, @variable(jump, base_name = "$(jump.ext[:active])[$idx]"))
    push!(var.power.reactive, @variable(jump, base_name = "$(jump.ext[:reactive])[$idx]"))

    push!(analysis.power.generator.active, gen.output.active[end])
    push!(analysis.power.generator.reactive, gen.output.reactive[end])

    if gen.layout.status[end] == 1
        capabilityCurve(system, jump, var, con, idx)

        addCapability(
            jump, var.power.active, con.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
        addCapability(
            jump, var.power.reactive, con.capability.reactive,
            gen.capability.minReactive, gen.capability.maxReactive, idx
        )
    else
        fix!(var.power.active[idx], 0.0, con.capability.active, idx)
        fix!(var.power.reactive[idx], 0.0, con.capability.reactive, idx)
    end

    remove!(jump, con.balance.active, idxBus)
    remove!(jump, con.balance.reactive, idxBus)
    addBalance(system, jump, var, con, idxBus)
end

function _addGenerator!(analysis::DcOptimalPowerFlow)
    system = analysis.system
    gen = system.generator
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    idx = gen.number
    idxBus =  gen.layout.bus[end]

    push!(var.power.active, @variable(jump, base_name = "$(jump.ext[:active])[$idx]"))
    push!(analysis.power.generator.active, gen.output.active[end])

    if gen.layout.status[end] == 1
        addCapability(
            jump, var.power.active, con.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
    else
        fix!(var.power.active[idx], 0.0, con.capability.active, idx)
    end

    remove!(jump, con.balance.active, idxBus)
    addBalance(system, jump, var, con, idxBus)
end

"""
    updateGenerator!(system::PowerSystem; kwargs...)

The function allows for the alteration of parameters for an existing generator.

# Keywords
To update a specific generator, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addGenerator!`](@ref addGenerator!) function, along with their respective
values. Ensure that the `label` keyword matches the label of the existing generator. If any keywords
are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `generator` field within the `PowerSystem` type, and in cases where
parameters impact variables in the `bus` field, it automatically adjusts the field.

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
function updateGenerator!(system::PowerSystem; label::IntStr, kwargs...)
    updateGeneratorMain!(system, label, GeneratorKey(; kwargs...))
end

function updateGeneratorMain!(system::PowerSystem, label::IntStr, key::GeneratorKey)
    bus = system.bus
    gen = system.generator

    idx = getIndex(gen, label, "generator")
    idxBus = gen.layout.bus[idx]

    statusNew = key.status
    statusOld = gen.layout.status[idx]

    if ismissing(statusNew)
        statusNew = copy(statusOld)
    end
    checkStatus(statusNew)

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    output = isset(key.active) || isset(key.reactive)

    if statusOld == 1
        if statusNew == 0 || (statusNew == 1 && output)
            bus.supply.active[idxBus] -= gen.output.active[idx]
            bus.supply.reactive[idxBus] -= gen.output.reactive[idx]
        end
        if statusNew == 0
            gen.layout.inservice -= 1
            for (k, i) in enumerate(bus.supply.generator[idxBus])
                if i == idx
                    deleteat!(bus.supply.generator[idxBus], k)
                    break
                end
            end
        end
    end

    if output
        update!(gen.output.active, key.active, pfx.activePower, baseInv, idx)
        update!(gen.output.reactive, key.reactive, pfx.reactivePower, baseInv, idx)
    end

    if statusNew == 1
        if statusOld == 0 || (statusOld == 1 && output)
            bus.supply.active[idxBus] += gen.output.active[idx]
            bus.supply.reactive[idxBus] += gen.output.reactive[idx]
        end
        if statusOld == 0
            gen.layout.inservice += 1
            if haskey(bus.supply.generator, idxBus)
                position = searchsortedfirst(bus.supply.generator[idxBus], idx)
                insert!(bus.supply.generator[idxBus], position, idx)
            else
                bus.supply.generator[idxBus] = [idx]
            end
        end
    end
    gen.layout.status[idx] = statusNew

    update!(gen.capability.minActive, key.minActive, pfx.activePower, baseInv, idx)
    update!(gen.capability.maxActive, key.maxActive, pfx.activePower, baseInv, idx)
    update!(gen.capability.minReactive, key.minReactive, pfx.reactivePower, baseInv, idx)
    update!(gen.capability.maxReactive, key.maxReactive, pfx.reactivePower, baseInv, idx)
    update!(gen.capability.lowActive, key.lowActive, pfx.activePower, baseInv, idx)
    update!(gen.capability.minLowReactive, key.minLowReactive, pfx.reactivePower, baseInv, idx)
    update!(gen.capability.maxLowReactive, key.maxLowReactive, pfx.reactivePower, baseInv, idx)
    update!(gen.capability.upActive, key.upActive, pfx.activePower, baseInv, idx)
    update!(gen.capability.minUpReactive, key.minUpReactive, pfx.reactivePower, baseInv, idx)
    update!(gen.capability.maxUpReactive, key.maxUpReactive, pfx.reactivePower, baseInv, idx)

    update!(gen.ramping.loadFollowing, key.loadFollowing, pfx.activePower, baseInv, idx)
    update!(gen.ramping.reserve10min, key.reserve10min, pfx.activePower, baseInv, idx)
    update!(gen.ramping.reserve30min, key.reserve30min, pfx.activePower, baseInv, idx)
    update!(gen.ramping.reactiveRamp, key.reactiveRamp, pfx.reactivePower, baseInv, idx)

    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)
    update!(gen.voltage.magnitude, key.magnitude, pfx.voltageMagnitude, baseInv, idx)

    update!(gen.layout.area, key.area, idx)
end

"""
    updateGenerator!(analysis::Analysis; kwargs...)

The function extends the [`updateGenerator!`](@ref updateGenerator!(::PowerSystem)) function. By
passing the `Analysis` type, the function first updates the specific generator within the
`PowerSystem` type using the provided `kwargs`, and then updates the `Analysis` type with parameters
associated with that generator.

A key feature of this function is that any prior modifications made to the specified generator are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system = powerSystem("case14.h5")
analysis = newtonRaphson(system)

updateGenerator!(analysis; label = 2, active = 0.35)
```
"""
function updateGenerator!(analysis::PowerFlow; label::IntStr, kwargs...)
    updateGeneratorMain!(analysis.system, label, GeneratorKey(; kwargs...))
    _updateGenerator!(analysis, getIndex(analysis.system.generator, label, "generator"))
end

function _updateGenerator!(analysis::AcPowerFlow{T}, idx::Int64) where T <: Union{NewtonRaphson, FastNewtonRaphson}
    system = analysis.system
    gen = system.generator

    errorTypeConversion(system.bus.layout.pattern, analysis.method.signature[:type])

    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 0 && system.bus.layout.type[idxBus] ∈ (2, 3)
        if length(system.bus.supply.generator[idxBus]) == 0
            errorTypeConversion()
        end
    end

    if system.bus.layout.type[idxBus] ∈ (2, 3)
        idx = system.bus.supply.generator[idxBus][1]
        analysis.voltage.magnitude[idxBus] = gen.voltage.magnitude[idx]
    end
end

function _updateGenerator!(analysis::AcPowerFlow{GaussSeidel}, idx::Int64)
    system = analysis.system
    bus = system.bus
    gen = system.generator

    errorTypeConversion(system.bus.layout.pattern, analysis.method.signature[:type])

    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 0 && bus.layout.type[idxBus] ∈ (2, 3)
        if length(bus.supply.generator[idxBus]) == 0
            errorTypeConversion()
        end
    end

    if bus.layout.type[idxBus] ∈ (2, 3)
        idx = bus.supply.generator[idxBus][1]
        analysis.voltage.magnitude[idxBus] = gen.voltage.magnitude[idx]
        analysis.method.voltage[idxBus] =
            gen.voltage.magnitude[idx] * cis(angle(analysis.method.voltage[idxBus]))
     end
end

function _updateGenerator!(analysis::DcPowerFlow, idx::Int64)
    system = analysis.system
    gen = system.generator

    errorTypeConversion(system.bus.layout.slack, analysis.method.signature[:slack])

    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 0 && system.bus.layout.slack == idxBus
        if length(system.bus.supply.generator[idxBus]) == 0
            errorTypeConversion()
        end
    end
end

function _updateGenerator!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    cbt = system.generator.capability

    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint
    obj = analysis.method.objective
    quad = analysis.method.objective.quadratic

    P = var.power.active
    Q = var.power.reactive
    H = var.power.actwise
    G = var.power.reactwise

    freeP = analysis.method.signature[:freeP]
    freeQ = analysis.method.signature[:freeQ]

    idxBus = system.generator.layout.bus[idx]

    if lastindex(analysis.power.generator.active) == system.generator.number
        analysis.power.generator.active[idx] = system.generator.output.active[idx]
        analysis.power.generator.reactive[idx] = system.generator.output.reactive[idx]
    else
        push!(var.power.active, @variable(jump, base_name = "$(jump.ext[:active])[$idx]"))
        push!(var.power.reactive, @variable(jump, base_name = "$(jump.ext[:reactive])[$idx]"))

        push!(analysis.power.generator.active, system.generator.output.active[idx])
        push!(analysis.power.generator.reactive, system.generator.output.reactive[idx])
    end

    remove!(jump, con.capability.active, idx)
    remove!(jump, con.capability.reactive, idx)
    remove!(jump, con.capability.lower, idx)
    remove!(jump, con.capability.upper, idx)

    @objective(jump, Min, 0.0)

    removeObjective!(jump, P, H, con.piecewise.active, quad, freeP, idx)
    removeObjective!(jump, Q, G, con.piecewise.reactive, quad, freeQ, idx)
    removeNonlinear!(analysis.method.objective, idx)

    if system.generator.layout.status[idx] == 1
        addObjective(system, jump, var, con, obj, freeP, freeQ, idx)

        capabilityCurve(system, jump, var, con, idx)
        addCapability(jump, P, con.capability.active, cbt.minActive, cbt.maxActive, idx)
        addCapability(jump, Q, con.capability.reactive, cbt.minReactive, cbt.maxReactive, idx)
    else
        fix!(var.power.active[idx], 0.0, con.capability.active, idx)
        fix!(var.power.reactive[idx], 0.0, con.capability.reactive, idx)
    end

    setObjective(jump, obj)

    remove!(jump, con.balance.active, idxBus)
    remove!(jump, con.balance.reactive, idxBus)
    addBalance(system, jump, var, con, idxBus)
end

function _updateGenerator!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    cbt = system.generator.capability
    cost = system.generator.cost.active

    jump = analysis.method.jump
    power = analysis.method.variable.power.active
    helper = analysis.method.variable.power.actwise
    con = analysis.method.constraint
    obj = analysis.method.objective

    free = analysis.method.signature[:free]
    actwise = jump.ext[:actwise]

    idxBus = system.generator.layout.bus[idx]

    if lastindex(analysis.power.generator.active) == system.generator.number
        analysis.power.generator.active[idx] = system.generator.output.active[idx]
    else
        push!(power, @variable(jump, base_name = "$(jump.ext[:active])[$idx]"))
        push!(analysis.power.generator.active, system.generator.output.active[idx])
    end

    remove!(jump, con.capability.active, idx)
    removeObjective!(jump, power, helper, con.piecewise.active, obj, free, idx)

    if system.generator.layout.status[idx] == 1
        addObjective(system, cost, jump, power, helper, con, obj, actwise, free, idx)
        addCapability(jump, power, con.capability.active, cbt.minActive, cbt.maxActive, idx)
    else
        fix!(power[idx], 0.0, con.capability.active, idx)
    end

    set_objective_function(jump, obj)

    remove!(jump, con.balance.active, idxBus)
    addBalance(system, jump, analysis.method.variable, con, idxBus)
end

"""
    @generator(kwargs...)

The macro generates a template for a generator.

# Keywords
To define the generator template, the `kwargs` input arguments must be provided in accordance with
the keywords specified within the [`addGenerator!`](@ref addGenerator!) function, along with their
corresponding values.

# Units
By default, the input units are associated with per-units. However, users have the option to use
other units instead of per-units using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage)
macros.

# Examples
Adding a generator using the default unit system:
```jldoctest
@generator(magnitude = 1.1)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.25, reactive = -0.04, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5, reactive = 0.1)
```

Adding a generator using a custom unit system:
```jldoctest
@power(MW, MVAr)
@voltage(kV, deg, kV)
@generator(magnitude = 145.2)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 25, reactive = -4, base = 132)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 50, reactive = 10)
```
"""
macro generator(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(GeneratorTemplate, parameter)
                if parameter ∉ (:area, :status, :label)
                    container::ContainerTemplate = getfield(template.generator, parameter)

                    if parameter in (
                        :active, :minActive, :maxActive, :lowActive, :upActive,
                        :loadFollowing, :reserve10min, :reserve30min
                        )
                        pfxLive = pfx.activePower
                    elseif parameter in (
                        :reactive, :minReactive, :maxReactive, :minLowReactive,
                        :maxLowReactive, :minUpReactive, :maxUpReactive, :reactiveRamp
                        )
                        pfxLive = pfx.reactivePower
                    elseif parameter == :magnitude
                        pfxLive = pfx.voltageMagnitude
                    end
                    if pfxLive != 0.0
                        setfield!(container, :value, pfxLive * Float64(eval(kwarg.args[2])))
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, Float64(eval(kwarg.args[2])))
                        setfield!(container, :pu, true)
                    end
                else
                    if parameter == :status
                        setfield!(template.generator, parameter, Int8(eval(kwarg.args[2])))
                    elseif parameter == :area
                        setfield!(template.generator, parameter, Int64(eval(kwarg.args[2])))
                    elseif parameter == :label
                        macroLabel(template.generator, kwarg.args[2], "[?]")
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end

"""
    cost!(system::PowerSystem; generator, active, reactive, piecewise, polynomial)

The function either adds a new cost or modifies an existing one for the active or reactive power
generated by the corresponding generator within the `PowerSystem` type. It has the capability to
append a cost to an already defined generator.

# Keywords
The function accepts five keywords:
* `generator`: Corresponds to the already defined generator label.
* `active`: Active power cost model:
  * `active = 1`: adding or updating cost, and piecewise linear is being used,
  * `active = 2`: adding or updating cost, and polynomial is being used.
* `reactive`: Reactive power cost model:
  * `reactive = 1`: adding or updating cost, and piecewise linear is being used,
  * `reactive = 2`: adding or updating cost, and polynomial is being used.
* `piecewise`: Cost model defined by input-output points given as `Matrix{Float64}`:
  * first column (pu, W or VAr): active or reactive power output of the generator,
  * second column (\\\$/hr): cost for the specified active or reactive power output.
* `polynomial`: The n-th degree polynomial coefficients given as `Vector{Float64}`:
  * first element (\\\$/puⁿ-hr, \\\$/Wⁿ-hr or \\\$/VArⁿ-hr): coefficient of the n-th degree term, ....,
  * penultimate element (\\\$/pu-hr, \\\$/W-hr or \\\$/VAr-hr): coefficient of the first degree term,
  * last element (\\\$/hr): constant coefficient.

# Updates
The function updates the `generator.cost` field within the `PowerSystem` type.

# Units
By default, the input units related with active powers are per-units, but they can be
modified using the macro [`@power`](@ref @power).

# Examples
Adding a cost using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, reactive = -0.04, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5)
cost!(system; generator = "Generator 1", active = 2, polynomial = [1100.0; 500.0; 150.0])
```

Adding a cost using a custom unit system:
```jldoctest
@power(MW, MVAr)

system = powerSystem()

addBus!(system; label = "Bus 1", active = 25, reactive = -4, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 50, reactive = 10)
cost!(system; generator = "Generator 1", active = 2, polynomial = [0.11; 5.0; 150.0])
```
"""
function cost!(system::PowerSystem; generator::IntStr, kwargs...)
    costMain!(system, generator, CostKey(; kwargs...))
end

function costMain!(system::PowerSystem, generator::IntStr, key::CostKey)
    if isset(key.active) && isset(key.reactive)
        throw(ErrorException(
            "The concurrent definition of the keywords active and reactive is not allowed.")
        )
    elseif ismissing(key.active) && ismissing(key.reactive)
        throw(ErrorException("The cost model is missing."))
    elseif isset(key.active) && key.active ∉ (1, 2) || isset(key.reactive) && key.reactive ∉ (1, 2)
        throw(ErrorException(
            "The model is not allowed; it should be piecewise (1) or polynomial (2).")
        )
    end

    idx = getIndex(system.generator, generator, "generator")

    if isset(key.active)
        container = system.generator.cost.active
        container.model[idx] = key.active
        if pfx.activePower == 0.0
            scale = 1.0
        else
            scale = pfx.activePower / (system.base.power.prefix * system.base.power.value)
        end
    elseif isset(key.reactive)
        container = system.generator.cost.reactive
        container.model[idx] = key.reactive
        if pfx.reactivePower == 0.0
            scale = 1.0
        else
            scale = pfx.reactivePower / (system.base.power.prefix * system.base.power.value)
        end
    end

    if container.model[idx] == 1 && isempty(key.piecewise) && !haskey(container.piecewise, idx)
        errorAssignCost("piecewise")
    end
    if container.model[idx] == 2 && isempty(key.polynomial) && !haskey(container.polynomial, idx)
        errorAssignCost("polynomial")
    end

    if !isempty(key.polynomial)
        numCoeff = lastindex(key.polynomial)
        container.polynomial[idx] = fill(0.0, numCoeff)

        @inbounds for i = 1:numCoeff
            container.polynomial[idx][i] = key.polynomial[i] / (scale^(numCoeff - i))
        end
    end

    if !isempty(key.piecewise)
        container.piecewise[idx] = [scale .* key.piecewise[:, 1] key.piecewise[:, 2]]
    end
end

"""
    cost!(analysis::Analysis; kwargs...)

The function extends the [`cost!`](@ref cost!(::PowerSystem)) function. When the `Analysis` type is
passed, the function first adds or modifies an existing cost in the `PowerSystem` type using the
provided `kwargs` and then applies the same changes to the `Analysis` type.

A key feature of this function is that any prior modifications to the specified cost are preserved
and applied to the `Analysis` type when the function is executed, ensuring consistency throughout
the update process.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

cost!(analysis; generator = 2, active = 2, polynomial = [1100.0; 500.0; 150.0])
```
"""
function cost!(analysis::OptimalPowerFlow; generator::IntStr, kwargs...)
    costMain!(analysis.system, generator, CostKey(; kwargs...))
    _cost!(analysis, getIndex(analysis.system.generator, generator, "generator"))
end

function _cost!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system

    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint
    obj = analysis.method.objective

    P = var.power.active
    Q = var.power.reactive
    H = var.power.actwise
    G = var.power.reactwise

    freeP = analysis.method.signature[:freeP]
    freeQ = analysis.method.signature[:freeQ]

    if system.generator.layout.status[idx] == 1
        @objective(jump, Min, 0.0)

        removeObjective!(jump, P, H, con.piecewise.active, obj.quadratic, freeP, idx)
        removeObjective!(jump, Q, G, con.piecewise.reactive, obj.quadratic, freeQ, idx)
        removeNonlinear!(analysis.method.objective, idx)

        addObjective(system, jump, var, con, obj, freeP, freeQ, idx)
    end

    setObjective(jump, obj)
end

function _cost!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    cost = system.generator.cost.active

    jump = analysis.method.jump
    power = analysis.method.variable.power.active
    helper = analysis.method.variable.power.actwise
    con = analysis.method.constraint
    obj = analysis.method.objective

    free = analysis.method.signature[:free]
    actwise = jump.ext[:actwise]

    if system.generator.layout.status[idx] == 1
        removeObjective!(jump, power, helper, con.piecewise.active, obj, free, idx)

        addObjective(system, cost, jump, power, helper, con, obj, actwise, free, idx)
        set_objective_function(jump, obj)
    end
end