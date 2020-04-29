##########################
#  DC power flow results #
##########################
function results_flowdc(settings, system, Ti, slack, algtime)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/flowdc")

    results = Dict("bus" => fill(0.0, system.Nbus, 6), "branch" => fill(0.0, system.Nbra, 5))
    if system.Ngen != 0
        push!(results, "generator" => fill(0.0, system.Ngen, 2))
    end

    ################## DC main results ##################
    for i = 1:system.Nbus
        results["bus"][i, 1] = system.bus[i, 1]
        results["bus"][i, 2] = 180 * Ti[i] / pi
        results["bus"][i, 3] = system.baseMVA * system.bus[i, 11]
        results["bus"][i, 4] = system.baseMVA * system.bus[i, 10]
        results["bus"][i, 5] = system.bus[i, 3]
        results["bus"][i, 6] = system.bus[i, 5]
    end
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("")
        pretty_table(results["bus"], header["bus"], screen_size = (-1,-1), alignment = [:r,:r,:r,:r,:r,:r],
            highlighters = h1, columns_width = [6, 18, 18, 18, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:6)))

        sum_data = Any["Sum" sum(results["bus"][:, 3:6], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [27, 18, 18, 18, 18],
            alignment=[:l,:r,:r,:r,:r], formatters = ft_printf(["%-s","%15.2f","%11.2f","%11.2f","%13.2f"], collect(1:5)))
    end

    ################## DC flow results ##################
    for i = 1:system.Nbra
        results["branch"][i, 1] = system.branch[i, 1]
        results["branch"][i, 2] = system.branch[i, 2]
        results["branch"][i, 3] = system.branch[i, 3]
        results["branch"][i, 4] = system.baseMVA * system.branch[i, 4]
        results["branch"][i, 5] = -system.baseMVA * system.branch[i, 4]
    end
    if settings.flow
        println("")
        pretty_table(results["branch"], header["branch"], screen_size = (-1,-1), columns_width = [6, 8, 8, 18, 18],
            alignment=[:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ################## DC generator results ##################
    for i = 1:system.Ngen
        results["generator"][i, 1] = system.generator[i, 1]
        results["generator"][i, 2] = system.baseMVA * system.generator[i, 2]
    end
    if settings.generator
        println("")
        pretty_table(results["generator"], header["generator"], screen_size = (-1,-1), alignment=[:r,:r],
            formatters = ft_printf(["%1.0f","%1.4f"], collect(1:2)))
    end

    return results, header
end


###########################
#  AC power flow results  #
###########################
function results_flowac(settings, system, limit, slack, Vc, algtime, iter)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/flowac")

    results = Dict("bus" => fill(0.0, system.Nbus, 11), "branch" => fill(0.0, system.Nbra, 14), "iterations" => iter)
    if system.Ngen != 0
        push!(results, "generator" => fill(0.0, system.Ngen, 3))
    end

    ################## AC limit results ##################
    if settings.reactive[1]
        min = findall(x -> x == 2, limit)
        max = findall(x -> x == 3, limit)
        println("")
        if !isempty(min)
            println("Generators that did not satisfy lower reactive power limits:")
            Nl = length(min)
            table = ["Bus" system.generator[min, 1]'; "Generator" min']
            pretty_table(table,
                noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
                formatters = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
            println("")
        end
        if !isempty(max)
            println("Generators that did not satisfy upper reactive power limits:")
            Nl = length(max)
            table = ["Bus" system.generator[max, 1]'; "Generator" max']
            pretty_table(table,
                noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
                formatters = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
        end
    end

    ################## AC main results ##################
    for i = 1:system.Nbus
        results["bus"][i, 1] = system.bus[i, 1]
        results["bus"][i, 2] = abs(Vc[i])
        results["bus"][i, 3] = 180 * angle(Vc[i]) / pi
        results["bus"][i, 4] = system.baseMVA * system.bus[i, 12]
        results["bus"][i, 5] = system.baseMVA * system.bus[i, 13]
        results["bus"][i, 6] = system.baseMVA * system.bus[i, 10]
        results["bus"][i, 7] = system.baseMVA *  system.bus[i, 11]
        results["bus"][i, 8] = system.bus[i, 3]
        results["bus"][i, 9] = system.bus[i, 4]
        results["bus"][i, 10] = system.baseMVA *  system.bus[i, 5]
        results["bus"][i, 11] = system.baseMVA *  system.bus[i, 6]
    end

    if settings.main
        h1 = Highlighter((data, i, j)-> (i == slack), background = :red)
        println("")
        pretty_table(results["bus"], header["bus"],
            screen_size = (-1,-1), highlighters = h1, columns_width = [6, 16, 12, 17, 21, 17, 21, 17, 21, 17, 21],
            alignment = repeat([Symbol(:r)], outer = 11),
            formatters = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:11)))
        sum_data = Any["Sum" sum(results["bus"][:, 4:11], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r,:r,:r,:r,:r], columns_width = [40, 17, 21, 17, 21, 17, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f","%11.2f","%15.2f","%13.2f","%15.2f"], collect(1:9)))
    end

    ################## AC flow results ##################
    for i = 1:system.Nbra
        results["branch"][i, 1] = system.branch[i, 1]
        results["branch"][i, 2] = system.branch[i, 2]
        results["branch"][i, 3] = system.branch[i, 3]
        results["branch"][i, 4] = system.baseMVA * system.branch[i, 8]
        results["branch"][i, 5] = system.baseMVA * system.branch[i, 9]
        results["branch"][i, 6] = system.baseMVA * system.branch[i, 10]
        results["branch"][i, 7] = system.baseMVA * system.branch[i, 11]
        results["branch"][i, 8] = system.baseMVA * system.branch[i, 12]
        results["branch"][i, 9] = system.baseMVA * system.branch[i, 13]
        results["branch"][i, 10] = system.baseMVA * system.branch[i, 14]
        results["branch"][i, 11] = system.branch[i, 4]
        results["branch"][i, 12] = 180 * system.branch[i, 5] / pi
        results["branch"][i, 13] = system.branch[i, 6]
        results["branch"][i, 14] = 180 * system.branch[i, 7] / pi
    end

    if settings.flow
        println("")
        pretty_table(results["branch"][:,1:10], header["branch"][:,1:10],
            screen_size = (-1,-1), columns_width = [6, 8, 8, 17, 21, 17, 21, 21, 17, 21],
            alignment=[:r,:r,:r,:r,:r,:r,:r,:r,:r,:r],
            formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(results["branch"][:, 7:9], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ################## AC generator results ##################
    for i = 1:system.Ngen
        results["generator"][i, 1] = system.generator[i, 1]
        results["generator"][i, 2] = system.baseMVA * system.generator[i, 2]
        results["generator"][i, 3] = system.baseMVA * system.generator[i, 3]
    end

    if settings.generator
        println("")
        pretty_table(results["generator"], header["generator"],
            screen_size = (-1,-1), alignment=[:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%1.4f", "%1.4f"], collect(1:3)))
    end

    return results, header
end


############################
#  Power system info data  #
############################
function infogrid(bus, branch, generator, info, dataname, Nbra, Nbus, Ngen)
    reference = "unknown"
    grid = "unknown"
    for (k, i) in enumerate(info[:, 1])
        if occursin("Reference", i)
            reference = info[k, 2]
        end
        if occursin("Grid", i)
            grid = info[k, 2]
        end
    end

    Ntrain = 0
    Ntra = 0
    pv = 0
    for i = 1:Nbra
        if branch[i, 12] == 1 && (branch[i, 10] != 0 || branch[i, 11] != 0)
            Ntrain += 1
        end
        if branch[i, 10] != 0 || branch[i, 11] != 0
            Ntra += 1
        end
    end
    if Ngen != 0
        pv = length(unique(generator[:, 1]))
    end
    info = ["Reference" string(reference) "";
            "Data" string(dataname) "";
            "Grid" string(grid) "";
            "" "" "";
            "Bus" string(Nbus) "";
            "PV bus" string(pv) "";
            "PQ bus" string(Nbus - pv - 1) "";
            "Shunt element" string(count(x->x != 0, abs.(bus[:, 5]) + abs.(bus[:, 6]))) "";
            "Generator" string(Ngen) "$(trunc(Int, sum(generator[:, 8]))) in-service";
            "Branch" string(Nbra) "$(trunc(Int, sum(branch[:, 12]))) in-service";
            "Transformer" string(Ntra) string(Ntrain, " in-service")]

    return info
end


############################
#  Measurements info data  #
############################
function infogenerator(system, settings, measurement, names)
    setkeys = keys(settings.set)
    varkeys = keys(settings.variance)

    ################## PMU set ##################
    info = [system.info; "" "" ""]
    if "pmuall" in setkeys
        info = [info; "PMU set setting" "all measurements adjust in-service" ""]
    elseif "pmuredundancy" in setkeys
        info = [info; "PMU set setting" "redundancy" string(settings.set["pmuredundancy"])]
    elseif "pmudevice" in setkeys
        info = [info; "PMU set setting" "devices in-services" string(settings.set["pmudevice"])]
    elseif "pmuoptimal" in setkeys
        info = [info; "PMU set setting" "optimal placement" ""]
    elseif "pmuVoltage" in setkeys || "pmuCurrent" in setkeys
        info = [info; "PMU set setting" "measurements by type adjust in-service" ""]
    else
        info = [info; "PMU set setting" "" ""]
    end
    read = Dict("pmuVoltage" => [4, 7], "pmuCurrent" => [6, 9])
    title = Dict("pmuVoltage" => ["Bus voltage magnitude", "Bus voltage angle"],
                "pmuCurrent" => ["Branch current magnitude", "Branch current angle"])
    for i in names["pmu"]
        cnt = 1
        for k in read[i]
            on = trunc(Int, sum(measurement[i][:, k]))
            info = [info; title[i][cnt] "$on in-service" "$(size(measurement[i], 1) - on) out-service"]
            cnt += 1
        end
    end

    ################## Legacy set ##################
    info = [info; "" "" ""]
    if "legacyall" in setkeys
        info = [info; "Legacy set setting" "all measurements adjust in-service" ""]
    elseif "legacyredundancy" in setkeys
        info = [info; "Legacy set setting" "redundancy" string(settings.set["legacyredundancy"])]
    elseif "legacyFlow" in setkeys || "legacyCurrent" in setkeys || "legacyInjection" in setkeys || "legacyVoltage" in setkeys
        info = [info; "Legacy set setting" "measurements by type adjust in-service" ""]
    else
        info = [info; "Legacy set setting" "" ""]
    end
    read = Dict("legacyFlow" => [6, 9], "legacyCurrent" => 6,
                 "legacyInjection" => [4, 7], "legacyVoltage" => 4)
    title = Dict("legacyFlow" => ["Active power flow", "Reactive power flow"],
                "legacyCurrent" => ["Branch current magnitude"],
                "legacyInjection" => ["Active power injection", "Reactive power injection"],
                "legacyVoltage" => ["Bus voltage magnitude"])
    for i in names["legacy"]
        cnt = 1
        for k in read[i]
            on = trunc(Int, sum(measurement[i][:, k]))
            info = [info; title[i][cnt] "$on in-service" "$(size(measurement[i], 1) - on) out-service"]
            cnt += 1
        end
    end

    ################## PMU variance ##################
    info = [info; "" "" ""]
    if "pmuall" in varkeys
        info = [info; "PMU variance setting" "all with same variances" string(settings.variance["pmuall"])]
    elseif "pmurandom" in varkeys
        info = [info; "PMU variance setting" "randomized variances within limits" "$(settings.variance["pmurandom"][1]), $(settings.variance["pmurandom"][2])"]
    elseif "pmuVoltage" in varkeys || "pmuCurrent" in varkeys
        info = [info; "PMU variance setting" "variances by measurement type" ""]
    else
        info = [info; "PMU variance set setting" "" ""]
    end
    read = Dict("pmuVoltage" => [3, 6], "pmuCurrent" => [5, 8])
    title = Dict("pmuVoltage" => ["Bus voltage magnitude", "Bus voltage angle"],
                "pmuCurrent" => ["Branch current magnitude", "Branch current angle"])
    for i in names["pmu"]
        cnt = 1
        for k in read[i]
            on = extrema(measurement[i][:, k])
            info = [info; title[i][cnt] "$(on[1]) minimum" "$(on[2]) maximum"]
            cnt += 1
        end
    end

    ################## Legacy variance ##################
    info = [info; "" "" ""]
    if "legacyall" in varkeys
        info = [info; "Legacy variance setting" "all with same variances" string(settings.variance["legacyall"])]
    elseif "legacyrandom" in varkeys
        info = [info; "Legacy variance setting" "randomized variances within limits" string(settings.variance["legacyrandom"][1], ", ", settings.variance["legacyrandom"][2])]
    elseif "legacyFlow" in varkeys || "legacyCurrent" in varkeys || "legacyInjection" in varkeys || "legacyVoltage" in varkeys
        info = [info; "Legacy variance setting" "variances by measurement type" ""]
    else
        info = [info; "Legacy variance set setting" "" ""]
    end
    read = Dict("legacyFlow" => [5, 8], "legacyCurrent" => 5,
                 "legacyInjection" => [3, 6], "legacyVoltage" => 3)
    title = Dict("legacyFlow" => ["Active power flow", "Reactive power flow"],
                "legacyCurrent" => ["Branch current magnitude"],
                "legacyInjection" => ["Active power injection", "Reactive power injection"],
                "legacyVoltage" => ["Bus voltage magnitude"])
    for i in names["legacy"]
        cnt = 1
        for k in read[i]
            on = extrema(measurement[i][:, k])
            info = [info; title[i][cnt] "$(on[1]) minimum" "$(on[2]) maximum"]
            cnt += 1
        end
    end

    return info
end


################################
#  DC state estimation results #
################################
function results_estimationdc(settings, system, Ti, slack, algtime, measurement, Nmeasur, branchPij, busPi, busTi, savebad)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/estimationdc")

    dimension = [0, 0]
    exact = false
    if size(measurement.pmuVoltage, 2) == 9 && size(measurement.legacyFlow, 2) == 11 && size(measurement.legacyInjection, 2) == 9
        exact = true
        dimension = [6, 3, 3]
        errordes = header["errordes"]
    else
        dimension = [4, 3, 1]
        errordes = header["errordesno"]
    end

    ################## DC bad data results ##################
    N = 0
    labelbad = Array{String}(undef, size(savebad, 1), 2)
    if settings.bad && !isempty(savebad)
        for i = 1:measurement.legacyNv
            if measurement.pmuVoltage[i, 7] == 1
                N += 1
                if N in savebad[:, 1]
                    measurement.pmuVoltage[i, 7] = 0
                    idx = findfirst(x->x==N, savebad[:, 1])
                    labelbad[idx, 1] = "PMU"
                    labelbad[idx, 2] = "T$(trunc(Int, measurement.legacyInjection[i, 1]))"
                    Nmeasur -= 1
                end
            end
        end
        for i = 1:measurement.legacyNf
            if measurement.legacyFlow[i, 6] == 1
                N += 1
                if N in savebad[:, 1]
                    measurement.legacyFlow[i, 6] = 0
                    idx = findfirst(x->x==N, savebad[:, 1])
                    labelbad[idx, 1] = "Legacy"
                    labelbad[idx, 2] = "P$(trunc(Int, measurement.legacyFlow[i, 2])),$(trunc(Int, measurement.legacyFlow[i, 3]))"
                    Nmeasur -= 1
                end
            end
        end
        for i = 1:measurement.legacyNi
            if measurement.legacyInjection[i, 4] == 1
                N += 1
                if N in savebad[:, 1]
                    measurement.legacyInjection[i, 4] = 0
                    idx = findfirst(x->x==N, savebad[:, 1])
                    labelbad[idx, 1] = "Legacy"
                    labelbad[idx, 2] = "P$(trunc(Int, measurement.legacyInjection[i, 1]))"
                    Nmeasur -= 1
                end
            end
        end

        println("")
        pass = collect(1:size(savebad, 1))
        headerbad = ["Algorithm Pass" "Type" "Suspected Bad Data" "Normalized Residual" "Status"]
        pretty_table([pass labelbad savebad[:, 2:end]], headerbad, screen_size = (-1,-1), columns_width = [15, 10, 20, 20, 10],
            alignment=[:l,:l,:l,:r,:r], formatters = ft_printf(["%1.0f", "%-s","%-s","%1.4e","%-s"], collect(1:5)))
    end

    estimate = zeros(Nmeasur, dimension[1])
    label = Array{String}(undef, Nmeasur, dimension[2])
    error = zeros(dimension[3], 3)
    bus = fill(0.0, system.Nbus, 3)
    branch = fill(0.0, system.Nbra, 5)

    ################## DC main results ##################
    for i = 1:system.Nbus
        bus[i, 1] = system.bus[i, 1]
        bus[i, 2] = 180 * Ti[i] / pi
        bus[i, 3] = system.baseMVA * system.bus[i, 11]
    end
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("")
        pretty_table(bus, header["bus"], screen_size = (-1,-1), alignment = [:r,:r,:r],
            highlighters = h1, columns_width = [6, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f"], collect(1:3)))

        sum_data = Any["Sum" sum(bus[:, 3], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [27, 18],
            alignment=[:l,:r], formatters = ft_printf(["%-s","%15.2f"], [1, 2]))
    end

    ################## DC flow results ##################
    for i = 1:system.Nbra
        branch[i, 1] = system.branch[i, 1]
        branch[i, 2] = system.branch[i, 2]
        branch[i, 3] = system.branch[i, 3]
        branch[i, 4] = system.baseMVA * system.branch[i, 4]
        branch[i, 5] = -system.baseMVA * system.branch[i, 4]
    end
    if settings.flow
        println("")
        pretty_table(branch, header["branch"], screen_size = (-1,-1), columns_width = [6, 8, 8, 18, 18],
            alignment=[:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end


    ################## DC estimate and error results ##################
    idx = 1
    scaleTi = 180 / pi
    for i = 1:measurement.pmuNv
        if measurement.pmuVoltage[i, 7] == 1
            label[idx, 1] = "PMU"
            label[idx, 2] = "T$(trunc(Int, measurement.legacyInjection[i, 1]))"
            label[idx, 3] = "deg"

            estimate[idx, 1] = bus[busTi[i], 2]
            estimate[idx, 2] = 180 * measurement.pmuVoltage[i, 5] / pi
            estimate[idx, 3] = abs(estimate[idx, 1] - estimate[idx, 2])

            error[1, 1] += estimate[idx, 3] / (Nmeasur * scaleTi)
            error[1, 2] += estimate[idx, 3]^2 / (Nmeasur * scaleTi^2)
            error[1, 3] += estimate[idx, 3]^2 / (measurement.pmuVoltage[i, 6] * scaleTi^2)

            if exact
                estimate[idx, 4] = 180 * measurement.pmuVoltage[i, 9] / pi
                estimate[idx, 5] = abs(estimate[idx, 1] - estimate[idx, 4])
                estimate[idx, 6] = 180 * measurement.pmuVoltage[i, 6]  / pi

                error[2, 1] += estimate[idx, 5] / (Nmeasur * scaleTi)
                error[2, 2] += estimate[idx, 5]^2 / (Nmeasur * scaleTi^2)
                error[2, 3] += estimate[idx, 5]^2 / (measurement.pmuVoltage[i, 6] * scaleTi^2)
            else
                estimate[idx, 4] = 180 * measurement.pmuVoltage[i, 6] / pi
            end
            idx += 1
        end
    end
    for i = 1:measurement.legacyNf
        if measurement.legacyFlow[i, 6] == 1
            label[idx, 1] = "Legacy"
            label[idx, 2] = "P$(trunc(Int, measurement.legacyFlow[i, 2])),$(trunc(Int, measurement.legacyFlow[i, 3]))"
            label[idx, 3] = "MW"

            k = branchPij[i]
            if measurement.legacyFlow[i, 2] == system.branch[k, 2] && measurement.legacyFlow[i, 3] == system.branch[k, 3]
                estimate[idx, 1] = branch[k, 4]
            else
                estimate[idx, 1] = branch[k, 5]
            end
            estimate[idx, 2] = measurement.legacyFlow[i, 4] * system.baseMVA
            estimate[idx, 3] = abs(estimate[idx, 1] - estimate[idx, 2])

            error[1, 1] += estimate[idx, 3] / (Nmeasur * system.baseMVA)
            error[1, 2] += estimate[idx, 3]^2 / (Nmeasur * system.baseMVA^2)
            error[1, 3] += estimate[idx, 3]^2 / (measurement.legacyFlow[i, 5] * system.baseMVA^2)

            if exact
                estimate[idx, 4] = measurement.legacyFlow[i, 10] * system.baseMVA
                estimate[idx, 5] = abs(estimate[idx, 1] - estimate[idx, 4])
                estimate[idx, 6] = measurement.legacyFlow[i, 5] * system.baseMVA

                error[2, 1] += estimate[idx, 5] / (Nmeasur * system.baseMVA)
                error[2, 2] += estimate[idx, 5]^2 / (Nmeasur * system.baseMVA^2)
                error[2, 3] += estimate[idx, 5]^2 / (measurement.legacyFlow[i, 5] * system.baseMVA^2)
            else
                estimate[idx, 4] = measurement.legacyFlow[i, 5] * system.baseMVA
            end
            idx += 1
        end
    end
    for i = 1:measurement.legacyNi
        if measurement.legacyInjection[i, 4] == 1
            label[idx, 1] = "Legacy"
            label[idx, 2] = "P$(trunc(Int, measurement.legacyInjection[i, 1]))"
            label[idx, 3] = "MW"

            estimate[idx, 1] = bus[busPi[i], 3]
            estimate[idx, 2] = measurement.legacyInjection[i, 2] * system.baseMVA
            estimate[idx, 3] = abs(estimate[idx, 1] - estimate[idx, 2])

            error[1, 1] += estimate[idx, 3] / (Nmeasur * system.baseMVA)
            error[1, 2] += estimate[idx, 3]^2 / (Nmeasur * system.baseMVA^2)
            error[1, 3] += estimate[idx, 3]^2 / (measurement.legacyInjection[i, 3] * system.baseMVA^2)

            if exact
                estimate[idx, 4] = measurement.legacyInjection[i, 8] * system.baseMVA
                estimate[idx, 5] = abs(estimate[idx, 1] - estimate[idx, 4])
                estimate[idx, 6] = measurement.legacyInjection[i, 3] * system.baseMVA

                error[2, 1] += estimate[idx, 5] / (Nmeasur * system.baseMVA)
                error[2, 2] += estimate[idx, 5]^2 / (Nmeasur * system.baseMVA^2)
                error[2, 3] += estimate[idx, 5]^2 / (measurement.legacyInjection[i, 3] * system.baseMVA^2)
            else
                estimate[idx, 4] = measurement.legacyInjection[i, 3] * system.baseMVA
            end
            idx += 1
        end
    end

    if exact
        for i = 1:system.Nbus
            error[3, 1] += abs(pi * bus[i, 2] / 180 - measurement.pmuVoltage[i, 9]) / Nmeasur
            error[3, 2] += (pi * bus[i, 2] / 180 - measurement.pmuVoltage[i, 9])^2 / Nmeasur
        end
    end
    error[:, 2] = sqrt.(error[:, 2])

    if settings.estimate
        println("")
        if exact
            columns_width = [7, 9, 9, 9, 15, 15, 15, 15, 15, 15]
            alignment = [:l, :l, :l, :l, :r, :r, :r, :r, :r, :r]
            formatters = ["%1.0f", "%s", "%s", "%s", "%1.2f", "%1.2f", "%1.2e", "%1.2f", "%1.2e", "%1.2e"]
            many = collect(1:10)
            head = header["estimate"]
        else
            columns_width = [7, 9, 9, 9, 15, 15, 15, 15]
            alignment = [:l, :l, :l, :l, :r, :r, :r, :r]
            formatters = ["%1.0f", "%s", "%s", "%s", "%1.2f", "%1.2f", "%1.2e", "%1.2e"]
            many = collect(1:8)
            head = header["estimateno"]
        end
        pretty_table([collect(1:Nmeasur) label estimate], head, screen_size = (-1,-1), columns_width = columns_width,
            alignment = alignment, formatters = ft_printf((formatters), many))
    end

    ################## DC error display ##################
    if settings.error
        println("")
        pretty_table([errordes error], header["error"], screen_size = (-1,-1), columns_width = [55, 15, 15, 15],
            alignment=[:l,:r,:r,:r], formatters = ft_printf(["%-s","%1.4e","%1.4e","%1.4e"], collect(1:4)))
    end

    ################## Export results ##################
    results = Dict("bus" => bus, "branch" => branch, "estimate" => [collect(1:Nmeasur) label estimate], "error" => [errordes error])

    labels = Dict()
    savetoh5 = Dict()
    if settings.saveextension == ".h5"
        atr = [string(label[i, 1], ": ", label[i, 2], " [", label[i, 3], "]") for i=1:Nmeasur]
        push!(labels, "estimate" => atr)
        push!(labels, "error" => errordes)
        savetoh5 = Dict("bus" => bus, "branch" => branch, "estimate" => [collect(1:Nmeasur) estimate], "error" => error)
        if exact
            header["estimate"] = header["estimateH5"]
        else
            header["estimate"] = header["estimateH5no"]
        end
    end

    return results, header, labels, savetoh5
end
