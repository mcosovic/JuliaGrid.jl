###################
#  DC power flow  #
###################
function rundcpf(settings, system)
    println("Algorithm: DC power flow")
    busi, type, Pload, Gshunt, Tini, geni, Pgen, genOn, fromi, toi,
    resistance, reactance, charging, transTap, transShift, branchOn, Pbus, Pinj,
    Pshift, Ydiag, Pij, admitance = view_dcsystem(system)

  algtime = @elapsed begin
    info = ""
    numbering = false
    bus = collect(1:system.Nbus)
    slack = 0
    @inbounds for i = 1:system.Nbus
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

    Pbus .= 0.0
    gen_bus = renumber(geni, system.Ngen, busi, bus, system.Nbus, numbering)
    @inbounds for (k, i) in enumerate(gen_bus)
        if genOn[k] == 1
            Pbus[i] += Pgen[k] / system.baseMVA
            Pgen[k] = Pgen[k] / system.baseMVA
        end
    end

    from = renumber(fromi, system.Nbra, busi, bus, system.Nbus, numbering)
    to = renumber(toi, system.Nbra, busi, bus, system.Nbus, numbering)

    Ybus = ybusdc(system, Pshift, Ydiag, branchOn, transTap, admitance, reactance, transShift, bus, from, to)
    Ybus = sparse([bus; from; to], [bus; to; from], [Ydiag; -admitance; -admitance], system.Nbus, system.Nbus)
    keep = [collect(1:slack - 1); collect(slack + 1:system.Nbus)]
    Ybus_reduce = Ybus[keep, keep]
    b = Pbus[keep] - Pshift[keep] - (Pload[keep] + Gshunt[keep]) ./ system.baseMVA

    Ti = ls(Ybus_reduce, b, settings.solve)

    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tini[slack] .+ Ti

    @inbounds for i = 1:system.Nbra
        if branchOn[i] == 1
            Pij[i] = admitance[i] * (Ti[from[i]] - Ti[to[i]] - (pi / 180) * transShift[i])
        else
            Pij[i] = 0.0
        end
    end

    Pinj[:] = Ybus * Ti + Pshift
    Pbus[slack] = Pinj[slack] + Pload[slack] / system.baseMVA

    flag = true
    tempslack = 0
    for i = 1:system.Ngen
        if genOn[i] == 1
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
        end
    end
 end # algtime

    results, header = results_flowdc(settings, system, Ti, slack, algtime)
    if !isempty(settings.save)
        savedata(results; info = system.info, group = keys(results), header = header, path = settings.save)
    end

    return results
end


####################
#  DC Ybus matrix  #
####################
function ybusdc(system, Pshift, Ydiag, branchOn, transTap, admitance, reactance, transShift, bus, from, to)
    Pshift .= 0.0
    Ydiag .= 0.0
    @inbounds for i = 1:system.Nbra
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
        else
            admitance[i] = 0.0
        end
    end

    Ybus = sparse([bus; from; to], [bus; to; from], [Ydiag; -admitance; -admitance], system.Nbus, system.Nbus)

    return Ybus
end


###############
#  View data  #
###############
function view_dcsystem(system)
    ################## Read data ##################
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Pload = @view(system.bus[:, 3])
    Gshunt = @view(system.bus[:, 5])
    Tini = @view(system.bus[:, 9])

    geni = @view(system.generator[:, 1])
    Pgen = @view(system.generator[:, 2])
    genOn = @view(system.generator[:, 8])

    fromi = @view(system.branch[:, 2])
    toi = @view(system.branch[:, 3])
    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    ################## Write data ##################
    Pbus = @view(system.bus[:, 10])
    Pinj = @view(system.bus[:, 11])
    Pshift = @view(system.bus[:, 12])
    Ydiag = @view(system.bus[:, 13])

    Pij = @view(system.branch[:, 4]);
    admitance = @view(system.branch[:, 5]);

    return busi, type, Pload, Gshunt, Tini, geni, Pgen, genOn, fromi, toi,
    resistance, reactance, charging, transTap, transShift, branchOn, Pbus, Pinj,
    Pshift, Ydiag, Pij, admitance
end
#-------------------------------------------------------------------------------
