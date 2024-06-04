"""
    addAmmeter!(system::PowerSystem, device::Measurement; label, from, to, magnitude,
        variance, noise, status)

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
function addAmmeter!(system::PowerSystem, device::Measurement;
    label::L = missing, from::L = missing, to::L = missing,
    magnitude::A, variance::A = missing, status::A = missing,
    noise::Bool = template.ammeter.noise)

    ammeter = device.ammeter
    default = template.ammeter

    location, fromFlag, toFlag = checkLocation(from, to)
    labelBranch = getLabel(system.branch, location, "branch")
    indexBranch = system.branch.label[getLabel(system.branch, location, "branch")]

    if system.branch.layout.status[indexBranch] == 1
        ammeter.number += 1
        push!(ammeter.layout.index, indexBranch)
        push!(ammeter.layout.from, fromFlag)
        push!(ammeter.layout.to, toFlag)

        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        if fromFlag
            setLabel(ammeter, label, default.label, labelBranch; prefix = "From ")
            defaultVariance = default.varianceFrom
            defaultStatus = default.statusFrom
            baseVoltage = system.base.voltage.value[system.branch.layout.from[indexBranch]] * system.base.voltage.prefix
        else
            setLabel(ammeter, label, default.label, labelBranch; prefix = "To ")
            defaultVariance = default.varianceTo
            defaultStatus = default.statusTo
            baseVoltage = system.base.voltage.value[system.branch.layout.to[indexBranch]] * system.base.voltage.prefix
        end

        baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

        setMeter(ammeter.magnitude, magnitude, variance, status, noise, defaultVariance, defaultStatus, prefix.currentMagnitude, baseCurrentInv)
    end
end

"""
    addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC; varianceFrom,
        statusFrom, varianceTo, statusTo, noise)

The function incorporates ammeters into the `Measurement` type for every branch within the
`PowerSystem` type. These measurements are derived from the exact branch current magnitudes
defined in the `AC` type.

# Keywords
Users have the option to configure the following keywords:
* `varianceFrom` (pu or A): Measurement variance for ammeters at the from-bus ends.
* `statusFrom`: Operating status of the ammeters at the from-bus ends:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service.
* `varianceTo` (pu or A): Measurement variance for ammeters at the to-bus ends.
* `statusTo`: Operating status of the ammeters at the to-bus ends:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the current magnitudes,
  * `noise = false`: uses the exact current magnitude values.

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
function addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceFrom::A = missing, varianceTo::A = missing,
    statusFrom::A = missing, statusTo::A = missing, noise::Bool = template.ammeter.noise)

    if isempty(analysis.current.from.magnitude)
        throw(ErrorException("The currents cannot be found."))
    end

    ammeter = device.ammeter
    default = template.ammeter
    ammeter.number = 0

    statusFrom = unitless(statusFrom, default.statusFrom)
    checkStatus(statusFrom)

    statusTo = unitless(statusTo, default.statusTo)
    checkStatus(statusTo)

    ammeterNumber = 2 * system.branch.layout.inservice
    ammeter.label = OrderedDict{String,Int64}(); sizehint!(ammeter.label, ammeterNumber)

    ammeter.layout.index = fill(0, ammeterNumber)
    ammeter.layout.from = fill(false, ammeterNumber)
    ammeter.layout.to = fill(false, ammeterNumber)

    ammeter.magnitude.mean = fill(0.0, ammeterNumber)
    ammeter.magnitude.variance = similar(ammeter.magnitude.mean)
    ammeter.magnitude.status = fill(Int8(0), ammeterNumber)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for (label, i) in system.branch.label
        if system.branch.layout.status[i] == 1
            ammeter.number += 1
            setLabel(ammeter, missing, default.label, label; prefix = "From ")

            ammeter.layout.index[ammeter.number] = i
            ammeter.layout.index[ammeter.number + 1] = i

            ammeter.layout.from[ammeter.number] = true
            ammeter.layout.to[ammeter.number + 1] = true

            ammeter.magnitude.status[ammeter.number] = statusFrom
            ammeter.magnitude.status[ammeter.number + 1] = statusTo

            baseCurrentFromInv = baseCurrentInverse(basePowerInv, system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix)
            ammeter.magnitude.variance[ammeter.number] = topu(varianceFrom, default.varianceFrom, prefix.currentMagnitude, baseCurrentFromInv)

            baseCurrentToInv = baseCurrentInverse(basePowerInv, system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix)
            ammeter.magnitude.variance[ammeter.number + 1] = topu(varianceTo, default.varianceTo, prefix.currentMagnitude, baseCurrentToInv)

            if noise
                ammeter.magnitude.mean[ammeter.number] = analysis.current.from.magnitude[i] + ammeter.magnitude.variance[ammeter.number]^(1/2) * randn(1)[1]
                ammeter.magnitude.mean[ammeter.number + 1] = analysis.current.to.magnitude[i] + ammeter.magnitude.variance[ammeter.number + 1]^(1/2) * randn(1)[1]
            else
                ammeter.magnitude.mean[ammeter.number] = analysis.current.from.magnitude[i]
                ammeter.magnitude.mean[ammeter.number + 1] = analysis.current.to.magnitude[i]
            end

            ammeter.number += 1
            setLabel(ammeter, missing, default.label, label; prefix = "To ")
        end
    end
    ammeter.layout.label = ammeter.number
end

"""
    updateAmmeter!(system::PowerSystem, device::Measurement, analysis::Analysis; kwargs...)

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
function updateAmmeter!(system::PowerSystem, device::Measurement; label::L,
    magnitude::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.ammeter.noise)

    ammeter = device.ammeter

    index = ammeter.label[getLabel(ammeter, label, "ammeter")]
    indexBranch = ammeter.layout.index[index]

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if ammeter.layout.from[index]
        baseVoltage = system.base.voltage.value[system.branch.layout.from[indexBranch]] * system.base.voltage.prefix
    else
        baseVoltage = system.base.voltage.value[system.branch.layout.to[indexBranch]] * system.base.voltage.prefix
    end
    baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

    updateMeter(ammeter.magnitude, index, magnitude, variance, status, noise,
    prefix.currentMagnitude, baseCurrentInv)
end

function updateAmmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{NonlinearWLS{T}};
    label::L, magnitude::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.ammeter.noise) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    ammeter = device.ammeter
    se = analysis.method

    indexAmmeter = ammeter.label[getLabel(ammeter, label, "ammeter")]
    indexBranch = ammeter.layout.index[indexAmmeter]
    idx = device.voltmeter.number + indexAmmeter

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if ammeter.layout.from[indexAmmeter]
        baseVoltage = system.base.voltage.value[system.branch.layout.from[indexBranch]] * system.base.voltage.prefix
    else
        baseVoltage = system.base.voltage.value[system.branch.layout.to[indexBranch]] * system.base.voltage.prefix
    end

    updateMeter(ammeter.magnitude, indexAmmeter, magnitude, variance, status, noise,
    prefix.currentMagnitude, baseCurrentInverse(basePowerInv, baseVoltage))

    if ammeter.magnitude.status[indexAmmeter] == 1
        if ammeter.layout.from[indexAmmeter]
            se.type[idx] = 2
        else
            se.type[idx] = 3
        end
        se.mean[idx] = ammeter.magnitude.mean[indexAmmeter]
    else
        se.jacobian[idx, branch.layout.from[indexBranch]] = 0.0
        se.jacobian[idx, bus.number + branch.layout.from[indexBranch]] = 0.0
        se.jacobian[idx, branch.layout.to[indexBranch]] = 0.0
        se.jacobian[idx, bus.number + branch.layout.to[indexBranch]] = 0.0
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(variance)
        se.precision[idx, idx] = 1 / ammeter.magnitude.variance[indexAmmeter]
    end
end

function updateAmmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{LAV};
    label::L, magnitude::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.ammeter.noise)

    ammeter = device.ammeter
    se = analysis.method

    indexAmmeter = ammeter.label[getLabel(ammeter, label, "ammeter")]
    indexBranch = ammeter.layout.index[indexAmmeter]
    idx = device.voltmeter.number + indexAmmeter

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if ammeter.layout.from[indexAmmeter]
        baseVoltage = system.base.voltage.value[system.branch.layout.from[indexBranch]] * system.base.voltage.prefix
    else
        baseVoltage = system.base.voltage.value[system.branch.layout.to[indexBranch]] * system.base.voltage.prefix
    end

    updateMeter(ammeter.magnitude, indexAmmeter, magnitude, variance, status, noise,
    prefix.currentMagnitude, baseCurrentInverse(basePowerInv, baseVoltage))

    if ammeter.magnitude.status[indexAmmeter] == 1
        addDeviceLAV(se, idx)

        remove!(se.jump, se.residual, idx)
        addAmmeterResidual!(system, ammeter, se, indexBranch, idx, indexAmmeter)
    else
        removeDeviceLAV(se, idx)
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
                if prefix.currentMagnitude != 0.0
                    setfield!(container, :value, prefix.currentMagnitude * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
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
                    throw(ErrorException("The label template is missing the '?' or '!' symbols."))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end