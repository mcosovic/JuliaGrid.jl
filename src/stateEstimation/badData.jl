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
The function returns an instance of the `ResidualTest` type, which includes:
- `detect`: Returns `true` after the function's execution if bad data is detected.
- `maxNormalizedResidual`: Denotes the value of the largest normalized residual.
- `label`: Signifies the label of the bad data.
- `index`: Represents the index of the bad data.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)

outlier = residualTest!(system, device, analysis; threshold = 4.0)
solve!(system, analysis)
```
"""
function residualTest!(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation{WLS{T}};
    threshold::Float64 = 3.0
) where T <: Union{Normal, Orthogonal}

    errorVoltage(analysis.voltage.angle)

    bus = system.bus
    se = analysis.method
    watt = device.wattmeter
    pmu = device.pmu

    bad = ResidualTest(false, 0.0, "", 0)

    slackRange, elementsRemove = delSlackCoeff(analysis, bus.layout.slack)

    gain = transpose(se.coefficient) * se.precision * se.coefficient
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    if !isa(se.factorization, UMFPACK.UmfpackLU{Float64, Int64})
        F = lu(gain)
    else
        F = se.factorization
    end

    gainInverse = sparseInverse(F, gain, bus.number)

    JGi = se.coefficient * gainInverse
    idx = findall(!iszero, se.coefficient)
    c = fill(0.0, size(se.coefficient, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * se.coefficient[i]
    end

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

    addSlackCoeff(analysis, slackRange, elementsRemove, bus.layout.slack)

    if bad.maxNormalizedResidual > threshold
        se.run = true
        bad.detect = true

        removeRow(se.coefficient, bad.index)
        se.mean[bad.index] = 0.0
    end

    if bad.index != 0
        if bad.index <= watt.number
            (bad.label, index),_ = iterate(watt.label, bad.index)
            if bad.detect
                watt.active.status[index] = 0
            end
        else
            index = 0
            @inbounds for (idx, val) in se.index
                if val == bad.index
                    index = idx
                    break
                end
            end
            (bad.label, _),_ = iterate(pmu.label, index)
            if bad.detect
                pmu.angle.status[index] = 0
            end
        end
    end

    return bad
end

function residualTest!(
    system::PowerSystem,
    device::Measurement,
    analysis::PMUStateEstimation{WLS{T}};
    threshold::Float64 = 3.0
)  where T <: Union{Normal, Orthogonal}

    errorVoltage(analysis.voltage.angle)

    bus = system.bus
    se = analysis.method

    bad = ResidualTest(false, 0.0, "", 0)

    gain = transpose(se.coefficient) * se.precision * se.coefficient
    if !isa(se.factorization, UMFPACK.UmfpackLU{Float64, Int64})
        F = lu(gain)
    else
        F = se.factorization
    end

    gainInverse = sparseInverse(F, gain, 2 * bus.number)

    JGi = se.coefficient * gainInverse
    idx = findall(!iszero, se.coefficient)
    c = fill(0.0, size(se.coefficient, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * se.coefficient[i]
    end

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

        removeRow(se.coefficient, bad.index)
        se.mean[bad.index] = 0.0

        removeRow(se.coefficient, alsoBad)
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

function residualTest!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{GaussNewton{T}};
    threshold::Float64 = 3.0
)  where T <: Union{Normal, Orthogonal}

    errorVoltage(analysis.voltage.angle)

    bus = system.bus
    se = analysis.method
    jcb = se.jacobian

    volt = device.voltmeter
    amp = device.ammeter
    watt = device.wattmeter
    var = device.varmeter

    bad = ResidualTest(false, 0.0, "", 0)

    slackRange = jcb.colptr[bus.layout.slack]:(jcb.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = jcb.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = 0.0
    end
    gain = (transpose(jcb) * se.precision * jcb)
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    if !isa(se.factorization, UMFPACK.UmfpackLU{Float64, Int64})
        F = lu(gain)
    else
        F = se.factorization
    end

    gainInverse = sparseInverse(F, gain, 2 * bus.number)

    JGi = jcb * gainInverse
    idx = findall(!iszero, jcb)
    c = fill(0.0, size(jcb, 1))
    @inbounds for i in idx
        c[i[1]] += JGi[i] * jcb[i]
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

    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = elementsRemove[k]
    end

    if bad.maxNormalizedResidual > threshold
        bad.detect = true
    end

    if bad.index != 0
        if se.range[1] <= bad.index < se.range[2]
            (bad.label, idx),_ = iterate(volt.label, bad.index)
            if bad.detect
                volt.magnitude.status[idx] = 0
            end
        elseif se.range[2] <= bad.index < se.range[3]
            (bad.label, idx),_ = iterate(amp.label, bad.index - volt.number)
            if bad.detect
                amp.magnitude.status[idx] = 0
            end
        elseif se.range[3] <= bad.index < se.range[4]
            (bad.label, idx),_ = iterate(watt.label, bad.index - volt.number - amp.number)
            if bad.detect
                watt.active.status[idx] = 0
            end
        elseif se.range[4] <= bad.index < se.range[5]
            (bad.label, idx),_ = iterate(
                var.label, bad.index - volt.number - amp.number - watt.number
            )
            if bad.detect
                var.reactive.status[idx] = 0
            end
        elseif se.range[5] <= bad.index < se.range[6]
            badIndex = bad.index - volt.number - amp.number - watt.number - var.number
            if badIndex % 2 == 0
                pmuIndex = trunc(Int, badIndex / 2)
                alsoBad = bad.index - 1
            else
                pmuIndex = trunc(Int, (badIndex + 1) / 2)
                alsoBad = bad.index + 1
            end

            (bad.label, idx),_ = iterate(device.pmu.label, pmuIndex)
            if bad.detect
                if device.pmu.layout.polar[idx]
                    if se.type[bad.index] in [2; 3; 4; 5; 12]
                        device.pmu.magnitude.status[idx] = 0
                    else
                        device.pmu.angle.status[idx] = 0
                    end
                else
                    device.pmu.magnitude.status[idx] = 0
                    device.pmu.angle.status[idx] = 0

                    removeRow(se.jacobian, alsoBad)
                    se.mean[alsoBad] = 0.0
                    se.residual[alsoBad] = 0.0
                    se.type[alsoBad] = 0
                end
            end
        end
    end

    if bad.detect
        removeRow(se.jacobian, bad.index)
        se.mean[bad.index] = 0.0
        se.residual[bad.index] = 0.0
        se.type[bad.index] = 0
        se.iteration = 0
    end

    return bad
end

##### Sparse Matrix Inverese #####
function sparseInverse(
    F::UMFPACK.UmfpackLU{Float64, Int64},
    gain::SparseMatrixCSC{Float64,Int64},
    variableNum::Int64
)
    L, U, p, q, Rss = F.:(:)
    U = copy(transpose(U))
    d = fill(0.0, variableNum)
    Rs = fill(0.0, variableNum)

    @inbounds for i = 1:variableNum
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

    sparseinv(L, U, d, p, q, Rs, R)
end

##### Compute the Elimination Tree of a Sparse Matrix #####
# Copyright (c) 2013-2014 Viral Shah, Douglas Bates and other contributors
# https://github.com/JuliaPackageMirrors/SuiteSparse.jl/blob/master/src/csparse.jl
# Based on Direct Methods for Sparse Linear Systems, T. A. Davis, SIAM, Philadelphia, 2006.
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

##### Find Nonzero Pattern of Cholesky #####
# Copyright (c) 2013-2014 Viral Shah, Douglas Bates and other contributors
# https://github.com/JuliaPackageMirrors/SuiteSparse.jl/blob/master/src/csparse.jl
# Based on Direct Methods for Sparse Linear Systems, T. A. Davis, SIAM, Philadelphia, 2006.
function symbfact(A::SparseMatrixCSC{Float64, Int64}, parent::Vector{Int64})
    m, n = size(A)
    Ap = A.colptr
    Ai = A.rowval

    col = Int64[]
    row = Int64[]
    sizehint!(col, n)
    sizehint!(row, n)

    visited = falses(n)
    @inbounds for k in 1:m
        fill!(visited, false)
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

    diagonal = collect(1:n)
    col = vcat(col, diagonal)
    row = vcat(row, diagonal)
    nnz = length(row)

    return sparse(col, row, ones(nnz), n, n)
end

##### The Sparse Inverse Subset of a Real Sparse Square Matrix #####
# Copyright 2011, Timothy A. Davis
# http://www.suitesparse.com
function sparseinv(
    L::SparseMatrixCSC{Float64, Int64},
    U::SparseMatrixCSC{Float64, Int64},
    d::Vector{Float64},
    p::Vector{Int64},
    q::Vector{Int64},
    Rs::Vector{Float64},
    R::SparseMatrixCSC{Float64, Int64}
)
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

function removeRow(A::SparseMatrixCSC{Float64, Int64}, idx::Int64)
    colIdx = findall(!iszero, A[idx, :])
    @inbounds for col in colIdx
        A[idx, col] = 0.0
    end
end

"""
    chiTest(system::PowerSystem, device::Measurement, analysis::StateEstimation;
        confidence)

The function performs a Chi-squared bad data detection test. This test can be applied after
obtaining WLS estimator.

# Arguments
This function requires the types `PowerSystem`, `Measurement`, and `StateEstimation`. The
abstract type `StateEstimation` can have the following subtypes:
- `ACStateEstimation`: Conducts bad data analysis within AC state estimation.
- `PMUStateEstimation`: Conducts bad data analysis within PMU state estimation.
- `DCStateEstimation`: Conducts bad data analysis within DC state estimation.

# Keyword
The keyword `confidence` specifies the detection confidence level, with a default value
of `0.95`.

# Returns
Returns `true` if bad data is detected; otherwise, returns `false`.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
solve!(system, analysis)

bad = chiTest(system, device, analysis; confidence = 0.96)
```
"""
function chiTest(
    system::PowerSystem,
    ::Measurement,
    analysis::ACStateEstimation{GaussNewton{T}};
    confidence::Float64 = 0.95
)  where T <: Union{Normal, Orthogonal}

    se = analysis.method

    df = lastindex(se.type) - count(==(0), se.type) - 2 * system.bus.number + 1
    chi = quantile(Chisq(df), confidence)

    return ChiTest(se.objective >= chi, chi, se.objective)
end

function chiTest(
    system::PowerSystem,
    ::Measurement,
    analysis::DCStateEstimation{WLS{T}};
    confidence::Float64 = 0.95
)  where T <: Union{Normal, Orthogonal}

    se = analysis.method

    residual = se.mean - se.coefficient * analysis.voltage.angle
    objective = transpose(residual) * se.precision * residual

    df = se.inservice - system.bus.number + 1
    chi = quantile(Chisq(df), confidence)

    return ChiTest(objective >= chi, chi, objective)
end

function chiTest(
    system::PowerSystem,
    ::Measurement,
    analysis::PMUStateEstimation{WLS{T}};
    confidence::Float64 = 0.95
)  where T <: Union{Normal, Orthogonal}

    se = analysis.method
    volt = analysis.voltage

    realV = volt.magnitude .* cos.(volt.angle)
    imagV = volt.magnitude .* sin.(volt.angle)

    residual = se.mean - se.coefficient * [realV; imagV]
    objective = transpose(residual) * se.precision * residual

    df = se.inservice - 2 * system.bus.number
    chi = quantile(Chisq(df), confidence)

    return ChiTest(objective >= chi, chi, objective)
end