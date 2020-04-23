###################
#  AC Power Flow  #
###################
function runacpf(settings, system)
    busi, type, Pload, Qload, Gshunt, Bshunt, Vini, Tini, geni, Pgen, Qgen,
    Qmax, Qmin, Vgen, genOn, fromi, toi, resistance, reactance, charging, transTap,
    transShift, branchOn, Pshunt, Qshunt, Pbus, Qbus, Pinj, Qinj, Imij, Iaij, Imji, Iaji,
    Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, limit, QminInf, QmaxInf = view_acsystem(system)

  algtime = @elapsed begin
    info = ""
    numbering = false
    bus = collect(1:system.Nbus)
    slack = 0
    @inbounds for i = 1:system.Nbus
        if bus[i] != busi[i]
            numbering = true
        end
        if type[i] == 3
            slack = bus[i]
        end
    end

    if slack == 0
        slack = 1
        println("The slack bus is not found. Slack bus is the first bus.")
    end

    slackLimit = copy(slack)
    multiple = fill(0, system.Nbus)
    isMultiple = false
    limit .= 1.0
    Pbus .= 0.0
    Qbus .= 0.0
    type .= 1.0

    gen_bus = numbering_generator(geni, busi, system.Nbus, bus, numbering)
    @inbounds for (k, i) in enumerate(gen_bus)
        if genOn[k] == 1
            Pbus[i] += Pgen[k] / system.baseMVA
            Qbus[i] += Qgen[k] / system.baseMVA
            Pgen[k] = Pgen[k] / system.baseMVA
            Qgen[k] = Qgen[k] / system.baseMVA
            Qmin[k] = Qmin[k] / system.baseMVA
            Qmax[k] = Qmax[k] / system.baseMVA
            Vini[i] = Vgen[k]
            type[i] = 2.0

            multiple[i] += 1
            if multiple[i] != 1
                isMultiple = true
            end
        end
    end
    type[slack] = 3.0

    from, to = numbering_branch(fromi, toi, busi, system.Nbra, system.Nbus, bus, numbering)
    tap = zeros(Complex, system.Nbra)
    admittance = zeros(Complex, system.Nbra)
    Ytt = zeros(Complex, system.Nbra)
    Yff = zeros(Complex, system.Nbra)
    Yft = zeros(Complex, system.Nbra)
    Ytf = zeros(Complex, system.Nbra)
    Ydiag = zeros(Complex, system.Nbus)
    shunt = complex.(Gshunt, Bshunt) ./ system.baseMVA
    @inbounds for i = 1:system.Nbra
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

    Ybus = sparse([bus; bus; from; to], [bus; bus; to; from], [Ydiag; shunt; Yft; Ytf], system.Nbus, system.Nbus)
    YbusT = sparse([bus; bus; to; from], [bus; bus; from; to], [Ydiag; shunt; Yft; Ytf], system.Nbus, system.Nbus)

    Vc = Vini .* exp.(im * (pi / 180)  * Tini)
    iter = 0
    while settings.reactive[2]
        if  settings.reactive[1] && settings.reactive[2]
            Vc = Vini .* exp.(im * (pi / 180)  * Tini)
        end

        if settings.algorithm == "gs"
            Vc, iter = gauss_seidel(settings, system, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, Vini, type, iter)
        end
        if settings.algorithm == "nr"
            Vc, iter = newton_raphson(settings, system, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, iter)
        end
        if settings.algorithm == "fnrbx" || settings.algorithm == "fnrxb"
            Vc, iter = fast_newton_raphson(system, settings, branchOn, Ybus, YbusT, slack, Vc, Pbus, Qbus,
            Pload, Qload, type, resistance, reactance, transShift, Gshunt, Bshunt, charging, transTap, from, to, iter)
        end

        @inbounds for i = 1:system.Nbus
            Sshunt = Vc[i] * conj(Vc[i] * shunt[i])
            Pshunt[i] = real(Sshunt)
            Qshunt[i] = imag(Sshunt)

            I = 0.0 + im * 0.0
            for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                row = Ybus.rowval[j]
                I += conj(YbusT[row, i]) * conj(Vc[row])
            end
            Si = I * Vc[i]
            Pinj[i] = real(Si)
            Qinj[i] = imag(Si)
            if type[i] != 1
                Qbus[i] = Qinj[i] + Qload[i] / system.baseMVA
            end
        end
        Pbus[slack] = Pinj[slack] + Pload[slack] / system.baseMVA

        if !isMultiple
            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    Pgen[i] = Pbus[gen_bus[i]]
                    Qgen[i] = Qbus[gen_bus[i]]
                else
                    Pgen[i] = 0.0
                    Qgen[i] = 0.0
                end
            end
        else
            Qmintotal = fill(0.0, system.Nbus)
            Qmaxtotal = fill(0.0, system.Nbus)
            Qgentotal = fill(0.0, system.Nbus)
            QminNew = copy(Qmin)
            QmaxNew = copy(Qmax)
            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if !isinf(Qmin[i])
                        Qmintotal[j] += Qmin[i]
                    end
                    if !isinf(Qmax[i])
                        Qmaxtotal[j] += Qmax[i]
                    end
                    Qgentotal[j] += (Qinj[j] + Qload[j] / system.baseMVA) / multiple[j]
                end
            end
            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if Qmin[i] == Inf
                        QminInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                    end
                    if Qmin[i] == -Inf
                        QminInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                    end
                    if Qmax[i] == Inf
                        QmaxInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                    end
                    if Qmax[i] == -Inf
                        QmaxInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                    end
                end
            end

            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if isinf(Qmin[i])
                        Qmintotal[j] += QminInf[i]
                        QminNew[i] = QminInf[i]
                    end
                    if isinf(Qmax[i])
                        Qmaxtotal[j] += QmaxInf[i]
                        QmaxNew[i] =  QmaxInf[i]
                    end
                end
            end
            flag = true
            tempslack = 0
            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if system.baseMVA * abs(Qmintotal[j] - Qmaxtotal[j]) > 10 * eps(Float64)
                        Qgen[i] = QminNew[i] + ((Qgentotal[j] - Qmintotal[j]) / (Qmaxtotal[j] - Qmintotal[j])) * (QmaxNew[i] - QminNew[i])
                    else
                        Qgen[i] = QminNew[i] + (Qgentotal[j] - Qmintotal[j]) / multiple[j]
                    end
                    if gen_bus[i] == slack && flag == false
                        Pgen[tempslack] -= Pgen[i]
                    end
                    if gen_bus[i] == slack && flag == true
                        Pgen[i] = Pbus[slack]
                        tempslack = i
                        flag = false
                    end
                else
                    Pgen[i] = 0.0
                    Qgen[i] = 0.0
                end
            end
        end

        if settings.reactive[1] && settings.reactive[2]
            settings.reactive[2] = false
            @inbounds for i = 1:system.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if limit[i] == 1 && (Qgen[i] < Qmin[i] || Qgen[i] > Qmax[i])
                        settings.reactive[2] = true
                        j = gen_bus[i]
                        if Qgen[i] < Qmin[i]
                            limit[i] = 2
                            Qbus[j] -= Qgen[i]
                            Qgen[i] = Qmin[i]
                            Qbus[j] += Qgen[i]
                        end
                        if Qgen[i] > Qmax[i]
                            limit[i] = 3
                            Qbus[j] -= Qgen[i]
                            Qgen[i] = Qmax[i]
                            Qbus[j] += Qgen[i]
                        end

                        type[j] = 1
                        if j == slack
                            for k = 1:system.Nbus
                                if type[k] == 2
                                    println(string("Bus ", trunc(Int, system.bus[k, 1]), " is the new slack bus."))
                                    slack = bus[k]
                                    type[k] = 3
                                    settings.reactive[3] = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        else
            settings.reactive[2] = false
        end
    end

    if settings.reactive[3]
        T = angle(Vc[slackLimit])
        for i = 1:system.Nbus
            Vc[i] = abs(Vc[i]) * exp(im * (angle(Vc[i]) - T +  (pi / 180) * Tini[slackLimit]))
        end
    end

    @inbounds for i = 1:system.Nbra
        if branchOn[i] == 1
            f = from[i]
            t = to[i]

            Iij = Vc[f] * Yff[i] + Vc[t] * Yft[i]
            Iji = Vc[f] * Ytf[i] + Vc[t] * Ytt[i]
            Iijb = admittance[i] * (Vc[f] / tap[i] - Vc[t])

            Sij = Vc[f] * conj(Iij)
            Pij[i] = real(Sij)
            Qij[i] = imag(Sij)

            Sji = Vc[t] * conj(Iji)
            Pji[i] = real(Sji)
            Qji[i] = imag(Sji)

            Qcharging[i] = charging[i] * (abs(Vc[f] / tap[i])^2 +  abs(Vc[t])^2) / 2
            Ploss[i] = (abs(Iijb))^2 * resistance[i]
            Qloss[i] = (abs(Iijb))^2 * reactance[i]

            Imij[i] = abs(Iij)
            Iaij[i] = angle(Iij)
            Imji[i] = abs(Iji)
            Iaji[i] = angle(Iji)
        else
            Ploss[i] = 0.0
            Qloss[i] = 0.0
            Qcharging[i] = 0.0
        end
    end
  end

    results = results_flowac(settings, system, limit, slack, Vc, algtime, iter)

    return results
end


###############
#  View data  #
###############
function view_acsystem(system)
    # Read Data
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Pload = @view(system.bus[:, 3])
    Qload = @view(system.bus[:, 4])
    Gshunt = @view(system.bus[:, 5])
    Bshunt =  @view(system.bus[:, 6])
    Vini =  @view(system.bus[:, 8])
    Tini = @view(system.bus[:, 9])

    geni = @view(system.generator[:, 1])
    Pgen = @view(system.generator[:, 2])
    Qgen = @view(system.generator[:, 3])
    Qmax = @view(system.generator[:, 4])
    Qmin = @view(system.generator[:, 5])
    Vgen = @view(system.generator[:, 6])
    genOn = @view(system.generator[:, 8])

    fromi = @view(system.branch[:, 2])
    toi = @view(system.branch[:, 3])
    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    # Write Data
    Pshunt = @view(system.bus[:, 5])
    Qshunt = @view(system.bus[:, 6])
    Pbus = @view(system.bus[:, 10])
    Qbus = @view(system.bus[:, 11])
    Pinj = @view(system.bus[:, 12])
    Qinj = @view(system.bus[:, 13])

    QminInf = @view(system.generator[:, 10])
    QmaxInf = @view(system.generator[:, 11])
    limit = @view(system.generator[:, 14])

    Imij = @view(system.branch[:, 4])
    Iaij = @view(system.branch[:, 5])
    Imji = @view(system.branch[:, 6])
    Iaji = @view(system.branch[:, 7])
    Pij = @view(system.branch[:, 8])
    Qij = @view(system.branch[:, 9])
    Pji = @view(system.branch[:, 10])
    Qji = @view(system.branch[:, 11])
    Qcharging = @view(system.branch[:, 12])
    Ploss = @view(system.branch[:, 13])
    Qloss = @view(system.branch[:, 14])

    return busi, type, Pload, Qload, Gshunt, Bshunt, Vini, Tini, geni, Pgen, Qgen,
    Qmax, Qmin, Vgen, genOn, fromi, toi, resistance, reactance, charging, transTap,
    transShift, branchOn, Pshunt, Qshunt, Pbus, Qbus, Pinj, Qinj, Imij, Iaij, Imji, Iaji,
    Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, limit, QminInf, QmaxInf
end
