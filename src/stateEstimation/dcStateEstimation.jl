"""
    dcStateEstimation(system::PowerSystem, device::Measurement, method)

The function sets up the framework to solve the DC state estimation.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish the 
framework. 

Additionally, the inclusion of the `method` parameter is not obligatory. It offers a range 
of techniques for resolving DC state estimation. To tackle the weighted least-squares (WLS) 
issue, users have the option to employ standard factorization methods like `LU` or `LDLt`, 
but only when the gain matrix is symmetrical. For a more resilient solution in situations 
involving ill-conditioned data, particularly when significant differences in variances 
exist, choosing the `QR` factorization method is recommended.

Moreover, instead of solving the WLS state estimation problem, users can utilize the least 
absolute value (LAV) method to find an estimator. This can be achieved by selecting one of 
the [optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/), 
where typically `Ipopt.Optimizer` suffices for common scenarios.

If the user does not provide the `method`, the default method for solving the DC estimation 
will be LU factorization.

# Updates
If the DC model was not created, the function will automatically initiate an update of the
`dc` field within the `PowerSystem` composite type. Additionally, if the slack bus lacks
an in-service generator, JuliaGrid considers it a mistake and defines a new slack bus as 
the first generator bus with an in-service generator in the bus type list.

# Returns
The function returns an instance of the `DCStateEstimation` abstract type, which includes 
the following fields:
- `voltage`: the variable allocated to store the bus voltage angles;
- `power`: the variable allocated to store the active powers;
- `method`: the system model vectors and matrices, or alternatively, the optimization model;
- `bad`: the variable linked to identifying bad data within the measurement set. 

# Examples
Establish the DC state estimation WLS framework that will be solved using the default LU 
factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
```

Establish the DC state estimation WLS framework that will be solved using the QR 
factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device, QR)
```

Establish the DC state estimation LAV framework:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function dcStateEstimation(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    dc = system.model.dc
    bus = system.bus
    branch = system.branch
    wattmeter = device.wattmeter
    pmu = device.pmu

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(dc.nodalMatrix)
        dcModel!(system)
    end
    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end

    nonZeroElement = 0 
    for (i, index) in enumerate(wattmeter.layout.index)
        if wattmeter.layout.bus[i]
            nonZeroElement += (dc.nodalMatrix.colptr[index + 1] - dc.nodalMatrix.colptr[index])
        elseif wattmeter.layout.from[i]
            nonZeroElement += 2 
        else
            nonZeroElement += 2 
        end
    end

    for i = 1:pmu.number
        if pmu.layout.bus[i]
            nonZeroElement += 1 
        end
    end

    deviceNumber = wattmeter.number + pmu.number
    row = fill(0, nonZeroElement) 
    col = similar(row)
    jac = fill(0.0, nonZeroElement)
    mean = fill(0.0, deviceNumber)
    weight = similar(mean)

    count = 1
    for (i, k) in enumerate(wattmeter.layout.index)
        if wattmeter.active.status[i] == 1
            constIf = 1
        else
            constIf = 0
        end

        if wattmeter.layout.bus[i]
            for j in dc.nodalMatrix.colptr[k]:(dc.nodalMatrix.colptr[k + 1] - 1)
                row[count] = i
                col[count] = dc.nodalMatrix.rowval[j]
                jac[count] = dc.nodalMatrix.nzval[j] * constIf
                count += 1
            end
            mean[i] = (wattmeter.active.mean[i] - dc.shiftPower[k] - bus.shunt.conductance[k]) * constIf
            weight[i] = (1 / wattmeter.active.variance[i]) * constIf
        else
            if wattmeter.layout.from[i]
                addmitance = dc.admittance[k] * constIf
            else
                addmitance = -dc.admittance[k] * constIf
            end

            row[count] = i
            col[count] = branch.layout.from[k]
            jac[count] = addmitance
            count += 1
            row[count] = i
            col[count] = branch.layout.to[k]
            jac[count] = -addmitance

            mean[i] = (wattmeter.active.mean[i] + branch.parameter.shiftAngle[k] * addmitance) * constIf
            weight[i] = (1 / wattmeter.active.variance[i]) * constIf
            
            count += 1
        end
    end

    rowindex = wattmeter.number + 1
    for i = 1:pmu.number
        if pmu.layout.bus[i]
            if pmu.angle.status[i] == 1
                constIf = 1
            else
                constIf = 0
            end

            row[count] = rowindex
            col[count] = pmu.layout.index[i]
            jac[count] = constIf

            mean[rowindex] = (pmu.angle.mean[i] - bus.voltage.angle[bus.layout.slack]) * constIf
            weight[rowindex] = (1 / pmu.angle.variance[i]) * constIf
            
            count += 1; rowindex += 1
        end
    end

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return DCStateEstimationWLS(
        PolarAngle(Float64[]),
        DCPowerSE(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
        ),
        DCStateEstimationWLSMethod(
            sparse(row, col, jac, deviceNumber, bus.number),
            weight,
            mean,
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            deviceNumber,
            false
        ),
        BadData(
            true, 
            0.0, 
            0, 
            ""
        )
    )
end

function dcStateEstimation(system::PowerSystem, device::Measurement, pseudo::Measurement, islands::Observability, factorization::Type{<:Union{QR, LDLt, LU}} = LU; threshold = 1e-5)
    if size(islands.island, 1) > 1
        restoration!(system, device, pseudo, islands, threshold)
    end
    dcStateEstimation(system, device, factorization)
end


function dcStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    branch = system.branch
    dc = system.model.dc
    wattmeter = device.wattmeter
    pmu = device.pmu
    deviceNumber = wattmeter.number + pmu.number

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    anglex = @variable(jump, 0 <= anglex[i = 1:bus.number])
    angley = @variable(jump, 0 <= angley[i = 1:bus.number])
    residualx = @variable(jump, 0 <= residualx[i = 1:deviceNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:deviceNumber])

    fix(anglex[bus.layout.slack], 0.0; force = true)
    fix(angley[bus.layout.slack], bus.voltage.angle[bus.layout.slack]; force = true)

    objective = @expression(jump, AffExpr())
    residual = Dict{Int64, JuMP.ConstraintRef}()
    for (i, k) in enumerate(wattmeter.layout.index)
        if device.wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                angleJacobian = @expression(jump, AffExpr())
                for j in dc.nodalMatrix.colptr[k]:(dc.nodalMatrix.colptr[k + 1] - 1)
                    col = dc.nodalMatrix.rowval[j]
                    add_to_expression!(angleJacobian, dc.nodalMatrix.nzval[j] * (angley[col] - anglex[col]))
                end
                residual[i] = @constraint(jump, angleJacobian + residualy[i] - residualx[i] - wattmeter.active.mean[i] + dc.shiftPower[k] + bus.shunt.conductance[k] == 0.0)
            else
                from = branch.layout.from[k]
                to = branch.layout.from[k]

                if wattmeter.layout.from[i]
                    admittance = dc.admittance[k] 
                else
                    admittance = -dc.admittance[k]
                end
                angleJacobian = admittance * (angley[from] - anglex[from] - angley[to] + anglex[to]) 
                residual[i] = @constraint(jump, angleJacobian + residualy[i] - residualx[i] - wattmeter.active.mean[i] - branch.parameter.shiftAngle[k] * admittance == 0.0)
            end
            add_to_expression!(objective, residualx[i] + residualy[i])
        else
            fix(residualx[i], 0.0; force = true)
            fix(residualy[i], 0.0; force = true)
        end
    end

    for (i, k) in enumerate(wattmeter.number + 1:deviceNumber)
        if pmu.layout.bus[i] 
            if pmu.angle.status[i] == 1
                busIndex = pmu.layout.index[i]
                add_to_expression!(objective, residualx[k] + residualy[k])
                residual[k] = @constraint(jump, angley[busIndex] - anglex[busIndex] + residualy[k] - residualx[k] - pmu.angle.mean[i] == 0.0)
            else
                fix(residualx[k], 0.0; force = true)
                fix(residualy[k], 0.0; force = true)
            end
        end
    end

    @objective(jump, Min, objective)

    return DCStateEstimationLAV(
        PolarAngle(copy(bus.voltage.angle)),
        DCPowerSE(
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
            CartesianReal(Float64[]),
        ),
        DCStateEstimationMethodLAV(
            jump,
            anglex,
            angley,
            residualx,
            residualy,
            residual,
            deviceNumber
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::DCStateEstimation)

By computing the bus voltage angles, the function solves the DC state estimation problem.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DCStateEstimation` 
type.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCStateEstimationWLS)
    se = analysis.method
    bus = system.bus

    slackRange, elementsRemove = deleteSlackJacobian(analysis, bus.layout.slack)
    dcStateEstimationSolution(system, analysis, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if bus.voltage.angle[bus.layout.slack] != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += bus.voltage.angle[bus.layout.slack]
        end
    end

    restoreSlackJacobian(analysis, slackRange, elementsRemove, bus.layout.slack)
end

function solve!(system::PowerSystem, analysis::DCStateEstimationLAV)
    se = analysis.method
    
    @inbounds for i = 1:system.bus.number
        JuMP.set_start_value(se.angley[i]::JuMP.VariableRef, analysis.voltage.angle[i])
    end

    JuMP.optimize!(se.jump)

    for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(se.angley[i]::JuMP.VariableRef) - value(se.anglex[i]::JuMP.VariableRef)
    end
end

########### DC State Estimation WLS Solution by LU or LDLt Factorization ###########
function dcStateEstimationSolution(system::PowerSystem, analysis::DCStateEstimationWLS, factorization::LULDLt)
    se = analysis.method
    bus = system.bus

    precision = spdiagm(0 => se.weight)
    if !se.done
        se.done = true

        gain = dcGain(analysis, bus.layout.slack)
        se.factorization = sparseFactorization(gain, se.factorization)
    end
    b = transpose(se.jacobian) * precision * se.mean

    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, b, se.factorization)
end

########### DC State Estimation WLS Solution by QR Factorization ###########
function dcStateEstimationSolution(system::PowerSystem, analysis::DCStateEstimationWLS, factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64})
    se = analysis.method
    bus = system.bus

    precision = spdiagm(0 => sqrt.(se.weight))
    if !se.done
        se.done = true

        jacobianScale = precision * se.jacobian
        se.factorization = sparseFactorization(jacobianScale, se.factorization)
    end
    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, precision * se.mean, se.factorization)
end

function deleteSlackJacobian(analysis::DCStateEstimation, slack::Int64)
    se = analysis.method

    slackRange = se.jacobian.colptr[slack]:(se.jacobian.colptr[slack + 1] - 1)
    elementsRemove = se.jacobian.nzval[slackRange]
    @inbounds for i in slackRange
        se.jacobian.nzval[i] = 0.0
    end

    return slackRange, elementsRemove
end

function dcGain(analysis::DCStateEstimation, slack::Int64)
    se = analysis.method

    gain = transpose(se.jacobian) * spdiagm(0 => se.weight) * se.jacobian
    gain[slack, slack] = 1.0

    return gain
end

function restoreSlackJacobian(analysis::DCStateEstimation, slackRange::UnitRange{Int64}, elementsRemove::Array{Float64,1}, slack::Int64)
    se = analysis.method

    @inbounds for (k, i) in enumerate(slackRange)
        se.jacobian[se.jacobian.rowval[i], slack] = elementsRemove[k]
    end 
end

function constMeter(flag::Union{Int8, Float64})
    if flag == 0
        constIf = 0.0
    else
        constIf = 1.0
    end

    return constIf
end