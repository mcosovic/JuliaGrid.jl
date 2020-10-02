struct StateEstimationNonlinear
    main::Array{Float64,2}
    flow::Array{Float64,2}
    estimate::Array{Float64,2}
    error::Array{Float64,1}
    # baddata::Array{Float64,2}
    # observability::Array{Array{Int64,1},1}
end


#### Non-linear state estimation
function runacse(system, measurements, num, numsys, settings, info)
    printstyled("Algorithm: Non-linear state estimation\n"; bold = true)

    ########## Pre-processing ##########
    busi, type, Gshunt, Bshunt, Vini, Tini,
    branchi, resistance, reactance, charging, transTap, transShift, branchOn,
    meanPij, variPij, onPij, meanQij, variQij, onQij,
    meanIij, variIij, onIij,
    meanPi, variPi, onPi, meanQi, variQi, onQi,
    meanVi, variVi, onVi,
    meanIijp, variIijp, onIijp, meanDijp, variDijp, onDijp,
    meanVip, variVip, onVip, meanTip, variTip, onTip = read_nonlinearsystem(system, measurements)

    main = fill(0.0, numsys.Nbus, 7)
    flow =  fill(0.0, numsys.Nbranch, 14)
    Va, Vm, Pinj, Qinj, Pshunt, Qshunt,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji = write_acsystem(system, numsys, main, flow)

  algtime = @elapsed begin
    ########## Convert in integers ##########
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])

    branchiFlow = convert(Array{Int64,1}, measurements.legacyFlow[:, 1])
    fromiFlow = convert(Array{Int64,1}, measurements.legacyFlow[:, 2])
    toiFlow = convert(Array{Int64,1}, measurements.legacyFlow[:, 3])
    branchiCurrent = convert(Array{Int64,1}, measurements.legacyCurrent[:, 1])
    fromiCurrent = convert(Array{Int64,1}, measurements.legacyCurrent[:, 2])
    toiCurrent = convert(Array{Int64,1}, measurements.legacyCurrent[:, 3])
    busiInjection = convert(Array{Int64,1}, measurements.legacyInjection[:, 1])
    busiVoltage = convert(Array{Int64,1}, measurements.legacyVoltage[:, 1])

    branchiCurrentPh = convert(Array{Int64,1}, measurements.pmuCurrent[:, 1])
    fromiCurrentPh = convert(Array{Int64,1}, measurements.pmuCurrent[:, 2])
    toiCurrentPh = convert(Array{Int64,1}, measurements.pmuCurrent[:, 3])
    busiVoltagePh = convert(Array{Int64,1}, measurements.pmuVoltage[:, 1])

    ########## Numbering and slack bus ##########
    bus = collect(1:numsys.Nbus)
    branch = collect(1:numsys.Nbranch)

    newnumbering = false; Tslack = 0.0; slack = 0
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

    from = renumber(fromi, busi, bus, newnumbering)
    to = renumber(toi, busi, bus, newnumbering)
    branchFlow = renumber(branchiFlow, branchi, branch, newnumbering)
    fromFlow = renumber(fromiFlow, busi, bus, newnumbering)
    toFlow = renumber(toiFlow, busi, bus, newnumbering)
    branchCurrent = renumber(branchiCurrent, branchi, branch, newnumbering)
    fromCurrent = renumber(fromiCurrent, busi, bus, newnumbering)
    toCurrent = renumber(toiCurrent, busi, bus, newnumbering)
    busInjection = renumber(busiInjection, busi, bus, newnumbering)
    busVoltage = renumber(busiVoltage, busi, bus, newnumbering)

    branchCurrentPh = renumber(branchiCurrentPh, branchi, branch, newnumbering)
    fromCurrentPh = renumber(fromiCurrentPh, busi, bus, newnumbering)
    toCurrentPh = renumber(toiCurrentPh, busi, bus, newnumbering)
    busVoltagePh = renumber(busiVoltagePh, busi, bus, newnumbering)

    ########## Ybus matrix ##########
    Ybus, YbusT, Ytt, Yff, Yft, Ytf, admittance, tap, shunt = ybusac(system, numsys, bus, from, to, branchOn,
        Gshunt, Bshunt, resistance, reactance, charging, transTap, transShift)

    ########## Number of Jacobian elements and measurements ##########
    Npij = 0; Nqij = 0; Nepij = 0; Neqij = 0
    @inbounds for i = 1:num.legacyNf
        if onPij[i] == 1
            Npij += 1; Nepij += 4
        end
        if onQij[i] == 1
            Nqij += 1; Neqij += 4
        end
    end
    Niij = 0; Neiij = 0
    @inbounds for i = 1:num.legacyNc
        if onIij[i] == 1
            Niij += 1; Neiij += 4
        end
    end
    Niijp = 0; Neiijp = 0; Ndijp = 0; Nedijp = 0
    @inbounds for i = 1:num.pmuNc
        if onIijp[i] == 1
            Niijp += 1; Neiijp += 4
        end
        if onDijp[i] == 1
            Ndijp += 1; Nedijp += 4
        end
    end
    Npi = 0; Nepi = 0; Nqi = 0; Neqi = 0
    @inbounds for i = 1:num.legacyNi
        if onPi[i] == 1
            Npi += 1
            for j in Ybus.colptr[busInjection[i]]:(Ybus.colptr[busInjection[i] + 1] - 1)
                Nepi += 2
            end
        end
        if onQi[i] == 1
            Nqi += 1
            for j in Ybus.colptr[busInjection[i]]:(Ybus.colptr[busInjection[i] + 1] - 1)
                Neqi += 2
            end
        end
    end
    Nvi = 0
    @inbounds for i = 1:num.legacyNv
        if onVi[i] == 1
            Nvi += 1
        end
    end
    Nvip = 0; Nti = 0
    @inbounds for i = 1:num.pmuNv
        if onVip[i] == 1
            Nvip += 1
        end
        if onTip[i] == 1
            Nti += 1
        end
    end

    Npair = Npij + Nqij + Niij + Niijp + Ndijp
    Nepair = Nepij + Neqij + Neiij + Neiijp + Nedijp
    Nmeasure = Npair + Npi + Nqi + Nvi + Nvip + Nti
    Nelement = Nepair + Nepi + Neqi + Nvi + Nvip + Nti

    ########## Initialize Jacobian and measurement data ##########
    mean = fill(0.0, Nmeasure); weight = similar(mean)
    row = fill(0, Nelement); col = similar(row)
    code = fill(0, Npair); ij = fill(0, Npair, 2)
    fromto = fill(false, Npair); branchid = similar(code)

    index = 1; rowidx = 1
    indexN = Nepij + 1; rowidxN = Npij + 1
    for i = 1:num.legacyNf
        if onPij[i] == 1
            branchid[rowidx] = branchFlow[i]
            if from[branchFlow[i]] == fromFlow[i]
                fromto[rowidx] = true
            end
            code[rowidx] = 1; ij[rowidx, :] = [fromFlow[i], toFlow[i]]

            row[index] = rowidx; col[index] = fromFlow[i]; index += 1
            row[index] = rowidx; col[index] = toFlow[i]; index += 1
            row[index] = rowidx; col[index] = fromFlow[i] + numsys.Nbus; index += 1
            row[index] = rowidx; col[index] = toFlow[i] + numsys.Nbus; index += 1

            mean[rowidx] = meanPij[i]; weight[rowidx] = 1 / variPij[i]
            rowidx += 1

        end
        if onQij[i] == 1
            branchid[rowidxN] = branchFlow[i]
            if from[branchFlow[i]] == fromFlow[i]
                fromto[rowidxN] = true
            end
            code[rowidxN] = 2; ij[rowidxN, :] = [fromFlow[i], toFlow[i]]

            row[indexN] = rowidxN; col[indexN] = fromFlow[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toFlow[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = fromFlow[i] + numsys.Nbus; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toFlow[i] + numsys.Nbus; indexN += 1

            mean[rowidxN] = meanQij[i]; weight[rowidxN] = 1 / variQij[i]
            rowidxN += 1
        end
    end
    for i = 1:num.legacyNc
        if onIij[i] == 1
            branchid[rowidxN] = branchCurrent[i]
            if from[branchCurrent[i]] == fromCurrent[i]
                fromto[rowidxN] = true
            end
            code[rowidxN] = 3; ij[rowidxN, :] = [fromCurrent[i], toCurrent[i]]

            row[indexN] = rowidxN; col[indexN] = fromCurrent[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toCurrent[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = fromCurrent[i] + numsys.Nbus; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toCurrent[i] + numsys.Nbus; indexN += 1

            mean[rowidxN] = meanIij[i]; weight[rowidxN] = 1 / variIij[i]
            rowidxN += 1
        end
    end
    index = copy(indexN); rowidx = copy(rowidxN)
    indexN += Neiijp; rowidxN += Niijp
    for i = 1:num.pmuNc
        if onIijp[i] == 1
            branchid[rowidx] = branchCurrentPh[i]
            if from[branchCurrentPh[i]] == fromCurrentPh[i]
                fromto[rowidx] = true
            end
            code[rowidx] = 3; ij[rowidx, :] = [fromCurrentPh[i], toCurrentPh[i]]

            row[index] = rowidx; col[index] = fromCurrentPh[i]; index += 1
            row[index] = rowidx; col[index] = toCurrentPh[i]; index += 1
            row[index] = rowidx; col[index] = fromCurrentPh[i] + numsys.Nbus; index += 1
            row[index] = rowidx; col[index] = toCurrentPh[i] + numsys.Nbus; index += 1

            mean[rowidx] = meanIijp[i]; weight[rowidx] = 1 / variIijp[i]
            rowidx += 1
        end
        if onDijp[i] == 1
            branchid[rowidxN] = branchCurrentPh[i]
            if from[branchCurrentPh[i]] == fromCurrentPh[i]
                fromto[rowidxN] = true
            end
            code[rowidxN] = 4; ij[rowidxN, :] = [fromCurrentPh[i], toCurrentPh[i]]

            row[indexN] = rowidxN; col[indexN] = fromCurrentPh[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toCurrentPh[i]; indexN += 1
            row[indexN] = rowidxN; col[indexN] = fromCurrentPh[i] + numsys.Nbus; indexN += 1
            row[indexN] = rowidxN; col[indexN] = toCurrentPh[i] + numsys.Nbus; indexN += 1

            mean[rowidxN] = meanDijp[i]; weight[rowidxN] = 1 / variDijp[i]
            rowidxN += 1
        end
    end
    index = copy(indexN); rowidx = copy(rowidxN)
    indexN += Nepi; rowidxN += Npi
    busPi = fill(0, Npi); busQi = fill(0, Nqi); cnt = 1; cnt1 = 1
    for i = 1:num.legacyNi
        if onPi[i] == 1
            busPi[cnt] = busInjection[i]
            for j in Ybus.colptr[busiInjection[i]]:(Ybus.colptr[busiInjection[i] + 1] - 1)
                row[index] = rowidx; col[index] = Ybus.rowval[j]; index += 1
                row[index] = rowidx; col[index] = Ybus.rowval[j] + numsys.Nbus; index += 1
            end
            mean[rowidx] = meanPi[i]; weight[rowidx] = 1 / variPi[i]
            rowidx += 1; cnt += 1
        end
        if onQi[i] == 1
            busQi[cnt1] = busInjection[i]
            for j in Ybus.colptr[busiInjection[i]]:(Ybus.colptr[busiInjection[i] + 1] - 1)
                row[indexN] = rowidxN; col[indexN] = Ybus.rowval[j]; indexN += 1
                row[indexN] = rowidxN; col[indexN] = Ybus.rowval[j] + numsys.Nbus; indexN += 1
            end
            mean[rowidxN] = meanQi[i]; weight[rowidxN] = 1 / variQi[i]
            rowidxN += 1; cnt1 += 1
        end
    end
    busV = fill(0, Nvi + Nvip); cnt = 1
    for i = 1:num.legacyNv
        if onVi[i] == 1
            busV[cnt] = busVoltage[i]
            row[indexN] = rowidxN; col[indexN] = busVoltage[i] + numsys.Nbus

            mean[rowidxN] = meanVi[i]; weight[rowidxN] = 1 / variVi[i]
            indexN += 1; rowidxN += 1; cnt += 1
        end
    end
    index = indexN + Nvip; rowidx = rowidxN + Nvip
    busT = fill(0, Nti); cnt1 = 1
    for i = 1:num.pmuNv
        if onVip[i] == 1
            busV[cnt] = busVoltage[i]
            row[indexN] = rowidxN; col[indexN] = busVoltage[i] + numsys.Nbus

            mean[rowidxN] = meanVip[i]; weight[rowidxN] = 1 / variVip[i]
            indexN += 1; rowidxN += 1; cnt += 1
        end
        if onTip[i] == 1
            busT[cnt1] = busVoltage[i]
            row[index] = rowidx; col[index] = busVoltage[i]

            mean[rowidx] = meanTip[i]; weight[rowidx] = 1 / variTip[i]
            index += 1; rowidx += 1; cnt1 += 1
        end
    end

    ########## Initialize Jacobian and measurement data ##########
    val = [collect(1:Nepair); ones(Nelement - Nepair)]
    Jt = sparse(col, row, val, 2 * numsys.Nbus, Nmeasure)
    F = fill(0.0, Nmeasure)
    lin = convert(Array{Int64}, Jt.nzval)

    ########## Initialize Voltages ##########
    T = copy((pi / 180) * Tini); V = copy(Vini)
    if settings.start[:start] == 2.0
        for i = 1:numsys.Nbus
            T[i] = 0.0; V[i] = 1.0
        end
    elseif settings.start[:start] == 3.0
        for i = 1:numsys.Nbus
            T[i] = (pi / 180) * (settings.start[:Tmin] + (settings.start[:Tmax] - settings.start[:Tmin]) * rand(1)[1])
            V[i] = settings.start[:Vmin] + (settings.start[:Vmax] - settings.start[:Vmin]) * rand(1)[1]
        end
    end

    ######### Slack bus and weighted matrix ##########
    Jt = [Jt sparse([slack], [1], [1.0], 2 * numsys.Nbus, 1)]
    push!(mean, 0.0); push!(weight, 1.0); push!(F, 0.0);
    W = spdiagm(0 => sqrt.(weight))

    ########## Gauss-Newton Algorithm ##########
    No = 0; converged = 0
    while No < settings.maxIter
        No = No + 1
        threshold = 0.0

        for k = 1:Npair
            idx = branchid[k]
            gij = real(admittance[idx]); bij = imag(admittance[idx]); bsi = charging[idx] / 2; tp = 1
            if transTap[idx] != 0
                tp = 1 / transTap[idx]
            end

            if fromto[k]
                Fi = (pi / 180) * transShift[idx]
            else
                Fi = -(pi / 180) * transShift[idx]
            end
            i = ij[k, 1]; j = ij[k, 2]; ang = sincos(T[i] - T[j] - Fi)

            pos = lin[Jt.colptr[k]:(Jt.colptr[k + 1] - 1)]
            if code[k] == 1 || code[k] == 2
                if fromto[k]
                    A = tp^2
                else
                    A = 1.0
                end
                if code[k] == 1
                    F[k] = A * gij * V[i]^2 - tp * (gij * ang[2] + bij * ang[1]) * V[i] * V[j]             # Pᵢⱼ
                    Jt.nzval[pos[1]] = tp * (gij * ang[1] - bij * ang[2]) * V[i] * V[j]                    # ∂Pᵢⱼ / ∂θᵢ
                    Jt.nzval[pos[2]] = - Jt.nzval[pos[1]]                                                  # ∂Pᵢⱼ / ∂θⱼ
                    Jt.nzval[pos[3]] = 2 * A * gij * V[i] - tp * (gij * ang[2] + bij * ang[1]) * V[j]      # ∂Pᵢⱼ / ∂Vᵢ
                    Jt.nzval[pos[4]] = -tp * (gij * ang[2] + bij * ang[1]) * V[i]                          # ∂Pᵢⱼ / ∂Vⱼ
                else
                    F[k] = - A * (bij + bsi) * V[i]^2 - tp * (gij * ang[1] - bij * ang[2]) * V[i] * V[j]              # Qᵢⱼ
                    Jt.nzval[pos[1]] = - tp * (gij * ang[2] + bij * ang[1]) * V[i] * V[j]                             # ∂Qᵢⱼ / ∂θᵢ
                    Jt.nzval[pos[2]] = - Jt.nzval[pos[1]]                                                             # ∂Qᵢⱼ / ∂θⱼ
                    Jt.nzval[pos[3]] = - 2 * A * V[i] * (bij + bsi) - tp * (gij * ang[1] - bij * ang[2]) * V[j]       # ∂Qᵢⱼ / ∂Vᵢ
                    Jt.nzval[pos[4]] = -tp * (gij * ang[1] - bij * ang[2]) * V[i]                                     # ∂Qᵢⱼ / ∂Vⱼ
                end
            else
                Am = (gij^2 + (bij + bsi)^2); Bm = tp^2 * (gij^2 + bij^2); Cm = (gij^2 + bij * (bij + bsi)); Dm = gij * bsi
                if fromto[k]
                    Am = tp^4 * Am; Cm = tp^3 * Cm; Dm = tp^3 * Dm
                else
                    Cm = tp * Cm; Dm = tp * Dm
                end
                F[k] = sqrt(Am * V[i]^2 + Bm * V[j]^2 - 2 * V[i] * V[j] * (Cm * ang[2] - Dm * ang[1]))              # Iᵢⱼ
                if code[k] == 3
                    Jt.nzval[pos[1]] = V[i] * V[j] * (Cm * ang[1] + Dm * ang[2]) / F[k]                             # ∂Iᵢⱼ / ∂θᵢ
                    Jt.nzval[pos[2]] = - Jt.nzval[pos[1]]                                                           # ∂Iᵢⱼ / ∂θⱼ
                    Jt.nzval[pos[3]] = (Am * V[i] - V[j] * (Cm * ang[2] - Dm * ang[1])) / F[k]                      # ∂Iᵢⱼ / ∂Vᵢ
                    Jt.nzval[pos[4]] = (Bm * V[j] - V[i] * (Cm * ang[2] - Dm * ang[1])) / F[k]                      # ∂Iᵢⱼ / ∂Vⱼ
                else
                    Aa = copy(gij); Ba = copy(bij + bsi); Ca = tp * gij; Da = tp * bij
                    if fromto[k]
                        Aa = tp^2 * Aa; Ba = tp^2 * Ba
                    end
                    Jt.nzval[pos[1]] = (Am * V[i]^2 - V[i] * V[j] * (Cm * ang[2] - Dm * ang[1])) / (F[k]^2)                     # ∂βᵢⱼ / ∂θᵢ
                    Jt.nzval[pos[2]] = (Bm * V[j]^2 - V[i] * V[j] * (Cm * ang[2] - Dm * ang[1])) / (F[k]^2)                     # ∂βᵢⱼ / ∂θⱼ
                    Jt.nzval[pos[3]] = -(V[j] * (Cm * ang[1] + Dm * ang[2])) / (F[k]^2)                                         # ∂βᵢⱼ / ∂Vᵢ
                    Jt.nzval[pos[4]] = (V[i] * (Cm * ang[1] + Dm * ang[2])) / (F[k]^2)                                          # ∂βᵢⱼ / ∂Vⱼ
                    Icr = (Aa * cos(T[i]) - Ba * sin(T[i])) * V[i] - (Ca * cos(T[j] + Fi) - Da * sin(T[j] + Fi)) * V[j]
                    Ici = (Aa * sin(T[i]) + Ba * cos(T[i])) * V[i] - (Ca * sin(T[j] + Fi) + Da * cos(T[j] + Fi)) * V[j]
                    F[k] = angle(complex(Icr, Ici))                                                                             # βᵢⱼ
                end
            end
        end

        cnt = Nepair + 1; cnt1 = Npair + 1
        for i in busPi
            N = (Ybus.colptr[i + 1]) - Ybus.colptr[i]
            for k in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                if Ybus.rowval[k] == i
                    I1 = 0; I2 = 0
                    for k in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                        j = Ybus.rowval[k]; Gij = real(Ybus[i, j]); Bij = imag(Ybus[i, j])
                        I1 += V[j] * (-Gij * sin(T[i] - T[j]) + Bij * cos(T[i] - T[j]))         # ∂Pᵢ / ∂θᵢ - sum
                        I2 +=  V[j] * (Gij * cos(T[i] - T[j]) + Bij * sin(T[i] - T[j]))         # ∂Pᵢ / ∂Vᵢ - sum
                    end
                    Jt.nzval[cnt] = V[i] * I1 - V[i]^2 * imag(Ybus[i, i])                       # ∂Pᵢ / ∂θᵢ
                    Jt.nzval[cnt + N] = I2 + V[i] * real(Ybus[i, i])                            # ∂Pᵢ / ∂Vᵢ
                    F[cnt1] = V[i] * I2                                                         # Pᵢ
                    cnt += 1
                else
                    j = Ybus.rowval[k]; Gij = real(Ybus[i, j]); Bij = imag(Ybus[i, j])
                    Jt.nzval[cnt] = V[i] * V[j] * (Gij * sin(T[i] - T[j]) - Bij * cos(T[i] - T[j]))     # ∂Pᵢ / ∂θⱼ
                    Jt.nzval[cnt + N] =  V[i] * (Gij * cos(T[i] - T[j]) + Bij * sin(T[i] - T[j]))       # ∂Pᵢ / ∂Vⱼ
                    cnt += 1
                end
            end
            cnt += N; cnt1 += 1
        end
        for i in busQi
            N = (Ybus.colptr[i + 1]) - Ybus.colptr[i]
            for k in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                if Ybus.rowval[k] == i
                    I1 = 0; I2 = 0
                    for k in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                        j = Ybus.rowval[k]; Gij = real(Ybus[i, j]); Bij = imag(Ybus[i, j])
                        I1 += V[j] * (Gij * cos(T[i] - T[j]) + Bij * sin(T[i] - T[j]))          # ∂Qᵢ / ∂θᵢ - sum
                        I2 +=  V[j] * (Gij * sin(T[i] - T[j]) - Bij * cos(T[i] - T[j]))         # ∂Qᵢ / ∂Vᵢ - sum
                    end
                    Jt.nzval[cnt] = V[i] * I1 - V[i]^2 * real(Ybus[i, i])                       # ∂Qᵢ / ∂θᵢ
                    Jt.nzval[cnt + N] = I2 - V[i] * imag(Ybus[i, i])                            # ∂Qᵢ / ∂Vᵢ
                    F[cnt1] = V[i] * I2                                                         # Qᵢ
                    cnt += 1
                else
                    j = Ybus.rowval[k]; Gij = real(Ybus[i, j]); Bij = imag(Ybus[i, j])
                    Jt.nzval[cnt] = V[i] * V[j] * (-Gij * cos(T[i] - T[j]) - Bij * sin(T[i] - T[j]))    # ∂Qᵢ / ∂θⱼ
                    Jt.nzval[cnt + N] =  V[i] * (Gij * sin(T[i] - T[j]) - Bij * cos(T[i] - T[j]))       # ∂Qᵢ / ∂Vⱼ
                    cnt += 1
                end
            end
            cnt += N; cnt1 += 1
        end

        for i in busV
            F[cnt1] = V[i]
            cnt1 += 1
        end
        for i in busT
            F[cnt1] = T[i]
            cnt1 += 1
        end

        H = W * Jt'
        for i in H.colptr[slack]:(H.colptr[slack + 1] - 1) - 1
            row = H.rowval[i]
            H[row, slack] = 0.0
        end

        G = transpose(H) * H
        b = transpose(H) * W * (mean - F)
        dTV = wls(G, b, settings.solve)
        dTV[slack] = 0.0

        for i = 1:numsys.Nbus
            T[i] = T[i] + dTV[i]
            V[i] = V[i] + dTV[i + numsys.Nbus]
        end

        threshold = norm(dTV, Inf)
        if threshold < settings.stopping
            converged = 1
            break
        end

    end # while

    if converged == 1
        printstyled("Algorithm: Nonlinear state estimation using Gauss-Newton algorithm converged in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    else
        printstyled("Algorithm: Nonlinear state estimation using Gauss-Newton algorithm did not converge in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    end


    ########## Post-processing ##########
    Vc = V .* exp.(im * T)
    for i = 1:numsys.Nbus
        Sshunt = Vc[i] * conj(Vc[i] * shunt[i])
        Pshunt[i] = real(Sshunt) * system.basePower
        Qshunt[i] = imag(Sshunt) * system.basePower

        I = 0.0 + im * 0.0
        for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
            row = Ybus.rowval[j]
            I += conj(YbusT[row, i]) * conj(Vc[row])
        end
        Si::ComplexF64 = I * Vc[i]
        Pinj[i] = real(Si) * system.basePower
        Qinj[i] = imag(Si) * system.basePower

        Vm[i] = V[i]; Va[i] = (180 / pi) * T[i]
    end

    acflow(system.basePower, numsys, from, to, branchOn, Vc, Yff, Yft, Ytt, Ytf,
        admittance, tap, resistance, reactance, charging,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji)

    ePmuVol = size(measurements.pmuVoltage, 2) == 9
    ePmuCur = size(measurements.pmuCurrent, 2) == 11
    eLegFlo = size(measurements.legacyFlow, 2) == 11
    eLegCur = size(measurements.legacyCurrent, 2) == 7
    eLegInj = size(measurements.legacyInjection, 2) == 9
    eLegVol = size(measurements.legacyVoltage, 2) == 5
    estimate_row = 9; error_row = 3; exact = false
    if ePmuVol && ePmuCur && eLegFlo && eLegCur && eLegInj && eLegVol
        estimate_row = 11; error_row = 6; exact = true
    end
    estimate = zeros(Nmeasure, estimate_row)
    error = zeros(error_row)

    Nm = Nmeasure
    idx = 1; scaleTi = 180 / pi
    for (i, on) in enumerate(onPij)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 1.0 i]

            estimate[idx, 6] = measurements.legacyFlow[i, 4] * system.basePower
            estimate[idx, 7] = measurements.legacyFlow[i, 5] * system.basePower
            k = branchFlow[i]
            if measurements.legacyFlow[i, 2] == system.branch[k, 2] && measurements.legacyFlow[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 4]
            else
                estimate[idx, 8] = flow[k, 6]
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
    for (i, on) in enumerate(onQij)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 2.0 i]

            estimate[idx, 6] = measurements.legacyFlow[i, 7] * system.basePower
            estimate[idx, 7] = measurements.legacyFlow[i, 8] * system.basePower
            k = branchFlow[i]
            if measurements.legacyFlow[i, 2] == system.branch[k, 2] && measurements.legacyFlow[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 5]
            else
                estimate[idx, 8] = flow[k, 7]
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nm * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyFlow[i, 8] * system.basePower^2)
            end

            if exact
                estimate[idx, 10] = measurements.legacyFlow[i, 11] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nm * system.basePower^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.legacyFlow[i, 8] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onPi)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 3.0 i]

            estimate[idx, 6] = measurements.legacyInjection[i, 2] * system.basePower
            estimate[idx, 7] = measurements.legacyInjection[i, 3] * system.basePower
            estimate[idx, 8] = main[busInjection[i], 4]
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
    for (i, on) in enumerate(onQi)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 4.0 i]

            estimate[idx, 6] = measurements.legacyInjection[i, 5] * system.basePower
            estimate[idx, 7] = measurements.legacyInjection[i, 6] * system.basePower
            estimate[idx, 8] = main[busInjection[i], 5]
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * system.basePower)
                error[2] += estimate[idx, 9]^2 / (Nm * system.basePower^2)
                error[3] += estimate[idx, 9]^2 / (measurements.legacyInjection[i, 6] * system.basePower^2)
            end

            if exact
                estimate[idx, 10] = measurements.legacyInjection[i, 9] * system.basePower
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * system.basePower)
                    error[5] += estimate[idx, 11]^2 / (Nm * system.basePower^2)
                    error[6] += estimate[idx, 11]^2 / (measurements.legacyInjection[i, 6] * system.basePower^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onIij)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 5.0 i]

            estimate[idx, 6] = measurements.legacyCurrent[i, 4]
            estimate[idx, 7] = measurements.legacyCurrent[i, 5]
            k = branchFlow[i]
            if measurements.legacyCurrent[i, 2] == system.branch[k, 2] && measurements.legacyCurrent[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 11]
            else
                estimate[idx, 8] = flow[k, 13]
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / Nm
                error[2] += estimate[idx, 9]^2 / Nm
                error[3] += estimate[idx, 9]^2 / measurements.legacyCurrent[i, 5]
            end

            if exact
                estimate[idx, 10] = measurements.legacyCurrent[i, 7]
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / measurements.legacyCurrent[i, 5]
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onIijp)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 2.0 5.0 i]

            estimate[idx, 6] = measurements.pmuCurrent[i, 4]
            estimate[idx, 7] = measurements.pmuCurrent[i, 5]
            k = branchFlow[i]
            if measurements.pmuCurrent[i, 2] == system.branch[k, 2] && measurements.pmuCurrent[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 11]
            else
                estimate[idx, 8] = flow[k, 13]
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / Nm
                error[2] += estimate[idx, 9]^2 / Nm
                error[3] += estimate[idx, 9]^2 / measurements.pmuCurrent[i, 5]
            end

            if exact
                estimate[idx, 10] = measurements.pmuCurrent[i, 10]
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / measurements.pmuCurrent[i, 5]
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onDijp)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 2.0 6.0 i]

            estimate[idx, 6] = measurements.pmuCurrent[i, 7] * scaleTi
            estimate[idx, 7] = measurements.pmuCurrent[i, 8] * scaleTi
            k = branchFlow[i]
            if measurements.pmuCurrent[i, 2] == system.branch[k, 2] && measurements.pmuCurrent[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = flow[k, 12]
            else
                estimate[idx, 8] = flow[k, 14]
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / (Nm * scaleTi)
                error[2] += estimate[idx, 9]^2 / (Nm * scaleTi^2)
                error[3] += estimate[idx, 9]^2 / (measurements.pmuCurrent[i, 8] * scaleTi^2)
            end

            if exact
                estimate[idx, 10] = measurements.pmuCurrent[i, 11] * scaleTi
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / (Nm * scaleTi)
                    error[5] += estimate[idx, 11]^2 / (Nm * scaleTi)
                    error[6] += estimate[idx, 11]^2 / (measurements.pmuCurrent[i, 8] * scaleTi^2)
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onVi)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 1.0 7.0 i]

            estimate[idx, 6] = measurements.legacyVoltage[i, 2]
            estimate[idx, 7] = measurements.legacyVoltage[i, 3]
            estimate[idx, 8] = main[busVoltage[i], 2]
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / Nm
                error[2] += estimate[idx, 9]^2 / Nm
                error[3] += estimate[idx, 9]^2 / measurements.legacyVoltage[i, 3]
            end

            if exact
                estimate[idx, 10] = measurements.legacyVoltage[i, 5]
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / measurements.legacyVoltage[i, 3]
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onVip)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 2.0 7.0 i]

            estimate[idx, 6] = measurements.pmuVoltage[i, 2]
            estimate[idx, 7] = measurements.pmuVoltage[i, 3]
            estimate[idx, 8] = main[busVoltage[i], 2]
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])

            if estimate[idx, 1] != 2.0
                error[1] += estimate[idx, 9] / Nm
                error[2] += estimate[idx, 9]^2 / Nm
                error[3] += estimate[idx, 9]^2 / measurements.pmuVoltage[i, 3]
            end

            if exact
                estimate[idx, 10] = measurements.pmuVoltage[i, 8]
                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])

                if estimate[idx, 1] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / measurements.pmuVoltage[i, 3]
                end
            end
            idx += 1
        end
    end
    for (i, on) in enumerate(onTip)
        if on != 0
            estimate[idx, 1:5] = [idx 1.0 2.0 8.0 i]

            estimate[idx, 6] = measurements.pmuVoltage[i, 5] * scaleTi
            estimate[idx, 7] = measurements.pmuVoltage[i, 6] * scaleTi
            estimate[idx, 8] = main[busVoltage[i], 3]
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
  end #algtime

    ########## Results ##########
    results = StateEstimationNonlinear(main, flow, estimate, error)
    header, group = results_estimateac(system, numsys, measurements, num, settings, results, slack, algtime)
    if !isempty(settings.save)
        savedata(results, measurements, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### Read system
function read_nonlinearsystem(system, measurements)
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Gshunt = @view(system.bus[:, 5])
    Bshunt =  @view(system.bus[:, 6])
    Vini =  @view(system.bus[:, 8])
    Tini = @view(system.bus[:, 9])

    branchi = @view(system.branch[:, 1])
    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    meanPij = @view(measurements.legacyFlow[:, 4])
    variPij = @view(measurements.legacyFlow[:, 5])
    onPij = @view(measurements.legacyFlow[:, 6])
    meanQij = @view(measurements.legacyFlow[:, 7])
    variQij = @view(measurements.legacyFlow[:, 8])
    onQij = @view(measurements.legacyFlow[:, 9])

    meanIij = @view(measurements.legacyCurrent[:, 4])
    variIij = @view(measurements.legacyCurrent[:, 5])
    onIij = @view(measurements.legacyCurrent[:, 6])

    meanPi = @view(measurements.legacyInjection[:, 2])
    variPi = @view(measurements.legacyInjection[:, 3])
    onPi = @view(measurements.legacyInjection[:, 4])
    meanQi = @view(measurements.legacyInjection[:, 5])
    variQi = @view(measurements.legacyInjection[:, 6])
    onQi = @view(measurements.legacyInjection[:, 7])

    meanVi = @view(measurements.legacyVoltage[:, 2])
    variVi = @view(measurements.legacyVoltage[:, 3])
    onVi = @view(measurements.legacyVoltage[:, 4])

    meanIijp = @view(measurements.pmuCurrent[:, 4])
    variIijp = @view(measurements.pmuCurrent[:, 5])
    onIijp = @view(measurements.pmuCurrent[:, 6])
    meanDijp = @view(measurements.pmuCurrent[:, 7])
    variDijp = @view(measurements.pmuCurrent[:, 8])
    onDijp = @view(measurements.pmuCurrent[:, 9])

    meanVip = @view(measurements.pmuVoltage[:, 2])
    variVip = @view(measurements.pmuVoltage[:, 3])
    onVip = @view(measurements.pmuVoltage[:, 4])
    meanTip = @view(measurements.pmuVoltage[:, 5])
    variTip = @view(measurements.pmuVoltage[:, 6])
    onTip = @view(measurements.pmuVoltage[:, 7])

    return busi, type, Gshunt, Bshunt, Vini, Tini,
           branchi, resistance, reactance, charging, transTap, transShift, branchOn,
           meanPij, variPij, onPij, meanQij, variQij, onQij,
           meanIij, variIij, onIij,
           meanPi, variPi, onPi, meanQi, variQi, onQi,
           meanVi, variVi, onVi,
           meanIijp, variIijp, onIijp, meanDijp, variDijp, onDijp,
           meanVip, variVip, onVip, meanTip, variTip, onTip
end


### Write data
function write_acsystem(system, numsys, main, flow)
    for i = 1:numsys.Nbus
        main[i, 1] = system.bus[i, 1]
    end
    Vm = @view(main[:, 2])
    Va = @view(main[:, 3])
    Pinj = @view(main[:, 4])
    Qinj = @view(main[:, 5])
    Pshunt = @view(main[:, 6])
    Qshunt = @view(main[:, 7])

    for i = 1:numsys.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
    end
    Pij = @view(flow[:, 4])
    Qij = @view(flow[:, 5])
    Pji = @view(flow[:, 6])
    Qji = @view(flow[:, 7])
    Qcharging = @view(flow[:, 8])
    Ploss = @view(flow[:, 9])
    Qloss = @view(flow[:, 10])
    Imij = @view(flow[:, 11])
    Iaij = @view(flow[:, 12])
    Imji = @view(flow[:, 13])
    Iaji = @view(flow[:, 14])

    return Va, Vm, Pinj, Qinj, Pshunt, Qshunt,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji
end
