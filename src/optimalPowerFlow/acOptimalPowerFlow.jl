"""
    acOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name, balance, limit,
        rating, capability)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the AC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `ac` field within the `PowerSystem` composite type has
not been created, the function will initiate an update automatically.

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/manual/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism;
- `name`: used to manage the creation of string names.

Moreover, we have included keywords that regulate the usage of different types of constraints:
- `balance`: controls the equality constraints that relate to the active and reactive power balance equations;
- `limit`: controls the inequality constraints that relate to the voltage magnitude and angle differences between buses;
- `rating`: controls the inequality constraints that relate to the long-term rating of branches;
- `capability`: controls the inequality constraints that relate to the active and reactive power generator outputs.

By default, all of these keywords are set to `true` and are of the `Bool` type.

# JuMP
The JuliaGrid builds the AC optimal power flow around the JuMP package and supports commonly
used solvers. For more information, refer to the
[JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Returns
The function returns an instance of the `ACOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `jump`: the JuMP model;
- `constraint`: holds the constraint references to the JuMP model.

# Examples
Create the complete AC optimal power flow model:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
```

Create the AC optimal power flow model without `rating` constraints:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer; rating = false)
```
"""
function acOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true,
    balance::Bool = true, limit::Bool = true,
    rating::Bool = true,  capability::Bool = true)

    if isempty(system.model.ac.nodalMatrix)
        acModel!(system)
    end

    branch = system.branch
    bus = system.bus
    generator = system.generator

    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    @variable(jump, active[i = 1:generator.number])
    @variable(jump, reactive[i = 1:generator.number])
    @variable(jump, magnitude[i = 1:bus.number])
    @variable(jump, angle[i = 1:bus.number])

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slackAngle = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    fix(magnitude[bus.layout.slack], bus.voltage.magnitude[bus.layout.slack])
    slackMagnitude = Dict(bus.layout.slack => FixRef(magnitude[bus.layout.slack]))

    objExpr = QuadExpr()
    nonLinExpr = Vector{NonlinearExpression}(undef, 0)
    helperActive = Dict{Int64, VariableRef}()
    helperReactive = Dict{Int64, VariableRef}()
    piecewiseActive = Dict{Int64, Array{JuMP.ConstraintRef,1}}()
    piecewiseReactive = Dict{Int64, Array{JuMP.ConstraintRef,1}}()
    capabilityActive = Dict{Int64, JuMP.ConstraintRef}()
    capabilityReactive = Dict{Int64, JuMP.ConstraintRef}()
    lower = Dict{Int64, JuMP.ConstraintRef}()
    upper = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1
            if costActive.model[i] == 2
                term = length(costActive.polynomial[i])
                if term == 3
                    objExpr = polynomialQuadratic(objExpr, active[i], costActive.polynomial[i])
                elseif term == 2
                    objExpr = polynomialLinear(objExpr, active[i], costActive.polynomial[i])
                elseif term == 1
                    add_to_expression!(objExpr, costActive.polynomial[i][1])
                elseif term > 3
                    jump, objExpr, nonLinExpr = polynomialNonlinear(jump, objExpr, nonLinExpr, costActive.polynomial[i], active[i], term)
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif costActive.model[i] == 1
                point = size(costActive.piecewise[i], 1)
                if point == 2
                    objExpr = piecewiseLinear(objExpr, active[i], costActive.piecewise[i])
                elseif point > 2
                    jump, objExpr, helperActive = addHelper(jump, objExpr, helperActive, i)
                    piecewiseActive = addPiecewise(jump, helperActive[i], piecewiseActive, costActive.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end

            if costReactive.model[i] == 2
                term = length(costReactive.polynomial[i])
                if term == 3
                    objExpr = polynomialQuadratic(objExpr, reactive[i], costReactive.polynomial[i])
                elseif term == 2
                    objExpr = polynomialLinear(objExpr, reactive[i], costReactive.polynomial[i])
                elseif term == 1
                    add_to_expression!(objExpr, costReactive.polynomial[i][1])
                elseif term > 3
                    jump, objExpr, nonLinExpr = polynomialNonlinear(jump, objExpr, nonLinExpr, costReactive.polynomial[i], reactive[i], term)
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif costReactive.model[i] == 1
                point = size(costReactive.piecewise[i], 1)
                if point == 2
                    objExpr = piecewiseLinear(objExpr, reactive[i], costReactive.piecewise[i])
                elseif point > 2
                    jump, objExpr, helperReactive = addHelper(jump, objExpr, helperReactive, i)
                    piecewiseReactive = addPiecewise(jump, helperReactive[i], piecewiseReactive, costReactive.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end
            jump, lower, upper = capabilityCurve(system, jump, active, reactive, lower, upper, i)

            jump, capabilityActive = addCapability(jump, active, capabilityActive, generator.capability.minActive, generator.capability.maxActive, i)
            jump, capabilityReactive = addCapability(jump, reactive, capabilityReactive, generator.capability.minReactive, generator.capability.maxReactive, i)
        else
            fix!(active, 0.0, capabilityActive, i)
            fix!(reactive, 0.0, capabilityReactive, i)
        end
    end

    numberNonLin = length(nonLinExpr)
    if numberNonLin == 0
        @objective(jump, Min, objExpr)
    elseif numberNonLin == 1
        @NLobjective(jump, Min, objExpr + nonLinExpr[1])
    else
        @NLobjective(jump, Min, objExpr + sum(nonLinExpr[i] for i = 1:numberNonLin))
    end

    voltageAngle = Dict{Int64, JuMP.ConstraintRef}()
    flowFrom = Dict{Int64, JuMP.ConstraintRef}()
    flowTo = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            jump, voltageAngle = addDiffAngle(jump, angle, voltageAngle, branch, i)

            if branch.flow.longTerm[i] ≉  0 && branch.flow.longTerm[i] < 10^16
                from = branch.layout.from[i]
                to = branch.layout.to[i]

                Vi = magnitude[from]
                Vj = magnitude[to]
                θij = angle[from] - angle[to]
                add_to_expression!(θij, -branch.parameter.shiftAngle[i])

                gij = real(system.model.ac.admittance[i])
                bij = imag(system.model.ac.admittance[i])
                gsi = 0.5 * branch.parameter.conductance[i]
                bsi = 0.5 * branch.parameter.susceptance[i]
                g = gij + gsi
                b = bij + bsi
                βij = 1 / branch.parameter.turnsRatio[i]

                if branch.flow.type[i] == 1 || branch.flow.type[i] == 3
                    Aij = βij^4 * (g^2 + b^2)
                    Bij = βij^2 * (gij^2 + bij^2)
                    Cij = βij^3 * (gij * g + bij * b)
                    Dij = βij^3 * (bij * g - gij * b)

                    Aji = g^2 + b^2
                    Cji = βij * (gij * g + bij * b)
                    Dji = βij * (gij * b - bij * g)
                end

                if branch.flow.type[i] == 1
                    flowFrom[i] = @NLconstraint(jump, Aij * Vi^4 + Bij * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (Cij * cos(θij) + Dij * sin(θij)) <= branch.flow.longTerm[i]^2)
                    flowTo[i] = @NLconstraint(jump, Aji * Vj^4 + Bij * Vi^2 * Vj^2 - 2 * Vi * Vj^3 * (Cji * cos(θij) + Dji * sin(θij)) <= branch.flow.longTerm[i]^2)
                end
                if branch.flow.type[i] == 2
                    flowFrom[i] = @NLconstraint(jump, βij^2 * g * Vi^2 - βij * Vi * Vj * (gij * cos(θij) + bij * sin(θij)) <= branch.flow.longTerm[i])
                    flowTo[i] = @NLconstraint(jump, g * Vj^2 - βij * Vi * Vj * (gij * cos(θij) - bij * sin(θij)) <= branch.flow.longTerm[i])
                end
                if branch.flow.type[i] == 3
                    flowFrom[i] = @NLconstraint(jump, Aij * Vi^2 + Bij * Vj^2 - 2 * Vi * Vj * (Cij * cos(θij) + Dij * sin(θij)) <= branch.flow.longTerm[i]^2)
                    flowTo[i] = @NLconstraint(jump, Aji * Vj^2 + Bij * Vi^2 - 2 * Vi * Vj * (Cji * cos(θij) + Dji * sin(θij)) <= branch.flow.longTerm[i]^2)
                end
            end
        end
    end

    balanceActive = Dict{Int64, JuMP.ConstraintRef}()
    balanceReactive = Dict{Int64, JuMP.ConstraintRef}()
    voltageMagnitude = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:bus.number
        n = system.model.ac.nodalMatrix.colptr[i + 1] - system.model.ac.nodalMatrix.colptr[i]
        Gij = Vector{AffExpr}(undef, n)
        Bij = Vector{AffExpr}(undef, n)
        θij = Vector{AffExpr}(undef, n)

        for (k, j) in enumerate(system.model.ac.nodalMatrix.colptr[i]:(system.model.ac.nodalMatrix.colptr[i + 1] - 1))
            row = system.model.ac.nodalMatrix.rowval[j]
            Gij[k] = magnitude[row] * real(system.model.ac.nodalMatrixTranspose.nzval[j])
            Bij[k] = magnitude[row] * imag(system.model.ac.nodalMatrixTranspose.nzval[j])
            θij[k] = angle[i] - angle[row]
        end

        balanceActive[i] = @NLconstraint(jump, bus.demand.active[i] - sum(active[k] for k in system.bus.supply.generator[i]) + magnitude[i] * sum(Gij[j] * cos(θij[j]) + Bij[j] * sin(θij[j]) for j = 1:n) == 0)
        balanceReactive[i] = @NLconstraint(jump, bus.demand.reactive[i] - sum(reactive[k] for k in system.bus.supply.generator[i]) + magnitude[i] * sum(Gij[j] * sin(θij[j]) - Bij[j] * cos(θij[j]) for j = 1:n) == 0)

        jump, voltageMagnitude = addLimitMagnitude(jump, magnitude, voltageMagnitude, bus.voltage.minMagnitude, bus.voltage.maxMagnitude, i)
    end

    return ACOptimalPowerFlow(
        Polar(
            copy(bus.voltage.magnitude),
            copy(bus.voltage.angle)
        ),
        Power(
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(Float64[], Float64[]),
            Cartesian(copy(generator.output.active), copy(generator.output.reactive))
        ),
        Current(
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[]),
            Polar(Float64[], Float64[])
        ),
        jump,
        Constraint(
            PolarRef(slackMagnitude, slackAngle),
            CartesianRef(balanceActive, balanceReactive),
            PolarRef(voltageMagnitude, voltageAngle),
            CartesianFlowRef(flowFrom, flowTo),
            CapabilityRef(capabilityActive, capabilityReactive, lower, upper),
            ACPiecewise(piecewiseActive, piecewiseReactive, helperActive, helperReactive),
        )
    )
end

"""
    solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)

The function finds the AC optimal power flow solution and calculate the bus voltage
magnitudes and angles, and output active and reactive powers of each generators.

The calculated voltage magnitudes and angles and active and reactive powers are then stored
in the variables of the `voltage` and `power` fields of the `ACOptimalPowerFlow` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    magnitude = analysis.jump[:magnitude]::Vector{JuMP.VariableRef}
    angle = analysis.jump[:angle]::Vector{JuMP.VariableRef}
    active = analysis.jump[:active]::Vector{JuMP.VariableRef}
    reactive = analysis.jump[:reactive]::Vector{JuMP.VariableRef}

    @inbounds for i = 1:system.bus.number
        variable = magnitude[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.voltage.magnitude[i])
        end

        variable = angle[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.voltage.angle[i])
        end
    end
    @inbounds for i = 1:system.generator.number
        variable = active[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.power.generator.active[i])
        end

        variable = reactive[i]::JuMP.VariableRef
        if isnothing(JuMP.start_value(variable))
            JuMP.set_start_value(variable, analysis.power.generator.reactive[i])
        end
    end

    JuMP.optimize!(analysis.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = value(magnitude[i]::JuMP.VariableRef)
        analysis.voltage.angle[i] = value(angle[i]::JuMP.VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(active[i]::JuMP.VariableRef)
        analysis.power.generator.reactive[i] = value(reactive[i]::JuMP.VariableRef)
    end
end

function capabilityCurve(system::PowerSystem, jump::JuMP.Model, active::Vector{VariableRef}, reactive::Vector{VariableRef}, lower::Dict{Int64, JuMP.ConstraintRef}, upper::Dict{Int64, JuMP.ConstraintRef}, i::Int64)
    capability = system.generator.capability

    if capability.lowActive[i] != 0.0 || capability.upActive[i] != 0.0
        if capability.lowActive[i] >= capability.upActive[i]
            throw(ErrorException("Capability curve is is not correctly defined."))
        end
        if capability.maxLowReactive[i] <= capability.minLowReactive[i] && capability.maxUpReactive[i] <= capability.minUpReactive[i]
            throw(ErrorException("Capability curve is is not correctly defined."))
        end

        if capability.lowActive[i] != capability.upActive[i]
            deltaActiveInv = 1 / (capability.upActive[i] - capability.lowActive[i])
            minLowActive = capability.minActive[i] - capability.lowActive[i]
            maxLowActive = capability.maxActive[i] - capability.lowActive[i]

            deltaReactive = capability.minUpReactive[i] - capability.minLowReactive[i]
            minReactiveMinActive = capability.minLowReactive[i] + minLowActive * deltaReactive * deltaActiveInv
            minReactiveMaxActive = capability.minLowReactive[i] + maxLowActive * deltaReactive * deltaActiveInv
            if  minReactiveMinActive > capability.minReactive[i] || minReactiveMaxActive > capability.minReactive[i]
                deltaQ = capability.maxLowReactive[i] - capability.maxUpReactive[i]
                deltaP = capability.upActive[i] - capability.lowActive[i]
                b = deltaQ * capability.lowActive[i] + deltaP * capability.maxLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                upper[i] = @constraint(jump, scale * deltaQ * active[i] + scale * deltaP * reactive[i] <= scale * b)
            end

            deltaReactive = capability.maxUpReactive[i] - capability.maxLowReactive[i]
            maxReactiveMinActive = capability.maxLowReactive[i] + minLowActive * deltaReactive * deltaActiveInv
            maxReactiveMaxActive = capability.minLowReactive[i] + maxLowActive * deltaReactive * deltaActiveInv
            if maxReactiveMinActive < capability.maxReactive[i] || maxReactiveMaxActive < capability.maxReactive[i]
                deltaQ = capability.minUpReactive[i] - capability.minLowReactive[i]
                deltaP = capability.lowActive[i] - capability.upActive[i]
                b = deltaQ * capability.lowActive[i] + deltaP * capability.minLowReactive[i]
                scale = 1 / sqrt(deltaQ^2 + deltaP^2)

                lower[i] = @constraint(jump, scale * deltaQ * active[i] + scale * deltaP * reactive[i] <= scale * b)
            end
        end
    end

    return jump, lower, upper
end

######### Voltage Magnitude Constraints ##########
function addLimitMagnitude(jump::JuMP.Model, variable::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, minMagnitude::Array{Float64, 1}, maxMagnitude::Array{Float64, 1}, index::Int64)
    if minMagnitude[index] != maxMagnitude[index]
        ref[index] = @constraint(jump, minMagnitude[index] <= variable[index] <= maxMagnitude[index])
    else
        fix!(variable, 0.0, ref, index)
    end

    return jump, ref
end

function polynomialLinear(objExpr::QuadExpr, power::VariableRef, cost::Array{Float64,1})
    add_to_expression!(objExpr, cost[1], power)
    add_to_expression!(objExpr, cost[2])

    return objExpr
end

function polynomialQuadratic(objExpr::QuadExpr, power::VariableRef, cost::Array{Float64,1})
    add_to_expression!(objExpr, cost[1], power, power)
    add_to_expression!(objExpr, cost[2], power)
    add_to_expression!(objExpr, cost[3])

    return objExpr
end

function polynomialNonlinear(jump::JuMP.Model, objExpr::QuadExpr, nonlinearExpr::Vector{NonlinearExpression}, cost::Array{Float64,1}, power::VariableRef, term::Int64)
    add_to_expression!(objExpr, cost[end - 2], power, power)
    add_to_expression!(objExpr, cost[end - 1], power)
    add_to_expression!(objExpr, cost[end])
    push!(nonlinearExpr, @NLexpression(jump, sum(cost[term - degree] * power^degree for degree = term-1:-1:3)))

    return jump, objExpr, nonlinearExpr
end

function piecewiseLinear(objExpr::QuadExpr, power::VariableRef, piecewise::Array{Float64,2})
    slope = (piecewise[2, 2] - piecewise[1, 2]) / (piecewise[2, 1] - piecewise[1, 1])
    add_to_expression!(objExpr, slope, power)
    add_to_expression!(objExpr, piecewise[1, 2] - piecewise[1, 1] * slope)

    return objExpr
end

function addHelper(jump::JuMP.Model, objExpr::QuadExpr, helper::Dict{Int64, VariableRef}, index::Int64)
    helper[index] = @variable(jump, base_name = "helper[$index]")
    add_to_expression!(objExpr, helper[index])

    return jump, objExpr, helper
end

function addPiecewise(jump::JuMP.Model, helper::VariableRef, ref::Dict{Int64, Array{JuMP.ConstraintRef,1}}, piecewise::Array{Float64,2}, point::Int64, index::Int64)
    power = @view piecewise[:, 1]
    cost = @view piecewise[:, 2]
    ref[index] = Array{JuMP.ConstraintRef}(undef, point - 1)
    for j = 2:point
        slope = (cost[j] - cost[j-1]) / (power[j] - power[j-1])
        if slope == Inf
            throw(ErrorException("The piecewise linear cost function's slope of the generator indexed $i has infinite value."))
        end
        ref[index][j-1] = @constraint(jump, slope * jump[:active][index] - helper <= slope * power[j-1] - cost[j-1])
    end

    return ref
end

######### Fix Data ##########
function fix!(variable::Array{JuMP.VariableRef, 1}, value::Float64, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    JuMP.fix(variable[index], value)
    ref[index] = JuMP.FixRef(variable[index])
end

######## Capability Constraints ##########
function addCapability(jump::JuMP.Model, variable::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, minPower::Array{Float64, 1}, maxPower::Array{Float64, 1}, index::Int64)
    if minPower[index] != maxPower[index]
        ref[index] = @constraint(jump, minPower[index] <= variable[index] <= maxPower[index])
    else
        fix!(variable, 0.0, ref, index)
    end

    return jump, ref
end

######### Angle Difference Constraints ##########
function addDiffAngle(jump::JuMP.Model, angle::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, branch::Branch, index::Int64)
    if branch.voltage.minDiffAngle[index] > -2*pi || branch.voltage.maxDiffAngle[index] < 2*pi
        ref[index] = @constraint(jump, branch.voltage.minDiffAngle[index] <= angle[branch.layout.from[index]] - angle[branch.layout.to[index]] <= branch.voltage.maxDiffAngle[index])
    end

    return jump, ref
end