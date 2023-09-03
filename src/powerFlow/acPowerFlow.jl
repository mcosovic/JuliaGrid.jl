######### Newton-Raphson ##########
struct NewtonRaphsonMethod
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

struct NewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::NewtonRaphsonMethod
    uuid::UUID
end

######### Fast Newton-Raphson ##########
struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64}
end

struct FastNewtonRaphsonMethod
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

struct FastNewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::FastNewtonRaphsonMethod
    uuid::UUID
end

######### Gauss-Seidel ##########
struct GaussSeidelMethod
    voltage::Array{ComplexF64,1}
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

struct GaussSeidel <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::GaussSeidelMethod
    uuid::UUID
end

"""
    newtonRaphson(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the
Newton-Raphson method to solve AC power flow. Additionally, if the AC model was not created,
the function will automatically initiate an update of the `ac` field within the `PowerSystem`
composite type.

# Returns
The function returns an instance of the `NewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `method`: contains the Jacobian matrix, power injection mismatches, bus voltage increments, and indices;
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
```
"""
function newtonRaphson(system::PowerSystem)
    ac = system.model.ac
    bus = system.bus

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end
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

    return NewtonRaphson(
        Polar(
            voltageMagnitude,
            voltageAngle
        ),
        Power(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        Current(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        NewtonRaphsonMethod(
            jacobian,
            mismatch,
            increment,
            pqIndex,
            pvpqIndex
        ),
        system.uuid
    )
end

"""
    fastNewtonRaphsonBX(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the fast
Newton-Raphson method of version BX to solve AC power flow. Additionally, if the AC model was
not created, the function will automatically initiate an update of the `ac` field  within the
`PowerSystem` composite type.

# Returns
The function returns an instance of the `FastNewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `method`: contains Jacobian matrices, power injection mismatches, bus voltage increments, and indices;
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonBX(system)
```
"""
function fastNewtonRaphsonBX(system::PowerSystem)
    algorithmBX = 1
    analysis = fastNewtonRaphson(system, algorithmBX)

    return analysis
end

"""
    fastNewtonRaphsonXB(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the fast
Newton-Raphson method of version XB to solve AC power flow. Additionally, if the AC model was
not created, the function will automatically initiate an update of the `ac` field within the
`PowerSystem` composite type.

# Returns
The function returns an instance of the `FastNewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `method`: contains Jacobian matrices, power injection mismatches, bus voltage increments, and indices;
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = fastNewtonRaphsonXB(system)
```
"""
function fastNewtonRaphsonXB(system::PowerSystem)
    algorithmXB = 2
    analysis = fastNewtonRaphson(system, algorithmXB)

    return analysis
end

@inline function fastNewtonRaphson(system::PowerSystem, algorithmFlag::Int64)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end
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

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            from = branch.layout.from[i]
            to = branch.layout.to[i]

            shiftcos = cos(branch.parameter.shiftAngle[i])
            shiftsin = sin(branch.parameter.shiftAngle[i])
            resistance = branch.parameter.resistance[i]
            reactance = branch.parameter.reactance[i]
            susceptance = branch.parameter.susceptance[i]

            m = pvpqIndex[from]
            n = pvpqIndex[to]

            if algorithmFlag == 1
                gmk = resistance / (resistance^2 + reactance^2)
                bmk = -reactance / (resistance^2 + reactance^2)
            end
            if algorithmFlag == 2
                gmk = 0.0
                bmk = -1 / reactance
            end
            if from != bus.layout.slack && to != bus.layout.slack
                jacobianActive[m, n] += (-gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
                jacobianActive[n, m] += (gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
            end
            if from != bus.layout.slack
                jacobianActive[m, m] += bmk / (shiftcos^2 + shiftsin^2)
            end
            if to != bus.layout.slack
                jacobianActive[n, n] += bmk
            end

            m = pqIndex[from]
            n = pqIndex[to]

            if algorithmFlag == 1
                bmk = - 1 / reactance
            end
            if algorithmFlag == 2
                bmk = -reactance / (resistance^2 + reactance^2)
            end
            if branch.parameter.turnsRatio[i] == 0
                turnsRatio = 1.0
            else
                turnsRatio = branch.parameter.turnsRatio[i]
            end
            if m != 0 && n != 0
                jacobianReactive[m, n] += -bmk / turnsRatio
                jacobianReactive[n, m] += -bmk / turnsRatio
            end
            if bus.layout.type[from] == 1
                jacobianReactive[m, m] += (bmk + 0.5 * susceptance) / (turnsRatio^2)
            end
            if bus.layout.type[to] == 1
                jacobianReactive[n, n] += bmk + 0.5 * susceptance
            end
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            jacobianReactive[pqIndex[i], pqIndex[i]] += bus.shunt.susceptance[i]
        end
    end

    factorisationActive = lu(jacobianActive)
    factorisationReactive = lu(jacobianReactive)

    mismatchActive = fill(0.0, bus.number - 1)
    mismatchReactive = fill(0.0, pqNumber)
    incrementReactive = fill(0.0, pqNumber)
    incrementActive = fill(0.0, bus.number - 1)

    if algorithmFlag == 1
        method = "Fast Newton-Raphson BX"
    else
        method = "Fast Newton-Raphson XB"
    end

    return FastNewtonRaphson(
        Polar(voltageMagnitude,voltageAngle),
        Power(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        Current(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        FastNewtonRaphsonMethod(
            FastNewtonRaphsonModel(
                jacobianActive,
                mismatchActive,
                incrementActive,
                factorisationActive
            ),
            FastNewtonRaphsonModel(
                jacobianReactive,
                mismatchReactive,
                incrementReactive,
                factorisationReactive
            ),
            pqIndex,
            pvpqIndex
        ),
        system.uuid
    )
end

"""
    gaussSeidel(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the
Gauss-Seidel method to solve AC power flow. Additionally, if the AC model was not created, the
function will automatically initiate an update of the `ac` field within the `PowerSystem`
composite type.

# Returns
The function returns an instance of the `GaussSeidel` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `method`: contains the bus complex voltages and indices;
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = gaussSeidel(system)
```
"""
function gaussSeidel(system::PowerSystem)
    bus = system.bus

    if isempty(system.model.ac.nodalMatrix)
        acModel!(system)
    end
    voltageMagnitude, voltageAngle = initializeACPowerFlow(system)

    voltage = zeros(ComplexF64, bus.number)
    pqIndex = Int64[]
    pvIndex = Int64[]
    @inbounds for i = 1:bus.number
        voltage[i] = voltageMagnitude[i] * exp(im * voltageAngle[i])

        if bus.layout.type[i] == 1
            push!(pqIndex, i)
        end
        if bus.layout.type[i] == 2
            push!(pvIndex, i)
        end
    end

    method = "Gauss-Seidel"

    return GaussSeidel(
        Polar(voltageMagnitude, voltageAngle),
        Power(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        Current(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        GaussSeidelMethod(
            voltage,
            pqIndex,
            pvIndex
        ),
        system.uuid
    )
end


"""
    mismatch!(system::PowerSystem, analysis::ACPowerFlow)

The function calculates both active and reactive power injection mismatches and returns
their maximum absolute values, which can be utilized to terminate the iteration loop of
methods employed to solve the AC power flow problem.

# Updates
This function updates the mismatch variables in the Newton-Raphson and fast Newton-Raphson
methods. It should be employed during the iteration loop before invoking the
[`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) function.

In contrast, the Gauss-Seidel method does not need mismatches to obtain bus voltages, but
the maximum absolute values are commonly employed to stop the iteration loop. The function
does not save any data and should be utilized during the iteration loop before invoking the
[`solve!`](@ref solve!(::PowerSystem, ::NewtonRaphson)) function.

# Abstract type
The abstract type `ACPowerFlow` can have the following subtypes:
- `NewtonRaphson`: computes the power mismatches within the Newton-Raphson method;
- `FastNewtonRaphson`: computes the power mismatches within the fast Newton-Raphson method;
- `GaussSeidel`: computes the power mismatches within the Gauss-Seidel method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = newtonRaphson(system)
mismatch!(system, analysis)
```
"""
function mismatch!(system::PowerSystem, analysis::NewtonRaphson)
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

function mismatch!(system::PowerSystem, analysis::FastNewtonRaphson)
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

function mismatch!(system::PowerSystem, analysis::GaussSeidel)
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

The function employs the Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method to solve
the AC power flow problem and calculate bus voltage magnitudes and angles.

After the [`mismatch!`](@ref mismatch!) function is called, this function should be executed to
perform a single iteration of the method.

# Updates
The calculated voltages are stored in the `voltage` field of the respective struct type.

# Abstract type
The abstract type `ACPowerFlow` can have the following subtypes:
- `NewtonRaphson`: computes the bus voltages within the Newton-Raphson method;
- `FastNewtonRaphson`: computes the bus voltages within the fast Newton-Raphson method;
- `GaussSeidel`: computes the bus voltages within the Gauss-Seidel method.

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
function solve!(system::PowerSystem, analysis::NewtonRaphson)
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

    ldiv!(analysis.method.increment, lu(jacobian), analysis.method.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - analysis.method.increment[pq[i]]
        end
        if i != bus.layout.slack
            voltage.angle[i] = voltage.angle[i] - analysis.method.increment[pvpq[i]]
        end
    end
end

function solve!(system::PowerSystem, analysis::FastNewtonRaphson)
    ac = system.model.ac
    bus = system.bus

    voltage = analysis.voltage
    active = analysis.method.active
    reactive = analysis.method.reactive
    pq = analysis.method.pq
    pvpq = analysis.method.pvpq

    ldiv!(active.increment, active.factorization, active.mismatch)

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

    ldiv!(reactive.increment, reactive.factorization, reactive.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] += reactive.increment[pq[i]]
        end
    end
end

function solve!(system::PowerSystem, analysis::GaussSeidel)
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
if they are violated, after determining the bus voltage magnitudes and angles. If the
limits are violated, the corresponding generator buses or the slack bus are converted to
demand buses.

# Updates
The function assigns values to the `generator.output.active` and `bus.supply.active`
variables of the `PowerSystem` type. Additionally, it examines the reactive powers of the
generator and adjusts them to their maximum or minimum values if they exceed the specified
threshold. Subsequently, the `generator.output.reactive` variable of the `PowerSystem` type
is modified accordingly. As a result of this adjustment, the `bus.supply.reactive` variable
of the `PowerSystem` type is also updated, and the bus types specified in `bus.layout.type`
are modified. If the slack bus is converted, the `bus.layout.slack` field is correspondingly
adjusted.

# Returns
The function returns the `violate` variable to indicate which buses violate the limits,
with -1 indicating a violation of the minimum limits and 1 indicating a violation of the
maximum limits.

# Abstract type
The abstract type `ACPowerFlow` can have the following subtypes:
- `NewtonRaphson`: computes the bus voltages within the Newton-Raphson method,
- `FastNewtonRaphson`: computes the bus voltages within the fast Newton-Raphson method,
- `GaussSeidel`: computes the bus voltages within the Gauss-Seidel method.

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
                            labels = collect(keys(sort(system.bus.label; byvalue = true)))
                            @info("The slack bus labeled $(labels[j]) is converted to generator bus.\nThe bus labeled $(labels[k]) is the new slack bus.")
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
the [`reactiveLimit!`](@ref reactiveLimit!) function will change that bus to the demand bus
and designate the first generator bus in the sequence as the new slack bus. After obtaining
the updated AC power flow solution based on the new slack bus, it is possible to adjust the
voltage angles to align with the angle of the original slack bus. The `slack` keyword
specifies the bus label of the original slack bus.

# Updates
This function only updates the `voltage.angle` variable of the `ACPowerFlow` abstract type.

# Abstract type
The abstract type `ACPowerFlow` can have the following subtypes:
- `NewtonRaphson`: computes the bus voltages within the Newton-Raphson method;
- `FastNewtonRaphson`: computes the bus voltages within the fast Newton-Raphson method;
- `GaussSeidel`: computes the bus voltages within the Gauss-Seidel method.

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

########## Initialize AC Power Flow ##########
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

    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end

    return magnitude, angle
end

########## Change Slack Bus ##########
function changeSlackBus!(system::PowerSystem)
    system.bus.layout.type[system.bus.layout.slack] = 1
    @inbounds for i = 1:system.bus.number
        if system.bus.layout.type[i] == 2 && !isempty(system.bus.supply.generator[i])
            system.bus.layout.type[i] = 3
            system.bus.layout.slack = i
            @info("The slack bus did not have an in-service generator, the first generator bus in the list with in-service generator is set to be slack bus.")
            break
        end
    end

    if system.bus.layout.type[system.bus.layout.slack] == 1
        throw(ErrorException("No generator buses with an in-service generator found in the power system. Slack bus definition not possible."))
    end
end

######### Query About Bus ##########
function addBus!(system::PowerSystem, analysis::ACPowerFlow; kwargs...)
    throw(ErrorException("The ACPowerFlow cannot be reused when adding a new bus."))
end

######### Query About Deamnd Bus ##########
function demandBus!(system::PowerSystem, analysis::ACPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    demandBus!(system::PowerSystem; user...)
end

######### Query About Shunt Bus ##########
function shuntBus!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel}; user...)
    checkUUID(system.uuid, analysis.uuid)
    shuntBus!(system::PowerSystem; user...)
end

function shuntBus!(system::PowerSystem, analysis::FastNewtonRaphson; user...)
    throw(ErrorException("The FastNewtonRaphson cannot be reused when the shunt element is altered."))
end

######### Query About Branch ##########
function addBranch!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel};
    label::L = missing, from::L, to::L, status::T = missing,
    resistance::T = missing, reactance::T = missing, susceptance::T = missing,
    conductance::T = missing, turnsRatio::T = missing, shiftAngle::T = missing,
    minDiffAngle::T = missing, maxDiffAngle::T = missing,
    longTerm::T = missing, shortTerm::T = missing, emergency::T = missing, type::T = missing)

    checkUUID(system.uuid, analysis.uuid)
    addBranch!(system; label, from, to, status, resistance, reactance, susceptance,
        conductance, turnsRatio, shiftAngle, minDiffAngle, maxDiffAngle, longTerm, shortTerm,
        emergency, type)
end

function addBranch!(system::PowerSystem, analysis::FastNewtonRaphson; kwargs...)
    throw(ErrorException("The FastNewtonRaphson cannot be reused when adding a new branch."))
end

######### Query About Status Branch ##########
function statusBranch!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel}; label::L, status::T)
    checkUUID(system.uuid, analysis.uuid)
    statusBranch!(system; label, status)
end

function statusBranch!(system::PowerSystem, analysis::FastNewtonRaphson; kwargs...)
    throw(ErrorException("The FastNewtonRaphson cannot be reused when the branch status is altered."))
end

######### Query About Parameter Branch ##########
function parameterBranch!(system::PowerSystem, analysis::Union{NewtonRaphson, GaussSeidel}; user...)
    checkUUID(system.uuid, analysis.uuid)
    parameterBranch!(system; user...)
end

function parameterBranch!(system::PowerSystem, analysis::FastNewtonRaphson; kwargs...)
    throw(ErrorException("The FastNewtonRaphson cannot be reused when the branch parameters are altered."))
end

######### Query About Generator ##########
function addGenerator!(system::PowerSystem, analysis::ACPowerFlow;
    label::L = missing, bus::L, area::T = missing, status::T = missing,
    active::T = missing, reactive::T = missing, magnitude::T = missing,
    minActive::T = missing, maxActive::T = missing, minReactive::T = missing,
    maxReactive::T = missing, lowActive::T = missing, minLowReactive::T = missing,
    maxLowReactive::T = missing, upActive::T = missing, minUpReactive::T = missing,
    maxUpReactive::T = missing, loadFollowing::T = missing, reserve10min::T = missing,
    reserve30min::T = missing, reactiveTimescale::T = missing)

    checkUUID(system.uuid, analysis.uuid)
    addGenerator!(system; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowActive, minLowReactive,
        maxLowReactive, upActive, minUpReactive, maxUpReactive, loadFollowing, reserve10min,
        reserve30min, reactiveTimescale)
end

######### Query About Status Generator ##########
function statusGenerator!(system::PowerSystem, analysis::ACPowerFlow; label::L, status::Int64 = 0)
    checkUUID(system.uuid, analysis.uuid)
    checkStatus(status)

    index = system.generator.label[getLabel(system.generator, label, "generator")]
    indexBus = system.generator.layout.bus[index]
    if status == 0 && system.bus.layout.type[indexBus] in [2, 3]
        if length(system.bus.supply.generator[indexBus]) == 1
            throw(ErrorException("The ACPowerFlow cannot be reused due to required bus type conversion."))
        elseif length(system.bus.supply.generator[indexBus]) > 1 && system.bus.supply.generator[indexBus][1] == index
            idx = system.bus.supply.generator[indexBus][2]
            analysis.voltage.magnitude[indexBus] = system.generator.voltage.magnitude[idx]
        end
    end

    statusGenerator!(system; label, status)

    if status == 1 && system.bus.layout.type[indexBus] in [2, 3] && system.bus.supply.generator[indexBus][1] == index
        analysis.voltage.magnitude[indexBus] = system.generator.voltage.magnitude[system.bus.supply.generator[indexBus][1]]
    end
end

######### Query About Output Generator ##########
function outputGenerator!(system::PowerSystem, analysis::ACPowerFlow; user...)
    checkUUID(system.uuid, analysis.uuid)
    outputGenerator!(system; user...)
end