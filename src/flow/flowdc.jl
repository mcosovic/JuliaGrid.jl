### DC power flow
@inbounds function rundcpf(system, num, settings, info)
    printstyled("Algorithm: DC power flow\n"; bold = true)
    busi, type, Pload, Gshunt, Tini, Pgeni, genOn, resistance, reactance,
    charging, transTap, transShift, branchOn = view_dcsystem(system)

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
            println("The new bus numbering is running.")
        end
        if type[i] == 3
            slack = bus[i]
        end
    end

    if slack == 0
        slack = 1
        println("The slack bus is not found. Slack bus is the first bus.")
    end

    Pbus = fill(0.0, num.Nbus)
    Pgen = fill(0.0, num.Ngen)
    gen_bus = renumber(geni, num.Ngen, busi, bus, num.Nbus, numbering)
    for (k, i) in enumerate(gen_bus)
        if genOn[k] == 1
            Pbus[i] += Pgeni[k] / system.basePower
            Pgen[k] = Pgeni[k] / system.basePower
        end
    end

    from = renumber(fromi, num.Nbranch, busi, bus, num.Nbus, numbering)
    to = renumber(toi, num.Nbranch, busi, bus, num.Nbus, numbering)

    ########## Solve the system ##########
    Ybus, admitance, Pshift = ybusdc(system, num, branchOn, transTap, reactance, transShift, bus, from, to)

    keep = [collect(1:slack - 1); collect(slack + 1:num.Nbus)]
    Ybus_reduce = Ybus[keep, keep]
    b = Pbus[keep] - Pshift[keep] - (Pload[keep] + Gshunt[keep]) ./ system.basePower

    Ti = ls(Ybus_reduce, b, settings.solve)

    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tini[slack] .+ Ti

    ########## Post-processing ##########
    Pij = fill(0.0, num.Nbranch)
    for i = 1:num.Nbranch
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i])
        end
    end

    Pinj = Ybus * Ti + Pshift
    Pbus[slack] = Pinj[slack] + Pload[slack] / system.basePower

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
    results, header, group = results_flowdc(system, num, settings, Ti, Pinj, Pbus, Pij, Pgen, slack, algtime)
    if !isempty(settings.save)
        savedata(results, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### DC Ybus matrix
@inbounds function ybusdc(system, num, branchOn, transTap, reactance, transShift, bus, from, to)
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

            shift = (pi / 180) * transShift[i] * reactance[i]
            Pshift[from[i]] -= shift
            Pshift[to[i]] += shift

            Ydiag[from[i]] += admitance[i]
            Ydiag[to[i]] += admitance[i]
        end
    end

    Ybus = sparse([bus; from; to], [bus; to; from], [Ydiag; -admitance; -admitance], num.Nbus, num.Nbus)

    return Ybus, admitance, Pshift
end


### View data
function view_dcsystem(system)
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
