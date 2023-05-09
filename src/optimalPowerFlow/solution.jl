######### DC Optimal Power Flow ##########
struct DCOptimalPowerFlow
    voltage::PolarAngle
    output::CartesianReal
    jump::JuMP.Model
end

"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer; bridges, names, slack, capability,
        rating, difference, balance)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the DC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `dcModel` field within the `PowerSystem` composite
type has not been created, the function will initiate an update automatically.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However,
certain configurations may require different method calls, such as:
- `bridges`: used to manage the bridging mechanism
- `names`: used to manage the creation of string names.

Moreover, we have included keywords that regulate the usage of different types of constraints:
- `slack`: controls the equality constraint associated with the slack bus
- `capability`: controls the inequality constraints that relate to the active power generator outputs
- `rating`: controls the inequality constraints that relate to the long-term rating of branches
- `difference`: controls the inequality constraints that relate to the voltage angle differences between buses
- `balance`: controls the equality constraints that relate to the power balance equations.

By default, all of these keywords are set to `true` and are of the `Bool` type.

# JuMP
The JuliaGrid builds the DC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the angles of bus voltages
- `output`: the active power output of the generators
- `jump`: the JuMP model.

# Examples
Create the complete DC optimal power flow model:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system, HiGHS.Optimizer)
```

Create the DC optimal power flow model without `rating` constraints:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system, HiGHS.Optimizer; rating = false)
```
"""
function dcOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizer_factory);
    bridges::Bool = true, names::Bool = true,
    slack::Bool = true, capability::Bool = true, rating::Bool = true,
    difference::Bool = true, balance::Bool = true)

    bus = system.bus
    branch = system.branch
    generator = system.generator

    if isempty(system.dcModel.nodalMatrix)
        dcModel!(system)
    end

    model = Model(optimizer_factory; add_bridges = bridges)
    set_string_names_on_creation(model, names)


    @variable(model, angle[i = 1:bus.number])
    @variable(model, active[i = 1:generator.number])

    if slack
        @constraint(model, angle[bus.layout.slack] == system.bus.voltage.angle[bus.layout.slack], base_name = "slack")
    end

    idxPiecewise = Array{Int64,1}(undef, 0); sizehint!(idxPiecewise, generator.number)
    objExpression = QuadExpr()
    supplyActive = zeros(AffExpr, system.bus.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = generator.layout.bus[i]
            supplyActive[busIndex] += active[i]

            if generator.cost.active.model[i] == 2
                cost = generator.cost.active.polynomial[i]
                if length(cost) == 3
                    add_to_expression!(objExpression, cost[1], active[i], active[i])
                    add_to_expression!(objExpression, cost[2], active[i])
                    add_to_expression!(objExpression, cost[3])
                elseif length(cost) == 2
                    add_to_expression!(objExpression, cost[1], active[i])
                    add_to_expression!(objExpression, cost[2])
                end
            elseif generator.cost.active.model[i] == 1
                cost = generator.cost.active.piecewise[i]
                if size(cost, 1) == 2
                    slope = (cost[2, 2] - cost[1, 2]) / (cost[2, 1] - cost[1, 1])
                    add_to_expression!(objExpression, slope, active[i])
                    add_to_expression!(objExpression, cost[1, 2] - cost[1, 1] * slope)
                else
                    push!(idxPiecewise, i)
                end
            end

            if capability
                @constraint(model, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i], base_name = "capability[$i]")
            end
        else
            fix(active[i], 0.0)
        end
    end

    if !isempty(idxPiecewise)
        @variable(model, helper[i = 1:length(idxPiecewise)])
    end

    @inbounds for (k, i) in enumerate(idxPiecewise)
        add_to_expression!(objExpression, helper[k])

        activePower = @view generator.cost.active.piecewise[i][:, 1]
        activePowerCost = @view generator.cost.active.piecewise[i][:, 2]
        for j = 2:size(generator.cost.active.piecewise[i], 1)
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for active power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            @constraint(model, slope * active[i] - helper[k] <= slope * activePower[j-1] - activePowerCost[j-1], base_name = "piecewise[$i][$(j-1)]")
        end
    end

    @objective(model, Min, objExpression)

    if rating || difference
        @inbounds for i = 1:branch.number
            if branch.layout.status[i] == 1
                θij = angle[branch.layout.from[i]] - angle[branch.layout.to[i]]

                if rating && branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                    limit = branch.rating.longTerm[i] / system.dcModel.admittance[i]
                    @constraint(model, - limit + branch.parameter.shiftAngle[i] <= θij <= limit + branch.parameter.shiftAngle[i], base_name = "rating[$i]")
                end
                if difference && branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                    @constraint(model, branch.voltage.minDiffAngle[i] <= θij <= branch.voltage.maxDiffAngle[i], base_name = "difference[$i]")
                end
            end
        end
    end

    if balance
        @inbounds for i = 1:bus.number
            expression = AffExpr(bus.demand.active[i] + bus.shunt.conductance[i] + system.dcModel.shiftActivePower[i])
            for j in system.dcModel.nodalMatrix.colptr[i]:(system.dcModel.nodalMatrix.colptr[i + 1] - 1)
                row = system.dcModel.nodalMatrix.rowval[j]
                add_to_expression!(expression, system.dcModel.nodalMatrix.nzval[j], angle[row])
            end
            @constraint(model, expression - supplyActive[i] == 0.0, base_name = "balance[$i]")
        end
    end

    return DCOptimalPowerFlow(PolarAngle(system.bus.voltage.angle), CartesianReal(system.generator.output.active), model)
end

"""
    optimize!(system::PowerSystem, model::DCOptimalPowerFlow)

The function finds the DC optimal power flow solution and calculate the angles of bus
voltages and active power output of the generators.

The calculated voltage angles and active powers are then stored in the `angle` variable of
the `voltage` field and the `active` variable of the `power` field.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system, HiGHS.Optimizer)
optimize!(system, model)
```
"""
function optimize!(system::PowerSystem, model::DCOptimalPowerFlow)
    if isnothing(start_value(model.jump[:angle][1]))
        set_start_value.(model.jump[:angle], model.voltage.angle)
    end
    if isnothing(start_value(model.jump[:active][1]))
        set_start_value.(model.jump[:active], model.output.active)
    end

    JuMP.optimize!(model.jump)

    @inbounds for i = 1:system.bus.number
        model.voltage.angle[i] = value(model.jump[:angle][i])
    end

    @inbounds for i = 1:system.generator.number
        model.output.active[i] = value(model.jump[:active][i])
    end
end