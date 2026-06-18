"""
    addBranch!(system::PowerSystem;
        label, from, to, status,
        resistance, reactance, conductance, susceptance, turnsRatio, shiftAngle,
        minDiffAngle, maxDiffAngle, minFromBus, maxFromBus, minToBus, maxToBus, type)

The function adds a new branch to the `PowerSystem` type. A branch can be added between already
defined buses.

# Keywords
The main keywords used to define a branch are:
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

The following keywords are used only in optimal power flow analyses:
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

    return nothing
end

function addBranchMain!(system::PowerSystem, from::IntStr, to::IntStr, key::BranchKey)
    branch = system.branch
    param = branch.parameter
    def = template.branch

    if from == to
        throw(ErrorException("Invalid value for from or to keywords."))
    end

    fromIdx = getIndex(system.bus, from, "bus")
    toIdx = getIndex(system.bus, to, "bus")
    statusNew = coalesce(key.status, def.status)
    checkStatus(statusNew)

    turnsRatioNew = coalesce(key.turnsRatio, def.turnsRatio)
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = system.base.voltage.value[fromIdx] * system.base.voltage.prefix
    baseAdmInv = baseImpedance(baseVoltage, basePowerInv, turnsRatioNew)
    baseImpInv = 1 / baseAdmInv

    resistanceNew = topu(key.resistance, def.resistance, pfx.impedance, baseImpInv)
    reactanceNew = topu(key.reactance, def.reactance, pfx.impedance, baseImpInv)
    if resistanceNew == 0.0 && reactanceNew == 0.0
        throw(ErrorException("At least one of resistance or reactance is required."))
    end
    flowTypeNew = checkFlowType(system, key.type, def.type)

    idx = branch.number + 1
    setLabel(branch, idx, key.label, def.label, "branch")
    branch.number = idx

    push!(branch.layout.from, fromIdx)
    push!(branch.layout.to, toIdx)
    push!(branch.layout.status, statusNew)
    if statusNew == 1
        branch.layout.inservice += 1
    end

    push!(param.turnsRatio, turnsRatioNew)
    push!(param.resistance, resistanceNew)
    push!(param.reactance, reactanceNew)

    add!(param.conductance, key.conductance, def.conductance, pfx.admittance, baseAdmInv)
    add!(param.susceptance, key.susceptance, def.susceptance, pfx.admittance, baseAdmInv)
    add!(param.shiftAngle, key.shiftAngle, def.shiftAngle, pfx.voltageAngle, 1.0)

    if system.bus.layout.optimal
        add!(branch.voltage.minDiffAngle, key.minDiffAngle, def.minDiffAngle, pfx.voltageAngle, 1.0)
        add!(branch.voltage.maxDiffAngle, key.maxDiffAngle, def.maxDiffAngle, pfx.voltageAngle, 1.0)

        push!(branch.flow.type, flowTypeNew)

        pfxLive, baseInvFrom, baseInvTo = flowType(system, pfx, basePowerInv, branch.number)
        add!(branch.flow.minFromBus, key.minFromBus, def.minFromBus, pfxLive, baseInvFrom)
        add!(branch.flow.maxFromBus, key.maxFromBus, def.maxFromBus, pfxLive, baseInvFrom)
        add!(branch.flow.minToBus, key.minToBus, def.minToBus, pfxLive, baseInvTo)
        add!(branch.flow.maxToBus, key.maxToBus, def.maxToBus, pfxLive, baseInvTo)
    end

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

    topologyChanged!(system)

    return nothing
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
    syncTopology!(analysis)

    return nothing
end

function _addBranch!(analysis::AcPowerFlow{<:Union{NewtonRaphson, GaussSeidel}})
    errorTypeConversion(analysis.system.model.revision.type, analysis.method.signature.type)
end

function _addBranch!(analysis::AcPowerFlow{<:FastNewtonRaphson})
    errorTypeConversion(analysis.system.model.revision.type, analysis.method.signature.type)

    if analysis.system.branch.layout.status[analysis.system.branch.number] == 1
        jacobian(analysis.system, analysis, analysis.system.branch.number)
    end
    analysis.method.signature.jacobian = analysis.system.model.revision.acModel
end

function _addBranch!(analysis::DcPowerFlow)
    errorTypeConversion(analysis.system.model.revision.slack, analysis.method.signature.slack)
end

function _addBranch!(analysis::AcOptimalPowerFlow)
    system = analysis.system
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual

    if system.branch.layout.status[end] == 1
        i, j = fromto(system, system.branch.number)

        remove!(jump, moi, con.balance.active, dual.balance.active, i)
        remove!(jump, moi, con.balance.reactive, dual.balance.reactive, i)
        addBalance(system, jump, var, con, i)

        remove!(jump, moi, con.balance.active, dual.balance.active, j)
        remove!(jump, moi, con.balance.reactive, dual.balance.reactive, j)
        addBalance(system, jump, var, con, j)

        expr = AffQuadExpr()
        addFlow(system, jump, var.voltage, con, expr, system.branch.number)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr.aff, system.branch.number)
    end

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.acModel = revision.acModel
    signature.acOptimization = revision.acOptimization
end

function _addBranch!(analysis::DcOptimalPowerFlow)
    system = analysis.system
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual

    if system.branch.layout.status[end] == 1
        i, j = fromto(system, system.branch.number)
        expr = AffExpr()

        remove!(jump, moi, con.balance.active, dual.balance.active, i)
        addBalance(system, jump, var, con, expr, i)

        remove!(jump, moi, con.balance.active, dual.balance.active, j)
        addBalance(system, jump, var, con, expr, j)

        addFlow(system, jump, var.voltage.angle, con.flow.active, expr, system.branch.number)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr, system.branch.number)
    end

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.dcModel = revision.dcModel
    signature.dcOptimization = revision.dcOptimization
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

    return nothing
end

function updateBranchMain!(system::PowerSystem, label::IntStr, key::BranchKey)
    branch = system.branch
    ac = system.model.ac
    dc = system.model.dc

    idx = getIndex(branch, label, "branch")

    statusNew = key.status
    statusOld = branch.layout.status[idx]

    if ismissing(statusNew)
        statusNew = statusOld
    end
    checkStatus(statusNew)
    if system.bus.layout.optimal && isset(key.type)
        checkFlowType(system, key.type, branch.flow.type[idx])
    end

    hasAcModel = !isempty(ac.nodalMatrix)
    hasDcModel = !isempty(dc.nodalMatrix)
    shift = isset(key.shiftAngle)
    dcadm = isset(key.reactance) || isset(key.turnsRatio)
    pimodel = dcadm || isset(key.resistance) || isset(key.conductance) ||
        isset(key.susceptance) || shift

    if statusNew == 1 && statusOld == 0
        branch.layout.inservice += 1
    elseif statusNew == 0 && statusOld == 1
        branch.layout.inservice -= 1
    end

    if hasAcModel
        if statusOld == 1 && (statusNew == 0 || (statusNew == 1 && pimodel))
            acSubtractAdmittances!(ac, idx)
            acNodalUpdate!(system, idx)
            acSetZeros!(ac, idx)
        end
    end

    if hasDcModel
        if statusOld == 1
            if statusNew == 0 || (statusNew == 1 && (dcadm || shift))
                dc.admittance[idx] = -dc.admittance[idx]
                dcShiftUpdate!(system, idx)
                if statusNew == 0 || (statusNew == 1 && dcadm)
                    dcNodalUpdate!(system, idx)
                end
                dc.admittance[idx] = 0.0
            end
        end
    end

    baseInv = 1 / (system.base.power.value * system.base.power.prefix)

    if pimodel
        update!(branch.parameter.turnsRatio, key.turnsRatio, idx)

        baseVoltage = system.base.voltage.value[branch.layout.from[idx]] * system.base.voltage.prefix
        baseAdmInv = baseImpedance(baseVoltage, baseInv, branch.parameter.turnsRatio[idx])
        baseImpInv = 1 / baseAdmInv

        update!(branch.parameter.resistance, key.resistance, pfx.impedance, baseImpInv, idx)
        update!(branch.parameter.reactance, key.reactance, pfx.impedance, baseImpInv, idx)
        update!(branch.parameter.conductance, key.conductance, pfx.admittance, baseAdmInv, idx)
        update!(branch.parameter.susceptance, key.susceptance, pfx.admittance, baseAdmInv, idx)
        update!(branch.parameter.shiftAngle, key.shiftAngle, pfx.voltageAngle, 1.0, idx)
    end

    if hasAcModel
        if statusNew == 1 && (statusOld == 0 || (statusOld == 1 && pimodel))
            acParameterUpdate!(system, idx)
            acNodalUpdate!(system, idx)
        end
    end

    if hasDcModel
        if statusNew == 1
            if statusOld == 0 || (statusOld == 1 && (dcadm || shift))
                dcAdmittanceUpdate!(system, statusNew, idx)
                dcShiftUpdate!(system, idx)
                if statusOld == 0 || (statusOld == 1 && dcadm)
                    dcNodalUpdate!(system, idx)
                end
            end
        end
    end

    branch.layout.status[idx] = statusNew
    if statusNew != statusOld
        topologyChanged!(system)
    end

    if system.bus.layout.optimal
        angle = isset(key.minDiffAngle) || isset(key.maxDiffAngle)
        fromFlow = isset(key.minFromBus) || isset(key.maxFromBus)
        toFlow = isset(key.minToBus) || isset(key.maxToBus)
        flow = isset(key.type)

        if angle || fromFlow || toFlow || flow
            acOptimizationChanged!(system)
        end
        if angle || fromFlow || flow
            dcOptimizationChanged!(system)
        end

        update!(branch.voltage.minDiffAngle, key.minDiffAngle, pfx.voltageAngle, 1.0, idx)
        update!(branch.voltage.maxDiffAngle, key.maxDiffAngle, pfx.voltageAngle, 1.0, idx)
        update!(branch.flow.type, key.type, idx)

        pfxLive, baseInvFrom, baseInvTo = flowType(system, pfx, baseInv, idx)

        update!(branch.flow.minFromBus, key.minFromBus, pfxLive, baseInvFrom, idx)
        update!(branch.flow.maxFromBus, key.maxFromBus, pfxLive, baseInvFrom, idx)
        update!(branch.flow.minToBus, key.minToBus, pfxLive, baseInvTo, idx)
        update!(branch.flow.maxToBus, key.maxToBus, pfxLive, baseInvTo, idx)
    end

    return nothing
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

addBranch!(analysis; from = "Bus 13 LV", to = "Bus 14 LV", reactance = 0.21)
```
"""
function updateBranch!(analysis::PowerFlow; label::IntStr, kwargs...)
    updateBranchMain!(analysis.system, label, BranchKey(; kwargs...))
    _updateBranch!(analysis, getIndex(analysis.system.branch, label, "branch"))
    syncTopology!(analysis)

    return nothing
end

function syncTopology!(analysis::Union{AcPowerFlow, DcPowerFlow})
    analysis.method.signature.topology = analysis.system.model.revision.topology
end

function syncTopology!(analysis::DcOptimalPowerFlow)
    analysis.method.signature.topology = analysis.system.model.revision.topology
end

function syncTopology!(analysis::AcOptimalPowerFlow)
    analysis.method.signature.topology = analysis.system.model.revision.topology
end

function _updateBranch!(analysis::AcPowerFlow{<:Union{NewtonRaphson, GaussSeidel}}, ::Int64)
    errorTypeConversion(analysis.system.model.revision.type, analysis.method.signature.type)
end

function _updateBranch!(analysis::AcPowerFlow{<:FastNewtonRaphson}, idx::Int64)
    system = analysis.system
    jcbP = analysis.method.active.jacobian
    jcbQ = analysis.method.reactive.jacobian

    errorTypeConversion(system.model.revision.type, analysis.method.signature.type)

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

    @inbounds for br = 1:system.branch.number
        if system.branch.layout.status[br] == 1
            i, j = fromto(system, br)

            if i ∉ (from, to) && j ∉ (from, to)
                continue
            end

            p, q = jacobianCoefficient(system, analysis.method, br)

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
    analysis.method.signature.jacobian = system.model.revision.acModel
end

function _updateBranch!(analysis::DcPowerFlow, ::Int64)
    errorTypeConversion(analysis.system.model.revision.slack, analysis.method.signature.slack)
end

function _updateBranch!(analysis::AcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual

    i, j = fromto(system, idx)

    remove!(jump, moi, con.balance.active, dual.balance.active, i)
    remove!(jump, moi, con.balance.reactive, dual.balance.reactive, i)
    addBalance(system, jump, var, con, i)

    remove!(jump, moi, con.balance.active, dual.balance.active, j)
    remove!(jump, moi, con.balance.reactive, dual.balance.reactive, j)
    addBalance(system, jump, var, con, j)

    remove!(jump, moi, con.flow.from, dual.flow.from, idx)
    remove!(jump, moi, con.flow.to, dual.flow.to, idx)
    remove!(jump, moi, con.voltage.angle, dual.voltage.angle, idx)

    if system.branch.layout.status[idx] == 1
        expr = AffQuadExpr()
        addFlow(system, jump, var.voltage, con, expr, idx)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr.aff, idx)
    end

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.acModel = revision.acModel
    signature.acOptimization = revision.acOptimization
end

function _updateBranch!(analysis::DcOptimalPowerFlow, idx::Int64)
    system = analysis.system
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual

    i, j = fromto(system, idx)
    expr = AffExpr()

    remove!(jump, moi, con.balance.active, dual.balance.active, i)
    addBalance(system, jump, var, con, expr, i)

    remove!(jump, moi, con.balance.active, dual.balance.active, j)
    addBalance(system, jump, var, con, expr, j)

    remove!(jump, moi, con.flow.active, dual.flow.active, idx)
    remove!(jump, moi, con.voltage.angle, dual.voltage.angle, idx)

    if system.branch.layout.status[idx] == 1
        addFlow(system, jump, var.voltage.angle, con.flow.active, expr, idx)
        addAngle(system, jump, var.voltage.angle, con.voltage.angle, expr, idx)
    end

    revision = system.model.revision
    signature = analysis.method.signature
    signature.topology = revision.topology
    signature.dcModel = revision.dcModel
    signature.dcOptimization = revision.dcOptimization
end

function branchTemplatePrefix(parameter::Symbol)
    if parameter in (:resistance, :reactance)
        return pfx.impedance
    elseif parameter in (:conductance, :susceptance)
        return pfx.admittance
    elseif parameter in (:shiftAngle, :minDiffAngle, :maxDiffAngle)
        return pfx.voltageAngle
    elseif parameter in (:minFromBus, :maxFromBus, :minToBus, :maxToBus)
        if template.branch.type == 1
            return pfx.activePower
        elseif template.branch.type in (2, 3)
            return pfx.apparentPower
        elseif template.branch.type in (4, 5)
            return pfx.currentMagnitude
        end
    end
end

function setBranchTemplate!(parameter::Symbol, value)
    if hasfield(BranchTemplate, parameter)
        if parameter ∉ (:status, :type, :label, :turnsRatio)
            container::ContainerTemplate = getfield(template.branch, parameter)
            setContainerTemplate!(container, value, branchTemplatePrefix(parameter))
        elseif parameter == :type
            setfield!(template.branch, parameter, Int8(value))
        elseif parameter == :status
            setfield!(template.branch, parameter, Int8(value))
        elseif parameter == :turnsRatio
            setfield!(template.branch, parameter, Float64(value))
        elseif parameter == :label
            macroLabel(template.branch, value, "[?]")
        end
    else
        errorTemplateKeyword(parameter)
    end

    return nothing
end

"""
    @branch(kwargs...)

The macro generates a template for a branch.

The macro modifies global JuliaGrid settings that remain active until changed again.

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
    typeExprs = Expr[]
    exprs = Expr[]

    for kwarg in kwargs
        if !(kwarg isa Expr) || kwarg.head != :(=)
            push!(exprs, :(errorTemplateKeyword($(QuoteNode(kwarg)))))
            continue
        end

        parameter = kwarg.args[1]
        value = kwarg.args[2]
        call = :(setBranchTemplate!($(QuoteNode(parameter)), $(esc(value))))

        if parameter == :type
            push!(typeExprs, call)
        else
            push!(exprs, call)
        end
    end

    return Expr(:block, typeExprs..., exprs...)
end

##### Branch Flow Rating Type #####
function checkFlowType(system::PowerSystem, type::Union{Int8, Int64, Missing}, default::Int8)
    if !system.bus.layout.optimal
        return default
    end

    typeNew = coalesce(type, default)
    if typeNew ∉ (1, 2, 3, 4, 5)
        throw(ErrorException("The value $typeNew of the branch flow rating type is illegal."))
    end

    return Int8(typeNew)
end

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
