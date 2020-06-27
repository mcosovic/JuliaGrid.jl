### DC power flow results
@inbounds function results_flowdc(system, num, settings, results, slack, algtime)
    dheader = dcpfheader(); pheader = psheader()
    header = merge(dheader, pheader)

    ########## DC main display ##########
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("\n Main Data Display")
        pretty_table(results.main, header[:main], screen_size = (-1,-1), alignment = [:r,:r,:r,:r,:r,:r],
            highlighters = h1, columns_width = [7, 18, 18, 18, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:6)))

        pretty_table(["Sum" sum(results.main[:, 3:6], dims = 1)], noheader = true, screen_size = (-1,-1), columns_width = [28, 18, 18, 18, 18],
            alignment = [:l,:r,:r,:r,:r], formatters = ft_printf(["%-s","%15.2f","%11.2f","%11.2f","%13.2f"], collect(1:5)))
    end

    ########## DC flow display ##########
        if settings.flow
        println("\n Flow Data Display")
        pretty_table(results.flow, header[:flow], screen_size = (-1,-1), columns_width = [7, 8, 8, 18, 18],
            alignment = [:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ########## DC generation display ##########
    gen = 0; gent = 0
    if num.Ngen != 0
        gen = 2; gent = 1
    end

    if settings.generation
        println("\n Generation Data Display")
        pretty_table(results.generation, header[:generation], screen_size = (-1,-1), alignment=[:r,:r],
            formatters = ft_printf(["%1.0f","%1.4f"], collect(1:2)))
    end

    group = (main = 1, flow = 1, generation = gent, bus = 2, branch = 2, generator = gen, basePower = 2)

    return header, group
end


### AC power flow results
@inbounds function results_flowac(system, num, settings, results, slack, limit, algtime)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    aheader = acpfheader(); pheader = psheader()
    header = merge(aheader, pheader)

    ########## AC limit display ##########
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

    ########## AC main display ##########
    if settings.main
        h1 = Highlighter((data, i, j)-> (i == slack), background = :red)
        println("\n Main Data Display")
        pretty_table(results.main, header[:main],
            screen_size = (-1,-1), highlighters = h1, columns_width = [7, 16, 12, 17, 21, 17, 21, 17, 21, 17, 21],
            alignment = repeat([Symbol(:r)], outer = 11),
            formatters = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:11)))
        sum_data = Any["Sum" sum(results.main[:, 4:11], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r,:r,:r,:r,:r], columns_width = [41, 17, 21, 17, 21, 17, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f","%11.2f","%15.2f","%13.2f","%15.2f"], collect(1:9)))
    end

    ########## AC flow display ##########
    if settings.flow
        println("\n Flow Data Display")
        pretty_table(results.flow[:,1:10], header[:flow][:,1:10],
            screen_size = (-1,-1), columns_width = [6, 8, 8, 17, 21, 17, 21, 21, 17, 21],
            alignment=[:r,:r,:r,:r,:r,:r,:r,:r,:r,:r],
            formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(results.flow[:, 8:10], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ########## AC generation display ##########
    gen = 0; gent = 0
    if num.Ngen != 0
        gen = 2; gent = 1
    end

    if settings.generation
        println("\n Generation Data Display")
        pretty_table(results.generation, header[:generation],
            screen_size = (-1,-1), alignment=[:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%1.4f", "%1.4f"], collect(1:3)))
    end

    group = (main = 1, flow = 1, generation = gent, bus = 2, branch = 2, generator = gen, basePower = 2)

    return header, group
end


### Power system info data
@inbounds function infogrid(bus, branch, generator, info, dataname, Nbranch, Nbus, Ngen)
    reference = "unknown"; grid = "unknown"
    for (k, i) in enumerate(info[:, 1])
        if occursin("Reference", i)
            reference = info[k, 2]
        end
        if occursin("Grid", i)
            grid = info[k, 2]
        end
    end

    Ntrain = 0; Ntra = 0; pv = 0
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
function results_estimatedc(system, numsys, measurements, num, settings, results, idxbad, Npseudo, algtime, slack)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    header = dcseheader()

    ########## DC estimate and error results ##########
    label = Array{String}(undef, size(results.estimate, 1), 3)
    idex = 1
    for (k, i) in enumerate(results.estimate[:, 2])
        if i == 1.0
            label[k, 1] = "in-service"
        elseif i == 2.0
            label[k, 1] = "bad-measurement"
        elseif i == 3.0
            label[k, 1] = "pseudo-measurement"
        end
        if results.estimate[k, 3] == 1.0
            label[k, 2] = "Legacy"
        else
            label[k, 2] = "PMU"
        end
        j = convert(Int, results.estimate[k, 5])
        if results.estimate[k, 4] == 1.0
            label[k, 3] = "P$(trunc(Int, measurements.legacyFlow[j, 2])),$(trunc(Int, measurements.legacyFlow[j, 3])) [MW]"
        elseif results.estimate[k, 4] == 3.0
            label[k, 3] = "P$(trunc(Int, measurements.legacyInjection[j, 1])) [MW]"
        elseif results.estimate[k, 4] == 8.0
            label[k, 3] = "T$(trunc(Int, measurements.pmuVoltage[j, 1])) [deg]"
        end
    end

    ########## Observability display ##########
    idxp = findall(x->x==3, results.estimate[:, 2])
    pseudo = [label[idxp, 2:3] results.estimate[idxp, 5:7]]
    if settings.observe[:observe] == 1 && Npseudo != 0
        Nisland = size(results.observability, 1)
        numer = collect(1:Nisland)
        islanddisp = copy(results.observability)
        if Nisland > Npseudo
            pseudo = [pseudo; repeat([""], Nisland - Npseudo, 5)]
        elseif Nisland < Npseudo
            islanddisp = [islanddisp; repeat([[""]], Npseudo - Nisland, 1)]
            numer = [numer; repeat([""], Npseudo - Nisland)]
        end
        println("\n Observability Analysis Display")
        pretty_table([numer islanddisp pseudo], header[:observe], alignment=[:l,:l,:l,:l,:r,:r,:r],
            columns_width = [11, 40, 10, 20, 11, 11, 11],
            formatters = ft_printf(["%1.0f", "%-s", "%-s", "%-s", "%1.0f", "%1.2f", "%1.2e"], collect(1:7)))
    end

    ########## DC bad data display ##########
    if settings.bad[:bad] == 1 && !isempty(results.baddata)
        println("\n Bad Data Analysis Display")
        pretty_table([results.baddata[:,1] label[idxbad, 2:3] results.estimate[idxbad, 5] results.baddata[:,5] label[idxbad, 1]],
            header[:bad], screen_size = (-1,-1),
            columns_width = [10, 10, 18, 13, 20, 18], alignment=[:l,:l,:l,:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%-s","%-s","%1.0f","%1.4e","%-s"], collect(1:6)))
    end

    ########## DC main display ##########
    if settings.main
        h1 = Highlighter((data, i, j) -> (i == slack),  background = :blue)
        println("\n Main Data Display")
        pretty_table(results.main, header[:main], screen_size = (-1,-1), alignment = [:r,:r,:r],
            highlighters = h1, columns_width = [8, 18, 18],
            formatters = ft_printf(["%1.0f","%1.4f","%1.2f"], collect(1:3)))

        sum_data = Any["Sum" sum(results.main[:, 3], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), columns_width = [29, 18],
            alignment = [:l,:r], formatters = ft_printf(["%-s","%15.2f"], [1, 2]))
    end

    ########## DC flow display ##########
    if settings.flow
        println("\n Flow Data Display")
        pretty_table(results.flow, header[:flow], screen_size = (-1,-1), columns_width = [8, 8, 8, 18, 18],
            alignment=[:r,:r,:r,:r,:r], formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f"], collect(1:5)))
    end

    ########## DC Estimate display ##########
    if settings.estimate
        println("\n Estimate Data Display")
        columns_width = [18, 12, 15, 12, 12, 12, 12, 19, 12, 19]
        alignment = [:l, :l, :l, :r, :r, :r, :r, :r, :r, :r]
        formatters = ["%s", "%s", "%s", "%1.0f", "%1.2f", "%1.2e", "%1.2f", "%1.2e", "%1.2f", "%1.2e"]
        many = collect(1:10)
        head = header[:estimatedisplay]
        if size(results.estimate, 2) == 9
            columns_width = columns_width[1:8]
            alignment = alignment[1:8]
            formatters = formatters[1:8]
            many = many[1:8]
            head = head[:, 1:8]
        end
        pretty_table([label results.estimate[:, 5:end]], head, screen_size = (-1,-1), columns_width = columns_width,
            show_row_number = true, alignment = alignment, formatters = ft_printf((formatters), many))
    end

    ########## DC error display ##########
    if settings.error
        println("\n Error Data Display\n")
        if size(results.estimate, 2) == 11
            head = header[:errordisplay]
            err = [""; results.error[1:3]; ""; ""; results.error[4:6]]
        else
            head = header[:errordisplay][1:4, :]
            err = [""; results.error[1:3]]
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

    return headernew, group
end


### PMU state estimation results
@inbounds function results_estimatepmu(system, numsys, measurements, num, settings, results, idxbad, Npseudo, algtime)
    println(string("Execution time: ", (@sprintf "%.4f" algtime * 1000), " (ms)"))
    aheader = pmuseheader(); pheader = psheader()
    header = merge(aheader, pheader)

    ########## PMU estimate and error results ##########
    label = Array{String}(undef, size(results.estimate, 1), 3)
    idex = 1
    for (k, i) in enumerate(results.estimate[:, 2])
        if i == 1.0
            label[k, 1] = "in-service"
        elseif i == 2.0
            label[k, 1] = "bad-measurement"
        elseif i == 3.0
            label[k, 1] = "pseudo-measurement"
        end
        label[k, 2] = "PMU"
        j = convert(Int, results.estimate[k, 5])
        if results.estimate[k, 4] == 9.0
            label[k, 3] = "Ir$(trunc(Int, measurements.pmuCurrent[j, 2])),$(trunc(Int, measurements.pmuCurrent[j, 3])) [p.u.]"
        elseif results.estimate[k, 4] == 10.0
            label[k, 3] = "Ii$(trunc(Int, measurements.pmuCurrent[j, 2])),$(trunc(Int, measurements.pmuCurrent[j, 3])) [p.u.]"
        elseif results.estimate[k, 4] == 11.0
            label[k, 3] = "Vr$(trunc(Int, measurements.pmuVoltage[j, 1])) [p.u.]"
        elseif results.estimate[k, 4] == 12.0
            label[k, 3] = "Vi$(trunc(Int, measurements.pmuVoltage[j, 1])) [p.u.]"
        end
    end

    ########## PMU bad data display ##########
    if settings.bad[:bad] == 1 && !isempty(results.baddata)
        println("\n Bad Data Analysis Display")
        pretty_table([results.baddata[:,1] label[idxbad, 2:3] results.estimate[idxbad, 5] results.baddata[:,5] label[idxbad, 1]],
            header[:bad], screen_size = (-1,-1),
            columns_width = [10, 10, 18, 13, 20, 18], alignment=[:l,:l,:l,:r,:r,:r],
            formatters = ft_printf(["%1.0f", "%-s","%-s","%1.0f","%1.4e","%-s"], collect(1:6)))
    end

    ########## PMU main results ##########
    if settings.main
        println("\n Main Data Display")
        pretty_table(results.main, header[:main],
            screen_size = (-1,-1), columns_width = [7, 16, 12, 17, 21, 17, 21],
            alignment = repeat([Symbol(:r)], outer = 7),
            formatters = ft_printf(["%1.0f", "%1.4f","%1.4f","%1.2f" ,"%1.2f","%1.2f","%1.2f"], collect(1:7)))
        sum_data = Any["Sum" sum(results.main[:, 4:7], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1),
            alignment=[:l,:r,:r,:r,:r], columns_width = [41, 17, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%15.2f","%11.2f","%15.2f"], collect(1:5)))
    end

    ########## PMU flow results ##########
    if settings.flow
        println("\n Flow Data Display")
        pretty_table(results.flow[:,1:10], header[:flow][:,1:10],
            screen_size = (-1,-1), columns_width = [6, 8, 8, 17, 21, 17, 21, 21, 17, 21],
            alignment=[:r,:r,:r,:r,:r,:r,:r,:r,:r,:r],
            formatters = ft_printf(["%1.0f","%1.0f","%1.0f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f","%1.2f"], collect(1:10)))
        sum_data = Any["Sum" sum(results.flow[:, 8:10], dims = 1)]
        pretty_table(sum_data, noheader = true, screen_size = (-1,-1), alignment=[:l,:r,:r,:r], columns_width = [116, 21, 17, 21],
            formatters = ft_printf(["%-s","%15.2f","%11.2f","%15.2f"], collect(1:4)))
    end

    ########## PMU Estimate display ##########
    if settings.estimate
        println("\n Estimate Data Display")
        columns_width = [18, 12, 15, 12, 12, 12, 12, 19, 12, 19]
        alignment = [:l, :l, :l, :r, :r, :r, :r, :r, :r, :r]
        formatters = ["%s", "%s", "%s", "%1.0f", "%1.2f", "%1.2e", "%1.2f", "%1.2e", "%1.2f", "%1.2e"]
        many = collect(1:10)
        head = header[:estimatedisplay]
        if size(results.estimate, 2) == 9
            columns_width = columns_width[1:8]
            alignment = alignment[1:8]
            formatters = formatters[1:8]
            many = many[1:8]
            head = head[:, 1:8]
        end
        pretty_table([label results.estimate[:, 5:end]], head, screen_size = (-1,-1), columns_width = columns_width,
            show_row_number = true, alignment = alignment, formatters = ft_printf((formatters), many))
    end

    ########## DC error display ##########
    if settings.error
        println("\n Error Data Display\n")
        if size(results.estimate, 2) == 11
            head = header[:errordisplay]
            err = [""; results.error[1:3]; ""; ""; results.error[4:6]]
        else
            head = header[:errordisplay][1:4, :]
            err = [""; results.error[1:3]]
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

    return headernew, group
end
