"""
    acOptimalPowerFlow(system::PowerSystem, optimizer;
        iteration, tolerance, bridge, interval, name,
        magnitude, angle, active, reactive, actwise, reactwise, verbose)

The function sets up the optimization model for solving the AC optimal power flow problem.

# Arguments
The function requires the `PowerSystem` type to establish the framework. Next, the `optimizer`
argument is also required to create and solve the optimization problem. Specifically, JuliaGrid
constructs the AC optimal power flow using the JuMP package and provides support for commonly
employed solvers. For more detailed information, please consult the
[JuMP documentation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
Users can configure the following parameters:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `bridge`: Manage the bridging mechanism (default: `false`).
* `interval`: Uses interval form for two-sided constraints (default: `true`).
* `name`: Manage the creation of string names (default: `true`).
* `verbose`: Controls the output display, ranging from silent mode (`0`) to detailed output (`3`).

Additionally, users can modify the variable names used for printing and writing by setting the
keywords for the variables `magnitude`, `angle`, `active`, and `reactive`, as well as the helper
variables `actwise` and `reactwise`. For instance, users can choose `magnitude = "V"` and
`angle = "θ"` to display equations in a more readable format.

# Updates
If the AC model has not been created, the function automatically initiates an update within the `ac`
field of the `PowerSystem` type.

# Returns
The function returns an instance of the [`AcOptimalPowerFlow`](@ref AcOptimalPowerFlow) type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; iteration = 50, verbose = 1)
```
"""
function acOptimalPowerFlow(
    system::PowerSystem,
    @nospecialize optimizerFactory;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    bridge::Bool = false,
    interval::Bool = true,
    name::Bool = true,
    magnitude::String = "magnitude",
    angle::String = "angle",
    active::String = "active",
    reactive::String = "reactive",
    actwise::String = "actwise",
    reactwise::String = "reactwise",
    verbose::Int64 = template.config.verbose
)
    bus = system.bus
    gen = system.generator
    cbt = gen.capability
    vtg = bus.voltage

    errorOptimal(system)
    checkSlackBus(system)
    model!(system, system.model.ac)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    jump.ext[:active] = active
    jump.ext[:actwise] = actwise
    jump.ext[:reactive] = reactive
    jump.ext[:reactwise] = reactwise
    jump.ext[:interval] = interval
    jump.ext[:dualval] = false
    jump.ext[:nvar] = 0
    jump.ext[:ncon] = 0

    var = AcVariableRef(
        PolarVariableRef(
            @variable(
                jump, vtg.minMagnitude[i] <= magnitude[i = 1:bus.number] <= vtg.maxMagnitude[i],
                base_name = magnitude
            ),
            @variable(jump, angle[i = 1:bus.number], base_name = angle)
        ),
        CartesianVariableRef(
            @variable(
                jump, cbt.minActive[i] <= active[i = 1:gen.number] <= cbt.maxActive[i],
                base_name = active
            ),
            @variable(
                jump, cbt.minReactive[i] <= reactive[i = 1:gen.number] <= cbt.maxReactive[i],
                base_name = reactive
            ),
            Dict{Int64, VariableRef}(),
            Dict{Int64, VariableRef}()
        )
    )

    v = var.voltage
    s = var.power

    fix(v.angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])

    con = AcConstraintRef(
        AngleConstraintRef(
            OrderedDict(bus.layout.slack => Dict(:equality => FixRef(v.angle[bus.layout.slack])))
        ),
        CartesianConstraintRef(
            ConDict(),
            ConDict()
        ),
        PolarConstraintRef(
            ConDict(),
            ConDict()
        ),
        AcFlowConstraintRef(
            ConDict(),
            ConDict()
        ),
        AcCapabilityConstraintRef(
            ConDict(),
            ConDict(),
            ConDict(),
            ConDict()
        ),
        AcPiecewiseConstraintRef(
            ConDictVec(),
            ConDictVec()
        ),
    )

    obj = AcObjective(
        @expression(jump, QuadExpr()),
        AcNonlinearExpr(
            Dict{Int64, NonlinearExpr}(),
            Dict{Int64, NonlinearExpr}()
        )
    )

    freeP = Dict{Int64, Float64}()
    freeQ = Dict{Int64, Float64}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            addObjective(system, jump, var, con, obj, freeP, freeQ, i)

            capabilityCurve(system, jump, var, con, i)

            setConstraint!(s.active, con.capability.active, cbt.minActive, cbt.maxActive, i)
            setConstraint!(s.reactive, con.capability.reactive, cbt.minReactive, cbt.maxReactive, i)
        else
            fix!(s.active[i], 0.0, con.capability.active, i; force = true)
            fix!(s.reactive[i], 0.0, con.capability.reactive, i; force = true)
        end
    end

    setObjective(jump, obj)

    expr = AffQuadExpr()
    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            addFlow(system, jump, var.voltage, con, expr, i)
            addAngle(system, jump, v.angle, con.voltage.angle, expr.aff, i)
        end
    end

    @inbounds for i = 1:bus.number
        setConstraint!(v.magnitude, con.voltage.magnitude, vtg.minMagnitude, vtg.maxMagnitude, i)
        addBalance(system, jump, var, con, i)
    end

    AcOptimalPowerFlow(
        Polar(
            copy(bus.voltage.magnitude),
            copy(bus.voltage.angle)
        ),
        AcPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(copy(gen.output.active), copy(gen.output.reactive))
        ),
        AcCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        AcOptimalPowerFlowMethod(
            jump,
            var,
            con,
            AcDual(
                AngleDual(
                    DualDict()
                ),
                CartesianDual(
                    DualDict(),
                    DualDict()
                ),
                PolarDual(
                    DualDict(),
                    DualDict()
                ),
                AcFlowDual(
                    DualDict(),
                    DualDict()
                ),
                AcCapabilityDual(
                    DualDict(),
                    DualDict(),
                    DualDict(),
                    DualDict()
                ),
                AcPiecewiseDual(
                    DualDictVec(),
                    DualDictVec()
                )
            ),
            obj,
            Dict(
                :slack => copy(system.bus.layout.slack),
                :freeP => freeP,
                :freeQ => freeQ
            )
        ),
        Extended(
            Float64[],
            OrderedDict{Int64, VariableRef}(),
            OrderedDict{Int64, ConstraintRef}(),
            ExtendedDual(
                DualDict(),
                OrderedDict{Int64, Float64}()
            ),
        ),
        system
    )
end

"""
    solve!(analysis::AcOptimalPowerFlow)

The function solves the AC optimal power flow model, computing the active and reactive power outputs
of the generators, as well as the bus voltage magnitudes and angles.

# Updates
The calculated active and reactive powers, as well as voltage magnitudes and angles, are stored in
the `power.generator` and `voltage` fields of the `AcOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(analysis)
```
"""
function solve!(analysis::AcOptimalPowerFlow)
    jump = analysis.method.jump
    moi = backend(jump)
    con = analysis.method.constraint
    dual = analysis.method.dual

    gen = analysis.power.generator
    v = analysis.method.variable.voltage
    s = analysis.method.variable.power

    checkSlackBus(jump, con.slack.angle, analysis.system.bus.layout.slack)
    silentJump(jump, analysis.method.jump.ext[:verbose])

    for i = 1:analysis.system.bus.number
        setprimal!(jump, moi, v.magnitude[i], analysis.voltage.magnitude[i])
        setprimal!(jump, moi, v.angle[i], analysis.voltage.angle[i])
    end
    for i = 1:analysis.system.generator.number
        setprimal!(jump, moi, s.active[i], analysis.power.generator.active[i])
        setprimal!(jump, moi, s.reactive[i], analysis.power.generator.reactive[i])
    end
    setprimal(jump, moi, analysis.extended)

    trydual(jump, con.slack.angle, analysis.system.bus.layout.slack)

    if jump.ext[:dualval]
        setdual(jump, moi, dual.slack.angle, con.slack.angle)
        setdual(jump, moi, dual.voltage.magnitude, con.voltage.magnitude)

        setdual(jump, moi, dual.capability.active, con.capability.active)
        setdual(jump, moi, dual.capability.reactive, con.capability.reactive)
        setdual(jump, moi, dual.capability.lower, con.capability.lower)
        setdual(jump, moi, dual.capability.upper, con.capability.upper)

        setdual(jump, moi, analysis.extended, analysis.extended.variable)

        setdual(jump, moi, dual.balance.active, con.balance.active)
        setdual(jump, moi, dual.balance.reactive, con.balance.reactive)
        setdual(jump, moi, dual.voltage.angle, con.voltage.angle)

        setdual(jump, moi, dual.flow.from, con.flow.from)
        setdual(jump, moi, dual.flow.to, con.flow.to)

        setdual(jump, moi, dual.flow.from, con.flow.from)
        setdual(jump, moi, dual.flow.to, con.flow.to)

        setdual(jump, moi, dual.piecewise.active, con.piecewise.active)
        setdual(jump, moi, dual.piecewise.reactive, con.piecewise.reactive)

        setdual(jump, moi, analysis.extended, analysis.extended.constraint)
    end

    optimize!(jump)

    for i = 1:analysis.system.bus.number
        getprimal!(jump, moi, v.magnitude[i], analysis.voltage.magnitude, i)
        getprimal!(jump, moi, v.angle[i], analysis.voltage.angle, i)
    end
    for i = 1:analysis.system.generator.number
        getprimal!(jump, moi, s.active[i], analysis.power.generator.active, i)
        getprimal!(jump, moi, s.reactive[i], analysis.power.generator.reactive, i)
    end
    getprimal(jump, moi, analysis.extended)

    if has_duals(jump)
        jump.ext[:dualval] = true

        getdual(jump, moi, dual.slack.angle, con.slack.angle)
        getdual(jump, moi, dual.voltage.magnitude, con.voltage.magnitude)

        getdual(jump, moi, dual.capability.active, con.capability.active)
        getdual(jump, moi, dual.capability.reactive, con.capability.reactive)
        getdual(jump, moi, dual.capability.lower, con.capability.lower)
        getdual(jump, moi, dual.capability.upper, con.capability.upper)

        getdual(jump, moi, analysis.extended, analysis.extended.variable)

        getdual(jump, moi, dual.balance.active, con.balance.active)
        getdual(jump, moi, dual.balance.reactive, con.balance.reactive)
        getdual(jump, moi, dual.voltage.angle, con.voltage.angle)

        getdual(jump, moi, dual.flow.from, con.flow.from)
        getdual(jump, moi, dual.flow.to, con.flow.to)

        getdual(jump, moi, dual.flow.from, con.flow.from)
        getdual(jump, moi, dual.flow.to, con.flow.to)

        getdual(jump, moi, dual.piecewise.active, con.piecewise.active)
        getdual(jump, moi, dual.piecewise.reactive, con.piecewise.reactive)

        getdual(jump, moi, analysis.extended, analysis.extended.constraint)
    end

    printExit(analysis.method.jump, analysis.method.jump.ext[:verbose])
end

##### Objective Function #####
function addObjective(
    system::PowerSystem,
    jump::JuMP.Model,
    var::AcVariableRef,
    con::AcConstraintRef,
    obj::AcObjective,
    freeP::Dict{Int64, Float64},
    freeQ::Dict{Int64, Float64},
    i::Int64
)
    costP = system.generator.cost.active
    costQ = system.generator.cost.reactive

    P = var.power.active
    Q = var.power.reactive
    H = var.power.actwise
    G = var.power.reactwise

    quad = obj.quadratic
    nonlin = obj.nonlinear

    if costP.model[i] == 2
        addPolynomial(system, costP, jump, P, quad, nonlin.active, freeP, i)
    elseif costP.model[i] == 1
        addPiecewise(system, costP, jump, P, H, con.piecewise.active, quad, :actwise, freeP, i)
    end

    if costQ.model[i] == 2
        addPolynomial(system, costQ, jump, Q, quad, nonlin.reactive, freeQ, i)
    elseif costQ.model[i] == 1
        addPiecewise(system, costQ, jump, Q, G, con.piecewise.reactive, quad, :reactive, freeQ, i)
    end
end

function addPolynomial(
    system::PowerSystem,
    cost::Cost,
    jump::JuMP.Model,
    power::Vector{VariableRef},
    qaud::QuadExpr,
    nonlin::Dict{Int64, NonlinearExpr},
    free::Dict{Int64, Float64},
    i::Int64,
)
    term = length(cost.polynomial[i])
    if term == 3
        polynomialQuad(qaud, power, cost.polynomial, free, i)
    elseif term == 2
        polynomialAff(qaud, power, cost.polynomial, free, i)
    elseif term == 1
        polynomialConst(qaud, cost.polynomial, free, i)
    elseif term > 3
        polynomialQuad(qaud, power, cost.polynomial, free, i)
        nonLinear(jump, power, cost.polynomial, term, nonlin, i)
    else
        infoObjective(getLabel(system.generator.label, i))
    end
end

function addPiecewise(
    system::PowerSystem,
    cost::Cost,
    jump::JuMP.Model,
    power::Vector{VariableRef},
    wise::Dict{Int64, VariableRef},
    con::ConDictVec,
    obj::QuadExpr,
    name::Symbol,
    free::Dict{Int64, Float64},
    i::Int64
)
    point = size(cost.piecewise[i], 1)

    output = @view cost.piecewise[i][:, 1]
    price = @view cost.piecewise[i][:, 2]

    if size(cost.piecewise[i], 1) > 2
        wise[i] = @variable(jump, base_name = jump.ext[name] * "[$i]")
        add_to_expression!(obj, wise[i])

        con[i] = Dict(:upper => Array{ConstraintRef}(undef, point - 1))
        for j = 2:point
            slope = (price[j] - price[j-1]) / (output[j] - output[j-1])

            if isinf(slope) || isnan(slope)
                errorSlope(getLabel(system.generator.label, i), slope)
            end

            con[i][:upper][j-1] = @constraint(
                jump, slope * power[i] - wise[i] <= slope * output[j-1] - price[j-1]
            )
        end
    elseif point == 2
        slope = (price[2] - price[1]) / (output[2] - output[1])

        if isinf(slope) || isnan(slope)
            errorSlope(getLabel(system.generator.label, i), slope)
        end

        free[i] = price[1] - output[1] * slope

        add_to_expression!(obj, slope, power[i])
        add_to_expression!(obj, free[i])

    elseif point == 1
        errorOnePoint(getLabel(system.generator.label, i))
    end
end

function setObjective(jump::JuMP.Model, obj::AcObjective)
    @objective(
        jump, Min, obj.quadratic +
        sum(obj.nonlinear.active[i] for i in keys(obj.nonlinear.active)) +
        sum(obj.nonlinear.reactive[i] for i in keys(obj.nonlinear.reactive))
    )
end

##### Angle Difference Constraints #####
function addAngle(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    con::ConDict,
    expr::AffExpr,
    idx::Int64
)
    minθ = system.branch.voltage.minDiffAngle[idx]
    maxθ = system.branch.voltage.maxDiffAngle[idx]

    if isfinite(minθ) && !(minθ in (0.0, -2π)) || isfinite(maxθ) && !(maxθ in (0.0, 2π))
        con[idx] = Dict{Symbol, ConstraintRef}()

        θij(system, angle, expr, idx)
        addConstraint(jump, con[idx], expr, minθ, maxθ)

        empty!(expr.terms)
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    var::AcVariableRef,
    con::AcConstraintRef,
    i::Int64
)
    V = var.voltage.magnitude
    θ = var.voltage.angle
    P = var.power.active
    Q = var.power.reactive
    con.balance.active[i] = Dict{Symbol, ConstraintRef}()
    con.balance.reactive[i] = Dict{Symbol, ConstraintRef}()

    bus = system.bus
    ac = system.model.ac
    supply = system.bus.supply.generator

    exprP = @expression(jump, -V[i] * real(ac.nodalMatrixTranspose[i, i]))
    exprQ = @expression(jump, V[i] * imag(ac.nodalMatrixTranspose[i, i]))

    for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, θ, i, j, ptr)

            exprP = @expression(jump, exprP + V[j] * (-Gij * cosθij - Bij * sinθij))
            exprQ = @expression(jump, exprQ + V[j] * (-Gij * sinθij + Bij * cosθij))
        end
    end

    if haskey(supply, i)
        expr = sum(P[k] for k in supply[i]) + NonlinearExpr(:*, V[i], exprP)
        con.balance.active[i][:equality] = add_constraint(
            jump, ScalarConstraint(expr, MOI.EqualTo(bus.demand.active[i]))
        )

        expr = sum(Q[k] for k in supply[i]) + NonlinearExpr(:*, V[i], exprQ)
        con.balance.reactive[i][:equality] = add_constraint(
            jump,
            ScalarConstraint(expr, MOI.EqualTo(bus.demand.reactive[i]))
        )
    else
        con.balance.active[i][:equality] = add_constraint(
            jump, ScalarConstraint(NonlinearExpr(:*, V[i], exprP), MOI.EqualTo(bus.demand.active[i]))
        )
        con.balance.reactive[i][:equality] = add_constraint(
            jump, ScalarConstraint(NonlinearExpr(:*, V[i], exprQ), MOI.EqualTo(bus.demand.reactive[i]))
        )
    end
end

##### Capability Curve Constraints #####
function capabilityCurve(
    system::PowerSystem,
    jump::JuMP.Model,
    var::AcVariableRef,
    con::AcConstraintRef,
    i::Int64
)
    P = var.power.active
    Q = var.power.reactive
    cbt = system.generator.capability

    if cbt.lowActive[i] != 0.0 || cbt.upActive[i] != 0.0
        if cbt.lowActive[i] >= cbt.upActive[i]
            throw(ErrorException("Capability curve is is not correctly defined."))
        end
        if cbt.maxLowReactive[i] <= cbt.minLowReactive[i]
            throw(ErrorException("Capability curve is is not correctly defined."))
        end
        if cbt.maxUpReactive[i] <= cbt.minUpReactive[i]
            throw(ErrorException("Capability curve is is not correctly defined."))
        end

        if cbt.lowActive[i] != cbt.upActive[i]
            diffPInv = 1 / (cbt.upActive[i] - cbt.lowActive[i])
            minLowP = cbt.minActive[i] - cbt.lowActive[i]
            maxLowP = cbt.maxActive[i] - cbt.lowActive[i]

            diffQ = cbt.minUpReactive[i] - cbt.minLowReactive[i]
            minQminP = cbt.minLowReactive[i] + minLowP * diffQ * diffPInv
            minQmaxP = cbt.minLowReactive[i] + maxLowP * diffQ * diffPInv
            if  minQminP > cbt.minReactive[i] || minQmaxP > cbt.minReactive[i]
                deltaQ = cbt.maxLowReactive[i] - cbt.maxUpReactive[i]
                deltaP = cbt.upActive[i] - cbt.lowActive[i]
                b = deltaQ * cbt.lowActive[i] + deltaP * cbt.maxLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                con.capability.upper[i] = Dict{Symbol, ConstraintRef}()
                con.capability.upper[i][:upper] = @constraint(
                    jump, scale * deltaQ * P[i] + scale * deltaP * Q[i] <= scale * b
                )
            end

            diffQ = cbt.maxUpReactive[i] - cbt.maxLowReactive[i]
            minQminP = cbt.maxLowReactive[i] + minLowP * diffQ * diffPInv
            minQmaxP = cbt.minLowReactive[i] + maxLowP * diffQ * diffPInv
            if minQminP < cbt.maxReactive[i] || minQmaxP < cbt.maxReactive[i]
                deltaQ = cbt.minUpReactive[i] - cbt.minLowReactive[i]
                deltaP = cbt.lowActive[i] - cbt.upActive[i]
                b = deltaQ * cbt.lowActive[i] + deltaP * cbt.minLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                con.capability.lower[i] = Dict{Symbol, ConstraintRef}()
                con.capability.lower[i][:upper] = @constraint(
                    jump, scale * deltaQ * P[i] + scale * deltaP * Q[i] <= scale * b)
            end
        end
    end
end

##### Flow Constraints #####
function addFlow(
    system::PowerSystem,
    jump::JuMP.Model,
    voltage::PolarVariableRef,
    con::AcConstraintRef,
    exprs::AffQuadExpr,
    idx::Int64
)
    branch = system.branch

    minFrom = branch.flow.minFromBus[idx]
    maxFrom = branch.flow.maxFromBus[idx]
    minTo = branch.flow.minToBus[idx]
    maxTo = branch.flow.maxToBus[idx]

    square = branch.flow.type[idx] == 3 || branch.flow.type[idx] == 5
    sq = if2exp(square)

    minFrom, maxFrom, from = checkLimit(system, minFrom, maxFrom, sq, idx)
    minTo, maxTo, to = checkLimit(system, minTo, maxTo, sq, idx)

    if from
        con.flow.from[idx] = Dict{Symbol, ConstraintRef}()

        if branch.flow.type[idx] == 1
            expr = Pij(system, voltage, exprs, idx)
        elseif branch.flow.type[idx] == 2 || branch.flow.type[idx] == 3
            expr = Sij(system, voltage, square, exprs, idx)
        elseif branch.flow.type[idx] == 4 || branch.flow.type[idx] == 5
            expr = Iij(system, voltage, square, exprs, idx)
        else
            throw(ErrorException("Invalid branch flow constraint type."))
        end

        addConstraint(jump, con.flow.from[idx], expr, minFrom, maxFrom)
        emptyExpr!(exprs)
    end

    if to
        con.flow.to[idx] = Dict{Symbol, ConstraintRef}()

        if branch.flow.type[idx] == 1
            expr = Pji(system, voltage, exprs, idx)
        elseif branch.flow.type[idx] == 2 || branch.flow.type[idx] == 3
            expr = Sji(system, voltage, square, exprs, idx)
        elseif branch.flow.type[idx] == 4 || branch.flow.type[idx] == 5
            expr = Iji(system, voltage, square, exprs, idx)
        else
            throw(ErrorException("Invalid branch flow constraint type."))
        end

        addConstraint(jump, con.flow.to[idx], expr, minTo, maxTo)
        emptyExpr!(exprs)
    end
end

function checkLimit(system::PowerSystem, minFlow::Float64, maxFlow::Float64, sq::Int64, i::Int64)
    if system.branch.flow.type[i] != 1
        minFlow = max(minFlow, 0.0)
        maxFlow = max(maxFlow, 0.0)
    end

    flag = !((minFlow == 0.0 && maxFlow == 0.0) || (isinf(minFlow) && isinf(maxFlow)))

    return minFlow^sq, maxFlow^sq, flag
end

function removeObjective!(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    power::Vector{VariableRef},
    helper::Dict{Int64, JuMP.VariableRef},
    con::ConDictVec,
    dual::DualDictVec,
    obj::QuadExpr,
    free::Dict{Int64, Float64},
    idx::Int64
)
    if haskey(helper, idx) && is_valid.(jump, helper[idx])
        remove!(jump, moi, con, dual, idx)
        add_to_expression!(obj, -helper[idx])
        remove!(jump, moi, helper, idx)

        drop_zeros!(obj)

    elseif haskey(free, idx)
        a = -coefficient(obj, power[idx], power[idx])
        b = -coefficient(obj, power[idx])
        c = -free[idx]

        add_to_expression!(obj, a, power[idx], power[idx])
        add_to_expression!(obj, b, power[idx])
        add_to_expression!(obj, c)

        delete!(free, idx)
        drop_zeros!(obj)
    end
end

function removeNonlinear!(obj::AcObjective, idx::Int64)
    if haskey(obj.nonlinear.active, idx)
        delete!(obj.nonlinear.active, idx)
    end

    if haskey(obj.nonlinear.reactive, idx)
        delete!(obj.nonlinear.reactive, idx)
    end
end

"""
    setInitialPoint!(analysis::AcOptimalPowerFlow)

The function sets the initial point of the AC optimal power flow to the values from the `PowerSystem`
type.

# Updates
The function modifies the `voltage` and `generator` fields of the `AcOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis)

updateBus!(analysis; label = "Bus 14 LV", reactive = 0.13, magnitude = 1.2, angle = -0.17)

setInitialPoint!(analysis)
powerFlow!(analysis)
```
"""
function setInitialPoint!(analysis::AcOptimalPowerFlow)
    system = analysis.system

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = system.generator.output.active[i]
        analysis.power.generator.reactive[i] = system.generator.output.reactive[i]
    end

    empty!(analysis.method.dual.slack.angle)
    empty!(analysis.method.dual.capability.active)
    empty!(analysis.method.dual.capability.reactive)
    empty!(analysis.method.dual.balance.active)
    empty!(analysis.method.dual.balance.reactive)
    empty!(analysis.method.dual.voltage.magnitude)
    empty!(analysis.method.dual.voltage.angle)
    empty!(analysis.method.dual.flow.from)
    empty!(analysis.method.dual.flow.to)
    empty!(analysis.method.dual.capability.lower)
    empty!(analysis.method.dual.capability.upper)
    empty!(analysis.method.dual.piecewise.active)
    empty!(analysis.method.dual.piecewise.reactive)
end

"""
    setInitialPoint!(target::AcOptimalPowerFlow, source::Analysis)

The function initializes the AC optimal power flow based on results from the `Analysis` type, whether
from an AC or DC analysis.

The function assigns the active and reactive power outputs of the generators, along with the bus
voltage magnitudes and angles in the `target` argument, using data from the `source` argument. This
allows users to initialize primal values as needed. Additionally, if `source` is of type
`AcOptimalPowerFlow`, the function also assigns initial dual values in the `target` argument based on
data from `source`.

If `source` comes from a DC analysis, only the active power outputs of the generators and bus voltage
angles are assigned in the `target` argument, while the reactive power outputs of the generators and
bus voltage magnitudes remain unchanged. Additionally, if `source` is of type `DcOptimalPowerFlow`,
the corresponding dual variable values are also assigned in the `target` argument.

# Updates
This function may modify the `voltage`, `generator`, and `method.dual` fields of the
`AcOptimalPowerFlow` type.

# Example
Use the AC power flow results to initialize the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

source = newtonRaphson(system)
powerFlow!(source)

target = acOptimalPowerFlow(system, Ipopt.Optimizer)

setInitialPoint!(target, source)
powerFlow!(target)
```
"""
function setInitialPoint!(target::AcOptimalPowerFlow, source::AC)
    if !isempty(source.voltage.magnitude) && !isempty(source.voltage.angle)
        errorTransfer(source.voltage.magnitude, target.voltage.magnitude)
        errorTransfer(source.voltage.angle, target.voltage.angle)
        @inbounds for i = 1:length(source.voltage.magnitude)
            target.voltage.magnitude[i] = source.voltage.magnitude[i]
            target.voltage.angle[i] = source.voltage.angle[i]
        end
    end

    if !isempty(source.power.generator.active) && !isempty(source.power.generator.reactive)
        errorTransfer(source.power.generator.active, target.power.generator.active)
        errorTransfer(source.power.generator.reactive, target.power.generator.reactive)
        @inbounds for i = 1:length(source.power.generator.active)
            target.power.generator.active[i] = source.power.generator.active[i]
            target.power.generator.reactive[i] = source.power.generator.reactive[i]
        end
    end

    if isdefined(source.method, :dual)
        for (field, subfield) in (
                :slack => :angle, :voltage => :magnitude, :capability => :active,
                :capability => :reactive, :balance => :active, :balance => :reactive,
                :voltage => :angle, :flow => :from, :flow => :to, :capability => :lower,
                :capability => :upper, :piecewise => :active, :piecewise => :reactive
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

function setInitialPoint!(target::AcOptimalPowerFlow, source::DC)
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
        for (field, subfield) in (
                :slack => :angle, :capability => :active,  :balance => :active,
                :voltage => :angle, :piecewise => :active
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
    powerFlow!(analysis::AcOptimalPowerFlow; iteration, tolerance, power, current, verbose)

The function serves as a wrapper for solving AC optimal power flow and includes the functions:
* [`solve!`](@ref solve!(::AcOptimalPowerFlow)),
* [`power!`](@ref power!(::AcPowerFlow)),
* [`current!`](@ref current!(::AC)).

It computes the active and reactive power outputs of the generators, as well as the bus voltage
magnitudes and angles, with an option to compute the powers and currents related to buses and branches.

# Keywords
Users can use the following keywords:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `power`: Enables the computation of powers (default: `false`).
* `current`: Enables the computation of currents (default: `false`).
* `verbose`: Controls the output display, ranging from the default silent mode (`0`) to detailed output (`3`).

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; power = true, verbose = 1)
```
"""
function powerFlow!(
    analysis::AcOptimalPowerFlow;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    current::Bool = false,
    verbose::IntMiss = missing
)
    masterVerbose = analysis.method.jump.ext[:verbose]
    verbose = setJumpVerbose(analysis.method.jump, template, verbose)
    setAttribute(analysis.method.jump, iteration, tolerance, verbose)

    solve!(analysis)

    if power
        power!(analysis)
    end
    if current
        current!(analysis)
    end

    analysis.method.jump.ext[:verbose] = masterVerbose

    return nothing
end