### Newton-Raphson power flow algorithm
@inbounds function newton_raphson(system, num, settings, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, iter)
    V = abs.(Vc); T = angle.(Vc)
    No = 0; converged = 0

    P = similar(Pbus); Q = similar(Pbus)
    G = fill(0.0, num.Nbus + 2 * num.Nbranch); B = similar(G)
    BT = similar(G); GT = similar(G)

    PQ = fill(0, num.Nbus); PVPQ = similar(PQ)
    Nnon = 0; Npvpq = 0; Npq = 0
    cnt = 1
    for i = 1:num.Nbus
        P[i] = Pbus[i] - Pload[i] / system.basePower
        Q[i] = Qbus[i] - Qload[i] / system.basePower

        if type[i] == 1
            Npq += 1
            PQ[i] = Npq + num.Nbus - 1
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

    iJ = fill(0, Nnon); jJ = similar(iJ)
    dPQ = zeros(num.Nbus + Npq - 1)
    cnt1 = 1
    for i = 1:num.Nbus
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

    J = sparse(iJ, jJ, zeros(Nnon), num.Nbus + Npq - 1, num.Nbus + Npq - 1)

    while No < settings.maxIter
        No = No + 1
        threshold = 0.0

        Threads.@threads for i = 1:num.Nbus
            if i != slack
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
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

        dTV = ls(J, dPQ, settings.solve)

        for i = 1:num.Nbus
            if type[i] == 1
                V[i] = V[i] - dTV[PQ[i]]
            end
            if i != slack
                T[i] = T[i] - dTV[PVPQ[i]]
            end
        end

        for i = 1:num.Nbus
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
        printstyled("Algorithm: AC power flow using Newton-Raphson algorithm converged in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    else
        printstyled("Algorithm: AC power flow using Newton-Raphson algorithm did not converge in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    end

    for i = 1:num.Nbus
        Vc[i] = V[i] * exp(im * T[i])
    end
    iter += No

    return Vc, iter
end


### Fast Newton-Raphson power flow algorithm
@inbounds function fast_newton_raphson(system, num, settings, branchOn, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, resistance, reactance, transShift, Gshunt, Bshunt, charging, transTap, from, to, iter)
    V = abs.(Vc); T = angle.(Vc)
    No = 0; converged = 0

    P = similar(Pload); Q = similar(P)
    G = fill(0.0, num.Nbus + 2 * num.Nbranch); B = similar(G)
    BT = similar(G); GT = similar(G)

    PQ = fill(0, num.Nbus); PVPQ = similar(PQ)
    Npvpq = 0; Npq = 0; Nb1 = 0; Nb2 = 0
    cnt = 1
    for i = 1:num.Nbus
        P[i] = Pbus[i] - Pload[i] / system.basePower
        Q[i] = Qbus[i] - Qload[i] / system.basePower

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

    iB1 = fill(0, Nb1); jB1 = similar(iB1)
    iB2 = fill(0, Nb2); jB2 = similar(iB2)
    dP = zeros(num.Nbus - 1); dQ = zeros(Npq)
    cnt1 = 1; cnt2 = 1
    for i = 1:num.Nbus
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

    B1 = sparse(iB1, jB1, zeros(Nb1), num.Nbus - 1, num.Nbus - 1)
    B2 = sparse(iB2, jB2, zeros(Nb2), Npq, Npq)
    for i = 1:num.Nbranch
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

    for i = 1:num.Nbus
        if type[i] == 1
            B2[PQ[i], PQ[i]] += Bshunt[i] / system.basePower
        end
    end

    F1 = lu(B1); L1, U1, p1, q1, Rs1 = F1.:(:)
    F2 = lu(B2); L2, U2, p2, q2, Rs2 = F2.:(:)
    q1 = sortperm(q1); q2 = sortperm(q2)
    while No < settings.maxIter
        No = No + 1
        threshold = 0.0

        dT = U1 \  (L1 \ ((Rs1 .* dP)[p1]))
        dT = dT[q1]

        for i = 1:num.Nbus
            if i != slack
                T[i] = T[i] + dT[PVPQ[i]]
            end
        end
        for i = 1:num.Nbus
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
        dV = U2 \  (L2 \ ((Rs2 .* dQ)[p2]))
        dV = dV[q2]

        for i = 1:num.Nbus
            if type[i] == 1
                V[i] = V[i] + dV[PQ[i]]
            end
        end
        for i = 1:num.Nbus
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
        printstyled("Algorithm: AC power flow using fast Newton-Raphson algorithm converged in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    else
        printstyled("Algorithm: AC power flow using fastNewton-Raphson algorithm did not converge in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    end

    for i = 1:num.Nbus
        Vc[i] = V[i] * exp(im * T[i])
    end
    iter += No

    return Vc, iter
end


### Gauss-Seidel power flow algorithm
@inbounds function gauss_seidel(system, num, settings, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, Vini, type, iter)
    P = similar(Pbus); Q = similar(Pbus)
    No = 0; converged = 0
    for i = 1:num.Nbus
        P[i] = Pbus[i] - Pload[i] / system.basePower
        Q[i] = Qbus[i] - Qload[i] / system.basePower
    end

    dPqv = 0.0; dQqv = 0.0; dPpv = 0.0
    while No < settings.maxIter
        eps = 0.0
        No = No + 1

        for i = 1:num.Nbus
            if type[i] == 1
                I = 0.0 + im * 0.0
                for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                    row = Ybus.rowval[j]
                    I += YbusT[row, i] * Vc[row]
                end
                Vc[i] = Vc[i] + (((P[i] - im * Q[i]) / conj(Vc[i])) - I) / Ybus[i, i]
            end
        end

        for i = 1:num.Nbus
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

        for i = 1:num.Nbus
            if type[i] == 2
                Vc[i] = Vini[i]  * Vc[i] / abs(Vc[i])
            end
        end

        for i = 1:num.Nbus
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
        printstyled("Algorithm: AC power flow using Gauss-Seidel algorithm converged in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    else
        printstyled("Algorithm: AC power flow using Gauss-Seidel algorithm did not converge in $No iterations with the stop condition $(settings.stopping).\n"; bold = true)
    end

    iter += No

    return Vc, iter
end


### DC Ybus matrix
@inbounds function ybusdc(system, num, bus, from, to, branchOn, transTap, reactance, transShift)
    Pshift = fill(0.0, num.Nbus)
    Ydiag = fill(0.0, num.Nbus)
    admitance = fill(0.0, num.Nbranch)
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            if transTap[i] == 0
                admitance[i] = 1 / reactance[i]
            else
                admitance[i] = 1 / (transTap[i] * reactance[i])
            end

            shift = (pi / 180) * transShift[i] * admitance[i]
            Pshift[from[i]] -= shift
            Pshift[to[i]] += shift

            Ydiag[from[i]] += admitance[i]
            Ydiag[to[i]] += admitance[i]
        end
    end

    Ybus = sparse([bus; from; to], [bus; to; from], [Ydiag; -admitance; -admitance], num.Nbus, num.Nbus)

    return Ybus, admitance, Pshift
end


### AC Ybus matrix
function ybusac(system, num, bus, from, to, branchOn, Gshunt, Bshunt, resistance, reactance, charging, transTap, transShift)
    tap = zeros(ComplexF64, num.Nbranch)
    admittance = zeros(ComplexF64, num.Nbranch)
    Ytt = zeros(ComplexF64, num.Nbranch)
    Yff = zeros(ComplexF64, num.Nbranch)
    Yft = zeros(ComplexF64, num.Nbranch)
    Ytf = zeros(ComplexF64, num.Nbranch)
    Ydiag = zeros(ComplexF64, num.Nbus)
    shunt = complex.(Gshunt, Bshunt) ./ system.basePower
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            admittance[i] = 1 / complex(resistance[i], reactance[i])

            if transTap[i] == 0
                tap[i] = exp(im * (pi / 180) * transShift[i])
            else
                tap[i] = transTap[i] * exp(im * (pi / 180) * transShift[i])
            end

            Ytt[i] = admittance[i] + im * charging[i] / 2
            Yff[i] = Ytt[i] / (conj(tap[i]) * tap[i])
            Yft[i] = -admittance[i] / conj(tap[i])
            Ytf[i] = -admittance[i] / tap[i]

            Ydiag[from[i]] += Yff[i]
            Ydiag[to[i]] += Ytt[i]
        end
    end

    Ybus = sparse([bus; bus; from; to], [bus; bus; to; from], [Ydiag; shunt; Yft; Ytf], num.Nbus, num.Nbus)
    YbusT = sparse([bus; bus; to; from], [bus; bus; from; to], [Ydiag; shunt; Yft; Ytf], num.Nbus, num.Nbus)

    return Ybus, YbusT, Ytt, Yff, Yft, Ytf, admittance, tap, shunt
end


### Ac power flow post-processing
function acflow(basePower, num, from, to, branchOn, Vc, Yff, Yft, Ytt, Ytf, admittance, tap, resistance, reactance, charging,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji)
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            f = from[i]
            t = to[i]

            Iij::ComplexF64 = Vc[f] * Yff[i] + Vc[t] * Yft[i]
            Iji::ComplexF64 = Vc[f] * Ytf[i] + Vc[t] * Ytt[i]
            Iijb::ComplexF64 = admittance[i] * (Vc[f] / tap[i] - Vc[t])

            Sij::ComplexF64 = Vc[f] * conj(Iij)
            Pij[i] = real(Sij) * basePower
            Qij[i] = imag(Sij) * basePower

            Sji::ComplexF64 = Vc[t] * conj(Iji)
            Pji[i] = real(Sji) * basePower
            Qji[i] = imag(Sji) * basePower

            Qcharging[i] = basePower * charging[i] * (abs(Vc[f] / tap[i])^2 +  abs(Vc[t])^2) / 2
            Ploss[i] = (abs(Iijb))^2 * resistance[i] * basePower
            Qloss[i] = (abs(Iijb))^2 * reactance[i] * basePower

            Imij[i] = abs(Iij)
            Iaij[i] = (180 / pi) * angle(Iij)
            Imji[i] = abs(Iji)
            Iaji[i] = (180 / pi) * angle(Iji)
        end
    end
end