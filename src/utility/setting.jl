######### Polar Coordinate ##########
mutable struct Polar
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
end

######### Polar Angle Coordinate ##########
mutable struct PolarAngle
    angle::Array{Float64,1}
end

######### Cartesian Coordinate ##########
mutable struct Cartesian
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

######### Cartesian Real Coordinate ##########
mutable struct CartesianReal
    active::Array{Float64,1}
end

######### Cartesian Imaginary Coordinate ##########
mutable struct CartesianImag
    reactive::Array{Float64,1}
end

######### Bus ##########
mutable struct PowerBus
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
end

mutable struct CurrentBus
    injection::Polar
end

mutable struct DCPowerBus
    injection::CartesianReal
    supply::CartesianReal
end

######### Branch ##########
mutable struct PowerBranch
    from::Cartesian
    to::Cartesian
    shunt::CartesianImag
    loss::Cartesian
end

mutable struct CurrentBranch
    from::Polar
    to::Polar
    impedance::Polar
end

mutable struct DCPowerBranch
    from::CartesianReal
    to::CartesianReal
end

######### Generator ##########
mutable struct PowerGenerator
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct DCPowerGenerator
    active::Array{Float64,1}
end

######### Types ##########
const N = Union{Float64, Int64}
const T = Union{Float64, Int64, Missing}

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
