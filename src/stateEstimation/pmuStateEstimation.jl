"""
    pmuWlsStateEstimation(system::PowerSystem, device::Measurement, method)

The function establishes the linear WLS model for state estimation with PMUs only. In this
model, the vector of state variables contains bus voltages, given in rectangular
coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish
the WLS state estimation model.

Moreover, the presence of the `method` parameter is not mandatory. To address the WLS
state estimation method, users can opt to utilize factorization techniques to decompose
the gain matrix, such as `LU`, `QR`, or `LDLt` especially when the gain matrix is symmetric.
Opting for the `Orthogonal` method is advisable for a more robust solution in scenarios
involving ill-conditioned data, particularly when substantial variations in variances are
present.

If the user does not provide the `method`, the default method for solving the estimation
model will be LU factorization.

# Updates
If the AC model has not been created, the function will automatically trigger an update of
the `ac` field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the `PMUStateEstimation` abstract type, which includes
the following fields:
- `voltage`: The variable allocated to store the bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `method`: The system model vectors and matrices.

# Examples
Set up the PMU state estimation model to be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuWlsStateEstimation(system, device)
```

Set up the PMU state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuWlsStateEstimation(system, device, Orthogonal)
```
"""
function pmuWlsStateEstimation(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    coefficient, mean, precision, power, current, _ = pmuStateEstimationWLS(system, device)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return PMUStateEstimation(
        Polar(Float64[], Float64[]),
        power,
        current,
        LinearWLS{Normal}(
            coefficient,
            precision,
            mean,
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            2 * device.pmu.number,
            -1,
            true,
        )
    )
end

function pmuWlsStateEstimation(system::PowerSystem, device::Measurement, method::Type{<:Orthogonal})
    coefficient, mean, precision, power, current, correlated = pmuStateEstimationWLS(system, device)

    if correlated
        throw(ErrorException("The precision matrix is non-diagonal, therefore preventing the use of the orthogonal method."))
    end

    return PMUStateEstimation(
        Polar(Float64[], Float64[]),
        power,
        current,
        LinearWLS{Orthogonal}(
            coefficient,
            precision,
            mean,
            qr(sparse(Matrix(1.0I, 1, 1))),
            2 * device.pmu.number,
            -1,
            true,
        )
    )
end

function pmuStateEstimationWLS(system::PowerSystem, device::Measurement)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    pmu = device.pmu
    correlated = false

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    nonZeroElement = 0
    nonZeroPrecision = 0
    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            nonZeroElement += 2
        else
            nonZeroElement += 8
        end

        if pmu.layout.correlated[i]
            nonZeroPrecision += 4
        else
            nonZeroPrecision += 2
        end
    end

    rowCoeff = fill(0, nonZeroElement)
    colCoeff = similar(rowCoeff)
    coeff = fill(0.0, nonZeroElement)
    mean = fill(0.0, 2 * pmu.number)

    rowPrec = fill(0, nonZeroPrecision)
    colPrec = similar(rowPrec)
    valPrec = fill(0.0, nonZeroPrecision)

    count = 1
    rowindex = 1
    cntPrec = 1
    @inbounds for (i, k) in enumerate(pmu.layout.index)
        cosAngle = cos(pmu.angle.mean[i])
        sinAngle = sin(pmu.angle.mean[i])

        varianceRe = pmu.magnitude.variance[i] * cosAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * sinAngle)^2
        varianceIm = pmu.magnitude.variance[i] * sinAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * cosAngle)^2

        if pmu.layout.correlated[i]
            correlated = true
            covariance = sinAngle * cosAngle * (pmu.magnitude.variance[i] - pmu.angle.variance[i] * pmu.magnitude.mean[i]^2)
            rowPrec, colPrec, valPrec, cntPrec = invCovarianceBlock(rowPrec, colPrec, valPrec, cntPrec, varianceRe, varianceIm, covariance, rowindex)
        else
            rowPrec[cntPrec] = rowindex
            colPrec[cntPrec] = rowindex
            valPrec[cntPrec] = 1 / varianceRe

            rowPrec[cntPrec + 1] = rowindex + 1
            colPrec[cntPrec + 1] = rowindex + 1
            valPrec[cntPrec + 1] = 1 / varianceIm

            cntPrec += 2
        end

        if pmu.layout.bus[i]
            rowCoeff[count] = rowindex
            colCoeff[count] = pmu.layout.index[i]
            rowCoeff[count + 1] = rowindex + 1
            colCoeff[count + 1] = pmu.layout.index[i] + bus.number
            if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
                coeff[count] = 1.0
                coeff[count + 1] = 1.0

                mean[rowindex] = pmu.magnitude.mean[i] * cosAngle
                mean[rowindex + 1] = pmu.magnitude.mean[i] * sinAngle
            else
                coeff[count:(count + 1)] .= 0.0
                mean[rowindex:(rowindex + 1)] .= 0.0
            end
            count += 2
            rowindex += 2
        else
            rowCoeff[count] = rowindex
            colCoeff[count] = branch.layout.from[k]
            rowCoeff[count + 1] = rowindex + 1
            colCoeff[count + 1] = branch.layout.from[k] + bus.number

            rowCoeff[count + 2] = rowindex;
            colCoeff[count + 2] = branch.layout.to[k]
            rowCoeff[count + 3] = rowindex + 1
            colCoeff[count + 3] = branch.layout.to[k] + bus.number

            rowCoeff[count + 4] = rowindex
            colCoeff[count + 4] = branch.layout.from[k] + bus.number
            rowCoeff[count + 5] = rowindex + 1
            colCoeff[count + 5] = branch.layout.from[k]

            rowCoeff[count + 6] = rowindex
            colCoeff[count + 6] = branch.layout.to[k] + bus.number
            rowCoeff[count + 7] = rowindex + 1
            colCoeff[count + 7] = branch.layout.to[k]

            if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
                gij = real(ac.admittance[k])
                bij = imag(ac.admittance[k])
                bsi = 0.5 * branch.parameter.susceptance[k]
                gsi = 0.5 * branch.parameter.conductance[k]
                cosShift = cos(branch.parameter.shiftAngle[k])
                sinShift = sin(branch.parameter.shiftAngle[k])
                turnsRatioInv = 1 / branch.parameter.turnsRatio[k]

                if pmu.layout.from[i]
                    coeff[count] = turnsRatioInv^2 * (gij + gsi)
                    coeff[count + 1] = coeff[count]

                    coeff[count + 2] = -turnsRatioInv * (gij * cosShift - bij * sinShift)
                    coeff[count + 3] = coeff[count + 2]

                    coeff[count + 4] = -turnsRatioInv^2 * (bij + bsi)
                    coeff[count + 5] = -coeff[count + 4]

                    coeff[count + 6] = turnsRatioInv * (bij * cosShift + gij * sinShift)
                    coeff[count + 7] = -coeff[count + 6]
                else
                    coeff[count] = -turnsRatioInv * (gij * cosShift + bij * sinShift)
                    coeff[count + 1] = coeff[count]

                    coeff[count + 2] = gij + gsi
                    coeff[count + 3] = coeff[count + 2]

                    coeff[count + 4] = turnsRatioInv * (bij * cosShift - gij * sinShift)
                    coeff[count + 5] = -coeff[count + 4]

                    coeff[count + 6] = -bij - bsi
                    coeff[count + 7] = -coeff[count + 6]
                end

                mean[rowindex] = pmu.magnitude.mean[i] * cosAngle
                mean[rowindex + 1] = pmu.magnitude.mean[i] * sinAngle
            else
                coeff[count:(count + 7)] .= 0.0
                mean[rowindex:(rowindex + 1)] .= 0.0
            end
            count += 8
            rowindex += 2
        end
    end

    coefficient = sparse(rowCoeff, colCoeff, coeff, 2 * pmu.number, 2 * bus.number)
    precision = sparse(rowPrec, colPrec, valPrec, 2 * pmu.number, 2 * pmu.number)

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), nothing)
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    return coefficient, mean, precision, power, current, correlated
end

"""
    pmuLavStateEstimation(system::PowerSystem, device::Measurement, optimizer)

The function establishes the LAV model for state estimation with PMUs only. In this
model, the vector of state variables contains bus voltages, given in rectangular
coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish
the LAV state estimation model. The LAV method offers increased robustness compared
to WLS, ensuring unbiasedness even in the presence of various measurement errors and
outliers.

Users can employ the LAV method to find an estimator by choosing one of the available
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically,
`Ipopt.Optimizer` suffices for most scenarios.

# Updates
If the AC model has not been created, the function will automatically trigger an update of
the `ac` field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the `PMUStateEstimation` abstract type, which includes
the following fields:
- `voltage`: The variable allocated to store the bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `method`: The optimization model.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function pmuLavStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    measureNumber = 2 * pmu.number

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    statex = @variable(jump, 0 <= statex[i = 1:2 * bus.number])
    statey = @variable(jump, 0 <= angley[i = 1:2 * bus.number])
    residualx = @variable(jump, 0 <= residualx[i = 1:measureNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:measureNumber])

    objective = @expression(jump, AffExpr())
    residual = Dict{Int64, JuMP.ConstraintRef}()
    count = 1
    @inbounds for (i, k) in enumerate(pmu.layout.index)
        if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
            if pmu.layout.bus[i]
                cosAngle = cos(pmu.angle.mean[i])
                sinAngle = sin(pmu.angle.mean[i])

                busIndex = pmu.layout.index[i]
                add_to_expression!(objective, residualx[count] + residualy[count] + residualx[count + 1] + residualy[count + 1])
                residual[count] = @constraint(jump, statex[busIndex] - statey[busIndex] + residualx[count] - residualy[count] - pmu.magnitude.mean[i] * cosAngle == 0.0)
                residual[count + 1] = @constraint(jump, statex[busIndex + bus.number] - statey[busIndex + bus.number] + residualx[count + 1] - residualy[count + 1] - pmu.magnitude.mean[i] * sinAngle == 0.0)
            else
                add_to_expression!(objective, residualx[count] + residualy[count] + residualx[count + 1] + residualy[count + 1])

                gij = real(ac.admittance[k])
                bij = imag(ac.admittance[k])
                bsi = 0.5 * branch.parameter.susceptance[k]
                cosShift = cos(branch.parameter.shiftAngle[k])
                sinShift = sin(branch.parameter.shiftAngle[k])
                turnsRatioInv = 1 / branch.parameter.turnsRatio[k]

                from = branch.layout.from[k]
                to = branch.layout.to[k]

                Vrei = statex[from] - statey[from]
                Vimi = statex[from + bus.number] - statey[from + bus.number]
                Vrej = statex[to] - statey[to]
                Vimj = statex[to + bus.number] - statey[to + bus.number]

                cosAngle = cos(pmu.angle.mean[i])
                sinAngle = sin(pmu.angle.mean[i])

                if pmu.layout.from[i]
                    a1 = turnsRatioInv^2 * gij
                    a2 = -turnsRatioInv^2 * (bij + bsi)
                    a3 = -turnsRatioInv * (gij * cosShift - bij * sinShift)
                    a4 = turnsRatioInv * (bij * cosShift + gij * sinShift)

                    residual[count] = @constraint(jump, a1 * Vrei + a2 * Vimi + a3 * Vrej + a4 * Vimj + residualx[count] - residualy[count] - pmu.magnitude.mean[i] * cosAngle == 0.0)
                    residual[count + 1] = @constraint(jump, -a2 * Vrei + a1 * Vimi - a4 * Vrej + a3 * Vimj + residualx[count + 1] - residualy[count + 1] - pmu.magnitude.mean[i] * sinAngle == 0.0)
                else
                    a1 = -turnsRatioInv * (gij * cosShift + bij * sinShift)
                    a2 = turnsRatioInv * (bij * cosShift - gij * sinShift)
                    a3 = gij
                    a4 = -bij - bsi

                    residual[count] = @constraint(jump, a1 * Vrei + a2 * Vimi + a3 * Vrej + a4 * Vimj + residualx[count] - residualy[count] - pmu.magnitude.mean[i] * cosAngle == 0.0)
                    residual[count + 1] = @constraint(jump, -a2 * Vrei + a1 * Vimi - a4 * Vrej + a3 * Vimj + residualx[count + 1] - residualy[count + 1] - pmu.magnitude.mean[i] * sinAngle == 0.0)
                end
            end
        else
            fix(residualx[count], 0.0; force = true)
            fix(residualy[count], 0.0; force = true)
            fix(residualx[count + 1], 0.0; force = true)
            fix(residualy[count + 1], 0.0; force = true)
        end
        count += 2
    end

    @objective(jump, Min, objective)

    return PMUStateEstimation(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        ACPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            nothing
        ),
        ACCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        LAV(
            jump,
            statex,
            statey,
            residualx,
            residualy,
            residual,
            pmu.number
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::PMUStateEstimation)

By computing the bus voltage magnitudes and angles, the function solves the PMU state
estimation model.

# Updates
The resulting bus voltage magnitudes and angles are stored in the `voltage` field of the
`PMUStateEstimation` type.

# Examples
Solving the PMU state estimation model and obtaining the WLS estimator:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuWlsStateEstimation(system, device)
solve!(system, analysis)
```

Solving the PMU state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuLavStateEstimation(system, device, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::PMUStateEstimation{LinearWLS{Normal}})
    se = analysis.method
    bus = system.bus

    gain = transpose(se.coefficient) * se.precision * se.coefficient

    if analysis.method.pattern == -1
        analysis.method.pattern = 0
        se.factorization = sparseFactorization(gain, se.factorization)
    else
        se.factorization = sparseFactorization!(gain, se.factorization)
    end
    b = transpose(se.coefficient) * se.precision * se.mean

    voltageRectangular = sparseSolution(fill(0.0, 2 * bus.number), b, se.factorization)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        voltage = complex(voltageRectangular[i], voltageRectangular[i + bus.number])
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end
end

########### PMU State Estimation WLS Solution by QR Factorization ###########
function solve!(system::PowerSystem, analysis::PMUStateEstimation{LinearWLS{Orthogonal}})
    se = analysis.method
    bus = system.bus

    @inbounds for i = 1:se.number
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    coefficientScale = se.precision * se.coefficient
    se.factorization = sparseFactorization(coefficientScale, se.factorization)
    voltageRectangular = sparseSolution(fill(0.0, 2 * bus.number), se.precision * se.mean, se.factorization)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        voltage = complex(voltageRectangular[i], voltageRectangular[i + bus.number])
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end

    @inbounds for i = 1:se.number
        se.precision.nzval[i] ^= 2
    end
end

function solve!(system::PowerSystem, analysis::PMUStateEstimation{LAV})
    se = analysis.method
    bus = system.bus

    @inbounds for i = 1:system.bus.number
        JuMP.set_start_value(se.statex[i]::JuMP.VariableRef, analysis.voltage.magnitude[i] * cos(analysis.voltage.angle[i]))
        JuMP.set_start_value(se.statex[i + bus.number]::JuMP.VariableRef, analysis.voltage.magnitude[i] * sin(analysis.voltage.angle[i]))
    end

    JuMP.optimize!(se.jump)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        voltageReal = value(se.statex[i]::JuMP.VariableRef) - value(se.statey[i]::JuMP.VariableRef)
        voltageImag = value(se.statex[i + bus.number]::JuMP.VariableRef) - value(se.statey[i + bus.number]::JuMP.VariableRef)
        voltage = complex(voltageReal, voltageImag)
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end
end

"""
    pmuPlacement(system::PowerSystem, optimizer; bridge)

The function determines the optimal placement of PMUs through integer linear programming.
Specifically, it identifies the minimum set of PMU locations required for effective power
system state estimation, ensuring observability with the least number of PMUs.

The function accepts a `PowerSystem` composite type as input to establish the framework
for finding the optimal PMU placement. If the `ac` field within the `PowerSystem`
composite type is not yet created, the function automatically initiates an update process.

Additionally, the `optimizer` argument is a crucial component for formulating and solving
the optimization problem. Typically, using the GLPK or HiGHS solver is sufficient. For
more detailed information, please refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keyword
The `bridge` keyword enables users to manage the bridging mechanism within the JuMP
package.

# Returns
The function returns an instance of the `PlacementPMU` type, containing variables such as:
* `bus`: Bus labels with indices marking the positions of PMUs at buses.
* `from`: Branch labels with indices marking the positions of PMUs at from-bus ends.
* `to`: Branch labels with indices marking the positions of PMUs at to-bus ends.

Note that if the conventional understanding of a PMU involves a device measuring the bus
voltage phasor and all branch current phasors incident to the bus, the result is saved
only in the bus variable. However, if we consider that a PMU measures individual phasors,
each described with magnitude and angle, then measurements are needed at each bus in the
`bus` variable, and each branch with positions given according to `from` and `to`
variables.

# Example
```jldoctest
using GLPK, Ipopt

system = powerSystem("case14.h5")
device = measurement()

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

placement = pmuPlacement(system, GLPK.Optimizer)

@pmu(label = "PMU ?: !")
for (bus, i) in placement.bus
    Vi, θi = analysis.voltage.magnitude[i], analysis.voltage.angle[i]
    addPmu!(system, device; bus = bus, magnitude = Vi, angle = θi)
end
for branch in keys(placement.from)
    Iij, ψij = fromCurrent(system, analysis; label = branch)
    addPmu!(system, device; from = branch, magnitude = Iij, angle = ψij)
end
for branch in keys(placement.to)
    Iji, ψji = toCurrent(system, analysis; label = branch)
    addPmu!(system, device; to = branch, magnitude = Iji, angle = ψji)
end
```
"""
function pmuPlacement(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true)

    placementPmu = PlacementPMU(
        OrderedDict{String, Int64}(),
        OrderedDict{String, Int64}(),
        OrderedDict{String, Int64}()
    )

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    filledElements = nnz(ac.nodalMatrix)

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, false)

    placement = @variable(jump, 0 <= placement[i = 1:bus.number] <= 1, Int)

    dropzeros!(ac.nodalMatrix)

    if filledElements != nnz(ac.nodalMatrix)
        ac.pattern += 1
    end

    @inbounds for i = 1:bus.number
        angleJacobian = @expression(jump, AffExpr())
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            add_to_expression!(angleJacobian, placement[k])
        end
        @constraint(jump, angleJacobian >= 1)
    end

    @objective(jump, Min, sum(placement))
    optimize!(jump)

    @inbounds for i = 1:bus.number
        if value(placement[i]) == 1
            placementPmu.bus[iterate(bus.label, i)[1][1]] = i
            for j = 1:branch.number
                if branch.layout.status[j] == 1
                    if branch.layout.from[j] == i
                        placementPmu.from[iterate(system.branch.label, j)[1][1]] = j
                    end
                    if branch.layout.to[j] == i
                        placementPmu.to[iterate(system.branch.label, j)[1][1]] = j
                    end
                end
            end
        end
    end

    return placementPmu
end

function invCovarianceBlock(rowPrec::Array{Int64,1}, colPrec::Array{Int64,1}, valPrec::Array{Float64,1}, cntPrec::Int64, varianceRe::Float64, varianceIm::Float64, covariance::Float64, rowindex::Int64)
    L1inv = 1 / sqrt(varianceRe)
    L2 = covariance * L1inv
    L3inv2 = 1 / (varianceIm - L2^2)

    rowPrec[cntPrec] = rowindex
    colPrec[cntPrec] = rowindex + 1
    valPrec[cntPrec] = (- L2 * L1inv) * L3inv2

    rowPrec[cntPrec + 1] = rowindex + 1
    colPrec[cntPrec + 1] = rowindex
    valPrec[cntPrec + 1] = valPrec[cntPrec]

    rowPrec[cntPrec + 2] = rowindex
    colPrec[cntPrec + 2] = rowindex
    valPrec[cntPrec + 2] = (L1inv - L2 * valPrec[cntPrec]) * L1inv

    rowPrec[cntPrec + 3] = rowindex + 1
    colPrec[cntPrec + 3] = rowindex + 1
    valPrec[cntPrec + 3] = L3inv2

    cntPrec += 4

    return rowPrec, colPrec, valPrec, cntPrec
end