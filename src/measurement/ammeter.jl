"""
    addAmmeter!(system::PowerSystem, device::Measurement; label, from, to,
        magnitude, variance, status, noise)

The function adds a new ammeter to the `Measurement` composite type within a given
`PowerSystem` type. The ammeter can be added to an already defined branch.

# Keywords
The ammeter is defined with the following keywords:
* `label`: a unique label for the ammeter;
* `from`: the label of the branch if the ammeter is located at the "from" bus end;
* `to`: the label of the branch if the ammeter is located at the "to" bus end;
* `magnitude` (pu or A): the branch current magnitude value;
* `variance` (pu or A): the variance of the branch current magnitude measurement;
* `status`: the operating status of the ammeter:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `noise`:
  * `noise = true`: AWGN with `variance` influences `magnitude` to define the measurement mean;
  * `noise = false`: the value of `magnitude` is used as the measurement mean.

# Updates
The function updates the `ammeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `status = 1`,
`noise = true`, which apply to ammeters located at both the "from" and "to" bus ends.
Users can fine-tune these settings by explicitly specifying the variance and status for
ammeters positioned on either the "from" or "to" bus ends of branches using the 
[@ammetar](@ref @ammetar) macro.

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
    magnitude::T, variance::T = missing, status::T = missing,
    noise::Bool = template.ammeter.noise)

    ammeter = device.ammeter
    default = template.ammeter

    location = checkLocation(ammeter, from, to)

    ammeter.number += 1
    setLabel(ammeter, label, default.label, "ammeter")

    index = system.branch.label[getLabel(system.branch, location, "branch")]
    push!(ammeter.layout.index, index)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if ammeter.layout.from[end]
        defaultVariance = default.varianceFrom
        defaultStatus = default.statusFrom
        baseVoltage = system.base.voltage.value[system.branch.layout.from[index]] * system.base.voltage.prefix
    else
        defaultVariance = default.varianceTo
        defaultStatus = default.statusTo
        baseVoltage = system.base.voltage.value[system.branch.layout.to[index]] * system.base.voltage.prefix
    end

    baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
    setMeter(ammeter.magnitude, magnitude, variance, status, noise, defaultVariance,
        defaultStatus, prefix.currentMagnitude, baseCurrentInv)
end

"""
    addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceFrom, statusFrom, varianceTo, statusTo)

The function incorporates ammeters into the `Measurement` composite type for every branch
within the `PowerSystem` type. These measurements are derived from the exact branch current
magnitudes defined in the `AC` abstract type. These exact values are perturbed by AWGN
with the specified `variance` to obtain measurement data.

# Keywords
Users have the option to configure the following keywords:
* `varianceFrom` (pu or A): the measurement variance for ammeters at the "from" bus ends of branches;
* `statusFrom`: the operating status of the ammeters at the "from" bus ends of branches:
  * `statusFrom = 1`: in-service;
  * `statusFrom = 0`: out-of-service;
* `varianceTo` (pu or A): the measurement variance for ammeters at the "to" bus ends of branches;
* `statusTo`: the operating status of the ammeters at the "to" bus ends of branches:
  * `statusTo = 1`: in-service;
  * `statusTo = 0`: out-of-service.

# Updates
The function updates the `ammeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceFrom = 1e-2`, `statusFrom = 1`, 
`varianceTo = 1e-2`, and `statusTo = 1`. Users can change these default settings using the
[@ammetar](@ref @ammetar) macro.

# Units
The default units for the `varianceFrom` and `varianceTo` keywords are per-units (pu).
However, users can choose to use amperes (A) as the units by applying the
[`@current`](@ref @current) macro.

# Abstract type
The abstract type `AC` can have the following subtypes:
- `ACPowerFlow`: generates measurements uses AC power flow results;
- `ACOptimalPowerFlow`: generates measurements uses AC optimal power flow results.

# Examples
Adding ammeters using exact values from the AC power flow:
```jldoctest
system = powerSystem("case14.h5")
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

device = measurement()

@ammeter(label = "Ammeter ?")
addAmmeter!(system, device, analysis; varianceFrom = 1e-3, statusTo = 0)
```

Adding ammeters using exact values from the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

device = measurement()

@ammeter(label = "Ammeter ?")
addAmmeter!(system, device, analysis; varianceFrom = 1e-3, statusTo = 0)
```
"""
function addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceFrom::T = missing, varianceTo::T = missing,
    statusFrom::T = missing, statusTo::T = missing)

    ammeter = device.ammeter
    default = template.ammeter

    statusFrom = unitless(statusFrom, default.statusFrom)
    checkStatus(statusFrom)

    statusTo = unitless(statusTo, default.statusTo)
    checkStatus(statusTo)

    ammeter.number = 2 * system.branch.number
    ammeter.label = Dict{String,Int64}(); sizehint!(ammeter.label, ammeter.number)

    ammeter.layout.index = fill(0, ammeter.number)
    ammeter.layout.from = fill(false, ammeter.number)
    ammeter.layout.to = fill(false, ammeter.number)

    ammeter.magnitude.mean = fill(0.0, ammeter.number)
    ammeter.magnitude.variance = similar(ammeter.magnitude.mean)
    ammeter.magnitude.status = fill(Int8(0), ammeter.number)

    count = 1
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for i = 1:2:ammeter.number
        ammeter.label[replace(default.label, r"\?" => string(i))] = i
        ammeter.label[replace(default.label, r"\?" => string(i + 1))] = i + 1

        ammeter.layout.index[i] = count
        ammeter.layout.index[i + 1] = count
        ammeter.layout.from[i] = true
        ammeter.layout.to[i + 1] = true

        baseVoltage = system.base.voltage.value[system.branch.layout.from[count]] * system.base.voltage.prefix
        baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
        ammeter.magnitude.variance[i] = topu(varianceFrom, default.varianceFrom, prefix.currentMagnitude, baseCurrentInv)
        ammeter.magnitude.mean[i] = analysis.current.from.magnitude[count] + ammeter.magnitude.variance[i]^(1/2) * randn(1)[1]
        ammeter.magnitude.status[i] = statusFrom

        baseVoltage = system.base.voltage.value[system.branch.layout.to[count]] * system.base.voltage.prefix
        baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
        ammeter.magnitude.variance[i + 1] = topu(varianceTo, default.varianceTo, prefix.currentMagnitude, baseCurrentInv)
        ammeter.magnitude.mean[i + 1] = analysis.current.to.magnitude[count] + ammeter.magnitude.variance[i + 1]^(1/2) * randn(1)[1]
        ammeter.magnitude.status[i + 1] = statusTo

        count += 1
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
    magnitude::T = missing, variance::T = missing, status::T = missing,
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

"""
    @ammeter(label, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The macro generates a template for an ammeter, which can be utilized to define an ammeter
using the [`addAmmeter!`](@ref addAmmeter!) function.

# Keywords
To establish the ammeter template, users can set default variance and status values for
ammeters at both the "from" and "to" bus ends of branches using `varianceFrom` and
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

@ammeter(label = "Ammeter ?", varianceTo = 1e-3, statusTo = 0, noise = false)
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

@ammeter(label = "Ammeter ?", varianceTo = 0.004374, statusTo = 0, noise = false)
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
                if contains(label, "?")
                    setfield!(template.ammeter, parameter, label)
                else
                    throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end