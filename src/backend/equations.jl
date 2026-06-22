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
@inline function ViVjθijState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)
    sinθij, cosθij = sincos(V.angle[i] - V.angle[j] - system.branch.parameter.shiftAngle[idx])

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθij = sinθij,
        cosθij = cosθij
    )
end

@inline function ViVjθiθjState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)
    sinθi, cosθi = sincos(V.angle[i])
    sinθj, cosθj = sincos(V.angle[j] + system.branch.parameter.shiftAngle[idx])

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθi = sinθi,
        cosθi = cosθi,
        sinθj = sinθj,
        cosθj = cosθj,
    )
end

@inline function VjViθjθiState(system::PowerSystem, V::Polar, idx::Int64)
    i, j = fromto(system, idx)
    sinθi, cosθi = sincos(V.angle[i] - system.branch.parameter.shiftAngle[idx])
    sinθj, cosθj = sincos(V.angle[j])

    StateModel(
        Vi = V.magnitude[i],
        Vj = V.magnitude[j],
        sinθi = sinθi,
        cosθi = cosθi,
        sinθj = sinθj,
        cosθj = cosθj
    )
end

##### Admittance and Angle Helpers #####
@inline function GijBijθij(ac::AcModel, V::Polar, i::Int64, j::Int64, q::Int64)
    Gij, Bij = reim(ac.nodalMatrixTranspose.nzval[q])
    sinθij, cosθij = sincos(V.angle[i] - V.angle[j])

    return Gij, Bij, sinθij, cosθij
end

@inline function GijBijθij(ac::AcModel, V::Polar, i::Int64, j::Int64)
    Gij, Bij = reim(ac.nodalMatrix[i, j])
    sinθij, cosθij = sincos(V.angle[i] - V.angle[j])

    return Gij, Bij, sinθij, cosθij
end

##### Power Injection Helpers #####
@inline function PiQiSumPlus(
    V::Polar,
    Gij::Float64,
    tgc1::Float64,
    Bij::Float64,
    tgc2::Float64,
    j::Int64
)
    V.magnitude[j] * (Gij * tgc1 + Bij * tgc2)
end

@inline function PiQiSumMinus(
    V::Polar,
    Gij::Float64,
    tgc1::Float64,
    Bij::Float64,
    tgc2::Float64,
    j::Int64
)
    V.magnitude[j] * (Gij * tgc1 - Bij * tgc2)
end

##### Active Power Injection #####
@inline function Pi(V::Polar, I::Float64, i::Int64)
    V.magnitude[i] * I
end

@inline function Piθi(V::Polar, Bii::Float64, I::Float64, i::Int64)
    V.magnitude[i] * I - Bii * V.magnitude[i]^2
end

@inline function Piθj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64, j::Int64)
    V.magnitude[i] * V.magnitude[j] * (Gij * sinθij - Bij * cosθij)
end

@inline function PiVi(V::Polar, Gii::Float64, I::Float64, i::Int64)
    I + Gii * V.magnitude[i]
end

@inline function PiVj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64)
    V.magnitude[i] * (Gij * cosθij + Bij * sinθij)
end

@inline function meanPi(bus::Bus, dc::DcModel, watt::Wattmeter, i::Int64, j::Int64)
    watt.active.mean[i] - dc.shiftPower[j] - bus.shunt.conductance[j]
end

##### Reactive Power Injection #####
@inline function Qi(V::Polar, I::Float64, i::Int64)
    V.magnitude[i] * I
end

@inline function Qiθi(V::Polar, Gii::Float64, I::Float64, i::Int64)
    V.magnitude[i] * I - Gii * V.magnitude[i]^2
end

@inline function Qiθj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64, j::Int64)
    -V.magnitude[i] * V.magnitude[j] * (Gij * cosθij + Bij * sinθij)
end

@inline function QiVi(V::Polar, Bii::Float64, I::Float64, i::Int64)
    I - Bii * V.magnitude[i]
end

@inline function QiVj(V::Polar, Gij::Float64, Bij::Float64, sinθij::Float64, cosθij::Float64, i::Int64)
    V.magnitude[i] * (Gij * sinθij - Bij * cosθij)
end

##### From-Bus End Active Power Flow #####
@inline function PijCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (gij + 0.5 * branch.parameter.conductance[idx]),
        B = τinv * gij,
        C = τinv * bij
    )
end

@inline function Pij(p::PiModel, e::StateModel)
    p.A * e.Vi^2 - (p.B * e.cosθij + p.C * e.sinθij) * e.Vi * e.Vj
end

@inline function Pijθi(p::PiModel, e::StateModel)
    (p.B * e.sinθij - p.C * e.cosθij) * e.Vi * e.Vj
end

@inline function PijVi(p::PiModel, e::StateModel)
    2 * p.A * e.Vi - (p.B * e.cosθij + p.C * e.sinθij) * e.Vj
end

@inline function Pijθj(p::PiModel, e::StateModel)
    -Pijθi(p, e)
end

@inline function PijVj(p::PiModel, e::StateModel)
    -(p.B * e.cosθij + p.C * e.sinθij) * e.Vi
end

@inline function meanPij(branch::Branch, watt::Wattmeter, admittance::Float64, i::Int64, j::Int64)
    watt.active.mean[i] + branch.parameter.shiftAngle[j] * admittance
end

##### To-Bus End Active Power Flow #####
@inline function PjiCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = gij + 0.5 * branch.parameter.conductance[idx],
        B = τinv * gij,
        C = τinv * bij
    )
end

@inline function Pji(p::PiModel, e::StateModel)
    p.A * e.Vj^2 - (p.B * e.cosθij - p.C * e.sinθij) * e.Vi * e.Vj
end

@inline function Pjiθi(p::PiModel, e::StateModel)
    (p.B * e.sinθij + p.C * e.cosθij) * e.Vi * e.Vj
end

@inline function PjiVi(p::PiModel, e::StateModel)
    (-p.B * e.cosθij + p.C * e.sinθij) * e.Vj
end

@inline function Pjiθj(p::PiModel, e::StateModel)
    -Pjiθi(p, e)
end

@inline function PjiVj(p::PiModel, e::StateModel)
    2 * p.A * e.Vj - (p.B * e.cosθij - p.C * e.sinθij) * e.Vi
end

##### From-Bus End Reactive Power Flow #####
@inline function QijCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (bij + 0.5 * branch.parameter.susceptance[idx]),
        B = τinv * gij,
        C = τinv * bij
    )
end

@inline function Qij(p::PiModel, e::StateModel)
    -p.A * e.Vi^2 - (p.B * e.sinθij - p.C * e.cosθij) * e.Vi * e.Vj
end

@inline function Qijθi(p::PiModel, e::StateModel)
    -(p.B * e.cosθij + p.C * e.sinθij) * e.Vi * e.Vj
end

@inline function QijVi(p::PiModel, e::StateModel)
    -2 * p.A * e.Vi - (p.B * e.sinθij - p.C * e.cosθij) * e.Vj
end

@inline function Qijθj(p::PiModel, e::StateModel)
    -Qijθi(p, e)
end

@inline function QijVj(p::PiModel, e::StateModel)
    -(p.B * e.sinθij - p.C * e.cosθij) * e.Vi
end

##### To-Bus End Reactive Power Flow #####
@inline function QjiCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = bij + 0.5 * branch.parameter.susceptance[idx],
        B = τinv * gij,
        C = τinv * bij
    )
end

@inline function Qji(p::PiModel, e::StateModel)
    -p.A * e.Vj^2 + (p.B * e.sinθij + p.C * e.cosθij) * e.Vi * e.Vj
end

@inline function Qjiθi(p::PiModel, e::StateModel)
    (p.B * e.cosθij - p.C * e.sinθij) * e.Vi * e.Vj
end

@inline function QjiVi(p::PiModel, e::StateModel)
    (p.B * e.sinθij + p.C * e.cosθij) * e.Vj
end

@inline function Qjiθj(p::PiModel, e::StateModel)
    -Qjiθi(p, e)
end

@inline function QjiVj(p::PiModel, e::StateModel)
    -2 * p.A * e.Vj + (p.B * e.sinθij + p.C * e.cosθij) * e.Vi
end

##### From-Bus End Current Magnitude #####
@inline function IijCoefficient(branch::Branch, ac::AcModel, idx::Int64)
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

@inline function Iijinv(p::PiModel, e::StateModel)
    1 / (sqrt(p.A * e.Vi^2 + p.B * e.Vj^2 - 2 * e.Vi * e.Vj * (p.C * e.cosθij - p.D * e.sinθij)))
end

@inline function Iijθi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.C * e.sinθij + p.D * e.cosθij) * e.Vi * e.Vj
end

@inline function IijVi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.A * e.Vi - (p.C * e.cosθij - p.D * e.sinθij) * e.Vj)
end

@inline function Iijθj(p::PiModel, e::StateModel, Iinv::Float64)
    -Iijθi(p, e, Iinv)
end

@inline function IijVj(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.B * e.Vj - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi)
end

@inline function Iij2(p::PiModel, e::StateModel)
    p.A * e.Vi^2 + p.B * e.Vj^2 - 2 * e.Vi * e.Vj * (p.C * e.cosθij - p.D * e.sinθij)
end

@inline function Iij2θi(p::PiModel, e::StateModel)
    2 * (p.C * e.sinθij + p.D * e.cosθij) * e.Vi * e.Vj
end

@inline function Iij2Vi(p::PiModel, e::StateModel)
    2 * (p.A * e.Vi - (p.C * e.cosθij - p.D * e.sinθij) * e.Vj)
end

@inline function Iij2θj(p::PiModel, e::StateModel)
    -Iij2θi(p, e)
end

@inline function Iij2Vj(p::PiModel, e::StateModel)
    2 * (p.B * e.Vj - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi)
end

##### To-Bus End Current Magnitude #####
@inline function IjiCoefficient(branch::Branch, ac::AcModel, idx::Int64)
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

@inline function Ijiinv(p::PiModel, e::StateModel)
    1 / sqrt(p.A * e.Vi^2 + p.B * e.Vj^2 - 2 * e.Vi * e.Vj * (p.C * e.cosθij + p.D * e.sinθij))
end

@inline function Ijiθi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.C * e.sinθij - p.D * e.cosθij) * e.Vi * e.Vj
end

@inline function IjiVi(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.A * e.Vi - (p.C * e.cosθij + p.D * e.sinθij) * e.Vj)
end

@inline function Ijiθj(p::PiModel, e::StateModel, Iinv::Float64)
    -Ijiθi(p, e, Iinv)
end

@inline function IjiVj(p::PiModel, e::StateModel, Iinv::Float64)
    Iinv * (p.B * e.Vj - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi)
end

@inline function Iji2(p::PiModel, e::StateModel)
    p.A * e.Vi^2 + p.B * e.Vj^2 - 2 * e.Vi * e.Vj * (p.C * e.cosθij + p.D * e.sinθij)
end

@inline function Iji2θi(p::PiModel, e::StateModel)
    2 * (p.C * e.sinθij - p.D * e.cosθij) * e.Vi * e.Vj
end

@inline function Iji2Vi(p::PiModel, e::StateModel)
    2 * (p.A * e.Vi - (p.C * e.cosθij + p.D * e.sinθij) * e.Vj)
end

@inline function Iji2θj(p::PiModel, e::StateModel)
    -Iji2θi(p, e)
end

@inline function Iji2Vj(p::PiModel, e::StateModel)
    2 * (p.B * e.Vj - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi)
end

##### From-Bus End Current Angle #####
@inline function ψijCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = τinv^2 * (gij + 0.5 * branch.parameter.conductance[idx]),
        B = τinv^2 * (bij + 0.5 * branch.parameter.susceptance[idx]),
        C = τinv * gij,
        D = τinv * bij
    )
end

@inline function ψij(p::PiModel, e::StateModel)
    ReIij = (p.A * e.cosθi - p.B * e.sinθi) * e.Vi - (p.C * e.cosθj - p.D * e.sinθj) * e.Vj
    ImIij = (p.A * e.sinθi + p.B * e.cosθi) * e.Vi - (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
    Iij = complex(ReIij, ImIij)

    return 1 / abs2(Iij), Iij
end

@inline function ψijθi(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.A * e.Vi^2 - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi * e.Vj)
end

@inline function ψijVi(p::PiModel, e::StateModel, Iinv2::Float64)
    -Iinv2 * (p.C * e.sinθij + p.D * e.cosθij) * e.Vj
end

@inline function ψijθj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.B * e.Vj^2 - (p.C * e.cosθij - p.D * e.sinθij) * e.Vi * e.Vj)
end

@inline function ψijVj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.C * e.sinθij + p.D * e.cosθij) * e.Vi
end

##### To-Bus End Current Angle #####
@inline function ψjiCoefficient(branch::Branch, ac::AcModel, idx::Int64)
    gij, bij = reim(ac.admittance[idx])
    τinv = 1 / branch.parameter.turnsRatio[idx]

    PiModel(
        A = gij + 0.5 * branch.parameter.conductance[idx],
        B = bij + 0.5 * branch.parameter.susceptance[idx],
        C = τinv * gij,
        D = τinv * bij
    )
end

@inline function ψji(p::PiModel, e::StateModel)
    Iij = complex(ReIji(p, e), ImIji(p, e))

    return 1 / abs2(Iij), Iij
end

@inline function ψjiθi(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.A * e.Vi^2 - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi * e.Vj)
end

@inline function ψjiVi(p::PiModel, e::StateModel, Iinv2::Float64)
    -Iinv2 * (p.C * e.sinθij - p.D * e.cosθij) * e.Vj
end

@inline function ψjiθj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.B * e.Vj^2 - (p.C * e.cosθij + p.D * e.sinθij) * e.Vi * e.Vj)
end

@inline function ψjiVj(p::PiModel, e::StateModel, Iinv2::Float64)
    Iinv2 * (p.C * e.sinθij - p.D * e.cosθij) * e.Vi
end

##### Bus Voltage Angle #####
@inline function meanθi(pmu::PMU, bus::Bus, i::Int64)
    pmu.angle.mean[i] - bus.voltage.angle[bus.layout.slack]
end

##### Real Component of From-Bus End Current Phasor #####
@inline function ReIij(p::PiModel, e::StateModel)
    (p.A * e.cosθi - p.B * e.sinθi) * e.Vi - (p.C * e.cosθj - p.D * e.sinθj) * e.Vj
end

@inline function ReIijθi(p::PiModel, e::StateModel)
    -(p.A * e.sinθi + p.B * e.cosθi) * e.Vi
end

@inline function ReIijVi(p::PiModel, e::StateModel)
    p.A * e.cosθi - p.B * e.sinθi
end

@inline function ReIijθj(p::PiModel, e::StateModel)
    (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
end

@inline function ReIijVj(p::PiModel, e::StateModel)
    -p.C * e.cosθj + p.D * e.sinθj
end

##### Imaginary Component of From-Bus End Current Phasor #####
@inline function ImIij(p::PiModel, e::StateModel)
    (p.A * e.sinθi + p.B * e.cosθi) * e.Vi - (p.C * e.sinθj + p.D * e.cosθj) * e.Vj
end

@inline function ImIijθi(p::PiModel, e::StateModel)
    (p.A * e.cosθi - p.B * e.sinθi) * e.Vi
end

@inline function ImIijVi(p::PiModel, e::StateModel)
    p.A * e.sinθi + p.B * e.cosθi
end

@inline function ImIijθj(p::PiModel, e::StateModel)
    (-p.C * e.cosθj + p.D * e.sinθj) * e.Vj
end

@inline function ImIijVj(p::PiModel, e::StateModel)
    -p.C * e.sinθj - p.D * e.cosθj
end

##### Real Component of To-Bus End Current Phasor #####
@inline function ReIji(p::PiModel, e::StateModel)
    (p.A * e.cosθj - p.B * e.sinθj) * e.Vj - (p.C * e.cosθi - p.D * e.sinθi) * e.Vi
end

@inline function ReIjiθi(p::PiModel, e::StateModel)
    (p.C * e.sinθi + p.D * e.cosθi) * e.Vi
end

@inline function ReIjiVi(p::PiModel, e::StateModel)
    -p.C * e.cosθi + p.D * e.sinθi
end

@inline function ReIjiθj(p::PiModel, e::StateModel)
    -(p.A * e.sinθj + p.B * e.cosθj) * e.Vj
end

@inline function ReIjiVj(p::PiModel, e::StateModel)
    p.A * e.cosθj - p.B * e.sinθj
end

##### Imaginary Component of To-Bus End Current Phasor #####
@inline function ImIji(p::PiModel, e::StateModel)
    (p.A * e.sinθj + p.B * e.cosθj) * e.Vj - (p.C * e.sinθi + p.D * e.cosθi) * e.Vi
end

@inline function ImIjiθi(p::PiModel, e::StateModel)
    (-p.C * e.cosθi + p.D * e.sinθi) * e.Vi
end

@inline function ImIjiVi(p::PiModel, e::StateModel)
    -p.C * e.sinθi - p.D * e.cosθi
end

@inline function ImIjiθj(p::PiModel, e::StateModel)
    (p.A * e.cosθj - p.B * e.sinθj) * e.Vj
end

@inline function ImIjiVj(p::PiModel, e::StateModel)
    p.A * e.sinθj + p.B * e.cosθj
end

##### Real Component of Bus Voltage Phasor #####
@inline function ReVi(V::Polar, i::Int64)
    V.magnitude[i] * cos(V.angle[i])
end

@inline function ReViθi(V::Polar, i::Int64)
    -V.magnitude[i] * sin(V.angle[i])
end

@inline function ReViVi(V::Polar, i::Int64)
    cos(V.angle[i])
end

##### Imaginary Component of Bus Voltage Phasor #####
@inline function ImVi(V::Polar, i::Int64)
    V.magnitude[i] * sin(V.angle[i])
end

@inline function ImViθi(V::Polar, i::Int64)
    V.magnitude[i] * cos(V.angle[i])
end

@inline function ImViVi(V::Polar, i::Int64)
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

    errorVariance(pmu, varianceRe, varianceIm, idx)

    return varianceRe, varianceIm
end

##### PMU Covariance Factors #####
function covariancePmu(
    pmu::PMU,
    cosθ::Float64,
    sinθ::Float64,
    varianceRe::Float64,
    varianceIm::Float64,
    idxPmu::Int64
)
    varianceMagnitude = pmu.magnitude.variance[idxPmu]
    varianceAngle = pmu.angle.variance[idxPmu]
    magnitude = pmu.magnitude.mean[idxPmu]

    L1⁻¹ = 1 / sqrt(varianceRe)
    L2 = sinθ * cosθ * (varianceMagnitude - varianceAngle * magnitude^2) * L1⁻¹
    L3⁻² = 1 / (varianceIm - L2^2)

    errorCovariance(pmu, varianceIm, L2, idxPmu)

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
    offDiagonal = (-L2 * L1⁻¹) * L3⁻²

    precision[idx, idx + 1] = offDiagonal
    precision[idx + 1, idx] = offDiagonal
    precision[idx, idx] = (L1⁻¹ - L2 * offDiagonal) * L1⁻¹
    precision[idx + 1, idx + 1] = L3⁻²

    return nothing
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
    offDiagonal = (-L2 * L1⁻¹) * L3⁻²

    pcs.row[pcs.cnt] = pcs.idx
    pcs.col[pcs.cnt] = pcs.idx + 1
    pcs.val[pcs.cnt] = offDiagonal

    pcs.row[pcs.cnt + 1] = pcs.idx + 1
    pcs.col[pcs.cnt + 1] = pcs.idx
    pcs.val[pcs.cnt + 1] = offDiagonal

    pcs.row[pcs.cnt + 2] = pcs.idx
    pcs.col[pcs.cnt + 2] = pcs.idx
    pcs.val[pcs.cnt + 2] = (L1⁻¹ - L2 * offDiagonal) * L1⁻¹

    pcs.row[pcs.cnt + 3] = pcs.idx + 1
    pcs.col[pcs.cnt + 3] = pcs.idx + 1
    pcs.val[pcs.cnt + 3] = L3⁻²

    pcs.cnt += 4
    pcs.idx += 2

    return nothing
end

function precision!(pcs::SparseModel, variance::Float64)
    pcs.row[pcs.cnt] = pcs.idx
    pcs.col[pcs.cnt] = pcs.idx
    pcs.val[pcs.cnt] = 1 / variance

    pcs.cnt += 1
    pcs.idx += 1

    return nothing
end

##### Base Voltages at the Branch Ends #####
@inline function baseVoltageEnd(system::PowerSystem, baseVolt::BaseVoltage, from::Bool, idxBranch::Int64)
    if from
        return baseVolt.value[system.branch.layout.from[idxBranch]] * baseVolt.prefix
    else
        return baseVolt.value[system.branch.layout.to[idxBranch]] * baseVolt.prefix
    end
end

##### WLS AC State Estimation Objective Value #####
@inline function seobjective(analysis::AcStateEstimation, idx::Int64)
    se = analysis.method
    se.objective += se.residual[idx]^2 * se.precision[idx, idx]
end

@inline function seobjective(analysis::AcStateEstimation, idx1::Int64, idx2::Int64)
    se = analysis.method
    se.objective += se.residual[idx1]^2 * se.precision[idx1, idx1] +
        2 * se.residual[idx1] * se.residual[idx2] * se.precision[idx1, idx2]
end
