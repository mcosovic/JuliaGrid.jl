######### General Struct ##########
mutable struct Polar
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
end

mutable struct Cartesian
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct CartesianImag
    reactive::Array{Float64,1}
end

mutable struct CartesianFloat
    active::Float64
    reactive::Float64
end

######### Bus Struct ##########
mutable struct BusPower
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
end

mutable struct BusCurrent
    injection::Polar
end

mutable struct BusResult
    voltage::Polar
    power::BusPower
    current::BusCurrent
end

######### Branch Struct ##########
mutable struct BranchPower
    from::Cartesian
    to::Cartesian
    shunt::CartesianImag
    loss::Cartesian
end

mutable struct BranchCurrent
    from::Polar
    to::Polar
    impedance::Polar
end

mutable struct BranchResult
    power::BranchPower
    current::BranchCurrent
end

######### Generator ##########
mutable struct GeneratorResult
    power::Cartesian
end

######### Newton-Raphson Struct ##########
struct NewtonRaphsonIndex
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    index::NewtonRaphsonIndex
    method::String
end

######### Fast Newton-Raphson Struct ##########
struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    lower::SparseMatrixCSC{Float64,Int64}
    upper::SparseMatrixCSC{Float64,Int64}
    right::Array{Int64,1}
    left::Array{Int64,1}
    scaling::Array{Float64,1}
end

struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    index::NewtonRaphsonIndex
    method::String
end

######### Gauss-Seidel Struct ##########
struct GaussSeidelVoltage
    complex::Array{ComplexF64,1}
    magnitude::Array{Float64,1}
end

struct GaussSeidelIndex
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

struct GaussSeidel
    voltage::GaussSeidelVoltage
    index::GaussSeidelIndex
    method::String
end

######### DC Power Flow Struct ##########
struct DcPowerFlow
    method::String
end

######### Result Struct ##########
mutable struct Result
    bus::BusResult
    branch::BranchResult
    generator::GeneratorResult
    algorithm::Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel, DcPowerFlow}
end

"""
The function accepts the `PowerSystem` composite type as input, uses it to set up the
Newton-Raphson method, and then produces the `Result` composite type as output.

    newtonRaphson(system::PowerSystem)

The `algorithm` field of the `Result` type is updated during the function's execution.
"""
function newtonRaphson(system::PowerSystem)
    ac = system.acModel
    bus = system.bus

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
            I = 0.0; C = 0.0

            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltageAngle[i] - voltageAngle[row]
                I += voltageMagnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))

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
                if bus.layout.type[i] == 1
                    C += voltageMagnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end
        end
    end

    jacobian = sparse(iIndex, jIndex, fill(0.0, nonZeroElement), bus.number + pqNumber - 1, bus.number + pqNumber - 1)
    mismatch = fill(0.0, bus.number + pqNumber - 1)
    increment = fill(0.0, bus.number + pqNumber - 1)
    method = "Newton-Raphson"

    return Result(
        BusResult(Polar(voltageMagnitude, voltageAngle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        NewtonRaphson(jacobian, mismatch, increment, NewtonRaphsonIndex(pqIndex, pvpqIndex), method)
        )
end

"""
The function accepts the `PowerSystem` composite type as input, uses it to set up the
fast Newton-Raphson method of version BX, and then produces the `Result` composite type as
output.

    fastNewtonRaphsonBX(system::PowerSystem)

The `algorithm` field of the `Result` type is updated during the function's execution.
"""
function fastNewtonRaphsonBX(system::PowerSystem)
    algorithmBX = 1
    result = fastNewtonRaphson(system, algorithmBX)

    return result
end

"""
The function accepts the `PowerSystem` composite type as input, uses it to set up the
fast Newton-Raphson method of version XB, and then produces the `Result` composite type as
output.

    fastNewtonRaphsonXB(system::PowerSystem)

The `algorithm` field of the `Result` type is updated during the function's execution.
"""
function fastNewtonRaphsonXB(system::PowerSystem)
    algorithmXB = 2
    result = fastNewtonRaphson(system, algorithmXB)

    return result
end

@inline function fastNewtonRaphson(system::PowerSystem, algorithmFlag::Int64)
    ac = system.acModel
    bus = system.bus
    branch = system.branch

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

    F1 = lu(jacobianActive)
    lowerActive, upperActive, rightActive, leftActive, scalingActive = F1.:(:)
    leftActive = sortperm(leftActive)

    F2 = lu(jacobianReactive)
    lowerReactive, upperReactive, rightReactive, leftReactive, scalingReactive = F2.:(:)
    leftReactive = sortperm(leftReactive)

    mismatchActive = fill(0.0, bus.number - 1)
    mismatchReactive = fill(0.0, pqNumber)
    icrementReactive = fill(0.0, pqNumber)
    icrementActive = fill(0.0, bus.number - 1)

    if algorithmFlag == 1
        method = "Fast Newton-Raphson BX"
    else
        method = "Fast Newton-Raphson XB"
    end

    return Result(
        BusResult(Polar(voltageMagnitude, voltageAngle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        FastNewtonRaphson(
            FastNewtonRaphsonModel(jacobianActive, mismatchActive, icrementActive, lowerActive, upperActive, rightActive, leftActive, scalingActive),
            FastNewtonRaphsonModel(jacobianReactive, mismatchReactive, icrementReactive, lowerReactive, upperReactive, rightReactive, leftReactive, scalingReactive),
            NewtonRaphsonIndex(pqIndex, pvpqIndex), method)
        )
end

"""
The function accepts the `PowerSystem` composite type as input, uses it to set up the
Gauss-Seidel method, and then produces the `Result` composite type as output.

    gaussSeidel(system::PowerSystem)

The `algorithm` field of the `Result` type is updated during the function's execution.
"""
function gaussSeidel(system::PowerSystem)
    bus = system.bus

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

    return Result(
        BusResult(Polar(voltageMagnitude, voltageAngle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        GaussSeidel(GaussSeidelVoltage(voltage, copy(voltageMagnitude)), GaussSeidelIndex(pqIndex, pvIndex), method)
        )
end


"""
The function calculates both active and reactive power injection mismatches and returns
their maximum values. These maximum values can be used to terminate the iteration loop.

    mismatch!(system::PowerSystem, result::Result)

This function is designed to be used within the iteration loop before calling the
[`solvePowerFlow!`](@ref solvePowerFlow!) function. When using either the Newton-Raphson or
fast Newton-Raphson methods, the function updates the `mismatch` fields within the `Result`
composite type. When using the Gauss-Seidel method, the function does not store any data
and is only used to terminate the iteration loop.
"""
function mismatch!(system::PowerSystem, result::Result)
    if result.algorithm.method == "Newton-Raphson"
        stopActive, stopReactive = mismatchNewtonRaphson!(system, result)
    elseif result.algorithm.method == "Fast Newton-Raphson BX" || result.algorithm.method == "Fast Newton-Raphson XB"
        stopActive, stopReactive = mismatchFastNewtonRaphson!(system, result)
    elseif result.algorithm.method == "Gauss-Seidel"
        stopActive, stopReactive = mismatchGaussSeidel!(system, result)
    end

    return stopActive, stopReactive
end

function mismatchNewtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    mismatch = result.algorithm.mismatch
    index = result.algorithm.index

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

            mismatch[index.pvpq[i]] = voltage.magnitude[i] * I - bus.supply.active[i] + bus.demand.active[i]
            stopActive = max(stopActive, abs(mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                mismatch[index.pq[i]] = voltage.magnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
                stopReactive = max(stopReactive, abs(mismatch[index.pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatchFastNewtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    active = result.algorithm.active
    reactive = result.algorithm.reactive
    index = result.algorithm.index

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            active.mismatch[index.pvpq[i]] = - (bus.supply.active[i] - bus.demand.active[i]) / voltage.magnitude[i]
            C = 0.0
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                active.mismatch[index.pvpq[i]] += voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                if bus.layout.type[i] == 1
                    C += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end

            stopActive = max(stopActive, abs(active.mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                reactive.mismatch[index.pq[i]] = C - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
                stopReactive = max(stopReactive, abs(reactive.mismatch[index.pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatchGaussSeidel!(system::PowerSystem, result::Result)
    ac = system.acModel

    voltage = result.algorithm.voltage
    index = result.algorithm.index

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i in index.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        apparent = voltage.complex[i] * conj(I)

        mismatchActive = real(apparent) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))

        mismatchReactive = imag(apparent) - system.bus.supply.reactive[i] + system.bus.demand.reactive[i]
        stopReactive = max(stopReactive, abs(mismatchReactive))
    end

    @inbounds for i in index.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        mismatchActive = real(voltage.complex[i] * conj(I)) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))
    end

    return stopActive, stopReactive
end

"""
The function calculates the magnitudes and angles of bus voltages using either the
Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method. It updates the `bus.voltage` and
`algorithm` fields of the `Result` composite type accordingly.

    solvePowerFlow!(system::PowerSystem, result::Result)

This function should be used within the iteration loop that follows the
[`mismatch!`](@ref mismatch!) function, as they together perform a single iteration of the
Newton-Raphson or fast Newton-Raphson method. If you utilize the Gauss-Seidel method, this
function alone will calculate the bus voltages.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end
```
"""
function solvePowerFlow!(system::PowerSystem, result::Result)
    if result.algorithm.method == "Newton-Raphson"
        solveNewtonRaphson!(system, result)
    elseif result.algorithm.method == "Fast Newton-Raphson BX" || result.algorithm.method == "Fast Newton-Raphson XB"
        solveFastNewtonRaphson!(system, result)
    elseif result.algorithm.method == "Gauss-Seidel"
        solveGaussSeidel!(system, result)
    end
end

function solveNewtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    jacobian = result.algorithm.jacobian
    index = result.algorithm.index

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
                        jacobian[index.pvpq[row], index.pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (Gij * sin(Tij) - Bij * cos(Tij))
                        if typeRow == 1
                            jacobian[index.pq[row], index.pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (-Gij * cos(Tij) - Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1
                            jacobian[index.pvpq[row], index.pq[i]] = voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[index.pq[row], index.pq[i]] = voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
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
                        jacobian[index.pvpq[row], index.pvpq[i]] = voltage.magnitude[row] * I1 - Bij * voltage.magnitude[row]^2
                        if typeRow == 1
                            jacobian[index.pq[row], index.pvpq[i]] = voltage.magnitude[row] * I2 - Gij * voltage.magnitude[row]^2
                        end
                        if bus.layout.type[i] == 1
                            jacobian[index.pvpq[row], index.pq[i]] = I2 + Gij * voltage.magnitude[row]
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[index.pq[row], index.pq[i]] = -I1 - Bij * voltage.magnitude[row]
                        end
                    end
                end
            end
        end
    end

    ldiv!(result.algorithm.increment, lu(jacobian), result.algorithm.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - result.algorithm.increment[index.pq[i]]
        end
        if i != bus.layout.slack
            voltage.angle[i] = voltage.angle[i] - result.algorithm.increment[index.pvpq[i]]
        end
    end
end

function solveFastNewtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    active = result.algorithm.active
    reactive = result.algorithm.reactive
    index = result.algorithm.index

    ldiv!(active.increment, lu(active.upper), (active.lower \ ((active.scaling .* active.mismatch)[active.right])))
    permute!(active.increment, active.left)

    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            voltage.angle[i] += active.increment[index.pvpq[i]]
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            reactive.mismatch[index.pq[i]] = - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                reactive.mismatch[index.pq[i]] += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
            end
        end
    end

    ldiv!(reactive.increment, lu(reactive.upper), (reactive.lower \ ((reactive.scaling .* reactive.mismatch)[reactive.right])))
    permute!(reactive.increment, reactive.left)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] += reactive.increment[index.pq[i]]
        end
    end
end

function solveGaussSeidel!(system::PowerSystem, result::Result)
    ac = system.acModel

    voltage = result.algorithm.voltage
    index = result.algorithm.index

    @inbounds for i in index.pq
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] - im * (system.bus.supply.reactive[i] - system.bus.demand.reactive[i])
        I = injection / conj(voltage.complex[i])
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I -= ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        voltage.complex[i] += I / ac.nodalMatrix[i, i]

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end

    @inbounds for i in index.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        conjVoltage = conj(voltage.complex[i])
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] + im * imag(conjVoltage * I)
        voltage.complex[i] += ((injection / conjVoltage) - I) / ac.nodalMatrix[i, i]
    end

    @inbounds for i in index.pv
        voltage.complex[i] = voltage.magnitude[i] * voltage.complex[i] / abs(voltage.complex[i])

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end
end

"""
The function takes a `PowerSystem` composite type as input and uses it to solve the DC power
flow problem by calculating the voltage angles for each bus.

    solvePowerFlow(system::PowerSystem)

The function returns the composite type `Result` as output, which includes updated
`bus.voltage.angle` and `algorithm` fields. These fields are modified during the execution
of the function.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

result = solvePowerFlow(system)
```
"""
function solvePowerFlow(system::PowerSystem)
    dc = system.dcModel
    bus = system.bus

    slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftActivePower[i]
    end

    angle = dc.nodalMatrix \ b
    angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end

    @inbounds for (k, i) in enumerate(slackRange)
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = elementsRemove[k]
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
    end

    method = "DC Power Flow"

    return Result(
        BusResult(Polar(Float64[], angle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        DcPowerFlow(method)
        )
end


"""
The function verifies whether the generators in a power system exceed their reactive power
limits. This is done by setting the reactive power of the generators to within the limits if
they are violated, after determining the bus voltage magnitudes and angles. If the limits are
violated, the corresponding generator buses or the slack bus are converted to demand buses.

The function returns the `violate` variable to indicate which buses violate the limits,
with -1 indicating a violation of the minimum limits and 1 indicating a violation of the
maximum limits.

    reactivePowerLimit!(system::PowerSystem, result::Result)

Initially, if the [`generator!`](@ref generator!) function has not been run, it will be executed
to update the `generator` field of the `Result` type.

Afterward, the function uses the results from the `generator` field to assign values to the
`generator.output.active` and `bus.supply.active` fields of the `System` type.

At the end of the process, the function inspects the reactive powers of the generator and
adjusts them to their maximum or minimum values if they violate the threshold. The
`generator.output.reactive` field of the `System` type is then modified accordingly. In
light of this modification, the `bus.supply.reactive` field of the `System` type is also
updated, and the bus types in `bus.layout.type` are adjusted. If the slack bus is
converted, the `bus.layout.slack` field is modified accordingly.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

violate = reactivePowerLimit!(system, result)

result = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end
```
"""
function reactivePowerLimit!(system::PowerSystem, result::Result)
    bus = system.bus
    generator = system.generator

    power = result.generator.power
    errorVoltage(result.bus.voltage.magnitude)

    violate = fill(0, generator.number)
    if isempty(power.reactive)
        generator!(system, result)
    end

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        if generator.layout.status[k] == 1
            generator.output.active[k] = power.active[k]
            bus.supply.active[i] += power.active[k]
            bus.supply.reactive[i] += power.reactive[k]
        end
    end

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 && (generator.capability.minReactive[i] < generator.capability.maxReactive[i])
            j = generator.layout.bus[i]

            violateMinimum = power.reactive[i] < generator.capability.minReactive[i]
            violateMaximum = power.reactive[i] > generator.capability.maxReactive[i]
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

                bus.supply.reactive[j] -= result.generator.power.reactive[i]
                generator.output.reactive[i] = newReactivePower
                bus.supply.reactive[j] += newReactivePower

                if j == bus.layout.slack
                    for k = 1:bus.number
                        if bus.layout.type[k] == 2
                            @info("The slack bus $(trunc(Int, bus.label[j])) is converted to generator bus (PQ), bus $(trunc(Int, bus.label[k])) is the new slack bus.")
                            bus.layout.slack = bus.label[k]
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
        As a result, there are no more generator buses left that can be considered as the new slack bus for the system."))
    end

    return violate
end

"""
The function modifies the bus voltage angles based on a different slack bus than the one
identified by the `bus.layout.slack` field. This function only updates the
`bus.voltage.angle` field of the `Result` type.

    adjustVoltageAngle!(system::PowerSystem, result::Result; slack)

For instance, if the reactive power of the generator exceeds the limit on the slack bus,
the [`reactivePowerLimit!`](@ref reactivePowerLimit!) function will change that bus to a
demand bus and designate the first generator bus in the sequence as the new slack bus. After
obtaining the updated AC power flow solution based on the new slack bus, it is possible to
adjust the voltage angles to align with the angle of the original slack bus. The `slack`
keyword specifies the bus label of the original slack bus.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

reactivePowerLimit!(system, result)

result = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, result)
    if all(stopping .< 1e-8)
        break
    end
    solvePowerFlow!(system, result)
end

adjustVoltageAngle!(system, result; slack = 1)
```
"""
function adjustVoltageAngle!(system::PowerSystem, result::Result; slack::T = system.bus.layout.slack)
    index = system.bus.label[slack]
    T = system.bus.voltage.angle[index] - result.bus.voltage.angle[index]
    @inbounds for i = 1:system.bus.number
        result.bus.voltage.angle[i] = result.bus.voltage.angle[i] + T
    end
end

######### Initialize AC Power Flow ##########
function initializeACPowerFlow(system::PowerSystem)
    magnitude = copy(system.bus.voltage.magnitude)
    angle = copy(system.bus.voltage.angle)

    @inbounds for i = 1:system.bus.number
        if system.bus.supply.inService[i] == 0 && system.bus.layout.type[i] == 2
            system.bus.layout.type[i] = 1
        end
    end

    @inbounds for (k, i) in enumerate(system.generator.layout.bus)
        if system.generator.layout.status[k] == 1 && system.bus.layout.type[i] != 1
            magnitude[i] = system.generator.voltage.magnitude[k]
        end
    end

    return magnitude, angle
end