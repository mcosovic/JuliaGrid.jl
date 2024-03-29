export AC, DC, ACPowerFlow, OptimalPowerFlow
export NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export DCOptimalPowerFlow, ACOptimalPowerFlow
export DCStateEstimation, DCStateEstimationWLS, DCStateEstimationLAV
export PMUStateEstimation, PMUStateEstimationWLS, PMUStateEstimationLAV
export ACStateEstimation, ACStateEstimationWLS, ACStateEstimationLAV, NonlinearWLS
export LU, QR, LDLt, Factorization, Orthogonal, LinearWLS, LinearOrthogonal
export Island, IslandWatt, IslandVar
export PlacementPMU

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
abstract type PMUStateEstimation <: AC end
abstract type ACStateEstimation <: AC end
abstract type Island end
abstract type Orthogonal end

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

########### Powers in the Legacy and PMU SE Framework ###########
mutable struct PowerSE
    injection::Cartesian
    supply::Cartesian
    shunt::Cartesian
    from::Cartesian
    to::Cartesian
    series::Cartesian
    charging::Cartesian
end

########### Newton-Raphson ###########
mutable struct NewtonRaphsonMethod
    jacobian::SparseMatrixCSC{Float64,Int64}
    mismatch::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::LUQR
    pq::Array{Int64,1}
    pvpq::Array{Int64,1} 
    pattern::Int64
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
    acmodel::Int64
    pattern::Int64
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
    label::String
    index::Int64
end

mutable struct LinearWLS
    coefficient::SparseMatrixCSC{Float64,Int64}
    precision::SparseMatrixCSC{Float64,Int64}
    mean::Array{Float64,1}
    factorization::LULDLtQR
    number::Int64
    pattern::Int64
    run::Bool
end

mutable struct LinearOrthogonal
    coefficient::SparseMatrixCSC{Float64,Int64}
    precision::SparseMatrixCSC{Float64,Int64}
    mean::Array{Float64,1}
    factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64}
    number::Int64
    pattern::Int64
    run::Bool
end

struct DCStateEstimationWLS{T <: Union{LinearWLS, LinearOrthogonal}} <: DCStateEstimation
    voltage::PolarAngle
    power::DCPowerSE
    method::T
    outlier::BadData
end

mutable struct LAVMethod
    jump::JuMP.Model
    statex::Array{JuMP.VariableRef,1}
    statey::Array{JuMP.VariableRef,1}
    residualx::Array{JuMP.VariableRef,1}
    residualy::Array{JuMP.VariableRef,1}
    residual::Dict{Int64, JuMP.ConstraintRef}
    number::Int64
end

struct DCStateEstimationLAV <: DCStateEstimation
    voltage::PolarAngle
    power::DCPowerSE
    method::LAVMethod
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

########### PMU State Estimation ###########
struct PMUStateEstimationWLS{T <: Union{LinearWLS, LinearOrthogonal}} <: PMUStateEstimation
    voltage::Polar
    power::PowerSE
    current::Current
    method::T
    outlier::BadData
end

struct PMUStateEstimationLAV <: PMUStateEstimation
    voltage::Polar
    power::PowerSE
    current::Current
    method::LAVMethod
end

mutable struct PlacementPMU
    bus::OrderedDict{String,Int64}
    from::OrderedDict{String,Int64}
    to::OrderedDict{String,Int64}
end

########### AC State Estimation ###########
mutable struct NonlinearWLS
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

mutable struct NonlinearOrthogonal
    jacobian::SparseMatrixCSC{Float64,Int64}
    precision::SparseMatrixCSC{Float64,Int64}
    mean::Array{Float64,1}
    residual::Array{Float64,1}
    increment::Array{Float64,1}
    factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64}
    type::Array{Int8,1}
    index::Array{Int64,1}
    range::Array{Int64,1}
    pattern::Int64
end

struct ACStateEstimationWLS{T <: Union{NonlinearWLS, NonlinearOrthogonal}} <: ACStateEstimation
    voltage::Polar
    power::PowerSE
    current::Current
    method::T
end

mutable struct SparseModel
    row::Array{Int64,1}
    col::Array{Int64,1}
    val::Array{Float64,1}
    cnt::Int64
    idx::Int64
end

struct ACStateEstimationLAV <: ACStateEstimation
    voltage::Polar
    power::PowerSE
    current::Current
    method::LAVMethod
end