export PolarAngleRefSimple, PolarAngleRef, CartesianRealRef

########### Types ###########
const N = Union{Float64, Int64}
const T = Union{Float64, Int64, Int8, Missing}
const L = Union{String, Int64, Missing}

########### Polar Coordinate ###########
mutable struct Polar
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
end

mutable struct PolarAngle
    angle::Array{Float64,1}
end

mutable struct PolarRef
    magnitude::Array{JuMP.ConstraintRef,1}
    angle::Array{JuMP.ConstraintRef,1}
end

mutable struct PolarRefSimple
    magnitude::JuMP.ConstraintRef
    angle::JuMP.ConstraintRef
end

mutable struct PolarAngleRef
    angle::Array{JuMP.ConstraintRef,1}
end

mutable struct PolarAngleRefSimple
    angle::JuMP.ConstraintRef
end

########### Cartesian Coordinate ###########
mutable struct Cartesian
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct CartesianReal
    active::Array{Float64,1}
end

mutable struct SimpleCartesianReal
    active::Float64
end

mutable struct CartesianImag
    reactive::Array{Float64,1}
end

mutable struct CartesianRef
    active::Array{JuMP.ConstraintRef,1}
    reactive::Array{JuMP.ConstraintRef,1}
end

mutable struct CartesianRefComplex
    active::Array{Array{JuMP.ConstraintRef,1},1}
    reactive::Array{Array{JuMP.ConstraintRef,1},1}
end

mutable struct CartesianRealRef
    active::Array{JuMP.ConstraintRef,1}
end

mutable struct CartesianRealRefComplex
    active::Array{Array{JuMP.ConstraintRef,1},1}
end

mutable struct CartesianImagRef
    reactive::Array{JuMP.ConstraintRef,1}
end

mutable struct CartesianImagRefComplex
    reactive::Array{Array{JuMP.ConstraintRef,1},1}
end

########### Template ###########
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
    minMagnitude::ContainerTemplate = ContainerTemplate()
    maxMagnitude::ContainerTemplate = ContainerTemplate()
    base::Float64 = 138e3
    angle::Float64 = 0.0
    type::Int8 = Int8(1)
    area::Int64 = 0
    lossZone::Int64 = 0
end

Base.@kwdef mutable struct BranchTemplate
    resistance::ContainerTemplate = ContainerTemplate()
    reactance::ContainerTemplate = ContainerTemplate()
    conductance::ContainerTemplate = ContainerTemplate()
    susceptance::ContainerTemplate = ContainerTemplate()
    longTerm::ContainerTemplate = ContainerTemplate()
    shortTerm::ContainerTemplate = ContainerTemplate()
    emergency::ContainerTemplate = ContainerTemplate()
    turnsRatio::Float64 = 1.0
    shiftAngle::Float64 = 0.0
    minDiffAngle::Float64 = 0.0
    maxDiffAngle::Float64 = 0.0
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
    reactiveTimescale::ContainerTemplate = ContainerTemplate()
    reserve10min::ContainerTemplate = ContainerTemplate()
    reserve30min::ContainerTemplate = ContainerTemplate()
    status::Int8 = Int8(1)
    area::Int64 = 0
end

Base.@kwdef mutable struct VoltmeterTemplate
    variance::ContainerTemplate = ContainerTemplate(1e-2, true)
    status::Int8 = Int8(1)
end

Base.@kwdef mutable struct AmmeterTemplate
    variancefrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceto::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusfrom::Int8 = Int8(1)
    statusto::Int8 = Int8(1)
end

Base.@kwdef mutable struct WattmeterTemplate
    variancebus::ContainerTemplate = ContainerTemplate(1e-2, true)
    variancefrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceto::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusbus::Int8 = Int8(1)
    statusfrom::Int8 = Int8(1)
    statusto::Int8 = Int8(1)
end

Base.@kwdef mutable struct VarmeterTemplate
    variancebus::ContainerTemplate = ContainerTemplate(1e-2, true)
    variancefrom::ContainerTemplate = ContainerTemplate(1e-2, true)
    varianceto::ContainerTemplate = ContainerTemplate(1e-2, true)
    statusbus::Int8 = Int8(1)
    statusfrom::Int8 = Int8(1)
    statusto::Int8 = Int8(1)
end

Base.@kwdef mutable struct AnglepmuTemplate
    variancebus::Float64 = 1e-5
    variancefrom::Float64 = 1e-5
    varianceto::Float64 = 1e-5
    statusbus::Int8 = Int8(1)
    statusfrom::Int8 = Int8(1)
    statusto::Int8 = Int8(1)
end

Base.@kwdef mutable struct MagnitudepmuTemplate
    variancebus::ContainerTemplate = ContainerTemplate(1e-5, true)
    variancefrom::ContainerTemplate = ContainerTemplate(1e-5, true)
    varianceto::ContainerTemplate = ContainerTemplate(1e-5, true)
    statusbus::Int8 = Int8(1)
    statusfrom::Int8 = Int8(1)
    statusto::Int8 = Int8(1)
end

mutable struct Template
    bus::BusTemplate
    branch::BranchTemplate
    generator::GeneratorTemplate
    voltmeter::VoltmeterTemplate
    ammeter::AmmeterTemplate
    wattmeter::WattmeterTemplate
    varmeter::VarmeterTemplate
    anglepmu::AnglepmuTemplate
    magnitudepmu::MagnitudepmuTemplate
end

template = Template(
    BusTemplate(),
    BranchTemplate(),
    GeneratorTemplate(),
    VoltmeterTemplate(),
    AmmeterTemplate(),
    WattmeterTemplate(),
    VarmeterTemplate(),
    AnglepmuTemplate(),
    MagnitudepmuTemplate()
)

########### List of Prefixes ###########
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

########### List of Suffixes ###########
Base.@kwdef struct SuffixList
    basePower::Array{String,1} = ["VA"]
    baseVoltage::Array{String,1} = ["V"]
    activePower::Array{String,1} = ["W", "pu"]
    reactivePower::Array{String,1} = ["VAr", "pu"]
    apparentPower::Array{String,1} = ["VA", "pu"]
    voltageMagnitude::Array{String,1} = ["V", "pu"]
    voltageAngle::Array{String,1} = ["deg", "rad"]
    currentMagnitude::Array{String,1} = ["A", "pu"]
    currentAngle::Array{String,1} = ["deg", "rad"]
    impedance::Array{String,1} = [string(:Ω), "pu"]
    admittance::Array{String,1} = ["S", "pu"]
end
suffixList = SuffixList()

########### Live Prefix Values ###########
Base.@kwdef mutable struct PrefixLive
    activePower::Float64 = 0.0
    reactivePower::Float64 = 0.0
    apparentPower::Float64 = 0.0
    voltageMagnitude::Float64 = 0.0
    voltageAngle::Float64 = 1.0
    currentMagnitude::Float64 = 0.0
    currentAngle::Float64 = 1.0
    impedance::Float64 = 0.0
    admittance::Float64 = 0.0
    baseVoltage::Float64 = 1.0
end
prefix = PrefixLive()

########### Live Power System Data ###########
systemList = Dict{UInt128, Dict{String, Int64}}()