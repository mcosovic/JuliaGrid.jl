### DC optimal power flow, created by Ognjen Kundacina
function dcOptimalPowerFlow!(system::PowerSystem, model::JuMP.Model)
    dc = system.dcModel
    branch = system.branch
    bus = system.bus
    generator = system.generator
    slack = bus.layout.slackIndex

    @variable(model, angle[i = 1:bus.number], start = bus.voltage.angle[i])
    @variable(model, generator.capability.minActive[i] <= output[i = 1:generator.number] <= generator.capability.maxActive[i])

    @constraint(model, angle[slack] == 0.0)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 0
            @constraint(model, output[i] == 0.0)
        else
            set_start_value(output[i], (generator.capability.minActive[i] + generator.capability.maxActive[i]) / 2)
        end
    end

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            angleFrom = angle[branch.layout.from[i]]
            angleTo = angle[branch.layout.to[i]]

            if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                fromLimit = branch.rating.longTerm[i] + dc.admittance[i] * branch.parameter.shiftAngle[i]
                toLimit = branch.rating.longTerm[i] - dc.admittance[i] * branch.parameter.shiftAngle[i]
                @constraint(model, -toLimit <= dc.admittance[i] * (angleFrom - angleTo) <= fromLimit)
            end
            if branch.voltage.minAngleDifference[i] > -2*pi && branch.voltage.maxAngleDifference[i] < 2*pi
                @constraint(model, branch.voltage.minAngleDifference[i] <= angleFrom - angleTo <= branch.voltage.maxAngleDifference[i])
            end
        end
    end

    generatorIncidence = sparse(generator.layout.bus, collect(1:generator.number), 1, bus.number, generator.number)
    @constraint(model, dc.nodalMatrix * angle - generatorIncidence * output .== - bus.demand.active - bus.shunt.conductance - dc.shiftActivePower)

    dcObjective!(system::PowerSystem, model::JuMP.Model)


end

function dcOptimalPowerFlow(model::JuMP.Model)
    bus = system.bus
    slack = bus.layout.slackIndex

    optimize!(model)
    angle = JuMP.value.(model[:angle])

    if bus.voltage.angle[slack] != 0.0
        @inbounds for i = 1:bus.number
            angle[i] += bus.voltage.angle[slack]
        end
    end

    method = "DC Optimal Power Flow"

    return Result(
        BusResult(Polar(Float64[], angle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        DCAlgorithm(method)
        )
end

function dcObjective!(system::PowerSystem, model::JuMP.Model)
    generator = system.generator

    linearTerm = fill(0.0, generator.number)
    quadraticTerm = fill(0.0, generator.number)
    constantTerm = fill(0.0, generator.number)
    numberPiecewise = 0
    indexPiecewise = Int64[]

    for i = 1:generator.number
        if generator.cost.activeModel[i] == 1
            if generator.cost.activeDataPoint[i] == 2
                x0 = generator.cost.activeCoefficient[1, i]
                y0 = generator.cost.activeCoefficient[2, i]
                x1 = generator.cost.activeCoefficient[3, i]
                y1 = generator.cost.activeCoefficient[4, i]

                linearTerm[i] = (y1 - y0) / (x1 - x0)
                constantTerm[i] = y0 - linearTerm[i] * x0
            else
                numberPiecewise += 1
                push!(indexPiecewise, i)
            end
        elseif generator.cost.activeModel[i] == 2
            if generator.cost.activeDataPoint[i] == 2
                linearTerm[i] = generator.cost.activeCoefficient[1, i] * ((system.basePower / 1e6))
                constantTerm[i] = generator.cost.activeCoefficient[2, i]
            elseif generator.cost.activeDataPoint[i] == 3
                quadraticTerm[i] = generator.cost.activeCoefficient[1, i] * ((system.basePower / 1e6)^2)
                linearTerm[i] = generator.cost.activeCoefficient[2, i] * ((system.basePower / 1e6))
                constantTerm[i] = generator.cost.activeCoefficient[3, i]
            end
        end
    end

    output = model[:output]
    if numberPiecewise == 0
        @objective(model, Min, sum(quadraticTerm[i] * output[i]^2 + linearTerm[i] * output[i] + constantTerm[i] for i = 1:generator.number))
    end

    if numberPiecewise != 0
        @variable(model, cost[i = 1:numberPiecewise])

        @inbounds for i in indexPiecewise
            ns = generator.cost.activeDataPoint[i]
            p = @view(system.generatorcost[i, 5:2:(5 + 2 * ns - 1)])
            #         c = @view(system.generatorcost[i, 6:2:(5 + 2 * ns)])
            #         m = diff(c) ./ diff(p)
        end
    end

end



# function rundcopf(system, num, settings, info)


#     Qpg, cpg, kpg, nPWL, pwlIds = process_cost_table(system, num, costModel, coeffs, numOfCoeffs)
#     if nPWL == 0
#         @objective(model, Min, sum(0.5 * Qpg[i] * pGen[i]^2 + cpg[i] * pGen[i] + kpg[i] for i = 1:num.Ngen))
#     elseif nPWL > 0
#         @variable(model, pwlVars[i = 1:nPWL])
#         pgbas = 1
#         qgbas = zeros(Int64, 0)
#         nq = 0
#         ybas = 1 + num.Ngen + nq
#         Apwl, bpwl = makeApwl(system, num, nPWL, pwlIds, pgbas, qgbas, ybas, numOfCoeffs)
#         for i = 1:(length(bpwl))
#             @constraint(model, dot(Apwl[i,:], [pGen; pwlVars]) <= bpwl[i])
#         end
#         @objective(model, Min, sum(0.5 * Qpg[i] * pGen[i]^2 + cpg[i] * pGen[i] + kpg[i] for i = 1:num.Ngen) + sum(pwlVars[i] for i = 1:nPWL))
#     end

#     optimize!(model)
#     Ti = value.(thetas) .+ (pi / 180) * Tini[slack]


# end




# ### Construct parameters for linear basin constraints
# function makeApwl(system, num, nPWL, pwlIds, pgbas, qgbas, ybas, numOfCoeffs)
#     if nPWL == 0
#         Apwl = sparse([], [], [], 0, ybas + nPWL - 1, 0)
#         bpwl = zeros(Int64, 0)

#         return Apwl, bpwl
#     end

#     numCostPoints = sum(numOfCoeffs[i] for i in pwlIds)
#     Apwl = zeros(Float64, numCostPoints - nPWL, ybas + nPWL - 1)
#     bpwl = zeros(Int64, 0)

#     k = 1
#     @inbounds for i in pwlIds
#         ns = numOfCoeffs[i]
#         p = @view(system.generatorcost[i, 5:2:(5 + 2 * ns - 1)]) / system.basePower
#         c = @view(system.generatorcost[i, 6:2:(5 + 2 * ns)])
#         m = diff(c) ./ diff(p)
#         if any(diff(p) == 0)
#             println("makeApwl: Bad x axis data in the generator cost matrix, row: ", i)
#         end
#         b = m .* p[1:(ns - 1)] - c[1:(ns - 1)]
#         bpwl = [bpwl; b]
#         ########## Q and P costs ##########
#         if i > num.Ngen
#             sidx = qgbas + (i-ng) - 1
#         else
#             sidx = pgbas + i - 1
#         end
#         @inbounds for j = 1:(ns - 1)
#             Apwl[j + k - 1, sidx] = m[j]
#         end
#         k = k + ns - 1
#     end

#     k = 1; j = 1
#     @inbounds for i in pwlIds
#         ns = numOfCoeffs[i]
#         @inbounds for it = k:(k + ns - 2)
#             Apwl[it, ybas + j - 1] = -1.0
#         end
#         k = k + ns - 1
#         j = j + 1
#     end

#     return Apwl, bpwl
# end


# ### Read data
# function read_opfdcsystem(system, num)
#     busi = @view(system.bus[:, 1])
#     type = @view(system.bus[:, 2])
#     Pload = @view(system.bus[:, 3])
#     Gshunt = @view(system.bus[:, 5])
#     Tini = @view(system.bus[:, 9])

#     Pmax = @view(system.generator[:, 9])
#     Pmin = @view(system.generator[:, 10])

#     reactance = @view(system.branch[:, 5])
#     transTap = @view(system.branch[:, 10])
#     transShift = @view(system.branch[:, 11])
#     branchOn = @view(system.branch[:, 12])
#     longTermRating = @view(system.branch[:, 7])
#     angleMin = @view(system.branch[:, 13])
#     angleMax = @view(system.branch[:, 14])

#     costModel = @view(system.generatorcost[:, 1])
#     numOfCoeffs = convert(Array{Int64,1}, system.generatorcost[:, 4])
#     coeffs = @view(system.generatorcost[:, 5:end])

#     return busi, type, Pload, Gshunt, Tini,
#             Pmax, Pmin,
#             reactance, transTap, transShift, branchOn, longTermRating, angleMin, angleMax,
#             costModel, numOfCoeffs, coeffs
# end
