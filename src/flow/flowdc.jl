###################
#  DC Power Flow  #
###################


#-------------------------------------------------------------------------------
function rundcpf(settings, system)
    busi, type, Pload, Gshunt, Tini, geni, Pgen, genOn, fromi, toi,
    resistance, reactance, charging, transTap, transShift, branchOn, Pbus, Pinj,
    Pshift, Ydiag, Pij, admitance = view_dcsystem(system)

  algtime = @elapsed begin
    numbering = false
    Nbus = size(system.bus, 1)
    Ngen = size(system.generator, 1)
    Nbranch = size(system.branch, 1)
    bus = collect(1:Nbus)
    slack = 0

    @inbounds for i = 1:Nbus
        if bus[i] != busi[i]
            numbering = true
        end
        if type[i] == 3
            slack = bus[i]
        end
    end

    if slack == 0
        slack = 1
        println("  The slack bus is not found. Slack bus is the first bus.")
    end

    if !isempty(system.generator)
        gen_bus = numbering_generator(geni, busi, Nbus, bus, numbering)
        Pbus .= 0.0
        @inbounds for (k, i) in enumerate(gen_bus)
            if genOn[k] == 1
                Pbus[i] += Pgen[k] / system.baseMVA
                Pgen[k] = Pgen[k] / system.baseMVA
            end
        end
    end

    from, to = numbering_branch(fromi, toi, busi, Nbranch, Nbus, bus, numbering)
    Pshift .= 0.0
    Ydiag .= 0.0
    @inbounds for i = 1:Nbranch
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

    Ybus = sparse([bus; from; to], [bus; to; from], [Ydiag; -admitance; -admitance], Nbus, Nbus)
    keep = [collect(1:slack - 1); collect(slack + 1:Nbus)]
    Ybus_reduce = Ybus[keep, keep]
    b = Pbus[keep] - Pshift[keep] - (Pload[keep] + Gshunt[keep]) ./ system.baseMVA

    if settings.solve == "mldivide"
        Ti = Ybus_reduce \ b
    end
    if settings.solve == "lu"
        F = lu(Ybus_reduce)
        Ti = F.U \  (F.L \ ((F.Rs .* b)[F.p]))
        Ti = Ti[sortperm(F.q)]
    end

    insert!(Ti, slack, 0.0)
    Ti =  (pi / 180) * Tini[slack] .+ Ti
    println("  Algorithm: DC power flow")

    @inbounds for i = 1:Nbranch
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
    for i = 1:Ngen
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
  end

    BUS, BRANCH, GENERATOR = results_flowdc(settings, system, Nbus, Nbranch, Ngen, Ti, slack, algtime)

    return BUS, BRANCH, GENERATOR
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function view_dcsystem(system)
    # Read Data
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

    # Write Data
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
