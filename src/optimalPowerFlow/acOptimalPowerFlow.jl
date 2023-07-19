export ACOptimalPowerFlow

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
struct ACOptimalPowerFlow <: ACAnalysis
    voltage::Polar
    power::Cartesian
    jump::JuMP.Model
    constraint::Constraint
end

"""
    acOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name, balance, limit,
        rating, capability)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the AC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `acModel` field within the `PowerSystem` composite
type has not been created, the function will initiate an update automatically.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism
- `name`: used to manage the creation of string names.

Moreover, we have included keywords that regulate the usage of different types of constraints:
- `balance`: controls the equality constraints that relate to the active and reactive power balance equations
- `limit`: controls the inequality constraints that relate to the voltage magnitude and angle differences between buses
- `rating`: controls the inequality constraints that relate to the long-term rating of branches
- `capability`: controls the inequality constraints that relate to the active and reactive power generator outputs.

By default, all of these keywords are set to `true` and are of the `Bool` type.

# JuMP
The JuliaGrid builds the AC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `ACOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the bus voltage magnitudes and angles
- `output`: the output active and reactive powers of each generator
- `jump`: the JuMP model
- `constraint`: holds the constraint references to the JuMP model.

# Examples
Create the complete DC optimal power flow model:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = acOptimalPowerFlow(system, HiGHS.Optimizer)
```

Create the DC optimal power flow model without `rating` constraints:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = acOptimalPowerFlow(system, HiGHS.Optimizer; rating = false)
```
"""
function acOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true,
    balance::Bool = true, limit::Bool = true,
    rating::Bool = true,  capability::Bool = true)

    if isempty(system.acModel.nodalMatrix)
        acModel!(system)
    end

    branch = system.branch
    bus = system.bus
    generator = system.generator

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    model = Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(model, name)

    @variable(model, angle[i = 1:bus.number])
    @variable(model, magnitude[i = 1:bus.number])
    @variable(model, active[i = 1:generator.number])
    @variable(model, reactive[i = 1:generator.number])

    slackAngleRef = @constraint(model, angle[bus.layout.slack] == bus.voltage.angle[bus.layout.slack])
    slackMagnitudeRef = @constraint(model, magnitude[bus.layout.slack] == bus.voltage.magnitude[bus.layout.slack])

    idxPiecewiseActive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseActive, generator.number)
    idxPiecewiseReactive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseReactive, generator.number)

    capabilityActiveRef = Array{JuMP.ConstraintRef}(undef, generator.number)
    capabilityReactiveRef = Array{JuMP.ConstraintRef}(undef, generator.number)

    objExpr = QuadExpr()
    nonlinearExpr = Vector{NonlinearExpression}(undef, 0)
    supplyActive = zeros(AffExpr, system.bus.number)
    supplyReactive = zeros(AffExpr, system.bus.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = generator.layout.bus[i]
            supplyActive[busIndex] += active[i]
            supplyReactive[busIndex] += reactive[i]

            if costActive.model[i] == 2
                numberTerm = length(costActive.polynomial[i])
                if numberTerm == 3
                    add_to_expression!(objExpr, costActive.polynomial[i][1], active[i], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][2], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][3])
                elseif numberTerm == 2
                    add_to_expression!(objExpr, costActive.polynomial[i][1], active[i])
                    add_to_expression!(objExpr, costActive.polynomial[i][2])
                elseif numberTerm > 3
                    push!(nonlinearExpr, @NLexpression(model, sum(costActive.polynomial[i][j] * active[i]^(numberTerm - j) for j = 1:numberTerm)))
                end
            elseif costActive.model[i] == 1
                if size(costActive.piecewise[i], 1) == 2
                    slope = (costActive.piecewise[i][2, 2] - costActive.piecewise[i][1, 2]) / (costActive.piecewise[i][2, 1] - costActive.piecewise[i][1, 1])
                    add_to_expression!(objExpr, slope, active[i])
                    add_to_expression!(objExpr, costActive.piecewise[i][1, 2] - costActive.piecewise[i][1, 1] * slope)
                else
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
                elseif numberTerm > 3
                    push!(nonlinearExpr, @NLexpression(model, sum(costReactive.polynomial[i][j] * active[i]^(numberTerm - j) for j = 1:numberTerm)))
                end
            elseif costReactive.model[i] == 1
                if size(costReactive.piecewise[i], 1) == 2
                    slope = (costReactive.piecewise[i][2, 2] - costReactive.piecewise[i][1, 2]) / (costReactive.piecewise[i][2, 1] - costReactive.piecewise[i][1, 1])
                    add_to_expression!(objExpr, slope, reactive[i])
                    add_to_expression!(objExpr, costReactive.piecewise[i][1, 2] - costReactive.piecewise[i][1, 1] * slope)
                else
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

                    gij = real(system.acModel.admittance[i])
                    bij = imag(system.acModel.admittance[i])
                    bsi = 0.5 * branch.parameter.susceptance[i]
                    add_to_expression!(θij, -branch.parameter.shiftAngle[i])

                    if branch.parameter.turnsRatio[i] == 0
                        βij = 1.0
                    else
                        βij = 1 / branch.parameter.turnsRatio[i]
                    end

                    if branch.rating.type[i] == 1
                        A = βij^4 * (gij^2 + (bij + bsi)^2)
                        B = βij^2 * (gij^2 + bij^2)
                        C = βij^3 * (gij^2 + bij * (bij + bsi))
                        D = βij^3 * gij * bsi

                        ratingFromRef[i] = @NLconstraint(model, sqrt(A * Vi^4 + B * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (C * cos(θij) - D * sin(θij))) <= branch.rating.longTerm[i])

                        A = gij^2 + (bij + bsi)^2
                        C = βij * (gij^2 + bij * (bij + bsi))
                        D = βij * gij * bsi
                        ratingToRef[i] = @NLconstraint(model, sqrt(A * Vj^4 + B * Vi^2 * Vj^2 - 2 * Vi * Vj^3 * (C * cos(θij) + D * sin(θij))) <= branch.rating.longTerm[i])
                    end

                    if branch.rating.type[i] == 2
                        ratingFromRef[i] = @NLconstraint(model, βij^2 * gij * Vi^2 - βij * Vi * Vj * (gij * cos(θij) + bij * sin(θij))  <= branch.rating.longTerm[i])
                        ratingToRef[i] = @NLconstraint(model, gij * Vj^2 - βij * Vi * Vj * (gij * cos(θij) - bij * sin(θij)) <= branch.rating.longTerm[i])
                    end

                    if branch.rating.type[i] == 3
                        A = βij^4 * (gij^2 + (bij + bsi)^2)
                        B = βij^2 * (gij^2 + bij^2)
                        C = βij^3 * (gij^2 + bij * (bij + bsi))
                        D = βij^3 * gij * bij
                        ratingFromRef[i] = @NLconstraint(model, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cos(θij) - D * sin(θij))) <= branch.rating.longTerm[i])

                        A = gij^2 + (bij + bsi)^2
                        C = βij * (gij^2 + bij * (bij + bsi))
                        D = βij * gij * bij
                        ratingToRef[i] = @NLconstraint(model, sqrt(A * Vj^2 + B * Vi^2 - 2 * Vi * Vj * (C * cos(θij) + D * sin(θij))) <= branch.rating.longTerm[i])
                    end
                end
            end
        end
    end

    balanceActiveRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    balanceReactiveRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    limitMagnitudeRef = Array{JuMP.ConstraintRef}(undef, bus.number)
    @time @inbounds for i = 1:bus.number
        if balance
            n = system.acModel.nodalMatrix.colptr[i + 1] - system.acModel.nodalMatrix.colptr[i]
            Gij = Vector{AffExpr}(undef, n)
            Bij = Vector{AffExpr}(undef, n)
            θij = Vector{AffExpr}(undef, n)

            for (k, j) in enumerate(system.acModel.nodalMatrix.colptr[i]:(system.acModel.nodalMatrix.colptr[i + 1] - 1))
                row = system.acModel.nodalMatrix.rowval[j]
                Gij[k] = magnitude[row] * real(system.acModel.nodalMatrixTranspose.nzval[j])
                Bij[k] = magnitude[row] * imag(system.acModel.nodalMatrixTranspose.nzval[j])
                θij[k] = angle[i] - angle[row]
            end

            balanceActiveRef[i] = @NLconstraint(model, bus.demand.active[i] - supplyActive[i] + magnitude[i] * sum(Gij[j] * cos(θij[j]) + Bij[j] * sin(θij[j]) for j = 1:n) == 0)
            balanceReactiveRef[i] = @NLconstraint(model, bus.demand.reactive[i] - supplyReactive[i] + magnitude[i] * sum(Gij[j] * sin(θij[j]) - Bij[j] * cos(θij[j]) for j = 1:n) == 0)
        end

        if limit
            limitMagnitudeRef[i] = @constraint(model, bus.voltage.minMagnitude[i] <= magnitude[i] <= bus.voltage.maxMagnitude[i])
        end
    end

    return ACOptimalPowerFlow(
        Polar(copy(system.bus.voltage.magnitude), copy(system.bus.voltage.angle)),
        Cartesian(copy(system.generator.output.active), copy(system.generator.output.reactive)),
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
    solve!(system::PowerSystem, model::ACOptimalPowerFlow)

The function finds the AC optimal power flow solution and calculate the bus voltage
magnitudes and angles, and output active and reactive powers of each generators.

The calculated voltage magnitudes and angles and active and reactive powers are then stored
in the variables of the `voltage` and `power` fields of the `Model` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = acOptimalPowerFlow(system, HiGHS.Optimizer)
solve!(system, model)
```
"""
function solve!(system::PowerSystem, model::ACOptimalPowerFlow)
    if isnothing(start_value(model.jump[:angle][1]))
        set_start_value.(model.jump[:angle], model.voltage.angle)
    end
    if isnothing(start_value(model.jump[:magnitude][1]))
        set_start_value.(model.jump[:magnitude], model.voltage.magnitude)
    end
    if isnothing(start_value(model.jump[:active][1]))
        set_start_value.(model.jump[:active], model.power.active)
    end
    if isnothing(start_value(model.jump[:reactive][1]))
        set_start_value.(model.jump[:reactive], model.power.reactive)
    end

    JuMP.optimize!(model.jump)

    @inbounds for i = 1:system.bus.number
        model.voltage.angle[i] = value(model.jump[:angle][i])
        model.voltage.magnitude[i] = value(model.jump[:magnitude][i])
    end

    @inbounds for i = 1:system.generator.number
        model.power.active[i] = value(model.jump[:active][i])
        model.power.reactive[i] = value(model.jump[:reactive][i])
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
                Q = capability.maxLowReactive[i] - capability.maxUpReactive[i]
                P = capability.upActive[i] - capability.lowActive[i]
                b = Q * capability.lowActive[i] + P * capability.maxLowReactive[i]
                scale = 1 / sqrt(Q^2 + P^2)

                @constraint(model, scale * Q * model[:active][i] + scale * P * model[:reactive][i] <= scale * b)
            end

            deltaReactive = capability.maxUpReactive[i] - capability.maxLowReactive[i]
            maxReactiveMinActive = capability.maxLowReactive[i] + minLowActive * deltaReactive * deltaActiveInv
            maxReactiveMaxActive = capability.minLowReactive[i] + maxLowActive * deltaReactive * deltaActiveInv
            if maxReactiveMinActive < capability.maxReactive[i] || maxReactiveMaxActive < capability.maxReactive[i]
                Q = capability.minUpReactive[i] - capability.minLowReactive[i]
                P = capability.lowActive[i] - capability.upActive[i]
                b = Q * capability.lowActive[i] + P * capability.minLowReactive[i]
                scale = 1 / sqrt(Q^2 + P^2)

                @constraint(model, scale * Q * model[:active][i] + scale * P * model[:reactive][i] <= scale * b)
            end
        end
    end
end