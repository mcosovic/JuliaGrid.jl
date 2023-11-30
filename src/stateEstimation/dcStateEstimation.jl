"""
    dcStateEstimation(system::PowerSystem, device::Measurement, method)

The function sets up the framework to solve the DC state estimation.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish the 
framework. 

Additionally, the inclusion of the `method` parameter is not obligatory. It offers a range 
of techniques for resolving DC state estimation. To tackle the weighted least-squares (WLS) 
issue, users have the option to employ standard factorization methods like `LU` or `LDLt`, 
but only when the gain matrix is symmetrical. For a more resilient solution in situations 
involving ill-conditioned data, particularly when significant differences in variances 
exist, choosing the `QR` factorization method is recommended.

Moreover, instead of solving the WLS state estimation problem, users can utilize the least 
absolute value (LAV) method to find an estimator. This can be achieved by selecting one of 
the [optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/), 
where typically `Ipopt.Optimizer` suffices for common scenarios.

If the user does not provide the `method`, the default method for solving the DC estimation 
will be LU factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as 
the first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCStateEstimation` abstract type, which includes 
the following fields:
- `voltage`: the variable allocated to store the bus voltage angles;
- `power`: the variable allocated to store the active powers;
- `method`: the system model vectors and matrices, or alternatively, the optimization model.

# Examples
Establish the DC state estimation WLS framework that will be solved using the default LU 
factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
```

Establish the DC state estimation WLS framework that will be solved using the QR 
factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device, QR)
```

Establish the DC state estimation LAV framework:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function dcStateEstimation(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    jacobian, weight, mean = dcStateEstimationModel(system, device)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return DCStateEstimationWLS(
        PolarAngle(Float64[]),
        DCPowerSE(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
        ),
        DCStateEstimationWLSMethod(
            jacobian,
            weight,
            mean, 
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            false)
    )
end

function dcStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)
    jacobian, weight, mean = dcStateEstimationModel(system, device)

    bus = system.bus
    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    measureNumber = lastindex(mean)
    anglex = @variable(jump, 0 <= anglex[i = 1:bus.number])
    angley = @variable(jump, 0 <= angley[i = 1:bus.number])
    residualx = @variable(jump, 0 <= residualx[i = 1:measureNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:measureNumber])

    fix(anglex[bus.layout.slack], 0.0; force = true)
    fix(angley[bus.layout.slack], bus.voltage.angle[bus.layout.slack]; force = true)

    residual = Dict{Int64, JuMP.ConstraintRef}()
    angleJacobian = jacobian * (angley - anglex)
    for i = 1:measureNumber
        residual[i] = @constraint(jump, angleJacobian[i] + residualy[i] - residualx[i] - mean[i] == 0.0)
    end

    objective = @objective(jump, Min, sum(residualx[i] + residualy[i] for i = 1:measureNumber))

    return DCStateEstimationLAV(
        PolarAngle(Float64[]),
        DCPowerSE(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
        ),
        DCStateEstimationMethodLAV(
            jacobian,
            weight,
            mean, 
            jump,
            VariableLAV(anglex, angley, residualx, residualy),
            residual,
            objective)
    )
end

"""
    solve!(system::PowerSystem, analysis::DCStateEstimation)

By computing the bus voltage angles, the function solves the DC state estimation problem.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DCStateEstimation` 
type.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCStateEstimationWLS)
    se = analysis.method
    bus = system.bus

    slackRange = se.jacobian.colptr[bus.layout.slack]:(se.jacobian.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = se.jacobian.nzval[slackRange]
    @inbounds for i in slackRange
        se.jacobian.nzval[i] = 0.0
    end

    dcStateEstimationSolution(system, analysis, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end

    @inbounds for (k, i) in enumerate(slackRange)
        se.jacobian[se.jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    end 
end

function solve!(system::PowerSystem, analysis::DCStateEstimationLAV)
    se = analysis.method
    bus = system.bus

    JuMP.optimize!(se.jump)

    if isempty(analysis.voltage.angle)
        analysis.voltage.angle = fill(0.0, bus.number)
    end

    for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(se.variable.angley[i]::JuMP.VariableRef) - value(se.variable.anglex[i]::JuMP.VariableRef)
    end
end

########### DC State Estimation WLS Solution by LU or LDLt Factorization ###########
function dcStateEstimationSolution(system::PowerSystem, analysis::DCStateEstimationWLS, factorization::LULDLt)
    se = analysis.method
    bus = system.bus

    precision = spdiagm(0 => se.weight)
    if !se.done
        se.done = true

        gain = transpose(se.jacobian) * precision * se.jacobian
        gain[bus.layout.slack, bus.layout.slack] = 1.0
        se.factorization = sparseFactorization(gain, se.factorization)
    end
    b = transpose(se.jacobian) * precision * se.mean

    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, b, se.factorization)
end

########### DC State Estimation WLS Solution by QR Factorization ###########
function dcStateEstimationSolution(system::PowerSystem, analysis::DCStateEstimationWLS, factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64})
    se = analysis.method
    bus = system.bus

    precision = spdiagm(0 => sqrt.(se.weight))
    if !se.done
        se.done = true

        jacobianScale = precision * se.jacobian
        se.factorization = sparseFactorization(jacobianScale, se.factorization)
    end
    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, precision * se.mean, se.factorization)
end

########### DC State Estimation Model ###########
function dcStateEstimationModel(system::PowerSystem, device::Measurement)
    dc = system.model.dc
    bus = system.bus
    branch = system.branch
    wattmeter = device.wattmeter
    pmu = device.pmu

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end
    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end

    nonZeroElement = 0 
    measureNumber = 0
    @inbounds for (i, index) in enumerate(wattmeter.layout.index)
        if wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                nonZeroElement += (dc.nodalMatrix.colptr[index + 1] - dc.nodalMatrix.colptr[index])
                measureNumber += 1
            else
                nonZeroElement += 2 
                measureNumber += 1
            end
        end
    end
    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i] && pmu.angle.status[i] == 1
            nonZeroElement += 1 
            measureNumber += 1
        end
    end

    row = fill(0, nonZeroElement) 
    col = similar(row)
    jac = fill(0.0, nonZeroElement)
    mean = fill(0.0, measureNumber)
    weight = similar(mean)

    count = 1
    rowindex = 1
    @inbounds for (i, index) in enumerate(wattmeter.layout.index)
        if wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                for j in dc.nodalMatrix.colptr[index]:(dc.nodalMatrix.colptr[index + 1] - 1)
                    row[count] = rowindex
                    col[count] = dc.nodalMatrix.rowval[j]
                    jac[count] = dc.nodalMatrix.nzval[j]
                    count += 1
                end
                mean[rowindex] = wattmeter.active.mean[i] - dc.shiftPower[index] - bus.shunt.conductance[index]
                weight[rowindex] = 1 / wattmeter.active.variance[i]
    
                rowindex += 1
            else
                if wattmeter.layout.from[i]
                    addmitance = dc.admittance[index]
                else
                    addmitance = -dc.admittance[index]
                end

                row[count] = rowindex
                col[count] = branch.layout.from[index]
                jac[count] = addmitance
                count += 1
                row[count] = rowindex
                col[count] = branch.layout.to[index]
                jac[count] = -addmitance

                mean[rowindex] = wattmeter.active.mean[i] + branch.parameter.shiftAngle[index] * addmitance
                weight[rowindex] = 1 / wattmeter.active.variance[i]
    
                count += 1; rowindex += 1
            end
        end
    end
    @inbounds for i = 1:pmu.number
        if  pmu.layout.bus[i] && pmu.angle.status[i] == 1
            row[count] = rowindex
            col[count] = pmu.layout.index[i]
            jac[count] = 1.0

            mean[rowindex] = pmu.angle.mean[i] - bus.voltage.angle[bus.layout.slack]
            weight[rowindex] = 1 / pmu.angle.variance[i]

            count += 1; rowindex += 1
        end
    end

    return sparse(row, col, jac, measureNumber, bus.number), weight, mean
end

function badData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation; threshold = 3.0)
    bus = system.bus
    se = analysis.method

    slackRange = se.jacobian.colptr[bus.layout.slack]:(se.jacobian.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = se.jacobian.nzval[slackRange]
    @inbounds for i in slackRange
        se.jacobian.nzval[i] = 0.0
    end

    gain = transpose(se.jacobian) * spdiagm(0 => se.weight) * se.jacobian
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    # @inbounds for (k, i) in enumerate(slackRange)
    #     se.jacobian[se.jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    # end 

    if !isa(se.factorization, SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64}) 
        F = lu(gain)
    else 
        F = se.factorization
    end

    ########## Construct Factorization ##########
    L, U, p, q, Rss = F.:(:)
    U = copy(transpose(U))
    n = size(U, 2)
    d = fill(0.0, n)
    Rs = fill(0.0, n)

    for i = 1:n
        Rs[i] = Rss[p[i]]
        d[i] = U[i, i]
        for j = U.colptr[i]:(U.colptr[i + 1] - 1)
            if i != U.rowval[j]
                U.nzval[j] = U.nzval[j] / d[i]
            end
        end
    end
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
    rmax = 0.0; idxr = 0

    @inbounds for i = 1:lastindex(se.mean)
        rnor = abs(se.mean[i] - h[i]) / sqrt(abs((1 / se.weight[i]) - c[i]))
        if rnor > rmax
            idxr = i
            rmax = rnor
        end
    end

    display([idxr rmax])

    @inbounds for (k, i) in enumerate(slackRange)
        se.jacobian[se.jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    end 

    colIndecies = findall(!iszero, se.jacobian[idxr, :])
    for col in colIndecies
        se.jacobian[idxr, col] = 0.0
    end
    se.mean[idxr] = 0.0
    se.weight[idxr] = 0.0
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



