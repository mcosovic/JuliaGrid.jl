struct StateEstimationDC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    estimate::Array{Float64,2}
    error::Array{Float64,1}
    baddata::Array{Float64,2}
    observability::Array{Array{Int64,1},1}
end

#### DC state estimation
function rundcse(system, measurements, num, numsys, settings, info)
    printstyled("Algorithm: DC state estimation\n"; bold = true)

    ########## Pre-processing ##########
    busi, type, Gshunt, Tini, branchi, reactance, transTap, transShift, branchOn,
    meanPij, variPij, onPij, meanPi, variPi, onPi,
    meanTi, variTi, onTi  = read_dcsystem(system, measurements)

    main = fill(0.0, numsys.Nbus, 3)
    flow = fill(0.0, numsys.Nbranch, 5)
    Va, Pinj, Pij, Pji, badsave, islands = write_dcsystem(system, numsys, main, flow)

  algtime = @elapsed begin
    ########## Convert in integers ##########
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])
    fromiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 2])
    toiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 3])
    busiPi = convert(Array{Int64,1}, measurements.legacyInjection[:, 1])
    busiTi = convert(Array{Int64,1}, measurements.pmuVoltage[:, 1])
    branchiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 1])

    ########## Numbering and slack bus ##########
    bus = collect(1:numsys.Nbus)
    branch = collect(1:numsys.Nbranch)
    newnumbering = false
    Tslack = 0.0
    slack = 0
    @inbounds for i = 1:numsys.Nbus
        if bus[i] != busi[i]
            newnumbering = true
        end
        if type[i] == 3
            Tslack = Tini[i]
            slack = bus[i]
        end
    end
    if newnumbering
        println("The new bus numbering is running.")
    end
    if slack == 0
        slack = 1
        println("The slack bus is not found. Slack bus is the first bus.")
    end

    numlabel = false
    @inbounds for i = 1:numsys.Nbranch
        if branch[i] != branchi[i]
            numlabel = true
            break
        end
    end
    if numlabel
        println("The new branch numbering is running.")
    end
    from = renumber(fromi, busi, bus, newnumbering)
    to = renumber(toi, busi, bus, newnumbering)
    fromPij = renumber(fromiPij, busi, bus, newnumbering)
    toPij = renumber(toiPij, busi, bus, newnumbering)
    busPi = renumber(busiPi, busi, bus, newnumbering)
    busTi = renumber(busiTi, busi, bus, newnumbering)
    branchPij = renumber(branchiPij, branchi, branch, newnumbering)

    ########## Ybus matrix ##########
    Ybus, admitance, Pshift = ybusdc(system, numsys, bus, from, to, branchOn, transTap, reactance, transShift)

    ########## Number of Jacobian elements and measurements ##########
    Nelement = 0; Nmeasure = 0; Nflow = 0; Nvol = 0; Ninj = 0
    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            Nelement += 2; Nmeasure += 1; Nflow += 1
        end
    end
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            Nmeasure += 1; Ninj += 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                Nelement += 1
            end
        end
    end
    @inbounds for i = 1:num.pmuNv
        if onTi[i] == 1
            Nelement += 1; Nmeasure += 1; Nvol += 1
        end
    end

    ########## Jacobian and measurement data ##########
    row = fill(0, Nelement); col = similar(row); jac = fill(0.0, Nelement)
    mean = fill(0.0, Nmeasure); weight = similar(mean)
    index = 1; rowindex = 1
    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            row[index] = rowindex
            col[index] = fromPij[i]
            jac[index] = admitance[branchPij[i]]
            index += 1
            row[index] = rowindex
            col[index] = toPij[i]
            jac[index] = -admitance[branchPij[i]]

            if fromPij[i] == from[branchPij[i]]
                mean[rowindex] = meanPij[i] + transShift[branchPij[i]] * (pi / 180)  * admitance[branchPij[i]]
            else
                mean[rowindex] = meanPij[i] - transShift[branchPij[i]] * (pi / 180) * admitance[branchPij[i]]
            end
            weight[rowindex] = 1 / variPij[i]

            index += 1; rowindex += 1
        end
    end

    if settings.observe[:observe] == 1
        N = 2 * Nflow
        Jflow = sparse(row[1:N], col[1:N], jac[1:N], Nflow, numsys.Nbus)
    end

    cnt = 1
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                row[index] = rowindex
                col[index] = Ybus.rowval[j]
                jac[index] = Ybus.nzval[j]
                index += 1
            end

            mean[rowindex] = meanPi[i] - Pshift[i] - Gshunt[i] / system.basePower
            weight[rowindex] = 1 / variPi[i]

            rowindex += 1; cnt += 1
        end
    end

    cnt = 1
    @inbounds for i = 1:num.pmuNv
        if onTi[i] == 1
            row[index] = rowindex
            col[index] = busTi[i]
            jac[index] = 1.0

            mean[rowindex] = meanTi[i] - Tslack * (pi / 180)
            weight[rowindex] = 1 / variTi[i]

            index += 1; rowindex += 1; cnt += 1
        end
    end
    J = sparse(row, col, jac, Nmeasure, numsys.Nbus)

    ########## Observability analysis ##########
    Npseudo = 0
    if settings.observe[:observe] == 1
        r = rank(J)
        if r < numsys.Nbus
            println("The power system is unobservable, the column rank of the Jacobian matrix is $r." )

            islands, Nislands = islandsflow(Jflow)
            if settings.observe[:islands] == 1
                islands, Nisland = islandstopological(settings, numsys, J, Jflow, Ybus, branch, from, to, busPi, onPi, islands)
            elseif settings.observe[:islands] == 2
                islands, Nisland = islandsbp(settings, numsys, J, bus, islands, Nislands)
            end

            if settings.observe[:restore] == 1
                J, mean, weight, Npseudo = restorationgram(system, settings, numsys, num, measurements, islands, Nisland, J, mean, weight,
                    Ybus, slack, Tslack, branch, from, to, fromPij, toPij, busPi, branchPij, busTi, onPi, onPij, onTi, Nvol, Nflow,
                    meanPij, meanPi, meanTi, variPi, variTi, variPij, admitance, Gshunt, transShift, Pshift)
            elseif settings.observe[:restore] == 2
                J, mean, weight, Npseudo = restorationbp(system, settings, numsys, num, measurements, islands, Nisland, J, mean, weight,
                    Ybus, branch, from, to, busPi, onPi, meanPi, variPi, Pshift, Gshunt)
            end
        else
            println("The power system is observable.")
        end
    end
    Nmeasure = Nmeasure + Npseudo

    ######### Remove column of the slack bus, but keep full column rank ##########
    for i in J.colptr[slack]:(J.colptr[slack + 1] - 1)
        J.nzval[i] = 0.0
    end
    J = [J; sparse([1], [slack], [1.0], 1, numsys.Nbus)]
    push!(mean, 0.0); push!(weight, 1.0);

    ######### LAV ##########
    if settings.lav[:lav] == 1
        Ti = Array{Float64}(undef, numsys.Nbus)
        x = lav(J, mean, numsys.Nbus, Nmeasure + 1, settings)
        for i = 1:numsys.Nbus
            Ti[i] = x[i] - x[numsys.Nbus + i]
        end
    end

    ######## WLS and bad data analysis ##########
    if settings.lav[:lav] == 0
        W = spdiagm(0 => sqrt.(weight))

        if settings.bad[:bad] == 1
            idx = findall(!iszero, J)
            v = 1 ./ weight
        end

        pass = 1; rbelow = true
        while rbelow
            if settings.bad[:pass] < pass || settings.bad[:bad] == 0
                rbelow = false
            end

            H = W * J
            G = transpose(H) * H
            b = transpose(H) * W * mean
            Ti = wls(G, b, settings.solve)

            if rbelow
                J, mean, W, badsave, rbelow = baddata(settings, numsys, Ti, mean, v, W, G, J, Nmeasure, idx, badsave, rbelow)
                pass += 1
            end
        end
    end

    ########## Post-processing ##########
    Ti =  (pi / 180) * Tslack .+ Ti

    @inbounds for i = 1:numsys.Nbranch
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i]) * system.basePower
            Pji[i] = -Pij[i]
        end
    end

    Pinj[:] = (Ybus * Ti + Pshift) * system.basePower + Gshunt
    for i = 1:numsys.Nbus
        Va[i] = (180 / pi) * Ti[i]
    end

    ePmuVol = size(measurements.pmuVoltage, 2) == 9
    eLegFlo = size(measurements.legacyFlow, 2) == 11
    eLegInj = size(measurements.legacyInjection, 2) == 9
    estimate_row = 9; error_row = 3; exact = false
    if ePmuVol && eLegFlo && eLegInj
        estimate_row = 11; error_row = 6; exact = true
    end
    estimate = zeros(Nmeasure, estimate_row)
    error = zeros(error_row)

    Nm = Nmeasure - size(badsave, 1)
    idx = 1; scaleTi = 180 / pi
    for (i, on) in enumerate(onPij)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 1.0 i]
            if idx in badsave[:, 1]
                estimate[idx, 2] = 2.0; onPij[i] = 0
            end
            if on == 2
                estimate[idx, 2] = 3.0; onPij[i] = 1
            end

            estimate[idx, 6] = measurements.legacyFlow[i, 4] * system.basePower
            estimate[idx, 7] = measurements.legacyFlow[i, 5] * system.basePower
            k = branchPij[i]
            if measurements.legacyFlow[i, 2] == system.branch[k, 2] && measurements.legacyFlow[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 4]
            else
                estimate[idx, 8] = flow[k, 5]
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nm * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyFlow[i, 5] * system.basePower^2)
            end

            if exact
                estimate[idx, 10] = measurements.legacyFlow[i, 10] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nm * system.basePower^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.legacyFlow[i, 5] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onPi)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 3.0 i]
            if idx in badsave[:, 1]
                estimate[idx, 2] = 2.0; onPi[i] = 0
            end
            if on == 2
                estimate[idx, 2] = 3.0; onPi[i] = 1
            end

            estimate[idx, 6] = measurements.legacyInjection[i, 2] * system.basePower
            estimate[idx, 7] = measurements.legacyInjection[i, 3] * system.basePower
            estimate[idx, 8] = main[busPi[i], 3]
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nm * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyInjection[i, 3] * system.basePower^2)
            end

            if exact
                estimate[idx, 10] = measurements.legacyInjection[i, 8] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nm * system.basePower^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.legacyInjection[i, 3] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onTi)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 2.0 8.0 i]
            if idx in badsave[:, 1]
                estimate[idx, 2] = 2.0; onTi[i] = 0
            end
            if on == 2
                estimate[idx, 2] = 3.0; onTi[i] = 1
            end

            estimate[idx, 6] = measurements.pmuVoltage[i, 5] * scaleTi
            estimate[idx, 7] = measurements.pmuVoltage[i, 6] * scaleTi
            estimate[idx, 8] = main[busTi[i], 2]
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * scaleTi)
                error[2] += estimate[idx, 9]^2 / (Nm * scaleTi^2)
                error[3] += estimate[idx, 9]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
            end

            if exact
                estimate[idx, 10] = measurements.pmuVoltage[i, 9] * scaleTi
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * scaleTi)
                    error[5] += estimate[idx, 11]^2 / (Nm * scaleTi^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
                end
            end
            idx += 1
        end
    end
    error[2] = sqrt(error[2])
    if exact
        error[5] = sqrt(error[5])
    end

    pass = collect(1:size(badsave, 1))
    idxbad = trunc.(Int, badsave[:, 1])
    bad = [pass estimate[idxbad, 3:5] badsave[:, 2] estimate[idxbad, 2]]

    if settings.observe[:observe] == 1 && Npseudo != 0 && newnumbering
        Nisland = size(islands, 1)
        for k = 1:Nisland
            for (n, i) in enumerate(k)
                islands[k][n] = system.bus[i, 1]
            end
        end
    end
 end # algtime

    ######### Results ##########
    results = StateEstimationDC(main, flow, estimate, error, bad, islands)
    header, group = results_estimatedc(system, numsys, measurements, num, settings, results, idxbad, Npseudo, algtime, slack)
    if !isempty(settings.save)
        savedata(results, measurements, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### Read system
function read_dcsystem(system, measurements)
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Gshunt = @view(system.bus[:, 5])
    Tini = @view(system.bus[:, 9])

    branchi = @view(system.branch[:, 1])
    reactance = @view(system.branch[:, 5])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    meanPij = @view(measurements.legacyFlow[:, 4])
    variPij = @view(measurements.legacyFlow[:, 5])
    onPij = @view(measurements.legacyFlow[:, 6])

    meanPi = @view(measurements.legacyInjection[:, 2])
    variPi = @view(measurements.legacyInjection[:, 3])
    onPi = @view(measurements.legacyInjection[:, 4])

    meanTi = @view(measurements.pmuVoltage[:, 5])
    variTi = @view(measurements.pmuVoltage[:, 6])
    onTi = @view(measurements.pmuVoltage[:, 7])

    return busi, type, Gshunt, Tini,
           branchi, reactance, transTap, transShift, branchOn,
           meanPij, variPij, onPij,
           meanPi, variPi, onPi,
           meanTi, variTi, onTi
end


### Write data
function write_dcsystem(system, numsys, main, flow)
    for i = 1:numsys.Nbus
        main[i, 1] = system.bus[i, 1]
    end
    Va = @view(main[:, 2])
    Pinj = @view(main[:, 3])

    for i = 1:numsys.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
    end
    Pij = @view(flow[:, 4])
    Pji = @view(flow[:, 5])

    badsave = reshape(Float64[], 0, 2)
    islands = [Int64[]]

    return Va, Pinj, Pij, Pji, badsave, islands
end
