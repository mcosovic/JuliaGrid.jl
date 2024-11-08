export PowerSystem, Bus, Branch, Generator, BasePower, Model
export Measurement, Voltmeter, Ammeter, Wattmeter, Varmeter, PMU

##### Bus #####
mutable struct BusDemand
    active::Vector{Float64}
    reactive::Vector{Float64}
end

mutable struct BusShunt
    conductance::Vector{Float64}
    susceptance::Vector{Float64}
end

mutable struct BusVoltage
    magnitude::Vector{Float64}
    angle::Vector{Float64}
    minMagnitude::Vector{Float64}
    maxMagnitude::Vector{Float64}
end

mutable struct BusLayout
    type::Vector{Int8}
    area::Vector{Int64}
    lossZone::Vector{Int64}
    slack::Int64
    label::Int64
end

mutable struct BusSupply
    active::Vector{Float64}
    reactive::Vector{Float64}
    generator::Dict{Int64, Vector{Int64}}
end

mutable struct Bus
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    demand::BusDemand
    supply::BusSupply
    shunt::BusShunt
    voltage::BusVoltage
    layout::BusLayout
    number::Int64
end

##### Branch #####
mutable struct BranchParameter
    resistance::Vector{Float64}
    reactance::Vector{Float64}
    conductance::Vector{Float64}
    susceptance::Vector{Float64}
    turnsRatio::Vector{Float64}
    shiftAngle::Vector{Float64}
end

mutable struct BranchFlow
    minFromBus::Vector{Float64}
    maxFromBus::Vector{Float64}
    minToBus::Vector{Float64}
    maxToBus::Vector{Float64}
    type::Vector{Int8}
end

mutable struct BranchVoltage
    minDiffAngle::Vector{Float64}
    maxDiffAngle::Vector{Float64}
end

mutable struct BranchLayout
    from::Vector{Int64}
    to::Vector{Int64}
    status::Vector{Int8}
    inservice::Int64
    label::Int64
end

mutable struct Branch
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    parameter::BranchParameter
    flow::BranchFlow
    voltage::BranchVoltage
    layout::BranchLayout
    number::Int64
end

##### Generator #####
mutable struct GeneratorOutput
    active::Vector{Float64}
    reactive::Vector{Float64}
end

mutable struct GeneratorCapability
    minActive::Vector{Float64}
    maxActive::Vector{Float64}
    minReactive::Vector{Float64}
    maxReactive::Vector{Float64}
    lowActive::Vector{Float64}
    minLowReactive::Vector{Float64}
    maxLowReactive::Vector{Float64}
    upActive::Vector{Float64}
    minUpReactive::Vector{Float64}
    maxUpReactive::Vector{Float64}
end

mutable struct GeneratorRamping
    loadFollowing::Vector{Float64}
    reserve10min::Vector{Float64}
    reserve30min::Vector{Float64}
    reactiveRamp::Vector{Float64}
end

mutable struct Cost
    model::Vector{Int8}
    polynomial::OrderedDict{Int64, Vector{Float64}}
    piecewise::OrderedDict{Int64, Matrix{Float64}}
end

mutable struct GeneratorCost
    active::Cost
    reactive::Cost
end

mutable struct GeneratorVoltage
    magnitude::Vector{Float64}
end

mutable struct GeneratorLayout
    bus::Vector{Int64}
    area::Vector{Float64}
    status::Vector{Int8}
    inservice::Int64
    label::Int64
end

mutable struct Generator
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    output::GeneratorOutput
    capability::GeneratorCapability
    ramping::GeneratorRamping
    voltage::GeneratorVoltage
    cost::GeneratorCost
    layout::GeneratorLayout
    number::Int64
end

##### Base Data #####
mutable struct BasePower
    value::Float64
    unit::String
    prefix::Float64
end

mutable struct BaseVoltage
    value::Vector{Float64}
    unit::String
    prefix::Float64
end

mutable struct BaseData
    power::BasePower
    voltage::BaseVoltage
end

##### DC Model #####
mutable struct DCModel
    nodalMatrix::SparseMatrixCSC{Float64, Int64}
    admittance::Vector{Float64}
    shiftPower::Vector{Float64}
    model::Int64
    pattern::Int64
end

##### AC Model #####
mutable struct ACModel
    nodalMatrix::SparseMatrixCSC{ComplexF64, Int64}
    nodalMatrixTranspose::SparseMatrixCSC{ComplexF64, Int64}
    nodalFromFrom::Vector{ComplexF64}
    nodalFromTo::Vector{ComplexF64}
    nodalToTo::Vector{ComplexF64}
    nodalToFrom::Vector{ComplexF64}
    admittance::Vector{ComplexF64}
    model::Int64
    pattern::Int64
end

##### Model #####
mutable struct Model
    ac::ACModel
    dc::DCModel
end

##### Power System #####
mutable struct PowerSystem
    bus::Bus
    branch::Branch
    generator::Generator
    base::BaseData
    model::Model
end

##### Measurement #####
mutable struct GaussMeter
    mean::Vector{Float64}
    variance::Vector{Float64}
    status::Vector{Int8}
end

mutable struct VoltmeterLayout
    index::Vector{Int64}
    label::Int64
end

mutable struct AmmeterLayout
    index::Vector{Int64}
    from::Vector{Bool}
    to::Vector{Bool}
    label::Int64
end

mutable struct PowermeterLayout
    index::Vector{Int64}
    bus::Vector{Bool}
    from::Vector{Bool}
    to::Vector{Bool}
    label::Int64
end

mutable struct PmuLayout
    index::Vector{Int64}
    bus::Vector{Bool}
    from::Vector{Bool}
    to::Vector{Bool}
    correlated::Vector{Bool}
    polar::Vector{Bool}
    label::Int64
end

mutable struct Voltmeter
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    magnitude::GaussMeter
    layout::VoltmeterLayout
    number::Int64
end

mutable struct Ammeter
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    magnitude::GaussMeter
    layout::AmmeterLayout
    number::Int64
end

mutable struct Wattmeter
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    active::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

mutable struct Varmeter
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    reactive::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

mutable struct PMU
    label::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
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

##### Types #####
const P = Union{Bus, Branch, Generator}
const M = Union{Voltmeter, Ammeter, Wattmeter, Varmeter, PMU}