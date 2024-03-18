"""
    pmuWlsStateEstimation(system::PowerSystem, device::Measurement, method; correlated)

The function sets up the framework to solve the linear state estimation model with PMUs 
only, where the vector of state variables is given in rectangular coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish 
the PMU WLS state estimation framework. 

Moreover, the presence of the `method` parameter is not mandatory. It provides various 
approaches for addressing PMU state estimation. To address the WLS state estimation method, 
users can opt to utilize factorization techniques to decompose the gain matrix, such as 
`LU`, `QR`, or `LDLt`, especially when the gain matrix is symmetric. Opting for the 
`Orthogonal` method is advisable for a more robust solution in scenarios involving 
ill-conditioned data, particularly when substantial variations in variances are present.

If the `method` parameter is not provided, the default method for solving the PMU 
estimation will be LU factorization using the WLS framework.

# Keyword
The boolean keyword `correlated` defines the correlation between measurement errors of a 
single PMU.

When `correlated = false`, which is the default setting, the measurement errors of a 
single PMU are not correlated. This results in the covariance matrix maintaining a 
diagonal form. In this case, users can also run the `Orthogonal` method to find the 
estimate of state variables.
    
On the other hand, when `correlated = true`, the covariance matrix does not maintain a 
diagonal form. Instead, it becomes a block diagonal matrix due to the correlation between 
measurement errors, and in this case, the `Orthogonal` method is not allowed. Users can 
then use LU, QR, or LDLt factorization over the gain matrix to obtain the solution.

# Updates
If the AC model has not been created, the function will automatically trigger an update of 
the `ac` field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the `DCStateEstimation` abstract type, which includes 
the following fields:
- `voltage`: the variable allocated to store the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `method`: the system model vectors and matrices, or alternatively, the optimization model;
- `bad`: the variable linked to identifying bad data within the measurement set. 

# Examples
Set up the PMU state estimation WLS framework to be solved using the default LU factorization 
method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device)
```

Set up the PMU state estimation WLS framework to be solved using the default LU factorization 
method, where measurement errors are correlated:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device; correlated = true)
```

Set up the PMU state estimation WLS framework to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device, Orthogonal)
```
"""
function pmuWlsStateEstimation(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU; correlated = false)
    coefficient, mean, precision, badData, power, current = pmuStateEstimationWLS(system, device, correlated)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return PMUStateEstimationWLS(
        Polar(Float64[], Float64[]),
        power,
        current, 
        LinearWLS(
            coefficient,
            precision,
            mean,
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            2 * device.pmu.number,
            -1,
            true,
            correlated
        ),
        badData
    )
end

function pmuWlsStateEstimation(system::PowerSystem, device::Measurement, method::Type{<:Orthogonal})
    coefficient, mean, precision, badData, power, current = pmuStateEstimationWLS(system, device, false)

    return PMUStateEstimationWLS(
        Polar(Float64[], Float64[]),
        power,
        current,
        LinearOrthogonal(
            coefficient,
            precision,
            mean,
            qr(sparse(Matrix(1.0I, 1, 1))),
            2 * device.pmu.number,
            -1,
            true,
            false
        ),
        badData
    )
end

function pmuStateEstimationWLS(system::PowerSystem, device::Measurement, correlated::Bool)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    pmu = device.pmu

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    nonZeroElement = 0 
    for i = 1:pmu.number
        if pmu.layout.bus[i]
            nonZeroElement += 2
        else
            nonZeroElement += 8 
        end
    end

    row = fill(0, nonZeroElement) 
    col = similar(row)
    coeff = fill(0.0, nonZeroElement)
    mean = fill(0.0, 2 * pmu.number)

    if correlated
        temp = sparse([1.0 1.0; 1.0 1.0])
        precision = blockdiag([temp for _ in 1:pmu.number]...)
    else
        precision = spdiagm(0 => mean)
    end

    count = 1
    rowindex = 1
    for (i, k) in enumerate(pmu.layout.index)
        cosAngle = cos(pmu.angle.mean[i])
        sinAngle = sin(pmu.angle.mean[i])

        varianceRe = pmu.magnitude.variance[i] * cosAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * sinAngle)^2
        varianceIm = pmu.magnitude.variance[i] * sinAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * cosAngle)^2

        if correlated
            covariance = sinAngle * cosAngle * (pmu.magnitude.variance[i] - pmu.angle.variance[i] * pmu.magnitude.mean[i]^2)
            invCovarianceBlock!(precision, varianceRe, varianceIm, covariance, rowindex)
        else
            precision.nzval[rowindex] = 1 / varianceRe
            precision.nzval[rowindex + 1] = 1 / varianceIm
        end

        if pmu.layout.bus[i]
            row[count] = rowindex
            col[count] = pmu.layout.index[i]
            row[count + 1] = rowindex + 1
            col[count + 1] = pmu.layout.index[i] + bus.number
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
            row[count] = rowindex 
            col[count] = branch.layout.from[k]
            row[count + 1] = rowindex + 1 
            col[count + 1] = branch.layout.from[k] + bus.number

            row[count + 2] = rowindex;
            col[count + 2] = branch.layout.to[k]
            row[count + 3] = rowindex + 1
            col[count + 3] = branch.layout.to[k] + bus.number

            row[count + 4] = rowindex
            col[count + 4] = branch.layout.from[k] + bus.number
            row[count + 5] = rowindex + 1
            col[count + 5] = branch.layout.from[k]

            row[count + 6] = rowindex
            col[count + 6] = branch.layout.to[k] + bus.number
            row[count + 7] = rowindex + 1
            col[count + 7] = branch.layout.to[k]

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

    coefficient = sparse(row, col, coeff, 2 * pmu.number, 2 * bus.number)
    badData = BadData(true, 0.0, "", 0)
    power = PowerSE(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), 
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))
    current = Current(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))       

    return coefficient, mean, precision, badData, power, current
end


"""
    pmuLavStateEstimation(system::PowerSystem, device::Measurement, method)

The function sets up the framework to solve the linear state estimation model with PMUs 
only, where the vector of state variables is given in rectangular coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish 
the PMU LAV state estimation framework. The LAV method offers increased robustness 
compared to WLS, ensuring unbiasedness even in the presence of various measurement errors 
and outliers.
    
Users can employ the LAV method to find an estimator by choosing one of the available 
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically, 
`Ipopt.Optimizer` suffices for most scenarios.

# Updates
If the AC model has not been created, the function will automatically trigger an update of 
the `ac` field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the `DCStateEstimation` abstract type, which includes 
the following fields:
- `voltage`: the variable allocated to store the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `method`: the system model vectors and matrices, or alternatively, the optimization model;
- `bad`: the variable linked to identifying bad data within the measurement set. 

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function pmuLavStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    measureNumber = 2 * pmu.number

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    statex = @variable(jump, 0 <= statex[i = 1:2 * bus.number])
    statey = @variable(jump, 0 <= angley[i = 1:2 * bus.number])
    residualx = @variable(jump, 0 <= residualx[i = 1:measureNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:measureNumber])

    objective = @expression(jump, AffExpr())
    residual = Dict{Int64, JuMP.ConstraintRef}()
    count = 1
    for (i, k) in enumerate(pmu.layout.index)
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

    return PMUStateEstimationLAV(
        Polar(
            copy(system.bus.voltage.magnitude), 
            copy(system.bus.voltage.angle)
        ),
        PowerSE(
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
        LAVMethod(
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

This function computes the bus voltage magnitudes and angles to solve the state estimation 
problem exclusively using PMU data.

# Updates
The resulting bus voltage magnitudes and angles are stored in the `voltage` field of the 
`PMUStateEstimation` type.

# Examples
Solving the PMU state estimation model with WLS:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device)
solve!(system, analysis)
```

Solving the PMU state estimation model with LAV:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::PMUStateEstimationWLS{LinearWLS})
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

    for i = 1:bus.number
        voltage = complex(voltageRectangular[i], voltageRectangular[i + bus.number])
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end
end

########### PMU State Estimation WLS Solution by QR Factorization ###########
function solve!(system::PowerSystem, analysis::PMUStateEstimationWLS{LinearOrthogonal})
    se = analysis.method
    bus = system.bus

    for i = 1:se.number
        se.precision.nzval[i] = (se.precision.nzval[i])^(1/2)
    end

    coefficientScale = se.precision * se.coefficient
    se.factorization = sparseFactorization(coefficientScale, se.factorization)
    voltageRectangular = sparseSolution(fill(0.0, 2 * bus.number), se.precision * se.mean, se.factorization)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    for i = 1:bus.number
        voltage = complex(voltageRectangular[i], voltageRectangular[i + bus.number])
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end

    for i = 1:se.number
        se.precision.nzval[i] = se.precision.nzval[i]^2
    end
end

function solve!(system::PowerSystem, analysis::PMUStateEstimationLAV)
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

    for i = 1:bus.number
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
more detailed information, please refer to the JuMP 
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keyword
The `bridge` keyword enables users to manage the bridging mechanism within the JuMP 
package.

# Returns
The function returns an instance of the `PlacementPMU` type, containing variables such as:
* `bus`: bus labels with indices marking the positions of PMUs at buses;
* `from`: branch labels with indices marking the positions of PMUs at "from" bus ends;
* `to`: branch labels with indices marking the positions of PMUs at "to" bus ends.

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
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

V = analysis.voltage.magnitude
θ = analysis.voltage.angle
If = analysis.current.from.magnitude
ψf = analysis.current.from.angle
It = analysis.current.to.magnitude
ψt = analysis.current.to.angle

placement = pmuPlacement(system, GLPK.Optimizer)
device = measurement()

@pmu(label = "PMU ?: !")
for (label, i) in placement.bus
    addPmu!(system, device; bus = label, magnitude = V[i], angle = θ[i])
end
for (label, i) in placement.from
    addPmu!(system, device; from = label, magnitude = If[i], angle = ψf[i])
end
for (label, i) in placement.to
    addPmu!(system, device; to = label, magnitude = It[i], angle = ψt[i])
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

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, false)

    placement = @variable(jump, 0 <= placement[i = 1:bus.number] <= 1, Int)

    dropzeros!(ac.nodalMatrix)
    for i = 1:bus.number
        angleJacobian = @expression(jump, AffExpr())
        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            k = ac.nodalMatrix.rowval[j]
            add_to_expression!(angleJacobian, placement[k])
        end
        @constraint(jump, angleJacobian >= 1)
    end

    @objective(jump, Min, sum(placement))
    optimize!(jump)

    for i = 1:bus.number
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

function invCovarianceBlock!(precision::SparseMatrixCSC{Float64,Int64}, varianceRe::Float64, varianceIm::Float64, covariance::Float64, index::Int64)
    L1inv = 1 / sqrt(varianceRe)
    L2 = covariance * L1inv
    L3inv2 = 1 / (varianceIm - L2^2)

    precision[index, index + 1] = (- L2 * L1inv) * L3inv2
    precision[index + 1, index] = precision[index, index + 1]
    precision[index, index] = (L1inv - L2 * precision[index, index + 1]) * L1inv
    precision[index + 1, index + 1] = L3inv2
end