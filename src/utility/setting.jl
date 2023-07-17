export ACAnalysis, DCAnalysis, OptimalPowerFlow

######### Polar Coordinate ##########
mutable struct Polar
    magnitude::Union{Array{Float64,1}, Float64}
    angle::Union{Array{Float64,1}, Float64}
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
    active::Union{Array{Float64,1}, Float64}
    reactive::Union{Array{Float64,1}, Float64}
end

mutable struct CartesianReal
    active::Union{Array{Float64,1}, Float64}
end

mutable struct CartesianImag
    reactive::Union{Array{Float64,1}, Float64}
end

mutable struct CartesianRef
    active::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1}}}
    reactive::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1}}}
end

mutable struct CartesianRealRef
    active::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1}}}
end

mutable struct CartesianImagRef
    reactive::Union{Array{JuMP.ConstraintRef,1}, Array{Array{JuMP.ConstraintRef,1}}}
end

######### Power ##########
mutable struct PowerBus
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
end

mutable struct PowerBranch
    from::Cartesian
    to::Cartesian
    shunt::CartesianImag
    loss::Cartesian
end

mutable struct PowerGenerator
    output::Cartesian
end

mutable struct Power
    bus::PowerBus
    branch::PowerBranch
    generator::PowerGenerator
end


######### Power ##########
mutable struct CurrentBus
    injection::Polar
end

mutable struct CurrentBranch
    from::Polar
    to::Polar
    line::Polar
end

mutable struct Current
    bus::CurrentBus
    branch::CurrentBranch
end

######### Branch ##########
mutable struct DCPowerBus
    injection::CartesianReal
    supply::CartesianReal
end

mutable struct DCPowerBranch
    from::CartesianReal
    to::CartesianReal
end

mutable struct DCPowerGenerator
    output::CartesianReal
end

mutable struct DCPower
    bus::DCPowerBus
    branch::DCPowerBranch
    generator::DCPowerGenerator
end


######### Types ##########
const N = Union{Float64, Int64}
const T = Union{Float64, Int64, Missing}

abstract type
    DCAnalysis
end
abstract type
    ACAnalysis
end
abstract type
    OptimalPowerFlow
end

######### Template ##########
const template = Dict(
    :bus => Dict(
        :type => 1,
        :active => 0.0,
        :reactive => 0.0,
        :conductance => 0.0,
        :susceptance => 0.0,
        :magnitude => 1.0,
        :angle => 0.0,
        :minMagnitude => 0.0,
        :maxMagnitude => 0.0,
        :base => 138e3,
        :area => 0,
        :lossZone => 0,
        :activePower => 0.0,
        :reactivePower => 0.0,
        :apparentPower => 0.0,
        :voltageMagnitude => 0.0,
        :voltageAngle => 1.0,
        :currentMagnitude => 0.0,
        :currentAngle => 1.0,
        :impedance => 0.0,
        :admittance => 0.0,
        :baseVoltage => 1.0
    ),
    :branch => Dict(
        :status => 1,
        :resistance => 0.0,
        :reactance => 0.0,
        :susceptance => 0.0,
        :turnsRatio => 0.0,
        :shiftAngle => 0.0,
        :minDiffAngle => 0.0,
        :maxDiffAngle => 0.0,
        :longTerm => 0.0,
        :shortTerm => 0.0,
        :emergency => 0.0,
        :type => 1,
        :activePower => 0.0,
        :reactivePower => 0.0,
        :apparentPower => 0.0,
        :voltageMagnitude => 0.0,
        :voltageAngle => 1.0,
        :currentMagnitude => 0.0,
        :currentAngle => 1.0,
        :impedance => 0.0,
        :admittance => 0.0,
        :baseVoltage => 1.0
    ),
    :generator => Dict(
        :status => 1,
        :active => 0.0,
        :reactive => 0.0,
        :magnitude => 1.0,
        :minActive => 0.0,
        :maxActive => 0.0,
        :minReactive => 0.0,
        :maxReactive => 0.0,
        :lowActive => 0.0,
        :minLowReactive => 0.0,
        :maxLowReactive => 0.0,
        :upActive => 0.0,
        :minUpReactive => 0.0,
        :maxUpReactive => 0.0,
        :loadFollowing => 0.0,
        :reactiveTimescale => 0.0,
        :reserve10min => 0.0,
        :reserve30min => 0.0,
        :area => 0,
        :activePower => 0.0,
        :reactivePower => 0.0,
        :apparentPower => 0.0,
        :voltageMagnitude => 0.0,
        :voltageAngle => 1.0,
        :currentMagnitude => 0.0,
        :currentAngle => 1.0,
        :impedance => 0.0,
        :admittance => 0.0,
        :baseVoltage => 1.0
    )
)