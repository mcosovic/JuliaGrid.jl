##### Types #####
const FltInt = Union{Float64, Int64}
const FltIntMiss = Union{Float64, Int64, Missing}
const BoolMiss = Union{Bool, Missing}
const IntMiss = Union{Int64, Missing}
const IntStr = Union{Int64, String}
const IntStrMiss = Union{Int64, String, Missing}

##### Polar Coordinate #####
mutable struct Polar
    magnitude::Vector{Float64}
    angle::Vector{Float64}
end

mutable struct PolarAngle
    angle::Vector{Float64}
end

mutable struct PolarRef
    magnitude::Dict{Int64, ConstraintRef}
    angle::Dict{Int64, ConstraintRef}
end

mutable struct PolarDual
    magnitude::Dict{Int64, Float64}
    angle::Dict{Int64, Float64}
end

mutable struct PolarAngleRef
    angle::Dict{Int64, ConstraintRef}
end

mutable struct PolarAngleDual
    angle::Dict{Int64, Float64}
end

##### Cartesian Coordinate #####
mutable struct Cartesian
    active::Vector{Float64}
    reactive::Vector{Float64}
end

mutable struct CartesianReal
    active::Vector{Float64}
end

mutable struct SimpleCartesianReal
    active::Float64
end

mutable struct CartesianImag
    reactive::Vector{Float64}
end

mutable struct CartesianRef
    active::Dict{Int64, ConstraintRef}
    reactive::Dict{Int64, ConstraintRef}
end

mutable struct CartesianDual
    active::Dict{Int64, Float64}
    reactive::Dict{Int64, Float64}
end

mutable struct CartesianRealDual
    active::Dict{Int64, Float64}
end

mutable struct CartesianRealRef
    active::Dict{Int64, ConstraintRef}
end

##### Sparse Matrix Model #####
mutable struct SparseModel
    row::Vector{Int64}
    col::Vector{Int64}
    val::Vector{Float64}
    cnt::Int64
    idx::Int64
end

##### Template #####
Base.@kwdef mutable struct ContainerTemplate
    value::Float64 = 0.0
    pu::Bool = true
end

Base.@kwdef mutable struct BusTemplate
    active::ContainerTemplate = ContainerTemplate()
    reactive::ContainerTemplate = ContainerTemplate()
    conductance::ContainerTemplate = ContainerTemplate()
    susceptance::ContainerTemplate = ContainerTemplate()
    magnitude::ContainerTemplate = ContainerTemplate(1.0, true)
    angle::ContainerTemplate = ContainerTemplate()
    minMagnitude::ContainerTemplate = ContainerTemplate(0.9, true)
    maxMagnitude::ContainerTemplate = ContainerTemplate(1.1, true)
    label::String = "?"
    base::Float64 = 138e3
    type::Int8 = Int8(1)
    area::Int64 = 0
    lossZone::Int64 = 0
end

Base.@kwdef mutable struct BranchTemplate
    resistance::ContainerTemplate = ContainerTemplate()
    reactance::ContainerTemplate = ContainerTemplate()
    conductance::ContainerTemplate = ContainerTemplate()
    susceptance::ContainerTemplate = ContainerTemplate()
    shiftAngle::ContainerTemplate = ContainerTemplate()
    minDiffAngle::ContainerTemplate = ContainerTemplate(-2*pi, true)
    maxDiffAngle::ContainerTemplate = ContainerTemplate(2*pi, true)
    minFromBus::ContainerTemplate = ContainerTemplate()
    maxFromBus::ContainerTemplate = ContainerTemplate()
    minToBus::ContainerTemplate = ContainerTemplate()
    maxToBus::ContainerTemplate = ContainerTemplate()
    label::String = "?"
    turnsRatio::Float64 = 1.0
    status::Int8 = Int8(1)
    type::Int8 = Int8(1)
end

Base.@kwdef mutable struct GeneratorTemplate
    active::ContainerTemplate = ContainerTemplate()
    reactive::ContainerTemplate = ContainerTemplate()
    magnitude::ContainerTemplate = ContainerTemplate(1.0, true)
    minActive::ContainerTemplate = ContainerTemplate()
    maxActive::ContainerTemplate = ContainerTemplate()
    minReactive::ContainerTemplate = ContainerTemplate()
    maxReactive::ContainerTemplate = ContainerTemplate()
    lowActive::ContainerTemplate = ContainerTemplate()
    minLowReactive::ContainerTemplate = ContainerTemplate()
    maxLowReactive::ContainerTemplate = ContainerTemplate()
    upActive::ContainerTemplate = ContainerTemplate()
    minUpReactive::ContainerTemplate = ContainerTemplate()
    maxUpReactive::ContainerTemplate = ContainerTemplate()
    loadFollowing::ContainerTemplate = ContainerTemplate()
    reactiveRamp::ContainerTemplate = ContainerTemplate()
    reserve10min::ContainerTemplate = ContainerTemplate()
    reserve30min::ContainerTemplate = ContainerTemplate()
    label::String = "?"
    status::Int8 = Int8(1)
    area::Int64 = 0
end

Base.@kwdef mutable struct VoltmeterTemplate
    variance::ContainerTemplate = ContainerTemplate(1e-2, true)
    status::Int8 = Int8(1)
    label::String = "?"
    noise::Bool = false
end

Base.@kwdef mutable struct AmmeterTemplate
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    label::String = "?"
    noise::Bool = false
end

Base.@kwdef mutable struct WattmeterTemplate
    varianceBus::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusBus::Int8 = Int8(1)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    label::String = "?"
    noise::Bool = false
end

Base.@kwdef mutable struct VarmeterTemplate
    varianceBus::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusBus::Int8 = Int8(1)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    label::String = "?"
    noise::Bool = false
end

Base.@kwdef mutable struct PmuTemplate
    varianceMagnitudeBus::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceAngleBus::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceMagnitudeFrom::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceAngleFrom::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceMagnitudeTo::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceAngleTo::ContainerTemplate = ContainerTemplate(1e-5, true)
    statusMagnitudeBus::Int8 = Int8(1)
    statusAngleBus::Int8 = Int8(1)
    statusMagnitudeFrom::Int8 = Int8(1)
    statusAngleFrom::Int8 = Int8(1)
    statusMagnitudeTo::Int8 = Int8(1)
    statusAngleTo::Int8 = Int8(1)
    label::String = "?"
    correlated::Bool = false
    polar::Bool = false
    noise::Bool = false
end

mutable struct Template
    bus::BusTemplate
    branch::BranchTemplate
    generator::GeneratorTemplate
    voltmeter::VoltmeterTemplate
    ammeter::AmmeterTemplate
    wattmeter::WattmeterTemplate
    varmeter::VarmeterTemplate
    pmu::PmuTemplate
end

template = Template(
    BusTemplate(),
    BranchTemplate(),
    GeneratorTemplate(),
    VoltmeterTemplate(),
    AmmeterTemplate(),
    WattmeterTemplate(),
    VarmeterTemplate(),
    PmuTemplate()
)

##### List of Prefixes #####
const prefixList = Dict(
    "q" => 1e-30,
    "r" => 1e-27,
    "y" => 1e-24,
    "z" => 1e-21,
    "a" => 1e-18,
    "f" => 1e-15,
    "p" => 1e-12,
    "n" => 1e-9,
    "μ" => 1e-6,
    "m" => 1e-3,
    "c" => 1e-2,
    "d" => 1e-1,
    "da" => 1e1,
    "h" => 1e2,
    "k" => 1e3,
    "M" => 1e6,
    "G" => 1e9,
    "T" => 1e12,
    "P" => 1e15,
    "E" => 1e18,
    "Z" => 1e21,
    "Y" => 1e24,
    "R" => 1e27,
    "Q" => 1e30
    )

##### List of Suffixes #####
Base.@kwdef mutable struct UnitList
    basePower::Vector{String}        = ["VA"]
    baseVoltage::Vector{String}      = ["V"]
    activePower::Vector{String}      = ["W", "pu"]
    reactivePower::Vector{String}    = ["VAr", "pu"]
    apparentPower::Vector{String}    = ["VA", "pu"]
    voltageMagnitude::Vector{String} = ["V", "pu"]
    voltageAngle::Vector{String}     = ["deg", "rad"]
    currentMagnitude::Vector{String} = ["A", "pu"]
    currentAngle::Vector{String}     = ["deg", "rad"]
    impedance::Vector{String}        = [string(:Ω), "pu"]
    admittance::Vector{String}       = ["S", "pu"]
    voltageMagnitudeLive::String     = "pu"
    voltageAngleLive::String         = "rad"
    activePowerLive::String          = "pu"
    reactivePowerLive::String        = "pu"
    apparentPowerLive::String        = "pu"
    currentMagnitudeLive::String     = "pu"
    currentAngleLive::String         = "rad"
end
unitList = UnitList()

##### Live Prefix Values #####
Base.@kwdef mutable struct PrefixLive
    activePower::Float64 = 0.0
    reactivePower::Float64 = 0.0
    apparentPower::Float64 = 0.0
    voltageMagnitude::Float64 = 0.0
    voltageAngle::Float64 = 0.0
    currentMagnitude::Float64 = 0.0
    currentAngle::Float64 = 0.0
    impedance::Float64 = 0.0
    admittance::Float64 = 0.0
    baseVoltage::Float64 = 1.0
end
pfx = PrefixLive()

##### Matrix Factorization Type #####
export LU, QR, LDLt

abstract type QR end
abstract type LU end
abstract type LDLt end

const factorized = Dict{DataType, Factorization{Float64}}()
factorized[LU] = lu(sparse(Matrix(1.0I, 1, 1)))
factorized[QR] = qr(sparse(Matrix(1.0I, 1, 1)))
factorized[LDLt] = ldlt(sparse(Matrix(1.0I, 1, 1)))