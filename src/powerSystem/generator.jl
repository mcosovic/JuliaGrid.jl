"""
    addGenerator!(system::PowerSystem;
        label, bus, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive,
        lowActive, minLowReactive, maxLowReactive, upActive, minUpReactive, maxUpReactive)

The function adds a new generator to the `PowerSystem` type. The generator can be added to an already
defined bus.

# Keywords
The main keywords used to define a generator are:
* `label`: Unique label for the generator.
* `bus`: Label of the bus to which the generator is connected.
* `status`: Operating status of the generator:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.
* `active` (pu or W): Output active power.
* `reactive` (pu or VAr): Output reactive power.
* `magnitude` (pu or V): Voltage magnitude setpoint.
* `minReactive` (pu or VAr): Minimum allowed reactive power output value.
* `maxReactive` (pu or VAr): Maximum allowed reactive power output value.

The following keywords are used only in optimal power flow analyses:
* `minActive` (pu or W): Minimum allowed active power output value.
* `maxActive` (pu or W): Maximum allowed active power output value.
* `lowActive` (pu or W): Lower allowed active power output value of PQ capability curve.
* `minLowReactive` (pu or VAr): Minimum allowed reactive power output value at `lowActive` value.
* `maxLowReactive` (pu or VAr): Maximum allowed reactive power output value at `lowActive` value.
* `upActive` (pu or W): Upper allowed active power output value of PQ capability curve.
* `minUpReactive` (pu or VAr): Minimum allowed reactive power output value at `upActive` value.
* `maxUpReactive` (pu or VAr): Maximum allowed reactive power output value at `upActive` value.

Note that voltage magnitude values are referenced to line-to-neutral voltages, while powers, when
given in SI units, correspond to three-phase power.

# Updates
The function updates the `generator` field within the `PowerSystem` type, and in cases where
parameters impact variables in the `bus` field, it automatically adjusts the field.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `magnitude = 1.0`,
`maxActive = 5 active`, `minReactive = -5 reactive`, and `maxReactive = 5 reactive`. The rest of the
keywords are initialized with a value of zero. However, the user can modify these default settings
using the [`@generator`](@ref @generator) macro.

# Units
By default, the input units are associated with per-unit values as shown. However, users can use
units other than per-unit values using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage)
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

    return nothing
end

function addGeneratorMain!(system::PowerSystem, bus::IntStr, key::GeneratorKey)
    gen = system.generator
    cbt = gen.capability
    def = template.generator

    idx = gen.number + 1
    setLabel(gen, idx, key.label, def.label, "generator")
    busIdx = getIndex(system.bus, bus, "bus")

    statusNew = coalesce(key.status, def.status)
    checkStatus(statusNew)

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    add!(gen.output.active, key.active, def.active, pfx.activePower, baseInv)
    add!(gen.output.reactive, key.reactive, def.reactive, pfx.reactivePower, baseInv)

    add!(cbt.minReactive, key.minReactive, def.minReactive, pfx.reactivePower, baseInv, -gen.output.reactive[end])
    add!(cbt.maxReactive, key.maxReactive, def.maxReactive, pfx.reactivePower, baseInv, gen.output.reactive[end])

    if system.bus.layout.optimal
        add!(cbt.minActive, key.minActive, def.minActive, pfx.activePower, baseInv, 0.0)
        add!(cbt.maxActive, key.maxActive, def.maxActive, pfx.activePower, baseInv, gen.output.active[end])

        add!(cbt.lowActive, key.lowActive, def.lowActive, pfx.activePower, baseInv)
        add!(cbt.minLowReactive, key.minLowReactive, def.minLowReactive, pfx.reactivePower, baseInv)
        add!(cbt.maxLowReactive, key.maxLowReactive, def.maxLowReactive, pfx.reactivePower, baseInv)
        add!(cbt.upActive, key.upActive, def.upActive, pfx.activePower, baseInv)
        add!(cbt.minUpReactive, key.minUpReactive, def.minUpReactive, pfx.reactivePower, baseInv)
        add!(cbt.maxUpReactive, key.maxUpReactive, def.maxUpReactive, pfx.reactivePower, baseInv)
    end

    push!(gen.layout.status, statusNew)

    if statusNew == 1
        addGenInBus!(system, busIdx, idx)
        gen.layout.inservice += 1

        system.bus.supply.active[busIdx] += gen.output.active[end]
        system.bus.supply.reactive[busIdx] += gen.output.reactive[end]
    end

    baseInv = sqrt(3) / (system.base.voltage.value[busIdx] * system.base.voltage.prefix)
    add!(gen.voltage.magnitude, key.magnitude, def.magnitude, pfx.voltageMagnitude, baseInv)

    push!(gen.layout.bus, busIdx)

    push!(gen.cost.active.model, 0)
    push!(gen.cost.reactive.model, 0)

    gen.number = idx
    topologyChanged!(system)

    return nothing
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
    syncTopology!(analysis)

    return nothing
end

function _addGenerator!(analysis::AcPowerFlow)
    errorTypeConversion(analysis.system.model.revision.type, analysis.method.signature.type)
end

function _addGenerator!(analysis::DcPowerFlow)
    errorTypeConversion(analysis.system.model.revision.slack, analysis.method.signature.slack)
end

function _addGenerator!(analysis::AcOptimalPowerFlow)
    system = analysis.system
    gen = system.generator
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual
    cbt = system.generator.capability

    idx = gen.number
    idxBus = gen.layout.bus[end]

    add!(jump, var.power.active, cbt.minActive, cbt.maxActive, jump.ext[:active], idx)
    add!(jump, var.power.reactive, cbt.minReactive, cbt.maxReactive, jump.ext[:reactive], idx)

    push!(analysis.power.generator.active, gen.output.active[end])
    push!(analysis.power.generator.reactive, gen.output.reactive[end])

    if gen.layout.status[end] == 1
        capabilityCurve(system, jump, var, con, idx)

        setConstraint!(var.power.active, con.capability.active, cbt.minActive, cbt.maxActive, idx)
        setConstraint!(var.power.reactive, con.capability.reactive, cbt.minReactive, cbt.maxReactive, idx)
    else
        fix!(var.power.active[idx], 0.0, con.capability.active, idx; force = true)
        fix!(var.power.reactive[idx], 0.0, con.capability.reactive, idx; force = true)
    end

    remove!(jump, moi, con.balance.active, dual.balance.active, idxBus)
    remove!(jump, moi, con.balance.reactive, dual.balance.reactive, idxBus)
    addBalance(system, jump, var, con, idxBus)

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.acOptimization = revision.acOptimization
end

function _addGenerator!(analysis::DcOptimalPowerFlow)
    system = analysis.system
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    cbt = system.generator.capability

    idx = system.generator.number
    idxBus = system.generator.layout.bus[end]

    add!(jump, var.power.active, cbt.minActive, cbt.maxActive, jump.ext[:active], idx)
    push!(analysis.power.generator.active, system.generator.output.active[end])

    if system.generator.layout.status[end] == 1
        setConstraint!(var.power.active, con.capability.active, cbt.minActive, cbt.maxActive, idx)
    else
        fix!(var.power.active[idx], 0.0, con.capability.active, idx; force = true)
    end

    remove!(jump, moi, con.balance.active, analysis.method.dual.balance.active, idxBus)
    addBalance(system, jump, var, con, AffExpr(), idxBus)

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.dcOptimization = revision.dcOptimization
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

    return nothing
end

function updateGeneratorMain!(system::PowerSystem, label::IntStr, key::GeneratorKey)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability

    idx = getIndex(gen, label, "generator")
    idxBus = gen.layout.bus[idx]

    statusNew = key.status
    statusOld = gen.layout.status[idx]

    if ismissing(statusNew)
        statusNew = statusOld
    end
    checkStatus(statusNew)

    active = isset(key.active) || isset(key.minActive) || isset(key.maxActive)
    reactive = (
        isset(key.reactive) || isset(key.minReactive) || isset(key.maxReactive) ||
        isset(key.lowActive) || isset(key.upActive) || isset(key.minLowReactive) ||
        isset(key.maxLowReactive) || isset(key.minUpReactive) || isset(key.maxUpReactive)
    )

    if statusNew != statusOld || active
        optimizationChanged!(system)
    end
    if reactive
        acOptimizationChanged!(system)
    end

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
                    if isempty(bus.supply.generator[idxBus])
                        delete!(bus.supply.generator, idxBus)
                    end
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

    update!(cbt.minReactive, key.minReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.maxReactive, key.maxReactive, pfx.reactivePower, baseInv, idx)

    if system.bus.layout.optimal
        update!(cbt.minActive, key.minActive, pfx.activePower, baseInv, idx)
        update!(cbt.maxActive, key.maxActive, pfx.activePower, baseInv, idx)
        update!(cbt.lowActive, key.lowActive, pfx.activePower, baseInv, idx)
        update!(cbt.minLowReactive, key.minLowReactive, pfx.reactivePower, baseInv, idx)
        update!(cbt.maxLowReactive, key.maxLowReactive, pfx.reactivePower, baseInv, idx)
        update!(cbt.upActive, key.upActive, pfx.activePower, baseInv, idx)
        update!(cbt.minUpReactive, key.minUpReactive, pfx.reactivePower, baseInv, idx)
        update!(cbt.maxUpReactive, key.maxUpReactive, pfx.reactivePower, baseInv, idx)
    end

    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)
    update!(gen.voltage.magnitude, key.magnitude, pfx.voltageMagnitude, baseInv, idx)

    return nothing
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

addGenerator!(analysis; bus = "Bus 1 HV", active = 0.5, reactive = 0.2)
```
"""
function updateGenerator!(analysis::PowerFlow; label::IntStr, kwargs...)
    updateGeneratorMain!(analysis.system, label, GeneratorKey(; kwargs...))
    _updateGenerator!(analysis, getIndex(analysis.system.generator, label, "generator"))
    syncTopology!(analysis)

    return nothing
end

function _updateGenerator!(analysis::AcPowerFlow{<:Union{NewtonRaphson, FastNewtonRaphson}}, idx::Int64)
    system = analysis.system
    gen = system.generator

    errorTypeConversion(system.model.revision.type, analysis.method.signature.type)

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

    errorTypeConversion(system.model.revision.type, analysis.method.signature.type)

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

    errorTypeConversion(system.model.revision.slack, analysis.method.signature.slack)

    idxBus = gen.layout.bus[idx]

    if gen.layout.status[idx] == 0 && system.bus.layout.slack == idxBus
        if length(system.bus.supply.generator[idxBus]) == 0
            errorTypeConversion()
        end
    end
end

function _updateGenerator!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    gen = system.generator
    cbt = gen.capability

    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual
    obj = analysis.method.objective
    quad = analysis.method.objective.quadratic

    P = var.power.active
    Q = var.power.reactive
    H = var.power.actwise
    G = var.power.reactwise

    freeP = analysis.method.signature.freeP
    freeQ = analysis.method.signature.freeQ

    idxBus = gen.layout.bus[idx]

    if lastindex(analysis.power.generator.active) == gen.number
        analysis.power.generator.active[idx] = gen.output.active[idx]
        analysis.power.generator.reactive[idx] = gen.output.reactive[idx]

        remove!(jump, moi, con.capability.active, dual.capability.active, idx)
        remove!(jump, moi, con.capability.reactive, dual.capability.reactive, idx)

        setBound!(P, cbt.minActive, cbt.maxActive, idx)
        setBound!(Q, cbt.minReactive, cbt.maxReactive, idx)
    else
        add!(jump, P, cbt.minActive, cbt.maxActive, jump.ext[:active], idx)
        add!(jump,Q, cbt.minReactive, cbt.maxReactive, jump.ext[:reactive], idx)
        push!(analysis.power.generator.active, gen.output.active[idx])
        push!(analysis.power.generator.reactive, gen.output.reactive[idx])
    end

    remove!(jump, moi, con.capability.lower, dual.capability.lower, idx)
    remove!(jump, moi, con.capability.upper, dual.capability.upper, idx)

    @objective(jump, Min, 0.0)

    removeObjective!(jump, moi, P, H, con.piecewise.active, dual.piecewise.active, quad, freeP, idx)
    removeObjective!(jump, moi, Q, G, con.piecewise.reactive, dual.piecewise.reactive, quad, freeQ, idx)
    removeNonlinear!(analysis.method.objective, idx)

    if gen.layout.status[idx] == 1
        addObjective(system, jump, var, con, obj, freeP, freeQ, idx)

        capabilityCurve(system, jump, var, con, idx)
        setConstraint!(P, con.capability.active, cbt.minActive, cbt.maxActive, idx)
        setConstraint!(Q, con.capability.reactive, cbt.minReactive, cbt.maxReactive, idx)
    else
        fix!(P[idx], 0.0, con.capability.active, idx; force = true)
        fix!(Q[idx], 0.0, con.capability.reactive, idx; force = true)
    end

    setObjective(jump, obj)

    remove!(jump, moi, con.balance.active, dual.balance.active, idxBus)
    remove!(jump, moi, con.balance.reactive, dual.balance.reactive, idxBus)
    addBalance(system, jump, var, con, idxBus)

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.acOptimization = revision.acOptimization
end

function _updateGenerator!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    gen = system.generator
    cbt = gen.capability
    cost = gen.cost.active

    jump = analysis.method.jump
    moi = backend(jump)
    power = analysis.method.variable.power.active
    helper = analysis.method.variable.power.actwise
    con = analysis.method.constraint
    dual = analysis.method.dual
    obj = analysis.method.objective

    free = analysis.method.signature.free
    actwise = jump.ext[:actwise]

    idxBus = gen.layout.bus[idx]

    if lastindex(analysis.power.generator.active) == gen.number
        analysis.power.generator.active[idx] = gen.output.active[idx]

        remove!(jump, moi, con.capability.active, dual.capability.active, idx)
        setBound!(power, cbt.minActive, cbt.maxActive, idx)
    else
        add!(jump, power, cbt.minActive, cbt.maxActive, jump.ext[:active], idx)
        push!(analysis.power.generator.active, gen.output.active[idx])
    end

    removeObjective!(jump, moi, power, helper, con.piecewise.active, dual.piecewise.active, obj, free, idx)

    if gen.layout.status[idx] == 1
        addObjective(system, cost, jump, power, helper, con, obj, free, idx)
        setConstraint!(power, con.capability.active, cbt.minActive, cbt.maxActive, idx)
    else
        fix!(power[idx], 0.0, con.capability.active, idx; force = true)
    end

    set_objective_function(jump, obj)

    remove!(jump, moi, con.balance.active, analysis.method.dual.balance.active, idxBus)
    addBalance(system, jump, analysis.method.variable, con, AffExpr(), idxBus)

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.dcOptimization = revision.dcOptimization
end

function generatorTemplatePrefix(parameter::Symbol)
    if parameter in (:active, :minActive, :maxActive, :lowActive, :upActive)
        return pfx.activePower
    elseif parameter in (
        :reactive, :minReactive, :maxReactive, :minLowReactive,
        :maxLowReactive, :minUpReactive, :maxUpReactive
        )
        return pfx.reactivePower
    elseif parameter == :magnitude
        return pfx.voltageMagnitude
    end
end

function setGeneratorTemplate!(parameter::Symbol, value)
    if hasfield(GeneratorTemplate, parameter)
        if parameter ∉ (:status, :label)
            container::ContainerTemplate = getfield(template.generator, parameter)
            setContainerTemplate!(container, value, generatorTemplatePrefix(parameter))
        elseif parameter == :status
            setfield!(template.generator, parameter, Int8(value))
        elseif parameter == :label
            macroLabel(template.generator, value, "[?]")
        end
    else
        errorTemplateKeyword(parameter)
    end

    return nothing
end

"""
    @generator(kwargs...)

The macro generates a template for a generator.

The macro modifies global JuliaGrid settings that remain active until changed again.

# Keywords
To define the generator template, the `kwargs` input arguments must be provided in accordance with
the keywords specified within the [`addGenerator!`](@ref addGenerator!) function, along with their
corresponding values.

# Units
By default, the input units are associated with per-unit values. However, users can use units other
than per-unit values using the [`@power`](@ref @power) and [`@voltage`](@ref @voltage)
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
    exprs = map(kwargs) do kwarg
        if !(kwarg isa Expr) || kwarg.head != :(=)
            return :(errorTemplateKeyword($(QuoteNode(kwarg))))
        end

        parameter = kwarg.args[1]
        value = kwarg.args[2]

        :(setGeneratorTemplate!($(QuoteNode(parameter)), $(esc(value))))
    end

    return Expr(:block, exprs...)
end

"""
    cost!(system::PowerSystem; generator, active, reactive, piecewise, polynomial)

The function either adds a new cost or modifies an existing one for the active or reactive power
generated by the corresponding generator within the `PowerSystem` type. It can append a cost to an
already defined generator.

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
By default, the input units related to active powers are per-unit values, but they can be
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
    if system.bus.layout.optimal
        costMain!(system, generator, CostKey(; kwargs...))
    end

    return nothing
end

function costMain!(system::PowerSystem, generator::IntStr, key::CostKey)
    if isset(key.active) && isset(key.reactive)
        throw(ErrorException(
            "The concurrent definition of the keywords active and reactive is not allowed.")
        )
    elseif ismissing(key.active) && ismissing(key.reactive)
        throw(ErrorException("The cost model is missing."))
    elseif (isset(key.active) && key.active ∉ (1, 2)) ||
           (isset(key.reactive) && key.reactive ∉ (1, 2))
        throw(ErrorException(
            "The model is not allowed; it should be piecewise (1) or polynomial (2).")
        )
    end

    idx = getIndex(system.generator, generator, "generator")

    if isset(key.active)
        container = system.generator.cost.active
        model = key.active
        if pfx.activePower == 0.0
            scale = 1.0
        else
            scale = pfx.activePower / (system.base.power.prefix * system.base.power.value)
        end
    elseif isset(key.reactive)
        container = system.generator.cost.reactive
        model = key.reactive
        if pfx.reactivePower == 0.0
            scale = 1.0
        else
            scale = pfx.reactivePower / (system.base.power.prefix * system.base.power.value)
        end
    end

    if model == 1 && isempty(key.piecewise) && !haskey(container.piecewise, idx)
        errorAssignCost("piecewise")
    end
    if model == 2 && isempty(key.polynomial) && !haskey(container.polynomial, idx)
        errorAssignCost("polynomial")
    end

    if isset(key.active)
        optimizationChanged!(system)
    elseif isset(key.reactive)
        acOptimizationChanged!(system)
    end
    container.model[idx] = model

    if !isempty(key.polynomial)
        numCoeff = lastindex(key.polynomial)
        polynomial = Vector{Float64}(undef, numCoeff)

        @inbounds for i = 1:numCoeff
            polynomial[i] = key.polynomial[i] / (scale^(numCoeff - i))
        end
        container.polynomial[idx] = polynomial
    end

    if !isempty(key.piecewise)
        rows = size(key.piecewise, 1)
        piecewise = Matrix{Float64}(undef, rows, 2)

        @inbounds for i = 1:rows
            piecewise[i, 1] = scale * key.piecewise[i, 1]
            piecewise[i, 2] = key.piecewise[i, 2]
        end
        container.piecewise[idx] = piecewise
    end

    return nothing
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

    return nothing
end

function _cost!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system

    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual.piecewise
    obj = analysis.method.objective

    P = var.power.active
    Q = var.power.reactive
    H = var.power.actwise
    G = var.power.reactwise

    freeP = analysis.method.signature.freeP
    freeQ = analysis.method.signature.freeQ

    if system.generator.layout.status[idx] == 1
        @objective(jump, Min, 0.0)

        removeObjective!(jump, moi, P, H, con.piecewise.active, dual.active, obj.quadratic, freeP, idx)
        removeObjective!(jump, moi, Q, G, con.piecewise.reactive, dual.reactive, obj.quadratic, freeQ, idx)
        removeNonlinear!(analysis.method.objective, idx)

        addObjective(system, jump, var, con, obj, freeP, freeQ, idx)
    end

    setObjective(jump, obj)

    analysis.method.signature.acOptimization = system.model.revision.acOptimization
end

function _cost!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    cost = system.generator.cost.active

    jump = analysis.method.jump
    moi = backend(jump)
    power = analysis.method.variable.power.active
    helper = analysis.method.variable.power.actwise
    con = analysis.method.constraint
    dual = analysis.method.dual.piecewise
    obj = analysis.method.objective

    free = analysis.method.signature.free
    actwise = jump.ext[:actwise]

    if system.generator.layout.status[idx] == 1
        removeObjective!(jump, moi, power, helper, con.piecewise.active, dual.active, obj, free, idx)

        addObjective(system, cost, jump, power, helper, con, obj, free, idx)
        set_objective_function(jump, obj)
    end

    analysis.method.signature.dcOptimization = system.model.revision.dcOptimization
end