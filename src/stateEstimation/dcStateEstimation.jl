"""
    dcWlsStateEstimation(system::PowerSystem, device::Measurement, method)

The function establishes the WLS model for DC state estimation, where the vector of state 
variables contains only bus voltage angles.

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
Set up the DC state estimation model to be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcWlsStateEstimation(system, device)
```

Set up the DC state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcWlsStateEstimation(system, device, Orthogonal)
```
"""
function dcWlsStateEstimation(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU, Orthogonal}} = LU)
    coefficient, mean, precision, badData, power = dcStateEstimationWLS(system, device)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr, Orthogonal => qr)
    return DCStateEstimationWLS(
        PolarAngle(Float64[]),
        power,
        LinearWLS(
            coefficient,
            precision,
            mean,
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            device.wattmeter.number + device.pmu.number,
            -1,
            true,
        ),
        badData
    )
end

function dcWlsStateEstimation(system::PowerSystem, device::Measurement, method::Type{<:Orthogonal})
    coefficient, mean, precision, badData, power = dcStateEstimationWLS(system, device)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return DCStateEstimationWLS(
        PolarAngle(Float64[]),
        power,
        LinearOrthogonal(
            coefficient,
            precision,
            mean,
            qr(sparse(Matrix(1.0I, 1, 1))),
            device.wattmeter.number + device.pmu.number,
            -1,
            true,
        ),
        badData
    )
end

function dcStateEstimationWLS(system::PowerSystem, device::Measurement)
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
    coeff = fill(0.0, nonZeroElement)
    mean = fill(0.0, deviceNumber)
    precision = spdiagm(0 => mean)

    count = 1
    for (i, k) in enumerate(wattmeter.layout.index)
        precision.nzval[i] = (1 / wattmeter.active.variance[i])
        
        status = wattmeter.active.status[i]
        if wattmeter.layout.bus[i]
            for j in dc.nodalMatrix.colptr[k]:(dc.nodalMatrix.colptr[k + 1] - 1)
                row[count] = i
                col[count] = dc.nodalMatrix.rowval[j]
                coeff[count] = status * dc.nodalMatrix.nzval[j] 
                count += 1
            end
            mean[i] = status * (wattmeter.active.mean[i] - dc.shiftPower[k] - bus.shunt.conductance[k])
        else
            status = wattmeter.active.status[i]

            if wattmeter.layout.from[i]
                addmitance = status * dc.admittance[k]
            else
                addmitance = -status * dc.admittance[k]
            end

            row[count] = i
            col[count] = branch.layout.from[k]
            coeff[count] = addmitance
            count += 1
            row[count] = i
            col[count] = branch.layout.to[k]
            coeff[count] = -addmitance

            mean[i] = status * (wattmeter.active.mean[i] + branch.parameter.shiftAngle[k] * addmitance) 
            
            count += 1
        end
    end

    rowindex = wattmeter.number + 1
    slackAngle = bus.voltage.angle[bus.layout.slack]
    for i = 1:pmu.number
        if pmu.layout.bus[i]
            status = pmu.angle.status[i]
            
            row[count] = rowindex
            col[count] = pmu.layout.index[i]
            coeff[count] = status

            mean[rowindex] = status * (pmu.angle.mean[i] - slackAngle)
            precision.nzval[rowindex] = (1 / pmu.angle.variance[i])
            
            count += 1; rowindex += 1
        end
    end

    coefficient = sparse(row, col, coeff, deviceNumber, bus.number)
    badData = BadData(true, 0.0, "", 0)
    power = DCPowerSE(CartesianReal(Float64[]), CartesianReal(Float64[]), CartesianReal(Float64[]), CartesianReal(Float64[]))

   return coefficient, mean, precision, badData, power
end

"""
    dcLavStateEstimation(system::PowerSystem, device::Measurement, optimizer)

The function establishes the LAV model for DC state estimation, where the vector of state 
variables contains only bus voltage angles.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish 
the LAV state estimation model. The LAV method offers increased robustness compared 
to WLS, ensuring unbiasedness even in the presence of various measurement errors and 
outliers.

Users can employ the LAV method to find an estimator by choosing one of the available 
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically, 
`Ipopt.Optimizer` suffices for most scenarios.

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
- `method`: the optimization model.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function dcLavStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    bus = system.bus
    branch = system.branch
    dc = system.model.dc
    wattmeter = device.wattmeter
    pmu = device.pmu
    deviceNumber = wattmeter.number + pmu.number

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    statex = @variable(jump, 0 <= statex[i = 1:bus.number])
    statey = @variable(jump, 0 <= statey[i = 1:bus.number])
    residualx = @variable(jump, 0 <= residualx[i = 1:deviceNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:deviceNumber])

    fix(statex[bus.layout.slack], 0.0; force = true)
    fix(statey[bus.layout.slack], 0.0; force = true)
    
    objective = @expression(jump, AffExpr())
    residual = Dict{Int64, JuMP.ConstraintRef}()
    for (i, k) in enumerate(wattmeter.layout.index)
        if device.wattmeter.active.status[i] == 1
            if wattmeter.layout.bus[i]
                angleCoeff = @expression(jump, AffExpr())
                for j in dc.nodalMatrix.colptr[k]:(dc.nodalMatrix.colptr[k + 1] - 1)
                    col = dc.nodalMatrix.rowval[j]
                    add_to_expression!(angleCoeff, dc.nodalMatrix.nzval[j] * (statex[col] - statey[col]))
                end
                residual[i] = @constraint(jump, angleCoeff + residualx[i] - residualy[i] - wattmeter.active.mean[i] + dc.shiftPower[k] + bus.shunt.conductance[k] == 0.0)
                add_to_expression!(objective, residualx[i] + residualy[i])
            else
                from = branch.layout.from[k]
                to = branch.layout.to[k]

                if wattmeter.layout.from[i]
                    admittance = dc.admittance[k] 
                else
                    admittance = -dc.admittance[k]
                end
                angleCoeff = admittance * (statex[from] - statey[from] - statex[to] + statey[to]) 
                residual[i] = @constraint(jump, angleCoeff + residualx[i] - residualy[i] - wattmeter.active.mean[i] - branch.parameter.shiftAngle[k] * admittance == 0.0)
                add_to_expression!(objective, residualx[i] + residualy[i])
            end
        else
            fix(residualx[i], 0.0; force = true)
            fix(residualy[i], 0.0; force = true)
        end
    end

    slackAngle = bus.voltage.angle[bus.layout.slack]
    for (i, k) in enumerate(wattmeter.number + 1:deviceNumber)
        if pmu.layout.bus[i] 
            if pmu.angle.status[i] == 1
                busIndex = pmu.layout.index[i]
                add_to_expression!(objective, residualx[k] + residualy[k])
                residual[k] = @constraint(jump, statex[busIndex] - statey[busIndex] + residualx[k] - residualy[k] - pmu.angle.mean[i] + slackAngle == 0.0)
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
        LAVMethod(
            jump,
            statex,
            statey,
            residualx,
            residualy,
            residual,
            deviceNumber
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::DCStateEstimation)

By computing the bus voltage angles, the function solves the DC state estimation model.

# Updates
The resulting bus voltage angles are stored in the `voltage` field of the `DCStateEstimation` 
type.

# Examples
Solving the DC state estimation model using the WLS method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcWlsStateEstimation(system, device)
solve!(system, analysis)
```

Solving the DC state estimation model using the LAV method:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = dcLavStateEstimation(system, device, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::DCStateEstimationWLS{LinearWLS})
    se = analysis.method
    bus = system.bus
    slackAngle = bus.voltage.angle[bus.layout.slack]

    slackRange, elementsRemove = deleteSlackCoefficient(analysis, bus.layout.slack)

    if se.run 
        analysis.method.run = false
        gain = dcGain(analysis, bus.layout.slack)

        if analysis.method.pattern == -1
            analysis.method.pattern = 0
            se.factorization = sparseFactorization(gain, se.factorization)
        else
            se.factorization = sparseFactorization!(gain, se.factorization)
        end
    end
    b = transpose(se.coefficient) * se.precision * se.mean

    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, b, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if slackAngle != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += slackAngle
        end
    end

    restoreSlackCoefficient(analysis, slackRange, elementsRemove, bus.layout.slack)
end

function solve!(system::PowerSystem, analysis::DCStateEstimationWLS{LinearOrthogonal})
    se = analysis.method
    bus = system.bus
    dc = system.model.dc
    slackAngle = bus.voltage.angle[bus.layout.slack]

    slackRange, elementsRemove = deleteSlackCoefficient(analysis, bus.layout.slack)

    @inbounds for i = 1:se.number
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    if se.run 
        analysis.method.run = false
        coefficientScale = se.precision * se.coefficient
        se.factorization = sparseFactorization(coefficientScale, se.factorization)
    end
    analysis.voltage.angle = sparseSolution(analysis.voltage.angle, se.precision * se.mean, se.factorization)

    analysis.voltage.angle[bus.layout.slack] = 0.0
    if slackAngle != 0.0
        @inbounds for i = 1:bus.number
            analysis.voltage.angle[i] += slackAngle
        end
    end

    @inbounds for i = 1:se.number
        se.precision.nzval[i] ^= 2
    end

    restoreSlackCoefficient(analysis, slackRange, elementsRemove, bus.layout.slack)
end

function solve!(system::PowerSystem, analysis::DCStateEstimationLAV)
    se = analysis.method
    slackAngle = system.bus.voltage.angle[system.bus.layout.slack]

    @inbounds for i = 1:system.bus.number
        JuMP.set_start_value(se.statex[i]::JuMP.VariableRef, analysis.voltage.angle[i] - slackAngle)
    end

    JuMP.optimize!(se.jump)

    for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(se.statex[i]::JuMP.VariableRef) - value(se.statey[i]::JuMP.VariableRef) + slackAngle
    end
end

function deleteSlackCoefficient(analysis::DCStateEstimation, slack::Int64)
    se = analysis.method

    slackRange = se.coefficient.colptr[slack]:(se.coefficient.colptr[slack + 1] - 1)
    elementsRemove = se.coefficient.nzval[slackRange]
    @inbounds for i in slackRange
        se.coefficient.nzval[i] = 0.0
    end

    return slackRange, elementsRemove
end

function dcGain(analysis::DCStateEstimation, slack::Int64)
    se = analysis.method

    gain = transpose(se.coefficient) * se.precision * se.coefficient
    gain[slack, slack] = 1.0

    return gain
end

function restoreSlackCoefficient(analysis::DCStateEstimation, slackRange::UnitRange{Int64}, elementsRemove::Array{Float64,1}, slack::Int64)
    se = analysis.method

    @inbounds for (k, i) in enumerate(slackRange)
        se.coefficient[se.coefficient.rowval[i], slack] = elementsRemove[k]
    end 
end

