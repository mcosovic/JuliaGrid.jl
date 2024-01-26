export AC, DC, ACPowerFlow, OptimalPowerFlow
export NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export DCOptimalPowerFlow, ACOptimalPowerFlow
export DCStateEstimation, DCStateEstimationWLS, DCStateEstimationLAV
export LU, QR, LDLt, Factorization
export Island, IslandWatt, IslandVar

########### Abstract Types ###########
abstract type AC end
abstract type DC end
abstract type ACPowerFlow <: AC end
abstract type OptimalPowerFlow end
abstract type Factorization end
abstract type QR <: Factorization end
abstract type LU <: Factorization end
abstract type LDLt <: Factorization end
abstract type DCStateEstimation <: DC end
abstract type Island end

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

########### Powers in the DC SE Framework ###########
mutable struct DCPowerSE
    injection::CartesianReal
    supply::CartesianReal
    from::CartesianReal
    to::CartesianReal
end

########### Newton-Raphson ###########
mutable struct NewtonRaphsonMethod
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LUQR
    pq::Array{Int64,1}
    pvpq::Array{Int64,1} 
end

struct NewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::NewtonRaphsonMethod
end

########### Fast Newton-Raphson ###########
mutable struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LUQR
end

mutable struct FastNewtonRaphsonMethod
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Array{Int64,1}
    pvpq::Array{Int64,1}
    done::Bool
    const bx::Bool
end

struct FastNewtonRaphson <: ACPowerFlow
    voltage::Polar
    power::Power
    current::Current
    method::FastNewtonRaphsonMethod
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
end

########### DC Power Flow ###########
mutable struct DCPowerFlowMethod
    factorization::LULDLtQR
    done::Bool
end

struct DCPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    method::DCPowerFlowMethod
end

######### Constraints ##########
struct CartesianFlowRef
    from::Dict{Int64, JuMP.ConstraintRef}
    to::Dict{Int64, JuMP.ConstraintRef}
end

struct ACPiecewise
    active::Dict{Int64, Array{JuMP.ConstraintRef,1}}
    reactive::Dict{Int64, Array{JuMP.ConstraintRef,1}}
end

struct CapabilityRef
    active::Dict{Int64, JuMP.ConstraintRef}
    reactive::Dict{Int64, JuMP.ConstraintRef}
    lower::Dict{Int64, JuMP.ConstraintRef}
    upper::Dict{Int64, JuMP.ConstraintRef}
end

struct Constraint
    slack::PolarAngleRef
    balance::CartesianRef
    voltage::PolarRef
    flow::CartesianFlowRef
    capability::CapabilityRef
    piecewise::ACPiecewise
end

######### AC Optimal Power Flow ##########
struct ACVariable
    active::Array{JuMP.VariableRef,1}
    reactive::Array{JuMP.VariableRef,1}
    magnitude::Array{JuMP.VariableRef,1}
    angle::Array{JuMP.VariableRef,1}
    actwise::Dict{Int64, VariableRef}
    reactwise::Dict{Int64, VariableRef}
end

struct ACNonlinear
    active::Dict{Int64, JuMP.NonlinearExpr}
    reactive::Dict{Int64, JuMP.NonlinearExpr}
end

mutable struct ACObjective
    quadratic::JuMP.QuadExpr
    nonlinear::ACNonlinear
end

mutable struct ACOptimalPowerFlow <: AC
    voltage::Polar
    power::Power
    current::Current
    jump::JuMP.Model
    variable::ACVariable
    constraint::Constraint
    objective::ACObjective
end

######### DC Optimal Power Flow ##########
struct DCVariable
    active::Array{JuMP.VariableRef,1}
    angle::Array{JuMP.VariableRef,1}
    actwise::Dict{Int64, VariableRef}
end

struct DCPiecewise
    active::Dict{Int64, Array{JuMP.ConstraintRef,1}}
end

struct DCConstraint
    slack::PolarAngleRef
    balance::CartesianRealRef
    voltage::PolarAngleRef
    flow::CartesianRealRef
    capability::CartesianRealRef
    piecewise::DCPiecewise
end

mutable struct DCOptimalPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    jump::JuMP.Model
    variable::DCVariable
    constraint::DCConstraint
    objective::JuMP.QuadExpr
end

########### DC State Estimation ###########
mutable struct BadData
    detect::Bool
    maxNormalizedResidual::Float64
    index::Int64
    label::String
end

mutable struct DCStateEstimationWLSMethod
    jacobian::SparseMatrixCSC{Float64,Int64}
    weight::Array{Float64,1}
    mean::Array{Float64,1}
    factorization::LULDLtQR
    number::Int64
    done::Bool
end

struct DCStateEstimationWLS <: DCStateEstimation
    voltage::PolarAngle
    power::DCPowerSE
    method::DCStateEstimationWLSMethod
    bad::BadData
end

struct VariableLAV
    anglex::Array{JuMP.VariableRef,1}
    angley::Array{JuMP.VariableRef,1}
    residualx::Array{JuMP.VariableRef,1}
    residualy::Array{JuMP.VariableRef,1}
end

mutable struct DCStateEstimationMethodLAV
    jump::JuMP.Model
    anglex::Array{JuMP.VariableRef,1}
    angley::Array{JuMP.VariableRef,1}
    residualx::Array{JuMP.VariableRef,1}
    residualy::Array{JuMP.VariableRef,1}
    residual::Dict{Int64, JuMP.ConstraintRef}
    number::Int64
end

struct DCStateEstimationLAV <: DCStateEstimation
    voltage::PolarAngle
    power::DCPowerSE
    method::DCStateEstimationMethodLAV
end

mutable struct TieData
    bus::Set{Int64}
    branch::Set{Int64}
    injection::Array{Int64,1}
end

mutable struct IslandWatt <: Island
    island::Array{Array{Int64,1},1}
    bus::Array{Int64,1}
    tie::TieData
end

mutable struct IslandVar <: Island
    island::Array{Array{Int64,1},1}
    bus::Array{Int64,1}
    tie::TieData
end