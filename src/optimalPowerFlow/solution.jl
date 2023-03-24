### DC optimal power flow, created by Ognjen Kundacina
function dcOptimalPowerFlow!(system::PowerSystem, model::JuMP.Model)
    branch = system.branch
    bus = system.bus
    generator = system.generator
    polynomial = generator.cost.active.polynomial
    piecewise = generator.cost.active.piecewise
    
    @variable(model, angle[i = 1:bus.number], start = bus.voltage.angle[i])
    @variable(model, generator.capability.minActive[i] <= output[i = 1:generator.number] <= generator.capability.maxActive[i], start = generator.output.active[i])

    @constraint(model, angle[bus.layout.slack] == 0.0)
    
    indexPiecewise = Array{Int64,1}(undef, 0); sizehint!(indexPiecewise, generator.number)
    indexPiecewiseLinear = Array{Int64,1}(undef, 0); sizehint!(indexPiecewiseLinear, generator.number)
    indexPolynomialSecond = Array{Int64,1}(undef, 0); sizehint!(indexPolynomialSecond, generator.number)
    indexPolynomialFirst = Array{Int64,1}(undef, 0); sizehint!(indexPolynomialFirst, generator.number)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 
            if generator.cost.active.model[i] == 2
                if length(polynomial[i]) == 3
                    push!(indexPolynomialSecond, i)
                elseif length(polynomial[i]) == 2
                    push!(indexPolynomialFirst, i)
                end
            elseif generator.cost.active.model[i] == 1
                if size(piecewise[i], 1) == 2
                    push!(indexPiecewiseLinear, i)
                else
                    push!(indexPiecewise, i)
                end   
            end
        else
            @constraint(model, output[i] == 0.0) 
        end
    end
    
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            angleFrom = angle[branch.layout.from[i]]
            angleTo = angle[branch.layout.to[i]]

            if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                fromLimit = branch.rating.longTerm[i] + system.dcModel.admittance[i] * branch.parameter.shiftAngle[i]
                toLimit = branch.rating.longTerm[i] - system.dcModel.admittance[i] * branch.parameter.shiftAngle[i]
                @constraint(model, -toLimit <= system.dcModel.admittance[i] * (angleFrom - angleTo) <= fromLimit)
            end
            if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                @constraint(model, branch.voltage.minDiffAngle[i] <= angleFrom - angleTo <= branch.voltage.maxDiffAngle[i])
            end
        end
    end

    generatorIncidence = sparse(generator.layout.bus, collect(1:generator.number), 1, bus.number, generator.number)
    @constraint(model, system.dcModel.nodalMatrix * angle - generatorIncidence * output + bus.demand.active + bus.shunt.conductance + system.dcModel.shiftActivePower .== 0.0)

    @variable(model, cost[i = 1:length(indexPiecewise)])

    @inbounds for (k, i) in enumerate(indexPiecewise)
        activePower = @view piecewise[i][:, 1]
        activePowerCost = @view piecewise[i][:, 2]

        for j = 2:size(piecewise[i], 1)
            slope = (activePowerCost[j] - activePowerCost[j-1]) / (activePower[j] - activePower[j-1])
            if slope == Inf
                error("The piecewise linear cost function's slope for the generator labeled as $(generator.label[i]) has infinite value.")
            end

            @constraint(model, slope * output[i] - cost[k] - slope * activePower[j-1] + activePowerCost[j-1] <= 0.0)
        end
    end

    @objective(model, Min, 
        sum(polynomial[i][1] * output[i]^2 + polynomial[i][2] * output[i] + polynomial[i][3] for i in indexPolynomialSecond) + 
        sum(polynomial[i][1] * output[i] + polynomial[i][2] for i in indexPolynomialFirst) + 
        sum((piecewise[i][2, 2] - piecewise[i][1, 2]) / (piecewise[i][2, 1] - piecewise[i][1, 1]) * output[i] + 
            piecewise[i][1, 2] - piecewise[i][1, 1] * (piecewise[i][2, 2] - piecewise[i][1, 2]) / (piecewise[i][2, 1] - piecewise[i][1, 1]) for i in indexPiecewiseLinear) + 
        sum(cost[i] for i = 1:length(indexPiecewise)))
end

function optimizePowerFlow!(system::PowerSystem, model::JuMP.Model)
    bus = system.bus

    optimize!(model)
    angle = JuMP.value.(model[:angle])

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            angle[i] += bus.voltage.angle[bus.layout.slack]
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


function acOptimalPowerFlow!(system::PowerSystem, model::JuMP.Model)
    branch = system.branch
    bus = system.bus
    generator = system.generator
    polynomial = generator.cost.active.polynomial
    piecewise = generator.cost.active.piecewise
    
    @variable(model, angle[i = 1:bus.number], start = bus.voltage.angle[i])
    @variable(model, bus.voltage.minMagnitude[i] <= magnitude[i = 1:bus.number] <= bus.voltage.maxMagnitude[i], start = bus.voltage.magnitude[i])
    @variable(model, generator.capability.minActive[i] <= active[i = 1:generator.number] <= generator.capability.maxActive[i], start = generator.output.active[i])
    @variable(model, generator.capability.minReactive[i] <= reactive[i = 1:generator.number] <= generator.capability.maxReactive[i], start = generator.output.reactive[i])
    
    @constraint(model, angle[bus.layout.slack] == bus.voltage.angle[bus.layout.slack])

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            f = branch.layout.from[i]
            t = branch.layout.to[i]

            Tij = angle[f] - angle[t]

            if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                @constraint(model, branch.voltage.minDiffAngle[i] <= Tij <= branch.voltage.maxDiffAngle[i])
            end

            if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                Vi = magnitude[f]
                Vj = magnitude[t]

                gij = real(system.acModel.admittance[i])
                bij = imag(system.acModel.admittance[i])
                bs = - 0.5 * branch.parameter.susceptance[i] - bij
                Φij = branch.parameter.shiftAngle[i]
    
                if branch.parameter.turnsRatio[i] == 0
                    τij = 1.0
                else
                    τij = branch.parameter.turnsRatio[i]
                end

                @time @NLconstraint(model, ((gij * Vi^2 - τij * Vi * Vj * (gij * cos(Tij - Φij) + bij * sin(Tij - Φij)))^2 + 
                    (bs * Vi^2 - τij * Vi * Vj * (gij * sin(Tij - Φij) - bij * cos(Tij - Φij)))^2) - τij^4 * branch.rating.longTerm[i]^2 <= 0)

                @time @NLconstraint(model, ((gij * Vj^2 - (1 / τij) * Vi * Vj * (gij * cos(Tij - Φij) - bij * sin(Tij - Φij)))^2 + 
                    (bs * Vj^2 + (1 / τij) * Vi * Vj * (gij * sin(Tij - Φij) + bij * cos(Tij - Φij)))^2) - branch.rating.longTerm[i]^2 <= 0)
            end


            # print(model)
            
        end
    end

    supplyActive = zeros(AffExpr, system.bus.number)
    supplyReactive = zeros(AffExpr, system.bus.number)
    indexPolynomialSecond = Array{Int64,1}(undef, 0)
    indexPiecewiseLinear = Array{Int64,1}(undef, 0)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 
            busIndex = generator.layout.bus[i]
            supplyActive[busIndex] += active[i]
            supplyReactive[busIndex] += reactive[i]

            if generator.cost.active.model[i] == 2
                if length(polynomial[i]) == 3
                    push!(indexPolynomialSecond, i)
                elseif length(polynomial[i]) == 2
                end
            elseif generator.cost.active.model[i] == 1
                if size(piecewise[i], 1) == 2
                    push!(indexPiecewiseLinear, i)
                else
                end   
            end
        end
    end

    @inbounds for i = 1:system.bus.number
        n = system.acModel.nodalMatrix.colptr[i + 1] - system.acModel.nodalMatrix.colptr[i]
        Gij = zeros(AffExpr, n)
        Bij = zeros(AffExpr, n)
        Tij = zeros(AffExpr, n)
        for (k, j) in enumerate(system.acModel.nodalMatrix.colptr[i]:(system.acModel.nodalMatrix.colptr[i + 1] - 1))
            row = system.acModel.nodalMatrix.rowval[j]
            Gij[k] = magnitude[row] * real(system.acModel.nodalMatrixTranspose.nzval[j])
            Bij[k] = magnitude[row] * imag(system.acModel.nodalMatrixTranspose.nzval[j])
            Tij[k] = (angle[i] - angle[row])
        end

        @NLconstraint(model, bus.demand.active[i] - supplyActive[i] + magnitude[i] * sum(Gij[i] * cos(Tij[i]) + Bij[i] * sin(Tij[i]) for i = 1:length(Gij)) == 0)
        @NLconstraint(model, bus.demand.reactive[i] - supplyReactive[i] + magnitude[i] * sum(Gij[i] * sin(Tij[i]) - Bij[i] * cos(Tij[i]) for i = 1:length(Gij)) == 0)
    end

    @objective(model, Min, sum(polynomial[i][1] * active[i]^2 + polynomial[i][2] * active[i] + polynomial[i][3] for i in indexPolynomialSecond) + 
        sum((piecewise[i][2, 2] - piecewise[i][1, 2]) / (piecewise[i][2, 1] - piecewise[i][1, 1]) * active[i] + 
            piecewise[i][1, 2] - piecewise[i][1, 1] * (piecewise[i][2, 2] - piecewise[i][1, 2]) / (piecewise[i][2, 1] - piecewise[i][1, 1]) for i in indexPiecewiseLinear)
    )

    optimize!(model)
    angle = JuMP.value.(model[:angle])
    display(angle * 180 / pi)

    magnitude = JuMP.value.(model[:magnitude])
    display(magnitude)
end