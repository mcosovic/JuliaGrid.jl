export PowerSystem

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
end

mutable struct BusSupply
    active::Array{Float64,1}
    reactive::Array{Float64,1}
    generator::Array{Array{Int64,1},1}
end

mutable struct Bus
    label::Dict{String,Int64}
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

mutable struct BranchRating
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
end

mutable struct Branch
    label::Dict{String,Int64}
    parameter::BranchParameter
    rating::BranchRating
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
end

mutable struct Generator
    label::Dict{String,Int64}
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
    shiftActivePower::Array{Float64,1}
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
    const uuid::UUID
end