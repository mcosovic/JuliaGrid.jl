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

    pseudoslack = false
    if settings.observe[:observe] == 1 && onTi[slack] == 0
        onTi[slack] = 1
        pseudoslack = true
    end

    numlabel = false
    @inbounds for i = 1:numsys.Nbranch
        if branch[i] != branchi[i]
            numlabel = true
            break
        end
    end
    if numlabel
        println("The new branch label numbering is running.")
    end
    from = renumber(fromi, numsys.Nbranch, busi, bus, numsys.Nbus, newnumbering)
    to = renumber(toi, numsys.Nbranch, busi, bus, numsys.Nbus, newnumbering)
    fromPij = renumber(fromiPij, num.legacyNf, busi, bus, numsys.Nbus, newnumbering)
    toPij = renumber(toiPij, num.legacyNf, busi, bus, numsys.Nbus, newnumbering)
    busPi = renumber(busiPi, num.legacyNi, busi, bus, numsys.Nbus, newnumbering)
    busTi = renumber(busiTi, num.pmuNv, busi, bus, numsys.Nbus, newnumbering)
    branchPij = renumber(branchiPij, num.legacyNf, branchi, branch, numsys.Nbranch, newnumbering)

    ########## Ybus matrix ##########
    Ybus, admitance, Pshift = ybusdc(system, numsys, bus, from, to, branchOn, transTap, reactance, transShift)

    ########## Jacobian ##########
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
        J, mean, weight, Npseudo, islands = observability_flow(settings, system, numsys, measurements, num, J,
            Jflow, slack, branch, from, to, busPi, onPi, onTi, Ybus, Nvol, Nflow, branchPij,
            onPij, busTi, fromPij, toPij, admitance, mean, weight, meanPij, transShift, Pshift, meanPi,
            meanTi, Tslack, variPi, variTi, variPij, Npseudo, islands)
    end
    Nmeasure = Nmeasure + Npseudo

    ########## Remove column of the slack bus ##########
    keep = [collect(1:slack - 1); collect(slack + 1:numsys.Nbus)]
    J = J[:, keep]

    ########## LAV ##########
    if settings.lav[:lav] == 1
        Ti = Array{Float64}(undef, numsys.Nbus - 1)
        Nvar = numsys.Nbus - 1
        x = lav(J, mean, Nvar, Nmeasure, settings)
        for i = 1:Nvar
            Ti[i] = x[i] - x[Nvar + i]
        end
    end

    ########## WLS and bad data analysis ##########
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
    insert!(Ti, slack, 0.0)
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

    exact1 = 2; exact2 = 3
    if size(measurements.pmuVoltage, 2) == 9 && size(measurements.legacyFlow, 2) == 11 && size(measurements.legacyInjection, 2) == 9
        exact1 = 0; exact2 = 0
    end
    estimate = zeros(Nmeasure, 11 - exact1)
    error = zeros(6 - exact2)
    Nmeasure = Nmeasure - size(badsave, 1) - Npseudo
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
                error[1] += estimate[idx, 9] / (Nmeasure * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nmeasure * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyFlow[i, 5] * system.basePower^2)
            end

            if exact1 == 0
                estimate[idx, 10] = measurements.legacyFlow[i, 10] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nmeasure * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nmeasure * system.basePower^2)
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
                error[1] += estimate[idx, 9] / (Nmeasure * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nmeasure * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyInjection[i, 3] * system.basePower^2)
            end

            if exact1 == 0
                estimate[idx, 10] = measurements.legacyInjection[i, 8] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nmeasure * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nmeasure * system.basePower^2)
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
                error[1] += estimate[idx, 9] / (Nmeasure * scaleTi)
                error[2] += estimate[idx, 9]^2 / (Nmeasure * scaleTi^2)
                error[3] += estimate[idx, 9]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
            end

            if exact1 == 0
                estimate[idx, 10] = measurements.pmuVoltage[i, 9] * scaleTi
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nmeasure * scaleTi)
                    error[5] += estimate[idx, 11]^2 / (Nmeasure * scaleTi^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.pmuVoltage[i, 6] * scaleTi^2)
                end
            end
            idx += 1
        end
    end
    error[2] = sqrt(error[2])
    if exact1 == 0
        error[5] = sqrt(error[5])
    end

    pass = collect(1:size(badsave, 1))
    idxbad = trunc.(Int, badsave[:, 1])
    bad = [pass estimate[idxbad, 3:5] badsave[:, 2] estimate[idxbad, 2]]

    if settings.observe[:observe] == 1 && Npseudo != 0 && newnumbering
        for k in islands
            for i in k
                islands[k][i] = system.bus[i, 1]
            end
        end
    end
 end # algtime

    ########## Results ##########
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
