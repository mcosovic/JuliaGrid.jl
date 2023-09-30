"""
    acOptimalPowerFlow(system::PowerSystem, optimizer; bridge, name)

The function takes the `PowerSystem` composite type as input to establish the structure for
solving the AC optimal power flow. The `optimizer` argument is also required to create and
solve the optimization problem. If the `ac` field within the `PowerSystem` composite type has
not been created, the function will initiate an update automatically.

Additionally, the `optimizer` argument is a necessary component for formulating and solving the
optimization problem. Specifically, JuliaGrid constructs the AC optimal power flow using the
JuMP package and provides support for commonly employed solvers. For more detailed information,
please consult the [JuMP documenatation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
JuliaGrid offers the ability to manipulate the `jump` model based on the guidelines provided
in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/reference/models/). However,
certain configurations may require different method calls, such as:
- `bridge`: used to manage the bridging mechanism;
- `name`: used to manage the creation of string names.
By default, these keyword settings are configured as `true`.

# Returns
The function returns an instance of the `ACOptimalPowerFlow` type, which includes the following
fields:
- `voltage`: the bus voltage magnitudes and angles;
- `power`: the variable allocated to store the active and reactive powers;
- `current`: the variable allocated to store the currents;
- `jump`: the JuMP model;
- `variable`: holds the variable references to the JuMP model;
- `constraint`: holds the constraint references to the JuMP model;
- `objective`: holds the objective expression of the JuMP model;
- `uuid`: a universally unique identifier associated with the `PowerSystem` composite type.

# Examples
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
```
"""
function acOptimalPowerFlow(system::PowerSystem, (@nospecialize optimizerFactory);
    bridge::Bool = true, name::Bool = true)

    branch = system.branch
    bus = system.bus
    generator = system.generator
    ac = system.model.ac
    costActive = generator.cost.active
    costReactive = generator.cost.reactive

    if bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
    if isempty(system.model.ac.nodalMatrix)
        acModel!(system)
    end

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)
    set_string_names_on_creation(jump, name)

    active = @variable(jump, active[i = 1:generator.number])
    reactive = @variable(jump, reactive[i = 1:generator.number])
    magnitude = @variable(jump, magnitude[i = 1:bus.number])
    angle = @variable(jump, angle[i = 1:bus.number])

    fix(angle[bus.layout.slack], bus.voltage.angle[bus.layout.slack])
    slack = Dict(bus.layout.slack => FixRef(angle[bus.layout.slack]))

    quadratic = @expression(jump, QuadExpr())
    nonLinActive = Dict{Int64, JuMP.NonlinearExpr}()
    nonLinReactive = Dict{Int64, JuMP.NonlinearExpr}()
    actwise = Dict{Int64, VariableRef}()
    reactwise = Dict{Int64, VariableRef}()
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
                    polynomialQuadratic(quadratic, active[i], costActive.polynomial[i])
                elseif term == 2
                    polynomialLinear(quadratic, active[i], costActive.polynomial[i])
                elseif term == 1
                    add_to_expression!(quadratic, costActive.polynomial[i][1])
                elseif term > 3
                    polynomialQuadratic(quadratic, active[i], costActive.polynomial[i])
                    nonLinActive[i] = @expression(jump, sum(costActive.polynomial[i][term - degree] * active[i]^degree for degree = term-1:-1:3))
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif costActive.model[i] == 1
                point = size(costActive.piecewise[i], 1)
                if point == 2
                    piecewiseLinear(quadratic, active[i], costActive.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, quadratic, actwise, i; name = "actwise")
                    addPiecewise(jump, active[i], actwise[i], piecewiseActive, costActive.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end

            if costReactive.model[i] == 2
                term = length(costReactive.polynomial[i])
                if term == 3
                    polynomialQuadratic(quadratic, reactive[i], costReactive.polynomial[i])
                elseif term == 2
                    polynomialLinear(quadratic, reactive[i], costReactive.polynomial[i])
                elseif term == 1
                    add_to_expression!(quadratic, costReactive.polynomial[i][1])
                elseif term > 3
                    polynomialQuadratic(quadratic, reactive[i], costReactive.polynomial[i])
                    nonLinReactive[i] =  @expression(jump, sum(costReactive.polynomial[i][term - degree] * reactive[i]^degree for degree = term-1:-1:3))
                else
                    @info("The generator indexed $i has an undefined polynomial cost function, which is not included in the objective.")
                end
            elseif costReactive.model[i] == 1
                point = size(costReactive.piecewise[i], 1)
                if point == 2
                    piecewiseLinear(quadratic, reactive[i], costReactive.piecewise[i])
                elseif point > 2
                    addPowerwise(jump, quadratic, reactwise, i; name = "reactwise")
                    addPiecewise(jump, reactive[i], reactwise[i], piecewiseReactive, costReactive.piecewise[i], point, i)
                elseif point == 1
                    throw(ErrorException("The generator indexed $i has a piecewise linear cost function with only one defined point."))
                else
                    @info("The generator indexed $i has an undefined piecewise linear cost function, which is not included in the objective.")
                end
            end
            capabilityCurve(system, jump, active, reactive, lower, upper, i)

            addCapability(jump, active[i], capabilityActive, generator.capability.minActive, generator.capability.maxActive, i)
            addCapability(jump, reactive[i], capabilityReactive, generator.capability.minReactive, generator.capability.maxReactive, i)
        else
            fix!(active[i], 0.0, capabilityActive, i)
            fix!(reactive[i], 0.0, capabilityReactive, i)
        end
    end

    @objective(jump, Min, quadratic + sum(nonLinActive[i] for i in keys(nonLinActive)) + sum(nonLinReactive[i] for i in keys(nonLinReactive)))

    voltageAngle = Dict{Int64, JuMP.ConstraintRef}()
    flowFrom = Dict{Int64, JuMP.ConstraintRef}()
    flowTo = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            addAngle(system, jump, angle, voltageAngle, i)
            addFlow(system, jump, magnitude, angle, flowFrom, flowTo, i)
        end
    end

    balanceActive = Dict{Int64, JuMP.ConstraintRef}()
    balanceReactive = Dict{Int64, JuMP.ConstraintRef}()
    voltageMagnitude = Dict{Int64, JuMP.ConstraintRef}()
    @inbounds for i = 1:bus.number
        activeExpr = @expression(jump, magnitude[i] * real(ac.nodalMatrixTranspose[i, i]))
        reactiveExpr = @expression(jump, -magnitude[i] * imag(ac.nodalMatrixTranspose[i, i]))

        for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
            row = ac.nodalMatrix.rowval[j]
            if i != row
                θ = @expression(jump, angle[i] - angle[row])
                cosθ = @expression(jump, cos(θ))
                sinθ = @expression(jump, sin(θ))
                Gij = real(ac.nodalMatrixTranspose.nzval[j])
                Bij = imag(ac.nodalMatrixTranspose.nzval[j])

                if Gij != 0 && Bij !=0
                    activeExpr = @expression(jump, activeExpr + magnitude[row] * (Gij * cosθ + Bij * sinθ))
                    reactiveExpr = @expression(jump, reactiveExpr + magnitude[row] * (Gij * sinθ - Bij * cosθ))
                elseif Gij != 0
                    activeExpr = @expression(jump, activeExpr + magnitude[row] * Gij * cosθ)
                    reactiveExpr = @expression(jump, reactiveExpr + magnitude[row] * Gij * sinθ)
                elseif Bij != 0
                    activeExpr = @expression(jump, activeExpr + magnitude[row] * Bij * sinθ)
                    reactiveExpr = @expression(jump, reactiveExpr - magnitude[row] * Bij * cosθ)
                end
            end
        end
        balanceActive[i] = @constraint(jump, sum(active[k] for k in bus.supply.generator[i]) - magnitude[i] * activeExpr == bus.demand.active[i])
        balanceReactive[i] = @constraint(jump, sum(reactive[k] for k in bus.supply.generator[i]) - magnitude[i] * reactiveExpr == bus.demand.reactive[i])

        addMagnitude(system, jump, magnitude, voltageMagnitude, i)
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
        ACVariable(
            active,
            reactive,
            magnitude,
            angle,
            actwise,
            reactwise),
        Constraint(
            PolarAngleRef(slack),
            CartesianRef(balanceActive, balanceReactive),
            PolarRef(voltageMagnitude, voltageAngle),
            CartesianFlowRef(flowFrom, flowTo),
            CapabilityRef(capabilityActive, capabilityReactive, lower, upper),
            ACPiecewise(piecewiseActive, piecewiseReactive),
        ),
        ACObjective(
            quadratic,
            ACNonlinear(
                nonLinActive,
                nonLinReactive
            )
        ),
        system.uuid
    )
end

"""
    solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)

The function determines the optimal power flow for AC systems, computing the magnitudes and
angles of bus voltages, as well as generating active and reactive power values for each generator.

# Updates
The calculated voltage magnitudes and angles and active and reactive powers are then stored
in the variables of the `voltage` and `power.generator` fields of the `ACOptimalPowerFlow`
composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
```
"""
function solve!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    variable = analysis.variable

    @inbounds for i = 1:system.bus.number
        JuMP.set_start_value(variable.magnitude[i]::JuMP.VariableRef, analysis.voltage.magnitude[i])
        JuMP.set_start_value(variable.angle[i]::JuMP.VariableRef, analysis.voltage.angle[i])
    end
    @inbounds for i = 1:system.generator.number
        JuMP.set_start_value(variable.active[i]::JuMP.VariableRef, analysis.power.generator.active[i])
        JuMP.set_start_value(variable.reactive[i]::JuMP.VariableRef, analysis.power.generator.reactive[i])
    end

    JuMP.optimize!(analysis.jump)

    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = value(variable.magnitude[i]::JuMP.VariableRef)
        analysis.voltage.angle[i] = value(variable.angle[i]::JuMP.VariableRef)
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = value(variable.active[i]::JuMP.VariableRef)
        analysis.power.generator.reactive[i] = value(variable.reactive[i]::JuMP.VariableRef)
    end
end

######## Quadratic Term in the Objective Function ##########
function polynomialQuadratic(objective::QuadExpr, power::VariableRef, cost::Array{Float64,1})
    add_to_expression!(objective, cost[end - 2], power, power)
    add_to_expression!(objective, cost[end - 1], power)
    add_to_expression!(objective, cost[end])

    return objective
end

######## Linear Term in the Objective Function ##########
function polynomialLinear(objective::QuadExpr, power::VariableRef, cost::Array{Float64,1})
    add_to_expression!(objective, cost[1], power)
    add_to_expression!(objective, cost[2])

    return objective
end

######## Linear Piecewise in the Objective Function ##########
function piecewiseLinear(objective::QuadExpr, power::VariableRef, piecewise::Array{Float64,2})
    slope = (piecewise[2, 2] - piecewise[1, 2]) / (piecewise[2, 1] - piecewise[1, 1])
    add_to_expression!(objective, slope, power)
    add_to_expression!(objective, piecewise[1, 2] - piecewise[1, 1] * slope)

    return objective
end

######## Add Helper Variable ##########
function addPowerwise(jump::JuMP.Model, objective::QuadExpr, powerwise::Dict{Int64, VariableRef}, index::Int64; name)
    powerwise[index] = @variable(jump, base_name = "$name[$index]")
    add_to_expression!(objective, powerwise[index])

    return jump, objective, powerwise
end

######## Piecewise Constraints ##########
function addPiecewise(jump::JuMP.Model, active::VariableRef, powerwise::VariableRef, ref::Dict{Int64, Array{JuMP.ConstraintRef,1}}, piecewise::Array{Float64,2}, point::Int64, index::Int64)
    power = @view piecewise[:, 1]
    cost = @view piecewise[:, 2]
    ref[index] = Array{JuMP.ConstraintRef}(undef, point - 1)
    for j = 2:point
        slope = (cost[j] - cost[j-1]) / (power[j] - power[j-1])
        if slope == Inf
            throw(ErrorException("The piecewise linear cost function's slope of the generator indexed $i has infinite value."))
        end
        ref[index][j-1] = @constraint(jump, slope * active - powerwise <= slope * power[j-1] - cost[j-1])
    end

    return jump, ref
end

######## Add Capability Constraints ##########
function addCapability(jump::JuMP.Model, variable::VariableRef, ref::Dict{Int64, JuMP.ConstraintRef}, minPower::Array{Float64,1}, maxPower::Array{Float64,1}, index::Int64)
    if minPower[index] != maxPower[index]
        ref[index] = @constraint(jump, minPower[index] <= variable <= maxPower[index])
    else
        fix!(variable, minPower[index], ref, index)
    end

    return jump, ref
end


######### Voltage Magnitude Constraints ##########
function addMagnitude(system::PowerSystem, jump::JuMP.Model, magnitude::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    bus = system.bus
    if bus.voltage.minMagnitude[index] != bus.voltage.maxMagnitude[index]
        ref[index] = @constraint(jump, bus.voltage.minMagnitude[index] <= magnitude[index] <= bus.voltage.maxMagnitude[index])
    else
        fix!(magnitude[index], bus.voltage.minMagnitude[index], ref, index)
    end

    return jump, ref
end

######### Angle Difference Constraints ##########
function addAngle(system::PowerSystem, jump::JuMP.Model, angle::Vector{VariableRef}, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    branch = system.branch
    if branch.voltage.minDiffAngle[index] > -2*pi || branch.voltage.maxDiffAngle[index] < 2*pi
        ref[index] = @constraint(jump, branch.voltage.minDiffAngle[index] <= angle[branch.layout.from[index]] - angle[branch.layout.to[index]] <= branch.voltage.maxDiffAngle[index])
    end

    return jump, ref
end

######### Capability Curve Constraints ##########
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

######### Flow Constraints ##########
function addFlow(system::PowerSystem, jump::JuMP.Model, magnitude::Vector{VariableRef}, angle::Vector{VariableRef}, refFrom::Dict{Int64, JuMP.ConstraintRef}, refTo::Dict{Int64, JuMP.ConstraintRef}, i::Int64)
    branch = system.branch
    ac = system.model.ac

    if branch.flow.longTerm[i] ≉  0 && branch.flow.longTerm[i] < 10^16
        from = branch.layout.from[i]
        to = branch.layout.to[i]

        Vi = magnitude[from]
        Vj = magnitude[to]
        θ = @expression(jump, angle[from] - angle[to] - branch.parameter.shiftAngle[i])
        cosθ = @expression(jump, cos(θ))
        sinθ = @expression(jump, sin(θ))

        gij = real(ac.admittance[i])
        bij = imag(ac.admittance[i])
        gsi = 0.5 * branch.parameter.conductance[i]
        bsi = 0.5 * branch.parameter.susceptance[i]
        βij = 1 / branch.parameter.turnsRatio[i]

        if branch.flow.type[i] == 1 || branch.flow.type[i] == 3
            Aij = βij^4 * ((gij + gsi)^2 + (bij + bsi)^2)
            Bij = βij^2 * (gij^2 + bij^2)
            Cij = βij^3 * (gij * (gij + gsi) + bij * (bij + bsi))
            Dij = βij^3 * (bij * (gij + gsi) - gij * (bij + bsi))

            Aji = (gij + gsi)^2 + (bij + bsi)^2
            Cji = βij * (gij * (gij + gsi) + bij * (bij + bsi))
            Dji = βij * (gij * (bij + bsi) - bij * (gij + gsi))

            if branch.flow.type[i] == 1
                refFrom[i] = @constraint(jump, Aij * Vi^4 + Bij * Vi^2 * Vj^2 - 2 * Vi^3 * Vj * (Cij * cosθ + Dij * sinθ) <= branch.flow.longTerm[i]^2)
                refTo[i] = @constraint(jump, Aji * Vj^4 + Bij * Vi^2 * Vj^2 - 2 * Vi * Vj^3 * (Cji * cosθ + Dji * sinθ) <= branch.flow.longTerm[i]^2)
            elseif branch.flow.type[i] == 3
                refFrom[i] = @constraint(jump, Aij * Vi^2 + Bij * Vj^2 - 2 * Vi * Vj * (Cij * cosθ + Dij * sinθ) <= branch.flow.longTerm[i]^2)
                refTo[i] = @constraint(jump, Aji * Vj^2 + Bij * Vi^2 - 2 * Vi * Vj * (Cji * cosθ + Dji * sinθ) <= branch.flow.longTerm[i]^2)
            end
        elseif branch.flow.type[i] == 2
            if gij != 0 && bij != 0
                refFrom[i] = @constraint(jump, βij^2 * (gij + gsi) * Vi^2 - βij * Vi * Vj * (gij * cosθ + bij * sinθ) <= branch.flow.longTerm[i])
                refTo[i] = @constraint(jump, (gij + gsi) * Vj^2 - βij * Vi * Vj * (gij * cosθ - bij * sinθ) <= branch.flow.longTerm[i])
            elseif gij != 0
                refFrom[i] = @constraint(jump, βij^2 * (gij + gsi) * Vi^2 - βij * Vi * Vj * gij * cosθ  <= branch.flow.longTerm[i])
                refTo[i] = @constraint(jump, (gij + gsi) * Vj^2 - βij * Vi * Vj * gij * cosθ <= branch.flow.longTerm[i])
            elseif bij != 0
                refFrom[i] = @constraint(jump, βij^2 * (gij + gsi) * Vi^2 - βij * Vi * Vj * bij * sinθ <= branch.flow.longTerm[i])
                refTo[i] = @constraint(jump, (gij + gsi) * Vj^2 + βij * Vi * Vj * bij * sinθ <= branch.flow.longTerm[i])
            end
        end
    end

    return jump, refFrom, refTo
end

######### Fix and UnfixData ##########
function fix!(variable::JuMP.VariableRef, value::Float64, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    JuMP.fix(variable, value)
    ref[index] = JuMP.FixRef(variable)
end

function unfix!(jump::JuMP.Model, variable::JuMP.VariableRef, ref::Dict{Int64, JuMP.ConstraintRef}, index::Int64)
    if haskey(ref, index)
        if JuMP.is_valid(jump, ref[index])
            JuMP.unfix(variable)
        end
        delete!(ref, index)
    end
end

######### Remove Constraints ##########
function remove!(jump::JuMP.Model, ref::Union{Dict{Int64, JuMP.ConstraintRef}, Dict{Int64, VariableRef}}, index::Int64)
    if haskey(ref, index)
        if JuMP.is_valid.(jump, ref[index])
            JuMP.delete(jump, ref[index])
        end
        delete!(ref, index)
    end
end

function remove!(jump::JuMP.Model, ref::Dict{Int64, Array{JuMP.ConstraintRef,1}}, index::Int64)
    if haskey(ref, index)
        if all(JuMP.is_valid.(jump, ref[index]))
            JuMP.delete.(jump, ref[index])
        end
        delete!(ref, index)
    end
end

######### Update Balance Constraints ##########
function updateBalance(system::PowerSystem, analysis::ACOptimalPowerFlow, index::Int64; active = false, reactive = false)
    bus = system.bus
    ac = system.model.ac
    jump = analysis.jump
    constraint = analysis.constraint
    variable = analysis.variable

    if active
        if is_valid(jump, constraint.balance.active[index])
            remove!(jump, constraint.balance.active, index)
        end
        activeExpr = @expression(jump, variable.magnitude[index] * real(ac.nodalMatrixTranspose[index, index]))
    end
    if reactive
        if is_valid(jump, constraint.balance.reactive[index])
            remove!(jump, constraint.balance.reactive, index)
        end
        reactiveExpr = @expression(jump, -variable.magnitude[index] * imag(ac.nodalMatrixTranspose[index, index]))
    end
    for j in ac.nodalMatrix.colptr[index]:(ac.nodalMatrix.colptr[index + 1] - 1)
        row = ac.nodalMatrix.rowval[j]
        if index != row
            θ = @expression(jump, variable.angle[index] - variable.angle[row])
            cosθ = @expression(jump, cos(θ))
            sinθ = @expression(jump, sin(θ))
            Gij = real(ac.nodalMatrixTranspose.nzval[j])
            Bij = imag(ac.nodalMatrixTranspose.nzval[j])

            if active
                if Gij != 0 && Bij !=0
                    activeExpr = @expression(jump, activeExpr + variable.magnitude[row] * (Gij * cosθ + Bij * sinθ))
                elseif Gij != 0
                    activeExpr = @expression(jump, activeExpr + variable.magnitude[row] * Gij * cosθ)
                elseif Bij != 0
                    activeExpr = @expression(jump, activeExpr + variable.magnitude[row] * Bij * sinθ)
                end
            end
            if reactive
                if Gij != 0 && Bij !=0
                    reactiveExpr = @expression(jump, reactiveExpr + variable.magnitude[row] * (Gij * sinθ - Bij * cosθ))
                elseif Gij != 0
                    reactiveExpr = @expression(jump, reactiveExpr + variable.magnitude[row] * Gij * sinθ)
                elseif Bij != 0
                    reactiveExpr = @expression(jump, reactiveExpr - variable.magnitude[row] * Bij * cosθ)
                end
            end
        end
    end
    if active
        constraint.balance.active[index] = @constraint(jump, sum(variable.active[k] for k in bus.supply.generator[index]) - variable.magnitude[index] * activeExpr == bus.demand.active[index])
    end
    if reactive
        constraint.balance.reactive[index] = @constraint(jump, sum(variable.reactive[k] for k in bus.supply.generator[index]) - variable.magnitude[index] * reactiveExpr == bus.demand.reactive[index])
    end
end

"""
    startingPrimal!(system::PowerSystem, analysis::OptimalPowerFlow)

In the context of the `ACOptimalPowerFlow` composite type, this function retrieves the
active and reactive power outputs of the generators, as well as the voltage magnitudes and
angles from the `PowerSystem` composite type. It then assigns these values to the
`ACOptimalPowerFlow` type, allowing users to initialize starting primal values as needed.

For the `DCOptimalPowerFlow` composite type, this function retrieves the active power
outputs of the generators and the bus voltage angles from the `PowerSystem` composite type.
These values are then assigned to the `DCOptimalPowerFlow` type, enabling users to
initialize starting primal values according to their requirements.

# Updates
This function only updates the `voltage` and `generator` fields of the `OptimalPowerFlow`
abstract type.

# Abstract type
The abstract type `OptimalPowerFlow` can have the following subtypes:
- `ACOptimalPowerFlow`: employed to initializing starting primal values within the AC optimal power flow;
- `DCOptimalPowerFlow`: employed to initialize starting primal values within the DC optimal power flow.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

updateBus!(system, analysis; label = 14, reactive = 0.13, magnitude = 1.2, angle = -0.17)

startingPrimal!(system, analysis)
solve!(system, analysis)
```
"""
function startingPrimal!(system::PowerSystem, analysis::ACOptimalPowerFlow)
    @inbounds for i = 1:system.bus.number
        analysis.voltage.magnitude[i] = system.bus.voltage.magnitude[i]
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = system.generator.output.active[i]
        analysis.power.generator.reactive[i] = system.generator.output.reactive[i]
    end
end

function startingPrimal!(system::PowerSystem, analysis::DCOptimalPowerFlow)
    @inbounds for i = 1:system.bus.number
        analysis.voltage.angle[i] = system.bus.voltage.angle[i]
    end
    @inbounds for i = 1:system.generator.number
        analysis.power.generator.active[i] = system.generator.output.active[i]
    end
end