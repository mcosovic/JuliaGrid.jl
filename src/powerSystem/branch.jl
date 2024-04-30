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
* `longTerm` (pu, VA or W): Long-term flow rating (equal to zero for unlimited).
* `shortTerm` (pu, VA or W): Short-term flow rating (equal to zero for unlimited).
* `emergency` (pu, VA or W): Emergency flow rating (equal to zero for unlimited).
* `type`: types of `longTerm`, `shortTerm`, and `emergency` flow ratings:
  * `type = 1`: apparent power flow (pu or VA),
  * `type = 2`: active power flow (pu or W),
  * `type = 3`: current magnitude flow (pu or VA at 1 pu voltage).

# Updates
The function updates the `branch` field within the `PowerSystem` composite type, and in
cases where parameters impact variables in the `ac` and `dc` fields, it automatically
adjusts the fields. Furthermore, it guarantees that any modifications to the parameters
are transmitted to the  `Analysis` type.

# Default Settings
By default, certain keywords are assigned default values: `status = 1`, `turnsRatio = 1.0`,
`type = 1`, `minDiffAngle = -2pi`, and `maxDiffAngle = 2pi`. The rest of the keywords are
initialized with a value of zero. However, the user can modify these default settings by
utilizing the [`@branch`](@ref @branch) macro.

# Units
The default units for the keyword parameters are per-units (pu) and radians (rad). However,
the user can choose to use other units besides per-units and radians by utilizing macros such
as [`@power`](@ref @power), [`@voltage`](@ref @voltage), and [`@parameter`](@ref @parameter).

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
@voltage(pu, deg, kV)
system = powerSystem()

addBus!(system; label = "Bus 1", type = 3, active = 0.25, reactive = -0.04)
addBus!(system; label = "Bus 2", type = 1, active = 0.15, reactive = 0.08)

addBranch!(system; from = "Bus 1", to = "Bus 2", reactance = 0.12, shiftAngle = 10)
```
"""
function addBranch!(system::PowerSystem;
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    default = template.branch

    branch.number += 1
    setLabel(branch, label, default.label, "branch")

    if from == to
        throw(ErrorException("The provided value for the from or to keywords is not valid."))
    end

    push!(branch.layout.from, system.bus.label[getLabel(system.bus, from, "bus")])
    push!(branch.layout.to, system.bus.label[getLabel(system.bus, to, "bus")])

    push!(branch.layout.status, unitless(status, default.status))
    checkStatus(branch.layout.status[end])
    if branch.layout.status[end] == 1
        branch.layout.inservice += 1
    end

    push!(branch.parameter.turnsRatio, unitless(turnsRatio, default.turnsRatio))

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = system.base.voltage.value[branch.layout.from[end]] * system.base.voltage.prefix
    baseAdmittanceInv = baseImpedance(baseVoltage, basePowerInv, branch.parameter.turnsRatio[end])
    baseImpedanceInv = 1 / baseAdmittanceInv

    push!(branch.parameter.resistance, topu(resistance, default.resistance, prefix.impedance, baseImpedanceInv))
    push!(branch.parameter.reactance, topu(reactance, default.reactance, prefix.impedance, baseImpedanceInv))
    if branch.parameter.resistance[end] == 0.0 && branch.parameter.reactance[end] == 0.0
        throw(ErrorException("At least one of the keywords resistance or reactance must be provided."))
    end

    push!(branch.parameter.conductance, topu(conductance, default.conductance, prefix.admittance, baseAdmittanceInv))
    push!(branch.parameter.susceptance, topu(susceptance, default.susceptance, prefix.admittance, baseAdmittanceInv))
    push!(branch.parameter.shiftAngle, topu(shiftAngle, default.shiftAngle, prefix.voltageAngle, 1.0))

    push!(branch.voltage.minDiffAngle, topu(minDiffAngle, default.minDiffAngle, prefix.voltageAngle, 1.0))
    push!(branch.voltage.maxDiffAngle, topu(maxDiffAngle, default.maxDiffAngle, prefix.voltageAngle, 1.0))

    push!(branch.flow.type, unitless(type, default.type))
    if branch.flow.type[end] == 2
        prefixLive = prefix.activePower
    else
        prefixLive = prefix.apparentPower
    end
    push!(branch.flow.longTerm, topu(longTerm, default.longTerm, prefixLive, basePowerInv))
    push!(branch.flow.shortTerm, topu(shortTerm, default.shortTerm, prefixLive, basePowerInv))
    push!(branch.flow.emergency, topu(emergency, default.emergency, prefixLive, basePowerInv))

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

function addBranch!(system::PowerSystem, analysis::DCPowerFlow;
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)
end

function addBranch!(system::PowerSystem, analysis::Union{ACPowerFlow{NewtonRaphson}, ACPowerFlow{GaussSeidel}};
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)
end

function addBranch!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson};
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    bus = system.bus
    branch = system.branch
    active = analysis.method.active
    reactive = analysis.method.reactive

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    if branch.layout.status[branch.number] == 1
        fastNewtonRaphsonJacobian(system, analysis, branch.number, 1)
    end
end

function addBranch!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    if branch.layout.status[end] == 1
        from = branch.layout.from[end]
        to = branch.layout.to[end]

        rhs = isset(shiftAngle)
        updateBalance(system, analysis, from; voltage = true, rhs = rhs)
        updateBalance(system, analysis, to; voltage = true, rhs = rhs)

        addFlow(system, jump, variable.angle, constraint.flow.active, branch.number)
        addAngle(system, jump, variable.angle, constraint.voltage.angle, branch.number)
    end
end

function addBranch!(system::PowerSystem, analysis::ACOptimalPowerFlow;
    label::L = missing, from::L, to::L, status::A = missing,
    resistance::A = missing, reactance::A = missing, susceptance::A = missing,
    conductance::A = missing, turnsRatio::A = missing, shiftAngle::A = missing,
    minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    if branch.layout.status[end] == 1
        from = branch.layout.from[end]
        to = branch.layout.to[end]

        updateBalance(system, analysis, from; active = true, reactive = true)
        updateBalance(system, analysis, to; active = true, reactive = true)

        addFlow(system, jump, variable.magnitude, variable.angle, constraint.flow.from, constraint.flow.to, branch.number)
        addAngle(system, jump, variable.angle, constraint.voltage.angle, branch.number)
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
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    ac = system.model.ac
    dc = system.model.dc

    index = branch.label[getLabel(branch, label, "branch")]

    if ismissing(status)
        status = branch.layout.status[index]
    end
    checkStatus(status)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    dcAdmittance = isset(reactance) || isset(turnsRatio)
    parameter = dcAdmittance || isset(resistance) || isset(conductance) || isset(susceptance) || isset(shiftAngle)

    if status == 1 && branch.layout.status[index] == 0
        branch.layout.inservice += 1
    elseif status == 0 && branch.layout.status[index] == 1
        branch.layout.inservice -= 1
    end

    if !isempty(ac.nodalMatrix)
        if branch.layout.status[index] == 1 && (status == 0 || (status == 1 && parameter))
            acSubtractAdmittances!(ac, index)
            acNodalUpdate!(system, index)
            acSetZeros!(ac, index)
        end
    end

    if !isempty(dc.nodalMatrix)
        if branch.layout.status[index] == 1 && (status == 0 || (status == 1 && dcAdmittance || isset(shiftAngle)))
            dc.admittance[index] = -dc.admittance[index]
            dcShiftUpdate!(system, index)
            if branch.layout.status[index] == 1 && (status == 0 || (status == 1 && dcAdmittance))
                dcNodalUpdate!(system, index)
            end
            dc.admittance[index] = 0.0
        end
    end

    if parameter
        if isset(turnsRatio)
            branch.parameter.turnsRatio[index] = turnsRatio
        end

        baseVoltage = system.base.voltage.value[branch.layout.from[index]] * system.base.voltage.prefix
        baseAdmittanceInv = baseImpedance(baseVoltage, basePowerInv, branch.parameter.turnsRatio[index])
        baseImpedanceInv = 1 / baseAdmittanceInv

        if isset(resistance)
            branch.parameter.resistance[index] = topu(resistance, prefix.impedance, baseImpedanceInv)
        end
        if isset(reactance)
            branch.parameter.reactance[index] = topu(reactance, prefix.impedance, baseImpedanceInv)
        end
        if isset(conductance)
            branch.parameter.conductance[index] = topu(conductance, prefix.admittance, baseAdmittanceInv)
        end
        if isset(susceptance)
            branch.parameter.susceptance[index] = topu(susceptance, prefix.admittance, baseAdmittanceInv)
        end
        if isset(shiftAngle)
            branch.parameter.shiftAngle[index] = topu(shiftAngle, prefix.voltageAngle, 1.0)
        end
    end

    if !isempty(ac.nodalMatrix)
        if status == 1 && (branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && parameter))
            acParameterUpdate!(system, index)
            acNodalUpdate!(system, index)
        end
    end

    if !isempty(dc.nodalMatrix)
        if status == 1 && (branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && dcAdmittance || isset(shiftAngle)))
            dcAdmittanceUpdate!(system, status, index)
            dcShiftUpdate!(system, index)
            if status == 1 && (branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && dcAdmittance))
                dcNodalUpdate!(system, index)
            end
        end
    end

    branch.layout.status[index] = status

    if isset(minDiffAngle)
        branch.voltage.minDiffAngle[index] = topu(minDiffAngle, prefix.voltageAngle, 1.0)
    end
    if isset(maxDiffAngle)
        branch.voltage.maxDiffAngle[index] = topu(maxDiffAngle, prefix.voltageAngle, 1.0)
    end

    if isset(type)
        branch.flow.type[index] = type
    end

    if isset(longTerm) || isset(shortTerm) || isset(emergency)
        if branch.flow.type[index] == 2
            prefixLive = prefix.activePower
        else
            prefixLive = prefix.apparentPower
        end
        if isset(longTerm)
            branch.flow.longTerm[index] = topu(longTerm, prefixLive, basePowerInv)
        end
        if isset(shortTerm)
            branch.flow.shortTerm[index] = topu(shortTerm, prefixLive, basePowerInv)
        end
        if isset(emergency)
            branch.flow.emergency[index] = topu(emergency, prefixLive, basePowerInv)
        end
    end
end

function updateBranch!(system::PowerSystem, analysis::DCPowerFlow;
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)
end

function updateBranch!(system::PowerSystem, analysis::Union{ACPowerFlow{NewtonRaphson}, ACPowerFlow{GaussSeidel}};
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)
end

function updateBranch!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson};
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    index = branch.label[getLabel(branch, label, "branch")]

    if branch.layout.status[index] == 1
        fastNewtonRaphsonJacobian(system, analysis, index, -1)
    end

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    if branch.layout.status[index] == 1
        fastNewtonRaphsonJacobian(system, analysis, index, 1)
    end
end

function updateBranch!(system::PowerSystem, analysis::DCOptimalPowerFlow;
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = branch.label[getLabel(branch, label, "branch")]
    statusOld = branch.layout.status[index]

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    parameter = isset(reactance) || isset(turnsRatio) || isset(shiftAngle)
    diffAngle = isset(minDiffAngle) || isset(maxDiffAngle)
    long = isset(longTerm)

    from = branch.layout.from[index]
    to = branch.layout.to[index]
    if parameter || branch.layout.status[index] != statusOld
        updateBalance(system, analysis, from; voltage = true, rhs = true)
        updateBalance(system, analysis, to; voltage = true, rhs = true)
    end

    if statusOld == 1
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && (parameter || long))
            remove!(jump, constraint.flow.active, index)
        end
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && diffAngle)
            remove!(jump, constraint.voltage.angle, index)
        end
    end

    if branch.layout.status[index] == 1
        if statusOld == 0 || (statusOld == 1 && (parameter || long))
            addFlow(system, jump, variable.angle, constraint.flow.active, index)
        end
        if statusOld == 0 || (statusOld == 1 && diffAngle)
            addAngle(system, jump, variable.angle, constraint.voltage.angle, index)
        end
    end
end

function updateBranch!(system::PowerSystem, analysis::ACOptimalPowerFlow;
    label::L, status::A = missing, resistance::A = missing, reactance::A = missing,
    susceptance::A = missing, conductance::A = missing, turnsRatio::A = missing,
    shiftAngle::A = missing, minDiffAngle::A = missing, maxDiffAngle::A = missing,
    longTerm::A = missing, shortTerm::A = missing, emergency::A = missing, type::A = missing)

    branch = system.branch
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    index = branch.label[getLabel(branch, label, "branch")]
    statusOld = branch.layout.status[index]

    updateBranch!(system; label, status, resistance, reactance, susceptance,
    conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
    emergency, type)

    parameter = isset(resistance) || isset(reactance) || isset(conductance) || isset(susceptance) || isset(turnsRatio) || isset(shiftAngle)
    diffAngle = isset(minDiffAngle) || isset(maxDiffAngle)
    long = isset(longTerm) || isset(type)

    from = branch.layout.from[index]
    to = branch.layout.to[index]
    if parameter || branch.layout.status[index] != statusOld
        updateBalance(system, analysis, from; active = true, reactive = true)
        updateBalance(system, analysis, to; active = true, reactive = true)
    end

    if statusOld == 1
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && (parameter || long))
            remove!(jump, constraint.flow.from, index)
            remove!(jump, constraint.flow.to, index)
        end
        if branch.layout.status[index] == 0 || (branch.layout.status[index] == 1 && diffAngle)
            remove!(jump, constraint.voltage.angle, index)
        end
    end

    if branch.layout.status[index] == 1
        if statusOld == 0 || (statusOld == 1 && (parameter || long))
            addFlow(system, jump, variable.magnitude, variable.angle, constraint.flow.from, constraint.flow.to, index)
        end
        if statusOld == 0 || (statusOld == 1 && diffAngle)
            addAngle(system, jump, variable.angle, constraint.voltage.angle, index)
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

        if hasfield(BranchTemplate, parameter)
            if !(parameter in [:status; :type; :label])
                container::ContainerTemplate = getfield(template.branch, parameter)
                if parameter in [:resistance; :reactance]
                    prefixLive = prefix.impedance
                elseif parameter in [:conductance; :susceptance]
                    prefixLive = prefix.admittance
                elseif parameter in [:shiftAngle; :minDiffAngle; :maxDiffAngle]
                    prefixLive = prefix.voltageAngle
                elseif parameter in [:longTerm; :shortTerm; :emergency]
                    if template.branch.type in [1, 3]
                        prefixLive = prefix.apparentPower
                    elseif template.branch.type == 2
                        prefixLive = prefix.activePower
                    end
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
                    setfield!(template.branch, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?")
                        setfield!(template.branch, parameter, label)
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