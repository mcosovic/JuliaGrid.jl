Base.@kwdef struct AffQuadExpr
    aff::AffExpr = AffExpr()
    quad1::QuadExpr = QuadExpr()
    quad2::QuadExpr = QuadExpr()
end

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

    NonlinearExpr(:*, V[i], expr)
end

function Pi(system::PowerSystem, voltage::AngleVariableRef, expr::AffExpr, i::Int64)
    nodal = system.model.dc.nodalMatrix

    @inbounds for ptr in nodal.colptr[i]:(nodal.colptr[i + 1] - 1)
        j = nodal.rowval[ptr]
        add_to_expression!(expr, nodal.nzval[ptr] * voltage.angle[j])
    end
end

##### From-Bus Active Power Flow #####
function Pij(system::PowerSystem, v::PolarVariableRef, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = PijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.A, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, cos(expr.aff))
    sinθij = NonlinearExpr(:*, k2, sin(expr.aff))

    NonlinearExpr(:-, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:+, cosθij, sinθij)))
end

function Pij(system::PowerSystem, voltage::AngleVariableRef, admittance::Float64, expr::AffExpr, idx::Int64)
    i, j = fromto(system, idx)
    add_to_expression!(expr, admittance, voltage.angle[i])
    add_to_expression!(expr, -admittance, voltage.angle[j])
end

function Pij(system::PowerSystem, angle::Vector{VariableRef}, expr::AffExpr, idx::Int64)
    dc = system.model.dc

    i, j = fromto(system, idx)
    add_to_expression!(expr, dc.admittance[idx], angle[i])
    add_to_expression!(expr, -dc.admittance[idx], angle[j])
    add_to_expression!(expr, -dc.admittance[idx] * system.branch.parameter.shiftAngle[idx])
end

##### To-Bus Active Power Flow #####
function Pji(system::PowerSystem, v::PolarVariableRef, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = PjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.A, v.magnitude[j], v.magnitude[j])
    add_to_expression!(expr.quad2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, cos(expr.aff))
    sinθij = NonlinearExpr(:*, k2, sin(expr.aff))

    NonlinearExpr(:-, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:-, cosθij, sinθij)))
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

    NonlinearExpr(:*, V[i], expr)
end

##### From-Bus Reactive Power Flow #####
function Qij(system::PowerSystem, v::PolarVariableRef, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = QijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, -p.A, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, NonlinearExpr(:cos, expr.aff))
    sinθij = NonlinearExpr(:*, k2, NonlinearExpr(:sin, expr.aff))

    NonlinearExpr(:+, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:-, cosθij, sinθij)))
end

##### To-Bus Reactive Power Flow #####
function Qji(system::PowerSystem, v::PolarVariableRef, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = QjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, -p.A, v.magnitude[j], v.magnitude[j])
    add_to_expression!(expr.quad2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, NonlinearExpr(:cos, expr.aff))
    sinθij = NonlinearExpr(:*, k2, NonlinearExpr(:sin, expr.aff))

    NonlinearExpr(:+, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:+, cosθij, sinθij)))
end

##### From-Bus Current Magnitude #####
function Iij(system::PowerSystem, v::PolarVariableRef, square::Bool, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = IijCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = minusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.A, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad1, p.B, v.magnitude[j], v.magnitude[j])
    add_to_expression!(expr.quad2, 2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, cos(expr.aff))
    sinθij = NonlinearExpr(:*, k2, sin(expr.aff))

    Iij = NonlinearExpr(:-, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:-, cosθij, sinθij)))

    if square
        return Iij
    else
        return NonlinearExpr(:sqrt, Iij)
    end
end

##### To-Bus Current Magnitude #####
function Iji(system::PowerSystem, v::PolarVariableRef, square::Bool, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = IjiCoefficient(system.branch, system.model.ac, idx)
    k1, k2 = plusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.A, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad1, p.B, v.magnitude[j], v.magnitude[j])
    add_to_expression!(expr.quad2, 2, v.magnitude[i], v.magnitude[j])

    cosθij = NonlinearExpr(:*, k1, cos(expr.aff))
    sinθij = NonlinearExpr(:*, k2, sin(expr.aff))

    Iji = NonlinearExpr(:-, expr.quad1, NonlinearExpr(:*, expr.quad2, NonlinearExpr(:+, cosθij, sinθij)))

    if square
        return Iji
    else
        return NonlinearExpr(:sqrt, Iji)
    end
end

##### From-Bus Current Angle #####
function ψij(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    IijRe, IijIm = ReImIij(system, voltage, idx)

    NonlinearExpr(:atan, IijIm, IijRe)
end

##### To-Bus Current Angle #####
function ψji(system::PowerSystem, voltage::PolarVariableRef, idx::Int64)
    IjiRe, IjiIm = ReImIji(system, voltage, idx)

    NonlinearExpr(:atan, IjiIm, IjiRe)
end

##### From-Bus Apparent Power #####
function Sij(system::PowerSystem, v::PolarVariableRef, square::Bool, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)
    p = IijCoefficient(system.branch, system.model.ac, idx)

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.B, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad2, v.magnitude[j], v.magnitude[j])

    Vi2Vj2 = NonlinearExpr(:*, expr.quad1, expr.quad2)
    Vi4 = NonlinearExpr(:*, p.A, v.magnitude[i]^4)
    Vi3Vj = NonlinearExpr(:*, -2, v.magnitude[i]^3, v.magnitude[j])

    cosθij = NonlinearExpr(:*, p.C, cos(expr.aff))
    sinθij = NonlinearExpr(:*, p.D, sin(expr.aff))

    Sij = NonlinearExpr(:+, Vi4, Vi2Vj2, NonlinearExpr(:*, Vi3Vj, NonlinearExpr(:-, cosθij, sinθij)))

    if square
        return Sij
    else
        return NonlinearExpr(:sqrt, Sij)
    end
end

##### To-Bus Apparent Power #####
function Sji(system::PowerSystem, v::PolarVariableRef, square::Bool, expr::AffQuadExpr, idx::Int64)
    i, j = fromto(system, idx)

    p = IjiCoefficient(system.branch, system.model.ac, idx)

    add_to_expression!(expr.aff, v.angle[i])
    add_to_expression!(expr.aff, -1.0, v.angle[j])

    add_to_expression!(expr.quad1, p.A, v.magnitude[i], v.magnitude[i])
    add_to_expression!(expr.quad2, v.magnitude[j], v.magnitude[j])

    Vi2Vj2 = NonlinearExpr(:*, expr.quad1, expr.quad2)
    Vj4 = NonlinearExpr(:*, p.B, v.magnitude[j]^4)
    Vi3Vj = NonlinearExpr(:*, -2, v.magnitude[i], v.magnitude[j]^3)

    cosθij = NonlinearExpr(:*, p.C, cos(expr.aff))
    sinθij = NonlinearExpr(:*, p.D, sin(expr.aff))

    Sji = NonlinearExpr(:+, Vi2Vj2, Vj4, NonlinearExpr(:*, Vi3Vj, NonlinearExpr(:+, cosθij, sinθij)))

    if square
        return Sji
    else
        return NonlinearExpr(:sqrt, Sji)
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

function ReImIij(system::PowerSystem, voltage::RectangularVariableRef, p::PiModel, reExpr::AffExpr, imExpr::AffExpr, idx::Int64)
    i, j = fromto(system, idx)

    add_to_expression!(reExpr, p.A, voltage.real[i])
    add_to_expression!(reExpr, p.B, voltage.imag[i])
    add_to_expression!(reExpr, p.C, voltage.real[j])
    add_to_expression!(reExpr, p.D, voltage.imag[j])

    add_to_expression!(imExpr, -p.B, voltage.real[i])
    add_to_expression!(imExpr, p.A, voltage.imag[i])
    add_to_expression!(imExpr, -p.D, voltage.real[j])
    add_to_expression!(imExpr, p.C, voltage.imag[j])
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

##### Bus Voltage Angle Difference #####
function θij(system::PowerSystem, θ::Vector{VariableRef}, expr::AffExpr, idx::Int64)
    i, j = fromto(system, idx)

    add_to_expression!(expr, 1.0, θ[i])
    add_to_expression!(expr, -1.0, θ[j])
end

##### Read Data for Injection Measurements #####
function GijBijθij(ac::AcModel, angle::Vector{VariableRef}, i::Int64, j::Int64, ptr::Int64)
    θij = angle[i] - angle[j]
    Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[ptr])

    return Gij, Bij, sin(θij), cos(θij)
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
    add_to_expression!(expr, lav.variable.deviation.positive[idx])
    add_to_expression!(expr, -1.0, lav.variable.deviation.negative[idx])

    lav.residual[idx] = add_constraint(lav.jump, ScalarConstraint(expr, MOI.EqualTo(z)))
end

function addConstrLav!(lav::LAV, expr::NonlinearExpr, z::Float64, aff::AffExpr, idx::Int64)
    add_to_expression!(aff, lav.variable.deviation.positive[idx])
    add_to_expression!(aff, -1.0, lav.variable.deviation.negative[idx])

    lav.residual[idx] = @constraint(lav.jump, expr + aff == z)
    empty!(aff.terms)
end

function addConstrLav!(lav::LAV, var::VariableRef, z::Float64, idx::Int64)
    dev = lav.variable.deviation
    lav.residual[idx] = @constraint(lav.jump, var + dev.positive[idx] - dev.negative[idx] == z)
end

##### Add Objective #####
function addObjectLav!(lav::LAV, objective::AffExpr, idx::Int64)
    add_to_expression!(objective, lav.variable.deviation.positive[idx])
    add_to_expression!(objective, lav.variable.deviation.negative[idx])
end

#### Fix Values #####
function fix!(deviation::DeviationVariableRef, idx::Int64)
    fix(deviation.positive[idx], 0.0; force = true)
    fix(deviation.negative[idx], 0.0; force = true)
end

##### Reset Expression #####
function emptyExpr!(expr::AffExpr)
    expr.constant = 0.0
    empty!(expr.terms)
end

function emptyExpr!(expr::AffQuadExpr)
    empty!(expr.aff.terms)
    empty!(expr.quad1.terms)
    empty!(expr.quad2.terms)
end