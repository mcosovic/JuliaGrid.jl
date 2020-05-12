### Struct variables
struct PowerFlowDC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    generation::Array{Float64,2}
end

struct PowerFlowAC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    generation::Array{Float64,2}
    iterations::Int64
end

struct StateEstimationDC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    estimate::Array{Float64,2}
    error::Array{Float64,1}
    baddata::Array{Float64,2}
    observability::Array{Array{Int64,1},1}
end

### DC power flow results
@inbounds function results_flowdc(system, num, settings, Ti, Pinj, Pbus, Pij, Pgen, slack, algtime)
    dheader = dcpfheader(); pheader = psheader()
    header = merge(dheader, pheader)

    ########## DC main results ##########
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    main = fill(0.0, num.Nbus, 6)
    for i = 1:num.Nbus
        main[i, 1] = system.bus[i, 1]
        main[i, 2] = 180 * Ti[i] / pi
        main[i, 3] = system.basePower * Pinj[i]
        main[i, 4] = system.basePower * Pbus[i]
        main[i, 5] = system.bus[i, 3]
        main[i, 6] = system.bus[i, 5]
    end
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("\n Main Data Display")
        pretty_table(main, header[:main], screen_size = (-1,-1), alignment = [:r,:r,:r,:r,:r,:r],
            highlighters = h1, columns_width = [7, 18, 18, 18, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:6)))

        pretty_table(["Sum" sum(main[:, 3:6], dims = 1)], noheader = true, screen_size = (-1,-1), columns_width = [28, 18, 18, 18, 18],
            alignment = [:l,:r,:r,:r,:r], formatters = ft_printf(["%-s","%15.2f","%11.2f","%11.2f","%13.2f"], collect(1:5)))
    end

    ########## DC flow results ##########
    flow =  fill(0.0, num.Nbranch, 5)
    for i = 1:num.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
        flow[i, 4] = system.basePower * Pij[i]
        flow[i, 5] = -system.basePower * Pij[i]
    end
    if settings.flow
        println("\n Flow Data Display")
        pretty_table(flow, header[:flow], screen_size = (-1,-1), columns_width = [7, 8, 8, 18, 18],
            alignment = [:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ########## DC generator results ##########
    gen = 0; gent = 0
    if num.Ngen != 0
        generation = fill(0.0, num.Ngen, 2)
        gen = 2; gent = 1
    else
        generation = Array{Float64}(undef, 0, 0)
    end
    for i = 1:num.Ngen
        generation[i, 1] = system.generator[i, 1]
        generation[i, 2] = system.basePower * Pgen[i]
    end
    if settings.generation
        println("\n Generation Data Display")
        pretty_table(generation, header[:generation], screen_size = (-1,-1), alignment=[:r,:r],
            formatters = ft_printf(["%1.0f","%1.4f"], collect(1:2)))
    end

    group = (main = 1, flow = 1, generation = gent, bus = 2, branch = 2, generator = gen, basePower = 2)

    return PowerFlowDC(main, flow, generation), header, group
end


### AC power flow results
@inbounds function results_flowac(system, num, settings, Pinj, Qinj, Pbus, Qbus, Pshunt, Qshunt, Imij, Iaij, Imji, Iaji,
    Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Pgen, Qgen, limit, slack, Vc, algtime, iter)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    aheader = acpfheader(); pheader = psheader()
    header = merge(aheader, pheader)

    ########## AC limit results ##########
    if settings.reactive[1]
        min = findall(x -> x == 2, limit)
        max = findall(x -> x == 3, limit)
        if !isempty(min)
            println("\n Generators that Violate Lower Reactive Power Limits")
            Nl = length(min)
            pretty_table(["Bus" system.generator[min, 1]'; "Generator" min'],
                noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
                formatters = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
        end
        if !isempty(max)
            println("\n Generators that Violate Uppert Reactive Power Limits")
            Nl = length(max)
            pretty_table(["Bus" system.generator[max, 1]'; "Generator" max'],
                noheader = true, alignment = repeat([Symbol(:r)], outer = Nl + 1),
                formatters = ft_printf(vcat("%s", repeat(["%1.0f"], outer = Nl)), collect(1:1 + Nl)))
        end
    end

    ########## AC main results ##########
    main = fill(0.0, num.Nbus, 11)
    for i = 1:num.Nbus
        main[i, 1] = system.bus[i, 1]
        main[i, 2] = abs(Vc[i])
        main[i, 3] = 180 * angle(Vc[i]) / pi
        main[i, 4] = system.basePower * Pinj[i]
        main[i, 5] = system.basePower * Qinj[i]
        main[i, 6] = system.basePower * Pbus[i]
        main[i, 7] = system.basePower * Qbus[i]
        main[i, 8] = system.bus[i, 3]
        main[i, 9] = system.bus[i, 4]
        main[i, 10] = system.basePower * Pshunt[i]
        main[i, 11] = system.basePower * Qshunt[i]
    end

    if settings.main
        h1 = Highlighter((data, i, j)-> (i == slack), background = :red)
        println("\n Main Data Display")
        pretty_table(main, header[:main],
            screen_size = (-1,-1), highlighters = h1, columns_width = [7, 16, 12, 17, 21, 17, 21, 17, 21, 17, 21],
            alignment = repeat([Symbol(:r)], outer = 11),
            formatters = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:11)))
        sum_data = Any["Sum" sum(main[:, 4:11], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r,:r,:r,:r,:r], columns_width = [41, 17, 21, 17, 21, 17, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f","%11.2f","%15.2f","%13.2f","%15.2f"], collect(1:9)))
    end

    ########## AC flow results ##########
    flow =  fill(0.0, num.Nbranch, 14)
    for i = 1:num.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
        flow[i, 4] = system.basePower * Pij[i]
        flow[i, 5] = system.basePower * Qij[i]
        flow[i, 6] = system.basePower * Pji[i]
        flow[i, 7] = system.basePower * Qji[i]
        flow[i, 8] = system.basePower * Qcharging[i]
        flow[i, 9] = system.basePower * Ploss[i]
        flow[i, 10] = system.basePower * Qloss[i]
        flow[i, 11] = Imij[i]
        flow[i, 12] = 180 * Iaij[i] / pi
        flow[i, 13] = Imji[i]
        flow[i, 14] = 180 * Iaji[i] / pi
    end

    if settings.flow
        println("\n Flow Data Display")
        pretty_table(flow[:,1:10], header[:flow][:,1:10],
            screen_size = (-1,-1), columns_width = [6, 8, 8, 17, 21, 17, 21, 21, 17, 21],
            alignment=[:r,:r,:r,:r,:r,:r,:r,:r,:r,:r],
            formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(flow[:, 7:9], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ########## AC generator results ##########
    gen = 0; gent = 0
    if num.Ngen != 0
        generation = fill(0.0, num.Ngen, 3)
        gen = 2; gent = 1
    else
        generation = Array{Float64}(undef, 0, 0)
    end
    for i = 1:num.Ngen
        generation[i, 1] = system.generator[i, 1]
        generation[i, 2] = system.basePower * Pgen[i]
        generation[i, 3] = system.basePower * Qgen[i]
    end

    if settings.generation
        println("\n Generation Data Display")
        pretty_table(generation, header[:generation],
            screen_size = (-1,-1), alignment=[:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%1.4f", "%1.4f"], collect(1:3)))
    end

    group = (main = 1, flow = 1, generation = gent, bus = 2, branch = 2, generator = gen, basePower = 2)

    return PowerFlowAC(main, flow, generation, iter), header, group
end


### Power system info data
@inbounds function infogrid(bus, branch, generator, info, dataname, Nbranch, Nbus, Ngen)
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
    for i = 1:Nbranch
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

    info = [["Reference" string(reference) ""]
            ["Data" string(dataname) ""]
            ["Grid" string(grid) ""]
            ["" "" ""]
            ["Bus" string(Nbus) ""]
            ["PV bus" string(pv) ""]
            ["PQ bus" string(Nbus - pv - 1) ""]
            ["Shunt element" string(count(x->x != 0, abs.(bus[:, 5]) + abs.(bus[:, 6]))) ""]
            ["Generator" string(Ngen) "$(trunc(Int, sum(generator[:, 8]))) in-service"]
            ["Branch" string(Nbranch) "$(trunc(Int, sum(branch[:, 12]))) in-service"]
            ["Transformer" string(Ntra) "$Ntrain in-service"]]

    return info
end


### Measurements info data
@inbounds function infogenerator(system, measurements, settings, info, names)
    setkeys = keys(settings.set)
    varkeys = keys(settings.variance)

    ########## PMU set ##########
    info = [info; ["" "" ""]]
    if :pmucomplete in setkeys
        info = [info; ["PMU set setting" "complete measurement set in-service" ""]]
    elseif :pmuredundancy in setkeys
        info = [info; ["PMU set setting" "redundancy" string(settings.set[:pmuredundancy])]]
    elseif :pmudevice in setkeys
        info = [info; ["PMU set setting" "devices in-services" string(settings.set[:pmudevice])]]
    elseif :pmuoptimal in setkeys
        info = [info; ["PMU set setting" "optimal placement" ""]]
    elseif :pmuVoltage in setkeys || :pmuCurrent in setkeys
        info = [info; ["PMU set setting" "measurements by type adjust in-service" ""]]
    else
        info = [info; ["PMU set setting" "" ""]]
    end
    readps = (pmuVoltage = [4, 7], pmuCurrent = [6, 9])
    titleps = (pmuVoltage = ["Bus voltage magnitude", "Bus voltage angle"], pmuCurrent = ["Branch current magnitude", "Branch current angle"])

    for i in names[:pmu]
        cnt = 1
        for k in readps[i]
            on = trunc(Int, sum(getfield(measurements, i)[:, k]))
            info = [info; [titleps[i][cnt] "$on in-service" "$(size(getfield(measurements, i), 1) - on) out-service"]]
            cnt += 1
        end
    end

    ########## Legacy set ##########
    info = [info; ["" "" ""]]
    if :legacycomplete in setkeys
        info = [info; ["Legacy set setting" "complete measurement set in-service" ""]]
    elseif :legacyredundancy in setkeys
        info = [info; ["Legacy set setting" "redundancy" string(settings.set[:legacyredundancy])]]
    elseif :legacyFlow in setkeys || :legacyCurrent in setkeys || :legacyInjection in setkeys || :legacyVoltage in setkeys
        info = [info; ["Legacy set setting" "measurements by type adjust in-service" ""]]
    else
        info = [info; ["Legacy set setting" "" ""]]
    end
    readls = (legacyFlow = [6, 9], legacyCurrent = [6], legacyInjection = [4, 7], legacyVoltage = [4])
    titlels = (legacyFlow = ["Active power flow", "Reactive power flow"], legacyCurrent = ["Branch current magnitude"],
            legacyInjection = ["Active power injection", "Reactive power injection"], legacyVoltage = ["Bus voltage magnitude"])
    for i in names[:legacy]
        cnt = 1
        for k in readls[i]
            on = trunc(Int, sum(getfield(measurements, i)[:, k]))
            info = [info; [titlels[i][cnt] "$on in-service" "$(size(getfield(measurements, i), 1) - on) out-service"]]
            cnt += 1
        end
    end

    ########## PMU variance ##########
    info = [info; ["" "" ""]]
    if :pmucomplete in varkeys
        info = [info; ["PMU variance setting" "fixed-value variance over all measurements" string(settings.variance[:pmucomplete])]]
    elseif :pmurandom in varkeys
        info = [info; ["PMU variance setting" "randomized variances within limits" "$(settings.variance[:pmurandom][1]), $(settings.variance[:pmurandom][2])"]]
    elseif :pmuVoltage in varkeys || :pmuCurrent in varkeys
        info = [info; ["PMU variance setting" "variances by measurement type" ""]]
    else
        info = [info; ["PMU variance set setting" "" ""]]
    end
    readpv = (pmuVoltage = [3, 6], pmuCurrent = [5, 8])
    titlepv = (pmuVoltage = ["Bus voltage magnitude", "Bus voltage angle"], pmuCurrent = ["Branch current magnitude", "Branch current angle"])
    for i in names[:pmu]
        cnt = 1
        for k in readpv[i]
            on = extrema(getfield(measurements, i)[:, k])
            info = [info; [titlepv[i][cnt] "$(on[1]) minimum" "$(on[2]) maximum"]]
            cnt += 1
        end
    end

    ########## Legacy variance ##########
    info = [info; ["" "" ""]]
    if :legacycomplete in varkeys
        info = [info; ["Legacy variance setting" "fixed-value variance over all measurements" string(settings.variance[:legacycomplete])]]
    elseif :legacyrandom in varkeys
        info = [info; ["Legacy variance setting" "randomized variances within limits" string(settings.variance[:legacyrandom][1], ", ", settings.variance[:legacyrandom][2])]]
    elseif :legacyFlow in varkeys || :legacyCurrent in varkeys || :legacyInjection in varkeys || :legacyVoltage in varkeys
        info = [info; ["Legacy variance setting" "variances by measurement type" ""]]
    else
        info = [info; ["Legacy variance set setting" "" ""]]
    end
    readlv = (legacyFlow = [5, 8], legacyCurrent = [5], legacyInjection = [3, 6], legacyVoltage = [3])
    titlelv = (legacyFlow = ["Active power flow", "Reactive power flow"], legacyCurrent = ["Branch current magnitude"],
               legacyInjection = ["Active power injection", "Reactive power injection"], legacyVoltage = ["Bus voltage magnitude"])
    for i in names[:legacy]
        cnt = 1
        for k in readlv[i]
            on = extrema(getfield(measurements, i)[:, k])
            info = [info; [titlelv[i][cnt] "$(on[1]) minimum" "$(on[2]) maximum"]]
            cnt += 1
        end
    end

    return info
end


### DC state estimation results
function results_estimationdc(system, numsys, measurements, num, settings, algtime, slack, Ti, Pij, Pinj,
    Nmeasur, branchPij, busPi, busTi, onPij, onPi, onTi, savebad, Npseudo, islands, newnumbering)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = dcseheader()

    dimension = [0, 0, 0]
    exact = false
    if size(measurements.pmuVoltage, 2) == 9 && size(measurements.legacyFlow, 2) == 11 && size(measurements.legacyInjection, 2) == 9
        exact = true
        dimension = [6, 6]
    else
        dimension = [4, 3]
    end


    ########## DC main results ##########
    main = fill(0.0, numsys.Nbus, 3)
    for i = 1:numsys.Nbus
        main[i, 1] = system.bus[i, 1]
        main[i, 2] = 180 * Ti[i] / pi
        main[i, 3] = Pinj[i] * system.basePower
    end

    ########## DC flow results ##########
    flow = fill(0.0, numsys.Nbranch, 5)
    for i = 1:numsys.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
        flow[i, 4] = Pij[i] * system.basePower
        flow[i, 5] = -Pij[i] * system.basePower
    end

    ########## DC estimate and error results ##########
    estimate = zeros(Nmeasur, dimension[1])
    label = Array{String}(undef, Nmeasur, 3)
    code = zeros(Nmeasur, 4)
    error = zeros(dimension[2])
    Nmeasur = Nmeasur - size(savebad, 1) - Npseudo
    idx = 1; scaleTi = 180 / pi
    for (i, on) in enumerate(onPij)
        if on != 0
            label[idx, 1] = "in-service"
            label[idx, 2] = "Legacy"
            label[idx, 3] = "P$(trunc(Int, measurements.legacyFlow[i, 2])),$(trunc(Int, measurements.legacyFlow[i, 3])) [MW]"
            code[idx, 1] = 1.0
            code[idx, 2] = 1.0
            code[idx, 3] = 1.0
            code[idx, 4] = i
            if idx in savebad[:, 1]
                label[idx, 1] = "bad-measurement"
                code[idx, 1] = 2.0
            end
            if on == 2
                label[idx, 1] = "pseudo-measurement"
                code[idx, 1] = 3.0
                onPij[i] = 1
            end

            estimate[idx, 1] = measurements.legacyFlow[i, 4] * system.basePower
            estimate[idx, 2] = measurements.legacyFlow[i, 5] * system.basePower
            k = branchPij[i]
            if measurements.legacyFlow[i, 2] == system.branch[k, 2] && measurements.legacyFlow[i, 3] == system.branch[k, 3]
                estimate[idx, 3] = flow[k, 4]
            else
                estimate[idx, 3] = flow[k, 5]
            end
            estimate[idx, 4] = abs(estimate[idx, 1] - estimate[idx, 3])

            if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                error[1] += estimate[idx, 4] / (Nmeasur * system.basePower)
                error[2] += estimate[idx, 4]^2 / (Nmeasur * system.basePower^2)
                error[3] += estimate[idx, 4]^2 / (measurements.legacyFlow[i, 5] * system.basePower^2)
            end

            if exact
                estimate[idx, 5] = measurements.legacyFlow[i, 10] * system.basePower
                estimate[idx, 6] = abs(estimate[idx, 3] - estimate[idx, 5])

                if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                    error[4] += estimate[idx, 6] / (Nmeasur * system.basePower)
                    error[5] += estimate[idx, 6]^2 / (Nmeasur * system.basePower^2)
                    error[6] += estimate[idx, 6]^2 / (measurements.legacyFlow[i, 5] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onPi)
        if on != 0
            label[idx, 1] = "in-service"
            label[idx, 2] = "Legacy"
            label[idx, 3] = "P$(trunc(Int, measurements.legacyInjection[i, 1])) [MW]"
            code[idx, 1] = 1.0
            code[idx, 2] = 1.0
            code[idx, 3] = 4.0
            code[idx, 4] = i
            if idx in savebad[:, 1]
                label[idx, 1] = "bad-measurement"
                code[idx, 1] = 2.0
            end
            if on == 2
                label[idx, 1] = "pseudo-measurement"
                code[idx, 1] = 3.0
                onPi[i] = 1
            end

            estimate[idx, 1] = measurements.legacyInjection[i, 2] * system.basePower
            estimate[idx, 2] = measurements.legacyInjection[i, 3] * system.basePower
            estimate[idx, 3] = main[busPi[i], 3]
            estimate[idx, 4] = abs(estimate[idx, 1] - estimate[idx, 3])

            if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                error[1] += estimate[idx, 4] / (Nmeasur * system.basePower)
                error[2] += estimate[idx, 4]^2 / (Nmeasur * system.basePower^2)
                error[3] += estimate[idx, 4]^2 / (measurements.legacyInjection[i, 3] * system.basePower^2)
            end

            if exact
                estimate[idx, 5] = measurements.legacyInjection[i, 8] * system.basePower
                estimate[idx, 6] = abs(estimate[idx, 3] - estimate[idx, 5])

                if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                    error[4] += estimate[idx, 6] / (Nmeasur * system.basePower)
                    error[5] += estimate[idx, 6]^2 / (Nmeasur * system.basePower^2)
                    error[6] += estimate[idx, 6]^2 / (measurements.legacyInjection[i, 3] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onTi)
        if on != 0
            label[idx, 1] = "in-service"
            label[idx, 2] = "PMU"
            label[idx, 3] = "T$(trunc(Int, measurements.pmuVoltage[i, 1])) [deg]"
            code[idx, 1] = 1.0
            code[idx, 2] = 2.0
            code[idx, 3] = 8.0
            code[idx, 4] = i
            if idx in savebad[:, 1]
                label[idx, 1] = "bad-measurement"
                code[idx, 1] = 2.0
            end
            if on == 2
                label[idx, 1] = "pseudo-measurement"
                code[idx, 1] = 3.0
                onTi[i] = 1
            end

            estimate[idx, 1] = 180 * measurements.pmuVoltage[i, 5] / pi
            estimate[idx, 2] = 180 * measurements.pmuVoltage[i, 6] / pi
            estimate[idx, 3] = main[busTi[i], 2]
            estimate[idx, 4] = abs(estimate[idx, 1] - estimate[idx, 3])

            if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                error[1] += estimate[idx, 4] / (Nmeasur * scaleTi)
                error[2] += estimate[idx, 4]^2 / (Nmeasur * scaleTi^2)
                error[3] += estimate[idx, 4]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
            end

            if exact
                estimate[idx, 5] = 180 * measurements.pmuVoltage[i, 9] / pi
                estimate[idx, 6] = abs(estimate[idx, 3] - estimate[idx, 5])

                if code[idx, 1] != 2.0 && code[idx, 1] != 3.0
                    error[4] += estimate[idx, 6] / (Nmeasur * scaleTi)
                    error[5] += estimate[idx, 6]^2 / (Nmeasur * scaleTi^2)
                    error[6] += estimate[idx, 6]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
                end
            end
            idx += 1
        end
    end
    error[[2 5]] = sqrt.(error[[2 5]])

    ########## Observability display ##########
    idxp = findall(x->x==3, code[:, 1])
    pseudo = [label[idxp, 2:3] code[idxp, 4] estimate[idxp, 1:2]]
    if settings.observe[:observe] == 1 && Npseudo != 0
        if newnumbering
            for k in islands
                for i in k
                    islands[k][i] = system.bus[i, 1]
                end
            end
        end
        Nisland = size(islands, 1)
        numer = collect(1:Nisland)
        islanddisp = copy(islands)
        if Nisland > Npseudo
            pseudo = [pseudo; repeat([""], Nisland - Npseudo, 5)]
        elseif Nisland < Npseudo
            islanddisp = [islanddisp; repeat([[""]], Npseudo - Nisland, 1)]
            numer = [numer; repeat([""], Npseudo - Nisland)]
        end
        println("\n Observability Analysis Display")
        pretty_table([numer islands pseudo], header[:observe], alignment=[:r,:r,:r,:r,:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%-s", "%-s", "%-s", "%-s", "%1.2f", "%1.2e"], collect(1:7)))
    end

    ########## DC bad data display ##########
    pass = collect(1:size(savebad, 1))
    idxb = trunc.(Int, savebad[:,1])
    bad = [pass code[idxb, 2:4] savebad[:, 2] code[idxb, 1]]
    if settings.bad[:bad] == 1 && !isempty(savebad)
        println("\n Bad Data Analysis Display")
        pretty_table([pass label[idxb, 2:3] code[idxb, 4]  savebad[:, 2] label[idxb, 1]], header[:bad], screen_size = (-1,-1),
            columns_width = [10, 10, 18, 13, 20, 18], alignment=[:l,:l,:l,:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%-s","%-s","%1.0f","%1.4e","%-s"], collect(1:6)))
    end

    ########## DC main display ##########
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("\n Main Data Display")
        pretty_table(main, header[:main], screen_size = (-1,-1), alignment = [:r,:r,:r],
            highlighters = h1, columns_width = [6, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f"], collect(1:3)))

        sum_data = Any["Sum" sum(main[:, 3], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [27, 18],
            alignment = [:l,:r], formatters = ft_printf(["%-s","%15.2f"], [1, 2]))
    end

    ########## DC flow display ##########
    if settings.flow
        println("\n Flow Data Display")
        pretty_table(flow, header[:flow], screen_size = (-1,-1), columns_width = [6, 8, 8, 18, 18],
            alignment=[:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ########## DC Estimate display ##########
    if settings.estimate
        println("\n Estimate Data Display")
        columns_width = [18, 12, 12, 12, 12, 12, 12, 19, 12, 19]
        alignment = [:l, :l, :l, :r, :r, :r, :r, :r, :r, :r]
        formatters = ["%s", "%s", "%s", "%1.0f", "%1.2f", "%1.2e", "%1.2f", "%1.2e", "%1.2f", "%1.2e"]
        many = collect(1:10)
        head = header[:estimatedisplay]
        if !exact
            columns_width = columns_width[1:8]
            alignment = alignment[1:8]
            formatters = formatters[1:8]
            many = many[1:8]
            head = head[:, 1:8]
        end
        pretty_table([label code[:, 4] estimate], head, screen_size = (-1,-1), columns_width = columns_width,
            show_row_number = true, alignment = alignment, formatters = ft_printf((formatters), many))
    end

    ########## DC error display ##########
    if settings.error
        println("\n Error Data Display\n")
        if exact
            head = header[:errordisplay]
            err = [""; error[1:3]; ""; ""; error[4:6]]
        else
            head = header[:errordisplay][1:4, :]
            err = [""; error[1:3]]
        end
        pretty_table([head err], screen_size = (-1,-1), tf = borderless,
            noheader = true, alignment = [:l, :l, :r], formatters = ft_printf("%1.4e", 3),
            highlighters = (hl_cell( [(1,1);(6,1)], crayon"bold"), hl_col(2, crayon"dark_gray")),
            body_hlines = [1,6], body_hlines_format = Tuple('─' for _ = 1:4))
    end

    ########## Export results ##########
    pmuv = 2; pmuc = 2; legf = 2; legc = 2; legi = 2; legv = 2; gen = 3;
    if num.pmuNv == 0 pmuv = 0  end
    if num.pmuNc == 0 pmuc = 0 end
    if num.legacyNf == 0 legf = 0 end
    if num.legacyNc == 0 legc = 0 end
    if num.legacyNi == 0 legi = 0 end
    if num.legacyNv == 0  legv = 0 end
    if numsys.Ngen == 0  gen = 0 end

    group = (main = 1, flow = 1, estimate = 1, error = 1,
        pmuVoltage = pmuv, pmuCurrent = pmuc, legacyFlow = legf, legacyCurrent = legc, legacyInjection = legi, legacyVoltage = legv,
        bus = 3, branch = 3, generator = gen, basePower = 3)

    mheader = measureheader(); pheader = psheader(); headernew = merge(mheader, pheader, header)

    return StateEstimationDC(main, flow, [code estimate], error, bad, islands), headernew, group
end
