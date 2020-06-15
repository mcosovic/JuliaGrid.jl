### Bad data processing
function baddata(settings, numsys, x, z, v, W, G, J, Nmeasure, idx, badsave, rbelow)
    ########## Sparse inverse ##########
    S, L, U, d, p, q, Rs = constructfact(G)
    parent = etree(S)
    R = symbfact(S, parent)
    Gi = sparseinv(L, U, d, p, q, Rs, R)

    ########## Diagonal entries of residual matrix ##########
    JGi = J * Gi
    c = fill(0.0, size(J, 1))
    for i in idx
        c[i[1]] += JGi[i] * J[i]
    end

    ########## Critical data ##########
    xcr = (J' * J) \ (J' * z)
    hcr = J * xcr

    ########## Largest normalized residual ##########
    h = J * x
    rmax = 0.0; idxr = 0
    for i = 1:Nmeasure
        if abs(z[i] - hcr[i]) > settings.bad[:critical]
            rnor = abs(z[i] - h[i]) / sqrt(abs(v[i] - c[i]))
            if rnor > rmax
                idxr = i
                rmax = rnor
            end
        end
    end

    if rmax < settings.bad[:treshold]
        rbelow = false
    end

    if idxr == 0
        println("All measurements are marked as critical, the bad data processing is terminated.")
        rbelow = false
    end

    ########## Remove measurement ##########
    if rbelow
        for i in idx
            if i[1] == idxr
                J[i] = 0.0
            end
        end
        z[idxr] = 0.0
        for i in W.rowval
            if i == idxr
                W.nzval[i] = 0.0
            end
        end
        badsave = [badsave; [idxr rmax]]
    end

    return J, z, W, badsave, rbelow
end


### Observability analysis
function observability_flow(settings, system, numsys, measurements, num, J, Jflow, slack,
        branch, from, to, busPi, onPi, onTi, Ybus, Nvol, Nflow, branchPij, onPij, busTi, fromPij, toPij, admitance,
        mean, weight, meanPij, transShift, Pshift, meanPi, meanTi, Tslack, variPi, variTi, variPij, Npseudo, islands)

        G = transpose(J) * J
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
        M = Jflow' * Jflow
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
        Jt = copy(transpose(J))
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

       ########## Pseudo-measurements Jacobian ##########
       Nelement = 0; Nmeasuren = 0
       Nflown = 0; Ninjn = 0; Nvoln = 0;
       if settings.observe[:Pij] != 0
            @inbounds for i = 1:num.legacyNf
                if onPij[i] == 0 && tie_branch[branchPij[i]] != 0
                   Nelement += 2; Nmeasuren += 1; Nflown += 1
                end
            end
        end
        if settings.observe[:Pi] != 0
            @inbounds for i = 1:num.legacyNi
                if onPi[i] == 0 && tie_bus[busPi[i]] != 0
                    Nmeasuren += 1; Ninjn += 1
                    for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                        Nelement += 1
                    end
                end
            end
        end
        if settings.observe[:Ti] != 0
            @inbounds for i = 1:num.pmuNv
                if onTi[i] == 0 && tie_bus[busTi[i]] != 0
                    Nelement += 1; Nmeasuren += 1; Nvoln += 1
                end
            end
        end

        rown = fill(0, Nelement)
        coln = similar(rown)
        jacn = fill(0.0, Nelement)
        idx = fill(0, Nmeasuren)
        meann = fill(0.0, Nmeasuren)
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
        JpseudoT = sparse(coln, rown, jacn, numsys.Nbus, Nmeasuren)

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
        for i = (Nreduced + 1):(Nreduced + Nmeasuren)
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
        J = [J; transpose(JpseudoT[:,pseudo])]
        mean = [mean; meann[pseudo]]
        weight = [weight; weight[pseudo]]
    end # nonobserve

    return J, mean, weight, Npseudo, islands
end
