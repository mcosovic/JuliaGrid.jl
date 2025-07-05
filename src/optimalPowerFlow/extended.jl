"""
    @addVariable(analysis::OptimalPowerFlow, expr, primal, lower, upper, args..., kwargs...)

This macro wraps the JuMP [@variable](https://jump.dev/JuMP.jl/stable/api/JuMP/#@variable) macro,
adding an optimization variable defined by `expr` to the model. In addition to creating the JuMP
variable, it also registers the variable within the JuliaGrid framework and optionally sets
initial values for both primal and dual variables.

The positional arguments `args` and keyword arguments `kwargs` are consistent with those accepted by
the [@variable](https://jump.dev/JuMP.jl/stable/api/JuMP/#@variable) macro in JuMP.

Additionally, the following keyword arguments can be used:
* `primal`: Sets the initial primal value.
* `lower`: If a lower bound is defined, sets the initial dual value.
* `upper`: If an upper bound is defined, sets the initial dual value.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)

@addVariable(analysis, 0.0 <= x <= 0.2, primal = 0.1, lower = 10.0, upper = 0.0)
@addVariable(analysis, y[i = 1:2] <= 0.2, primal = [0.1, 0.2], upper = [0.0; -2.5])
```
"""
macro addVariable(args...)
    analysisSym = args[1]
    filteredArgs = Any[]
    bounds = Dict{Symbol, Any}(:primal => nothing, :lower => nothing, :upper => nothing)

    for arg in args[2:end]
        if arg isa Expr && arg.head == :(=)
            key, val = arg.args[1], arg.args[2]
            if haskey(bounds, key)
                bounds[key] = val
                continue
            end
        end
        push!(filteredArgs, arg)
    end

    model = Expr(:., Expr(:., analysisSym, QuoteNode(:method)), QuoteNode(:jump))
    jumpCall = Expr(:macrocall, GlobalRef(JuMP, Symbol("@variable")), __source__, model, filteredArgs...)

    quote
        local analysis = $(esc(analysisSym))
        local varref = $(esc(jumpCall))
        local primal = $(bounds[:primal])
        local lower  = $(bounds[:lower])
        local upper  = $(bounds[:upper])

        for (vec, name) in ((primal, :primal), (lower, :lower), (upper, :upper))
            if vec !== nothing && length(vec) != length(varref)
                throw(ArgumentError("The length of $(name) does not match the number of variables."))
            end
        end

        for (i, var) in enumerate(varref)
            analysis.method.jump.ext[:nvar] += 1
            local idx = analysis.method.jump.ext[:nvar]

            analysis.extended.variable[idx] = var
            push!(analysis.extended.solution, primal !== nothing ? primal[i] : 0.0)

            haslower = has_lower_bound(var)
            hasupper = has_upper_bound(var)

            if (lower !== nothing && haslower) || (upper !== nothing && hasupper)
                analysis.extended.dual.variable[idx] = Dict{Symbol, Float64}()

                if lower !== nothing && haslower
                    analysis.extended.dual.variable[idx][:lower] = lower[i]
                end
                if upper !== nothing && hasupper
                    analysis.extended.dual.variable[idx][:upper] = upper[i]
                end
            end
        end

        varref
    end
end

"""
    @addConstraint(analysis::OptimalPowerFlow, expr, dual, args..., kwargs...)

This macro wraps the JuMP [@constraint](https://jump.dev/JuMP.jl/stable/api/JuMP/#@constraint) macro,
adding an constraint defined by `expr` to the model. In addition to creating the JuMP
constraint, it also registers the constraint within the JuliaGrid framework and optionally sets
initial dual value.

The positional arguments `args` and keyword arguments `kwargs` are consistent with those accepted by
the [@constraint](https://jump.dev/JuMP.jl/stable/api/JuMP/#@constraint) macro in JuMP.

Additionally, the keyword `dual` can be used to set the initial dual value.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = dcOptimalPowerFlow(system, Ipopt.Optimizer)

@addVariable(analysis, 0.0 <= x[i = 1:2] <= 0.2)
@addConstraint(analysis, x[1] + 2 * x[2] <= 1.2, dual = 0.1)
```
"""
macro addConstraint(args...)
    analysisSym = args[1]
    filteredArgs = Any[]
    dual = nothing

    for arg in args[2:end]
        if arg isa Expr && arg.head == :(=)
            key, val = arg.args[1], arg.args[2]
            if key == :dual
                dual = val
                continue
            end
        end
        push!(filteredArgs, arg)
    end

    model = Expr(:., Expr(:., analysisSym, QuoteNode(:method)), QuoteNode(:jump))
    jumpCall = Expr(:macrocall, GlobalRef(JuMP, Symbol("@constraint")), __source__, model, filteredArgs...)

    quote
        local analysis = $(esc(analysisSym))
        local conref = $(esc(jumpCall))
        local dual = $(esc(dual))

        if isa(conref, ConstraintRef)
            analysis.method.jump.ext[:ncon] += 1
            analysis.extended.constraint[analysis.method.jump.ext[:ncon]] = conref

            if dual !== nothing && length(dual) == 1
                analysis.extended.dual.constraint[analysis.method.jump.ext[:ncon]] = dual
            else
                throw(ArgumentError("The length of dual does not match the number of constraints."))
            end
        else
            if dual != nothing && length(dual) != length(conref)
                throw(ArgumentError("The length of dual does not match the number of constraints."))
            end
            for (i, con) in enumerate(conref)
                analysis.method.jump.ext[:ncon] += 1
                analysis.extended.constraint[analysis.method.jump.ext[:ncon]] = con
                if dual != nothing
                    analysis.extended.dual.constraint[analysis.method.jump.ext[:ncon]] = dual[i]
                end
            end
        end

        conref
    end
end

##### Set Primal Start Values #####
function setprimal(jump::JuMP.Model, moi::MOI.ModelLike, extended::Extended)
    for (idx, var) in extended.variable
        setprimal!(jump, moi, var, extended.solution[idx])
    end
end

##### Get Primal Values #####
function getprimal(jump::JuMP.Model, moi::MOI.ModelLike, extended::Extended)
    for (i, var) in extended.variable
        getprimal!(jump, moi, var, extended.solution, i)
    end
end

##### Set Dual Start Values #####
function setdual(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    extended::Extended,
    vars::OrderedDict{Int64, VariableRef}
)
    for (idx, var) in vars
        if haskey(extended.dual.variable, idx) && isvalid(jump, moi, var)
            for type in keys(extended.dual.variable[idx])
                if type == :lower
                    set_dual_start_value(LowerBoundRef(var), extended.dual.variable[idx][type])
                end
                if type == :upper
                    set_dual_start_value(UpperBoundRef(var), extended.dual.variable[idx][type])
                end
                if type == :equality
                    set_dual_start_value(FixRef(var), extended.dual.variable[idx][type])
                end
            end
        end
    end
end

function setdual(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    extended::Extended,
    cons::OrderedDict{Int64, ConstraintRef}
)
    for (idx, con) in cons
        if haskey(extended.dual.constraint, idx)
            setdual!(jump, moi, con, extended.dual.constraint[idx])
        end
    end
end

##### Get Dual Values #####
function getdual(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    extended::Extended,
    variable::OrderedDict{Int64, VariableRef}
)
    for (idx, var) in variable
        extended.dual.variable[idx] = Dict{Symbol, Float64}()

        if isvalid(jump, moi, var)
            if has_lower_bound(var)
                extended.dual.variable[idx][:lower] = JuMP.dual(LowerBoundRef(var))
            end
            if has_upper_bound(var)
                extended.dual.variable[idx][:upper] = JuMP.dual(UpperBoundRef(var))
            end
            if is_fixed(var)
                extended.dual.variable[idx][:equality] = JuMP.dual(FixRef(var))
            end
        end
    end
end

function getdual(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    extended::Extended,
    constraint::OrderedDict{Int64, ConstraintRef}
)
    for (idx, con) in constraint
        if isvalid(jump, moi, con)
            extended.dual.constraint[idx] = JuMP.dual(con)
        end
    end
end

function remove!(
    jump::JuMP.Model,
    moi::MOI.ModelLike,
    con::OrderedDict{Int64, ConstraintRef},
    dual::OrderedDict{Int64, Float64},
    idx::Int64
)
    if haskey(con, idx)
        if isvalid(jump, moi, con[idx])
            _delete(jump, moi, con[idx])
        end
        delete!(con, idx)
    end

    if haskey(dual, idx)
        delete!(dual, idx)
    end
end