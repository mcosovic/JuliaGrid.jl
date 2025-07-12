##### Aliases #####
const FltInt = Union{Float64, Int64}
const FltIntMiss = Union{Float64, Int64, Missing}
const BoolMiss = Union{Bool, Missing}
const IntMiss = Union{Int64, Missing}
const IntStr = Union{Int64, String}
const IntStrMiss = Union{Int64, String, Missing}
const LabelDict = Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
const Signature = Dict{Symbol, Union{Int64, Dict{Int64, Float64}}}
const ConDict = OrderedDict{Int64, Dict{Symbol, ConstraintRef}}
const DualDict = OrderedDict{Int64, Dict{Symbol, Float64}}
const DualDictVec = OrderedDict{Int64, Dict{Symbol, Vector{Float64}}}
const ConDictVec = OrderedDict{Int64, Dict{Symbol, Vector{ConstraintRef}}}
const FactorSparse = Union{
    UMFPACK.UmfpackLU{Float64, Int64},
    SPQR.QRSparse{Float64, Int64},
    CHOLMOD.Factor{Float64},
    KLUFactorization{Float64, Int64}
}

##### Polar Coordinate #####
mutable struct Polar
    magnitude::Vector{Float64}
    angle::Vector{Float64}
end

mutable struct PolarVariableRef
    magnitude::Vector{VariableRef}
    angle::Vector{VariableRef}
end

mutable struct PolarConstraintRef
    magnitude::ConDict
    angle::ConDict
end

mutable struct PolarDual
    magnitude::DualDict
    angle::DualDict
end

mutable struct Angle
    angle::Vector{Float64}
end

mutable struct AngleVariableRef
    angle::Vector{VariableRef}
end

mutable struct AngleConstraintRef
    angle::ConDict
end

mutable struct AngleDual
    angle::DualDict
end

##### Cartesian Coordinate #####
mutable struct Cartesian
    active::Vector{Float64}
    reactive::Vector{Float64}
end

mutable struct CartesianVariableRef
    active::Vector{VariableRef}
    reactive::Vector{VariableRef}
    actwise::Dict{Int64, VariableRef}
    reactwise::Dict{Int64, VariableRef}
end

mutable struct CartesianConstraintRef
    active::ConDict
    reactive::ConDict
end

mutable struct CartesianDual
    active::DualDict
    reactive::DualDict
end

mutable struct Real
    active::Vector{Float64}
end

mutable struct RealVariableRef
    active::Vector{VariableRef}
    actwise::Dict{Int64, VariableRef}
end

mutable struct RealConstraintRef
    active::ConDict
end

mutable struct RealDual
    active::DualDict
end

mutable struct RectangularVariableRef
    real::Vector{VariableRef}
    imag::Vector{VariableRef}
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
    base::Float64 = 138e3
    type::Int8 = Int8(1)
    area::Int64 = 0
    lossZone::Int64 = 0
    label::String = "?"
    key::DataType = String
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
    turnsRatio::Float64 = 1.0
    status::Int8 = Int8(1)
    type::Int8 = Int8(3)
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct GeneratorTemplate
    active::ContainerTemplate = ContainerTemplate()
    reactive::ContainerTemplate = ContainerTemplate()
    magnitude::ContainerTemplate = ContainerTemplate(1.0, true)
    minActive::ContainerTemplate = ContainerTemplate()
    maxActive::ContainerTemplate = ContainerTemplate(NaN, true)
    minReactive::ContainerTemplate = ContainerTemplate(NaN, true)
    maxReactive::ContainerTemplate = ContainerTemplate(NaN, true)
    lowActive::ContainerTemplate = ContainerTemplate()
    minLowReactive::ContainerTemplate = ContainerTemplate()
    maxLowReactive::ContainerTemplate = ContainerTemplate()
    upActive::ContainerTemplate = ContainerTemplate()
    minUpReactive::ContainerTemplate = ContainerTemplate()
    maxUpReactive::ContainerTemplate = ContainerTemplate()
    status::Int8 = Int8(1)
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct VoltmeterTemplate
    variance::ContainerTemplate = ContainerTemplate(1e-4, true)
    status::Int8 = Int8(1)
    noise::Bool = false
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct AmmeterTemplate
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-4, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-4, true)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    square::Bool = false
    noise::Bool = false
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct WattmeterTemplate
    varianceBus::ContainerTemplate = ContainerTemplate(1e-4, true)
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-4, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-4, true)
    statusBus::Int8 = Int8(1)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    noise::Bool = false
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct VarmeterTemplate
    varianceBus::ContainerTemplate = ContainerTemplate(1e-4, true)
    varianceFrom::ContainerTemplate = ContainerTemplate(1e-4, true)
    varianceTo::ContainerTemplate = ContainerTemplate(1e-4, true)
    statusBus::Int8 = Int8(1)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    noise::Bool = false
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct PmuTemplate
    varianceMagnitudeBus::ContainerTemplate = ContainerTemplate(1e-8, true)
    varianceAngleBus::ContainerTemplate = ContainerTemplate(1e-8, true)
    varianceMagnitudeFrom::ContainerTemplate = ContainerTemplate(1e-8, true)
    varianceAngleFrom::ContainerTemplate = ContainerTemplate(1e-8, true)
    varianceMagnitudeTo::ContainerTemplate = ContainerTemplate(1e-8, true)
    varianceAngleTo::ContainerTemplate = ContainerTemplate(1e-8, true)
    statusBus::Int8 = Int8(1)
    statusFrom::Int8 = Int8(1)
    statusTo::Int8 = Int8(1)
    correlated::Bool = false
    polar::Bool = false
    square::Bool = false
    noise::Bool = false
    label::String = "?"
    key::DataType = String
end

Base.@kwdef mutable struct ConfigTemplate
    verbose::Int64 = 0
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
    config::ConfigTemplate
end

const template = Template(
    BusTemplate(),
    BranchTemplate(),
    GeneratorTemplate(),
    VoltmeterTemplate(),
    AmmeterTemplate(),
    WattmeterTemplate(),
    VarmeterTemplate(),
    PmuTemplate(),
    ConfigTemplate()
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
    voltageBaseLive::String          = "V"
    impedanceLive::String            = "pu"
    admittanceLive::String           = "pu"
end
const unitList = UnitList()

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
const pfx = PrefixLive()

Base.@kwdef struct BusKey
    label::IntStrMiss = missing
    type::IntMiss = missing
    active::FltIntMiss = missing
    reactive::FltIntMiss = missing
    conductance::FltIntMiss = missing
    susceptance::FltIntMiss = missing
    magnitude::FltIntMiss = missing
    angle::FltIntMiss = missing
    minMagnitude::FltIntMiss = missing
    maxMagnitude::FltIntMiss = missing
    base::FltIntMiss = missing
    area::IntMiss = missing
    lossZone::FltIntMiss = missing
end

Base.@kwdef struct BranchKey
    label::IntStrMiss = missing
    status::IntMiss = missing
    resistance::FltIntMiss = missing
    reactance::FltIntMiss = missing
    susceptance::FltIntMiss = missing
    conductance::FltIntMiss = missing
    turnsRatio::FltIntMiss = missing
    shiftAngle::FltIntMiss = missing
    minDiffAngle::FltIntMiss = missing
    maxDiffAngle::FltIntMiss = missing
    minFromBus::FltIntMiss = missing
    maxFromBus::FltIntMiss = missing
    minToBus::FltIntMiss = missing
    maxToBus::FltIntMiss = missing
    type::IntMiss = missing
end

Base.@kwdef struct GeneratorKey
    label::IntStrMiss = missing
    status::IntMiss = missing
    active::FltIntMiss = missing
    reactive::FltIntMiss = missing
    magnitude::FltIntMiss = missing
    minActive::FltIntMiss = missing
    maxActive::FltIntMiss = missing
    minReactive::FltIntMiss = missing
    maxReactive::FltIntMiss = missing
    lowActive::FltIntMiss = missing
    minLowReactive::FltIntMiss = missing
    maxLowReactive::FltIntMiss = missing
    upActive::FltIntMiss = missing
    minUpReactive::FltIntMiss = missing
    maxUpReactive::FltIntMiss = missing
end

Base.@kwdef struct CostKey
    active::FltIntMiss = missing
    reactive::FltIntMiss = missing
    polynomial::Vector{Float64} = Float64[]
    piecewise::Matrix{Float64} = Array{Float64}(undef, 0, 0)
end

Base.@kwdef struct VoltmeterKey
    label::IntStrMiss = missing
    magnitude::FltIntMiss = missing
    variance::FltIntMiss = missing
    status::IntMiss = missing
    noise::Bool = template.voltmeter.noise
end

Base.@kwdef struct AmmeterKey
    label::IntStrMiss = missing
    from::IntStrMiss = missing
    to::IntStrMiss = missing
    magnitude::FltIntMiss = missing
    variance::FltIntMiss = missing
    varianceFrom::FltIntMiss = missing
    varianceTo::FltIntMiss = missing
    status::IntMiss = missing
    statusFrom::FltIntMiss = missing
    statusTo::FltIntMiss = missing
    square::BoolMiss = missing
    noise::Bool = template.ammeter.noise
end

Base.@kwdef struct WattmeterKey
    label::IntStrMiss = missing
    bus::IntStrMiss = missing
    from::IntStrMiss = missing
    to::IntStrMiss = missing
    active::FltIntMiss = missing
    variance::FltIntMiss = missing
    varianceBus::FltIntMiss = missing
    varianceFrom::FltIntMiss = missing
    varianceTo::FltIntMiss = missing
    status::IntMiss = missing
    statusBus::FltIntMiss = missing
    statusFrom::FltIntMiss = missing
    statusTo::FltIntMiss = missing
    noise::Bool = template.wattmeter.noise
end

Base.@kwdef struct VarmeterKey
    label::IntStrMiss = missing
    bus::IntStrMiss = missing
    from::IntStrMiss = missing
    to::IntStrMiss = missing
    reactive::FltIntMiss = missing
    variance::FltIntMiss = missing
    varianceBus::FltIntMiss = missing
    varianceFrom::FltIntMiss = missing
    varianceTo::FltIntMiss = missing
    status::IntMiss = missing
    statusBus::FltIntMiss = missing
    statusFrom::FltIntMiss = missing
    statusTo::FltIntMiss = missing
    noise::Bool = template.varmeter.noise
end

Base.@kwdef struct PmuKey
    label::IntStrMiss = missing
    bus::IntStrMiss = missing
    from::IntStrMiss = missing
    to::IntStrMiss = missing
    magnitude::FltIntMiss = missing
    varianceMagnitude::FltIntMiss = missing
    varianceMagnitudeBus::FltIntMiss = missing
    varianceMagnitudeFrom::FltIntMiss = missing
    varianceMagnitudeTo::FltIntMiss = missing
    angle::FltIntMiss = missing
    varianceAngle::FltIntMiss = missing
    varianceAngleBus::FltIntMiss = missing
    varianceAngleFrom::FltIntMiss = missing
    varianceAngleTo::FltIntMiss = missing
    status::FltIntMiss = missing
    statusBus::FltIntMiss = missing
    statusFrom::FltIntMiss = missing
    statusTo::FltIntMiss = missing
    correlated::BoolMiss = missing
    polar::BoolMiss = missing
    square::BoolMiss = missing
    noise::Bool = template.pmu.noise
end