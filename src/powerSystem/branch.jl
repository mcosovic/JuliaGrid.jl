"""
    addBranch!(system::PowerSystem, analysis::Analysis; label, from, to, status,
        resistance, reactance, conductance, susceptance, turnsRatio, shiftAngle,
        minDiffAngle, maxDiffAngle, longTerm, shortTerm, emergency, type)

The function adds a new branch to the `PowerSystem` composite type. A branch can be added
between already defined buses.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined approach circumvents the necessity
for completely reconstructing vectors and matrices when adding a new branch.

# Keywords
The branch is defined with the following keywords:
* `label`: unique label for the branch;
* `from`: from bus label, corresponds to the bus label;
* `to`: to bus label, corresponds to the bus label;
* `status`: operating status of the branch:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `resistance` (pu or Ω): series resistance;
* `reactance` (pu or Ω): series reactance;
* `conductance` (pu or S): total shunt conductance;
* `susceptance` (pu or S): total shunt susceptance;
* `turnsRatio`: transformer off-nominal turns ratio, equal to one for a line;
* `shiftAngle` (rad or deg): transformer phase shift angle, where positive value defines delay;
* `minDiffAngle` (rad or deg): minimum voltage angle difference value between from and to bus;
* `maxDiffAngle` (rad or deg): maximum voltage angle difference value between from and to bus;
* `longTerm` (pu or VA, W): long-term flow rating (equal to zero for unlimited);
* `shortTerm` (pu or VA, W): short-term flow rating (equal to zero for unlimited);
* `emergency` (pu or VA, W): emergency flow rating (equal to zero for unlimited);
* `type`: types of `longTerm`, `shortTerm`, and `emergency` flow ratings:
  * `type = 1`: apparent power flow (pu or VA);
  * `type = 2`: active power flow (pu or W);
  * `type = 3`: current magnitude flow (pu or VA at 1 pu voltage).

# Updates
The function updates the `branch` field within the `PowerSystem` composite type, and in
cases where parameters impact variables in the `ac` and `dc` fields, it automatically
adjusts the fields. Furthermore, it guarantees that any modifications to the parameters
are transmitted to the  `Analysis` type.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `turnsRatio = 1.0`,
and `type = 1`. The  rest of the keywords are initialized with a value of zero. However,
the user can modify these default settings by utilizing the [`@branch`](@ref @branch) macro.

# Units
The default units for the keyword parameters are per-units (pu) and radians (rad). However,
the user can choose to use other units besides per-units and radians by utilizing macros such
as [`@power`](@ref @power), [`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

# Examples
Creating a branch using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 0.1745)
```

Creating a branch using a custom unit system:
```jldoctest
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 10)
```
"""
function addBranch!(system::PowerSystem;
    label::L = missing, from::L, to::L, status::T = missing,
    resistance::T = missing, reactance::T = missing, susceptance::T = missing,
    conductance::T = missing, turnsRatio::T = missing, shiftAngle::T = missing,
    minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    branch = system.branch
    default = template.branch

    branch.number += 1
    setLabel(branch, system.uuid, label, "branch")

    if from == to
        throw(ErrorException("The provided value for the from or to keywords is not valid."))
    end

    push!(branch.layout.from, system.bus.label[getLabel(system.bus, from, "bus")])
    push!(branch.layout.to, system.bus.label[getLabel(system.bus, to, "bus")])

    push!(branch.layout.status, unitless(status, default.status))
    checkStatus(branch.layout.status[end])

    push!(branch.parameter.turnsRatio, unitless(turnsRatio, default.turnsRatio))

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = system.base.voltage.value[branch.layout.from[end]] * system.base.voltage.prefix
    baseAdmittanceInv = baseImpedance(baseVoltage, basePowerInv, branch.parameter.turnsRatio[end])
    baseImpedanceInv = 1 / baseAdmittanceInv

    push!(branch.parameter.resistance, topu(resistance, default.resistance, baseImpedanceInv, prefix.impedance))
    push!(branch.parameter.reactance, topu(reactance, default.reactance, baseImpedanceInv, prefix.impedance))
    if branch.parameter.resistance[end] == 0.0 && branch.parameter.reactance[end] == 0.0
        throw(ErrorException("At least one of the keywords resistance or reactance must be provided."))
    end

    push!(branch.parameter.conductance, topu(conductance, default.conductance, baseAdmittanceInv, prefix.admittance))
    push!(branch.parameter.susceptance, topu(susceptance, default.susceptance, baseAdmittanceInv, prefix.admittance))
    push!(branch.parameter.shiftAngle, tosi(shiftAngle, default.shiftAngle, prefix.voltageAngle))

    push!(branch.voltage.minDiffAngle, tosi(minDiffAngle, default.minDiffAngle, prefix.voltageAngle))
    push!(branch.voltage.maxDiffAngle, tosi(maxDiffAngle, default.maxDiffAngle, prefix.voltageAngle))

    push!(branch.flow.type, unitless(type, default.type))
    if branch.flow.type[end] == 2
        prefixLive = prefix.activePower
    else
        prefixLive = prefix.apparentPower
    end
    push!(branch.flow.longTerm, topu(longTerm, default.longTerm, basePowerInv, prefixLive))
    push!(branch.flow.shortTerm, topu(shortTerm, default.shortTerm, basePowerInv, prefixLive))
    push!(branch.flow.emergency, topu(emergency, default.emergency, basePowerInv, prefixLive))

    if !isempty(system.model.dc.nodalMatrix)
        nilModel!(system, :dcModelPushZeros)
        if branch.layout.status[system.branch.number] == 1
            dcParameterUpdate!(system, branch.number)
            dcNodalShiftUpdate!(system, branch.number)
        end
    end
    if !isempty(system.model.ac.nodalMatrix)
        nilModel!(system, :acModelPushZeros)
        if branch.layout.status[branch.number] == 1
            acParameterUpdate!(system, branch.number)
            acNodalUpdate!(system, branch.number)
        end
    end
end

function addBranch!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    throw(ErrorException("The DC power flow model cannot be reused when adding a new branch."))
end

function addBranch!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel};
    label::L = missing, from::L, to::L, status::T = missing,
    resistance::T = missing, reactance::T = missing, susceptance::T = missing,
    conductance::T = missing, turnsRatio::T = missing, shiftAngle::T = missing,
    minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
        conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
        emergency, type)
end

function addBranch!(system::PowerSystem, analysis::FastNewtonRaphson; kwargs...)
    throw(ErrorException("The fast Newton-Raphson model cannot be reused when adding a new branch."))
end

function addBranch!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L = missing, from::L, to::L, status::T = missing,
    resistance::T = missing, reactance::T = missing, susceptance::T = missing,
    conductance::T = missing, turnsRatio::T = missing, shiftAngle::T = missing,
    minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    branch = system.branch
    jump = analysis.jump
    constraint = analysis.constraint

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
        conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
        emergency, type)

    if branch.layout.status[end] == 1
        from = branch.layout.from[end]
        to = branch.layout.to[end]

        rhs = !ismissing(shiftAngle)
        changeBalance(system, analysis, from; voltage = true, rhs = rhs)
        changeBalance(system, analysis, to; voltage = true, rhs = rhs)

        angle = analysis.jump[:angle]
        if branch.flow.longTerm[end] ≉  0 && branch.flow.longTerm[end] < 10^16
            restriction = branch.flow.longTerm[end] / system.model.dc.admittance[end]
            flowRef = @constraint(jump, - restriction + branch.parameter.shiftAngle[end] <= angle[from] - angle[to] <= restriction + branch.parameter.shiftAngle[end])
            push!(constraint.flow.active, flowRef)
        else
            append!(constraint.flow.active, Array{JuMP.ConstraintRef}(undef, 1))
        end
        if branch.voltage.minDiffAngle[end] > -2*pi && branch.voltage.maxDiffAngle[end] < 2*pi
            voltageRef = @constraint(jump, branch.voltage.minDiffAngle[end] <= angle[from] - angle[to] <= branch.voltage.maxDiffAngle[end])
            push!(constraint.voltage.angle, voltageRef)
        else
            append!(constraint.voltage.angle, Array{JuMP.ConstraintRef}(undef, 1))
        end
    else
        append!(constraint.flow.active, Array{JuMP.ConstraintRef}(undef, 1))
        append!(constraint.voltage.angle, Array{JuMP.ConstraintRef}(undef, 1))
    end
end

"""
    updateBranch!(system::PowerSystem, analysis::Analysis; kwargs...)

The function allows for the alteration of parameters for an existing branch.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `PowerSystem`
composite type only. However, when including the `Analysis` type, it updates both the
`PowerSystem` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameter

# Keywords
To update a specific branch, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addBranch!`](@ref addBranch!) function, along with
their respective values. Ensure that the `label` keyword matches the label of the existing
branch you want to modify. If any keywords are omitted, their corresponding values will
remain unchanged.

# Updates
The function updates the `branch` field within the `PowerSystem` composite type, and in
cases where parameters impact variables in the `ac` and `dc` fields, it automatically
adjusts the fields. Furthermore, it guarantees that any modifications to the parameters
are transmitted to the `Analysis` type.

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
function updateBranch!(system::PowerSystem;
    label::L, status::T = missing, resistance::T = missing, reactance::T = missing,
    susceptance::T = missing, conductance::T = missing, turnsRatio::T = missing,
    shiftAngle::T = missing, minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    branch = system.branch
    ac = system.model.ac
    dc = system.model.dc

    index = branch.label[getLabel(branch, label, "branch")]

    if ismissing(status)
        status = branch.layout.status[index]
    end
    checkStatus(status)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    parameter = !ismissing(resistance) || !ismissing(reactance) || !ismissing(conductance) || !ismissing(susceptance) || !ismissing(turnsRatio) || !ismissing(shiftAngle)

    if branch.layout.status[index] == 1
        if status == 0 || (status == 1 && parameter)
            if !isempty(system.model.ac.nodalMatrix)
                nilModel!(system, :acModelDeprive; index = index)
                acNodalUpdate!(system, index)
                nilModel!(system, :acModelZeros; index = index)
            end
            if !isempty(system.model.dc.nodalMatrix)
                nilModel!(system, :dcModelDeprive; index = index)
                dcNodalShiftUpdate!(system, index)
                nilModel!(system, :dcModelZeros; index = index)
            end
        end
    end

    if parameter
        if !ismissing(turnsRatio)
            branch.parameter.turnsRatio[index] = turnsRatio
        end

        baseVoltage = system.base.voltage.value[branch.layout.from[index]] * system.base.voltage.prefix
        baseAdmittanceInv = baseImpedance(baseVoltage, basePowerInv, branch.parameter.turnsRatio[index])
        baseImpedanceInv = 1 / baseAdmittanceInv

        if !ismissing(resistance)
            branch.parameter.resistance[index] = topu(resistance, baseImpedanceInv, prefix.impedance)
        end
        if !ismissing(reactance)
            branch.parameter.reactance[index] = topu(reactance, baseImpedanceInv, prefix.impedance)
        end
        if !ismissing(conductance)
            branch.parameter.conductance[index] = topu(conductance, baseAdmittanceInv, prefix.admittance)
        end
        if !ismissing(susceptance)
            branch.parameter.susceptance[index] = topu(susceptance, baseAdmittanceInv, prefix.admittance)
        end
        if !ismissing(shiftAngle)
            branch.parameter.shiftAngle[index] = shiftAngle * prefix.voltageAngle
        end
    end

    if status == 1
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && parameter)
            if !isempty(dc.nodalMatrix)
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end
            if !isempty(ac.nodalMatrix)
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
        end
    end
    branch.layout.status[index] = status

    if !ismissing(minDiffAngle)
        branch.voltage.minDiffAngle[index] = minDiffAngle * prefix.voltageAngle
    end
    if !ismissing(maxDiffAngle)
        branch.voltage.maxDiffAngle[index] = maxDiffAngle * prefix.voltageAngle
    end

    if !ismissing(type)
        branch.flow.type[index] = type
    end

    if !ismissing(longTerm) || !ismissing(shortTerm) || !ismissing(emergency)
        if branch.flow.type[index] == 2
            prefixLive = prefix.activePower
        else
            prefixLive = prefix.apparentPower
        end
        if !ismissing(longTerm)
            branch.flow.longTerm[index] = topu(longTerm, basePowerInv, prefixLive)
        end
        if !ismissing(shortTerm)
            branch.flow.shortTerm[index] = topu(shortTerm, basePowerInv, prefixLive)
        end
        if !ismissing(emergency)
            branch.flow.emergency[index] = topu(emergency, basePowerInv, prefixLive)
        end
    end

end

function updateBranch!(system::PowerSystem, analysis::DCPowerFlow; kwargs...)
    throw(ErrorException("The DC power flow model cannot be reused when the branch is altered."))
end

function updateBranch!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel};
    label::L, status::T = missing, resistance::T = missing, reactance::T = missing,
    susceptance::T = missing, conductance::T = missing, turnsRatio::T = missing,
    shiftAngle::T = missing, minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)
end

function updateBranch!(system::PowerSystem, analysis::FastNewtonRaphson; kwargs...)
    throw(ErrorException("The fast Newton-Raphson model cannot be reused when the branch is altered."))
end

function updateBranch!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L, status::T = missing, resistance::T = missing, reactance::T = missing,
    susceptance::T = missing, conductance::T = missing, turnsRatio::T = missing,
    shiftAngle::T = missing, minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    checkUUID(system.uuid, analysis.uuid)

    branch = system.branch
    jump = analysis.jump
    constraint = analysis.constraint

    index = branch.label[getLabel(branch, label, "branch")]
    statusOld = branch.layout.status[index]

    updateBranch!(system; label, status, resistance, reactance, susceptance,
        conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
        emergency, type)

    angle = jump[:angle]
    from = branch.layout.from[index]
    to = branch.layout.to[index]

    parameter = !ismissing(reactance) || !ismissing(turnsRatio) || !ismissing(shiftAngle)
    diffAngle = !ismissing(minDiffAngle) || !ismissing(maxDiffAngle)
    long = !ismissing(longTerm)

    if parameter || branch.layout.status[index] != statusOld
        changeBalance(system, analysis, from; voltage = true, rhs = true)
        changeBalance(system, analysis, to; voltage = true, rhs = true)
    end

    if statusOld == 1
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && (parameter || long))
            JuMP.delete(jump, constraint.flow.active[index])
        end
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && diffAngle)
            JuMP.delete(jump, constraint.voltage.angle[index])
        end
    end

    if branch.layout.status[index] == 1
        if statusOld == 0 || (statusOld == 1 && (parameter || long))
            if branch.flow.longTerm[index] ≉  0 && branch.flow.longTerm[index] < 10^16
                restriction = branch.flow.longTerm[index] / system.model.dc.admittance[index]
                constraint.flow.active[index] = @constraint(jump, - restriction + branch.parameter.shiftAngle[index] <= angle[from] - angle[to] <= restriction + branch.parameter.shiftAngle[index])
            end
        end
        if statusOld == 0 || (statusOld == 1 && diffAngle)
            if branch.voltage.minDiffAngle[index] > -2*pi && branch.voltage.maxDiffAngle[index] < 2*pi
                constraint.voltage.angle[index] = @constraint(jump, branch.voltage.minDiffAngle[index] <= angle[from] - angle[to] <= branch.voltage.maxDiffAngle[index])
            end
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
Creating a branch template using the default unit system:
```jldoctest
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

@branch(reactance = 0.12, shiftAngle = 0.1745)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2")
```

Creating a branch template using a custom unit system:
```jldoctest
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1,  active = 0.15, reactive = 0.08)

@branch(shiftAngle = 10)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.12)
```
"""
macro branch(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]
        if parameter == :type
            setfield!(template.branch, parameter, Int8(eval(kwarg.args[2])))
        end
    end

    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]
        value::Float64 = Float64(eval(kwarg.args[2]))
        if hasfield(BranchTemplate, parameter)
            if !(parameter in [:status; :type; :shiftAngle; :minDiffAngle; :maxDiffAngle])
                container::ContainerTemplate = getfield(template.branch, parameter)
                if parameter in [:resistance; :reactance]
                    prefixLive = prefix.impedance
                elseif parameter in [:conductance; :susceptance]
                    prefixLive = prefix.admittance
                elseif parameter in [:longTerm; :shortTerm; :emergency]
                    if template.branch.type in [1, 3]
                        prefixLive = prefix.apparentPower
                    elseif template.branch.type == 2
                        prefixLive = prefix.activePower
                    end
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                if parameter in [:shiftAngle; :minDiffAngle; :maxDiffAngle]
                    setfield!(template.branch, parameter, value * prefix.voltageAngle)
                elseif parameter == :status
                    setfield!(template.branch, parameter, Int8(value))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end