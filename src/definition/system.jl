export PowerSystem, Bus, Branch, Generator, BasePower, BaseData, Model
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

"""
    Bus

A composite type used in [`PowerSystem`](@ref PowerSystem) to store bus-related data.

# Fields
- `label::LabelDict`: Bus labels.
- `demand::BusDemand`: Active and reactive power demands.
- `supply::BusSupply`: Active and reactive power supplies from generators.
- `shunt::BusShunt`: Active and reactive power injections or demands from shunt elements.
- `voltage::BusVoltage`: Initial voltages and voltage magnitude constraints.
- `layout::BusLayout`: Bus layout, including bus types.
- `number::Int64`: Total number of buses.
"""
mutable struct Bus
    label::LabelDict
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

"""
    Branch

A composite type used in [`PowerSystem`](@ref PowerSystem) to store branch-related data.

# Fields
- `label::LabelDict`: Branch labels.
- `parameter::BranchParameter`: Data related to the π-model of the branches.
- `flow::BranchFlow`: Branch flow constraints.
- `voltage::BranchVoltage`: Voltage angle difference constraints.
- `layout::BranchLayout`: Branch layout, including operational statuses.
- `number::Int64`: Total number of branches.
"""
mutable struct Branch
    label::LabelDict
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

"""
    Generator

A composite type used in [`PowerSystem`](@ref PowerSystem) to store generator-related data.

# Fields
- `label::LabelDict`: Generator labels.
- `output::GeneratorOutput`: Active and reactive power outputs.
- `capability::GeneratorCapability`: Power output constraints.
- `ramping::GeneratorRamping`: Ramp rate limits.
- `voltage::GeneratorVoltage`: Voltage magnitude setpoints.
- `cost::GeneratorCost`: Costs associated with active and reactive power outputs.
- `layout::GeneratorLayout`: Generator layout, including operational statuses.
- `number::Int64`: Total number of generators.
"""
mutable struct Generator
    label::LabelDict
    output::GeneratorOutput
    capability::GeneratorCapability
    ramping::GeneratorRamping
    voltage::GeneratorVoltage
    cost::GeneratorCost
    layout::GeneratorLayout
    number::Int64
end

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

"""
    BaseData

A composite type used in [`PowerSystem`](@ref PowerSystem) to store base data.

# Fields
- `power::BasePower`: Base power.
- `voltage::BaseVoltage`: Base voltages.
"""
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

"""
    Model

A composite type used in [`PowerSystem`](@ref PowerSystem) to store vectors and matrices
related to the power system's topology and parameters.

# Fields
- `ac::ACModel`: AC model, including the nodal admittance matrix and Y-parameters of two-port branches.
- `dc::DCModel`: DC model, including the nodal admittance matrix and branch admittances.
"""
mutable struct Model
    ac::ACModel
    dc::DCModel
end

"""
    PowerSystem

A composite type constructed using the [`powerSystem`](@ref powerSystem) function to store
power system data.

# Fields
- `bus::Bus`: Bus-related data.
- `branch::Branch`: Branch-related data.
- `generator::Generator`: Generator-related data.
- `base::BaseData`: Base power and base voltages.
- `model::Model`: Data related to AC and DC analyses.
"""
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

"""
    Voltmeter

A composite type used in [`Measurement`](@ref Measurement) to store voltmeter-related data.

# Fields
- `label::LabelDict`: Voltmeter labels.
- `magnitude::GaussMeter`: Bus voltage magnitude measurements.
- `layout::VoltmeterLayout`: Placement indices and indicators.
- `number::Int64`: Total number of voltmeters.
"""
mutable struct Voltmeter
    label::LabelDict
    magnitude::GaussMeter
    layout::VoltmeterLayout
    number::Int64
end

"""
    Ammeter

A composite type used in [`Measurement`](@ref Measurement) to store ammeter-related data.

# Fields
- `label::LabelDict`: Ammeter labels.
- `magnitude::GaussMeter`: Branch current magnitude measurements.
- `layout::AmmeterLayout`: Placement indices and indicators.
- `number::Int64`: Total number of ammeters.
"""
mutable struct Ammeter
    label::LabelDict
    magnitude::GaussMeter
    layout::AmmeterLayout
    number::Int64
end

"""
    Wattmeter

A composite type used in [`Measurement`](@ref Measurement) to store wattmeter-related data.

# Fields
- `label::LabelDict`: Wattmeter labels.
- `active::GaussMeter`: Active power injection and active power flow measurements.
- `layout::PowermeterLayout`: Placement indices and indicators.
- `number::Int64`: Total number of wattmeters.
"""
mutable struct Wattmeter
    label::LabelDict
    active::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

"""
    Varmeter

A composite type used in [`Measurement`](@ref Measurement) to store varmeter-related data.

# Fields
- `label::LabelDict`: Varmeter labels.
- `reactive::GaussMeter`: Reactive power injection and reactive power flow measurements.
- `layout::PowermeterLayout`: Placement indices and indicators.
- `number::Int64`: Total number of varmeters.
"""
mutable struct Varmeter
    label::LabelDict
    reactive::GaussMeter
    layout::PowermeterLayout
    number::Int64
end

"""
    PMU

A composite type used in [`Measurement`](@ref Measurement) to store PMU-related data.

# Fields
- `label::LabelDict`: PMU labels.
- `magnitude::GaussMeter`: Bus voltage and branch current magnitude measurements.
- `angle::GaussMeter`: Bus voltage and branch current angle measurements.
- `layout::PmuLayout`: Placement indices and indicators.
- `number::Int64`: Total number of PMUs.
"""
mutable struct PMU
    label::LabelDict
    magnitude::GaussMeter
    angle::GaussMeter
    layout::PmuLayout
    number::Int64
end

"""
    Measurement

A composite type built using the [`measurement`](@ref measurement) function to store
measurement data.

# Fields
- `voltmeter::Voltmeter`: Data related to bus voltage magnitude measurements.
- `ammeter::Ammeter`: Data related to branch current magnitude measurements.
- `wattmeter::Wattmeter`: Data related to active power injection and active power flow measurements.
- `varmeter::Varmeter`: Data related to reactive power injection and reactive power flow measurements.
- `pmu::PMU`: Data related to bus voltage and branch current phasor measurements.
"""
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