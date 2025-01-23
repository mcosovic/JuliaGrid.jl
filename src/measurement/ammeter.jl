"""
    addAmmeter!(system::PowerSystem, device::Measurement;
        label, from, to, magnitude, variance, noise, status)

The function adds a new ammeter that measures branch current magnitude to the `Measurement`
type within a given `PowerSystem` type. The ammeter can be added to an already defined
branch.

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
* `status`: Operating status of the ammeter:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

# Updates
The function updates the `ammeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `noise = false`,
`status = 1`, which apply to ammeters located at both the from-bus and to-bus ends.
Users can fine-tune these settings by explicitly specifying the variance and status for
ammeters positioned on either the from-bus or to-bus ends of branches using the
[`@ammeter`](@ref @ammeter) macro.

# Units
The default units for the `magnitude` and `variance` keywords are per-units (pu). However,
users can choose to use amperes (A) as the units by applying the [`@current`](@ref @current)
macro.

# Examples
Adding ammeters using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", magnitude = 1.1)
addAmmeter!(system, device; label = "Ammeter 2", to = "Branch 1", magnitude = 1.0)
```

Adding ammeters using a custom unit system:
```jldoctest
@current(A, rad)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", magnitude = 481.125)
addAmmeter!(system, device; label = "Ammeter 2", to = "Branch 1", magnitude = 437.386)
```
"""
function addAmmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    magnitude::FltInt,
    kwargs...
)
    branch = system.branch
    baseVoltg = system.base.voltage
    def = template.ammeter
    key = meterkwargs(def.noise; kwargs...)

    location, fromFlag, toFlag = checkLocation(from, to)
    lblBrch = getLabel(branch, location, "branch")
    idxBrch = branch.label[getLabel(branch, location, "branch")]

    if branch.layout.status[idxBrch] == 1
        device.ammeter.number += 1
        push!(device.ammeter.layout.index, idxBrch)
        push!(device.ammeter.layout.from, fromFlag)
        push!(device.ammeter.layout.to, toFlag)

        from, to = fromto(system, idxBrch)
        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        if fromFlag
            setLabel(device.ammeter, label, def.label, lblBrch; prefix = "From ")
            defVariance = def.varianceFrom
            defStatus = def.statusFrom
            baseVoltage = baseVoltg.value[from] * baseVoltg.prefix
        else
            setLabel(device.ammeter, label, def.label, lblBrch; prefix = "To ")
            defVariance = def.varianceTo
            defStatus = def.statusTo
            baseVoltage = baseVoltg.value[to] * baseVoltg.prefix
        end

        baseInv = baseCurrentInv(basePowerInv, baseVoltage)

        setMeter(
            device.ammeter.magnitude, magnitude, key.variance, key.status, key.noise,
            defVariance, defStatus, pfx.currentMagnitude, baseInv
        )
    end
end

"""
    addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates ammeters into the `Measurement` type for every branch within the
`PowerSystem` type. These measurements are derived from the exact branch current magnitude
values defined in the `AC` type.

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
  * `noise = true`: adds white Gaussian noise to the current magnitudes, using the defined variances,
  * `noise = false`: uses the exact current magnitude values without adding noise.

# Updates
The function updates the `ammeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceFrom = 1e-2`, `statusFrom = 1`,
`varianceTo = 1e-2`, `statusTo = 1`, and `noise = false`. Users can change these default
settings using the [`@ammeter`](@ref @ammeter) macro.

# Units
The default units for the `varianceFrom` and `varianceTo` keywords are per-units (pu).
However, users can choose to use amperes (A) as the units by applying the
[`@current`](@ref @current) macro.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement()

acModel!(system)
analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
current!(system, analysis)

@ammeter(label = "Ammeter ?")
addAmmeter!(system, device, analysis; varianceFrom = 1e-3, statusTo = 0)
```
"""
function addAmmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::AC;
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    noise::Bool = template.ammeter.noise,
    outofservice::Bool = true
)
    errorCurrent(analysis.current.from.magnitude)

    baseVoltg = system.base.voltage
    current = analysis.current
    amp = device.ammeter
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

        amp.label = OrderedDict{template.device, Int64}()
        sizehint!(amp.label, ammNumber)

        amp.layout.index = fill(0, ammNumber)
        amp.layout.from = fill(false, ammNumber)
        amp.layout.to = fill(false, ammNumber)

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
    updateAmmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

The function allows for the alteration of parameters for an ammeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
composite type only. However, when including the `Analysis` type, it updates both the
`Measurement` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific ammeter, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addAmmeter!`](@ref addAmmeter!) function, along with
their respective values. Ensure that the `label` keyword matches the `label` of the
existing ammeter you want to modify. If any keywords are omitted, their corresponding
values will remain unchanged.

# Updates
The function updates the `ammeter` field within the `Measurement` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addAmmeter!`](@ref addAmmeter!) function.

# Example
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addAmmeter!(system, device; label = "Ammeter 1", from = "Branch 1", magnitude = 1.1)
updateAmmeter!(system, device; label = "Ammeter 1", magnitude = 1.2, variance = 1e-4)
```
"""
function updateAmmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    baseVoltg = system.base.voltage
    amp = device.ammeter
    key = meterkwargs(template.ammeter.noise; kwargs...)

    idx = amp.label[getLabel(amp, label, "ammeter")]
    idxBrch = amp.layout.index[idx]

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = baseVoltageEnd(system, baseVoltg, amp.layout.from[idx], idxBrch)

    updateMeter(
        amp.magnitude, idx, magnitude, key.variance, key.status, key.noise,
        pfx.currentMagnitude, baseCurrentInv(basePowerInv, baseVoltage)
    )
end

function updateAmmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{NonlinearWLS{T}};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    baseVoltg = system.base.voltage
    amp = device.ammeter
    se = analysis.method
    key = meterkwargs(template.ammeter.noise; kwargs...)

    idxAmp = amp.label[getLabel(amp, label, "ammeter")]
    idxBrch = amp.layout.index[idxAmp]
    idx = device.voltmeter.number + idxAmp

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = baseVoltageEnd(system, baseVoltg, amp.layout.from[idxAmp], idxBrch)

    updateMeter(
        amp.magnitude, idxAmp, magnitude, key.variance, key.status, key.noise,
        pfx.currentMagnitude, baseCurrentInv(basePowerInv, baseVoltage)
    )

    if amp.magnitude.status[idxAmp] == 1
        if amp.layout.from[idxAmp]
            se.type[idx] = 2
        else
            se.type[idx] = 3
        end
        se.mean[idx] = amp.magnitude.mean[idxAmp]
    else
        i, j = fromto(system, idxBrch)

        se.jacobian[idx, i] = 0.0
        se.jacobian[idx, system.bus.number + i] = 0.0
        se.jacobian[idx, j] = 0.0
        se.jacobian[idx, system.bus.number + j] = 0.0

        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(key.variance)
        se.precision[idx, idx] = 1 / amp.magnitude.variance[idxAmp]
    end
end

function updateAmmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{LAV};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    baseVoltg = system.base.voltage
    amp = device.ammeter
    se = analysis.method
    key = meterkwargs(template.ammeter.noise; kwargs...)

    idxAmp = amp.label[getLabel(amp, label, "ammeter")]
    idxBrch = amp.layout.index[idxAmp]
    idx = device.voltmeter.number + idxAmp

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    baseVoltage = baseVoltageEnd(system, baseVoltg, amp.layout.from[idxAmp], idxBrch)

    updateMeter(
        amp.magnitude, idxAmp, magnitude, key.variance, key.status, key.noise,
        pfx.currentMagnitude, baseCurrentInv(basePowerInv, baseVoltage)
    )

    if amp.magnitude.status[idxAmp] == 1
        add!(se, idx)

        if amp.layout.from[idxAmp]
            expr = Iij(system, se, idxBrch)
        else
            expr = Iji(system, se, idxBrch)
        end
        addConstrLav!(se, expr, amp.magnitude.mean[idxAmp], idx)
    else
        remove!(se, idx)
    end
end

"""
    @ammeter(label, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The macro generates a template for an ammeter, which can be utilized to define an ammeter
using the [`addAmmeter!`](@ref addAmmeter!) function.

# Keywords
To establish the ammeter template, users can set default variance and status values for
ammeters at both the from-bus and to-bus ends of branches, using `varianceFrom` and
`statusFrom` for the former and `varianceTo` and `statusTo` for the latter. Users can also
configure label patterns with the `label` keyword, as well as specify the `noise` type.

# Units
The default units for the `varianceFrom` and `varianceTo` keywords are per-units (pu).
However, users can choose to use amperes (A) as the units by applying the
[`@current`](@ref @current) macro.

# Examples
Adding an ammeter using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@ammeter(label = "Ammeter ?", varianceTo = 1e-3, statusTo = 0)
addAmmeter!(system, device; to = "Branch 1", magnitude = 1.1)
```

Adding an ammeter using a custom unit system:
```jldoctest
@current(A, rad)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@ammeter(label = "Ammeter ?", varianceTo = 0.004374, statusTo = 0)
addAmmeter!(system, device; label = "Ammeter 1", to = "Branch 1", magnitude = 481.125)
```
"""
macro ammeter(kwargs...)
    for kwarg in kwargs
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
            elseif parameter == :noise
                setfield!(template.ammeter, parameter, Bool(eval(kwarg.args[2])))
            elseif parameter == :label
                label = string(kwarg.args[2])
                if contains(label, "?") || contains(label, "!")
                    setfield!(template.ammeter, parameter, label)
                else
                    errorTemplateLabel()
                end
            end
        else
            errorTemplateKeyword(parameter)
        end
    end
end