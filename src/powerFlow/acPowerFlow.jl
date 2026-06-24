"""
    newtonRaphson(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the Newton-Raphson method to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Uses LU factorization (default).
- `KLU`: Uses KLU factorization.
- `QR`: Uses QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the Newton-Raphson method using LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
```

Set up the Newton-Raphson method using KLU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system, KLU)
```
"""
function newtonRaphson(system::PowerSystem, ::Type{T} = LU) where {T <: Union{QR, LU, KLU}}
    ac = system.model.ac

    checkSlackBus(system)
    model!(system, ac)
    voltMagnitude, voltAngle = initializeACPowerFlow(system)

    jacobian, pq, pvpq, pcount = newtonJacobian(system)
    dimJcb = size(jacobian, 1)

    AcPowerFlow(
        Polar(
            voltMagnitude,
            voltAngle
        ),
        AcPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        AcCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        NewtonRaphson{T}(
            jacobian,
            fill(0.0, dimJcb),
            fill(0.0, dimJcb),
            selectFactorization(T),
            pq,
            pvpq,
            pcount,
            NewtonRaphsonSignature(
                copy(system.model.revision.topology),
                -1,
                copy(system.model.revision.type)
            ),
            0
        ),
        system
    )
end

function newtonJacobian(system::PowerSystem)
    ac = system.model.ac
    bus = system.bus

    pq = fill(0, bus.number)
    pvpq = fill(0, bus.number)
    pvpqNum = 0
    pqNum = 0
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            pqNum += 1
            pq[i] = pqNum + bus.number - 1
        end
        if bus.layout.type[i] != 3
            pvpqNum += 1
            pvpq[i] = pvpqNum
        end
    end

    dimJcb = bus.number + pqNum - 1
    colcount = fill(0, dimJcb)
    pcount = fill(0, bus.number)
    qcount = fill(0, bus.number)

    @inbounds for i = 1:bus.number
        i == bus.layout.slack && continue

        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[ptr]]
            if typeRow != 3
                pcount[i] += 1
            end
            if typeRow == 1
                qcount[i] += 1
            end
        end

        colcount[pvpq[i]] = pcount[i] + qcount[i]
        if bus.layout.type[i] == 1
            colcount[pq[i]] = pcount[i] + qcount[i]
        end
    end

    colptr = Vector{Int64}(undef, dimJcb + 1)
    colptr[1] = 1
    @inbounds for col = 1:dimJcb
        colptr[col + 1] = colptr[col] + colcount[col]
    end

    nnzJcb = colptr[end] - 1
    rowval = Vector{Int64}(undef, nnzJcb)
    nzval = fill(0.0, nnzJcb)

    @inbounds for i = 1:bus.number
        i == bus.layout.slack && continue

        isPQ = bus.layout.type[i] == 1
        pAnglePos = colptr[pvpq[i]]
        qAnglePos = pAnglePos + pcount[i]
        pMagnitudePos = isPQ ? colptr[pq[i]] : 0
        qMagnitudePos = isPQ ? pMagnitudePos + pcount[i] : 0

        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            typeRow = bus.layout.type[row]

            if typeRow != 3
                rowval[pAnglePos] = pvpq[row]
                pAnglePos += 1
                if isPQ
                    rowval[pMagnitudePos] = pvpq[row]
                    pMagnitudePos += 1
                end
            end
            if typeRow == 1
                rowval[qAnglePos] = pq[row]
                qAnglePos += 1
                if isPQ
                    rowval[qMagnitudePos] = pq[row]
                    qMagnitudePos += 1
                end
            end
        end
    end

    return SparseMatrixCSC(dimJcb, dimJcb, colptr, rowval, nzval), pq, pvpq, pcount
end

"""
    fastNewtonRaphsonBX(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the fast Newton-Raphson method of version BX to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Uses LU factorization (default).
- `KLU`: Uses KLU factorization.
- `QR`: Uses QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the fast Newton-Raphson method using LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonBX(system)
```

Set up the fast Newton-Raphson method using KLU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonBX(system, KLU)
```
"""
function fastNewtonRaphsonBX(system::PowerSystem, ::Type{T} = LU) where {T <: Union{QR, LU, KLU}}
    fastNewtonRaphsonModel(system, T, true)
end

"""
    fastNewtonRaphsonXB(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the fast Newton-Raphson method of version XB to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Uses LU factorization (default).
- `KLU`: Uses KLU factorization.
- `QR`: Uses QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the fast Newton-Raphson method using LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonXB(system)
```

Set up the fast Newton-Raphson method using KLU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonXB(system, KLU)
```
"""
function fastNewtonRaphsonXB(system::PowerSystem, ::Type{T} = LU) where {T <: Union{QR, LU, KLU}}
    fastNewtonRaphsonModel(system, T, false)
end

function fastNewtonRaphsonModel(system::PowerSystem, ::Type{T}, bx::Bool) where {T <: Union{QR, LU, KLU}}
    bus = system.bus
    branch = system.branch
    ac = system.model.ac

    checkSlackBus(system)
    model!(system, ac)
    voltMagnitude, voltAngle = initializeACPowerFlow(system)

    activeJacobian, reactiveJacobian, pq, pvpq = fastNewtonJacobian(system)

    analysis = AcPowerFlow(
        Polar(
            voltMagnitude,
            voltAngle
        ),
        AcPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        AcCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        FastNewtonRaphson{T}(
            FastNewtonRaphsonModel{T}(
                activeJacobian,
                fill(0.0, bus.number - 1),
                fill(0.0, bus.number - 1),
                selectFactorization(T),
            ),
            FastNewtonRaphsonModel{T}(
                reactiveJacobian,
                fill(0.0, size(reactiveJacobian, 1)),
                fill(0.0, size(reactiveJacobian, 1)),
                selectFactorization(T),
            ),
            pq,
            pvpq,
            FastNewtonRaphsonSignature(
                copy(system.model.revision.topology),
                copy(system.model.revision.acModel),
                -1,
                -1,
                copy(system.model.revision.type),
                Dict{Int64, Float64}()
            ),
            bx,
            0
        ),
        system
    )

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            fastNewtonJacobian!(system, analysis, i)
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1 && bus.shunt.susceptance[i] != 0
            j = analysis.method.pq[i]
            addStored!(analysis.method.reactive.jacobian, j, j, bus.shunt.susceptance[i])
            analysis.method.signature.susceptance[i] = bus.shunt.susceptance[i]
        end
    end

    return analysis
end

function fastNewtonJacobian(system::PowerSystem)
    bus = system.bus
    ac = system.model.ac

    pq = fill(0, bus.number)
    pvpq = fill(0, bus.number)
    pvpqNum = 0
    pqNum = 0
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            pqNum += 1
            pq[i] = pqNum
        end
        if bus.layout.type[i] != 3
            pvpqNum += 1
            pvpq[i] = pvpqNum
        end
    end

    colcountP = fill(0, bus.number - 1)
    colcountQ = fill(0, pqNum)
    @inbounds for i = 1:bus.number
        i == bus.layout.slack && continue

        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[ptr]]
            if typeRow != 3
                colcountP[pvpq[i]] += 1
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                colcountQ[pq[i]] += 1
            end
        end
    end

    colptrP = Vector{Int64}(undef, bus.number)
    colptrP[1] = 1
    @inbounds for col = 1:(bus.number - 1)
        colptrP[col + 1] = colptrP[col] + colcountP[col]
    end

    colptrQ = Vector{Int64}(undef, pqNum + 1)
    colptrQ[1] = 1
    @inbounds for col = 1:pqNum
        colptrQ[col + 1] = colptrQ[col] + colcountQ[col]
    end

    rowvalP = Vector{Int64}(undef, colptrP[end] - 1)
    rowvalQ = Vector{Int64}(undef, colptrQ[end] - 1)
    @inbounds for i = 1:bus.number
        i == bus.layout.slack && continue

        ppos = colptrP[pvpq[i]]
        qpos = bus.layout.type[i] == 1 ? colptrQ[pq[i]] : 0
        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            typeRow = bus.layout.type[row]

            if typeRow != 3
                rowvalP[ppos] = pvpq[row]
                ppos += 1
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                rowvalQ[qpos] = pq[row]
                qpos += 1
            end
        end
    end

    return (
        SparseMatrixCSC(bus.number - 1, bus.number - 1, colptrP, rowvalP, zeros(colptrP[end] - 1)),
        SparseMatrixCSC(pqNum, pqNum, colptrQ, rowvalQ, zeros(colptrQ[end] - 1)),
        pq,
        pvpq
    )
end

function fastNewtonJacobian!(
    system::PowerSystem,
    analysis::AcPowerFlow{<:FastNewtonRaphson},
    idx::Int64
)
    i, j = fromto(system, idx)
    p, q = jacobianCoefficient(system, analysis.method, idx)
    method = analysis.method
    active = method.active.jacobian
    reactive = method.reactive.jacobian

    m = method.pvpq[i]
    n = method.pvpq[j]
    rowi = method.pq[i]
    rowj = method.pq[j]

    if i != system.bus.layout.slack && j != system.bus.layout.slack
        pij, pji = Pijθij(p)
        addStored!(active, m, n, pij)
        addStored!(active, n, m, pji)
    end
    if i != system.bus.layout.slack
        addStored!(active, m, m, Pijθi(p))
    end
    if j != system.bus.layout.slack
        addStored!(active, n, n, p.B)
    end

    if rowi != 0 && rowj != 0
        addStored!(reactive, rowi, rowj, q.A)
        addStored!(reactive, rowj, rowi, q.A)
    end
    if system.bus.layout.type[i] == 1
        addStored!(reactive, rowi, rowi, q.B)
    end
    if system.bus.layout.type[j] == 1
        addStored!(reactive, rowj, rowj, q.C)
    end

    return nothing
end

function jacobianCoefficient(system::PowerSystem, method::FastNewtonRaphson, idx::Int64)
    bsi = 0.5 * system.branch.parameter.susceptance[idx]
    τinv = 1 / system.branch.parameter.turnsRatio[idx]
    sinθ, cosθ = sincos(system.branch.parameter.shiftAngle[idx])

    if method.bx
        bmk = - 1 / system.branch.parameter.reactance[idx]
        A, B = reim(system.model.ac.admittance[idx])
    else
        bmk = imag(system.model.ac.admittance[idx])
        A = 0.0
        B = -1 / system.branch.parameter.reactance[idx]
    end

    PiModel(
        A = A,
        B = B,
        C = sinθ,
        D = cosθ
    ),
    PiModel(
        A = - bmk * τinv,
        B = (bmk + bsi) * τinv^2,
        C = (bmk + bsi)
    )
end

@inline function Pijθij(p::PiModel)
    denominator = p.D^2 + p.C^2

    return (-p.A * p.C - p.B * p.D) / denominator,
        (p.A * p.C - p.B * p.D) / denominator
end

@inline function Pijθij(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, i::Int64, j::Int64)
    m = mth.pvpq[i]
    n = mth.pvpq[j]

    if i != system.bus.layout.slack && j != system.bus.layout.slack
        pij, pji = Pijθij(p)
        mth.active.jacobian[m, n] += pij
        mth.active.jacobian[n, m] += pji
    end
end

@inline Pijθi(p::PiModel) = p.B / (p.D^2 + p.C^2)

@inline function Pijθi(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, i::Int64)
    if i != system.bus.layout.slack
        mth.active.jacobian[mth.pvpq[i], mth.pvpq[i]] += Pijθi(p)
    end
end

@inline function Pijθj(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, j::Int64)
    if j != system.bus.layout.slack
        mth.active.jacobian[mth.pvpq[j], mth.pvpq[j]] += p.B
    end
end

@inline function QijVij(mth::FastNewtonRaphson, q::PiModel, i::Int64, j::Int64)
    m = mth.pq[i]
    n = mth.pq[j]

    if m != 0 && n != 0
        mth.reactive.jacobian[m, n] += q.A
        mth.reactive.jacobian[n, m] += q.A
    end
end

@inline function QijVi(system::PowerSystem, mth::FastNewtonRaphson, q::PiModel, i::Int64)
    if system.bus.layout.type[i] == 1
        mth.reactive.jacobian[mth.pq[i], mth.pq[i]] += q.B
    end
end

@inline function QijVj(system::PowerSystem, mth::FastNewtonRaphson, q::PiModel, j::Int64)
    if system.bus.layout.type[j] == 1
        mth.reactive.jacobian[mth.pq[j], mth.pq[j]] += q.C
    end
end

"""
    gaussSeidel(system::PowerSystem)

The function sets up the Gauss-Seidel method to solve the AC power flow.

# Argument
The function requires the `PowerSystem` type to establish the framework.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = gaussSeidel(system)
```
"""
function gaussSeidel(system::PowerSystem)
    checkSlackBus(system)
    model!(system, system.model.ac)
    voltgMagnitude, voltgAngle = initializeACPowerFlow(system)

    bus = system.bus

    voltg = zeros(ComplexF64, bus.number)
    pq = Int64[]
    pv = Int64[]
    sizehint!(pq, bus.number)
    sizehint!(pv, bus.number)
    @inbounds for i = 1:bus.number
        voltg[i] = voltgMagnitude[i] * cis(voltgAngle[i])

        if bus.layout.type[i] == 1
            push!(pq, i)
        end
        if bus.layout.type[i] == 2
            push!(pv, i)
        end
    end

    AcPowerFlow(
        Polar(
            voltgMagnitude,
            voltgAngle
        ),
        AcPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        AcCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        GaussSeidel(
            voltg,
            pq,
            pv,
            GaussSeidelSignature(
                copy(system.model.revision.topology),
                copy(system.model.revision.type)
            ),
            0
        ),
        system
    )
end

"""
    mismatch!(analysis::AcPowerFlow)

The function calculates both active and reactive power injection mismatches.

# Updates
This function updates the `mismatch` variables in the Newton-Raphson and fast Newton-Raphson methods.
It should be used during the iteration loop before invoking the
[`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson{T}}) where T) function.

# Returns
The function returns maximum absolute values of the active and reactive power injection mismatches,
which can be used to terminate the iteration loop of the Newton-Raphson, fast Newton-Raphson, or
Gauss-Seidel methods used to solve the AC power flow problem.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
mismatch!(analysis)
```
"""
function mismatch!(analysis::AcPowerFlow{<:NewtonRaphson})
    system = analysis.system
    ac = system.model.ac
    bus = system.bus
    voltg = analysis.voltage
    mism = analysis.method.mismatch
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    stopP = 0.0
    stopQ = 0.0
    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        k = pvpq[i]
        q = pq[i]
        currentP = 0.0
        currentQ = 0.0
        isPQ = bus.layout.type[i] == 1
        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltg, i, row, ptr)

            currentP += PiQiSumPlus(voltg, Gij, cosθij, Bij, sinθij, row)
            if isPQ
                currentQ += PiQiSumMinus(voltg, Gij, sinθij, Bij, cosθij, row)
            end
        end

        mism[k] = Pi(voltg, currentP, i) - bus.supply.active[i] + bus.demand.active[i]
        stopP = max(stopP, abs(mism[k]))
        if isPQ
            mism[q] = Qi(voltg, currentQ, i) - bus.supply.reactive[i] + bus.demand.reactive[i]
            stopQ = max(stopQ, abs(mism[q]))
        end
    end

    return stopP, stopQ
end

function mismatch!(analysis::AcPowerFlow{<:FastNewtonRaphson})
    system = analysis.system
    ac = system.model.ac
    bus = system.bus

    volt = analysis.voltage
    mismP = analysis.method.active.mismatch
    mismQ = analysis.method.reactive.mismatch
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    stopP = 0.0
    stopQ = 0.0
    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        k = pvpq[i]
        q = pq[i]
        currentP = 0.0
        currentQ = 0.0
        isPQ = bus.layout.type[i] == 1
        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, volt, i, row, ptr)

            currentP += PiQiSumPlus(volt, Gij, cosθij, Bij, sinθij, row)
            if isPQ
                currentQ += PiQiSumMinus(volt, Gij, sinθij, Bij, cosθij, row)
            end
        end

        Vinv = 1 / volt.magnitude[i]
        mismP[k] = currentP - (bus.supply.active[i] - bus.demand.active[i]) * Vinv
        stopP = max(stopP, abs(mismP[k]))
        if isPQ
            mismQ[q] = currentQ - (bus.supply.reactive[i] - bus.demand.reactive[i]) * Vinv
            stopQ = max(stopQ, abs(mismQ[q]))
        end
    end

    return stopP, stopQ
end

function mismatch!(analysis::AcPowerFlow{GaussSeidel})
    system = analysis.system
    bus = system.bus
    ac = system.model.ac
    voltg = analysis.method.voltage

    stopP = 0.0
    stopQ = 0.0
    @inbounds for i in analysis.method.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltg[ac.nodalMatrix.rowval[j]]
        end
        Pi, Qi = reim(voltg[i] * conj(I))

        mismP = Pi - bus.supply.active[i] + bus.demand.active[i]
        stopP = max(stopP, abs(mismP))

        mismQ = Qi - bus.supply.reactive[i] + bus.demand.reactive[i]
        stopQ = max(stopQ, abs(mismQ))
    end

    @inbounds for i in analysis.method.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltg[ac.nodalMatrix.rowval[j]]
        end
        mismP = real(voltg[i] * conj(I)) - bus.supply.active[i] + bus.demand.active[i]
        stopP = max(stopP, abs(mismP))
    end

    return stopP, stopQ
end

"""
    solve!(analysis::AcPowerFlow)

The function uses the Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method to solve the AC
power flow and calculate bus voltage magnitudes and angles.

After the [`mismatch!`](@ref mismatch!(::AcPowerFlow{<:NewtonRaphson})) function is executed, the execution of this function will
perform a single iteration of one of the methods.

# Updates
The calculated voltages are stored in the `voltage` field of the `AcPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(analysis)
end
```
"""
function solve!(analysis::AcPowerFlow{NewtonRaphson{T}}) where T
    system = analysis.system
    ac = system.model.ac
    revision = system.model.revision
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage

    if revision.topology != pf.signature.topology || revision.type != pf.signature.type
        errorTypeConversion()
    end

    patternChanged = revision.acPattern != pf.signature.acPattern
    if patternChanged && pf.signature.acPattern != -1
        pf.jacobian, pf.pq, pf.pvpq, pf.pcount = newtonJacobian(system)
        resize!(pf.mismatch, size(pf.jacobian, 1))
        resize!(pf.increment, size(pf.jacobian, 1))
    end

    jcb = pf.jacobian
    pq = pf.pq
    pvpq = pf.pvpq
    pcount = pf.pcount
    nzval = jcb.nzval
    jcolptr = jcb.colptr

    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        isPQ = bus.layout.type[i] == 1

        pAnglePos = jcolptr[pvpq[i]]
        qAnglePos = pAnglePos + pcount[i]
        pMagnitudePos = isPQ ? jcolptr[pq[i]] : 0
        qMagnitudePos = isPQ ? pMagnitudePos + pcount[i] : 0

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[j]
            type = bus.layout.type[row]

            if type == 3
                continue
            end

            Gij, Bij = reim(ac.nodalMatrix.nzval[j])
            if row != i
                sinθij, cosθij = sincos(volt.angle[row] - volt.angle[i])

                nzval[pAnglePos] = Piθj(volt, Gij, Bij, sinθij, cosθij, row, i)
                pAnglePos += 1
                if type == 1
                    nzval[qAnglePos] = Qiθj(volt, Gij, Bij, sinθij, cosθij, row, i)
                    qAnglePos += 1
                end
                if isPQ
                    nzval[pMagnitudePos] = PiVj(volt, Gij, Bij, sinθij, cosθij, row)
                    pMagnitudePos += 1
                end
                if isPQ && type == 1
                    nzval[qMagnitudePos] = QiVj(volt, Gij, Bij, sinθij, cosθij, row)
                    qMagnitudePos += 1
                end
            else
                currentθ = 0.0
                currentV = 0.0
                for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                    q = ac.nodalMatrix.rowval[ptr]
                    Gik, Bik = reim(ac.nodalMatrixTranspose.nzval[ptr])
                    sinθik, cosθik = sincos(volt.angle[i] - volt.angle[q])

                    currentθ += PiQiSumMinus(volt, Gik, sinθik, Bik, cosθik, q)
                    if isPQ
                        currentV += PiQiSumPlus(volt, Gik, cosθik, Bik, sinθik, q)
                    end
                end

                nzval[pAnglePos] = Piθi(volt, Bij, -currentθ, row)
                pAnglePos += 1
                if isPQ
                    nzval[qAnglePos] = Qiθi(volt, Gij, currentV, row)
                    qAnglePos += 1
                end
                if isPQ
                    nzval[pMagnitudePos] = PiVi(volt, Gij, currentV, row)
                    pMagnitudePos += 1
                end
                if isPQ
                    nzval[qMagnitudePos] = QiVi(volt, Bij, currentθ, row)
                    qMagnitudePos += 1
                end
            end
        end
    end

    if patternChanged
        pf.signature.acPattern = copy(revision.acPattern)
        pf.factorization = factorization(jcb, pf.factorization, T)
    else
        pf.factorization = factorization!(jcb, pf.factorization, T)
    end

    solution!(pf.increment, pf.factorization, pf.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            volt.magnitude[i] = volt.magnitude[i] - pf.increment[pq[i]]
        end
        if i != bus.layout.slack
            volt.angle[i] = volt.angle[i] - pf.increment[pvpq[i]]
        end
    end

    pf.iteration += 1

    return nothing
end

function solve!(analysis::AcPowerFlow{FastNewtonRaphson{T}}) where T
    system = analysis.system
    ac = system.model.ac
    revision = system.model.revision
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage
    active = pf.active
    reactive = pf.reactive
    pq = pf.pq
    pvpq = pf.pvpq

    if revision.topology != pf.signature.topology || revision.type != pf.signature.type
        errorTypeConversion()
    end

    if revision.acModel != pf.signature.acModel
        if revision.acModel != pf.signature.jacobian
            throw(ErrorException(
                "The fast Newton-Raphson model cannot be reused because the power system " *
                "changed without updating the analysis model."
            ))
        end

        pf.signature.acModel = copy(revision.acModel)

        if revision.acPattern == pf.signature.acPattern
            active.factorization = factorization!(active.jacobian, active.factorization, T)
            reactive.factorization = factorization!(reactive.jacobian, reactive.factorization, T)
        else
            pf.signature.acPattern = copy(revision.acPattern)

            active.factorization = factorization(active.jacobian, active.factorization, T)
            reactive.factorization = factorization(reactive.jacobian, reactive.factorization, T)
        end
    end

    solution!(active.increment, active.factorization, active.mismatch)

    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            volt.angle[i] += active.increment[pvpq[i]]
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            reactive.mismatch[pq[i]] =
                -(bus.supply.reactive[i] - bus.demand.reactive[i]) / volt.magnitude[i]
            for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[ptr]
                Gij, Bij, sinθij, cosθij = GijBijθij(ac, volt, i, row, ptr)

                reactive.mismatch[pq[i]] += PiQiSumMinus(volt, Gij, sinθij, Bij, cosθij, row)
            end
        end
    end

    solution!(reactive.increment, reactive.factorization, reactive.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            volt.magnitude[i] += reactive.increment[pq[i]]
        end
    end

    pf.iteration += 1

    return nothing
end

function solve!(analysis::AcPowerFlow{GaussSeidel})
    system = analysis.system
    bus = system.bus
    ac = system.model.ac
    revision = system.model.revision
    gs = analysis.method
    volt = analysis.method.voltage

    if revision.topology != gs.signature.topology || revision.type != gs.signature.type
        errorTypeConversion()
    end

    @inbounds for i in analysis.method.pq
        supply = bus.supply.active[i] - im * bus.supply.reactive[i]
        demand = bus.demand.active[i] - im * bus.demand.reactive[i]
        I = (supply - demand) / conj(volt[i])
        Yii = 0.0 + 0.0im
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[j]
            y = ac.nodalMatrixTranspose.nzval[j]
            I -= y * volt[row]
            if row == i
                Yii = y
            end
        end
        volt[i] += I / Yii

        analysis.voltage.magnitude[i], analysis.voltage.angle[i] = absang(volt[i])
    end

    @inbounds for i in analysis.method.pv
        I = 0.0 + im * 0.0
        Yii = 0.0 + 0.0im
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[j]
            y = ac.nodalMatrixTranspose.nzval[j]
            I += y * volt[row]
            if row == i
                Yii = y
            end
        end
        conjVolt = conj(volt[i])
        injection = bus.supply.active[i] - bus.demand.active[i] + im * imag(conjVolt * I)
        volt[i] += ((injection / conjVolt) - I) / Yii
    end

    @inbounds for i in analysis.method.pv
        idx = bus.supply.generator[i][1]
        volt[i] = system.generator.voltage.magnitude[idx] * volt[i] / abs(volt[i])

        analysis.voltage.magnitude[i], analysis.voltage.angle[i] = absang(volt[i])
    end

    analysis.method.iteration += 1

    return nothing
end

"""
    reactiveLimit!(analysis::AcPowerFlow)

The function verifies whether the generators in a power system exceed their reactive power limits.
This is done by setting the reactive power of the generators to within the limits if they are
violated after determining the bus voltage magnitudes and angles. If the limits are violated, the
corresponding generator buses or the slack bus are converted to demand buses.

# Updates
The function assigns values to the `generator.output.active` and `bus.supply.active` variables of
the `PowerSystem` type.

Additionally, it examines the reactive powers of the generators and adjusts them to their maximum or
minimum values if they exceed the specified threshold. This results in the modification of the
variable `generator.output.reactive` of the `PowerSystem` type accordingly.

As a result of this adjustment, the `bus.supply.reactive` variable is also updated, and the bus types
specified in `bus.layout.type` are modified. If the slack bus is converted, the `bus.layout.slack`
field is correspondingly adjusted.

# Returns
The function returns the variable to indicate which buses violate the limits, with -1 indicating a
violation of the minimum limits and 1 indicating a violation of the maximum limits.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

violate = reactiveLimit!(analysis)

analysis = newtonRaphson(system)
powerFlow!(analysis)
```
"""
function reactiveLimit!(analysis::AcPowerFlow)
    errorVoltage(analysis.voltage.magnitude)

    system = analysis.system
    bus = system.bus
    generator = system.generator

    violate = fill(0, generator.number)

    fill!(bus.supply.active, 0.0)
    fill!(bus.supply.reactive, 0.0)
    outputReactive = fill(0.0, generator.number)
    @inbounds for (label, k) in system.generator.label
        if generator.layout.status[k] == 1
            busIdx = generator.layout.bus[k]
            active, reactive = generatorPower(analysis; label)

            generator.output.active[k] = active
            bus.supply.active[busIdx] += active
            bus.supply.reactive[busIdx] += reactive
            outputReactive[k] = reactive
        end
    end

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 0
            continue
        end

        if generator.capability.minReactive[i] < generator.capability.maxReactive[i]
            j = generator.layout.bus[i]

            violateMin = outputReactive[i] < generator.capability.minReactive[i]
            violateMax = outputReactive[i] > generator.capability.maxReactive[i]
            if  bus.layout.type[j] != 1 && (violateMin || violateMax)
                if violateMin
                    violate[i] = -1
                    newReactivePower = generator.capability.minReactive[i]
                end
                if violateMax
                    violate[i] = 1
                    newReactivePower = generator.capability.maxReactive[i]
                end
                bus.layout.type[j] = 1
                typeChanged!(system)

                bus.supply.reactive[j] -= outputReactive[i]
                generator.output.reactive[i] = newReactivePower
                bus.supply.reactive[j] += newReactivePower

                if j == bus.layout.slack
                    for k = 1:bus.number
                        if bus.layout.type[k] == 2
                            @info(
                                "The slack bus labeled $(getLabel(bus.label, j)) is converted to " *
                                "generator bus. The bus labeled $(getLabel(bus.label, k)) is the " *
                                "new slack bus."
                            )
                            bus.layout.slack = k
                            slackChanged!(system)
                            bus.layout.type[k] = 3
                            typeChanged!(system)
                            break
                        end
                    end
                end
            end
        end
    end

    if bus.layout.type[bus.layout.slack] != 3
        errorSlackDefinition()
    end

    return violate
end

"""
    adjustAngle!(analysis::AcPowerFlow; slack)

The function modifies the bus voltage angles based on a different slack bus than the one identified
by the `bus.layout.slack` field.

For instance, if the reactive power of the generator exceeds the limit on the slack bus, the
[`reactiveLimit!`](@ref reactiveLimit!) function will change that bus to the demand bus and designate
the first generator bus in the sequence as the new slack bus. After obtaining the updated AC power
flow solution based on the new slack bus, the voltage angles can be adjusted to align with
the angle of the original slack bus.

# Keyword
The `slack` keyword specifies the bus label for which we want to adjust voltage angles.

# Updates
This function only updates the `voltage.angle` variable of the `AcPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis)

reactiveLimit!(analysis)

analysis = newtonRaphson(system)
powerFlow!(analysis)

adjustAngle!(analysis; slack = "Bus 1 HV")
```
"""
function adjustAngle!(analysis::AcPowerFlow; slack::IntStrMiss)
    system = analysis.system

    idx = getIndex(system.bus, slack, "bus")
    T = system.bus.voltage.angle[idx] - analysis.voltage.angle[idx]
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + T
    end

    return nothing
end

"""
    setInitialPoint!(analysis::AcPowerFlow)

The function sets the initial point of the AC power flow to the values from the `PowerSystem` type.

# Updates
The function modifies the `voltage` field of the `AcPowerFlow` type.

# Example:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis; tolerance = 1e-10)

updateBranch!(analysis; label = 14, reactance = 0.2, resistance = 0.01)

setInitialPoint!(analysis)
powerFlow!(analysis; tolerance = 1e-10)
```
"""
function setInitialPoint!(analysis::AcPowerFlow)
    system = analysis.system
    bus = system.bus
    volt = analysis.voltage

    errorTransfer(bus.voltage.angle, volt.angle)
    errorTransfer(bus.voltage.magnitude, volt.magnitude)

    @inbounds for i = 1:bus.number
        if haskey(bus.supply.generator, i) && bus.layout.type[i] != 1
            volt.magnitude[i] = system.generator.voltage.magnitude[bus.supply.generator[i][1]]
        else
            volt.magnitude[i] = bus.voltage.magnitude[i]
        end

        volt.angle[i] = bus.voltage.angle[i]

        if isdefined(analysis.method, :voltage)
            analysis.method.voltage[i] = volt.magnitude[i] * cis(volt.angle[i])
        end
    end

    return nothing
end

"""
    setInitialPoint!(target::AcPowerFlow, source::Analysis)

The function initializes the AC power flow based on results from the `Analysis` type, whether
from an AC or DC analysis.

The function assigns the bus voltage magnitudes and angles in the `target` argument, using data from
the `source` argument. This allows users to initialize AC power flow as needed.

If `source` comes from a DC analysis, only the bus voltage angles are assigned in the `target`
argument, while the bus voltage magnitudes remain unchanged.

# Updates
The function modifies the `voltage` field of the `AcPowerFlow` type.

# Example
Initialize the Newton-Raphson method with values from the Gauss-Seidel method:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

source = gaussSeidel(system)
powerFlow!(source; iteration = 10)

target = newtonRaphson(system)

setInitialPoint!(target, source)
powerFlow!(target; tolerance = 1e-10)
```
"""
function setInitialPoint!(target::AcPowerFlow, source::AC)
    errorTransfer(source.voltage.magnitude, target.voltage.magnitude)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.magnitude)
        target.voltage.magnitude[i] = source.voltage.magnitude[i]
        target.voltage.angle[i] = source.voltage.angle[i]

        if isdefined(target.method, :voltage)
            target.method.voltage[i] = target.voltage.magnitude[i] * cis(target.voltage.angle[i])
        end
    end

    return nothing
end

function setInitialPoint!(target::AcPowerFlow, source::DC)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.angle)
        target.voltage.angle[i] = source.voltage.angle[i]

        if isdefined(target.method, :voltage)
            target.method.voltage[i] = target.voltage.magnitude[i] * cis(target.voltage.angle[i])
        end
    end

    return nothing
end

##### Initialize Voltages for AC Power Flow #####
function initializeACPowerFlow(system::PowerSystem)
    bus = system.bus

    magnitude = copy(bus.voltage.magnitude)
    angle = copy(bus.voltage.angle)

    @inbounds for i = 1:bus.number
        if !haskey(bus.supply.generator, i) && bus.layout.type[i] == 2
            bus.layout.type[i] = 1
            typeChanged!(system)
        end
        if haskey(bus.supply.generator, i) && bus.layout.type[i] != 1
            magnitude[i] = system.generator.voltage.magnitude[bus.supply.generator[i][1]]
        end
    end

    changeSlackBus!(system)

    return magnitude, angle
end

##### Change Slack Bus #####
function changeSlackBus!(system::PowerSystem)
    if !haskey(system.bus.supply.generator, system.bus.layout.slack)
        system.bus.layout.type[system.bus.layout.slack] = 1
        typeChanged!(system)
        @inbounds for i = 1:system.bus.number
            if system.bus.layout.type[i] == 2 && haskey(system.bus.supply.generator, i)
                system.bus.layout.type[i] = 3
                typeChanged!(system)
                system.bus.layout.slack = i
                slackChanged!(system)

                @info(
                    "No in-service generator found at the slack bus. " *
                    "The bus labeled $(getLabel(system.bus.label, i)) is the new slack bus."
                )

                break
            end
        end

        if system.bus.layout.type[system.bus.layout.slack] == 1
            errorSlackDefinition()
        end
    end
end

"""
    powerFlow!(analysis::AcPowerFlow; iteration, tolerance, power, current, verbose)

The function serves as a wrapper for solving AC power flow and includes the functions:
* [`mismatch!`](@ref mismatch!(::AcPowerFlow{<:NewtonRaphson})),
* [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson{T}}) where T),
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

It computes bus voltage magnitudes and angles using an iterative algorithm with the option to compute
powers and currents.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations (default: `20`).
* `tolerance`: Defines the mismatch tolerance for the iteration stopping criterion (default: `1e-8`).
* `power`: Enables power computation upon convergence or reaching the iteration limit (default: `false`).
* `current`: Enables current computation upon convergence or reaching the iteration limit (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true, iteration = 30, tolerance = 1e-10, verbose = 3)
```
"""
function powerFlow!(
    analysis::AcPowerFlow;
    iteration::Int64 = 20,
    tolerance::Float64 = 1e-8,
    power::Bool = false,
    current::Bool = false,
    verbose::Int64 = template.config.verbose
)
    system = analysis.system

    converged = false
    maxExceeded = false
    analysis.method.iteration = 0

    printTop(system, analysis, verbose)
    printMiddle(analysis, verbose)

    for iter = 0:iteration
        delP, delQ = mismatch!(analysis)

        printSolver(analysis, delP, delQ, verbose)
        if delP < tolerance && delQ < tolerance
            converged = true
            break
        end
        if analysis.method.iteration == iteration
            maxExceeded = true
            break
        end

        solve!(analysis)
    end

    printSolver(system, analysis, verbose)
    printExit(analysis, maxExceeded, converged, verbose)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end

    return nothing
end