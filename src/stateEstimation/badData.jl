"""
    residualTest!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation; threshold)

The function conducts bad data detection and identification using the largest normalized 
residual test, subsequently removing measurement outliers from the measurement set. It can 
be executed after obtaining estimation solutions.

# Arguments
This function necessitates the composite types `PowerSystem`, `Measurement`, and 
`DCStateEstimation` to detect and identify bad data.

# Keyword
The keyword `threshold` establishes the identification threshold. If the largest 
normalized residual surpasses this threshold, the measurement is flagged as bad data. The 
default threshold value is set to `threshold = 3.0`.

# Updates
In case bad data is detected, the function removes measurements from the `jacobian` matrix, 
`weight`, and `mean` vectors within the `DCStateEstimation` type. Additionally, it marks 
the respective measurement within the `Measurement` type as out-of-service.

Furthermore, the variable `bad` within the `DCStateEstimation` type stores information 
regarding bad data detection and identification:
- `detect`: returns `true` after the function's execution if bad data is detected;
- `maxNormalizedResidual`: denotes the value of the largest normalized residual;
- `index`: represents the index of the bad data associated with the `DCStateEstimation` type;
- `label`: signifies the label of the bad data.

# Example
Obtaining the solution after detecting and removing bad data:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)

residualTest!(system, device, analysis; threshold = 4.0)
solve!(system, analysis)
```

Obtaining the solution while bad data is detected:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)

while analysis.bad.detect
    solve!(system, analysis)
    residualTest!(system, device, analysis; threshold = 4.0)
end
```
"""
function residualTest!(system::PowerSystem, device::Measurement, analysis::DCStateEstimationWLS; threshold = 3.0)
    bus = system.bus
    se = analysis.method
    bad = analysis.bad

    slackRange, elementsRemove = deleteSlackJacobian(analysis, bus.layout.slack)
    gain = dcGain(analysis, bus.layout.slack)

    if !isa(se.factorization, SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64}) 
        F = lu(gain)
    else 
        F = se.factorization
    end

    ########## Construct Factorization ##########
    L, U, p, q, Rss = F.:(:)
    U = copy(transpose(U))
    d = fill(0.0, bus.number)
    Rs = fill(0.0, bus.number)

    for i = 1:bus.number
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
    gainInverse = sparseinv(L, U, d, p, q, Rs, R)

    ########## Diagonal entries of residual matrix ##########
    JGi = se.jacobian * gainInverse
    idx = findall(!iszero, se.jacobian)
    c = fill(0.0, size(se.jacobian, 1))
    for i in idx
        c[i[1]] += JGi[i] * se.jacobian[i]
    end

    ########## Largest normalized residual ##########
    h = se.jacobian * analysis.voltage.angle
    bad.maxNormalizedResidual = 0.0
    bad.index = 0
    @inbounds for i = 1:se.number
        normResidual = abs(se.mean[i] - h[i]) / sqrt(abs((1 / se.weight[i]) - c[i]))
        if normResidual > bad.maxNormalizedResidual
            bad.maxNormalizedResidual = normResidual
            bad.index = i
        end
    end

    restoreSlackJacobian(analysis, slackRange, elementsRemove, bus.layout.slack)
    
    bad.detect = false
    if bad.maxNormalizedResidual > threshold
        bad.detect = true

        colIndecies = findall(!iszero, se.jacobian[bad.index, :])
        for col in colIndecies
            se.jacobian[bad.index, col] = 0.0
        end
        se.mean[bad.index] = 0.0
        se.weight[bad.index] = 0.0 
        se.done = false     
    end

    bad.label = ""
    if bad.index <= device.wattmeter.number
        (bad.label,_),_ = iterate(device.wattmeter.label, bad.index)
    else
        (bad.label,_),_ = iterate(device.pmu.label, bad.index - device.wattmeter.number)
    end
end

### The sparse inverse subset of a real sparse square matrix: Compute the elimination tree of a sparse matrix
# Copyright (c) 2013-2014 Viral Shah, Douglas Bates and other contributors
# https://github.com/JuliaPackageMirrors/SuiteSparse.jl/blob/master/src/csparse.jl
# Based on Direct Methods for Sparse Linear Systems, T. A. Davis, SIAM, Philadelphia, Sept. 2006.
function etree(A)
    n = size(A, 2)
    parent = fill(0, n)
    ancestor = fill(0, n)
    for k in 1:n, p in A.colptr[k]:(A.colptr[k + 1] - 1)
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
    for j in n:-1:1
        if parent[j] == 0 
            continue 
        end
        next[j] = head[parent[j]]
        head[parent[j]] = j
    end
    stack = Int64[]
    for j in 1:n 
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
function symbfact(A, parent)
    m, n = size(A) 
    Ap = A.colptr 
    Ai = A.rowval
    col = Int64[]; sizehint!(col, n)
    row = Int64[]; sizehint!(row, n)

    visited = falses(n)
    for k = 1:m
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
@inbounds function sparseinv(L, U, d, p, q, Rs, R)
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
    for j = 1:n
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

    if flag
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
    for (k, i) in enumerate(idx)
        Zpattern[i] = Zx[k]
    end

    return Zpattern[invperm(q), invperm(p)]
end