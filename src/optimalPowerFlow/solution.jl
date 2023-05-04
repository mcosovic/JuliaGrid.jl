function dcOptimalPowerFlow(system)
    return Result(
        BusResult(Polar(Float64[], Float64[]),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        DcPowerFlow("DC Optimal Power Flow")
        )
end


function optimizePowerFlow!(system::PowerSystem, model::JuMP.Model, result::Result)
    bus = system.bus
    branch = system.branch
    generator = system.generator
    polynomial = generator.cost.active.polynomial
    piecewise = generator.cost.active.piecewise

    @variable(model, angle[i = 1:bus.number], start = result.bus.voltage.angle[i])
    @variable(model, active[i = 1:generator.number], start = result.generator.power.active[i])

    if settings[:optimization][:slack]
        @constraint(model, angle[bus.layout.slack] == 0.0, base_name = "slack")
    end

    # idxPiecewise = Array{Int64,1}(undef, 0); sizehint!(idxPiecewise, generator.number)
    # objExpression = QuadExpr()
    # supplyActive = zeros(AffExpr, system.bus.number)
    # @time @inbounds for i = 1:generator.number
    #     if generator.layout.status[i] == 1
    #         busIndex = generator.layout.bus[i]
    #         supplyActive[busIndex] += active[i]

    #         if generator.cost.active.model[i] == 2 && optimization[:polynomial]
    #             cost = polynomial[i]
    #             if length(cost) == 3
    #                 add_to_expression!(objExpression, cost[1], active[i], active[i])
    #                 add_to_expression!(objExpression, cost[2], active[i])
    #                 add_to_expression!(objExpression, cost[3])
    #             elseif length(cost) == 2
    #                 add_to_expression!(objExpression, cost[1], active[i])
    #                 add_to_expression!(objExpression, cost[2])
    #             end
    #         elseif generator.cost.active.model[i] == 1 && optimization[:piecewise]
    #             cost = piecewise[i]
    #             if size(cost, 1) == 2
    #                 slope = (cost[2, 2] - cost[1, 2]) / (cost[2, 1] - cost[1, 1])
    #                 add_to_expression!(objExpression, slope, active[i])
    #                 add_to_expression!(objExpression, cost[1, 2] - cost[1, 1] * slope)
    #             else
    #                 push!(idxPiecewise, i)
    #             end
    #         end

    #         if optimization[:capability]
    #             @constraint(model, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i], base_name = "capability[$i]")
    #         end
    #     else
    #         fix(active[i], 0.0)
    #     end
    # end

    # if !isempty(idxPiecewise)
    #     @variable(model, helper[i = 1:length(idxPiecewise)])
    # end

    # @inbounds for (k, i) in enumerate(idxPiecewise)
    #     add_to_expression!(objExpression, helper[k])

    #     activePower = @view piecewise[i][:, 1]
    #     activePowerCost = @view piecewise[i][:, 2]
    #     for j = 2:size(piecewise[i], 1)
    #         slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
    #         if slope == Inf
    #             error("The piecewise linear cost function's slope for active power of the generator labeled as $(generator.label[i]) has infinite value.")
    #         end

    #         @constraint(model, slope * active[i] - helper[k] <= slope * activePower[j-1] - activePowerCost[j-1], base_name = "piecewise[$i][$(j-1)]")
    #     end
    # end

    # @objective(model, Min, objExpression)

    # @time if optimization[:flow] || optimization[:difference]
    #     @inbounds for i = 1:branch.number
    #         if branch.layout.status[i] == 1
    #             θij = angle[branch.layout.from[i]] - angle[branch.layout.to[i]]

    #             if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16 && optimization[:flow]
    #                 limit = branch.rating.longTerm[i] / system.dcModel.admittance[i]
    #                 @constraint(model, - limit + branch.parameter.shiftAngle[i] <= θij <= limit + branch.parameter.shiftAngle[i], base_name = "flow[$i]")
    #             end
    #             if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi && optimization[:difference]
    #                 @constraint(model, branch.voltage.minDiffAngle[i] <= θij <= branch.voltage.maxDiffAngle[i], base_name = "difference[$i]")
    #             end
    #         end
    #     end
    # end

    # @time if optimization[:balance]
    #     @inbounds for i = 1:bus.number
    #         expression = AffExpr(bus.demand.active[i] + bus.shunt.conductance[i] + system.dcModel.shiftActivePower[i])
    #         for j in system.dcModel.nodalMatrix.colptr[i]:(system.dcModel.nodalMatrix.colptr[i + 1] - 1)
    #             row = system.dcModel.nodalMatrix.rowval[j]
    #             add_to_expression!(expression, system.dcModel.nodalMatrix.nzval[j], angle[row])
    #         end
    #         @constraint(model, expression - supplyActive[i] == 0.0, base_name = "balance[$i]")
    #     end
    # end

    # # @time if optimization[:balance]
    # #     generatorIncidence = sparse(generator.layout.bus, collect(1:generator.number), 1, bus.number, generator.number)
    # #     @constraint(model, system.dcModel.nodalMatrix * angle - generatorIncidence * active .== - bus.demand.active - bus.shunt.conductance - system.dcModel.shiftActivePower, base_name = "balance")
    # # end
end

function acOptimalPowerFlow!(system::PowerSystem, model::JuMP.Model; startAngle = system.bus.voltage.angle, startMagnitude = system.bus.voltage.magnitude,
    startActive = system.generator.output.active, startReactive = system.generator.output.reactive)

    branch = system.branch
    bus = system.bus
    generator = system.generator

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    @variable(model, angle[i = 1:bus.number], start = startAngle[i])
    @variable(model, magnitude[i = 1:bus.number], start = startMagnitude[i])
    @variable(model, active[i = 1:generator.number], start = startActive[i])
    @variable(model, reactive[i = 1:generator.number], start = startReactive[i])

    if optimization[:slack]
        @constraint(model, angle[bus.layout.slack] == bus.voltage.angle[bus.layout.slack], base_name = "slack")
    end

    idxPiecewiseActive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseActive, generator.number)
    idxPiecewiseReactive = Array{Int64,1}(undef, 0); sizehint!(idxPiecewiseReactive, generator.number)

    objExpression = QuadExpr()
    nonExpression = Vector{NonlinearExpression}(undef, 0)
    supplyActive = zeros(AffExpr, system.bus.number)
    supplyReactive = zeros(AffExpr, system.bus.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            busIndex = generator.layout.bus[i]
            supplyActive[busIndex] += active[i]
            supplyReactive[busIndex] += reactive[i]

            if costActive.model[i] == 2 && optimization[:polynomial]
                if length(costActive.polynomial[i]) == 3
                    add_to_expression!(objExpression, costActive.polynomial[i][1], active[i], active[i])
                    add_to_expression!(objExpression, costActive.polynomial[i][2], active[i])
                    add_to_expression!(objExpression, costActive.polynomial[i][3])
                elseif length(costActive.polynomial[i]) == 2
                    add_to_expression!(objExpression, costActive.polynomial[i][1], active[i])
                    add_to_expression!(objExpression, costActive.polynomial[i][2])
                elseif length(costActive.polynomial[i]) > 3
                    n = length(costActive.polynomial[i])
                    push!(nonExpression, @NLexpression(model, sum(costActive.polynomial[i][j] * active[i]^(n - j) for j = 1:n)))
                end
            elseif costActive.model[i] == 1 && optimization[:piecewise]
                if size(costActive.piecewise[i], 1) == 2
                    slope = (costActive.piecewise[i][2, 2] - costActive.piecewise[i][1, 2]) / (costActive.piecewise[i][2, 1] - costActive.piecewise[i][1, 1])
                    add_to_expression!(objExpression, slope, active[i])
                    add_to_expression!(objExpression, costActive.piecewise[i][1, 2] - costActive.piecewise[i][1, 1] * slope)
                else
                    push!(idxPiecewiseActive, i)
                end
            end

            if costReactive.model[i] == 2 && optimization[:polynomial]
                if length(costReactive.polynomial[i]) == 3
                    add_to_expression!(objExpression, costReactive.polynomial[i][1], reactive[i], reactive[i])
                    add_to_expression!(objExpression, costReactive.polynomial[i][2], reactive[i])
                    add_to_expression!(objExpression, costReactive.polynomial[i][3])
                elseif length(costReactive.polynomial[i]) == 2
                    add_to_expression!(objExpression, costReactive.polynomial[i][1], reactive[i])
                    add_to_expression!(objExpression, costReactive.polynomial[i][2])
                elseif length(costReactive.polynomial[i]) > 3
                    n = length(costReactive.polynomial[i])
                    push!(nonExpression, @NLexpression(model, sum(costReactive.polynomial[i][j] * active[i]^(n - j) for j = 1:n)))
                end
            elseif costReactive.model[i] == 1 && optimization[:piecewise]
                if size(costReactive.piecewise[i], 1) == 2
                    slope = (costReactive.piecewise[i][2, 2] - costReactive.piecewise[i][1, 2]) / (costReactive.piecewise[i][2, 1] - costReactive.piecewise[i][1, 1])
                    add_to_expression!(objExpression, slope, reactive[i])
                    add_to_expression!(objExpression, costReactive.piecewise[i][1, 2] - costReactive.piecewise[i][1, 1] * slope)
                else
                    push!(idxPiecewiseReactive, i)
                end
            end

            if optimization[:capability]
                @constraint(model, generator.capability.minActive[i] <= active[i] <= generator.capability.maxActive[i], base_name = "capability")
                @constraint(model, generator.capability.minReactive[i] <= reactive[i] <= generator.capability.maxReactive[i], base_name = "capability")
            end
        else
            @constraint(model, active[i] == 0.0, base_name = "outservice")
            @constraint(model, reactive[i] == 0.0, base_name = "outservice")
        end
    end

    @variable(model, helperActive[i = 1:length(idxPiecewiseActive)])
    @variable(model, helperReactive[i = 1:length(idxPiecewiseReactive)])

    @inbounds for (k, i) in enumerate(idxPiecewiseActive)
        add_to_expression!(objExpression, 1.0, helperActive[k])

        activePower = @view costActive.piecewise[i][:, 1]
        activePowerCost = @view costActive.piecewise[i][:, 2]
        for j = 2:size(costActive.piecewise[i], 1)
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for active power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            @constraint(model, slope * active[i] - helperActive[k] <= slope * activePower[j-1] - activePowerCost[j-1], base_name = "piecewise")
        end
    end

    @inbounds for (k, i) in enumerate(idxPiecewiseReactive)
        add_to_expression!(objExpression, 1.0, helperReactive[k])

        reactivePower = @view costReactive.piecewise[i][:, 1]
        reactivePowerCost = @view costReactive.piecewise[i][:, 2]
        for j = 2:size(costReactive.piecewise[i], 1)
            slope = (reactivePowerCost[j] - reactivePowerCost[j-1]) / (reactivePower[j] - reactivePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for reactive power of the generator labeled as $(generator.label[i]) has infinite value.")
            end

            @constraint(model, slope * reactive[i] - helperReactive[k] <= slope * reactivePower[j-1] - reactivePowerCost[j-1], base_name = "piecewise")
        end
    end

    numberNonLinear = length(nonExpression)
    if numberNonLinear == 0
        @objective(model, Min, objExpression)
    elseif numberNonLinear == 1
        @NLobjective(model, Min, objExpression + nonExpression[1])
    else
        @NLobjective(model, Min, objExpression + sum(nonExpression[i] for i = 1:numberNonLinear))
    end

    if optimization[:flow] || optimization[:difference]
        @inbounds for i = 1:branch.number
            if branch.layout.status[i] == 1
                f = branch.layout.from[i]
                t = branch.layout.to[i]

                θij = angle[f] - angle[t]
                if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi && optimization[:difference]
                    @constraint(model, branch.voltage.minDiffAngle[i] <= θij <= branch.voltage.maxDiffAngle[i], base_name = "difference")
                end

                if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16 && optimization[:flow]
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

                        @NLconstraint(model, sqrt(A * Vi^4 + B * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (C * cos(θij) - D * sin(θij))) <= branch.rating.longTerm[i])

                        A = gij^2 + (bij + bsi)^2
                        C = βij * (gij^2 + bij * (bij + bsi))
                        D = βij * gij * bsi
                        @NLconstraint(model, sqrt(A * Vj^4 + B * Vi^2 * Vj^2 - 2 * Vi * Vj^3 * (C * cos(θij) + D * sin(θij))) <= branch.rating.longTerm[i])
                    end

                    if branch.rating.type[i] == 2
                        @NLconstraint(model, βij^2 * gij * Vi^2 - βij * Vi * Vj * (gij * cos(θij) + bij * sin(θij))  <= branch.rating.longTerm[i])
                        @NLconstraint(model, gij * Vj^2 - βij * Vi * Vj * (gij * cos(θij) - bij * sin(θij)) <= branch.rating.longTerm[i])
                    end

                    if branch.rating.type[i] == 3
                        A = βij^4 * (gij^2 + (bij + bsi)^2)
                        B = βij^2 * (gij^2 + bij^2)
                        C = βij^3 * (gij^2 + bij * (bij + bsi))
                        D = βij^3 * gij * bij
                        @NLconstraint(model, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cos(θij) - D * sin(θij))) <= branch.rating.longTerm[i])

                        A = gij^2 + (bij + bsi)^2
                        C = βij * (gij^2 + bij * (bij + bsi))
                        D = βij * gij * bij
                        @NLconstraint(model, sqrt(A * Vj^2 + B * Vi^2 - 2 * Vi * Vj * (C * cos(θij) + D * sin(θij))) <= branch.rating.longTerm[i])
                    end
                end
            end
        end
    end

    @inbounds for i = 1:bus.number
        if optimization[:balance]
            n = system.acModel.nodalMatrix.colptr[i + 1] - system.acModel.nodalMatrix.colptr[i]
            Gij = zeros(AffExpr, n)
            Bij = zeros(AffExpr, n)
            θij = zeros(AffExpr, n)

            for (k, j) in enumerate(system.acModel.nodalMatrix.colptr[i]:(system.acModel.nodalMatrix.colptr[i + 1] - 1))
                row = system.acModel.nodalMatrix.rowval[j]

                Gij[k] = magnitude[row] * real(system.acModel.nodalMatrixTranspose.nzval[j])
                Bij[k] = magnitude[row] * imag(system.acModel.nodalMatrixTranspose.nzval[j])
                θij[k] = (angle[i] - angle[row])
            end

            @NLconstraint(model, bus.demand.active[i] - supplyActive[i] + magnitude[i] * sum(Gij[j] * cos(θij[j]) + Bij[j] * sin(θij[j]) for j = 1:n) == 0)
            @NLconstraint(model, bus.demand.reactive[i] - supplyReactive[i] + magnitude[i] * sum(Gij[j] * sin(θij[j]) - Bij[j] * cos(θij[j]) for j = 1:n) == 0)
        end

        if optimization[:voltage]
            @constraint(model, bus.voltage.minMagnitude[i] <= magnitude[i] <= bus.voltage.maxMagnitude[i], base_name = "voltage")
        end
    end

    # optimize!(model)
    # angle = JuMP.value.(model[:angle])
    # display(angle * 180 / pi)

    # magnitude = JuMP.value.(model[:magnitude])
    # display(magnitude)
end

# function optimizePowerFlow!(system::PowerSystem, model::JuMP.Model)
#     display(model[:magnitude])


# end


# function acOptimizePowerFlow!(system::PowerSystem, model::JuMP.Model)
#     bus = system.bus

#     optimize!(model)

#     method = "AC Optimal Power Flow"

#     return Result(
#         BusResult(Polar(JuMP.value.(model[:magnitude]), JuMP.value.(model[:angle])),
#             BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
#             BusCurrent(Polar(Float64[], Float64[]))),
#         BranchResult(
#             BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
#             BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
#         GeneratorResult(Cartesian(Float64[], Float64[])),
#         ACAlgorithm(method)
#         )
# end

# function dcOptimizePowerFlow!(system::PowerSystem, model::JuMP.Model)
#     bus = system.bus

#     optimize!(model)
#     angle = JuMP.value.(model[:angle])

#     if bus.voltage.angle[bus.layout.slack] != 0.0
#         @inbounds for i = 1:bus.number
#             angle[i] += bus.voltage.angle[bus.layout.slack]
#         end
#     end

#     method = "DC Optimal Power Flow"

#     return Result(
#         BusResult(Polar(Float64[], angle),
#             BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
#             BusCurrent(Polar(Float64[], Float64[]))),
#         BranchResult(
#             BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
#             BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
#         GeneratorResult(Cartesian(Float64[], Float64[])),
#         DCAlgorithm(method)
#         )
# end


