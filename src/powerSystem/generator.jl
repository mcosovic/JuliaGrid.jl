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
* `minLowReactive` (pu or VAr): minimum allowed reactive power output value at `lowActive` value;
* `maxLowReactive` (pu or VAr): maximum allowed reactive power output value at `lowActive` value;
* `upActive` (pu or W): upper allowed active power output value of PQ capability curve;
* `minUpReactive` (pu or VAr): minimum allowed reactive power output value at `upActive` value;
* `maxUpReactive` (pu or VAr): maximum allowed reactive power output value at `upActive` value;
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
Adding a generator using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.2, base = 132e3)

addGenerator!(system; bus = "Bus 1", active = 0.5, magnitude = 1.1)
```

Adding a generator using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
@voltage(kV, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 20, base = 132)

addGenerator!(system; bus = "Bus 1", active = 50, magnitude = 145.2)
```
"""
function addGenerator!(system::PowerSystem;
    label::L = missing, bus::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    generator = system.generator
    default = template.generator

    system.generator.number += 1
    setLabel(generator, label, default.label, "generator")

    busIndex = system.bus.label[getLabel(system.bus, bus, "bus")]

    push!(generator.layout.status, unitless(status, default.status))
    checkStatus(generator.layout.status[end])

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltageInv = 1 / (system.base.voltage.value[busIndex] * system.base.voltage.prefix)

    push!(generator.output.active, topu(active, default.active, prefix.activePower, basePowerInv))
    push!(generator.output.reactive, topu(reactive, default.reactive, prefix.reactivePower, basePowerInv))

    if generator.layout.status[end] == 1
        push!(system.bus.supply.generator[busIndex], generator.number)
        system.bus.supply.active[busIndex] += generator.output.active[end]
        system.bus.supply.reactive[busIndex] += generator.output.reactive[end]
        generator.layout.inservice += 1
    end

    push!(generator.capability.minActive, topu(minActive, default.minActive, prefix.activePower, basePowerInv))
    push!(generator.capability.maxActive, topu(maxActive, default.maxActive, prefix.activePower, basePowerInv))

    push!(generator.capability.minReactive, topu(minReactive, default.minReactive, prefix.reactivePower, basePowerInv))
    push!(generator.capability.maxReactive, topu(maxReactive, default.maxReactive, prefix.reactivePower, basePowerInv))

    push!(generator.capability.lowActive, topu(lowActive, default.lowActive, prefix.activePower, basePowerInv))
    push!(generator.capability.minLowReactive, topu(minLowReactive, default.minLowReactive, prefix.reactivePower, basePowerInv))
    push!(generator.capability.maxLowReactive, topu(maxLowReactive, default.maxLowReactive, prefix.reactivePower, basePowerInv))

    push!(generator.capability.upActive, topu(upActive, default.upActive, prefix.activePower, basePowerInv))
    push!(generator.capability.minUpReactive, topu(minUpReactive, default.minUpReactive, prefix.reactivePower, basePowerInv))
    push!(generator.capability.maxUpReactive, topu(maxUpReactive, default.maxUpReactive, prefix.reactivePower, basePowerInv))

    push!(generator.ramping.loadFollowing, topu(loadFollowing, default.loadFollowing, prefix.activePower, basePowerInv))
    push!(generator.ramping.reserve10min, topu(reserve10min, default.reserve10min, prefix.activePower, basePowerInv))
    push!(generator.ramping.reserve30min, topu(reserve30min, default.reserve30min, prefix.activePower, basePowerInv))
    push!(generator.ramping.reactiveTimescale, topu(reactiveTimescale, default.reactiveTimescale, prefix.reactivePower, basePowerInv))

    push!(generator.voltage.magnitude, topu(magnitude, default.magnitude, prefix.voltageMagnitude, baseVoltageInv))

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
    label::L = missing, bus::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

function addGenerator!(system::PowerSystem, analysis::ACPowerFlow;
    label::L = missing, bus::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

function addGenerator!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L = missing, bus::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = generator.number

    push!(variable.active, @variable(jump, base_name = "active[$index]"))
    push!(analysis.power.generator.active, generator.output.active[end])

    if generator.layout.status[end] == 1
        updateBalance(system, analysis, generator.layout.bus[end]; power = 1, genIndex = index)
        addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
    else
        fix!(variable.active[index], 0.0, constraint.capability.active, index)
    end
end

function addGenerator!(system::PowerSystem, analysis::ACOptimalPowerFlow;
    label::L = missing, bus::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = generator.number

    push!(variable.active, @variable(jump, base_name = "active[$index]"))
    push!(variable.reactive, @variable(jump, base_name = "reactive[$index]"))

    push!(analysis.power.generator.active, generator.output.active[end])
    push!(analysis.power.generator.reactive, generator.output.reactive[end])

    if generator.layout.status[end] == 1
        updateBalance(system, analysis, generator.layout.bus[end]; active = true, reactive = true)
        addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
        addCapability(jump, variable.reactive[index], constraint.capability.reactive, generator.capability.minReactive, generator.capability.maxReactive, index)
    else
        fix!(variable.active[index], 0.0, constraint.capability.active, index)
        fix!(variable.reactive[index], 0.0, constraint.capability.reactive, index)
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
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    bus = system.bus
    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]

    if ismissing(status)
        status = generator.layout.status[index]
    end
    checkStatus(status)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    output = isset(active) || isset(reactive)

    if generator.layout.status[index] == 1
        if status == 0 || (status == 1 && output)
            bus.supply.active[indexBus] -= generator.output.active[index]
            bus.supply.reactive[indexBus] -= generator.output.reactive[index]
        end
        if status == 0
            generator.layout.inservice -= 1
            for (k, i) in enumerate(bus.supply.generator[indexBus])
                if i == index
                    deleteat!(bus.supply.generator[indexBus], k)
                    break
                end
            end
        end
    end

    if output
        if isset(active)
            generator.output.active[index] = topu(active, prefix.activePower, basePowerInv)
        end
        if isset(reactive)
            generator.output.reactive[index] = topu(reactive, prefix.reactivePower, basePowerInv)
        end
    end

    if status == 1
        if generator.layout.status[index] == 0 || (generator.layout.status[index] == 1 && output)
            bus.supply.active[indexBus] += generator.output.active[index]
            bus.supply.reactive[indexBus] += generator.output.reactive[index]
        end
        if generator.layout.status[index] == 0
            generator.layout.inservice += 1
            position = searchsortedfirst(bus.supply.generator[indexBus], index)
            insert!(bus.supply.generator[indexBus], position, index)
        end
    end
    generator.layout.status[index] = status

    if isset(minActive)
        generator.capability.minActive[index] = topu(minActive, prefix.activePower, basePowerInv)
    end
    if isset(maxActive)
        generator.capability.maxActive[index] = topu(maxActive, prefix.activePower, basePowerInv)
    end
    if isset(minReactive)
        generator.capability.minReactive[index] = topu(minReactive, prefix.reactivePower, basePowerInv)
    end
    if isset(maxReactive)
        generator.capability.maxReactive[index] = topu(maxReactive, prefix.reactivePower, basePowerInv)
    end

    if isset(lowActive)
        generator.capability.lowActive[index] = topu(lowActive, prefix.activePower, basePowerInv)
    end
    if isset(minLowReactive)
        generator.capability.minLowReactive[index] = topu(minLowReactive, prefix.reactivePower, basePowerInv)
    end
    if isset(maxLowReactive)
        generator.capability.maxLowReactive[index] = topu(maxLowReactive, prefix.reactivePower, basePowerInv)
    end

    if isset(upActive)
        generator.capability.upActive[index] = topu(upActive, prefix.activePower, basePowerInv)
    end
    if isset(minUpReactive)
        generator.capability.minUpReactive[index] = topu(minUpReactive, prefix.reactivePower, basePowerInv)
    end
    if isset(maxUpReactive)
        generator.capability.maxUpReactive[index] = topu(maxUpReactive, prefix.reactivePower, basePowerInv)
    end

    if isset(loadFollowing)
        generator.ramping.loadFollowing[index] = topu(loadFollowing, prefix.activePower, basePowerInv)
    end
    if isset(reserve10min)
        generator.ramping.reserve10min[index] = topu(reserve10min, prefix.activePower, basePowerInv)
    end
    if isset(reserve30min)
        generator.ramping.reserve30min[index] = topu(reserve30min, prefix.activePower, basePowerInv)
    end
    if isset(reactiveTimescale)
        generator.ramping.reactiveTimescale[index] = topu(reactiveTimescale, prefix.reactivePower, basePowerInv)
    end

    if isset(magnitude)
        baseVoltageInv = 1 / (system.base.voltage.value[indexBus] * system.base.voltage.prefix)
        generator.voltage.magnitude[index] = topu(magnitude, prefix.voltageMagnitude, baseVoltageInv)
    end

    if isset(area)
        generator.layout.area[index] = area
    end
end

function updateGenerator!(system::PowerSystem, analysis::DCPowerFlow;
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    generator = system.generator

    if isset(status)
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

function updateGenerator!(system::PowerSystem, analysis::Union{ACPowerFlow{NewtonRaphson}, ACPowerFlow{FastNewtonRaphson}};
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    if isset(status)
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

function updateGenerator!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel};
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    bus = system.bus
    generator = system.generator

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    if isset(status)
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
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    statusOld = generator.layout.status[index]

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    if isset(active)
        analysis.power.generator.active[index] = generator.output.active[index]
    end

    if statusOld == 1 && generator.layout.status[index] == 0
        cost, isPowerwise = costExpr(generator.cost.active, variable.active[index], index, label)

        if isPowerwise
            remove!(jump, constraint.piecewise.active, index)
            add_to_expression!(analysis.method.objective, -variable.actwise[index])
            remove!(jump, variable.actwise, index)
        else
            analysis.method.objective -= cost
        end
        drop_zeros!(analysis.method.objective)
        JuMP.set_objective_function(jump, analysis.method.objective)

        remove!(jump, constraint.capability.active, index)
        updateBalance(system, analysis, indexBus; power = 0, genIndex = index)
        fix!(variable.active[index], 0.0, constraint.capability.active, index)
    end

    if statusOld == 0 && generator.layout.status[index] == 1
        cost, isPowerwise = costExpr(generator.cost.active, variable.active[index], index, label)

        if isPowerwise
            addPowerwise(jump, analysis.method.objective, variable.actwise, index; name = "actwise")
            addPiecewise(jump, variable.active[index], variable.actwise[index], constraint.piecewise.active, generator.cost.active.piecewise[index], size(generator.cost.active.piecewise[index], 1), index)
        else
            analysis.method.objective += cost
        end
        JuMP.set_objective_function(jump, analysis.method.objective)

        updateBalance(system, analysis, indexBus; power = 1, genIndex = index)
        remove!(jump, constraint.capability.active, index)
        addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
    end

    if statusOld == 1 && generator.layout.status[index] == 1 && (isset(minActive) || isset(maxActive))
        remove!(jump, constraint.capability.active, index)
        addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
    end
end

function updateGenerator!(system::PowerSystem, analysis::ACOptimalPowerFlow;
    label::L, area::A = missing, status::A = missing,
    active::A = missing, reactive::A = missing, magnitude::A = missing,
    minActive::A = missing, maxActive::A = missing, minReactive::A = missing,
    maxReactive::A = missing, lowActive::A = missing, minLowReactive::A = missing,
    maxLowReactive::A = missing, upActive::A = missing, minUpReactive::A = missing,
    maxUpReactive::A = missing, loadFollowing::A = missing, reserve10min::A = missing,
    reserve30min::A = missing, reactiveTimescale::A = missing)

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable
    objective = analysis.method.objective

    index = generator.label[getLabel(generator, label, "generator")]
    indexBus = generator.layout.bus[index]
    statusOld = generator.layout.status[index]

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    updateGenerator!(system; label, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)

    if isset(active)
        analysis.power.generator.active[index] = generator.output.active[index]
    end
    if isset(reactive)
        analysis.power.generator.reactive[index] = generator.output.reactive[index]
    end

    if statusOld == 1 && generator.layout.status[index] == 0
        ActCost, isActwise, isActNonlin = costExpr(costActive, variable.active[index], index, label; ac = true)
        ReactCost, isReactwise, isReactNonlin = costExpr(costReactive, variable.reactive[index], index, label; ac = true)

        @objective(jump, Min, 0.0)

        if isActwise
            remove!(jump, constraint.piecewise.active, index)
            add_to_expression!(objective.quadratic, -variable.actwise[index])
            remove!(jump, variable.actwise, index)
        else
            objective.quadratic -= ActCost
        end
        if isReactwise
            remove!(jump, constraint.piecewise.reactive, index)
            add_to_expression!(objective.quadratic, -variable.reactwise[index])
            remove!(jump, variable.reactwise, index)
        else
            objective.quadratic -= ReactCost
        end
        drop_zeros!(objective.quadratic)

        if isActNonlin
            delete!(objective.nonlinear.active, index)
        end
        if isReactNonlin
            delete!(objective.nonlinear.reactive, index)
        end

        @objective(jump, Min, objective.quadratic + sum(objective.nonlinear.active[i] for i in keys(objective.nonlinear.active)) + sum(objective.nonlinear.reactive[i] for i in keys(objective.nonlinear.reactive)))

        remove!(jump, constraint.capability.active, index)
        remove!(jump, constraint.capability.reactive, index)
        fix!(variable.active[index], 0.0, constraint.capability.active, index)
        fix!(variable.reactive[index], 0.0, constraint.capability.reactive, index)
        updateBalance(system, analysis, indexBus; active = true, reactive = true)
    end

    if statusOld == 0 && generator.layout.status[index] == 1
        ActCost, isActwise, isActNonlin = costExpr(costActive, variable.active[index], index, label; ac = true)
        ReactCost, isReactwise, isReactNonlin = costExpr(costReactive, variable.reactive[index], index, label; ac = true)

        if isActwise
            addPowerwise(jump, objective.quadratic, variable.actwise, index; name = "actwise")
            addPiecewise(jump, variable.active[index], variable.actwise[index], constraint.piecewise.active, generator.cost.active.piecewise[index], size(generator.cost.active.piecewise[index], 1), index)
        else
            objective.quadratic += ActCost
        end
        if isReactwise
            addPowerwise(jump, objective.quadratic, variable.reactwise, index; name = "reactwise")
            addPiecewise(jump, variable.reactive[index], variable.reactwise[index], constraint.piecewise.reactive, generator.cost.reactive.piecewise[index], size(generator.cost.reactive.piecewise[index], 1), index)
        else
            objective.quadratic += ReactCost
        end

        if isActNonlin
            term = length(costActive.polynomial[index])
            objective.nonlinear.active[index] = @expression(jump, sum(costActive.polynomial[index][term - degree] * variable.active[index]^degree for degree = term-1:-1:3))
        end
        if isReactNonlin
            term = length(costReactive.polynomial[index])
            objective.nonlinear.reactive[index] = @expression(jump, sum(costReactive.polynomial[index][term - degree] * variable.reactive[index]^degree for degree = term-1:-1:3))
        end

        @objective(jump, Min, objective.quadratic + sum(objective.nonlinear.active[i] for i in keys(objective.nonlinear.active)) + sum(objective.nonlinear.reactive[i] for i in keys(objective.nonlinear.reactive)))


        remove!(jump, constraint.capability.active, index)
        remove!(jump, constraint.capability.reactive, index)
        addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
        addCapability(jump, variable.reactive[index], constraint.capability.reactive, generator.capability.minReactive, generator.capability.maxReactive, index)
        updateBalance(system, analysis, indexBus; active = true, reactive = true)
    end

    if statusOld == 1 && generator.layout.status[index] == 1
        if isset(minActive) || isset(maxActive)
            remove!(jump, constraint.capability.active, index)
            addCapability(jump, variable.active[index], constraint.capability.active, generator.capability.minActive, generator.capability.maxActive, index)
        end
        if isset(minReactive) || isset(maxReactive)
            remove!(jump, constraint.capability.reactive, index)
            addCapability(jump, variable.reactive[index], constraint.capability.reactive, generator.capability.minReactive, generator.capability.maxReactive, index)
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
Adding a generator using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 2, active = 0.25, reactive = -0.04, base = 132e3)

@generator(magnitude = 1.1)
addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5, reactive = 0.1)
```

Adding a generator using a custom unit system:
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

        if hasfield(GeneratorTemplate, parameter)
            if !(parameter in [:area; :status; :label])
                container::ContainerTemplate = getfield(template.generator, parameter)

                if parameter in [:active; :minActive; :maxActive; :lowActive; :upActive; :loadFollowing; :reserve10min; :reserve30min]
                    prefixLive = prefix.activePower
                elseif parameter in [:reactive; :minReactive; :maxReactive; :minLowReactive; :maxLowReactive; :minUpReactive; :maxUpReactive; :reactiveTimescale]
                    prefixLive = prefix.reactivePower
                elseif parameter == :magnitude
                    prefixLive = prefix.voltageMagnitude
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * Float64(eval(kwarg.args[2])))
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
                        throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                    end
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

"""
    cost!(system::PowerSystem, analysis::Analysis; label, active, reactive,
        piecewise, polynomial)

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
* `label`: corresponds to the already defined generator label;
* `active`: cost model:
  * `active = 1`: adding or updating cost for the active power, and piecewise linear is being used;
  * `active = 2`: adding or updating cost for the active power, and polynomial is being used;
* `reactive`: cost model:
  * `reactive = 1`: adding or updating cost for the reactive power, and piecewise linear is being used;
  * `reactive = 2`: adding or updating cost for the reactive power, and polynomial is being used;
* `piecewise`: cost model defined by input-output points given as `Array{Float64,2}`:
  * first column (pu, W or VAr): active or reactive power output of the generator;
  * second column ($/hr): cost for the specified active or reactive power output;
* `polynomial`: n-th degree polynomial coefficients given as `Array{Float64,1}`:
  * first element ($/puⁿhr, $/Wⁿhr or $/VArⁿhr): coefficient of the n-th degree term, ...;
  * penultimate element ($/puhr, $/Whr or $/VArhr): coefficient of the first degree term;
  * last element ($/hr): constant coefficient.

# Updates
The function updates the `generator.cost` field within the `PowerSystem` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

# Units
By default, the input units related with active powers are per-units (pu), but they can be
modified using the macro [`@power`](@ref @power).

# Examples
Adding a cost using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", active = 0.25, reactive = -0.04, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 0.5)
cost!(system; label = "Generator 1", active = 2, polynomial = [1100.0; 500.0; 150.0])
```

Adding a cost using a custom unit system:
```jldoctest
@power(MW, MVAr, MVA)
system = powerSystem()

addBus!(system; label = "Bus 1", active = 25, reactive = -4, base = 132e3)

addGenerator!(system; label = "Generator 1", bus = "Bus 1", active = 50, reactive = 10)
cost!(system; label = "Generator 1", active = 2, polynomial = [0.11; 5.0; 150.0])
```
"""
function cost!(system::PowerSystem; label::L,
    active::A = missing, reactive::A = missing,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    if isset(active) && isset(reactive)
        throw(ErrorException("The concurrent definition of the keywords active and reactive is not allowed."))
    elseif ismissing(active) && ismissing(reactive)
        throw(ErrorException("The cost model is missing."))
    elseif isset(active) && !(active in [1; 2]) || isset(reactive) && !(reactive in [1; 2])
        throw(ErrorException("The model $model is not allowed; it should be either piecewise (1) or polynomial (2)."))
    end

    index = system.generator.label[getLabel(system.generator, label, "generator")]

    if isset(active)
        container = system.generator.cost.active
        container.model[index] = active
        if prefix.activePower == 0.0
            scale = 1.0
        else
            scale = prefix.activePower / (system.base.power.prefix * system.base.power.value)
        end
    elseif isset(reactive)
        container = system.generator.cost.reactive
        container.model[index] = reactive
        if prefix.reactivePower == 0.0
            scale = 1.0
        else
            scale = prefix.reactivePower / (system.base.power.prefix * system.base.power.value)
        end
    end

    if container.model[index] == 1 && isempty(piecewise) && isempty(container.piecewise[index])
        throw(ErrorException("An attempt to assign a piecewise function has been made, but the piecewise function does not exist."))
    end
    if container.model[index] == 2 && isempty(polynomial) && isempty(container.polynomial[index])
        throw(ErrorException("An attempt to assign a polynomial function has been made, but the polynomial function does not exist."))
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
    active::A = missing, reactive::A = missing,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    dropZero = false
    index = generator.label[getLabel(generator, label, "generator")]
    if generator.layout.status[index] == 1
        costOld, isPowerwiseOld = costExpr(generator.cost.active, variable.active[index], index, label)

        if isPowerwiseOld
            remove!(jump, constraint.piecewise.active, index)
        else
            dropZero = true
            analysis.method.objective -= costOld
        end
    end

    cost!(system; label, active, reactive, polynomial, piecewise)

    if generator.layout.status[index] == 1
        costNew, isPowerwiseNew = costExpr(generator.cost.active, variable.active[index], index, label)

        if isPowerwiseNew
            if !isPowerwiseOld
                addPowerwise(jump, analysis.method.objective, variable.actwise, index; name = "actwise")
            end
            addPiecewise(jump, variable.active[index], variable.actwise[index], constraint.piecewise.active, generator.cost.active.piecewise[index], size(generator.cost.active.piecewise[index], 1), index)
        else
            if isPowerwiseOld
                dropZero = true
                add_to_expression!(analysis.method.objective, -variable.actwise[index])
                remove!(jump, variable.actwise, index)
            end
            analysis.method.objective += costNew
        end
    end

    if dropZero
        drop_zeros!(analysis.method.objective)
    end
    JuMP.set_objective_function(jump, analysis.method.objective)
end

function cost!(system::PowerSystem, analysis::ACOptimalPowerFlow; label::L,
    active::A = missing,  reactive::A = missing,
    polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
    piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

    generator = system.generator
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable
    objective = analysis.method.objective

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    dropZero = false
    index = generator.label[getLabel(generator, label, "generator")]
    if generator.layout.status[index] == 1
        ActCost, isActwiseOld, isActNonlin = costExpr(generator.cost.active, variable.active[index], index, label; ac = true)
        ReactCost, isReactwisOld, isReactNonlin = costExpr(generator.cost.reactive, variable.reactive[index], index, label; ac = true)

        @objective(jump, Min, 0.0)

        if isActwiseOld
            remove!(jump, constraint.piecewise.active, index)
        else
            dropZero = true
            objective.quadratic -= ActCost
        end
        if isReactwisOld
            remove!(jump, constraint.piecewise.reactive, index)
        else
            dropZero = true
            objective.quadratic -= ReactCost
        end

        if isActNonlin
            delete!(objective.nonlinear.active, index)
        end
        if isReactNonlin
            delete!(objective.nonlinear.reactive, index)
        end
    end

    cost!(system; label, active, reactive, polynomial, piecewise)

    if generator.layout.status[index] == 1
        ActCost, isActwiseNew, isActNonlin = costExpr(generator.cost.active, variable.active[index], index, label; ac = true)
        ReactCost, isReactwiseNew, isReactNonlin = costExpr(generator.cost.reactive, variable.reactive[index], index, label; ac = true)

        if isActwiseNew
            if !isActwiseOld
                addPowerwise(jump, objective.quadratic, variable.actwise, index; name = "actwise")
            end
            addPiecewise(jump, variable.active[index], variable.actwise[index], constraint.piecewise.active, generator.cost.active.piecewise[index], size(generator.cost.active.piecewise[index], 1), index)
        else
            if isActwiseOld
                dropZero = true
                add_to_expression!(objective.quadratic, -variable.actwise[index])
                remove!(jump, variable.actwise, index)
            end
            objective.quadratic += ActCost
        end

        if isReactwiseNew
            if !isReactwisOld
                addPowerwise(jump, objective.quadratic, variable.reactwise, index; name = "reactwise")
            end
            addPiecewise(jump, variable.reactive[index], variable.reactwise[index], constraint.piecewise.reactive, generator.cost.reactive.piecewise[index], size(generator.cost.reactive.piecewise[index], 1), index)
        else
            if isReactwisOld
                dropZero = true
                add_to_expression!(objective.quadratic, -variable.reactwise[index])
                remove!(jump, variable.reactwise, index)
            end
            objective.quadratic += ReactCost
        end

        if isActNonlin
            delete!(objective.nonlinear.active, index)
            term = length(costActive.polynomial[index])
            objective.nonlinear.active[index] = @expression(jump, sum(costActive.polynomial[index][term - degree] * variable.active[index]^degree for degree = term-1:-1:3))
        end
        if isReactNonlin
            delete!(objective.nonlinear.reactive, index)
            term = length(costReactive.polynomial[index])
            objective.nonlinear.reactive[index] = @expression(jump, sum(costReactive.polynomial[index][term - degree] * variable.reactive[index]^degree for degree = term-1:-1:3))
        end
    end

    if dropZero
        drop_zeros!(objective.quadratic)
    end

    @objective(jump, Min, objective.quadratic + sum(objective.nonlinear.active[i] for i in keys(objective.nonlinear.active)) + sum(objective.nonlinear.reactive[i] for i in keys(objective.nonlinear.reactive)))
end