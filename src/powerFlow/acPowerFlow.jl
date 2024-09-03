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
    voltageMagnitude, voltageAngle = initializeACPowerFlow(system)

    pqIndex = fill(0, bus.number)
    pvpqIndex = similar(pqIndex)
    nonZeroElement = 0; pvpqNumber = 0; pqNumber = 0
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            pqNumber += 1
            pqIndex[i] = pqNumber + bus.number - 1
        end
        if bus.layout.type[i] != 3
            pvpqNumber += 1
            pvpqIndex[i] = pvpqNumber
        end

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[j]]
            if bus.layout.type[i] != 3 && typeRow != 3
                nonZeroElement += 1
            end
            if bus.layout.type[i] == 1 && typeRow != 3
                nonZeroElement += 2
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                nonZeroElement += 1
            end
        end
    end

    iIndex = fill(0, nonZeroElement)
    jIndex = similar(iIndex)
    count = 1
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    iIndex[count] = pvpqIndex[row]
                    jIndex[count] = pvpqIndex[i]
                    count += 1
                end
                if typeRow == 1
                    iIndex[count] = pqIndex[row]
                    jIndex[count] = pvpqIndex[i]
                    count += 1
                end
                if bus.layout.type[i] == 1 && typeRow != 3
                    iIndex[count] = pvpqIndex[row]
                    jIndex[count] = pqIndex[i]
                    count += 1
                end
                if bus.layout.type[i] == 1 && typeRow == 1
                    iIndex[count] = pqIndex[row]
                    jIndex[count] = pqIndex[i]
                    count += 1
                end
            end
        end
    end

    jacobian = sparse(iIndex, jIndex, fill(0.0, nonZeroElement), bus.number + pqNumber - 1, bus.number + pqNumber - 1)
    mismatch = fill(0.0, bus.number + pqNumber - 1)
    increment = fill(0.0, bus.number + pqNumber - 1)

    return ACPowerFlow(
        Polar(
            voltageMagnitude,
            voltageAngle
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
            jacobian,
            mismatch,
            increment,
            factorized[factorization],
            pqIndex,
            pvpqIndex,
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
    analysis = fastNewtonRaphsonModel(system, factorization, true)

    return analysis
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
    analysis = fastNewtonRaphsonModel(system, factorization, false)

    return analysis
end

@inline function fastNewtonRaphsonModel(system::PowerSystem, factorization::Type{<:Union{QR, LU}}, bx::Bool)
    bus = system.bus
    branch = system.branch
    ac = system.model.ac

    checkSlackBus(system)
    model!(system, ac)
    voltageMagnitude, voltageAngle = initializeACPowerFlow(system)

    pqIndex = fill(0, bus.number)
    pvpqIndex = similar(pqIndex)
    nonZeroElementActive = 0; nonZeroElementReactive = 0; pvpqNumber = 0; pqNumber = 0
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            pqNumber += 1
            pqIndex[i] = pqNumber
        end
        if bus.layout.type[i] != 3
            pvpqNumber += 1
            pvpqIndex[i] = pvpqNumber
        end

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            typeRow = bus.layout.type[ac.nodalMatrix.rowval[j]]
            if bus.layout.type[i] != 3 && typeRow != 3
                nonZeroElementActive += 1
            end
            if bus.layout.type[i] == 1 && typeRow == 1
                nonZeroElementReactive += 1
            end
        end
    end

    iIndexActive = fill(0, nonZeroElementActive); jIndexActive = similar(iIndexActive)
    iIndexReactive = fill(0, nonZeroElementReactive); jIndexReactive = similar(iIndexReactive)
    countActive = 1; countReactive = 1
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    iIndexActive[countActive] = pvpqIndex[row]
                    jIndexActive[countActive] = pvpqIndex[i]
                    countActive += 1
                end
                if bus.layout.type[i] == 1 && typeRow == 1
                    iIndexReactive[countReactive] = pqIndex[row]
                    jIndexReactive[countReactive] = pqIndex[i]
                    countReactive += 1
                end
            end
        end
    end

    jacobianActive = sparse(iIndexActive, jIndexActive, zeros(nonZeroElementActive), bus.number - 1, bus.number - 1)
    jacobianReactive = sparse(iIndexReactive, jIndexReactive, zeros(nonZeroElementReactive), pqNumber, pqNumber)

    mismatchActive = fill(0.0, bus.number - 1)
    mismatchReactive = fill(0.0, pqNumber)
    incrementReactive = fill(0.0, pqNumber)
    incrementActive = fill(0.0, bus.number - 1)

    analysis = ACPowerFlow(
        Polar(
            voltageMagnitude,
            voltageAngle
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
                jacobianActive,
                mismatchActive,
                incrementActive,
                factorized[factorization],
            ),
            FastNewtonRaphsonModel(
                jacobianReactive,
                mismatchReactive,
                incrementReactive,
                factorized[factorization],
            ),
            pqIndex,
            pvpqIndex,
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
            analysis.method.reactive.jacobian[analysis.method.pq[i], analysis.method.pq[i]] += bus.shunt.susceptance[i]
        end
    end

    return analysis
end

@inline function fastNewtonRaphsonJacobian(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson}, i::Int64, sign::Int64)
    from = system.branch.layout.from[i]
    to = system.branch.layout.to[i]

    shiftcos = cos(system.branch.parameter.shiftAngle[i])
    shiftsin = sin(system.branch.parameter.shiftAngle[i])
    resistance = system.branch.parameter.resistance[i]
    reactance = system.branch.parameter.reactance[i]
    susceptance = system.branch.parameter.susceptance[i]
    turnsRatio = system.branch.parameter.turnsRatio[i]

    m = analysis.method.pvpq[from]
    n = analysis.method.pvpq[to]

    if analysis.method.bx
        gmk = resistance / (resistance^2 + reactance^2)
        bmk = -reactance / (resistance^2 + reactance^2)
    else
        gmk = 0.0
        bmk = -1 / reactance
    end
    if from != system.bus.layout.slack && to != system.bus.layout.slack
        analysis.method.active.jacobian[m, n] += sign * (-gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
        analysis.method.active.jacobian[n, m] += sign * (gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
    end
    if from != system.bus.layout.slack
        analysis.method.active.jacobian[m, m] += sign * bmk / (shiftcos^2 + shiftsin^2)
    end
    if to != system.bus.layout.slack
        analysis.method.active.jacobian[n, n] += sign * bmk
    end

    m = analysis.method.pq[from]
    n = analysis.method.pq[to]

    if analysis.method.bx
        bmk = - 1 / reactance
    else
        bmk = -reactance / (resistance^2 + reactance^2)
    end
    if m != 0 && n != 0
        analysis.method.reactive.jacobian[m, n] += sign * (-bmk / turnsRatio)
        analysis.method.reactive.jacobian[n, m] += sign * (-bmk / turnsRatio)
    end
    if system.bus.layout.type[from] == 1
        analysis.method.reactive.jacobian[m, m] += sign * (bmk + 0.5 * susceptance) / (turnsRatio^2)
    end
    if system.bus.layout.type[to] == 1
        analysis.method.reactive.jacobian[n, n] += sign * (bmk + 0.5 * susceptance)
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
    voltageMagnitude, voltageAngle = initializeACPowerFlow(system)

    bus = system.bus

    voltage = zeros(ComplexF64, bus.number)
    pqIndex = Int64[]
    pvIndex = Int64[]
    @inbounds for i = 1:bus.number
        voltage[i] = voltageMagnitude[i] * cis(voltageAngle[i])

        if bus.layout.type[i] == 1
            push!(pqIndex, i)
        end
        if bus.layout.type[i] == 2
            push!(pvIndex, i)
        end
    end

    return ACPowerFlow(
        Polar(
            voltageMagnitude,
            voltageAngle
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
            voltage,
            pqIndex,
            pvIndex
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
    voltage = analysis.voltage
    mismatch = analysis.method.mismatch
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            I = 0.0
            C = 0.0
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                I += voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                if bus.layout.type[i] == 1
                    C += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end

            mismatch[pvpq[i]] = voltage.magnitude[i] * I - bus.supply.active[i] + bus.demand.active[i]
            stopActive = max(stopActive, abs(mismatch[pvpq[i]]))
            if bus.layout.type[i] == 1
                mismatch[pq[i]] = voltage.magnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
                stopReactive = max(stopReactive, abs(mismatch[pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatch!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
    ac = system.model.ac
    bus = system.bus

    voltage = analysis.voltage
    active = analysis.method.active
    reactive = analysis.method.reactive
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            active.mismatch[pvpq[i]] = - (bus.supply.active[i] - bus.demand.active[i]) / voltage.magnitude[i]
            C = 0.0
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                active.mismatch[pvpq[i]] += voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                if bus.layout.type[i] == 1
                    C += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end

            stopActive = max(stopActive, abs(active.mismatch[pvpq[i]]))
            if bus.layout.type[i] == 1
                reactive.mismatch[pq[i]] = C - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
                stopReactive = max(stopReactive, abs(reactive.mismatch[pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatch!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
    ac = system.model.ac
    voltage = analysis.method.voltage

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i in analysis.method.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage[ac.nodalMatrix.rowval[j]]
        end
        apparent = voltage[i] * conj(I)

        mismatchActive = real(apparent) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))

        mismatchReactive = imag(apparent) - system.bus.supply.reactive[i] + system.bus.demand.reactive[i]
        stopReactive = max(stopReactive, abs(mismatchReactive))
    end

    @inbounds for i in analysis.method.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage[ac.nodalMatrix.rowval[j]]
        end
        mismatchActive = real(voltage[i] * conj(I)) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))
    end

    return stopActive, stopReactive
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

    voltage = analysis.voltage
    jacobian = analysis.method.jacobian
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    I1 = 0.0; I2 = 0.0
                    Gij = real(ac.nodalMatrix.nzval[j])
                    Bij = imag(ac.nodalMatrix.nzval[j])
                    if row != i
                        Tij = voltage.angle[row] - voltage.angle[i]
                        jacobian[pvpq[row], pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (Gij * sin(Tij) - Bij * cos(Tij))
                        if typeRow == 1
                            jacobian[pq[row], pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (-Gij * cos(Tij) - Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1
                            jacobian[pvpq[row], pq[i]] = voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[pq[row], pq[i]] = voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                        end
                    else
                        for k in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                            q = ac.nodalMatrix.rowval[k]
                            Gik = real(ac.nodalMatrixTranspose.nzval[k])
                            Bik = imag(ac.nodalMatrixTranspose.nzval[k])
                            Tij = voltage.angle[row] - voltage.angle[q]
                            I1 -= voltage.magnitude[q] * (Gik * sin(Tij) - Bik * cos(Tij))
                            if bus.layout.type[i] == 1 || typeRow == 1
                                I2 += voltage.magnitude[q] * (Gik * cos(Tij) + Bik * sin(Tij))
                            end
                        end
                        jacobian[pvpq[row], pvpq[i]] = voltage.magnitude[row] * I1 - Bij * voltage.magnitude[row]^2
                        if typeRow == 1
                            jacobian[pq[row], pvpq[i]] = voltage.magnitude[row] * I2 - Gij * voltage.magnitude[row]^2
                        end
                        if bus.layout.type[i] == 1
                            jacobian[pvpq[row], pq[i]] = I2 + Gij * voltage.magnitude[row]
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[pq[row], pq[i]] = -I1 - Bij * voltage.magnitude[row]
                        end
                    end
                end
            end
        end
    end

    if ac.pattern != analysis.method.pattern
        analysis.method.pattern = copy(system.model.ac.pattern)
        analysis.method.factorization = factorization(jacobian, analysis.method.factorization)
    else
        analysis.method.factorization = factorization!(jacobian, analysis.method.factorization)
    end

    analysis.method.increment = solution(analysis.method.increment, analysis.method.mismatch, analysis.method.factorization)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - analysis.method.increment[pq[i]]
        end
        if i != bus.layout.slack
            voltage.angle[i] = voltage.angle[i] - analysis.method.increment[pvpq[i]]
        end
    end
end

function solve!(system::PowerSystem, analysis::ACPowerFlow{FastNewtonRaphson})
    ac = system.model.ac
    bus = system.bus

    voltage = analysis.voltage
    active = analysis.method.active
    reactive = analysis.method.reactive
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    if system.model.ac.model != analysis.method.acmodel
        analysis.method.acmodel = copy(system.model.ac.model)
        if ac.pattern != analysis.method.pattern
            analysis.method.pattern = copy(system.model.ac.pattern)
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
            voltage.angle[i] += active.increment[pvpq[i]]
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            reactive.mismatch[pq[i]] = - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                reactive.mismatch[pq[i]] += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
            end
        end
    end

    reactive.increment = solution(reactive.increment, reactive.mismatch, reactive.factorization)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] += reactive.increment[pq[i]]
        end
    end
end

function solve!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
    ac = system.model.ac
    voltage = analysis.method.voltage

    @inbounds for i in analysis.method.pq
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] - im * (system.bus.supply.reactive[i] - system.bus.demand.reactive[i])
        I = injection / conj(voltage[i])
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I -= ac.nodalMatrixTranspose.nzval[j] * voltage[ac.nodalMatrix.rowval[j]]
        end
        voltage[i] += I / ac.nodalMatrix[i, i]

        analysis.voltage.magnitude[i] = abs(voltage[i])
        analysis.voltage.angle[i] = angle(voltage[i])
    end

    @inbounds for i in analysis.method.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage[ac.nodalMatrix.rowval[j]]
        end
        conjVoltage = conj(voltage[i])
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] + im * imag(conjVoltage * I)
        voltage[i] += ((injection / conjVoltage) - I) / ac.nodalMatrix[i, i]
    end

    @inbounds for i in analysis.method.pv
        index = system.bus.supply.generator[i][1]
        voltage[i] = system.generator.voltage.magnitude[index] * voltage[i] / abs(voltage[i])

        analysis.voltage.magnitude[i] = abs(voltage[i])
        analysis.voltage.angle[i] = angle(voltage[i])
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
    bus = system.bus
    generator = system.generator

    errorVoltage(analysis.voltage.magnitude)

    violate = fill(0, generator.number)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    outputReactive = fill(0.0, generator.number)
    labels = collect(keys(sort(system.generator.label; byvalue = true)))
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
        if generator.layout.status[i] == 1 && (generator.capability.minReactive[i] < generator.capability.maxReactive[i])
            j = generator.layout.bus[i]

            violateMinimum = outputReactive[i] < generator.capability.minReactive[i]
            violateMaximum = outputReactive[i] > generator.capability.maxReactive[i]
            if  bus.layout.type[j] != 1 && (violateMinimum || violateMaximum)
                if violateMinimum
                    violate[i] = -1
                    newReactivePower = generator.capability.minReactive[i]
                end
                if violateMaximum
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
                            @info("The slack bus labeled $(iterate(system.bus.label, j)[1][1]) is converted to generator bus.\nThe bus labeled $(iterate(system.bus.label, k)[1][1]) is the new slack bus.")
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
        throw(ErrorException("In the iterative process, a generator bus is chosen as the new slack bus.
        However, if the reactive power limits are violated, the new slack bus is converted to a demand bus.
        As a analysis, there are no more generator buses left that can be considered as the new slack bus for the system."))
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
function adjustAngle!(system::PowerSystem, analysis::ACPowerFlow; slack::L)
    index = system.bus.label[getLabel(system.bus, slack, "bus")]
    T = system.bus.voltage.angle[index] - analysis.voltage.angle[index]
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + T
    end
end

"""
    startingVoltage!(system::PowerSystem, analysis::ACPowerFlow)

The function extracts bus voltage magnitudes and angles from the `PowerSystem` composite
type and assigns them to the `ACPowerFlow` type, enabling users to initialize voltage
values as required.

# Updates
This function only updates the `voltage` field of the `ACPowerFlow` type.

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

updateBus!(system, analysis; label = 14, reactive = 0.13, magnitude = 1.2, angle = -0.17)

startingVoltage!(system, analysis)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
```
"""
function startingVoltage!(system::PowerSystem, analysis::ACPowerFlow{T}) where T <: Union{NewtonRaphson, FastNewtonRaphson}
    @inbounds for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i]) && system.bus.layout.type[i] != 1
            analysis.voltage.magnitude[i] = system.generator.voltage.magnitude[system.bus.supply.generator[i][1]]
        else
            analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
        end
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
end

function startingVoltage!(system::PowerSystem, analysis::ACPowerFlow{GaussSeidel})
    @inbounds for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i]) && system.bus.layout.type[i] != 1
            analysis.voltage.magnitude[i] = system.generator.voltage.magnitude[system.bus.supply.generator[i][1]]
        else
            analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
        end
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
        analysis.method.voltage[i] = analysis.voltage.magnitude[i] * cis(analysis.voltage.angle[i])
    end
end

function initializeACPowerFlow(system::PowerSystem)
    magnitude = copy(system.bus.voltage.magnitude)
    angle = copy(system.bus.voltage.angle)

    @inbounds for i = 1:system.bus.number
        if isempty(system.bus.supply.generator[i]) && system.bus.layout.type[i] == 2
            system.bus.layout.type[i] = 1
        end
        if !isempty(system.bus.supply.generator[i]) && system.bus.layout.type[i] != 1
            magnitude[i] = system.generator.voltage.magnitude[system.bus.supply.generator[i][1]]
        end
    end

    changeSlackBus!(system)

    return magnitude, angle
end

########## Change Slack Bus ##########
function changeSlackBus!(system::PowerSystem)
    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        system.bus.layout.type[system.bus.layout.slack] = 1
        @inbounds for i = 1:system.bus.number
            if system.bus.layout.type[i] == 2 && !isempty(system.bus.supply.generator[i])
                system.bus.layout.type[i] = 3
                system.bus.layout.slack = i
                @info("The bus with index $i is now the new slack bus since no in-service generator was available at the previous slack bus.")
                break
            end
        end

        if system.bus.layout.type[system.bus.layout.slack] == 1
            throw(ErrorException("No generator buses with an in-service generator found in the power system. Slack bus definition not possible."))
        end
    end
end