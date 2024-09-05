"""
    residualTest!(system::PowerSystem, device::Measurement, analysis::StateEstimation;
        threshold)

The function conducts bad data detection and identification using the largest normalized
residual test, subsequently removing measurement outliers from the measurement set. It can
be executed after obtaining WLS estimator.

# Arguments
This function requires the types `PowerSystem`, `Measurement`, and `StateEstimation`. The
abstract type `StateEstimation` can have the following subtypes:
- `ACStateEstimation`: Conducts bad data analysis within AC state estimation.
- `PMUStateEstimation`: Conducts bad data analysis within PMU state estimation.
- `DCStateEstimation`: Conducts bad data analysis within DC state estimation.

# Keyword
The keyword `threshold` establishes the identification threshold. If the largest
normalized residual surpasses this threshold, the measurement is flagged as bad data. The
default threshold value is set to `threshold = 3.0`.

# Updates
If bad data is detected, the function flags the corresponding measurement within the
`Measurement` type as out-of-service.

Moreover, for `DCStateEstimation` and `PMUStateEstimation` types, the function removes
the corresponding measurement from the coefficient matrix and mean vector. This facilitates
direct progress to the function that solves the state estimation problem.

# Returns
The function returns an instance of the `BadData` type, which includes:
- `detect`: Returns `true` after the function's execution if bad data is detected.
- `maxNormalizedResidual`: Denotes the value of the largest normalized residual.
- `label`: Signifies the label of the bad data.
- `index`: Represents the index of the bad data.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcWlsStateEstimation(system, device)
solve!(system, analysis)

outlier = residualTest!(system, device, analysis; threshold = 4.0)
solve!(system, analysis)
```
"""
function residualTest!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation{LinearWLS{T}}; threshold::Float64 = 3.0) where T <: Union{Normal, Orthogonal}
    errorVoltage(analysis.voltage.angle)

    bad = BadData(false, 0.0, "", 0)
    bus = system.bus
    se = analysis.method

    slackRange, elementsRemove = deleteSlackCoefficient(analysis, bus.layout.slack)
    gain = dcGain(analysis, bus.layout.slack)

    if !isa(se.factorization, UMFPACK.UmfpackLU{Float64, Int64})
        F = lu(gain)
    else
        F = se.factorization
    end

    ########## Sparse Matrix Inverese ##########
    gainInverse = sparseInverse(F, gain, bus.number)

    ########## Diagonal entries of residual matrix ##########
    JGi = se.coefficient * gainInverse
    idx = findall(!iszero, se.coefficient)
    c = fill(0.0, size(se.coefficient, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * se.coefficient[i]
    end

    ########## Largest normalized residual ##########
    h = se.coefficient * analysis.voltage.angle
    bad.maxNormalizedResidual = 0.0
    bad.index = 0
    @inbounds for i = 1:se.number
        residual = se.mean[i] - h[i]
        if residual != 0.0
            normResidual = abs(residual) / sqrt(abs((1 / se.precision.nzval[i]) - c[i]))
            if normResidual > bad.maxNormalizedResidual
                bad.maxNormalizedResidual = normResidual
                bad.index = i
            end
        end
    end

    restoreSlackCoefficient(analysis, slackRange, elementsRemove, bus.layout.slack)

    if bad.maxNormalizedResidual > threshold
        se.run = true
        bad.detect = true

        colIndecies = findall(!iszero, se.coefficient[bad.index, :])
        @inbounds for col in colIndecies
            se.coefficient[bad.index, col] = 0.0
        end
        se.mean[bad.index] = 0.0
    end

    if bad.index != 0
        if bad.index <= device.wattmeter.number
            (bad.label, index),_ = iterate(device.wattmeter.label, bad.index)
            if bad.detect
                device.wattmeter.active.status[index] = 0
            end
        else
            (bad.label, index),_ = iterate(device.pmu.label, bad.index - device.wattmeter.number)
            if bad.detect
                device.pmu.angle.status[index] = 0
            end
        end
    end

    return bad
end

function residualTest!(system::PowerSystem, device::Measurement, analysis::PMUStateEstimation{LinearWLS{T}}; threshold::Float64 = 3.0)  where T <: Union{Normal, Orthogonal}
    errorVoltage(analysis.voltage.angle)

    bad = BadData(false, 0.0, "", 0)
    bus = system.bus
    se = analysis.method

    gain = transpose(se.coefficient) * se.precision * se.coefficient
    if !isa(se.factorization, UMFPACK.UmfpackLU{Float64, Int64})
        F = lu(gain)
    else
        F = se.factorization
    end

    ########## Sparse Matrix Inverese ##########
    gainInverse = sparseInverse(F, gain, 2 * bus.number)

    ########## Diagonal entries of residual matrix ##########
    JGi = se.coefficient * gainInverse
    idx = findall(!iszero, se.coefficient)
    c = fill(0.0, size(se.coefficient, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * se.coefficient[i]
    end

    ########## Largest normalized residual ##########
    voltageRe = analysis.voltage.magnitude .* cos.(analysis.voltage.angle)
    voltageIm = analysis.voltage.magnitude .* sin.(analysis.voltage.angle)
    h = se.coefficient * [voltageRe; voltageIm]
    bad.maxNormalizedResidual = 0.0
    bad.index = 0
    @inbounds for i = 1:se.number
        residual = se.mean[i] - h[i]
        if residual != 0.0
            normResidual = abs(residual) / sqrt(abs((1 / se.precision[i, i]) - c[i]))
            if normResidual > bad.maxNormalizedResidual
                bad.maxNormalizedResidual = normResidual
                bad.index = i
            end
        end
    end

    if bad.maxNormalizedResidual > threshold
        bad.detect = true

        if bad.index % 2 == 0
            alsoBad = bad.index - 1
        else
            alsoBad = bad.index + 1
        end

        colIndecies = findall(!iszero, se.coefficient[bad.index, :])
        @inbounds for col in colIndecies
            se.coefficient[bad.index, col] = 0.0
        end
        se.mean[bad.index] = 0.0

        colIndecies = findall(!iszero, se.coefficient[alsoBad, :])
        for col in colIndecies
            se.coefficient[alsoBad, col] = 0.0
        end
        se.mean[alsoBad] = 0.0
    end

    if bad.index % 2 == 0
        pmuIndex = trunc(Int, bad.index / 2)
    else
        pmuIndex = trunc(Int, (bad.index + 1) / 2)
    end

    if bad.index != 0
        (bad.label, ),_ = iterate(device.pmu.label, pmuIndex)
    end
    if bad.detect
        device.pmu.magnitude.status[pmuIndex] = 0
        device.pmu.angle.status[pmuIndex] = 0
    end

    return bad
end

function residualTest!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{NonlinearWLS{T}}; threshold::Float64 = 3.0)  where T <: Union{Normal, Orthogonal}
    errorVoltage(analysis.voltage.angle)

    bad = BadData(false, 0.0, "", 0)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    se = analysis.method
    voltage = analysis.voltage

    normalEquation!(system, analysis)

    slackRange = se.jacobian.colptr[bus.layout.slack]:(se.jacobian.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = se.jacobian.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        se.jacobian[se.jacobian.rowval[i], bus.layout.slack] = 0.0
    end
    gain = (transpose(se.jacobian) * se.precision * se.jacobian)
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    F = lu(gain)

    ########## Sparse Matrix Inverese ##########
    gainInverse = sparseInverse(F, gain, 2 * bus.number)

    ########## Diagonal entries of residual matrix ##########
    JGi = se.jacobian * gainInverse
    idx = findall(!iszero, se.jacobian)
    c = fill(0.0, size(se.jacobian, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * se.jacobian[i]
    end

    bad.maxNormalizedResidual = 0.0
    bad.index = 0
    @inbounds for i = 1:length(se.mean)
        if se.residual[i] != 0.0
            normResidual = abs(se.residual[i]) / sqrt(abs((1 / se.precision[i, i]) - c[i]))
            if normResidual > bad.maxNormalizedResidual
                bad.maxNormalizedResidual = normResidual
                bad.index = i
            end
        end
    end

    if bad.maxNormalizedResidual > threshold
        bad.detect = true
    end

    if bad.index != 0
        if se.range[1] <= bad.index < se.range[2]
            (bad.label, index),_ = iterate(device.voltmeter.label, bad.index)
            if bad.detect
                device.voltmeter.magnitude.status[index] = 0
            end
        elseif se.range[2] <= bad.index < se.range[3]
            (bad.label, index),_ = iterate(device.ammeter.label, bad.index - device.voltmeter.number)
            if bad.detect
                device.ammeter.magnitude.status[index] = 0
            end
        elseif se.range[3] <= bad.index < se.range[4]
            (bad.label, index),_ = iterate(device.wattmeter.label, bad.index - device.voltmeter.number - device.ammeter.number)
            if bad.detect
                device.wattmeter.active.status[index] = 0
            end
        elseif se.range[4] <= bad.index < se.range[5]
            (bad.label, index),_ = iterate(device.varmeter.label, bad.index - device.voltmeter.number - device.ammeter.number - device.wattmeter.number)
            if bad.detect
                device.varmeter.reactive.status[index] = 0
            end
        elseif se.range[5] <= bad.index < se.range[6]
            badIndex = bad.index - device.voltmeter.number - device.ammeter.number - device.wattmeter.number - device.varmeter.number
            if badIndex % 2 == 0
                pmuIndex = trunc(Int, badIndex / 2)
                alsoBad = bad.index - 1
            else
                pmuIndex = trunc(Int, (badIndex + 1) / 2)
                alsoBad = bad.index + 1
            end

            (bad.label, index),_ = iterate(device.pmu.label, pmuIndex)
            if bad.detect
                if device.pmu.layout.polar[index]
                    if se.type[bad.index] in [2; 3; 10]
                        device.pmu.magnitude.status[index] = 0
                    else
                        device.pmu.angle.status[index] = 0
                    end
                else
                    device.pmu.magnitude.status[index] = 0
                    device.pmu.angle.status[index] = 0

                    se.mean[alsoBad] = 0.0
                    se.residual[alsoBad] = 0.0
                    se.type[alsoBad] = 0
                end
            end
        end
    end

    if bad.detect
        se.mean[bad.index] = 0.0
        se.residual[bad.index] = 0.0
        se.type[bad.index] = 0
    end

    @inbounds for (k, i) in enumerate(slackRange)
        se.jacobian[se.jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    end

    return bad
end

######### Sparse Matrix Inverese #########
function sparseInverse(F::UMFPACK.UmfpackLU{Float64, Int64}, gain::SparseMatrixCSC{Float64,Int64}, variableNumber::Int64)
    L, U, p, q, Rss = F.:(:)
    U = copy(transpose(U))
    d = fill(0.0, variableNumber)
    Rs = fill(0.0, variableNumber)

    @inbounds for i = 1:variableNumber
        Rs[i] = Rss[p[i]]
        d[i] = U[i, i]
        U[i, i] = 0.0
        L[i, i] = 0.0
        for j = U.colptr[i]:(U.colptr[i + 1] - 1)
            if i != U.rowval[j]
                U.nzval[j] = U.nzval[j] / d[i]
            end
        end
    end

    dropzeros!(U)
    dropzeros!(L)
    S = gain[p, q]
    S = S + transpose(S)

    parent = etree(S)
    R = symbfact(S, parent)

    return sparseinv(L, U, d, p, q, Rs, R)
end

### The sparse inverse subset of a real sparse square matrix: Compute the elimination tree of a sparse matrix
# Copyright (c) 2013-2014 Viral Shah, Douglas Bates and other contributors
# https://github.com/JuliaPackageMirrors/SuiteSparse.jl/blob/master/src/csparse.jl
# Based on Direct Methods for Sparse Linear Systems, T. A. Davis, SIAM, Philadelphia, Sept. 2006.
function etree(A::SparseMatrixCSC{Float64,Int64})
    n = size(A, 2)
    parent = fill(0, n)
    ancestor = fill(0, n)
    @inbounds for k in 1:n, p in A.colptr[k]:(A.colptr[k + 1] - 1)
        i = A.rowval[p]
        while i != 0 && i < k
            inext = ancestor[i]
            ancestor[i] = k
            if inext == 0
                parent[i] = k
            end
            i = inext
        end
    end

    head = fill(0, n)
    next = fill(0, n)
    @inbounds for j in n:-1:1
        if parent[j] == 0
            continue
        end
        next[j] = head[parent[j]]
        head[parent[j]] = j
    end
    stack = Int64[]
    @inbounds for j in 1:n
        if parent[j] != 0
            continue
        end
        push!(stack, j)
        while !isempty(stack)
            p = stack[end]
            i = head[p]
            if i == 0
                pop!(stack)
            else
                head[p] = next[i]
                push!(stack, i)
            end
        end
    end

    return parent
end

### The sparse inverse subset of a real sparse square matrix: Find nonzero pattern of Cholesky
# Copyright (c) 2013-2014 Viral Shah, Douglas Bates and other contributors
# https://github.com/JuliaPackageMirrors/SuiteSparse.jl/blob/master/src/csparse.jl
# Based on Direct Methods for Sparse Linear Systems, T. A. Davis, SIAM, Philadelphia, Sept. 2006.
function symbfact(A::SparseMatrixCSC{Float64,Int64}, parent::Array{Int64,1})
    m, n = size(A)
    Ap = A.colptr
    Ai = A.rowval
    col = Int64[]; sizehint!(col, n)
    row = Int64[]; sizehint!(row, n)

    visited = falses(n)
    @inbounds for k = 1:m
        visited = falses(n)
        visited[k] = true
        for p in Ap[k]:(Ap[k + 1] - 1)
            i = Ai[p]
            if i > k
                continue
            end
            while !visited[i]
                push!(col, i)
                push!(row, k)
                visited[i] = true
                i = parent[i]
            end
        end
    end
    R = sparse([col; collect(1:n)], [row; collect(1:n)], ones(length(row) + n), n, n)

    return R
end

### The sparse inverse subset of a real sparse square matrix
# Copyright 2011, Timothy A. Davis
# http://www.suitesparse.com
function sparseinv(L::SparseMatrixCSC{Float64,Int64}, U::SparseMatrixCSC{Float64,Int64}, d::Array{Float64,1}, p::Array{Int64,1}, q::Array{Int64,1}, Rs::Array{Float64,1}, R::SparseMatrixCSC{Float64,Int64})
    Zpattern = R + R'
    n = size(Zpattern, 1)

    Zdiagp = fill(1, n)
    Lmunch = fill(0, n)

    znz = nnz(Zpattern)
    Zx = fill(0.0, znz)
    z = zeros(n)
    k = 0

    Zcolptr = Zpattern.colptr
    Zrowval = Zpattern.rowval
    flag = true
    @inbounds for j = 1:n
        pdiag = -1
        for p = Zcolptr[j]:(Zcolptr[j + 1] - 1)
            if pdiag == -1 && Zrowval[p] == j
                pdiag = p
                Zx[p] = 1 / (d[j] / Rs[j])
            end
        end
        if pdiag == -1
            flag = false
          break
        end
        Zdiagp[j] = pdiag
    end

    @inbounds if flag
        for k = 1:n
            Lmunch[k] = L.colptr[k + 1] - 1
        end

        for j = n:-1:1
            for p = Zdiagp[j]:Zcolptr[j + 1] - 1
                z[Zrowval[p]] = Zx[p]
            end

            for p = Zdiagp[j]-1:-1:Zcolptr[j]
                k = Zrowval[p]
                zkj = 0.0
                for up = U.colptr[k]:U.colptr[k + 1] - 1
                    i = U.rowval[up]
                    if i > k && z[i] != 0.0
                        zkj -= U.nzval[up] * z[i]
                    end
                end
                z[k] = zkj
            end

            for p = Zdiagp[j]-1:-1:Zcolptr[j]
                k = Zrowval[p]
                if Lmunch[k] < L.colptr[k] || L.rowval[Lmunch[k]] != j
                    continue
                end
                ljk = L.nzval[Lmunch[k]] * Rs[k] / Rs[L.rowval[Lmunch[k]]]
                Lmunch[k] -= 1
                for zp = Zdiagp[k]:Zcolptr[k + 1] - 1
                    Zx[zp] -= z[Zrowval[zp]] * ljk
                end
            end

            for p = Zcolptr[j]:Zcolptr[j + 1] - 1
                i = Zrowval[p]
                Zx[p] = z[i]
                z[i] = 0.0
            end
        end
    end

    idx = findall(!iszero, Zpattern)
    @inbounds for (k, i) in enumerate(idx)
        Zpattern[i] = Zx[k]
    end

    return Zpattern[invperm(q), invperm(p)]
end