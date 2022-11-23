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
mutable struct ACBusPower
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
end

mutable struct ACBus
    voltage::Polar
    power::ACBusPower
end

######### Branch Struct ##########
mutable struct ACBranchPower
    fromBus::Cartesian
    toBus::Cartesian
    shunt::CartesianImag
    loss::Cartesian
end

mutable struct ACBranchCurrent
    fromBus::Polar
    toBus::Polar
    impedance::Polar
end

mutable struct ACBranch
    power::ACBranchPower
    current::ACBranchCurrent
end

######### Generator ##########
mutable struct ACGenerator
    power::Cartesian
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
end

mutable struct ACPowerFlow
    bus::ACBus
    branch::ACBranch
    generator::ACGenerator
    algorithm::Union{GaussSeidel, NewtonRaphson, FastNewtonRaphson}
    mismatch::CartesianFloat
    iteration::Int64
end

######### Gauss-Seidel Model ##########
function gaussSeidel(system::PowerSystem)
    bus = system.bus

    voltageMagnitude = generatorVoltageMagnitude(system)
    voltage = zeros(ComplexF64, bus.number)
    pqIndex = Int64[]
    pvIndex = Int64[]
    @inbounds for i = 1:bus.number
        voltage[i] = voltageMagnitude[i] * exp(im * bus.voltage.angle[i])

        if bus.layout.type[i] == 1
            push!(pqIndex, i)
        end
        if bus.layout.type[i] == 2
            push!(pvIndex, i)
        end
    end

    return ACPowerFlow(
        ACBus(Polar(voltageMagnitude, copy(bus.voltage.angle)),
            ACBusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))),
        ACBranch(
            ACBranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            ACBranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        ACGenerator(Cartesian(Float64[], Float64[])),
        GaussSeidel(GaussSeidelVoltage(voltage, copy(voltageMagnitude)), GaussSeidelIndex(pqIndex, pvIndex)),
        CartesianFloat(0.0, 0.0), 0)
end

######### Gauss-Seidel Algorithm ##########
function gaussSeidel!(system::PowerSystem, result::ACPowerFlow)
    ac = system.acModel

    voltage = result.algorithm.voltage
    index = result.algorithm.index

    result.iteration += 1

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

    result.mismatch.active = 0.0
    result.mismatch.reactive = 0.0
    @inbounds for i in index.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        apparent = voltage.complex[i] * conj(I)

        mismatchActive = real(apparent) - system.bus.supply.active[i] + system.bus.demand.active[i]
        result.mismatch.active = max(result.mismatch.active, abs(mismatchActive))

        mismatchReactive = imag(apparent) - system.bus.supply.reactive[i] + system.bus.demand.reactive[i]
        result.mismatch.reactive = max(result.mismatch.reactive, abs(mismatchReactive))

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end
    @inbounds for i in index.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * voltage.complex[ac.nodalMatrix.rowval[j]]
        end
        mismatchActive = real(voltage.complex[i] * conj(I)) - system.bus.supply.active[i] + system.bus.demand.active[i]
        result.mismatch.active = max(result.mismatch.active, abs(mismatchActive))

        result.bus.voltage.magnitude[i] = abs(voltage.complex[i])
        result.bus.voltage.angle[i] = angle(voltage.complex[i])
    end
end

######### Newton-Raphson Model ##########
function newtonRaphson(system::PowerSystem)
    ac = system.acModel
    bus = system.bus

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

    voltageMagnitude = generatorVoltageMagnitude(system)
    voltageAngle = copy(bus.voltage.angle)
    mismatch = fill(0.0, bus.number + pqNumber - 1)
    iIndex = fill(0, nonZeroElement)
    jIndex = similar(iIndex)
    count = 1
    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
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

    return ACPowerFlow(
        ACBus(Polar(voltageMagnitude, voltageAngle),
            ACBusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))),
        ACBranch(
            ACBranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            ACBranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        ACGenerator(Cartesian(Float64[], Float64[])),
        NewtonRaphson(jacobian, mismatch, Float64[], NewtonRaphsonIndex(pqIndex, pvpqIndex)),
        CartesianFloat(0.0, 0.0), 0)
end

######### Newton-Raphson Algorithm ##########
function newtonRaphson!(system::PowerSystem, result::ACPowerFlow)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    jacobian = result.algorithm.jacobian
    mismatch = result.algorithm.mismatch
    increment = result.algorithm.increment
    index = result.algorithm.index

    result.iteration += 1

    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                typeRow = bus.layout.type[row]

                if typeRow != 3
                    I1 = 0.0; I2 = 0.0
                    Gij = real(ac.nodalMatrix.nzval[j])
                    Bij = imag(ac.nodalMatrix.nzval[j])
                    if row != i
                        Tij = voltage.angle[row] - voltage.angle[i]
                        jacobian[index.pvpq[row], index.pvpq[i]] =  voltage.magnitude[row] * voltage.magnitude[i] * (Gij * sin(Tij) - Bij * cos(Tij))
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

    increment = jacobian \ mismatch

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - increment[index.pq[i]]
        end
        if i != bus.layout.slackIndex
            voltage.angle[i] = voltage.angle[i] - increment[index.pvpq[i]]
        end
    end

    result.mismatch.active = 0.0
    result.mismatch.reactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
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
            result.mismatch.active = max(result.mismatch.active, abs(mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                mismatch[index.pq[i]] = voltage.magnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
                result.mismatch.reactive = max(result.mismatch.reactive, abs(mismatch[index.pq[i]]))
            end
        end
    end
end

######### Fast Newton-Raphson Algorithm BX ##########
@inbounds function fastNewtonRaphsonBX(system::PowerSystem)
    algorithmBX = 1
    result = fastNewtonRaphson(system, algorithmBX)

    return result
end

######### Fast Newton-Raphson Algorithm XB ##########
@inbounds function fastNewtonRaphsonXB(system::PowerSystem)
    algorithmXB = 2
    result = fastNewtonRaphson(system, algorithmXB)

    return result
end

######### Fast Newton-Raphson Model ##########
function fastNewtonRaphson(system::PowerSystem, algorithmFlag::Int64)
    ac = system.acModel
    bus = system.bus
    branch = system.branch

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

    voltageMagnitude = generatorVoltageMagnitude(system)
    voltageAngle = copy(bus.voltage.angle)

    mismatchActive = fill(0.0, bus.number - 1)
    iIndexActive = fill(0, nonZeroElementActive); jIndexActive = similar(iIndexActive)
    iIndexReactive = fill(0, nonZeroElementReactive); jIndexReactive = similar(iIndexReactive)
    countActive = 1; countReactive = 1
    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
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
            if from != bus.layout.slackIndex && to != bus.layout.slackIndex
                jacobianActive[m, n] += (-gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
                jacobianActive[n, m] += (gmk * shiftsin - bmk * shiftcos) / (shiftcos^2 + shiftsin^2)
            end
            if from != bus.layout.slackIndex
                jacobianActive[m, m] += bmk / (shiftcos^2 + shiftsin^2)
            end
            if to != bus.layout.slackIndex
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

    return ACPowerFlow(
        ACBus(Polar(voltageMagnitude, voltageAngle),
            ACBusPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))),
        ACBranch(
            ACBranchPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), CartesianImag(Float64[]), Cartesian(Float64[], Float64[])),
            ACBranchCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))),
        ACGenerator(Cartesian(Float64[], Float64[])),
        FastNewtonRaphson(
            FastNewtonRaphsonModel(jacobianActive, mismatchActive, Float64[], lowerActive, upperActive, rightActive, leftActive, scalingActive),
            FastNewtonRaphsonModel(jacobianReactive, mismatchReactive, Float64[], lowerReactive, upperReactive, rightReactive, leftReactive, scalingReactive),
            NewtonRaphsonIndex(pqIndex, pvpqIndex)),
        CartesianFloat(0.0, 0.0), 0)
end

######### Fast Newton-Raphson Algorithm ##########
@inline function fastNewtonRaphson!(system::PowerSystem, result::ACPowerFlow)
    ac = system.acModel
    bus = system.bus

    voltage = result.bus.voltage
    active = result.algorithm.active
    reactive = result.algorithm.reactive
    index = result.algorithm.index

    result.iteration += 1

    active.increment = active.upper \ (active.lower \ ((active.scaling .* active.mismatch)[active.right]))
    active.increment = active.increment[active.left]
    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
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

    result.mismatch.active = 0.0
    result.mismatch.reactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slackIndex
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

            result.mismatch.active = max(result.mismatch.active, abs(active.mismatch[index.pvpq[i]]))
            if bus.layout.type[i] == 1
                reactive.mismatch[index.pq[i]] = C - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
                result.mismatch.reactive = max(result.mismatch.reactive, abs(reactive.mismatch[index.pq[i]]))
            end
        end
    end
end

######### Branch Results ##########
function branch!(system::PowerSystem, result::ACPowerFlow)
    ac = system.acModel

    voltage = result.bus.voltage
    current = result.branch.current
    power = result.branch.power
    errorVoltage(voltage.magnitude)

    power.fromBus.active = fill(0.0, system.branch.number)
    power.fromBus.reactive = fill(0.0, system.branch.number)
    power.toBus.active = fill(0.0, system.branch.number)
    power.toBus.reactive = fill(0.0, system.branch.number)
    power.shunt.reactive = fill(0.0, system.branch.number)
    power.loss.active = fill(0.0, system.branch.number)
    power.loss.reactive = fill(0.0, system.branch.number)

    current.fromBus.magnitude = fill(0.0, system.branch.number)
    current.fromBus.angle = fill(0.0, system.branch.number)
    current.toBus.magnitude = fill(0.0, system.branch.number)
    current.toBus.angle = fill(0.0, system.branch.number)
    current.impedance.magnitude = fill(0.0, system.branch.number)
    current.impedance.angle = fill(0.0, system.branch.number)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            f = system.branch.layout.from[i]
            t = system.branch.layout.to[i]

            voltageFrom = voltage.magnitude[f] * exp(im * voltage.angle[f])
            voltageTo = voltage.magnitude[t] * exp(im * voltage.angle[t])

            currentFromBus = voltageFrom * ac.nodalFromFrom[i] + voltageTo * ac.nodalFromTo[i]
            current.fromBus.magnitude[i] = abs(currentFromBus)
            current.fromBus.angle[i] = angle(currentFromBus)

            currentToBus = voltageFrom * ac.nodalToFrom[i] + voltageTo * ac.nodalToTo[i]
            current.toBus.magnitude[i] = abs(currentToBus)
            current.toBus.angle[i] = angle(currentToBus)

            currentImpedance = ac.admittance[i] * (voltageFrom / ac.transformerRatio[i] - voltageTo)
            current.impedance.magnitude[i] = abs(currentImpedance)
            current.impedance.angle[i] = angle(currentImpedance)

            powerFromBus = voltageFrom * conj(currentFromBus)
            power.fromBus.active[i] = real(powerFromBus)
            power.fromBus.reactive[i] = imag(powerFromBus)

            powerToBus = voltageTo * conj(currentToBus)
            power.toBus.active[i] = real(powerToBus)
            power.toBus.reactive[i] = imag(powerToBus)

            power.shunt.reactive[i] = 0.5 * system.branch.parameter.susceptance[i] * (abs(voltageFrom / ac.transformerRatio[i])^2 +  voltage.magnitude[t]^2)

            power.loss.active[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.resistance[i]
            power.loss.reactive[i] = current.impedance.magnitude[i]^2 * system.branch.parameter.reactance[i]
        end
    end
end

######### Bus Results ##########
function bus!(system::PowerSystem, result::ACPowerFlow)
    ac = system.acModel
    slack = system.bus.layout.slackIndex

    voltage = result.bus.voltage
    power = result.bus.power
    errorVoltage(voltage.magnitude)

    power.injection.active = fill(0.0, system.bus.number)
    power.injection.reactive = fill(0.0, system.bus.number)

    power.supply.active = fill(0.0, system.bus.number)
    power.supply.reactive = fill(0.0, system.bus.number)

    power.shunt.active = fill(0.0, system.bus.number)
    power.shunt.reactive = fill(0.0, system.bus.number)

    @inbounds for i = 1:system.bus.number
        voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

        powerShunt = voltageBus * conj(voltageBus * (system.bus.shunt.susceptance[i] + im * system.bus.shunt.susceptance[i]))
        power.shunt.active[i] = real(powerShunt)
        power.shunt.reactive[i] = imag(powerShunt)

        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            I += conj(ac.nodalMatrixTranspose.nzval[j]) * conj(voltage.magnitude[k] * exp(im * voltage.angle[k]))
        end
        powerInjection = I * voltageBus
        power.injection.active[i] = real(powerInjection)
        power.injection.reactive[i] = imag(powerInjection)


        power.supply.active[i] = system.bus.supply.active[i]
        if system.bus.layout.type[i] != 1
            power.supply.reactive[i] = system.bus.supply.reactive[i] + system.bus.demand.reactive[i] + power.injection.reactive[i]
        else
            power.supply.reactive[i] = system.bus.supply.reactive[i]
        end
    end
    power.supply.active[slack] = power.injection.active[slack] + system.bus.demand.active[slack]
end

######### Generator Results ##########
function generator!(system::PowerSystem, result::ACPowerFlow)
        ac = system.acModel

        voltage = result.bus.voltage
        power = result.generator.power
        errorVoltage(voltage.magnitude)

        power.active = fill(0.0, system.generator.number)
        power.reactive = fill(0.0, system.generator.number)
        isMultiple = false
        for i in system.generator.layout.bus
            if system.bus.supply.inService[i] > 1
                isMultiple = true
                break
            end
        end

        if isempty(result.bus.power.injection.active)
            injectionActive = fill(0.0, system.bus.number)
            injectionReactive = fill(0.0, system.bus.number)

            @inbounds for i = 1:system.bus.number
                voltageBus = voltage.magnitude[i] * exp(im * voltage.angle[i])

                I = 0.0 + im * 0.0
                for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                    k = ac.nodalMatrix.rowval[j]
                    I += conj(ac.nodalMatrixTranspose.nzval[j]) * conj(voltage.magnitude[k] * exp(im * voltage.angle[k]))
                end
                powerInjection = I * voltageBus
                injectionActive[i] = real(powerInjection)
                injectionReactive[i] = imag(powerInjection)
            end
        else
            injectionActive = result.bus.power.injection.active
            injectionReactive = result.bus.power.injection.reactive
        end

        if !isMultiple
            @inbounds for i = 1:system.generator.number
                if system.generator.layout.status[i] == 1
                    j = system.generator.layout.bus[i]
                    power.active[i] = system.generator.output.active[i]
                    power.reactive[i] = injectionReactive[j] + system.bus.demand.reactive[j]
                    if j == system.bus.layout.slackIndex
                        power.active[i] = injectionActive[j] + system.bus.demand.active[j]
                    end
                end
            end
        end

        if isMultiple
            Qmintotal = fill(0.0, system.bus.number)
            Qmaxtotal = fill(0.0, system.bus.number)
            QminInf = fill(0.0, system.bus.number)
            QmaxInf = fill(0.0, system.bus.number)
            QminNew = copy(system.generator.capability.minReactive)
            QmaxNew = copy(system.generator.capability.maxReactive)
            Qgentotal = fill(0.0, system.bus.number)

            @inbounds for i = 1:system.generator.number
                if system.generator.layout.status[i] == 1
                    j = system.generator.layout.bus[i]
                    if !isinf(system.generator.capability.minReactive[i])
                        Qmintotal[j] += system.generator.capability.minReactive[i]
                    end
                    if !isinf(system.generator.capability.maxReactive[i])
                        Qmaxtotal[j] += system.generator.capability.maxReactive[i]
                    end
                    Qgentotal[j] += (injectionReactive[j] + system.bus.demand.reactive[j]) / system.bus.supply.inService[j]
                end
            end
            @inbounds for i = 1:system.generator.number
                if system.generator.layout.status[i] == 1
                    j = system.generator.layout.bus[i]
                    if system.generator.capability.minReactive[i] == Inf
                        QminInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                    end
                    if system.generator.capability.minReactive[i] == -Inf
                        QminInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                    end
                    if system.generator.capability.maxReactive[i] == Inf
                        QmaxInf[i] = abs(Qgentotal[j]) + abs(Qmintotal[j]) + abs(Qmaxtotal[j])
                    end
                    if system.generator.capability.maxReactive[i] == -Inf
                        QmaxInf[i] = -abs(Qgentotal[j]) - abs(Qmintotal[j]) - abs(Qmaxtotal[j])
                    end
                end
            end
            @inbounds for i = 1:system.generator.number
                if system.generator.layout.status[i] == 1
                    j = system.generator.layout.bus[i]
                    if isinf(system.generator.capability.minReactive[i])
                        Qmintotal[j] += QminInf[i]
                        QminNew[i] = QminInf[i]
                    end
                    if isinf(system.generator.capability.maxReactive[i])
                        Qmaxtotal[j] += QmaxInf[i]
                        QmaxNew[i] =  QmaxInf[i]
                    end
                end
            end

            tempSlack = 0
            @inbounds for i = 1:system.generator.number
                if system.generator.layout.status[i] == 1
                    j = system.generator.layout.bus[i]
                    if 1e-6 * system.basePower * abs(Qmintotal[j] - Qmaxtotal[j]) > 10 * eps(Float64)
                        power.reactive[i] = QminNew[i] + ((Qgentotal[j] - Qmintotal[j]) / (Qmaxtotal[j] - Qmintotal[j])) * (QmaxNew[i] - QminNew[i])
                    else
                        power.reactive[i] = QminNew[i] + (Qgentotal[j] - Qmintotal[j]) / system.bus.supply.inService[j]
                    end

                    power.active[i] = system.generator.output.active[i]
                    if j == system.bus.layout.slackIndex
                        if tempSlack != 0
                            power.active[tempSlack] -= power.active[i]
                        end
                        if tempSlack == 0
                            power.active[i] = injectionActive[j] + system.bus.demand.active[j]
                            tempSlack = i
                        end
                    end
                end
            end
        end
    end

######### Check Reactive Power Limits ##########
function reactivePowerLimit!(system::PowerSystem, result::ACPowerFlow)
    bus = system.bus
    generator = system.generator

    power = result.generator.power
    errorVoltage(result.bus.voltage.magnitude)

    generator.layout.violate = fill(0, generator.number)
    if isempty(power.reactive)
        generator!(system, result)
    end

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        if generator.layout.status[k] == 1
            bus.supply.active[i] += power.active[k]
            bus.supply.reactive[i] += power.reactive[k]
        end
    end

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            violateMinimum = power.reactive[i] < generator.capability.minReactive[i]
            violateMaximum = power.reactive[i] > generator.capability.maxReactive[i]
            if generator.layout.violate[i] == 0 && (violateMinimum || violateMaximum)
                if violateMinimum
                    generator.layout.violate[i] = -1
                    newReactivePower = generator.capability.minReactive[i]
                end
                if violateMaximum
                    generator.layout.violate[i] = 1
                    newReactivePower = generator.capability.maxReactive[i]
                end
                j = generator.layout.bus[i]
                bus.layout.type[j] = 1

                bus.supply.reactive[j] -= result.generator.power.reactive[i]
                generator.output.reactive[i] = newReactivePower
                bus.supply.reactive[j] += newReactivePower

                if j == bus.layout.slackIndex
                    for k = 1:bus.number
                        if bus.layout.type[k] == 2
                            @info("The slack bus $(trunc(Int, bus.label[j])) is converted to PQ bus, bus $(trunc(Int, bus.label[k])) is the new slack bus.")
                            bus.layout.slackIndex = bus.label[k]
                            bus.layout.type[k] = 3
                            break
                        end
                    end
                end
            end
        end
    end
end

######### Adjust Voltage Angle According to Original Slack Bus ##########
function adjustVoltageAngle!(system::PowerSystem, result::ACPowerFlow)
    T = system.bus.voltage.angle[system.bus.layout.slackImmutable] - result.bus.voltage.angle[system.bus.layout.slackImmutable]
    @inbounds for i = 1:system.bus.number
        result.bus.voltage.angle[i] = result.bus.voltage.angle[i] + T
    end
end

######### Set Voltage Magnitude Values According to Generators ##########
function generatorVoltageMagnitude(system::PowerSystem)
    magnitude = copy(system.bus.voltage.magnitude)
    @inbounds for (k, i) in enumerate(system.generator.layout.bus)
        if system.generator.layout.status[k] == 1
            magnitude[i] = system.generator.voltage.magnitude[k]
        end
    end

    return magnitude
end