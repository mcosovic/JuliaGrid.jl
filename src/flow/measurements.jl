### Generate measurements
@inbounds function rungenerator(system, measurements, num, numsys, settings, info; flow = 0)
    if settings.runflow == 1
        branch = flow.flow; bus = flow.main
        busi, Vi, Ti, Pinj, Qinj, branchi, fromi, toi, Pij,
            Qij, Pji, Qji, Iij, Dij, Iji, Dji = read_generator(bus, branch)

        for i = 1:numsys.Nbranch
            measurements.legacyFlow[i, 1] = branchi[i]
            measurements.legacyFlow[i + numsys.Nbranch, 1] = branchi[i]
            measurements.legacyFlow[i, 2] = fromi[i]
            measurements.legacyFlow[i + numsys.Nbranch, 2] = toi[i]
            measurements.legacyFlow[i, 3] = toi[i]
            measurements.legacyFlow[i + numsys.Nbranch, 3] = fromi[i]
            measurements.legacyFlow[i, 10] = Pij[i] / system.basePower
            measurements.legacyFlow[i + numsys.Nbranch, 10] = Pji[i] / system.basePower
            measurements.legacyFlow[i, 11] = Qij[i] / system.basePower
            measurements.legacyFlow[i + numsys.Nbranch, 11] = Qji[i] / system.basePower

            measurements.legacyCurrent[i, 1] = branchi[i]
            measurements.legacyCurrent[i + numsys.Nbranch, 1] = branchi[i]
            measurements.legacyCurrent[i, 2] = fromi[i]
            measurements.legacyCurrent[i + numsys.Nbranch, 2] = toi[i]
            measurements.legacyCurrent[i, 3] = toi[i]
            measurements.legacyCurrent[i + numsys.Nbranch, 3] = fromi[i]
            measurements.legacyCurrent[i, 7] = Iij[i]
            measurements.legacyCurrent[i + numsys.Nbranch, 7] = Iji[i]

            measurements.pmuCurrent[i, 1] = branchi[i]
            measurements.pmuCurrent[i + numsys.Nbranch, 1] = branchi[i]
            measurements.pmuCurrent[i, 2] = fromi[i]
            measurements.pmuCurrent[i + numsys.Nbranch, 2] = toi[i]
            measurements.pmuCurrent[i, 3] = toi[i]
            measurements.pmuCurrent[i + numsys.Nbranch, 3] = fromi[i]
            measurements.pmuCurrent[i, 10] = Iij[i]
            measurements.pmuCurrent[i + numsys.Nbranch, 10] = Iji[i]
            measurements.pmuCurrent[i, 11] = (pi / 180) * Dij[i]
            measurements.pmuCurrent[i + numsys.Nbranch, 11] = (pi / 180) * Dji[i]
        end

        for i = 1:numsys.Nbus
            measurements.legacyInjection[i, 1] = busi[i]
            measurements.legacyInjection[i, 8] = Pinj[i] / system.basePower
            measurements.legacyInjection[i, 9] = Qinj[i] / system.basePower

            measurements.legacyVoltage[i, 1] = busi[i]
            measurements.legacyVoltage[i, 5] = Vi[i]

            measurements.pmuVoltage[i, 1] = busi[i]
            measurements.pmuVoltage[i, 8] = Vi[i]
            measurements.pmuVoltage[i, 9] = (pi / 180) * Ti[i]
        end
    end

    names = Dict(:pmu => [:pmuVoltage, :pmuCurrent], :legacy => [:legacyFlow, :legacyCurrent, :legacyInjection, :legacyVoltage])
    measure = [:pmuVoltage, :pmuCurrent, :legacyFlow, :legacyCurrent, :legacyInjection, :legacyVoltage]
    pmuv = 1; pmuc = 1; legf = 1; legc = 1; legi = 1; legv = 1
    if num.pmuNv == 0 measure[1] = :no; pmuv = 0  end
    if num.pmuNc == 0 measure[2] = :no; pmuc = 0 end
    if num.legacyNf == 0 measure[3] = :no; legf = 0 end
    if num.legacyNc == 0 measure[4] = :no; legc = 0 end
    if num.legacyNi == 0 measure[5] = :no; legi = 0 end
    if num.legacyNv == 0 measure[6] = :no; legv = 0 end
    names[:legacy] = intersect(names[:legacy], measure)
    names[:pmu] = intersect(names[:pmu], measure)

    measurements = runset(system, measurements, numsys, settings, names)
    measurements = runvariance(system, measurements, settings, names)
    info = infogenerator(system, measurements, settings, info, names)

    gen = 2
    if numsys.Ngen == 0
        gen = 0
    end
    group = (pmuVoltage = pmuv, pmuCurrent = pmuc, legacyFlow = legf, legacyCurrent = legc, legacyInjection = legi, legacyVoltage = legv, bus = 2, branch = 2, generator = gen, basePower = 2)

    println("Measurment data is successfully generated.")
    if !isempty(settings.save)
        mheader = measureheader(); pheader = psheader(); header = merge(mheader, pheader)
        savedata(measurements, system; group = group, header = header, path = settings.save, info = info)
    end

    return info
end


### Produce  measurement set
@inbounds function runset(system, measurements, numsys, settings, names)
    write = (pmuVoltage = [4, 7], pmuCurrent = [6, 9], legacyFlow = [6, 9], legacyCurrent = [6], legacyInjection = [4, 7], legacyVoltage = [4])
    type = (pmucomplete = :pmu,  legacycomplete = :legacy, pmuredundancy = :pmu,  legacyredundancy = :legacy)

    for set in keys(settings.set)
        if set in [:pmucomplete :legacycomplete]
            for i in names[type[set]]
                T::Array{Float64,2} = getfield(measurements, i)
                T[:, write[i]] = ones(size(T, 1), length(write[i]))
            end
        end
        if set in [:pmuVoltage, :pmuCurrent, :legacyFlow, :legacyCurrent, :legacyInjection, :legacyVoltage]
            for (pos, howMany) in enumerate(settings.set[set])
                success = false
                T::Array{Float64,2} = getfield(measurements, set)
                N = size(T, 1)
                if 0 <= howMany <= N
                    success = true
                    T[:, write[set][pos]] = zeros(N)
                    idxn = randperm(N)
                    idx = idxn[1:Int64(howMany)]
                    T[idx, write[set][pos]] = ones(N)[idx]
                elseif howMany > N || howMany == -200.0
                    success = true
                    T[:, write[set][pos]] = zeros(N)
                    T[:, write[set][pos]] = ones(N)
                elseif !success && howMany != -100
                    throw(ErrorException("the name-value pair setting is incorect, deployment measurements according to TYPE failed"))
                end
            end
        end
        if set in [:pmuredundancy :legacyredundancy]
            Nmax = 0
            for i in names[type[set]]
                Nmax += length(write[i]) * size(getfield(measurements, i), 1)
            end
            success = false
            howMany = settings.set[set][1]
            if 0 <= howMany <= Nmax / (2 * numsys.Nbus - 1)
                success = true
                idxn = randperm(Nmax)
                idx = idxn[1:trunc(Int, round((2 * numsys.Nbus - 1) * howMany))]
                total_set = fill(0.0, Nmax)
                total_set[idx] = ones(Nmax)[idx]
            elseif howMany > Nmax / (2 * numsys.Nbus - 1) || howMany == -200.0
                success = true
                total_set = fill(1.0, Nmax)
            end
            if success
                start = 0
                last = 0
                for i in names[type[set]]
                    for k in write[i]
                        T::Array{Float64,2} = getfield(measurements, i)
                        last += size(T, 1)
                        T[:, k] = total_set[(start + 1):last]
                        start += size(T, 1)
                    end
                end
            else
                throw(ErrorException("the name-value pair setting is incorect, deployment measurements according to REDUNDANCY failed"))
            end
        end
        if set == :pmudevice
            if :pmuVoltage in names[:pmu] && :pmuCurrent in names[:pmu]
                success = false
                howMany = settings.set[set][1]
                N = size(measurements.pmuVoltage, 1)
                if 0 <= howMany <= N
                    success = true
                    idxn = randperm(N)
                    idx = idxn[1:Int64(howMany)]
                elseif howMany > N || howMany == -200.0
                    success = true
                    idx = collect(1:N)
                end
                if success
                    Nc = size(measurements.pmuCurrent, 1)
                    measurements.pmuVoltage[:, [4, 7]] = zeros(N, 2)
                    measurements.pmuCurrent[:, [6, 9]] = zeros(Nc, 2)
                    labelVol = measurements.pmuVoltage[:, 1]
                    labelCurr = measurements.pmuCurrent[:, 2]
                    try
                        labelVol = measurements.pmuVoltage[:, 10]
                        labelCurr = measurements.pmuCurrent[:, 12]
                    catch
                    end
                    for i in idx
                        measurements.pmuVoltage[i, 4] = 1.0
                        measurements.pmuVoltage[i, 7] = 1.0
                        for j = 1:size(measurements.pmuCurrent, 1)
                            if labelVol[i] == labelCurr[j]
                                measurements.pmuCurrent[j, 6] = 1.0
                                measurements.pmuCurrent[j, 9] = 1.0
                            end
                        end
                    end
                else
                    throw(ErrorException("the name-value pair setting is incorect, deployment measurements according to DEVICE failed"))
                end
            else
                throw(ErrorException("the complete PMU measurement DATA is not found"))
           end
        end
        if set == :pmuoptimal
            if :pmuVoltage in names[:pmu] && :pmuCurrent in names[:pmu]
                Nvol = size(measurements.pmuVoltage, 1)
                Ncurr = size(measurements.pmuCurrent, 1)
                if Nvol == numsys.Nbus && Ncurr == 2 * numsys.Nbranch
                    bus = collect(1:numsys.Nbus)
                    numbering = false
                    fromi = convert(Array{Int64,1}, system.branch[:, 2])
                    toi = convert(Array{Int64,1}, system.branch[:, 3])
                    busi = @view(system.bus[:, 1])
                    for i = 1:numsys.Nbus
                        if bus[i] != busi[i]
                            numbering = true
                        end
                    end
                    from = renumber(fromi, numsys.Nbranch, busi, bus, numsys.Nbus, numbering)
                    to = renumber(toi, numsys.Nbranch, busi, bus, numsys.Nbus, numbering)

                    A = sparse([bus; from; to], [bus; to; from], fill(1, numsys.Nbus + 2 * numsys.Nbranch), numsys.Nbus, numsys.Nbus)
                    f  = fill(1, numsys.Nbus);
                    lb = fill(0, numsys.Nbus);
                    ub = fill(1, numsys.Nbus);
                    model = Model(GLPK.Optimizer)

                    @variable(model, x[i = 1:numsys.Nbus], Int)
                    @constraint(model, lb .<= x .<= ub)
                    @constraint(model, -A * x .<= -f)
                    @objective(model, Min, sum(x))
                    optimize!(model)
                    x = JuMP.value.(x)
                    idx = findall(x->x == 1, x)

                    measurements.pmuVoltage[:, [4, 7]] = zeros(Nvol, 2)
                    measurements.pmuCurrent[:, [6, 9]] = zeros(Ncurr, 2)
                    for i in idx
                        measurements.pmuVoltage[i, 4] = 1.0
                        measurements.pmuVoltage[i, 7] = 1.0
                        for j = 1:numsys.Nbranch
                            if busi[i] == fromi[j]
                                measurements.pmuCurrent[j, 6] = 1.0
                                measurements.pmuCurrent[j, 9] = 1.0
                            end
                            if busi[i] == toi[j]
                                measurements.pmuCurrent[j + numsys.Nbranch, 6] = 1.0
                                measurements.pmuCurrent[j + numsys.Nbranch, 9] = 1.0
                            end
                        end
                    end
                else
                    throw(ErrorException("the optimal algorithm requires the concordant number of buses and branches, and corresponding measurements"))
                end
            else
                throw(ErrorException("the complete PMU measurement DATA is not found"))
            end
        end
    end

    return measurements
end


### Produce measurement variances
@inbounds function runvariance(system, measurements, settings, names)
    write = (pmuVoltage = [2 8 3; 5 9 6], pmuCurrent = [4 10 5; 7 11 8], legacyFlow = [4 10 5; 7 11 8], legacyCurrent = [4 7 5], legacyInjection = [2 8 3; 5 9 6], legacyVoltage = [2 5 3])
    type = (pmucomplete = :pmu, legacycomplete = :legacy, pmurandom = :pmu, legacyrandom = :legacy)

    for var in keys(settings.variance)
        if var in [:pmucomplete :legacycomplete]
            howMany = settings.variance[var][1]
            if howMany > 0
                for i in names[type[var]]
                    T::Array{Float64,2} = getfield(measurements, i)
                    for row in eachrow(write[i])
                        T[:, row[3]] .= howMany
                        T[:, row[1]] .= T[:, row[2]] .+ howMany.^(1/2) .* randn!(zeros(size(T, 1)))
                    end
                end
            else
                error("the variance must be positive number")
            end
        end
        if var in [:pmurandom :legacyrandom]
            min = minimum(settings.variance[var])
            max = maximum(settings.variance[var])
            if min > 0 && max > 0
                for i in names[type[var]]
                    T::Array{Float64,2} = getfield(measurements, i)
                    for row in eachrow(write[i])
                        T[:, row[3]] .= min .+ (max - min) .* rand(size(T, 1))
                        T[:, row[1]] .= T[:, row[2]] .+ T[:, row[3]].^(1/2) .* randn!(zeros(size(T, 1)))

                    end
                end
            else
                throw(ErrorException("the variance value must be positive number"))
            end
        end
        if var in [:pmuVoltage, :pmuCurrent, :legacyFlow, :legacyCurrent, :legacyInjection, :legacyVoltage]
            for (pos, howMany) in enumerate(settings.variance[var])
                if howMany != -100.0
                    if howMany > 0
                        T::Array{Float64,2} = getfield(measurements, var)
                        T[:, write[var][pos, 3]] .= howMany
                        T[:, write[var][pos, 1]] .= T[:, write[var][pos, 2]] .+ howMany.^(1/2) .* randn!(zeros(size(T, 1)))
                    else
                        throw(ErrorException("the variance value must be positive number"))
                    end
                end
            end
        end
    end

    return measurements
end


### Read data
function read_generator(bus, branch)
    busi = @view(bus[:, 1])
    Vi = @view(bus[:, 2])
    Ti = @view(bus[:, 3])
    Pinj = @view(bus[:, 4])
    Qinj = @view(bus[:, 5])

    branchi = @view(branch[:, 1])
    fromi = @view(branch[:, 2])
    toi = @view(branch[:, 3])
    Pij = @view(branch[:, 4])
    Qij = @view(branch[:, 5])
    Pji = @view(branch[:, 6])
    Qji = @view(branch[:, 7])
    Iij = @view(branch[:, 11])
    Dij = @view(branch[:, 12])
    Iji = @view(branch[:, 13])
    Dji = @view(branch[:, 14])

    return busi, Vi, Ti, Pinj, Qinj,
        branchi, fromi, toi, Pij, Qij, Pji, Qji, Iij, Dij, Iji, Dji
end
