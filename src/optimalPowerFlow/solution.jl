struct DCOptimalPowerFlow
    voltage::Polar
    power::Cartesian
    jump::JuMP.Model
end

"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer)

The function takes a `PowerSystem` composite type as input to establish the structure for
solving the DC optimal power flow. The `optimizer` argument is also required to create and solve
the optimization problem. If the `dcModel` field within the `PowerSystem` composite type has not
been created, the function will initiate an update automatically.

# JuMP
The JuliaGrid builds the DC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `DCOptimalPowerFlow` type, which includes the following
fields:
- voltage: the magnitudes and angles of bus voltages
- power: the active and reactive power output of the generators
- jump: the JuMP model.

# Note
In JuliaGrid, you can manipulate the `jump` model according to the
[JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However, some settings
may need to be called slightly differently.

For example, to disable adding bridges, use the macro @disable(addBridges), instead of
`add_bridges = false`. Also, to turn off string creations, instead of calling the
`set_string_names_on_creation(model, false)` function, you can use the macro
`@disable(stringNames)`.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcOptimalPowerFlow(system, HiGHS.Optimizer)
```
"""
function dcOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizer_factory))
    bus = system.bus
    branch = system.branch
    generator = system.generator
    polynomial = generator.cost.active.polynomial
    piecewise = generator.cost.active.piecewise
    settings = setting[:optimization]

    if isempty(system.dcModel.nodalMatrix)
        dcModel!(system)
    end

    model = Model(optimizer_factory; add_bridges = settings[:addBridges])
    set_string_names_on_creation(model, settings[:stringNames])

    @variable(model, angle[i = 1:bus.number])
    @variable(model, active[i = 1:generator.number])

    if settings[:slack]
        @constraint(model, angle[bus.layout.slack] == system.bus.voltage.angle[bus.layout.slack], base_name = "slack")
    end

    idxPiecewise = Array{Int64,1}(undef, 0); sizehint!(idxPiecewise, generator.number)
    objExpression = QuadExpr()
    supplyActive = zeros(AffExpr, system.bus.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = generator.layout.bus[i]
            supplyActive[busIndex] += active[i]

            if generator.cost.active.model[i] == 2 && settings[:polynomial]
                cost = polynomial[i]
                if length(cost) == 3
                    add_to_expression!(objExpression, cost[1], active[i], active[i])
                    add_to_expression!(objExpression, cost[2], active[i])
                    add_to_expression!(objExpression, cost[3])
                elseif length(cost) == 2
                    add_to_expression!(objExpression, cost[1], active[i])
                    add_to_expression!(objExpression, cost[2])
                end
            elseif generator.cost.active.model[i] == 1 && settings[:piecewise]
                cost = piecewise[i]
                if size(cost, 1) == 2
                    slope = (cost[2, 2] - cost[1, 2]) / (cost[2, 1] - cost[1, 1])
                    add_to_expression!(objExpression, slope, active[i])
                    add_to_expression!(objExpression, cost[1, 2] - cost[1, 1] * slope)
                else
                    push!(idxPiecewise, i)
                end
            end

            if settings[:capability]
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

        activePower = @view piecewise[i][:, 1]
        activePowerCost = @view piecewise[i][:, 2]
        for j = 2:size(piecewise[i], 1)
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for active power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            @constraint(model, slope * active[i] - helper[k] <= slope * activePower[j-1] - activePowerCost[j-1], base_name = "piecewise[$i][$(j-1)]")
        end
    end

    @objective(model, Min, objExpression)

    if settings[:flow] || settings[:difference]
        @inbounds for i = 1:branch.number
            if branch.layout.status[i] == 1
                θij = angle[branch.layout.from[i]] - angle[branch.layout.to[i]]

                if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16 && settings[:flow]
                    limit = branch.rating.longTerm[i] / system.dcModel.admittance[i]
                    @constraint(model, - limit + branch.parameter.shiftAngle[i] <= θij <= limit + branch.parameter.shiftAngle[i], base_name = "flow[$i]")
                end
                if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi && settings[:difference]
                    @constraint(model, branch.voltage.minDiffAngle[i] <= θij <= branch.voltage.maxDiffAngle[i], base_name = "difference[$i]")
                end
            end
        end
    end

    if settings[:balance]
        @inbounds for i = 1:bus.number
            expression = AffExpr(bus.demand.active[i] + bus.shunt.conductance[i] + system.dcModel.shiftActivePower[i])
            for j in system.dcModel.nodalMatrix.colptr[i]:(system.dcModel.nodalMatrix.colptr[i + 1] - 1)
                row = system.dcModel.nodalMatrix.rowval[j]
                add_to_expression!(expression, system.dcModel.nodalMatrix.nzval[j], angle[row])
            end
            @constraint(model, expression - supplyActive[i] == 0.0, base_name = "balance[$i]")
        end
    end

    return DCOptimalPowerFlow(Polar(Float64[], system.bus.voltage.angle), Cartesian(system.generator.output.active, Float64[]), model)
end

"""
    optimize!(system::PowerSystem, model::DCOptimalPowerFlow)

The function finds the DC optimal power flow solution and calculate the angles of bus voltages
and active power output of the generators.

The calculated voltage angles and active powers are then stored in the `angle` variable of the
`voltage` field and the `active` variable of the `power` field.

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
        set_start_value.(model.jump[:active], model.power.active)
    end

    JuMP.optimize!(model.jump)

    @inbounds for i = 1:system.bus.number
        model.voltage.angle[i] = value(model.jump[:angle][i])
    end

    @inbounds for i = 1:system.generator.number
        model.power.active[i] = value(model.jump[:active][i])
    end
end