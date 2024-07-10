"""
    addWattmeter!(system::PowerSystem, device::Measurement; label, bus, from, to, active,
        variance, noise, status)

The function adds a new wattmeter that measures active power injection or active power flow
to the `Measurement` type within a given `PowerSystem` type. The wattmeter can be added to
an already defined bus or branch.

# Keywords
The wattmeter is defined with the following keywords:
* `label`: Unique label for the wattmeter.
* `bus`: Label of the bus if the wattmeter is located at the bus.
* `from`: Label of the branch if the wattmeter is located at the from-bus end.
* `to`: Label of the branch if the wattmeter is located at the to-bus end.
* `active` (pu or W): Active power value.
* `variance` (pu or W): Variance of the active power measurement.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the `active`,
  * `noise = false`: uses the `active` value only.
* `status`: Operating status of the wattmeter:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

# Updates
The function updates the `wattmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `noise = false`,
and `status = 1`, which apply to wattmeters located at the bus, as well as at both the
from-bus and to-bus ends. Users can fine-tune these settings by explicitly specifying the
variance and status for wattmeters positioned at the buses, from-bus ends, or to-bus
ends of branches using the [`@wattmeter`](@ref @wattmeter) macro.

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
    active::A, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise)

    addPowerMeter!(system, device.wattmeter, device.wattmeter.active, template.wattmeter,
    prefix.activePower, label, bus, from, to, active, variance, status, noise)
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement; label, bus, from, to, reactive,
        variance, noise, status)

The function adds a new varmeter that measures reactive power injection or reactive power
flow to the `Measurement` type within a given `PowerSystem` type. The varmeter can be added
to an already defined bus or branch.

# Keywords
The varmeter is defined with the following keywords:
* `label`: Unique label for the varmeter.
* `bus`: Label of the bus if the varmeter is located at the bus.
* `from`: Label of the branch if the varmeter is located at the from-bus end.
* `to`: Label of the branch if the varmeter is located at the to-bus end.
* `reactive` (pu or VAr): Reactive power value.
* `variance` (pu or VAr): Variance of the reactive power measurement.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the `reactive`,
  * `noise = false`: uses the `reactive` value only.
* `status`: Operating status of the varmeter:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

# Updates
The function updates the `varmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-2`, `noise = false`,
and `status = 1`, which apply to varmeters located at the bus, as well as at both the
from-bus and to-bus ends. Users can fine-tune these settings by explicitly specifying the
variance and status for varmeters positioned at the buses, from-bus ends, or to-bus
ends of branches using the [`@varmeter`](@ref @varmeter) macro.

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
    reactive::A, variance::A = missing, status::A = missing,
    noise::Bool = template.varmeter.noise)

    addPowerMeter!(system, device.varmeter, device.varmeter.reactive, template.varmeter,
    prefix.reactivePower, label, bus, from, to, reactive, variance, status, noise)
end

######### Add Wattmeter or Varmeter ##########
function addPowerMeter!(system, device, measure, default, prefixPower, label, bus, from, to,
    power, variance, status, noise)

    location, busFlag, fromFlag, toFlag = checkLocation(bus, from, to)

    branchFlag = false
    if !busFlag
        labelBranch = getLabel(system.branch, location, "branch")
        index = system.branch.label[labelBranch]
        if system.branch.layout.status[index] == 1
            branchFlag = true
        end
    end

    if busFlag || branchFlag
        device.number += 1
        push!(device.layout.bus, busFlag)
        push!(device.layout.from, fromFlag)
        push!(device.layout.to, toFlag)

        if busFlag
            labelBus = getLabel(system.bus, location, "bus")
            index = system.bus.label[labelBus]
            setLabel(device, label, default.label, labelBus)

            defaultVariance = default.varianceBus
            defaultStatus = default.statusBus
        elseif fromFlag
            setLabel(device, label, default.label, labelBranch; prefix = "From ")
            defaultVariance = default.varianceFrom
            defaultStatus = default.statusFrom
        else
            setLabel(device, label, default.label, labelBranch; prefix = "To ")
            defaultVariance = default.varianceTo
            defaultStatus = default.statusTo
        end
        push!(device.layout.index, index)

        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

        setMeter(measure, power, variance, status, noise, defaultVariance, defaultStatus, prefixPower, basePowerInv)
    end
end

"""
    addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates wattmeters into the `Measurement` composite type for every bus
and branch within the `PowerSystem` type. These measurements are derived from the exact
active power injections at buses and active power flows in branches defined in the `AC`
type.

# Keywords
Users have the option to configure the following keywords:
* `varianceBus` (pu or W): Measurement variance for wattmeters at the buses.
* `statusBus`: Operating status of the wattmeters at the buses:
  * `statusBus = 1`: in-service,
  * `statusBus = 0`: out-of-service.
* `varianceFrom` (pu or W): Measurement variance for wattmeters at the from-bus ends.
* `statusFrom`: Operating status of the wattmeters at the from-bus ends:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service.
* `varianceTo` (pu or W): Measurement variance for wattmeters at the to-bus ends.
* `statusTo`: Operating status of the wattmeters at the to-bus ends:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the active powers,
  * `noise = false`: uses the exact active power values.

# Updates
The function updates the `wattmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-2`, `statusBus = 1`,
`varianceFrom = 1e-2`, `statusFrom = 1`, `varianceTo = 1e-2`, `statusTo = 1`, and
`noise = false`. Users can change these default settings using the
[`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to use watts (W) as the units by applying the
[`@power`](@ref @power) macro.

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
power!(system, analysis)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; varianceBus = 1e-3, statusFrom = 0)
```
"""
function addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceBus::A = missing, varianceFrom::A = missing, varianceTo::A = missing,
    statusBus::A = missing, statusFrom::A = missing, statusTo::A = missing,
    noise::Bool = template.wattmeter.noise)

    wattmeter = device.wattmeter
    power = analysis.power

    addPowermeter!(system, wattmeter, wattmeter.active, power.injection.active,
    power.from.active, power.to.active, template.wattmeter, prefix.activePower,
    varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo, noise)
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates varmeters into the `Measurement` composite type for every bus
and branch within the `PowerSystem` type. These measurements are derived from the exact
reactive power injections at buses and reactive power flows in branches defined in the `AC`
type.

# Keywords
* `varianceBus` (pu or VAr): Measurement variance for varmeters at the buses.
* `statusBus`: Operating status of the varmeters at the buses:
  * `statusBus = 1`: in-service,
  * `statusBus = 0`: out-of-service.
* `varianceFrom` (pu or VAr): Measurement variance for varmeters at the from-bus ends.
* `statusFrom`: Operating status of the varmeters at the from-bus ends:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service.
* `varianceTo` (pu or VAr): Measurement variance for varmeters at the to-bus ends.
* `statusTo`: Operating status of the varmeters at the to-bus ends:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the reactive powers,
  * `noise = false`: uses the exact reactive power values.

# Updates
The function updates the `varmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-2`, `statusBus = 1`,
`varianceFrom = 1e-2`, `statusFrom = 1`, `varianceTo = 1e-2`, `statusTo = 1`, and
`noise = false`. Users can change these default settings using the
[`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units (pu). However, users can choose to use volt-amperes reactive (VAr) as the units
by applying the [`@power`](@ref @power) macro.

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
power!(system, analysis)

@varmeter(label = "Varmeter ?")
addVarmeter!(system, device, analysis; varianceFrom = 1e-3, statusBus = 0)
```
"""
function addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceBus::A = missing, varianceFrom::A = missing, varianceTo::A = missing,
    statusBus::A = missing, statusFrom::A = missing, statusTo::A = missing,
    noise::Bool = template.varmeter.noise)

    varmeter = device.varmeter
    power = analysis.power

    addPowermeter!(system, varmeter, varmeter.reactive, power.injection.reactive, power.from.reactive,
    power.to.reactive, template.varmeter, prefix.reactivePower, varianceBus, varianceFrom, varianceTo,
    statusBus, statusFrom, statusTo, noise)
end

######### Add Group of Wattmeters or Varmeters ##########
function addPowermeter!(system, device, measure, powerBus, powerFrom, powerTo, default,
    prefixPower, varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo,
    noise)

    if isempty(powerBus)
        throw(ErrorException("The powers cannot be found."))
    end

    statusBus = unitless(statusBus, default.statusBus)
    checkStatus(statusBus)

    statusFrom = unitless(statusFrom, default.statusFrom)
    checkStatus(statusFrom)

    statusTo = unitless(statusTo, default.statusTo)
    checkStatus(statusTo)

    deviceNumber = system.bus.number + 2 * system.branch.layout.inservice
    device.label = OrderedDict{String,Int64}(); sizehint!(device.label, deviceNumber)
    device.number = 0

    device.layout.index = fill(0, deviceNumber)
    device.layout.bus = fill(false, deviceNumber)
    device.layout.from = fill(false, deviceNumber)
    device.layout.to = fill(false, deviceNumber)

    measure.mean = fill(0.0, deviceNumber)
    measure.variance = similar(measure.mean)
    measure.status = fill(Int8(0), deviceNumber)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for (label, i) in system.bus.label
        device.number += 1
        setLabel(device, missing, default.label, label)

        device.layout.index[i] = i
        device.layout.bus[i] = true

        measure.status[i] = statusBus
        measure.variance[i] = topu(varianceBus, default.varianceBus, prefixPower, basePowerInv)
        if noise
            measure.mean[i] = powerBus[i] + measure.variance[i]^(1/2) * randn(1)[1]
        else
            measure.mean[i] = powerBus[i]
        end

    end

    @inbounds for (label, i) in system.branch.label
        if system.branch.layout.status[i] == 1
            device.number += 1
            setLabel(device, missing, default.label, label; prefix = "From ")

            device.layout.index[device.number] = i
            device.layout.index[device.number + 1] = i

            device.layout.from[device.number] = true
            device.layout.to[device.number + 1] = true

            measure.status[device.number] = statusFrom
            measure.status[device.number + 1] = statusTo

            measure.variance[device.number] = topu(varianceFrom, default.varianceFrom, prefixPower, basePowerInv)
            measure.variance[device.number + 1] = topu(varianceTo, default.varianceTo, prefixPower, basePowerInv)

            if noise
                measure.mean[device.number] = powerFrom[i] + measure.variance[device.number]^(1/2) * randn(1)[1]
                measure.mean[device.number + 1] = powerTo[i] + measure.variance[device.number + 1]^(1/2) * randn(1)[1]
            else
                measure.mean[device.number] = powerFrom[i]
                measure.mean[device.number + 1] = powerTo[i]
            end

            device.number += 1
            setLabel(device, missing, default.label, label; prefix = "To ")
        end
    end

    device.layout.label = device.number
end

"""
    updateWattmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

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
    active::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise)

    wattmeter = device.wattmeter

    index = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(wattmeter.active, index, active, variance, status, noise,
    prefix.activePower, basePowerInv)
end

function updateWattmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{NonlinearWLS{T}};
    label::L, active::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    wattmeter = device.wattmeter
    se = analysis.method

    indexWattmeter = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    indexBusBranch = wattmeter.layout.index[indexWattmeter]
    idx = device.voltmeter.number + device.ammeter.number + indexWattmeter

    updateMeter(wattmeter.active, indexWattmeter, active, variance, status, noise,
    prefix.activePower, 1 / (system.base.power.value * system.base.power.prefix))

    if wattmeter.active.status[indexWattmeter] == 1
        if wattmeter.layout.bus[indexWattmeter]
            se.type[idx] = 4
        elseif wattmeter.layout.from[indexWattmeter]
            se.type[idx] = 5
        else
            se.type[idx] = 6
        end
        se.mean[idx] = wattmeter.active.mean[indexWattmeter]
    else
        if wattmeter.layout.bus[indexWattmeter]
            for k in ac.nodalMatrix.colptr[indexBusBranch]:(ac.nodalMatrix.colptr[indexBusBranch + 1] - 1)
                j = ac.nodalMatrix.rowval[k]
                se.jacobian[idx, j] = 0.0
                se.jacobian[idx, bus.number + j] = 0.0
            end
        else
            se.jacobian[idx, branch.layout.from[indexBusBranch]] = 0.0
            se.jacobian[idx, bus.number + branch.layout.from[indexBusBranch]] = 0.0
            se.jacobian[idx, branch.layout.to[indexBusBranch]] = 0.0
            se.jacobian[idx, bus.number + branch.layout.to[indexBusBranch]] = 0.0
        end
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(variance)
        se.precision[idx, idx] = 1 / wattmeter.active.variance[indexWattmeter]
    end
end

function updateWattmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{LAV};
    label::L, active::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise)

    wattmeter = device.wattmeter
    se = analysis.method

    indexWattmeter = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    indexBusBranch = wattmeter.layout.index[indexWattmeter]
    idx = device.voltmeter.number + device.ammeter.number + indexWattmeter

    updateMeter(wattmeter.active, indexWattmeter, active, variance, status, noise,
    prefix.activePower, 1 / (system.base.power.value * system.base.power.prefix))

    if wattmeter.active.status[indexWattmeter] == 1
        addDeviceLAV(se, idx)

        remove!(se.jump, se.residual, idx)
        addWattmeterResidual!(system, wattmeter, se, indexBusBranch, idx, indexWattmeter)
    else
        removeDeviceLAV(se, idx)
    end
end

function updateWattmeter!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation{LinearWLS{T}};
    label::L, active::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise) where T <: Union{Normal, Orthogonal}

    dc = system.model.dc
    wattmeter = device.wattmeter
    method = analysis.method

    indexWattmeter = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    oldStatus = wattmeter.active.status[indexWattmeter]
    oldVariance = wattmeter.active.variance[indexWattmeter]

    updateMeter(wattmeter.active, indexWattmeter, active, variance, status, noise,
    prefix.activePower, 1 / (system.base.power.value * system.base.power.prefix))

    newStatus = wattmeter.active.status[indexWattmeter]
    if oldStatus != newStatus || oldVariance != wattmeter.active.variance[indexWattmeter]
        method.run = true
    end

    if isset(status) || isset(active)
        if wattmeter.layout.bus[indexWattmeter]
            indexBus = wattmeter.layout.index[indexWattmeter]
            if isset(status)
                for j in dc.nodalMatrix.colptr[indexBus]:(dc.nodalMatrix.colptr[indexBus + 1] - 1)
                    method.coefficient[indexWattmeter, dc.nodalMatrix.rowval[j]] = newStatus * dc.nodalMatrix.nzval[j]
                end
            end
            method.mean[indexWattmeter] = newStatus * (wattmeter.active.mean[indexWattmeter] - dc.shiftPower[indexBus] - system.bus.shunt.conductance[indexBus])
        else
            indexBranch = wattmeter.layout.index[indexWattmeter]
            newStatus *= system.branch.layout.status[indexBranch]
            if wattmeter.layout.from[indexWattmeter]
                addmitance = newStatus * dc.admittance[indexBranch]
            else
                addmitance = -newStatus * dc.admittance[indexBranch]
            end
            if isset(status)
                method.coefficient[indexWattmeter, system.branch.layout.from[indexBranch]] = addmitance
                method.coefficient[indexWattmeter, system.branch.layout.to[indexBranch]] = -addmitance
            end
            method.mean[indexWattmeter] = newStatus * (wattmeter.active.mean[indexWattmeter] + system.branch.parameter.shiftAngle[indexBranch] * addmitance)
        end
    end

    if isset(variance)
        method.precision.nzval[indexWattmeter] = 1 / wattmeter.active.variance[indexWattmeter]
    end
end

function updateWattmeter!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation{LAV};
    label::L, active::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.wattmeter.noise)

    dc = system.model.dc
    wattmeter = device.wattmeter
    method = analysis.method

    indexWattmeter = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(wattmeter.active, indexWattmeter, active, variance, status, noise,
    prefix.activePower, basePowerInv)

    if isset(status) || isset(active)
        if wattmeter.layout.bus[indexWattmeter]
            indexBus = wattmeter.layout.index[indexWattmeter]
        else
            indexBranch = wattmeter.layout.index[indexWattmeter]
            if wattmeter.layout.from[indexWattmeter]
                admittance = dc.admittance[indexBranch]
            else
                admittance = -dc.admittance[indexBranch]
            end
        end
    end

    if isset(status)
        if wattmeter.active.status[indexWattmeter] == 1
            addDeviceLAV(method, indexWattmeter)

            if wattmeter.layout.bus[indexWattmeter]
                angleCoeff = @expression(method.jump, AffExpr())
                for j in dc.nodalMatrix.colptr[indexBus]:(dc.nodalMatrix.colptr[indexBus + 1] - 1)
                    k = dc.nodalMatrix.rowval[j]
                    add_to_expression!(angleCoeff, dc.nodalMatrix.nzval[j] * (method.statex[k] - method.statey[k]))
                end

                remove!(method.jump, method.residual, indexWattmeter)
                method.residual[indexWattmeter] = @constraint(method.jump, angleCoeff + method.residualy[indexWattmeter] - method.residualx[indexWattmeter] == 0.0)
            elseif system.branch.layout.status[indexBranch] == 1
                from = system.branch.layout.from[indexBranch]
                to =  system.branch.layout.to[indexBranch]

                angleCoeff = admittance * (method.statex[from] - method.statey[from] - method.statex[to] + method.statey[to])

                remove!(method.jump, method.residual, indexWattmeter)
                method.residual[indexWattmeter] = @constraint(method.jump, angleCoeff + method.residualy[indexWattmeter] - method.residualx[indexWattmeter] == 0.0)
            else
                removeDeviceLAV(method, indexWattmeter)
            end
        else
            removeDeviceLAV(method, indexWattmeter)
        end
    end

    if wattmeter.active.status[indexWattmeter] == 1 && (isset(status) || isset(active))
        if wattmeter.layout.bus[indexWattmeter]
            JuMP.set_normalized_rhs(method.residual[indexWattmeter], wattmeter.active.mean[indexWattmeter] - dc.shiftPower[indexBus] - system.bus.shunt.conductance[indexBus])
        elseif system.branch.layout.status[indexBranch] == 1
            JuMP.set_normalized_rhs(method.residual[indexWattmeter], wattmeter.active.mean[indexWattmeter] + system.branch.parameter.shiftAngle[indexBranch] * admittance)
        end
    end
end

"""
    updateVarmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

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
    reactive::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.varmeter.noise)

    varmeter = device.varmeter

    index = varmeter.label[getLabel(varmeter, label, "varmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(varmeter.reactive, index, reactive, variance, status, noise,
    prefix.reactivePower, basePowerInv)
end

function updateVarmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{NonlinearWLS{T}};
    label::L, reactive::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.varmeter.noise) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    varmeter = device.varmeter
    se = analysis.method

    indexVarmeter = varmeter.label[getLabel(varmeter, label, "varmeter")]
    indexBusBranch = varmeter.layout.index[indexVarmeter]
    idx = device.voltmeter.number + device.ammeter.number + device.wattmeter.number + indexVarmeter

    updateMeter(varmeter.reactive, indexVarmeter, reactive, variance, status, noise,
    prefix.reactivePower,  1 / (system.base.power.value * system.base.power.prefix))

    if varmeter.reactive.status[indexVarmeter] == 1
        if varmeter.layout.bus[indexVarmeter]
            se.type[idx] = 7
        elseif varmeter.layout.from[indexVarmeter]
            se.type[idx] = 8
        else
            se.type[idx] = 9
        end
        se.mean[idx] = varmeter.reactive.mean[indexVarmeter]
    else
        if varmeter.layout.bus[indexVarmeter]
            for k in ac.nodalMatrix.colptr[indexBusBranch]:(ac.nodalMatrix.colptr[indexBusBranch + 1] - 1)
                j = ac.nodalMatrix.rowval[k]
                se.jacobian[idx, j] = 0.0
                se.jacobian[idx, bus.number + j] = 0.0
            end
        else
            se.jacobian[idx, branch.layout.from[indexBusBranch]] = 0.0
            se.jacobian[idx, bus.number + branch.layout.from[indexBusBranch]] = 0.0
            se.jacobian[idx, branch.layout.to[indexBusBranch]] = 0.0
            se.jacobian[idx, bus.number + branch.layout.to[indexBusBranch]] = 0.0
        end
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(variance)
        se.precision[idx, idx] = 1 / varmeter.reactive.variance[indexVarmeter]
    end
end

function updateVarmeter!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{LAV};
    label::L, reactive::A = missing, variance::A = missing, status::A = missing,
    noise::Bool = template.varmeter.noise)

    varmeter = device.varmeter
    se = analysis.method

    indexVarmeter = varmeter.label[getLabel(varmeter, label, "varmeter")]
    indexBusBranch = varmeter.layout.index[indexVarmeter]
    idx = device.voltmeter.number + device.ammeter.number + device.wattmeter.number + indexVarmeter

    updateMeter(varmeter.reactive, indexVarmeter, reactive, variance, status, noise,
    prefix.reactivePower, 1 / (system.base.power.value * system.base.power.prefix))

    if varmeter.reactive.status[indexVarmeter] == 1
        addDeviceLAV(se, idx)

        remove!(se.jump, se.residual, idx)
        addVarmeterResidual!(system, varmeter, se, indexBusBranch, idx, indexVarmeter)
    else
        removeDeviceLAV(se, idx)
    end
end

"""
    @wattmeter(label, varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo,
        noise)

The macro generates a template for a wattmeter, which can be utilized to define a wattmeter
using the [`addWattmeter!`](@ref addWattmeter!) function.

# Keywords
To establish the wattmeter template, users can set default variance and status values for
wattmeters at buses using `varianceBus` and `statusBus`, and at both the from-bus and to-bus
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

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4)
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

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2)
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
                if contains(label, "?") || contains(label, "!")
                    setfield!(template.wattmeter, parameter, label)
                else
                    throw(ErrorException("The label template is missing the '?' or '!' symbols."))
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
varmeters at buses using `varianceBus` and `statusBus`, and at both the from-bus and to-bus
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

@varmeter(label = "Varmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4)
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

@varmeter(label = "Varmeter ?", varianceBus = 1e-1, varianceFrom = 1e-2)
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
                if contains(label, "?") || contains(label, "!")
                    setfield!(template.varmeter, parameter, label)
                else
                    throw(ErrorException("The label template is missing the '?' or '!' symbols."))
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end