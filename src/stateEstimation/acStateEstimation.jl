"""
    gaussNewton(system::PowerSystem, device::Measurement, method)

The function sets up the the Gauss-Newton method to solve the nonlinaer or AC state 
estimation model, where the vector of state variables is given in polar coordinates. The 
Gauss-Newton method throuout iterations provied WLS estimator.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish 
the nonlinear WLS state estimation framework. 

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
- `voltage`: the variable allocated to store the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `method`: the system model vectors and matrices, or alternatively, the optimization model;
- `bad`: the variable linked to identifying bad data within the measurement set. 

# Examples
Set up the AC state estimation model to be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
```

Set up the ACC state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device, Orthogonal)
```
"""
function gaussNewton(system::PowerSystem, device::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    jacobian, mean, precision, residual, type, index, range, power, current, _ = acStateEstimationWLS(system, device)

    method = Dict(LU => lu, LDLt => ldlt, QR => qr)
    return ACStateEstimationWLS(
        Polar(
            copy(system.bus.voltage.magnitude), 
            copy(system.bus.voltage.angle)
        ),
        power,
        current, 
        NonlinearWLS(
            jacobian,
            precision,
            mean,
            residual,
            fill(0.0, 2 * system.bus.number),
            get(method, factorization, lu)(sparse(Matrix(1.0I, 1, 1))),
            type,
            index,
            range,
            -1
        )
    )
end

function gaussNewton(system::PowerSystem, device::Measurement, method::Type{<:Orthogonal})
    jacobian, mean, precision, residual, type, index, range, power, current, correlated = acStateEstimationWLS(system, device)

    if correlated
        throw(ErrorException("The precision matrix is non-diagonal, therefore preventing the use of the orthogonal method.")) 
    end

    return ACStateEstimationWLS(
        Polar(
            copy(system.bus.voltage.magnitude), 
            copy(system.bus.voltage.angle)
        ),
        power,
        current, 
        NonlinearOrthogonal(
            jacobian,
            precision,
            mean,
            residual,
            fill(0.0, 2 * system.bus.number),
            qr(sparse(Matrix(1.0I, 1, 1))),
            type,
            index,
            range,
            -1
        )
    )
end

function acStateEstimationWLS(system::PowerSystem, device::Measurement)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    voltmeter = device.voltmeter
    ammeter = device.ammeter
    wattmeter = device.wattmeter
    varmeter = device.varmeter
    pmu = device.pmu
    correlated = false

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(ac.nodalMatrix)
        acModel!(system)
    end
    if isempty(system.bus.supply.generator[system.bus.layout.slack])
        changeSlackBus!(system)
    end

    measureNumber = voltmeter.number + ammeter.number + wattmeter.number + varmeter.number + 2 * pmu.number
    nonZeroJacobian = voltmeter.number + 4 * ammeter.number
    nonZeroPrecision = copy(measureNumber)

    for (i, index) in enumerate(wattmeter.layout.index)
        if wattmeter.layout.bus[i]
            nonZeroJacobian += 2 * (ac.nodalMatrix.colptr[index + 1] - ac.nodalMatrix.colptr[index])
        else
            nonZeroJacobian += 4 
        end
    end
    for (i, index) in enumerate(varmeter.layout.index)
        if varmeter.layout.bus[i]
            nonZeroJacobian += 2 * (ac.nodalMatrix.colptr[index + 1] - ac.nodalMatrix.colptr[index])
        else
            nonZeroJacobian += 4
        end
    end

    for i = 1:pmu.number
        if pmu.layout.bus[i]
            if pmu.layout.polar[i]
                nonZeroJacobian += 2
            else
                nonZeroJacobian += 4
            end
        else
            nonZeroJacobian += 8 
        end

        if !pmu.layout.polar[i] && pmu.layout.correlated[i]  
            nonZeroPrecision += 2
        end
    end

    jac = SparseModel(fill(0, nonZeroJacobian), fill(0, nonZeroJacobian), fill(0.0, nonZeroJacobian), 1, 1)
    prec = SparseModel(fill(0, nonZeroPrecision) , fill(0, nonZeroPrecision), fill(0.0, nonZeroPrecision), 1, 1)
    mean = fill(0.0, measureNumber)
    
    type = fill(Int8(0), measureNumber)
    index = fill(0, measureNumber)
    range = fill(1, 6)

    for (i, k) in enumerate(voltmeter.layout.index)
        mean[i] = voltmeter.magnitude.status[i] * voltmeter.magnitude.mean[i]
        prec = precisionDiagonal(prec, voltmeter.magnitude.variance[i])

        type, index = typeIndex(jac, type, index, voltmeter.magnitude.status[i], k, 1)
        jac = jacobianInitialize(jac, voltmeter.magnitude.status[i], k + bus.number)
    end
    range[2] = jac.idx

    for (i, k) in enumerate(wattmeter.layout.index)
        mean[jac.idx] = wattmeter.active.status[i] * wattmeter.active.mean[i]
        prec = precisionDiagonal(prec, wattmeter.active.variance[i])

        if wattmeter.layout.bus[i]
            type, index = typeIndex(jac, type, index, wattmeter.active.status[i], k, 2)
            jac = jacobianInitialize(jac, ac.nodalMatrix, k, bus.number)
        else
            type, index = typeIndex(jac, type, index, wattmeter.active.status[i], wattmeter.layout.from[i], k, 3, 4)
            jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)
        end
    end
    range[3] = jac.idx

    for (i, k) in enumerate(varmeter.layout.index)
        mean[jac.idx] = varmeter.reactive.status[i] * varmeter.reactive.mean[i]
        prec = precisionDiagonal(prec, varmeter.reactive.variance[i])

        if varmeter.layout.bus[i]
            type, index = typeIndex(jac, type, index, varmeter.reactive.status[i], k, 5)
            jac = jacobianInitialize(jac, ac.nodalMatrix, k, bus.number)
        else
            type, index = typeIndex(jac, type, index, varmeter.reactive.status[i], varmeter.layout.from[i], k, 6, 7)
            jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)
        end
    end
    range[4] = jac.idx

    for (i, k) in enumerate(ammeter.layout.index)
        mean[jac.idx] = ammeter.magnitude.status[i] * ammeter.magnitude.mean[i]
        prec = precisionDiagonal(prec, ammeter.magnitude.variance[i])
   
        type, index = typeIndex(jac, type, index, ammeter.magnitude.status[i], ammeter.layout.from[i], k, 8, 9)
        jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)
    end
    range[5] = jac.idx
    
    for (i, k) in enumerate(pmu.layout.index)
        if pmu.layout.polar[i]
            mean[jac.idx] = pmu.magnitude.status[i] * pmu.magnitude.mean[i]
            mean[jac.idx + 1] = pmu.angle.status[i] * pmu.angle.mean[i]

            prec = precisionDiagonal(prec, pmu.magnitude.variance[i])
            prec = precisionDiagonal(prec, pmu.angle.variance[i])  
            
            if pmu.layout.bus[i]
                type, index = typeIndex(jac, type, index, pmu.magnitude.status[i], k, 10)
                jac = jacobianInitialize(jac, pmu.magnitude.status[i], k + bus.number)

                type, index = typeIndex(jac, type, index, pmu.angle.status[i], k, 11)
                jac = jacobianInitialize(jac, pmu.angle.status[i], k)
            else
                type, index = typeIndex(jac, type, index, pmu.magnitude.status[i], pmu.layout.from[i], k, 8, 9)
                jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)

                type, index = typeIndex(jac, type, index, pmu.angle.status[i], pmu.layout.from[i], k, 12, 13)
                jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)
            end
        else
            cosAngle = cos(pmu.angle.mean[i])
            sinAngle = sin(pmu.angle.mean[i])
            status = pmu.magnitude.status[i] * pmu.angle.status[i]

            mean[jac.idx] = status * pmu.magnitude.mean[i] * cosAngle
            mean[jac.idx + 1] = status * pmu.magnitude.mean[i] * sinAngle

            varianceRe = pmu.magnitude.variance[i] * cosAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * sinAngle)^2
            varianceIm = pmu.magnitude.variance[i] * sinAngle^2 + pmu.angle.variance[i] * (pmu.magnitude.mean[i] * cosAngle)^2
            if pmu.layout.correlated[i]
                correlated = true
                covariance = sinAngle * cosAngle * (pmu.magnitude.variance[i] - pmu.angle.variance[i] * pmu.magnitude.mean[i]^2)
                prec = precisionBlock(prec, varianceRe, varianceIm, covariance)
            else
                prec = precisionDiagonal(prec, varianceRe)
                prec = precisionDiagonal(prec, varianceIm)
            end

            if pmu.layout.bus[i]
                type, index = typeIndex(jac, type, index, status, k, 14)
                jac = jacobianInitialize(jac, k, bus.number)

                type, index = typeIndex(jac, type, index, status, k, 15)
                jac = jacobianInitialize(jac, k, bus.number)
            else
                type, index = typeIndex(jac, type, index, status, pmu.layout.from[i], k, 16, 17)
                jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)

                type, index = typeIndex(jac, type, index, status, pmu.layout.from[i], k, 18, 19)
                jac = jacobianInitialize(jac, branch.layout.from[k], branch.layout.to[k], bus.number)
            end

        end
    end
    range[6] = prec.idx

    jacobian = sparse(jac.row, jac.col, jac.val, measureNumber, 2 * bus.number)
    precision = sparse(prec.row, prec.col, prec.val, measureNumber, measureNumber)

    power = PowerSE(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), 
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))
    current = Current(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))      

   return jacobian, mean, precision, fill(0.0, measureNumber), type, index, range, power, current, correlated
end

"""
    acLavStateEstimation(system::PowerSystem, device::Measurement, optimizer)

The function sets up the the LAV method to solve the nonlinaer or AC state estimation 
model, where the vector of state variables is given in polar coordinates.

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
- `voltage`: the variable allocated to store the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `method`: the optimization model.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = acLavStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function acLavStateEstimation(system::PowerSystem, device::Measurement, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    voltmeter = device.voltmeter
    ammeter = device.ammeter
    wattmeter = device.wattmeter
    varmeter = device.varmeter
    pmu = device.pmu

    measureNumber = voltmeter.number + ammeter.number + wattmeter.number + varmeter.number + 2 * pmu.number

    if isempty(ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    statex = @variable(jump, 0 <= magnitudex[i = 1:(2 * bus.number)])
    statey = @variable(jump, 0 <= magnitudey[i = 1:(2 * bus.number)])

    anglex = @view(statex[1:bus.number])
    magnitudex = @view(statex[(bus.number + 1):end])
    angley = @view(statey[1:bus.number])
    magnitudey = @view(statey[(bus.number + 1):end])

    residualx = @variable(jump, 0 <= residualx[i = 1:measureNumber])
    residualy = @variable(jump, 0 <= residualy[i = 1:measureNumber])

    fix(anglex[bus.layout.slack], 0.0; force = true)
    fix(angley[bus.layout.slack], 0.0; force = true)

    objective = @expression(jump, AffExpr())
    residual = Dict{Int64, JuMP.ConstraintRef}()
    
    for (k, index) in enumerate(voltmeter.layout.index)
        if voltmeter.magnitude.status[k] == 1
            add_to_expression!(objective, residualx[k] + residualy[k])
            residual[k] = @constraint(jump, magnitudex[index] - magnitudey[index] + residualx[k] - residualy[k] - voltmeter.magnitude.mean[k] == 0.0)
        else
            fix!(residualx, residualy, k)
        end
    end

    idx = voltmeter.number + 1
    for (k, index) in enumerate(wattmeter.layout.index)
        if wattmeter.active.status[k] == 1
            add_to_expression!(objective, residualx[idx] + residualy[idx])

            if wattmeter.layout.bus[k]
                Vi = magnitudex[index] - magnitudey[index]
                expr = @expression(jump, Vi * real(ac.nodalMatrixTranspose[index, index]))
                
                for ptr in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
                    j = ac.nodalMatrix.rowval[ptr]
                    if index != j
                        Gij = real(ac.nodalMatrixTranspose.nzval[ptr])
                        Bij = imag(ac.nodalMatrixTranspose.nzval[ptr])
                        cosAngle = @expression(jump, cos(anglex[index] - angley[index] - anglex[j] + angley[j]))
                        sinAngle = @expression(jump, sin(anglex[index] - angley[index] - anglex[j] + angley[j]))
                        expr = @expression(jump, expr + (magnitudex[j] - magnitudey[j]) * (Gij * cosAngle + Bij * sinAngle))
                    end
                end
                residual[idx] = @constraint(jump, Vi * expr + residualx[idx] - residualy[idx] - wattmeter.active.mean[k] == 0)
            else
                i, j, gij, bij, gsi, _, tij, Fij = branchParameter(branch, ac, index)

                Vi = magnitudex[i] - magnitudey[i]
                Vj = magnitudex[j] - magnitudey[j]
                cosAngle = @expression(jump, cos(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
                sinAngle = @expression(jump, sin(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
                
                if wattmeter.layout.from[k]
                    residual[idx] = @constraint(jump, (gij + gsi) * tij^2 * Vi^2 - tij * (gij * cosAngle + bij * sinAngle) * Vi * Vj + residualx[idx] - residualy[idx] - wattmeter.active.mean[k] == 0)
                else
                    residual[idx] = @constraint(jump, (gij + gsi) * Vj^2 - tij * (gij * cosAngle - bij * sinAngle) * Vi * Vj + residualx[idx] - residualy[idx] - wattmeter.active.mean[k] == 0)   
                end
            end
        else
            fix!(residualx, residualy, idx)
        end
        idx += 1
    end

    for (k, index) in enumerate(varmeter.layout.index)
        if varmeter.reactive.status[k] == 1
            add_to_expression!(objective, residualx[idx] + residualy[idx])

            if varmeter.layout.bus[k]
                Vi = magnitudex[index] - magnitudey[index]
                expr = @expression(jump, -Vi * imag(ac.nodalMatrixTranspose[index, index]))
                
                for ptr in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
                    j = ac.nodalMatrix.rowval[ptr]
                    if index != j
                        Gij = real(ac.nodalMatrixTranspose.nzval[ptr])
                        Bij = imag(ac.nodalMatrixTranspose.nzval[ptr])
                        cosAngle = @expression(jump, cos(anglex[index] - angley[index] - anglex[j] + angley[j]))
                        sinAngle = @expression(jump, sin(anglex[index] - angley[index] - anglex[j] + angley[j]))
                        expr = @expression(jump, expr + (magnitudex[j] - magnitudey[j]) * (Gij * sinAngle - Bij * cosAngle))
                    end
                end
                residual[idx] = @constraint(jump, Vi * expr + residualx[idx] - residualy[idx] - varmeter.reactive.mean[k] == 0)
            else
                i, j, gij, bij, _, bsi, tij, Fij = branchParameter(branch, ac, index)
                Vi = magnitudex[i] - magnitudey[i]
                Vj = magnitudex[j] - magnitudey[j]
                cosAngle = @expression(jump, cos(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
                sinAngle = @expression(jump, sin(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))

                if varmeter.layout.from[k]
                    residual[idx] = @constraint(jump, - (bij + bsi) * tij^2 * Vi^2 - tij * (gij * sinAngle - bij * cosAngle) * Vi * Vj + residualx[idx] - residualy[idx] - varmeter.reactive.mean[k] == 0)
                else
                    residual[idx] = @constraint(jump, - (bij + bsi) * Vj^2 + tij * (gij * sinAngle + bij * cosAngle) * Vi * Vj + residualx[idx] - residualy[idx] - varmeter.reactive.mean[k] == 0)   
                end
            end
        else
            fix!(residualx, residualy, idx)
        end
        idx += 1
    end

    for (k, index) in enumerate(ammeter.layout.index)
        if ammeter.magnitude.status[k] == 1
            add_to_expression!(objective, residualx[idx] + residualy[idx])

            i, j, gij, bij, gsi, bsi, tij, Fij = branchParameter(branch, ac, index)
            Vi = magnitudex[i] - magnitudey[i]
            Vj = magnitudex[j] - magnitudey[j]
            cosAngle = @expression(jump, cos(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
            sinAngle = @expression(jump, sin(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
            
            if ammeter.layout.from[k]
                A, B, C, D = IijCoeff(gij, gsi, bij, bsi, tij)
                residual[idx] = @constraint(jump, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cosAngle - D * sinAngle)) + residualx[idx] - residualy[idx] - ammeter.magnitude.mean[k] == 0)
            else
                A, B, C, D = IjiCoeff(gij, gsi, bij, bsi, tij)
                residual[idx] = @constraint(jump, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cosAngle + D * sinAngle)) + residualx[idx] - residualy[idx] - ammeter.magnitude.mean[k] == 0)   
            end
        else
            fix!(residualx, residualy, idx)
        end
        idx += 1
    end

    for (k, index) in enumerate(pmu.layout.index)
        if pmu.layout.polar[k]
            if pmu.layout.bus[k]
                if pmu.magnitude.status[k] == 1
                    add_to_expression!(objective, residualx[idx] + residualy[idx])
                    residual[idx] = @constraint(jump, magnitudex[index] - magnitudey[index] + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] == 0.0)
                else
                    fix!(residualx, residualy, idx)
                end

                if pmu.angle.status[k] == 1
                    add_to_expression!(objective, residualx[idx + 1] + residualy[idx + 1])
                    residual[idx + 1] = @constraint(jump, anglex[index] - angley[index] + residualx[idx + 1] - residualy[idx + 1] - pmu.angle.mean[k] == 0.0)
                else
                    fix!(residualx, residualy, idx + 1)
                end
            else
                if pmu.magnitude.status[k] == 1
                    add_to_expression!(objective, residualx[idx] + residualy[idx])

                    i, j, gij, bij, gsi, bsi, tij, Fij = branchParameter(branch, ac, index)
                    cosAngle = @expression(jump, cos(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
                    sinAngle = @expression(jump, sin(anglex[i] - angley[i] - anglex[j] + angley[j] - Fij))
                    Vi = magnitudex[i] - magnitudey[i]
                    Vj = magnitudex[j] - magnitudey[j]

                    if pmu.layout.from[k]
                        A, B, C, D = IijCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx] = @constraint(jump, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cosAngle - D * sinAngle)) + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] == 0)
                    else
                        A, B, C, D = IjiCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx] = @constraint(jump, sqrt(A * Vi^2 + B * Vj^2 - 2 * Vi * Vj * (C * cosAngle + D * sinAngle)) + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] == 0)   
                    end
                else
                    fix!(residualx, residualy, idx)
                end

                if pmu.angle.status[k] == 1
                    add_to_expression!(objective, residualx[idx + 1] + residualy[idx + 1])

                    i, j, gij, bij, gsi, bsi, tij, Fij = branchParameter(branch, ac, index)
                    θi = anglex[i] - angley[i]
                    θj = anglex[j] - angley[j]
                    Vi = magnitudex[i] - magnitudey[i]
                    Vj = magnitudex[j] - magnitudey[j]

                    if pmu.layout.from[k]
                        A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)
                        IijRe = @expression(jump, (A * cos(θi) - B * sin(θi)) * Vi - (C * cos(θj + Fij) - D * sin(θj + Fij)) * Vj)
                        IijIm = @expression(jump, (A * sin(θi) + B * cos(θi)) * Vi - (C * sin(θj + Fij) + D * cos(θj + Fij)) * Vj)

                        residual[idx + 1] = @constraint(jump, atan(IijIm, IijRe) + residualx[idx + 1] - residualy[idx + 1] - pmu.angle.mean[k] == 0)  
                    else
                        A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)
                        IijRe = @expression(jump, (A * cos(θj) - B * sin(θj)) * Vj - (C * cos(θi - Fij) - D * sin(θi - Fij)) * Vi)
                        IijIm = @expression(jump, (A * sin(θj) + B * cos(θj)) * Vj - (C * sin(θi - Fij) + D * cos(θi - Fij)) * Vi)

                        residual[idx + 1] = @constraint(jump, atan(IijIm, IijRe) + residualx[idx + 1] - residualy[idx + 1] - pmu.angle.mean[k] == 0)
                    end
                else
                    fix!(residualx, residualy, idx + 1)
                end
            end
        else
            if pmu.magnitude.status[k] == 1 && pmu.angle.status[k] == 1
                add_to_expression!(objective, residualx[idx] + residualy[idx])
                add_to_expression!(objective, residualx[idx + 1] + residualy[idx + 1])

                if pmu.layout.bus[k]
                    Vi = magnitudex[index] - magnitudey[index]
                    cosAngle = @expression(jump, cos(anglex[index] - angley[index]))
                    sinAngle = @expression(jump, sin(anglex[index] - angley[index]))

                    residual[idx] = @constraint(jump, Vi * cosAngle + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] * cos(pmu.angle.mean[k]) == 0.0)
                    residual[idx + 1] = @constraint(jump, Vi * sinAngle + residualx[idx + 1] - residualy[idx + 1] - pmu.magnitude.mean[k] * sin(pmu.angle.mean[k]) == 0.0)
                else
                    i, j, gij, bij, gsi, bsi, tij, Fij = branchParameter(branch, ac, index)
                    θi = anglex[i] - angley[i]
                    θj = anglex[j] - angley[j]
                    Vi = magnitudex[i] - magnitudey[i]
                    Vj = magnitudex[j] - magnitudey[j]
                    
                    if pmu.layout.from[k]
                        A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx] = @constraint(jump, (A * cos(θi) - B * sin(θi)) * Vi - (C * cos(θj + Fij) - D * sin(θj + Fij)) * Vj + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] * cos(pmu.angle.mean[k]) == 0.0)
                    else
                        A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx] = @constraint(jump, (A * cos(θj) - B * sin(θj)) * Vj - (C * cos(θi - Fij) - D * sin(θi - Fij)) * Vi + residualx[idx] - residualy[idx] - pmu.magnitude.mean[k] * cos(pmu.angle.mean[k]) == 0.0)   
                    end

                    if pmu.layout.from[k]
                        A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx + 1] = @constraint(jump, (A * sin(θi) + B * cos(θi)) * Vi - (C * sin(θj + Fij) + D * cos(θj + Fij)) * Vj + residualx[idx + 1] - residualy[idx + 1] - pmu.magnitude.mean[k] * sin(pmu.angle.mean[k]) == 0.0)
                    else
                        A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)
                        residual[idx + 1] = @constraint(jump, (A * sin(θj) + B * cos(θj)) * Vj - (C * sin(θi - Fij) + D * cos(θi - Fij)) * Vi + residualx[idx + 1] - residualy[idx + 1] - pmu.magnitude.mean[k] * sin(pmu.angle.mean[k]) == 0.0)   
                    end
                end
            else
                fix!(residualx, residualy, idx)
                fix!(residualx, residualy, idx + 1)
            end
        end
        idx += 2
    end

    @objective(jump, Min, objective)

    return ACStateEstimationLAV(
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
            measureNumber
        )
    )
end


"""
    solve!(system::PowerSystem, analysis::ACStateEstimation)

By computing the bus voltage magnitudes and angles, the function solves the AC state 
estimation model.

# Updates
The resulting bus voltage magnitudes and angles are stored in the `voltage` field of the 
`ACStateEstimation` type.

# Examples
Solving the AC state estimation model and obtaining the WLS estimator:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system14, analysis)
    if stopping < 1e-8
        break
    end
end
```
"""
function solve!(system::PowerSystem, analysis::ACStateEstimationWLS{NonlinearWLS})
    normalEquation!(system, analysis)

    bus = system.bus
    se = analysis.method
    jacobian = se.jacobian

    slackRange = jacobian.colptr[bus.layout.slack]:(jacobian.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = jacobian.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        jacobian[jacobian.rowval[i], bus.layout.slack] = 0.0
    end
    gain = (transpose(jacobian) * se.precision * jacobian) 
    gain[bus.layout.slack, bus.layout.slack] = 1.0
  
    if se.pattern == -1
        se.pattern = 0
        se.factorization = sparseFactorization(gain, se.factorization)
    else
        se.factorization = sparseFactorization!(gain, se.factorization)
    end

    se.increment = sparseSolution(se.increment, transpose(jacobian) * se.precision * se.residual, se.factorization)

    @inbounds for (k, i) in enumerate(slackRange)
        jacobian[jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    end 

    se.increment[bus.layout.slack] = 0.0
    maxAbsIncrement = 0.0
    @inbounds for i = 1:bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + se.increment[i]
        analysis.voltage.magnitude[i] = analysis.voltage.magnitude[i] + se.increment[i + bus.number]

        maxAbsIncrement = max(maxAbsIncrement, abs(se.increment[i]), abs(se.increment[i + bus.number]))
    end

    return maxAbsIncrement
end

function solve!(system::PowerSystem, analysis::ACStateEstimationWLS{NonlinearOrthogonal})
    normalEquation!(system, analysis)

    bus = system.bus
    se = analysis.method
    jacobian = se.jacobian

    @inbounds for i = 1:lastindex(se.mean)
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    slackRange = jacobian.colptr[bus.layout.slack]:(jacobian.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = jacobian.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        jacobian[jacobian.rowval[i], bus.layout.slack] = 0.0
    end

    JacobianScale = se.precision * se.jacobian
    if se.pattern == -1
        se.pattern = 0
        se.factorization = sparseFactorization(JacobianScale, se.factorization)
    else
        se.factorization = sparseFactorization!(JacobianScale, se.factorization)
    end
    
    se.increment = sparseSolution(se.increment, se.precision * se.residual, se.factorization)

    @inbounds for (k, i) in enumerate(slackRange)
        jacobian[jacobian.rowval[i], bus.layout.slack] = elementsRemove[k]
    end 

    se.increment[bus.layout.slack] = 0.0
    maxAbsIncrement = 0.0
    @inbounds for i = 1:bus.number
        analysis.voltage.angle[i] = analysis.voltage.angle[i] + se.increment[i]
        analysis.voltage.magnitude[i] = analysis.voltage.magnitude[i] + se.increment[i + bus.number]

        maxAbsIncrement = max(maxAbsIncrement, abs(se.increment[i]), abs(se.increment[i + bus.number]))
    end

    @inbounds for i = 1:lastindex(se.mean)
        se.precision.nzval[i] ^= 2
    end

    return maxAbsIncrement
end

function solve!(system::PowerSystem, analysis::ACStateEstimationLAV)
    se = analysis.method
    bus = system.bus

    @inbounds for i = 1:bus.number
        JuMP.set_start_value(se.statex[i]::JuMP.VariableRef, bus.voltage.angle[i])
        JuMP.set_start_value(se.statex[i + bus.number]::JuMP.VariableRef, bus.voltage.magnitude[i])
    end

    JuMP.optimize!(se.jump)

    for i = 1:bus.number
        analysis.voltage.angle[i] = value(se.statex[i]::JuMP.VariableRef) - value(se.statey[i]::JuMP.VariableRef)
        analysis.voltage.magnitude[i] = value(se.statex[i + bus.number]::JuMP.VariableRef) - value(se.statey[i + bus.number]::JuMP.VariableRef)
        
    end
end

function normalEquation!(system::PowerSystem, analysis::ACStateEstimationWLS)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    se = analysis.method
    voltage = analysis.voltage
    jacobian = se.jacobian

    for col = 1:bus.number
        for lin in jacobian.colptr[col]:(jacobian.colptr[col + 1] - 1)
            row = jacobian.rowval[lin]
            index = se.index[row]

            if se.type[row] == 2 # Pᵢ
                if col == se.index[row]
                    I1 = 0.0; I2 = 0.0
                    for k in ac.nodalMatrix.colptr[col]:(ac.nodalMatrix.colptr[col + 1] - 1)
                        j = ac.nodalMatrix.rowval[k]
                        Gij = real(ac.nodalMatrixTranspose.nzval[k])
                        Bij = imag(ac.nodalMatrixTranspose.nzval[k])
                        cosAngle = cos(voltage.angle[col] - voltage.angle[j])
                        sinAngle = sin(voltage.angle[col] - voltage.angle[j])
                        I1 -= voltage.magnitude[j] * (Gij * sinAngle - Bij * cosAngle)
                        I2 += voltage.magnitude[j] * (Gij * cosAngle + Bij * sinAngle)
                    end
                    se.residual[row] = se.mean[row] - voltage.magnitude[col] * I2

                    jacobian[row, col] = voltage.magnitude[col] * I1 - imag(ac.nodalMatrix[col, col]) * voltage.magnitude[col]^2  # ∂Pᵢ / ∂θᵢ
                    jacobian[row, col + bus.number] = I2 + real(ac.nodalMatrix[col, col]) * voltage.magnitude[col]                # ∂Pᵢ / ∂Vᵢ
                else
                    Gij = real(ac.nodalMatrix[index, col])
                    Bij = imag(ac.nodalMatrix[index, col])
                    cosAngle = cos(voltage.angle[index] - voltage.angle[col])
                    sinAngle = sin(voltage.angle[index] - voltage.angle[col])

                    jacobian[row, col] = voltage.magnitude[index] * voltage.magnitude[col] * (Gij * sinAngle - Bij * cosAngle)  # ∂Pᵢ / ∂θⱼ
                    jacobian[row, col + bus.number] = voltage.magnitude[index] * (Gij * cosAngle + Bij * sinAngle)              # ∂Pᵢ / ∂Vⱼ
                end

            elseif se.type[row] == 5 # Qᵢ
                if col == se.index[row]
                    I1 = 0.0; I2 = 0.0
                    for k in ac.nodalMatrix.colptr[col]:(ac.nodalMatrix.colptr[col + 1] - 1)
                        j = ac.nodalMatrix.rowval[k]
                        Gij = real(ac.nodalMatrixTranspose.nzval[k])
                        Bij = imag(ac.nodalMatrixTranspose.nzval[k])
                        cosAngle = cos(voltage.angle[col] - voltage.angle[j])
                        sinAngle = sin(voltage.angle[col] - voltage.angle[j])
                        I1 += voltage.magnitude[j] * (Gij * cosAngle + Bij * sinAngle)
                        I2 += voltage.magnitude[j] * (Gij * sinAngle - Bij * cosAngle)
                    end
                    se.residual[row] = se.mean[row] - voltage.magnitude[col] * I2

                    jacobian[row, col] = voltage.magnitude[col] * I1 - real(ac.nodalMatrix[col, col]) * voltage.magnitude[col]^2  # ∂Qᵢ / ∂θᵢ
                    jacobian[row, col + bus.number] = I2 - imag(ac.nodalMatrix[col, col]) * voltage.magnitude[col]                # ∂Qᵢ / ∂Vᵢ
                else
                    Gij = real(ac.nodalMatrix[index, col])
                    Bij = imag(ac.nodalMatrix[index, col])
                    cosAngle = cos(voltage.angle[index] - voltage.angle[col])
                    sinAngle = sin(voltage.angle[index] - voltage.angle[col])
    
                    jacobian[row, col] = -voltage.magnitude[index] * voltage.magnitude[col] * (Gij * cosAngle + Bij * sinAngle)  # ∂Qᵢ / ∂θⱼ
                    jacobian[row, col + bus.number] = voltage.magnitude[index] * (Gij * sinAngle - Bij * cosAngle)               # ∂Qᵢ / ∂Vⱼ
                end

            else
                i, j, gij, bij, gsi, bsi, tij, Fij = branchParameter(branch, ac, index)

                cosAngle = cos(voltage.angle[i] - voltage.angle[j] - Fij)
                sinAngle = sin(voltage.angle[i] - voltage.angle[j] - Fij)

                if se.type[row] == 3 # Pᵢⱼ
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (gij + gsi) * tij^2 * voltage.magnitude[i]^2 + tij * (gij * cosAngle + bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j]

                        jacobian[row, col] = tij * (gij * sinAngle - bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                                         # ∂Pᵢⱼ / ∂θᵢ
                        jacobian[row, col + bus.number] = 2 * (gij + gsi) * tij^2 * voltage.magnitude[i] - tij * (gij * cosAngle + bij * sinAngle) * voltage.magnitude[j]  # ∂Pᵢⱼ / ∂Vᵢ
                    else
                        jacobian[row, col] = -tij * (gij * sinAngle - bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]  # ∂Pᵢⱼ / ∂θⱼ
                        jacobian[row, col + bus.number] = -tij * (gij * cosAngle + bij * sinAngle) * voltage.magnitude[i]            # ∂Pᵢⱼ / ∂Vⱼ
                    end

                elseif se.type[row] == 4 # Pⱼᵢ
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (gij + gsi) * voltage.magnitude[j]^2 + tij * (gij * cosAngle - bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j] 

                        jacobian[row, col] = tij * (gij * sinAngle + bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]  # ∂Pⱼᵢ / ∂θᵢ
                        jacobian[row, col + bus.number] = -tij * (gij * cosAngle - bij * sinAngle) * voltage.magnitude[j]           # ∂Pⱼᵢ / ∂Vᵢ
                    else
                        jacobian[row, col] = -tij * (gij * sinAngle + bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                                # ∂Pⱼᵢ / ∂θⱼ
                        jacobian[row, col + bus.number] = 2 * (gij + gsi) * voltage.magnitude[j] - tij * (gij * cosAngle - bij * sinAngle) * voltage.magnitude[i]  # ∂Pⱼᵢ / ∂Vⱼ
                    end

                elseif se.type[row] == 6 # Qᵢⱼ
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] + (bij + bsi) * tij^2 * voltage.magnitude[i]^2 + tij * (gij * sinAngle - bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]

                        jacobian[row, col] = -tij * (gij * cosAngle + bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j]                                         # ∂Qᵢⱼ / ∂θᵢ
                        jacobian[row, col + bus.number] = -2 * (bij + bsi) * tij^2 * voltage.magnitude[i] - tij * (gij * sinAngle - bij * cosAngle) * voltage.magnitude[j]  # ∂Qᵢⱼ / ∂Vᵢ
                    else
                        jacobian[row, col] = tij * (gij * cosAngle + bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j]  # ∂Qᵢⱼ / ∂θⱼ
                        jacobian[row, col + bus.number] = -tij * (gij * sinAngle - bij * cosAngle) * voltage.magnitude[i]           # ∂Qᵢⱼ / ∂Vⱼ
                    end
                
                elseif se.type[row] == 7 # Qⱼᵢ               
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] + (bij + bsi) * voltage.magnitude[j]^2 - tij * (gij * sinAngle + bij * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j] 

                        jacobian[row, col] = tij * (gij * cosAngle - bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j]  # ∂Qⱼᵢ / ∂θᵢ
                        jacobian[row, col + bus.number] = tij * (gij * sinAngle + bij * cosAngle) * voltage.magnitude[j]            # ∂Qⱼᵢ / ∂Vᵢ
                    else
                        jacobian[row, col] = -tij * (gij * cosAngle - bij * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j]                                # ∂Qⱼᵢ / ∂θⱼ
                        jacobian[row, col + bus.number] = -2 * (bij + bsi) * voltage.magnitude[j] + tij * (gij * sinAngle + bij * cosAngle) * voltage.magnitude[i] # ∂Qⱼᵢ / ∂Vⱼ
                    end  

                elseif se.type[row] == 8 # Iᵢⱼ
                    A, B, C, D = IijCoeff(gij, gsi, bij, bsi, tij)
                    Iinv = 1 / sqrt(A * voltage.magnitude[i]^2 + B * voltage.magnitude[j]^2 - 2 * voltage.magnitude[i] * voltage.magnitude[j] * (C * cosAngle - D * sinAngle))

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (1 / Iinv)

                        jacobian[row, col] = Iinv * (C * sinAngle + D * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                     # ∂Iᵢⱼ / ∂θᵢ
                        jacobian[row, col + bus.number] = Iinv * (A * voltage.magnitude[i] - (C * cosAngle - D * sinAngle) * voltage.magnitude[j])  # ∂Iᵢⱼ / ∂Vᵢ
                    else
                        jacobian[row, col] = - Iinv * (C * sinAngle + D * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                   # ∂Iᵢⱼ / ∂θⱼ
                        jacobian[row, col + bus.number] = Iinv * (B * voltage.magnitude[j] - (C * cosAngle - D * sinAngle) * voltage.magnitude[i])  # ∂Iᵢⱼ / ∂Vⱼ
                    end  

                elseif se.type[row] == 9 # Iⱼᵢ
                    A, B, C, D = IjiCoeff(gij, gsi, bij, bsi, tij)
                    Iinv = 1 / sqrt(A * voltage.magnitude[i]^2 + B * voltage.magnitude[j]^2 - 2 * voltage.magnitude[i] * voltage.magnitude[j] * (C * cosAngle + D * sinAngle))

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (1 / Iinv)

                        jacobian[row, col] = Iinv * (C * sinAngle - D * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                     # ∂Iⱼᵢ / ∂θᵢ
                        jacobian[row, col + bus.number] = Iinv * (A * voltage.magnitude[i] - (C * cosAngle + D * sinAngle) * voltage.magnitude[j])  # ∂Iⱼᵢ / ∂Vᵢ
                    else
                        jacobian[row, col] = - Iinv * (C * sinAngle - D * cosAngle) * voltage.magnitude[i] * voltage.magnitude[j]                   # ∂Iⱼᵢ / ∂θⱼ
                        jacobian[row, col + bus.number] = Iinv * (B * voltage.magnitude[j] - (C * cosAngle + D * sinAngle) * voltage.magnitude[i])  # ∂Iⱼᵢ / ∂Vⱼ
                    end

                elseif se.type[row] == 12 # ψᵢⱼ
                    A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)
                    
                    IijRe = (A * cos(voltage.angle[i]) - B * sin(voltage.angle[i])) * voltage.magnitude[i] - (C * cos(voltage.angle[j] + Fij) - D * sin(voltage.angle[j] + Fij)) * voltage.magnitude[j]
                    IijIm = (A * sin(voltage.angle[i]) + B * cos(voltage.angle[i])) * voltage.magnitude[i] - (C * sin(voltage.angle[j] + Fij) + D * cos(voltage.angle[j] + Fij)) * voltage.magnitude[j]
                    Iij = complex(IijRe, IijIm)
                    Iinv = 1 / (abs(Iij))^2
                    
                    A, B, C, D = IijCoeff(gij, gsi, bij, bsi, tij)
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - angle(Iij)

                        jacobian[row, col] = Iinv * (A * voltage.magnitude[i]^2 - (C * cosAngle - D * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j])  # ∂ψᵢⱼ / ∂θᵢ
                        jacobian[row, col + bus.number] = -Iinv * (C * sinAngle + D * cosAngle) * voltage.magnitude[j]                                          # ∂ψᵢⱼ / ∂Vᵢ
                    else
                        jacobian[row, col] = Iinv * (B * voltage.magnitude[j]^2 - (C * cosAngle - D * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j])  # ∂ψᵢⱼ / ∂θⱼ
                        jacobian[row, col + bus.number] = Iinv * (C * sinAngle + D * cosAngle) * voltage.magnitude[i]                                           # ∂ψᵢⱼ / ∂Vⱼ
                    end    

                elseif se.type[row] == 13 # ψⱼᵢ
                    A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)

                    IijRe = (A * cos(voltage.angle[j]) - B * sin(voltage.angle[j])) * voltage.magnitude[j] - (C * cos(voltage.angle[i] - Fij) - D * sin(voltage.angle[i] - Fij)) * voltage.magnitude[i]
                    IijIm = (A * sin(voltage.angle[j]) + B * cos(voltage.angle[j])) * voltage.magnitude[j] - (C * sin(voltage.angle[i] - Fij) + D * cos(voltage.angle[i] - Fij)) * voltage.magnitude[i]
                    Iij = complex(IijRe, IijIm)
                    Iinv = 1 / (abs(Iij))^2
                
                    A, B, C, D = IjiCoeff(gij, gsi, bij, bsi, tij)
                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - angle(Iij)

                        jacobian[row, col] = Iinv * (A * voltage.magnitude[i]^2 - (C * cosAngle + D * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j])  # ∂ψⱼᵢ / ∂θᵢ
                        jacobian[row, col + bus.number] = -Iinv * (C * sinAngle - D * cosAngle) * voltage.magnitude[j]                                          # ∂ψⱼᵢ / ∂Vᵢ
                    else
                        jacobian[row, col] = Iinv * (B * voltage.magnitude[j]^2 - (C * cosAngle + D * sinAngle) * voltage.magnitude[i] * voltage.magnitude[j])  # ∂ψⱼᵢ / ∂θⱼ
                        jacobian[row, col + bus.number] = Iinv * (C * sinAngle - D * cosAngle) * voltage.magnitude[i]                                           # ∂ψⱼᵢ / ∂Vⱼ
                    end 

                elseif se.type[row] == 14 # ℜ(Vᵢ)
                    se.residual[row] = se.mean[row] - voltage.magnitude[index] * cos(voltage.angle[index])

                    jacobian[row, col] = -voltage.magnitude[index] * sin(voltage.angle[index])  # ∂ℜ(Vᵢ) / ∂θᵢ
                    jacobian[row, col + bus.number] = cos(voltage.angle[index])                 # ∂ℜ(Vᵢ) / ∂Vᵢ   

                elseif se.type[row] == 15 # ℑ(Vᵢ)  
                    se.residual[row] = se.mean[row] - voltage.magnitude[index] * sin(voltage.angle[index])  

                    jacobian[row, col] = voltage.magnitude[index] * cos(voltage.angle[index])  # ∂ℑ(Vᵢ) / ∂θᵢ
                    jacobian[row, col + bus.number] = sin(voltage.angle[index])                # ∂ℑ(Vᵢ) / ∂Vᵢ 

                elseif se.type[row] == 16 # ℜ(Iᵢⱼ)
                    A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (A * cos(voltage.angle[i]) - B * sin(voltage.angle[i])) * voltage.magnitude[i] + (C * cos(voltage.angle[j] + Fij) - D * sin(voltage.angle[j] + Fij)) * voltage.magnitude[j]

                        jacobian[row, col] = -(A * sin(voltage.angle[i]) + B * cos(voltage.angle[i])) * voltage.magnitude[i]             # ∂ℜ(Iᵢⱼ) / ∂θᵢ
                        jacobian[row, col + bus.number] = A * cos(voltage.angle[i]) - B * sin(voltage.angle[i])                          # ∂ℜ(Iᵢⱼ) / ∂Vᵢ
                    else
                        jacobian[row, col] = (C * sin(voltage.angle[j] + Fij) + D * cos(voltage.angle[j] + Fij)) * voltage.magnitude[j]  # ∂ℜ(Iᵢⱼ) / ∂θⱼ
                        jacobian[row, col + bus.number] = -C * cos(voltage.angle[j] + Fij) + D * sin(voltage.angle[j] + Fij)             # ∂ℜ(Iᵢⱼ) / ∂Vⱼ
                    end  
                    
                elseif se.type[row] == 18 # ℑ(Iᵢⱼ)
                    A, B, C, D = FijCoeff(gij, gsi, bij, bsi, tij)

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (A * sin(voltage.angle[i]) + B * cos(voltage.angle[i])) * voltage.magnitude[i] + (C * sin(voltage.angle[j] + Fij) + D * cos(voltage.angle[j] + Fij)) * voltage.magnitude[j]

                        jacobian[row, col] = (A * cos(voltage.angle[i]) - B * sin(voltage.angle[i])) * voltage.magnitude[i]           # ∂ℑ(Iᵢⱼ) / ∂θᵢ
                        jacobian[row, col + bus.number] = A * sin(voltage.angle[i]) + B * cos(voltage.angle[i])                       # ∂ℑ(Iᵢⱼ) / ∂Vᵢ
                    else
                        jacobian[row, col] = (-C * cos(voltage.angle[j] + Fij) + D * sin(voltage.angle[j] + Fij)) * voltage.magnitude[j]  # ∂ℑ(Iᵢⱼ) / ∂θⱼ
                        jacobian[row, col + bus.number] = - C * sin(voltage.angle[j] + Fij) - D * cos(voltage.angle[j] + Fij)             # ∂ℑ(Iᵢⱼ) / ∂Vⱼ
                    end 

                elseif se.type[row] == 17 # ℜ(Iⱼᵢ)
                    A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (A * cos(voltage.angle[j]) - B * sin(voltage.angle[j])) * voltage.magnitude[j] + (C * cos(voltage.angle[i] - Fij) - D * sin(voltage.angle[i] - Fij)) * voltage.magnitude[i]

                        jacobian[row, col] = (C * sin(voltage.angle[i] - Fij) + D * cos(voltage.angle[i] - Fij)) * voltage.magnitude[i] # ∂ℜ(Iⱼᵢ) / ∂θᵢ
                        jacobian[row, col + bus.number] = -C * cos(voltage.angle[i] - Fij) + D * sin(voltage.angle[i] - Fij)            # ∂ℜ(Iⱼᵢ) / ∂Vᵢ
                    else
                        jacobian[row, col] = -(A * sin(voltage.angle[j]) + B * cos(voltage.angle[j])) * voltage.magnitude[j]        # ∂ℜ(Iⱼᵢ) / ∂θⱼ
                        jacobian[row, col + bus.number] = A * cos(voltage.angle[j]) - B * sin(voltage.angle[j])                     # ∂ℜ(Iⱼᵢ) / ∂Vⱼ
                    end 
                
                elseif se.type[row] == 19 # ℑ(Iⱼᵢ)
                    A, B, C, D = FjiCoeff(gij, gsi, bij, bsi, tij)

                    if col == branch.layout.from[index]
                        se.residual[row] = se.mean[row] - (A * sin(voltage.angle[j]) + B * cos(voltage.angle[j])) * voltage.magnitude[j] + (C * sin(voltage.angle[i] - Fij) + D * cos(voltage.angle[i] - Fij)) * voltage.magnitude[i]

                        jacobian[row, col] = (-C * cos(voltage.angle[i] - Fij) + D * sin(voltage.angle[i] - Fij)) * voltage.magnitude[i]  # ∂ℑ(Iⱼᵢ) / ∂θᵢ
                        jacobian[row, col + bus.number] = - (C * sin(voltage.angle[i] - Fij) + D * cos(voltage.angle[i] - Fij))           # ∂ℑ(Iⱼᵢ) / ∂Vᵢ
                    else
                        jacobian[row, col] = (A * cos(voltage.angle[j]) - B * sin(voltage.angle[j])) * voltage.magnitude[j]               # ∂ℑ(Iⱼᵢ) / ∂θⱼ
                        jacobian[row, col + bus.number] = A * sin(voltage.angle[j]) + B * cos(voltage.angle[j])                           # ∂ℑ(Iⱼᵢ) / ∂Vⱼ
                    end     

                end
            end
        end
    end

    for row = se.range[1]:(se.range[2] - 1)
        if se.type[row] == 1
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
        end
    end

    for row = se.range[5]:(se.range[6] - 1)
        if se.type[row] == 10
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
        elseif se.type[row] == 11
            se.residual[row] = se.mean[row] - voltage.angle[se.index[row]]
        end
    end
end

function typeIndex(jac::SparseModel, type::Array{Int8,1}, index::Array{Int64,1}, status::Int8, bus::Int64, a::Int64)
    type[jac.idx] = status * a
    index[jac.idx] = bus

    return type, index
end

function typeIndex(jac::SparseModel, type::Array{Int8,1}, index::Array{Int64,1}, status::Int8, location::Bool, branch::Int64, a::Int64, b::Int64)
    index[jac.idx] = branch

    if location
        type[jac.idx] = status * a
    else
        type[jac.idx] = status * b
    end

    return type, index
end

function jacobianInitialize(jac::SparseModel, val::Int8, col::Int64)
    jac.row[jac.cnt] = jac.idx
    jac.col[jac.cnt] = col
    jac.val[jac.cnt] = val

    jac.cnt += 1
    jac.idx += 1

    return jac
end

function jacobianInitialize(jac::SparseModel, nodalMatrix::SparseMatrixCSC{ComplexF64,Int64}, bus::Int64, busNumber::Int64)
    for j in nodalMatrix.colptr[bus]:(nodalMatrix.colptr[bus + 1] - 1)
        jac.row[jac.cnt] = jac.idx
        jac.col[jac.cnt] = nodalMatrix.rowval[j]
        jac.row[jac.cnt + 1] = jac.idx
        jac.col[jac.cnt + 1] = nodalMatrix.rowval[j] + busNumber
        
        jac.cnt += 2 
    end
        
    jac.idx += 1

    return jac
end

function jacobianInitialize(jac::SparseModel, from::Int64, to::Int64, busNumber::Int64)
    jac.row[jac.cnt] = jac.idx
    jac.col[jac.cnt] = from
    jac.row[jac.cnt + 1] = jac.idx
    jac.col[jac.cnt + 1] = to
    jac.row[jac.cnt + 2] = jac.idx
    jac.col[jac.cnt + 2] = from + busNumber
    jac.row[jac.cnt + 3] = jac.idx
    jac.col[jac.cnt + 3] = to + busNumber

    jac.idx += 1
    jac.cnt += 4

    return jac
end

function jacobianInitialize(jac::SparseModel, bus::Int64, busNumber::Int64)
    jac.row[jac.cnt] = jac.idx
    jac.col[jac.cnt] = bus

    jac.row[jac.cnt + 1] = jac.idx
    jac.col[jac.cnt + 1] = bus + busNumber

    jac.idx += 1
    jac.cnt += 2
    
    return jac
end

function precisionDiagonal(prec::SparseModel, variance::Float64)
    prec.row[prec.cnt] = prec.idx
    prec.col[prec.cnt] = prec.idx
    prec.val[prec.cnt] = 1 / variance

    prec.cnt += 1
    prec.idx += 1

    return prec
end

function precisionBlock(prec::SparseModel, varianceRe::Float64, varianceIm::Float64, covariance::Float64)
    L1inv = 1 / sqrt(varianceRe)
    L2 = covariance * L1inv
    L3inv2 = 1 / (varianceIm - L2^2)

    prec.row[prec.cnt] = prec.idx
    prec.col[prec.cnt] = prec.idx + 1
    prec.val[prec.cnt] = (- L2 * L1inv) * L3inv2

    prec.row[prec.cnt + 1] = prec.idx + 1
    prec.col[prec.cnt + 1] = prec.idx
    prec.val[prec.cnt + 1] = prec.val[prec.cnt]

    prec.row[prec.cnt + 2] = prec.idx
    prec.col[prec.cnt + 2] = prec.idx
    prec.val[prec.cnt + 2] = (L1inv - L2 * prec.val[prec.cnt]) * L1inv

    prec.row[prec.cnt + 3] = prec.idx + 1
    prec.col[prec.cnt + 3] = prec.idx + 1
    prec.val[prec.cnt + 3] = L3inv2   

    prec.cnt += 4
    prec.idx += 2

    return prec 
end

function branchParameter(branch::Branch, ac::ACModel, index::Int64)
    i = branch.layout.from[index]  
    j = branch.layout.to[index]
    gij = real(ac.admittance[index])
    bij = imag(ac.admittance[index])
    gsi = 0.5 * branch.parameter.conductance[index]
    bsi = 0.5 * branch.parameter.susceptance[index]
    tij = 1 / branch.parameter.turnsRatio[index]
    Fij = branch.parameter.shiftAngle[index]

    return i, j, gij, bij, gsi, bsi, tij, Fij
end

function IijCoeff(gij::Float64, gsi::Float64, bij::Float64, bsi::Float64, tij::Float64)
    A = tij^4 * ((gij + gsi)^2 + (bij + bsi)^2) 
    B = tij^2 * (gij^2 + bij^2)
    C = tij^3 * (gij * (gij + gsi) + bij * (bij + bsi))
    D = tij^3 * (gij * bsi - bij * gsi)

    return A, B, C, D
end

function IjiCoeff(gij::Float64, gsi::Float64, bij::Float64, bsi::Float64, tij::Float64)
    A = tij^2 * (gij^2 + bij^2)
    B = (gij + gsi)^2 + (bij + bsi)^2
    C = tij * (gij * (gij + gsi) + bij * (bij + bsi))
    D = tij * (gij * bsi - gsi * bij)

    return A, B, C, D
end

function FijCoeff(gij::Float64, gsi::Float64, bij::Float64, bsi::Float64, tij::Float64)
    A = tij^2 * (gij + gsi)
    B = tij^2 * (bij + bsi)
    C = tij * gij 
    D = tij * bij

    return A, B, C, D
end

function FjiCoeff(gij::Float64, gsi::Float64, bij::Float64, bsi::Float64, tij::Float64)
    A = gij + gsi
    B = bij + bsi
    C = tij * gij 
    D = tij * bij

    return A, B, C, D
end

function fix!(residualx::Vector{JuMP.VariableRef}, residualy::Vector{JuMP.VariableRef}, index::Int64)
    fix(residualx[index], 0.0; force = true)
    fix(residualy[index], 0.0; force = true)   
end

