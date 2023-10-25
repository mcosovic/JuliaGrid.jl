"""
    addWattmeter!(system::PowerSystem, device::Measurement; label, bus, from, to, active,
        variance, status, noise)

The function adds a new wattmeter that measures active power flow or injection to the 
`Measurement` composite type within a given `PowerSystem` type. The wattmeter can be added 
to an already defined bus or branch.

# Keywords
The wattmeter is defined with the following keywords:
* `label`: a unique label for the wattmeter;
* `bus`: the label of the bus if the wattmeter is located at the bus;
* `from`: the label of the branch if the wattmeter is located at the "from" bus end;
* `to`: the label of the branch if the wattmeter is located at the "to" bus end;
* `active` (pu or W): the active power value;
* `variance` (pu or W): the variance of the active power measurement;
* `status`: the operating status of the wattmeter:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `noise`: specifies how to generate the measurement mean:
  * `noise = true`: Adds white Gaussian noise with the `variance` to the `active`;
  * `noise = false`: uses the `active` value only.

# Updates
The function updates the `wattmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `status = 1`, and
`noise = true`, which apply to wattmeters located at the bus, as well as at both the "from"
and "to" bus ends. Users can fine-tune these settings by explicitly specifying the variance
and status for wattmeters positioned at the buses, "from" bus ends, or "to" bus ends of
branches using the [`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `active` and `variance` keywords are per-units (pu). However,
users can choose to use watts (W) as the units by applying the [`@power`](@ref @power)
macro.

# Examples
Adding wattmeters using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(system, device; label = "Wattmeter 1", bus = "Bus 2", active = 0.4)
addWattmeter!(system, device; label = "Wattmeter 2", from = "Branch 1", active = 0.1)
```

Adding wattmeters using a custom unit system:
```jldoctest
@power(MW, pu, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(system, device; label = "Wattmeter 1", bus = "Bus 2", active = 40.0)
addWattmeter!(system, device; label = "Wattmeter 2", from = "Branch 1", active = 10.0)
```
"""
function addWattmeter!(system::PowerSystem, device::Measurement;
    label::L = missing, bus::L = missing, from::L = missing, to::L = missing,
    active::T, variance::T = missing, status::T = missing,
    noise::Bool = template.wattmeter.noise)

    addPowerMeter!(system, device.wattmeter, template.wattmeter, prefix.activePower,
        label, bus, from, to, active, variance, status, noise, "wattmeter")
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement; label, bus, from, to, reactive,
        variance, status, noise)

The function adds a new varmeter that measures reactive power flow or injection to the 
`Measurement` composite type within a given `PowerSystem` type. The varmeter can be added 
to an already defined bus or branch.

# Keywords
The varmeter is defined with the following keywords:
* `label`: a unique label for the varmeter;
* `bus`: the label of the bus if the varmeter is located at the bus;
* `from`: the label of the branch if the varmeter is located at the "from" bus end;
* `to`: the label of the branch if the varmeter is located at the "to" bus end;
* `reactive` (pu or VAr): the reactive power value;
* `variance` (pu or VAr): the variance of the reactive power measurement;
* `status`: the operating status of the varmeter:
  * `status = 1`: in-service;
  * `status = 0`: out-of-service;
* `noise`: specifies how to generate the measurement mean:
  * `noise = true`: Adds white Gaussian noise with the `variance` to the `reactive`;
  * `noise = false`: uses the `reactive` value only.

# Updates
The function updates the `varmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `status = 1`, and
`noise = true`, which apply to varmeters located at the bus, as well as at both the "from"
and "to" bus ends. Users can fine-tune these settings by explicitly specifying the variance
and status for varmeters positioned at the buses, "from" bus ends, or "to" bus ends of
branches using the [`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `reactive` and `variance` keywords are per-units (pu). However,
users can choose to use volt-amperes reactive (VAr) as the units by applying the
[`@power`](@ref @power) macro.

# Examples
Adding varmeters using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(system, device; label = "Varmeter 1", bus = "Bus 2", reactive = 0.4)
addVarmeter!(system, device; label = "Varmeter 2", from = "Branch 1", reactive = 0.1)
```

Adding varmeters using a custom unit system:
```jldoctest
@power(MW, pu, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(system, device; label = "Varmeter 1", bus = "Bus 2", reactive = 40.0)
addVarmeter!(system, device; label = "Varmeter 2", from = "Branch 1", reactive = 10.0)
```
"""
function addVarmeter!(system::PowerSystem, device::Measurement;
    label::L = missing, bus::L = missing, from::L = missing, to::L = missing,
    reactive::T, variance::T = missing, status::T = missing,
    noise::Bool = template.varmeter.noise)

    addPowerMeter!(system, device.varmeter, template.varmeter, prefix.reactivePower,
        label, bus, from, to, reactive, variance, status, noise, "varmeter")
end

######### Add Wattmeter or Varmeter ##########
function addPowerMeter!(system, device, default, prefixPower, label, bus, from, to,
    power, variance, status, noise, name)

    location = checkLocation(device, bus, from, to)

    device.number += 1
    setLabel(device, label, default.label, name)

    if device.layout.bus[end]
        index = system.bus.label[getLabel(system.bus, location, "bus")]
        defaultVariance = default.varianceBus
        defaultStatus = default.statusBus
    else
        index = system.branch.label[getLabel(system.branch, location, "branch")]
        if device.layout.from[end]
            defaultVariance = default.varianceFrom
            defaultStatus = default.statusFrom
        else
            defaultVariance = default.varianceTo
            defaultStatus = default.statusTo
        end
    end
    push!(device.layout.index, index)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    setMeter(device.power, power, variance, status, noise, defaultVariance,
        defaultStatus, prefixPower, basePowerInv)
end

"""
    addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo)

The function incorporates wattmeters into the `Measurement` composite type for every bus
and branch within the `PowerSystem` type. These measurements are derived from the exact
active power injections at buses and active power flows in branches defined in the `AC`
abstract type. These exact values are perturbed by white Gaussian noise with the specified 
`variance` to obtain measurement data.

# Keywords
Users have the option to configure the following keywords:
* `varianceBus` (pu or W): the measurement variance for wattmeters at the buses;
* `statusBus`: the operating status of the wattmeters at the buses:
  * `statusBus = 1`: in-service;
  * `statusBus = 0`: out-of-service;
* `varianceFrom` (pu or W): the measurement variance for wattmeters at the "from" bus ends;
* `statusFrom`: the operating status of the wattmeters at the "from" bus ends:
  * `statusFrom = 1`: in-service;
  * `statusFrom = 0`: out-of-service;
* `varianceTo` (pu or W): the measurement variance for wattmeters at the "to" bus ends;
* `statusTo`: the operating status of the wattmeters at the "to" bus ends:
  * `statusTo = 1`: in-service;
  * `statusTo = 0`: out-of-service.

# Updates
The function updates the `wattmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-2`, `statusBus = 1`,
`varianceFrom = 1e-2`, `statusFrom = 1`, `varianceTo = 1e-2`, and `statusTo = 1`. Users
can change these default settings using the [`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to use watts (W) as the units by applying the
[`@power`](@ref @power) macro.

# Abstract type
The abstract type `AC` can have the following subtypes:
- `ACPowerFlow`: generates measurements uses AC power flow results;
- `ACOptimalPowerFlow`: generates measurements uses AC optimal power flow results.

# Examples
Adding wattmeters using exact values from the AC power flow:
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
power!(system, analysis)

device = measurement()

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; varianceBus = 1e-3, statusFrom = 0)
```

Adding wattmeters using exact values from the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)

device = measurement()

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; varianceBus = 1e-3, statusFrom = 0)
```
"""
function addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceBus::T = missing, varianceFrom::T = missing, varianceTo::T = missing,
    statusBus::T = missing, statusFrom::T = missing, statusTo::T = missing)

    addPowermeter!(system, device.wattmeter, analysis.power.injection.active,
        analysis.power.from.active, analysis.power.to.active, template.wattmeter,
        prefix.activePower, varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo)
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo)

The function incorporates varmeters into the `Measurement` composite type for every bus
and branch within the `PowerSystem` type. These measurements are derived from the exact
reactive power injections at buses and reactive power flows in branches defined in the `AC`
abstract type. These exact values are perturbed by white Gaussian noise with the specified 
`variance` to obtain measurement data.

# Keywords
* `varianceBus` (pu or VAr): the measurement variance for varmeters at the buses;
* `statusBus`: the operating status of the varmeters at the buses:
  * `statusBus = 1`: in-service;
  * `statusBus = 0`: out-of-service;
* `varianceFrom` (pu or VAr): the measurement variance for varmeters at the "from" bus ends;
* `statusFrom`: the operating status of the varmeters at the "from" bus ends:
  * `statusFrom = 1`: in-service;
  * `statusFrom = 0`: out-of-service;
* `varianceTo` (pu or VAr): the measurement variance for varmeters at the "to" bus ends;
* `statusTo`: the operating status of the varmeters at the "to" bus ends:
  * `statusTo = 1`: in-service;
  * `statusTo = 0`: out-of-service.

# Updates
The function updates the `varmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-2`, `statusBus = 1`,
`varianceFrom = 1e-2`, `statusFrom = 1`, `varianceTo = 1e-2`, and `statusTo = 1`. Users
can change these default settings using the [`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to use volt-amperes reactive (VAr) as the units
by applying the [`@power`](@ref @power) macro.

# Abstract type
The abstract type `AC` can have the following subtypes:
- `ACPowerFlow`: generates measurements uses AC power flow results;
- `ACOptimalPowerFlow`: generates measurements uses AC optimal power flow results.

# Examples
Adding varmeters using exact values from the AC power flow:
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
power!(system, analysis)

device = measurement()

@varmeter(label = "Varmeter ?")
addVarmeter!(system, device, analysis; varianceFrom = 1e-3, statusBus = 0)
```

Adding varmeters using exact values from the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)

device = measurement()

@varmeter(label = "Varmeter ?")
addVarmeter!(system, device, analysis; varianceFrom = 1e-3, statusBus = 0)
```
"""
function addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceBus::T = missing, varianceFrom::T = missing, varianceTo::T = missing,
    statusBus::T = missing, statusFrom::T = missing, statusTo::T = missing)

    addPowermeter!(system, device.varmeter, analysis.power.injection.reactive,
        analysis.power.from.reactive, analysis.power.to.reactive, template.varmeter,
        prefix.reactivePower, varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo)
end

######### Add Group of Wattmeters or Varmeters ##########
function addPowermeter!(system, device, powerBus, powerFrom, powerTo, default, prefixPower,
    varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo)

    statusBus = unitless(statusBus, default.statusBus)
    checkStatus(statusBus)

    statusFrom = unitless(statusFrom, default.statusFrom)
    checkStatus(statusFrom)

    statusTo = unitless(statusTo, default.statusTo)
    checkStatus(statusTo)

    device.number = system.bus.number + 2 * system.branch.number
    device.label = Dict{String,Int64}(); sizehint!(device.label, device.number)

    device.layout.index = fill(0, device.number)
    device.layout.bus = fill(false, device.number)
    device.layout.from = fill(false, device.number)
    device.layout.to = fill(false, device.number)

    device.power.mean = fill(0.0, device.number)
    device.power.variance = similar(device.power.mean)
    device.power.status = fill(Int8(0), device.number)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for i = 1:system.bus.number
        device.label[replace(default.label, r"\?" => string(i))] = i

        device.layout.index[i] = i
        device.layout.bus[i] = true

        device.power.variance[i] = topu(varianceBus, default.varianceBus, prefixPower, basePowerInv)
        device.power.mean[i] = powerBus[i] + device.power.variance[i]^(1/2) * randn(1)[1]
        device.power.status[i] = statusBus
    end

    count = 1
    @inbounds for i = (system.bus.number + 1):2:device.number
        device.label[replace(default.label, r"\?" => string(i))] = i
        device.label[replace(default.label, r"\?" => string(i + 1))] = i + 1

        device.layout.index[i] = count
        device.layout.index[i + 1] = count
        device.layout.from[i] = true
        device.layout.to[i + 1] = true

        device.power.variance[i] = topu(varianceFrom, default.varianceFrom, prefixPower, basePowerInv)
        device.power.mean[i] = powerFrom[count] + device.power.variance[i]^(1/2) * randn(1)[1]
        device.power.status[i] = statusFrom

        device.power.variance[i + 1] = topu(varianceTo, default.varianceTo, prefixPower, basePowerInv)
        device.power.mean[i + 1] = powerTo[count] + device.power.variance[i + 1]^(1/2) * randn(1)[1]
        device.power.status[i + 1] = statusTo

        count += 1
    end

    device.layout.label = device.number
end

"""
    updateWattmeter!(system::PowerSystem, device::Measurement, analysis::Analysis; kwargs...)

The function allows for the alteration of parameters for a wattmeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
composite type only. However, when including the `Analysis` type, it updates both the
`Measurement` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific wattmeter, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addWattmeter!`](@ref addWattmeter!) function, along
with their respective values. Ensure that the `label` keyword matches the `label` of the
existing wattmeter you want to modify. If any keywords are omitted, their corresponding
values will remain unchanged.

# Updates
The function updates the `wattmeter` field within the `Measurement` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addWattmeter!`](@ref addWattmeter!) function.

# Example
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(system, device; label = "Wattmeter 1", from = "Branch 1", active = 1.1)
updateWattmeter!(system, device; label = "Wattmeter 1", active = 1.2, variance = 1e-4)
```
"""
function updateWattmeter!(system::PowerSystem, device::Measurement; label::L,
    active::T = missing, variance::T = missing, status::T = missing,
    noise::Bool = template.wattmeter.noise)

    wattmeter = device.wattmeter

    index = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(wattmeter.power, index, active, variance, status, noise,
        prefix.activePower, basePowerInv)
end

"""
    updateVarmeter!(system::PowerSystem, device::Measurement, analysis::Analysis; kwargs...)

The function allows for the alteration of parameters for a varmeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
composite type only. However, when including the `Analysis` type, it updates both the
`Measurement` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific varmeter, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addVarmeter!`](@ref addVarmeter!) function, along
with their respective values. Ensure that the `label` keyword matches the `label` of the
existing varmeter you want to modify. If any keywords are omitted, their corresponding
values will remain unchanged.

# Updates
The function updates the `varmeter` field within the `Measurement` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addVarmeter!`](@ref addVarmeter!) function.

# Example
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(system, device; label = "Varmeter 1", from = "Branch 1", reactive = 1.1)
updateVarmeter!(system, device; label = "Varmeter 1", reactive = 1.2, variance = 1e-4)
```
"""
function updateVarmeter!(system::PowerSystem, device::Measurement; label::L,
    reactive::T = missing, variance::T = missing, status::T = missing,
    noise::Bool = template.varmeter.noise)

    varmeter = device.varmeter

    index = varmeter.label[getLabel(varmeter, label, "varmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(varmeter.power, index, reactive, variance, status, noise,
        prefix.reactivePower, basePowerInv)
end

"""
    @wattmeter(label, varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo,
        noise)

The macro generates a template for a wattmeter, which can be utilized to define a wattmeter
using the [`addWattmeter!`](@ref addWattmeter!) function.

# Keywords
To establish the wattmeter template, users can set default variance and status values for
wattmeters at buses using `varianceBus` and `statusBus`, and at both the "from" and "to" bus
ends of branches using `varianceFrom` and `statusFrom` for the former and `varianceTo` and
`statusTo` for the latter. Users can also configure label patterns with the `label` keyword,
as well as specify the `noise` type.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to use watts (W) as the units by applying the
[`@power`](@ref @power) macro.

# Examples
Adding wattmeters using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4, noise = false)
addWattmeter!(system, device; bus = "Bus 2", active = 0.4)
addWattmeter!(system, device; from = "Branch 1", active = 0.1)
```

Adding wattmeters using a custom unit system:
```jldoctest
@power(MW, pu, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2, noise = false)
addWattmeter!(system, device; bus = "Bus 2", active = 40.0)
addWattmeter!(system, device; from = "Branch 1", active = 10.0)
```
"""
macro wattmeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]

        if hasfield(WattmeterTemplate, parameter)
            if parameter in [:varianceBus, :varianceFrom, :varianceTo]
                container::ContainerTemplate = getfield(template.wattmeter, parameter)
                if prefix.activePower != 0.0
                    setfield!(container, :value, prefix.activePower * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, true)
                end
            elseif parameter in [:statusBus, :statusFrom, :statusTo]
                setfield!(template.wattmeter, parameter, Int8(eval(kwarg.args[2])))
            elseif parameter == :noise
                setfield!(template.wattmeter, parameter, Bool(eval(kwarg.args[2])))
            elseif parameter == :label
                label = string(kwarg.args[2])
                if contains(label, "?")
                    setfield!(template.wattmeter, parameter, label)
                else
                    throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

"""
    @varmeter(label, varinaceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo,
        noise)

The macro generates a template for a varmeter, which can be utilized to define a varmeter
using the [`addVarmeter!`](@ref addVarmeter!) function.

# Keywords
To establish the varmeter template, users can set default variance and status values for
varmeters at buses using `varianceBus` and `statusBus`, and at both the "from" and "to" bus
ends of branches using `varianceFrom` and `statusFrom` for the former and `varianceTo` and
`statusTo` for the latter. Users can also configure label patterns with the `label` keyword,
as well as specify the `noise` type.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to usevolt-amperes reactive (VAr) as the units
by applying the [`@power`](@ref @power) macro.

# Examples
Adding varmeters using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@varmeter(label = "Varmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4, noise = false)
addVarmeter!(system, device; bus = "Bus 2", reactive = 0.4)
addVarmeter!(system, device; from = "Branch 1", reactive = 0.1)
```

Adding varmeters using a custom unit system:
```jldoctest
@power(MW, pu, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@varmeter(label = "Varmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2, noise = false)
addVarmeter!(system, device; bus = "Bus 2", reactive = 40.0)
addVarmeter!(system, device; from = "Branch 1", reactive = 10.0)
```
"""
macro varmeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]

        if hasfield(VarmeterTemplate, parameter)
            if parameter in [:varianceBus, :varianceFrom, :varianceTo]
                container::ContainerTemplate = getfield(template.varmeter, parameter)
                if prefix.reactivePower != 0.0
                    setfield!(container, :value, prefix.reactivePower * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, true)
                end
            elseif parameter in [:statusBus, :statusFrom, :statusTo]
                setfield!(template.varmeter, parameter, Int8(eval(kwarg.args[2])))
            elseif parameter == :noise
                setfield!(template.varmeter, parameter, Bool(eval(kwarg.args[2])))
            elseif parameter == :label
                label = string(kwarg.args[2])
                if contains(label, "?")
                    setfield!(template.varmeter, parameter, label)
                else
                    throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end