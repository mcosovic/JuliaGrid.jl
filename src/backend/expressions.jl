##### State Variables #####
function θijState!(system::PowerSystem, method::LAV, idxBrch::Int64)
    if !haskey(method.state.sinθij, idxBrch)
        i = system.branch.layout.from[idxBrch]
        j = system.branch.layout.to[idxBrch]
        θij = @expression(
            method.jump, method.statex[i] - method.statey[i] -
            method.statex[j] + method.statey[j]
        )
        method.state.sinθij[idxBrch] = sin(θij)
        method.state.cosθij[idxBrch] = cos(θij)
    end
end

function θiState!(method::LAV, idxBus::Int64...)
    for i in idxBus
        if !haskey(method.state.sinθ, i)
            θ = method.statex[i] - method.statey[i]
            method.state.sinθ[i] = sin(θ)
            method.state.cosθ[i] = cos(θ)
        end
    end
end

function minusΦ(A::Float64, B::Float64, Φ::Float64)
    return A * cos(Φ) + B * sin(Φ), -A * sin(Φ) + B * cos(Φ)
end

function plusΦ(A::Float64, B::Float64, Φ::Float64)
    return A * cos(Φ) - B * sin(Φ), A * sin(Φ) + B * cos(Φ)
end

function idxBijGij(method::LAV, BG::Float64, i::Int64, j::Int64)
    if haskey(method.state.incidence, (i, j))
        return method.state.incidence[(i, j)], BG
    else
        return method.state.incidence[(j, i)], -BG
    end
end

function GijBijθij(ac::ACModel, angle::Vector{VariableRef}, i::Int64, j::Int64, ptr::Int64)
    θij = angle[i] - angle[j]
    sinθij = sin(θij)
    cosθij = cos(θij)
    Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[ptr])

    return Gij, Bij, sinθij, cosθij
end

function θi(se::LAV, i::Int64)
    se.statex[i] - se.statey[i]
end

##### Active Power Injection #####
function Pi(system::PowerSystem, method::LAV, i::Int64)
    ac = system.model.ac
    s = method.state

    expr = @expression(method.jump, real(ac.nodalMatrixTranspose[i, i]) * s.V[i])

    @inbounds for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[ptr])
            k, Bij = idxBijGij(method, Bij, i, j)
            θijState!(system, method, k)

            expr += (Gij * s.cosθij[k] + Bij * s.sinθij[k]) * s.V[j]
        end
    end

    s.V[i] * expr
end

function Pi(dc::DCModel, se::LAV, k::Int64)
    nodal = dc.nodalMatrix

    expr = @expression(se.jump, AffExpr())
    @inbounds for ptr in nodal.colptr[k]:(nodal.colptr[k + 1] - 1)
        j = nodal.rowval[ptr]
        add_to_expression!(expr, nodal.nzval[ptr] * (se.statex[j] - se.statey[j]))
    end

    return expr
end

##### From-Bus End Active Power Flow #####
function Pij(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = PijCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = plusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    p.A * s.V[i]^2 - s.V[i] * s.V[j] * (k1 * s.cosθij[idx] + k2 * s.sinθij[idx])
end

function Pij(system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθij::NonlinearExpr,
    cosθij::NonlinearExpr,
    idx::Int64
)
    p = PijCoefficient(system.branch, system.model.ac, idx)

    p.A * Vi^2 - Vi * Vj * (p.B * cosθij + p.C * sinθij)
end

function Pij(system::PowerSystem, se::LAV, admittance::Float64, idx::Int64)
    i, j = fromto(system, idx)

    AffExpr(0.0,
        se.statex[i] => admittance,
        se.statey[i] => -admittance,
        se.statex[j] => -admittance,
        se.statey[j]=> admittance,
    )
end

##### To-Bus End Active Power Flow #####
function Pji(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = PjiCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = minusΦ(p.B, p.C, system.branch.parameter.shiftAngle[idx])

    p.A * s.V[j]^2 - s.V[i] * s.V[j] * (k1 * s.cosθij[idx] - k2 * s.sinθij[idx])
end

function Pji(system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθij::NonlinearExpr,
    cosθij::NonlinearExpr,
    idx::Int64
)
    p = PjiCoefficient(system.branch, system.model.ac, idx)

    p.A * Vj^2 - Vi * Vj * (p.B * cosθij - p.C * sinθij)
end

##### Reactive Power Injection #####
function Qi(system::PowerSystem, method::LAV, i::Int64)
    ac = system.model.ac
    s = method.state

    expr = @expression(method.jump, -imag(ac.nodalMatrixTranspose[i, i]) * s.V[i])

    @inbounds for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[ptr])
            k, Gij = idxBijGij(method, Gij, i, j)
            θijState!(system, method, k)

            expr += (Gij * s.sinθij[k] - Bij * s.cosθij[k]) * s.V[j]
        end
    end

    s.V[i] * expr
end

##### From-Bus End Reactive Power Flow #####
function Qij(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = QijCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = minusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    -p.A * s.V[i]^2 + s.V[i] * s.V[j] * (k1 * s.cosθij[idx] - k2 * s.sinθij[idx])
end

##### To-Bus End Reactive Power Flow #####
function Qji(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = QjiCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = plusΦ(p.C, p.B, system.branch.parameter.shiftAngle[idx])

    -p.A * s.V[j]^2 + s.V[i] * s.V[j] * (k1 * s.cosθij[idx] + k2 * s.sinθij[idx])
end

##### From-Bus End Current Magnitude #####
function Iij(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = IijCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = minusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    @expression(
        method.jump, sqrt(p.A * s.V[i]^2 + p.B * s.V[j]^2 -
        2 * s.V[i] * s.V[j] * (k1 * s.cosθij[idx] - k2 * s.sinθij[idx]))
    )
end

function Iij(
    system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθij::NonlinearExpr,
    cosθij::NonlinearExpr,
    idx::Int64
)
    p = IijCoefficient(system.branch, system.model.ac, idx)

    sqrt(p.A * Vi^2 + p.B * Vj^2 - 2 * Vi * Vj * (p.C * cosθij - p.D * sinθij))
end

##### To-Bus End Current Magnitude #####
function Iji(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = IjiCoefficient(system.branch, system.model.ac, idx)

    θijState!(system, method, idx)
    k1, k2 = plusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])

    @expression(
        method.jump, sqrt(p.A * s.V[i]^2 + p.B * s.V[j]^2 -
        2 * s.V[i] * s.V[j] * (k1 * s.cosθij[idx] + k2 * s.sinθij[idx]))
    )
end

function Iji(
    system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθ::NonlinearExpr,
    cosθ::NonlinearExpr,
    idx::Int64
)
    p = IjiCoefficient(system.branch, system.model.ac, idx)

    sqrt(p.A * Vi^2 + p.B * Vj^2 - 2 * Vi * Vj * (p.C * cosθ + p.D * sinθ))
end

##### From-Bus End Current Angle #####
function ψij(system::PowerSystem, method::LAV, idx::Int64)
    IijRe, IijIm = ReImIij(system, method, idx)

    atan(IijIm, IijRe)
end

##### To-Bus End Current Angle #####
function ψji(system::PowerSystem, method::LAV, idx::Int64)
    IjiRe, IjiIm = ReImIji(system, method, idx)

    atan(IjiIm, IjiRe)
end

##### From-Bus End Apparent Power #####
function Sij(
    system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθ::NonlinearExpr,
    cosθ::NonlinearExpr,
    idx::Int64
)
    p = IijCoefficient(system.branch, system.model.ac, idx)

    sqrt(p.A * Vi^4 + p.B * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (p.C * cosθ - p.D * sinθ))
end

##### To-Bus End Apparent Power #####
function Sji(
    system::PowerSystem,
    Vi::VariableRef,
    Vj::VariableRef,
    sinθ::NonlinearExpr,
    cosθ::NonlinearExpr,
    idx::Int64
)
    p = IjiCoefficient(system.branch, system.model.ac, idx)

    sqrt(p.A * Vi^2 * Vj^2 + p.B * Vj^4 - 2 * Vi * Vj^3 * (p.C * cosθ + p.D * sinθ))
end

##### Real and Imaginary Components of Bus Voltage Phasor #####
function ReImVi(method::LAV, idx::Int64)
    s = method.state
    θiState!(method, idx)

    return s.V[idx] * s.cosθ[idx], s.V[idx] * s.sinθ[idx]
end

function ReImVi(method::LAV, i::Int64, j::Int64)
    return @expression(method.jump, method.statex[i] - method.statey[i]),
    @expression(method.jump, method.statex[i + j] - method.statey[i + j])
end

##### Real and Imaginary Components of From-Bus End Current Phasor #####
function ReImIij(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = ψijCoefficient(system.branch, system.model.ac, idx)

    θiState!(method, i, j)
    k1, k2 = minusΦ(p.C, p.D, -system.branch.parameter.shiftAngle[idx])
    k3, k4 = plusΦ(p.D, p.C, -system.branch.parameter.shiftAngle[idx])

    IijRe = (p.A * s.cosθ[i] - p.B * s.sinθ[i]) * s.V[i] - (k1 * s.cosθ[j] - k2 * s.sinθ[j]) * s.V[j]
    IijIm = (p.A * s.sinθ[i] + p.B * s.cosθ[i]) * s.V[i] - (k3 * s.cosθ[j] + k4 * s.sinθ[j]) * s.V[j]

    return IijRe, IijIm
end

function ReImIijCoefficient(branch::Branch, ac::ACModel, idx::Int64)
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

function ReImIij(
    system::PowerSystem,
    method::LAV,
    p::PiModel,
    idx::Int64
)
    i, j = fromto(system, idx)
    k = system.bus.number

    return AffExpr(0.0,
        method.statex[i] => p.A,
        method.statey[i] => -p.A,
        method.statex[i + k] => p.B,
        method.statey[i + k]=> -p.B,
        method.statex[j] => p.C,
        method.statey[j]=> -p.C,
        method.statex[j + k]=> p.D,
        method.statey[j + k]=> -p.D,
    ),
    AffExpr(0.0,
        method.statex[i] => -p.B,
        method.statey[i] => p.B,
        method.statex[i + k] => p.A,
        method.statey[i + k]=> -p.A,
        method.statex[j] => -p.D,
        method.statey[j]=> p.D,
        method.statex[j + k]=> p.C,
        method.statey[j + k]=> -p.C,
    )
end

##### Real and Imaginary Components of To-Bus End Current Phasor #####
function ReImIji(system::PowerSystem, method::LAV, idx::Int64)
    s = method.state

    i, j = fromto(system, idx)
    p = ψjiCoefficient(system.branch, system.model.ac, idx)

    θiState!(method, i, j)
    k1, k2 = minusΦ(p.C, p.D, system.branch.parameter.shiftAngle[idx])
    k3, k4 = plusΦ(p.D, p.C, system.branch.parameter.shiftAngle[idx])

    IjiRe = (p.A * s.cosθ[j] - p.B * s.sinθ[j]) * s.V[j] - (k1 * s.cosθ[i] - k2 * s.sinθ[i]) * s.V[i]
    IjiIm = (p.A * s.sinθ[j] + p.B * s.cosθ[j]) * s.V[j] - (k3 * s.cosθ[i] + k4 * s.sinθ[i]) * s.V[i]

    return IjiRe, IjiIm
end

function ReImIjiCoefficient(branch::Branch, ac::ACModel, idx::Int64)
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

##### Add Constraints #####
function addConstrLav!(method::LAV, expr::AffExpr, z::Float64, idx::Int64)
    method.residual[idx] = @constraint(
        method.jump, expr + method.residualx[idx] - method.residualy[idx] == z
    )
end

function addConstrLav!(method::LAV, expr::NonlinearExpr, z::Float64, idx::Int64)
    method.residual[idx] = @constraint(
        method.jump, expr + method.residualx[idx] - method.residualy[idx] == z
    )
end

##### Add Objective #####
function addObjectLav!(method::LAV, objective::AffExpr, idx::Int64)
    add_to_expression!(objective, method.residualx[idx] + method.residualy[idx])
end

##### Fix Values #####
function fix!(residualx::Vector{VariableRef}, residualy::Vector{VariableRef}, index::Int64)
    fix(residualx[index], 0.0; force = true)
    fix(residualy[index], 0.0; force = true)
end