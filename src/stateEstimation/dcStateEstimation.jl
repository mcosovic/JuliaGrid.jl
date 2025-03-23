"""
    dcStateEstimation(system::PowerSystem, device::Measurement, [method = LU])

The function establishes the WLS model for DC state estimation, where the vector of state
variables contains only bus voltage angles.

# Arguments
This function requires the `PowerSystem` and `Measurement` types to establish the WLS state
estimation model.

Moreover, the presence of the `method` parameter is not mandatory. To address the WLS
state estimation method, users can opt to utilize factorization techniques to decompose
the gain matrix, such as `LU`, `QR`, or `LDLt` especially when the gain matrix is symmetric.
Opting for the `Orthogonal` method is advisable for a more robust solution in scenarios
involving ill-conditioned data, particularly when substantial variations in variances are
present.

If the user does not provide the `method`, the default method for solving the estimation
model will be `LU` factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as
the first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCStateEstimation` type, which includes the
following fields:
- `voltage`: The variable allocated to store the bus voltage angles.
- `power`: The variable allocated to store the active powers.
- `method`: The system model vectors and matrices.

# Examples
Set up the DC state estimation model to be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
```

Set up the DC state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device, Orthogonal)
```
"""
function dcStateEstimation(
    system::PowerSystem,
    device::Measurement,
    factorization::Type{<:Union{QR, LDLt, LU}} = LU
)
    coeff, mean, precision, power, idx, numDevice, inservice = dcStateEstimationWls(system, device)

    DCStateEstimation(
        PolarAngle(Float64[]),
        power,
        WLS{Normal}(
            coeff,
            precision,
            mean,
            factorized[factorization],
            idx,
            numDevice,
            inservice,
            -1,
            true,
        )
    )
end

function dcStateEstimation(
    system::PowerSystem,
    device::Measurement,
    ::Type{<:Orthogonal}
)
    coeff, mean, precision, power, idx, numDevice, inservice = dcStateEstimationWls(system, device)

    DCStateEstimation(
        PolarAngle(
            Float64[]
        ),
        power,
        WLS{Orthogonal}(
            coeff,
            precision,
            mean,
            factorized[QR],
            idx,
            numDevice,
            inservice,
            -1,
            true,
        )
    )
end

function dcStateEstimationWls(system::PowerSystem, device::Measurement)
    dc = system.model.dc
    bus = system.bus
    branch = system.branch
    wattmeter = device.wattmeter
    pmu = device.pmu

    checkSlackBus(system)
    model!(system, dc)
    changeSlackBus!(system)

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

    power = DCPower(
        CartesianReal(Float64[]),
        CartesianReal(Float64[]),
        CartesianReal(Float64[]),
        CartesianReal(Float64[]),
        CartesianReal(Float64[])
    )

   return coefficient, mean, pcs, power, pmuIdx, numDevice, inservice
end

"""
    dcLavStateEstimation(system::PowerSystem, device::Measurement, optimizer;
        iteration, tolerance, bridge, name, angle, positive, negative, verbose)

The function establishes the LAV model for DC state estimation, where the vector of state
variables contains only bus voltage angles.

# Arguments
This function requires the `PowerSystem` and `Measurement` types to establish the LAV state
estimation model. The LAV method offers increased robustness compared to WLS, ensuring
unbiasedness even in the presence of various measurement errors and outliers.

Users can employ the LAV method to find an estimator by choosing one of the available
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically,
`Ipopt` suffices for most scenarios.

# Keywords
The function accepts the following keywords:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `true`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

Additionally, users can modify variable names used for printing and writing through the
keywords `angle`, `positive`, and `negative`. For instance, users can choose `angle = "θ"`,
`positive = "u"`, and `negative = "v"` to display equations in a more readable format.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as
the first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCStateEstimation` type, which includes the
following fields:
- `voltage`: The variable allocated to store the bus voltage angles.
- `power`: The variable allocated to store the active powers.
- `method`: The optimization model.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function dcLavStateEstimation(
    system::PowerSystem,
    device::Measurement,
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
    bus = system.bus
    branch = system.branch
    dc = system.model.dc
    wattmeter = device.wattmeter
    pmu = device.pmu

    checkSlackBus(system)
    model!(system, dc)
    changeSlackBus!(system)

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
        DCState(
            @variable(jump, angle[i = 1:bus.number], base_name = angle)
        ),
        Deviation(
            @variable(jump, 0 <= positive[i = 1:total], base_name = positive),
            @variable(jump, 0 <= negative[i = 1:total], base_name = negative)
        ),
        Dict{Int64, ConstraintRef}(),
        pmuIdx,
        fill(1, 3),
        total
    )
    objective = @expression(lav.jump, AffExpr())

    fix(lav.state.angle[bus.layout.slack], 0.0; force = true)

    @inbounds for (i, k) in enumerate(wattmeter.layout.index)
        if device.wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                mean = meanPi(bus, dc, wattmeter, i, k)
                expr = Pi(dc, lav, k)
            else
                if wattmeter.layout.from[i]
                    admittance = dc.admittance[k]
                else
                    admittance = -dc.admittance[k]
                end

                mean = meanPij(branch, wattmeter, admittance, i, k)
                expr = Pij(system, lav.state, admittance, k)
            end
            addConstrLav!(lav, expr, mean, i)
            addObjectLav!(lav, objective, i)
        else
            fix(lav.deviation.positive[i], 0.0; force = true)
            fix(lav.deviation.negative[i], 0.0; force = true)
        end
    end
    lav.range[2] = wattmeter.number + 1

    @inbounds for (i, k) in lav.index
        if pmu.angle.status[i] == 1
            mean = meanθi(pmu, bus, i)

            addConstrLav!(lav, lav.state.angle[pmu.layout.index[i]], mean, k)
            addObjectLav!(lav, objective, k)
        else
            fix(lav.deviation.positive[k], 0.0; force = true)
            fix(lav.deviation.negative[k], 0.0; force = true)
        end
    end
    lav.range[3] = total + 1

    @objective(lav.jump, Min, objective)

    DCStateEstimation(
        PolarAngle(
            copy(bus.voltage.angle)
        ),
        DCPower(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[])
        ),
        lav
    )
end

"""
    solve!(system::PowerSystem, analysis::DCStateEstimation)

By computing the bus voltage angles, the function solves the DC state estimation model.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DCStateEstimation`
type.

# Examples
Solving the DC state estimation model and obtaining the WLS estimator:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
```

Solving the DC state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer; verbose = 1)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCStateEstimation{WLS{Normal}})
    se = analysis.method
    bus = system.bus
    slackAngle = bus.voltage.angle[bus.layout.slack]

    slackRange, elementsRemove = delSlackCoeff(analysis, bus.layout.slack)

    if se.run
        analysis.method.run = false

        gain = transpose(se.coefficient) * se.precision * se.coefficient
        gain[bus.layout.slack, bus.layout.slack] = 1.0

        if analysis.method.pattern == -1
            analysis.method.pattern = 0
            se.factorization = factorization(gain, se.factorization)
        else
            se.factorization = factorization!(gain, se.factorization)
        end
    end
    b = transpose(se.coefficient) * se.precision * se.mean

    analysis.voltage.angle = solution(analysis.voltage.angle, b, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if slackAngle != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += slackAngle
        end
    end

    addSlackCoeff(analysis, slackRange, elementsRemove, bus.layout.slack)
end

function solve!(system::PowerSystem, analysis::DCStateEstimation{WLS{Orthogonal}})
    bus = system.bus
    voltage = analysis.voltage
    se = analysis.method

    slackRange, elementsRemove = delSlackCoeff(analysis, bus.layout.slack)

    @inbounds for i = 1:se.number
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    if se.run
        analysis.method.run = false
        coefficientScale = se.precision * se.coefficient
        se.factorization = factorization(coefficientScale, se.factorization)
    end
    voltage.angle = solution(voltage.angle, se.precision * se.mean, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end

    @inbounds for i = 1:se.number
        se.precision.nzval[i] ^= 2
    end

    addSlackCoeff(analysis, slackRange, elementsRemove, bus.layout.slack)
end

function solve!(
    system::PowerSystem,
    analysis::DCStateEstimation{LAV};
)
    lav = analysis.method
    verbose = lav.jump.ext[:verbose]
    slackAngle = system.bus.voltage.angle[system.bus.layout.slack]

    silentJump(lav.jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(lav.state.angle[i]::VariableRef, analysis.voltage.angle[i] - slackAngle)
    end

    optimize!(lav.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(lav.state.angle[i]::VariableRef) + slackAngle
    end

    printExit(lav.jump, verbose)
end

##### Indices of the Coefficient Matrix #####
function dcIndices(cff::SparseModel, row::Int64, col::Int64)
    cff.row[cff.cnt] = row
    cff.col[cff.cnt] = col

    cff.cnt += 1
end

##### Remove Slack Bus Coefficents #####
function delSlackCoeff(analysis::DCStateEstimation, slack::Int64)
    se = analysis.method

    slackRange = se.coefficient.colptr[slack]:(se.coefficient.colptr[slack + 1] - 1)
    elementsRemove = se.coefficient.nzval[slackRange]
    @inbounds for i in slackRange
        se.coefficient.nzval[i] = 0.0
    end

    return slackRange, elementsRemove
end

##### Restore Slack Bus Coefficents #####
function addSlackCoeff(
    analysis::DCStateEstimation,
    slackRange::UnitRange{Int64},
    elementsRemove::Vector{Float64},
    slack::Int64
)
    se = analysis.method

    @inbounds for (k, i) in enumerate(slackRange)
        se.coefficient[se.coefficient.rowval[i], slack] = elementsRemove[k]
    end
end

"""
    stateEstimation!(system::PowerSystem, analysis::DCStateEstimation;
        iteration, tolerance, power, verbose)

The function serves as a wrapper for solving DC state estimation and includes the functions:
* [`solve!`](@ref solve!(::PowerSystem, ::DCStateEstimation{WLS{Normal}})),
* [`power!`](@ref power!(::PowerSystem, ::DCPowerFlow)).

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
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
stateEstimation!(system, analysis; power = true, verbose = 3)
```

Use the wrapper function to obtain the LAV estimator:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
stateEstimation!(system, analysis; iteration = 30, tolerance = 1e-6, verbose = 1)
```
"""
function stateEstimation!(
    system::PowerSystem,
    analysis::DCStateEstimation{WLS{T}};
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    verbose::Int64 = template.config.verbose
)  where T <: Union{Normal, Orthogonal}

    printMiddle(system, analysis, verbose)

    solve!(system, analysis)

    printExit(analysis, verbose)

    if power
        power!(system, analysis)
    end
end

function stateEstimation!(
    system::PowerSystem,
    analysis::DCStateEstimation{LAV};
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    verbose::IntMiss = missing
)
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(system, analysis)

    if power
        power!(system, analysis)
    end
end