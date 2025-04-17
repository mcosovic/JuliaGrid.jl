"""
    gaussNewton(monitoring::Measurement, [method = LU])

The function sets up the Gauss-Newton method to solve the nonlinear or AC state estimation model,
where the vector of state variables is given in polar coordinates. The Gauss-Newton method throughout
iterations provided WLS estimator.

# Arguments
This function requires the `Measurement` type to establish the WLS state estimation framework.

Moreover, the presence of the `method` parameter is not mandatory. To address the WLS state
estimation method, users can opt to utilize factorization techniques to decompose the gain matrix,
such as `LU`, `QR`, or `LDLt` especially when the gain matrix is symmetric. Opting for the
`Orthogonal` method is advisable for a more robust solution in scenarios involving ill-conditioned
data, particularly when substantial variations in variances are present.

If the user does not provide the `method`, the default method for solving the estimation model will
be `LU` factorization.

# Updates
If the AC model has not been created, the function will automatically trigger an update of the `ac`
field within the `PowerSystem` type.

# Returns
The function returns an instance of the [`AcStateEstimation`](@ref AcStateEstimation) type.

# Examples
Set up the AC state estimation model to be solved using the default LU factorization:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
```

Set up the AC state estimation model to be solved using the orthogonal method:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring, Orthogonal)
```
"""
function gaussNewton(monitoring::Measurement, factorization::Type{<:Union{QR, LDLt, LU}} = LU)
    system = monitoring.system
    jcb, mean, pcs, rsd, type, index, range, power, current, _ = acWLS(system, monitoring)

    AcStateEstimation(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        power,
        current,
        GaussNewton{Normal}(
            jcb,
            pcs,
            mean,
            rsd,
            fill(0.0, 2 * system.bus.number),
            factorized[factorization],
            type,
            index,
            range,
            Dict(:pattern => -1),
            0.0,
            0
        ),
        system,
        monitoring,
    )
end

function gaussNewton(monitoring::Measurement, ::Type{<:Orthogonal})
    system = monitoring.system
    jcb, mean, pcs, rsd, type, index, range, power, current, crld = acWLS(system, monitoring)

    if crld
        throw(ErrorException(
            "The non-diagonal precision matrix prevents using the orthogonal method.")
        )
    end

    AcStateEstimation(
        Polar(
            copy(system.bus.voltage.magnitude),
            copy(system.bus.voltage.angle)
        ),
        power,
        current,
        GaussNewton{Orthogonal}(
            jcb,
            pcs,
            mean,
            rsd,
            fill(0.0, 2 * system.bus.number),
            factorized[QR],
            type,
            index,
            range,
            Dict(:pattern => -1),
            0.0,
            0
        ),
        system,
        monitoring,
    )
end

function acWLS(system::PowerSystem, monitoring::Measurement)
    ac = system.model.ac
    bus = system.bus
    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter
    pmu = monitoring.pmu
    correlated = false

    checkSlackBus(system)
    model!(system, ac)

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

        sq = if2exp(amp.layout.square[i])
        mean[jcb.idx] = status * (amp.magnitude.mean[i]^sq)
        precision!(pcs, sq * amp.magnitude.variance[i])

        if amp.layout.square[i]
            fourIndices!(jcb, type, idx, status, amp.layout.from[i], system, k, 4, 5)
        else
            fourIndices!(jcb, type, idx, status, amp.layout.from[i], system, k, 2, 3)
        end
    end
    range[3] = jcb.idx

    @inbounds for (i, k) in enumerate(watt.layout.index)
        status = watt.active.status[i]

        mean[jcb.idx] = status * watt.active.mean[i]
        precision!(pcs, watt.active.variance[i])

        if watt.layout.bus[i]
            nthIndices!(jcb, type, idx, status, system, k, 6)
        else
            fourIndices!(jcb, type, idx, status, watt.layout.from[i], system, k, 7, 8)
        end
    end
    range[4] = jcb.idx

    @inbounds for (i, k) in enumerate(var.layout.index)
        status = var.reactive.status[i]

        mean[jcb.idx] = status * var.reactive.mean[i]
        precision!(pcs, var.reactive.variance[i])

        if var.layout.bus[i]
            nthIndices!(jcb, type, idx, status, system, k, 9)
        else
            fourIndices!(jcb, type, idx, status, var.layout.from[i], system, k, 10, 11)
        end
    end
    range[5] = jcb.idx

    @inbounds for (i, k) in enumerate(pmu.layout.index)
        statusMag = pmu.magnitude.status[i]
        statusAng = pmu.angle.status[i]

        if pmu.layout.polar[i]
            sq = if2exp(pmu.layout.square[i])
            mean[jcb.idx] = statusMag * (pmu.magnitude.mean[i]^sq)
            precision!(pcs, sq * pmu.magnitude.variance[i])

            mean[jcb.idx + 1] = statusAng * pmu.angle.mean[i]
            precision!(pcs, pmu.angle.variance[i])

            if pmu.layout.bus[i]
                oneIndices!(jcb, type, idx, statusMag, k + bus.number, k, 12)
                oneIndices!(jcb, type, idx, statusAng, k, k, 13)
            else
                if pmu.layout.square[i]
                    fourIndices!(jcb, type, idx, statusMag, pmu.layout.from[i], system, k, 4, 5)
                else
                    fourIndices!(jcb, type, idx, statusMag, pmu.layout.from[i], system, k, 2, 3)
                end
                fourIndices!(jcb, type, idx, statusAng, pmu.layout.from[i], system, k, 14, 15)
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
                twoIndices!(jcb, type, idx, status, bus.number, k, 16)
                twoIndices!(jcb, type, idx, status, bus.number, k, 17)
            else
                fourIndices!(jcb, type, idx, status, pmu.layout.from[i], system, k, 18, 19)
                fourIndices!(jcb, type, idx, status, pmu.layout.from[i], system, k, 20, 21)
            end
        end
    end
    range[6] = pcs.idx

    jacobian = sparse(jcb.row, jcb.col, jcb.val, total, 2 * bus.number)
    precision = sparse(pcs.row, pcs.col, pcs.val, total, total)

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

    return jacobian, mean, precision, fill(0.0, total), type, idx, range, power, current, correlated
end

function normalEquation!(system::PowerSystem, analysis::AcStateEstimation)
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    se = analysis.method
    voltage = analysis.voltage
    jcb = se.jacobian

    se.objective = 0.0
    I = [0.0; 0.0]
    @inbounds for col = 1:bus.number
        cok = col + bus.number

        for lin in jcb.colptr[col]:(jcb.colptr[col + 1] - 1)
            row = jcb.rowval[lin]
            idx = se.index[row]
            if se.type[row] == 0
                continue
            end

            if se.type[row] == 6 # Pi
                if col == se.index[row]
                    fill!(I, 0.0)
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

            elseif se.type[row] == 7 # Pij
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

            elseif se.type[row] == 8 # Pji
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

            elseif se.type[row] == 9 # Qi
                if col == se.index[row]
                    fill!(I, 0.0)
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

            elseif se.type[row] == 10 # Qij
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

            elseif se.type[row] == 11 # Qji
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

            elseif se.type[row] == 4 # Iij2
                model = IijCoefficient(branch, ac, idx)
                state = ViVjθijState(system, voltage, idx)
                Iij = Iij2(model, state)

                if col == branch.layout.from[idx]
                    se.residual[row] = se.mean[row] - Iij
                    seobjective(analysis, row)

                    jcb[row, col] = Iij2θi(model, state)
                    jcb[row, cok] = Iij2Vi(model, state)
                else
                    jcb[row, col] = Iij2θj(model, state)
                    jcb[row, cok] = Iij2Vj(model, state)
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

            elseif se.type[row] == 5 # Iji2
                model = IjiCoefficient(branch, ac, idx)
                state = ViVjθijState(system, voltage, idx)
                Iji = Iji2(model, state)

                if col == branch.layout.from[idx]
                    se.residual[row] = se.mean[row] - Iji
                    seobjective(analysis, row)

                    jcb[row, col] = Iji2θi(model, state)
                    jcb[row, cok] = Iji2Vi(model, state)
                else
                    jcb[row, col] = Iji2θj(model, state)
                    jcb[row, cok] = Iji2Vj(model, state)
                end

            elseif se.type[row] == 16 # Re(Vi)
                se.residual[row] = se.mean[row] - ReVi(voltage, idx)
                seobjective(analysis, row)

                jcb[row, col] = ReViθi(voltage, idx)
                jcb[row, cok] = ReViVi(voltage, idx)

            elseif se.type[row] == 17 # Im(Vi)
                se.residual[row] = se.mean[row] - ImVi(voltage, idx)
                seobjective(analysis, row, row - 1)

                jcb[row, col] = ImViθi(voltage, idx)
                jcb[row, cok] = ImViVi(voltage, idx)

            elseif se.type[row] == 14 # ψij
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

            elseif se.type[row] == 15 # ψji
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

            elseif se.type[row] == 18 # Re(Iij)
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

            elseif se.type[row] == 20 # Im(Iij)
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

            elseif se.type[row] == 19 # Re(Iji)
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

            elseif se.type[row] == 21 # Im(Iji)
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

    @inbounds for row = se.range[1]:(se.range[2] - 1)
        if se.type[row] == 1 # Vi
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
            seobjective(analysis, row)
        end
    end

    @inbounds for row = se.range[5]:(se.range[6] - 1)
        if se.type[row] == 12 # Vi
            se.residual[row] = se.mean[row] - voltage.magnitude[se.index[row]]
            seobjective(analysis, row)
        elseif se.type[row] == 13 # Ti
            se.residual[row] = se.mean[row] - voltage.angle[se.index[row]]
            seobjective(analysis, row)
        end
    end
end

"""
    acLavStateEstimation(monitoring::Measurement, optimizer;
        iteration, tolerance, bridge, name, magnitude, angle, positive, negative, verbose)

The function sets up the LAV method to solve the nonlinear or AC state estimation model, where the
vector of state variables is given in polar coordinates.

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
`magnitude`, `angle`, `positive`, and `negative`. For instance, users can choose `magnitude = "V"`,
`angle = "θ"`, `positive = "u"`, and `negative = "v"` to display equations in a more readable format.

# Updates
If the AC model has not been created, the function will automatically trigger an update of the `ac`
field within the `PowerSystem` composite type.

# Returns
The function returns an instance of the [`AcStateEstimation`](@ref AcStateEstimation) type.

# Example
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = acLavStateEstimation(monitoring, Ipopt.Optimizer)
```
"""
function acLavStateEstimation(
    monitoring::Measurement,
    @nospecialize optimizerFactory;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    bridge::Bool = false,
    name::Bool = true,
    magnitude::String = "magnitude",
    angle::String = "angle",
    positive::String = "positive",
    negative::String = "negative",
    verbose::Int64 = template.config.verbose
)
    system = monitoring.system
    ac = system.model.ac
    bus = system.bus
    branch = system.branch
    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter
    pmu = monitoring.pmu

    checkSlackBus(system)
    model!(system, ac)

    total = volt.number + amp.number + watt.number + var.number + 2 * pmu.number

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    lav = LAV(
        jump,
        LavVariableRef(
            PolarVariableRef(
                @variable(jump, magnitude[i = 1:bus.number], base_name = magnitude),
                @variable(jump, angle[i = 1:bus.number], base_name = angle)
            ),
            DeviationVariableRef(
                @variable(jump, 0 <= positive[i = 1:total], base_name = positive),
                @variable(jump, 0 <= negative[i = 1:total], base_name = negative)
            )
        ),
        Dict{Int64, ConstraintRef}(),
        OrderedDict{Int64, Int64}(),
        fill(1, 6),
        total
    )
    objective = @expression(lav.jump, AffExpr())

    voltage = lav.variable.voltage
    deviation = lav.variable.deviation

    fix(voltage.angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack]; force = true)

    @inbounds for (k, idx) in enumerate(volt.layout.index)
        if volt.magnitude.status[k] == 1
            addConstrLav!(lav, voltage.magnitude[idx], volt.magnitude.mean[k], k)
            addObjectLav!(lav, objective, k)
        else
            fix!(deviation, k)
        end
    end
    lav.range[2] = volt.number + 1

    cnt = volt.number + 1
    @inbounds for (k, idx) in enumerate(amp.layout.index)
        if amp.magnitude.status[k] == 1
            if amp.layout.from[k]
                expr = Iij(system, voltage, amp.layout.square[k], idx)
            else
                expr = Iji(system, voltage, amp.layout.square[k], idx)
            end

            sq = if2exp(amp.layout.square[k])
            addConstrLav!(lav, expr, amp.magnitude.mean[k]^sq, cnt)
            addObjectLav!(lav, objective, cnt)
        else
            fix!(deviation, cnt)
        end
        cnt += 1
    end
    lav.range[3] = cnt

    @inbounds for (k, idx) in enumerate(watt.layout.index)
        if watt.active.status[k] == 1
            if watt.layout.bus[k]
                expr = Pi(system, voltage, idx)
            else
                if watt.layout.from[k]
                    expr = Pij(system, voltage, idx)
                else
                    expr = Pji(system, voltage, idx)
                end
            end
            addConstrLav!(lav, expr, watt.active.mean[k], cnt)
            addObjectLav!(lav, objective, cnt)
        else
            fix!(deviation, cnt)
        end
        cnt += 1
    end
    lav.range[4] = cnt

    @inbounds for (k, idx) in enumerate(var.layout.index)
        if var.reactive.status[k] == 1
            if var.layout.bus[k]
                expr = Qi(system, voltage, idx)
            else
                if var.layout.from[k]
                    expr = Qij(system, voltage, idx)
                else
                    expr = Qji(system, voltage, idx)
                end
            end
            addConstrLav!(lav, expr, var.reactive.mean[k], cnt)
            addObjectLav!(lav, objective, cnt)
        else
            fix!(deviation, cnt)
        end
        cnt += 1
    end
    lav.range[5] = cnt

    @inbounds for (k, idx) in enumerate(pmu.layout.index)
        if pmu.layout.polar[k]
            if pmu.layout.bus[k]
                if pmu.magnitude.status[k] == 1
                    addConstrLav!(lav, voltage.magnitude[idx], pmu.magnitude.mean[k], cnt)
                    addObjectLav!(lav, objective, cnt)
                else
                    fix!(deviation, cnt)
                end

                if pmu.angle.status[k] == 1
                    addConstrLav!(lav, voltage.angle[idx], pmu.angle.mean[k], cnt + 1)
                    addObjectLav!(lav, objective, cnt + 1)
                else
                    fix!(deviation, cnt + 1)
                end
            else
                if pmu.magnitude.status[k] == 1
                    if pmu.layout.from[k]
                        expr = Iij(system, voltage, pmu.layout.square[k], idx)
                    else
                        expr = Iji(system, voltage, pmu.layout.square[k], idx)
                    end

                    sq = if2exp(pmu.layout.square[k])
                    addConstrLav!(lav, expr, pmu.magnitude.mean[k]^sq, cnt)
                    addObjectLav!(lav, objective, cnt)
                else
                    fix!(deviation, cnt)
                end

                if pmu.angle.status[k] == 1
                    if pmu.layout.from[k]
                        expr = ψij(system, voltage, idx)
                    else
                        expr = ψji(system, voltage, idx)
                    end
                    addConstrLav!(lav, expr, pmu.angle.mean[k], cnt + 1)
                    addObjectLav!(lav, objective, cnt + 1)
                else
                    fix!(deviation, cnt + 1)
                end
            end
        else
            if pmu.magnitude.status[k] == 1 && pmu.angle.status[k] == 1
                if pmu.layout.bus[k]
                    ReExpr, ImExpr = ReImVi(voltage, idx)
                else
                    if pmu.layout.from[k]
                        ReExpr, ImExpr = ReImIij(system, voltage, idx)
                    else
                        ReExpr, ImExpr = ReImIji(system, voltage, idx)
                    end
                end
                ReMean = pmu.magnitude.mean[k] * cos(pmu.angle.mean[k])
                ImMean = pmu.magnitude.mean[k] * sin(pmu.angle.mean[k])

                addConstrLav!(lav, ReExpr, ReMean, cnt)
                addObjectLav!(lav, objective, cnt)

                addConstrLav!(lav, ImExpr, ImMean, cnt + 1)
                addObjectLav!(lav, objective, cnt + 1)
            else
                fix!(deviation, cnt)
                fix!(deviation, cnt + 1)
            end
        end
        cnt += 2
    end
    lav.range[6] = cnt

    @objective(lav.jump, Min, objective)

    AcStateEstimation(
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
    increment!(analysis::AcStateEstimation)

By solving the normal equation, this function computes the bus voltage magnitude and angle increments.

# Updates
The function updates the `residual`, `jacobian`, and `factorisation` variables within the
`AcStateEstimation` type. Using these results, it then computes and updates the `increment` variable
within the same type. It should be used during the Gauss-Newton iteration loop before invoking the
[`solve!`](@ref solve!(::AcStateEstimation)) function.

# Returns
The function returns the maximum absolute increment value, which can be used to terminate the
iteration loop of the Gauss-Newton method applied to solve the AC state estimation problem.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
increment!(analysis)
```
"""
function increment!(analysis::AcStateEstimation{GaussNewton{Normal}})
    system = analysis.system

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

    if se.signature[:pattern] == -1
        se.signature[:pattern] = 0
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

    return maximum(abs, se.increment)
end

function increment!(analysis::AcStateEstimation{GaussNewton{Orthogonal}})
    system = analysis.system

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
    if se.signature[:pattern] == -1
        se.signature[:pattern] = 0
        se.factorization = factorization(jcbScale, se.factorization)
    else
        se.factorization = factorization!(jcbScale, se.factorization)
    end

    se.increment = solution(se.increment, se.precision * se.residual, se.factorization)

    @inbounds for (k, i) in enumerate(slackRange)
        jcb[jcb.rowval[i], bus.layout.slack] = elementsRemove[k]
    end

    se.increment[bus.layout.slack] = 0.0

    @inbounds for i = 1:lastindex(se.mean)
        se.precision.nzval[i] ^= 2
    end

    return maximum(abs, se.increment)
end

"""
    solve!(analysis::AcStateEstimation)

By computing the bus voltage magnitudes and angles, the function solves the AC state estimation. Note
that if the Gauss-Newton method is employed to obtain the WLS estimator, this function simply updates
the state variables using the obtained increments.

# Updates
The resulting bus voltage magnitudes and angles are stored in the `voltage` field of the
`AcStateEstimation` type.

# Examples
Solving the AC state estimation model and obtaining the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
for iteration = 1:20
    stopping = increment!(analysis)
    if stopping < 1e-8
        break
    end
    solve!(analysis)
end
```

Solving the AC state estimation model and obtaining the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = acLavStateEstimation(monitoring, Ipopt.Optimizer; verbose = 1)
solve!(analysis)
```
"""
function solve!(analysis::AcStateEstimation{GaussNewton{T}}) where T <: Union{Normal, Orthogonal}
    system = analysis.system
    bus = system.bus
    volt = analysis.voltage

    @inbounds for i = 1:bus.number
        volt.angle[i] = volt.angle[i] + analysis.method.increment[i]
        volt.magnitude[i] = volt.magnitude[i] + analysis.method.increment[i + bus.number]
    end
    analysis.method.iteration += 1
end

function solve!(analysis::AcStateEstimation{LAV})
    system = analysis.system
    bus = system.bus
    lav = analysis.method
    volt = analysis.voltage
    verbose = lav.jump.ext[:verbose]

    silentJump(lav.jump, verbose)

    @inbounds for i = 1:bus.number
        set_start_value(lav.variable.voltage.angle[i]::VariableRef, bus.voltage.angle[i])
        set_start_value(lav.variable.voltage.magnitude[i]::VariableRef, bus.voltage.magnitude[i])
    end

    optimize!(lav.jump)

    @inbounds for i = 1:bus.number
        volt.angle[i] = value(lav.variable.voltage.angle[i]::VariableRef)
        volt.magnitude[i] = value(lav.variable.voltage.magnitude[i]::VariableRef)
    end

    printExit(lav.jump, verbose)
end

"""
    setInitialPoint!(analysis::AcStateEstimation)

The function sets the initial point of the AC state estimation to the values from the `PowerSystem`
type.

# Updates
The function modifies the `voltage` field of the `AcStateEstimation` type.

# Example:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

residualTest!(analysis; threshold = 1.0)

setInitialPoint!(analysis)
stateEstimation!(analysis)
```
"""
function setInitialPoint!(analysis::AcStateEstimation)
    errorTransfer(analysis.system.bus.voltage.magnitude, analysis.voltage.magnitude)
    errorTransfer(analysis.system.bus.voltage.angle, analysis.voltage.angle)

    @inbounds for i = 1:analysis.system.bus.number
        analysis.voltage.magnitude[i] = analysis.system.bus.voltage.magnitude[i]
        analysis.voltage.angle[i] = analysis.system.bus.voltage.angle[i]
    end
end

"""
    setInitialPoint!(target::AcStateEstimation, source::Analysis)

The function initializes the AC state estimation based on results from the `Analysis` type, whether
from an AC or DC analysis.

The function assigns the bus voltage magnitudes and angles in the `target` argument, using data from
the `source` argument. This allows users to initialize AC state estimation as needed.

If `source` comes from a DC analysis, only the bus voltage angles are assigned in the `target`
argument, while the bus voltage magnitudes remain unchanged.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

source = newtonRaphson(system)
powerFlow!(source)

target = gaussNewton(monitoring)

setInitialPoint!(target, source)
stateEstimation!(target)
```
"""
function setInitialPoint!(target::AcStateEstimation, source::AC)
    errorTransfer(source.voltage.magnitude, target.voltage.magnitude)
    errorTransfer(source.voltage.angle, target.voltage.angle)

    @inbounds for i = 1:length(source.voltage.magnitude)
        target.voltage.magnitude[i] = source.voltage.magnitude[i]
        target.voltage.angle[i] = source.voltage.angle[i]
    end
end

function setInitialPoint!(target::AcStateEstimation, source::DC)
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
    stateEstimation!(analysis::AcStateEstimation;
        iteration, tolerance, power, current, verbose)

The function serves as a wrapper for solving AC state estimation and includes the functions:
* [`solve!`](@ref solve!(::AcStateEstimation{GaussNewton{Normal}})),
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

Additionally, for the WLS model, it includes:
* [`increment!`](@ref increment!).

It computes bus voltage magnitudes and angles using the WLS or LAV model with the option to compute
powers and currents.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations (default for WLS model: `40`).
* `tolerance`: Defines the tolerance for the iteration stopping criterion (default for WLS model: `1e-8`).
* `power`: Enables the computation of powers (default: `false`).
* `current`: Enables the computation of currents (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

For the WLS model, `tolerance` refers to the step size tolerance in the stopping criterion, whereas
for the LAV model, it defines the allowed deviation from the optimal solution. If `iteration` and
`tolerance` are not specified for the LAV model, the optimization solver settings are used.

# Examples
Use the wrapper function to obtain the WLS estimator:
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis; tolerance = 1e-10, current = true, verbose = 3)
```

Use the wrapper function to obtain the LAV estimator:
```jldoctest
using Ipopt

system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = acLavStateEstimation(monitoring, Ipopt.Optimizer)
stateEstimation!(analysis; iteration = 30, power = true, verbose = 1)
```
"""
function stateEstimation!(
    analysis::AcStateEstimation{GaussNewton{T}};
    iteration::Int64 = 40,
    tolerance::Float64 = 1e-8,
    power::Bool = false,
    current::Bool = false,
    verbose::Int64 = template.config.verbose
)  where T <: Union{Normal, Orthogonal}

    system = analysis.system
    converged = false
    maxExceeded = false
    analysis.method.iteration = 0

    printTop(analysis, verbose)
    printMiddle(system, analysis, verbose)

    for iter = 0:iteration
        maxInc = increment!(analysis)

        printSolver(analysis, maxInc, verbose)
        if maxInc < tolerance
            converged = true
            break
        end
        if analysis.method.iteration == iteration
            maxExceeded = true
            break
        end
        solve!(analysis)
    end

    printSolver(system, analysis, verbose)
    printExit(analysis, maxExceeded, converged, verbose)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end
end

function stateEstimation!(
    analysis::AcStateEstimation{LAV};
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    current::Bool = false,
    verbose::IntMiss = missing
)
    masterVerbose = analysis.method.jump.ext[:verbose]
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    printTop(analysis, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end

    analysis.method.jump.ext[:verbose] = masterVerbose
end