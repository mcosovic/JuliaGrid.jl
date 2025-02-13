"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name, silent, angle, active)

The function sets up the optimization model for solving the DC optimal power flow problem.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `optimizer` argument is also required to create and solve the optimization problem.
Specifically, JuliaGrid constructs the DC optimal power flow using the JuMP package and
provides support for commonly employed solvers. For more detailed information,
please consult the [JuMP documentation](https://jump.dev/jl/stable/packages/solvers/).

# Updates
If the DC model has not been created, the function automatically initiates an update within
the `dc` field of the `PowerSystem` type.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines
provided in the [JuMP documentation](https://jump.dev/jl/stable/reference/models/).
However, certain configurations may require different method calls, such as:
- `bridge`: manage the bridging mechanism (default: `false`),
- `name`: manage the creation of string names (default: `true`),
- `silent`: controls solver output display (default: `false`).

Additionally, users can modify variable names used for printing and writing through the
keywords `angle` and `active`. For instance, users can choose `angle = "θ"` to display
equations in a more readable format.

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the
following fields:
- `voltage`: The variable allocated to store the bus voltage angle,
- `power`: The variable allocated to store the active powers,
- `method`: The JuMP model, references to the variables, constraints, and objective.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
```
"""
function dcOptimalPowerFlow(
    system::PowerSystem,
    @nospecialize optimizerFactory;
    bridge::Bool = false,
    name::Bool = true,
    silent::Bool = false,
    angle::String = "angle",
    active::String = "active",
)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability
    cost = gen.cost.active

    checkSlackBus(system)
    model!(system, system.model.dc)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    if silent
        JuMP.set_silent(jump)
    end

    active = @variable(jump, active[i = 1:gen.number], base_name = active)
    angle = @variable(jump, angle[i = 1:bus.number], base_name = angle)

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slack = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    objective = @expression(jump, QuadExpr())
    actwise = Dict{Int64, VariableRef}()
    piecewise = Dict{Int64, Vector{ConstraintRef}}()
    capability = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            if cost.model[i] == 2
                term = length(cost.polynomial[i])
                if term == 3
                    polynomialQuad(objective, active[i], cost.polynomial[i])
                elseif term == 2
                    polynomialAff(objective, active[i], cost.polynomial[i])
                elseif term == 1
                    add_to_expression!(objective, cost.polynomial[i][1])
                elseif term > 3
                    infoObjective(iterate(gen.label, i)[1][1], term)
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            elseif cost.model[i] == 1
                point = size(cost.piecewise[i], 1)
                if point == 2
                    piecewiseAff(objective, active[i], cost.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, objective, actwise, i, "actwise")
                    addPiecewise(jump, active, actwise, piecewise, cost.piecewise, point, i)
                elseif point == 1
                    errorOnePoint(iterate(gen.label, i)[1][1])
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            end
            addCapability(jump, active, capability, cbt.minActive, cbt.maxActive, i)
        else
            fix!(active[i], 0.0, capability, i)
        end
    end

    @objective(jump, Min, objective)

    balance = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:bus.number
        addBalance(system, jump, active, angle, balance, i)
    end

    flow = Dict{Int64, ConstraintRef}()
    voltage = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            addFlow(system, jump, angle, flow, i)
            addAngle(system, jump, angle, voltage, i)
        end
    end

    DCOptimalPowerFlow(
        PolarAngle(
            copy(bus.voltage.angle)
        ),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(copy(gen.output.active))
        ),
        DCOptimalPowerFlowMethod(
            jump,
            DCVariable(
                active,
                angle,
                actwise
            ),
            DCConstraint(
                PolarAngleRef(slack),
                CartesianRealRef(balance),
                PolarAngleRef(voltage),
                CartesianRealRef(flow),
                CartesianRealRef(capability),
                DCPiecewise(piecewise)
            ),
            DCDual(
                PolarAngleDual(Dict{Int64, Float64}()),
                CartesianRealDual(Dict{Int64, Float64}()),
                PolarAngleDual(Dict{Int64, Float64}()),
                CartesianRealDual(Dict{Int64, Float64}()),
                CartesianRealDual(Dict{Int64, Float64}()),
                DCPiecewiseDual(Dict{Int64, Vector{Float64}}())
            ),
            objective
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::DCOptimalPowerFlow)

The function solves the DC optimal power flow model, computing the active power outputs of
the generators, as well as the bus voltage angles.

# Updates
The calculated active powers, as well as voltage angles, are stored in the
`power.generator` and `voltage` fields of the `DCOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCOptimalPowerFlow)
    variable = analysis.method.variable
    constr = analysis.method.constraint
    dual = analysis.method.dual

    @inbounds for i = 1:system.bus.number
        set_start_value(variable.angle[i]::VariableRef, analysis.voltage.angle[i])
    end
    @inbounds for i = 1:system.generator.number
        set_start_value(variable.active[i]::VariableRef, analysis.power.generator.active[i])
    end

    try
        setdual!(analysis.method.jump, constr.slack.angle, dual.slack.angle)
        setdual!(analysis.method.jump, constr.balance.active, dual.balance.active)
        setdual!(analysis.method.jump, constr.voltage.angle, dual.voltage.angle)
        setdual!(analysis.method.jump, constr.flow.active, dual.flow.active)
        setdual!(analysis.method.jump, constr.capability.active, dual.capability.active)
        setdual!(analysis.method.jump, constr.piecewise.active, dual.piecewise.active)
    catch
    end

    optimize!(analysis.method.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(variable.angle[i]::VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(variable.active[i]::VariableRef)
    end

    if has_duals(analysis.method.jump)
        dual!(analysis.method.jump, constr.slack.angle, dual.slack.angle)
        dual!(analysis.method.jump, constr.balance.active, dual.balance.active)
        dual!(analysis.method.jump, constr.voltage.angle, dual.voltage.angle)
        dual!(analysis.method.jump, constr.flow.active, dual.flow.active)
        dual!(analysis.method.jump, constr.capability.active, dual.capability.active)
        dual!(analysis.method.jump, constr.piecewise.active, dual.piecewise.active)
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    active::Vector{VariableRef},
    angle::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    i::Int64
)
    bus = system.bus
    dc = system.model.dc

    expr = AffExpr()
    for ptr in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        j = dc.nodalMatrix.rowval[ptr]
        add_to_expression!(expr, dc.nodalMatrix.nzval[ptr], -angle[j])
    end
    rhs = bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftPower[i]
    if haskey(bus.supply.generator, i)
        ref[i] = @constraint(jump, expr + sum(active[k] for k in bus.supply.generator[i]) == rhs)
    else
        ref[i] = @constraint(jump, expr == rhs)
    end

    return jump, ref
end

##### Flow Constraints #####
function addFlow(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    i::Int64
)
    branch = system.branch
    dc = system.model.dc

    if branch.flow.minFromBus[i] != 0.0 || branch.flow.maxFromBus[i] != 0.0
        from, to = fromto(system, i)
        expr = dc.admittance[i] * (angle[from] - angle[to] - branch.parameter.shiftAngle[i])

        ref[i] = @constraint(
            jump, branch.flow.minFromBus[i] <= expr <= branch.flow.maxFromBus[i]
        )
    end

    return jump, ref
end

##### Update Balance Constraints #####
function updateBalance(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    idx::Int64;
    voltage::Bool = false,
    rhs::Bool = false,
    power::Int64 = -1,
    idxGen::Int64 = 0
)
    bus = system.bus
    dc = system.model.dc
    nodal = dc.nodalMatrix
    jump = analysis.method.jump
    constr = analysis.method.constraint
    varble = analysis.method.variable

    if haskey(constr.balance.active, idx) && is_valid(jump, constr.balance.active[idx])
        if voltage
            @inbounds for j in nodal.colptr[idx]:(nodal.colptr[idx + 1] - 1)
                angle = varble.angle[nodal.rowval[j]]
                set_normalized_coefficient(constr.balance.active[idx], angle, 0)
                set_normalized_coefficient(constr.balance.active[idx], angle, -nodal.nzval[j])
            end
        end
        if power in [0, 1]
            set_normalized_coefficient(constr.balance.active[idx], varble.active[idxGen], power)
        end
        if rhs
            expr = bus.demand.active[idx] + bus.shunt.conductance[idx] + dc.shiftPower[idx]
            set_normalized_rhs(constr.balance.active[idx], expr)
        end
    else
        addBalance(system, jump, varble.active, varble.angle, constr.balance.active, idx)
    end
end

##### Make Cost Expression #####
function costExpr(
    cost::Cost,
    variable::VariableRef,
    idx::Int64,
    label::IntStrMiss;
    ac::Bool = false
)
    isPowerwise = false
    isNonLin = false
    expr = QuadExpr()

    if cost.model[idx] == 2
        term = length(cost.polynomial[idx])
        if term == 3
            polynomialQuad(expr, variable, cost.polynomial[idx])
        elseif term == 2
            polynomialAff(expr, variable, cost.polynomial[idx])
        elseif term == 1
            add_to_expression!(expr, cost.polynomial[idx][1])
        elseif term > 3
            if ac
                polynomialQuad(expr, variable, cost.polynomial[idx])
                isNonLin = true
            else
                infoObjective(label, term)
            end
        else
            infoObjective(label)
        end
    elseif cost.model[idx] == 1
        point = size(cost.piecewise[idx], 1)
        if point == 2
            piecewiseAff(expr, variable, cost.piecewise[idx])
        elseif point > 2
            isPowerwise = true
        elseif point == 1
            errorOnePoint(label)
        else
            infoObjective(label)
        end
    end

    return expr, isPowerwise, isNonLin
end

"""
    startingPrimal!(system::PowerSystem, analysis::DCOptimalPowerFlow)

The function retrieves the active power outputs of the generators and the bus voltage
angles from the `PowerSystem` composite type. These values are then assigned to the
`DCOptimalPowerFlow` type, enabling users to initialize starting primal values according
to their requirements.

# Updates
This function only updates the `voltage` and `generator` fields of the `DCOptimalPowerFlow`
type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)

updateBus!(system, analysis; label = 14, active = 0.1, angle = -0.17)

startingPrimal!(system, analysis)
solve!(system, analysis)
```
"""
function startingPrimal!(system::PowerSystem, analysis::DCOptimalPowerFlow)
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = system.generator.output.active[i]
    end
end

"""
    startingDual!(system::PowerSystem, analysis::DCOptimalPowerFlow)

The function removes all values of the dual variables.

# Updates
This function only updates the `dual` field of the `DCOptimalPowerFlow`
type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)

updateBus!(system, analysis; label = 14, active = 0.1, angle = -0.17)

startingDual!(system, analysis)
solve!(system, analysis)
```
"""
function startingDual!(::PowerSystem, analysis::DCOptimalPowerFlow)
    dual = analysis.method.dual

    dual.slack.angle = Dict{Int64, Float64}()
    dual.balance.active = Dict{Int64, Float64}()
    dual.voltage.angle = Dict{Int64, Float64}()
    dual.flow.active = Dict{Int64, Float64}()
    dual.capability.active = Dict{Int64, Float64}()
    dual.piecewise.active = Dict{Int64, Vector{Float64}}()
end