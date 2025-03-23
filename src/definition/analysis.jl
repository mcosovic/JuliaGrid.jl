export Analysis, AC, DC, Normal, Orthogonal
export ACPowerFlow, NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export ACOptimalPowerFlow, DCOptimalPowerFlow
export ACStateEstimation, GaussNewton, LAV
export DCStateEstimation, WLS
export PMUStateEstimation
export Island, PMUPlacement, ResidualTest, ChiTest

"""
    Analysis

An abstract type used for representing both AC and DC analyses in JuliaGrid.
"""
abstract type Analysis end

"""
    AC <: Analysis

An abstract type representing AC analyses in JuliaGrid.
"""
abstract type AC <: Analysis end

"""
    DC <: Analysis

An abstract type representing DC analyses in JuliaGrid.
"""
abstract type DC <: Analysis end

"""
    Normal

An abstract type representing weighted least-squares state estimation, where the normal
equation is solved by factorizing the gain matrix and performing forward/backward
substitutions on the right-hand-side vector. It is used as a type parameter in
[`GaussNewton`](@ref GaussNewton) and [`WLS`](@ref WLS) models.
"""
abstract type Normal end

"""
    Orthogonal

An abstract type representing weighted least-squares state estimation, where the normal
equation is solved using an orthogonal method. It is used as a type parameter in
[`GaussNewton`](@ref GaussNewton) and [`WLS`](@ref WLS) models.
"""
abstract type Orthogonal end

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

"""
    NewtonRaphson

A composite type built using the [`newtonRaphson`](@ref newtonRaphson) function to define
the AC power flow model, which will be solved using the Newton-Raphson method.

# Fields
- `jacobian::SparseMatrixCSC{Float64, Int64}`: Jacobian matrix.
- `mismatch::Vector{Float64}`: Vector of mismatches.
- `increment::Vector{Float64}`: Vector of state variable increments.
- `factorization::Factorization{Float64}`: Factorization of the Jacobian matrix.
- `iteration::Int64`: The iteration counter.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `pattern::Int64`: Tracks pattern changes in entries of the Jacobian matrix.
"""
mutable struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64, Int64}
    mismatch::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    iteration::Int64
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

"""
    FastNewtonRaphson

A composite type built using the [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX) and
[`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB) functions to define the AC power flow
model, which will be solved using the fast Newton-Raphson method.

# Fields
- `active:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `reactive:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `iteration::Int64`: The iteration counter.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `acmodel::Int64`: Tracks values changing in entries of the Jacobian matrices.
- `pattern::Int64`: Tracks pattern changes in entries of the Jacobian matrices.
- `bx::Bool`: Version of the method, either BX or XB.
"""
mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    iteration::Int64
    pq::Vector{Int64}
    pvpq::Vector{Int64}
    acmodel::Int64
    pattern::Int64
    const bx::Bool
end

"""
    GaussSeidel

A composite type built using the [`gaussSeidel`](@ref gaussSeidel) function to define
the AC power flow model, which will be solved using the Gauss-Seidel method.

# Fields
- `voltage::Vector{ComplexF64}`: Vector of complex voltage values.
- `iteration::Int64`: The iteration counter.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pv::Vector{Int64}`: Indices related to generator buses.
"""
mutable struct GaussSeidel
    voltage::Vector{ComplexF64}
    iteration::Int64
    pq::Vector{Int64}
    pv::Vector{Int64}
end

"""
    ACPowerFlow{T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}} <: AC

A composite type representing an AC power flow model, where the type parameter `T` specifies
the numerical method used to solve the power flow. Supported methods include
[`NewtonRaphson`](@ref NewtonRaphson), [`FastNewtonRaphson`](@ref FastNewtonRaphson), and
[`GaussSeidel`](@ref GaussSeidel).

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::ACPower`: Active and reactive powers at the buses, branches, and generators.
- `current::ACCurrent`: Currents at the buses and branches.
- `method::T`: Vectors and matrices associated with the method used to solve the AC power flow.
"""
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

"""
    DCPowerFlow <: DC

A composite type built using the [`dcPowerFlow`](@ref dcPowerFlow) function to define
the DC power flow model.

# Fields
- `voltage::PolarAngle`: Bus voltage angles.
- `power::DCPower`: Active powers at the buses, branches, and generators.
- `method::DCPowerFlowMethod`: Factorization of the nodal admittance matrix.
"""
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

"""
    ACOptimalPowerFlow <: AC

A composite type built using the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function
to define the AC optimal power flow model.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::ACPower`: Active and reactive powers at buses, branches, and generators.
- `current::ACCurrent`: Currents at buses and branches.
- `method::ACOptimalPowerFlowMethod`: The JuMP model, including variables, constraints, and objective.
"""
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

"""
    DCOptimalPowerFlow <: DC

A composite type built using the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function
to define the DC optimal power flow model.

# Fields
- `voltage::PolarAngle`: Bus voltage angles.
- `power::DCPower`: Active powers at buses, branches, and generators.
- `method::DCOptimalPowerFlowMethod`: The JuMP model, including variables, constraints, and objective.
"""
mutable struct DCOptimalPowerFlow <: DC
    voltage::PolarAngle
    power::DCPower
    method::DCOptimalPowerFlowMethod
end

"""
    WLS{T <: Union{Normal, Orthogonal}}

A composite type representing a linear weighted least-squares state estimation model.

# Fields
- `coefficient::SparseMatrixCSC{Float64, Int64}`: Coefficient matrix.
- `precision::SparseMatrixCSC{Float64, Int64}`: Precision matrix.
- `mean::Vector{Float64}`: Mean vector.
- `factorization::Factorization{Float64}`: Factorization of the coefficient matrix.
- `index::OrderedDict{Int64, Int64}`: Indices if needed.
- `number::Int64`: Number of measurement devices.
- `inservice`::Int64: Number of equations related to in-service measurement devices.
- `pattern::Int64`: Tracks pattern changes in the coefficient matrix.
- `run::Bool`: Indicates whether factorization can be reused.
"""
mutable struct WLS{T <: Union{Normal, Orthogonal}}
    coefficient::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    factorization::Factorization{Float64}
    index::OrderedDict{Int64, Int64}
    number::Int64
    inservice::Int64
    pattern::Int64
    run::Bool
end

"""
    GaussNewton{T <: Union{Normal, Orthogonal}}

A composite type built using the [`gaussNewton`](@ref gaussNewton) function to define
the AC state estimation model, which will be solved using the Gauss-Newton method.

# Fields
- `jacobian::SparseMatrixCSC{Float64, Int64}`: Jacobian matrix.
- `precision::SparseMatrixCSC{Float64, Int64}`: Precision matrix.
- `mean::Vector{Float64}`: Mean vector.
- `residual::Vector{Float64}`: Residual vector.
- `increment::Vector{Float64}`: Increment vector.
- `factorization::Factorization{Float64}`: Factorization of the Jacobian matrix.
- `objective::Float64`: Value of the objective function.
- `iteration::Int64`: The iteration counter.
- `type::Vector{Int8}`: Indicators of measurement types.
- `index::Vector{Int64}`: Indices of buses and branches where measurements are located.
- `range::Vector{Int64}`: Range of measurement devices.
- `pattern::Int64`: Tracks pattern changes in the Jacobian matrix.
"""
mutable struct GaussNewton{T <: Union{Normal, Orthogonal}}
    jacobian::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    residual::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    objective::Float64
    iteration::Int64
    type::Vector{Int8}
    index::Vector{Int64}
    range::Vector{Int64}
    pattern::Int64
end

struct ACState
    magnitude::Vector{VariableRef}
    angle::Vector{VariableRef}
    sinθij::Dict{Int64, NonlinearExpr}
    cosθij::Dict{Int64, NonlinearExpr}
    sinθ::Dict{Int64, NonlinearExpr}
    cosθ::Dict{Int64, NonlinearExpr}
    incidence::Dict{Tuple{Int64, Int64}, Int64}
end

struct PMUState
    realpart::Vector{VariableRef}
    imagpart::Vector{VariableRef}
end

struct DCState
    angle::Vector{VariableRef}
end

struct Deviation
    positive::Vector{VariableRef}
    negative::Vector{VariableRef}
end

"""
    LAV{T <: Union{ACState, PMUState, DCState}}

A composite type representing a least absolute value state estimation model.

# Fields
- `jump::JuMP.Model`: The JuMP optimization model.
- `state::State`: References to data related to state variables.
- `deviation::Deviation`: References to variables for positive and negative deviations.
- `residual::Dict{Int64, ConstraintRef}`: References to residual constraints.
- `index::OrderedDict{Int64, Int64}`: Mapping of indices, if needed.
- `range::Vector{Int64}`: Range of measurement devices.
- `number::Int64`: Total number of measurement devices.
"""
mutable struct LAV
    jump::JuMP.Model
    state::Union{ACState, PMUState, DCState}
    deviation::Deviation
    residual::Dict{Int64, ConstraintRef}
    index::OrderedDict{Int64, Int64}
    range::Vector{Int64}
    number::Int64
end

"""
    DCStateEstimation{T <: Union{WLS, LAV}} <: DC

A composite type representing a DC state estimation model, where the type parameter `T`
specifies the estimation method. Supported methods include [`WLS`](@ref WLS) and
[`LAV`](@ref LAV). The model is constructed using either the
[`dcStateEstimation`](@ref dcStateEstimation) or
[`dcLavStateEstimation`](@ref dcLavStateEstimation) function.

# Fields
- `voltage::PolarAngle`: Bus voltage angles.
- `power::DCPower`: Active powers at the buses and generators.
- `method::T`: The estimation model associated with the method used to solve the DC state estimation.
"""
struct DCStateEstimation{T <: Union{WLS, LAV}} <: DC
    voltage::PolarAngle
    power::DCPower
    method::T
end

"""
    PMUStateEstimation{T <: Union{WLS, LAV}} <: AC

A composite type representing a PMU state estimation model, where the type parameter `T`
specifies the estimation method. Supported methods include [`WLS`](@ref WLS) and
[`LAV`](@ref LAV). The model is constructed using either the
[`pmuStateEstimation`](@ref pmuStateEstimation) or
[`pmuLavStateEstimation`](@ref pmuLavStateEstimation) function.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::ACPower`: Active and reactive powers at the buses and branches.
- `current::ACCurrent`: Currents at the buses and branches.
- `method::T`: The estimation model associated with the method used to solve the PMU state estimation.
"""
struct PMUStateEstimation{T <: Union{WLS, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

"""
    ACStateEstimation{T <: Union{GaussNewton, LAV}} <: AC

A composite type representing an AC state estimation model, where the type parameter `T`
specifies the estimation method. Supported methods include [`GaussNewton`](@ref GaussNewton)
and [`LAV`](@ref LAV). The model is constructed using either the
[`gaussNewton`](@ref gaussNewton) or [`acLavStateEstimation`](@ref acLavStateEstimation)
function.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::ACPower`: Active and reactive powers at the buses and branches.
- `current::ACCurrent`: Currents at the buses and branches.
- `method::T`: The estimation model associated with the method used to solve the AC state estimation.
"""
struct ACStateEstimation{T <: Union{GaussNewton, LAV}} <: AC
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end

mutable struct TieData
    bus::Set{Int64}
    branch::Set{Int64}
    injection::Set{Int64}
end

"""
    Island

A composite type built using the [`islandTopologicalFlow`](@ref islandTopologicalFlow) and
[`islandTopological`](@ref islandTopological) functions, which holds data about observable
islands.

# Fields
- `island::Vector{Vector{Int64}}`: List of observable islands, represented by a vector of bus indices.
- `bus::Vector{Int64}`: Positions of buses in relation to each island.
- `tie::TieData`: Tie data associated with buses and branches.
"""
mutable struct Island
    island::Vector{Vector{Int64}}
    bus::Vector{Int64}
    tie::TieData
end

"""
    PMUPlacement

A composite type built using the [`pmuPlacement`](@ref pmuPlacement) function, which
stores data on optimal PMU placement.

# Fields
- `bus::LabelDict`: Phasor measurement placement at buses.
- `from::LabelDict`: Phasor measurement placement at from-buses.
- `to::LabelDict`: Phasor measurement placement at to-buses.
"""
mutable struct PMUPlacement
    bus::LabelDict
    from::LabelDict
    to::LabelDict
end

"""
    ResidualTest

A composite type built using [`residualTest!`](@ref residualTest!) function, which stores
results from the bad data processing.

# Fields
- `detect::Bool`: Flag indicating bad data detection.
- `maxNormalizedResidual::Float64`: The maximum value of the normalized residual.
- `label::IntStr`: The label of the measurement suspected to be an outlier.
- `index::Int64`: The index of the outlier measurement within the model.
"""
mutable struct ResidualTest
    detect::Bool
    maxNormalizedResidual::Float64
    label::IntStr
    index::Int64
end

"""
    ChiTest

A composite type constructed using the [`chiTest`](@ref chiTest) function, which stores
results from the Chi-squared bad data detection test.

# Fields
- `detect::Bool`: Flag indicating bad data detection.
- `threshold::Float64`: Chi-squared critical value.
- `objective::Float64`: Objective function value from WLS state estimation.
"""
mutable struct ChiTest
    detect::Bool
    treshold::Float64
    objective::Float64
end