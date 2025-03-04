Base.@kwdef struct PiModel
    A::Float64 = 0.0
    B::Float64 = 0.0
    C::Float64 = 0.0
    D::Float64 = 0.0
end

Base.@kwdef struct StateModel
    Vi::Float64 = 0.0
    Vj::Float64 = 0.0
    sinθij::Float64 = 0.0
    cosθij::Float64 = 0.0
    sinθi::Float64 = 0.0
    sinθj::Float64 = 0.0
    cosθi::Float64 = 0.0
    cosθj::Float64 = 0.0
end

##### State Variables #####
function ViVjθijState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθij = sin(V.angle[i] - V.angle[j] - system.branch.parameter.shiftAngle[idx]),
        cosθij = cos(V.angle[i] - V.angle[j] - system.branch.parameter.shiftAngle[idx])
    )
end

function ViVjθiθjState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθi = sin(V.angle[i]),
        cosθi = cos(V.angle[i]),
        sinθj = sin(V.angle[j] + system.branch.parameter.shiftAngle[idx]),
        cosθj = cos(V.angle[j] + system.branch.parameter.shiftAngle[idx]),
    )
end

function VjViθjθiState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθi = sin(V.angle[i] - system.branch.parameter.shiftAngle[idx]),
        cosθi = cos(V.angle[i] - system.branch.parameter.shiftAngle[idx]),
        sinθj = sin(V.angle[j]),
        cosθj = cos(V.angle[j])
    )
end

function GijBijθij(ac::ACModel, V::Polar, i::Int64, j::Int64, q::Int64)
    Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[q])
    sinθij, cosθij = sincos(V.angle[i] - V.angle[j])

    return Gij, Bij, sinθij, cosθij
end

function GijBijθij(ac::ACModel, V::Polar, i::Int64, j::Int64)
    Gij, Bij = reim(ac.nodalMatrix[i, j])
    sinθij, cosθij = sincos(V.angle[i] - V.angle[j])

    return Gij, Bij, sinθij, cosθij
end

function PiQiSum(V::Polar,
    Gij::Float64,
    tgc1::Float64,
    Bij::Float64,
    tgc2::Float64,
    I::Vector{Float64},
    j::Int64,
    op::Function,
    idx::Int64
)
    I[idx] += V.magnitude[j] * (Gij * tgc1 + op(Bij * tgc2))
end

##### Active Power Injection #####
function Pi(V::Polar, I::Float64, i::Int64)
    V.magnitude[i] * I
end

function Piθi(V::Polar, Bii::Float64, I::Float64, i::Int64)
    V.magnitude[i] * I - Bii * V.magnitude[i]^2
end

function Piθj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64, j::Int64)
    V.magnitude[i] * V.magnitude[j] * (Gij * sinθij - Bij * cosθij)
end

function PiVi(V::Polar, Gii::Float64, I::Float64, i::Int64)
    I + Gii * V.magnitude[i]
end

function PiVj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64)
    V.magnitude[i] * (Gij * cosθij + Bij * sinθij)
end

function meanPi(bus::Bus, dc::DCModel, watt::Wattmeter, i::Int64, j::Int64)
    watt.active.mean[i] - dc.shiftPower[j] - bus.shunt.conductance[j]
end

##### Reactive Power Injection #####
function Qi(V::Polar, I::Float64, i::Int64)
    V.magnitude[i] * I
end

function Qiθi(V::Polar, Gii::Float64, I::Float64, i::Int64)
    V.magnitude[i] * I - Gii * V.magnitude[i]^2
end

function Qiθj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64, j::Int64)
    -V.magnitude[i] * V.magnitude[j] * (Gij * cosθij + Bij * sinθij)
end

function QiVi(V::Polar, Bii::Float64, I::Float64, i::Int64)
    I - Bii * V.magnitude[i]
end

function QiVj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64)
    V.magnitude[i] * (Gij * sinθij - Bij * cosθij)
end

##### From-Bus End Active Power Flow #####
function PijCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (gij + 0.5 * branch.parameter.conductance[idx]),
        B = τinv * gij,
        C = τinv * bij
    )
end

function Pij(p::PiModel, e::StateModel)
    p.A * e.Vi^2 - (p.B * e.cosθij + p.C * e.sinθij) * e.Vi * e.Vj
end

function Pijθi(p::PiModel, e::StateModel)
    (p.B * e.sinθij - p.C * e.cosθij) * e.Vi * e.Vj
end

function PijVi(p::PiModel, e::StateModel)
    2 * p.A * e.Vi - (p.B * e.cosθij + p.C * e.sinθij) * e.Vj
end

function Pijθj(p::PiModel, e::StateModel)
    -Pijθi(p, e)
end

function PijVj(p::PiModel, e::StateModel)
    -(p.B * e.cosθij + p.C * e.sinθij) * e.Vi
end

function meanPij(branch::Branch, watt::Wattmeter, admittance::Float64, i::Int64, j::Int64)
    watt.active.mean[i] + branch.parameter.shiftAngle[j] * admittance
end

##### To-Bus End Active Power Flow #####
function PjiCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = gij + 0.5 * branch.parameter.conductance[idx],
        B = τinv * gij,
        C = τinv * bij
    )
end

function Pji(p::PiModel, e::StateModel)
    p.A * e.Vj^2 - (p.B * e.cosθij - p.C * e.sinθij) * e.Vi * e.Vj
end

function Pjiθi(p::PiModel, e::StateModel)
    (p.B * e.sinθij + p.C * e.cosθij) * e.Vi * e.Vj
end

function PjiVi(p::PiModel, e::StateModel)
    (-p.B * e.cosθij + p.C * e.sinθij) * e.Vj
end

function Pjiθj(p::PiModel, e::StateModel)
    -Pjiθi(p, e)
end

function PjiVj(p::PiModel, e::StateModel)
    2 * p.A * e.Vj - (p.B * e.cosθij - p.C * e.sinθij) * e.Vi
end

##### From-Bus End Reactive Power Flow #####
function QijCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (bij + 0.5 * branch.parameter.susceptance[idx]),
        B = τinv * gij,
        C = τinv * bij
    )
end

function Qij(p::PiModel, e::StateModel)
    -p.A * e.Vi^2 - (p.B * e.sinθij - p.C * e.cosθij) * e.Vi * e.Vj
end

function Qijθi(p::PiModel, e::StateModel)
    -(p.B * e.cosθij + p.C * e.sinθij) * e.Vi * e.Vj
end

function QijVi(p::PiModel, e::StateModel)
    -2 * p.A * e.Vi - (p.B * e.sinθij - p.C * e.cosθij) * e.Vj
end

function Qijθj(p::PiModel, e::StateModel)
    -Qijθi(p, e)
end

function QijVj(p::PiModel, e::StateModel)
    -(p.B * e.sinθij - p.C * e.cosθij) * e.Vi
end

##### To-Bus End Reactive Power Flow #####
function QjiCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = bij + 0.5 * branch.parameter.susceptance[idx],
        B = τinv * gij,
        C = τinv * bij
    )
end

function Qji(p::PiModel, e::StateModel)
    -p.A * e.Vj^2 + (p.B * e.sinθij + p.C * e.cosθij) * e.Vi * e.Vj
end

function Qjiθi(p::PiModel, e::StateModel)
    (p.B * e.cosθij - p.C * e.sinθij) * e.Vi * e.Vj
end

function QjiVi(p::PiModel, e::StateModel)
    (p.B * e.sinθij + p.C * e.cosθij) * e.Vj
end

function Qjiθj(p::PiModel, e::StateModel)
    -Qjiθi(p, e)
end

function QjiVj(p::PiModel, e::StateModel)
    -2 * p.A * e.Vj + (p.B * e.sinθij + p.C * e.cosθij) * e.Vi
end

##### From-Bus End Current Magnitude #####
function IijCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    gsi = 0.5 * branch.parameter.conductance[idx]
    bsi = 0.5 * branch.parameter.susceptance[idx]
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^4 * ((gij + gsi)^2 + (bij + bsi)^2),
        B = τinv^2 * (gij^2 + bij^2),
        C = τinv^3 * (gij * (gij + gsi) + bij * (bij + bsi)),
        D = τinv^3 * (gij * bsi - bij * gsi)
    )
end

function Iijinv(p::PiModel, e::StateModel)
    1 / (sqrt(p.A * e.Vi^2 + p.B * e.Vj^2 -
        2 * e.Vi * e.Vj * (p.C * e.cosθij - p.D * e.sinθij)))
end

function Iijθi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.C * e.sinθij + p.D * e.cosθij) * e.Vi * e.Vj
end

function IijVi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.A * e.Vi - (p.C * e.cosθij - p.D * e.sinθij) * e.Vj)
end

function Iijθj(p::PiModel, e::StateModel, Iinv::Float64)
    -Iijθi(p, e, Iinv)
end

function IijVj(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.B * e.Vj - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi)
end

##### To-Bus End Current Magnitude #####
function IjiCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    gsi = 0.5 * branch.parameter.conductance[idx]
    bsi = 0.5 * branch.parameter.susceptance[idx]
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (gij^2 + bij^2),
        B = (gij + gsi)^2 + (bij + bsi)^2,
        C = τinv * (gij * (gij + gsi) + bij * (bij + bsi)),
        D = τinv * (gij * bsi - gsi * bij)
    )
end

function Ijiinv(p::PiModel, e::StateModel)
    1 / sqrt(p.A * e.Vi^2 + p.B * e.Vj^2 -
        2 * e.Vi * e.Vj * (p.C * e.cosθij + p.D * e.sinθij))
end

function Ijiθi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.C * e.sinθij - p.D * e.cosθij) * e.Vi * e.Vj
end

function IjiVi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.A * e.Vi - (p.C * e.cosθij + p.D * e.sinθij) * e.Vj)
end

function Ijiθj(p::PiModel, e::StateModel, Iinv::Float64)
    -Ijiθi(p, e, Iinv)
end

function IjiVj(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.B * e.Vj - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi)
end

##### From-Bus End Current Angle #####
function ψijCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (gij + 0.5 * branch.parameter.conductance[idx]),
        B = τinv^2 * (bij + 0.5 * branch.parameter.susceptance[idx]),
        C = τinv * gij,
        D = τinv * bij
    )
end

function ψij(p::PiModel, e::StateModel)
    ReIij = (p.A * e.cosθi - p.B * e.sinθi) * e.Vi - (p.C * e.cosθj - p.D * e.sinθj) * e.Vj
    ImIij = (p.A * e.sinθi + p.B * e.cosθi) * e.Vi - (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
    Iij = complex(ReIij, ImIij)

    return 1 / (abs(Iij))^2, Iij
end

function ψijθi(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.A * e.Vi^2 - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi * e.Vj)
end

function ψijVi(p::PiModel, e::StateModel, Iinv2::Float64)
    -Iinv2 * (p.C * e.sinθij + p.D * e.cosθij) * e.Vj
end

function ψijθj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.B * e.Vj^2 - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi * e.Vj)
end

function ψijVj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.C * e.sinθij + p.D * e.cosθij) * e.Vi
end

##### To-Bus End Current Angle #####
function ψjiCoefficient(branch::Branch, ac::ACModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = gij + 0.5 * branch.parameter.conductance[idx],
        B = bij + 0.5 * branch.parameter.susceptance[idx],
        C = τinv * gij,
        D = τinv * bij
    )
end

function ψji(p::PiModel, e::StateModel)
    ReIij = (p.A * e.cosθj - p.B * e.sinθj) * e.Vj - (p.C * e.cosθi - p.D * e.sinθi) * e.Vi
    ImIij = (p.A * e.sinθj + p.B * e.cosθj) * e.Vj - (p.C * e.sinθi + p.D * e.cosθi) * e.Vi
    Iij = complex(ReIij, ImIij)

    return 1 / (abs(Iij))^2, Iij
end

function ψjiθi(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.A * e.Vi^2 - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi * e.Vj)
end

function ψjiVi(p::PiModel, e::StateModel, Iinv2::Float64)
    -Iinv2 * (p.C * e.sinθij - p.D * e.cosθij) * e.Vj
end

function ψjiθj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.B * e.Vj^2 - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi * e.Vj)
end

function ψjiVj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.C * e.sinθij - p.D * e.cosθij) * e.Vi
end

###### Bus Voltage Angle ######
function meanθi(pmu::PMU, bus::Bus, i::Int64)
    pmu.angle.mean[i] - bus.voltage.angle[bus.layout.slack]
end

##### Real Component of From-Bus End Current Phasor #####
function ReIij(p::PiModel, e::StateModel)
    (p.A * e.cosθi - p.B * e.sinθi) * e.Vi - (p.C * e.cosθj - p.D * e.sinθj) * e.Vj
end

function ReIijθi(p::PiModel, e::StateModel)
    -(p.A * e.sinθi + p.B * e.cosθi) * e.Vi
end

function ReIijVi(p::PiModel, e::StateModel)
    p.A * e.cosθi - p.B * e.sinθi
end

function ReIijθj(p::PiModel, e::StateModel)
    (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
end

function ReIijVj(p::PiModel, e::StateModel)
    -p.C * e.cosθj + p.D * e.sinθj
end

##### Imaginary Component of From-Bus End Current Phasor #####
function ImIij(p::PiModel, e::StateModel)
    (p.A * e.sinθi + p.B * e.cosθi) * e.Vi - (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
end

function ImIijθi(p::PiModel, e::StateModel)
    (p.A * e.cosθi - p.B * e.sinθi) * e.Vi
end

function ImIijVi(p::PiModel, e::StateModel)
    p.A * e.sinθi + p.B * e.cosθi
end

function ImIijθj(p::PiModel, e::StateModel)
    (-p.C * e.cosθj + p.D * e.sinθj) * e.Vj
end

function ImIijVj(p::PiModel, e::StateModel)
    -p.C * e.sinθj - p.D * e.cosθj
end

##### Real Component of To-Bus End Current Phasor #####
function ReIji(p::PiModel, e::StateModel)
    (p.A * e.cosθj - p.B * e.sinθj) * e.Vj - (p.C * e.cosθi - p.D * e.sinθi) * e.Vi
end

function ReIjiθi(p::PiModel, e::StateModel)
    (p.C * e.sinθi + p.D * e.cosθi) * e.Vi
end

function ReIjiVi(p::PiModel, e::StateModel)
    -p.C * e.cosθi + p.D * e.sinθi
end

function ReIjiθj(p::PiModel, e::StateModel)
    -(p.A * e.sinθj + p.B * e.cosθj) * e.Vj
end

function ReIjiVj(p::PiModel, e::StateModel)
    p.A * e.cosθj - p.B * e.sinθj
end

##### Imaginary Component of To-Bus End Current Phasor #####
function ImIji(p::PiModel, e::StateModel)
    (p.A * e.sinθj + p.B * e.cosθj) * e.Vj - (p.C * e.sinθi + p.D * e.cosθi) * e.Vi
end

function ImIjiθi(p::PiModel, e::StateModel)
    (-p.C * e.cosθi + p.D * e.sinθi) * e.Vi
end

function ImIjiVi(p::PiModel, e::StateModel)
    -p.C * e.sinθi - p.D * e.cosθi
end

function ImIjiθj(p::PiModel, e::StateModel)
    (p.A * e.cosθj - p.B * e.sinθj) * e.Vj
end

function ImIjiVj(p::PiModel, e::StateModel)
    p.A * e.sinθj + p.B * e.cosθj
end

##### Real Component of Bus Voltage Phasor #####
function ReVi(V::Polar, i::Int64)
    V.magnitude[i] * cos(V.angle[i])
end

function ReViθi(V::Polar, i::Int64)
    -V.magnitude[i] * sin(V.angle[i])
end

function ReViVi(V::Polar, i::Int64)
    cos(V.angle[i])
end

##### Imaginary Component of Bus Voltage Phasor #####
function ImVi(V::Polar, i::Int64)
    V.magnitude[i] * sin(V.angle[i])
end

function ImViθi(V::Polar, i::Int64)
    V.magnitude[i] * cos(V.angle[i])
end

function ImViVi(V::Polar, i::Int64)
    sin(V.angle[i])
end

##### PMU Variance #####
function variancePmu(pmu::PMU, cosθ::Float64, sinθ::Float64, idx::Int64)
    varianceRe =
        pmu.magnitude.variance[idx] * cosθ^2 +
        pmu.angle.variance[idx] * (pmu.magnitude.mean[idx] * sinθ)^2

    varianceIm =
        pmu.magnitude.variance[idx] * sinθ^2 +
        pmu.angle.variance[idx] * (pmu.magnitude.mean[idx] * cosθ)^2

    return varianceRe, varianceIm
end

##### PMU Covariance #####
function covariancePmu(
    pmu::PMU,
    cosθ::Float64,
    sinθ::Float64,
    varianceRe::Float64,
    varianceIm::Float64,
    idxPmu::Int64
)
    L1⁻¹ = 1 / sqrt(varianceRe)
    L2 =
        (sinθ * cosθ * (pmu.magnitude.variance[idxPmu] -
        pmu.angle.variance[idxPmu] * pmu.magnitude.mean[idxPmu]^2)) * L1⁻¹
    L3⁻² = 1 / (varianceIm - L2^2)

    return L1⁻¹, L2, L3⁻²
end

##### PMU Precision #####
function precision!(
    precision::SparseMatrixCSC{Float64, Int64},
    pmu::PMU,
    cosθ::Float64,
    sinθ::Float64,
    varianceRe::Float64,
    varianceIm::Float64,
    idxPmu::Int64,
    idx::Int64
)
    L1⁻¹, L2, L3⁻² = covariancePmu(pmu, cosθ, sinθ, varianceRe, varianceIm, idxPmu)

    precision[idx, idx + 1] = (- L2 * L1⁻¹) * L3⁻²
    precision[idx + 1, idx] = precision[idx, idx + 1]
    precision[idx, idx] = (L1⁻¹ - L2 * precision[idx, idx + 1]) * L1⁻¹
    precision[idx + 1, idx + 1] = L3⁻²
end

function precision!(
    pcs::SparseModel,
    pmu::PMU,
    cosθ::Float64,
    sinθ::Float64,
    varianceRe::Float64,
    varianceIm::Float64,
    idxPmu::Int64
)
    L1⁻¹, L2, L3⁻² = covariancePmu(pmu, cosθ, sinθ, varianceRe, varianceIm, idxPmu)

    pcs.row[pcs.cnt] = pcs.idx
    pcs.col[pcs.cnt] = pcs.idx + 1
    pcs.val[pcs.cnt] = (-L2 * L1⁻¹) * L3⁻²

    pcs.row[pcs.cnt + 1] = pcs.idx + 1
    pcs.col[pcs.cnt + 1] = pcs.idx
    pcs.val[pcs.cnt + 1] = pcs.val[pcs.cnt]

    pcs.row[pcs.cnt + 2] = pcs.idx
    pcs.col[pcs.cnt + 2] = pcs.idx
    pcs.val[pcs.cnt + 2] = (L1⁻¹ - L2 * pcs.val[pcs.cnt]) * L1⁻¹

    pcs.row[pcs.cnt + 3] = pcs.idx + 1
    pcs.col[pcs.cnt + 3] = pcs.idx + 1
    pcs.val[pcs.cnt + 3] = L3⁻²

    pcs.cnt += 4
    pcs.idx += 2
end

function precision!(pcs::SparseModel, variance::Float64)
    pcs.row[pcs.cnt] = pcs.idx
    pcs.col[pcs.cnt] = pcs.idx
    pcs.val[pcs.cnt] = 1 / variance

    pcs.cnt += 1
    pcs.idx += 1
end

##### Base Voltages at the Branch Ends #####
function baseVoltageEnd(
    system::PowerSystem,
    baseVolt::BaseVoltage,
    from::Bool,
    idxBranch::Int64
)
    layout = system.branch.layout
    if from
        return baseVolt.value[layout.from[idxBranch]] * baseVolt.prefix
    else
        return baseVolt.value[layout.to[idxBranch]] * baseVolt.prefix
    end
end

##### WLS AC State Estimation Objective Value #####
function seobjective(analysis::ACStateEstimation, idx::Int64)
    se = analysis.method
    se.objective += se.residual[idx]^2 * se.precision[idx, idx]
end

function seobjective(analysis::ACStateEstimation, idx1::Int64, idx2::Int64)
    se = analysis.method
    se.objective += se.residual[idx1]^2 * se.precision[idx1, idx1] +
        2 * se.residual[idx1] * se.residual[idx2] * se.precision[idx1, idx2]
end