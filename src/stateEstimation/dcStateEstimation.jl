"""
    dcStateEstimation(monitoring::Measurement, [method = LU])

The function establishes the WLS model for DC state estimation, where the vector of state variables
contains only bus voltage angles.

# Arguments
This function requires the `Measurement` type to establish the WLS state estimation model.

Moreover, the presence of the `method` parameter is not mandatory. To address the WLS state
estimation method, users can opt to utilize factorization techniques to decompose the gain matrix,
such as `LU`, `QR`, or `LDLt` especially when the gain matrix is symmetric. For improved robustness
in cases with ill-conditioned data or significant variance disparities, using the `Orthogonal` or
`PetersWilkinson` method is recommended.

If the user does not provide the `method`, the default method for solving the estimation model will
be `LU` factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the `dc` field
within the `PowerSystem` composite type. Additionally, if the slack bus lacks an in-service generator,
JuliaGrid considers it a mistake and defines a new slack bus as the first generator bus with an
in-service generator in the bus type list.

# Returns
The function returns an instance of the [`DcStateEstimation`](@ref DcStateEstimation) type.

# Examples
Set up the DC state estimation model to be solved using the default LU factorization:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcStateEstimation(monitoring)
```

Set up the DC state estimation model to be solved using the orthogonal method:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcStateEstimation(monitoring, Orthogonal)
```
"""
function dcStateEstimation(monitoring::Measurement, ::Type{T} = LU) where {T <: WlsMethod}
    system = monitoring.system
    coeff, mean, precision, power, idx, numDevice, inservice = dcStateEstimationWls(system, monitoring)

    DcStateEstimation(
        Angle(
            Float64[]
        ),
        power,
        WLS{selectType(T)}(
            coeff,
            precision,
            mean,
            selectFactorization(T),
            idx,
            numDevice,
            inservice,
            Dict(:pattern => -1, :run => true)
        ),
        system,
        monitoring
    )
end

function dcStateEstimationWls(system::PowerSystem, monitoring::Measurement)
    dc = system.model.dc
    bus = system.bus
    branch = system.branch
    wattmeter = monitoring.wattmeter
    pmu = monitoring.pmu

    checkSlackBus(system)
    model!(system, dc)

    nnzCff = 0
    @inbounds for (i, idx) in enumerate(wattmeter.layout.index)
        if wattmeter.layout.bus[i]
            nnzCff += (dc.nodalMatrix.colptr[idx + 1] - dc.nodalMatrix.colptr[idx])
        else
            nnzCff += 2
        end
    end

    pmuIdx = OrderedDict{Int64, Int64}()
    numDevice = copy(wattmeter.number)
    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            nnzCff += 1
            numDevice += 1
            pmuIdx[i] = numDevice
        end
    end

    mean = fill(0.0, numDevice)
    pcs = spdiagm(0 => mean)
    cff = SparseModel(fill(0, nnzCff), fill(0, nnzCff), fill(0.0, nnzCff), 1, 1)
    inservice = 0

    @inbounds for (i, k) in enumerate(wattmeter.layout.index)
        pcs.nzval[i] = 1 / wattmeter.active.variance[i]

        status = wattmeter.active.status[i]
        inservice += status
        if wattmeter.layout.bus[i]
            mean[i] = status * meanPi(bus, dc, wattmeter, i, k)

            for j in dc.nodalMatrix.colptr[k]:(dc.nodalMatrix.colptr[k + 1] - 1)
                cff.val[cff.cnt] = status * dc.nodalMatrix.nzval[j]
                dcIndices(cff, i, dc.nodalMatrix.rowval[j])
            end
        else
            if wattmeter.layout.from[i]
                admittance = status * dc.admittance[k]
            else
                admittance = -status * dc.admittance[k]
            end

            mean[i] = status * meanPij(branch, wattmeter, admittance, i, k)

            cff.val[cff.cnt] = admittance
            dcIndices(cff, i, branch.layout.from[k])

            cff.val[cff.cnt] = -admittance
            dcIndices(cff, i, branch.layout.to[k])
        end
    end

    @inbounds for (i, k) in pmuIdx
        status = pmu.angle.status[i]
        inservice += status

        mean[k] = status * meanθi(pmu, bus, i)
        pcs.nzval[k] = 1 / pmu.angle.variance[i]

        cff.val[cff.cnt] = status
        dcIndices(cff, k, pmu.layout.index[i])
    end

    coefficient = sparse(cff.row, cff.col, cff.val, numDevice, bus.number)

    power = DcPower(
        Real(Float64[]),
        Real(Float64[]),
        Real(Float64[]),
        Real(Float64[]),
        Real(Float64[])
    )

    return coefficient, mean, pcs, power, pmuIdx, numDevice, inservice
end

"""
    dcLavStateEstimation(monitoring::Measurement, optimizer;
        iteration, tolerance, bridge, name, angle, positive, negative, verbose)

The function establishes the LAV model for DC state estimation, where the vector of state variables
contains only bus voltage angles.

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
`angle`, `positive`, and `negative`. For instance, users can choose `angle = "θ"`, `positive = "u"`,
and `negative = "v"` to display equations in a more readable format.

# Updates
If the DC model was not created, the function will automatically initiate an update of the `dc` field
within the `PowerSystem` composite type. Additionally, if the slack bus lacks an in-service generator,
JuliaGrid considers it a mistake and defines a new slack bus as the first generator bus with an
in-service generator in the bus type list.

# Returns
The function returns an instance of the [`DcStateEstimation`](@ref DcStateEstimation) type.

# Example
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
```
"""
function dcLavStateEstimation(
    monitoring::Measurement,
    (@nospecialize optimizerFactory);
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    bridge::Bool = false,
    name::Bool = true,
    angle::String = "angle",
    positive::String = "positive",
    negative::String = "negative",
    verbose::Int64 = template.config.verbose
)
    system = monitoring.system
    bus = system.bus
    branch = system.branch
    dc = system.model.dc
    wattmeter = monitoring.wattmeter
    pmu = monitoring.pmu

    checkSlackBus(system)
    model!(system, dc)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    total = copy(wattmeter.number)
    pmuIdx = OrderedDict{Int64, Int64}()
    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            total += 1
            pmuIdx[i] = total
        end
    end

    lav = LAV(
        jump,
        LavVariableRef(
            AngleVariableRef(
                @variable(jump, angle[i = 1:bus.number], base_name = angle)
            ),
            DeviationVariableRef(
                @variable(jump, 0 <= positive[i = 1:total], base_name = positive),
                @variable(jump, 0 <= negative[i = 1:total], base_name = negative)
            )
        ),
        Dict{Int64, ConstraintRef}(),
        pmuIdx,
        fill(1, 3),
        total
    )
    objective = @expression(lav.jump, AffExpr())

    voltage = lav.variable.voltage
    deviation = lav.variable.deviation

    fix(voltage.angle[bus.layout.slack], 0.0; force = true)

    @inbounds for (i, k) in enumerate(wattmeter.layout.index)
        if monitoring.wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                mean = meanPi(bus, dc, wattmeter, i, k)
                expr = Pi(system, voltage, k)
            else
                if wattmeter.layout.from[i]
                    admittance = dc.admittance[k]
                else
                    admittance = -dc.admittance[k]
                end

                mean = meanPij(branch, wattmeter, admittance, i, k)
                expr = Pij(system, voltage, admittance, k)
            end
            addConstrLav!(lav, expr, mean, i)
            addObjectLav!(lav, objective, i)
        else
            fix!(deviation, i)
        end
    end
    lav.range[2] = wattmeter.number + 1

    @inbounds for (i, k) in lav.index
        if pmu.angle.status[i] == 1
            mean = meanθi(pmu, bus, i)

            addConstrLav!(lav, voltage.angle[pmu.layout.index[i]], mean, k)
            addObjectLav!(lav, objective, k)
        else
            fix!(deviation, k)
        end
    end
    lav.range[3] = total + 1

    @objective(lav.jump, Min, objective)

    DcStateEstimation(
        Angle(
            copy(bus.voltage.angle)
        ),
        DcPower(
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[])
        ),
        lav,
        system,
        monitoring
    )
end

"""
    solve!(analysis::DcStateEstimation)

By computing the bus voltage angles, the function solves the DC state estimation model.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DcStateEstimation` type.

# Examples
Solving the DC state estimation model and obtaining the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcStateEstimation(monitoring)
solve!(analysis)
```

Solving the DC state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer; verbose = 1)
solve!(analysis)
```
"""
function solve!(analysis::DcStateEstimation{WLS{Normal}})
    se = analysis.method
    bus = analysis.system.bus

    removeIdx, removeVal = removeColumn(se.coefficient, bus.layout.slack)

    temp = transpose(se.coefficient) * se.precision
    if se.signature[:run]
        se.signature[:run] = false

        gain = temp * se.coefficient
        gain[bus.layout.slack, bus.layout.slack] = 1.0

        if se.signature[:pattern] == -1
            se.signature[:pattern] = 0
            se.factorization = factorization(gain, se.factorization)
        else
            se.factorization = factorization!(gain, se.factorization)
        end
    end
    b = temp * se.mean

    fillState!(analysis.voltage, bus.number)
    solution!(analysis.voltage.angle, se.factorization, b)

    addSlackAngle!(analysis.system, analysis)
    restoreColumn!(se.coefficient, removeIdx, removeVal, bus.layout.slack)
end

function solve!(analysis::DcStateEstimation{WLS{Orthogonal}})
    se = analysis.method
    bus = analysis.system.bus

    removeIdx, removeVal = removeColumn(se.coefficient, bus.layout.slack)
    sqrtPrecision!(se.precision, se.number)

    if se.signature[:run]
        se.signature[:run] = false
        se.factorization = qr(se.precision * se.coefficient)
    end

    fillState!(analysis.voltage, bus.number)
    solution!(analysis.voltage.angle, se.factorization, se.precision * se.mean)

    addSlackAngle!(analysis.system, analysis)
    squarePrecision!(se.precision, se.number)
    restoreColumn!(se.coefficient, removeIdx, removeVal, bus.layout.slack)
end

function solve!(analysis::DcStateEstimation{WLS{PetersWilkinson}})
    se = analysis.method
    bus = analysis.system.bus

    control = UMFPACK.get_umfpack_control(Float64, Int64)
    control[UMFPACK.JL_UMFPACK_SCALE] = 0

    removeIdx, removeVal = removeColumn(se.coefficient, bus.layout.slack)
    sqrtPrecision!(se.precision, se.number)

    if se.signature[:run]
        se.signature[:run] = false

        H = vcat(se.precision * se.coefficient, sparse([1], [bus.layout.slack], [1.0], 1, bus.number))
        se.signature[:pattern] = dropZeros!(H)

        if se.signature[:pattern] == -1
            se.signature[:pattern] = 0
            se.factorization = lu(H; control)
        else
            lu!(se.factorization, H)
        end
    end

    z = se.precision * se.mean
    push!(z, 0.0)
    permute!(z, se.factorization.p)

    Lt = transpose(se.factorization.L)
    y = (Lt * se.factorization.L) \ (Lt * z)

    fillState!(analysis.voltage, bus.number)
    analysis.voltage.angle .= UpperTriangular(se.factorization.U) \ y
    invpermute!(analysis.voltage.angle, se.factorization.q)

    addSlackAngle!(analysis.system, analysis)
    squarePrecision!(se.precision, se.number)
    restoreColumn!(se.coefficient, removeIdx, removeVal, bus.layout.slack)
end

function solve!(analysis::DcStateEstimation{LAV})
    system = analysis.system
    lav = analysis.method
    verbose = lav.jump.ext[:verbose]
    slackAngle = system.bus.voltage.angle[system.bus.layout.slack]

    silentJump(lav.jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(lav.variable.voltage.angle[i]::VariableRef, analysis.voltage.angle[i] - slackAngle)
    end

    optimize!(lav.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(lav.variable.voltage.angle[i]::VariableRef) + slackAngle
    end

    printExit(lav.jump, verbose)
end

function setInitialPoint!(analysis::DcStateEstimation{LAV})
    errorTransfer(analysis.system.bus.voltage.angle, analysis.voltage.angle)

    @inbounds for i = 1:analysis.system.bus.number
        analysis.voltage.angle[i] = analysis.system.bus.voltage.angle[i]
    end
end

function setInitialPoint!(target::DcStateEstimation{LAV}, source::Analysis)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:target.system.bus.number
        target.voltage.angle[i] = source.voltage.angle[i]
    end
end

##### Indices of the Coefficient Matrix #####
function dcIndices(cff::SparseModel, row::Int64, col::Int64)
    cff.row[cff.cnt] = row
    cff.col[cff.cnt] = col

    cff.cnt += 1
end


function sqrtPrecision!(P::SparseMatrixCSC{Float64, Int64}, n::Int64)
    @inbounds for i = 1:n
        P.nzval[i] = sqrt(P.nzval[i])
    end
end

function squarePrecision!(P::SparseMatrixCSC{Float64, Int64}, n::Int64)
    @inbounds for i = 1:n
        P.nzval[i] ^= 2
    end
end

function fillState!(voltage::Angle, n::Int64)
    if isempty(voltage.angle)
        voltage.angle = fill(0.0, n)
    end
end

"""
    stateEstimation!(analysis::DcStateEstimation; iteration, tolerance, power, verbose)

The function serves as a wrapper for solving DC state estimation and includes the functions:
* [`solve!`](@ref solve!(::DcStateEstimation{WLS{Normal}})),
* [`power!`](@ref power!(::DcPowerFlow)).

It computes bus voltage angles using the WLS or LAV model with the option to compute powers.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations for the LAV model.
* `tolerance`: Specifies the allowed deviation from the optimal solution for the LAV model.
* `power`: Enables the computation of powers (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

If `iteration` and `tolerance` are not specified, the optimization solver settings are used.

# Examples
Use the wrapper function to obtain the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcStateEstimation(monitoring)
stateEstimation!(analysis; power = true, verbose = 3)
```

Use the wrapper function to obtain the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = dcLavStateEstimation(monitoring, Ipopt.Optimizer)
stateEstimation!(analysis; iteration = 30, tolerance = 1e-6, verbose = 1)
```
"""
function stateEstimation!(
    analysis::DcStateEstimation{WLS{T}};
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    verbose::Int64 = template.config.verbose
) where T <: WlsMethod

    system = analysis.system
    printMiddle(system, analysis, verbose)

    solve!(analysis)

    printExit(analysis, verbose)

    if power
        power!(analysis)
    end
end

function stateEstimation!(
    analysis::DcStateEstimation{LAV};
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    verbose::IntMiss = missing
)
    masterVerbose = analysis.method.jump.ext[:verbose]
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end

    analysis.method.jump.ext[:verbose] = masterVerbose
end