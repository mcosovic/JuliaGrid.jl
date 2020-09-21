### Struct variable
struct PowerFlowAC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    generation::Array{Float64,2}
    iterations::Int64
end


### AC power flow
@inbounds function runacpf(system, num, settings, info)

    ########## Pre-processing ##########
    busi, typei, Pload, Qload, Gshunt, Bshunt, Vini, Tini,
    Pgeni, Qgeni, Qmaxi, Qmini, Vgen, genOn,
    resistance, reactance, charging, transTap, transShift, branchOn = read_acsystem(system)

    main = fill(0.0, num.Nbus, 11)
    flow =  fill(0.0, num.Nbranch, 14)
    gene = fill(0.0, num.Ngen, 3)
    Va, Vm, Pinj, Qinj, Pbus, Qbus, Pshunt, Qshunt,
    Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji,
    Pgen, Qgen = write_acsystem(system, num, main, flow, gene)

  algtime = @elapsed begin
    ########## Convert in integers ##########
    geni = convert(Array{Int64,1}, system.generator[:, 1])
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])

    ########## Numbering and slack bus ##########
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

    gen_bus = renumber(geni, busi, bus, numbering)
    from = renumber(fromi, busi, bus, numbering)
    to = renumber(toi, busi, bus, numbering)

    ########## Generation ##########
    slackLimit = copy(slack)
    multiple = fill(0, num.Nbus)
    isMultiple = false
    limit = fill(1, num.Ngen)
    Qmin = fill(0.0, num.Ngen)
    Qmax = fill(0.0, num.Ngen)
    type = fill(1, num.Nbus)

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

    ########## Ybus matrix ##########
    Ybus, YbusT, Ytt, Yff, Yft, Ytf, admittance, tap, shunt = ybusac(system, num, bus, from, to, branchOn,
        Gshunt, Bshunt, resistance, reactance, charging, transTap, transShift)

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
            if type[i] != 1
                Qbus[i] = (Qinj[i] + Qload[i]) / system.basePower
            end
        end
        Pbus[slack] = (Pinj[slack] + Pload[slack]) / system.basePower

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
                    Qgentotal[j] += ((Qinj[j] + Qload[j]) / system.basePower) / multiple[j]
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
    for i = 1:num.Nbus
        Vm[i] = abs(Vc[i])
        Va[i] = (180 / pi) * angle(Vc[i])
        Pbus[i] = Pbus[i] * system.basePower
        Qbus[i] = Qbus[i] * system.basePower
    end

    for i = 1:num.Ngen
        Pgen[i] = Pgen[i] * system.basePower
        Qgen[i] = Qgen[i] * system.basePower
    end

    acflow(system.basePower, num, from, to, branchOn, Vc, Yff, Yft, Ytt, Ytf,
        admittance, tap, resistance, reactance, charging,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji)
  end #algtime

    ########## Results ##########
    results = PowerFlowAC(main, flow, gene, iter)
    header, group = results_flowac(system, num, settings, results, slack, limit, algtime)
    if !isempty(settings.save)
        savedata(results, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### Read data
function read_acsystem(system)
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

    return busi, typei, Pload, Qload, Gshunt, Bshunt, Vini, Tini,
        Pgeni, Qgeni, Qmaxi, Qmini, Vgen, genOn,
        resistance, reactance, charging, transTap, transShift, branchOn
end

### Write data
function write_acsystem(system, num, main, flow, gene)
    for i = 1:num.Nbus
        main[i, 1] = system.bus[i, 1]
        main[i, 8] = system.bus[i, 3]
        main[i, 9] = system.bus[i, 4]
    end
    Vm = @view(main[:, 2])
    Va = @view(main[:, 3])
    Pinj = @view(main[:, 4])
    Qinj = @view(main[:, 5])
    Pbus = @view(main[:, 6])
    Qbus = @view(main[:, 7])
    Pshunt = @view(main[:, 10])
    Qshunt = @view(main[:, 11])

    for i = 1:num.Nbranch
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

    for i = 1:num.Ngen
        gene[i, 1] = system.generator[i, 1]
    end
    Pgen = @view(gene[:, 2])
    Qgen = @view(gene[:, 3])

    return Va, Vm, Pinj, Qinj, Pbus, Qbus, Pshunt, Qshunt,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji,
        Pgen, Qgen
end
