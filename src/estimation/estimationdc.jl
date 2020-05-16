#### DC state estimation
function rundcse(system, measurements, num, numsys, settings, info)
    printstyled("Algorithm: DC state estimation\n"; bold = true)

    busi, type, Tini, branchi, reactance, transTap, transShift, branchOn,
    meanPij, variPij, onPij, meanPi, variPi, onPi,
    meanTi, variTi, onTi  = view_dcsystem(system, measurements)

  algtime = @elapsed begin
    ########## Pre-processing ##########
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])
    fromiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 2])
    toiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 3])
    busiPi = convert(Array{Int64,1}, measurements.legacyInjection[:, 1])
    busiTi = convert(Array{Int64,1}, measurements.pmuVoltage[:, 1])
    branchiPij = convert(Array{Int64,1}, measurements.legacyFlow[:, 1])

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
    Ybus, admitance, Pshift = ybusdc(system, numsys, branchOn, transTap, reactance, transShift, bus, from, to)

    ########## Jacobian ##########
    Nelement = 0; Nmeasur = 0; Nflow = 0; Nvol = 0; Ninj = 0
    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            Nelement += 2; Nmeasur += 1; Nflow += 1
        end
    end
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            Nmeasur += 1; Ninj += 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                Nelement += 1
            end
        end
    end
    @inbounds for i = 1:num.pmuNv
        if onTi[i] == 1
            Nelement += 1; Nmeasur += 1; Nvol += 1
        end
    end

    row = fill(0, Nelement); col = similar(row); jac = fill(0.0, Nelement)
    mean = fill(0.0, Nmeasur); weight = similar(mean)
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

            mean[rowindex] = meanPij[i] - transShift[branchPij[i]] * (pi / 180)
            weight[rowindex] = 1 / variPij[i]

            index += 1; rowindex += 1
        end
    end

    if settings.observe[:observe] == 1
        N = 2 * Nflow
        jacobianflow = sparse(row[1:N], col[1:N], jac[1:N], Nflow, numsys.Nbus)
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

            mean[rowindex] = meanPi[i] - Pshift[i]
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
    jacobian = sparse(row, col, jac, Nmeasur, numsys.Nbus)


    ########## Observability analysis ##########
    Npseudo = 0; islands = [Int64[], Int64[]]
    if settings.observe[:observe] == 1
        jacobian, mean, weight, Npseudo, islands = observability_flow(settings, system, numsys, measurements, num, jacobian,
            jacobianflow, slack, branch, from, to, busPi, onPi, onTi, Ybus, Nvol, Nflow, branchPij,
            onPij, busTi, fromPij, toPij, admitance, mean, weight, meanPij, transShift, Pshift, meanPi,
            meanTi, Tslack, variPi, variTi, variPij, Npseudo, islands)
    end

    ########## WLS and LAV ##########
    Nmeasur = Nmeasur + Npseudo
    W = spdiagm(0 => sqrt.(weight))
    keep = [collect(1:slack - 1); collect(slack + 1:numsys.Nbus)]
    jacobian = jacobian[:, keep]
    H = W * jacobian
    G = transpose(H) * H
    Ti = Array{Float64}(undef, numsys.Nbus - 1)
    if settings.lav[:lav] == 1
        Nvar = numsys.Nbus - 1
        x = lav(jacobian, mean, Nvar, Nmeasur, settings)
        Ti = zeros(Nvar)
        for i = 1:Nvar
            Ti[i] = x[i] - x[Nvar + i]
        end
    else
        Ti = wls(jacobian, G, H, W, mean, settings.solve)
    end

    ########## Bad data analysis ##########
    savebad = reshape(Float64[], 0, 2)
    if settings.bad[:bad] == 1
        Ti, savebad = baddata(settings, numsys, G, jacobian, Ti, Nmeasur, mean, weight, W, savebad)
    end

    ########## Post-processing ##########
    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tslack .+ Ti

    Pij = fill(0.0, numsys.Nbranch)
    @inbounds for i = 1:numsys.Nbranch
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i])
        end
    end

    Pinj = Ybus * Ti + Pshift
 end # algtime

    ########## Results ##########
    if pseudoslack == true
        onTi[slack] = 0
        Nmeasur = Nmeasur - 1
    end
    results, header, group = results_estimationdc(system, numsys, measurements, num, settings, algtime, slack,
        Ti, Pij, Pinj, Nmeasur, branchPij, busPi, busTi, onPij, onPi, onTi, savebad, Npseudo, islands, newnumbering)
    if !isempty(settings.save)
        savedata(results, measurements, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### Bad data analysis
function baddata(settings, numsys, G, jacobian, Ti, Nmeasur, mean, weight, W, savebad)
    pass = 1
    while settings.bad[:pass] >= pass
        S, L, U, d, p, q, Rs = constructfact(G)
        parent = etree(S)
        R = symbfact(S, parent)
        Gi = sparseinv(L, U, d, p, q, Rs, R)

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
            if abs(mean[i] - meancr[i]) > settings.bad[:critical]
                rnor = abs((mean[i] - meanest[i])) / sqrt(abs(1 / weight[i] - p[i]))
                if rnor > rmax
                    idxr = i
                    rmax = rnor
                end
            end
        end

        if rmax < settings.bad[:treshold]
            break
        end

        for i in idx
            if i[1] == idxr
                jacobian[i] = 0.0
            end
        end
        mean[idxr] = 0.0
        W[idxr, idxr] = 0.0
        savebad = [savebad; [idxr rmax]]

        H = W * jacobian
        G = transpose(H) * H
        if settings.lav[:lav] == 1
            Nvar = numsys.Nbus - 1
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

    return Ti, savebad
end

#
### Observability analysis
function observability_flow(settings, system, numsys, measurements, num, jacobian, jacobianflow, slack,
        branch, from, to, busPi, onPi, onTi, Ybus, Nvol, Nflow, branchPij, onPij, busTi, fromPij, toPij, admitance,
        mean, weight, meanPij, transShift, Pshift, meanPi, meanTi, Tslack, variPi, variTi, variPij, Npseudo, islands)

        G = transpose(jacobian) * jacobian
        F = qr(Matrix(G))
        nonobserve = false
        if any(abs.(diag(F.R)) .< settings.observe[:pivot])
            nonobserve = true
        end
        if nonobserve
            println("The power system is unobservable.")
        else
            println("The power system is observable.")
        end

    if nonobserve
        ########## Flow islands ##########
        M = jacobianflow' * jacobianflow
        islands = connected_components(SimpleGraph(M))

        islandsWhere = fill(0, numsys.Nbus)
        for (k, island) in enumerate(islands)
            for i in island
                islandsWhere[i] = k
            end
        end

        ########## Tie buses and branches ##########
        tie_branch = copy(branch)
        for i = 1:numsys.Nbranch
            if islandsWhere[from[i]] == islandsWhere[to[i]]
                tie_branch[i] = 0
            end
        end
        tie_bus = fill(0, numsys.Nbus)
        for i in tie_branch
            if i != 0
                tie_bus[from[i]] = from[i]
                tie_bus[to[i]] = to[i]
            end
        end

        ########## Merge flow islands ##########
        inj = copy(busPi); inj = inj[tie_bus[busPi] .!= 0]
        merge = 1; current = 0
        for (k, i) in enumerate(inj)
            if onPi[i] == 0
                inj[k] = 0
            end
        end
        filter!(x->x!=0, inj)

        @inbounds while merge != 0
            merge = 1
            for (k, i) in enumerate(inj)
                current = islandsWhere[i]
                conection = Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                conection = Ybus.rowval[conection]
                conection = setdiff(conection, islands[current])
                toOther = islandsWhere[conection]
                if !(isempty(toOther)) && all(y->y==toOther[1], toOther)
                    merge = 2
                    islands[current] = [islands[current]; islands[toOther[1]]]
                    islandsWhere[islands[toOther[1]]] .= current
                    islands[toOther[1]] = []
                    deleteat!(inj, k)
                end
            end
            if merge == 1 || size(islands, 1) == 1
                merge = 0
            end
        end
        empty = isempty.(islands)
        deleteat!(islands, empty)
        Nisland = size(islands, 1)

        islandsWhere = fill(0, numsys.Nbus)
        for (k, island) in enumerate(islands)
            for i in island
                islandsWhere[i] = k
            end
        end

        ########## New tie buses and branches ##########
        tie_branch = copy(branch)
        for i = 1:numsys.Nbranch
            if islandsWhere[from[i]] == islandsWhere[to[i]]
                tie_branch[i] = 0
            end
        end
        tie_bus = fill(0, numsys.Nbus)
        for i in tie_branch
            if i != 0
                tie_bus[from[i]] = from[i]
                tie_bus[to[i]] = to[i]
            end
        end

        ########## Reduced Jacobian ##########
        Nreduced = Nvol
        for i = 1:num.legacyNi
            if onPi[i] == 1 && tie_bus[busPi[i]] != 0
                Nreduced += 1
            end
        end
        idx = fill(0, Nreduced)
        N = Nflow; cnt = 1
        @inbounds for i = 1:num.legacyNi
            if onPi[i] == 1
                N += 1
                if tie_bus[busPi[i]] != 0
                    idx[cnt] = N
                    cnt += 1
                end
            end
        end
        @inbounds for i = 1:num.pmuNv
            if onTi[i] == 1
                N += 1
                idx[cnt] = N
                cnt += 1
            end
        end
        Jt = copy(transpose(jacobian))
        col = fill(0, numsys.Nbus)
        for (k, island) in enumerate(islands)
            for j in island
                col[j] = k
            end
        end
        N = 0
        for (k, i) in enumerate(idx)
            for j in Jt.colptr[i]:(Jt.colptr[i + 1] - 1)
                N += 1
            end
        end
        rown = fill(0, N); coln = fill(0, N); valn = fill(0.0, N)
        cnt = 1
        for (k, i) in enumerate(idx)
            for j in Jt.colptr[i]:(Jt.colptr[i + 1] - 1)
                rown[cnt] = k
                coln[cnt] = col[Jt.rowval[j]]
                valn[cnt] = Jt.nzval[j]
                cnt += 1
            end
        end
        Wb = sparse(rown, coln, valn, length(idx), Nisland)

       ########## Pseudo-measurements jacobian ##########
       Nelement = 0; Nmeasurn = 0
       Nflown = 0; Ninjn = 0; Nvoln = 0;
       if settings.observe[:Pij] != 0
            @inbounds for i = 1:num.legacyNf
                if onPij[i] == 0 && tie_branch[branchPij[i]] != 0
                   Nelement += 2; Nmeasurn += 1; Nflown += 1
                end
            end
        end
        if settings.observe[:Pi] != 0
            @inbounds for i = 1:num.legacyNi
                if onPi[i] == 0 && tie_bus[busPi[i]] != 0
                    Nmeasurn += 1; Ninjn += 1
                    for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                        Nelement += 1
                    end
                end
            end
        end
        if settings.observe[:Ti] != 0
            @inbounds for i = 1:num.pmuNv
                if onTi[i] == 0 && tie_bus[busTi[i]] != 0
                    Nelement += 1; Nmeasurn += 1; Nvoln += 1
                end
            end
        end

        rown = fill(0, Nelement)
        coln = similar(rown)
        jacn = fill(0.0, Nelement)
        idx = fill(0, Nmeasurn)
        meann = fill(0.0, Nmeasurn)
        weightn = similar(meann)
        index = 1; rowindex = 1
        Xflown = fill(0, Nflown, 2); Xinjn = fill(0, Ninjn, 2); Xvoln = fill(0, Nvoln, 2)
        if settings.observe[:Pij] != 0
            @inbounds for i = 1:num.legacyNf
                if onPij[i] == 0 && tie_branch[branchPij[i]] != 0
                    rown[index] = rowindex
                    coln[index] = fromPij[i]
                    jacn[index] = admitance[branchPij[i]]
                    index += 1
                    rown[index] = rowindex
                    coln[index] = toPij[i]
                    jacn[index] = -admitance[branchPij[i]]

                    meann[rowindex] = meanPij[i] - transShift[branchPij[i]] * (pi / 180)
                    weightn[rowindex] = 1 / settings.observe[:Pij]
                    idx[rowindex] = rowindex

                    Xflown[rowindex, 1] = i; Xflown[rowindex, 2] = rowindex
                    index += 1; rowindex += 1
                end
            end
        end

        cnt = 1
        if settings.observe[:Pi] != 0
            for i = 1:num.legacyNi
                if onPi[i] == 0 && tie_bus[busPi[i]] != 0
                    for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                        rown[index] = rowindex
                        coln[index] = Ybus.rowval[j]
                        jacn[index] = Ybus.nzval[j]
                        index += 1
                    end

                    meann[rowindex] = meanPi[i] - Pshift[i]
                    weightn[rowindex] = 1 / settings.observe[:Pi]
                    idx[rowindex] = rowindex

                    Xinjn[cnt, 1] = i; Xinjn[cnt, 2] = rowindex
                    rowindex += 1; cnt += 1
                end
            end
        end

        cnt = 1
        if settings.observe[:Ti] != 0
            @inbounds for i = 1:num.pmuNv
                if onTi[i] == 0 && tie_bus[busTi[i]] != 0
                    rown[index] = rowindex
                    coln[index] = busTi[i]
                    jacn[index] = 1.0

                    meann[rowindex] = meanTi[i] - Tslack * (pi / 180)
                    weightn[rowindex] = 1 / settings.observe[:Ti]
                    idx[rowindex] = rowindex

                    Xvoln[cnt, 1] = i; Xvoln[cnt, 2] = rowindex
                    index += 1; rowindex += 1; cnt += 1
                end
            end
        end
        JpseudoT = sparse(coln, rown, jacn, numsys.Nbus, Nmeasurn)

        ########## Reduced Jacobian ##########
        N = 0
        for (k, i) in enumerate(idx)
            for j in JpseudoT.colptr[i]:(JpseudoT.colptr[i + 1] - 1)
                N += 1
            end
        end
        rown = fill(0, N); coln = fill(0, N); valn = fill(0.0, N)
        cnt = 1
        for (k, i) in enumerate(idx)
            for j in JpseudoT.colptr[i]:(JpseudoT.colptr[i + 1] - 1)
                rown[cnt] = k
                coln[cnt] = col[JpseudoT.rowval[j]]
                valn[cnt] = JpseudoT.nzval[j]
                cnt += 1
            end
        end
        Wc = sparse(rown, coln, valn, length(idx), Nisland)

        ########## Restore observability ##########
        M = [Wb; Wc] * transpose([Wb; Wc])
        F = qr(Matrix(M))
        pseudo = Int64[]
        for i = (Nreduced + 1):(Nreduced + Nmeasurn)
            if abs(F.R[i, i]) > settings.observe[:pivot]
                push!(pseudo, i - Nreduced)
            end
        end
        for i in pseudo
            for j in Xflown[:, 2]
                if i == j
                    onPij[Xflown[j, 1]] = 2
                    variPij[Xflown[j, 1]] = settings.observe[:Pij]
                end
            end
            for j in Xinjn[:, 2]
                if i == j
                    onPi[Xinjn[j, 1]] = 2
                    variPi[Xinjn[j, 1]] = settings.observe[:Pi]
                end
            end
            for j in Xvoln[:, 2]
                if i == j
                    onTi[Xvoln[j, 1]] = 2
                    variTi[Xvoln[j, 1]] = settings.observe[:Ti]
                end
            end
        end

        Npseudo = length(pseudo)
        jacobian = [jacobian; transpose(JpseudoT[:,pseudo])]
        mean = [mean; meann[pseudo]]
        weight = [weight; weight[pseudo]]
    end # nonobserve
#
    return jacobian, mean, weight, Npseudo, islands
end


### View system
function view_dcsystem(system, measurements)
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
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

    return busi, type, Tini,
           branchi, reactance, transTap, transShift, branchOn,
           meanPij, variPij, onPij,
           meanPi, variPi, onPi,
           meanTi, variTi, onTi
end
