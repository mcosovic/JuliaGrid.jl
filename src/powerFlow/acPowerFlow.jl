"""
    newtonRaphson(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the Newton-Raphson method to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Utilizes LU factorization (default).
- `QR`: Utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the Newton-Raphson method utilizing LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
```

Set up the Newton-Raphson method utilizing QR factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system, QR)
```
"""
function newtonRaphson(system::PowerSystem, factorization::Type{<:Union{QR, LU}} = LU)
    ac = system.model.ac
    bus = system.bus

    checkSlackBus(system)
    model!(system, ac)
    voltMagnitude, voltAngle = initializeACPowerFlow(system)

    pq = fill(0, bus.number)
    pvpq = fill(0, bus.number)
    nnzJcb = 0
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

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[j]]
            if bus.layout.type[i] != 3 && typeRow != 3
                nnzJcb += 1
            end
            if bus.layout.type[i] == 1 && typeRow != 3
                nnzJcb += 2
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                nnzJcb += 1
            end
        end
    end

    cnt = 1
    iIdx = fill(0, nnzJcb)
    jIdx = similar(iIdx)
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    iIdx[cnt] = pvpq[row]
                    jIdx[cnt] = pvpq[i]
                    cnt += 1
                end
                if typeRow == 1
                    iIdx[cnt] = pq[row]
                    jIdx[cnt] = pvpq[i]
                    cnt += 1
                end
                if bus.layout.type[i] == 1 && typeRow != 3
                    iIdx[cnt] = pvpq[row]
                    jIdx[cnt] = pq[i]
                    cnt += 1
                end
                if bus.layout.type[i] == 1 && typeRow == 1
                    iIdx[cnt] = pq[row]
                    jIdx[cnt] = pq[i]
                    cnt += 1
                end
            end
        end
    end
    dimJcb = bus.number + pqNum - 1

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
        NewtonRaphson(
            sparse(iIdx, jIdx, fill(0.0, nnzJcb), dimJcb, dimJcb),
            fill(0.0, dimJcb),
            fill(0.0, dimJcb),
            factorized[factorization],
            pq,
            pvpq,
            Dict(:pattern => -1, :type => 0),
            0
        ),
        system
    )
end

"""
    fastNewtonRaphsonBX(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the fast Newton-Raphson method of version BX to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Utilizes LU factorization (default).
- `QR`: Utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the fast Newton-Raphson method utilizing LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonBX(system)
```

Set up the fast Newton-Raphson method utilizing QR factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonBX(system, QR)
```
"""
function fastNewtonRaphsonBX(system::PowerSystem, factorization::Type{<:Union{QR, LU}} = LU)
    fastNewtonRaphsonModel(system, factorization, true)
end

"""
    fastNewtonRaphsonXB(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the fast Newton-Raphson method of version XB to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `Factorization`
argument, while optional, determines the method used to solve the linear system of equations within
each iteration. It can take one of the following values:
- `LU`: Utilizes LU factorization (default).
- `QR`: Utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type. It also performs a check on bus types and rectifies any mistakes
present.

# Returns
The function returns an instance of the [`AcPowerFlow`](@ref AcPowerFlow) type.

# Examples
Set up the fast Newton-Raphson method utilizing LU factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonXB(system)
```

Set up the fast Newton-Raphson method utilizing QR factorization:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonXB(system, QR)
```
"""
function fastNewtonRaphsonXB(system::PowerSystem, factorization::Type{<:Union{QR, LU}} = LU)
    fastNewtonRaphsonModel(system, factorization, false)
end

function fastNewtonRaphsonModel(
    system::PowerSystem,
    factorization::Type{<:Union{QR, LU}},
    bx::Bool
)
    bus = system.bus
    branch = system.branch
    ac = system.model.ac

    checkSlackBus(system)
    model!(system, ac)
    voltMagnitude, voltAngle = initializeACPowerFlow(system)

    pq = fill(0, bus.number)
    pvpq = fill(0, bus.number)
    nnzP = 0
    nnzQ = 0
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

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[j]]
            if bus.layout.type[i] != 3 && typeRow != 3
                nnzP += 1
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                nnzQ += 1
            end
        end
    end

    cntP = 1
    cntQ = 1
    iIdxP = fill(0, nnzP)
    jIdxP = similar(iIdxP)
    iIdxQ = fill(0, nnzQ)
    jIdxQ = similar(iIdxQ)
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    iIdxP[cntP] = pvpq[row]
                    jIdxP[cntP] = pvpq[i]
                    cntP += 1
                end
                if bus.layout.type[i] == 1 && typeRow == 1
                    iIdxQ[cntQ] = pq[row]
                    jIdxQ[cntQ] = pq[i]
                    cntQ += 1
                end
            end
        end
    end

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
        FastNewtonRaphson(
            FastNewtonRaphsonModel(
                sparse(iIdxP, jIdxP, zeros(nnzP), bus.number - 1, bus.number - 1),
                fill(0.0, bus.number - 1),
                fill(0.0, bus.number - 1),
                factorized[factorization],
            ),
            FastNewtonRaphsonModel(
                sparse(iIdxQ, jIdxQ, zeros(nnzQ), pqNum, pqNum),
                fill(0.0, pqNum),
                fill(0.0, pqNum),
                factorized[factorization],
            ),
            pq,
            pvpq,
            Dict(
                :acmodel => -1,
                :pattern => -1,
                :type => 0,
                :susceptance => Dict{Int64, Float64}()
            ),
            bx,
            0
        ),
        system
    )

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            jacobian(system, analysis, i)
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1 && bus.shunt.susceptance[i] != 0
            j = analysis.method.pq[i]
            analysis.method.reactive.jacobian[j, j] += bus.shunt.susceptance[i]
            analysis.method.signature[:susceptance][i] = bus.shunt.susceptance[i]
        end
    end

    return analysis
end

function jacobian(system::PowerSystem, analysis::AcPowerFlow{FastNewtonRaphson}, idx::Int64)
    i, j = fromto(system, idx)
    p, q = jacobianCoefficient(system, analysis.method, idx)

    Pijθij(system, analysis.method, p, i, j)
    Pijθi(system, analysis.method, p, i)
    Pijθj(system, analysis.method, p, j)

    QijVij(analysis.method, q, i, j)
    QijVi(system, analysis.method, q, i)
    QijVj(system, analysis.method, q, j)
end

function jacobianCoefficient(system::PowerSystem, method::FastNewtonRaphson, idx::Int64)
    bsi = 0.5 * system.branch.parameter.susceptance[idx]
    τinv = 1 / system.branch.parameter.turnsRatio[idx]

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
        C = sin(system.branch.parameter.shiftAngle[idx]),
        D = cos(system.branch.parameter.shiftAngle[idx])
    ),
    PiModel(
        A = - bmk * τinv,
        B = (bmk + bsi) * τinv^2,
        C = (bmk + bsi)
    )
end

function Pijθij(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, i::Int64, j::Int64)
    m = mth.pvpq[i]
    n = mth.pvpq[j]

    if i != system.bus.layout.slack && j != system.bus.layout.slack
        mth.active.jacobian[m, n] += (-p.A * p.C - p.B * p.D) / (p.D^2 + p.C^2)
        mth.active.jacobian[n, m] += (p.A * p.C - p.B * p.D) / (p.D^2 + p.C^2)
    end
end

function Pijθi(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, i::Int64)
    if i != system.bus.layout.slack
        mth.active.jacobian[mth.pvpq[i], mth.pvpq[i]] += p.B / (p.D^2 + p.C^2)
    end
end

function Pijθj(system::PowerSystem, mth::FastNewtonRaphson, p::PiModel, j::Int64)
    if j != system.bus.layout.slack
        mth.active.jacobian[mth.pvpq[j], mth.pvpq[j]] += p.B
    end
end

function QijVij(mth::FastNewtonRaphson, q::PiModel, i::Int64, j::Int64)
    m = mth.pq[i]
    n = mth.pq[j]

    if m != 0 && n != 0
        mth.reactive.jacobian[m, n] += q.A
        mth.reactive.jacobian[n, m] += q.A
    end
end

function QijVi(system::PowerSystem, mth::FastNewtonRaphson, q::PiModel, i::Int64)
    if system.bus.layout.type[i] == 1
        mth.reactive.jacobian[mth.pq[i], mth.pq[i]] += q.B
    end
end

function QijVj(system::PowerSystem, mth::FastNewtonRaphson, q::PiModel, j::Int64)
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
            Dict(:type => 0),
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
It should be employed during the iteration loop before invoking the
[`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson})) function.

# Returns
The function returns maximum absolute values of the active and reactive power injection mismatches,
which can be utilized to terminate the iteration loop of the Newton-Raphson, fast Newton-Raphson, or
Gauss-Seidel methods employed to solve the AC power flow problem.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
mismatch!(analysis)
```
"""
function mismatch!(analysis::AcPowerFlow{NewtonRaphson})
    system = analysis.system
    ac = system.model.ac
    bus = system.bus
    voltg = analysis.voltage
    mism = analysis.method.mismatch
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    stopP = 0.0
    stopQ = 0.0
    I = [0.0; 0.0]
    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        k = pvpq[i]
        q = pq[i]
        fill!(I, 0.0)
        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltg, i, row, ptr)

            PiQiSum(voltg, Gij, cosθij, Bij, sinθij, I, row, +, 1)
            if bus.layout.type[i] == 1
                PiQiSum(voltg, Gij, sinθij, Bij, cosθij, I, row, -, 2)
            end
        end

        mism[k] = Pi(voltg, I[1], i) - bus.supply.active[i] + bus.demand.active[i]
        stopP = max(stopP, abs(mism[k]))
        if bus.layout.type[i] == 1
            mism[q] = Qi(voltg, I[2], i) - bus.supply.reactive[i] + bus.demand.reactive[i]
            stopQ = max(stopQ, abs(mism[q]))
        end
    end

    return stopP, stopQ
end

function mismatch!(analysis::AcPowerFlow{FastNewtonRaphson})
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
    I = [0.0; 0.0]
    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        k = pvpq[i]
        q = pq[i]
        fill!(I, 0.0)
        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[ptr]
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, volt, i, row, ptr)

            PiQiSum(volt, Gij, cosθij, Bij, sinθij, I, row, +, 1)
            if bus.layout.type[i] == 1
                PiQiSum(volt, Gij, sinθij, Bij, cosθij, I, row, -, 2)
            end
        end

        Vinv = 1 / volt.magnitude[i]
        mismP[k] = I[1] - (bus.supply.active[i] - bus.demand.active[i]) * Vinv
        stopP = max(stopP, abs(mismP[k]))
        if bus.layout.type[i] == 1
            mismQ[q] = I[2] - (bus.supply.reactive[i] - bus.demand.reactive[i]) * Vinv
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

The function employs the Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method to solve the AC
power flow and calculate bus voltage magnitudes and angles.

After the [`mismatch!`](@ref mismatch!) function is executed, the execution of this function will
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
function solve!(analysis::AcPowerFlow{NewtonRaphson})
    system = analysis.system
    ac = system.model.ac
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage
    jcb = pf.jacobian
    pq = pf.pq
    pvpq = pf.pvpq

    I = [0.0; 0.0]
    @inbounds for i = 1:bus.number
        if i == bus.layout.slack
            continue
        end

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[j]
            type = bus.layout.type[row]

            if type == 3
                continue
            end

            fill!(I, 0.0)
            Gij, Bij = reim(ac.nodalMatrix.nzval[j])
            if row != i
                sinθij, cosθij = sincos(volt.angle[row] - volt.angle[i])

                jcb[pvpq[row], pvpq[i]] = Piθj(volt, Gij, Bij, sinθij, cosθij, row, i)
                if type == 1
                    jcb[pq[row], pvpq[i]] = Qiθj(volt, Gij, Bij, sinθij, cosθij, row, i)
                end
                if bus.layout.type[i] == 1
                    jcb[pvpq[row], pq[i]] = PiVj(volt, Gij, Bij, sinθij, cosθij, row)
                end
                if bus.layout.type[i] == 1 && type == 1
                    jcb[pq[row], pq[i]] = QiVj(volt, Gij, Bij, sinθij, cosθij, row)
                end
            else
                for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                    q = ac.nodalMatrix.rowval[ptr]
                    Gik, Bik, sinθik, cosθik = GijBijθij(ac, volt, row, q, ptr)

                    PiQiSum(volt, Gik, sinθik, Bik, cosθik, I, q, -, 1)
                    if bus.layout.type[i] == 1 || type == 1
                        PiQiSum(volt, Gik, cosθik, Bik, sinθik, I, q, +, 2)
                    end
                end

                jcb[pvpq[row], pvpq[i]] = Piθi(volt, Bij, -I[1], row)
                if type == 1
                    jcb[pq[row], pvpq[i]] = Qiθi(volt, Gij, I[2], row)
                end
                if bus.layout.type[i] == 1
                    jcb[pvpq[row], pq[i]] = PiVi(volt, Gij, I[2], row)
                end
                if bus.layout.type[i] == 1 && type == 1
                    jcb[pq[row], pq[i]] = QiVi(volt, Bij, I[1], row)
                end
            end
        end
    end

    if ac.pattern == pf.signature[:pattern]
        pf.factorization = factorization!(jcb, pf.factorization)
    else
        pf.signature[:pattern] = copy(system.model.ac.pattern)
        pf.factorization = factorization(jcb, pf.factorization)
    end

    pf.increment = solution(pf.increment, pf.mismatch, pf.factorization)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            volt.magnitude[i] = volt.magnitude[i] - pf.increment[pq[i]]
        end
        if i != bus.layout.slack
            volt.angle[i] = volt.angle[i] - pf.increment[pvpq[i]]
        end
    end

    pf.iteration += 1
end

function solve!(analysis::AcPowerFlow{FastNewtonRaphson})
    system = analysis.system
    ac = system.model.ac
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage
    active = pf.active
    reactive = pf.reactive
    pq = pf.pq
    pvpq = pf.pvpq

    if ac.model != pf.signature[:acmodel]
        pf.signature[:acmodel] = copy(ac.model)

        if ac.pattern == pf.signature[:pattern]
            active.factorization = factorization!(active.jacobian, active.factorization)
            reactive.factorization = factorization!(reactive.jacobian, reactive.factorization)
        else
            pf.signature[:pattern] = copy(ac.pattern)

            active.factorization = factorization(active.jacobian, active.factorization)
            reactive.factorization = factorization(reactive.jacobian, reactive.factorization)
        end
    end

   active.increment = solution(active.increment, active.mismatch, active.factorization)

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

                reactive.mismatch[pq[i]] += volt.magnitude[row] * (Gij * sinθij - Bij * cosθij)
            end
        end
    end

    reactive.increment = solution(reactive.increment, reactive.mismatch, reactive.factorization)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            volt.magnitude[i] += reactive.increment[pq[i]]
        end
    end

    pf.iteration += 1
end

function solve!(analysis::AcPowerFlow{GaussSeidel})
    system = analysis.system
    bus = system.bus
    ac = system.model.ac
    volt = analysis.method.voltage

    @inbounds for i in analysis.method.pq
        supply = bus.supply.active[i] - im * bus.supply.reactive[i]
        demand = bus.demand.active[i] - im * bus.demand.reactive[i]
        I = (supply - demand) / conj(volt[i])
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I -= ac.nodalMatrixTranspose.nzval[j] * volt[ac.nodalMatrix.rowval[j]]
        end
        volt[i] += I / ac.nodalMatrix[i, i]

        analysis.voltage.magnitude[i], analysis.voltage.angle[i] = absang(volt[i])
    end

    @inbounds for i in analysis.method.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * volt[ac.nodalMatrix.rowval[j]]
        end
        conjVolt = conj(volt[i])
        injection = bus.supply.active[i] - bus.demand.active[i] + im * imag(conjVolt * I)
        volt[i] += ((injection / conjVolt) - I) / ac.nodalMatrix[i, i]
    end

    @inbounds for i in analysis.method.pv
        idx = bus.supply.generator[i][1]
        volt[i] = system.generator.voltage.magnitude[idx] * volt[i] / abs(volt[i])

        analysis.voltage.magnitude[i], analysis.voltage.angle[i] = absang(volt[i])
    end

    analysis.method.iteration += 1
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
                            bus.layout.type[k] = 3
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
flow solution based on the new slack bus, it is possible to adjust the voltage angles to align with
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

adjustAngle!(analysis; slack = 1)
```
"""
function adjustAngle!(analysis::AcPowerFlow; slack::IntStrMiss)
    system = analysis.system

    idx = getIndex(system.bus, slack, "bus")
    T = system.bus.voltage.angle[idx] - analysis.voltage.angle[idx]
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + T
    end
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
end

function setInitialPoint!(target::AcPowerFlow, source::DC)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.angle)
        target.voltage.angle[i] = source.voltage.angle[i]

        if isdefined(target.method, :voltage)
            target.method.voltage[i] = target.voltage.magnitude[i] * cis(target.voltage.angle[i])
        end
    end
end

##### Initialize Voltages for AC Power Flow #####
function initializeACPowerFlow(system::PowerSystem)
    bus = system.bus

    magnitude = copy(bus.voltage.magnitude)
    angle = copy(bus.voltage.angle)

    @inbounds for i = 1:bus.number
        if !haskey(bus.supply.generator, i) && bus.layout.type[i] == 2
            bus.layout.type[i] = 1
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
        @inbounds for i = 1:system.bus.number
            if system.bus.layout.type[i] == 2 && haskey(system.bus.supply.generator, i)
                system.bus.layout.type[i] = 3
                system.bus.layout.slack = i

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
* [`mismatch!`](@ref mismatch!(::AcPowerFlow{NewtonRaphson})),
* [`solve!`](@ref solve!(::AcPowerFlow{NewtonRaphson})),
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

It computes bus voltage magnitudes and angles using an iterative algorithm with the option to compute
powers and currents.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations (default: `20`).
* `tolerance`: Defines the step size tolerance for the iteration stopping criterion (default: `1e-8`).
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
end