export Analysis, AC, DC, Normal, Orthogonal
export AcPowerFlow, NewtonRaphson, FastNewtonRaphson, GaussSeidel, DcPowerFlow
export AcOptimalPowerFlow, DcOptimalPowerFlow
export AcStateEstimation, GaussNewton, LAV
export DcStateEstimation, WLS
export PmuStateEstimation
export Island, PmuPlacement, ResidualTest, ChiTest

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

An abstract type representing weighted least-squares state estimation, where the normal equation is
solved by factorizing the gain matrix and performing forward/backward substitutions on the
right-hand-side vector. It is used as a type parameter in [`GaussNewton`](@ref GaussNewton) and
[`WLS`](@ref WLS) models.
"""
abstract type Normal end

"""
    Orthogonal

An abstract type representing weighted least-squares state estimation, where the normal equation is
solved using an orthogonal method. It is used as a type parameter in [`GaussNewton`](@ref GaussNewton)
and [`WLS`](@ref WLS) models.
"""
abstract type Orthogonal end

##### Powers in the AC Framework #####
mutable struct AcPower
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
mutable struct AcCurrent
    injection::Polar
    from::Polar
    to::Polar
    series::Polar
end

##### Powers in the DC Framework #####
mutable struct DcPower
    injection::Real
    supply::Real
    from::Real
    to::Real
    generator::Real
end

"""
    NewtonRaphson

A composite type built using the [`newtonRaphson`](@ref newtonRaphson) function to define the AC power
flow model, which will be solved using the Newton-Raphson method.

# Fields
- `jacobian::SparseMatrixCSC{Float64, Int64}`: Jacobian matrix.
- `mismatch::Vector{Float64}`: Vector of mismatches.
- `increment::Vector{Float64}`: Vector of state variable increments.
- `factorization::Factorization{Float64}`: Factorization of the Jacobian matrix.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `signature::Signature`: Tracks modifications in key variables.
- `iteration::Int64`: The iteration counter.
"""
mutable struct NewtonRaphson
    jacobian::SparseMatrixCSC{Float64, Int64}
    mismatch::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    pq::Vector{Int64}
    pvpq::Vector{Int64}
    signature::Dict{Symbol, Int64}
    iteration::Int64
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
[`fastNewtonRaphsonXB`](@ref fastNewtonRaphsonXB) functions to define the AC power flow model, which
will be solved using the fast Newton-Raphson method.

# Fields
- `active:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `reactive:FastNewtonRaphsonModel`: Jacobian, mismatches, and incrementes for active power equations.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pvpq::Vector{Int64}`: Indices related to demand and generator buses.
- `signature::Signature`: Tracks modifications in key variables.
- `bx::Bool`: Version of the method, either BX or XB.
- `iteration::Int64`: The iteration counter.
"""
mutable struct FastNewtonRaphson
    active::FastNewtonRaphsonModel
    reactive::FastNewtonRaphsonModel
    pq::Vector{Int64}
    pvpq::Vector{Int64}
    signature::Signature
    const bx::Bool
    iteration::Int64
end

"""
    GaussSeidel

A composite type built using the [`gaussSeidel`](@ref gaussSeidel) function to define the AC power
flow model, which will be solved using the Gauss-Seidel method.

# Fields
- `voltage::Vector{ComplexF64}`: Vector of complex voltage values.
- `pq::Vector{Int64}`: Indices related to demand buses.
- `pv::Vector{Int64}`: Indices related to generator buses.
- `signature::Signature`: Tracks modifications in key variables.
- `iteration::Int64`: The iteration counter.
"""
mutable struct GaussSeidel
    voltage::Vector{ComplexF64}
    pq::Vector{Int64}
    pv::Vector{Int64}
    signature::Dict{Symbol, Int64}
    iteration::Int64
end

"""
    AcPowerFlow{T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}} <: AC

A composite type representing an AC power flow model, where the type parameter `T` specifies the
numerical method used to solve the power flow. Supported methods include
[`NewtonRaphson`](@ref NewtonRaphson), [`FastNewtonRaphson`](@ref FastNewtonRaphson), and
[`GaussSeidel`](@ref GaussSeidel).

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::AcPower`: Active and reactive powers at the buses, branches, and generators.
- `current::AcCurrent`: Currents at the buses and branches.
- `method::T`: Vectors and matrices associated with the method used to solve the AC power flow.
- `system::PowerSystem`: The reference to the power system.
"""
struct AcPowerFlow{T <: Union{NewtonRaphson, FastNewtonRaphson, GaussSeidel}} <: AC
    voltage::Polar
    power::AcPower
    current::AcCurrent
    method::T
    system::PowerSystem
end

##### DC Power Flow #####
mutable struct DcPowerFlowMethod
    factorization::Factorization{Float64}
    signature::Dict{Symbol, Int64}
end

"""
    DcPowerFlow <: DC

A composite type built using the [`dcPowerFlow`](@ref dcPowerFlow) function to define the DC power
flow model.

# Fields
- `voltage::Angle`: Bus voltage angles.
- `power::DcPower`: Active powers at the buses, branches, and generators.
- `method::DcPowerFlowMethod`: Factorization of the nodal admittance matrix.
- `system::PowerSystem`: The reference to the power system.
"""
struct DcPowerFlow <: DC
    voltage::Angle
    power::DcPower
    method::DcPowerFlowMethod
    system::PowerSystem
end

##### AC Optimal Power Flow #####
struct AcVariableRef
    voltage::PolarVariableRef
    power::CartesianVariableRef
end

mutable struct AcFlowConstraintRef
    from::Dict{Int64, ConstraintRef}
    to::Dict{Int64, ConstraintRef}
end

struct AcPiecewiseConstraintRef
    active::Dict{Int64, Vector{ConstraintRef}}
    reactive::Dict{Int64, Vector{ConstraintRef}}
end

struct AcCapabilityConstraintRef
    active::Dict{Int64, ConstraintRef}
    reactive::Dict{Int64, ConstraintRef}
    lower::Dict{Int64, ConstraintRef}
    upper::Dict{Int64, ConstraintRef}
end

struct AcConstraintRef
    slack::AngleConstraintRef
    balance::CartesianConstraintRef
    voltage::PolarConstraintRef
    flow::AcFlowConstraintRef
    capability::AcCapabilityConstraintRef
    piecewise::AcPiecewiseConstraintRef
end

mutable struct AcFlowDual
    from::Dict{Int64, Float64}
    to::Dict{Int64, Float64}
end

mutable struct AcCapabilityDual
    active::Dict{Int64, Float64}
    reactive::Dict{Int64, Float64}
    lower::Dict{Int64, Float64}
    upper::Dict{Int64, Float64}
end

mutable struct AcPiecewiseDual
    active::Dict{Int64, Vector{Float64}}
    reactive::Dict{Int64, Vector{Float64}}
end

struct AcDual
    slack::AngleDual
    balance::CartesianDual
    voltage::PolarDual
    flow::AcFlowDual
    capability::AcCapabilityDual
    piecewise::AcPiecewiseDual
end

struct AcNonlinearExpr
    active::Dict{Int64, NonlinearExpr}
    reactive::Dict{Int64, NonlinearExpr}
end

mutable struct AcObjective
    quadratic::QuadExpr
    nonlinear::AcNonlinearExpr
end

mutable struct AcOptimalPowerFlowMethod
    jump::JuMP.Model
    variable::AcVariableRef
    constraint::AcConstraintRef
    dual::AcDual
    objective::AcObjective
    signature::Signature
end

"""
    AcOptimalPowerFlow <: AC

A composite type built using the [`acOptimalPowerFlow`](@ref acOptimalPowerFlow) function to define
the AC optimal power flow model.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::AcPower`: Active and reactive powers at buses, branches, and generators.
- `current::AcCurrent`: Currents at buses and branches.
- `method::AcOptimalPowerFlowMethod`: The JuMP model, including variables, constraints, and objective.
- `system::PowerSystem`: The reference to the power system.
"""
mutable struct AcOptimalPowerFlow <: AC
    voltage::Polar
    power::AcPower
    current::AcCurrent
    method::AcOptimalPowerFlowMethod
    system::PowerSystem
end

##### DC Optimal Power Flow #####
struct DcVariableRef
    voltage::AngleVariableRef
    power::RealVariableRef
end

struct DcPiecewiseConstraintRef
    active::Dict{Int64, Vector{ConstraintRef}}
end

struct DcConstraintRef
    slack::AngleConstraintRef
    balance::RealConstraintRef
    voltage::AngleConstraintRef
    flow::RealConstraintRef
    capability::RealConstraintRef
    piecewise::DcPiecewiseConstraintRef
end

mutable struct DcPiecewiseDual
    active::Dict{Int64, Vector{Float64}}
end

struct DcDual
    slack::AngleDual
    balance::RealDual
    voltage::AngleDual
    flow::RealDual
    capability::RealDual
    piecewise::DcPiecewiseDual
end

mutable struct DcOptimalPowerFlowMethod
    jump::JuMP.Model
    variable::DcVariableRef
    constraint::DcConstraintRef
    dual::DcDual
    objective::QuadExpr
    signature::Signature
end

"""
    DcOptimalPowerFlow <: DC

A composite type built using the [`dcOptimalPowerFlow`](@ref dcOptimalPowerFlow) function to define
the DC optimal power flow model.

# Fields
- `voltage::Angle`: Bus voltage angles.
- `power::DcPower`: Active powers at buses, branches, and generators.
- `method::DcOptimalPowerFlowMethod`: The JuMP model, including variables, constraints, and objective.
- `system::PowerSystem`: The reference to the power system.
"""
mutable struct DcOptimalPowerFlow <: DC
    voltage::Angle
    power::DcPower
    method::DcOptimalPowerFlowMethod
    system::PowerSystem
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
- `signature::Signature`: Tracks modifications in key variables.
"""
mutable struct WLS{T <: Union{Normal, Orthogonal}}
    coefficient::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    factorization::Factorization{Float64}
    index::OrderedDict{Int64, Int64}
    number::Int64
    inservice::Int64
    signature::Dict{Symbol, Union{Int64, Bool}}
end

"""
    GaussNewton{T <: Union{Normal, Orthogonal}}

A composite type built using the [`gaussNewton`](@ref gaussNewton) function to define the AC state
estimation model, which will be solved using the Gauss-Newton method.

# Fields
- `jacobian::SparseMatrixCSC{Float64, Int64}`: Jacobian matrix.
- `precision::SparseMatrixCSC{Float64, Int64}`: Precision matrix.
- `mean::Vector{Float64}`: Mean vector.
- `residual::Vector{Float64}`: Residual vector.
- `increment::Vector{Float64}`: Increment vector.
- `factorization::Factorization{Float64}`: Factorization of the Jacobian matrix.
- `type::Vector{Int8}`: Indicators of measurement types.
- `index::Vector{Int64}`: Indices of buses and branches where measurements are located.
- `range::Vector{Int64}`: Range of measurement devices.
- `signature::Signature`: Tracks modifications in key variables.
- `objective::Float64`: Value of the objective function.
- `iteration::Int64`: The iteration counter.
"""
mutable struct GaussNewton{T <: Union{Normal, Orthogonal}}
    jacobian::SparseMatrixCSC{Float64, Int64}
    precision::SparseMatrixCSC{Float64, Int64}
    mean::Vector{Float64}
    residual::Vector{Float64}
    increment::Vector{Float64}
    factorization::Factorization{Float64}
    type::Vector{Int8}
    index::Vector{Int64}
    range::Vector{Int64}
    signature::Dict{Symbol, Int64}
    objective::Float64
    iteration::Int64
end

struct DeviationVariableRef
    positive::Vector{VariableRef}
    negative::Vector{VariableRef}
end

struct LavVariableRef{T <: Union{PolarVariableRef, AngleVariableRef, RectangularVariableRef}}
    voltage::T
    deviation::DeviationVariableRef
end

"""
    LAV

A composite type representing a least absolute value state estimation model.

# Fields
- `jump::JuMP.Model`: The JuMP optimization model.
- `variable::LavVariableRef`: References to state variables and positive and negative deviations.
- `residual::Dict{Int64, ConstraintRef}`: References to residual constraints.
- `index::OrderedDict{Int64, Int64}`: Mapping of indices, if needed.
- `range::Vector{Int64}`: Range of measurement devices.
- `number::Int64`: Total number of measurement devices.
"""
mutable struct LAV
    jump::JuMP.Model
    variable::LavVariableRef
    residual::Dict{Int64, ConstraintRef}
    index::OrderedDict{Int64, Int64}
    range::Vector{Int64}
    number::Int64
end

"""
    DcStateEstimation{T <: Union{WLS, LAV}} <: DC

A composite type representing a DC state estimation model, where the type parameter `T` specifies the
estimation method. Supported methods include [`WLS`](@ref WLS) and [`LAV`](@ref LAV). The model is
constructed using either the [`dcStateEstimation`](@ref dcStateEstimation) or
[`dcLavStateEstimation`](@ref dcLavStateEstimation) function.

# Fields
- `voltage::Angle`: Bus voltage angles.
- `power::DcPower`: Active powers at the buses and generators.
- `method::T`: The estimation model associated with the method used to solve the DC state estimation.
- `system::PowerSystem`: The reference to the power system.
- `monitoring::Measurement`: The reference to the measurement model.
"""
struct DcStateEstimation{T <: Union{WLS, LAV}} <: DC
    voltage::Angle
    power::DcPower
    method::T
    system::PowerSystem
    monitoring::Measurement
end

"""
    PmuStateEstimation{T <: Union{WLS, LAV}} <: AC

A composite type representing a PMU state estimation model, where the type parameter `T` specifies
the estimation method. Supported methods include [`WLS`](@ref WLS) and [`LAV`](@ref LAV). The model
is constructed using either the [`pmuStateEstimation`](@ref pmuStateEstimation) or
[`pmuLavStateEstimation`](@ref pmuLavStateEstimation) function.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::AcPower`: Active and reactive powers at the buses and branches.
- `current::AcCurrent`: Currents at the buses and branches.
- `method::T`: The estimation model associated with the method used to solve the PMU state estimation.
- `system::PowerSystem`: The reference to the power system.
- `monitoring::Measurement`: The reference to the measurement model.
"""
struct PmuStateEstimation{T <: Union{WLS, LAV}} <: AC
    voltage::Polar
    power::AcPower
    current::AcCurrent
    method::T
    system::PowerSystem
    monitoring::Measurement
end

"""
    AcStateEstimation{T <: Union{GaussNewton, LAV}} <: AC

A composite type representing an AC state estimation model, where the type parameter `T` specifies
the estimation method. Supported methods include [`GaussNewton`](@ref GaussNewton) and
[`LAV`](@ref LAV). The model is constructed using either the [`gaussNewton`](@ref gaussNewton) or
[`acLavStateEstimation`](@ref acLavStateEstimation) function.

# Fields
- `voltage::Polar`: Bus voltages represented in polar form.
- `power::AcPower`: Active and reactive powers at the buses and branches.
- `current::AcCurrent`: Currents at the buses and branches.
- `method::T`: The estimation model associated with the method used to solve the AC state estimation.
- `system::PowerSystem`: The reference to the power system.
- `monitoring::Measurement`: The reference to the measurement model.
"""
struct AcStateEstimation{T <: Union{GaussNewton, LAV}} <: AC
    voltage::Polar
    power::AcPower
    current::AcCurrent
    method::T
    system::PowerSystem
    monitoring::Measurement
end

mutable struct TieData
    bus::Set{Int64}
    branch::Set{Int64}
    injection::Set{Int64}
end

"""
    Island

A composite type built using the [`islandTopologicalFlow`](@ref islandTopologicalFlow) and
[`islandTopological`](@ref islandTopological) functions, which holds data about observable islands.

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
    PmuPlacement

A composite type built using the [`pmuPlacement`](@ref pmuPlacement) function, which stores data on
optimal PMU placement.

# Fields
- `bus::LabelDict`: Phasor measurement placement at buses.
- `from::LabelDict`: Phasor measurement placement at from-buses.
- `to::LabelDict`: Phasor measurement placement at to-buses.
"""
mutable struct PmuPlacement
    bus::LabelDict
    from::LabelDict
    to::LabelDict
end

"""
    ResidualTest

A composite type built using [`residualTest!`](@ref residualTest!) function, which stores results
from the bad data processing.

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

A composite type constructed using the [`chiTest`](@ref chiTest) function, which stores results from
the Chi-squared bad data detection test.

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