"""
    acOptimalPowerFlow(system::PowerSystem, optimizer;
        iteration, tolerance, bridge, name, magnitude, angle,
        active, reactive, actwise, reactwise, verbose)

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
    name::Bool = true,
    magnitude::String = "magnitude",
    angle::String = "angle",
    active::String = "active",
    reactive::String = "reactive",
    actwise::String = "actwise",
    reactwise::String = "reactwise",
    verbose::Int64 = template.config.verbose
)
    branch = system.branch
    bus = system.bus
    gen = system.generator
    cbt = gen.capability

    checkSlackBus(system)
    model!(system, system.model.ac)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)
    setAttribute(jump, iteration, tolerance, verbose)

    jump.ext[:active] = active
    jump.ext[:actwise] = actwise
    jump.ext[:reactive] = reactive
    jump.ext[:reactwise] = reactwise

    var = AcVariableRef(
        PolarVariableRef(
            @variable(jump, magnitude[i = 1:bus.number], base_name = magnitude),
            @variable(jump, angle[i = 1:bus.number], base_name = angle)
        ),
        CartesianVariableRef(
            @variable(jump, active[i = 1:gen.number], base_name = active),
            @variable(jump, reactive[i = 1:gen.number], base_name = reactive),
            Dict{Int64, VariableRef}(),
            Dict{Int64, VariableRef}()
        )
    )

    fix(var.voltage.angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])

    con = AcConstraintRef(
        AngleConstraintRef(
            Dict(bus.layout.slack => FixRef(var.voltage.angle[bus.layout.slack]))
        ),
        CartesianConstraintRef(
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}()
        ),
        PolarConstraintRef(
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}()
        ),
        AcFlowConstraintRef(
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}()
        ),
        AcCapabilityConstraintRef(
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}(),
            Dict{Int64, ConstraintRef}()
        ),
        AcPiecewiseConstraintRef(
            Dict{Int64, Vector{ConstraintRef}}(),
            Dict{Int64, Vector{ConstraintRef}}()
        ),
    )

    obj = AcObjective(
        @expression(jump, QuadExpr()),
        AcNonlinearExpr(
            Dict{Int64, NonlinearExpr}(),
            Dict{Int64, NonlinearExpr}()
        )
    )

    V = var.voltage.magnitude
    θ = var.voltage.angle
    P = var.power.active
    Q = var.power.reactive

    freeP = Dict{Int64, Float64}()
    freeQ = Dict{Int64, Float64}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            addObjective(system, jump, var, con, obj, freeP, freeQ, i)

            capabilityCurve(system, jump, var, con, i)

            addCapability(jump, P, con.capability.active, cbt.minActive, cbt.maxActive, i)
            addCapability(jump, Q, con.capability.reactive, cbt.minReactive, cbt.maxReactive, i)
        else
            fix!(P[i], 0.0, con.capability.active, i)
            fix!(Q[i], 0.0, con.capability.reactive, i)
        end
    end

    setObjective(jump, obj)

    aff = AffExpr()
    quad1 = QuadExpr()
    quad2 = QuadExpr()
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            addAngle(system, jump, θ, con.voltage.angle, aff, i)
            addFlow(system, jump, var.voltage, con, quad1, quad2, i)
        end
    end

    @inbounds for i = 1:bus.number
        addBalance(system, jump, var, con, i)
        addMagnitude(system, jump, V, con.voltage.magnitude, i)
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
                    Dict{Int64, Float64}()
                ),
                CartesianDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                PolarDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                AcFlowDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                AcCapabilityDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                AcPiecewiseDual(
                    Dict{Int64, Vector{Float64}}(),
                    Dict{Int64, Vector{Float64}}()
                )
            ),
            obj,
            Dict(
                :slack => copy(system.bus.layout.slack),
                :freeP => freeP,
                :freeQ => freeQ
            )
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
    system = analysis.system
    voltage = analysis.method.variable.voltage
    power = analysis.method.variable.power
    con = analysis.method.constraint
    dual = analysis.method.dual
    jump = analysis.method.jump
    verbose = analysis.method.jump.ext[:verbose]

    silentJump(jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(voltage.magnitude[i]::VariableRef, analysis.voltage.magnitude[i]::Float64)
        set_start_value(voltage.angle[i]::VariableRef, analysis.voltage.angle[i]::Float64)
    end

    @inbounds for i = 1:system.generator.number
        set_start_value(power.active[i]::VariableRef, analysis.power.generator.active[i])
        set_start_value(power.reactive[i]::VariableRef, analysis.power.generator.reactive[i])
    end

    try
        setdual!(jump, con.slack.angle, dual.slack.angle)
        setdual!(jump, con.balance.active, dual.balance.active)
        setdual!(jump, con.balance.reactive, dual.balance.reactive)
        setdual!(jump, con.voltage.magnitude, dual.voltage.magnitude)
        setdual!(jump, con.voltage.angle, dual.voltage.angle)
        setdual!(jump, con.flow.from, dual.flow.from)
        setdual!(jump, con.flow.to, dual.flow.to)
        setdual!(jump, con.capability.active, dual.capability.active)
        setdual!(jump, con.capability.reactive, dual.capability.reactive)
        setdual!(jump, con.capability.lower, dual.capability.lower)
        setdual!(jump, con.capability.upper, dual.capability.upper)
        setdual!(jump, con.piecewise.active, dual.piecewise.active)
        setdual!(jump, con.piecewise.reactive, dual.piecewise.reactive)
    catch
    end

    optimize!(jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = value(voltage.magnitude[i]::VariableRef)
        analysis.voltage.angle[i] = value(voltage.angle[i]::VariableRef)
    end

    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(power.active[i]::VariableRef)
        analysis.power.generator.reactive[i] = value(power.reactive[i]::VariableRef)
    end

    if has_duals(jump)
        dual!(jump, con.slack.angle, dual.slack.angle)
        dual!(jump, con.balance.active, dual.balance.active)
        dual!(jump, con.balance.reactive, dual.balance.reactive)
        dual!(jump, con.voltage.magnitude, dual.voltage.magnitude)
        dual!(jump, con.voltage.angle, dual.voltage.angle)
        dual!(jump, con.flow.from, dual.flow.from)
        dual!(jump, con.flow.to, dual.flow.to)
        dual!(jump, con.capability.active, dual.capability.active)
        dual!(jump, con.capability.reactive, dual.capability.reactive)
        dual!(jump, con.capability.lower, dual.capability.lower)
        dual!(jump, con.capability.upper, dual.capability.upper)
        dual!(jump, con.piecewise.active, dual.piecewise.active)
        dual!(jump, con.piecewise.reactive, dual.piecewise.reactive)
    end

    printExit(analysis.method.jump, verbose)
end

function dual!(jump::JuMP.Model, con::Dict{Int64, ConstraintRef}, dual::Dict{Int64, Float64})
    @inbounds for (i, value) in con
        if is_valid(jump, value)
            dual[i] = JuMP.dual(value::ConstraintRef)
        end
    end
end

function dual!(
    jump::JuMP.Model,
    con::Dict{Int64, Vector{ConstraintRef}},
    dual::Dict{Int64, Vector{Float64}}
)
    @inbounds for (i, value) in con
        n = length(value)
        dual[i] = fill(0.0, n)
        for j = 1:n
            if is_valid(jump, value[j])
                dual[i][j] = JuMP.dual(value[j]::ConstraintRef)
            end
        end
    end
end

function setdual!(jump::JuMP.Model, con::Dict{Int64, ConstraintRef}, dual::Dict{Int64, Float64})
    @inbounds for (i, value) in dual
        if is_valid(jump, con[i])
            set_dual_start_value(con[i], value)
        end
    end
end

function setdual!(
    jump::JuMP.Model,
    con::Dict{Int64, Vector{ConstraintRef}},
    dual::Dict{Int64, Vector{Float64}}
)
    @inbounds for (i, value) in dual
        for j in eachindex(value)
            if is_valid(jump, con[i][j])
                set_dual_start_value(con[i][j], value[j])
            end
        end
    end
end

##### Objective Function #####
function polynomialQuad(
    obj::QuadExpr,
    power::Vector{VariableRef},
    cost::OrderedDict{Int64, Vector{Float64}},
    free::Dict{Int64, Float64},
    i::Int64
)
    add_to_expression!(obj, cost[i][end - 2], power[i], power[i])
    add_to_expression!(obj, cost[i][end - 1], power[i])
    add_to_expression!(obj, cost[i][end])

    free[i] = cost[i][end]
end

function polynomialAff(
    obj::QuadExpr,
    power::Vector{VariableRef},
    cost::OrderedDict{Int64, Vector{Float64}},
    free::Dict{Int64, Float64},
    i::Int64
)
    add_to_expression!(obj, cost[i][1], power[i])
    add_to_expression!(obj, cost[i][2])

    free[i] = cost[i][2]
end

function polynomialConst(
    obj::QuadExpr,
    cost::OrderedDict{Int64, Vector{Float64}},
    free::Dict{Int64, Float64},
    i::Int64
)
    add_to_expression!(obj, cost[i][1])

    free[i] = cost[i][1]
end

function nonLinear(
    jump::JuMP.Model,
    variable::Vector{VariableRef},
    polynomial::OrderedDict{Int64, Vector{Float64}},
    term::Int64,
    nonlin::Dict{Int64, NonlinearExpr},
    i::Int64
)
    nonlin[i] = @expression(
        jump, sum(polynomial[i][term - degree] * variable[i]^degree for degree = term-1:-1:3)
    )
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
    con::Dict{Int64, Vector{ConstraintRef}},
    obj::QuadExpr,
    name::String,
    free::Dict{Int64, Float64},
    i::Int64
)
    point = size(cost.piecewise[i], 1)

    output = @view cost.piecewise[i][:, 1]
    price = @view cost.piecewise[i][:, 2]

    if size(cost.piecewise[i], 1) > 2
        wise[i] = @variable(jump, base_name = name * "[$i]")
        add_to_expression!(obj, wise[i])

        con[i] = Array{ConstraintRef}(undef, point - 1)
        for j = 2:point
            slope = (price[j] - price[j-1]) / (output[j] - output[j-1])

            if isinf(slope) || isnan(slope)
                errorSlope(getLabel(system.generator.label, i), slope)
            end

            con[i][j-1] = @constraint(
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

    actwise = jump.ext[:actwise]
    reactive = jump.ext[:reactive]

    if costP.model[i] == 2
        addPolynomial(system, costP, jump, P, quad, nonlin.active, freeP, i)
    elseif costP.model[i] == 1
        addPiecewise(system, costP, jump, P, H, con.piecewise.active, quad, actwise, freeP, i)
    end

    if costQ.model[i] == 2
        addPolynomial(system, costQ, jump, Q, quad, nonlin.reactive, freeQ, i)
    elseif costQ.model[i] == 1
        addPiecewise(system, costQ, jump, Q, G, con.piecewise.reactive, quad, reactive, freeQ, i)
    end
end

function setObjective(jump::JuMP.Model, obj::AcObjective)
    @objective(
        jump, Min, obj.quadratic +
        sum(obj.nonlinear.active[i] for i in keys(obj.nonlinear.active)) +
        sum(obj.nonlinear.reactive[i] for i in keys(obj.nonlinear.reactive))
    )
end

##### Add Capability Constraints #####
function addCapability(
    jump::JuMP.Model,
    var::Vector{VariableRef},
    con::Dict{Int64, ConstraintRef},
    minPower::Vector{Float64},
    maxPower::Vector{Float64},
    idx::Int64
)
    if minPower[idx] != maxPower[idx]
        if minPower[idx] != -Inf && maxPower[idx] != Inf
           con[idx] = @constraint(jump, var[idx] in MOI.Interval(minPower[idx], maxPower[idx]))
        end
    else
        fix!(var[idx], minPower[idx], con, idx)
    end
end

##### Voltage Magnitude Constraints #####
function addMagnitude(
    system::PowerSystem,
    jump::JuMP.Model,
    magnitude::Vector{VariableRef},
    con::Dict{Int64, ConstraintRef},
    idx::Int64
)
    V = system.bus.voltage

    if V.minMagnitude[idx] != V.maxMagnitude[idx]
        con[idx] = @constraint(jump, magnitude[idx] in MOI.Interval(V.minMagnitude[idx], V.maxMagnitude[idx]))
    else
        fix!(magnitude[idx], V.minMagnitude[idx], con, idx)
    end
end

##### Angle Difference Constraints #####
function addAngle(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    con::Dict{Int64, ConstraintRef},
    expr::JuMP.GenericAffExpr{Float64, JuMP.VariableRef},
    idx::Int64
)
    minθ = system.branch.voltage.minDiffAngle[idx]
    maxθ = system.branch.voltage.maxDiffAngle[idx]

    if minθ > -2*pi || maxθ < 2*pi
        i, j = fromto(system, idx)

        JuMP.add_to_expression!(expr, 1.0, angle[i])
        JuMP.add_to_expression!(expr, -1.0, angle[j])

        con[idx] = @constraint(jump, minθ <= expr <= maxθ)

        empty!(expr.terms)
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    var::AcVariableRef,
    constraint::AcConstraintRef,
    i::Int64
)
    V = var.voltage.magnitude
    θ = var.voltage.angle
    P = var.power.active
    Q = var.power.reactive
    refP = constraint.balance.active
    refQ = constraint.balance.reactive

    bus = system.bus
    ac = system.model.ac
    supply = system.bus.supply.generator

    exprP = @expression(jump, V[i] * real(ac.nodalMatrixTranspose[i, i]))
    exprQ = @expression(jump, -V[i] * imag(ac.nodalMatrixTranspose[i, i]))

    for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if i != j
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, θ, i, j, ptr)

            exprP = @expression(jump, exprP + V[j] * (Gij * cosθij + Bij * sinθij))
            exprQ = @expression(jump, exprQ + V[j] * (Gij * sinθij - Bij * cosθij))
        end
    end

    if haskey(supply, i)
        refP[i] = @constraint(jump, sum(P[k] for k in supply[i]) - V[i] * exprP == bus.demand.active[i])
        refQ[i] = @constraint(jump, sum(Q[k] for k in supply[i]) - V[i] * exprQ == bus.demand.reactive[i])
    else
        refP[i] = @constraint(jump, - V[i] * exprP == bus.demand.active[i])
        refQ[i] = @constraint(jump, - V[i] * exprQ == bus.demand.reactive[i])
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

                con.capability.upper[i] = @constraint(
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

                con.capability.lower[i] = @constraint(
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
    quad1::QuadExpr,
    quad2::QuadExpr,
    idx::Int64
)
    branch = system.branch
    conFrom = con.flow.from
    conTo = con.flow.to

    minFrom = branch.flow.minFromBus[idx]
    maxFrom = branch.flow.maxFromBus[idx]
    minTo = branch.flow.minToBus[idx]
    maxTo = branch.flow.maxToBus[idx]

    minFrom, maxFrom, from = checkLimit(system, minFrom, maxFrom, idx)
    minTo, maxTo, to = checkLimit(system, minTo, maxTo, idx)

    if from || to
        if branch.flow.type[idx] == 1
            if from
                expr = Pij(system, voltage, quad1, quad2, idx)
                conFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
                emptyExpr!(quad1, quad2)
            end
            if to
                expr = Pji(system, voltage, quad1, quad2, idx)
                conTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
                emptyExpr!(quad1, quad2)
            end

        elseif branch.flow.type[idx] == 2 || branch.flow.type[idx] == 3
            square = branch.flow.type[idx] == 3
            sq = if2exp(square)

            if from
                expr = Sij(system, voltage, square, quad1, quad2, idx)
                minFrom ^= sq
                maxFrom ^= sq
                conFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
                emptyExpr!(quad1, quad2)
            end
            if to
                expr = Sji(system, voltage, square, quad1, quad2, idx)
                minTo ^= sq
                maxTo ^= sq
                conTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
                emptyExpr!(quad1, quad2)
            end

        elseif branch.flow.type[idx] == 4 || branch.flow.type[idx] == 5
            square = branch.flow.type[idx] == 5
            sq = if2exp(square)

            if from
                expr = Iij(system, voltage, square, quad1, quad2, idx)
                minFrom ^= sq
                maxFrom ^= sq
                conFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
                emptyExpr!(quad1, quad2)
            end
            if to
                expr = Iji(system, voltage, square, quad1, quad2, idx)
                minTo ^= sq
                maxTo ^= sq
                conTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
                emptyExpr!(quad1, quad2)
            end
        end

    end
end

##### Fix and Unfix Data #####
function fix!(
    var::VariableRef,
    value::Float64,
    con::Dict{Int64, ConstraintRef},
    idx::Int64
)
    fix(var, value)
    con[idx] = FixRef(var)
end

function unfix!(jump::JuMP.Model,
    var::VariableRef,
    con::Dict{Int64, ConstraintRef},
    idx::Int64
)
    if haskey(con, idx)
        if is_valid(jump, con[idx])
            unfix(var)
        end
        delete!(con, idx)
    end
end

##### Remove Data #####
function remove!(
    jump::JuMP.Model,
    ref::Union{Dict{Int64, ConstraintRef}, Dict{Int64, VariableRef}},
    idx::Int64
)
    if haskey(ref, idx)
        if is_valid.(jump, ref[idx])
            delete(jump, ref[idx])
        end
        delete!(ref, idx)
    end
end

function remove!(jump::JuMP.Model, con::Dict{Int64, Vector{ConstraintRef}}, idx::Int64)
    if haskey(con, idx)
        if all(is_valid.(jump, con[idx]))
            delete.(jump, con[idx])
        end
        delete!(con, idx)
    end
end

function removeObjective!(
    jump::JuMP.Model,
    power::Vector{VariableRef},
    helper::Dict{Int64, JuMP.VariableRef},
    con::Dict{Int64, Vector{ConstraintRef}},
    obj::QuadExpr,
    free::Dict{Int64, Float64},
    idx::Int64
)
    if haskey(helper, idx) && is_valid.(jump, helper[idx])
        remove!(jump, con, idx)
        add_to_expression!(obj, -helper[idx])
        remove!(jump, helper, idx)

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

function checkLimit(system::PowerSystem, minFlow::Float64, maxFlow::Float64, i::Int64)
    if system.branch.flow.type[i] != 1
        if minFlow < 0.0
            minFlow = 0.0
        end
        if maxFlow < 0.0
            maxFlow = 0.0
        end
    end

    flag = true
    if minFlow == 0.0 && maxFlow == 0.0
        flag = false
    end

    return minFlow, maxFlow, flag
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

updateBus!(analysis; label = 14, reactive = 0.13, magnitude = 1.2, angle = -0.17)

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

    analysis.method.dual.slack.angle = Dict{Int64, Float64}()
    analysis.method.dual.balance.active = Dict{Int64, Float64}()
    analysis.method.dual.balance.reactive = Dict{Int64, Float64}()
    analysis.method.dual.voltage.magnitude = Dict{Int64, Float64}()
    analysis.method.dual.voltage.angle = Dict{Int64, Float64}()
    analysis.method.dual.flow.from = Dict{Int64, Float64}()
    analysis.method.dual.flow.to = Dict{Int64, Float64}()
    analysis.method.dual.capability.active = Dict{Int64, Float64}()
    analysis.method.dual.capability.reactive = Dict{Int64, Float64}()
    analysis.method.dual.capability.lower = Dict{Int64, Float64}()
    analysis.method.dual.capability.upper = Dict{Int64, Float64}()
    analysis.method.dual.piecewise.active = Dict{Int64, Vector{Float64}}()
    analysis.method.dual.piecewise.reactive = Dict{Int64, Vector{Float64}}()
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
        for (key, value) in source.method.dual.slack.angle
            target.method.dual.slack.angle[key] = value
        end

        for (key, value) in source.method.dual.balance.active
            target.method.dual.balance.active[key] = value
        end
        for (key, value) in source.method.dual.balance.reactive
            target.method.dual.balance.reactive[key] = value
        end

        for (key, value) in source.method.dual.voltage.magnitude
            target.method.dual.voltage.magnitude[key] = value
        end
        for (key, value) in source.method.dual.voltage.angle
            target.method.dual.voltage.angle[key] = value
        end

        for (key, value) in source.method.dual.flow.from
            target.method.dual.flow.from[key] = value
        end
        for (key, value) in source.method.dual.flow.to
            target.method.dual.flow.to[key] = value
        end

        for (key, value) in source.method.dual.capability.active
            target.method.dual.capability.active[key] = value
        end
        for (key, value) in source.method.dual.capability.reactive
            target.method.dual.capability.reactive[key] = value
        end
        for (key, value) in source.method.dual.capability.lower
            target.method.dual.capability.lower[key] = value
        end
        for (key, value) in source.method.dual.capability.upper
            target.method.dual.capability.upper[key] = value
        end

        for (key, value) in source.method.dual.piecewise.active
            target.method.dual.piecewise.active[key] = value
        end
        for (key, value) in source.method.dual.piecewise.reactive
            target.method.dual.piecewise.reactive[key] = value
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
end