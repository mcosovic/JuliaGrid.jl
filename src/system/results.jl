##############################################
#  DC dower flow results and call save data  #
##############################################
function results_flowdc(settings, system, Ti, slack, algtime)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/flowdc")

    results = Dict("bus" => fill(0.0, system.Nbus, 6), "branch" => fill(0.0, system.Nbra, 5))
    if system.Ngen != 0
        push!(results, "generator" => fill(0.0, system.Ngen, 2))
    end

    ################## DC Main Display ##################
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
            formatter = ft_printf(["%1.0f","%1.4f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:6)))

        sum_data = Any["Sum" sum(results["bus"][:, 3:6], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [27, 18, 18, 18, 18],
            alignment=[:l,:r,:r,:r,:r], formatter = ft_printf(["%-s","%15.2f","%11.2f","%11.2f","%13.2f"], collect(1:5)))
    end

    ################## DC Flow Display ##################
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
        alignment=[:r,:r,:r,:r,:r], formatter = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ################## DC Generator Display ##################
    for i = 1:system.Ngen
        results["generator"][i, 1] = system.generator[i, 1]
        results["generator"][i, 2] = system.baseMVA * system.generator[i, 2]
    end
    if settings.generator
        println("")
        pretty_table(results["generator"], header["generator"], screen_size = (-1,-1), alignment=[:r,:r],
            formatter = ft_printf(["%1.0f","%1.4f"], collect(1:2)))
    end

    if !isempty(settings.save)
        savedata(results; info = system.info, group = keys(results), header = header, path = settings.save)
    end

    return results
end


##############################################
#  AC dower flow results and call save data  #
##############################################
function results_flowac(settings, system, limit, slack, Vc, algtime, iter)
    println(string("  Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/flowac")

    results = Dict("bus" => fill(0.0, system.Nbus, 11), "branch" => fill(0.0, system.Nbra, 14), "iterations" => iter)
    if system.Ngen != 0
        push!(results, "generator" => fill(0.0, system.Ngen, 3))
    end

    ################## AC Limit Display ##################
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
            formatter = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
            println("")
        end
        if !isempty(max)
            println("Generators that did not satisfy upper reactive power limits:")
            Nl = length(max)
            table = ["Bus" system.generator[max, 1]'; "Generator" max']
            pretty_table(table,
            noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
            formatter = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
        end
    end

    ################## AC Main Display ##################
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
             formatter = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:11)))
        sum_data = Any["Sum" sum(results["bus"][:, 4:11], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r,:r,:r,:r,:r], columns_width = [40, 17, 21, 17, 21, 17, 21, 17, 21],
            formatter = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f","%11.2f","%15.2f","%13.2f","%15.2f"], collect(1:9)))
    end

    ################## AC Flow Display ##################
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
             formatter = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(results["branch"][:, 7:9], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
                    formatter = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ################## AC Generator Display ##################
    for i = 1:system.Ngen
        results["generator"][i, 1] = system.generator[i, 1]
        results["generator"][i, 2] = system.baseMVA * system.generator[i, 2]
        results["generator"][i, 3] = system.baseMVA * system.generator[i, 3]
    end

    if settings.generator
        println("")
        pretty_table(results["generator"], header["generator"],
            screen_size = (-1,-1), alignment=[:r,:r,:r],
            formatter = ft_printf(["%1.0f", "%1.4f", "%1.4f"], collect(1:3)))
    end


    ################## Export Data ##################
    if !isempty(settings.save)
        group = ["bus" "branch"]
        if system.Ngen != 0
            group = [group "generator"]
        end
        savedata(results; info = system.info, group = group, header = header, path = settings.save)
    end

    return results
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
            "Generator" string(Ngen) string(trunc(Int, sum(generator[:, 8])), " in-service");
            "Branch" string(Nbra) string(trunc(Int, sum(branch[:, 12])), " in-service");
            "Transformer" string(Ntra) string(Ntrain, " in-service")]

    return info
end


###############################################
#  Measurements info data and call save data  #
###############################################
function infogenerator(system, settings, measurement, names)
    setkeys = keys(settings.set)
    varkeys = keys(settings.variance)

    ################## PMU Set ##################
    info = [system.info; "" "" ""]
    if any(setkeys .== "pmuall")
        info = [info; "PMU set setting" "all measurements adjust in-service" ""]
    elseif any(setkeys .== "pmuredundancy")
        info = [info; "PMU set setting" "redundancy" string(settings.set["pmuredundancy"])]
    elseif any(setkeys .== "pmudevice")
        info = [info; "PMU set setting" "devices in-services" string(settings.set["pmudevice"])]
    elseif any(setkeys .== "pmuoptimal")
        info = [info; "PMU set setting" "optimal placement" ""]
    elseif any(setkeys .== "pmuVoltage") || any(setkeys .== "pmuCurrent")
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
            info = [info; title[i][cnt] string(on, " in-service") string(size(measurement[i], 1) - on, " out-service")]
            cnt += 1
        end
    end

    ################## Legacy Set ##################
    info = [info; "" "" ""]
    if any(setkeys .== "legacyall")
        info = [info; "Legacy set setting" "all measurements adjust in-service" ""]
    elseif any(setkeys .== "legacyredundancy")
        info = [info; "Legacy set setting" "redundancy" string(settings.set["legacyredundancy"])]
    elseif any(setkeys .== "legacyFlow") || any(setkeys .== "legacyCurrent") || any(setkeys .== "legacyInjection") || any(setkeys .== "legacyVoltage")
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
            info = [info; title[i][cnt] string(on, " in-service") string(size(measurement[i], 1) - on, " out-service")]
            cnt += 1
        end
    end

    ################## PMU Variance ##################
    info = [info; "" "" ""]
    if any(varkeys .== "pmuall")
        info = [info; "PMU variance setting" "all with same variances" string(settings.variance["pmuall"])]
    elseif any(varkeys .== "pmurandom")
        info = [info; "PMU variance setting" "randomized variances within limits" string(settings.variance["pmurandom"][1], ", ", settings.variance["pmurandom"][2])]
    elseif any(varkeys .== "pmuVoltage") || any(varkeys .== "pmuCurrent")
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
            info = [info; title[i][cnt] string(on[1], " minimum") string(on[2], " maximum")]
            cnt += 1
        end
    end

    ################## Legacy Variance ##################
    info = [info; "" "" ""]
    if any(varkeys .== "legacyall")
        info = [info; "Legacy variance setting" "all with same variances" string(settings.variance["legacyall"])]
    elseif any(varkeys .== "legacyrandom")
        info = [info; "Legacy variance setting" "randomized variances within limits" string(settings.variance["legacyrandom"][1], ", ", settings.variance["legacyrandom"][2])]
    elseif any(varkeys .== "legacyFlow") || any(varkeys .== "legacyCurrent") || any(varkeys .== "legacyInjection") || any(varkeys .== "legacyVoltage")
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
            info = [info; title[i][cnt] string(on[1], " minimum") string(on[2], " maximum")]
            cnt += 1
        end
    end

    ################## Export Data ##################
    if !isempty(settings.path)
        header = h5read(joinpath(system.packagepath, "src/system/header.h5"), "/measurement")

        group = ["pmuVoltage"; "pmuCurrent"; "legacyFlow"; "legacyCurrent"; "legacyInjection"; "legacyVoltage"]
        for (k, i) in enumerate(group)
            if !any(i .== keys(measurement))
                deleteat!(group, k)
            end
        end
        if system.Ngen != 0
            group = [group; "bus"; "generator"; "branch"; "basePower"]
            push!(measurement, "generator" => system.generator)
        else
            group = [group; "bus"; "branch"; "basePower"]
        end

        push!(measurement, "bus" => system.bus)
        push!(measurement, "branch" => system.branch)
        push!(measurement, "basePower" => system.baseMVA)

        savedata(measurement; group = group, header = header, path = settings.path, info = info)
    end

    return info
end
