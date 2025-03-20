"""
    addBranch!(system::PowerSystem, [analysis::Analysis];
        label, from, to, status,
        resistance, reactance, conductance, susceptance, turnsRatio, shiftAngle,
        minDiffAngle, maxDiffAngle, minFromBus, maxFromBus, minToBus, maxToBus, type)

The function adds a new branch to the `PowerSystem` type. A branch can be added between
already defined buses.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem` type
only. However, when including the `Analysis` type, it updates both the `PowerSystem` and
`Analysis` types. This streamlined approach circumvents the necessity for completely
reconstructing vectors and matrices when adding a new branch.

# Keywords
The branch is defined with the following keywords:
* `label`: Unique label for the branch.
* `from`: From-bus label, corresponds to the bus label.
* `to`: To-bus label, corresponds to the bus label.
* `status`: Operating status of the branch:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.
* `resistance` (pu or Ω): Series resistance.
* `reactance` (pu or Ω): Series reactance.
* `conductance` (pu or S): Total shunt conductance.
* `susceptance` (pu or S): Total shunt susceptance.
* `turnsRatio`: Transformer off-nominal turns ratio, equal to one for a line.
* `shiftAngle` (rad or deg): Transformer phase shift angle, where positive value defines delay.
* `minDiffAngle` (rad or deg): Minimum voltage angle difference value between from-bus and to-bus ends.
* `maxDiffAngle` (rad or deg): Maximum voltage angle difference value between from-bus and to-bus ends.
* `minFromBus` (pu, VA, W, or A): Minimum branch flow limit at the from-bus end.
* `maxFromBus` (pu, VA, W, or A): Maximum branch flow limit at the from-bus end.
* `minToBus` (pu, VA, W, or A): Minimum branch flow limit at the to-bus end.
* `maxToBus` (pu, VA, W, or A): Maximum branch flow limit at the to-bus end.
* `type`: Types of `minFromBus`, `maxFromBus`, `minToBus`, and `maxToBus` branch flow limits:
  * `type = 1`: active power flow (pu or W),
  * `type = 2`: apparent power flow (pu or VA),
  * `type = 3`: apparent power flow (pu or VA) with a squared inequality constraint,
  * `type = 4`: current magnitude flow (pu or A),
  * `type = 5`: current magnitude flow (pu or A) with a squared inequality constraint.

Note that when powers are given in SI units, they correspond to three-phase power.

# Updates
The function updates the `branch` field within the `PowerSystem` type, and in cases where
parameters impact variables in the `ac` and `dc` fields, it automatically adjusts the
fields. Furthermore, it guarantees that any modifications to the parameters are transmitted
to the `Analysis` type.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `turnsRatio = 1.0`,
`type = 3`, `minDiffAngle = -2pi`, and `maxDiffAngle = 2pi`. The rest of the keywords are
initialized with a value of zero. However, the user can modify these default settings by
utilizing the [`@branch`](@ref @branch) macro.

# Units
The default units for the keyword parameters are per-units and radians. However, the user
can choose to use other units besides per-units and radians by utilizing macros such as
[`@power`](@ref @power), [`@voltage`](@ref @voltage), [`@current`](@ref @current), and
[`@parameter`](@ref @parameter).

# Examples
Adding a branch using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 0.1745)
```

Adding a branch using a custom unit system:
```jldoctest
@voltage(pu, deg)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 10)
```
"""
function addBranch!(
    system::PowerSystem;
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
)
    branch = system.branch
    param = branch.parameter
    def = template.branch
    baseVoltg = system.base.voltage
    key = branchkwargs(; kwargs...)

    branch.number += 1
    setLabel(branch, label, def.label, "branch")

    if from == to
        throw(ErrorException("Invalid value for from or to keywords."))
    end

    push!(branch.layout.from, system.bus.label[getLabel(system.bus, from, "bus")])
    push!(branch.layout.to, system.bus.label[getLabel(system.bus, to, "bus")])

    add!(branch.layout.status, key.status, def.status)
    checkStatus(branch.layout.status[end])
    if branch.layout.status[end] == 1
        branch.layout.inservice += 1
    end

    add!(param.turnsRatio, key.turnsRatio, def.turnsRatio)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = baseVoltg.value[branch.layout.from[end]] * baseVoltg.prefix
    baseAdmInv = baseImpedance(baseVoltage, basePowerInv, param.turnsRatio[end])
    baseImpInv = 1 / baseAdmInv

    add!(param.resistance, key.resistance, def.resistance, pfx.impedance, baseImpInv)
    add!(param.reactance, key.reactance, def.reactance, pfx.impedance, baseImpInv)

    if param.resistance[end] == 0.0 && param.reactance[end] == 0.0
        throw(ErrorException("At least one of resistance or reactance is required."))
    end

    add!(param.conductance, key.conductance, def.conductance, pfx.admittance, baseAdmInv)
    add!(param.susceptance, key.susceptance, def.susceptance, pfx.admittance, baseAdmInv)
    add!(param.shiftAngle, key.shiftAngle, def.shiftAngle, pfx.voltageAngle, 1.0)

    add!(branch.voltage.minDiffAngle, key.minDiffAngle, def.minDiffAngle, pfx.voltageAngle, 1.0)
    add!(branch.voltage.maxDiffAngle, key.maxDiffAngle, def.maxDiffAngle, pfx.voltageAngle, 1.0)

    add!(branch.flow.type, key.type, def.type)

    pfxLive, baseInvFrom, baseInvTo = flowType(system, pfx, basePowerInv, branch.number)
    add!(branch.flow.minFromBus, key.minFromBus, def.minFromBus, pfxLive, baseInvFrom)
    add!(branch.flow.maxFromBus, key.maxFromBus, def.maxFromBus, pfxLive, baseInvFrom)
    add!(branch.flow.minToBus, key.minToBus, def.minToBus, pfxLive, baseInvTo)
    add!(branch.flow.maxToBus, key.maxToBus, def.maxToBus, pfxLive, baseInvTo)

    if !isempty(system.model.ac.nodalMatrix)
        acPushZeros!(system.model.ac)

        if branch.layout.status[branch.number] == 1
            acParameterUpdate!(system, branch.number)
            acNodalUpdate!(system, branch.number)
        end
    end
    if !isempty(system.model.dc.nodalMatrix)
        push!(system.model.dc.admittance, 0.0)
        dcAdmittanceUpdate!(system, branch.layout.status[branch.number], branch.number)

        if system.model.dc.admittance[branch.number] != 0
            dcShiftUpdate!(system, branch.number)
            dcNodalUpdate!(system, branch.number)
        end
    end
end

function addBranch!(
    system::PowerSystem,
    analysis::ACPowerFlow{T};
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
) where T <: Union{NewtonRaphson, GaussSeidel}

    addBranch!(system; label, from, to, kwargs...)
end

function addBranch!(
    system::PowerSystem,
    analysis::ACPowerFlow{FastNewtonRaphson};
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
)
    addBranch!(system; label, from, to, kwargs...)

    if system.branch.layout.status[system.branch.number] == 1
        fastNewtonRaphsonJacobian(system, analysis, system.branch.number, 1)
    end
end

function addBranch!(
    system::PowerSystem,
    ::DCPowerFlow;
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
)
    addBranch!(system; label, from, to, kwargs...)
end

function addBranch!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
)
    branch = system.branch
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable

    addBranch!(system; label, from, to, kwargs...)

    if branch.layout.status[end] == 1
        from = branch.layout.from[end]
        to = branch.layout.to[end]

        updateBalance(system, analysis, from; active = true, reactive = true)
        updateBalance(system, analysis, to; active = true, reactive = true)

        addFlow(
            system, jump, variable.magnitude, variable.angle,
            constr.flow.from, constr.flow.to, branch.number
        )
        addAngle(system, jump, variable.angle, constr.voltage.angle, branch.number)
    end
end

function addBranch!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    label::IntStrMiss = missing,
    from::IntStrMiss,
    to::IntStrMiss,
    kwargs...
)
    branch = system.branch
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    key = branchkwargs(; kwargs...)

    addBranch!(system; label, from, to, kwargs...)

    if branch.layout.status[end] == 1
        from = branch.layout.from[end]
        to = branch.layout.to[end]

        rhs = isset(key.shiftAngle)
        updateBalance(system, analysis, from; voltage = true, rhs = rhs)
        updateBalance(system, analysis, to; voltage = true, rhs = rhs)

        addFlow(system, jump, variable.angle, constr.flow.active, branch.number)
        addAngle(system, jump, variable.angle, constr.voltage.angle, branch.number)
    end
end

"""
    updateBranch!(system::PowerSystem, [analysis::Analysis]; kwargs...)

The function allows for the alteration of parameters for an existing branch.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem` type
only. However, when including the `Analysis` type, it updates both the `PowerSystem` and
`Analysis` types. This streamlined process avoids the need to completely rebuild vectors
and matrices when adjusting these parameter.

# Keywords
To update a specific branch, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addBranch!`](@ref addBranch!) function, along with
their respective values. Ensure that the `label` keyword matches the label of the existing
branch. If any keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `branch` field within the `PowerSystem` type, and in cases where
parameters impact variables in the `ac` and `dc` fields, it automatically adjusts the fields.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addBranch!`](@ref addBranch!) function.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
updateBranch!(system; label = "Branch 1", reactance = 0.02, susceptance = 0.062)
```
"""
function updateBranch!(system::PowerSystem; label::IntStrMiss, kwargs...)
    branch = system.branch
    param = branch.parameter
    ac = system.model.ac
    dc = system.model.dc
    baseVoltg = system.base.voltage
    key = branchkwargs(; kwargs...)

    idx = branch.label[getLabel(branch, label, "branch")]

    statusNew = key.status
    statusOld = branch.layout.status[idx]

    if ismissing(statusNew)
        statusNew = copy(statusOld)
    end
    checkStatus(statusNew)

    dcadm = isset(key.reactance, key.turnsRatio)
    pimodel = isset(dcadm, key.resistance, key.conductance, key.susceptance, key.shiftAngle)

    if statusNew == 1 && statusOld == 0
        branch.layout.inservice += 1
    elseif statusNew == 0 && statusOld == 1
        branch.layout.inservice -= 1
    end

    if !isempty(ac.nodalMatrix)
        if statusOld == 1 && (statusNew == 0 || (statusNew == 1 && pimodel))
            acSubtractAdmittances!(ac, idx)
            acNodalUpdate!(system, idx)
            acSetZeros!(ac, idx)
        end
    end

    if !isempty(dc.nodalMatrix)
        if statusOld == 1
            if statusNew == 0 || (statusNew == 1 && isset(dcadm, key.shiftAngle))
                dc.admittance[idx] = -dc.admittance[idx]
                dcShiftUpdate!(system, idx)
                if statusOld == 1 && (statusNew == 0 || (statusNew == 1 && dcadm))
                    dcNodalUpdate!(system, idx)
                end
                dc.admittance[idx] = 0.0
            end
        end
    end

    if pimodel
        update!(param.turnsRatio, key.turnsRatio, idx)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseVoltage = baseVoltg.value[branch.layout.from[idx]] * baseVoltg.prefix
        baseAdmInv = baseImpedance(baseVoltage, baseInv, param.turnsRatio[idx])
        baseImpInv = 1 / baseAdmInv

        update!(param.resistance, key.resistance, pfx.impedance, baseImpInv, idx)
        update!(param.reactance, key.reactance, pfx.impedance, baseImpInv, idx)
        update!(param.conductance, key.conductance, pfx.admittance, baseAdmInv, idx)
        update!(param.susceptance, key.susceptance, pfx.admittance, baseAdmInv, idx)
        update!(param.shiftAngle, key.shiftAngle, pfx.voltageAngle, 1.0, idx)
    end

    if !isempty(ac.nodalMatrix)
        if statusNew == 1 && (statusOld == 0 || (statusOld == 1 && pimodel))
            acParameterUpdate!(system, idx)
            acNodalUpdate!(system, idx)
        end
    end

    if !isempty(dc.nodalMatrix)
        if statusNew == 1
            if statusOld == 0 || (statusOld == 1 && isset(dcadm, key.shiftAngle))
                dcAdmittanceUpdate!(system, statusNew, idx)
                dcShiftUpdate!(system, idx)
                if statusNew == 1 && (statusOld == 0 || (statusOld == 1 && dcadm))
                    dcNodalUpdate!(system, idx)
                end
            end
        end
    end

    branch.layout.status[idx] = statusNew

    update!(branch.voltage.minDiffAngle, key.minDiffAngle, pfx.voltageAngle, 1.0, idx)
    update!(branch.voltage.maxDiffAngle, key.maxDiffAngle, pfx.voltageAngle, 1.0, idx)
    update!(branch.flow.type, key.type, idx)

    if isset(key.minFromBus, key.maxFromBus, key.minToBus, key.maxToBus)
        pfxLive, baseInvFrom, baseInvTo = flowType(system, pfx, baseInv, idx)

        update!(branch.flow.minFromBus, key.minFromBus, pfxLive, baseInvFrom, idx)
        update!(branch.flow.maxFromBus, key.maxFromBus, pfxLive, baseInvFrom, idx)
        update!(branch.flow.minToBus, key.minToBus, pfxLive, baseInvTo, idx)
        update!(branch.flow.maxToBus, key.maxToBus, pfxLive, baseInvTo, idx)
    end
end

function updateBranch!(
    system::PowerSystem,
    analysis::ACPowerFlow{T};
    label::IntStrMiss,
    kwargs...
) where T <: Union{NewtonRaphson, GaussSeidel}

    updateBranch!(system; label, kwargs...)
end

function updateBranch!(
    system::PowerSystem,
    analysis::ACPowerFlow{FastNewtonRaphson};
    label::IntStrMiss,
    kwargs...
)
    idx = system.branch.label[getLabel(system.branch, label, "branch")]

    if system.branch.layout.status[idx] == 1
        fastNewtonRaphsonJacobian(system, analysis, idx, -1)
    end

    updateBranch!(system; label, kwargs...)

    if system.branch.layout.status[idx] == 1
        fastNewtonRaphsonJacobian(system, analysis, idx, 1)
    end
end

function updateBranch!(system::PowerSystem, ::DCPowerFlow; label::IntStrMiss, kwargs...)
    updateBranch!(system; label, kwargs...)
end

function updateBranch!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    key = branchkwargs(; kwargs...)

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
    statusOld = system.branch.layout.status[idx]

    updateBranch!(system; label, kwargs...)

    statusNew = system.branch.layout.status[idx]
    diffAngle = isset(key.minDiffAngle, key.maxDiffAngle)
    flow = isset(key.minFromBus, key.maxFromBus, key.minToBus, key.maxToBus, key.type)
    pimodel = isset(
        key.resistance, key.reactance, key.conductance,
        key.susceptance, key.turnsRatio, key.shiftAngle
    )

    if pimodel || statusNew != statusOld
        from, to = fromto(system, idx)
        updateBalance(system, analysis, from; active = true, reactive = true)
        updateBalance(system, analysis, to; active = true, reactive = true)
    end

    if statusOld == 1
        if statusNew == 0 || (statusNew == 1 && (pimodel || flow))
            remove!(jump, constr.flow.from, idx)
            remove!(jump, constr.flow.to, idx)
        end
        if statusNew == 0 || (statusNew == 1 && diffAngle)
            remove!(jump, constr.voltage.angle, idx)
        end
    end

    if statusNew == 1
        if statusOld == 0 || (statusOld == 1 && (pimodel || flow))
            addFlow(
                system, jump, variable.magnitude, variable.angle,
                constr.flow.from, constr.flow.to, idx
            )
        end
        if statusOld == 0 || (statusOld == 1 && diffAngle)
            addAngle(system, jump, variable.angle, constr.voltage.angle, idx)
        end
    end
end

function updateBranch!(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow;
    label::IntStrMiss,
    kwargs...
)
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable
    key = branchkwargs(; kwargs...)

    idx = system.branch.label[getLabel(system.branch, label, "branch")]
    statusOld = system.branch.layout.status[idx]

    updateBranch!(system; label, kwargs...)

    statusNew = system.branch.layout.status[idx]
    pimodel = isset(key.reactance, key.turnsRatio, key.shiftAngle)
    diffAngle = isset(key.minDiffAngle, key.maxDiffAngle)
    flow = isset(key.minFromBus, key.maxFromBus, key.minToBus, key.maxToBus)

    if pimodel || statusNew != statusOld
        from, to = fromto(system, idx)
        updateBalance(system, analysis, from; voltage = true, rhs = true)
        updateBalance(system, analysis, to; voltage = true, rhs = true)
    end

    if statusOld == 1
        if statusNew == 0 || (statusNew == 1 && (pimodel || flow))
            remove!(jump, constr.flow.active, idx)
        end
        if statusNew == 0 || (statusNew == 1 && diffAngle)
            remove!(jump, constr.voltage.angle, idx)
        end
    end

    if statusNew == 1
        if statusOld == 0 || (statusOld == 1 && (pimodel || flow))
            addFlow(system, jump, variable.angle, constr.flow.active, idx)
        end
        if statusOld == 0 || (statusOld == 1 && diffAngle)
            addAngle(system, jump, variable.angle, constr.voltage.angle, idx)
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
Adding a branch template using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

@branch(reactance = 0.12, shiftAngle = 0.1745)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
```

Adding a branch template using a custom unit system:
```jldoctest
@voltage(pu, deg)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1,  active = 0.15, reactive = 0.08)

@branch(shiftAngle = 10)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
```
"""
macro branch(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]
            if parameter == :type
                setfield!(template.branch, parameter, Int8(eval(kwarg.args[2])))
            end
        end

        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(BranchTemplate, parameter)
                if !(parameter in [:status; :type; :label; :turnsRatio])
                    container::ContainerTemplate = getfield(template.branch, parameter)
                    if parameter in [:resistance; :reactance]
                        pfxLive = pfx.impedance
                    elseif parameter in [:conductance; :susceptance]
                        pfxLive = pfx.admittance
                    elseif parameter in [:shiftAngle; :minDiffAngle; :maxDiffAngle]
                        pfxLive = pfx.voltageAngle
                    elseif parameter in [:minFromBus; :maxFromBus; :minToBus; :maxToBus]
                        if template.branch.type == 1
                            pfxLive = pfx.activePower
                        elseif template.branch.type in [2, 3]
                            pfxLive = pfx.apparentPower
                        elseif template.branch.type in [4, 5]
                            pfxLive = pfx.currentMagnitude
                        end
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
                        setfield!(template.branch, parameter, Int8(eval(kwarg.args[2])))
                    elseif parameter == :turnsRatio
                        setfield!(template.branch, parameter, Float64(eval(kwarg.args[2])))
                    elseif parameter == :label
                        label = string(kwarg.args[2])
                        if contains(label, "?")
                            setfield!(template.branch, parameter, label)
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
end

##### Branch Flow Rating Type #####
function flowType(system::PowerSystem, pfx::PrefixLive, basePowerInv::Float64, i::Int64)
    branch = system.branch
    baseVoltg = system.base.voltage

    if branch.flow.type[i] == 1
        pfxLive = pfx.activePower
        baseInvFrom = basePowerInv
        baseInvTo = basePowerInv
    elseif branch.flow.type[i] == 2 || branch.flow.type[i] == 3
        pfxLive = pfx.apparentPower
        baseInvFrom = basePowerInv
        baseInvTo = basePowerInv
    elseif branch.flow.type[i] == 4 || branch.flow.type[i] == 5
        pfxLive = pfx.currentMagnitude
        baseInvFrom = baseCurrentInv(
            basePowerInv, baseVoltg.value[branch.layout.from[i]] * baseVoltg.prefix
        )
        baseInvTo = baseCurrentInv(
            basePowerInv, baseVoltg.value[branch.layout.to[i]] * baseVoltg.prefix
        )
    else
        throw(ErrorException(
            "The value $(branch.flow.type[i]) of " *
            "the branch flow rating type is illegal.")
        )
    end

    return pfxLive, baseInvFrom, baseInvTo
end

##### Branch Keywords #####
function branchkwargs(;
    status::IntMiss = missing,
    resistance::FltIntMiss = missing,
    reactance::FltIntMiss = missing,
    susceptance::FltIntMiss = missing,
    conductance::FltIntMiss = missing,
    turnsRatio::FltIntMiss = missing,
    shiftAngle::FltIntMiss = missing,
    minDiffAngle::FltIntMiss = missing,
    maxDiffAngle::FltIntMiss = missing,
    minFromBus::FltIntMiss = missing,
    maxFromBus::FltIntMiss = missing,
    minToBus::FltIntMiss = missing,
    maxToBus::FltIntMiss = missing,
    type::IntMiss = missing
)
    (
    status = status,
    resistance = resistance, reactance = reactance,
    susceptance = susceptance, conductance = conductance,
    turnsRatio = turnsRatio, shiftAngle = shiftAngle,
    minDiffAngle = minDiffAngle, maxDiffAngle = maxDiffAngle,
    minFromBus = minFromBus, maxFromBus = maxFromBus,
    minToBus = minToBus, maxToBus = maxToBus, type = type
    )
end