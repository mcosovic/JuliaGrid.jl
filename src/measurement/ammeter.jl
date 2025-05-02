"""
    addAmmeter!(monitoring::Measurement;
        label, from, to, magnitude, variance, noise, square, status)

The function adds an ammeter that measures branch current magnitude to the `Measurement` type. The
ammeter can be added to an already defined branch.

# Keywords
The ammeter is defined with the following keywords:
* `label`: Unique label for the ammeter.
* `from`: Label of the branch if the ammeter is located at the from-bus end.
* `to`: Label of the branch if the ammeter is located at the to-bus end.
* `magnitude` (pu or A): Branch current magnitude value.
* `variance` (pu or A): Variance of the branch current magnitude measurement.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the `magnitude`,
  * `noise = false`: uses the `magnitude` value only.
* `square`: Specifies how the measurement is included in the state estimation model:
  * `square = true`: included in squared form,
  * `square = false`: included in its original form.
* `status`: Operating status of the ammeter:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

# Updates
The function updates the `ammeter` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`,
`square = false`, and `status = 1`, which apply to ammeters located at both the from-bus and to-bus
ends. Users can fine-tune these settings by explicitly specifying the variance and status for
ammeters positioned on either the from-bus or to-bus ends of branches using the
[`@ammeter`](@ref @ammeter) macro.

# Units
The default units for the `magnitude` and `variance` keywords are per-units. However, users can
choose to use amperes as the units by applying the [`@current`](@ref @current) macro.

# Examples
Adding ammeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(monitoring; label = "Ammeter 1", from = "Branch 1", magnitude = 1.1)
addAmmeter!(monitoring; label = "Ammeter 2", to = "Branch 1", magnitude = 1.0)
```

Adding ammeters using a custom unit system:
```jldoctest
@current(A, rad)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(monitoring; label = "Ammeter 1", from = "Branch 1", magnitude = 481.125)
addAmmeter!(monitoring; label = "Ammeter 2", to = "Branch 1", magnitude = 437.386)
```
"""
function addAmmeter!(
    monitoring::Measurement;
    label::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    magnitude::FltInt,
    square::Bool = template.ammeter.square,
    kwargs...
)
    system = monitoring.system
    branch = system.branch
    baseVoltg = system.base.voltage
    def = template.ammeter
    key = meterkwargs(def.noise; kwargs...)

    location, fromFlag, toFlag = checkLocation(from, to)
    lblBrch = getLabel(branch, location, "branch")
    idxBrch = branch.label[getLabel(branch, location, "branch")]

    if branch.layout.status[idxBrch] == 1
        monitoring.ammeter.number += 1
        push!(monitoring.ammeter.layout.index, idxBrch)
        push!(monitoring.ammeter.layout.from, fromFlag)
        push!(monitoring.ammeter.layout.to, toFlag)
        push!(monitoring.ammeter.layout.square, square)

        from, to = fromto(system, idxBrch)
        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        if fromFlag
            setLabel(monitoring.ammeter, label, def.label, lblBrch; prefix = "From ")
            defVariance = def.varianceFrom
            defStatus = def.statusFrom
            baseVoltage = baseVoltg.value[from] * baseVoltg.prefix
        else
            setLabel(monitoring.ammeter, label, def.label, lblBrch; prefix = "To ")
            defVariance = def.varianceTo
            defStatus = def.statusTo
            baseVoltage = baseVoltg.value[to] * baseVoltg.prefix
        end

        baseInv = baseCurrentInv(basePowerInv, baseVoltage)

        setMeter(
            monitoring.ammeter.magnitude, magnitude, key.variance, key.status, key.noise,
            defVariance, defStatus, pfx.currentMagnitude, baseInv
        )
    end
end

"""
    addAmmeter!(monitoring::Measurement, analysis::AC;
        varianceFrom, statusFrom, varianceTo, statusTo, noise, square)

The function incorporates ammeters into the `Measurement` type for every branch within the
`PowerSystem` type from which `Measurement` was created. These measurements are derived from the
exact branch current magnitudes defined in the `AC` type.

# Keywords
Ammeters at the from-bus ends of the branches can be configured using:
* `varianceFrom` (pu or A): Measurement variance.
* `statusFrom`: Operating status:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service,
  * `statusFrom = -1`: not included in the `Measurement` type.
Ammeters at the to-bus ends of the branches can be configured using:
* `varianceTo` (pu or A): Measurement variance.
* `statusTo`: Operating status:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service,
  * `statusTo = -1`: not included in the `Measurement` type.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the current magnitudes using defined variances,
  * `noise = false`: uses the exact current magnitude values without adding noise.
Settings for including measurements:
* `square`: Specifies how measurements are included in the state estimation model:
  * `square = true`: included in squared form,
  * `square = false`: included in its original form.

# Updates
The function updates the `ammeter` field of the `Measurement` type.

# Default Settings
Default settings for keywords are as follows: `varianceFrom = 1e-4`, `statusFrom = 1`,
`varianceTo = 1e-4`, `statusTo = 1`, `noise = false`, and `square = false`. Users can change these
default settings using the [`@ammeter`](@ref @ammeter) macro.

# Units
The default units for the `varianceFrom` and `varianceTo` keywords are per-units. However, users can
choose to use amperes as the units by applying the [`@current`](@ref @current) macro.

# Example
```jldoctest
@ammeter(label = "Ammeter ?")

system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; current = true)

addAmmeter!(monitoring, analysis; varianceFrom = 1e-3, statusTo = 0, square = true)
```
"""
function addAmmeter!(
    monitoring::Measurement,
    analysis::AC;
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    square::Bool = template.ammeter.square,
    noise::Bool = template.ammeter.noise,
)
    errorCurrent(analysis.current.from.magnitude)

    system = monitoring.system
    baseVoltg = system.base.voltage
    current = analysis.current
    amp = monitoring.ammeter
    def = template.ammeter

    amp.number = 0

    statusFrom = givenOrDefault(statusFrom, def.statusFrom)
    checkWideStatus(statusFrom)

    statusTo = givenOrDefault(statusTo, def.statusTo)
    checkWideStatus(statusTo)

    if statusFrom != -1 || statusTo != -1
        if statusFrom != -1 && statusTo != -1
            ammNumber = 2 * system.branch.layout.inservice
        else
            ammNumber = system.branch.layout.inservice
        end

        amp.label = OrderedDict{template.ammeter.key, Int64}()
        sizehint!(amp.label, ammNumber)

        amp.layout.index = fill(0, ammNumber)
        amp.layout.from = fill(false, ammNumber)
        amp.layout.to = fill(false, ammNumber)
        amp.layout.square = fill(square, ammNumber)

        amp.magnitude.mean = fill(0.0, ammNumber)
        amp.magnitude.variance = similar(amp.magnitude.mean)
        amp.magnitude.status = fill(Int8(0), ammNumber)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)
        @inbounds for (label, i) in system.branch.label
            if system.branch.layout.status[i] == 1
                from, to = fromto(system, i)

                if statusFrom != -1
                    amp.number += 1
                    setLabel(amp, missing, def.label, label; prefix = "From ")

                    amp.layout.index[amp.number] = i
                    amp.layout.from[amp.number] = true
                    baseFromInv = baseCurrentInv(baseInv, baseVoltg.value[from] * baseVoltg.prefix)

                    add!(
                        amp.magnitude, amp.number, noise, pfx.currentMagnitude,
                        current.from.magnitude[i], varianceFrom, def.varianceFrom,
                        statusFrom, baseFromInv
                    )
                end

                if statusTo != -1
                    amp.number += 1
                    setLabel(amp, missing, def.label, label; prefix = "To ")

                    amp.layout.index[amp.number] = i
                    amp.layout.to[amp.number] = true
                    baseToInv = baseCurrentInv(baseInv, baseVoltg.value[to] * baseVoltg.prefix)

                    add!(
                        amp.magnitude, amp.number, noise, pfx.currentMagnitude,
                        current.to.magnitude[i], varianceTo, def.varianceTo,
                        statusTo, baseToInv
                    )
                end
            end
        end
        amp.layout.label = amp.number
    end
end

"""
    updateAmmeter!(monitoring::Measurement; kwargs...)

The function allows for the alteration of parameters for an ammeter.

# Keywords
To update a specific ammeter, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addAmmeter!`](@ref addAmmeter!) function, along with their respective
values. Ensure that the `label` keyword matches the `label` of the existing ammeter you want to
modify. If any keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `ammeter` field within the `Measurement` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addAmmeter!`](@ref addAmmeter!) function.

# Example
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(monitoring; label = "Ammeter 1", from = "Branch 1", magnitude = 1.1)
updateAmmeter!(monitoring; label = "Ammeter 1", magnitude = 1.2, variance = 1e-3)
```
"""
function updateAmmeter!(
    monitoring::Measurement;
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    square::BoolMiss = missing,
    kwargs...
)
    system = monitoring.system
    baseVoltg = system.base.voltage
    amp = monitoring.ammeter
    key = meterkwargs(template.ammeter.noise; kwargs...)

    idx = getIndex(amp, label, "ammeter")
    idxBrch = amp.layout.index[idx]

    if isset(square)
        amp.layout.square[idx] = square
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = baseVoltageEnd(system, baseVoltg, amp.layout.from[idx], idxBrch)

    updateMeter(
        amp.magnitude, idx, magnitude, key.variance, key.status, key.noise,
        pfx.currentMagnitude, baseCurrentInv(basePowerInv, baseVoltage)
    )

    amp.magnitude.status[idx] &= system.branch.layout.status[idxBrch]
end

"""
    updateAmmeter!(analysis::Analysis; kwargs...)

The function extends the [`updateAmmeter!`](@ref updateAmmeter!(::Measurement)) function. By passing
the `Analysis` type, the function first updates the specific ammeter within the `Measurement` type
using the provided `kwargs`, and then updates the `Analysis` type with all parameters associated with
that ammeter.

A key feature of this function is that any prior modifications made to the specified ammeter are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

updateAmmeter!(analysis; label = "From 1", magnitude = 0.9, variance = 1e-5)
```
"""
function updateAmmeter!(
    analysis::AcStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    square::BoolMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    amp = analysis.monitoring.ammeter
    wls = analysis.method

    updateAmmeter!(analysis.monitoring; label, magnitude, square, kwargs...)

    idxAmp = getIndex(amp, label, "ammeter")
    idxBrch = amp.layout.index[idxAmp]
    idx = analysis.monitoring.voltmeter.number + idxAmp

    status = amp.magnitude.status[idxAmp] == 1
    sq = if2exp(amp.layout.square[idxAmp])
    ty = if2type(amp.layout.square[idxAmp])
    i, j = fromto(analysis.system, idxBrch)

    wls.mean[idx] = status * (amp.magnitude.mean[idxAmp]^sq)
    wls.precision[idx, idx] = 1 / (sq * amp.magnitude.variance[idxAmp])
    wls.residual[idx] = 0.0

    wls.jacobian[idx, i] = 0.0
    wls.jacobian[idx, analysis.system.bus.number + i] = 0.0
    wls.jacobian[idx, j] = 0.0
    wls.jacobian[idx, analysis.system.bus.number + j] = 0.0

    if amp.layout.from[idxAmp]
        wls.type[idx] = status * (2 + ty)
    else
        wls.type[idx] = status * (3 + ty)
    end
end

function updateAmmeter!(
    analysis::AcStateEstimation{LAV};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    square::BoolMiss = missing,
    kwargs...
)
    amp = analysis.monitoring.ammeter
    lav = analysis.method

    updateAmmeter!(analysis.monitoring; label, magnitude, square, kwargs...)

    idxAmp = getIndex(amp, label, "ammeter")
    idxBrch = amp.layout.index[idxAmp]
    idx = analysis.monitoring.voltmeter.number + idxAmp

    remove!(lav, idx)
    if amp.magnitude.status[idxAmp] == 1
        add!(lav, idx)

        if amp.layout.from[idxAmp]
            expr = Iij(analysis.system, lav.variable.voltage, amp.layout.square[idxAmp], idxBrch)
        else
            expr = Iji(analysis.system, lav.variable.voltage, amp.layout.square[idxAmp], idxBrch)
        end

        sq = if2exp(amp.layout.square[idxAmp])
        addConstrLav!(lav, expr, amp.magnitude.mean[idxAmp]^sq, idx)
    end
end

"""
    @ammeter(label, varianceFrom, statusFrom, varianceTo, statusTo, noise, square)

The macro generates a template for an ammeter.

# Keywords
To establish the ammeter template, users can set default variance and status values for ammeters at
both the from-bus and to-bus ends of branches, using `varianceFrom` and `statusFrom` for the former
and `varianceTo` and `statusTo` for the latter. Users can also configure label patterns with the
`label` keyword, as well as specify the `noise` type. Finally, the `square` keyword enables including
the measurement in squared form for the state estimation model.

# Units
The default units for the `varianceFrom` and `varianceTo` keywords are per-units. However, users can
choose to use amperes as the units by applying the [`@current`](@ref @current) macro.

# Examples
Adding an ammeter using the default unit system:
```jldoctest
@ammeter(label = "Ammeter ?", varianceTo = 1e-3, statusTo = 0, square = true)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(monitoring; to = "Branch 1", magnitude = 1.1)
```

Adding an ammeter using a custom unit system:
```jldoctest
@current(A, rad)
@ammeter(label = "Ammeter ?", varianceTo = 0.004374, statusTo = 0, square = true)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(monitoring; label = "Ammeter 1", to = "Branch 1", magnitude = 481.125)
```
"""
macro ammeter(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(AmmeterTemplate, parameter)
                if parameter in [:varianceFrom, :varianceTo]
                    container::ContainerTemplate = getfield(template.ammeter, parameter)
                    val = Float64(eval(kwarg.args[2]))
                    if pfx.currentMagnitude != 0.0
                        setfield!(container, :value, pfx.currentMagnitude * val)
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, val)
                        setfield!(container, :pu, true)
                    end
                elseif parameter in [:statusFrom, :statusTo]
                    setfield!(template.ammeter, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter in [:noise, :square]
                    setfield!(template.ammeter, parameter, Bool(eval(kwarg.args[2])))
                elseif parameter == :label
                    macroLabel(template.ammeter, kwarg.args[2], "[?!]")
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end