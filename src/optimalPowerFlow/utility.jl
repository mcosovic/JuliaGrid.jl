"""
    addDual!(analysis::OptimalPowerFlow, field::Symbol, subfield::Symbol;
        label, index, subindex, dual, lower, upper)

Assigns an initial dual value to a specific constraint in the optimal power flow model.

For DC optimal power flow, only `field` is required to identify the constraint. For AC optimal power
flow, both `field` and `subfield` must be provided to target the specific constraint type.

# Arguments
* `field`: Specifies the primary constraint category.
* `subfield`: Specifies the constraint subtype within the selected `field`.

Initial dual values are assigned according to the selected constraint:
* `:slack`: Slack angle constraint.
* `:capability`: Generator capability constraints:
  * `:active`: Active power.
  * `:reactive`: Reactive power.
  * `:lower`: PQ capability curve.
  * `:upper`: PQ capability curve.
* `:balance`: Power balance constraints:
  * `:active`: Active power balance.
  * `:reactive`: Reactive power balance.
* `:voltage`: Voltage constraints:
  * `:magnitude`: Voltage magnitude.
  * `:angle`: Angle difference.
* `:flow`: Branch power flow constraints:
  * `:from`: From-bus end.
  * `:to`: To-bus end.
* `:piecewise`: Piecewise linear cost constraints:
  * `:active`: Active power.
  * `:reactive`: Reactive power.
* `:variable`: Constraint on external user-defined variable.
* `:constraint`: External user-defined constraint.

# Keywords
The following keyword arguments can be used:
* `label`: Identifies the constraint by the label of a bus, branch, or generator.
* `index`: Identifies the constraint by numerical index.
* `subindex`: Specify a subconstraint index for `:piecewise` constraints only.
* `dual`: Sets the dual value for equality or interval constraints.
* `lower`: Sets the dual value associated with the lower bound.
* `upper`: Sets the dual value associated with the upper bound.

# Examples
AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

addDual!(analysis, :balance, :active; index = 2, dual = 258.23)
addDual!(analysis, :voltage, :magnitude; index = 2, lower = 0.0, upper = 587.23)
```

DC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)

addDual!(analysis, :balance; index = 2, dual = 258.23)
addDual!(analysis, :capability; index = 2, lower = 0.0, upper = 587.23)
```
"""
function addDual!(
    analysis::OptimalPowerFlow,
    field::Symbol,
    subfield::Symbol = :none;
    label::IntStrMiss = missing,
    index::IntMiss = missing,
    subindex::IntMiss = missing,
    dual::FltIntMiss = missing,
    lower::FltIntMiss = missing,
    upper::FltIntMiss = missing
)
    if ismissing(label) && ismissing(index)
        throw(ErrorException("Missing required keyword: label or index must be specified."))
    end
    if isset(dual) && (isset(lower) || isset(upper))
        throw(ErrorException("Cannot use the dual keyword together with lower and upper."))
    end

    con, dul, index = getConstraintDual(analysis, field, subfield, label, index)
    if haskey(con, index)
        adddual!(analysis, con, dul, dual, lower, upper, index, subindex)

        if isempty(dul[index])
            errorAddDualKeyword()
        end
    else
        throw(ErrorException("The provided index does not match any existing constraint in the model."))
    end
end

function getConstraintDual(
    analysis::OptimalPowerFlow,
    field::Symbol,
    subfield::Symbol,
    label::IntStrMiss,
    index::IntMiss
)
    if field == :constraint
        con, dual = analysis.extended.constraint, analysis.extended.dual.constraint
    elseif field == :variable
        con, dual = analysis.extended.variable, analysis.extended.dual.variable
    else
        cons = getfield(analysis.method.constraint, field)
        duals = getfield(analysis.method.dual, field)

        if subfield == :none
            subfield = fieldnames(typeof(cons))[1]
        end

        con, dual = getfield(cons, subfield), getfield(duals, subfield)

        if field in (:slack, :balance) || (field == :voltage && subfield == :magnitude)
            index = isset(label) ? getIndex(analysis.system.bus, label, "bus") : index
        elseif field == :flow || (field == :voltage && subfield == :angle)
            index = isset(label) ? getIndex(analysis.system.branch, label, "branch") : index
        elseif field in (:capability, :piecewise)
            index = isset(label) ? getIndex(analysis.system.generator, label, "generator") : index
        end
    end

    return con, dual, index
end

function adddual!(
    analysis::OptimalPowerFlow,
    con::ConDict,
    dul::DualDict,
    dual::FltIntMiss,
    lower::FltIntMiss,
    upper::FltIntMiss,
    idx::Int64,
    ::IntMiss
)
    dul[idx] = Dict{Symbol, Float64}()

    for type in keys(con[idx])
        dul[idx][type] = getdual(analysis.method.jump, con[idx][type], type, dual, lower, upper)
    end
end

function adddual!(
    analysis::OptimalPowerFlow,
    con::ConDictVec,
    dul::DualDictVec,
    dual::FltIntMiss,
    lower::FltIntMiss,
    upper::FltIntMiss,
    idx::Int64,
    sub::Int64
)
    for type in keys(con[idx])
        if !haskey(dul, idx)
            dul[idx] = Dict(type => zeros(length(con[idx][type])))
        end

        if length(con[idx][type]) != length(dul[idx][type])
            throw(ErrorException("Dimension mismatch between constraints and dual values."))
        end

        dul[idx][type][sub] = getdual(analysis.method.jump, con[idx][type][sub], type, dual, lower, upper)
    end
end

function adddual!(
    analysis::OptimalPowerFlow,
    con::OrderedDict{Int64, ConstraintRef},
    dul::OrderedDict{Int64, Float64},
    dual::FltIntMiss,
    lower::FltIntMiss,
    upper::FltIntMiss,
    idx::Int64,
    ::IntMiss
)
    dual = isset(dual) ? dual : isset(lower) ? lower : isset(upper) ? upper : missing
    type = isset(lower) ? :lower : isset(upper) ? :upper : Symbol()

    dul[idx] = getdual(analysis.method.jump, con[idx], type, dual, lower, upper)
end

function adddual!(
    analysis::OptimalPowerFlow,
    var::OrderedDict{Int64, VariableRef},
    dul::DualDict,
    dual::FltIntMiss,
    lower::FltIntMiss,
    upper::FltIntMiss,
    index::Int64,
    ::IntMiss
)
    if is_valid(analysis.method.jump, var[index])
        dul[index] = Dict{Symbol, Float64}()
        if has_lower_bound(var[index]) && isset(lower)
            dul[index][:lower] = lower
        end
        if has_upper_bound(var[index]) && isset(upper)
            dul[index][:upper] = upper
        end
        if is_fixed(var[index]) && isset(dual)
            dul[index][:equality] = dual
        end
    end
end

function getdual(
    jump::JuMP.Model,
    con::ConstraintRef,
    type::Symbol,
    dual::FltIntMiss,
    lower::FltIntMiss,
    upper::FltIntMiss
)
    if is_valid(jump, con)
        if isset(dual)
            return dual
        elseif isset(lower) && type == :lower
            return lower
        elseif isset(upper) && type == :upper
            return upper
        else
            errorAddDualKeyword()
        end
    else
        errorAddDualValid()
    end
end

"""
    remove!(analysis::OptimalPowerFlow, field::Symbol, subfield::Symbol; label, index)

Removes a specific constraint from the optimal power flow model.

For DC optimal power flow, only `field` is required to identify the constraint. For AC optimal power
flow, both `field` and `subfield` must be provided to target the specific constraint type.

# Arguments
* `field`: Specifies the primary constraint category.
* `subfield`: Specifies the constraint subtype within the selected `field`.

The constraint to be removed can correspond to one of the following:
* `:slack`: Slack angle constraint.
* `:capability`: Generator capability constraints:
  * `:active`: Active power.
  * `:reactive`: Reactive power.
  * `:lower`: PQ capability curve.
  * `:upper`: PQ capability curve.
* `:balance`: Power balance constraints:
  * `:active`: Active power balance.
  * `:reactive`: Reactive power balance.
* `:voltage`: Voltage constraints:
  * `:magnitude`: Voltage magnitude.
  * `:angle`: Angle difference.
* `:flow`: Branch power flow constraints:
  * `:from`: From-bus end.
  * `:to`: To-bus end.
* `:piecewise`: Piecewise linear cost constraints:
  * `:active`: Active power.
  * `:reactive`: Reactive power.
* `:variable`: Constraint on external user-defined variable.
* `:constraint`: External user-defined constraint.

# Keywords
The following keyword arguments can be used:
* `label`: Identifies the constraint by the label of a bus, branch, or generator.
* `index`: Identifies the constraint by numerical index.

# Examples
AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)

remove!(analysis, :balance, :active; index = 2)
remove!(analysis, :voltage, :magnitude; index = 2)
```

DC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)

remove!(analysis, :balance; index = 2)
remove!(analysis, :capability; index = 2)
```
"""
function remove!(
    analysis::OptimalPowerFlow,
    field::Symbol,
    subfield::Symbol = :none;
    label::IntStrMiss = missing,
    index::IntMiss = missing
)
    if ismissing(label) && ismissing(index)
        throw(ErrorException("Missing required keyword: label or index must be specified."))
    end

    con, dual, index = getConstraintDual(analysis, field, subfield, label, index)
    remove!(analysis.method.jump, backend(analysis.method.jump), con, dual, index)
end

##### Variable and Constraint Validation #####
function isvalid(jump::JuMP.Model, moi::MOI.ModelLike, con::ConstraintRef)
    return jump === con.model && MOI.is_valid(moi, con.index)
end

function isvalid(jump::JuMP.Model, moi::MOI.ModelLike, var::VariableRef)
    return jump === owner_model(var) && MOI.is_valid(moi, var.index)
end

##### Box Constraints #####
function setConstraint!(
    var::Vector{VariableRef},
    con::ConDict,
    minVal::Vector{Float64},
    maxVal::Vector{Float64},
    idx::Int64
)
    if minVal[idx] == maxVal[idx] && isfinite(minVal[idx])
        fix!(var[idx], minVal[idx], con, idx; force = true)
    elseif isfinite(minVal[idx]) || isfinite(maxVal[idx])
        con[idx] = Dict{Symbol, ConstraintRef}()

        if isfinite(minVal[idx])
            con[idx][:lower] = LowerBoundRef(var[idx])
        end
        if isfinite(maxVal[idx])
            con[idx][:upper] = UpperBoundRef(var[idx])
        end
    end
end

##### Add Variable #####
function add!(
    jump::JuMP.Model,
    var::Vector{VariableRef},
    minVal::Vector{Float64},
    maxVal::Vector{Float64},
    name::String,
    idx::Int64
)
    push!(
        var,
        @variable(
            jump, base_name = "$(name)[$idx]", lower_bound = minVal[idx], upper_bound = maxVal[idx]
        )
    )
end

##### Add Constraint #####
@inline function addConstraint(
    jump::JuMP.Model,
    con::Dict{Symbol, ConstraintRef},
    expr::Union{AffExpr, NonlinearExpr},
    minVal::Float64,
    maxVal::Float64
)
    if minVal != maxVal
        if jump.ext[:interval]
            con[:interval] = add_constraint(jump, ScalarConstraint(expr, MOI.Interval(minVal, maxVal)))
        else
            if isfinite(minVal)
                con[:lower] = add_constraint(jump, ScalarConstraint(expr, MOI.GreaterThan(minVal)))
            end
            if isfinite(maxVal)
                con[:upper] = add_constraint(jump, ScalarConstraint(expr, MOI.LessThan(maxVal)))
            end
        end
    else
        con[:equality] = add_constraint(jump, ScalarConstraint(expr, MOI.EqualTo(minVal)))
    end
end

##### Set Primal Start Values #####
function setprimal!(jump::JuMP.Model, moi::MOI.ModelLike, var::VariableRef, start::Float64)
    if isvalid(jump, moi, var)
        set_start_value(var::VariableRef, start)
    end
end

##### Get Primal Values #####
function getprimal!(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    var::VariableRef,
    val::Union{Vector{Float64}, OrderedDict{Int64, Float64}},
    i::Int64
)
    if isvalid(jump, moi, var)
        val[i] = value(var::VariableRef)
    end
end

##### Set Dual Start Values #####
function setdual!(jump::JuMP.Model, moi::MOI.ModelLike, con::ConstraintRef, dual::Float64)
    if isvalid(jump, moi, con)
        set_dual_start_value(con, dual)
    end
end

function setdual(jump::JuMP.Model, moi::MOI.ModelLike, dual::DualDict, cons::ConDict)
    for (idx, con) in cons
        if haskey(dual, idx)
            for type in keys(con)
                if haskey(dual[idx], type)
                    setdual!(jump, moi, con[type], dual[idx][type])
                end
            end
        end
    end
end

function setdual(jump::JuMP.Model, moi::MOI.ModelLike, dual::DualDictVec, cons::ConDictVec)
    for (idx, con) in cons
        if haskey(dual, idx)
            for type in keys(con)
                if haskey(dual[idx], type)
                    for j = 1:length(con[type])
                        setdual!(jump, moi, con[type][j], dual[idx][type][j])
                    end
                end
            end
        end
    end
end

##### Get Dual Values #####
function getdual(jump::JuMP.Model, moi::MOI.ModelLike, dual::DualDict, constraint::ConDict)
    for (idx, con) in constraint
        dual[idx] = Dict{Symbol, Float64}()

        for type in keys(con)
            if isvalid(jump, moi, con[type])
                dual[idx][type] = JuMP.dual(con[type])
            end
        end
    end
end

function getdual(jump::JuMP.Model, moi::MOI.ModelLike, dual::DualDictVec, constraint::ConDictVec)
    for (idx, con) in constraint
        dual[idx] = Dict{Symbol, Vector{Float64}}()

        for type in keys(con)
            n = length(con[type])
            dual[idx][type] = fill(0.0, n)
            for j = 1:n
                if isvalid(jump, moi, con[type][j])
                    dual[idx][type][j] = JuMP.dual(con[type][j])
                end
            end
        end
    end
end

##### Objective Functions #####
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

##### Fix and Unfix Data #####
function fix!(
    var::VariableRef,
    value::Float64,
    con::ConDict,
    idx::Int64;
    force::Bool = false
)
    con[idx] = Dict{Symbol, ConstraintRef}()

    fix(var, value; force)
    con[idx][:equality] = FixRef(var)
end

function unfix!(jump::JuMP.Model, moi::MOI.ModelLike, var::VariableRef, con::ConDict, idx::Int64)
    if haskey(con, idx) && haskey(con[idx], :equality) && isvalid(jump, moi, con[idx][:equality])
        unfix(var)
        empty!(con[idx])
    end
end

##### Remove Data #####
function remove!(jump::JuMP.Model, moi::MOI.ModelLike, var::Dict{Int64, JuMP.VariableRef}, idx::Int64)
    if haskey(var, idx)
        if isvalid(jump, moi, var[idx])
            _delete(jump, moi, var[idx])
        end
        delete!(var, idx)
    end
end

function _delete(jump::JuMP.Model, moi::MOI.ModelLike, var::VariableRef)
    if jump !== owner_model(var)
        error(
            "The variable reference you are trying to delete does not " *
            "belong to the model.",
        )
    end
    jump.is_model_dirty = true
    MOI.delete(moi, var.index)
    return
end

function remove!(jump::JuMP.Model, moi::MOI.ModelLike, con::ConDict, dual::DualDict, idx::Int64)
    if haskey(con, idx)
        for type in keys(con[idx])
            if isvalid(jump, moi, con[idx][type])
                _delete(jump, moi, con[idx][type])
            end
        end
        empty!(con[idx])
    end
    if haskey(dual, idx)
        empty!(dual[idx])
    end
end

function _delete(jump::JuMP.Model, moi::MOI.ModelLike, con::ConstraintRef)
    if jump !== con.model
        error(
            "The constraint reference you are trying to delete does not " *
            "belong to the model.",
        )
    end
    jump.is_model_dirty = true
    return MOI.delete(moi, index(con))
end

function remove!(jump::JuMP.Model, moi::MOI.ModelLike, con::ConDictVec, dual::DualDictVec, idx::Int64)
    if haskey(con, idx)
        for type in keys(con[idx])
            for i = 1:lastindex(con[idx][type])
                if isvalid(jump, moi, con[idx][type][i])
                    _delete(jump, moi, con[idx][type][i])
                end
            end
        end
        empty!(con[idx])
    end
    if haskey(dual, idx)
        empty!(dual[idx])
    end
end

##### Remove and Set Box Constraints #####
function setBound!(
    var::Vector{VariableRef},
    minVal::Vector{Float64},
    maxVal::Vector{Float64},
    idx::Int64
)
    if isfinite(minVal[idx])
        set_lower_bound(var[idx], minVal[idx])
    end
    if isfinite(maxVal[idx])
        set_upper_bound(var[idx], maxVal[idx])
    end
end

##### Transfer Dual #####
function transferdual!(
    dualTarget::DualDict,
    conTarget::ConDict,
    dualSource::DualDict,
    conSource::ConDict
)
    for (idx, con) in conTarget
        if haskey(conSource, idx) && haskey(dualSource, idx)
            dualTarget[idx] = Dict{Symbol, Float64}()

            for type in keys(con)
                if haskey(conSource[idx], type) && haskey(dualSource[idx], type)
                    dualTarget[idx][type] = dualSource[idx][type]
                end
            end
        end
    end
end

function transferdual!(
    dualTarget::DualDictVec,
    conTarget::ConDictVec,
    dualSource::DualDictVec,
    conSource::ConDictVec
)
    for (idx, con) in conTarget
        if haskey(conSource, idx) && haskey(dualSource, idx)
            dualTarget[idx] = Dict{Symbol, Vector{Float64}}()

            for type in keys(con)
                if haskey(conSource[idx], type) && haskey(dualSource[idx], type)
                    n = length(conTarget[idx][type])
                    dualTarget[idx][type] = fill(0.0, n)
                    for j = 1:n
                        dualTarget[idx][type][j] = dualSource[idx][type][j]
                    end
                end
            end
        end
    end
end

##### Check Does Solver Support Dual #####
function trydual(jump::JuMP.Model, conSlack::ConDict, slack::Int64)
    if jump.ext[:dualval]
        try
            set_dual_start_value(conSlack[slack][:equality], nothing)
        catch
            jump.ext[:dualval] = false
        end
    end
end