"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer;
        iteration, tolerance, bridge, interval, name, angle, active, actwise, verbose)

The function sets up the optimization model for solving the DC optimal power flow problem.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `optimizer`
argument is also required to create and solve the optimization problem. Specifically, JuliaGrid
constructs the DC optimal power flow using the JuMP package and provides support for commonly
employed solvers. For more detailed information, please consult the
[JuMP documentation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
Users can configure the following parameters:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `bridge`: Controls the bridging mechanism (default: `false`).
* `interval`: Uses interval form for two-sided expression constraints (default: `true`).
* `name`: Enables or disables the creation of string names (default: `true`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

Additionally, users can modify the variable names used for printing and writing by setting the
keywords for the voltage variables `angle` and `active`, as well as the helper variable `actwise`.
For example, users may set `angle = "θ"`, `active = "P"`, and `actwise = "H"` to display equations
in a more readable format.

# Updates
If the DC model has not been created, the function automatically initiates an update within the `dc`
field of the `PowerSystem` type.

# Returns
The function returns an instance of the [`DcOptimalPowerFlow`](@ref DcOptimalPowerFlow) type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
```
"""
function dcOptimalPowerFlow(
    system::PowerSystem,
    @nospecialize optimizerFactory;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    bridge::Bool = false,
    interval::Bool = true,
    name::Bool = true,
    angle::String = "angle",
    active::String = "active",
    actwise::String = "actwise",
    verbose::Int64 = template.config.verbose
)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability

    errorOptimal(system)
    checkSlackBus(system)
    model!(system, system.model.dc)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    jump.ext[:active] = active
    jump.ext[:actwise] = actwise
    jump.ext[:interval] = interval
    jump.ext[:dualval] = false
    jump.ext[:nvar] = 0
    jump.ext[:ncon] = 0

    var = DcVariableRef(
        AngleVariableRef(
            @variable(jump, angle[i = 1:bus.number], base_name = angle)
        ),
        RealVariableRef(
            @variable(
                jump, cbt.minActive[i] <= active[i = 1:gen.number] <= cbt.maxActive[i],
                base_name = active
            ),
            Dict{Int64, VariableRef}()
        )
    )

    power = var.power.active
    helper = var.power.actwise
    angle = var.voltage.angle

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])

    con = DcConstraintRef(
        AngleConstraintRef(
            OrderedDict(bus.layout.slack => Dict(:equality => FixRef(angle[bus.layout.slack])))
        ),
        RealConstraintRef(
            ConDict()
        ),
        RealConstraintRef(
            ConDict()
        ),
        AngleConstraintRef(
            ConDict()
        ),
        RealConstraintRef(
            ConDict()
        ),
        DcPiecewiseConstraintRef(
            ConDictVec()
        )
    )

    obj = @expression(jump, QuadExpr())

    free = Dict{Int64, Float64}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            addObjective(system, gen.cost.active, jump, power, helper, con, obj, free, i)
            setConstraint!(power, con.capability.active, cbt.minActive, cbt.maxActive, i)
        else
            fix!(power[i], 0.0, con.capability.active, i; force = true)
        end
    end

    @objective(jump, Min, obj)

    expr = @expression(jump, AffExpr())
    @inbounds for i = 1:bus.number
        addBalance(system, jump, var, con, expr, i)
    end

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            addFlow(system, jump, angle, con.flow.active, expr, i)
            addAngle(system, jump, angle, con.voltage.angle, expr, i)
        end
    end

    DcOptimalPowerFlow(
        Angle(
            copy(bus.voltage.angle)
        ),
        DcPower(
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(Float64[]),
            Real(copy(gen.output.active))
        ),
        DcOptimalPowerFlowMethod(
            jump,
            var,
            con,
            DcDual(
                AngleDual(
                    DualDict()
                ),
                RealDual(
                    DualDict()
                ),
                RealDual(
                    DualDict()
                ),
                AngleDual(
                    DualDict()
                ),
                RealDual(
                    DualDict()
                ),
                DcPiecewiseDual(
                    DualDictVec()
                )
            ),
            obj,
            Dict(
                :slack => copy(system.bus.layout.slack),
                :free => free
            )
        ),
        Extended(
            Float64[],
            OrderedDict{Int64, VariableRef}(),
            OrderedDict{Int64, ConstraintRef}(),
            ExtendedDual(
                OrderedDict{Int64, Dict{Symbol, Float64}}(),
                OrderedDict{Int64, Float64}()
            ),
        ),
        system
    )
end

##### Objective Functions #####
function addObjective(
    system::PowerSystem,
    cost::Cost,
    jump::JuMP.Model,
    power::Vector{VariableRef},
    helper::Dict{Int64, VariableRef},
    con::DcConstraintRef,
    obj::QuadExpr,
    free::Dict{Int64, Float64},
    idx::Int64
)
    if cost.model[idx] == 2
        term = length(cost.polynomial[idx])
        if term >= 3
            polynomialQuad(obj, power, cost.polynomial, free, idx)
        elseif term == 2
            polynomialAff(obj, power, cost.polynomial, free, idx)
        elseif term == 1
            polynomialConst(obj, cost.polynomial, free, idx)
        else
            infoObjective(getLabel(system.generator.label, idx))
        end
    elseif cost.model[idx] == 1
        addPiecewise(system, cost, jump, power, helper, con.piecewise.active, obj, :actwise, free, idx)
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    var::DcVariableRef,
    con::DcConstraintRef,
    expr::AffExpr,
    idx::Int64
)
    dc = system.model.dc
    con.balance.active[idx] = Dict{Symbol, ConstraintRef}()

    @inbounds for ptr in dc.nodalMatrix.colptr[idx]:(dc.nodalMatrix.colptr[idx + 1] - 1)
        j = dc.nodalMatrix.rowval[ptr]
        add_to_expression!(expr, -dc.nodalMatrix.nzval[ptr], var.voltage.angle[j])
    end

    if haskey(system.bus.supply.generator, idx)
        @inbounds for j in system.bus.supply.generator[idx]
            add_to_expression!(expr, var.power.active[j])
        end
    end

    rhs = system.bus.demand.active[idx] + system.bus.shunt.conductance[idx] + dc.shiftPower[idx]
    con.balance.active[idx][:equality] = add_constraint(jump, ScalarConstraint(expr, MOI.EqualTo(rhs)))

    empty!(expr.terms)
end

##### Flow Constraints #####
function addFlow(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    con::ConDict,
    expr::AffExpr,
    idx::Int64
)
    minPij = system.branch.flow.minFromBus[idx]
    maxPij = system.branch.flow.maxFromBus[idx]

    if (minPij != 0.0 && isfinite(minPij)) || (maxPij != 0.0 && isfinite(maxPij))
        con[idx] = Dict{Symbol, ConstraintRef}()

        Pij(system, angle, expr, idx)
        addConstraint(jump, con[idx], expr, minPij, maxPij)

        emptyExpr!(expr)
    end
end

"""
    solve!(analysis::DcOptimalPowerFlow)

The function solves the DC optimal power flow model, computing the active power outputs of the
generators, as well as the bus voltage angles.

# Updates
The calculated active powers, as well as voltage angles, are stored in the `power.generator` and
`voltage` fields of the `DcOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(analysis)
```
"""
function solve!(analysis::DcOptimalPowerFlow)
    jump = analysis.method.jump
    moi = backend(jump)
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual

    checkSlackBus(jump, con.slack.angle, analysis.system.bus.layout.slack)
    silentJump(jump, jump.ext[:verbose])

    @inbounds for i = 1:analysis.system.bus.number
        setprimal!(jump, moi, var.voltage.angle[i], analysis.voltage.angle[i])
    end
    @inbounds for i = 1:analysis.system.generator.number
        setprimal!(jump, moi, var.power.active[i], analysis.power.generator.active[i])
    end
    setprimal(jump, moi, analysis.extended)

    trydual(jump, con.slack.angle, analysis.system.bus.layout.slack)

    if jump.ext[:dualval]
        setdual(jump, moi, dual.slack.angle, con.slack.angle)
        setdual(jump, moi, dual.capability.active, con.capability.active)
        setdual(jump, moi, analysis.extended, analysis.extended.variable)

        setdual(jump, moi, dual.balance.active, con.balance.active)
        setdual(jump, moi, dual.voltage.angle, con.voltage.angle)
        setdual(jump, moi, dual.flow.active, con.flow.active)
        setdual(jump, moi, dual.piecewise.active, con.piecewise.active)
        setdual(jump, moi, analysis.extended, analysis.extended.constraint)
    end

    optimize!(jump)

    @inbounds for i = 1:analysis.system.bus.number
        getprimal!(jump, moi, var.voltage.angle[i], analysis.voltage.angle, i)
    end
    @inbounds for i = 1:analysis.system.generator.number
        getprimal!(jump, moi, var.power.active[i], analysis.power.generator.active, i)
    end
    getprimal(jump, moi, analysis.extended)

    if has_duals(jump)
        jump.ext[:dualval] = true

        getdual(jump, moi, dual.slack.angle, con.slack.angle)
        getdual(jump, moi, dual.capability.active, con.capability.active)
        getdual(jump, moi, analysis.extended, analysis.extended.variable)

        getdual(jump, moi, dual.balance.active, con.balance.active)
        getdual(jump, moi, dual.voltage.angle, con.voltage.angle)
        getdual(jump, moi, dual.flow.active, con.flow.active)
        getdual(jump, moi, dual.piecewise.active, con.piecewise.active)
        getdual(jump, moi, analysis.extended, analysis.extended.constraint)
    end

    printExit(analysis.method.jump, jump.ext[:verbose])
end

"""
    setInitialPoint!(analysis::DcOptimalPowerFlow)

The function sets the initial point of the DC optimal power flow to the values from the `PowerSystem`
type.

# Updates
The function modifies the `voltage` and `generator` fields of the `DcOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

updateBus!(analysis; label = "Bus 14 LV", active = 0.1, angle = -0.17)

setInitialPoint!(analysis)
powerFlow!(analysis)
```
"""
function setInitialPoint!(analysis::DcOptimalPowerFlow)
    system = analysis.system

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = system.generator.output.active[i]
    end

    empty!(analysis.method.dual.slack.angle)
    empty!(analysis.method.dual.capability.active)
    empty!(analysis.method.dual.balance.active)
    empty!(analysis.method.dual.voltage.angle)
    empty!(analysis.method.dual.flow.active)
    empty!(analysis.method.dual.piecewise.active)
end

"""
    setInitialPoint!(target::DcOptimalPowerFlow, source::Analysis)

The function initializes the DC optimal power flow based on results from the `Analysis` type, whether
from an AC or DC analysis.

The function assigns the active power outputs of the generators, along with the bus voltage angles in
the `target` argument, using data from the `source` argument. This allows users to initialize primal
values as needed. Additionally, if source is of type `AcOptimalPowerFlow` or `DcOptimalPowerFlow`,
the function also assigns initial dual values in the `target` argument based on data from `source`.

# Updates
This function may modify the `voltage`, `generator`, and `method.dual` fields of the
`DcOptimalPowerFlow` type.

# Example
Use the DC power flow results to initialize the DC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

source = dcPowerFlow(system)
solve!(source)

target = dcOptimalPowerFlow(system, Ipopt.Optimizer)

setInitialPoint!(target, source)
solve!(target)
```
"""
function setInitialPoint!(target::DcOptimalPowerFlow, source::DC)
    if !isempty(source.voltage.angle)
        errorTransfer(source.voltage.angle, target.voltage.angle)

        @inbounds for i = 1:length(source.voltage.angle)
            target.voltage.angle[i] = source.voltage.angle[i]
        end
    end

    if !isempty(source.power.generator.active)
        errorTransfer(source.power.generator.active, target.power.generator.active)
        @inbounds for i = 1:length(source.power.generator.active)
            target.power.generator.active[i] = source.power.generator.active[i]
        end
    end

    if isdefined(source.method, :dual)
        @inbounds for (field, subfield) in (
            :slack => :angle, :capability => :active, :balance => :active, :voltage => :angle,
            :flow => :active, :piecewise => :active
        )
            transferdual!(
                getfield(getfield(target.method.dual, field), subfield),
                getfield(getfield(target.method.constraint, field), subfield),
                getfield(getfield(source.method.dual, field), subfield),
                getfield(getfield(source.method.constraint, field), subfield),
            )
        end
    end
end

function setInitialPoint!(target::DcOptimalPowerFlow, source::AC)
    if !isempty(source.voltage.angle)
        errorTransfer(source.voltage.angle, target.voltage.angle)
        @inbounds for i = 1:length(source.voltage.angle)
            target.voltage.angle[i] = source.voltage.angle[i]
        end
    end

    if !isempty(source.power.generator.active)
        errorTransfer(source.power.generator.active, target.power.generator.active)
        @inbounds for i = 1:length(source.power.generator.active)
            target.power.generator.active[i] = source.power.generator.active[i]
        end
    end

    if isdefined(source.method, :dual)
        @inbounds for (field, subfield) in (
            :slack => :angle, :capability => :active, :balance => :active, :voltage => :angle,
            :piecewise => :active
        )
            transferdual!(
                getfield(getfield(target.method.dual, field), subfield),
                getfield(getfield(target.method.constraint, field), subfield),
                getfield(getfield(source.method.dual, field), subfield),
                getfield(getfield(source.method.constraint, field), subfield),
            )
        end
    end
end

"""
    powerFlow!(analysis::DcOptimalPowerFlow; iteration, tolerance, power, verbose)

The function serves as a wrapper for solving DC optimal power flow and includes the functions:
* [`solve!`](@ref solve!(::DcOptimalPowerFlow)),
* [`power!`](@ref power!(::DcPowerFlow)).

It computes the active power outputs of the generators, as well as the bus voltage angles, with an
option to compute the powers related to buses and branches.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `power`: Enables the computation of powers (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; power = true, verbose = 1)
```
"""
function powerFlow!(
    analysis::DcOptimalPowerFlow;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    verbose::IntMiss = missing
)
    masterVerbose = analysis.method.jump.ext[:verbose]
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end

    analysis.method.jump.ext[:verbose] = masterVerbose

    return nothing
end