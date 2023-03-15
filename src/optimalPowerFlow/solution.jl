### DC optimal power flow, created by Ognjen Kundacina
function dcOptimalPowerFlow!(system::PowerSystem, model::JuMP.Model)
    dc = system.dcModel
    branch = system.branch
    bus = system.bus
    generator = system.generator
    polynomial = generator.cost.active.polynomial
    piecewise = generator.cost.active.piecewise
    
    @variable(model, angle[i = 1:bus.number], start = bus.voltage.angle[i])
    @variable(model, generator.capability.minActive[i] <= output[i = 1:generator.number] <= generator.capability.maxActive[i])

    @constraint(model, angle[bus.layout.slack] == 0.0)
    
    indexPiecewise = Array{Int64,1}(undef, 0)
    indexPiecewiseLinear = Array{Int64,1}(undef, 0)
    indexPolynomial = Array{Int64,1}(undef, 0)
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            set_start_value(output[i], (generator.capability.minActive[i] + generator.capability.maxActive[i]) / 2)
            if generator.cost.active.model[i] == 2
                push!(indexPolynomial, i)
            elseif generator.cost.active.model[i] == 1
                if size(generator.cost.active.piecewise[i], 1) == 2
                    push!(indexPiecewiseLinear, i)
                else
                    push!(indexPiecewise, i)
                end   
            end
        else
            @constraint(model, output[i] == 0.0) 
        end
    end
    @variable(model, cost[i = 1:length(indexPiecewise)])

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            angleFrom = angle[branch.layout.from[i]]
            angleTo = angle[branch.layout.to[i]]

            if branch.rating.longTerm[i] ≉  0 && branch.rating.longTerm[i] < 10^16
                fromLimit = branch.rating.longTerm[i] + dc.admittance[i] * branch.parameter.shiftAngle[i]
                toLimit = branch.rating.longTerm[i] - dc.admittance[i] * branch.parameter.shiftAngle[i]
                @constraint(model, -toLimit <= dc.admittance[i] * (angleFrom - angleTo) <= fromLimit)
            end
            if branch.voltage.minDiffAngle[i] > -2*pi && branch.voltage.maxDiffAngle[i] < 2*pi
                @constraint(model, branch.voltage.minDiffAngle[i] <= angleFrom - angleTo <= branch.voltage.maxDiffAngle[i])
            end
        end
    end

    generatorIncidence = sparse(generator.layout.bus, collect(1:generator.number), 1, bus.number, generator.number)
    @constraint(model, dc.nodalMatrix * angle - generatorIncidence * output .== - bus.demand.active - bus.shunt.conductance - dc.shiftActivePower)

    @inbounds for (k, i) in enumerate(indexPiecewise)
        p = @view generator.cost.active.piecewise[i][:, 1]
        c = @view generator.cost.active.piecewise[i][:, 2]

        for j = 2:size(generator.cost.active.piecewise[i], 1)
            m = (c[j] - c[j-1]) / (p[j] - p[j-1])
            if m == Inf
                error("The cost specified in the generator cost data for a given active power output is not legal.")
            end
            b = m * p[j-1] - c[j-1] 

           @constraint(model, m * output[i] - cost[k] <= b)
        end
    end

    @objective(model, Min, sum(polynomial[i][1] * output[i]^2 + polynomial[i][2] * output[i] + polynomial[i][3] for i in indexPolynomial) + 
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