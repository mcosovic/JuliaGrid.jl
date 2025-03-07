export AC, DC
export ACPowerFlow, NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export ACOptimalPowerFlow, DCOptimalPowerFlow
export ACStateEstimation, NonlinearWLS, Normal, Orthogonal, LAV
export DCStateEstimation, LinearWLS
export PMUStateEstimation
export Island, PlacementPMU

##### Abstract Types #####
abstract type AC end
abstract type DC end

abstract type Orthogonal end
abstract type Normal end

##### Powers in the AC Framework #####
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

##### Currents in the AC Framework #####
mutable struct ACCurrent
    injection::Polar
    from::Polar
    to::Polar
    series::Polar
end

##### Powers in the DC Framework #####
mutable struct DCPower
    injection::CartesianReal
    supply::CartesianReal
    from::CartesianReal
    to::CartesianReal
    generator::CartesianReal
end

##### Newton-Raphson #####
mutable struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64, Int64}
    mismatch::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    pq::Vector{Int64}
    pvpq::Vector{Int64}
    pattern::Int64
end

##### Fast Newton-Raphson #####
mutable struct FastNewtonRaphsonModel
    jacobian::SparseMatrixCSC{Float64, Int64}
    mismatch::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
end

mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Vector{Int64}
    pvpq::Vector{Int64}
    acmodel::Int64
    pattern::Int64
    const bx::Bool
end

##### Gauss-Seidel #####
struct GaussSeidel
    voltage::Vector{ComplexF64}
    pq::Vector{Int64}
    pv::Vector{Int64}
end

##### AC Power Flow #####
struct ACPowerFlow{T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

##### DC Power Flow #####
mutable struct DCPowerFlowMethod
    factorization::Factorization{Float64}
    dcmodel::Int64
    pattern::Int64
end

struct DCPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    method::DCPowerFlowMethod
end

##### Constraints #####
mutable struct CartesianFlowRef
    from::Dict{Int64, ConstraintRef}
    to::Dict{Int64, ConstraintRef}
end

mutable struct CartesianFlowDual
    from::Dict{Int64, Float64}
    to::Dict{Int64, Float64}
end

struct ACPiecewise
    active::Dict{Int64, Vector{ConstraintRef}}
    reactive::Dict{Int64, Vector{ConstraintRef}}
end

mutable struct ACPiecewiseDual
    active::Dict{Int64, Vector{Float64}}
    reactive::Dict{Int64, Vector{Float64}}
end

struct CapabilityRef
    active::Dict{Int64, ConstraintRef}
    reactive::Dict{Int64, ConstraintRef}
    lower::Dict{Int64, ConstraintRef}
    upper::Dict{Int64, ConstraintRef}
end

mutable struct CapabilityDual
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

##### AC Optimal Power Flow #####
struct ACVariable
    active::Vector{VariableRef}
    reactive::Vector{VariableRef}
    magnitude::Vector{VariableRef}
    angle::Vector{VariableRef}
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

##### DC Optimal Power Flow #####
struct DCVariable
    active::Vector{VariableRef}
    angle::Vector{VariableRef}
    actwise::Dict{Int64, VariableRef}
end

struct DCPiecewise
    active::Dict{Int64, Vector{ConstraintRef}}
end

mutable struct DCPiecewiseDual
    active::Dict{Int64, Vector{Float64}}
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

##### State Estimation #####
mutable struct BadData
    detect::Bool
    maxNormalizedResidual::Float64
    label::IntStr
    index::Int64
end

mutable struct LinearWLS{T <: Union{Normal, Orthogonal}}
    coefficient::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    factorization::Factorization{Float64}
    number::Int64
    pattern::Int64
    run::Bool
end

mutable struct NonlinearWLS{T <: Union{Normal, Orthogonal}}
    jacobian::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    residual::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    objective::Float64
    type::Vector{Int8}
    index::Vector{Int64}
    range::Vector{Int64}
    pattern::Int64
end

struct StateAC
    V::Vector{AffExpr}
    sinθij::Dict{Int64, NonlinearExpr}
    cosθij::Dict{Int64, NonlinearExpr}
    sinθ::Dict{Int64, NonlinearExpr}
    cosθ::Dict{Int64, NonlinearExpr}
    incidence::Dict{Tuple{Int64, Int64}, Int64}
end

mutable struct LAV
    jump::JuMP.Model
    state::Union{StateAC, Nothing}
    statex::Vector{VariableRef}
    statey::Vector{VariableRef}
    residualx::Vector{VariableRef}
    residualy::Vector{VariableRef}
    residual::Dict{Int64, ConstraintRef}
    range::Vector{Int64}
    number::Int64
end

mutable struct TieData
    bus::Set{Int64}
    branch::Set{Int64}
    injection::Set{Int64}
end

mutable struct Island
    island::Vector{Vector{Int64}}
    bus::Vector{Int64}
    tie::TieData
end

##### DC State Estimation #####
struct DCStateEstimation{T <: Union{LinearWLS{Normal}, LinearWLS{Orthogonal}, LAV}} <: DC
    voltage::PolarAngle
    power::DCPower
    method::T
end

##### PMU State Estimation #####
struct PMUStateEstimation{T <: Union{LinearWLS{Normal}, LinearWLS{Orthogonal}, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

mutable struct PlacementPMU
    bus::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    from::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
    to::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}}
end

##### AC State Estimation #####
struct ACStateEstimation{T <: Union{NonlinearWLS{Normal}, NonlinearWLS{Orthogonal}, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end