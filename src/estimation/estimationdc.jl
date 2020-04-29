#########################
#  DC state estimation  #
#########################
function rundcse(settings, system, measurement)
    println("Algorithm: DC state estimation")
    busi, type, Tini,
    branchi, fromi, toi, reactance, transTap, transShift, branchOn,
    branchiPij, fromiPij, toiPij, meanPij, variPij, onPij,
    busiPi, meanPi, variPi, onPi,
    busiTi, meanTi, variTi, onTi,
    Pinj, Pshift, Ydiag, Pij, admitance = view_dcsystem(system, measurement)

  algtime = @elapsed begin
    bus = collect(1:system.Nbus)
    branch = collect(1:system.Nbra)

    numsystem = false
    Tslack = 0.0
    slack = 0
    @inbounds for i = 1:system.Nbus
        if bus[i] != busi[i]
            numsystem = true
            println("The new bus numbering is running.")
        end
        if type[i] == 3
            Tslack = Tini[i]
            slack = bus[i]
        end
    end
    if slack == 0
        slack = 1
        println("The slack bus is not found. Slack bus is the first bus.")
    end
    numlabel = false
    @inbounds for i = 1:system.Nbra
        if branch[i] != branchi[i]
            numlabel = true
            println("The new branch label numbering is running.")
            break
        end
    end
    from = renumber(fromi, system.Nbra, busi, bus, system.Nbus, numsystem)
    to = renumber(toi, system.Nbra, busi, bus, system.Nbus, numsystem)
    fromPij = renumber(fromiPij, measurement.legacyNf, busi, bus, system.Nbus, numsystem)
    toPij = renumber(toiPij, measurement.legacyNf, busi, bus, system.Nbus, numsystem)
    busPi = renumber(busiPi, measurement.legacyNi, busi, bus, system.Nbus, numsystem)
    busTi = renumber(busiTi, measurement.pmuNv, busi, bus, system.Nbus, numsystem)
    branchPij = renumber(branchiPij, measurement.legacyNf, branchi, branch, system.Nbra, numlabel)

    Ybus = ybusdc(system, Pshift, Ydiag, branchOn, transTap, admitance, reactance, transShift, bus, from, to)

    Nelement = 0
    Nmeasur = 0
    @inbounds for i = 1:measurement.legacyNv
        if onTi[i] == 1
            Nelement += 1
            Nmeasur += 1
        end
    end
    @inbounds for i = 1:measurement.legacyNf
        if onPij[i] == 1
            Nelement += 2
            Nmeasur += 1
        end
    end
    @inbounds for i = 1:measurement.legacyNi
        if onPi[i] == 1
            Nmeasur += 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                Nelement += 1
            end
        end
    end

    row = fill(0, Nelement)
    col = similar(row)
    jac = fill(0.0, Nelement)
    mean = fill(0.0, Nmeasur)
    weight = similar(mean)
    index = 1
    rowindex = 1
    @inbounds for i = 1:measurement.legacyNv
        if onTi[i] == 1
            row[index] = rowindex
            col[index] = busTi[i]
            jac[index] = 1.0

            mean[rowindex] = meanTi[i] - Tslack * (pi / 180)
            weight[rowindex] = 1 / variTi[i]

            index += 1
            rowindex += 1
        end
    end
    @inbounds for i = 1:measurement.legacyNf
        if onPij[i] == 1
            row[index] = rowindex
            col[index] = fromPij[i]
            jac[index] = admitance[branchPij[i]]
            index += 1
            row[index] = rowindex
            col[index] = toPij[i]
            jac[index] = -admitance[branchPij[i]]

            mean[rowindex] = meanPij[i] - transShift[branchPij[i]] * (pi / 180)
            weight[rowindex] = 1 / variPij[i]

            index += 1
            rowindex += 1
        end
    end
    @inbounds for i = 1:measurement.legacyNi
        if onPi[i] == 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                row[index] = rowindex
                col[index] = Ybus.rowval[j]
                jac[index] = Ybus.nzval[j]
                index += 1
            end

            mean[rowindex] = meanPi[i] - Pshift[i]
            weight[rowindex] = 1 / variPi[i]

            rowindex += 1
        end
    end

    jacobian = sparse(row, col, jac, Nmeasur, system.Nbus)
    W = spdiagm(0 => sqrt.(weight))
    keep = [collect(1:slack - 1); collect(slack + 1:system.Nbus)]
    jacobian = jacobian[:, keep]
    H = W * jacobian
    G = transpose(H) * H

    Ti = Array{Float64}(undef, system.Nbus - 1, 1)
    if settings.lav
        Nvar = system.Nbus - 1
        x = lav(jacobian, mean, Nvar, Nmeasur, settings)
        Ti = zeros(Nvar)
        for i = 1:Nvar
            Ti[i] = x[i] - x[Nvar + i]
        end
    else
        Ti = wls(jacobian, G, H, W, mean, settings.solve)
    end

    pass = 1; savebad = reshape([], 0, 3)
    while settings.bad && settings.badpass >= pass
        Gi = inv(Matrix(G))

        meanest = jacobian * Ti
        jacobianGi = jacobian * Gi
        idx = findall(!iszero, jacobian)
        p = fill(0.0, size(jacobian, 1))
        for i in idx
            p[i[1]] += jacobianGi[i] * jacobian[i]
        end

        Ticr = (transpose(jacobian) * jacobian) \ (transpose(jacobian) * mean)
        meancr = jacobian * Ticr
        rmax = 0.0
        idxr = 0
        for i = 1:Nmeasur
            if abs(mean[i] - meancr[i]) > settings.badcritical
                rnor = abs((mean[i] - meanest[i])) / sqrt(abs(1 / weight[i] - p[i]))
                if rnor > rmax
                    idxr = i
                    rmax = rnor
                end
            end
        end

        if rmax < settings.badtreshold
            break
        end

        for i in idx
            if i[1] == idxr
                jacobian[i] = 0.0
            end
        end
        mean[idxr] = 0.0
        W[idxr, idxr] = 0.0
        savebad = [savebad; [idxr rmax "remove"]]

        H = W * jacobian
        G = transpose(H) * H
        if settings.lav
            Nvar = system.Nbus - 1
            x = lav(jacobian, mean, Nvar, Nmeasur, settings)
            Ti = zeros(Nvar)
            for i = 1:Nvar
                Ti[i] = x[i] - x[Nvar + i]
            end
        else
            Ti = wls(jacobian, G, H, W, mean, settings.solve)
        end

        pass += 1
    end

    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tslack .+ Ti

    @inbounds for i = 1:system.Nbra
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i])
        else
            Pij[i] = 0.0
        end
    end

    Pinj[:] = Ybus * Ti + Pshift
 end # algtime

    results, header, labels, savetoh5 = results_estimationdc(settings, system, Ti, slack, algtime, measurement, Nmeasur, branchPij, busPi, busTi, savebad)

    if !isempty(settings.save)
        if settings.saveextension == ".h5"
            savedata(savetoh5; info = measurement.info, group = keys(results), header = header, path = settings.save, label = labels)
        else
            savedata(results; info = measurement.info, group = keys(results), header = header, path = settings.save)
        end
    end
    push!(results, "info" => measurement.info)

    return results
end

#################
#  View system  #
#################
function view_dcsystem(system, measurement)
    ################## Write data ##################
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Tini = @view(system.bus[:, 9])

    branchi = @view(system.branch[:, 1])
    fromi = @view(system.branch[:, 2])
    toi = @view(system.branch[:, 3])
    reactance = @view(system.branch[:, 5])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    branchiPij = @view(measurement.legacyFlow[:, 1])
    fromiPij = @view(measurement.legacyFlow[:, 2])
    toiPij = @view(measurement.legacyFlow[:, 3])
    meanPij = @view(measurement.legacyFlow[:, 4])
    variPij = @view(measurement.legacyFlow[:, 5])
    onPij = @view(measurement.legacyFlow[:, 6])

    busiPi = @view(measurement.legacyInjection[:, 1])
    meanPi = @view(measurement.legacyInjection[:, 2])
    variPi = @view(measurement.legacyInjection[:, 3])
    onPi = @view(measurement.legacyInjection[:, 4])

    busiTi = @view(measurement.pmuVoltage[:, 1])
    meanTi = @view(measurement.pmuVoltage[:, 5])
    variTi = @view(measurement.pmuVoltage[:, 6])
    onTi = @view(measurement.pmuVoltage[:, 7])

    ################## Write data ##################
    Pinj = @view(system.bus[:, 11])
    Pshift = @view(system.bus[:, 12])
    Ydiag = @view(system.bus[:, 13])

    Pij = @view(system.branch[:, 4]);
    admitance = @view(system.branch[:, 5]);

    return busi, type, Tini,
           branchi, fromi, toi, reactance, transTap, transShift, branchOn,
           branchiPij, fromiPij, toiPij, meanPij, variPij, onPij,
           busiPi, meanPi, variPi, onPi,
           busiTi, meanTi, variTi, onTi,
           Pinj, Pshift, Ydiag, Pij, admitance

end
