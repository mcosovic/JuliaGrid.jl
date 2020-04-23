#########################################
#  Newton-Raphson power flow algorithm  #
#########################################
function newton_raphson(settings, system, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, iter)
    V = abs.(Vc)
    T = angle.(Vc)
    No = 0
    converged = 1

    P = similar(Pbus)
    Q = similar(Pbus)
    G = fill(0.0, system.Nbus + 2 * system.Nbra)
    B = similar(G)
    BT = similar(G)
    GT = similar(G)

    PQ = fill(0, system.Nbus)
    PVPQ = similar(PQ)
    Nnon = 0
    Npvpq = 0
    Npq = 0
    cnt = 1
    @inbounds for i = 1:system.Nbus
        P[i] = Pbus[i] - Pload[i] / system.baseMVA
        Q[i] = Qbus[i] - Qload[i] / system.baseMVA

        if type[i] == 1
            Npq += 1
            PQ[i] = Npq + system.Nbus - 1
        end
        if type[i] != 3
            Npvpq += 1
            PVPQ[i] = Npvpq
        end

        for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
            G[cnt] = real(Ybus.nzval[j])
            B[cnt] = imag(Ybus.nzval[j])
            GT[cnt] = real(YbusT.nzval[j])
            BT[cnt] = imag(YbusT.nzval[j])

            type_row = type[Ybus.rowval[j]]
            cnt += 1
            if type[i] != 3 && type_row != 3
                Nnon += 1
            end
            if type[i] == 1 && type_row != 3
                Nnon += 2
            end
            if type[i] == 1 && type_row == 1
                Nnon += 1
            end
        end
    end

    iJ = fill(0, Nnon)
    jJ = similar(iJ)
    cnt1 = 1
    dPQ = zeros(system.Nbus + Npq - 1)
    @inbounds for i = 1:system.Nbus
        if i != slack
            I = 0.0
            C = 0.0

            for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                row = Ybus.rowval[j]
                type_row = type[row]
                I += V[row] * (GT[j] * cos(T[i] - T[row]) + BT[j] * sin(T[i] - T[row]))

                if type_row != 3
                    iJ[cnt1] = PVPQ[row]
                    jJ[cnt1] = PVPQ[i]
                    cnt1 += 1
                end
                if type_row == 1
                    iJ[cnt1] = PQ[row]
                    jJ[cnt1] = PVPQ[i]
                    cnt1 += 1
                end
                if type[i] == 1 && type_row != 3
                    iJ[cnt1] = PVPQ[row]
                    jJ[cnt1] = PQ[i]
                    cnt1 += 1
                end
                if type[i] == 1 && type_row == 1
                    iJ[cnt1] = PQ[row]
                    jJ[cnt1] = PQ[i]
                    cnt1 += 1
                end
                if type[i] == 1
                    C += V[row] * (GT[j] * sin(T[i] - T[row]) - BT[j] * cos(T[i] - T[row]))
                end
            end

            dPQ[PVPQ[i]] = V[i] * I - P[i]
            if type[i] == 1
                dPQ[PQ[i]] = V[i] * C - Q[i]
            end
        end
    end

    J = sparse(iJ, jJ, zeros(Nnon), system.Nbus + Npq - 1, system.Nbus + Npq - 1)

    while No < settings.maxIter
        No = No + 1
        threshold = 0.0

        Threads.@threads for i = 1:system.Nbus
            if i != slack
                @inbounds for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    type_row = type[row]

                    if type_row != 3
                        I1 = 0.0
                        I2 = 0.0
                        if row != i
                            J[PVPQ[row], PVPQ[i]] =  V[row] * V[i] * (G[j] * sin(T[row] - T[i]) - B[j] * cos(T[row] - T[i]))
                            if type_row == 1
                                J[PQ[row], PVPQ[i]] = V[row] * V[i] * (-G[j] * cos(T[row] - T[i]) -B[j] * sin(T[row] - T[i]))
                            end
                            if type[i] == 1
                                J[PVPQ[row], PQ[i]] = V[row] * (G[j] * cos(T[row] - T[i]) + B[j] * sin(T[row] - T[i]))
                            end
                            if type[i] == 1 && type_row == 1
                                J[PQ[row], PQ[i]] = V[row] * (G[j] * sin(T[row] - T[i]) - B[j] * cos(T[row] - T[i]))
                            end
                        else
                            for kk in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                                q = Ybus.rowval[kk]
                                I1 -= V[q] * (GT[kk] * sin(T[row] - T[q]) - BT[kk] * cos(T[row] - T[q]))
                                if type[i] == 1 || type_row == 1
                                    I2 += V[q] * (GT[kk] * cos(T[row] - T[q]) + BT[kk] * sin(T[row] - T[q]))
                                end
                            end
                            J[PVPQ[row], PVPQ[i]] = V[row] * I1 - B[j] * V[row]^2
                            if type_row == 1
                                J[PQ[row], PVPQ[i]] = V[row] * I2 - G[j] * V[row]^2
                            end
                            if type[i] == 1
                                J[PVPQ[row], PQ[i]] = I2 + G[j] * V[row]
                            end
                            if type[i] == 1 && type_row == 1
                                J[PQ[row], PQ[i]] = -I1 - B[j] * V[row]
                            end
                        end
                    end
                end
            end
        end

        if settings.solve == "lu"
            F = lu(J)
            dTV = F.U \  (F.L \ ((F.Rs .* dPQ)[F.p]))
            dTV = dTV[sortperm(F.q)]
        else
            dTV = J \ dPQ
        end

        @inbounds for i = 1:system.Nbus
            if type[i] == 1
                V[i] = V[i] - dTV[PQ[i]]
            end
            if i != slack
                T[i] = T[i] - dTV[PVPQ[i]]
            end
        end

        @inbounds for i = 1:system.Nbus
            if i != slack
                I = 0.0
                C = 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += V[row] * (GT[j] * cos(T[i] - T[row]) + BT[j] * sin(T[i] - T[row]))

                    if type[i] == 1
                        C += V[row] * (GT[j] * sin(T[i] - T[row]) - BT[j] * cos(T[i] - T[row]))
                    end
                end
                dPQ[PVPQ[i]] = V[i] * I - P[i]
                threshold = maximum(([abs(dPQ[PVPQ[i]]) threshold]))
                if type[i] == 1
                    dPQ[PQ[i]] = V[i] * C - Q[i]
                    threshold = maximum(([abs(dPQ[PQ[i]]) threshold]))
                end
            end
        end

        if threshold < settings.stopping
            converged = 1
            break
        end
    end

    if converged == 1
        println(string("AC power flow using Newton-Raphson algorithm converged in ", No, " iterations for stopping condition ", settings.stopping,"."))
    else
        @info(string("AC power flow using Newton-Raphson algorithm did not converge in ", No, " iterations for stopping condition ", settings.stopping,"."))
    end

    @inbounds for i = 1:system.Nbus
        Vc[i] = V[i] * exp(im * T[i])
    end
    iter += No

    return Vc, iter
end


##############################################
#  Fast Newton-Raphson power flow algorithm  #
##############################################
function fast_newton_raphson(system, settings, branchOn, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, resistance, reactance, transShift, Gshunt, Bshunt, charging, transTap, from, to, iter)
    V = abs.(Vc)
    T = angle.(Vc)
    No = 0
    converged = 1

    P = similar(Pload)
    Q = similar(P)
    G = fill(0.0, system.Nbus + 2 * system.Nbra)
    B = similar(G)
    BT = similar(G)
    GT = similar(G)

    PQ = fill(0, system.Nbus)
    PVPQ = similar(PQ)
    Npvpq = 0
    Npq = 0
    Nb1 = 0
    Nb2 = 0
    cnt = 1

    @inbounds for i = 1:system.Nbus
        P[i] = Pbus[i] - Pload[i] / system.baseMVA
        Q[i] = Qbus[i] - Qload[i] / system.baseMVA

        if type[i] == 1
            Npq += 1
            PQ[i] = Npq
        end
        if type[i] != 3
            Npvpq += 1
            PVPQ[i] = Npvpq
        end

        for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
            G[cnt] = real(Ybus.nzval[j])
            B[cnt] = imag(Ybus.nzval[j])
            GT[cnt] = real(YbusT.nzval[j])
            BT[cnt] = imag(YbusT.nzval[j])

            type_row = type[Ybus.rowval[j]]
            cnt += 1
            if type[i] != 3 && type_row != 3
                Nb1 += 1
            end
            if type[i] == 1 && type_row == 1
                Nb2 += 1
            end
        end
    end

    iB1 = fill(0, Nb1)
    jB1 = similar(iB1)
    iB2 = fill(0, Nb2)
    jB2 = similar(iB2)
    dP = zeros(system.Nbus - 1)
    dQ = zeros(Npq)
    cnt1 = 1
    cnt2 = 1
    @inbounds for i = 1:system.Nbus
        if i != slack
            I = 0.0
            C = 0.0
            for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                row = Ybus.rowval[j]
                type_row = type[row]
                I += V[row] * (GT[j] * cos(T[i] - T[row]) + BT[j] * sin(T[i] - T[row]))

                if type_row != 3
                    iB1[cnt1] = PVPQ[row]
                    jB1[cnt1] = PVPQ[i]
                    cnt1 += 1
                end
                if type[i] == 1 && type_row == 1
                    iB2[cnt2] = PQ[row]
                    jB2[cnt2] = PQ[i]
                    cnt2 += 1
                end
                if type[i] == 1
                    C += V[row] * (GT[j] * sin(T[i] - T[row]) - BT[j] * cos(T[i] - T[row]))
                end
            end

            dP[PVPQ[i]] = I - P[i] / V[i]
            if type[i] == 1
                dQ[PQ[i]] = C - Q[i] / V[i]
            end
        end
    end

    B1 = sparse(iB1, jB1, zeros(Nb1), system.Nbus - 1, system.Nbus - 1)
    B2 = sparse(iB2, jB2, zeros(Nb2), Npq, Npq)
    @inbounds for i = 1:system.Nbra
        if branchOn[i] == 1
            m = PVPQ[from[i]]
            n = PVPQ[to[i]]
            shiftcos = cos((pi / 180) * transShift[i])
            shiftsin = sin((pi / 180) * transShift[i])
            if settings.algorithm == "fnrbx"
                gmk = resistance[i] / (resistance[i]^2 + reactance[i]^2)
                bmk = -reactance[i] / (resistance[i]^2 + reactance[i]^2)
            end
            if settings.algorithm == "fnrxb"
                gmk = 0.0
                bmk = -1 / reactance[i]
            end
            if from[i] != slack && to[i] != slack
                B1[m, n] += (-gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
                B1[n, m] += (gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
            end
            if from[i] != slack
                B1[m, m] += bmk / (shiftcos^2 + shiftsin^2)
            end
            if to[i] != slack
                B1[n, n] += bmk
            end

            if settings.algorithm == "fnrbx"
                bmk = - 1 / reactance[i]
            end
            if settings.algorithm == "fnrxb"
                bmk = -reactance[i] / (resistance[i]^2 + reactance[i]^2)
            end
            m = PQ[from[i]]
            n = PQ[to[i]]
            if transTap[i] == 0
                tap = 1.0
            else
                tap = transTap[i]
            end
            if PQ[from[i]] != 0 && PQ[to[i]] != 0
                B2[m, n] += -bmk / tap
                B2[n, m] += -bmk / tap
            end
            if type[from[i]] == 1
                B2[m, m] += (bmk + charging[i] / 2) / (tap^2)
            end
            if type[to[i]] == 1
                B2[n, n] += bmk + charging[i] / 2
            end
        end
    end

    @inbounds for i = 1:system.Nbus
        if type[i] == 1
            B2[PQ[i], PQ[i]] += Bshunt[i] / system.baseMVA
        end
    end

    F = lu(B1)
    W = lu(B2)
    q1 = sortperm(F.q)
    q2 = sortperm(W.q)

    while No < settings.maxIter
        No = No + 1
        threshold = 0.0

        dT = F.U \  (F.L \ ((F.Rs .* dP)[F.p]))
        dT = dT[q1]

        @inbounds for i = 1:system.Nbus
            if i != slack
                T[i] = T[i] + dT[PVPQ[i]]
            end
        end
        @inbounds for i = 1:system.Nbus
            if i != slack
                I = 0.0
                C = 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += V[row] * (GT[j] * cos(T[i] - T[row]) + BT[j] * sin(T[i] - T[row]))

                    if type[i] == 1
                        C += V[row] * (GT[j] * sin(T[i] - T[row]) - BT[j] * cos(T[i] - T[row]))
                    end
                end
                dP[PVPQ[i]] = I - P[i] / V[i]
                threshold = maximum(([abs(dP[PVPQ[i]]) threshold]))
                if type[i] == 1
                    dQ[PQ[i]] = C - Q[i] / V[i]
                    threshold = maximum(([abs(dQ[PQ[i]]) threshold]))
                end
            end
        end

        if threshold < settings.stopping
            converged = 1
            break
        end

        threshold = 0.0
        dV = W.U \  (W.L \ ((W.Rs .* dQ)[W.p]))
        dV = dV[q2]

        @inbounds for i = 1:system.Nbus
            if type[i] == 1
                V[i] = V[i] + dV[PQ[i]]
            end
        end
        @inbounds for i = 1:system.Nbus
            if i != slack
                I = 0.0
                C = 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += V[row] * (GT[j] * cos(T[i] - T[row]) + BT[j] * sin(T[i] - T[row]))

                    if type[i] == 1
                        C += V[row] * (GT[j] * sin(T[i] - T[row]) - BT[j] * cos(T[i] - T[row]))
                    end
                end
                dP[PVPQ[i]] = I - P[i] / V[i]
                threshold = maximum(([abs(dP[PVPQ[i]]) threshold]))
                if type[i] == 1
                    dQ[PQ[i]] = C - Q[i] / V[i]
                    threshold = maximum(([abs(dQ[PQ[i]]) threshold]))
                end
            end
        end

        if threshold < settings.stopping
            converged = 1
            break
        end
    end

    if converged == 1
        println(string("AC power flow using fast Newton-Raphson algorithm converged in ", No, " iterations for stopping condition ", settings.stopping,"."))
    else
        println(string("AC power flow using fast Newton-Raphson algorithm did not converge in ", No, " iterations for stopping condition ", settings.stopping,"."))
    end

    @inbounds for i = 1:system.Nbus
        Vc[i] = V[i] * exp(im * T[i])
    end
    iter += No

    return Vc, iter
end


#######################################
#  Gauss-Seidel power flow algorithm  #
#######################################
function gauss_seidel(settings, system, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, Vini, type, iter)
    P = similar(Pbus)
    Q = similar(Pbus)
    No = 0
    for i = 1:system.Nbus
        P[i] = Pbus[i] - Pload[i] / system.baseMVA
        Q[i] = Qbus[i] - Qload[i] / system.baseMVA
    end

    dPqv = 0.0
    dQqv = 0.0
    dPpv = 0.0
    converged = 0
    while No < settings.maxIter
        eps = 0.0
        No = No + 1

        @inbounds for i = 1:system.Nbus
            if type[i] == 1
                I = 0.0 + im * 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += YbusT[row, i] * Vc[row]
                end
                Vc[i] = Vc[i] + (((P[i] - im * Q[i]) / conj(Vc[i])) - I) / Ybus[i, i]
            end
        end

        @inbounds for i = 1:system.Nbus
            if type[i] == 2
                I = 0.0 + im * 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += YbusT[row, i] * Vc[row]
                end
                Q[i] = - imag(conj(Vc[i]) * I)
                Vc[i] = Vc[i] + (((P[i] - im * Q[i]) / conj(Vc[i])) - I) / Ybus[i,i]
            end
        end

        @inbounds for i = 1:system.Nbus
            if type[i] == 2
                Vc[i] = Vini[i]  * Vc[i] / abs(Vc[i])
            end
        end

        @inbounds for i = 1:system.Nbus
            if i != slack
                I = 0.0 + im * 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += YbusT[row, i] * Vc[row]
                end
                dS = Vc[i] * conj(I) - P[i] - im * Q[i]
                if type[i] == 1
                    dPqv = abs(real(dS))
                    dQqv = abs(imag(dS))
                end
                if type[i] == 2
                    dPpv = abs(real(dS))
                end
                eps = maximum(([dPqv dQqv dPpv eps]))
            end
        end

        if eps < settings.stopping
            converged = 1
            break
        end
    end
    if converged == 1
        println(string("AC power flow using Gauss-Seidel algorithm converged in ", No, " iterations for stopping condition ", settings.stopping,"."))
    else
        println(string("AC power flow using Gauss-Seidel algorithm did not converge in ", No, " iterations for stopping condition ", settings.stopping,"."))
    end
    iter += No

    return Vc, iter
end
