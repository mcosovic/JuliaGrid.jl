##### Check Meter Location #####
function checkLocation(from::IntStrMiss, to::IntStrMiss)
    if isset(from) && isset(to)
        throw(ErrorException("Concurrent location keyword definition is not allowed."))
    elseif ismissing(from) && ismissing(to)
        throw(ErrorException("At least one of the location keywords must be provided."))
    elseif isset(from)
        return from, true, false
    else
        return to, false, true
    end
end

function checkLocation(bus::IntStrMiss, from::IntStrMiss, to::IntStrMiss)
    if isset(bus) && ismissing(from) && ismissing(to)
        return bus, true, false, false
    elseif ismissing(bus) && isset(from) && ismissing(to)
        return from, false, true, false
    elseif ismissing(bus) && ismissing(from) && isset(to)
        return to, false, false, true
    elseif ismissing(bus) && ismissing(from) && ismissing(to)
        throw(ErrorException("At least one of the location keywords must be provided."))
    else
        throw(ErrorException("Concurrent location keyword definition is not allowed."))
    end
end

##### Set Mean, Variance, and Status #####
function setMeter(
    meter::GaussMeter,
    mean::FltIntMiss,
    variance::FltIntMiss,
    status::IntMiss,
    noise::Bool,
    defVariance::ContainerTemplate,
    defStatus::Int8,
    pfxLive::Float64,
    baseInv::Float64
)
    add!(meter.variance, variance, defVariance, pfxLive, baseInv)

    measure = topu(mean, pfxLive, baseInv)
    if noise
        measure += meter.variance[end]^(1/2) * randn(1)[1]
    end
    push!(meter.mean, measure)

    add!(meter.status, status, defStatus)
    checkStatus(meter.status[end])

    checkVariance(meter.variance[end])
end

#### Update Mean, Variance, and Status #####
function update!(
    meter::GaussMeter,
    mean::FltIntMiss,
    key::Union{VoltmeterKey, AmmeterKey, WattmeterKey, VarmeterKey, PmuKey},
    pfxLive::Float64,
    baseInv::Float64,
    idx::Int64
)
    if isset(mean)
        meter.mean[idx] = topu(mean, pfxLive, baseInv)
        if key.noise
            meter.mean[idx] += meter.variance[idx]^(1/2) * randn(1)[1]
        end
    end

    if isset(key.status)
        meter.status[idx] = key.status
    end
    checkStatus(meter.status[idx])
    checkVariance(meter.variance[idx])
end

##### Add Meter #####
function add!(
    meter::GaussMeter,
    idx::Int64,
    noise::Bool,
    pfxLive::Float64,
    exact::Float64,
    variance::FltIntMiss,
    defVariance::ContainerTemplate,
    status::Union{Int8, Int64},
    baseInv::Float64
)
    meter.status[idx] = status

    meter.variance[idx] = topu(variance, defVariance, pfxLive, baseInv)
    checkVariance(meter.variance[idx])

    meter.mean[idx] = exact
    if noise
        meter.mean[idx] += meter.variance[idx]^(1/2) * randn(1)[1]
    end
end

function add!(lav::LAV, idx::Int64)
    deviation = lav.variable.deviation
    remove!(lav.jump, backend(lav.jump), lav.residual, idx)

    if is_fixed(deviation.positive[idx])
        unfix(deviation.positive[idx])
        unfix(deviation.negative[idx])
        set_lower_bound(deviation.positive[idx], 0.0)
        set_lower_bound(deviation.negative[idx], 0.0)

        set_objective_coefficient(lav.jump, deviation.positive[idx], 1)
        set_objective_coefficient(lav.jump, deviation.negative[idx], 1)
    end
end

##### Delete Meter #####
function remove!(lav::LAV, idx::Int64)
    deviation = lav.variable.deviation
    remove!(lav.jump, backend(lav.jump), lav.residual, idx)

    if !is_fixed(deviation.positive[idx])
        fix(deviation.positive[idx], 0.0; force = true)
        fix(deviation.negative[idx], 0.0; force = true)

        set_objective_coefficient(lav.jump, deviation.positive[idx], 0)
        set_objective_coefficient(lav.jump, deviation.negative[idx], 0)
    end
end

function remove!(jump::JuMP.Model, moi::MOI.ModelLike, con::Dict{Int64, ConstraintRef}, idx::Int64)
    if haskey(con, idx)
        if isvalid(jump, moi, con[idx])
            delete(jump, con[idx])
        end
        delete!(con, idx)
    end
end

##### Squared Current Magnitude #####
function if2exp(square::Bool)
    if square
        return 2
    else
        return 1
    end
end

function if2type(square::Bool)
    if square
        return 2
    else
        return 0
    end
end