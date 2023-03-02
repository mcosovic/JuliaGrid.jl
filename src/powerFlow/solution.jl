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

######### Iteration Loop ##########
mutable struct IterationLoop
    stopping::CartesianFloat
    number::Int64
end

######### Gauss-Seidel Struct ##########
mutable struct GaussSeidelVoltage
    complex::Array{ComplexF64,1}
    magnitude::Array{Float64,1}
end

mutable struct GaussSeidelIndex
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

mutable struct GaussSeidel
    voltage::GaussSeidelVoltage
    index::GaussSeidelIndex
    iteration::IterationLoop
    method::String
end

######### Newton-Raphson Struct ##########
mutable struct NewtonRaphsonIndex
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

mutable struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    index::NewtonRaphsonIndex
    iteration::IterationLoop
    method::String
end

######### Fast Newton-Raphson Struct ##########
mutable struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    lower::SparseMatrixCSC{Float64,Int64}
    upper::SparseMatrixCSC{Float64,Int64}
    right::Array{Int64,1}
    left::Array{Int64,1}
    scaling::Array{Float64,1}
end

mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    index::NewtonRaphsonIndex
    iteration::IterationLoop
    method::String
end

######### DC Power Flow Struct ##########
mutable struct DCAlgorithm
    method::String
end

######### Result Struct ##########
mutable struct Result
    bus::BusResult
    branch::BranchResult
    generator::GeneratorResult
    algorithm::Union{GaussSeidel, NewtonRaphson, FastNewtonRaphson, DCAlgorithm}
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

    pqIndex = fill(0, bus.number)
    pvpqIndex = similar(pqIndex)
    nonZeroElement = 0; pvpqNumber = 0; pqNumber = 0
    @inbounds for i = 1:bus.number
        if bus.supply.inService[i] == 0 && bus.layout.type[i] != 3
            bus.layout.type[i] = 1
        end

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

    voltageMagnitude = setGeneratorVoltageMagnitude(system)
    voltageAngle = copy(bus.voltage.angle)
    mismatch = fill(0.0, bus.number + pqNumber - 1)
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

            mismatch[pvpqIndex[i]] = voltageMagnitude[i] * I - bus.supply.active[i] + bus.demand.active[i]
            if bus.layout.type[i] == 1
                mismatch[pqIndex[i]] = voltageMagnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
            end
        end
    end

    jacobian = sparse(iIndex, jIndex, fill(0.0, nonZeroElement), bus.number + pqNumber - 1, bus.number + pqNumber - 1)

    method = "Newton-Raphson"

    return Result(
        BusResult(Polar(voltageMagnitude, voltageAngle),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        NewtonRaphson(jacobian, mismatch, Float64[], NewtonRaphsonIndex(pqIndex, pvpqIndex), IterationLoop(CartesianFloat(0.0, 0.0), 0), method)
        )
end

"""
The function updates the `bus.voltage` and `algorithm` fields of the `Result` composite 
type by computing the magnitudes and angles of bus voltages using the Newton-Raphson 
method.
    
    newtonRaphson!(system::PowerSystem, result::Result)
    
It is intended to be used within a for loop as it performs only one iteration of the 
Newton-Raphson method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = newtonRaphson(system)
stopping = result.algorithm.iteration.stopping
for i = 1:10
    newtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```
"""
function newtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    jacobian = result.algorithm.jacobian
    mismatch = result.algorithm.mismatch
    index = result.algorithm.index
    iteration = result.algorithm.iteration

    iteration.number += 1

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

    result.algorithm.increment = jacobian \ mismatch

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - result.algorithm.increment[index.pq[i]]
        end
        if i != bus.layout.slack
            voltage.angle[i] = voltage.angle[i] - result.algorithm.increment[index.pvpq[i]]
        end
    end

    iteration.stopping.active = 0.0
    iteration.stopping.reactive = 0.0
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
            iteration.stopping.active = max(iteration.stopping.active, abs(mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                mismatch[index.pq[i]] = voltage.magnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
                iteration.stopping.reactive = max(iteration.stopping.reactive, abs(mismatch[index.pq[i]]))
            end
        end
    end
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

    pqIndex = fill(0, bus.number)
    pvpqIndex = similar(pqIndex)
    nonZeroElementActive = 0; nonZeroElementReactive = 0; pvpqNumber = 0; pqNumber = 0
    @inbounds for i = 1:bus.number
        if bus.supply.inService[i] == 0 && bus.layout.type[i] != 3
            bus.layout.type[i] = 1
        end

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

    voltageMagnitude = setGeneratorVoltageMagnitude(system)
    voltageAngle = copy(bus.voltage.angle)

    mismatchActive = fill(0.0, bus.number - 1)
    iIndexActive = fill(0, nonZeroElementActive); jIndexActive = similar(iIndexActive)
    iIndexReactive = fill(0, nonZeroElementReactive); jIndexReactive = similar(iIndexReactive)
    countActive = 1; countReactive = 1
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            mismatchActive[pvpqIndex[i]] = - (bus.supply.active[i] - bus.demand.active[i]) / voltageMagnitude[i]
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltageAngle[i] - voltageAngle[row]

                mismatchActive[pvpqIndex[i]] += voltageMagnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))

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

    mismatchReactive = fill(0.0, pqNumber)

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
            FastNewtonRaphsonModel(jacobianActive, mismatchActive, Float64[], lowerActive, upperActive, rightActive, leftActive, scalingActive),
            FastNewtonRaphsonModel(jacobianReactive, mismatchReactive, Float64[], lowerReactive, upperReactive, rightReactive, leftReactive, scalingReactive),
            NewtonRaphsonIndex(pqIndex, pvpqIndex),
            IterationLoop(CartesianFloat(0.0, 0.0), 0), method)
        )
end

"""
The function updates the `bus.voltage` and `algorithm` fields of the `Result` composite 
type by computing the magnitudes and angles of bus voltages using the fast Newton-Raphson 
method.

    fastNewtonRaphson!(system::PowerSystem, result::Result)

It is intended to be used within a for loop as it performs only one iteration of the 
fast Newton-Raphson method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = fastNewtonRaphsonBX(system)
stopping = result.algorithm.iteration.stopping
for i = 1:100
    fastNewtonRaphson!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```
"""
function fastNewtonRaphson!(system::PowerSystem, result::Result)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    active = result.algorithm.active
    reactive = result.algorithm.reactive
    index = result.algorithm.index
    iteration = result.algorithm.iteration

    iteration.number += 1

    active.increment = active.upper \ (active.lower \ ((active.scaling .* active.mismatch)[active.right]))
    active.increment = active.increment[active.left]
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

    reactive.increment = reactive.upper \ (reactive.lower \ ((reactive.scaling .* reactive.mismatch)[reactive.right]))
    reactive.increment = reactive.increment[reactive.left]
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] += reactive.increment[index.pq[i]]
        end
    end

    iteration.stopping.active = 0.0
    iteration.stopping.reactive = 0.0
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

            iteration.stopping.active = max(iteration.stopping.active, abs(active.mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                reactive.mismatch[index.pq[i]] = C - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
                iteration.stopping.reactive = max(iteration.stopping.reactive, abs(reactive.mismatch[index.pq[i]]))
            end
        end
    end
end

"""
The function accepts the `PowerSystem` composite type as input, uses it to set up the 
Gauss-Seidel method, and then produces the `Result` composite type as output.
        
    gaussSeidel(system::PowerSystem)
        
The `algorithm` field of the `Result` type is updated during the function's execution.  
"""
function gaussSeidel(system::PowerSystem)
    bus = system.bus

    voltageMagnitude = setGeneratorVoltageMagnitude(system)
    voltage = zeros(ComplexF64, bus.number)
    pqIndex = Int64[]
    pvIndex = Int64[]
    @inbounds for i = 1:bus.number
        voltage[i] = voltageMagnitude[i] * exp(im * bus.voltage.angle[i])

        if bus.supply.inService[i] == 0 && bus.layout.type[i] != 3
            bus.layout.type[i] = 1
        end
        if bus.layout.type[i] == 1
            push!(pqIndex, i)
        end
        if bus.layout.type[i] == 2
            push!(pvIndex, i)
        end
    end

    method = "Gauss-Seidel"

    return Result(
        BusResult(Polar(voltageMagnitude, copy(bus.voltage.angle)),
            BusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[])),
            BusCurrent(Polar(Float64[], Float64[]))),
        BranchResult(
            BranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            BranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        GeneratorResult(Cartesian(Float64[], Float64[])),
        GaussSeidel(GaussSeidelVoltage(voltage, copy(voltageMagnitude)), GaussSeidelIndex(pqIndex, pvIndex), IterationLoop(CartesianFloat(0.0, 0.0), 0), method)
        )
end

"""
The function updates the `bus.voltage` and `algorithm` fields of the `Result` composite 
type by computing the magnitudes and angles of bus voltages using the Gauss-Seidel method.

    gaussSeidel!(system::PowerSystem, result::Result)

It is intended to be used within a for loop as it performs only one iteration of the 
Gauss-Seidel method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

result = gaussSeidel(system)
stopping = result.algorithm.iteration.stopping
for i = 1:1000
    gaussSeidel!(system, result)
    if stopping.active < 1e-8 && stopping.reactive < 1e-8
        break
    end
end
```
"""
function gaussSeidel!(system::PowerSystem, result::Result)
    ac = system.acModel

    voltage = result.algorithm.voltage
    index = result.algorithm.index
    iteration = result.algorithm.iteration

    iteration.number += 1

    @inbounds for i in index.pq
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] - im * (system.bus.supply.reactive[i] - system.bus.demand.reactive[i])
        I = injection / conj(voltage.complex[i])
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I -= ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        voltage.complex[i] += I / ac.nodalMatrix[i, i]
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
    end

    iteration.stopping.active = 0.0
    iteration.stopping.reactive = 0.0
    @inbounds for i in index.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        apparent = voltage.complex[i] * conj(I)

        mismatchActive = real(apparent) - system.bus.supply.active[i] + system.bus.demand.active[i]
        iteration.stopping.active = max(iteration.stopping.active, abs(mismatchActive))

        mismatchReactive = imag(apparent) - system.bus.supply.reactive[i] + system.bus.demand.reactive[i]
        iteration.stopping.reactive = max(iteration.stopping.reactive, abs(mismatchReactive))

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end
    @inbounds for i in index.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        mismatchActive = real(voltage.complex[i] * conj(I)) - system.bus.supply.active[i] + system.bus.demand.active[i]
        iteration.stopping.active = max(iteration.stopping.active, abs(mismatchActive))

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end
end

"""
The function takes a `PowerSystem` composite type as input and uses it to solve the DC 
power flow problem by calculating the voltage angles for each bus. 
    
    dcPowerFlow(system::PowerSystem)
    
The function returns a composite type `Result` as output, which includes updated 
`bus.voltage.angle` and `algorithm` fields. These fields are modified during the execution 
of the function.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

result = dcPowerFlow(system)
```
"""
function dcPowerFlow(system::PowerSystem)
    dc = system.dcModel
    bus = system.bus
    slack = bus.layout.slack

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
        DCAlgorithm(method)
        )
end

######### Set Voltage Magnitude Values According to Generators ##########
function setGeneratorVoltageMagnitude(system::PowerSystem)
    magnitude = copy(system.bus.voltage.magnitude)
    
    @inbounds for (k, i) in enumerate(system.generator.layout.bus)
        if system.generator.layout.status[k] == 1
            magnitude[i] = system.generator.voltage.magnitude[k]
        end
    end

    return magnitude
end