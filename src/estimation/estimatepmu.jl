struct StateEstimationPMU
    main::Array{Float64,2}
    flow::Array{Float64,2}
    estimate::Array{Float64,2}
    error::Array{Float64,1}
    baddata::Array{Float64,2}
    observability::Array{Array{Int64,1},1}
end


#### PMU state estimation
function runpmuse(system, measurements, num, numsys, settings, info)
    printstyled("Algorithm: Linear PMU state estimation\n"; bold = true)

    ########## Pre-processing ##########
    busi, type, Gshunt, Bshunt, Tini,
    branchi, resistance, reactance, charging, transTap, transShift, branchOn,
    meanVi, variVi, onVi, meanTi, variTi, onTi,
    meanIij, variIij, onIij, meanDij, variDij, onDij = read_pmusystem(system, measurements)

    main = fill(0.0, numsys.Nbus, 7)
    flow =  fill(0.0, numsys.Nbranch, 14)
    Va, Vm, Pinj, Qinj, Pshunt, Qshunt, Pij, Qij, Pji, Qji, Qcharging, Ploss,
    Qloss, Imij, Iaij, Imji, Iaji, badsave, islands = write_pmusystem(system, numsys, main, flow)

  algtime = @elapsed begin
    ########## Pre-processing ##########
    fromi = convert(Array{Int64,1}, system.branch[:, 2])
    toi = convert(Array{Int64,1}, system.branch[:, 3])
    branchiC = convert(Array{Int64,1}, measurements.pmuCurrent[:, 1])
    fromiC = convert(Array{Int64,1}, measurements.pmuCurrent[:, 2])
    toiC = convert(Array{Int64,1}, measurements.pmuCurrent[:, 3])
    busiV = convert(Array{Int64,1}, measurements.pmuVoltage[:, 1])

    bus = collect(1:numsys.Nbus)
    branch = collect(1:numsys.Nbranch)

    newnumbering = false
    @inbounds for i = 1:numsys.Nbus
        if bus[i] != busi[i]
            newnumbering = true
        end
    end
    if newnumbering
        println("The new bus numbering is running.")
    end
    numlabel = false
    @inbounds for i = 1:numsys.Nbranch
        if branch[i] != branchi[i]
            numlabel = true
            break
        end
    end
    if numlabel
        println("The new branch label numbering is running.")
    end
    from = renumber(fromi, numsys.Nbranch, busi, bus, numsys.Nbus, newnumbering)
    to = renumber(toi, numsys.Nbranch, busi, bus, numsys.Nbus, newnumbering)
    fromC = renumber(fromiC, num.pmuNc, busi, bus, numsys.Nbus, newnumbering)
    toC = renumber(toiC, num.pmuNc, busi, bus, numsys.Nbus, newnumbering)
    busV = renumber(busiV, num.pmuNv, busi, bus, numsys.Nbus, newnumbering)
    branchC = renumber(branchiC, num.pmuNc, branchi, branch, numsys.Nbranch, newnumbering)

    ########## Jacobian ##########
    Nelement = 0; Nmeasure = 0; Ncur = 0; Nvol = 0;
    @inbounds for i = 1:num.pmuNc
        if onIij[i] == 1 || onDij[i] == 1
            onIij[i] = 1.0; onDij[i] = 1.0
            Nelement += 8; Nmeasure += 2; Ncur += 1
        end
    end
    @inbounds for i = 1:num.pmuNv
        if onVi[i] == 1 || onTi[i] == 1
            onVi[i] = 1.0; onTi[i] = 1.0
            Nelement += 2; Nmeasure += 2; Nvol += 1
        end
    end

    row = fill(0, Nelement); col = similar(row); jac = fill(0.0, Nelement)
    mean = fill(0.0, Nmeasure); variance = similar(mean);
    index = 1; rowindex = 1
    if settings.covariance
        idxco = 1
        covariance = fill(0.0, Ncur + Nvol)
    end

    Ybus, YbusT, Ytt, Yff, Yft, Ytf, admittance, tap, shunt = ybusac(system, numsys, bus, from, to, branchOn,
        Gshunt, Bshunt, resistance, reactance, charging, transTap, transShift)

    @inbounds for i = 1:num.pmuNc
        if onIij[i] == 1 || onDij[i] == 1
            idx = branchC[i]
            if branchOn[idx] == 1
                gij = real(admittance[idx])
                bij = imag(admittance[idx])

                if transTap[idx] == 0
                    tapij = 1
                else
                    tapij = transTap[idx]
                end

                shift = (pi / 180) * transShift[idx]
                bsi = charging[idx] / 2
            else
                gij = 0.0; bij = 0.0; bsi = 0.0; tapij = 1.0; shift = 0.0
            end

            ##### dIreal/dVreal,i and dIimag/dVimag,i  #####
            row[index] = rowindex; col[index] = fromC[i]
            row[index + 1] = rowindex + 1; col[index + 1] = fromC[i] + numsys.Nbus
            if from[idx] == fromC[i]
                jac[index] = gij / (tapij^2)
                jac[index + 1] = jac[index]
            else
                jac[index] = gij
                jac[index + 1] = jac[index]
            end
            index += 2

            ##### dIreal/dVreal,j and dIimag/dVimag,j #####
            row[index] = rowindex; col[index] = toC[i]
            row[index + 1] = rowindex + 1; col[index + 1] = toC[i] + numsys.Nbus
            if from[idx] == fromC[i]
                jac[index] = -(1 / tapij) * (gij * cos(shift) - bij * sin(shift))
                jac[index + 1] = jac[index]
            else
                jac[index] = -(1 / tapij) * (gij * cos(shift) + bij * sin(shift))
                jac[index + 1] = jac[index]
            end
            index += 2

            ##### dIreal/dVimag,i and dIimag/dVreal,i #####
            row[index] = rowindex; col[index] = fromC[i] + numsys.Nbus
            row[index + 1] = rowindex + 1; col[index + 1] = fromC[i]
            if from[idx] == fromC[i]
                jac[index] = -(bij + bsi) / (tapij^2)
                jac[index + 1] = -jac[index]
            else
                jac[index] = -bij - bsi
                jac[index + 1] = -jac[index]
            end
            index += 2

            ##### dIreal/dVimag,j and dIimag/dVreal,j#####
            row[index] = rowindex; col[index] = toC[i] + numsys.Nbus
            row[index + 1] = rowindex + 1; col[index + 1] = toC[i]
            if from[idx] == fromC[i]
                jac[index] = (1 / tapij) * (bij * cos(shift) + gij * sin(shift))
                jac[index + 1] =  -jac[index]
            else
                jac[index] = (1 / tapij) * (bij * cos(shift) - gij * sin(shift))
                jac[index + 1] =  -jac[index]
            end
            index += 2

            ##### Mean Ireal, Iimag #####
            mean[rowindex] = meanIij[i] * cos(meanDij[i])
            mean[rowindex + 1] = meanIij[i] * sin(meanDij[i])

            ##### Variance Ireal, Iimag #####
            variance[rowindex] = variIij[i] * (cos(meanDij[i]))^2 + variDij[i] * (meanIij[i] * sin(meanDij[i]))^2
            variance[rowindex + 1] = variIij[i] * (sin(meanDij[i]))^2 + variDij[i] * (meanIij[i] * cos(meanDij[i]))^2

            ##### Covariance #####
            if settings.covariance
                covariance[idxco] = sin(meanDij[i]) * cos(meanDij[i]) * (variIij[i] - variDij[i] * meanIij[i]^2)
                idxco += 1
            end

            rowindex += 2
        end
    end

    rowindex = 2 * Ncur + 1
    for i = 1:num.pmuNv
        if onVi[i] == 1 || onTi[i] == 1
            ##### dVreal/dVreal,i #####
            row[index] = rowindex
            col[index] = busiV[i]
            jac[index] = 1.0

            ##### Vimag/dVimag,i #####
            row[index + 1] = rowindex + 1
            col[index + 1] = busiV[i] + numsys.Nbus
            jac[index + 1] = 1.0
            index += 2

            ##### Mean Vreal, Vimag #####
            mean[rowindex] = meanVi[i] * cos(meanTi[i])
            mean[rowindex + 1] = meanVi[i] * sin(meanTi[i])

            ##### Variance Vreal, Vimag #####
            variance[rowindex] = variVi[i] * (cos(meanTi[i]))^2 + variTi[i] * (meanVi[i] * sin(meanTi[i]))^2
            variance[rowindex + 1] = variVi[i] * (sin(meanTi[i]))^2 + variTi[i] * (meanVi[i] * cos(meanTi[i]))^2

            ##### Covariance #####
            if settings.covariance
                covariance[idxco] = sin(meanTi[i]) * cos(meanTi[i]) * (variVi[i] - variTi[i] * meanVi[i]^2)
                idxco += 1
            end

            rowindex += 2
        end
    end

    J = sparse(row, col, jac, Nmeasure, 2 * numsys.Nbus)

    ########## Observability analysis ##########
    Npseudo = 0

    ########## LAV ##########
    if settings.lav[:lav] == 1
        VrealVimag = Array{Float64}(undef, 2 * numsys.Nbus)
        Nvar = 2 * numsys.Nbus
        x = lav(J, mean, Nvar, Nmeasure, settings)
        for i = 1:Nvar
            VrealVimag[i] = x[i] - x[Nvar + i]
        end
    end


    ########## WLS and bad data analysis ##########
    if settings.lav[:lav] == 0
        if settings.covariance
            idxVar = collect(1:Nmeasure); Icov = collect(1:2:Nmeasure); Jcov = collect(2:2:Nmeasure)
            R = sparse([idxVar; Icov; Jcov], [idxVar; Jcov; Icov], [variance; covariance; covariance], Nmeasure, Nmeasure)
            W = sparse(inv(Matrix(R)))
            G = J' * W * J
            b = J' * W * mean
        else
            W = spdiagm(0 => 1 ./ sqrt.(variance))
            H = W * J
            G = H' * H
            b = H' * W * mean
        end

        if settings.bad[:bad] == 1
            idx = findall(!iszero, J)
        end

        pass = 1; rbelow = true
        while rbelow
            if settings.bad[:pass] < pass || settings.bad[:bad] == 0
                rbelow = false
            end

            VrealVimag = wls(G, b, settings.solve)

            if rbelow
                J, mean, W, badsave, rbelow = baddata(settings, numsys, VrealVimag, mean, variance, W, G, J, Nmeasure, idx, badsave, rbelow)
                pass += 1
            end
        end
    end

    Vc = zeros(ComplexF64, numsys.Nbus)
    for i = 1:numsys.Nbus
        Vc[i] = complex(VrealVimag[i], VrealVimag[i + numsys.Nbus])
    end

    for i = 1:numsys.Nbus
        Vm[i] = abs(Vc[i])
        Va[i] = (180 / pi) * angle(Vc[i])

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
    end

    acflow(system.basePower, numsys, from, to, branchOn, Vc, Yff, Yft, Ytt, Ytf,
        admittance, tap, resistance, reactance, charging,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji)

    estimate_row = 9; error_row = 3; exact = false
    if size(measurements.pmuVoltage, 2) == 9 && size(measurements.pmuCurrent, 2) == 11
        estimate_row = 11; error_row = 6; exact = true
    end
    estimate = zeros(Nmeasure, estimate_row)
    error = zeros(error_row)
    Nm = Nmeasure - size(badsave, 1)
    idx = 1; toRad = pi / 180
    for (i, on) in enumerate(onIij)
        if on != 0
            idy = idx + 1
            estimate[idx, 1:5] = [idx 1.0 2.0 9.0 i]
            estimate[idy, 1:5] = [idx 1.0 2.0 10.0 i]

            if idx in badsave[:, 1]
                estimate[idx, 2] = 2.0; onIij[i] = 0; onDij[i] = 0
            end
            if idy in badsave[:, 1]
                estimate[idy, 2] = 2.0; onIij[i] = 0; onDij[i] = 0
            end

            estimate[idx, 6] = meanIij[i] * cos(meanDij[i])
            estimate[idy, 6] = meanIij[i] * sin(meanDij[i])
            estimate[idx, 7] = variance[idx]
            estimate[idy, 7] = variance[idy]
            k = branchC[i]
            if measurements.pmuCurrent[i, 2] == system.branch[k, 2] && measurements.pmuCurrent[i, 3] == system.branch[k, 3]
                estimate[idx, 8] = Imij[k] * cos(toRad * Iaij[k])
                estimate[idy, 8] = Imij[k] * sin(toRad * Iaij[k])
            else
                estimate[idx, 8] = Imji[k] * cos(toRad * Iaji[k])
                estimate[idy, 8] = Imji[k] * sin(toRad * Iaji[k])
            end
            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])
            estimate[idy, 9] = abs(estimate[idy, 6] - estimate[idy, 8])

            if estimate[idx, 2] != 2.0
                error[1] += estimate[idx, 9] ./ Nm
                error[2] += estimate[idx, 9]^2 ./ Nm
                error[3] += estimate[idx, 9]^2 ./ variance[idx]
            end
            if estimate[idy, 2] != 2.0
                error[1] += estimate[idy, 9] ./ Nm
                error[2] += estimate[idy, 9]^2 ./ Nm
                error[3] += estimate[idy, 9]^2 ./ variance[idy]
            end

            if exact
                estimate[idx, 10] = measurements.pmuCurrent[i, 10] * cos(measurements.pmuCurrent[i, 11])
                estimate[idy, 10] = measurements.pmuCurrent[i, 10] * sin(measurements.pmuCurrent[i, 11])

                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])
                estimate[idy, 11] = abs(estimate[idy, 8] - estimate[idy, 10])

                if estimate[idx, 2] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / variance[idx]
                end
                if estimate[idy, 2] != 2.0
                    error[4] += estimate[idy, 11] / Nm
                    error[5] += estimate[idy, 11]^2 / Nm
                    error[6] += estimate[idy, 11]^2 / variance[idy]
                end
            end
            idx += 2
        end
    end
    for (i, on) in enumerate(onVi)
        if on != 0
            idy = idx + 1
            estimate[idx, 1:5] = [idx 1.0 2.0 11.0 i]
            estimate[idy, 1:5] = [idx 1.0 2.0 12.0 i]

            if idx in badsave[:, 1]
                estimate[idx, 2] = 2.0; onVi[i] = 0; onTi[i] = 0
            end
            if idy in badsave[:, 1]
                estimate[idy, 2] = 2.0; onVi[i] = 0; onTi[i] = 0
            end

            estimate[idx, 6] = meanVi[i] * cos(meanTi[i])
            estimate[idy, 6] = meanVi[i] * sin(meanTi[i])
            estimate[idx, 7] = variance[idx]
            estimate[idy, 7] = variance[idy]
            estimate[idx, 8] = Vm[busV[i]] * cos(toRad * Va[busV[i]])
            estimate[idy, 8] = Vm[busV[i]] * sin(toRad * Va[busV[i]])

            estimate[idx, 9] = abs(estimate[idx, 6] - estimate[idx, 8])
            estimate[idy, 9] = abs(estimate[idy, 6] - estimate[idy, 8])

            if estimate[idx, 2] != 2.0
                error[1] += estimate[idx, 9] ./ Nm
                error[2] += estimate[idx, 9]^2 ./ Nm
                error[3] += estimate[idx, 9]^2 ./ variance[idx]
            end
            if estimate[idy, 2] != 2.0
                error[1] += estimate[idy, 9] ./ Nm
                error[2] += estimate[idy, 9]^2 ./ Nm
                error[3] += estimate[idy, 9]^2 ./ variance[idy]
            end

            if exact
                estimate[idx, 10] = measurements.pmuVoltage[i, 8] * cos(measurements.pmuVoltage[i, 9])
                estimate[idy, 10] = measurements.pmuVoltage[i, 8] * sin(measurements.pmuVoltage[i, 9])

                estimate[idx, 11] = abs(estimate[idx, 8] - estimate[idx, 10])
                estimate[idy, 11] = abs(estimate[idy, 8] - estimate[idy, 10])

                if estimate[idx, 2] != 2.0
                    error[4] += estimate[idx, 11] / Nm
                    error[5] += estimate[idx, 11]^2 / Nm
                    error[6] += estimate[idx, 11]^2 / variance[idx]
                end
                if estimate[idy, 2] != 2.0
                    error[4] += estimate[idy, 11] / Nm
                    error[5] += estimate[idy, 11]^2 / Nm
                    error[6] += estimate[idy, 11]^2 / variance[idy]
                end
            end
            idx += 2
        end
    end
    error[2] = sqrt(error[2])
    if exact
        error[5] = sqrt(error[5])
    end

    pass = collect(1:size(badsave, 1))
    idxbad = trunc.(Int, badsave[:, 1])
    bad = [pass estimate[idxbad, 3:5] badsave[:, 2] estimate[idxbad, 2]]

 end # algtime

    ########## Results ##########
    results = StateEstimationPMU(main, flow, estimate, error, bad, islands)
    header, group = results_estimatepmu(system, numsys, measurements, num, settings, results, idxbad, Npseudo, algtime)
    if !isempty(settings.save)
        savedata(results, measurements, system; info = info, group = group, header = header, path = settings.save)
    end

    return results
end


### View system
function read_pmusystem(system, measurements)
    busi = @view(system.bus[:, 1])
    type = @view(system.bus[:, 2])
    Gshunt = @view(system.bus[:, 5])
    Bshunt =  @view(system.bus[:, 6])
    Tini = @view(system.bus[:, 9])

    branchi = @view(system.branch[:, 1])
    resistance = @view(system.branch[:, 4])
    reactance = @view(system.branch[:, 5])
    charging = @view(system.branch[:, 6])
    transTap = @view(system.branch[:, 10])
    transShift = @view(system.branch[:, 11])
    branchOn = @view(system.branch[:, 12])

    meanVi = @view(measurements.pmuVoltage[:, 2])
    variVi = @view(measurements.pmuVoltage[:, 3])
    onVi = @view(measurements.pmuVoltage[:, 4])
    meanTi = @view(measurements.pmuVoltage[:, 5])
    variTi = @view(measurements.pmuVoltage[:, 6])
    onTi = @view(measurements.pmuVoltage[:, 7])

    meanIij = @view(measurements.pmuCurrent[:, 4])
    variIij = @view(measurements.pmuCurrent[:, 5])
    onIij = @view(measurements.pmuCurrent[:, 6])
    meanDij = @view(measurements.pmuCurrent[:, 7])
    variDij = @view(measurements.pmuCurrent[:, 8])
    onDij = @view(measurements.pmuCurrent[:, 9])

    return busi, type, Gshunt, Bshunt, Tini,
           branchi, resistance, reactance, charging, transTap, transShift, branchOn,
           meanVi, variVi, onVi, meanTi, variTi, onTi,
           meanIij, variIij, onIij, meanDij, variDij, onDij
end


### Write data
function write_pmusystem(system, numsys, main, flow)
    for i = 1:numsys.Nbus
        main[i, 1] = system.bus[i, 1]
    end
    Vm = @view(main[:, 2])
    Va = @view(main[:, 3])
    Pinj = @view(main[:, 4])
    Qinj = @view(main[:, 5])
    Pshunt = @view(main[:, 6])
    Qshunt = @view(main[:, 7])

    for i = 1:numsys.Nbranch
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

    badsave = reshape(Float64[], 0, 2)
    islands = [Int64[]]

    return Va, Vm, Pinj, Qinj, Pshunt, Qshunt,
        Pij, Qij, Pji, Qji, Qcharging, Ploss, Qloss, Imij, Iaij, Imji, Iaji,
        badsave, islands
end
