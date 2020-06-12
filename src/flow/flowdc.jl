### Struct variable
struct PowerFlowDC
    main::Array{Float64,2}
    flow::Array{Float64,2}
    generation::Array{Float64,2}
end


### DC power flow
@inbounds function rundcpf(system, num, settings, info)
    printstyled("Algorithm: DC power flow\n"; bold = true)

    ########## Pre-processing ##########
    busi, type, Pload, Gshunt, Tini, Pgeni, genOn, resistance, reactance,
    charging, transTap, transShift, branchOn = read_dcsystem(system)

    main = fill(0.0, num.Nbus, 6)
    flow = fill(0.0, num.Nbranch, 5)
    gene = fill(0.0, num.Ngen, 2)
    Va, Pinj, Pbus, Pij, Pji, Pgen = write_dcsystem(system, num, main, flow, gene)

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
        if type[i] == 3
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

    gen_bus = renumber(geni, num.Ngen, busi, bus, num.Nbus, numbering)
    from = renumber(fromi, num.Nbranch, busi, bus, num.Nbus, numbering)
    to = renumber(toi, num.Nbranch, busi, bus, num.Nbus, numbering)

    ########## Generation ##########
    for (k, i) in enumerate(gen_bus)
        if genOn[k] == 1
            Pbus[i] += Pgeni[k] / system.basePower
            Pgen[k] = Pgeni[k]
        end
    end

    ########## Ybus matrix ##########
    Ybus, admitance, Pshift = ybusdc(system, num, bus, from, to, branchOn, transTap, reactance, transShift)

    ########## Solve the system ##########
    keep = [collect(1:slack - 1); collect(slack + 1:num.Nbus)]
    Ybus_reduce = Ybus[keep, keep]
    b = Pbus[keep] - Pshift[keep] - (Pload[keep] + Gshunt[keep]) ./ system.basePower

    Ti = ls(Ybus_reduce, b, settings.solve)

    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tini[slack] .+ Ti

    ########## Post-processing ##########
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i]) * system.basePower
            Pji[i] = -Pij[i]
        end
    end

    for i = 1:num.Nbus
        Va[i] = (180 / pi) * Ti[i]
        Pbus[i] = Pbus[i] * system.basePower
        Pinj[i] = Pbus[i] - Pload[i]
        if i == slack
            I = 0.0
            for j in Ybus.colptr[i]:(Ybus.colptr[i + 1] - 1)
                row = Ybus.rowval[j]
                I += Ybus[slack, row] * Ti[row]
            end
            Pinj[slack] = (I + Pshift[slack]) * system.basePower + Gshunt[slack]
            Pbus[slack] = Pinj[slack] + Pload[slack]
        end
    end

    flag = true
    tempslack = 0
    for i = 1:num.Ngen
        if genOn[i] == 1
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
 end # algtime

    ########## Results ##########
    results = PowerFlowDC(main, flow, gene)
    header, group = results_flowdc(system, num, settings, results, slack, algtime)
    if !isempty(settings.save)
        savedata(results, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### Read data
function read_dcsystem(system)
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Pload = @view(system.bus[:, 3])
    Gshunt = @view(system.bus[:, 5])
    Tini = @view(system.bus[:, 9])

    Pgeni = @view(system.generator[:, 2])
    genOn = @view(system.generator[:, 8])

    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    return busi, type, Pload, Gshunt, Tini, Pgeni, genOn,
    resistance, reactance, charging, transTap, transShift, branchOn
end


### Write data
function write_dcsystem(system, num, main, flow, gene)
    for i = 1:num.Nbus
        main[i, 1] = system.bus[i, 1]
        main[i, 5] = system.bus[i, 3]
        main[i, 6] = system.bus[i, 5]
    end
    Va = @view(main[:, 2])
    Pinj = @view(main[:, 3])
    Pbus = @view(main[:, 4])

    for i = 1:num.Nbranch
        flow[i, 1] = system.branch[i, 1]
        flow[i, 2] = system.branch[i, 2]
        flow[i, 3] = system.branch[i, 3]
    end
    Pij = @view(flow[:, 4])
    Pji = @view(flow[:, 5])

    for i = 1:num.Ngen
        gene[i, 1] = system.generator[i, 1]
    end
    Pgen = @view(gene[:,2])

    return Va, Pinj, Pbus, Pij, Pji, Pgen
end
