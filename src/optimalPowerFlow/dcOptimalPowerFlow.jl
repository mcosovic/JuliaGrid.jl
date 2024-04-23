"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name)

The function sets up the optimization model for solving the DC optimal power flow problem.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `optimizer` argument is also required to create and solve the optimization problem.
Specifically, JuliaGrid constructs the AC optimal power flow using the JuMP package and
provides support for commonly employed solvers. For more detailed information,
please consult the [JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Updates
If the DC model has not been created, the function automatically initiates an update within
the `dc` field of the `PowerSystem` type.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines
providedin the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/).
However, certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism;
- `name`: used to manage the creation of string names.
By default, these keyword settings are configured as `true`.

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the
following fields:
- `voltage`: the variable allocated to store the bus voltage angle;
- `power`: the variable allocated to store the active powers;
- `method`: the JuMP model, references to the variables, constraints, and objective.

# Examples
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
```
"""
function dcOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    generator = system.generator
    cost = generator.cost.active

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(system.model.dc.nodalMatrix)
        dcModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    active = @variable(jump, active[i = 1:generator.number])
    angle = @variable(jump, angle[i = 1:bus.number])

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slack = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    objective = @expression(jump, QuadExpr())
    actwise = Dict{Int64, VariableRef}()
    piecewise = Dict{Int64, Array{JuMP.ConstraintRef,1}}()
    capability = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            if cost.model[i] == 2
                term = length(cost.polynomial[i])
                if term == 3
                    polynomialQuadratic(objective, active[i], cost.polynomial[i])
                elseif term == 2
                    polynomialLinear(objective, active[i], cost.polynomial[i])
                elseif term == 1
                    add_to_expression!(objective, cost.polynomial[i][1])
                elseif term > 3
                    @info("The generator indexed $i has a polynomial cost function of degree $(term-1), which is not included in the objective.")
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif cost.model[i] == 1
                point = size(cost.piecewise[i], 1)
                if point == 2
                    piecewiseLinear(objective, active[i], cost.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, objective, actwise, i; name = "actwise")
                    addPiecewise(jump, active[i], actwise[i], piecewise, cost.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end
            addCapability(jump, active[i], capability, generator.capability.minActive, generator.capability.maxActive, i)
        else
            fix!(active[i], 0.0, capability, i)
        end
    end

    @objective(jump, Min, objective)

    balance = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:bus.number
        addBalance(system, jump, active, angle, balance, i)
    end

    flow = Dict{Int64, JuMP.ConstraintRef}()
    voltage = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            addFlow(system, jump, angle, flow, i)
            addAngle(system, jump, angle, voltage, i)
        end
    end

    return DCOptimalPowerFlow(
        PolarAngle(copy(bus.voltage.angle)),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(copy(generator.output.active))
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
            objective
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::DCOptimalPowerFlow)

The function solves the DC optimal power flow model, computing the active power outputs of
the generators, as well as the bus voltage angles.

# Updates
The calculated active powers, as well as voltage angles, are stored in the `voltage` and
`power.generator` fields of the `DCOptimalPowerFlow` type.

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

    @inbounds for i = 1:system.bus.number
        JuMP.set_start_value(variable.angle[i]::JuMP.VariableRef, analysis.voltage.angle[i])
    end
    @inbounds for i = 1:system.generator.number
        JuMP.set_start_value(variable.active[i]::JuMP.VariableRef, analysis.power.generator.active[i])
    end

    JuMP.optimize!(analysis.method.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(variable.angle[i]::JuMP.VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(variable.active[i]::JuMP.VariableRef)
    end
end

######### Balance Constraints ##########
function addBalance(system::PowerSystem, jump::JuMP.Model, active::Vector{VariableRef}, angle::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, i::Int64)
    dc = system.model.dc
    expression = AffExpr()
    for j in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        add_to_expression!(expression, dc.nodalMatrix.nzval[j], - angle[dc.nodalMatrix.rowval[j]])
    end
    rhs = system.bus.demand.active[i] + system.bus.shunt.conductance[i] + dc.shiftPower[i]
    ref[i] = @constraint(jump, expression + sum(active[k] for k in system.bus.supply.generator[i]) == rhs)

    return jump, ref
end

######### Flow Constraints ##########
function addFlow(system::PowerSystem, jump::JuMP.Model, angle::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    branch = system.branch
    if branch.flow.longTerm[index] ≉  0 && branch.flow.longTerm[index] < 10^16
        restriction = branch.flow.longTerm[index] / system.model.dc.admittance[index]
        ref[index] = @constraint(jump, - restriction + branch.parameter.shiftAngle[index] <= angle[branch.layout.from[index]] - angle[branch.layout.to[index]] <= restriction + branch.parameter.shiftAngle[index])
    end

    return jump, ref
end

######### Update Balance Constraints ##########
function updateBalance(system::PowerSystem, analysis::DCOptimalPowerFlow, index::Int64; voltage = false, rhs = false, power = -1, genIndex = 0)
    dc = system.model.dc
    jump = analysis.method.jump
    constraint = analysis.method.constraint
    variable = analysis.method.variable

    if haskey(constraint.balance.active, index) && is_valid(jump, constraint.balance.active[index])
        if voltage
            @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
                angle = variable.angle[dc.nodalMatrix.rowval[j]]
                JuMP.set_normalized_coefficient(constraint.balance.active[index], angle, 0)
                JuMP.set_normalized_coefficient(constraint.balance.active[index], angle, - dc.nodalMatrix.nzval[j])
            end
        end
        if power in [0, 1]
            JuMP.set_normalized_coefficient(constraint.balance.active[index], variable.active[genIndex], power)
        end
        if rhs
            JuMP.set_normalized_rhs(constraint.balance.active[index], system.bus.demand.active[index] + system.bus.shunt.conductance[index] + dc.shiftPower[index])
        end
    else
        addBalance(system, jump, variable.active, variable.angle, constraint.balance.active, index)
    end
end

######### Make Cost Expression ##########
function costExpr(cost::Cost, variable::JuMP.VariableRef, index::Int64, label::L; ac = false)
    isPowerwise = false
    isNonLin = false
    expr = QuadExpr()

    if cost.model[index] == 2
        term = length(cost.polynomial[index])
        if term == 3
            polynomialQuadratic(expr, variable, cost.polynomial[index])
        elseif term == 2
            polynomialLinear(expr, variable, cost.polynomial[index])
        elseif term == 1
            add_to_expression!(expr, cost.polynomial[index][1])
        elseif term > 3
            if ac
                polynomialQuadratic(expr, variable, cost.polynomial[index])
                isNonLin = true
            else
                @info("The generator labelled $label has a polynomial cost function of degree $(term-1), which is not included in the objective.")
            end
        else
            @info("The generator labelled $label has an undefined polynomial cost function, which is not included in the objective.")
        end
    elseif cost.model[index] == 1
        point = size(cost.piecewise[index], 1)
        if point == 2
            piecewiseLinear(expr, variable, cost.piecewise[index])
        elseif point > 2
            isPowerwise = true
        elseif point == 1
            throw(ErrorException("The generator labelled $label has a piecewise linear cost function with only one defined point."))
        else
            @info("The generator labelled $label has an undefined piecewise linear cost function, which is not included in the objective.")
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

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
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
