"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the DC optimal power flow. If the `dc` field within the `PowerSystem` composite
type has not been created, the function will automatically  initiate an update process.

Additionally, the `optimizer` argument is a necessary component for formulating and solving the
optimization problem. Specifically, JuliaGrid constructs the DC optimal power flow using the
JuMP package and provides support for commonly employed solvers. For more detailed information,
please consult the [JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism;
- `name`: used to manage the creation of string names.
By default, these keyword settings are configured as `true`.

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the variable allocated to store the bus voltage angle;
- `power`: the variable allocated to store the active powers;
- `jump`: the JuMP model;
- `constraint`: holds the constraint references to the JuMP model.

# Examples
Create the complete DC optimal power flow model:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
```
"""
function dcOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    branch = system.branch
    generator = system.generator
    dc = system.model.dc
    cost = generator.cost.active

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    @variable(jump, active[i = 1:generator.number])
    @variable(jump, angle[i = 1:bus.number])

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slack = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    objExpr = QuadExpr()
    helper = Dict{Int64, VariableRef}()
    piecewise = Dict{Int64, Array{JuMP.ConstraintRef,1}}()
    capability = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            if cost.model[i] == 2
                term = length(cost.polynomial[i])
                if term == 3
                    objExpr = polynomialQuadratic(objExpr, active[i], cost.polynomial[i])
                elseif term == 2
                    objExpr = polynomialLinear(objExpr, active[i], cost.polynomial[i])
                elseif term == 1
                    add_to_expression!(objExpr, cost.polynomial[i][1])
                elseif term > 3
                    @info("The generator indexed $i has a polynomial cost function of degree $(term-1), which is not included in the objective.")
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif cost.model[i] == 1
                point = size(cost.piecewise[i], 1)
                if point == 2
                    objExpr = piecewiseLinear(objExpr, active[i], cost.piecewise[i])
                elseif point > 2
                    jump, objExpr, helper = addHelper(jump, objExpr, helper, i)
                    piecewise = addPiecewise(jump, helper[i], piecewise, cost.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end
            jump, capability = addCapability(jump, active, capability, generator.capability.minActive, generator.capability.maxActive, i)
        else
            fix!(active, 0.0, capability, i)
        end
    end

    @objective(jump, Min, objExpr)

    balance = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:bus.number
        jump, balance = addBalance(jump, active, angle, balance, dc, bus, i)
    end

    flow = Dict{Int64, JuMP.ConstraintRef}()
    voltage = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            jump, flow = addFlow(jump, angle, flow, branch, dc, i)
            jump, voltage = addDiffAngle(jump, angle, voltage, branch, i)
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
        jump,
        DCConstraint(
            PolarAngleRef(slack),
            CartesianRealRef(balance),
            PolarAngleRef(voltage),
            CartesianRealRef(flow),
            CartesianRealRef(capability),
            DCPiecewise(piecewise, helper)
        ),
        system.uuid
    )
end

"""
    solve!(system::PowerSystem, analysis::DCOptimalPowerFlow)

The function finds the DC optimal power flow solution and calculate the bus voltage angles
and output active powers of the generators.

The calculated voltage angles and active powers are then stored in the `angle` variable of
the `voltage` field and the `generator` variable of the `power` field.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCOptimalPowerFlow)
    angle = analysis.jump[:angle]::Vector{JuMP.VariableRef}
    active = analysis.jump[:active]::Vector{JuMP.VariableRef}

    @inbounds for i = 1:system.bus.number
        variable = angle[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.voltage.angle[i])
        end
    end
    @inbounds for i = 1:system.generator.number
        variable = active[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.power.generator.active[i])
        end
    end

    JuMP.optimize!(analysis.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(angle[i]::JuMP.VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(active[i]::JuMP.VariableRef)
    end
end

######### Balance Constraints ##########
function addBalance(jump::JuMP.Model, active::Vector{VariableRef}, angle::Vector{VariableRef},  ref::Dict{Int64, JuMP.ConstraintRef}, dc::DCModel, bus::Bus, i::Int64)
    expression = AffExpr()
    for j in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        add_to_expression!(expression, dc.nodalMatrix.nzval[j], - angle[dc.nodalMatrix.rowval[j]])
    end
    rhs = bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftActivePower[i]
    ref[i] = @constraint(jump, expression + sum(active[k] for k in bus.supply.generator[i]) == rhs)

    return jump, ref
end

######### Flow Constraints ##########
function addFlow(jump::JuMP.Model, angle::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, branch::Branch, dc::DCModel, index::Int64)
    if branch.flow.longTerm[index] ≉  0 && branch.flow.longTerm[index] < 10^16
        restriction = branch.flow.longTerm[index] / dc.admittance[index]
        ref[index] = @constraint(jump, - restriction + branch.parameter.shiftAngle[index] <= angle[branch.layout.from[index]] - angle[branch.layout.to[index]] <= restriction + branch.parameter.shiftAngle[index])
    end

    return jump, ref
end

######### Update Balance Constraints ##########
function updateBalance(system::PowerSystem, analysis::DCOptimalPowerFlow, index::Int64; voltage = false, power = false, rhs = false, genIndex = 0)
    bus = system.bus
    dc = system.model.dc
    jump = analysis.jump
    constraint = analysis.constraint

    if is_valid(jump, constraint.balance.active[index])
        if voltage
            @inbounds for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
                angle = jump[:angle][dc.nodalMatrix.rowval[j]]
                JuMP.set_normalized_coefficient(constraint.balance.active[index], angle, 0)
                JuMP.set_normalized_coefficient(constraint.balance.active[index], angle, - dc.nodalMatrix.nzval[j])
            end
        end
        if power
            JuMP.set_normalized_coefficient(constraint.balance.active[index], jump[:active][genIndex], 1)
        end
        if rhs
            JuMP.set_normalized_rhs(constraint.balance.active[index], bus.demand.active[index] + bus.shunt.conductance[index] + dc.shiftActivePower[index])
        end
    else
        addBalance(jump, jump[:active], jump[:angle], constraint.balance.active, dc, bus, index)
    end
end

######### Update Objective Function ##########
function updateObjective(objExpr::QuadExpr, active::JuMP.VariableRef, generator::Generator, index::Int64, label::L)
    ishelper = false

    if generator.cost.active.model[index] == 2
        cost = generator.cost.active.polynomial[index]
        numberTerm = length(cost)
        if numberTerm == 3
            polynomialQuadratic(objExpr, active, cost)
        elseif numberTerm == 2
            polynomialLinear(objExpr, active, cost)
        elseif numberTerm == 1
            add_to_expression!(objExpr, cost[1])
        elseif numberTerm > 3
            @info("The generator labelled $label has a polynomial cost function of degree $(numberTerm-1), which is not included in the objective.")
        else
            @info("The generator labelled $label has an undefined polynomial cost function, which is not included in the objective.")
        end
    elseif generator.cost.active.model[index] == 1
        piecewise = generator.cost.active.piecewise[index]
        point = size(piecewise, 1)
        if point == 2
            piecewiseLinear(objExpr, active, piecewise)
        elseif point > 2
            ishelper = true
        elseif point == 1
            throw(ErrorException("The generator labelled $label has a piecewise linear cost function with only one defined point."))
        else
            @info("The generator labelled $label has an undefined piecewise linear cost function, which is not included in the objective.")
        end
    end

    return objExpr, ishelper
end