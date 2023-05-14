abstract type ACPowerFlow end

######### Newton-Raphson ##########
struct NewtonRaphson <: ACPowerFlow
    voltage::Polar
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

######### Fast Newton-Raphson ##########
struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::Factorization
end

struct FastNewtonRaphson <: ACPowerFlow
    voltage::Polar
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

######### Gauss-Seidel ##########
struct GaussSeidel <: ACPowerFlow
    voltage::Polar
    complex::Array{ComplexF64,1}
    magnitude::Array{Float64,1}
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

######### DC Power Flow ##########
struct DCPowerFlow
    voltage::PolarAngle
    factorization::Union{Factorization, Diagonal}
end

######### Export ##########
export NewtonRaphson, FastNewtonRaphson, GaussSeidel, ACPowerFlow
export DCPowerFlow

"""
    newtonRaphson(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the
Newton-Raphson method to solve AC power flow. Additionally, if the AC model was not created,
the function will automatically initiate an update of the `acModel` field within the `PowerSystem`
composite type.

# Returns
The function returns an instance of the `NewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the magnitudes and angles of bus voltages
- `jacobian`: the Jacobian matrix
- `mismatch`: the active and reactive power injection mismatches
- `increment`: the magnitudes and angles of bus voltage increments
- `pq`: indices of demand buses
- `pvpq`: indices of demand and generator buses.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
```
"""
function newtonRaphson(system::PowerSystem)
    ac = system.acModel
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

    return NewtonRaphson(
        Polar(voltageMagnitude, voltageAngle),
        jacobian, mismatch, increment, pqIndex, pvpqIndex)
end

"""
    fastNewtonRaphsonBX(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the Fast
Newton-Raphson method of version BX to solve AC power flow. Additionally, if the AC model was
not created, the function will automatically initiate an update of the `acModel` field within
the `PowerSystem` composite type.

# Returns
The function returns an instance of the `FastNewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the magnitudes and angles of bus voltages
- `active`:
  - `jacobian`: the Jacobian matrix associated with active power equations
  - `mismatch`: the active power injection mismatches
  - `increment`: the angles of bus voltage increments
  - `factorization`: the factorized Jacobian matrix
- `reactive`:
  - `jacobian`: the Jacobian matrix associated with reactive power equations
  - `mismatch`: the reative power injection mismatches
  - `increment`: the magnitudes of bus voltage increments
  - `factorization`: the factorized Jacobian matrix
- `pq`: indices of demand buses
- `pvpq`: indices of demand and generator buses.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = fastNewtonRaphsonBX(system)
```
"""
function fastNewtonRaphsonBX(system::PowerSystem)
    algorithmBX = 1
    model = fastNewtonRaphson(system, algorithmBX)

    return model
end

"""
    fastNewtonRaphsonXB(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the Fast
Newton-Raphson method of version XB to solve AC power flow. Additionally, if the AC model was
not created, the function will automatically initiate an update of the `acModel` field within
the `PowerSystem` composite type.

# Returns
The function returns an instance of the `FastNewtonRaphson` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the magnitudes and angles of bus voltages
- `active`:
  - `jacobian`: the Jacobian matrix associated with active power equations
  - `mismatch`: the active power injection mismatches
  - `increment`: the angles of bus voltage increments
  - `factorization`: the factorized Jacobian matrix
- `reactive`:
  - `jacobian`: the Jacobian matrix associated with reactive power equations
  - `mismatch`: the reative power injection mismatches
  - `increment`: the magnitudes of bus voltage increments
  - `factorization`: the factorized Jacobian matrix
- `pq`: indices of demand buses
- `pvpq`: indices of demand and generator buses.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = fastNewtonRaphsonXB(system)
```
"""
function fastNewtonRaphsonXB(system::PowerSystem)
    algorithmXB = 2
    model = fastNewtonRaphson(system, algorithmXB)

    return model
end

@inline function fastNewtonRaphson(system::PowerSystem, algorithmFlag::Int64)
    ac = system.acModel
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
    icrementReactive = fill(0.0, pqNumber)
    icrementActive = fill(0.0, bus.number - 1)

    if algorithmFlag == 1
        method = "Fast Newton-Raphson BX"
    else
        method = "Fast Newton-Raphson XB"
    end

    return FastNewtonRaphson(
        Polar(voltageMagnitude, voltageAngle),
        FastNewtonRaphsonModel(jacobianActive, mismatchActive, icrementActive, factorisationActive),
        FastNewtonRaphsonModel(jacobianReactive, mismatchReactive, icrementReactive, factorisationReactive),
        pqIndex, pvpqIndex)
end

"""
    gaussSeidel(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input and uses it to set up the
Gauss-Seidel method to solve AC power flow. Additionally, if the AC model was not created, the
function will automatically initiate an update of the `acModel` field within the `PowerSystem`
composite type.

# Returns
The function returns an instance of the `GaussSeidel` subtype of the abstract `ACPowerFlow`
type, which includes the following fields:
- `voltage`: the magnitudes and angles of bus voltages
- `complex`: the complex voltages
- `magnitude`: the bus voltage magnitudes for corrections
- `pq`: indices of demand buses
- `pv`: indices of generator buses.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = gaussSeidel(system)
```
"""
function gaussSeidel(system::PowerSystem)
    bus = system.bus

    if isempty(system.acModel.nodalMatrix)
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
        voltage, copy(voltageMagnitude), pqIndex, pvIndex)
end

"""
    mismatch!(system::PowerSystem, model::Method) where Method <: ACPowerFlow

The function calculates both active and reactive power injection mismatches and returns their
maximum absolute values, which can be utilized to terminate the iteration loop of methods
employed to solve the AC power flow problem.

This function updates the mismatch variables in the Newton-Raphson and fast Newton-Raphson
methods. It should be employed during the iteration loop before invoking the
[`solve!`](@ref solve!) function.

In contrast, the Gauss-Seidel method does not need mismatches to obtain bus voltages, but the
maximum absolute values are commonly employed to stop the iteration loop. The function does not
save any data and should be utilized during the iteration loop before invoking the
[`solve!`](@ref solve!) function.

# Subtypes
The `ACPowerFlow` abstract type can take the following subtypes:
- `NewtonRaphson`: computes the power mismatches within the Newton-Raphson method
- `FastNewtonRaphson`: computes the power mismatches within the fast Newton-Raphson method
- `GaussSeidel`: computes the power mismatches within the Gauss-Seidel method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
mismatch!(system, model)
```
"""
function mismatch!(system::PowerSystem, model::NewtonRaphson)
    ac = system.acModel
    bus = system.bus

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
                Tij = model.voltage.angle[i] - model.voltage.angle[row]

                I += model.voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                if bus.layout.type[i] == 1
                    C += model.voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end

            model.mismatch[model.pvpq[i]] = model.voltage.magnitude[i] * I - bus.supply.active[i] + bus.demand.active[i]
            stopActive = max(stopActive, abs(model.mismatch[model.pvpq[i]]))
            if bus.layout.type[i] == 1
                model.mismatch[model.pq[i]] = model.voltage.magnitude[i] * C - bus.supply.reactive[i] + bus.demand.reactive[i]
                stopReactive = max(stopReactive, abs(model.mismatch[model.pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatch!(system::PowerSystem, model::FastNewtonRaphson)
    ac = system.acModel
    bus = system.bus

    voltage = model.voltage
    active = model.active
    reactive = model.reactive

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            active.mismatch[model.pvpq[i]] = - (bus.supply.active[i] - bus.demand.active[i]) / voltage.magnitude[i]
            C = 0.0
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                active.mismatch[model.pvpq[i]] += voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                if bus.layout.type[i] == 1
                    C += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
                end
            end

            stopActive = max(stopActive, abs(active.mismatch[model.pvpq[i]]))
            if bus.layout.type[i] == 1
                reactive.mismatch[model.pq[i]] = C - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
                stopReactive = max(stopReactive, abs(reactive.mismatch[model.pq[i]]))
            end
        end
    end

    return stopActive, stopReactive
end

function mismatch!(system::PowerSystem, model::GaussSeidel)
    ac = system.acModel

    stopActive = 0.0
    stopReactive = 0.0
    @inbounds for i in model.pq
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * model.complex[ac.nodalMatrix.rowval[j]]
        end
        apparent = model.complex[i] * conj(I)

        mismatchActive = real(apparent) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))

        mismatchReactive = imag(apparent) - system.bus.supply.reactive[i] + system.bus.demand.reactive[i]
        stopReactive = max(stopReactive, abs(mismatchReactive))
    end

    @inbounds for i in model.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * model.complex[ac.nodalMatrix.rowval[j]]
        end
        mismatchActive = real(model.complex[i] * conj(I)) - system.bus.supply.active[i] + system.bus.demand.active[i]
        stopActive = max(stopActive, abs(mismatchActive))
    end

    return stopActive, stopReactive
end


"""
    solve!(system::PowerSystem, model::Method) where Method <: ACPowerFlow

The function employs the Newton-Raphson, fast Newton-Raphson, or Gauss-Seidel method to solve
the AC power flow problem and calculate the magnitudes and angles of bus voltages.

After the [`mismatch!`](@ref mismatch!) function is called, [`solve!`](@ref solve!) should be
executed to perform a single iteration of the method. The calculated voltages are stored in the
`voltage` field of the respective struct type.

# Subtypes
The `ACPowerFlow` abstract type can take the following subtypes:
- `NewtonRaphson`: computes the bus voltages within the Newton-Raphson method
- `FastNewtonRaphson`: computes the bus voltages within the fast Newton-Raphson method
- `GaussSeidel`: computes the bus voltages within the Gauss-Seidel method.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```
"""
function solve!(system::PowerSystem, model::NewtonRaphson)
    ac = system.acModel
    bus = system.bus

    voltage = model.voltage
    jacobian = model.jacobian
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
                        jacobian[model.pvpq[row], model.pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (Gij * sin(Tij) - Bij * cos(Tij))
                        if typeRow == 1
                            jacobian[model.pq[row], model.pvpq[i]] = voltage.magnitude[row] * voltage.magnitude[i] * (-Gij * cos(Tij) - Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1
                            jacobian[model.pvpq[row], model.pq[i]] = voltage.magnitude[row] * (Gij * cos(Tij) + Bij * sin(Tij))
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[model.pq[row], model.pq[i]] = voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
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
                        jacobian[model.pvpq[row], model.pvpq[i]] = voltage.magnitude[row] * I1 - Bij * voltage.magnitude[row]^2
                        if typeRow == 1
                            jacobian[model.pq[row], model.pvpq[i]] = voltage.magnitude[row] * I2 - Gij * voltage.magnitude[row]^2
                        end
                        if bus.layout.type[i] == 1
                            jacobian[model.pvpq[row], model.pq[i]] = I2 + Gij * voltage.magnitude[row]
                        end
                        if bus.layout.type[i] == 1 && typeRow == 1
                            jacobian[model.pq[row], model.pq[i]] = -I1 - Bij * voltage.magnitude[row]
                        end
                    end
                end
            end
        end
    end

    ldiv!(model.increment, lu(jacobian), model.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] = voltage.magnitude[i] - model.increment[model.pq[i]]
        end
        if i != bus.layout.slack
            voltage.angle[i] = voltage.angle[i] - model.increment[model.pvpq[i]]
        end
    end
end

function solve!(system::PowerSystem, model::FastNewtonRaphson)
    ac = system.acModel
    bus = system.bus

    voltage = model.voltage
    active = model.active
    reactive = model.reactive

    ldiv!(active.increment, active.factorization, active.mismatch)

    @inbounds for i = 1:bus.number
        if i != bus.layout.slack
            voltage.angle[i] += active.increment[model.pvpq[i]]
        end
    end

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            reactive.mismatch[model.pq[i]] = - (bus.supply.reactive[i] - bus.demand.reactive[i]) / voltage.magnitude[i]
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                row = ac.nodalMatrix.rowval[j]
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])
                Tij = voltage.angle[i] - voltage.angle[row]

                reactive.mismatch[model.pq[i]] += voltage.magnitude[row] * (Gij * sin(Tij) - Bij * cos(Tij))
            end
        end
    end

    ldiv!(reactive.increment, reactive.factorization, reactive.mismatch)

    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 1
            voltage.magnitude[i] += reactive.increment[model.pq[i]]
        end
    end
end

function solve!(system::PowerSystem, model::GaussSeidel)
    ac = system.acModel

    @inbounds for i in model.pq
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] - im * (system.bus.supply.reactive[i] - system.bus.demand.reactive[i])
        I = injection / conj(model.complex[i])
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I -= ac.nodalMatrixTranspose.nzval[j] * model.complex[ac.nodalMatrix.rowval[j]]
        end
        model.complex[i] += I / ac.nodalMatrix[i, i]

        model.voltage.magnitude[i] = abs(model.complex[i])
        model.voltage.angle[i] = angle(model.complex[i])
    end

    @inbounds for i in model.pv
        I = 0.0 + im * 0.0
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            I += ac.nodalMatrixTranspose.nzval[j] * model.complex[ac.nodalMatrix.rowval[j]]
        end
        conjVoltage = conj(model.complex[i])
        injection = system.bus.supply.active[i] - system.bus.demand.active[i] + im * imag(conjVoltage * I)
        model.complex[i] += ((injection / conjVoltage) - I) / ac.nodalMatrix[i, i]
    end

    @inbounds for i in model.pv
        model.complex[i] = model.magnitude[i] * model.complex[i] / abs(model.complex[i])

        model.voltage.magnitude[i] = abs(model.complex[i])
        model.voltage.angle[i] = angle(model.complex[i])
    end
end

"""
    reactiveLimit!(system::PowerSystem, model::ACPowerFlow, power::PowerGenerator)

The function verifies whether the generators in a power system exceed their reactive power
limits. This is done by setting the reactive power of the generators to within the limits
if they are violated, after determining the bus voltage magnitudes and angles. If the
limits are violated, the corresponding generator buses or the slack bus are converted to
demand buses.

# Arguments
Initially, the [`analysisGenerator`](@ref analysisGenerator) function must be executed.
Afterward, the function uses the results from this function to assign values to the
`generator.output.active` and `bus.supply.active` fields of the `PowerSystem` type.

At the end of the process, the function inspects the reactive powers of the generator and
adjusts them to their maximum or minimum values if they violate the threshold. The
`generator.output.reactive` field of the `PowerSystem` type is then modified accordingly. In
light of this modification, the `bus.supply.reactive` field of the `PowerSystem` type is also
updated, and the bus types in `bus.layout.type` are adjusted. If the slack bus is
converted, the `bus.layout.slack` field is modified accordingly.

# Returns
The function returns the `violate` variable to indicate which buses violate the limits,
with -1 indicating a violation of the minimum limits and 1 indicating a violation of the
maximum limits.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
power = analysisGenerator(system, model)

violate = reactiveLimit!(system, model, power)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
```
"""
function reactiveLimit!(system::PowerSystem, model::ACPowerFlow, power::PowerGenerator)
    bus = system.bus
    generator = system.generator

    errorVoltage(model.voltage.magnitude)

    violate = fill(0, generator.number)

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

                bus.supply.reactive[j] -= power.reactive[i]
                generator.output.reactive[i] = newReactivePower
                bus.supply.reactive[j] += newReactivePower

                if j == bus.layout.slack
                    for k = 1:bus.number
                        if bus.layout.type[k] == 2
                            @info("The slack bus $(trunc(Int, bus.label[j])) is converted to generator bus, bus $(trunc(Int, bus.label[k])) is the new slack bus.")
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
        As a analysis, there are no more generator buses left that can be considered as the new slack bus for the system."))
    end

    return violate
end

"""
    adjustAngle!(system::PowerSystem, model::ACPowerFlow; slack)

The function modifies the bus voltage angles based on a different slack bus than the one
identified by the `bus.layout.slack` field. This function only updates the `voltage.angle`
variable of the `Model` composite type.

For instance, if the reactive power of the generator exceeds the limit on the slack bus,
the [`reactiveLimit!`](@ref reactiveLimit!) function will change that bus to the demand bus
and designate the first generator bus in the sequence as the new slack bus. After obtaining
the updated AC power flow solution based on the new slack bus, it is possible to adjust the
voltage angles to align with the angle of the original slack bus. The `slack` keyword
specifies the bus label of the original slack bus.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end
power = analysisGenerator(system, model)

reactiveLimit!(system, model, power)

model = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, model)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, model)
end

adjustAngle!(system, model; slack = 1)
```
"""
function adjustAngle!(system::PowerSystem, model::ACPowerFlow; slack::T = system.bus.layout.slack)
    index = system.bus.label[slack]
    T = system.bus.voltage.angle[index] - model.voltage.angle[index]
    @inbounds for i = 1:system.bus.number
        model.voltage.angle[i] = model.voltage.angle[i] + T
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

"""
    dcPowerFlow(system::PowerSystem)

The function accepts the `PowerSystem` composite type as input, which is utilized to establish
the structure for solving the DC power flow. Additionally, if the DC model was not created, the
function will automatically initiate an update of the `dcModel` field within the `PowerSystem`
composite type.

# Returns
The function returns an instance of the `DCPowerFlow` type, which includes the following filled
fields:
- `voltage`: the angles of bus voltages
- `factorization`: the factorized nodal matrix.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
```
"""
function dcPowerFlow(system::PowerSystem)
    dc = system.dcModel
    bus = system.bus

    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end

    slackRange = dc.nodalMatrix.colptr[bus.layout.slack]:(dc.nodalMatrix.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = dc.nodalMatrix.nzval[slackRange]
    @inbounds for i in slackRange
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = 0.0
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = 0.0
    end
    dc.nodalMatrix[bus.layout.slack, bus.layout.slack] = 1.0

    factorization = factorize(dc.nodalMatrix)
    @inbounds for (k, i) in enumerate(slackRange)
        dc.nodalMatrix[dc.nodalMatrix.rowval[i], bus.layout.slack] = elementsRemove[k]
        dc.nodalMatrix[bus.layout.slack, dc.nodalMatrix.rowval[i]] = elementsRemove[k]
    end

    return DCPowerFlow(PolarAngle(Float64[]), factorization)
end

"""
    solve!(system::PowerSystem, model::DCPowerFlow)

By computing the voltage angles for each bus, the function solves the DC power flow problem.
The resulting voltage angles are stored in the `voltage` field of the `DCPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

model = dcPowerFlow(system)
solve!(system, model)
```
"""
function solve!(system::PowerSystem, model::DCPowerFlow)
    bus = system.bus

    b = copy(bus.supply.active)
    @inbounds for i = 1:bus.number
        b[i] -= bus.demand.active[i] + bus.shunt.conductance[i] + system.dcModel.shiftActivePower[i]
    end

    model.voltage.angle = model.factorization \ b
    model.voltage.angle[bus.layout.slack] = 0.0

    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            model.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end
end