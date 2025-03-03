"""
    newtonRaphson(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the Newton-Raphson method to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `Factorization` argument, while optional, determines the method used to solve the
linear system of equations within each iteration. It can take one of the following values:
- `LU`: utilizes LU factorization (default),
- `QR`: utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within
the `ac` field of the `PowerSystem` type. It also performs a check on bus types and
rectifies any mistakes present.

# Returns
The function returns an instance of the `ACPowerFlow` type, which includes the following
fields:
- `voltage`: The bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `current`: The variable allocated to store the currents.
- `method`: The Jacobian matrix, its factorization, mismatches, increments, and indices.

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
    pvpq = similar(pq)
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

    ACPowerFlow(
        Polar(
            voltMagnitude,
            voltAngle
        ),
        ACPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        ACCurrent(
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
            -1
        )
    )
end

"""
    fastNewtonRaphsonBX(system::PowerSystem, [factorization::Factorization = LU])

The function sets up the fast Newton-Raphson method of version BX to solve the AC power
flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `Factorization` argument, while optional, determines the method used to solve the
linear system of equations within each iteration. It can take one of the following values:
- `LU`: utilizes LU factorization (default),
- `QR`: utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within
the `ac` field of the `PowerSystem` type. It also performs a check on bus types and
rectifies any mistakes present.

# Returns
The function returns an instance of the `ACPowerFlow` type, which includes the following
fields:
- `voltage`: The bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `current`: The variable allocated to store the currents.
- `method`: The Jacobian matrices, their factorizations, mismatches, increments, and indices.

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

The function sets up the fast Newton-Raphson method of version XB to solve the AC power
flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `Factorization` argument, while optional, determines the method used to solve the
linear system of equations within each iteration. It can take one of the following values:
- `LU`: utilizes LU factorization (default),
- `QR`: utilizes QR factorization.

# Updates
If the AC model has not been created, the function automatically initiates an update within
the `ac` field of the `PowerSystem` type. It also performs a check on bus types and
rectifies any mistakes present.

# Returns
The function returns an instance of the `ACPowerFlow` type, which includes the following
fields:
- `voltage`: The bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `current`: The variable allocated to store the currents.
- `method`: The Jacobian matrices, their factorizations, mismatches, increments, and indices.

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

@inline function fastNewtonRaphsonModel(
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
    pvpq = similar(pq)
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

    analysis = ACPowerFlow(
        Polar(
            voltMagnitude,
            voltAngle
        ),
        ACPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        ACCurrent(
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
            -1,
            -1,
            bx
        )
    )

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            fastNewtonRaphsonJacobian(system, analysis, i, 1)
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            j = analysis.method.pq[i]
            analysis.method.reactive.jacobian[j, j] += bus.shunt.susceptance[i]
        end
    end

    return analysis
end

@inline function fastNewtonRaphsonJacobian(
    system::PowerSystem,
    analysis::ACPowerFlow{FastNewtonRaphson},
    idx::Int64,
    sign::Int64
)
    jcbP = analysis.method.active.jacobian
    jcbQ = analysis.method.reactive.jacobian

    i, j = fromto(system, idx)

    sinΦ, cosΦ = sincos(system.branch.parameter.shiftAngle[idx])
    rij = system.branch.parameter.resistance[idx]
    xij = system.branch.parameter.reactance[idx]
    gsi = 0.5 * system.branch.parameter.susceptance[idx]
    τinv = 1 / system.branch.parameter.turnsRatio[idx]

    m = analysis.method.pvpq[i]
    n = analysis.method.pvpq[j]

    if analysis.method.bx
        gmk = rij / (rij^2 + xij^2)
        bmk = -xij / (rij^2 + xij^2)
    else
        gmk = 0.0
        bmk = -1 / xij
    end
    if i != system.bus.layout.slack && j != system.bus.layout.slack
        jcbP[m, n] += sign * (-gmk * sinΦ - bmk * cosΦ) / (cosΦ^2 + sinΦ^2)
        jcbP[n, m] += sign * (gmk * sinΦ - bmk * cosΦ) / (cosΦ^2 + sinΦ^2)
    end
    if i != system.bus.layout.slack
        jcbP[m, m] += sign * bmk / (cosΦ^2 + sinΦ^2)
    end
    if j != system.bus.layout.slack
        jcbP[n, n] += sign * bmk
    end

    m = analysis.method.pq[i]
    n = analysis.method.pq[j]

    if analysis.method.bx
        bmk = - 1 / xij
    else
        bmk = -xij / (rij^2 + xij^2)
    end
    if m != 0 && n != 0
        jcbQ[m, n] += sign * (-bmk * τinv)
        jcbQ[n, m] += sign * (-bmk * τinv)
    end
    if system.bus.layout.type[i] == 1
        jcbQ[m, m] += sign * (bmk + gsi) * τinv^2
    end
    if system.bus.layout.type[j] == 1
        jcbQ[n, n] += sign * (bmk + gsi)
    end
end

"""
    gaussSeidel(system::PowerSystem)

The function sets up the Gauss-Seidel method to solve the AC power flow.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework.

# Updates
If the AC model has not been created, the function automatically initiates an update within
the `ac` field of the `PowerSystem` type. It also performs a check on bus types and
rectifies any mistakes present.

# Returns
The function returns an instance of the `ACPowerFlow` type, which includes the following
fields:
- `voltage`: The bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `current`: The variable allocated to store the currents.
- `method`: The bus complex voltages and indices.

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

    ACPowerFlow(
        Polar(
            voltgMagnitude,
            voltgAngle
        ),
        ACPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        ACCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        GaussSeidel(
            voltg,
            pq,
            pv
        )
    )
end

"""
    mismatch!(system::PowerSystem, analysis::ACPowerFlow)

The function calculates both active and reactive power injection mismatches.

# Updates
This function updates the mismatch variables in the Newton-Raphson and fast Newton-Raphson
methods. It should be employed during the iteration loop before invoking the
[`solve!`](@ref solve!(::PowerSystem, ::ACPowerFlow{NewtonRaphson})) function.

# Returns
The function returns maximum absolute values of the active and reactive power injection
mismatches, which can be utilized to terminate the iteration loop of the Newton-Raphson,
fast Newton-Raphson, or Gauss-Seidel methods employed to solve the AC power flow problem.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
mismatch!(system, analysis)
```
"""
function mismatch!(system::PowerSystem, analysis::ACPowerFlow{NewtonRaphson})
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
        I = [0.0; 0.0]
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

function mismatch!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
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
        I = [0.0; 0.0]
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

function mismatch!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
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
    solve!(system::PowerSystem, analysis::ACPowerFlow)

The function employs the Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method to
solve the AC power flow model and calculate bus voltage magnitudes and angles.

After the [`mismatch!`](@ref mismatch!) function is called, this function should be
executed to perform a single iteration of the method.

# Updates
The calculated voltages are stored in the `voltage` field of the `ACPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```
"""
function solve!(system::PowerSystem, analysis::ACPowerFlow{NewtonRaphson})
    ac = system.model.ac
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage
    jcb = pf.jacobian
    pq = pf.pq
    pvpq = pf.pvpq

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

            I = [0.0; 0.0]
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

    if ac.pattern != pf.pattern
        pf.pattern = copy(system.model.ac.pattern)
        pf.factorization = factorization(jcb, pf.factorization)
    else
        pf.factorization = factorization!(jcb, pf.factorization)
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
end

function solve!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
    ac = system.model.ac
    bus = system.bus

    pf = analysis.method
    volt = analysis.voltage
    active = pf.active
    reactive = pf.reactive
    pq = pf.pq
    pvpq = pf.pvpq

    if ac.model != pf.acmodel
        pf.acmodel = copy(ac.model)
        if ac.pattern != pf.pattern
            pf.pattern = copy(ac.pattern)
            active.factorization = factorization(active.jacobian, active.factorization)
            reactive.factorization = factorization(reactive.jacobian, reactive.factorization)
        else
            active.factorization = factorization!(active.jacobian, active.factorization)
            reactive.factorization = factorization!(reactive.jacobian, reactive.factorization)
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
end

function solve!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
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
end

"""
    reactiveLimit!(system::PowerSystem, analysis::ACPowerFlow)

The function verifies whether the generators in a power system exceed their reactive power
limits. This is done by setting the reactive power of the generators to within the limits
if they are violated after determining the bus voltage magnitudes and angles. If the
limits are violated, the corresponding generator buses or the slack bus are converted to
demand buses.

# Updates
The function assigns values to the `generator.output.active` and `bus.supply.active`
variables of the `PowerSystem` type.

Additionally, it examines the reactive powers of the generators and adjusts them to their
maximum or minimum values if they exceed the specified threshold. This results in the
modification of the variable `generator.output.reactive` of the `PowerSystem` type
accordingly.

As a result of this adjustment, the `bus.supply.reactive` variable is also updated, and
the bus types specified in `bus.layout.type` are modified. If the slack bus is converted,
the `bus.layout.slack` field is correspondingly adjusted.

# Returns
The function returns the variable to indicate which buses violate the limits, with -1
indicating a violation of the minimum limits and 1 indicating a violation of the maximum
limits.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

violate = reactiveLimit!(system, analysis)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```
"""
function reactiveLimit!(system::PowerSystem, analysis::ACPowerFlow)
    errorVoltage(analysis.voltage.magnitude)

    bus = system.bus
    generator = system.generator

    violate = fill(0, generator.number)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    outputReactive = fill(0.0, generator.number)
    labels = collect(keys(system.generator.label))
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        if generator.layout.status[k] == 1
            active, reactive = generatorPower(system, analysis; label = labels[k])

            generator.output.active[k] = active
            bus.supply.active[i] += active
            bus.supply.reactive[i] += reactive
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
                            old = iterate(system.bus.label, j)[1][1]
                            new = iterate(system.bus.label, k)[1][1]
                            @info(
                                "The slack bus labeled $old is converted to " *
                                "generator bus. The bus labeled $new is the " *
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
    adjustAngle!(system::PowerSystem, analysis::ACPowerFlow; slack)

The function modifies the bus voltage angles based on a different slack bus than the one
identified by the `bus.layout.slack` field.

For instance, if the reactive power of the generator exceeds the limit on the slack bus,
the [`reactiveLimit!`](@ref reactiveLimit!) function will change that bus to the demand
bus and designate the first generator bus in the sequence as the new slack bus. After
obtaining the updated AC power flow solution based on the new slack bus, it is possible to
adjust the voltage angles to align with the angle of the original slack bus.

# Keyword
The `slack` keyword specifies the bus label for which we want to adjust voltage angles.

# Updates
This function only updates the `voltage.angle` variable of the `ACPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

reactiveLimit!(system, analysis)

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end

adjustAngle!(system, analysis; slack = 1)
```
"""
function adjustAngle!(system::PowerSystem, analysis::ACPowerFlow; slack::IntStrMiss)
    idx = system.bus.label[getLabel(system.bus, slack, "bus")]
    T = system.bus.voltage.angle[idx] - analysis.voltage.angle[idx]
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + T
    end
end

"""
    setInitialPoint!(source::Union{PowerSystem, Analysis}, target::ACPowerFlow)

The function can reset the initial point of the AC power flow to values from the
`PowerSystem` type. It can also initialize the AC power flow based on results from the
`Analysis` type, whether from an AC or DC analysis.

The function assigns the bus voltage magnitudes and angles in the `target` argument,
using data from the `source` argument. This allows users to initialize AC power flow as
needed.

If `source` comes from a DC analysis, only the bus voltage angles are assigned in the
`target` argument, while the bus voltage magnitudes remain unchanged.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

gs = gaussSeidel(system)
for i = 1:10
    solve!(system, gs)
end

nr = newtonRaphson(system)

setInitialPoint!(gs, nr)
for i = 1:10
    stopping = mismatch!(system, nr)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, nr)
end
```
"""
function setInitialPoint!(system::PowerSystem, analysis::ACPowerFlow)
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

function setInitialPoint!(source::AC, target::ACPowerFlow)
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

function setInitialPoint!(source::DC, target::ACPowerFlow)
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

                slack = iterate(system.bus.label, i)[1][1]
                @info(
                    "The bus labeled $slack is the new slack bus since no " *
                    "in-service generator was available at the previous slack bus."
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
    acPowerFlow!(system::PowerSystem, analysis::ACPowerFlow;
        maxIteration, stopping, power, current, print, exit)

The function serves as a wrapper for solving AC power flow. It calculates bus voltage
magnitudes and angles, with the option to compute powers and currents.

# Keywords
Users can use the following keywords:
* `maxIteration`: Specifies the maximum number of iteration (default: `20`).
* `stopping`: Defines the stopping criterion for the iterative algorithm (default: `1e-8`).
* `power`: Enables power computation upon convergence or reaching the iteration limit (default: `true`).
* `current`: Enables current computation upon convergence or reaching the iteration limit (default: `false`).
* `print`: Controls solver output display (default: `true`).
* `exit`: Prints only exit information about algorithm convergence (default: `false`).

# Updates
The calculated voltages are stored in the `voltage` field of the `ACPowerFlow` type, with
optional storage in the `power` and `current` fields.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
acPowerFlow!(system, analysis; stopping = 1e-10, current = true)
```
"""
function acPowerFlow!(
    system::PowerSystem,
    analysis::ACPowerFlow;
    maxIteration::Int64 = 20,
    stopping::Float64 = 1e-8,
    power::Bool = true,
    current::Bool = true,
    print::Bool = true,
    exit::Bool = false,
)
    converged = false

    if exit
        print = false
    end

    iter = 0
    printPowerFlowData(system, analysis, print)
    for iteration = 0:maxIteration
        delP, delQ = mismatch!(system, analysis)

        printPowerFlowIteration(iteration, delP, delQ, print)
        if delP < stopping && delQ < stopping
            iter = iteration
            converged = true
            break
        end

        solve!(system, analysis)
    end

    printPowerFlowExit(system, analysis, iter, converged, print, exit)

    if power
        power!(system, analysis)
    end
    if current
        current!(system, analysis)
    end
end

function printPowerFlowData(system::PowerSystem, analysis::ACPowerFlow, printpf::Bool)
    if printpf
        elements = nnz(analysis.method.jacobian)
        width = textwidth(string(elements)) + 2

        print("Number of buses:")
        print(format(Format("%*i\n"), width + 19, system.bus.number))

        print("Number of branches:")
        print(format(Format("%*i\n"), width + 16, system.branch.number))
        print("Number of in-service branches:")
        print(format(Format("%*i\n"), width + 5, system.branch.layout.inservice))

        print("Number of generators:")
        print(format(Format("%*i\n"), width + 14, system.generator.number))
        print("Number of in-service generators:")
        print(format(Format("%*i\n"), width + 3, system.generator.layout.inservice))

        print("Number of state variables:")
        print(format(Format("%*i\n"), width + 9, lastindex(analysis.method.increment)))

        print("Number of nonzeros in the Jacobian:")
        print(format(Format("%*i\n\n"), width, elements))
    end
end

function printPowerFlowIteration(iter::Int64, delP::Float64, delQ::Float64, printpf::Bool)
    if printpf
        if iter % 10 == 0
            println("Iteration  Active Mismatch  Reactive Mismatch")
        end
        print(format(Format("%*i "), 9, iter))
        print(format(Format("%*.4e"), 16, delP))
        print(format(Format("%*.4e \n"), 19, delQ))
    end
end

function printPowerFlowExit(
    system::PowerSystem,
    analysis::ACPowerFlow{NewtonRaphson},
    iter::Int64,
    converged::Bool,
    printpf::Bool,
    exitpf::Bool
)
    if printpf
        minDelθ = extrema(analysis.method.increment[1:(system.bus.number - 1)])
        minDelV = extrema(analysis.method.increment[system.bus.number:end])

        print("\nMinimum Magnitude Increment: ")
        print(format(Format("%*.4e\n"), 12, minDelV[1]))
        print("Minimum Angle Increment:     ")
        print(format(Format("%*.4e\n"), 12, minDelθ[1]))

        print("Maximum Magnitude Increment: ")
        print(format(Format("%*.4e\n"), 12, minDelV[2]))
        print("Maximum Angle Increment:     ")
        print(format(Format("%*.4e\n\n"), 12, minDelθ[2]))
    end

    if exitpf || printpf
        if converged
            printMethodConverged(analysis, iter)
        else
            printMethodNotConverged(analysis, iter)
        end
    end
end

function printMethodConverged(::ACPowerFlow{NewtonRaphson}, iter::Int64)
    println("EXIT: The solution was found using the Newton-Raphson method in $iter iterations.")
end

function printMethodConverged(::ACPowerFlow{GaussSeidel}, iter::Int64)
    println("EXIT: The solution was found using the Gauss-Seidel method in $iter iterations.")
end

function printMethodConverged(::ACPowerFlow{FastNewtonRaphson}, iter::Int64)
    println("EXIT: The solution was found using the fast Newton-Raphson method in $iter iterations.")
end

function printMethodNotConverged(::ACPowerFlow{NewtonRaphson}, ::Int64)
    println("EXIT: The Newton-Raphson method failed to converge.")
end

function printMethodNotConverged(::ACPowerFlow{GaussSeidel}, ::Int64)
    println("EXIT: The Gauss-Seidel method failed to converge.")
end

function printMethodNotConverged(::ACPowerFlow{FastNewtonRaphson}, ::Int64)
    println("EXIT: The Fast Newton-Raphson method failed to converge.")
end