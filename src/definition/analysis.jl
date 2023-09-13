export AC, DC, ACPowerFlow, OptimalPowerFlow
export NewtonRaphson, DCPowerFlow, DCOptimalPowerFlow, ACOptimalPowerFlow

########### Abstract Types ###########
abstract type AC end
abstract type DC end
abstract type ACPowerFlow <: AC end
abstract type OptimalPowerFlow end

########### Powers in the AC Framework ###########
mutable struct Power
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
    from::Cartesian
    to::Cartesian
    series::Cartesian
    charging::Cartesian
    generator::Cartesian
end

########### Currents in the AC Framework ###########
mutable struct Current
    injection::Polar
    from::Polar
    to::Polar
    series::Polar
end

########### Powers in the DC Framework ###########
mutable struct DCPower
    injection::CartesianReal
    supply::CartesianReal
    from::CartesianReal
    to::CartesianReal
    generator::CartesianReal
end

########### Newton-Raphson ###########
struct NewtonRaphsonMethod
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

struct NewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::NewtonRaphsonMethod
    uuid::UUID
end

########### Fast Newton-Raphson ###########
struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64}
end

struct FastNewtonRaphsonMethod
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
end

struct FastNewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::FastNewtonRaphsonMethod
    uuid::UUID
end

########### Gauss-Seidel ###########
struct GaussSeidelMethod
    voltage::Array{ComplexF64,1}
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

struct GaussSeidel <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::GaussSeidelMethod
    uuid::UUID
end

########### DC Power Flow ###########
struct DCPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    factorization::SuiteSparse.CHOLMOD.Factor{Float64}
    uuid::UUID
end

######### Constraints ##########
struct CartesianFlowRef
    from::Array{JuMP.ConstraintRef,1}
    to::Array{JuMP.ConstraintRef,1}
end

struct ConstraintAC
    slack::Union{PolarRef, PolarAngleRef}
    balance::CartesianRef
    limit::PolarRef
    rating::CartesianRef
    capability::CartesianRef
    piecewise::CartesianRef
end

struct DCPiecewise
    active::Dict{Int64, Array{JuMP.ConstraintRef,1}}
    helper::Dict{Int64, VariableRef}
end

struct DCConstraint
    slack::PolarAngleRefSimple
    balance::CartesianRealRef
    voltage::PolarAngleRef
    flow::CartesianRealRef
    capability::CartesianRealRef
    piecewise::DCPiecewise
end

######### AC Optimal Power Flow ##########
struct ACOptimalPowerFlow <: AC
    voltage::Polar
    power::Power
    current::Current
    jump::JuMP.Model
    constraint::ConstraintAC
end

######### DC Optimal Power Flow ##########
struct DCOptimalPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    jump::JuMP.Model
    constraint::DCConstraint
    uuid::UUID
end