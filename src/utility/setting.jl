export PowerSystem
export NewtonRaphson, DCPowerFlow, DCOptimalPowerFlow, ACOptimalPowerFlow
export AC, DC, ACPowerFlow, OptimalPowerFlow

abstract type AC end
abstract type DC end
abstract type ACPowerFlow <: AC end
abstract type OptimalPowerFlow end

######### Polar Coordinate ##########
mutable struct Polar
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
end

mutable struct PolarAngle
    angle::Array{Float64,1}
end

mutable struct PolarRef
    magnitude::Union{Array{JuMP.ConstraintRef,1}, JuMP.ConstraintRef}
    angle::Union{Array{JuMP.ConstraintRef,1}, JuMP.ConstraintRef}
end

mutable struct PolarAngleRef
    angle::Union{Array{JuMP.ConstraintRef,1}, JuMP.ConstraintRef}
end

######### Cartesian Coordinate ##########
mutable struct Cartesian
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct CartesianReal
    active::Array{Float64,1}
end

mutable struct CartesianImag
    reactive::Array{Float64,1}
end

mutable struct CartesianRef
    active::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1},1}}
    reactive::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1},1}}
end

mutable struct CartesianRealRef
    active::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1},1}}
end

mutable struct CartesianImagRef
    reactive::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1},1}}
end

######### Powers in the AC Framework ##########
mutable struct Power
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
    from::Cartesian
    to::Cartesian
    charging::Cartesian
    series::Cartesian
    generator::Cartesian
end

######### Currents in the AC Framework ##########
mutable struct Current
    injection::Polar
    from::Polar
    to::Polar
    series::Polar
end

######### Powers in the DC Framework ##########
mutable struct DCPower
    injection::CartesianReal
    supply::CartesianReal
    from::CartesianReal
    to::CartesianReal
    generator::CartesianReal
end

######### Types ##########
const N = Union{Float64, Int64}
const T = Union{Float64, Int64, Int8, Missing}
const L = Union{String, Int64, Missing}

######### Template ##########
Base.@kwdef mutable struct ContainerTemplate
    value::Float64 = 0.0
    pu::Bool = true
end

mutable struct BusTemplate
    active::ContainerTemplate
    reactive::ContainerTemplate
    conductance::ContainerTemplate
    susceptance::ContainerTemplate
    magnitude::ContainerTemplate
    minMagnitude::ContainerTemplate
    maxMagnitude::ContainerTemplate
    base::Float64
    angle::Float64
    type::Int8
    area::Int64
    lossZone::Int64
end

mutable struct BranchTemplate
    resistance::ContainerTemplate
    reactance::ContainerTemplate
    conductance::ContainerTemplate
    susceptance::ContainerTemplate
    longTerm::ContainerTemplate
    shortTerm::ContainerTemplate
    emergency::ContainerTemplate
    turnsRatio::Float64
    shiftAngle::Float64
    minDiffAngle::Float64
    maxDiffAngle::Float64
    status::Int8
    type::Int8
end

mutable struct GeneratorTemplate
    active::ContainerTemplate
    reactive::ContainerTemplate
    magnitude::ContainerTemplate
    minActive::ContainerTemplate
    maxActive::ContainerTemplate
    minReactive::ContainerTemplate
    maxReactive::ContainerTemplate
    lowActive::ContainerTemplate
    minLowReactive::ContainerTemplate
    maxLowReactive::ContainerTemplate
    upActive::ContainerTemplate
    minUpReactive::ContainerTemplate
    maxUpReactive::ContainerTemplate
    loadFollowing::ContainerTemplate
    reactiveTimescale::ContainerTemplate
    reserve10min::ContainerTemplate
    reserve30min::ContainerTemplate
    status::Int8
    area::Int64
end

mutable struct VoltmeterTemplate
    variance::ContainerTemplate
    status::Int8
end

mutable struct AmmeterTemplate
    variancefrom::ContainerTemplate
    varianceto::ContainerTemplate
    statusfrom::Int8
    statusto::Int8
end

mutable struct WattmeterTemplate
    variancebus::ContainerTemplate
    variancefrom::ContainerTemplate
    varianceto::ContainerTemplate
    statusbus::Int8
    statusfrom::Int8
    statusto::Int8
end

mutable struct VarmeterTemplate
    variancebus::ContainerTemplate
    variancefrom::ContainerTemplate
    varianceto::ContainerTemplate
    statusbus::Int8
    statusfrom::Int8
    statusto::Int8
end

mutable struct AnglepmuTemplate
    variancebus::Float64
    variancefrom::Float64
    varianceto::Float64
    statusbus::Int8
    statusfrom::Int8
    statusto::Int8
end

mutable struct MagnitudepmuTemplate
    variancebus::ContainerTemplate
    variancefrom::ContainerTemplate
    varianceto::ContainerTemplate
    statusbus::Int8
    statusfrom::Int8
    statusto::Int8
end

Base.@kwdef mutable struct Template
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
    BusTemplate(
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(1.0, true),
        ContainerTemplate(),
        ContainerTemplate(),
        138e3,
        0.0,
        Int8(1),
        0,
        0
    ),
    BranchTemplate(
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        1.0,
        0.0,
        0.0,
        0.0,
        Int8(1),
        Int8(1)
    ),
    GeneratorTemplate(
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(1.0, true),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        ContainerTemplate(),
        Int8(1),
        0
    ),
    VoltmeterTemplate(
        ContainerTemplate(1e-2, true),
        Int8(1)
    ),
    AmmeterTemplate(
        ContainerTemplate(1e-2, true),
        ContainerTemplate(1e-2, true),
        Int8(1),
        Int8(1)
    ),
    WattmeterTemplate(
        ContainerTemplate(1e-2, true),
        ContainerTemplate(1e-2, true),
        ContainerTemplate(1e-2, true),
        Int8(1),
        Int8(1),
        Int8(1)
    ),
    VarmeterTemplate(
        ContainerTemplate(1e-2, true),
        ContainerTemplate(1e-2, true),
        ContainerTemplate(1e-2, true),
        Int8(1),
        Int8(1),
        Int8(1)
    ),
    AnglepmuTemplate(
        1e-5,
        1e-5,
        1e-5,
        Int8(1),
        Int8(1),
        Int8(1)
    ),
    MagnitudepmuTemplate(
        ContainerTemplate(1e-5, true),
        ContainerTemplate(1e-5, true),
        ContainerTemplate(1e-5, true),
        Int8(1),
        Int8(1),
        Int8(1)
    )
)

setting = Dict{UInt128, Dict{String, Int64}}()
function setUUID()
    id = uuid4()
    setting[id.value] = Dict(
        "bus" => 0,
        "branch" => 0,
        "generator" => 0
    )

    return id
end





