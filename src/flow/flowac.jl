### AC power flow
@inbounds function runacpf(system, num, settings, info)
    busi, typei, Pload, Qload, Gshunt, Bshunt, Vini, Tini, Pgeni, Qgeni,
    Qmaxi, Qmini, Vgen, genOn, resistance, reactance, charging, transTap,
    transShift, branchOn = view_acsystem(system)

  algtime = @elapsed begin
    ########## Pre-processing ##########
    geni = convert(Array{Int64,1}, system.generator[:, 1])
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])

    numbering = false
    bus = collect(1:num.Nbus)
    slack = 0
    for i = 1:num.Nbus
        if bus[i] != busi[i]
            numbering = true
        end
        if typei[i] == 3
            slack = bus[i]
        end
    end
    if numbering
        println("The new bus numbering is running.")
    end
    if slack == 0
        slack = 1
        println("The slack bus is not found. Slack bus is the first bus.")
    end

    slackLimit = copy(slack)
    multiple = fill(0, num.Nbus)
    isMultiple = false
    limit = fill(1, num.Ngen)
    Pgen = fill(0.0, num.Ngen)
    Qgen = fill(0.0, num.Ngen)
    Qmin = fill(0.0, num.Ngen)
    Qmax = fill(0.0, num.Ngen)
    Pbus = fill(0.0, num.Nbus)
    Qbus = fill(0.0, num.Nbus)
    type = fill(1, num.Nbus)

    gen_bus = renumber(geni, num.Ngen, busi, bus, num.Nbus, numbering)
    for (k, i) in enumerate(gen_bus)
        if genOn[k] == 1
            Pbus[i] += Pgeni[k] / system.basePower
            Qbus[i] += Qgeni[k] / system.basePower
            Pgen[k] = Pgeni[k] / system.basePower
            Qgen[k] = Qgeni[k] / system.basePower
            Qmin[k] = Qmini[k] / system.basePower
            Qmax[k] = Qmaxi[k] / system.basePower
            Vini[i] = Vgen[k]
            type[i] = 2

            multiple[i] += 1
            if multiple[i] != 1
                isMultiple = true
            end
        end
    end
    type[slack] = 3
    from = renumber(fromi, num.Nbranch, busi, bus, num.Nbus, numbering)
    to = renumber(toi, num.Nbranch, busi, bus, num.Nbus, numbering)

    ########## Ybus matrix ##########
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

    Pshunt = fill(0.0, num.Nbus); Qshunt = similar(Pshunt)
    Pinj = similar(Pshunt); Qinj = similar(Pshunt)

    ########## Solve the system ##########
    Vc = Vini .* exp.(im * (pi / 180)  * Tini)
    iter = 0
    while settings.reactive[2]
        if  settings.reactive[1] && settings.reactive[2]
            Vc = Vini .* exp.(im * (pi / 180)  * Tini)
        end

        if settings.algorithm == "gs"
            Vc, iter = gauss_seidel(system, num, settings, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, Vini, type, iter)
        end
        if settings.algorithm == "nr"
            Vc, iter = newton_raphson(system, num, settings, Ybus, YbusT, slack, Vc, Pbus, Qbus, Pload, Qload, type, iter)
        end
        if settings.algorithm == "fnrbx" || settings.algorithm == "fnrxb"
            Vc, iter = fast_newton_raphson(system, num, settings, branchOn, Ybus, YbusT, slack, Vc, Pbus, Qbus,
            Pload, Qload, type, resistance, reactance, transShift, Gshunt, Bshunt, charging, transTap, from, to, iter)
        end

        for i = 1:num.Nbus
            Sshunt = Vc[i] * conj(Vc[i] * shunt[i])
            Pshunt[i] = real(Sshunt)
            Qshunt[i] = imag(Sshunt)

            I = 0.0 + im * 0.0
            for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                row = Ybus.rowval[j]
                I += conj(YbusT[row, i]) * conj(Vc[row])
            end
            Si::ComplexF64 = I * Vc[i]
            Pinj[i] = real(Si)
            Qinj[i] = imag(Si)
            if type[i] != 1
                Qbus[i] = Qinj[i] + Qload[i] / system.basePower
            end
        end
        Pbus[slack] = Pinj[slack] + Pload[slack] / system.basePower

        if !isMultiple
            for i = 1:num.Ngen
                if genOn[i] == 1
                    Pgen[i] = Pbus[gen_bus[i]]
                    Qgen[i] = Qbus[gen_bus[i]]
                end
            end
        else
            Qmintotal = fill(0.0, num.Nbus); Qmaxtotal = fill(0.0, num.Nbus)
            QminInf = fill(0.0, num.Nbus); QmaxInf = fill(0.0, num.Nbus)
            QminNew = copy(Qmin);  QmaxNew = copy(Qmax)
            Qgentotal = fill(0.0, num.Nbus)
            for i = 1:num.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if !isinf(Qmin[i])
                        Qmintotal[j] += Qmin[i]
                    end
                    if !isinf(Qmax[i])
                        Qmaxtotal[j] += Qmax[i]
                    end
                    Qgentotal[j] += (Qinj[j] + Qload[j] / system.basePower) / multiple[j]
                end
            end
            for i = 1:num.Ngen
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

            for i = 1:num.Ngen
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
            for i = 1:num.Ngen
                if genOn[i] == 1
                    j = gen_bus[i]
                    if system.basePower * abs(Qmintotal[j] - Qmaxtotal[j]) > 10 * eps(Float64)
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
                end
            end
        end

        if settings.reactive[1] && settings.reactive[2]
            settings.reactive[2] = false
            for i = 1:num.Ngen
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
                            for k = 1:num.Nbus
                                if type[k] == 2
                                    println("Bus $(trunc(Int, system.bus[k, 1])) is the new slack bus.")
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
        for i = 1:num.Nbus
            Vc[i] = abs(Vc[i]) * exp(im * (angle(Vc[i]) - T +  (pi / 180) * Tini[slackLimit]))
        end
    end

    ########## Post-processing ##########
    Imij = fill(0.0, num.Nbranch); Iaij = fill(0.0, num.Nbranch)
    Imji = fill(0.0, num.Nbranch); Iaji = fill(0.0, num.Nbranch)
    Pij = fill(0.0, num.Nbranch); Qij = fill(0.0, num.Nbranch)
    Pji = fill(0.0, num.Nbranch); Qji = fill(0.0, num.Nbranch)
    Qcharging = fill(0.0, num.Nbranch); Ploss = fill(0.0, num.Nbranch)
    Qloss = fill(0.0, num.Nbranch);
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            f = from[i]
            t = to[i]

            Iij::ComplexF64 = Vc[f] * Yff[i] + Vc[t] * Yft[i]
            Iji::ComplexF64 = Vc[f] * Ytf[i] + Vc[t] * Ytt[i]
            Iijb::ComplexF64 = admittance[i] * (Vc[f] / tap[i] - Vc[t])

            Sij::ComplexF64 = Vc[f] * conj(Iij)
            Pij[i] = real(Sij)
            Qij[i] = imag(Sij)

            Sji::ComplexF64 = Vc[t] * conj(Iji)
            Pji[i] = real(Sji)
            Qji[i] = imag(Sji)

            Qcharging[i] = charging[i] * (abs(Vc[f] / tap[i])^2 +  abs(Vc[t])^2) / 2
            Ploss[i] = (abs(Iijb))^2 * resistance[i]
            Qloss[i] = (abs(Iijb))^2 * reactance[i]

            Imij[i] = abs(Iij)
            Iaij[i] = angle(Iij)
            Imji[i] = abs(Iji)
            Iaji[i] = angle(Iji)
        end
    end
  end

    ########## Results ##########
    results, header, group = results_flowac(system, num, settings, Pinj, Qinj, Pbus, Qbus, Pshunt, Qshunt, Imij, Iaij,
    Imji, Iaji, Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Pgen, Qgen, limit, slack, Vc, algtime, iter)
    if !isempty(settings.save)
        savedata(results, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### View data
function view_acsystem(system)
    busi = @view(system.bus[:, 1])
    typei = @view(system.bus[:, 2])
    Pload = @view(system.bus[:, 3])
    Qload = @view(system.bus[:, 4])
    Gshunt = @view(system.bus[:, 5])
    Bshunt =  @view(system.bus[:, 6])
    Vini =  @view(system.bus[:, 8])
    Tini = @view(system.bus[:, 9])

    Pgeni = @view(system.generator[:, 2])
    Qgeni = @view(system.generator[:, 3])
    Qmaxi = @view(system.generator[:, 4])
    Qmini = @view(system.generator[:, 5])
    Vgen = @view(system.generator[:, 6])
    genOn = @view(system.generator[:, 8])

    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    return busi, typei, Pload, Qload, Gshunt, Bshunt, Vini, Tini, Pgeni, Qgeni,
    Qmaxi, Qmini, Vgen, genOn, resistance, reactance, charging, transTap,
    transShift, branchOn
end
