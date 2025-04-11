"""
    pmuStateEstimation(monitoring::Measurement, [method = LU])

The function establishes the linear WLS model for state estimation with PMUs only. In this model,
the vector of state variables contains bus voltages, given in rectangular coordinates.

# Arguments
This function requires the `Measurement` type to establish the WLS state estimation model.

Moreover, the presence of the `method` parameter is not mandatory. To address the WLS state
estimation method, users can opt to utilize factorization techniques to decompose the gain matrix,
such as `LU`, `QR`, or `LDLt` especially when the gain matrix is symmetric. Opting for the
`Orthogonal` method is advisable for a more robust solution in scenarios involving ill-conditioned
data, particularly when substantial variations in variances are present.

If the user does not provide the `method`, the default method for solving the estimation model will
be `LU` factorization.

# Updates
If the AC model has not been created, the function will automatically trigger an update of the `ac`
field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the [`PmuStateEstimation`](@ref PmuStateEstimation) type.

# Examples
Set up the PMU state estimation model to be solved using the default LU factorization:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuStateEstimation(monitoring)
```

Set up the PMU state estimation model to be solved using the orthogonal method:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuStateEstimation(monitoring, Orthogonal)
```
"""
function pmuStateEstimation(monitoring::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    system = monitoring.system
    coeff, mean, precision, power, current, inservice, _ = pmuEstimationWls(system, monitoring)

    PmuStateEstimation(
        Polar(
            Float64[],
            Float64[]
        ),
        power,
        current,
        WLS{Normal}(
            coeff,
            precision,
            mean,
            factorized[factorization],
            OrderedDict{Int64, Int64}(),
            2 * monitoring.pmu.number,
            inservice,
            Dict(:pattern => -1, :run => true)
        ),
        system,
        monitoring
    )
end

function pmuStateEstimation(monitoring::Measurement, ::Type{<:Orthogonal})
    system = monitoring.system
    coeff, mean, precision, power, current, inservice, correlated = pmuEstimationWls(system, monitoring)

    if correlated
        throw(ErrorException(
            "The non-diagonal precision matrix prevents using the orthogonal method.")
        )
    end

    PmuStateEstimation(
        Polar(Float64[], Float64[]),
        power,
        current,
        WLS{Orthogonal}(
            coeff,
            precision,
            mean,
            factorized[QR],
            OrderedDict{Int64, Int64}(),
            2 * monitoring.pmu.number,
            inservice,
            Dict(:pattern => -1, :run => true)
        ),
        system,
        monitoring
    )
end

function pmuEstimationWls(system::PowerSystem, monitoring::Measurement)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    pmu = monitoring.pmu
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
    inservice = 0

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
                inservice += 2

                mean[cff.idx] = pmu.magnitude.mean[i] * cosθ
                mean[cff.idx + 1] = pmu.magnitude.mean[i] * sinθ

                cff.val[cff.cnt] = 1.0
                cff.val[cff.cnt + 1] = 1.0
            end
            pmuIndices(cff, pmu.layout.index[i], pmu.layout.index[i] + bus.number)

            cff.idx += 2
        else
            if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
                inservice += 2

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

    power = AcPower(
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[])
    )
    current = AcCurrent(
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[])
    )

    return coefficient, mean, precision, power, current, inservice, correlated
end

"""
    pmuLavStateEstimation(monitoring::Measurement, optimizer;
        iteration, tolerance, bridge, name, real, imag, positive, negative, verbose)

The function establishes the LAV model for state estimation with PMUs only. In this model, the vector
of state variables contains bus voltages, given in rectangular coordinates.

# Arguments
This function requires the `Measurement` type to establish the LAV state estimation model. The LAV
method offers increased robustness compared to WLS, ensuring unbiasedness even in the presence of
various measurement errors and outliers.

Users can employ the LAV method to find an estimator by choosing one of the available
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically, `Ipopt`
suffices for most scenarios.

# Keywords
The function accepts the following keywords:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `true`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

Additionally, users can modify variable names used for printing and writing through the keywords
`real`, `imag`, `positive`, and `negative`. For instance, users can choose `real = "Vr"`,
`imag = "Vi"`, `positive = "u"`, and `negative = "v"` to display equations in a more readable format.

# Updates
If the AC model has not been created, the function will automatically trigger an update of the `ac`
field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the [`PmuStateEstimation`](@ref PmuStateEstimation) type.

# Example
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)
```
"""
function pmuLavStateEstimation(
    monitoring::Measurement,
    @nospecialize optimizerFactory;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    bridge::Bool = false,
    name::Bool = true,
    real::String = "real",
    imag::String = "imag",
    positive::String = "positive",
    negative::String = "negative",
    verbose::Int64 = template.config.verbose
)
    system = monitoring.system
    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = monitoring.pmu
    total = 2 * pmu.number

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    lav = LAV(
        jump,
        LavVariableRef(
            RectangularVariableRef(
                @variable(jump, real[i = 1:bus.number], base_name = real),
                @variable(jump, imag[i = 1:bus.number], base_name = imag)
            ),
            DeviationVariableRef(
                @variable(jump, 0 <= positive[i = 1:total], base_name = positive),
                @variable(jump, 0 <= negative[i = 1:total], base_name = negative)
            )
        ),
        Dict{Int64, ConstraintRef}(),
        OrderedDict{Int64, Int64}(),
        fill(1, 1),
        pmu.number
    )
    objective = @expression(lav.jump, AffExpr())

    voltage = lav.variable.voltage
    deviation = lav.variable.deviation

    cnt = 1
    @inbounds for (i, k) in enumerate(pmu.layout.index)
        if pmu.magnitude.status[i] == 1 && pmu.angle.status[i] == 1
            sinθ, cosθ = sincos(pmu.angle.mean[i])
            reMean = pmu.magnitude.mean[i] * cosθ
            imMean = pmu.magnitude.mean[i] * sinθ

            if pmu.layout.bus[i]
                reExpr = voltage.real[pmu.layout.index[i]]
                imExpr = voltage.imag[pmu.layout.index[i]]
            else
                if pmu.layout.from[i]
                    piModel = ReImIijCoefficient(branch, ac, k)
                else
                    piModel = ReImIjiCoefficient(branch, ac, k)
                end
                reExpr, imExpr = ReImIij(system, voltage, piModel, k)
            end

            addConstrLav!(lav, reExpr, reMean, cnt)
            addObjectLav!(lav, objective, cnt)

            addConstrLav!(lav, imExpr, imMean, cnt + 1)
            addObjectLav!(lav, objective, cnt + 1)
        else
            fix!(deviation, cnt)
            fix!(deviation, cnt + 1)
        end
        cnt += 2
    end

    @objective(lav.jump, Min, objective)

    PmuStateEstimation(
        Polar(
            copy(bus.voltage.magnitude),
            copy(bus.voltage.angle)
        ),
        AcPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[])
        ),
        AcCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        lav,
        system,
        monitoring
    )
end

"""
    solve!(analysis::PmuStateEstimation)

By computing the bus voltage magnitudes and angles, the function solves the PMU state estimation
model.

# Updates
The resulting bus voltage magnitudes and angles are stored in the `voltage` field of the
`PmuStateEstimation` type.

# Examples
Solving the PMU state estimation model and obtaining the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuStateEstimation(monitoring)
solve!(analysis)
```

Solving the PMU state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuLavStateEstimation(monitoring, Ipopt.Optimizer; verbose = 1)
solve!(analysis)
```
"""
function solve!(analysis::PmuStateEstimation{WLS{Normal}})
    system = analysis.system
    se = analysis.method
    bus = system.bus

    gain = transpose(se.coefficient) * se.precision * se.coefficient

    if se.signature[:pattern] == -1
        se.signature[:pattern] = 0
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

function solve!(analysis::PmuStateEstimation{WLS{Orthogonal}})
    system = analysis.system
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

function solve!(analysis::PmuStateEstimation{LAV})
    system = analysis.system
    lav = analysis.method
    bus = system.bus
    verbose = lav.jump.ext[:verbose]

    silentJump(lav.jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(
            lav.variable.voltage.real[i]::VariableRef,
            analysis.voltage.magnitude[i] * cos(analysis.voltage.angle[i])
        )
        set_start_value(
            lav.variable.voltage.imag[i]::VariableRef,
            analysis.voltage.magnitude[i] * sin(analysis.voltage.angle[i])
        )
    end

    optimize!(lav.jump)

    if isempty(analysis.voltage.magnitude)
        analysis.voltage.magnitude = fill(0.0, bus.number)
        analysis.voltage.angle = similar(analysis.voltage.magnitude)
    end

    @inbounds for i = 1:bus.number
        realpart = value(lav.variable.voltage.real[i]::VariableRef)
        imagpart = value(lav.variable.voltage.imag[i]::VariableRef)

        voltage = complex(realpart, imagpart)
        analysis.voltage.magnitude[i] = abs(voltage)
        analysis.voltage.angle[i] = angle(voltage)
    end

    printExit(lav.jump, verbose)
end

function setInitialPoint!(analysis::PmuStateEstimation{LAV})
    errorTransfer(analysis.system.bus.voltage.magnitude, analysis.voltage.magnitude)
    errorTransfer(analysis.system.bus.voltage.angle, analysis.voltage.angle)

    @inbounds for i = 1:analysis.system.bus.number
        analysis.voltage.magnitude[i] = analysis.system.bus.voltage.magnitude[i]
        analysis.voltage.angle[i] = analysis.system.bus.voltage.angle[i]
    end
end

##### Indices of the Coefficient Matrix #####
function pmuIndices(cff::SparseModel, co1::Int64, col2::Int64)
    cff.row[cff.cnt] = cff.idx
    cff.col[cff.cnt] = co1

    cff.row[cff.cnt + 1] = cff.idx + 1
    cff.col[cff.cnt + 1] = col2

    cff.cnt += 2
end

"""
    stateEstimation!(analysis::PmuStateEstimation; iteration, tolerance, power, verbose)

The function serves as a wrapper for solving PMU state estimation and includes the functions:
* [`solve!`](@ref solve!(::PmuStateEstimation{WLS{Normal}})),
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

It computes bus voltage magnitudes and angles using the WLS or LAV model with the option to compute
powers and currents.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations for the LAV model.
* `tolerance`: Specifies the allowed deviation from the optimal solution for the LAV model.
* `power`: Enables the computation of powers (default: `false`).
* `current`: Enables the computation of currents (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

If `iteration` and `tolerance` are not specified, the optimization solver settings are used.

# Examples
Use the wrapper function to obtain the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuStateEstimation(monitoring)
stateEstimation!(analysis; power = true, verbose = 3)
```

Use the wrapper function to obtain the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = pmuLavStateEstimation(monitoring, Ipopt.Optimizer)
stateEstimation!(analysis; iteration = 30, tolerance = 1e-6, verbose = 3)
```
"""
function stateEstimation!(
    analysis::PmuStateEstimation{WLS{T}};
    iteration::Int64 = 40,
    tolerance::Float64 = 1e-8,
    power::Bool = false,
    current::Bool = false,
    verbose::Int64 = template.config.verbose
)  where T <: Union{Normal, Orthogonal}

    system = analysis.system
    printMiddle(system, analysis, verbose)

    solve!(analysis)

    printExit(analysis, verbose)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end
end

function stateEstimation!(
    analysis::PmuStateEstimation{LAV};
    iteration::Int64 = 40,
    tolerance::Float64 = 1e-8,
    power::Bool = false,
    current::Bool = false,
    verbose::IntMiss = missing
)
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end
end