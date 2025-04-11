##### Active Power Injection #####
function Pi(system::PowerSystem, voltage::PolarVariableRef, i::Int64)
    ac = system.model.ac
    V = voltage.magnitude

    expr = real(ac.nodalMatrixTranspose[i, i]) * V[i]

    @inbounds for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage.angle, i, j, ptr)

            expr += (Gij * cosθij + Bij * sinθij) * V[j]
        end
    end

    V[i] * expr
end

function Pi(system::PowerSystem, voltage::AngleVariableRef, i::Int64)
    nodal = system.model.dc.nodalMatrix

    expr = AffExpr()
    @inbounds for ptr in nodal.colptr[i]:(nodal.colptr[i + 1] - 1)
        j = nodal.rowval[ptr]
        add_to_expression!(expr, nodal.nzval[ptr] * voltage.angle[j])
    end

    expr
end

##### From-Bus Active Power Flow #####
function Pij(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = PijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    p.A * V[i]^2 - V[i] * V[j] * (k1 * cos(θij) + k2 * sin(θij))
end

function Pij(system::PowerSystem, voltage::AngleVariableRef, admittance::Float64, idx::Int64)
    i, j = fromto(system, idx)

    admittance * voltage.angle[i] - admittance * voltage.angle[j]
end

##### To-Bus Active Power Flow #####
function Pji(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = PjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    p.A * V[j]^2 - V[i] * V[j] * (k1 * cos(θij) - k2 * sin(θij))
end

##### Reactive Power Injection #####
function Qi(system::PowerSystem, voltage::PolarVariableRef, i::Int64)
    ac = system.model.ac
    V = voltage.magnitude

    expr = -imag(ac.nodalMatrixTranspose[i, i]) * V[i]

    @inbounds for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, voltage.angle, i, j, ptr)

            expr += (Gij * sinθij - Bij * cosθij) * V[j]
        end
    end

    V[i] * expr
end

##### From-Bus Reactive Power Flow #####
function Qij(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = QijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    -p.A * V[i]^2 + V[i] * V[j] * (k1 * cos(θij) - k2 * sin(θij))
end

##### To-Bus Reactive Power Flow #####
function Qji(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = QjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    -p.A * V[j]^2 + V[i] * V[j] * (k1 * cos(θij) + k2 * sin(θij))
end

##### From-Bus Current Magnitude #####
function Iij(system::PowerSystem, voltage::PolarVariableRef, square::Bool, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = IijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    if square
        p.A * V[i]^2 + p.B * V[j]^2 - 2 * V[i] * V[j] * (k1 * cos(θij) - k2 * sin(θij))
    else
        sqrt(p.A * V[i]^2 + p.B * V[j]^2 - 2 * V[i] * V[j] * (k1 * cos(θij) - k2 * sin(θij)))
    end
end

##### To-Bus Current Magnitude #####
function Iji(system::PowerSystem, voltage::PolarVariableRef, square::Bool, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]

    p = IjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    if square
        p.A * V[i]^2 + p.B * V[j]^2 - 2 * V[i] * V[j] * (k1 * cos(θij) + k2 * sin(θij))
    else
        sqrt(p.A * V[i]^2 + p.B * V[j]^2 - 2 * V[i] * V[j] * (k1 * cos(θij) + k2 * sin(θij)))
    end
end

##### From-Bus Current Angle #####
function ψij(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    IijRe, IijIm = ReImIij(system, voltage, idx)

    atan(IijIm, IijRe)
end

##### To-Bus Current Angle #####
function ψji(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    IjiRe, IjiIm = ReImIji(system, voltage, idx)

    atan(IjiIm, IjiRe)
end

##### From-Bus Apparent Power #####
function Sij(system::PowerSystem, voltage::PolarVariableRef, square::Bool, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]
    p = IijCoefficient(system.branch, system.model.ac, idx)

    if square
        p.A * V[i]^4 + p.B * V[i]^2 * V[j]^2 - 2 * V[i]^3 * V[j] * (p.C * cos(θij) - p.D * sin(θij))
    else
        sqrt(p.A * V[i]^4 + p.B * V[i]^2 * V[j]^2 - 2 * V[i]^3 * V[j] * (p.C * cos(θij) - p.D * sin(θij)))
    end
end

##### To-Bus Apparent Power #####
function Sji(system::PowerSystem, voltage::PolarVariableRef, square::Bool, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    θij = voltage.angle[i] - voltage.angle[j]
    p = IjiCoefficient(system.branch, system.model.ac, idx)

    if square
        p.A * V[i]^2 * V[j]^2 + p.B * V[j]^4 - 2 * V[i] * V[j]^3 * (p.C * cos(θij) + p.D * sin(θij))
    else
        sqrt(p.A * V[i]^2 * V[j]^2 + p.B * V[j]^4 - 2 * V[i] * V[j]^3 * (p.C * cos(θij) + p.D * sin(θij)))
    end
end

##### Bus Voltage Real and Imaginary Components #####
function ReImVi(voltage::PolarVariableRef, i::Int64)
    voltage.magnitude[i] * cos(voltage.angle[i]), voltage.magnitude[i] * sin(voltage.angle[i])
end

##### From-Bus Current Real and Imaginary Components #####
function ReImIij(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    sinθi = sin(voltage.angle[i])
    cosθi = cos(voltage.angle[i])
    sinθj = sin(voltage.angle[j])
    cosθj = cos(voltage.angle[j])

    p = ψijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.D, -system.branch.parameter.shiftAngle[idx])
    k3, k4 = plusΦ(p.D, p.C, -system.branch.parameter.shiftAngle[idx])

    IijRe = (p.A * cosθi - p.B * sinθi) * V[i] - (k1 * cosθj - k2 * sinθj) * V[j]
    IijIm = (p.A * sinθi + p.B * cosθi) * V[i] - (k3 * cosθj + k4 * sinθj) * V[j]

    IijRe, IijIm
end

function ReImIijCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]
    Φ = branch.parameter.shiftAngle[idx]

    PiModel(
        A = τinv^2 * (gij + 0.5 * branch.parameter.conductance[idx]),
        B = -τinv^2 * (bij + 0.5 * branch.parameter.susceptance[idx]),
        C = -τinv * (gij * cos(Φ) - bij * sin(Φ)),
        D = τinv * (bij * cos(Φ) + gij * sin(Φ))
    )
end

function ReImIij(system::PowerSystem, voltage::PolarVariableRef, p::PiModel, idx::Int64)
    i, j = fromto(system, idx)

    AffExpr(0.0,
        voltage.angle[i] => p.A,
        voltage.magnitude[i] => p.B,
        voltage.angle[j] => p.C,
        voltage.magnitude[j]=> p.D,
    ),
    AffExpr(0.0,
        voltage.angle[i] => -p.B,
        voltage.magnitude[i] => p.A,
        voltage.angle[j] => -p.D,
        voltage.magnitude[j]=> p.C,
    )
end

function ReImIij(system::PowerSystem, voltage::RectangularVariableRef, p::PiModel, idx::Int64)
    i, j = fromto(system, idx)

    AffExpr(0.0,
        voltage.real[i] => p.A,
        voltage.imag[i] => p.B,
        voltage.real[j] => p.C,
        voltage.imag[j]=> p.D,
    ),
    AffExpr(0.0,
        voltage.real[i] => -p.B,
        voltage.imag[i] => p.A,
        voltage.real[j] => -p.D,
        voltage.imag[j]=> p.C,
    )
end

##### To-Bus Current Real and Imaginary Components #####
function ReImIji(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    i, j = fromto(system, idx)

    V = voltage.magnitude
    sinθi = sin(voltage.angle[i])
    cosθi = cos(voltage.angle[i])
    sinθj = sin(voltage.angle[j])
    cosθj = cos(voltage.angle[j])

    p = ψjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])
    k3, k4 = plusΦ(p.D, p.C, system.branch.parameter.shiftAngle[idx])

    IjiRe = (p.A * cosθj - p.B * sinθj) * V[j] - (k1 * cosθi - k2 * sinθi) * V[i]
    IjiIm = (p.A * sinθj + p.B * cosθj) * V[j] - (k3 * cosθi + k4 * sinθi) * V[i]

    return IjiRe, IjiIm
end

function ReImIjiCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]
    Φ = branch.parameter.shiftAngle[idx]

    PiModel(
        A = -τinv * (gij * cos(Φ) + bij * sin(Φ)),
        B = τinv * (bij * cos(Φ) - gij * sin(Φ)),
        C = gij + 0.5 * branch.parameter.conductance[idx],
        D = -bij - 0.5 * branch.parameter.susceptance[idx]
    )
end

##### Read Data for Injection Measurements #####
function GijBijθij(ac::AcModel, angle::Vector{VariableRef}, i::Int64, j::Int64, ptr::Int64)
    θij = angle[i] - angle[j]
    sinθij = sin(θij)
    cosθij = cos(θij)
    Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[ptr])

    return Gij, Bij, sinθij, cosθij
end

##### Eliminate Phase-Shift Angle from Sine and Cosine #####
function minusΦ(A::Float64, B::Float64, Φ::Float64)
    A * cos(Φ) + B * sin(Φ), -A * sin(Φ) + B * cos(Φ)
end

function plusΦ(A::Float64, B::Float64, Φ::Float64)
    A * cos(Φ) - B * sin(Φ), A * sin(Φ) + B * cos(Φ)
end

##### Add Constraints #####
function addConstrLav!(lav::LAV, expr::AffExpr, z::Float64, idx::Int64)
    dev = lav.variable.deviation
    lav.residual[idx] = @constraint(lav.jump, expr + dev.positive[idx] - dev.negative[idx] == z)
end

function addConstrLav!(lav::LAV, expr::NonlinearExpr, z::Float64, idx::Int64)
    dev = lav.variable.deviation
    lav.residual[idx] = @constraint(lav.jump, expr + dev.positive[idx] - dev.negative[idx] == z)
end

function addConstrLav!(lav::LAV, var::VariableRef, z::Float64, idx::Int64)
    dev = lav.variable.deviation
    lav.residual[idx] = @constraint(lav.jump, var + dev.positive[idx] - dev.negative[idx] == z)
end

##### Add Objective #####
function addObjectLav!(lav::LAV, objective::AffExpr, idx::Int64)
    dev = lav.variable.deviation
    add_to_expression!(objective, dev.positive[idx] + dev.negative[idx])
end

#### Fix Values #####
function fix!(deviation::DeviationVariableRef, idx::Int64)
    fix(deviation.positive[idx], 0.0; force = true)
    fix(deviation.negative[idx], 0.0; force = true)
end