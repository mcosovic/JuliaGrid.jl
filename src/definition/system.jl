export PowerSystem, Measurement, Voltmeter, Ammeter, Wattmeter, Varmeter, PMU

########### Bus ###########
mutable struct BusDemand
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct BusShunt
    conductance::Array{Float64,1}
    susceptance::Array{Float64,1}
end

mutable struct BusVoltage
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
    minMagnitude::Array{Float64,1}
    maxMagnitude::Array{Float64,1}
end

mutable struct BusLayout
    type::Array{Int8,1}
    area::Array{Int64,1}
    lossZone::Array{Int64,1}
    slack::Int64
    label::Int64
end

mutable struct BusSupply
    active::Array{Float64,1}
    reactive::Array{Float64,1}
    generator::Array{Array{Int64,1},1}
end

mutable struct Bus
    label::OrderedDict{String, Int64}
    demand::BusDemand
    supply::BusSupply
    shunt::BusShunt
    voltage::BusVoltage
    layout::BusLayout
    number::Int64
end

########### Branch ###########
mutable struct BranchParameter
    resistance::Array{Float64,1}
    reactance::Array{Float64,1}
    conductance::Array{Float64,1}
    susceptance::Array{Float64,1}
    turnsRatio::Array{Float64,1}
    shiftAngle::Array{Float64,1}
end

mutable struct BranchFlow
    longTerm::Array{Float64,1}
    shortTerm::Array{Float64,1}
    emergency::Array{Float64,1}
    type::Array{Int8,1}
end

mutable struct BranchVoltage
    minDiffAngle::Array{Float64,1}
    maxDiffAngle::Array{Float64,1}
end

mutable struct BranchLayout
    from::Array{Int64,1}
    to::Array{Int64,1}
    status::Array{Int8,1}
    inservice::Int64
    label::Int64
end

mutable struct Branch
    label::OrderedDict{String, Int64}
    parameter::BranchParameter
    flow::BranchFlow
    voltage::BranchVoltage
    layout::BranchLayout
    number::Int64
end

########### Generator ###########
mutable struct GeneratorOutput
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct GeneratorCapability
    minActive::Array{Float64,1}
    maxActive::Array{Float64,1}
    minReactive::Array{Float64,1}
    maxReactive::Array{Float64,1}
    lowActive::Array{Float64,1}
    minLowReactive::Array{Float64,1}
    maxLowReactive::Array{Float64,1}
    upActive::Array{Float64,1}
    minUpReactive::Array{Float64,1}
    maxUpReactive::Array{Float64,1}
end

mutable struct GeneratorRamping
    loadFollowing::Array{Float64,1}
    reserve10min::Array{Float64,1}
    reserve30min::Array{Float64,1}
    reactiveTimescale::Array{Float64,1}
end

mutable struct Cost
    model::Array{Int8,1}
    polynomial::Array{Array{Float64,1},1}
    piecewise::Array{Array{Float64,2},1}
end

mutable struct GeneratorCost
    active::Cost
    reactive::Cost
end

mutable struct GeneratorVoltage
    magnitude::Array{Float64,1}
end

mutable struct GeneratorLayout
    bus::Array{Int64,1}
    area::Array{Float64,1}
    status::Array{Int8,1}
    inservice::Int64
    label::Int64
end

mutable struct Generator
    label::OrderedDict{String, Int64}
    output::GeneratorOutput
    capability::GeneratorCapability
    ramping::GeneratorRamping
    voltage::GeneratorVoltage
    cost::GeneratorCost
    layout::GeneratorLayout
    number::Int64
end

########### Base Data ###########
mutable struct BasePower
    value::Float64
    unit::String
    prefix::Float64
end

mutable struct BaseVoltage
    value::Array{Float64,1}
    unit::String
    prefix::Float64
end

mutable struct BaseData
    power::BasePower
    voltage::BaseVoltage
end

########### DC Model ###########
mutable struct DCModel
    nodalMatrix::SparseMatrixCSC{Float64,Int64}
    admittance::Array{Float64,1}
    shiftPower::Array{Float64,1}
    model::Int64
    pattern::Int64
end

########### AC Model ###########
mutable struct ACModel
    nodalMatrix::SparseMatrixCSC{ComplexF64,Int64}
    nodalMatrixTranspose::SparseMatrixCSC{ComplexF64,Int64}
    nodalFromFrom::Array{ComplexF64,1}
    nodalFromTo::Array{ComplexF64,1}
    nodalToTo::Array{ComplexF64,1}
    nodalToFrom::Array{ComplexF64,1}
    admittance::Array{ComplexF64,1}
    model::Int64
    pattern::Int64
end

########### Model ###########
mutable struct Model
    ac::ACModel
    dc::DCModel
end

########### Power System ###########
mutable struct PowerSystem
    bus::Bus
    branch::Branch
    generator::Generator
    base::BaseData
    model::Model
end

####### Measurement ##########
mutable struct GaussMeter
    mean::Array{Float64,1}
    variance::Array{Float64,1}
    status::Array{Int8,1}
end

mutable struct VoltmeterLayout
    index::Array{Int64,1}
    label::Int64
end

mutable struct AmmeterLayout
    index::Array{Int64,1}
    from::Array{Bool,1}
    to::Array{Bool,1}
    label::Int64
end

mutable struct PowermeterLayout
    index::Array{Int64,1}
    bus::Array{Bool,1}
    from::Array{Bool,1}
    to::Array{Bool,1}
    label::Int64
end

mutable struct PmuLayout
    index::Array{Int64,1}
    bus::Array{Bool,1}
    from::Array{Bool,1}
    to::Array{Bool,1}
    correlated::Array{Bool,1}
    polar::Array{Bool,1}
    label::Int64
end

mutable struct Voltmeter
    label::OrderedDict{String,Int64}
    magnitude::GaussMeter
    layout::VoltmeterLayout
    number::Int64
end

mutable struct Ammeter
    label::OrderedDict{String,Int64}
    magnitude::GaussMeter
    layout::AmmeterLayout
    number::Int64
end

mutable struct Wattmeter
    label::OrderedDict{String,Int64}
    active::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

mutable struct Varmeter
    label::OrderedDict{String,Int64}
    reactive::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

mutable struct PMU
    label::OrderedDict{String,Int64}
    magnitude::GaussMeter
    angle::GaussMeter
    layout::PmuLayout
    number::Int64
end

mutable struct Measurement
    voltmeter::Voltmeter
    ammeter::Ammeter
    wattmeter::Wattmeter
    varmeter::Varmeter
    pmu::PMU
end