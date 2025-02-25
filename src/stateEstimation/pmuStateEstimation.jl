"""
    pmuStateEstimation(system::PowerSystem, device::Measurement, [method = LU])

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

analysis = pmuStateEstimation(system, device)
```

Set up the PMU state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = pmuStateEstimation(system, device, Orthogonal)
```
"""
function pmuStateEstimation(system::PowerSystem, device::Measurement,
    factorization::Type{<:Union{QR, LDLt, LU}} = LU)

    coeff, mean, precision, power, current, _ = pmuEstimationWls(system, device)

    PMUStateEstimation(
        Polar(
            Float64[],
            Float64[]
        ),
        power,
        current,
        LinearWLS{Normal}(
            coeff,
            precision,
            mean,
            factorized[factorization],
            2 * device.pmu.number,
            -1,
            true,
        )
    )
end

function pmuStateEstimation(
    system::PowerSystem,
    device::Measurement,
    ::Type{<:Orthogonal}
)
    coeff, mean, precision, power, current, correlated = pmuEstimationWls(system, device)

    if correlated
        throw(ErrorException(
            "The non-diagonal precision matrix prevents using the orthogonal method.")
        )
    end

    PMUStateEstimation(
        Polar(Float64[], Float64[]),
        power,
        current,
        LinearWLS{Orthogonal}(
            coeff,
            precision,
            mean,
            factorized[QR],
            2 * device.pmu.number,
            -1,
            true,
        )
    )
end

function pmuEstimationWls(system::PowerSystem, device::Measurement)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    pmu = device.pmu
    correlated = false

    model!(system, system.model.ac)

    nnzCff = 0
    nnzPcs = 0
    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            nnzCff += 2
        else
            nnzCff += 8
        end

        if pmu.layout.correlated[i]
            correlated = true
            nnzPcs += 4
        else
            nnzPcs += 2
        end
    end

    mean = fill(0.0, 2 * pmu.number)
    cff = SparseModel(fill(0, nnzCff), fill(0, nnzCff), fill(0.0, nnzCff), 1, 1)
    pcs = SparseModel(fill(0, nnzPcs), fill(0, nnzPcs), fill(0.0, nnzPcs), 1, 1)

    @inbounds for (i, k) in enumerate(pmu.layout.index)
        sinθ, cosθ = sincos(pmu.angle.mean[i])
        varRe, varIm = variancePmu(pmu, cosθ, sinθ, i)

        if pmu.layout.correlated[i]
            precision!(pcs, pmu, cosθ, sinθ, varRe, varIm, i)
        else
            precision!(pcs, varRe)
            precision!(pcs, varIm)
        end

        if pmu.layout.bus[i]
            if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
                mean[cff.idx] = pmu.magnitude.mean[i] * cosθ
                mean[cff.idx + 1] = pmu.magnitude.mean[i] * sinθ

                cff.val[cff.cnt] = 1.0
                cff.val[cff.cnt + 1] = 1.0
            end
            pmuIndices(cff, pmu.layout.index[i], pmu.layout.index[i] + bus.number)

            cff.idx += 2
        else
            if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
                mean[cff.idx] = pmu.magnitude.mean[i] * cosθ
                mean[cff.idx + 1] = pmu.magnitude.mean[i] * sinθ

                if pmu.layout.from[i]
                    p = ReImIijCoefficient(branch, ac, k)
                else
                    p = ReImIjiCoefficient(branch, ac, k)
                end
                cff.val[cff.cnt] = cff.val[cff.cnt + 1] = p.A
                cff.val[cff.cnt + 2] = cff.val[cff.cnt + 3] = p.C
                cff.val[cff.cnt + 4] = p.B
                cff.val[cff.cnt + 6] = p.D
                cff.val[cff.cnt + 5] = -p.B
                cff.val[cff.cnt + 7] = -p.D
            end

            pmuIndices(cff, branch.layout.from[k], branch.layout.from[k] + bus.number)
            pmuIndices(cff, branch.layout.to[k], branch.layout.to[k] + bus.number)
            pmuIndices(cff, branch.layout.from[k] + bus.number, branch.layout.from[k])
            pmuIndices(cff, branch.layout.to[k] + bus.number, branch.layout.to[k])

            cff.idx += 2
        end
    end

    coefficient = sparse(cff.row, cff.col, cff.val, 2 * pmu.number, 2 * bus.number)
    precision = sparse(pcs.row, pcs.col, pcs.val, 2 * pmu.number, 2 * pmu.number)

    power = ACPower(
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[])
    )
    current = ACCurrent(
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[])
    )

    return coefficient, mean, precision, power, current, correlated
end

"""
    pmuLavStateEstimation(system::PowerSystem, device::Measurement, optimizer;
        bridge, name, print)

The function establishes the LAV model for state estimation with PMUs only. In this
model, the vector of state variables contains bus voltages, given in rectangular
coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish
the LAV state estimation model. The LAV method offers increased robustness compared
to WLS, ensuring unbiasedness even in the presence of various measurement errors and
outliers.

# Keywords
The function accepts the following keywords:
* `bridge`: controls the bridging mechanism (default: `false`),
* `name`: handles the creation of string names (default: `false`),
* `print`: controls solver output display (default: `true`).

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
function pmuLavStateEstimation(
    system::PowerSystem,
    device::Measurement,
    @nospecialize optimizerFactory;
    bridge::Bool = false,
    name::Bool = false,
    print::Bool = true,
)
    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    total = 2 * pmu.number

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    if !print
        JuMP.set_silent(jump)
    end

    method = LAV(
        jump,
        nothing,
        @variable(jump, 0 <= statex[i = 1:2 * bus.number]),
        @variable(jump, 0 <= statey[i = 1:2 * bus.number]),
        @variable(jump, 0 <= residualx[i = 1:total]),
        @variable(jump, 0 <= residualy[i = 1:total]),
        Dict{Int64, ConstraintRef}(),
        pmu.number
    )
    objective = @expression(method.jump, AffExpr())

    cnt = 1
    @inbounds for (i, k) in enumerate(pmu.layout.index)
        if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
            sinθ, cosθ = sincos(pmu.angle.mean[i])
            reMean = pmu.magnitude.mean[i] * cosθ
            imMean = pmu.magnitude.mean[i] * sinθ

            if pmu.layout.bus[i]
                reExpr, imExpr = ReImVi(method, pmu.layout.index[i], bus.number)
            else
                if pmu.layout.from[i]
                    state = ReImIijCoefficient(branch, ac, k)
                else
                    state = ReImIjiCoefficient(branch, ac, k)
                end
                reExpr, imExpr = ReImIij(system, method, state, k)
            end

            addConstrLav!(method, reExpr, reMean, cnt)
            addObjectLav!(method, objective, cnt)

            addConstrLav!(method, imExpr, imMean, cnt + 1)
            addObjectLav!(method, objective, cnt + 1)
        else
            fix!(method.residualx, method.residualy, cnt)
            fix!(method.residualx, method.residualy, cnt + 1)
        end
        cnt += 2
    end

    @objective(method.jump, Min, objective)

    PMUStateEstimation(
        Polar(
            copy(bus.voltage.magnitude),
            copy(bus.voltage.angle)
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
        method
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

analysis = pmuStateEstimation(system, device)
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
        se.factorization = factorization(gain, se.factorization)
    else
        se.factorization = factorization!(gain, se.factorization)
    end
    b = transpose(se.coefficient) * se.precision * se.mean

    voltageRectangular = solution(fill(0.0, 2 * bus.number), b, se.factorization)

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

function solve!(system::PowerSystem, analysis::PMUStateEstimation{LinearWLS{Orthogonal}})
    se = analysis.method
    bus = system.bus

    @inbounds for i = 1:se.number
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    coefficientScale = se.precision * se.coefficient
    se.factorization = factorization(coefficientScale, se.factorization)
    voltageInit = fill(0.0, 2 * bus.number)

    ReImVi = solution(voltageInit, se.precision * se.mean, se.factorization)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        voltage = complex(ReImVi[i], ReImVi[i + bus.number])
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
        set_start_value(
            se.statex[i]::VariableRef,
            analysis.voltage.magnitude[i] * cos(analysis.voltage.angle[i])
        )
        set_start_value(
            se.statex[i + bus.number]::VariableRef,
            analysis.voltage.magnitude[i] * sin(analysis.voltage.angle[i])
        )
    end

    optimize!(se.jump)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        j = i + bus.number
        ReVi = value(se.statex[i]::VariableRef) - value(se.statey[i]::VariableRef)
        ImVi = value(se.statex[j]::VariableRef) - value(se.statey[j]::VariableRef)

        voltage = complex(ReVi, ImVi)
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end
end

"""
    pmuPlacement(system::PowerSystem, optimizer; bridge, name, print)

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

# Keywords
The function accepts the following keywords:
* `bridge`: controls the bridging mechanism (default: `false`),
* `name`: handles the creation of string names (default: `false`),
* `print`: controls solver output display (default: `true`).

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
using HiGHS, Ipopt

system = powerSystem("case14.h5")
device = measurement()

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

placement = pmuPlacement(system, HiGHS.Optimizer)

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
function pmuPlacement(
    system::PowerSystem,
    (@nospecialize optimizerFactory);
    bridge::Bool = false,
    name::Bool = false,
    print::Bool = true,
)
    bus = system.bus
    branch = system.branch
    ac = system.model.ac

    placementPmu = PlacementPMU(
        OrderedDict{String, Int64}(),
        OrderedDict{String, Int64}(),
        OrderedDict{String, Int64}()
    )

    model!(system, ac)
    dropZeros!(ac)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)

    if !print
        JuMP.set_silent(jump)
    end

    set_string_names_on_creation(jump, name)

    placement = @variable(jump, 0 <= placement[i = 1:bus.number] <= 1, Int)

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

"""
    pmuPlacement!(system::PowerSystem, device::Measurement, analysis::AC, optimizer;
        varianceMagnitudeBus, varianceAngleBus,
        varianceMagnitudeFrom, varianceAngleFrom,
        varianceMagnitudeTo, varianceAngleTo,
        noise, correlated, polar,
        bridge, name, print)

The function determines the optimal placement of PMUs through integer linear programming.
Specifically, it identifies the minimum set of PMU locations required for effective power
system state estimation, ensuring observability with the least number of PMUs. Based on the
results from the `AC` type, it generates phasor measurements and integrates them into the
`Measurement` type. If current values are missing in the `AC` type, the function calculates
the associated currents required to form measurement values.

Additionally, the `optimizer` argument is a crucial component for formulating and solving
the optimization problem. Typically, using the GLPK or HiGHS solver is sufficient. For
more detailed information, please refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
PMUs at the buses can be configured using:
* `varianceMagnitudeBus` (pu or V): Variance of bus voltage magnitude measurements.
* `varianceAngleBus` (rad or deg): Variance of bus voltage angle measurements.
PMUs at the from-bus ends of the branches can be configured using:
* `varianceMagnitudeFrom` (pu or A): Variance of current magnitude measurements.
* `varianceAngleFrom` (rad or deg): Variance of current angle measurements.
PMUs at the to-bus ends of the branches can be configured using:
* `varianceMagnitudeTo` (pu or A): Variance of current magnitude measurements.
* `varianceAngleTo` (rad or deg): Variance of current angle measurements.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the phasor values, using the defined variances,
  * `noise = false`: uses the exact phasor values without adding noise.
Settings for handling phasor measurements include:
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.
Settings for the optimization solver include:
* `bridge`: controls the bridging mechanism (default: `false`),
* `name`: handles the creation of string names (default: `false`),
* `print`: controls solver output display (default: `true`).

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

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
using HiGHS, Ipopt

system = powerSystem("case14.h5")
device = measurement()

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

pmuPlacement!(system, device, analysis, HiGHS.Optimizer)
```
"""
function pmuPlacement!(
    system::PowerSystem,
    device::Measurement,
    analysis::AC,
    (@nospecialize optimizerFactory);
    bridge::Bool = false,
    name::Bool = false,
    print::Bool = true,
    varianceMagnitudeBus::FltIntMiss = missing,
    varianceAngleBus::FltIntMiss = missing,
    varianceMagnitudeFrom::FltIntMiss = missing,
    varianceAngleFrom::FltIntMiss = missing,
    varianceMagnitudeTo::FltIntMiss = missing,
    varianceAngleTo::FltIntMiss = missing,
    noise::Bool = template.pmu.noise,
    correlated::Bool = template.pmu.correlated,
    polar::Bool = template.pmu.polar
)
    placement = pmuPlacement(system, optimizerFactory; bridge, name, print)
    errorVoltage(analysis.voltage.magnitude)

    for (bus, idx) in placement.bus
        Vᵢ, θᵢ = analysis.voltage.magnitude[idx], analysis.voltage.angle[idx]
        addPmu!(
            system, device; bus = bus, magnitude = Vᵢ, angle = θᵢ,
            varianceMagnitude = varianceMagnitudeBus, varianceAngle = varianceAngleBus,
            noise, correlated, polar
        )
    end
    for (branch, idx) in placement.from
        if isempty(analysis.current.from.magnitude)
            Iᵢⱼ, ψᵢⱼ = fromCurrent(system, analysis; label = branch)
        else
            Iᵢⱼ, ψᵢⱼ = analysis.current.from.magnitude[idx], analysis.current.from.angle[idx]
        end
        addPmu!(
            system, device; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ,
            varianceMagnitude = varianceMagnitudeFrom, varianceAngle = varianceAngleFrom,
            noise, correlated, polar
        )
    end
    for (branch, idx) in placement.to
        if isempty(analysis.current.to.magnitude)
            Iⱼᵢ, ψⱼᵢ = toCurrent(system, analysis; label = branch)
        else
            Iⱼᵢ, ψⱼᵢ = analysis.current.to.magnitude[idx], analysis.current.to.angle[idx]
        end
        addPmu!(
            system, device; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ,
            varianceMagnitude = varianceMagnitudeTo, varianceAngle = varianceAngleTo,
            noise, correlated, polar
        )
    end

    return placement
end

##### Indices of the Coefficient Matrix #####
function pmuIndices(cff::SparseModel, co1::Int64, col2::Int64)
    cff.row[cff.cnt] = cff.idx
    cff.col[cff.cnt] = co1

    cff.row[cff.cnt + 1] = cff.idx + 1
    cff.col[cff.cnt + 1] = col2

    cff.cnt += 2
end