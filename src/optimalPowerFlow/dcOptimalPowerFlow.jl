######### DC Optimal Power Flow ##########
struct DCOptimalPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    jump::JuMP.Model
    constraint::Constraint
end

"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name, balance, limit,
        rating, capability)

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
- `rating`: controls the inequality constraints that relate to the long-term rating of branches;
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

Create the DC optimal power flow model without `rating` constraints:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, HiGHS.Optimizer; rating = false)
```
"""
function dcOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true,
    balance::Bool = true, limit::Bool = true,
    rating::Bool = true,  capability::Bool = true)

    bus = system.bus
    branch = system.branch
    generator = system.generator

    if isempty(system.model.dc.nodalMatrix)
        dcModel!(system)
    end

    model = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(model, name)

    @variable(model, active[i = 1:generator.number])
    @variable(model, angle[i = 1:bus.number])

    slackRef = @constraint(model, angle[bus.layout.slack] == system.bus.voltage.angle[bus.layout.slack])

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
                    @info("The generator with label $(generator.label[i]) has a polynomial cost function of degree $(numberTerm-1), which is not included in the objective.")
                else
                    @info("The generator with label $(generator.label[i]) has an undefined polynomial cost function, which is not included in the objective.")
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
                    throw(ErrorException("The generator with label $(generator.label[i]) has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator with label $(generator.label[i]) has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end

            if capability
                capabilityRef[i] = @constraint(model, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i])
            end
        else
            fix(active[i], 0.0)
        end
    end

    if !isempty(idxPiecewise)
        @variable(model, helper[i = 1:length(idxPiecewise)])
    end

    piecewiseRef = [Array{JuMP.ConstraintRef}(undef, 0) for i = 1:system.generator.number]
    @inbounds for (k, i) in enumerate(idxPiecewise)
        add_to_expression!(objExpr, helper[k])

        activePower = @view generator.cost.active.piecewise[i][:, 1]
        activePowerCost = @view generator.cost.active.piecewise[i][:, 2]

        point = size(generator.cost.active.piecewise[i], 1)
        piecewiseRef[i] = Array{JuMP.ConstraintRef}(undef, point - 1)
        for j = 2:point
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                throw(ErrorException("The piecewise linear cost function's slope of the generator labeled as $(generator.label[i]) has infinite value."))
            end

            piecewiseRef[i][j-1] = @constraint(model, slope * active[i] - helper[k] <= slope * activePower[j-1] - activePowerCost[j-1])
        end
    end

    @objective(model, Min, objExpr)

    balanceRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    if balance
        @inbounds for i = 1:bus.number
            expression = AffExpr(bus.demand.active[i] + bus.shunt.conductance[i] + system.model.dc.shiftActivePower[i])
            for j in system.model.dc.nodalMatrix.colptr[i]:(system.model.dc.nodalMatrix.colptr[i + 1] - 1)
                add_to_expression!(expression, system.model.dc.nodalMatrix.nzval[j], angle[system.model.dc.nodalMatrix.rowval[j]])
            end
            balanceRef[i] = @constraint(model, expression - sum(active[k] for k in system.bus.supply.generator[i]) == 0.0)
        end
    end

    ratingRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    limitRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    if rating || limit
        @inbounds for i = 1:branch.number
            if branch.layout.status[i] == 1
                f = branch.layout.from[i]
                t = branch.layout.to[i]

                if rating && branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                    restriction = branch.rating.longTerm[i] / system.model.dc.admittance[i]
                    ratingRef[i] = @constraint(model, - restriction + branch.parameter.shiftAngle[i] <= angle[f] - angle[t] <= restriction + branch.parameter.shiftAngle[i])
                end
                if limit && branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                    limitRef[i] = @constraint(model, branch.voltage.minDiffAngle[i] <= angle[f] - angle[t] <= branch.voltage.maxDiffAngle[i])
                end
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
        model,
        Constraint(
            PolarAngleRef(slackRef),
            CartesianRealRef(balanceRef),
            PolarAngleRef(limitRef),
            CartesianRealRef(ratingRef),
            CartesianRealRef(capabilityRef),
            CartesianRealRef(piecewiseRef)
        )
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