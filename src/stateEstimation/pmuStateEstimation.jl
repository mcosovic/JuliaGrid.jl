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
        bridge, name)

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
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `false`).

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
    solve!(system::PowerSystem, analysis::PMUStateEstimation; verbose)

By computing the bus voltage magnitudes and angles, the function solves the PMU state
estimation model.

# Keyword
Users can set:
* `verbose`: Controls the LAV solver output display:
  * `verbose = 0`: silent mode (default),
  * `verbose = 1`: prints only the exit message about convergence,
  * `verbose = 2`: prints detailed native solver output.

The default verbose setting can be modified using the [`@config`](@ref @config) macro.

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

function solve!(
    system::PowerSystem,
    analysis::PMUStateEstimation{LAV};
    verbose::Int64 = template.config.verbose
)
    se = analysis.method
    bus = system.bus

    silentOptimal(se.jump, verbose)

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

    printOptimal(se.jump, verbose)
end

##### Indices of the Coefficient Matrix #####
function pmuIndices(cff::SparseModel, co1::Int64, col2::Int64)
    cff.row[cff.cnt] = cff.idx
    cff.col[cff.cnt] = co1

    cff.row[cff.cnt + 1] = cff.idx + 1
    cff.col[cff.cnt + 1] = col2

    cff.cnt += 2
end