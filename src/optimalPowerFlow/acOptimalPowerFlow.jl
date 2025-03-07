"""
    acOptimalPowerFlow(system::PowerSystem, optimizer;
        iteration, tolerance, bridge, name, magnitude, angle, active, reactive, verbose)

The function sets up the optimization model for solving the AC optimal power flow problem.

# Arguments
The function requires the `PowerSystem` composite type to establish the framework. Next,
the `optimizer` argument is also required to create and solve the optimization problem.
Specifically, JuliaGrid constructs the AC optimal power flow using the JuMP package and
provides support for commonly employed solvers. For more detailed information,
please consult the [JuMP documentation](https://jump.dev/jl/stable/packages/solvers/).

# Updates
If the AC model has not been created, the function automatically initiates an update within
the `ac` field of the `PowerSystem` type.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines
provided in the [JuMP documentation](https://jump.dev/jl/stable/reference/models/).
However, certain configurations may require different method calls, such as:
* `iteration`: Specifies the maximum number of iterations.
* `tolerance`: Specifies the allowed deviation from the optimal solution.
* `bridge`: Manage the bridging mechanism (default: `false`).
* `name`: Manage the creation of string names (default: `true`).
* `verbose`: Controls the output display, ranging from silent mode (`0`) to detailed output (`3`).

Additionally, users can modify variable names used for printing and writing through the
keywords `magnitude`, `angle`, `active`, and `reactive`. For instance, users can choose
`magnitude = "V"` and `angle = "θ"` to display equations in a more readable format.

# Returns
The function returns an instance of the `ACOptimalPowerFlow` type, which includes the
following fields:
- `voltage`: The bus voltage magnitudes and angles.
- `power`: The variable allocated to store the active and reactive powers.
- `current`: The variable allocated to store the currents.
- `method`: The JuMP model, references to the variables, constraints, and objective.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
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
    verbose::Int64 = template.config.verbose
)
    branch = system.branch
    bus = system.bus
    gen = system.generator
    cbt = gen.capability
    ac = system.model.ac
    costP = gen.cost.active
    costQ = gen.cost.reactive

    checkSlackBus(system)
    model!(system, system.model.ac)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    if !ismissing(iteration)
        set_attribute(jump, "max_iter", iteration)
    end
    if !ismissing(tolerance)
        set_attribute(jump, "tol", tolerance)
    end
    if verbose == 2
        verbose = 3
    end
    jump.ext[:verbose] = verbose

    active = @variable(jump, active[i = 1:gen.number], base_name = active)
    reactive = @variable(jump, reactive[i = 1:gen.number], base_name = reactive)
    magnitude = @variable(jump, magnitude[i = 1:bus.number], base_name = magnitude)
    angle = @variable(jump, angle[i = 1:bus.number], base_name = angle)

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slack = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    quadratic = @expression(jump, QuadExpr())
    nonlinP = Dict{Int64, NonlinearExpr}()
    nonlinQ = Dict{Int64, NonlinearExpr}()
    actwise = Dict{Int64, VariableRef}()
    reactwise = Dict{Int64, VariableRef}()
    pieceP = Dict{Int64, Vector{ConstraintRef}}()
    pieceQ = Dict{Int64, Vector{ConstraintRef}}()
    cbtP = Dict{Int64, ConstraintRef}()
    cbtQ = Dict{Int64, ConstraintRef}()
    lower = Dict{Int64, ConstraintRef}()
    upper = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:gen.number
        if gen.layout.status[i] == 1
            if costP.model[i] == 2
                term = length(costP.polynomial[i])
                if term == 3
                    polynomialQuad(quadratic, active[i], costP.polynomial[i])
                elseif term == 2
                    polynomialAff(quadratic, active[i], costP.polynomial[i])
                elseif term == 1
                    add_to_expression!(quadratic, costP.polynomial[i][1])
                elseif term > 3
                    polynomialQuad(quadratic, active[i], costP.polynomial[i])
                    nonLinear(jump, active, costP.polynomial, term, nonlinP, i)
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            elseif costP.model[i] == 1
                point = size(costP.piecewise[i], 1)
                if point == 2
                    piecewiseAff(quadratic, active[i], costP.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, quadratic, actwise, i, "actwise")
                    addPiecewise(jump, active, actwise, pieceP, costP.piecewise, point, i)
                elseif point == 1
                    errorOnePoint(iterate(gen.label, i)[1][1])
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            end

            if costQ.model[i] == 2
                term = length(costQ.polynomial[i])
                if term == 3
                    polynomialQuad(quadratic, reactive[i], costQ.polynomial[i])
                elseif term == 2
                    polynomialAff(quadratic, reactive[i], costQ.polynomial[i])
                elseif term == 1
                    add_to_expression!(quadratic, costQ.polynomial[i][1])
                elseif term > 3
                    polynomialQuad(quadratic, reactive[i], costQ.polynomial[i])
                    nonLinear(jump, reactive, costQ.polynomial, term, nonlinQ, i)
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            elseif costQ.model[i] == 1
                point = size(costQ.piecewise[i], 1)
                if point == 2
                    piecewiseAff(quadratic, reactive[i], costQ.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, quadratic, reactwise, i, "reactwise")
                    addPiecewise(jump, reactive, reactwise, pieceQ, costQ.piecewise, point, i)
                elseif point == 1
                    errorOnePoint(iterate(gen.label, i)[1][1])
                else
                    infoObjective(iterate(gen.label, i)[1][1])
                end
            end
            capabilityCurve(system, jump, active, reactive, lower, upper, i)

            addCapability(jump, active, cbtP, cbt.minActive, cbt.maxActive, i)
            addCapability(jump, reactive, cbtQ, cbt.minReactive, cbt.maxReactive, i)
        else
            fix!(active[i], 0.0, cbtP, i)
            fix!(reactive[i], 0.0, cbtQ, i)
        end
    end

    @objective(
        jump, Min, quadratic +
        sum(nonlinP[i] for i in keys(nonlinP)) + sum(nonlinQ[i] for i in keys(nonlinQ))
    )

    voltgθ = Dict{Int64, ConstraintRef}()
    flowFrom = Dict{Int64, ConstraintRef}()
    flowTo = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            addAngle(system, jump, angle, voltgθ, i)
            addFlow(system, jump, magnitude, angle, flowFrom, flowTo, i)
        end
    end

    blcP = Dict{Int64, ConstraintRef}()
    blcQ = Dict{Int64, ConstraintRef}()
    voltgV = Dict{Int64, ConstraintRef}()
    @inbounds for i = 1:bus.number
        exprP = @expression(jump, magnitude[i] * real(ac.nodalMatrixTranspose[i, i]))
        exprQ = @expression(jump, -magnitude[i] * imag(ac.nodalMatrixTranspose[i, i]))

        for ptr in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            j = ac.nodalMatrix.rowval[ptr]
            if i != j
                Gij, Bij, sinθij, cosθij = GijBijθij(ac, angle, i, j, ptr)

                exprP += magnitude[j] * (Gij * cosθij + Bij * sinθij)
                exprQ += magnitude[j] * (Gij * sinθij - Bij * cosθij)
            end
        end

        addBalance(system, jump, active, magnitude, blcP, exprP, bus.demand.active, i)
        addBalance(system, jump, reactive, magnitude, blcQ, exprQ, bus.demand.reactive, i)
        addMagnitude(system, jump, magnitude, voltgV, i)
    end

    ACOptimalPowerFlow(
        Polar(
            copy(bus.voltage.magnitude),
            copy(bus.voltage.angle)
        ),
        ACPower(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(copy(gen.output.active), copy(gen.output.reactive))
        ),
        ACCurrent(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        ACOptimalPowerFlowMethod(
            jump,
            ACVariable(
                active,
                reactive,
                magnitude,
                angle,
                actwise,
                reactwise
            ),
            Constraint(
                PolarAngleRef(slack),
                CartesianRef(blcP, blcQ),
                PolarRef(voltgV, voltgθ),
                CartesianFlowRef(flowFrom, flowTo),
                CapabilityRef(cbtP, cbtQ, lower, upper),
                ACPiecewise(pieceP, pieceQ),
            ),
            Dual(
                PolarAngleDual(
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
                CartesianFlowDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                CapabilityDual(
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}(),
                    Dict{Int64, Float64}()
                ),
                ACPiecewiseDual(
                    Dict{Int64, Vector{Float64}}(),
                    Dict{Int64, Vector{Float64}}()
                )
            ),
            ACObjective(
                quadratic,
                ACNonlinear(
                    nonlinP,
                    nonlinQ
                )
            )
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)

The function solves the AC optimal power flow model, computing the active and reactive
power outputs of the generators, as well as the bus voltage magnitudes and angles.

# Updates
The calculated active and reactive powers, as well as voltage magnitudes and angles, are
stored in the `power.generator` and `voltage` fields of the `ACOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; verbose = 1)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    variable = analysis.method.variable
    constr = analysis.method.constraint
    dual = analysis.method.dual
    jump = analysis.method.jump
    verbose = analysis.method.jump.ext[:verbose]

    silentOptimal(jump, verbose)

    @inbounds for i = 1:system.bus.number
        set_start_value(variable.magnitude[i]::VariableRef, analysis.voltage.magnitude[i]::Float64)
        set_start_value(variable.angle[i]::VariableRef, analysis.voltage.angle[i]::Float64)
    end

    @inbounds for i = 1:system.generator.number
        set_start_value(variable.active[i]::VariableRef, analysis.power.generator.active[i])
        set_start_value(variable.reactive[i]::VariableRef, analysis.power.generator.reactive[i])
    end

    try
        setdual!(jump, constr.slack.angle, dual.slack.angle)
        setdual!(jump, constr.balance.active, dual.balance.active)
        setdual!(jump, constr.balance.reactive, dual.balance.reactive)
        setdual!(jump, constr.voltage.magnitude, dual.voltage.magnitude)
        setdual!(jump, constr.voltage.angle, dual.voltage.angle)
        setdual!(jump, constr.flow.from, dual.flow.from)
        setdual!(jump, constr.flow.to, dual.flow.to)
        setdual!(jump, constr.capability.active, dual.capability.active)
        setdual!(jump, constr.capability.reactive, dual.capability.reactive)
        setdual!(jump, constr.capability.lower, dual.capability.lower)
        setdual!(jump, constr.capability.upper, dual.capability.upper)
        setdual!(jump, constr.piecewise.active, dual.piecewise.active)
        setdual!(jump, constr.piecewise.reactive, dual.piecewise.reactive)
    catch
    end

    optimize!(jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = value(variable.magnitude[i]::VariableRef)
        analysis.voltage.angle[i] = value(variable.angle[i]::VariableRef)
    end

    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(variable.active[i]::VariableRef)
        analysis.power.generator.reactive[i] = value(variable.reactive[i]::VariableRef)
    end

    if has_duals(jump)
        dual!(jump, constr.slack.angle, dual.slack.angle)
        dual!(jump, constr.balance.active, dual.balance.active)
        dual!(jump, constr.balance.reactive, dual.balance.reactive)
        dual!(jump, constr.voltage.magnitude, dual.voltage.magnitude)
        dual!(jump, constr.voltage.angle, dual.voltage.angle)
        dual!(jump, constr.flow.from, dual.flow.from)
        dual!(jump, constr.flow.to, dual.flow.to)
        dual!(jump, constr.capability.active, dual.capability.active)
        dual!(jump, constr.capability.reactive, dual.capability.reactive)
        dual!(jump, constr.capability.lower, dual.capability.lower)
        dual!(jump, constr.capability.upper, dual.capability.upper)
        dual!(jump, constr.piecewise.active, dual.piecewise.active)
        dual!(jump, constr.piecewise.reactive, dual.piecewise.reactive)
    end

    printOptimal(jump, verbose)
end

function dual!(
    jump::JuMP.Model,
    constraint::Dict{Int64, ConstraintRef},
    dual::Dict{Int64, Float64}
)
    @inbounds for (i, value) in constraint
        if is_valid(jump, value)
            dual[i] = JuMP.dual(value::ConstraintRef)
        end
    end
end

function dual!(
    jump::JuMP.Model,
    constraint::Dict{Int64, Vector{ConstraintRef}},
    dual::Dict{Int64, Vector{Float64}}
)
    @inbounds for (i, value) in constraint
        n = length(value)
        dual[i] = fill(0.0, n)
        for j = 1:n
            if is_valid(jump, value[j])
                dual[i][j] = JuMP.dual(value[j]::ConstraintRef)
            end
        end
    end
end

function setdual!(
    jump::JuMP.Model,
    constraint::Dict{Int64, ConstraintRef},
    dual::Dict{Int64, Float64}
)
    @inbounds for (i, value) in dual
        if is_valid(jump, constraint[i])
            set_dual_start_value(constraint[i], value)
        end
    end
end

function setdual!(
    jump::JuMP.Model,
    constraint::Dict{Int64, Vector{ConstraintRef}},
    dual::Dict{Int64, Vector{Float64}}
)
    @inbounds for (i, value) in dual
        for j in eachindex(value)
            if is_valid(jump, constraint[i][j])
                set_dual_start_value(constraint[i][j], value[j])
            end
        end
    end
end

##### Quadratic Term in the Objective Function #####
function polynomialQuad(objective::QuadExpr, power::VariableRef, cost::Vector{Float64})
    add_to_expression!(objective, cost[end - 2], power, power)
    add_to_expression!(objective, cost[end - 1], power)
    add_to_expression!(objective, cost[end])
end

##### Linear Term in the Objective Function #####
function polynomialAff(objective::QuadExpr, power::VariableRef, cost::Vector{Float64})
    add_to_expression!(objective, cost[1], power)
    add_to_expression!(objective, cost[2])
end

##### Nonlinear Term in the Objective Function #####
function nonLinear(
    jump::JuMP.Model,
    variable::Vector{VariableRef},
    polynomial::OrderedDict{Int64, Vector{Float64}},
    term::Int64,
    nonlin::Dict{Int64, NonlinearExpr},
    i::Int64
)
    nonlin[i] = @expression(
        jump, sum(polynomial[i][term - degree] * variable[i]^degree
        for degree = term-1:-1:3)
    )
end

##### Piecewise Linear in the Objective Function #####
function piecewiseAff(objective::QuadExpr, power::VariableRef, piecewise::Matrix{Float64})
    slope = (piecewise[2, 2] - piecewise[1, 2]) / (piecewise[2, 1] - piecewise[1, 1])
    add_to_expression!(objective, slope, power)
    add_to_expression!(objective, piecewise[1, 2] - piecewise[1, 1] * slope)
end

##### Add Helper Variable #####
function addPowerwise(
    jump::JuMP.Model,
    objective::QuadExpr,
    powerwise::Dict{Int64, VariableRef},
    idx::Int64,
    name::String
)
    powerwise[idx] = @variable(jump, base_name = name * "[$idx]")
    add_to_expression!(objective, powerwise[idx])
end

##### Piecewise Constraints #####
function addPiecewise(
    jump::JuMP.Model,
    active::Vector{VariableRef},
    powerwise::Dict{Int64, JuMP.VariableRef},
    ref::Dict{Int64, Vector{ConstraintRef}},
    piecewise::OrderedDict{Int64, Matrix{Float64}},
    point::Int64,
    idx::Int64
)
    power = @view piecewise[idx][:, 1]
    cost = @view piecewise[idx][:, 2]
    ref[idx] = Array{ConstraintRef}(undef, point - 1)
    for j = 2:point
        slope = (cost[j] - cost[j-1]) / (power[j] - power[j-1])

        if slope == Inf
            errorInfSlope(iterate(generator.label, index)[1][1])
        end

        ref[idx][j-1] = @constraint(
            jump, slope * active[idx] - powerwise[idx] <= slope * power[j-1] - cost[j-1]
        )
    end
end

##### Add Capability Constraints #####
function addCapability(
    jump::JuMP.Model,
    variable::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    minPower::Vector{Float64},
    maxPower::Vector{Float64},
    idx::Int64
)
    if minPower[idx] != maxPower[idx]
        ref[idx] = @constraint(jump, minPower[idx] <= variable[idx] <= maxPower[idx])
    else
        fix!(variable[idx], minPower[idx], ref, idx)
    end
end

##### Voltage Magnitude Constraints #####
function addMagnitude(
    system::PowerSystem,
    jump::JuMP.Model,
    magnitude::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    idx::Int64
)
    voltg = system.bus.voltage

    if voltg.minMagnitude[idx] != voltg.maxMagnitude[idx]
        ref[idx] = @constraint(
            jump,
            voltg.minMagnitude[idx] <= magnitude[idx] <= voltg.maxMagnitude[idx]
    )
    else
        fix!(magnitude[idx], voltg.minMagnitude[idx], ref, idx)
    end
end

##### Angle Difference Constraints #####
function addAngle(
    system::PowerSystem,
    jump::JuMP.Model,
    angle::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    idx::Int64
)
    voltg = system.branch.voltage
    if voltg.minDiffAngle[idx] > -2*pi || voltg.maxDiffAngle[idx] < 2*pi
        i, j = fromto(system, idx)

        ref[idx] = @constraint(
            jump,
            voltg.minDiffAngle[idx] <= angle[i] - angle[j] <= voltg.maxDiffAngle[idx]
        )
    end
end

##### Balance Constraints #####
function addBalance(
    system::PowerSystem,
    jump::JuMP.Model,
    power::Vector{VariableRef},
    magnitude::Vector{VariableRef},
    ref::Dict{Int64, ConstraintRef},
    expr::NonlinearExpr,
    rhs::Vector{Float64},
    i::Int64
)
    if haskey(system.bus.supply.generator, i)
        ref[i] = @constraint(
            jump,
            sum(power[k] for k in system.bus.supply.generator[i]) - magnitude[i] * expr == rhs[i]
        )
    else
        ref[i] = @constraint(jump, - magnitude[i] * expr == rhs[i])
    end
end

##### Capability Curve Constraints #####
function capabilityCurve(
    system::PowerSystem,
    jump::JuMP.Model,
    active::Vector{VariableRef},
    reactive::Vector{VariableRef},
    lower::Dict{Int64, ConstraintRef},
    upper::Dict{Int64, ConstraintRef},
    i::Int64
)
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
            ΔPInv = 1 / (cbt.upActive[i] - cbt.lowActive[i])
            minLowP = cbt.minActive[i] - cbt.lowActive[i]
            maxLowP = cbt.maxActive[i] - cbt.lowActive[i]

            ΔQ = cbt.minUpReactive[i] - cbt.minLowReactive[i]
            minQminP = cbt.minLowReactive[i] + minLowP * ΔQ * ΔPInv
            minQmaxP = cbt.minLowReactive[i] + maxLowP * ΔQ * ΔPInv
            if  minQminP > cbt.minReactive[i] || minQmaxP > cbt.minReactive[i]
                deltaQ = cbt.maxLowReactive[i] - cbt.maxUpReactive[i]
                deltaP = cbt.upActive[i] - cbt.lowActive[i]
                b = deltaQ * cbt.lowActive[i] + deltaP * cbt.maxLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                upper[i] = @constraint(
                    jump,
                    scale * deltaQ * active[i] + scale * deltaP * reactive[i] <= scale * b
                )
            end

            ΔQ = cbt.maxUpReactive[i] - cbt.maxLowReactive[i]
            minQminP = cbt.maxLowReactive[i] + minLowP * ΔQ * ΔPInv
            minQmaxP = cbt.minLowReactive[i] + maxLowP * ΔQ * ΔPInv
            if minQminP < cbt.maxReactive[i] || minQmaxP < cbt.maxReactive[i]
                deltaQ = cbt.minUpReactive[i] - cbt.minLowReactive[i]
                deltaP = cbt.lowActive[i] - cbt.upActive[i]
                b = deltaQ * cbt.lowActive[i] + deltaP * cbt.minLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                lower[i] = @constraint(
                    jump,
                    scale * deltaQ * active[i] + scale * deltaP * reactive[i] <= scale * b
                )
            end
        end
    end
end

##### Flow Constraints #####
function addFlow(
    system::PowerSystem,
    jump::JuMP.Model,
    magnitude::Vector{VariableRef},
    angle::Vector{VariableRef},
    refFrom::Dict{Int64, ConstraintRef},
    refTo::Dict{Int64, ConstraintRef},
    idx::Int64
)
    branch = system.branch

    minFrom = branch.flow.minFromBus[idx]
    maxFrom = branch.flow.maxFromBus[idx]
    minTo = branch.flow.minToBus[idx]
    maxTo = branch.flow.maxToBus[idx]

    minFrom, maxFrom, from = checkLimit(system, minFrom, maxFrom, idx)
    minTo, maxTo, to = checkLimit(system, minTo, maxTo, idx)

    if from || to
        i, j = fromto(system, idx)

        Vi = magnitude[i]
        Vj = magnitude[j]
        θij = @expression(jump, angle[i] - angle[j] - branch.parameter.shiftAngle[idx])
        cosθij = cos(θij)
        sinθij = sin(θij)

        if branch.flow.type[idx] == 1
            if from
                expr = Pij(system, Vi, Vj, sinθij, cosθij, idx)
                refFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
            end
            if to
                expr = Pji(system, Vi, Vj, sinθij, cosθij, idx)
                refTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
            end
        elseif branch.flow.type[idx] == 2
            if from
                expr = Sij(system, Vi, Vj, sinθij, cosθij, idx)
                refFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
            end
            if to
                expr = Sji(system, Vi, Vj, sinθij, cosθij, idx)
                refTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
            end
        elseif branch.flow.type[idx] == 3
            if from
                expr = Sij2(system, Vi, Vj, sinθij, cosθij, idx)
                refFrom[idx] = @constraint(jump, minFrom^2 <= expr <= maxFrom^2)
            end
            if to
                expr = Sji2(system, Vi, Vj, sinθij, cosθij, idx)
                refTo[idx] = @constraint(jump, minTo^2 <= expr <= maxTo^2)
            end
        elseif branch.flow.type[idx] == 4
            if from
                expr = Iij(system, Vi, Vj, sinθij, cosθij, idx)
                refFrom[idx] = @constraint(jump, minFrom <= expr <= maxFrom)
            end
            if to
                expr = Iji(system, Vi, Vj, sinθij, cosθij, idx)
                refTo[idx] = @constraint(jump, minTo <= expr <= maxTo)
            end
        elseif branch.flow.type[idx] == 5
            if from
                expr = Iij2(system, Vi, Vj, sinθij, cosθij, idx)
                refFrom[idx] = @constraint(jump, minFrom^2 <= expr <= maxFrom^2)
            end
            if to
                expr = Iji2(system, Vi, Vj, sinθij, cosθij, idx)
                refTo[idx] = @constraint(jump, minTo^2 <= expr <= maxTo^2)
            end
        end
    end
end

##### Fix and Unfix Data #####
function fix!(
    variable::VariableRef,
    value::Float64,
    ref::Dict{Int64, ConstraintRef},
    idx::Int64
)
    fix(variable, value)
    ref[idx] = FixRef(variable)
end

function unfix!(jump::JuMP.Model,
    variable::VariableRef,
    ref::Dict{Int64, ConstraintRef},
    idx::Int64
)
    if haskey(ref, idx)
        if is_valid(jump, ref[idx])
            unfix(variable)
        end
        delete!(ref, idx)
    end
end

##### Remove Constraints #####
function remove!(
    jump::JuMP.Model,
    ref::Union{Dict{Int64, ConstraintRef}, Dict{Int64, VariableRef}},
    idx::Int64
)
    if haskey(ref, idx)
        if is_valid.(jump, ref[idx])
            delete(jump, ref[idx])
        end
        delete!(ref, index)
    end
end

function remove!(jump::JuMP.Model, ref::Dict{Int64, Vector{ConstraintRef}}, idx::Int64)
    if haskey(ref, idx)
        if all(is_valid.(jump, ref[idx]))
            delete.(jump, ref[idx])
        end
        delete!(ref, idx)
    end
end

##### Update Balance Constraints #####
function updateBalance(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    idx::Int64;
    active::Bool = false,
    reactive::Bool = false
)
    bus = system.bus
    ac = system.model.ac
    jump = analysis.method.jump
    constr = analysis.method.constraint
    variable = analysis.method.variable

    Vi = variable.magnitude[idx]
    if active
        if is_valid(jump, constr.balance.active[idx])
            remove!(jump, constr.balance.active, idx)
        end
        exprP = @expression(jump, Vi * real(ac.nodalMatrixTranspose[idx, idx]))
    end
    if reactive
        if is_valid(jump, constr.balance.reactive[idx])
            remove!(jump, constr.balance.reactive, idx)
        end
        exprQ = @expression(jump, -Vi * imag(ac.nodalMatrixTranspose[idx, idx]))
    end
    for ptr in ac.nodalMatrix.colptr[idx]:(ac.nodalMatrix.colptr[idx + 1] - 1)
        j = ac.nodalMatrix.rowval[ptr]
        if idx != j
            Gij, Bij, sinθij, cosθij = GijBijθij(ac, variable.angle, idx, j, ptr)

            if active
                exprP += variable.magnitude[j] * (Gij * cosθij + Bij * sinθij)
            end
            if reactive
                exprQ += variable.magnitude[j] * (Gij * sinθij - Bij * cosθij)
            end
        end
    end
    if active
        addBalance(
            system, jump, variable.active, variable.magnitude,
            constr.balance.active, exprP, bus.demand.active, idx
        )
    end
    if reactive
        addBalance(system, jump, variable.reactive, variable.magnitude,
        constr.balance.reactive, exprQ, bus.demand.reactive, idx
    )
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
    setInitialPoint!(source::Union{PowerSystem, Analysis}, target::ACOptimalPowerFlow)

The function can reset the initial point of the AC optimal power flow to values from the
`PowerSystem` type. It can also initialize the AC optimal power flow based on results from
the `Analysis` type, whether from an AC or DC analysis.

The function assigns the active and reactive power outputs of the generators, along with
the bus voltage magnitudes and angles in the `target` argument, using data from the
`source` argument. This allows users to initialize primal values as needed. Additionally,
if `source` is of type `ACOptimalPowerFlow`, the function also assigns initial dual values
in the `target` argument based on data from `source`.

If `source` comes from a DC analysis, only the active power outputs of the generators and
bus voltage angles are assigned in the `target` argument, while the reactive power outputs
of the generators and bus voltage magnitudes remain unchanged. Additionally, if `source`
is of type `DCOptimalPowerFlow`, the corresponding dual variable values are also assigned
in the `target` argument.

# Updates
This function may modify the `voltage`, `generator`, and `method.dual` fields of the
`ACOptimalPowerFlow` type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

updateBus!(system, analysis; label = 14, reactive = 0.13, magnitude = 1.2, angle = -0.17)

setInitialPoint!(system, analysis)
solve!(system, analysis)
```
"""
function setInitialPoint!(system::PowerSystem, analysis::ACOptimalPowerFlow)
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

function setInitialPoint!(source::AC, target::ACOptimalPowerFlow)
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

function setInitialPoint!(source::DC, target::ACOptimalPowerFlow)
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
    powerFlow!(system::PowerSystem, analysis::ACOptimalPowerFlow;
        iteration, tolerance, power, current, verbose)

The function serves as a wrapper for solving AC optimal power flow and includes the functions:
* [`solve!`](@ref solve!(::PowerSystem, ::ACOptimalPowerFlow)),
* [`power!`](@ref power!(::PowerSystem, ::ACPowerFlow)),
* [`current!`](@ref current!(::PowerSystem, ::AC)).

It computes the active and reactive power outputs of the generators, as well as the bus
voltage magnitudes and angles, with an option to compute the powers and currents related to
buses and branches.

# Keyword
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
powerFlow!(system, analysis; power = true, verbose = 1)
```
"""
function powerFlow!(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow;
    iteration::IntMiss = missing,
    tolerance::FltIntMiss = missing,
    power::Bool = false,
    current::Bool = false,
    verbose::Int64 = template.config.verbose
)
    if !ismissing(iteration)
        set_attribute(analysis.method.jump, "max_iter", iteration)
    end
    if !ismissing(tolerance)
        set_attribute(analysis.method.jump, "tol", tolerance)
    end
    if verbose == 2
        verbose = 3
    end
    analysis.method.jump.ext[:verbose] = verbose

    solve!(system, analysis)

    if power
        power!(system, analysis)
    end
    if current
        current!(system, analysis)
    end
end