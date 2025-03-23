##### Meter Keywords #####
function meterkwargs(
    defnoise::Bool;
    variance::FltIntMiss = missing,
    status::IntMiss = missing,
    noise::Bool = defnoise,
)
    (variance = variance, status = status, noise = noise)
end

##### PMU Keywords #####
function pmukwargs(
    def::PmuTemplate;
    magnitude::FltIntMiss = missing,
    angle::FltIntMiss = missing,
    varianceMagnitude::FltIntMiss = missing,
    varianceAngle::FltIntMiss = missing,
    status::FltIntMiss = missing,
    noise::Bool = def.noise,
    correlated::BoolMiss = missing,
    polar::BoolMiss = missing
)
    (
    magnitude = magnitude, angle = angle,
    varianceMagnitude = varianceMagnitude, varianceAngle = varianceAngle,
    status = status, noise = noise, correlated = correlated, polar = polar
    )
end

##### Check Meter Location #####
function checkLocation(locations::IntStrMiss...)
    flag = fill(false, lastindex(locations))
    count = 0
    @inbounds for (index, value) in enumerate(locations)
        if isset(value)
            count += 1
            flag[index] = true
        end
    end

    if count == 0
        throw(ErrorException("At least one of the location keywords must be provided."))
    elseif count > 1
        throw(ErrorException("Concurrent location keyword definition is not allowed."))
    end

    return locations[flag][1], flag...
end

##### Set Mean, Variance, and Status #####
function setMeter(
    device::GaussMeter,
    mean::FltIntMiss,
    variance::FltIntMiss,
    status::IntMiss,
    noise::Bool,
    defVariance::ContainerTemplate,
    defStatus::Int8,
    pfxLive::Float64,
    baseInv::Float64
)
    add!(device.variance, variance, defVariance, pfxLive, baseInv)

    measure = topu(mean, pfxLive, baseInv)
    if noise
        measure += device.variance[end]^(1/2) * randn(1)[1]
    end
    push!(device.mean, measure)

    add!(device.status, status, defStatus)
    checkStatus(device.status[end])
end

##### Update Mean, Variance, and Status #####
function updateMeter(
    device::GaussMeter,
    idx::Int64,
    mean::FltIntMiss,
    variance::FltIntMiss,
    status::IntMiss,
    noise::Bool,
    pfxLive::Float64,
    baseInv::Float64
)
    update!(device.variance, variance, pfxLive, baseInv, idx)

    if isset(mean)
        device.mean[idx] = topu(mean, pfxLive, baseInv)
        if noise
            device.mean[idx] += device.variance[idx]^(1/2) * randn(1)[1]
        end
    end

    if isset(status)
        checkStatus(status)
        device.status[idx] = status
    end
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

    meter.mean[idx] = exact
    if noise
        meter.mean[idx] += meter.variance[idx]^(1/2) * randn(1)[1]
    end
end

function add!(method::LAV, idx::Int64)
    remove!(method.jump, method.residual, idx)

    if is_fixed(method.deviation.positive[idx])
        unfix(method.deviation.positive[idx])
        unfix(method.deviation.negative[idx])
        set_lower_bound(method.deviation.positive[idx], 0.0)
        set_lower_bound(method.deviation.negative[idx], 0.0)

        set_objective_coefficient(method.jump, method.deviation.positive[idx], 1)
        set_objective_coefficient(method.jump, method.deviation.negative[idx], 1)
    end
end

##### Delete Meter #####
function remove!(method::LAV, idx::Int64)
    remove!(method.jump, method.residual, idx)

    if !is_fixed(method.deviation.positive[idx])
        fix(method.deviation.positive[idx], 0.0; force = true)
        fix(method.deviation.negative[idx], 0.0; force = true)

        set_objective_coefficient(method.jump, method.deviation.positive[idx], 0)
        set_objective_coefficient(method.jump, method.deviation.negative[idx], 0)
    end
end