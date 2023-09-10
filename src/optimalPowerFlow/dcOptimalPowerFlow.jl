"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the DC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `dc` field within the `PowerSystem` composite type has
not been created, the function will initiate an update automatically.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism;
- `name`: used to manage the creation of string names.

Moreover, we have included keywords that regulate the usage of different types of constraints:
- `balance`: controls the equality constraints that relate to the active power balance equations;
- `limit`: controls the inequality constraints that relate to the voltage angle differences between buses;
- `flow`: controls the inequality constraints that relate to the active power flow limits of branches;
- `capability`: controls the inequality constraints that relate to the active power generator outputs.

By default, all of these keywords are set to `true` and are of the `Bool` type.

# JuMP
The JuliaGrid builds the DC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the variable allocated to store the bus voltage angle,
- `power`: the variable allocated to store the active powers,
- `jump`: the JuMP model,
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

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end

    if isempty(system.model.dc.nodalMatrix)
        dcModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    @variable(jump, active[i = 1:generator.number])
    @variable(jump, angle[i = 1:bus.number])

    fix(angle[bus.layout.slack], system.bus.voltage.angle[bus.layout.slack])
    slackRef = FixRef(angle[bus.layout.slack])

    capabilityRef = Array{JuMP.ConstraintRef}(undef, generator.number)
    idxPiecewise = Array{Int64,1}(undef, 0); sizehint!(idxPiecewise, generator.number)
    objExpr = QuadExpr()
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            if generator.cost.active.model[i] == 2
                cost = generator.cost.active.polynomial[i]
                numberTerm = length(cost)
                if numberTerm == 3
                    add_to_expression!(objExpr, cost[1], active[i], active[i])
                    add_to_expression!(objExpr, cost[2], active[i])
                    add_to_expression!(objExpr, cost[3])
                elseif numberTerm == 2
                    add_to_expression!(objExpr, cost[1], active[i])
                    add_to_expression!(objExpr, cost[2])
                elseif numberTerm == 1
                    add_to_expression!(objExpr, cost[1])
                elseif numberTerm > 3
                    @info("The generator indexed as $i in the list possesses a polynomial cost function of degree $(numberTerm-1), which is not included in the objective.")
                else
                    @info("The generator indexed as $i in the list has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif generator.cost.active.model[i] == 1
                cost = generator.cost.active.piecewise[i]
                point = size(cost, 1)
                if point == 2
                    slope = (cost[2, 2] - cost[1, 2]) / (cost[2, 1] - cost[1, 1])
                    add_to_expression!(objExpr, slope, active[i])
                    add_to_expression!(objExpr, cost[1, 2] - cost[1, 1] * slope)
                elseif point > 2
                    push!(idxPiecewise, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed as $i in the list has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed as $i in the list has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end
            if generator.capability.minActive[i] != generator.capability.maxActive[i]
                capabilityRef[i] = @constraint(jump, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i])
            else
                fix(active[i], 0.0)
                capabilityRef[i] = FixRef(active[i])
            end
        else
            fix(active[i], 0.0)
            capabilityRef[i] = FixRef(active[i])
        end
    end

    if !isempty(idxPiecewise)
        @variable(jump, helper[i in idxPiecewise])
    end

    piecewiseRef = [Array{JuMP.ConstraintRef}(undef, 0) for i = 1:system.generator.number]
    @inbounds for i in idxPiecewise
        add_to_expression!(objExpr, helper[i])

        activePower = @view generator.cost.active.piecewise[i][:, 1]
        activePowerCost = @view generator.cost.active.piecewise[i][:, 2]

        point = size(generator.cost.active.piecewise[i], 1)
        piecewiseRef[i] = Array{JuMP.ConstraintRef}(undef, point - 1)
        for j = 2:point
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                throw(ErrorException("The piecewise linear cost function's slope of the generator labeled as $(generator.label[i]) has infinite value."))
            end

            piecewiseRef[i][j-1] = @constraint(jump, slope * active[i] - helper[i] <= slope * activePower[j-1] - activePowerCost[j-1])
        end
    end

    @objective(jump, Min, objExpr)

    balanceRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    @inbounds for i = 1:bus.number
        expression = AffExpr()
        rhs = bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftActivePower[i]
        for j in system.model.dc.nodalMatrix.colptr[i]:(system.model.dc.nodalMatrix.colptr[i + 1] - 1)
            add_to_expression!(expression, system.model.dc.nodalMatrix.nzval[j], - angle[system.model.dc.nodalMatrix.rowval[j]])
        end
        balanceRef[i] = @constraint(jump, expression + sum(active[k] for k in system.bus.supply.generator[i]) == rhs)
    end

    flowgRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    voltageRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            from = branch.layout.from[i]
            to = branch.layout.to[i]

            if branch.flow.longTerm[i] ≉  0 && branch.flow.longTerm[i] < 10^16
                restriction = branch.flow.longTerm[i] / system.model.dc.admittance[i]
                flowgRef[i] = @constraint(jump, - restriction + branch.parameter.shiftAngle[i] <= angle[from] - angle[to] <= restriction + branch.parameter.shiftAngle[i])
            end
            if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                voltageRef[i] = @constraint(jump, branch.voltage.minDiffAngle[i] <= angle[from] - angle[to] <= branch.voltage.maxDiffAngle[i])
            end
        end
    end

    return DCOptimalPowerFlow(
        PolarAngle(copy(system.bus.voltage.angle)),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(copy(system.generator.output.active))
        ),
        jump,
        DCConstraint(
            PolarAngleRefSimple(slackRef),
            CartesianRealRef(balanceRef),
            PolarAngleRef(voltageRef),
            CartesianRealRef(flowgRef),
            CartesianRealRef(capabilityRef),
            CartesianRealRefComplex(piecewiseRef)
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

# ######### Query About Active Cost ##########
# function addActiveCost!(system::PowerSystem, analysis::DCOptimalPowerFlow;
#     label::L, model::T = 0,
#     polynomial::Array{Float64,1} = Array{Float64}(undef, 0),
#     piecewise::Array{Float64,2} = Array{Float64}(undef, 0, 0))

#     checkUUID(system.uuid, analysis.uuid)
#     generator = system.generator
#     index = generator.label[getLabel(generator, label, "generator")]

#     objExprOld = QuadExpr()
#     idxPiecewise = false
#     if generator.cost.active.model[index] != 0
#         objExprOld, idxPiecewise = modifyObjective(system, analysis, objExprOld, idxPiecewise, index)
#     end

#     if idxPiecewise
#         # delete(analysis.jump, analysis.jump[:helper][index])
#         # unregister(analysis.jump, Symbol("helper[$index]"))
#     end

#     objExpr = QuadExpr()
#     idxPiecewise = false
#     objExpr, idxPiecewise = modifyObjective(system, analysis, objExpr, idxPiecewise, index)

#     push!(analysis.jump[:helper], @variable(analysis.jump, base_name = "helper[$index]"))

#     # push!(analysis.jump[:aaaaa], @variable(analysis.jump, base_name = "aaaaa[$index]"))
#     # display(haskey(analysis.jump, :helper))
# # aaa = 10
# # append!(analysis.jump[:helper], @variable(analysis.jump, base_name = "helper[$aaa]"))
#     # if idxPiecewise
#     #     display(haskey(analysis.jump, :helper))
#     #     @variable(model, helper[i in idxPiecewise])
#     # end

#     JuMP.set_objective_function(analysis.jump, objExpr - objExprOld)
# end

# function modifyObjective(system::PowerSystem, analysis::DCOptimalPowerFlow, objExpr::QuadExpr, idxPiecewise::Bool, index::Int64)
#     generator = system.generator
#     active = analysis.jump[:active]

#     idxPiecewise = false
#     if generator.layout.status[index] == 1
#         if generator.cost.active.model[index] == 2
#             cost = generator.cost.active.polynomial[index]
#             numberTerm = length(cost)
#             if numberTerm == 3
#                 add_to_expression!(objExprOld, cost[1], active[index], active[index])
#                 add_to_expression!(objExprOld, cost[2], active[index])
#                 add_to_expression!(objExprOld, cost[3])
#             elseif numberTerm == 2
#                 add_to_expression!(objExprOld, cost[1], active[index])
#                 add_to_expression!(objExprOld, cost[2])
#             elseif numberTerm == 1
#                 add_to_expression!(objExpr, cost[index])
#             elseif numberTerm > 3
#                 @info("The generator with label $label has a polynomial cost function of degree $(numberTerm-1), which is not included in the objective.")
#             else
#                 @info("The generator with label $label has an undefined polynomial cost function, which is not included in the objective.")
#             end
#         elseif generator.cost.active.model[index] == 1
#             cost = generator.cost.active.piecewise[index]
#             point = size(cost, 1)
#             if point == 2
#                 slope = (cost[2, 2] - cost[1, 2]) / (cost[2, 1] - cost[1, 1])
#                 add_to_expression!(objExprOld, slope, active[index])
#                 add_to_expression!(objExprOld, cost[1, 2] - cost[1, 1] * slope)
#             elseif point > 2
#                 idxPiecewise = true
#             elseif point == 1
#                 throw(ErrorException("The generator with label $label has a piecewise linear cost function with only one defined point."))
#             else
#                 @info("The generator with label $label has an undefined piecewise linear cost function, which is not included in the objective.")
#             end
#         end
#     end

#     return objExpr, idxPiecewise
# end

function changeBalance(system::PowerSystem, analysis::DCOptimalPowerFlow, index::Int64; voltage = false, power = false, rhs = false, genIndex = 0)
    bus = system.bus
    dc = system.model.dc

    jump = analysis.jump
    constraint = analysis.constraint

    if is_valid(analysis.jump, constraint.balance.active[index])
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
        expression = AffExpr()
        exprrhs = bus.demand.active[index] + bus.shunt.conductance[index] + dc.shiftActivePower[index]
        for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
            add_to_expression!(expression, dc.nodalMatrix.nzval[j], - jump[:angle][dc.nodalMatrix.rowval[j]])
        end
        constraint.balance.active[index] = @constraint(analysis.jump, sum(jump[:active][k] for k in bus.supply.generator[index]) + expression == exprrhs)
    end
end