export PowerSystem
export NewtonRaphson, DCPowerFlow, DCOptimalPowerFlow, ACOptimalPowerFlow
export AC, DC, ACPowerFlow, OptimalPowerFlow

abstract type AC end
abstract type DC end
abstract type ACPowerFlow <: AC end
abstract type OptimalPowerFlow end

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

######### Powers in the AC Framework ##########
mutable struct Charging
    from::Cartesian
    to::Cartesian
end

mutable struct Power
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
    from::Cartesian
    to::Cartesian
    charging::Charging
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
        :conductance => 0.0,
        :susceptance => 0.0,
        :turnsRatio => 1.0,
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