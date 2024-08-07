export AC, DC
export ACPowerFlow, NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export ACOptimalPowerFlow, DCOptimalPowerFlow
export ACStateEstimation, NonlinearWLS, Normal, Orthogonal, LAV
export DCStateEstimation, LinearWLS
export PMUStateEstimation
export Factorization, LU, QR, LDLt
export Island, PlacementPMU

########### Abstract Types ###########
abstract type AC end
abstract type DC end

abstract type Factorization end
abstract type QR <: Factorization end
abstract type LU <: Factorization end
abstract type LDLt <: Factorization end

abstract type Orthogonal end
abstract type Normal end

########### Powers in the AC Framework ###########
mutable struct ACPower
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
mutable struct ACCurrent
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
mutable struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LUQR
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
    pattern::Int64
end

########### Fast Newton-Raphson ###########
mutable struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LUQR
end

mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
    acmodel::Int64
    pattern::Int64
    const bx::Bool
end

########### Gauss-Seidel ###########
struct GaussSeidel
    voltage::Array{ComplexF64,1}
    pq::Array{Int64,1}
    pv::Array{Int64,1}
end

########### AC Power Flow ###########
struct ACPowerFlow{T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

########### DC Power Flow ###########
mutable struct DCPowerFlowMethod
    factorization::LULDLtQR
    dcmodel::Int64
    pattern::Int64
end

struct DCPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    method::DCPowerFlowMethod
end

######### Constraints ##########
struct CartesianFlowRef
    from::Dict{Int64, ConstraintRef}
    to::Dict{Int64, ConstraintRef}
end

struct CartesianFlowDual
    from::Dict{Int64, Float64}
    to::Dict{Int64, Float64}
end

struct ACPiecewise
    active::Dict{Int64, Array{ConstraintRef,1}}
    reactive::Dict{Int64, Array{ConstraintRef,1}}
end

struct ACPiecewiseDual
    active::Dict{Int64, Array{Float64,1}}
    reactive::Dict{Int64, Array{Float64,1}}
end

struct CapabilityRef
    active::Dict{Int64, ConstraintRef}
    reactive::Dict{Int64, ConstraintRef}
    lower::Dict{Int64, ConstraintRef}
    upper::Dict{Int64, ConstraintRef}
end

struct CapabilityDual
    active::Dict{Int64, Float64}
    reactive::Dict{Int64, Float64}
    lower::Dict{Int64, Float64}
    upper::Dict{Int64, Float64}
end

struct Constraint
    slack::PolarAngleRef
    balance::CartesianRef
    voltage::PolarRef
    flow::CartesianFlowRef
    capability::CapabilityRef
    piecewise::ACPiecewise
end

struct Dual
    slack::PolarAngleDual
    balance::CartesianDual
    voltage::PolarDual
    flow::CartesianFlowDual
    capability::CapabilityDual
    piecewise::ACPiecewiseDual
end

######### AC Optimal Power Flow ##########
struct ACVariable
    active::Array{VariableRef,1}
    reactive::Array{VariableRef,1}
    magnitude::Array{VariableRef,1}
    angle::Array{VariableRef,1}
    actwise::Dict{Int64, VariableRef}
    reactwise::Dict{Int64, VariableRef}
end

struct ACNonlinear
    active::Dict{Int64, NonlinearExpr}
    reactive::Dict{Int64, NonlinearExpr}
end

mutable struct ACObjective
    quadratic::QuadExpr
    nonlinear::ACNonlinear
end

mutable struct ACOptimalPowerFlowMethod
    jump::JuMP.Model
    variable::ACVariable
    constraint::Constraint
    dual::Dual
    objective::ACObjective
end

mutable struct ACOptimalPowerFlow <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::ACOptimalPowerFlowMethod
end

######### DC Optimal Power Flow ##########
struct DCVariable
    active::Array{VariableRef,1}
    angle::Array{VariableRef,1}
    actwise::Dict{Int64, VariableRef}
end

struct DCPiecewise
    active::Dict{Int64, Array{ConstraintRef,1}}
end

struct DCPiecewiseDual
    active::Dict{Int64, Array{Float64,1}}
end

struct DCConstraint
    slack::PolarAngleRef
    balance::CartesianRealRef
    voltage::PolarAngleRef
    flow::CartesianRealRef
    capability::CartesianRealRef
    piecewise::DCPiecewise
end

struct DCDual
    slack::PolarAngleDual
    balance::CartesianRealDual
    voltage::PolarAngleDual
    flow::CartesianRealDual
    capability::CartesianRealDual
    piecewise::DCPiecewiseDual
end

mutable struct DCOptimalPowerFlowMethod
    jump::JuMP.Model
    variable::DCVariable
    constraint::DCConstraint
    dual::DCDual
    objective::QuadExpr
end

mutable struct DCOptimalPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    method::DCOptimalPowerFlowMethod
end

########### State Estimation ###########
mutable struct BadData
    detect::Bool
    maxNormalizedResidual::Float64
    label::String
    index::Int64
end

mutable struct LinearWLS{T <: Union{Normal, Orthogonal}}
    coefficient::SparseMatrixCSC{Float64,Int64}
    precision::SparseMatrixCSC{Float64,Int64}
    mean::Array{Float64,1}
    factorization::LULDLtQR
    number::Int64
    pattern::Int64
    run::Bool
end

mutable struct NonlinearWLS{T <: Union{Normal, Orthogonal}}
    jacobian::SparseMatrixCSC{Float64,Int64}
    precision::SparseMatrixCSC{Float64,Int64}
    mean::Array{Float64,1}
    residual::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LULDLtQR
    type::Array{Int8,1}
    index::Array{Int64,1}
    range::Array{Int64,1}
    pattern::Int64
end

mutable struct LAV
    jump::JuMP.Model
    statex::Array{VariableRef,1}
    statey::Array{VariableRef,1}
    residualx::Array{VariableRef,1}
    residualy::Array{VariableRef,1}
    residual::Dict{Int64, ConstraintRef}
    number::Int64
end

mutable struct TieData
    bus::Set{Int64}
    branch::Set{Int64}
    injection::Set{Int64}
end

mutable struct Island
    island::Array{Array{Int64,1},1}
    bus::Array{Int64,1}
    tie::TieData
end

########### DC State Estimation ###########
struct DCStateEstimation{T <: Union{LinearWLS{Normal}, LinearWLS{Orthogonal}, LAV}} <: DC
    voltage::PolarAngle
    power::DCPower
    method::T
end

########### PMU State Estimation ###########
struct PMUStateEstimation{T <: Union{LinearWLS{Normal}, LinearWLS{Orthogonal}, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

mutable struct PlacementPMU
    bus::OrderedDict{String,Int64}
    from::OrderedDict{String,Int64}
    to::OrderedDict{String,Int64}
end

########### AC State Estimation ###########
struct ACStateEstimation{T <: Union{NonlinearWLS{Normal}, NonlinearWLS{Orthogonal}, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end