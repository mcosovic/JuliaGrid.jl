########################
#  Power Flow Results  #
########################

#-------------------------------------------------------------------------------
function results_flowdc(settings, system, Nbus, Nbranch, Ngen, Ti, slack, algtime, info)
    println(string("  Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.package, "src/system/header.h5"), "/flowdc")

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
        group = ["bus", "branch", "generator"]
        savedata(bus, branch, generator; info = info, group = group, header = header, path = settings.save)
    end

    return bus, branch, generator
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function results_flowac(settings, system, limit, Nbus, Nbranch, Ngen, slack, Vc, algtime, info)
    println(string("  Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = h5read(joinpath(system.package, "src/system/header.h5"), "/flowac")

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

    if !isempty(settings.save)
        group = ["bus", "branch", "generator"]
        savedata(bus, branch, generator; info = info, group = group, header = header, path = settings.save)
    end

    return bus, [branch system.branch[:, 4:7]], generator
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function results_generator(system, settings, Nbranch, Nbus, measurements)
    for i = 1:(2 * Nbranch)
        measurements["LegFlow"][i, 4] = measurements["LegFlow"][i, 10] + measurements["LegFlow"][i, 5]^(1/2) * randn(1)[1]
        measurements["LegFlow"][i, 7] = measurements["LegFlow"][i, 11] + measurements["LegFlow"][i, 8]^(1/2) * randn(1)[1]
        measurements["LegCurrent"][i, 4] = measurements["LegCurrent"][i, 7] + measurements["LegCurrent"][i, 5]^(1/2) * randn(1)[1]
        measurements["PmuCurrent"][i, 4] = measurements["PmuCurrent"][i, 10] + measurements["PmuCurrent"][i, 5]^(1/2) * randn(1)[1]
        measurements["PmuCurrent"][i, 7] = measurements["PmuCurrent"][i, 11] + measurements["PmuCurrent"][i, 8]^(1/2) * randn(1)[1]
    end

    for i = 1:Nbus
        measurements["LegInjection"][i, 2] = measurements["LegInjection"][i, 8] + measurements["LegInjection"][i, 3]^(1/2) * randn(1)[1]
        measurements["LegInjection"][i, 5] = measurements["LegInjection"][i, 9] + measurements["LegInjection"][i, 6]^(1/2) * randn(1)[1]
        measurements["LegVoltage"][i, 2] = measurements["LegVoltage"][i, 5] + measurements["LegVoltage"][i, 3]^(1/2) * randn(1)[1]
        measurements["PmuVoltage"][i, 2] = measurements["PmuVoltage"][i, 8] + measurements["PmuVoltage"][i, 3]^(1/2) * randn(1)[1]
        measurements["PmuVoltage"][i, 5] = measurements["PmuVoltage"][i, 9] + measurements["PmuVoltage"][i, 6]^(1/2) * randn(1)[1]
    end

    header1, header2, group = generator_headers()
    system = loadsystem([system.path])
    infosys = [read_data["info"]; "" "" ""]

    if settings.set["legacy"][1] == "all"
        push!(infosys, ["Legacy set setting" "all measurements in-service" ""])
    end
    if settings.set["legacy"][1] == "redundancy"
        push!(infosys, ["Legacy set setting" "redundancy" string(settings.set["legacy"][2])])
    end
    if settings.set["legacy"][1] == "onebyone"
        push!(infosys, ["Legacy set setting" "measurements by type" "" ])
    end
    Pij_in = trunc(Int, sum(measurements["LegFlow"][:, 6]))
    Qij_in = trunc(Int, sum(measurements["LegFlow"][:, 9]))
    Iij_in = trunc(Int, sum(measurements["LegCurrent"][:, 6]))
    Pi_in = trunc(Int, sum(measurements["LegInjection"][:, 4]))
    Qi_in = trunc(Int, sum(measurements["LegInjection"][:, 7]))
    Vi_in = trunc(Int, sum(measurements["LegVoltage"][:, 4]))
    mstat = ["Active power flow measurements" string(Pij_in, " in-service") string(2 * Nbranch - Pij_in, " out-service");
             "Reactive power flow measurements" string(Qij_in, " in-service") string(2 * Nbranch - Qij_in, " out-service");
             "Current magnitude measurements" string(Iij_in, " in-service") string(2 * Nbranch - Iij_in, " out-service");
             "Active power injection measurements" string(Pi_in, " in-service") string(Nbus - Pi_in, " out-service");
             "Reactive power injection measurements" string(Qi_in, " in-service") string(Nbus - Qi_in, " out-service");
             "Voltage magnitude measurements" string(Vi_in, " in-service") string(Nbus - Vi_in, " out-service");
             ""]
    infosys = [infosys; mstat]

    if settings.set["pmu"][1] == "all"
        push!(infosys, ["PMU set setting" "all measurements in-service" ""])
    end
    if settings.set["pmu"][1] == "redundancy"
        push!(infosys, ["PMU set setting" "redundancy" string(settings.set["pmu"][2])])
    end
    if settings.set["pmu"][1] == "onebyone"
        push!(infosys, ["PMU set setting" "measurements by type" ""])
    end
    if settings.set["pmu"][1] == "device"
        push!(infosys, ["PMU set setting" "devices in-service" string(settings.set["pmu"][2])])
    end
    if settings.set["pmu"][1] == "optimal"
        push!(infosys, ["PMU set setting" "Optimal placement" ""])
    end
    Iij_in = trunc(Int, sum(measurements["PmuCurrent"][:, 6]))
    Dij_in = trunc(Int, sum(measurements["PmuCurrent"][:, 9]))
    Vi_in = trunc(Int, sum(measurements["PmuVoltage"][:, 4]))
    Ti_in = trunc(Int, sum(measurements["PmuVoltage"][:, 7]))
    pstat = ["Current magnitude measurements" string(Iij_in, " in-service") string(2 * Nbranch - Iij_in, " out-service");
             "Current angle measurements" string(Dij_in, " in-service") string(2 * Nbranch - Dij_in, " out-service]");
             "Voltage magnitude measurements" string(Vi_in, " in-service") string(Nbus - Vi_in, " out-service");
             "Voltage angle measurements" string(Ti_in, " in-service") string(Nbus - Ti_in, " out-service");
             ""]
    infosys = [infosys; pstat]

    if settings.variance["legacy"][1] == "all"
        push!(infosys, ["Legacy variance setting" "all" string(settings.variance["legacy"][2])])
    end
    if settings.variance["legacy"][1] == "random"
        push!(infosys, ["Legacy variance setting" "randomized variances within limits" string(settings.variance["legacy"][2], ", ", settings.variance["legacy"][3])])
    end
    if settings.variance["legacy"][1] == "onebyone"
        push!(infosys, ["Legacy variance setting:" "variance by type" ""])
    end
    Pijex = extrema(measurements["LegFlow"][:, 5])
    Qijex = extrema(measurements["LegFlow"][:, 8])
    Iijex = extrema(measurements["LegCurrent"][:, 5])
    Piex = extrema(measurements["LegInjection"][:, 3])
    Qiex = extrema(measurements["LegInjection"][:, 6])
    Viex = extrema(measurements["LegVoltage"][:, 3])
    mstat = ["Active power flow measurements" string(Pijex[1], " minimum") string(Pijex[2], " maximum");
             "Reactive power flow measurements" string(Qijex[1], " minimum") string(Qijex[2], " maximum");
             "Current magnitude measurements" string(Iijex[1], " minimum") string(Iijex[2], " maximum");
             "Active power injection measurements" string(Piex[1], " minimum") string(Piex[2], " maximum");
             "Reactive power injection measurements" string(Qiex[1], " minimum") string(Qiex[2], " maximum");
             "Voltage magnitude measurements" string(Viex[1], " minimum") string(Viex[2], " maximum");
             ""]
    infosys = [infosys; mstat]

    if settings.variance["pmu"][1] == "all"
        push!(infosys, ["PMU variance setting" "all" string(settings.variance["pmu"][2])])
    end
    if settings.variance["pmu"][1] == "random"
        push!(infosys, ["PMU variance setting" "randomized variances within limits" string(settings.variance["pmu"][2], ", ", settings.variance["pmu"][3])])
    end
    if settings.variance["pmu"][1] == "onebyone"
        push!(infosys, ["PMU variance setting" "variance by type" ""])
    end
    Iijex = extrema(measurements["PmuCurrent"][:, 5])
    Dijex = extrema(measurements["PmuCurrent"][:, 8])
    Viex = extrema(measurements["PmuVoltage"][:, 3])
    Tiex = extrema(measurements["PmuVoltage"][:, 3])
    pstat = ["Current magnitude measurements" string(Iijex[1], " minimum") string(Iijex[2], " maximum");
             "Current angle measurements" string(Dijex[1], " minimum") string(Dijex[2], " maximum");
             "Voltage magnitude measurements" string(Viex[1], " minimum") string(Viex[2], " maximum");
             "Voltage angle measurements" string(Tiex[1], " minimum") string(Tiex[2], " maximum")]
    infosys = [infosys; pstat]

    if isempty(settings.path)
        package_dir = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."))
        path = joinpath(package_dir, string("new_juliagrid", system.extension))
    else
        path = settings.path
    end

    savedata(measurements["PmuVoltage"], measurements["PmuCurrent"], measurements["LegFlow"], measurements["LegCurrent"],
        measurements["LegInjection"], measurements["LegVoltage"], system.bus, system.generator, system.branch, system.baseMVA;
        group = group, header1 = header1, header2 = header2, path = path, info = infosys)
end
#-------------------------------------------------------------------------------
