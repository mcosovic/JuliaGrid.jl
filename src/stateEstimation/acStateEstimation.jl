"""
    gaussNewton(system::PowerSystem, device::Measurement, [method = LU])

The function sets up the Gauss-Newton method to solve the nonlinear or AC state
estimation model, where the vector of state variables is given in polar coordinates. The
Gauss-Newton method throughout iterations provided WLS estimator.

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
The function returns an instance of the `ACStateEstimation` type, which includes the
following fields:
- `voltage`: The variable allocated to store the bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `method`: The system model vectors and matrices.

# Examples
Set up the AC state estimation model to be solved using the default LU factorization:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
```

Set up the AC state estimation model to be solved using the orthogonal method:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device, Orthogonal)
```
"""
function gaussNewton(
    system::PowerSystem,
    device::Measurement,
    factorization::Type{<:Union{QR, LDLt, LU}} = LU
)
    jcb, mean, pcs, rsd, type, index, range, power, current, _ = acWLS(system, device)

    ACStateEstimation(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        power,
        current,
        NonlinearWLS{Normal}(
            jcb,
            pcs,
            mean,
            rsd,
            fill(0.0, 2 * system.bus.number),
            factorized[factorization],
            0.0,
            type,
            index,
            range,
            -1
        )
    )
end

function gaussNewton(system::PowerSystem, device::Measurement, ::Type{<:Orthogonal})
    jcb, mean, pcs, rsd, type, index, range, power, current, crld = acWLS(system, device)

    if crld
        throw(ErrorException(
            "The non-diagonal precision matrix prevents using the orthogonal method.")
        )
    end

    ACStateEstimation(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        power,
        current,
        NonlinearWLS{Orthogonal}(
            jcb,
            pcs,
            mean,
            rsd,
            fill(0.0, 2 * system.bus.number),
            factorized[QR],
            0.0,
            type,
            index,
            range,
            -1
        )
    )
end

function acWLS(system::PowerSystem, device::Measurement)
    ac = system.model.ac
    bus = system.bus
    volt = device.voltmeter
    amp = device.ammeter
    watt = device.wattmeter
    var = device.varmeter
    pmu = device.pmu
    correlated = false

    checkSlackBus(system)
    model!(system, ac)
    changeSlackBus!(system)

    total = volt.number + amp.number + watt.number + var.number + 2 * pmu.number

    nnzJcb = volt.number + 4 * amp.number
    nnzPcs = copy(total)

    @inbounds for (i, idx) in enumerate(watt.layout.index)
        if watt.layout.bus[i]
            nnzJcb += 2 * (ac.nodalMatrix.colptr[idx + 1] - ac.nodalMatrix.colptr[idx])
        else
            nnzJcb += 4
        end
    end
    @inbounds for (i, idx) in enumerate(var.layout.index)
        if var.layout.bus[i]
            nnzJcb += 2 * (ac.nodalMatrix.colptr[idx + 1] - ac.nodalMatrix.colptr[idx])
        else
            nnzJcb += 4
        end
    end

    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            if pmu.layout.polar[i]
                nnzJcb += 2
            else
                nnzJcb += 4
            end
        else
            nnzJcb += 8
        end

        if !pmu.layout.polar[i] && pmu.layout.correlated[i]
            correlated = true
            nnzPcs += 2
        end
    end

    mean = fill(0.0, total)
    jcb = SparseModel(fill(0, nnzJcb), fill(0, nnzJcb), fill(0.0, nnzJcb), 1, 1)
    pcs = SparseModel(fill(0, nnzPcs) , fill(0, nnzPcs), fill(0.0, nnzPcs), 1, 1)

    type = fill(Int8(0), total)
    idx = fill(0, total)
    range = fill(1, 6)

    @inbounds for (i, k) in enumerate(volt.layout.index)
        status =  volt.magnitude.status[i]

        mean[i] = status * volt.magnitude.mean[i]
        precision!(pcs, volt.magnitude.variance[i])
        oneIndices!(jcb, type, idx, status, k + bus.number, k, 1)
    end
    range[2] = jcb.idx

    @inbounds for (i, k) in enumerate(amp.layout.index)
        status = amp.magnitude.status[i]

        mean[jcb.idx] = status * amp.magnitude.mean[i]
        precision!(pcs, amp.magnitude.variance[i])
        fourIndices!(jcb, type, idx, status, amp.layout.from[i], system, k, 2, 3)
    end
    range[3] = jcb.idx

    @inbounds for (i, k) in enumerate(watt.layout.index)
        status = watt.active.status[i]

        mean[jcb.idx] = status * watt.active.mean[i]
        precision!(pcs, watt.active.variance[i])

        if watt.layout.bus[i]
            nthIndices!(jcb, type, idx, status, system, k, 4)
        else
            fourIndices!(jcb, type, idx, status, watt.layout.from[i], system, k, 5, 6)
        end
    end
    range[4] = jcb.idx

    @inbounds for (i, k) in enumerate(var.layout.index)
        status = var.reactive.status[i]

        mean[jcb.idx] = status * var.reactive.mean[i]
        precision!(pcs, var.reactive.variance[i])

        if var.layout.bus[i]
            nthIndices!(jcb, type, idx, status, system, k, 7)
        else
            fourIndices!(jcb, type, idx, status, var.layout.from[i], system, k, 8, 9)
        end
    end
    range[5] = jcb.idx

    @inbounds for (i, k) in enumerate(pmu.layout.index)
        statusMag = pmu.magnitude.status[i]
        statusAng = pmu.angle.status[i]

        if pmu.layout.polar[i]
            mean[jcb.idx] = statusMag * pmu.magnitude.mean[i]
            mean[jcb.idx + 1] = statusAng * pmu.angle.mean[i]

            precision!(pcs, pmu.magnitude.variance[i])
            precision!(pcs, pmu.angle.variance[i])

            if pmu.layout.bus[i]
                oneIndices!(jcb, type, idx, statusMag, k + bus.number, k, 10)
                oneIndices!(jcb, type, idx, statusAng, k, k, 11)
            else
                fourIndices!(jcb, type, idx, statusMag, pmu.layout.from[i], system, k, 2, 3)
                fourIndices!(jcb, type, idx, statusAng, pmu.layout.from[i], system, k, 12, 13)
            end
        else
            sinθ, cosθ = sincos(pmu.angle.mean[i])
            status = pmu.magnitude.status[i] * pmu.angle.status[i]

            mean[jcb.idx] = status * pmu.magnitude.mean[i] * cosθ
            mean[jcb.idx + 1] = status * pmu.magnitude.mean[i] * sinθ

            varRe, varIm = variancePmu(pmu, cosθ, sinθ, i)
            if pmu.layout.correlated[i]
                precision!(pcs,pmu, cosθ, sinθ, varRe, varIm, i)
            else
                precision!(pcs, varRe)
                precision!(pcs, varIm)
            end

            if pmu.layout.bus[i]
                twoIndices!(jcb, type, idx, status, bus.number, k, 14)
                twoIndices!(jcb, type, idx, status, bus.number, k, 15)
            else
                fourIndices!(jcb, type, idx, status, pmu.layout.from[i], system, k, 16, 17)
                fourIndices!(jcb, type, idx, status, pmu.layout.from[i], system, k, 18, 19)
            end
        end
    end
    range[6] = pcs.idx

    jacobian = sparse(jcb.row, jcb.col, jcb.val, total, 2 * bus.number)
    precision = sparse(pcs.row, pcs.col, pcs.val, total, total)

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

    return jacobian, mean, precision, fill(0.0, total),
        type, idx, range, power, current, correlated
end

function normalEquation!(system::PowerSystem, analysis::ACStateEstimation)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    se = analysis.method
    voltage = analysis.voltage
    jcb = se.jacobian

    se.objective = 0.0
    @inbounds for col = 1:bus.number
        cok = col + bus.number

        for lin in jcb.colptr[col]:(jcb.colptr[col + 1] - 1)
            row = jcb.rowval[lin]
            idx = se.index[row]
            if se.type[row] == 0
                continue
            end

            if se.type[row] == 4 # Pi
                if col == se.index[row]
                    I = [0.0; 0.0]
                    for q in ac.nodalMatrix.colptr[col]:(ac.nodalMatrix.colptr[col + 1] - 1)
                        j = ac.nodalMatrix.rowval[q]

                        Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage, col, j, q)
                        PiQiSum(voltage, Gij, sinθij, Bij, cosθij, I, j, -, 1)
                        PiQiSum(voltage, Gij, cosθij, Bij, sinθij, I, j, +, 2)
                    end
                    se.residual[row] = se.mean[row] - Pi(voltage, I[2], col)
                    seobjective(analysis, row)

                    Gii, Bii = reim(ac.nodalMatrix[col, col])
                    jcb[row, col] = Piθi(voltage, Bii, -I[1], col)
                    jcb[row, cok] = PiVi(voltage, Gii, I[2], col)
                else
                    Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage, idx, col)

                    jcb[row, col] = Piθj(voltage, Gij, Bij, sinθij, cosθij, idx, col)
                    jcb[row, cok] = PiVj(voltage, Gij, Bij, sinθij, cosθij, idx)
                end

            elseif se.type[row] == 7 # Qi
                if col == se.index[row]
                    I = [0.0; 0.0]
                    for q in ac.nodalMatrix.colptr[col]:(ac.nodalMatrix.colptr[col + 1] - 1)
                        j = ac.nodalMatrix.rowval[q]

                        Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage, col, j, q)
                        PiQiSum(voltage, Gij, cosθij, Bij, sinθij, I, j, +, 1)
                        PiQiSum(voltage, Gij, sinθij, Bij, cosθij, I, j, -, 2)
                    end
                    se.residual[row] = se.mean[row] - Pi(voltage, I[2], col)
                    seobjective(analysis, row)

                    Gii, Bii = reim(ac.nodalMatrix[col, col])
                    jcb[row, col] = Qiθi(voltage, Gii, I[1], col)
                    jcb[row, cok] = QiVi(voltage, Bii, I[2], col)
                else
                    Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage, idx, col)

                    jcb[row, col] = Qiθj(voltage, Gij, Bij, sinθij, cosθij, idx, col)
                    jcb[row, cok] = QiVj(voltage, Gij, Bij, sinθij, cosθij, idx)
                end

            elseif se.type[row] == 14 # Re(Vi)
                se.residual[row] = se.mean[row] - ReVi(voltage, idx)
                seobjective(analysis, row)

                jcb[row, col] = ReViθi(voltage, idx)
                jcb[row, cok] = ReViVi(voltage, idx)

            elseif se.type[row] == 15 # Im(Vi)
                se.residual[row] = se.mean[row] - ImVi(voltage, idx)
                seobjective(analysis, row, row - 1)

                jcb[row, col] = ImViθi(voltage, idx)
                jcb[row, cok] = ImViVi(voltage, idx)
            else
                if se.type[row] == 5 # Pij
                    model = PijCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - Pij(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = Pijθi(model, state)
                        jcb[row, cok] = PijVi(model, state)
                    else
                        jcb[row, col] = Pijθj(model, state)
                        jcb[row, cok] = PijVj(model, state)
                    end

                elseif se.type[row] == 6 # Pji
                    model = PjiCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - Pji(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = Pjiθi(model, state)
                        jcb[row, cok] = PjiVi(model, state)
                    else
                        jcb[row, col] = Pjiθj(model, state)
                        jcb[row, cok] = PjiVj(model, state)
                    end

                elseif se.type[row] == 8 # Qij
                    model = QijCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - Qij(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = Qijθi(model, state)
                        jcb[row, cok] = QijVi(model, state)
                    else
                        jcb[row, col] = Qijθj(model, state)
                        jcb[row, cok] = QijVj(model, state)
                    end

                elseif se.type[row] == 9 # Qji
                    model = QjiCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - Qji(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = Qjiθi(model, state)
                        jcb[row, cok] = QjiVi(model, state)
                    else
                        jcb[row, col] = Qjiθj(model, state)
                        jcb[row, cok] = QjiVj(model, state)
                    end

                elseif se.type[row] == 2 # Iij
                    model = IijCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)
                    Iinv = Iijinv(model, state)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - (1 / Iinv)
                        seobjective(analysis, row)

                        jcb[row, col] = Iijθi(model, state, Iinv)
                        jcb[row, cok] = IijVi(model, state, Iinv)
                    else
                        jcb[row, col] = Iijθj(model, state, Iinv)
                        jcb[row, cok] = IijVj(model, state, Iinv)
                    end

                elseif se.type[row] == 3 # Iji
                    model = IjiCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)
                    Iinv = Ijiinv(model, state)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - (1 / Iinv)
                        seobjective(analysis, row)

                        jcb[row, col] = Ijiθi(model, state, Iinv)
                        jcb[row, cok] = IjiVi(model, state, Iinv)
                    else
                        jcb[row, col] = Ijiθj(model, state, Iinv)
                        jcb[row, cok] = IjiVj(model, state, Iinv)
                    end

                elseif se.type[row] == 12 # ψij
                    model = ψijCoefficient(branch, ac, idx)
                    state = ViVjθiθjState(system, voltage, idx)
                    Iinv2, Iij = ψij(model, state)

                    model = IijCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - angle(Iij)
                        seobjective(analysis, row)

                        jcb[row, col] = ψijθi(model, state, Iinv2)
                        jcb[row, cok] = ψijVi(model, state, Iinv2)
                    else
                        jcb[row, col] = ψijθj(model, state, Iinv2)
                        jcb[row, cok] = ψijVj(model, state, Iinv2)
                    end

                elseif se.type[row] == 13 # ψji
                    model = ψjiCoefficient(branch, ac, idx)
                    state = VjViθjθiState(system, voltage, idx)
                    Iinv2, Iji = ψji(model, state)

                    model = IjiCoefficient(branch, ac, idx)
                    state = ViVjθijState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - angle(Iji)
                        seobjective(analysis, row)

                        jcb[row, col] = ψjiθi(model, state, Iinv2)
                        jcb[row, cok] = ψjiVi(model, state, Iinv2)
                    else
                        jcb[row, col] = ψjiθj(model, state, Iinv2)
                        jcb[row, cok] = ψjiVj(model, state, Iinv2)
                    end

                elseif se.type[row] == 16 # Re(Iij)
                    model = ψijCoefficient(branch, ac, idx)
                    state = ViVjθiθjState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - ReIij(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = ReIijθi(model, state)
                        jcb[row, cok] = ReIijVi(model, state)
                    else
                        jcb[row, col] = ReIijθj(model, state)
                        jcb[row, cok] = ReIijVj(model, state)
                    end

                elseif se.type[row] == 18 # Im(Iij)
                    model = ψijCoefficient(branch, ac, idx)
                    state = ViVjθiθjState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - ImIij(model, state)
                        seobjective(analysis, row, row - 1)

                        jcb[row, col] = ImIijθi(model, state)
                        jcb[row, cok] = ImIijVi(model, state)
                    else
                        jcb[row, col] = ImIijθj(model, state)
                        jcb[row, cok] = ImIijVj(model, state)
                    end

                elseif se.type[row] == 17 # Re(Iji)
                    model = ψjiCoefficient(branch, ac, idx)
                    state = VjViθjθiState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - ReIji(model, state)
                        seobjective(analysis, row)

                        jcb[row, col] = ReIjiθi(model, state)
                        jcb[row, cok] = ReIjiVi(model, state)
                    else
                        jcb[row, col] = ReIjiθj(model, state)
                        jcb[row, cok] = ReIjiVj(model, state)
                    end

                elseif se.type[row] == 19 # Im(Iji)
                    model = ψjiCoefficient(branch, ac, idx)
                    state = VjViθjθiState(system, voltage, idx)

                    if col == branch.layout.from[idx]
                        se.residual[row] = se.mean[row] - ImIji(model, state)
                        seobjective(analysis, row, row - 1)

                        jcb[row, col] = ImIjiθi(model, state)
                        jcb[row, cok] = ImIjiVi(model, state)
                    else
                        jcb[row, col] = ImIjiθj(model, state)
                        jcb[row, cok] = ImIjiVj(model, state)
                    end

                end
            end
        end
    end

    @inbounds for row = se.range[1]:(se.range[2] - 1)
        if se.type[row] == 1 # Vi
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
            seobjective(analysis, row)
        end
    end

    @inbounds for row = se.range[5]:(se.range[6] - 1)
        if se.type[row] == 10 # Vi
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
            seobjective(analysis, row)
        elseif se.type[row] == 11 # Ti
            se.residual[row] = se.mean[row] - voltage.angle[se.index[row]]
            seobjective(analysis, row)
        end
    end
end

"""
    acLavStateEstimation(system::PowerSystem, device::Measurement, optimizer;
        bridge, name)

The function sets up the LAV method to solve the nonlinear or AC state estimation
model, where the vector of state variables is given in polar coordinates.

# Arguments
This function requires the `PowerSystem` and `Measurement` composite types to establish
the LAV state estimation model. The LAV method offers increased robustness compared
to WLS, ensuring unbiasedness even in the presence of various measurement errors and
outliers.

Users can employ the LAV method to find an estimator by choosing one of the available
[optimization solvers](https://jump.dev/JuMP.jl/stable/packages/solvers/). Typically,
`Ipopt.Optimizer` suffices for most scenarios.

# Keywords
The function accepts the following keywords:
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `false`).

# Updates
If the AC model has not been created, the function will automatically trigger an update of
the `ac` field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the `ACStateEstimation` type, which includes the
following fields:
- `voltage`: The variable allocated to store the bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `method`: The optimization model.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = acLavStateEstimation(system, device, Ipopt.Optimizer)
```
"""
function acLavStateEstimation(
    system::PowerSystem,
    device::Measurement,
    @nospecialize optimizerFactory;
    bridge::Bool = false,
    name::Bool = false,
)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    volt = device.voltmeter
    amp = device.ammeter
    watt = device.wattmeter
    var = device.varmeter
    pmu = device.pmu

    checkSlackBus(system)
    model!(system, ac)
    changeSlackBus!(system)

    total = volt.number + amp.number + watt.number + var.number + 2 * pmu.number

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    method = LAV(
        jump,
        StateAC(
            Vector{AffExpr}(undef, bus.number),
            Dict{Int64, NonlinearExpr}(),
            Dict{Int64, NonlinearExpr}(),
            Dict{Int64, NonlinearExpr}(),
            Dict{Int64, NonlinearExpr}(),
            Dict{Tuple{Int64, Int64}, Int64}()
        ),
        @variable(jump, 0 <= statex[i = 1:(2 * bus.number)]),
        @variable(jump, 0 <= statey[i = 1:(2 * bus.number)]),
        @variable(jump, 0 <= residualx[i = 1:total]),
        @variable(jump, 0 <= residualy[i = 1:total]),
        Dict{Int64, ConstraintRef}(),
        total
    )
    objective = @expression(method.jump, AffExpr())

    @inbounds for i = 1:bus.number
        idx = i + bus.number
        method.state.V[i] = @expression(method.jump, method.statex[idx] - method.statey[idx])
    end
    @inbounds for i = 1:branch.number
        method.state.incidence[(fromto(system, i))] = i
    end

    fix(method.statex[bus.layout.slack], bus.voltage.angle[bus.layout.slack]; force = true)
    fix(method.statey[bus.layout.slack], 0.0; force = true)

    @inbounds for (k, idx) in enumerate(volt.layout.index)
        if volt.magnitude.status[k] == 1
            addConstrLav!(method, method.state.V[idx], volt.magnitude.mean[k], k)
            addObjectLav!(method, objective, k)
        else
            fix!(method.residualx, method.residualy, k)
        end
    end

    cnt = volt.number + 1
    @inbounds for (k, idx) in enumerate(amp.layout.index)
        if amp.magnitude.status[k] == 1
            if amp.layout.from[k]
                expr = Iij(system, method, idx)
            else
                expr = Iji(system, method, idx)
            end

            addConstrLav!(method, expr, amp.magnitude.mean[k], cnt)
            addObjectLav!(method, objective, cnt)
        else
            fix!(method.residualx, method.residualy, cnt)
        end
        cnt += 1
    end

    @inbounds for (k, idx) in enumerate(watt.layout.index)
        if watt.active.status[k] == 1
            if watt.layout.bus[k]
                expr = Pi(system, method, idx)
            else
                if watt.layout.from[k]
                    expr = Pij(system, method, idx)
                else
                    expr = Pji(system, method, idx)
                end
            end
            addConstrLav!(method, expr, watt.active.mean[k], cnt)
            addObjectLav!(method, objective, cnt)
        else
            fix!(method.residualx, method.residualy, cnt)
        end
        cnt += 1
    end

    @inbounds for (k, idx) in enumerate(var.layout.index)
        if var.reactive.status[k] == 1
            if var.layout.bus[k]
                expr = Qi(system, method, idx)
            else
                if var.layout.from[k]
                    expr = Qij(system, method, idx)
                else
                    expr = Qji(system, method, idx)
                end
            end
            addConstrLav!(method, expr, var.reactive.mean[k], cnt)
            addObjectLav!(method, objective, cnt)
        else
            fix!(method.residualx, method.residualy, cnt)
        end
        cnt += 1
    end

    @inbounds for (k, idx) in enumerate(pmu.layout.index)
        if pmu.layout.polar[k]
            if pmu.layout.bus[k]
                if pmu.magnitude.status[k] == 1
                    addConstrLav!(method, method.state.V[idx], pmu.magnitude.mean[k], cnt)
                    addObjectLav!(method, objective, cnt)
                else
                    fix!(method.residualx, method.residualy, cnt)
                end

                if pmu.angle.status[k] == 1
                    expr = @expression(method.jump, method.statex[idx] - method.statey[idx])
                    addConstrLav!(method, expr, pmu.angle.mean[k], cnt + 1)
                    addObjectLav!(method, objective, cnt + 1)
                else
                    fix!(method.residualx, method.residualy, cnt + 1)
                end
            else
                if pmu.magnitude.status[k] == 1
                    if pmu.layout.from[k]
                        expr = Iij(system, method, idx)
                    else
                        expr = Iji(system, method, idx)
                    end
                    addConstrLav!(method, expr, pmu.magnitude.mean[k], cnt)
                    addObjectLav!(method, objective, cnt)
                else
                    fix!(method.residualx, method.residualy, cnt)
                end

                if pmu.angle.status[k] == 1
                    if pmu.layout.from[k]
                        expr = ψij(system, method, idx)
                    else
                        expr = ψji(system, method, idx)
                    end
                    addConstrLav!(method, expr, pmu.angle.mean[k], cnt + 1)
                    addObjectLav!(method, objective, cnt + 1)
                else
                    fix!(method.residualx, method.residualy, cnt + 1)
                end
            end
        else
            if pmu.magnitude.status[k] == 1 && pmu.angle.status[k] == 1
                if pmu.layout.bus[k]
                    ReExpr, ImExpr = ReImVi(method, idx)
                else
                    if pmu.layout.from[k]
                        ReExpr, ImExpr = ReImIij(system, method, idx)
                    else
                        ReExpr, ImExpr = ReImIji(system, method, idx)
                    end
                end
                ReMean = pmu.magnitude.mean[k] * cos(pmu.angle.mean[k])
                ImMean = pmu.magnitude.mean[k] * sin(pmu.angle.mean[k])

                addConstrLav!(method, ReExpr, ReMean, cnt)
                addObjectLav!(method, objective, cnt)

                addConstrLav!(method, ImExpr, ImMean, cnt + 1)
                addObjectLav!(method, objective, cnt + 1)
            else
                fix!(method.residualx, method.residualy, cnt)
                fix!(method.residualx, method.residualy, cnt + 1)
            end
        end
        cnt += 2
    end

    @objective(method.jump, Min, objective)

    ACStateEstimation(
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
    solve!(system::PowerSystem, analysis::ACStateEstimation; verbose)

By computing the bus voltage magnitudes and angles, the function solves the AC state
estimation model.

# Keyword
Users can set:
* `verbose`: Controls the LAV solver output display:
  * `verbose = 0`: silent mode,
  * `verbose = 1`: prints only the exit message about convergence,
  * `verbose = 2`: prints detailed native solver output (default).

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
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
```

Solving the AC state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = acLavStateEstimation(system, device, Ipopt.Optimizer; verbose = 1)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::ACStateEstimation{NonlinearWLS{Normal}})
    normalEquation!(system, analysis)

    bus = system.bus
    se = analysis.method
    jcb = se.jacobian
    volt = analysis.voltage

    slackRange = jcb.colptr[bus.layout.slack]:(jcb.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = jcb.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = 0.0
    end
    gain = (transpose(jcb) * se.precision * jcb)
    gain[bus.layout.slack, bus.layout.slack] = 1.0

    if se.pattern == -1
        se.pattern = 0
        se.factorization = factorization(gain, se.factorization)
    else
        se.factorization = factorization!(gain, se.factorization)
    end

    se.increment = solution(
        se.increment, transpose(jcb) * se.precision * se.residual, se.factorization
    )

    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = elementsRemove[k]
    end

    se.increment[bus.layout.slack] = 0.0
    maxAbsΔ = 0.0
    @inbounds for i = 1:bus.number
        volt.angle[i] = volt.angle[i] + se.increment[i]
        volt.magnitude[i] = volt.magnitude[i] + se.increment[i + bus.number]

        maxAbsΔ = max(maxAbsΔ, abs(se.increment[i]), abs(se.increment[i + bus.number]))
    end

    return maxAbsΔ
end

function solve!(system::PowerSystem, analysis::ACStateEstimation{NonlinearWLS{Orthogonal}})
    normalEquation!(system, analysis)

    bus = system.bus
    se = analysis.method
    jcb = se.jacobian
    volt = analysis.voltage

    @inbounds for i = 1:lastindex(se.mean)
        se.precision.nzval[i] = sqrt(se.precision.nzval[i])
    end

    slackRange = jcb.colptr[bus.layout.slack]:(jcb.colptr[bus.layout.slack + 1] - 1)
    elementsRemove = jcb.nzval[slackRange]
    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = 0.0
    end

    jcbScale = se.precision * jcb
    if se.pattern == -1
        se.pattern = 0
        se.factorization = factorization(jcbScale, se.factorization)
    else
        se.factorization = factorization!(jcbScale, se.factorization)
    end

    se.increment = solution(se.increment, se.precision * se.residual, se.factorization)

    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = elementsRemove[k]
    end

    se.increment[bus.layout.slack] = 0.0
    maxAbsΔ = 0.0
    @inbounds for i = 1:bus.number
        volt.angle[i] = volt.angle[i] + se.increment[i]
        volt.magnitude[i] = volt.magnitude[i] + se.increment[i + bus.number]

        maxAbsΔ = max(maxAbsΔ, abs(se.increment[i]), abs(se.increment[i + bus.number]))
    end

    @inbounds for i = 1:lastindex(se.mean)
        se.precision.nzval[i] ^= 2
    end

    return maxAbsΔ
end

function solve!(system::PowerSystem, analysis::ACStateEstimation{LAV}; verbose::Int64 = 2)
    bus = system.bus
    se = analysis.method
    volt = analysis.voltage

    silentOptimal(se.jump, verbose)

    @inbounds for i = 1:bus.number
        set_start_value(se.statex[i]::VariableRef, bus.voltage.angle[i])
        set_start_value(se.statex[i + bus.number]::VariableRef, bus.voltage.magnitude[i])
    end

    optimize!(se.jump)

    @inbounds for i = 1:bus.number
        volt.angle[i] = value(se.statex[i]::VariableRef) - value(se.statey[i]::VariableRef)
        volt.magnitude[i] = value(se.state.V[i])
    end

    printOptimal(se.jump, verbose)
end

"""
    setInitialPoint!(source::Union{PowerSystem, Analysis}, target::ACStateEstimation)

The function can reset the initial point of the AC state estimation to values from the
`PowerSystem` type. It can also initialize the AC state estimation based on results from
the `Analysis` type, whether from an AC or DC analysis.

The function assigns the bus voltage magnitudes and angles in the `target` argument,
using data from the `source` argument. This allows users to initialize AC state estimation
as needed.

If `source` comes from a DC analysis, only the bus voltage angles are assigned in the
`target` argument, while the bus voltage magnitudes remain unchanged.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end

residualTest!(system, device, analysis; threshold = 1.0)

setInitialPoint!(system, analysis)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
```
"""
function setInitialPoint!(system::PowerSystem, analysis::ACStateEstimation)
    errorTransfer(system.bus.voltage.magnitude, analysis.voltage.magnitude)
    errorTransfer(system.bus.voltage.angle, analysis.voltage.angle)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
end

function setInitialPoint!(source::AC, target::ACStateEstimation)
    errorTransfer(source.voltage.magnitude, target.voltage.magnitude)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.magnitude)
        target.voltage.magnitude[i] = source.voltage.magnitude[i]
        target.voltage.angle[i] = source.voltage.angle[i]
    end
end

function setInitialPoint!(source::DC, target::ACStateEstimation)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.angle)
        target.voltage.angle[i] = source.voltage.angle[i]
    end
end

function oneIndices!(
    jcb::SparseModel,
    type::Vector{Int8},
    idx::Vector{Int64},
    status::Int8,
    col::Int64,
    idxBus::Int64,
    code::Int64
)
    type[jcb.idx] = status * code
    idx[jcb.idx] = idxBus

    jcb.row[jcb.cnt] = jcb.idx
    jcb.col[jcb.cnt] = col
    jcb.val[jcb.cnt] = status

    jcb.cnt += 1
    jcb.idx += 1

    return jcb, type, idx
end

function twoIndices!(
    jcb::SparseModel,
    type::Vector{Int8},
    idx::Vector{Int64},
    status::Int8,
    busNumber::Int64,
    idxBus::Int64,
    code::Int64
)
    type[jcb.idx] = status * code
    idx[jcb.idx] = idxBus

    jcb.row[jcb.cnt] = jcb.idx
    jcb.col[jcb.cnt] = idxBus

    jcb.row[jcb.cnt + 1] = jcb.idx
    jcb.col[jcb.cnt + 1] = idxBus + busNumber

    jcb.idx += 1
    jcb.cnt += 2

    return jcb, type, idx
end

function fourIndices!(
    jcb::SparseModel,
    type::Vector{Int8},
    idx::Vector{Int64},
    status::Int8,
    location::Bool,
    system::PowerSystem,
    idxBranch::Int64,
    code1::Int64,
    code2::Int64
)
    idx[jcb.idx] = idxBranch

    if location
        type[jcb.idx] = status * code1
    else
        type[jcb.idx] = status * code2
    end

    jcb.row[jcb.cnt] = jcb.idx
    jcb.col[jcb.cnt] = system.branch.layout.from[idxBranch]

    jcb.row[jcb.cnt + 1] = jcb.idx
    jcb.col[jcb.cnt + 1] = system.branch.layout.to[idxBranch]

    jcb.row[jcb.cnt + 2] = jcb.idx
    jcb.col[jcb.cnt + 2] = system.branch.layout.from[idxBranch] + system.bus.number

    jcb.row[jcb.cnt + 3] = jcb.idx
    jcb.col[jcb.cnt + 3] = system.branch.layout.to[idxBranch] + system.bus.number

    jcb.idx += 1
    jcb.cnt += 4

    return jcb, type, idx
end

function nthIndices!(
    jcb::SparseModel,
    type::Vector{Int8},
    idx::Vector{Int64},
    status::Int8,
    system::PowerSystem,
    idxBus::Int64,
    code::Int64
)
    type[jcb.idx] = status * code
    idx[jcb.idx] = idxBus

    nodal = system.model.ac.nodalMatrix
    @inbounds for j in nodal.colptr[idxBus]:(nodal.colptr[idxBus + 1] - 1)
        jcb.row[jcb.cnt] = jcb.idx
        jcb.col[jcb.cnt] = nodal.rowval[j]
        jcb.row[jcb.cnt + 1] = jcb.idx
        jcb.col[jcb.cnt + 1] = nodal.rowval[j] + system.bus.number

        jcb.cnt += 2
    end

    jcb.idx += 1

    return jcb, type, idx
end

"""
    acStateEstimation!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation;
        maxIteration, stopping, power, current, verbose)

The function serves as a wrapper for solving AC state estimation using Gauss-Newton method.
It calculates bus voltage magnitudes and angles, with the option to compute powers and currents.

# Keywords
Users can use the following keywords:
* `maxIteration`: Specifies the maximum number of iterations (default: `20`).
* `stopping`: Defines the stopping criterion for the iterative algorithm (default: `1e-8`).
* `power`: Enables power computation upon convergence or reaching the iteration limit (default: `false`).
* `current`: Enables current computation upon convergence or reaching the iteration limit (default: `false`).
* `verbose`: Controls the solver output display:
  * `verbose = 0`: silent mode,
  * `verbose = 1`: prints only the exit message about convergence,
  * `verbose = 2`: prints only iteration data,
  * `verbose = 3`: prints detailed data (default).

# Updates
The calculated voltages are stored in the `voltage` field of the `ACStateEstimation` type,
with optional storage in the `power` and `current` fields.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
acStateEstimation!(system, device, analysis; stopping = 1e-10, current = true)
```
"""
function acStateEstimation!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{NonlinearWLS{T}};
    maxIteration::Int64 = 20,
    stopping::Float64 = 1e-8,
    power::Bool = false,
    current::Bool = false,
    verbose::Int64 = 3
)  where T <: Union{Normal, Orthogonal}

    converged = false

    printseSystem(system, device, verbose)
    printseMethod(analysis, verbose)

    iter = 0
    for iteration = 1:maxIteration
        increment = solve!(system, analysis)

        printseIteration(analysis, iteration, increment, verbose)
        if increment < stopping
            iter = iteration
            converged = true
            break
        end
    end

    printseIncrement(system, analysis, verbose)
    printseConvergence(iter, converged, verbose)

    if power
        power!(system, analysis)
    end
    if current
        current!(system, analysis)
    end
end

function printseSystem(system::PowerSystem, device::Measurement, verbose::Int64)
    if verbose == 3
        wdcol1 = max(
            textwidth(string(device.wattmeter.number)),
            textwidth(string(device.ammeter.number)),
        )
        wdcol2 = max(
            textwidth(string(device.varmeter.number)),
            textwidth(string(device.voltmeter.number)),
        )
        wdcol3 = textwidth(string(device.pmu.number))

        print("Number of wattmeters: ")
        print(format(Format("%i"), device.wattmeter.number))

        print("   Number of varmeters:  ")
        print(format(Format("%i"), device.varmeter.number))

        print("   Number of PMUs: ")
        print(format(Format("%i\n"), device.pmu.number))

        print("  Bus:                ")
        print(format(Format("%*i"), wdcol1, count(device.wattmeter.layout.bus)))

        print("     Bus:                ")
        print(format(Format("%*i"), wdcol2, count(device.varmeter.layout.bus)))

        print("     Bus:          ")
        print(format(Format("%*i\n"), wdcol3, count(device.pmu.layout.bus)))

        print("  From-bus:           ")
        print(format(Format("%*i"), wdcol1, count(device.wattmeter.layout.from)))

        print("     From-bus:           ")
        print(format(Format("%*i"), wdcol2, count(device.varmeter.layout.from)))

        print("     From-bus:     ")
        print(format(Format("%*i\n"), wdcol3, count(device.pmu.layout.from)))

        print("  To-bus:             ")
        print(format(Format("%*i"), wdcol1, count(device.wattmeter.layout.to)))

        print("     To-bus:             ")
        print(format(Format("%*i"), wdcol2, count(device.varmeter.layout.to)))

        print("     To-bus:       ")
        print(format(Format("%*i\n\n"), wdcol3, count(device.pmu.layout.to)))

        print("Number of ammeters:   ")
        print(format(Format("%i"), device.ammeter.number))

        print("   Number of voltmeters: ")
        print(format(Format("%i\n"), device.voltmeter.number))

        print("  From-bus:           ")
        print(format(Format("%*i\n"), wdcol1, count(device.ammeter.layout.from)))

        print("  To-bus:             ")
        print(format(Format("%*i\n\n"), wdcol1, count(device.ammeter.layout.to)))
    end
end

function printseMethod(analysis::ACStateEstimation, verbose::Int64)
    if verbose == 2 || verbose == 3
        wd = textwidth(string(nnz(analysis.method.jacobian))) + 1
        mwd = textwidth("Number of nonzeros in the Jacobian:")
        tot = wd + mwd

        print("Number of nonzeros in the Jacobian:")
        print(format(Format("%*i\n"), wd, nnz(analysis.method.jacobian)))

        print("Number of measurement functions:")
        print(format(Format("%*i\n"), tot - 32, lastindex(analysis.method.mean)))

        print("Number of state variables:")
        print(format(Format("%*i\n"), tot - 26, lastindex(analysis.method.increment) - 1))

        print("Number of buses:")
        print(format(Format("%*i\n"), tot - 16, system.bus.number))

        print("Number of branches:")
        print(format(Format("%*i\n\n"), tot - 19, system.branch.number))
    end
end

function printseIteration(analysis::ACStateEstimation, iter::Int64, stopping::Float64, verbose::Int64)
    if verbose == 2 || verbose == 3
        if iter % 10 == 1
            println("Iteration   Maximum Increment   Objective Value")
        end
        print(format(Format("%*i "), 9, iter))
        print(format(Format("%*.4e"), 19, stopping))

        print(format(Format("%*.8e\n"), 18, analysis.method.objective))
    end
end

function printseIncrement(
    system::PowerSystem,
    analysis,
    verbose::Int64
)
    if verbose == 2 || verbose == 3
        slack = copy(analysis.method.increment[system.bus.layout.slack])

        analysis.method.increment[system.bus.layout.slack] = -Inf
        angmax = maximum(analysis.method.increment[1:system.bus.number])

        analysis.method.increment[system.bus.layout.slack] = Inf
        angmin = minimum(analysis.method.increment[1:system.bus.number])

        analysis.method.increment[system.bus.layout.slack] = slack

        mag = extrema(analysis.method.increment[(system.bus.number + 1):end])

        print("\n" * " "^21 * "Minimum Value   Maximum Value")

        print("\nMagnitude Increment:")
        print(format(Format("%*.4e"), 14, mag[1]))
        print(format(Format("%*.4e\n"), 16, mag[2]))

        print("Angle Increment:")
        print(format(Format("%*.4e"), 18, angmin))
        print(format(Format("%*.4e\n\n"), 16, angmax))
    end
end

function printseConvergence(
    iter::Int64,
    converged::Bool,
    verbose::Int64,
)
    if verbose != 0
        if converged
            println(
                "EXIT: The solution was found using the Gauss-Newton" *
                " method in $iter iterations."
            )
        else
            println("EXIT: The Gauss-Newton method failed to converge.")
        end
    end
end

