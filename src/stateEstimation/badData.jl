"""
    residualTest!(analysis::StateEstimation; threshold)

The function conducts bad data detection and identification using the largest normalized residual
test, subsequently removing measurement outliers from the measurement set. It can be executed after
obtaining WLS estimator.

# Arguments
The `StateEstimation` type alias can represent the following analysis types:
- `AcStateEstimation`: Conducts bad data analysis within AC state estimation.
- `PmuStateEstimation`: Conducts bad data analysis within PMU state estimation.
- `DcStateEstimation`: Conducts bad data analysis within DC state estimation.

# Keyword
The keyword `threshold` establishes the identification threshold. If the largest normalized residual
surpasses this threshold, the measurement is flagged as bad data. The default threshold value is set
to `threshold = 3.0`.

# Updates
If bad data is detected, the function flags the corresponding measurement within the `Measurement`
type as out-of-service.

Moreover, for `DcStateEstimation` and `PmuStateEstimation` types, the function removes the
corresponding measurement from the coefficient matrix and mean vector. This facilitates direct
progress to the function that solves the state estimation problem.

# Returns
The function returns an instance of the [`ResidualTest`](@ref ResidualTest) type.

# Note
For the residual covariance diagonal, the function reuses the selected factorization when possible.
With `LU`, it reuses the existing sparse LU factorization to compute the selected sparse inverse.
With `LL`, it reuses the existing Cholesky factorization and applies a selected-inverse projection.
For other WLS factorization choices, it first attempts a local Cholesky factorization of the gain
matrix and falls back to sparse LU if the Cholesky factorization is not applicable.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis)

outlier = residualTest!(analysis; threshold = 4.0)
stateEstimation!(analysis)
```
"""
function residualTest!(
    analysis::DcStateEstimation{WLS{T}};
    threshold::Float64 = 3.0
) where T <: WlsMethod

    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    monitoring = analysis.monitoring
    bus = system.bus
    se = analysis.method
    watt = monitoring.wattmeter
    pmu = monitoring.pmu

    bad = ResidualTest(false, 0.0, "", 0)

    removeIdx, removeVal = removeColumn(se.coefficient, bus.layout.slack)

    gain = transpose(se.coefficient) * se.precision * se.coefficient
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    c = badDataProjection(se.coefficient, gain, se.factorization, T, bus.number)

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

    restoreColumn!(se.coefficient, removeIdx, removeVal, bus.layout.slack)

    if bad.maxNormalizedResidual > threshold
        se.signature[:run] = true
        bad.detect = true

        removeRow(se.coefficient, bad.index)
        se.mean[bad.index] = 0.0
    end

    if bad.index != 0
        if bad.index <= watt.number
            bad.label, index = getLabelIdx(watt.label, bad.index)
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
            bad.label = getLabel(pmu.label, index)
            if bad.detect
                pmu.angle.status[index] = 0
            end
        end
    end

    return bad
end

function residualTest!(
    analysis::PmuStateEstimation{WLS{T}};
    threshold::Float64 = 3.0
) where T <: WlsMethod

    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    monitoring = analysis.monitoring
    bus = system.bus
    se = analysis.method

    bad = ResidualTest(false, 0.0, "", 0)

    gain = transpose(se.coefficient) * se.precision * se.coefficient

    c = badDataProjection(se.coefficient, gain, se.factorization, T, 2 * bus.number)

    state = rectangularState(analysis.voltage, bus.number)
    h = se.coefficient * state
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

    pmuIndex = (bad.index + 1) ÷ 2

    if bad.index != 0
        bad.label = getLabel(monitoring.pmu.label, pmuIndex)
    end
    if bad.detect
        monitoring.pmu.magnitude.status[pmuIndex] = 0
        monitoring.pmu.angle.status[pmuIndex] = 0
    end

    return bad
end

function residualTest!(
    analysis::AcStateEstimation{GaussNewton{T}};
    threshold::Float64 = 3.0
) where T <: WlsMethod

    errorVoltage(analysis.voltage.angle)

    system = analysis.system
    monitoring = analysis.monitoring
    bus = system.bus
    se = analysis.method

    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter

    bad = ResidualTest(false, 0.0, "", 0)

    removeIdx, removeVal = removeColumn(se.jacobian, bus.layout.slack)

    gain = (transpose(se.jacobian) * se.precision * se.jacobian)
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    c = badDataProjection(se.jacobian, gain, se.factorization, T, 2 * bus.number)

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

    restoreColumn!(se.jacobian, removeIdx, removeVal, bus.layout.slack)

    if bad.maxNormalizedResidual > threshold
        bad.detect = true
    end

    if bad.index != 0
        if se.range[1] <= bad.index < se.range[2]
            bad.label, idx = getLabelIdx(volt.label, bad.index)
            if bad.detect
                volt.magnitude.status[idx] = 0
            end
        elseif se.range[2] <= bad.index < se.range[3]
            bad.label, idx = getLabelIdx(amp.label, bad.index - volt.number)
            if bad.detect
                amp.magnitude.status[idx] = 0
            end
        elseif se.range[3] <= bad.index < se.range[4]
            bad.label, idx = getLabelIdx(watt.label, bad.index - volt.number - amp.number)
            if bad.detect
                watt.active.status[idx] = 0
            end
        elseif se.range[4] <= bad.index < se.range[5]
            bad.label, idx = getLabelIdx(
                var.label, bad.index - volt.number - amp.number - watt.number
            )
            if bad.detect
                var.reactive.status[idx] = 0
            end
        elseif se.range[5] <= bad.index < se.range[6]
            badIndex = bad.index - volt.number - amp.number - watt.number - var.number
            pmuIndex = (badIndex + 1) ÷ 2
            alsoBad = iseven(badIndex) ? bad.index - 1 : bad.index + 1

            bad.label, idx = getLabelIdx(monitoring.pmu.label, pmuIndex)
            if bad.detect
                if monitoring.pmu.layout.polar[idx]
                    type = se.type[bad.index]
                    if type == 2 || type == 3 || type == 4 || type == 5 || type == 12
                        monitoring.pmu.magnitude.status[idx] = 0
                    else
                        monitoring.pmu.angle.status[idx] = 0
                    end
                else
                    monitoring.pmu.magnitude.status[idx] = 0
                    monitoring.pmu.angle.status[idx] = 0

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

##### Residual Covariance Projection #####
function badDataProjection(
    A::SparseMatrixCSC{Float64, Int64},
    gain::SparseMatrixCSC{Float64, Int64},
    factorization::FactorSparse,
    ::Type{T},
    variableNum::Int64
) where T
    if T === LU && factorization isa UMFPACK.UmfpackLU{Float64, Int64}
        gainInverse = selectedInverse(factorization, gain, variableNum)
        return rowProjection(A, gainInverse)
    end

    if T === LL && factorization isa CHOLMOD.Factor{Float64}
        gainInverse = selectedInverse(factorization, gain, variableNum)
        return rowProjection(A, gainInverse)
    end

    try
        gainInverse = selectedInverse(cholesky(Symmetric(gain)), gain, variableNum)
        return rowProjection(A, gainInverse)
    catch
        gainInverse = selectedInverse(lu(gain), gain, variableNum)
        return rowProjection(A, gainInverse)
    end
end

##### Selected Inverse Types #####
struct SparseSelectedInverse
    matrix::SparseMatrixCSC{Float64, Int64}
end

struct PermutedSparseSelectedInverse
    matrix::SparseMatrixCSC{Float64, Int64}
    rowPermutation::Vector{Int64}
    colPermutation::Vector{Int64}
end

struct CholeskySelectedInverse
    matrix::SparseMatrixCSC{Float64, Int64}
    inversePermutation::Vector{Int64}
end

##### Selected Inverse Factorization Paths #####
function selectedInverse(
    F::UMFPACK.UmfpackLU{Float64, Int64},
    gain::SparseMatrixCSC{Float64, Int64},
    variableNum::Int64
)
    matrix, rowPermutation, colPermutation = sparseInversePermuted(F, gain, variableNum)
    PermutedSparseSelectedInverse(matrix, rowPermutation, colPermutation)
end

function selectedInverse(
    F::CHOLMOD.Factor{Float64},
    gain::SparseMatrixCSC{Float64, Int64},
    variableNum::Int64
)
    selected, p = takahashiCholeskyLower(F)
    CholeskySelectedInverse(selected, invperm(p))
end

##### Row Projection Helpers #####
function rowProjection(
    A::SparseMatrixCSC{Float64, Int64},
    AGi::SparseMatrixCSC{Float64, Int64}
)
    c = fill(0.0, size(A, 1))
    @inbounds for col = 1:size(A, 2)
        for ptr = A.colptr[col]:(A.colptr[col + 1] - 1)
            row = A.rowval[ptr]
            c[row] += AGi[row, col] * A.nzval[ptr]
        end
    end

    return c
end

function sparseRows(A::SparseMatrixCSC{Float64, Int64})
    m, n = size(A)
    counts = zeros(Int64, m)

    @inbounds for col = 1:n
        for ptr = A.colptr[col]:(A.colptr[col + 1] - 1)
            counts[A.rowval[ptr]] += 1
        end
    end

    rowptr = Vector{Int64}(undef, m + 1)
    rowptr[1] = 1
    @inbounds for row = 1:m
        rowptr[row + 1] = rowptr[row] + counts[row]
    end

    @inbounds for row = 1:m
        counts[row] = rowptr[row]
    end
    rowcols = Vector{Int64}(undef, nnz(A))
    rowvals = Vector{Float64}(undef, nnz(A))

    @inbounds for col = 1:n
        for ptr = A.colptr[col]:(A.colptr[col + 1] - 1)
            row = A.rowval[ptr]
            pos = counts[row]
            rowcols[pos] = col
            rowvals[pos] = A.nzval[ptr]
            counts[row] = pos + 1
        end
    end

    return rowptr, rowcols, rowvals
end

function selectedEntry(A::SparseMatrixCSC{Float64, Int64}, i::Int64, j::Int64)
    if i < j
        i, j = j, i
    end

    lo = A.colptr[j]
    hi = A.colptr[j + 1] - 1

    @inbounds while lo <= hi
        mid = (lo + hi) >>> 1
        row = A.rowval[mid]
        if row < i
            lo = mid + 1
        elseif row > i
            hi = mid - 1
        else
            return A.nzval[mid]
        end
    end

    return 0.0
end

function sparseEntry(A::SparseMatrixCSC{Float64, Int64}, i::Int64, j::Int64)
    lo = A.colptr[j]
    hi = A.colptr[j + 1] - 1

    @inbounds while lo <= hi
        mid = (lo + hi) >>> 1
        row = A.rowval[mid]
        if row < i
            lo = mid + 1
        elseif row > i
            hi = mid - 1
        else
            return A.nzval[mid]
        end
    end

    return 0.0
end

##### Cholesky Selected Inverse Helpers #####
function rowEntries(A::SparseMatrixCSC{Float64, Int64})
    n = size(A, 1)
    counts = zeros(Int64, n)

    @inbounds for col = 1:size(A, 2)
        for ptr = A.colptr[col]:(A.colptr[col + 1] - 1)
            counts[A.rowval[ptr]] += 1
        end
    end

    rowptr = Vector{Int64}(undef, n + 1)
    rowptr[1] = 1
    @inbounds for row = 1:n
        rowptr[row + 1] = rowptr[row] + counts[row]
    end

    @inbounds for row = 1:n
        counts[row] = rowptr[row]
    end
    ptrs = Vector{Int64}(undef, nnz(A))
    cols = Vector{Int64}(undef, nnz(A))

    @inbounds for col = 1:size(A, 2)
        for ptr = A.colptr[col]:(A.colptr[col + 1] - 1)
            row = A.rowval[ptr]
            pos = counts[row]
            ptrs[pos] = ptr
            cols[pos] = col
            counts[row] = pos + 1
        end
    end

    return rowptr, ptrs, cols
end

function rowProjectionSelected(
    A::SparseMatrixCSC{Float64, Int64},
    gainInverse::SparseMatrixCSC{Float64, Int64}
)
    rowptr, rowcols, rowvals = sparseRows(A)
    c = zeros(size(A, 1))

    @inbounds for row = 1:length(c)
        acc = 0.0
        firstPtr = rowptr[row]
        lastPtr = rowptr[row + 1] - 1
        for ptr1 = firstPtr:lastPtr
            col1 = rowcols[ptr1]
            val1 = rowvals[ptr1]
            for ptr2 = firstPtr:lastPtr
                acc += val1 * rowvals[ptr2] * selectedEntry(gainInverse, col1, rowcols[ptr2])
            end
        end
        c[row] = acc
    end

    return c
end

function rowProjection(
    A::SparseMatrixCSC{Float64, Int64},
    gainInverse::SparseSelectedInverse
)
    rowProjectionSelected(A, gainInverse.matrix)
end

function rowProjection(
    A::SparseMatrixCSC{Float64, Int64},
    gainInverse::PermutedSparseSelectedInverse
)
    rowptr, rowcols, rowvals = sparseRows(A)
    c = zeros(size(A, 1))
    selected = gainInverse.matrix
    rowPermutation = gainInverse.rowPermutation
    colPermutation = gainInverse.colPermutation

    @inbounds for row = 1:length(c)
        acc = 0.0
        firstPtr = rowptr[row]
        lastPtr = rowptr[row + 1] - 1
        for ptr1 = firstPtr:lastPtr
            col1 = rowPermutation[rowcols[ptr1]]
            val1 = rowvals[ptr1]
            for ptr2 = firstPtr:lastPtr
                acc += val1 * rowvals[ptr2] *
                    sparseEntry(selected, col1, colPermutation[rowcols[ptr2]])
            end
        end
        c[row] = acc
    end

    return c
end

function takahashiCholeskyLower(F::CHOLMOD.Factor{Float64})
    L = sparse(F.L)
    n = size(L, 1)
    selected = SparseMatrixCSC(n, n, L.colptr, L.rowval, zeros(Float64, nnz(L)))
    diag = Vector{Float64}(undef, n)
    diagPtr = Vector{Int64}(undef, n)
    rowptr, rowptrs, rowcols = rowEntries(selected)
    mark = zeros(Int64, n)
    acc = zeros(Float64, n)

    takahashiCholeskyLower!(
        selected, L, diag, diagPtr, rowptr, rowptrs, rowcols, mark, acc
    )

    return selected, F.p
end

function takahashiCholeskyLower!(
    selected::SparseMatrixCSC{Float64, Int64},
    L::SparseMatrixCSC{Float64, Int64},
    diag::Vector{Float64},
    diagPtr::Vector{Int64},
    rowptr::Vector{Int64},
    rowptrs::Vector{Int64},
    rowcols::Vector{Int64},
    mark::Vector{Int64},
    acc::Vector{Float64}
)
    n = size(L, 1)
    Lcolptr = L.colptr
    Lrowval = L.rowval
    Lnzval = L.nzval
    Scolptr = selected.colptr
    Srowval = selected.rowval
    Snzval = selected.nzval
    fill!(Snzval, 0.0)

    @inbounds for col = 1:n
        for ptr = Lcolptr[col]:(Lcolptr[col + 1] - 1)
            if Lrowval[ptr] == col
                diag[col] = Lnzval[ptr]
                diagPtr[col] = ptr
                break
            end
        end
    end

    @inbounds for col = 1:n
        invDiag = inv(diag[col])
        for ptr = Lcolptr[col]:(Lcolptr[col + 1] - 1)
            if Lrowval[ptr] != col
                Lnzval[ptr] *= invDiag
            end
        end
    end

    @inbounds for col = n:-1:1
        for ptr = Lcolptr[col]:(Lcolptr[col + 1] - 1)
            row = Lrowval[ptr]
            if row != col
                mark[row] = col
                acc[row] = 0.0
            end
        end

        for pos = Lcolptr[col]:(Lcolptr[col + 1] - 1)
            k = Lrowval[pos]
            if k == col
                continue
            end

            coeff = Lnzval[pos]
            for ptr = Scolptr[k]:(Scolptr[k + 1] - 1)
                row = Srowval[ptr]
                if mark[row] == col
                    acc[row] += coeff * Snzval[ptr]
                end
            end

            for entry = rowptr[k]:(rowptr[k + 1] - 1)
                ptr = rowptrs[entry]
                row = rowcols[entry]
                if row < k && mark[row] == col
                    acc[row] += coeff * Snzval[ptr]
                end
            end
        end

        diagAcc = 0.0
        for ptr = Lcolptr[col]:(Lcolptr[col + 1] - 1)
            row = Lrowval[ptr]
            if row != col
                value = -acc[row]
                Snzval[ptr] = value
                diagAcc += Lnzval[ptr] * value
            end
        end
        Snzval[diagPtr[col]] = inv(abs2(diag[col])) - diagAcc
    end

    return selected
end

function rowProjection(
    A::SparseMatrixCSC{Float64, Int64},
    gainInverse::CholeskySelectedInverse
)
    selected = gainInverse.matrix
    invp = gainInverse.inversePermutation
    rowptr, rowcols, rowvals = sparseRows(A)
    c = zeros(size(A, 1))

    @inbounds for row = 1:length(c)
        acc = 0.0
        firstPtr = rowptr[row]
        lastPtr = rowptr[row + 1] - 1
        for ptr1 = firstPtr:lastPtr
            col1 = invp[rowcols[ptr1]]
            val1 = rowvals[ptr1]
            for ptr2 = firstPtr:lastPtr
                acc += val1 * rowvals[ptr2] * selectedEntry(selected, col1, invp[rowcols[ptr2]])
            end
        end
        c[row] = acc
    end

    return c
end

##### Rectangular State Conversion #####
function rectangularState(voltage::Polar, n::Int64)
    state = Vector{Float64}(undef, 2 * n)
    @inbounds for i = 1:n
        sinθ, cosθ = sincos(voltage.angle[i])
        magnitude = voltage.magnitude[i]
        state[i] = magnitude * cosθ
        state[i + n] = magnitude * sinθ
    end

    return state
end

##### Sparse Matrix Inverse #####
function sparseInverse(
    F::UMFPACK.UmfpackLU{Float64, Int64},
    gain::SparseMatrixCSC{Float64,Int64},
    variableNum::Int64
)
    Zpattern, rowPermutation, colPermutation = sparseInversePermuted(F, gain, variableNum)

    return Zpattern[rowPermutation, colPermutation]
end

function sparseInversePermuted(
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

    sparseinvPermuted(L, U, d, p, q, Rs, R)
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
    Zpattern, rowPermutation, colPermutation = sparseinvPermuted(L, U, d, p, q, Rs, R)

    return Zpattern[rowPermutation, colPermutation]
end

function sparseinvPermuted(
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

    Zx = Zpattern.nzval
    fill!(Zx, 0.0)
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

    return Zpattern, invperm(q), invperm(p)
end

##### Measurement Row Removal #####
function removeRow(A::SparseMatrixCSC{Float64, Int64}, idx::Int64)
    colIdx = findall(!iszero, A[idx, :])
    @inbounds for col in colIdx
        A[idx, col] = 0.0
    end
end

"""
    chiTest(analysis::StateEstimation; confidence)

The function performs a Chi-squared bad data detection test. This test can be applied after obtaining
WLS estimator.

# Arguments
The `StateEstimation` type alias can represent the following analysis types:
- `AcStateEstimation`: Conducts bad data analysis within AC state estimation.
- `PmuStateEstimation`: Conducts bad data analysis within PMU state estimation.
- `DcStateEstimation`: Conducts bad data analysis within DC state estimation.

# Keyword
The keyword `confidence` specifies the detection confidence level, with a default value of `0.95`.

# Returns
The function returns an instance of the [`ChiTest`](@ref ChiTest) type.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

bad = chiTest(analysis; confidence = 0.96)
```
"""
function chiTest(
    analysis::AcStateEstimation{<:GaussNewton};
    confidence::Float64 = 0.95
)

    system = analysis.system
    se = analysis.method

    df = lastindex(se.type) - count(==(0), se.type) - 2 * system.bus.number + 1
    chi = quantile(Chisq(df), confidence)

    return ChiTest(se.objective >= chi, chi, se.objective)
end

function chiTest(
    analysis::DcStateEstimation{<:WLS};
    confidence::Float64 = 0.95
)

    system = analysis.system
    se = analysis.method

    residual = se.mean - se.coefficient * analysis.voltage.angle
    objective = transpose(residual) * se.precision * residual

    df = se.inservice - system.bus.number + 1
    chi = quantile(Chisq(df), confidence)

    return ChiTest(objective >= chi, chi, objective)
end

function chiTest(
    analysis::PmuStateEstimation{<:WLS};
    confidence::Float64 = 0.95
)

    system = analysis.system
    se = analysis.method
    volt = analysis.voltage

    state = rectangularState(volt, system.bus.number)
    residual = se.mean - se.coefficient * state
    objective = transpose(residual) * se.precision * residual

    df = se.inservice - 2 * system.bus.number
    chi = quantile(Chisq(df), confidence)

    return ChiTest(objective >= chi, chi, objective)
end
