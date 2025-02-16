"""
    addGenerator!(system::PowerSystem, [analysis::Analysis];
        label, bus, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive,
        lowActive, minLowReactive, maxLowReactive, upActive, minUpReactive, maxUpReactive,
        loadFollowing, reactiveRamp, reserve10min, reserve30min, area)

The function adds a new generator to the `PowerSystem` composite type. The generator can
be added to an already defined bus.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined approach circumvents the necessity
for completely reconstructing vectors and matrices when adding a new generator.

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
* `minActive` (pu or W): Minimum allowed output active power value.
* `maxActive` (pu or W): Maximum allowed output active power value.
* `minReactive` (pu or VAr): Minimum allowed output reactive power value.
* `maxReactive` (pu or VAr): Maximum allowed output reactive power value.
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

Note that voltage magnitude values are referenced to line-to-neutral voltages, while powers,
when given in SI units, correspond to three-phase power.

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
By default, the input units are associated with per-units as shown. However, users have
the option to use other units instead of per-units using the [`@power`](@ref @power)
and [`@voltage`](@ref @voltage) macros.

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
function addGenerator!(
    system::PowerSystem;
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    kwargs...
)
    gen = system.generator
    cbt = gen.capability
    rmp = gen.ramping
    def = template.generator
    key = generatorkwargs(; kwargs...)

    gen.number += 1
    setLabel(gen, label, def.label, "generator")
    busIdx = system.bus.label[getLabel(system.bus, bus, "bus")]

    add!(gen.layout.status, key.status, def.status)
    checkStatus(gen.layout.status[end])

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    add!(gen.output.active, key.active, def.active, pfx.activePower, baseInv)
    add!(gen.output.reactive, key.reactive, def.reactive, pfx.reactivePower, baseInv)

    add!(cbt.minActive, key.minActive, def.minActive, pfx.activePower, baseInv)
    add!(cbt.maxActive, key.maxActive, def.maxActive, pfx.activePower, baseInv)
    add!(cbt.minReactive, key.minReactive, def.minReactive, pfx.reactivePower, baseInv)
    add!(cbt.maxReactive, key.maxReactive, def.maxReactive, pfx.reactivePower, baseInv)
    add!(cbt.lowActive, key.lowActive, def.lowActive, pfx.activePower, baseInv)
    add!(cbt.minLowReactive, key.minLowReactive, def.minLowReactive, pfx.reactivePower, baseInv)
    add!(cbt.maxLowReactive, key.maxLowReactive, def.maxLowReactive, pfx.reactivePower, baseInv)
    add!(cbt.upActive, key.upActive, def.upActive, pfx.activePower, baseInv)
    add!(cbt.minUpReactive, key.minUpReactive, def.minUpReactive, pfx.reactivePower, baseInv)
    add!(cbt.maxUpReactive, key.maxUpReactive, def.maxUpReactive, pfx.reactivePower, baseInv)

    add!(rmp.loadFollowing, key.loadFollowing, def.loadFollowing, pfx.activePower, baseInv)
    add!(rmp.reserve10min, key.reserve10min, def.reserve10min, pfx.activePower, baseInv)
    add!(rmp.reserve30min, key.reserve30min, def.reserve30min, pfx.activePower, baseInv)
    add!(rmp.reactiveRamp, key.reactiveRamp, def.reactiveRamp, pfx.reactivePower, baseInv)

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

function addGenerator!(
    system::PowerSystem,
    analysis::Union{ACPowerFlow, DCPowerFlow};
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    kwargs...
)
    addGenerator!(system; label, bus, kwargs...)
end

function addGenerator!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable

    addGenerator!(system; label, bus, kwargs...)

    idx = gen.number

    push!(variable.active, @variable(jump, base_name = "active[$idx]"))
    push!(variable.reactive, @variable(jump, base_name = "reactive[$idx]"))

    push!(analysis.power.generator.active, gen.output.active[end])
    push!(analysis.power.generator.reactive, gen.output.reactive[end])

    if gen.layout.status[end] == 1
        updateBalance(system, analysis, gen.layout.bus[end]; active = true, reactive = true)
        addCapability(
            jump, variable.active, constr.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
        addCapability(
            jump, variable.reactive, constr.capability.reactive,
            gen.capability.minReactive, gen.capability.maxReactive, idx
        )
    else
        fix!(variable.active[idx], 0.0, constr.capability.active, idx)
        fix!(variable.reactive[idx], 0.0, constr.capability.reactive, idx)
    end
end

function addGenerator!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable

    addGenerator!(system; label, bus, kwargs...)

    idx = gen.number

    push!(variable.active, @variable(jump, base_name = "active[$idx]"))
    push!(analysis.power.generator.active, gen.output.active[end])

    if gen.layout.status[end] == 1
        updateBalance(system, analysis, gen.layout.bus[end]; power = 1, idxGen = idx)
        addCapability(
            jump, variable.active, constr.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
    else
        fix!(variable.active[idx], 0.0, constr.capability.active, idx)
    end
end

"""
    updateGenerator!(system::PowerSystem, [analysis::Analysis]; kwargs...)

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
function updateGenerator!(system::PowerSystem; label::IntStrMiss, kwargs...)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability
    rmp = gen.ramping
    key = generatorkwargs(; kwargs...)

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]

    statusNew = key.status
    statusOld = gen.layout.status[idx]

    if ismissing(statusNew)
        statusNew = copy(statusOld)
    end
    checkStatus(statusNew)

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)
    output = isset(key.active, key.reactive)

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

    update!(cbt.minActive, key.minActive, pfx.activePower, baseInv, idx)
    update!(cbt.maxActive, key.maxActive, pfx.activePower, baseInv, idx)
    update!(cbt.minReactive, key.minReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.maxReactive, key.maxReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.lowActive, key.lowActive, pfx.activePower, baseInv, idx)
    update!(cbt.minLowReactive, key.minLowReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.maxLowReactive, key.maxLowReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.upActive, key.upActive, pfx.activePower, baseInv, idx)
    update!(cbt.minUpReactive, key.minUpReactive, pfx.reactivePower, baseInv, idx)
    update!(cbt.maxUpReactive, key.maxUpReactive, pfx.reactivePower, baseInv, idx)

    update!(rmp.loadFollowing, key.loadFollowing, pfx.activePower, baseInv, idx)
    update!(rmp.reserve10min, key.reserve10min, pfx.activePower, baseInv, idx)
    update!(rmp.reserve30min, key.reserve30min, pfx.activePower, baseInv, idx)
    update!(rmp.reactiveRamp, key.reactiveRamp, pfx.reactivePower, baseInv, idx)

    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)
    update!(gen.voltage.magnitude, key.magnitude, pfx.voltageMagnitude, baseInv, idx)

    update!(gen.layout.area, key.area, idx)
end

function updateGenerator!(
    system::PowerSystem,
    analysis::Union{ACPowerFlow{NewtonRaphson}, ACPowerFlow{FastNewtonRaphson}};
    label::IntStrMiss,
    kwargs...
)
    gen = system.generator
    key = generatorkwargs(; kwargs...)

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]
    if isset(key.status)
        checkStatus(key.status)
        if key.status == 0 && system.bus.layout.type[idxBus] in [2, 3]
            if length(system.bus.supply.generator[idxBus]) == 1
                errorTypeConversion()
            end
        end
    end

    updateGenerator!(system; label, kwargs...)

    if system.bus.layout.type[idxBus] in [2, 3]
        idx = system.bus.supply.generator[idxBus][1]
        analysis.voltage.magnitude[idxBus] = gen.voltage.magnitude[idx]
    end
end

function updateGenerator!(
    system::PowerSystem,
    analysis::ACPowerFlow{GaussSeidel};
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    gen = system.generator
    key = generatorkwargs(; kwargs...)

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]
    if isset(key.status)
        checkStatus(key.status)
        if key.status == 0 && bus.layout.type[idxBus] in [2, 3]
            if length(bus.supply.generator[idxBus]) == 1
                errorTypeConversion()
            end
        end
    end

    updateGenerator!(system; label, kwargs...)

    if bus.layout.type[idxBus] in [2, 3]
        idx = bus.supply.generator[idxBus][1]
        analysis.voltage.magnitude[idxBus] = gen.voltage.magnitude[idx]
        analysis.method.voltage[idxBus] =
            gen.voltage.magnitude[idx] * cis(angle(analysis.method.voltage[idxBus]))
     end
end

function updateGenerator!(
    system::PowerSystem,
    analysis::DCPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    gen = system.generator
    key = generatorkwargs(; kwargs...)

    if isset(key.status)
        checkStatus(key.status)
        idx = gen.label[getLabel(gen, label, "generator")]
        idxBus = gen.layout.bus[idx]
        if key.status == 0 && system.bus.layout.slack == idxBus
            if length(system.bus.supply.generator[idxBus]) == 1
                errorTypeConversion()
            end
        end
    end

    updateGenerator!(system; label, kwargs...)
end

function updateGenerator!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    obj = analysis.method.objective
    key = generatorkwargs(; kwargs...)

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]
    statusOld = gen.layout.status[idx]

    costActive = gen.cost.active
    costReactive = gen.cost.reactive

    updateGenerator!(system; label, kwargs...)

    if isset(key.active)
        analysis.power.generator.active[idx] = gen.output.active[idx]
    end
    if isset(key.reactive)
        analysis.power.generator.reactive[idx] = gen.output.reactive[idx]
    end

    if statusOld == 1 && gen.layout.status[idx] == 0
        actCost, isActwise, isActNonlin = costExpr(
            costActive, variable.active[idx], idx, label; ac = true
        )
        ReactCost, isReactwise, isReactNonlin = costExpr(
            costReactive, variable.reactive[idx], idx, label; ac = true
        )

        @objective(jump, Min, 0.0)

        if isActwise
            remove!(jump, constr.piecewise.active, idx)
            add_to_expression!(obj.quadratic, -variable.actwise[idx])
            remove!(jump, variable.actwise, idx)
        else
            obj.quadratic -= actCost
        end
        if isReactwise
            remove!(jump, constr.piecewise.reactive, idx)
            add_to_expression!(obj.quadratic, -variable.reactwise[idx])
            remove!(jump, variable.reactwise, idx)
        else
            obj.quadratic -= ReactCost
        end
        drop_zeros!(obj.quadratic)

        if isActNonlin
            delete!(obj.nonlinear.active, idx)
        end
        if isReactNonlin
            delete!(obj.nonlinear.reactive, idx)
        end

        @objective(
            jump, Min,
            obj.quadratic +
            sum(obj.nonlinear.active[i] for i in keys(obj.nonlinear.active)) +
            sum(obj.nonlinear.reactive[i] for i in keys(obj.nonlinear.reactive))
        )

        remove!(jump, constr.capability.active, idx)
        remove!(jump, constr.capability.reactive, idx)
        fix!(variable.active[idx], 0.0, constr.capability.active, idx)
        fix!(variable.reactive[idx], 0.0, constr.capability.reactive, idx)
        updateBalance(system, analysis, idxBus; active = true, reactive = true)
    end

    if statusOld == 0 && gen.layout.status[idx] == 1
        actCost, isActwise, isActNonlin = costExpr(
            costActive, variable.active[idx], idx, label; ac = true
        )
        ReactCost, isReactwise, isReactNonlin = costExpr(
            costReactive, variable.reactive[idx], idx, label; ac = true
        )

        if isActwise
            addPowerwise(jump, obj.quadratic, variable.actwise, idx, "actwise")
            addPiecewise(
                jump, variable.active, variable.actwise,
                constr.piecewise.active, gen.cost.active.piecewise,
                size(gen.cost.active.piecewise[idx], 1), idx
            )
        else
            obj.quadratic += actCost
        end
        if isReactwise
            addPowerwise(jump, obj.quadratic, variable.reactwise, idx, "reactwise")
            addPiecewise(
                jump, variable.reactive, variable.reactwise,
                constr.piecewise.reactive, gen.cost.reactive.piecewise,
                size(gen.cost.reactive.piecewise[idx], 1), idx
            )
        else
            obj.quadratic += ReactCost
        end

        if isActNonlin
            term = length(costActive.polynomial[idx])
            obj.nonlinear.active[idx] = @expression(
                jump, sum(costActive.polynomial[idx][term - degree] *
                variable.active[idx]^degree for degree = term-1:-1:3)
            )
        end
        if isReactNonlin
            term = length(costReactive.polynomial[idx])
            obj.nonlinear.reactive[idx] = @expression(
                jump, sum(costReactive.polynomial[idx][term - degree] *
                variable.reactive[idx]^degree for degree = term-1:-1:3)
            )
        end

        @objective(
            jump, Min,
            obj.quadratic +
            sum(obj.nonlinear.active[i] for i in keys(obj.nonlinear.active)) +
            sum(obj.nonlinear.reactive[i] for i in keys(obj.nonlinear.reactive))
        )

        remove!(jump, constr.capability.active, idx)
        remove!(jump, constr.capability.reactive, idx)
        addCapability(
            jump, variable.active, constr.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
        addCapability(
            jump, variable.reactive, constr.capability.reactive,
            gen.capability.minReactive, gen.capability.maxReactive, idx
        )
        updateBalance(system, analysis, idxBus; active = true, reactive = true)
    end

    if statusOld == 1 && gen.layout.status[idx] == 1
        if isset(key.minActive, key.maxActive)
            remove!(jump, constr.capability.active, idx)
            addCapability(
                jump, variable.active, constr.capability.active,
                gen.capability.minActive, gen.capability.maxActive, idx
            )
        end
        if isset(key.minReactive, key.maxReactive)
            remove!(jump, constr.capability.reactive, idx)
            addCapability(
                jump, variable.reactive, constr.capability.reactive,
                gen.capability.minReactive, gen.capability.maxReactive, idx
            )
        end
    end
end

function updateGenerator!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    key = generatorkwargs(; kwargs...)

    idx = gen.label[getLabel(gen, label, "generator")]
    idxBus = gen.layout.bus[idx]
    statusOld = gen.layout.status[idx]

    updateGenerator!(system; label, kwargs...)

    if isset(key.active)
        analysis.power.gen.active[idx] = gen.output.active[idx]
    end

    if statusOld == 1 && gen.layout.status[idx] == 0
        cost, isPowerwise = costExpr(gen.cost.active, variable.active[idx], idx, label)

        if isPowerwise
            remove!(jump, constr.piecewise.active, idx)
            add_to_expression!(analysis.method.objective, -variable.actwise[idx])
            remove!(jump, variable.actwise, idx)
        else
            analysis.method.objective -= cost
        end
        drop_zeros!(analysis.method.objective)
        set_objective_function(jump, analysis.method.objective)

        remove!(jump, constr.capability.active, idx)
        updateBalance(system, analysis, idxBus; power = 0, idxGen = idx)
        fix!(variable.active[idx], 0.0, constr.capability.active, idx)
    end

    if statusOld == 0 && gen.layout.status[idx] == 1
        cost, isPowerwise = costExpr(gen.cost.active, variable.active[idx], idx, label)

        if isPowerwise
            addPowerwise(jump, analysis.method.objective, variable.actwise, idx, "actwise")
            addPiecewise(
                jump, variable.active, variable.actwise,
                constr.piecewise.active, gen.cost.active.piecewise,
                size(gen.cost.active.piecewise[idx], 1), idx
            )
        else
            analysis.method.objective += cost
        end
        set_objective_function(jump, analysis.method.objective)

        updateBalance(system, analysis, idxBus; power = 1, idxGen = idx)
        remove!(jump, constr.capability.active, idx)
        addCapability(
            jump, variable.active, constr.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
    end

    if statusOld == 1 && gen.layout.status[idx] == 1 && isset(key.minActive, key.maxActive)
        remove!(jump, constr.capability.active, idx)
        addCapability(
            jump, variable.active, constr.capability.active,
            gen.capability.minActive, gen.capability.maxActive, idx
        )
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
By default, the input units are associated with per-units as shown. However, users have
the option to use other units instead of per-units using the [`@power`](@ref @power) and
[`@voltage`](@ref @voltage) macros.

# Examples
Adding a generator using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.25, reactive = -0.04, base = 132e3)

@generator(magnitude = 1.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5, reactive = 0.1)
```

Adding a generator using a custom unit system:
```jldoctest
@power(MW, MVAr)
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

        if hasfield(GeneratorTemplate, parameter)
            if !(parameter in [:area; :status; :label])
                container::ContainerTemplate = getfield(template.generator, parameter)

                if parameter in [
                    :active; :minActive; :maxActive; :lowActive; :upActive;
                    :loadFollowing; :reserve10min; :reserve30min
                    ]
                    pfxLive = pfx.activePower
                elseif parameter in [
                    :reactive; :minReactive; :maxReactive; :minLowReactive;
                    :maxLowReactive; :minUpReactive; :maxUpReactive; :reactiveRamp
                    ]
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
                    label = string(kwarg.args[2])
                    if contains(label, "?")
                        setfield!(template.generator, parameter, label)
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

"""
    cost!(system::PowerSystem, [analysis::Analysis];
        generator, active, reactive, piecewise, polynomial)

The function either adds a new cost or modifies an existing one for the active or reactive
power generated by the corresponding generator within the `PowerSystem` composite type.
It has the capability to append a cost to an already defined generator.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined approach circumvents the necessity
for completely reconstructing vectors and matrices when adding a new branch.

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
  * second column (\$/hr): cost for the specified active or reactive power output.
* `polynomial`: The n-th degree polynomial coefficients given as `Vector{Float64}`:
  * first element (\$/puⁿ-hr, \$/Wⁿhr or \$/VArⁿ-hr): coefficient of the n-th degree term, ....,
  * penultimate element (\$/pu-hr, \$/W-hr or \$/VAr-hr): coefficient of the first degree term,
  * last element (\$/hr): constant coefficient.

# Updates
The function updates the `generator.cost` field within the `PowerSystem` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

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
function cost!(
    system::PowerSystem;
    generator::IntStrMiss,
    active::FltIntMiss = missing,
    reactive::FltIntMiss = missing,
    polynomial::Vector{Float64} = Float64[],
    piecewise::Matrix{Float64} = Array{Float64}(undef, 0, 0)
)
    if isset(active) && isset(reactive)
        throw(ErrorException(
            "The concurrent definition of the keywords " *
            "active and reactive is not allowed.")
        )
    elseif ismissing(active) && ismissing(reactive)
        throw(ErrorException("The cost model is missing."))
    elseif isset(active) && !(active in [1; 2]) || isset(reactive) && !(reactive in [1; 2])
        throw(ErrorException(
            "The model is not allowed; it should be piecewise (1) or polynomial (2).")
        )
    end

    idx = system.generator.label[getLabel(system.generator, generator, "generator")]

    if isset(active)
        container = system.generator.cost.active
        container.model[idx] = active
        if pfx.activePower == 0.0
            scale = 1.0
        else
            scale = pfx.activePower / (system.base.power.prefix * system.base.power.value)
        end
    elseif isset(reactive)
        container = system.generator.cost.reactive
        container.model[idx] = reactive
        if pfx.reactivePower == 0.0
            scale = 1.0
        else
            scale = pfx.reactivePower / (system.base.power.prefix * system.base.power.value)
        end
    end

    if container.model[idx] == 1 && isempty(piecewise) && !haskey(container.piecewise, idx)
        errorAssignCost("piecewise")
    end
    if container.model[idx] == 2 && isempty(polynomial) && !haskey(container.polynomial, idx)
        errorAssignCost("polynomial")
    end

    if !isempty(polynomial)
        numCoeff = length(polynomial)
        container.polynomial[idx] = fill(0.0, numCoeff)

        @inbounds for i = 1:numCoeff
            container.polynomial[idx][i] = polynomial[i] / (scale^(numCoeff - i))
        end
    end

    if !isempty(piecewise)
        container.piecewise[idx] = [scale .* piecewise[:, 1] piecewise[:, 2]]
    end
end

function cost!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    generator::IntStrMiss,
    active::FltIntMiss = missing,
    reactive::FltIntMiss = missing,
    polynomial::Vector{Float64} = Float64[],
    piecewise::Matrix{Float64} = Array{Float64}(undef, 0, 0)
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    obj = analysis.method.objective

    dropZero = false
    idx = gen.label[getLabel(gen, generator, "generator")]

    if gen.layout.status[idx] == 1
        actCost, isActwiseOld, isActNonlin = costExpr(
            gen.cost.active, variable.active[idx], idx, generator; ac = true
        )
        reactCost, isReactwisOld, isReactNonlin = costExpr(
            gen.cost.reactive, variable.reactive[idx], idx, generator; ac = true
        )

        @objective(jump, Min, 0.0)

        if isActwiseOld
            remove!(jump, constr.piecewise.active, idx)
        else
            dropZero = true
            obj.quadratic -= actCost
        end
        if isReactwisOld
            remove!(jump, constr.piecewise.reactive, idx)
        else
            dropZero = true
            obj.quadratic -= reactCost
        end

        if isActNonlin
            delete!(obj.nonlinear.active, idx)
        end
        if isReactNonlin
            delete!(obj.nonlinear.reactive, idx)
        end
    end

    cost!(system; generator, active, reactive, polynomial, piecewise)

    if gen.layout.status[idx] == 1
        actCost, isActwiseNew, isActNonlin = costExpr(
            gen.cost.active, variable.active[idx], idx, generator; ac = true
        )
        reactCost, isReactwiseNew, isReactNonlin = costExpr(
            gen.cost.reactive, variable.reactive[idx], idx, generator; ac = true
        )

        if isActwiseNew
            if !isActwiseOld
                addPowerwise(jump, obj.quadratic, variable.actwise, idx, "actwise")
            end
            addPiecewise(
                jump, variable.active, variable.actwise,
                constr.piecewise.active, gen.cost.active.piecewise,
                size(gen.cost.active.piecewise[idx], 1), idx
            )
        else
            if isActwiseOld
                dropZero = true
                add_to_expression!(obj.quadratic, -variable.actwise[idx])
                remove!(jump, variable.actwise, idx)
            end
            obj.quadratic += actCost
        end

        if isReactwiseNew
            if !isReactwisOld
                addPowerwise(jump, obj.quadratic, variable.reactwise, idx, "reactwise")
            end
            addPiecewise(
                jump, variable.reactive, variable.reactwise,
                constr.piecewise.reactive, gen.cost.reactive.piecewise,
                size(gen.cost.reactive.piecewise[idx], 1), idx
            )
        else
            if isReactwisOld
                dropZero = true
                add_to_expression!(obj.quadratic, -variable.reactwise[idx])
                remove!(jump, variable.reactwise, idx)
            end
            obj.quadratic += reactCost
        end

        if isActNonlin
            delete!(obj.nonlinear.active, idx)
            term = length(gen.cost.active.polynomial[idx])
            obj.nonlinear.active[idx] = @expression(
                jump, sum(gen.cost.active.polynomial[idx][term - degree] *
                variable.active[idx]^degree for degree = term-1:-1:3)
            )
        end
        if isReactNonlin
            delete!(obj.nonlinear.reactive, idx)
            term = length(gen.cost.reactive.polynomial[idx])
            obj.nonlinear.reactive[idx] = @expression(
                jump, sum(gen.cost.reactive.polynomial[idx][term - degree] *
                variable.reactive[idx]^degree for degree = term-1:-1:3)
            )
        end
    end

    if dropZero
        drop_zeros!(obj.quadratic)
    end

    @objective(
        jump, Min,
        obj.quadratic +
        sum(obj.nonlinear.active[i] for i in keys(obj.nonlinear.active)) +
        sum(obj.nonlinear.reactive[i] for i in keys(obj.nonlinear.reactive))
    )
end

function cost!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    generator::IntStrMiss,
    active::FltIntMiss = missing,
    reactive::FltIntMiss = missing,
    polynomial::Vector{Float64} = Float64[],
    piecewise::Matrix{Float64} = Array{Float64}(undef, 0, 0)
)
    gen = system.generator
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable

    dropZero = false
    idx = gen.label[getLabel(gen, generator, "generator")]

    if gen.layout.status[idx] == 1
        costOld, isPowerwiseOld = costExpr(gen.cost.active, variable.active[idx], idx, generator)

        if isPowerwiseOld
            remove!(jump, constr.piecewise.active, idx)
        else
            dropZero = true
            analysis.method.objective -= costOld
        end
    end

    cost!(system; generator, active, reactive, polynomial, piecewise)

    if gen.layout.status[idx] == 1
        costNew, isWiseNew = costExpr(gen.cost.active, variable.active[idx], idx, generator)

        if isWiseNew
            if !isPowerwiseOld
                addPowerwise(
                    jump, analysis.method.objective,
                    variable.actwise, idx, "actwise"
                )
            end
            addPiecewise(
                jump, variable.active, variable.actwise,
                constr.piecewise.active, gen.cost.active.piecewise,
                size(gen.cost.active.piecewise[idx], 1), idx
            )
        else
            if isPowerwiseOld
                dropZero = true
                add_to_expression!(analysis.method.objective, -variable.actwise[idx])
                remove!(jump, variable.actwise, idx)
            end
            analysis.method.objective += costNew
        end
    end

    if dropZero
        drop_zeros!(analysis.method.objective)
    end
    set_objective_function(jump, analysis.method.objective)
end

##### Generator Keywords #####
function generatorkwargs(;
    area::IntMiss = missing,
    status::IntMiss = missing,
    active::FltIntMiss = missing,
    reactive::FltIntMiss = missing,
    magnitude::FltIntMiss = missing,
    minActive::FltIntMiss = missing,
    maxActive::FltIntMiss = missing,
    minReactive::FltIntMiss = missing,
    maxReactive::FltIntMiss = missing,
    lowActive::FltIntMiss = missing,
    minLowReactive::FltIntMiss = missing,
    maxLowReactive::FltIntMiss = missing,
    upActive::FltIntMiss = missing,
    minUpReactive::FltIntMiss = missing,
    maxUpReactive::FltIntMiss = missing,
    loadFollowing::FltIntMiss = missing,
    reserve10min::FltIntMiss = missing,
    reserve30min::FltIntMiss = missing,
    reactiveRamp::FltIntMiss = missing
)
    (
    area = area, status = status, magnitude = magnitude,
    active = active, reactive = reactive,
    minActive = minActive, maxActive = maxActive,
    minReactive = minReactive, maxReactive = maxReactive,
    lowActive = lowActive, upActive = upActive,
    minLowReactive = minLowReactive, maxLowReactive = maxLowReactive,
    minUpReactive = minUpReactive, maxUpReactive = maxUpReactive,
    loadFollowing = loadFollowing, reactiveRamp = reactiveRamp,
    reserve10min = reserve10min, reserve30min = reserve30min,
    )
end