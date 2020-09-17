### Numbering
@inbounds function renumber(data, Nchange, original, new, Noldnew, numbering)
    if numbering
        lookup = Dict{Int, Int}()
        for (x, y) in zip(original, new)
            lookup[x] = y
        end

        for i = 1:length(data)
            data[i] = lookup[data[i]]
        end
    end

    return data
end


### Save data in h5-file or xlsx-file
@inbounds function savedata(args...; group, header, path, info = "", skip = [])
    extension = match(r"\.[A-Za-z0-9]+$", path).match

    if extension == ".h5"
        h5open(path, "w") do file
            for i in keys(group)
                if group[i] != 0
                    write(file, String(i), getfield(args[group[i]], i))
                    try
                        head = header[i]
                        N = size(getfield(args[group[i]], i), 2)
                        if N == 1
                            N = size(getfield(args[group[i]], i), 1)
                        end
                        atr = Dict(string("row", k) => string(head[1, k], ": ", head[2, k]) for k = 1:N)
                        h5writeattr(path, String(i), atr)
                    catch
                    end
                end
            end
            if !isempty(info)
                write(file, "info", info)
            end
        end
        println("Data is successfully exported to $path")
    elseif extension == ".xlsx"
        k = 1
        XLSX.openxlsx(path, mode = "w") do xf
            for i in keys(group)
                if group[i] != 0
                    if k == 1
                        sheet = xf[k]
                        XLSX.rename!(sheet, String(i))
                    else
                        XLSX.addsheet!(xf, String(i))
                        sheet = xf[k]
                    end
                    N = size(getfield(args[group[i]], i), 2)
                    if N == 1
                        N = size(getfield(args[group[i]], i), 1)
                    end
                    sheet["A1"] = header[i][:, 1:N]
                    sheet["A3"] = getfield(args[group[i]], i)
                    k += 1
                end
            end
            if !isempty(info)
                XLSX.addsheet!(xf, "info")
                sheet = xf[k]
                sheet["A1"] = info
            end
        end
        println("Data is successfully exported to $path")
    else
        throw(ErrorException("the SAVE data format is not supported"))
    end

end


### Start row in xlsx-file
function startxlsx(xf)
    start = 1
    for r in XLSX.eachrow(xf)
        if !isa(r[1], String)
            start = XLSX.row_number(r)
            break
        end
    end
    return start
end


### Weighted least-squares method
@inbounds function wls(G, b, method)
    if method == "lu"
        F = lu(G)
        L, U, p, q, Rs = F.:(:)
        x = U \  (L \ ((Rs .* b)[p]))
        x = x[sortperm(q)]
    else
        x = G \ b
    end

    return x
end


### Least-squares method
@inbounds function ls(A, b, method)
    if method == "lu"
        F = lu(A)
        L, U, p, q, Rs = F.:(:)
        x = U \  (L \ ((Rs .* b)[p]))
        x = x[sortperm(q)]
    else
        x = A \ b
    end

    return x
end


### Least absolute value method
@inbounds function lav(J, z, Nvar, Nmeasure, settings)
    t = [zeros(2 * Nvar); ones(2 * Nmeasure)]
    E = spdiagm(0 => ones(Nmeasure))
    A = [J -J E -E]
    lb = zeros(2 * (Nvar + Nmeasure))

    if settings.lav[:optimize] == 2
        model = Model(Ipopt.Optimizer)
    else
        model = Model(GLPK.Optimizer)
    end

    @variable(model, x[i = 1:(2 * (Nvar + Nmeasure))])
    @constraint(model, lb .<= x)
    @constraint(model, A * x .== z)
    @objective(model, Min, t' * x)
    optimize!(model)
    println("Least Aabsolute value state estimation status: $(JuMP.termination_status(model))")

    return JuMP.value.(x)
end


### Try-catch next element
function nextelement(set, current)
    value = 0.0
    try
        value = set[current + 1]
        if value == "all"
            value = -200.0
        end
        value = Float64(value)
    catch
        throw(ErrorException("the name-value pair setting is missing"))
    end

    return value
end


### Data structure
function datastruct(data, max; var = "")
    Nrow, Ncol = size(data)
    if Ncol < max
        throw(DomainError(var, "dimension mismatch"))
    end

    return Nrow
end


### The sparse inverse subset of a real sparse square matrix: Construct the factorization
function constructfact(A)
    F = lu(A)
    L, U, p, q, Rss = F.:(:)
    U = copy(transpose(U))
    n = size(U, 2)
    d = fill(0.0, n)
    Rs = fill(0.0, n)
    for i = 1:n
        Rs[i] = Rss[p[i]]
        d[i] = U[i,i]
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
    S = A[p, q]
    S = S + transpose(S)

    return S, L, U, d, p, q, Rs
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
            if (inext == 0)
                parent[i] = k
            end
            i = inext
        end
    end

    head = fill(0, n)
    next = fill(0, n)
    for j in n:-1:1
        if (parent[j] == 0); continue; end
        next[j] = head[parent[j]]
        head[parent[j]] = j
    end
    stack = Int64[]
    for j in 1:n
        if (parent[j] != 0)
            continue
        end
        push!(stack, j)
        while (!isempty(stack))
            p = stack[end]
            i = head[p]
            if (i == 0)
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
    m,n = size(A); Ap = A.colptr; Ai = A.rowval
    col = Int64[]; sizehint!(col, n)
    row = Int64[]; sizehint!(row, n)

    visited = falses(n)
    for k = 1:m
        visited = falses(n)
        visited[k] = true
        for p in Ap[k]:(Ap[k + 1] - 1)
            i = Ai[p]
            if i > k continue end
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
            if pdiag == -1
                if Zrowval[p] == j
                    pdiag = p
                    Zx[p] = 1 / (d[j] / Rs[j])
                end
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
                if (Lmunch[k] < L.colptr[k] || L.rowval[Lmunch[k]] != j)
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

    Zpattern = Zpattern[invperm(q), invperm(p)]

    return Zpattern
end

### Independent system of equations
function independentset(Jt)
    F = qr(Jt)
    R = F.R
    P = F.pcol

    flag = (10^-5) * R[1,1]
    r = 0
    @inbounds for i = 1:size(R,1)
        if abs(R[i,i]) >= flag
            r = i
        end
    end
    p = P[1:r]
    Ht = Jt[:, p]
    dropzeros!(Ht)

    return Ht
end

### Make factor graph
function factorgraph(Ht, Nvar, Nfac, Nlink, Nind)
    ########## Define indirect factor nodes arrays ##########
    row = fill(0, Nlink); col = similar(row)
    rowptr = fill(0, Nind); colptr = fill(0, Nvar)
    idxi = 1; idxr = 1
    idxT = findall(!iszero, Ht)
    @inbounds for i in idxT
        if (Ht.colptr[i[2] + 1] - Ht.colptr[i[2]]) != 1
            row[idxi] = idxr
            col[idxi] = i[1]

            idxi += 1

            colptr[i[1]] += 1
            rowptr[idxr] = idxi

            if idxT[Ht.colptr[i[2] + 1] - 1] == i
                idxr += 1
            end
        end
    end
    pushfirst!(colptr, 1)
    pushfirst!(rowptr, 1)
    colptr = cumsum(colptr)

    ########## Initialize arrays for messages ##########
    Vvar_fac = fill(1e-5, Nlink)
    Wfac_var = similar(Vvar_fac)

    ########## Indices for sending messages ##########
    temp = collect(1:Nlink)
    sort_col_idx = sortperm(col)
    to_fac = temp[sort_col_idx]

    new_row = row[sort_col_idx]
    sort_row_idx = sortperm(new_row)
    to_var = temp[sort_row_idx]

    return Vvar_fac, Wfac_var, to_fac, to_var, colptr, rowptr, idxT, row, col
end
