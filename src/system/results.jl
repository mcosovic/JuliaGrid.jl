##############################################
#  DC dower flow results and call save data  #
##############################################
function results_flowdc(settings, system, Nbus, Nbranch, Ngen, Ti, slack, algtime, info)
    println(string("  Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.package, "src/system/header.h5"), "/flowdc")

    ################## DC Main Display ##################
    bus = fill(0.0, Nbus, 6)
    for i = 1:Nbus
        bus[i, 1] = system.bus[i, 1]
        bus[i, 2] = 180 * Ti[i] / pi
        bus[i, 3] = system.baseMVA * system.bus[i, 11]
        bus[i, 4] = system.baseMVA * system.bus[i, 10]
        bus[i, 5] = system.bus[i, 3]
        bus[i, 6] = system.bus[i, 5]
    end
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("")
        pretty_table(bus, header["bus"], screen_size = (-1,-1), alignment = [:r,:r,:r,:r,:r,:r],
            highlighters = h1, columns_width = [6, 18, 18, 18, 18, 18],
            formatter = ft_printf(["%1.0f","%1.4f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:6)))

        sum_data = Any["Sum" sum(bus[:, 3:6], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [27, 18, 18, 18, 18],
            alignment=[:l,:r,:r,:r,:r], formatter = ft_printf(["%-s","%15.2f","%11.2f","%11.2f","%13.2f"], collect(1:5)))
    end

    ################## DC Flow Display ##################
    branch = fill(0.0, Nbranch, 5)
    for i = 1:Nbranch
        branch[i, 1] = system.branch[i, 1]
        branch[i, 2] = system.branch[i, 2]
        branch[i, 3] = system.branch[i, 3]
        branch[i, 4] = system.baseMVA * system.branch[i, 4]
        branch[i, 5] = -branch[i, 4]
    end
    if settings.flow
        println("")
        pretty_table(branch, header["branch"], screen_size = (-1,-1), columns_width = [6, 8, 8, 18, 18],
        alignment=[:r,:r,:r,:r,:r], formatter = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ################## DC Generator Display ##################
    generator = fill(0.0, Ngen, 2)
    for i = 1:Ngen
        generator[i, 1] = system.generator[i, 1]
        generator[i, 2] = system.baseMVA * system.generator[i, 2]
    end
    if settings.generator
        println("")
        pretty_table(generator, header["generator"], screen_size = (-1,-1), alignment=[:r,:r],
            formatter = ft_printf(["%1.0f","%1.4f"], collect(1:2)))
    end

    if !isempty(settings.save)
        dict = Dict("bus" => bus, "branch" => branch, "generator" => generator)
        savedata(dict; info = info, group = header["group"], header = header, path = settings.save)
    end

    return bus, branch, generator
end


##############################################
#  AC dower flow results and call save data  #
##############################################
function results_flowac(settings, system, limit, Nbus, Nbranch, Ngen, slack, Vc, algtime, info)
    println(string("  Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.package, "src/system/header.h5"), "/flowac")

    ################## AC Limit Display ##################
    if settings.reactive[1]
        min = findall(x -> x == 2, limit)
        max = findall(x -> x == 3, limit)
        println("")
        if !isempty(min)
            println("  Generators that did not satisfy lower reactive power limits:")
            Nl = length(min)
            table = ["Bus" system.generator[min, 1]'; "Generator" min']
            pretty_table(table,
            noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
            formatter = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
            println("")
        end
        if !isempty(max)
            println("  Generators that did not satisfy upper reactive power limits:")
            Nl = length(max)
            table = ["Bus" system.generator[max, 1]'; "Generator" max']
            pretty_table(table,
            noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
            formatter = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
        end
    end

    ################## AC Main Display ##################
    bus = fill(0.0, Nbus, 11)
    for i = 1:Nbus
        bus[i, 1] = system.bus[i, 1]
        bus[i, 2] = abs(Vc[i])
        bus[i, 3] = 180 * angle(Vc[i]) / pi
        bus[i, 4] = system.baseMVA * system.bus[i, 12]
        bus[i, 5] = system.baseMVA * system.bus[i, 13]
        bus[i, 6] = system.baseMVA * system.bus[i, 10]
        bus[i, 7] = system.baseMVA *  system.bus[i, 11]
        bus[i, 8] = system.bus[i, 3]
        bus[i, 9] = system.bus[i, 4]
        bus[i, 10] = system.baseMVA *  system.bus[i, 5]
        bus[i, 11] = system.baseMVA *  system.bus[i, 6]
    end

    if settings.main
        h1 = Highlighter((data, i, j)-> (i == slack), background = :red)
        println("")
        pretty_table(bus, header["bus"],
             screen_size = (-1,-1), highlighters = h1, columns_width = [6, 16, 12, 17, 21, 17, 21, 17, 21, 17, 21],
             alignment = repeat([Symbol(:r)], outer = 11),
             formatter = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:11)))
        sum_data = Any["Sum" sum(bus[:, 4:11], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r,:r,:r,:r,:r], columns_width = [40, 17, 21, 17, 21, 17, 21, 17, 21],
            formatter = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f","%11.2f","%15.2f","%13.2f","%15.2f"], collect(1:9)))
    end

    ################## AC Flow Display ##################
    branch = fill(0.0, Nbranch, 10)
    for i = 1:Nbranch
        branch[i, 1] = system.branch[i, 1]
        branch[i, 2] = system.branch[i, 2]
        branch[i, 3] = system.branch[i, 3]
        branch[i, 4] = system.baseMVA * system.branch[i, 8]
        branch[i, 5] = system.baseMVA * system.branch[i, 9]
        branch[i, 6] = system.baseMVA * system.branch[i, 10]
        branch[i, 7] = system.baseMVA * system.branch[i, 11]
        branch[i, 8] = system.baseMVA * system.branch[i, 12]
        branch[i, 9] = system.baseMVA * system.branch[i, 13]
        branch[i, 10] = system.baseMVA * system.branch[i, 14]
    end

    if settings.flow
        println("")
        pretty_table(branch, header["branch"],
             screen_size = (-1,-1), columns_width = [6, 8, 8, 17, 21, 17, 21, 21, 17, 21],
             alignment=[:r,:r,:r,:r,:r,:r,:r,:r,:r,:r],
             formatter = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(branch[:, 7:9], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
                    formatter = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ################## AC Generator Display ##################
    generator = fill(0.0, Ngen, 3)
    for i = 1:Ngen
        generator[i, 1] = system.generator[i, 1]
        generator[i, 2] = system.baseMVA * system.generator[i, 2]
        generator[i, 3] = system.baseMVA * system.generator[i, 3]
    end

    if settings.generator
        println("")
        pretty_table(generator, header["generator"],
            screen_size = (-1,-1), alignment=[:r,:r,:r],
            formatter = ft_printf(["%1.0f", "%1.4f", "%1.4f"], collect(1:3)))
    end

    ################## Export Data ##################
    if !isempty(settings.save)
        dict = Dict("bus" => bus, "branch" => branch, "generator" => generator)
        savedata(dict; info = info, group = header["group"], header = header, path = settings.save)
    end

    return bus, [branch system.branch[:, 4:7]], generator
end


############################
#  Power system info data  #
############################
function info_flow(branch, bus, generator, info, settings, data, Nbranch, Nbus, Ngen)
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
    for i = 1:Nbranch
        if branch[i, 12] == 1 && (branch[i, 10] != 0 || branch[i, 11] != 0)
            Ntrain += 1
        end
        if branch[i, 10] != 0 || branch[i, 11] != 0
            Ntra += 1
        end
    end
    info = ["Reference" string(reference) "";
            "Data" string(data) "";
            "Grid" string(grid) "";
            "" "" "";
            "Bus" string(Nbus) "";
            "PV bus" string(length(unique(generator[:, 1]))) "";
            "PQ bus" string(Nbus - length(unique(generator[:, 1])) - 1) "";
            "Shunt element" string(count(x->x != 0, abs.(bus[:, 5]) + abs.(bus[:, 6]))) "";
            "Generator" string(Ngen) string(trunc(Int, sum(generator[:, 8])), " in-service");
            "Branch" string(Nbranch) string(trunc(Int, sum(branch[:, 12])), " in-service");
            "Transformer" string(Ntra) string(Ntrain, " in-service")]

    return info
end


###############################################
#  Measurements info data and call save data  #
###############################################
function info_generator(system, settings, measurement, names, info, Nbus, Nbranch, Ngen)
    setkeys = keys(settings.set)
    varkeys = keys(settings.variance)

    ################## PMU Set ##################
    info = [info; "" "" ""]
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
        header = h5read(joinpath(system.package, "src/system/header.h5"), "/measurement")
        header["basePower"] = permutedims(header["basePower"])

        group = ["pmuVoltage"; "pmuCurrent"; "legacyFlow"; "legacyCurrent"; "legacyInjection"; "legacyVoltage"]
        for (k, i) in enumerate(group)
            if !any(i .== keys(measurement))
                deleteat!(group, k)
            end
        end
        group = [group; "bus"; "generator"; "branch"; "basePower"]

        push!(measurement, "bus" => system.bus)
        push!(measurement, "generator" => system.generator)
        push!(measurement, "branch" => system.branch)
        push!(measurement, "basePower" => system.baseMVA)

        savedata(measurement; group = group, header = header, path = settings.path, info = info)
    end

    return info
end
