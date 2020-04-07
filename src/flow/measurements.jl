

#-------------------------------------------------------------------------------
function rungenerator(system, settings, bus, branch)
    busi, Vi, Ti, Pinj, Qinj, branchi, fromi, toi, Pij, Qij, Pji, Qji, Iij, Dij, Iji, Dji = view_generator(bus, branch)
    Nbus = size(bus, 1)
    Nbranch = size(branch, 1)

    measurements = Dict("LegFlow" => fill(0.0, 2 * Nbranch, 11), "LegCurrent" =>  fill(0.0, 2 * Nbranch, 7),
                        "LegInjection" => fill(0.0, Nbus, 9), "LegVoltage" => fill(0.0, Nbus, 5),
                        "PmuVoltage" => fill(0.0, Nbus, 9), "PmuCurrent" =>  fill(0.0, 2 * Nbranch, 11))

    for i = 1:Nbranch
        measurements["LegFlow"][i, 1] = branchi[i]
        measurements["LegFlow"][i + Nbranch, 1] = branchi[i]
        measurements["LegFlow"][i, 2] = fromi[i]
        measurements["LegFlow"][i + Nbranch, 2] = toi[i]
        measurements["LegFlow"][i, 3] = toi[i]
        measurements["LegFlow"][i + Nbranch, 3] = fromi[i]
        measurements["LegFlow"][i, 10] = Pij[i] / system.baseMVA
        measurements["LegFlow"][i + Nbranch, 10] = Pji[i] / system.baseMVA
        measurements["LegFlow"][i, 11] = Qij[i] / system.baseMVA
        measurements["LegFlow"][i + Nbranch, 11] = Qji[i] / system.baseMVA

        measurements["LegCurrent"][i, 1] = branchi[i]
        measurements["LegCurrent"][i + Nbranch, 1] = branchi[i]
        measurements["LegCurrent"][i, 2] = fromi[i]
        measurements["LegCurrent"][i + Nbranch, 2] = toi[i]
        measurements["LegCurrent"][i, 3] = toi[i]
        measurements["LegCurrent"][i + Nbranch, 3] = fromi[i]
        measurements["LegCurrent"][i, 7] = Iij[i]
        measurements["LegCurrent"][i + Nbranch, 7] = Iji[i]

        measurements["PmuCurrent"][i, 1] = branchi[i]
        measurements["PmuCurrent"][i + Nbranch, 1] = branchi[i]
        measurements["PmuCurrent"][i, 2] = fromi[i]
        measurements["PmuCurrent"][i + Nbranch, 2] = toi[i]
        measurements["PmuCurrent"][i, 3] = toi[i]
        measurements["PmuCurrent"][i + Nbranch, 3] = fromi[i]
        measurements["PmuCurrent"][i, 10] = Iij[i]
        measurements["PmuCurrent"][i + Nbranch, 10] = Iji[i]
        measurements["PmuCurrent"][i, 11] = Dij[i]
        measurements["PmuCurrent"][i + Nbranch, 11] = Dji[i]
    end

    for i = 1:Nbus
        measurements["LegInjection"][i, 1] = busi[i]
        measurements["LegInjection"][i, 8] = Pinj[i] / system.baseMVA
        measurements["LegInjection"][i, 9] = Qinj[i] / system.baseMVA

        measurements["LegVoltage"][i, 1] = busi[i]
        measurements["LegVoltage"][i, 5] = Vi[i]

        measurements["PmuVoltage"][i, 1] = busi[i]
        measurements["PmuVoltage"][i, 8] = Vi[i]
        measurements["PmuVoltage"][i, 9] = (pi / 180) * Ti[i]
    end

    names = Dict("pmu" => ["PmuCurrent", "PmuCurrent", "PmuVoltage", "PmuVoltage"],
                 "legacy" => ["LegFlow", "LegFlow", "LegCurrent", "LegInjection", "LegInjection", "LegVoltage"])
    column = Dict("pmu" => [6, 9, 4, 7],
                  "legacy" => [6, 9, 6, 4, 7, 4])
    stat = Dict("pmu" => trunc.(Int, [4 * Nbranch + 2 * Nbus, (4 * Nbranch + 2 * Nbus) / (2 * Nbus - 1)]),
                "legacy" => trunc.(Int, [6 * Nbranch + 3 * Nbus, (6 * Nbranch + 3 * Nbus) / (2 * Nbus - 1)]))

    for i in ["pmu", "legacy"]
        if settings.set[i][1] == "all"
            for (k, j) in enumerate(names[i])
                measurements[j][:, column[i][k]] .= 1
            end
        end

        if settings.set[i][1] == "redundancy"
            success = 0
            if isa(settings.set[i][2], Number) && settings.set[i][2] <= stat[i][2]
                success = 1
                idxn = randperm(stat[i][1])
                on = trunc(Int, round((2 * Nbus - 1) * settings.set[i][2]))
                idx = idxn[1:on]

                total_set = fill(0, stat[i][1])
                total_set[idx] .= 1
            end
            if isa(settings.set[i][2], Number) && settings.set[i][2] > stat[i][2] || settings.set[i][2] == "all"
                success = 1
                total_set = fill(1, stat[i][1])
            end
            if success == 1
                start = 0
                last = 0
                for (k, j) in enumerate(names[i])
                    last += length(measurements[j][:, column[i][k]])
                    measurements[j][:, column[i][k]] = total_set[(start + 1):last]
                    start += length(measurements[j][:, column[i][k]])
                end
            end
        end

        if settings.set[i][1] == "onebyone"
            for (k, j) in enumerate(names[i])
                if isa(settings.set[i][k + 1], Number) && settings.set[i][k + 1] <= length(measurements[j][:, 1])
                    idxn = randperm(length(measurements[j][:, 1]))
                    on = trunc(Int, settings.set[i][k + 1])
                    idx = idxn[1:on]
                    measurements[j][idx, column[i][k]] .= 1
                end
                if isa(settings.set[i][k + 1], Number) && settings.set[i][k + 1] > length(measurements[j][:, 1]) || settings.set[i][k + 1] == "all"
                    measurements[j][:, column[i][k]] .= 1
                end
            end
        end
    end

    if settings.set["pmu"][1] == "device" || settings.set["pmu"][1] == "optimal"
        if settings.set["pmu"][1] == "device"
            if isa(settings.set["pmu"][2], Number) && settings.set["pmu"][2] <= bus.Nbus
                idxn = randperm(bus.Nbus)
                on = trunc(Int, settings.set["pmu"][2])
                idx = idxn[1:on]
            end
        end
        if settings.set["pmu"][1] == "optimal"
            bus = collect(1:Nbus)
            @inbounds for i = 1:Nbus
                if bus[i] != busi[i]
                    numbering = true
                end
            end
            from, to = numbering_branch(fromi, toi, busi, Nbranch, Nbus, bus, numbering)

            A = sparse([bus; from; to], [bus; to; from], fill(1, Nbus + 2 * Nbranch), Nbus, Nbus)
            f  = fill(1, bus.Nbus);
            lb = fill(0, bus.Nbus);
            ub = fill(1, bus.Nbus);

            if settings.set["pmu"][2] == "Gurobi"
                model = Model(with_optimizer(Gurobi.Optimizer))
            end
            if settings.set["pmu"][2] == "GLPK"
                model = Model(with_optimizer(GLPK.Optimizer))
            end

            @variable(model, x[i = 1:Nbus], Int)
            @constraint(model, lb .<= x .<= ub)
            @constraint(model, -A * x .<= -f)
            @objective(model, Min, sum(x))

            optimize!(model)
            x = JuMP.value.(x)
            idx = findall(x->x == 1, x)
            display(idx)
        end
        for i in idx
            measurements["PmuVoltage"][i, 4] = 1
            measurements["PmuVoltage"][i, 7] = 1
            for j = 1:Nbranch
                if bus[i, 1] == branch[j, 1]
                    measurements["PmuCurrent"][j, 5] = 1
                    measurements["PmuCurrent"][j, 8] = 1
                end
                if bus[i, 1] == branch[j, 2]
                    measurements["PmuCurrent"][j + Nbranch, 5] = 1
                    measurements["PmuCurrent"][j + Nbranch, 8] = 1
                end
            end
        end
    end

    names = Dict("pmu" => ["PmuCurrent", "PmuCurrent", "PmuVoltage", "PmuVoltage"],
                 "legacy" => ["LegFlow", "LegFlow", "LegCurrent", "LegInjection", "LegInjection", "LegVoltage"])
    column = Dict("pmu" => [5, 8, 3, 6],
                  "legacy" => [5, 8, 5, 3, 6, 3])
    for i in ["pmu", "legacy"]
        if settings.variance[i][1] == "all"
            if isa(settings.variance[i][2], Number) && settings.variance[i][2] > 0
                variance = settings.variance[i][2]
            else
                error("Invalid variance input.")
            end
            for (k, j) in enumerate(names[i])
                measurements[j][:, column[i][k]] .= variance
            end
        end

        if settings.variance[i][1] == "random"
            if isa(settings.variance[i][2], Number) && isa(settings.variance[i][3], Number) && settings.variance[i][2] > 0 && settings.variance[i][3] > 0
                variance_min = minimum([settings.variance[i][2], settings.variance[i][3]])
                variance_max = maximum([settings.variance[i][2], settings.variance[i][3]])
            else
                error("Invalid variance input.")
            end
            for (k, j) in enumerate(names[i])
                measurements[j][:, column[i][k]] = variance_min .+ (variance_max - variance_min) .* rand(length(measurements[j][:, 1]))
            end
        end

        if settings.variance[i][1] == "onebyone"
            for (k, j) in enumerate(names[i])
                if isa(settings.variance[i][k + 1], Number) && settings.variance[i][k + 1] > 0
                    measurements[j][:, column[i][k]] .= settings.variance[i][k + 1]
                else
                    error("Invalid variance input.")
                end
            end
        end
    end

    results_generator(system, settings, Nbranch, Nbus, measurements)
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function view_generator(bus, branch)
    # Read Data
    busi = @view(bus[:, 1])
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    Pinj = @view(bus[:, 4])
    Qinj = @view(bus[:, 5])

    branchi = @view(branch[:, 1])
    fromi = @view(branch[:, 2])
    toi = @view(branch[:, 3])
    Pij = @view(branch[:, 4])
    Qij = @view(branch[:, 5])
    Pji = @view(branch[:, 6])
    Qji = @view(branch[:, 7])
    Iij = @view(branch[:, 10])
    Dij = @view(branch[:, 11])
    Iji = @view(branch[:, 12])
    Dji = @view(branch[:, 13])

    return busi, Vi, Ti, Pinj, Qinj, branchi, fromi, toi, Pij, Qij, Pji, Qji, Iij, Dij, Iji, Dji
end
#-------------------------------------------------------------------------------
