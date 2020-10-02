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
    @inbounds for i = 1:Nmeasure
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
        @inbounds for i in idx
            if i[1] == idxr
                J[i] = 0.0
            end
        end
        z[idxr] = 0.0
        @inbounds for i in W.rowval
            if i == idxr
                W.nzval[i] = 0.0
            end
        end
        badsave = [badsave; [idxr rmax]]
    end

    return J, z, W, badsave, rbelow
end # baddata


### Observability restoration based on the Gram matrix associated to a reduced network and measurement set
function restorationgram(system, settings, numsys, num, measurements, islands, Nisland, J, mean, weight,
    Ybus, slack, Tslack, branch, from, to, fromPij, toPij, busPi, branchPij, busTi, onPi, onPij, onTi, Nvol, Nflow,
    meanPij, meanPi, meanTi, variPi, variTi, variPij, admitance, Gshunt, transShift, Pshift)
    ######### Bus-islands ##########
    islandsWhere = fill(0, numsys.Nbus)
    @inbounds for (k, island) in enumerate(islands)
        for i in island
            islandsWhere[i] = k
        end
    end

    ########## Tie buses and branches ##########
    tie_branch = copy(branch)
    @inbounds for i = 1:numsys.Nbranch
        if islandsWhere[from[i]] == islandsWhere[to[i]]
            tie_branch[i] = 0
        end
    end

    tie_bus = fill(0, numsys.Nbus)
    @inbounds for i in tie_branch
        if i != 0
            tie_bus[from[i]] = from[i]
            tie_bus[to[i]] = to[i]
        end
    end

    ########## Reduced Jacobian Wb ##########
    Nreduced = Nvol
    @inbounds for i = 1:num.legacyNi
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
    @inbounds for (k, island) in enumerate(islands)
        for j in island
            col[j] = k
        end
    end
    N = 0
    @inbounds for (k, i) in enumerate(idx)
        for j in Jt.colptr[i]:(Jt.colptr[i + 1] - 1)
            N += 1
        end
    end
    rown = fill(0, N); coln = fill(0, N); valn = fill(0.0, N)
    cnt = 1
    @inbounds for (k, i) in enumerate(idx)
        for j in Jt.colptr[i]:(Jt.colptr[i + 1] - 1)
            rown[cnt] = k
            coln[cnt] = col[Jt.rowval[j]]
            valn[cnt] = Jt.nzval[j]
            cnt += 1
        end
    end
    Wb = sparse(rown, coln, valn, length(idx), Nisland)

    ########## Pseudo-measurements Jacobian Wp ##########
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

    rown = fill(0, Nelement); coln = similar(rown); jacn = fill(0.0, Nelement)
    meann = fill(0.0, Nmeasuren); weightn = similar(meann)
    idx = fill(0, Nmeasuren); index = 1; rowindex = 1
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

                if fromPij[i] == from[branchPij[i]]
                    meann[rowindex] = meanPij[i] + transShift[branchPij[i]] * (pi / 180)  * admitance[branchPij[i]]
                else
                    meann[rowindex] = meanPij[i] - transShift[branchPij[i]] * (pi / 180) * admitance[branchPij[i]]
                end

                weightn[rowindex] = 1 / settings.observe[:Pij]
                idx[rowindex] = rowindex

                Xflown[rowindex, 1] = i; Xflown[rowindex, 2] = rowindex
                index += 1; rowindex += 1
            end
        end
    end

    cnt = 1
    if settings.observe[:Pi] != 0
        @inbounds for i = 1:num.legacyNi
            if onPi[i] == 0 && tie_bus[busPi[i]] != 0
                for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                    rown[index] = rowindex
                    coln[index] = Ybus.rowval[j]
                    jacn[index] = Ybus.nzval[j]
                    index += 1
                end

                meann[rowindex] = meanPi[i] - Pshift[i] - Gshunt[i] / system.basePower
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
    JpsT = sparse(coln, rown, jacn, numsys.Nbus, Nmeasuren)

    ########## Reduced Jacobian Wc ##########
    N = 0
    @inbounds for (k, i) in enumerate(idx)
        for j in JpsT.colptr[i]:(JpsT.colptr[i + 1] - 1)
            N += 1
        end
    end
    rown = fill(0, N); coln = fill(0, N); valn = fill(0.0, N)
    cnt = 1
    @inbounds for (k, i) in enumerate(idx)
        for j in JpsT.colptr[i]:(JpsT.colptr[i + 1] - 1)
            rown[cnt] = k
            coln[cnt] = col[JpsT.rowval[j]]
            valn[cnt] = JpsT.nzval[j]
            cnt += 1
        end
    end
    Wp = sparse(rown, coln, valn, length(idx), Nisland)

    ########## Restore observability ##########
    M = [Wb; Wp]
    M = M * M'
    F = qr(Matrix(M))
    R = F.R

    pseudo = Int64[]
    @inbounds for i = (Nreduced + 1):(Nreduced + Nmeasuren)
        if abs(R[i, i]) > settings.observe[:pivot]
            push!(pseudo, i - Nreduced)
        end
    end
    @inbounds for i in pseudo
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
    J = [J; transpose(JpsT[:, pseudo])]
    mean = [mean; meann[pseudo]]
    weight = [weight; weightn[pseudo]]

    return J, mean, weight, Npseudo
end # restorationgram


### Gaussian belief propagation observability restoration
function restorationbp(system, settings, numsys, num, measurements, islands, Nisland, J, mean, weight,
    Ybus, branch, from, to, busPi, onPi, meanPi, variPi, Pshift, Gshunt)
    ######### Bus-islands ##########
    islandsWhere = fill(0, numsys.Nbus)
    @inbounds for (k, island) in enumerate(islands)
        for i in island
            islandsWhere[i] = k
        end
    end

    ######### Tie buses and branches ##########
    tie_branch = copy(branch)
    @inbounds for i = 1:numsys.Nbranch
        if islandsWhere[from[i]] == islandsWhere[to[i]]
            tie_branch[i] = 0
        end
    end
    filter!(x->x!=0, tie_branch)

    tie_bus = fill(0, numsys.Nbus)
    @inbounds for i in tie_branch
        tie_bus[from[i]] = from[i]
        tie_bus[to[i]] = to[i]
    end

    ######### Tie real-time measurements and pseudo-measurements ##########
    Ntie = 0; Neletie = 0
    @inbounds for i = 1:num.legacyNi
        if tie_bus[busPi[i]] != 0
            Ntie += 1
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                Neletie += 1
            end
        end
    end

    rowtie = fill(0, Neletie); coltie = similar(rowtie); jactie = fill(0.0, Neletie); idx = fill(0, Ntie);
    meantie = fill(0.0, Ntie); weighttie = similar(meantie)
    injbus = fill(0, Ntie); incidence = fill(false, numsys.Nbus); pseudo = Int64[]
    Nreal = 0; index = 1; rowindex = 1
    @inbounds for i = 1:num.legacyNi
        if tie_bus[busPi[i]] != 0
            for j in Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
                rowtie[index] = rowindex
                coltie[index] = Ybus.rowval[j]
                jactie[index] = Ybus.nzval[j]
                incidence[Ybus.rowval[j]] = true
                index += 1
            end
            meantie[rowindex] = meanPi[i] - Pshift[i] - Gshunt[i] / system.basePower
            weighttie[rowindex] = 1 / variPi[i]
            idx[rowindex] = rowindex
            injbus[rowindex] = tie_bus[busPi[i]]

            if onPi[i] == 0
                push!(pseudo, rowindex)
            else
                Nreal += 1
            end
            rowindex += 1
        end
    end
    JtieT = sparse(coltie, rowtie, jactie, numsys.Nbus, Ntie)

    ######### Reduce matrix ##########
    N = 0
    @inbounds for (k, i) in enumerate(idx)
        for j in JtieT.colptr[i]:(JtieT.colptr[i + 1] - 1)
            N += 1
        end
    end

    col = fill(0, numsys.Nbus)
    @inbounds for (k, island) in enumerate(islands)
        for j in island
            col[j] = k
        end
    end

    rown = fill(0, N); coln = fill(0, N); valn = fill(0.0, N); cnt = 1
    @inbounds for (k, i) in enumerate(idx)
        for j in JtieT.colptr[i]:(JtieT.colptr[i + 1] - 1)
            rown[cnt] = k
            coln[cnt] = col[JtieT.rowval[j]]
            valn[cnt] = JtieT.nzval[j]
            cnt += 1
        end
    end
    Mt = sparse(coln, rown, valn, Nisland, length(idx))

    ########### Factor graph data ##########
    Nvar, Nfac = size(Mt); Nlink = nnz(Mt)
    Vvar_fac, Wfac_var, to_fac, to_var, colptr, rowptr, idxT, row, col, links = factorgraph(Mt, Nvar, Nfac, Nlink, Nfac)
    Wdir = fill(1e-120, Nvar); Vind = fill(1.0, Nfac); Vind[pseudo] .= 1e120

    ######### Pass messages from singly-connected factor nodes to all indirect links ##########
    @inbounds for i = 1:Nvar
        for j in colptr[i]:(colptr[i + 1] - 1)
            k = to_fac[j]
            Vvar_fac[k] = 1 / Wdir[i]
        end
    end

     ########## Inference ##########
    need = Nisland - 1 - Nreal; pass = 1; bppseudo = Int64[]; residual = 0.0; pre = 0.0; pseudom = Int64[]
    while need > 0
        on = pseudo[pass]
        Wdir[links[on][1]] = 1e120
        Vind[on] = 1

        for iter = 1:settings.observe[:restoreMax]
            @inbounds for i = 1:Nfac
                Vrow = 0.0
                for j in rowptr[i]:(rowptr[i + 1] - 1)
                    Vrow += Vvar_fac[j]
                end
                for j in rowptr[i]:(rowptr[i + 1] - 1)
                    Wfac_var[to_var[j]] = (1) / (Vind[i] + (Vrow -  Vvar_fac[j]))
                end
            end

            @inbounds for i = 1:Nvar
                Wcol = 0.0
                for j in colptr[i]:(colptr[i + 1] - 1)
                    Wcol += Wfac_var[j]
                end
                for j in colptr[i]:(colptr[i + 1] - 1)
                    Vvar_fac[to_fac[j]] = 1 / (Wdir[i] + (Wcol  - Wfac_var[j]))
                end
            end
        end

        residual = Vind[on]
        @inbounds for j in rowptr[on]:(rowptr[on + 1] - 1)
            residual += Vvar_fac[j]
        end

        Wdir[links[on][1]] = 1e-120
        if residual > 1e2
            need -= 1
            push!(bppseudo, injbus[on])
            push!(pseudom, on)
        else
            Vind[on] = 1e120
        end
        pass += 1
    end

    onPi[bppseudo] .= 2
    variPi[bppseudo] .= settings.observe[:Pi]

    J = [J; transpose(JtieT[:, pseudom])]
    mean = [mean; meantie[pseudom]]
    weight = [weight; weighttie[pseudom]]

    return J, mean, weight, Nisland - 1 - Nreal
end # restorationbp


### Flow islands defined by active power flow measurements
function islandsflow(Jflow)
    M = SimpleWeightedGraph(Jflow' * Jflow)
    islandsFlow = connected_components(M)
    NislandsFlow = size(islandsFlow, 1)

    return islandsFlow, NislandsFlow
end # islandsflow


### Gaussian belief propagation island detection
function islandsbp(settings, numsys, J, bus, islandsFlow, NislandsFlow)
    ########## Independent system of equations ##########
    Jt = copy(J')
    Ht = independentset(Jt)
    bus_indecies = copy(bus)

    ########## Factor graph data ##########
    Nvar, Nfac = size(Ht); Nlink = 0; Nind = 0
    Wvirtual = 0.0; Wdirect = 1e240
    Wdir = fill(Wvirtual, Nvar)

    ########## Find islands with isolated buses ##########
    variable_isolate = fill(0, Nvar)
    @inbounds for i = 1:Nfac
        for j in Ht.colptr[i]:(Ht.colptr[i + 1] - 1)
            variable_isolate[Ht.rowval[j]] += 1
        end
        var_in_column = Ht.colptr[i + 1] - Ht.colptr[i]
        if var_in_column == 1
            variable_isolate[Ht.rowval[Ht.colptr[i]]] -= 1
        else
            Nlink += var_in_column
            Nind += 1
        end
    end

    ########## Set probe nodes ##########
    islandsWhere = fill(0, numsys.Nbus)
    numvar = fill(0, NislandsFlow)
    @inbounds for (k, island) in enumerate(islandsFlow)
        for i in island
            islandsWhere[i] = k
            numvar[k] += 1
        end
    end
    numvar_max = maximum(numvar)

    if numvar_max > 1
        setprobe = findfirst(a -> a == numvar_max, numvar)
        @inbounds for i in islandsFlow[setprobe]
            Wdir[i] = Wdirect
        end
    else
        @inbounds for i = 1:Nvar
            if variable_isolate[i] != 0
                Wdir[i] = Wdirect
                break
            end
        end
    end

    ########## Find Islands ##########
    detection = true; previous = 0.0; islands = [Int64[]]
    iter_max = settings.observe[:islandMax]; breaks = settings.observe[:islandBreak]
    stop = settings.observe[:islandStop]; treshold = settings.observe[:islandTreshold];
    while detection
        ########## Factor graph data ##########
        Vvar_fac, Wfac_var, to_fac, to_var, colptr, rowptr, idxT, row, col = factorgraph(Ht, Nvar, Nfac, Nlink, Nind)

        ########## Inference ##########
        Xbp = fill(0.0, Nvar)
        @inbounds for iter = 1:iter_max
            for i = 1:Nind
                Vrow = 0.0
                for j in rowptr[i]:(rowptr[i + 1] - 1)
                    Vrow += Vvar_fac[j]
                end
                for j in rowptr[i]:(rowptr[i + 1] - 1)
                    Wfac_var[to_var[j]] = 1 / (Vrow - Vvar_fac[j] + eps(Float64))
                end
            end

            previous = 0.0
            for i = 1:Nvar
                Wcol = 0.0
                for j in colptr[i]:(colptr[i + 1] - 1)
                    Wcol += Wfac_var[j]
                end
                for j in colptr[i]:(colptr[i + 1] - 1)
                    Vvar_fac[to_fac[j]] = 1 / (Wcol + Wdir[i] - Wfac_var[j] + eps(Float64))
                end
                temp = 1 / (Wcol + Wdir[i])
                if temp < 10e30
                    previous = maximum([previous; abs(temp - Xbp[i])])
                end
                Xbp[i] = temp

            end
            if previous < stop && iter > breaks
                break
            end
        end

        ########## Reduce Jacobian ##########
        row = fill(true, Nvar); col = fill(true, Nfac); bip = fill(false, Nvar)
        @inbounds for i in idxT
            if Xbp[i[1]] < treshold
                row[i[1]] = false
                col[i[2]] = false
                bip[i[1]] = true
            end
        end
        Ht = Ht[row, col]
        Nvar, Nfac = size(Ht); Nlink = 0; Nind = 0

        ########## Find island ##########
        observable = bus_indecies[bip]
        unobservable = bus_indecies[.!bip]
        islands = [islands; [observable]]

        deleteat!(bus_indecies, bip)
        if length(bus_indecies) == 0
            break
        end

        ########## Find islands with isolated buses ##########
        variable_isolate = fill(0, Nvar)
        @inbounds for i = 1:Nfac
            for j in Ht.colptr[i]:(Ht.colptr[i + 1] - 1)
                variable_isolate[Ht.rowval[j]] += 1
            end
            var_in_column = Ht.colptr[i + 1] - Ht.colptr[i]
            if var_in_column == 1
                variable_isolate[Ht.rowval[Ht.colptr[i]]] -= 1
            else
                Nlink += var_in_column
                Nind += 1
            end
        end

        ########## Set probe nodes ##########
        unobservable_island = islandsWhere[unobservable]
        setprobe_idx = findfirst(a -> a != 0, variable_isolate)
        if setprobe_idx == nothing
            @inbounds for i in bus_indecies
                islands = [islands; [[i]]]
            end
            break
        end
        setprobe = unobservable_island[setprobe_idx]
        Wdir = fill(Wvirtual, Nvar)
        @inbounds for i = 1:Nvar
            if unobservable_island[i] == setprobe
                Wdir[i] = Wdirect
            end
        end
    end
    deleteat!(islands, 1)
    Nisland = size(islands, 1)

    return islands, Nisland
end # islandsbp


### Topological island detection
function islandstopological(settings, numsys, J, Jflow, Ybus, branch, from, to, busPi, onPi, islands)
    islandsWhere = fill(0, numsys.Nbus)
    @inbounds for (k, island) in enumerate(islands)
        for i in island
            islandsWhere[i] = k
        end
    end

    ########## Tie buses and branches ##########
    tie_branch = copy(branch)
    @inbounds for i = 1:numsys.Nbranch
        if islandsWhere[from[i]] == islandsWhere[to[i]]
            tie_branch[i] = 0
        end
    end
    tie_bus = fill(0, numsys.Nbus)
    @inbounds for i in tie_branch
        if i != 0
            tie_bus[from[i]] = from[i]
            tie_bus[to[i]] = to[i]
        end
    end

    ########## Boundary Injections ##########
    inj = copy(busPi); inj = inj[tie_bus[busPi] .!= 0]
    @inbounds for (k, i) in enumerate(inj)
        if onPi[i] == 0
            inj[k] = 0
        end
    end
    filter!(x->x!=0, inj); filter!(x->x!=0, tie_branch)

    ########## Stage 1: Processing of Individual Boundary Injections ##########
    islands, islandsWhere, inj, tie_branch = topological_merge_pairs(numsys, Ybus, busPi, islands, inj, islandsWhere, tie_branch, from, to)

    ########## Stage K: Processing of a Collection of K Boundary Injection Measurements ##########
    Ninj = length(inj); merge = 1; con = fill(false, numsys.Nbus); island_inj = fill(Int[], Ninj, 1)
    while merge != 0
        for (k, i) in enumerate(inj)
            conection = Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
            con[Ybus.rowval[conection]] .= true
            island_inj[k] = sort(unique(islandsWhere[con]))
            con[Ybus.rowval[conection]] .= false
        end
        merge_index = decision_tree(island_inj)

        if merge_index != false
            merge_islands = []
            for i in merge_index
                for j in island_inj[i]
                    push!(merge_islands, j)
                end
            end
            merge_islands = unique(merge_islands)
            start = merge_islands[1]
            for i = 2:length(merge_islands)
                next = merge_islands[i]
                islands[start] = [islands[start]; islands[next]]
                islands[next] = []
            end
            empty = isempty.(islands)
            deleteat!(islands, empty)
        else
            break
        end

        islandsWhere = fill(0, numsys.Nbus)
        @inbounds for (k, island) in enumerate(islands)
            for i in island
                islandsWhere[i] = k
            end
        end
        @inbounds for (k, i) in enumerate(tie_branch)
            if islandsWhere[from[i]] == islandsWhere[to[i]]
                tie_branch[k] = 0
            end
        end
        tie_bus = fill(0, numsys.Nbus)
        @inbounds for i in tie_branch
            if i != 0
                tie_bus[from[i]] = from[i]
                tie_bus[to[i]] = to[i]
            end
        end
        inj = tie_bus[inj]
        filter!(x->x!=0, inj); filter!(x->x!=0, tie_branch)

        islands, islandsWhere, inj, tie_branch = topological_merge_pairs(numsys, Ybus, busPi, islands, inj, islandsWhere, tie_branch, from, to)

        Ninj = length(inj)
        con = fill(false, numsys.Nbus)
        island_inj = fill(Int[], Ninj, 1)
    end
    empty = isempty.(islands)
    deleteat!(islands, empty)
    Nisland = size(islands, 1)

    return islands, Nisland
end # islandstopological

function topological_merge_pairs(numsys, Ybus, busPi, islands, inj, islandsWhere, tie_branch, from, to)
    merge = 1; current = 0
    con = fill(false, numsys.Nbus)
    flag = false
    @inbounds while merge != 0
        merge = 1
        for (k, i) in enumerate(inj)
            current = islandsWhere[i]
            conection = Ybus.colptr[busPi[i]]:(Ybus.colptr[busPi[i] + 1] - 1)
            con[Ybus.rowval[conection]] .= true
            con[islands[current]] .= false
            toOther = islandsWhere[con]
            con[Ybus.rowval[conection]] .= false
            if !(isempty(toOther)) && all(y -> y == toOther[1], toOther)
                merge = 2
                islands[current] = [islands[current]; islands[toOther[1]]]
                islandsWhere[islands[toOther[1]]] .= current
                islands[toOther[1]] = []
                deleteat!(inj, k)
                flag = true
            end
        end
        if merge == 1 || size(islands, 1) == 1
            merge = 0
        end
    end
    empty = isempty.(islands)
    deleteat!(islands, empty)

    if flag
        islandsWhere = fill(0, numsys.Nbus)
        @inbounds for (k, island) in enumerate(islands)
            for i in island
                islandsWhere[i] = k
            end
        end

        @inbounds for (k, i) in enumerate(tie_branch)
            if islandsWhere[from[i]] == islandsWhere[to[i]]
                    tie_branch[k] = 0
            end
        end
        tie_bus = fill(0, numsys.Nbus)
        @inbounds for i in tie_branch
            if i != 0
                tie_bus[from[i]] = from[i]
                tie_bus[to[i]] = to[i]
            end
        end
        inj = tie_bus[inj]
        filter!(x->x!=0, inj)
        filter!(x->x!=0, tie_branch)
    end

    return islands, islandsWhere, inj, tie_branch
end

function combinations_recursive(position, value, result, max_n, k, accumulator)
    for i = value:max_n
        result[position] = position + i
        if position < k
            combinations_recursive(position + 1, i, result, max_n, k, accumulator)
        else
            push!(accumulator, copy(result))
        end
    end
end

function combinations(n, k)
    max_n = n - k
    accumulator = []
    result = zeros(Int, k)
    combinations_recursive(1, 0, result, max_n, k, accumulator)

    return accumulator
end

function check(measurments, indicies, total, required)
    appeared = zeros(Bool, total)
    for index in indicies
        for island in measurments[index]
            appeared[island] = true
        end
    end

    return sum(appeared) == required
end

function decision_tree(measurments)
    total_islands = 0
    for measurment in measurments
        for island in measurment
            total_islands = max(total_islands, island)
        end
    end

    for t = 2:length(measurments)
        total_combinations = combinations(length(measurments), t)
        for combination in total_combinations
            if check(measurments, combination, total_islands , t + 1)
                return combination
            end
        end
    end

    return false
end


### Observability analysis using the nodal variable formulation without the restore routine (on hold util Julia 1.6 releases)
function islandsnodal(numsys, num, settings, J, bus, branch, onPij, branchPij, onPi, busPi, from, to, onTi, busTi)
    ########## Find irrelevant branches ##########
    branch_non = fill(0, numsys.Nbranch)

    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            branch_non[branchPij[i]] = 1
        end
    end
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            for j = 1:numsys.Nbranch
                if busPi[i] == from[j] || busPi[i] == to[j]
                    branch_non[j] = 1
                end
            end
        end
    end
    @inbounds for i = 1:num.pmuNv
        if onTi[i] == 1
            for j = 1:numsys.Nbranch
                if busTi[i] == from[j] || busTi[i] == to[j]
                    branch_non[j] = 1
                end
            end
        end
    end
    branch_irrelevant = copy(branch_non)

    ########## Branch-bus incidence matrix ##########
    row = collect(1:numsys.Nbranch)
    A = sparse([row; row], [from; to], [branch_non; -branch_non], numsys.Nbranch, numsys.Nbus)

    ########## Initialize position for angle pseudo-measurements ##########
    pseudo = sparse(bus, bus, zeros(numsys.Nbus), numsys.Nbus, numsys.Nbus)
    H = [J; pseudo]
    Ht = copy(transpose(H))
    rowsdel = collect(1:Nmeasure)

    ########## Branches and incident measurements ##########
    branch_measure = [Int64[] for i in 1:numsys.Nbranch]
    cnt = 0
    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            cnt += 1
            for j = 1:numsys.Nbranch
                if branchPij[i] == branch[j]
                    push!(branch_measure[j], cnt)
                end
            end
        end
    end
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            cnt += 1
            for j = 1:numsys.Nbranch
                if from[j] == busPi[i] || to[j] == busPi[i]
                    push!(branch_measure[j], cnt)
                end
            end
        end
    end

    Pf = 1
    @inbounds while sum(Pf) != 0
        ########## Find zero pivots and replace them with angle pseudo-measurements ##########
        G = transpose(H) * H
        F = qr(Matrix(G))
        D = F.R

        whereIs = Int64[]
        for i = 1:numsys.Nbus
            if abs(D[i, i]) <= 1e-5
                push!(whereIs, i)
            end
        end

        if isempty(whereIs)
            break
        end

        t = fill(0.0, numsys.Nbus)
        for (k, i) in enumerate(whereIs)
            H[Nmeasure + i, i] = 1.0
            t[i] = k
        end

        ########## Branch flow estimates ##########
        T = (transpose(H) * H) \ t
        Pf = abs.(A * T) .>= 1e-5
        for i = 1:numsys.Nbus
            for j in A.colptr[i]:(A.colptr[i + 1] - 1)
                if Pf[A.rowval[j]] == 1
                    A[A.rowval[j], i] = 0
                    branch_non[A.rowval[j]] = 0
                end
            end
        end

        ########## Remove all measurements incidence to unobservable branches ##########
        for i = 1:numsys.Nbranch
            if Pf[i] == 1
                for k in branch_measure[i]
                    if rowsdel[k] !=0
                        rowsdel[k] = 0
                        for j in Ht.colptr[k]:(Ht.colptr[k + 1] - 1)
                            H[k, Ht.rowval[j]] = 0.0
                        end
                    end
                end
            end
        end
        for (k, i) in enumerate(whereIs)
            H[Nmeasure + i, i] = 0.0
        end
    end

    islands = connected_components(SimpleGraph(A' * A))

    return islands
end # islandsnodal
