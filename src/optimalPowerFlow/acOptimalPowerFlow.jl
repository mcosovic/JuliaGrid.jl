
######### Constraints ##########
ArrayRef = Array{JuMP.ConstraintRef,1}

struct CartesianFlowRef
    from::ArrayRef
    to::ArrayRef
end

struct Constraint
    slack::Union{PolarRef, PolarAngleRef}
    balance::Union{CartesianRef, CartesianRealRef}
    limit::Union{PolarRef, PolarAngleRef}
    rating::Union{CartesianFlowRef, CartesianRealRef}
    capability::Union{CartesianRef, CartesianRealRef}
    piecewise::Union{CartesianRef, CartesianRealRef}
end

######### AC Optimal Power Flow ##########
struct ACOptimalPowerFlow <: AC
    voltage::Polar
    power::Power
    current::Current
    jump::JuMP.Model
    constraint::Constraint
end

"""
    acOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name, balance, limit,
        rating, capability)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the AC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `ac` field within the `PowerSystem` composite type has
not been created, the function will initiate an update automatically.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/manual/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism,
- `name`: used to manage the creation of string names.

Moreover, we have included keywords that regulate the usage of different types of constraints:
- `balance`: controls the equality constraints that relate to the active and reactive power balance equations;
- `limit`: controls the inequality constraints that relate to the voltage magnitude and angle differences between buses;
- `rating`: controls the inequality constraints that relate to the long-term rating of branches;
- `capability`: controls the inequality constraints that relate to the active and reactive power generator outputs.

By default, all of these keywords are set to `true` and are of the `Bool` type.

# JuMP
The JuliaGrid builds the AC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `ACOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `jump`: the JuMP model;
- `constraint`: holds the constraint references to the JuMP model.

# Examples
Create the complete DC optimal power flow model:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
```

Create the DC optimal power flow model without `rating` constraints:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; rating = false)
```
"""
function acOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true,
    balance::Bool = true, limit::Bool = true,
    rating::Bool = true,  capability::Bool = true)

    if isempty(system.model.ac.nodalMatrix)
        acModel!(system)
    end

    branch = system.branch
    bus = system.bus
    generator = system.generator

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    model = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(model, name)

    @variable(model, active[i = 1:generator.number])
    @variable(model, reactive[i = 1:generator.number])
    @variable(model, magnitude[i = 1:bus.number])
    @variable(model, angle[i = 1:bus.number])

    slackAngleRef = @constraint(model, angle[bus.layout.slack] == bus.voltage.angle[bus.layout.slack])
    slackMagnitudeRef = @constraint(model, magnitude[bus.layout.slack] == bus.voltage.magnitude[bus.layout.slack])

    idxPiecewiseActive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseActive, generator.number)
    idxPiecewiseReactive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseReactive, generator.number)

    capabilityActiveRef = Array{JuMP.ConstraintRef}(undef, generator.number)
    capabilityReactiveRef = Array{JuMP.ConstraintRef}(undef, generator.number)

    objExpr = QuadExpr()
    nonlinearExpr = Vector{NonlinearExpression}(undef, 0)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            if costActive.model[i] == 2
                numberTerm = length(costActive.polynomial[i])
                if numberTerm == 3
                    add_to_expression!(objExpr, costActive.polynomial[i][1], active[i], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][2], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][3])
                elseif numberTerm == 2
                    add_to_expression!(objExpr, costActive.polynomial[i][1], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][2])
                elseif numberTerm == 1
                    add_to_expression!(objExpr, costActive.polynomial[i][1])
                elseif numberTerm > 3
                    add_to_expression!(objExpr, costActive.polynomial[i][end - 2], active[i], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][end - 1], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][end])
                    push!(nonlinearExpr, @NLexpression(model, sum(costActive.polynomial[i][numberTerm - degree] * active[i]^degree for degree = numberTerm-1:-1:3)))
                end
            elseif costActive.model[i] == 1
                numberPoint = size(costActive.piecewise[i], 1)
                if numberPoint == 2
                    slope = (costActive.piecewise[i][2, 2] - costActive.piecewise[i][1, 2]) / (costActive.piecewise[i][2, 1] - costActive.piecewise[i][1, 1])
                    add_to_expression!(objExpr, slope, active[i])
                    add_to_expression!(objExpr, costActive.piecewise[i][1, 2] - costActive.piecewise[i][1, 1] * slope)
                elseif numberPoint > 2
                    push!(idxPiecewiseActive, i)
                end
            end

            if costReactive.model[i] == 2
                numberTerm = length(costReactive.polynomial[i])
                if numberTerm == 3
                    add_to_expression!(objExpr, costReactive.polynomial[i][1], reactive[i], reactive[i])
                    add_to_expression!(objExpr, costReactive.polynomial[i][2], reactive[i])
                    add_to_expression!(objExpr, costReactive.polynomial[i][3])
                elseif numberTerm == 2
                    add_to_expression!(objExpr, costReactive.polynomial[i][1], reactive[i])
                    add_to_expression!(objExpr, costReactive.polynomial[i][2])
                elseif numberTerm == 1
                    add_to_expression!(objExpr, costReactive.polynomial[i][1])
                elseif numberTerm > 3
                    add_to_expression!(objExpr, costReactive.polynomial[i][end - 2], reactive[i], reactive[i])
                    add_to_expression!(objExpr, costReactive.polynomial[i][end - 1], reactive[i])
                    add_to_expression!(objExpr, costReactive.polynomial[i][end])
                    push!(nonlinearExpr, @NLexpression(model, sum(costReactive.polynomial[i][numberTerm - degree] * reactive[i]^degree for degree = numberTerm-1:-1:3)))
                end
            elseif costReactive.model[i] == 1
                numberPoint = size(costReactive.piecewise[i], 1)
                if numberPoint == 2
                    slope = (costReactive.piecewise[i][2, 2] - costReactive.piecewise[i][1, 2]) / (costReactive.piecewise[i][2, 1] - costReactive.piecewise[i][1, 1])
                    add_to_expression!(objExpr, slope, reactive[i])
                    add_to_expression!(objExpr, costReactive.piecewise[i][1, 2] - costReactive.piecewise[i][1, 1] * slope)
                elseif numberPoint > 2
                    push!(idxPiecewiseReactive, i)
                end
            end

            if capability
                capabilityCurve(system, model, i)

                capabilityActiveRef[i] = @constraint(model, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i])
                capabilityReactiveRef[i] = @constraint(model, generator.capability.minReactive[i] <= reactive[i] <= generator.capability.maxReactive[i])
            end
        else
            fix(active[i], 0.0)
            fix(reactive[i], 0.0)
        end
    end

    @variable(model, helperActive[i = 1:length(idxPiecewiseActive)])
    @variable(model, helperReactive[i = 1:length(idxPiecewiseReactive)])

    piecewiseActiveRef = [Array{JuMP.ConstraintRef}(undef, 0) for i = 1:system.generator.number]
    @inbounds for (k, i) in enumerate(idxPiecewiseActive)
        add_to_expression!(objExpr, 1.0, helperActive[k])

        activePower = @view costActive.piecewise[i][:, 1]
        activePowerCost = @view costActive.piecewise[i][:, 2]

        point = size(costActive.piecewise[i], 1)
        piecewiseActiveRef[i] = Array{JuMP.ConstraintRef}(undef, point - 1)

        for j = 2:point
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for active power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            piecewiseActiveRef[i][j-1] = @constraint(model, slope * active[i] - helperActive[k] <= slope * activePower[j-1] - activePowerCost[j-1])
        end
    end

    piecewiseReactiveRef = [Array{JuMP.ConstraintRef}(undef, 0) for i = 1:system.generator.number]
    @inbounds for (k, i) in enumerate(idxPiecewiseReactive)
        add_to_expression!(objExpr, 1.0, helperReactive[k])

        reactivePower = @view costReactive.piecewise[i][:, 1]
        reactivePowerCost = @view costReactive.piecewise[i][:, 2]

        point = size(costReactive.piecewise[i], 1)
        piecewiseReactiveRef[i] = Array{JuMP.ConstraintRef}(undef, point - 1)

        for j = 2:point
            slope = (reactivePowerCost[j] - reactivePowerCost[j-1]) / (reactivePower[j] - reactivePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for reactive power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            piecewiseReactiveRef[i][j-1] = @constraint(model, slope * reactive[i] - helperReactive[k] <= slope * reactivePower[j-1] - reactivePowerCost[j-1])
        end
    end

    numberNonlinear = length(nonlinearExpr)
    if numberNonlinear == 0
        @objective(model, Min, objExpr)
    elseif numberNonlinear == 1
        @NLobjective(model, Min, objExpr + nonlinearExpr[1])
    else
        @NLobjective(model, Min, objExpr + sum(nonlinearExpr[i] for i = 1:numberNonlinear))
    end

    limitAngleRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    ratingFromRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    ratingToRef = Array{JuMP.ConstraintRef}(undef, branch.number)
    if rating || limit
        @inbounds for i = 1:branch.number
            if branch.layout.status[i] == 1
                f = branch.layout.from[i]
                t = branch.layout.to[i]

                θij = angle[f] - angle[t]
                if limit && branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                    limitAngleRef[i] = @constraint(model, branch.voltage.minDiffAngle[i] <= θij <= branch.voltage.maxDiffAngle[i])
                end

                if rating && branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                    Vi = magnitude[f]
                    Vj = magnitude[t]

                    gij = real(system.model.ac.admittance[i])
                    bij = imag(system.model.ac.admittance[i])
                    gsi = 0.5 * branch.parameter.conductance[i]
                    bsi = 0.5 * branch.parameter.susceptance[i]
                    add_to_expression!(θij, -branch.parameter.shiftAngle[i])

                    g = gij + gsi
                    b = bij + bsi
                    βij = 1 / branch.parameter.turnsRatio[i]

                    if branch.rating.type[i] == 1 || branch.rating.type[i] == 3
                        Aij = βij^4 * (g^2 + b^2)
                        Bij = βij^2 * (gij^2 + bij^2)
                        Cij = βij^3 * (gij * g + bij * b)
                        Dij = βij^3 * (bij * g - gij * b)

                        Aji = g^2 + b^2
                        Cji = βij * (gij * g + bij * b)
                        Dji = βij * (gij * b - bij * g)
                    end

                    if branch.rating.type[i] == 1
                        ratingFromRef[i] = @NLconstraint(model, Aij * Vi^4 + Bij * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (Cij * cos(θij) + Dij * sin(θij)) <= branch.rating.longTerm[i]^2)
                        ratingToRef[i] = @NLconstraint(model, Aji * Vj^4 + Bij * Vi^2 * Vj^2 - 2 * Vi * Vj^3 * (Cji * cos(θij) + Dji * sin(θij)) <= branch.rating.longTerm[i]^2)
                    end
                    if branch.rating.type[i] == 2
                        ratingFromRef[i] = @NLconstraint(model, βij^2 * g * Vi^2 - βij * Vi * Vj * (gij * cos(θij) + bij * sin(θij)) <= branch.rating.longTerm[i])
                        ratingToRef[i] = @NLconstraint(model, g * Vj^2 - βij * Vi * Vj * (gij * cos(θij) - bij * sin(θij)) <= branch.rating.longTerm[i])
                    end
                    if branch.rating.type[i] == 3
                        ratingFromRef[i] = @NLconstraint(model, Aij * Vi^2 + Bij * Vj^2 - 2 * Vi * Vj * (Cij * cos(θij) + Dij * sin(θij)) <= branch.rating.longTerm[i]^2)
                        ratingToRef[i] = @NLconstraint(model, Aji * Vj^2 + Bij * Vi^2 - 2 * Vi * Vj * (Cji * cos(θij) + Dji * sin(θij)) <= branch.rating.longTerm[i]^2)
                    end
                end
            end
        end
    end

    balanceActiveRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    balanceReactiveRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    limitMagnitudeRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    @inbounds for i = 1:bus.number
        if balance
            n = system.model.ac.nodalMatrix.colptr[i + 1] - system.model.ac.nodalMatrix.colptr[i]
            Gij = Vector{AffExpr}(undef, n)
            Bij = Vector{AffExpr}(undef, n)
            θij = Vector{AffExpr}(undef, n)

            for (k, j) in enumerate(system.model.ac.nodalMatrix.colptr[i]:(system.model.ac.nodalMatrix.colptr[i + 1] - 1))
                row = system.model.ac.nodalMatrix.rowval[j]
                Gij[k] = magnitude[row] * real(system.model.ac.nodalMatrixTranspose.nzval[j])
                Bij[k] = magnitude[row] * imag(system.model.ac.nodalMatrixTranspose.nzval[j])
                θij[k] = angle[i] - angle[row]
            end

            balanceActiveRef[i] = @NLconstraint(model, bus.demand.active[i] - sum(active[k] for k in system.bus.supply.generator[i]) + magnitude[i] * sum(Gij[j] * cos(θij[j]) + Bij[j] * sin(θij[j]) for j = 1:n) == 0)
            balanceReactiveRef[i] = @NLconstraint(model, bus.demand.reactive[i] - sum(reactive[k] for k in system.bus.supply.generator[i]) + magnitude[i] * sum(Gij[j] * sin(θij[j]) - Bij[j] * cos(θij[j]) for j = 1:n) == 0)
        end

        if limit
            limitMagnitudeRef[i] = @constraint(model, bus.voltage.minMagnitude[i] <= magnitude[i] <= bus.voltage.maxMagnitude[i])
        end
    end

    return ACOptimalPowerFlow(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        Power(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Charging(
                Cartesian(Float64[], Float64[]),
                Cartesian(Float64[], Float64[])),
            Cartesian(Float64[], Float64[]),
            Cartesian(copy(system.generator.output.active), copy(system.generator.output.reactive))
        ),
        Current(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        model,
        Constraint(
            PolarRef(slackMagnitudeRef, slackAngleRef),
            CartesianRef(balanceActiveRef, balanceReactiveRef),
            PolarRef(limitMagnitudeRef, limitAngleRef),
            CartesianFlowRef(ratingFromRef, ratingToRef),
            CartesianRef(capabilityActiveRef, capabilityReactiveRef),
            CartesianRef(piecewiseActiveRef, piecewiseReactiveRef),
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)

The function finds the AC optimal power flow solution and calculate the bus voltage
magnitudes and angles, and output active and reactive powers of each generators.

The calculated voltage magnitudes and angles and active and reactive powers are then stored
in the variables of the `voltage` and `power` fields of the `ACOptimalPowerFlow` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    if isnothing(start_value(analysis.jump[:angle][1]))
        set_start_value.(analysis.jump[:angle], analysis.voltage.angle)
    end
    if isnothing(start_value(analysis.jump[:magnitude][1]))
        set_start_value.(analysis.jump[:magnitude], analysis.voltage.magnitude)
    end
    if isnothing(start_value(analysis.jump[:active][1]))
        set_start_value.(analysis.jump[:active], analysis.power.generator.active)
    end
    if isnothing(start_value(analysis.jump[:reactive][1]))
        set_start_value.(analysis.jump[:reactive], analysis.power.generator.reactive)
    end

    JuMP.optimize!(analysis.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(analysis.jump[:angle][i])
        analysis.voltage.magnitude[i] = value(analysis.jump[:magnitude][i])
    end

    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(analysis.jump[:active][i])
        analysis.power.generator.reactive[i] = value(analysis.jump[:reactive][i])
    end
end

function capabilityCurve(system::PowerSystem, model::JuMP.Model, i)
    capability = system.generator.capability

    if capability.lowActive[i] != 0.0 || capability.upActive[i] != 0.0
        if capability.lowActive[i] >= capability.upActive[i]
            throw(ErrorException("PQ capability curve is is not correctly defined."))
        end
        if capability.maxLowReactive[i] <= capability.minLowReactive[i] && capability.maxUpReactive[i] <= capability.minUpReactive[i]
            throw(ErrorException("PQ capability curve is is not correctly defined."))
        end

        if capability.lowActive[i] != capability.upActive[i]
            deltaActiveInv = 1 / (capability.upActive[i] - capability.lowActive[i])
            minLowActive = capability.minActive[i] - capability.lowActive[i]
            maxLowActive = capability.maxActive[i] - capability.lowActive[i]

            deltaReactive = capability.minUpReactive[i] - capability.minLowReactive[i]
            minReactiveMinActive = capability.minLowReactive[i] + minLowActive * deltaReactive * deltaActiveInv
            minReactiveMaxActive = capability.minLowReactive[i] + maxLowActive * deltaReactive * deltaActiveInv
            if  minReactiveMinActive > capability.minReactive[i] || minReactiveMaxActive > capability.minReactive[i]
                deltaQ = capability.maxLowReactive[i] - capability.maxUpReactive[i]
                deltaP = capability.upActive[i] - capability.lowActive[i]
                b = deltaQ * capability.lowActive[i] + deltaP * capability.maxLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                @constraint(model, scale * deltaQ * model[:active][i] + scale * deltaP * model[:reactive][i] <= scale * b)
            end

            deltaReactive = capability.maxUpReactive[i] - capability.maxLowReactive[i]
            maxReactiveMinActive = capability.maxLowReactive[i] + minLowActive * deltaReactive * deltaActiveInv
            maxReactiveMaxActive = capability.minLowReactive[i] + maxLowActive * deltaReactive * deltaActiveInv
            if maxReactiveMinActive < capability.maxReactive[i] || maxReactiveMaxActive < capability.maxReactive[i]
                deltaQ = capability.minUpReactive[i] - capability.minLowReactive[i]
                deltaP = capability.lowActive[i] - capability.upActive[i]
                b = deltaQ * capability.lowActive[i] + deltaP * capability.minLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                @constraint(model, scale * deltaQ * model[:active][i] + scale * deltaP * model[:reactive][i] <= scale * b)
            end
        end
    end
end