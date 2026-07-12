##### Sparse Matrix Builder #####
mutable struct CscBuilder{T}
    colptr::Vector{Int64}
    rowval::Vector{Int64}
    nzval::Vector{T}
end

function CscBuilder{T}(degree::Vector{Int64}) where T
    ncol = length(degree)
    colptr = Vector{Int64}(undef, ncol + 1)
    colptr[1] = 1

    @inbounds for col = 1:ncol
        colptr[col + 1] = colptr[col] + degree[col]
    end

    nnzmax = colptr[end] - 1
    CscBuilder{T}(
        colptr,
        Vector{Int64}(undef, nnzmax),
        Vector{T}(undef, nnzmax)
    )
end

function addEntry!(builder::CscBuilder{T}, row::Int64, col::Int64, value::T) where T
    ptr = builder.colptr[col]
    builder.rowval[ptr] = row
    builder.nzval[ptr] = value
    builder.colptr[col] += 1

    return ptr
end

function restoreColptr!(builder::CscBuilder)
    @inbounds for col = (length(builder.colptr) - 1):-1:2
        builder.colptr[col] = builder.colptr[col - 1]
    end
    builder.colptr[1] = 1

    return nothing
end

function canonicalize!(builder::CscBuilder{T}) where T
    restoreColptr!(builder)

    count = 1
    oldlo = 1
    builder.colptr[1] = 1

    @inbounds for col = 1:(length(builder.colptr) - 1)
        lo = oldlo
        oldlo = builder.colptr[col + 1]
        hi = oldlo - 1

        if lo <= hi
            for j = (lo + 1):hi
                row = builder.rowval[j]
                val = builder.nzval[j]
                k = j - 1
                while k >= lo && builder.rowval[k] > row
                    builder.rowval[k + 1] = builder.rowval[k]
                    builder.nzval[k + 1] = builder.nzval[k]
                    k -= 1
                end
                builder.rowval[k + 1] = row
                builder.nzval[k + 1] = val
            end

            row = builder.rowval[lo]
            value = builder.nzval[lo]
            for ptr = (lo + 1):hi
                if builder.rowval[ptr] == row
                    value += builder.nzval[ptr]
                else
                    builder.rowval[count] = row
                    builder.nzval[count] = value
                    count += 1
                    row = builder.rowval[ptr]
                    value = builder.nzval[ptr]
                end
            end

            builder.rowval[count] = row
            builder.nzval[count] = value
            count += 1
        end

        builder.colptr[col + 1] = count
    end

    resize!(builder.rowval, count - 1)
    resize!(builder.nzval, count - 1)

    return builder
end

function sparseMatrix!(builder::CscBuilder{T}, nrow::Int64) where T
    canonicalize!(builder)

    return SparseMatrixCSC(nrow, length(builder.colptr) - 1, builder.colptr, builder.rowval, builder.nzval)
end

##### Direct Sparse Storage #####
function ptrFromCounts(counts::Vector{Int64})
    ptr = Vector{Int64}(undef, length(counts) + 1)
    ptr[1] = 1

    @inbounds for i in eachindex(counts)
        ptr[i + 1] = ptr[i] + counts[i]
    end

    return ptr
end

function cscStorage(counts::Vector{Int64}, ::Type{T}) where T
    colptr = ptrFromCounts(counts)
    rowval = Vector{Int64}(undef, colptr[end] - 1)
    nzval = Vector{T}(undef, colptr[end] - 1)
    pos = copy(colptr)

    return colptr, rowval, nzval, pos
end

function sparseDiagonal(n::Int64, ::Type{T}) where T
    colptr = Vector{Int64}(undef, n + 1)
    rowval = Vector{Int64}(undef, n)
    nzval = Vector{T}(undef, n)

    @inbounds for i = 1:n
        colptr[i] = i
        rowval[i] = i
    end
    colptr[n + 1] = n + 1

    return SparseMatrixCSC(n, n, colptr, rowval, nzval)
end

function sparseDiagonalSqrtProduct(
    A::SparseMatrixCSC{Float64, Int64},
    x::Vector{Float64},
    n::Int64
)
    y = Vector{Float64}(undef, n)

    @inbounds for i = 1:n
        y[i] = sqrt(A.nzval[i]) * x[i]
    end

    return y
end

function sparseDiagonalSqrtProduct(
    D::SparseMatrixCSC{Float64, Int64},
    A::SparseMatrixCSC{Float64, Int64},
    n::Int64
)
    nzval = Vector{Float64}(undef, nnz(A))

    @inbounds for col = 1:size(A, 2)
        for ptr in A.colptr[col]:(A.colptr[col + 1] - 1)
            row = A.rowval[ptr]
            nzval[ptr] = sqrt(D.nzval[row]) * A.nzval[ptr]
        end
    end

    return SparseMatrixCSC(n, size(A, 2), copy(A.colptr), copy(A.rowval), nzval)
end

function sparseTransposeDiagonalProduct(
    A::SparseMatrixCSC{Float64, Int64},
    D::SparseMatrixCSC{Float64, Int64},
    x::Vector{Float64}
)
    y = Vector{Float64}(undef, size(A, 2))

    @inbounds for col = 1:size(A, 2)
        acc = 0.0
        for ptr in A.colptr[col]:(A.colptr[col + 1] - 1)
            row = A.rowval[ptr]
            acc += A.nzval[ptr] * D.nzval[row] * x[row]
        end
        y[col] = acc
    end

    return y
end

@inline function addCscEntry!(
    rowval::Vector{Int64},
    nzval::Vector{T},
    pos::Vector{Int64},
    row::Int64,
    col::Int64,
    value::T
) where T
    ptr = pos[col]
    rowval[ptr] = row
    nzval[ptr] = value
    pos[col] += 1

    return nothing
end

##### Sparse Matrix Queries #####
@inline function storedPosition(A::SparseMatrixCSC{T, Int64}, row::Int64, col::Int64) where T
    lo = A.colptr[col]
    hi = A.colptr[col + 1] - 1

    @inbounds while lo <= hi
        mid = (lo + hi) >>> 1
        r = A.rowval[mid]
        if r < row
            lo = mid + 1
        elseif r > row
            hi = mid - 1
        else
            return mid
        end
    end

    throw(ErrorException("The sparse matrix pattern does not contain the requested entry."))
end

function isstored(A::SparseMatrixCSC{Float64, Int64}, i::Int64, j::Int64)
    startIdx = A.colptr[j]
    endIdx = A.colptr[j + 1] - 1

    @inbounds for k = startIdx:endIdx
        if A.rowval[k] == i
            return true
        end
    end

    return false
end

@inline function addStored!(A::SparseMatrixCSC{T, Int64}, row::Int64, col::Int64, value::T) where T
    A.nzval[storedPosition(A, row, col)] += value

    return nothing
end

##### Drop Stored Zeros #####
function dropZeros!(A::SparseMatrixCSC{Float64, Int64}, pattern::Int64)
    oldNnz = nnz(A)
    dropzeros!(A)

    if pattern == 0 && oldNnz != nnz(A)
        return -1
    else
        return pattern
    end
end

##### Set Zeros in the Row and Column #####
function removeColumn(A::SparseMatrixCSC{Float64, Int64}, idx::Int64)
    removeIdx = A.colptr[idx]:(A.colptr[idx + 1] - 1)
    removeVal = A.nzval[removeIdx]
    @inbounds for i in removeIdx
        A.nzval[i] = 0.0
    end

    return removeIdx, removeVal
end

function removeRowColumn(A::SparseMatrixCSC{Float64, Int64}, idx::Int64)
    removeIdx = A.colptr[idx]:(A.colptr[idx + 1] - 1)
    removeVal = A.nzval[removeIdx]
    @inbounds for i in removeIdx
        A[A.rowval[i], idx] = 0.0
        A[idx, A.rowval[i]] = 0.0
    end

    return removeIdx, removeVal
end

##### Restore Values in the Row and Column #####
function restoreColumn!(
    A::SparseMatrixCSC{Float64, Int64},
    removeIdx::UnitRange{Int64},
    removeVal::Vector{Float64},
    idx::Int64
)
    @inbounds for (k, i) in enumerate(removeIdx)
        A[A.rowval[i], idx] = removeVal[k]
    end

    return nothing
end

function restoreRowColumn!(
    A::SparseMatrixCSC{Float64, Int64},
    removeIdx::UnitRange{Int64},
    removeVal::Vector{Float64},
    idx::Int64
)
    @inbounds for (k, i) in enumerate(removeIdx)
        A[A.rowval[i], idx] = removeVal[k]
        A[idx, A.rowval[i]] = removeVal[k]
    end

    return nothing
end
