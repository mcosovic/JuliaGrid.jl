export Analysis, AC, DC, Normal, Orthogonal
export ACPowerFlow, NewtonRaphson, FastNewtonRaphson, GaussSeidel, DCPowerFlow
export ACOptimalPowerFlow, DCOptimalPowerFlow
export ACStateEstimation, GaussNewton, LAV
export DCStateEstimation, WLS
export PMUStateEstimation
export Island, PMUPlacement

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
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `pattern::Int64`: Tracks pattern changes in entries of the Jacobian matrix.
"""
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

"""
    FastNewtonRaphson

A composite type built using the [`fastNewtonRaphsonBX`](@ref fastNewtonRaphsonBX) and
[`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB) functions to define the AC power flow
model, which will be solved using the fast Newton-Raphson method.

# Fields
- `active:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `reactive:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `acmodel::Int64`: Tracks values changing in entries of the Jacobian matrices.
- `pattern::Int64`: Tracks pattern changes in entries of the Jacobian matrices.
- `bx::Bool`: Version of the method, either BX or XB.
"""
mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
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
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pv::Vector{Int64}`: Indices related to generator buses.
"""
struct GaussSeidel
    voltage::Vector{ComplexF64}
    pq::Vector{Int64}
    pv::Vector{Int64}
end

"""
    ACPowerFlow{T} <: AC where T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}

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
struct ACPowerFlow{T} <: AC where T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}
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

##### State Estimation #####
mutable struct BadData
    detect::Bool
    maxNormalizedResidual::Float64
    label::IntStr
    index::Int64
end

"""
    WLS{T <: Union{Normal, Orthogonal}}

A composite type representing a linear weighted least-squares state estimation model.

# Fields
- `coefficient::SparseMatrixCSC{Float64, Int64}`: Coefficient matrix.
- `precision::SparseMatrixCSC{Float64, Int64}`: Precision matrix.
- `mean::Vector{Float64}`: Mean vector.
- `factorization::Factorization{Float64}`: Factorization of the coefficient matrix.
- `number::Int64`: Number of measurement devices.
- `pattern::Int64`: Tracks pattern changes in the coefficient matrix.
- `run::Bool`: Indicates whether factorization can be reused.
"""
mutable struct WLS{T <: Union{Normal, Orthogonal}}
    coefficient::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    factorization::Factorization{Float64}
    number::Int64
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

"""
    LAV

A composite type representing a least absolute value state estimation model.

# Fields
- `jump::JuMP.Model`: The JuMP model.
- `state::Union{StateAC, Nothing}`: State variables data.
- `statex::Vector{VariableRef}`: References to optimization variables for bus voltages.
- `statey::Vector{VariableRef}`: References to optimization variables for bus voltages.
- `residualx::Vector{VariableRef}`: References to optimization variables for residuals.
- `residualy::Vector{VariableRef}`: References to optimization variables for residuals.
- `residual::Dict{Int64, ConstraintRef}`: References to the residual constraints.
- `range::Vector{Int64}`: Range of measurement devices.
- `number::Int64`: Number of measurement devices.
"""
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
    DCStateEstimation{T} <: DC where T <: Union{WLS, LAV}

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
struct DCStateEstimation{T} <: DC where T <: Union{WLS, LAV}
    voltage::PolarAngle
    power::DCPower
    method::T
end

"""
    PMUStateEstimation{T} <: AC where T <: Union{WLS, LAV}

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
struct PMUStateEstimation{T} <: AC where T <: Union{WLS, LAV}
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
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
    ACStateEstimation{T} <: AC where T <: Union{GaussNewton, LAV}

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
struct ACStateEstimation{T} <: AC where T <: Union{GaussNewton, LAV}
    voltage::Polar
    power::ACPower
    current::ACCurrent
    method::T
end