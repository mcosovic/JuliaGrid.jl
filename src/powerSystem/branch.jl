"""
    addBranch!(system::PowerSystem;
        label, from, to, status,
        resistance, reactance, conductance, susceptance, turnsRatio, shiftAngle,
        minDiffAngle, maxDiffAngle, minFromBus, maxFromBus, minToBus, maxToBus, type)

The function adds a new branch to the `PowerSystem` type. A branch can be added between already
defined buses.

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
The function updates the `branch` field within the `PowerSystem` type, and in cases where parameters
impact variables in the `ac` and `dc` fields, it automatically adjusts the fields.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `turnsRatio = 1.0`,
`type = 3`, `minDiffAngle = -2pi`, and `maxDiffAngle = 2pi`. The rest of the keywords are initialized
with a value of zero. However, the user can modify these default settings by utilizing the
[`@branch`](@ref @branch) macro.

# Units
The default units for the keyword parameters are per-units and radians. However, the user can choose
to use other units besides per-units and radians by utilizing macros such as [`@power`](@ref @power),
[`@voltage`](@ref @voltage), [`@current`](@ref @current), and [`@parameter`](@ref @parameter).

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
function addBranch!(system::PowerSystem; from::IntStr, to::IntStr, kwargs...)
    addBranchMain!(system, from, to, BranchKey(; kwargs...))
end

function addBranchMain!(system::PowerSystem, from::IntStr, to::IntStr, key::BranchKey)
    branch = system.branch
    param = branch.parameter
    def = template.branch

    branch.number += 1
    setLabel(branch, key.label, def.label, "branch")

    if from == to
        throw(ErrorException("Invalid value for from or to keywords."))
    end

    push!(branch.layout.from, getIndex(system.bus, from, "bus"))
    push!(branch.layout.to, getIndex(system.bus, to, "bus"))

    add!(branch.layout.status, key.status, def.status)
    checkStatus(branch.layout.status[end])
    if branch.layout.status[end] == 1
        branch.layout.inservice += 1
    end

    add!(param.turnsRatio, key.turnsRatio, def.turnsRatio)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = system.base.voltage.value[branch.layout.from[end]] * system.base.voltage.prefix
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

"""
    addBranch!(analysis::Analysis; kwargs...)

The function extends the [`addBranch!`](@ref addBranch!(::PowerSystem)) function. When the `Analysis`
type is passed, the function first adds the specified branch to the `PowerSystem` type using the
provided `kwargs`, and then adds the same branch to the `Analysis` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
analysis = newtonRaphson(system)

addBranch!(analysis; from = 13, to = 14, reactance = 0.21, susceptance = 0.06)
```
"""
function addBranch!(analysis::PowerFlow; from::IntStr, to::IntStr, kwargs...)
    addBranchMain!(analysis.system, from, to, BranchKey(; kwargs...))
    _addBranch!(analysis)
end

function _addBranch!(analysis::AcPowerFlow{T}) where T <: Union{NewtonRaphson, GaussSeidel}
    errorTypeConversion(analysis.system.bus.layout.pattern, analysis.method.signature[:type])
end

function _addBranch!(analysis::AcPowerFlow{FastNewtonRaphson})
    errorTypeConversion(analysis.system.bus.layout.pattern, analysis.method.signature[:type])

    if analysis.system.branch.layout.status[analysis.system.branch.number] == 1
        jacobian(analysis.system, analysis, analysis.system.branch.number)
    end
end

function _addBranch!(analysis::DcPowerFlow)
    errorTypeConversion(analysis.system.bus.layout.slack, analysis.method.signature[:slack])
end

function _addBranch!(analysis::AcOptimalPowerFlow)
    system = analysis.system
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    if system.branch.layout.status[end] == 1
        i, j = fromto(system, system.branch.number)

        remove!(jump, con.balance.active, i)
        remove!(jump, con.balance.reactive, i)
        addBalance(system, jump, var, con, i)

        remove!(jump, con.balance.active, j)
        remove!(jump, con.balance.reactive, j)
        addBalance(system, jump, var, con, j)

        addFlow(system, jump, var.voltage, con, QuadExpr(), QuadExpr(), system.branch.number)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, AffExpr(), system.branch.number)
    end
end

function _addBranch!(analysis::DcOptimalPowerFlow)
    system = analysis.system
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    if system.branch.layout.status[end] == 1
        i, j = fromto(system, system.branch.number)
        expr = AffExpr()

        remove!(jump, con.balance.active, i)
        addBalance(system, jump, var, con, expr, i)

        remove!(jump, con.balance.active, j)
        addBalance(system, jump, var, con, expr, j)

        addFlow(system, jump, var.voltage.angle, con.flow.active, expr, system.branch.number)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr, system.branch.number)
    end
end

"""
    updateBranch!(system::PowerSystem; kwargs...)

The function allows for the alteration of parameters for an existing branch.

# Keywords
To update a specific branch, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addBranch!`](@ref addBranch!) function, along with their respective
values. Ensure that the `label` keyword matches the label of the existing branch. If any keywords
are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `branch` field within the `PowerSystem` type, and in cases where parameters
impact variables in the `ac` and `dc` fields, it automatically adjusts the fields.

# Units
Units for input parameters can be changed using the same method as described for the
[`addBranch!`](@ref addBranch!) function.

# Example
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
updateBranch!(system; label = "Branch 1", reactance = 0.22, susceptance = 0.06)
```
"""
function updateBranch!(system::PowerSystem; label::IntStr, kwargs...)
    updateBranchMain!(system, label, BranchKey(; kwargs...))
end

function updateBranchMain!(system::PowerSystem, label::IntStr, key::BranchKey)
    branch = system.branch
    ac = system.model.ac
    dc = system.model.dc

    idx = getIndex(branch, label, "branch")

    statusNew = key.status
    statusOld = branch.layout.status[idx]

    if ismissing(statusNew)
        statusNew = copy(statusOld)
    end
    checkStatus(statusNew)

    dcadm = isset(key.reactance) || isset(key.turnsRatio)
    pimodel = any(isset, (dcadm, key.resistance, key.conductance, key.susceptance, key.shiftAngle))

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
            if statusNew == 0 || (statusNew == 1 && (isset(dcadm) || isset(key.shiftAngle)))
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
        update!(branch.parameter.turnsRatio, key.turnsRatio, idx)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseVoltage = system.base.voltage.value[branch.layout.from[idx]] * system.base.voltage.prefix
        baseAdmInv = baseImpedance(baseVoltage, baseInv, branch.parameter.turnsRatio[idx])
        baseImpInv = 1 / baseAdmInv

        update!(branch.parameter.resistance, key.resistance, pfx.impedance, baseImpInv, idx)
        update!(branch.parameter.reactance, key.reactance, pfx.impedance, baseImpInv, idx)
        update!(branch.parameter.conductance, key.conductance, pfx.admittance, baseAdmInv, idx)
        update!(branch.parameter.susceptance, key.susceptance, pfx.admittance, baseAdmInv, idx)
        update!(branch.parameter.shiftAngle, key.shiftAngle, pfx.voltageAngle, 1.0, idx)
    end

    if !isempty(ac.nodalMatrix)
        if statusNew == 1 && (statusOld == 0 || (statusOld == 1 && pimodel))
            acParameterUpdate!(system, idx)
            acNodalUpdate!(system, idx)
        end
    end

    if !isempty(dc.nodalMatrix)
        if statusNew == 1
            if statusOld == 0 || (statusOld == 1 && (isset(dcadm) || isset(key.shiftAngle)))
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

    pfxLive, baseInvFrom, baseInvTo = flowType(system, pfx, baseInv, idx)

    update!(branch.flow.minFromBus, key.minFromBus, pfxLive, baseInvFrom, idx)
    update!(branch.flow.maxFromBus, key.maxFromBus, pfxLive, baseInvFrom, idx)
    update!(branch.flow.minToBus, key.minToBus, pfxLive, baseInvTo, idx)
    update!(branch.flow.maxToBus, key.maxToBus, pfxLive, baseInvTo, idx)
end

"""
    updateBranch!(analysis::Analysis; kwargs...)

The function extends the [`updateBranch!`](@ref updateBranch!(::PowerSystem)) function. By passing
the `Analysis` type, the function first updates the specific branch within the `PowerSystem` type
using the provided `kwargs`, and then updates the `Analysis` type with all parameters associated
with that branch.

A key feature of this function is that any prior modifications made to the specified branch are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system = powerSystem("case14.h5")
analysis = newtonRaphson(system)

updateBranch!(analysis; label = 2, reactance = 0.32, susceptance = 0.07)
```
"""
function updateBranch!(analysis::PowerFlow; label::IntStr, kwargs...)
    updateBranchMain!(analysis.system, label, BranchKey(; kwargs...))
    _updateBranch!(analysis, getIndex(analysis.system.branch, label, "branch"))
end

function _updateBranch!(analysis::AcPowerFlow{T}, ::Int64) where T <: Union{NewtonRaphson, GaussSeidel}
    errorTypeConversion(analysis.system.bus.layout.pattern, analysis.method.signature[:type])
end

function _updateBranch!(analysis::AcPowerFlow{FastNewtonRaphson}, idx::Int64)
    system = analysis.system
    jcbP = analysis.method.active.jacobian
    jcbQ = analysis.method.reactive.jacobian

    errorTypeConversion(system.bus.layout.pattern, analysis.method.signature[:type])

    from, to = fromto(system, idx)

    if from != system.bus.layout.slack && to != system.bus.layout.slack
        jcbP[analysis.method.pvpq[from], analysis.method.pvpq[to]] = 0.0
        jcbP[analysis.method.pvpq[to], analysis.method.pvpq[from]] = 0.0
    end
    if from != system.bus.layout.slack
        jcbP[analysis.method.pvpq[from], analysis.method.pvpq[from]] = 0.0
    end
    if to != system.bus.layout.slack
        jcbP[analysis.method.pvpq[to], analysis.method.pvpq[to]] = 0.0
    end

    if analysis.method.pq[from] != 0 && analysis.method.pq[to] != 0
        jcbQ[analysis.method.pq[from], analysis.method.pq[to]] = 0.0
        jcbQ[analysis.method.pq[to], analysis.method.pq[from]] = 0.0
    end
    if system.bus.layout.type[from] == 1
        jcbQ[analysis.method.pq[from], analysis.method.pq[from]] = 0.0
    end
    if system.bus.layout.type[to] == 1
        jcbQ[analysis.method.pq[to], analysis.method.pq[to]] = 0.0
    end

    @inbounds for idx = 1:system.branch.number
        if system.branch.layout.status[idx] == 1
            i, j = fromto(system, idx)

            if i ∉ (from, to) && j ∉ (from, to)
                continue
            end

            p, q = jacobianCoefficient(system, analysis.method, idx)

            if (from, to) == (i, j) || (to, from) == (i, j)
                Pijθij(system, analysis.method, p, i, j)
                QijVij(analysis.method, q, i, j)
            end
            if i ∈ (from, to)
                Pijθi(system, analysis.method, p, i)
                QijVi(system, analysis.method, q, i)
            end
            if j ∈ (from, to)
                Pijθj(system, analysis.method, p, j)
                QijVj(system, analysis.method, q, j)
            end
        end
    end

    @inbounds for i ∈ (from, to)
        if system.bus.layout.type[i] == 1
            jcbQ[analysis.method.pq[i], analysis.method.pq[i]] += system.bus.shunt.susceptance[i]
        end
    end
end

function _updateBranch!(analysis::DcPowerFlow, ::Int64)
    errorTypeConversion(analysis.system.bus.layout.slack, analysis.method.signature[:slack])
end

function _updateBranch!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    i, j = fromto(system, idx)

    remove!(jump, con.balance.active, i)
    remove!(jump, con.balance.reactive, i)
    addBalance(system, jump, var, con, i)

    remove!(jump, con.balance.active, j)
    remove!(jump, con.balance.reactive, j)
    addBalance(system, jump, var, con, j)

    remove!(jump, con.flow.from, idx)
    remove!(jump, con.flow.to, idx)
    remove!(jump, con.voltage.angle, idx)

    if system.branch.layout.status[idx] == 1
        addFlow(system, jump, var.voltage, con, QuadExpr(), QuadExpr(), idx)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, AffExpr(), idx)
    end
end

function _updateBranch!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    jump = analysis.method.jump
    var = analysis.method.variable
    con = analysis.method.constraint

    i, j = fromto(system, idx)
    expr = AffExpr()

    remove!(jump, con.balance.active, i)
    addBalance(system, jump, var, con, expr, i)

    remove!(jump, con.balance.active, j)
    addBalance(system, jump, var, con, expr, j)

    remove!(jump, con.flow.active, idx)
    remove!(jump, con.voltage.angle, idx)

    if system.branch.layout.status[idx] == 1
        addFlow(system, jump, var.voltage.angle, con.flow.active, expr, idx)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr, idx)
    end
end

"""
    @branch(kwargs...)

The macro generates a template for a branch.

# Keywords
To define the branch template, the `kwargs` input arguments must be provided in accordance with the
keywords specified within the [`addBranch!`](@ref addBranch!) function, along with their
corresponding values.

# Units
The default units for the keyword parameters are per-units and radians. However, the user can choose
to use other units besides per-units and radians by utilizing macros such as [`@power`](@ref @power),
[`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

# Examples
Adding a branch template using the default unit system:
```jldoctest
@branch(reactance = 0.12, shiftAngle = 0.1745)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
```

Adding a branch template using a custom unit system:
```jldoctest
@voltage(pu, deg)
@branch(shiftAngle = 10)

system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1,  active = 0.15, reactive = 0.08)

addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
```
"""
macro branch(kwargs...)
    kwargs_escaped = esc(kwargs)

    quote
        for kwarg in $kwargs_escaped
            parameter::Symbol = kwarg.args[1]
            if parameter == :type
                setfield!(template.branch, parameter, Int8(eval(kwarg.args[2])))
            end
        end

        for kwarg in $kwargs_escaped
            parameter::Symbol = kwarg.args[1]

            if hasfield(BranchTemplate, parameter)
                if parameter ∉ (:status, :type, :label, :turnsRatio)
                    container::ContainerTemplate = getfield(template.branch, parameter)
                    if parameter in (:resistance, :reactance)
                        pfxLive = pfx.impedance
                    elseif parameter in (:conductance, :susceptance)
                        pfxLive = pfx.admittance
                    elseif parameter in (:shiftAngle, :minDiffAngle, :maxDiffAngle)
                        pfxLive = pfx.voltageAngle
                    elseif parameter in (:minFromBus, :maxFromBus, :minToBus, :maxToBus)
                        if template.branch.type == 1
                            pfxLive = pfx.activePower
                        elseif template.branch.type in (2, 3)
                            pfxLive = pfx.apparentPower
                        elseif template.branch.type in (4, 5)
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
                        macroLabel(template.branch, kwarg.args[2], "[?]")
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end

##### Branch Flow Rating Type #####
function flowType(system::PowerSystem, pfx::PrefixLive, basePowerInv::Float64, idx::Int64)
    baseVoltg = system.base.voltage
    type = system.branch.flow.type[idx]

    if type == 1
        return pfx.activePower, basePowerInv, basePowerInv
    elseif type ∈ (2, 3)
        return pfx.apparentPower, basePowerInv, basePowerInv
    elseif type ∈ (4, 5)
        i, j = fromto(system, idx)

        return pfx.currentMagnitude,
            baseCurrentInv(basePowerInv, baseVoltg.value[i] * baseVoltg.prefix),
            baseCurrentInv(basePowerInv, baseVoltg.value[j] * baseVoltg.prefix)
    else
        throw(ErrorException("The value $type of the branch flow rating type is illegal."))
    end
end