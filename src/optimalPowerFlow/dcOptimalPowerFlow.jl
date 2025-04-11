"""
    dcOptimalPowerFlow(system::PowerSystem, optimizer;
        iteration, tolerance, bridge, name, angle, active, actwise, verbose)

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
* `bridge`: Manage the bridging mechanism (default: `false`).
* `name`: Manage the creation of string names (default: `true`).
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
    name::Bool = true,
    angle::String = "angle",
    active::String = "active",
    actwise::String = "actwise",
    verbose::Int64 = template.config.verbose
)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability
    cost = gen.cost.active

    checkSlackBus(system)
    model!(system, system.model.dc)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    jump.ext[:active] = active
    jump.ext[:actwise] = actwise

    var = DcVariableRef(
        AngleVariableRef(
            @variable(jump, angle[i = 1:bus.number], base_name = angle)
        ),
        RealVariableRef(
            @variable(jump, active[i = 1:gen.number], base_name = active),
            Dict{Int64, VariableRef}()
        )
    )

    fix(var.voltage.angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])

    con = DcConstraintRef(
        AngleConstraintRef(
            Dict(bus.layout.slack => FixRef(var.voltage.angle[bus.layout.slack]))
        ),
        RealConstraintRef(
            Dict{Int64, ConstraintRef}()
        ),
        AngleConstraintRef(
            Dict{Int64, ConstraintRef}()
        ),
        RealConstraintRef(
            Dict{Int64, ConstraintRef}()
        ),
        RealConstraintRef(
            Dict{Int64, ConstraintRef}()
        ),
        DcPiecewiseConstraintRef(
            Dict{Int64, Vector{ConstraintRef}}()
        )
    )

    obj = @expression(jump, QuadExpr())

    power = var.power.active
    helper = var.power.actwise
    angle = var.voltage.angle

    free = Dict{Int64, Float64}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            addObjective(system, cost, jump, power, helper, con, obj, actwise, free, i)
            addCapability(jump, power, con.capability.active, cbt.minActive, cbt.maxActive, i)
        else
            fix!(active[i], 0.0, con.capability.active, i)
        end
    end

    @objective(jump, Min, obj)

    @inbounds for i = 1:bus.number
        addBalance(system, jump, var, con, i)
    end

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            addFlow(system, jump, angle, con.flow.active, i)
            addAngle(system, jump, angle, con.voltage.angle, i)
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
                    Dict{Int64, Float64}()
                ),
                RealDual(
                    Dict{Int64, Float64}()
                ),
                AngleDual(
                    Dict{Int64, Float64}()
                ),
                RealDual(
                    Dict{Int64, Float64}()
                ),
                RealDual(
                    Dict{Int64, Float64}()
                ),
                DcPiecewiseDual(
                    Dict{Int64, Vector{Float64}}()
                )
            ),
            obj,
            Dict(
                :slack => copy(system.bus.layout.slack),
                :free => free
            )
        ),
        system
    )
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
    system = analysis.system
    var = analysis.method.variable
    con = analysis.method.constraint
    dual = analysis.method.dual
    verbose = analysis.method.jump.ext[:verbose]

    silentJump(analysis.method.jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(var.voltage.angle[i]::VariableRef, analysis.voltage.angle[i])
    end
    @inbounds for i = 1:system.generator.number
        set_start_value(var.power.active[i]::VariableRef, analysis.power.generator.active[i])
    end

    try
        setdual!(analysis.method.jump, con.slack.angle, dual.slack.angle)
        setdual!(analysis.method.jump, con.balance.active, dual.balance.active)
        setdual!(analysis.method.jump, con.voltage.angle, dual.voltage.angle)
        setdual!(analysis.method.jump, con.flow.active, dual.flow.active)
        setdual!(analysis.method.jump, con.capability.active, dual.capability.active)
        setdual!(analysis.method.jump, con.piecewise.active, dual.piecewise.active)
    catch
    end

    optimize!(analysis.method.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = value(var.voltage.angle[i]::VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(var.power.active[i]::VariableRef)
    end

    if has_duals(analysis.method.jump)
        dual!(analysis.method.jump, con.slack.angle, dual.slack.angle)
        dual!(analysis.method.jump, con.balance.active, dual.balance.active)
        dual!(analysis.method.jump, con.voltage.angle, dual.voltage.angle)
        dual!(analysis.method.jump, con.flow.active, dual.flow.active)
        dual!(analysis.method.jump, con.capability.active, dual.capability.active)
        dual!(analysis.method.jump, con.piecewise.active, dual.piecewise.active)
    end

    printExit(analysis.method.jump, verbose)
end

##### Objective Functions #####
function addPolynomial(
    system::PowerSystem,
    cost::Cost,
    power::Vector{VariableRef},
    obj::QuadExpr,
    free::Dict{Int64, Float64},
    i::Int64,
)
    term = length(cost.polynomial[i])
    if term >= 3
        polynomialQuad(obj, power, cost.polynomial, free, i)
    elseif term == 2
        polynomialAff(obj, power, cost.polynomial, free, i)
    elseif term == 1
        polynomialConst(obj, cost.polynomial, free, i)
    else
        infoObjective(iterate(system.generator.label, i)[1][1])
    end
end

function addObjective(
    system::PowerSystem,
    cost::Cost,
    jump::JuMP.Model,
    power::Vector{VariableRef},
    wise::Dict{Int64, VariableRef},
    con::DcConstraintRef,
    obj::QuadExpr,
    name::String,
    free::Dict{Int64, Float64},
    i::Int64
)
    if cost.model[i] == 2
        addPolynomial(system, cost, power, obj, free, i)
    elseif cost.model[i] == 1
        addPiecewise(system, cost, jump, power, wise, con.piecewise.active, obj, name, free, i)
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    var::DcVariableRef,
    con::DcConstraintRef,
    i::Int64
)
    bus = system.bus
    dc = system.model.dc

    power = var.power.active
    angle = var.voltage.angle
    ref = con.balance.active

    expr = AffExpr()
    for ptr in dc.nodalMatrix.colptr[i]:(dc.nodalMatrix.colptr[i + 1] - 1)
        j = dc.nodalMatrix.rowval[ptr]
        add_to_expression!(expr, dc.nodalMatrix.nzval[ptr], -angle[j])
    end

    rhs = bus.demand.active[i] + bus.shunt.conductance[i] + dc.shiftPower[i]
    if haskey(bus.supply.generator, i)
        ref[i] = @constraint(jump, expr + sum(power[k] for k in bus.supply.generator[i]) == rhs)
    else
        ref[i] = @constraint(jump, expr == rhs)
    end
end

##### Flow Constraints #####
function addFlow(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    con::Dict{Int64, ConstraintRef},
    i::Int64
)
    branch = system.branch
    dc = system.model.dc

    if branch.flow.minFromBus[i] != 0.0 || branch.flow.maxFromBus[i] != 0.0
        from, to = fromto(system, i)
        expr = dc.admittance[i] * (angle[from] - angle[to] - branch.parameter.shiftAngle[i])

        con[i] = @constraint(jump, branch.flow.minFromBus[i] <= expr <= branch.flow.maxFromBus[i])
    end
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

updateBus!(analysis; label = 14, active = 0.1, angle = -0.17)

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

    analysis.method.dual.slack.angle = Dict{Int64, Float64}()
    analysis.method.dual.balance.active = Dict{Int64, Float64}()
    analysis.method.dual.voltage.angle = Dict{Int64, Float64}()
    analysis.method.dual.flow.active = Dict{Int64, Float64}()
    analysis.method.dual.capability.active = Dict{Int64, Float64}()
    analysis.method.dual.piecewise.active = Dict{Int64, Vector{Float64}}()
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
        for (key, value) in source.method.dual.slack.angle
            target.method.dual.slack.angle[key] = value
        end
        for (key, value) in source.method.dual.balance.active
            target.method.dual.balance.active[key] = value
        end
        for (key, value) in source.method.dual.voltage.angle
            target.method.dual.voltage.angle[key] = value
        end
        for (key, value) in source.method.dual.flow.active
            target.method.dual.flow.active[key] = value
        end
        for (key, value) in source.method.dual.capability.active
            target.method.dual.capability.active[key] = value
        end
        for (key, value) in source.method.dual.piecewise.active
            target.method.dual.piecewise.active[key] = value
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
        for (key, value) in source.method.dual.slack.angle
            target.method.dual.slack.angle[key] = value
        end
        for (key, value) in source.method.dual.balance.active
            target.method.dual.balance.active[key] = value
        end
        for (key, value) in source.method.dual.voltage.angle
            target.method.dual.voltage.angle[key] = value
        end
        for (key, value) in source.method.dual.capability.active
            target.method.dual.capability.active[key] = value
        end
        for (key, value) in source.method.dual.piecewise.active
            target.method.dual.piecewise.active[key] = value
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
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end
end