"""
    addWattmeter!(system::PowerSystem, device::Measurement;
        label, bus, from, to, active, variance, noise, status)

The function adds a wattmeter that measures active power injection or active power flow
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

Note that when powers are given in SI units, they correspond to three-phase power.

# Updates
The function updates the `wattmeter` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`,
and `status = 1`, which apply to wattmeters located at the bus, as well as at both the
from-bus and to-bus ends. Users can fine-tune these settings by explicitly specifying the
variance and status for wattmeters positioned at the buses, from-bus ends, or to-bus
ends of branches using the [`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `active` and `variance` keywords are per-units. However, users
can choose to use watts as the units by applying the [`@power`](@ref @power) macro.

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
@power(MW, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(system, device; label = "Wattmeter 1", bus = "Bus 2", active = 40.0)
addWattmeter!(system, device; label = "Wattmeter 2", from = "Branch 1", active = 10.0)
```
"""
function addWattmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    active::FltInt,
    kwargs...
)
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    addPowerMeter!(
        system, device.wattmeter, device.wattmeter.active, template.wattmeter,
        pfx.activePower, label, bus, from, to, active, key.variance, key.status, key.noise
    )
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement;
        label, bus, from, to, reactive, variance, noise, status)

The function adds a varmeter that measures reactive power injection or reactive power flow
to the `Measurement` type within a given `PowerSystem` type. The varmeter can be added to
an already defined bus or branch.

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

Note that when powers are given in SI units, they correspond to three-phase power.

# Updates
The function updates the `varmeter` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`,
and `status = 1`, which apply to varmeters located at the bus, as well as at both the
from-bus and to-bus ends. Users can fine-tune these settings by explicitly specifying the
variance and status for varmeters positioned at the buses, from-bus ends, or to-bus
ends of branches using the [`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `reactive` and `variance` keywords are per-units. However, users
can choose to use volt-amperes reactive as the units by applying the [`@power`](@ref @power)
macro.

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
@power(pu, MVAr)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(system, device; label = "Varmeter 1", bus = "Bus 2", reactive = 40.0)
addVarmeter!(system, device; label = "Varmeter 2", from = "Branch 1", reactive = 10.0)
```
"""
function addVarmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    reactive::FltInt,
    kwargs...
)
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    addPowerMeter!(
        system, device.varmeter, device.varmeter.reactive, template.varmeter,
        pfx.reactivePower, label, bus, from, to, reactive, key.variance,
        key.status, key.noise
    )
end

######### Add Wattmeter or Varmeter ##########
function addPowerMeter!(
    system::PowerSystem,
    device::Union{Wattmeter, Varmeter},
    measure::GaussMeter,
    def::Union{WattmeterTemplate, VarmeterTemplate},
    pfxPower::Float64,
    label::IntStrMiss,
    bus::IntStrMiss,
    from::IntStrMiss,
    to::IntStrMiss,
    power::FltInt,
    variance::FltIntMiss,
    status::FltIntMiss,
    noise::Bool
)
    location, busFlag, fromFlag, toFlag = checkLocation(bus, from, to)

    branchFlag = false
    if !busFlag
        lblBrch = getLabel(system.branch, location, "branch")
        idx = system.branch.label[lblBrch]
        if system.branch.layout.status[idx] == 1
            branchFlag = true
        end
    end

    if busFlag || branchFlag
        device.number += 1
        push!(device.layout.bus, busFlag)
        push!(device.layout.from, fromFlag)
        push!(device.layout.to, toFlag)

        if busFlag
            lblBus = getLabel(system.bus, location, "bus")
            idx = system.bus.label[lblBus]

            setLabel(device, label, def.label, lblBus)

            defVariance = def.varianceBus
            defStatus = def.statusBus
        elseif fromFlag
            setLabel(device, label, def.label, lblBrch; prefix = "From ")

            defVariance = def.varianceFrom
            defStatus = def.statusFrom
        else
            setLabel(device, label, def.label, lblBrch; prefix = "To ")

            defVariance = def.varianceTo
            defStatus = def.statusTo
        end
        push!(device.layout.index, idx)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)
        setMeter(
            measure, power, variance, status, noise,
            defVariance, defStatus, pfxPower, baseInv
        )
    end
end

"""
    addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates wattmeters into the `Measurement` type for every bus and branch
within the `PowerSystem` type. These measurements are derived from the exact active power
injections at buses and active power flows in branches defined in the `AC` type.

# Keywords
Wattmeters at the buses can be configured using:
* `varianceBus` (pu or W): Measurement variance.
* `statusBus`: Operating status:
  * `statusBus = 1`: in-service,
  * `statusBus = 0`: out-of-service,
  * `statusBus = -1`: not included in the `Measurement` type.
Wattmeters at the from-bus ends of the branches can be configured using:
* `varianceFrom` (pu or W): Measurement variance.
* `statusFrom`: Operating status:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service,
  * `statusFrom = -1`: not included in the `Measurement` type.
Wattmeters at the to-bus ends of the branches can be configured using:
* `varianceTo` (pu or W): Measurement variance.
* `statusTo`: Operating status:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service,
  * `statusTo = -1`: not included in the `Measurement` type.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the active power values using defined variances,
  * `noise = false`: uses the exact active power values without adding noise.

# Updates
The function updates the `wattmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-4`, `statusBus = 1`,
`varianceFrom = 1e-4`, `statusFrom = 1`, `varianceTo = 1e-4`, `statusTo = 1`, and
`noise = false`. Users can change these default settings using the
[`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units. However, users can choose to use watts as the units by applying the
[`@power`](@ref @power) macro.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement()

acModel!(system)
analysis = newtonRaphson(system)
powerFlow!(system, analysis; power = true)

@wattmeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; varianceBus = 1e-3, statusFrom = 0)
```
"""
function addWattmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::AC;
    varianceBus::FltIntMiss = missing,
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusBus::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    noise::Bool = template.wattmeter.noise
)
    wattmeter = device.wattmeter
    power = analysis.power

    addPowermeter!(
        system, wattmeter, wattmeter.active, power.injection.active,
        power.from.active, power.to.active, template.wattmeter, pfx.activePower,
        varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo, noise
    )
end

"""
    addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates varmeters into the `Measurement` type for every bus and branch
within the `PowerSystem` type. These measurements are derived from the exact reactive power
injections at buses and reactive power flows in branches defined in the `AC` type.

# Keywords
Varmeters at the buses can be configured using:
* `varianceBus` (pu or VAr): Measurement variance.
* `statusBus`: Operating status:
  * `statusBus = 1`: in-service,
  * `statusBus = 0`: out-of-service,
  * `statusBus = -1`: not included in the `Measurement` type.
Varmeters at the from-bus ends of the branches can be configured using:
* `varianceFrom` (pu or VAr): Measurement variance.
* `statusFrom`: Operating status:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service,
  * `statusFrom = -1`: not included in the `Measurement` type.
Varmeters at the to-bus ends of the branches can be configured using:
* `varianceTo` (pu or VAr): Measurement variance.
* `statusTo`: Operating status:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service,
  * `statusTo = -1`: not included in the `Measurement` type.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the reactive power values using defined variances,
  * `noise = false`: uses the exact reactive power values without adding noise.

# Updates
The function updates the `varmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `varianceBus = 1e-4`, `statusBus = 1`,
`varianceFrom = 1e-4`, `statusFrom = 1`, `varianceTo = 1e-4`, `statusTo = 1`, and
`noise = false`. Users can change these default settings using the
[`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are
per-units. However, users can choose to use volt-amperes reactive as the units by applying
the [`@power`](@ref @power) macro.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement()

acModel!(system)
analysis = newtonRaphson(system)
powerFlow!(system, analysis; power = true)

@varmeter(label = "Varmeter ?")
addVarmeter!(system, device, analysis; varianceFrom = 1e-3, statusBus = 0)
```
"""
function addVarmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::AC;
    varianceBus::FltIntMiss = missing,
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusBus::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    noise::Bool = template.varmeter.noise
)
    varmeter = device.varmeter
    power = analysis.power

    addPowermeter!(
        system, varmeter, varmeter.reactive, power.injection.reactive,
        power.from.reactive, power.to.reactive, template.varmeter, pfx.reactivePower,
        varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo, noise
    )
end

######### Add Group of Wattmeters or Varmeters ##########
function addPowermeter!(
    system::PowerSystem,
    device::Union{Wattmeter, Varmeter},
    measure::GaussMeter,
    powerBus::Vector{Float64},
    powerFrom::Vector{Float64},
    powerTo::Vector{Float64},
    def::Union{WattmeterTemplate, VarmeterTemplate},
    pfxPower::Float64,
    varianceBus::FltIntMiss,
    varianceFrom::FltIntMiss,
    varianceTo::FltIntMiss,
    statusBus::FltIntMiss,
    statusFrom::FltIntMiss,
    statusTo::FltIntMiss,
    noise::Bool
)
    errorPower(powerBus)

    statusBus = givenOrDefault(statusBus, def.statusBus)
    checkWideStatus(statusBus)

    statusFrom = givenOrDefault(statusFrom, def.statusFrom)
    checkWideStatus(statusFrom)

    statusTo = givenOrDefault(statusTo, def.statusTo)
    checkWideStatus(statusTo)

    if statusBus != -1 || statusFrom != -1 || statusTo != -1
        deviceNumber = 0
        if statusBus != -1
            deviceNumber += system.bus.number
        end
        if statusFrom != -1
            deviceNumber += system.branch.layout.inservice
        end
        if statusTo != -1
            deviceNumber += system.branch.layout.inservice
        end

        device.label = OrderedDict{template.config.device, Int64}()
        sizehint!(device.label, deviceNumber)
        device.number = 0

        device.layout.index = fill(0, deviceNumber)
        device.layout.bus = fill(false, deviceNumber)
        device.layout.from = fill(false, deviceNumber)
        device.layout.to = fill(false, deviceNumber)

        measure.mean = fill(0.0, deviceNumber)
        measure.variance = similar(measure.mean)
        measure.status = fill(Int8(0), deviceNumber)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)

        if statusBus != -1
            @inbounds for (label, i) in system.bus.label
                device.number += 1
                setLabel(device, missing, def.label, label)

                device.layout.index[i] = i
                device.layout.bus[i] = true

                add!(
                    measure, i, noise, pfxPower, powerBus[i], varianceBus,
                    def.varianceBus, statusBus, baseInv
                )
            end
        end

        if statusFrom != -1 || statusTo != -1
            @inbounds for (label, i) in system.branch.label
                if system.branch.layout.status[i] == 1
                    if statusFrom != -1
                        device.number += 1
                        setLabel(device, missing, def.label, label; prefix = "From ")

                        device.layout.index[device.number] = i
                        device.layout.from[device.number] = true

                        add!(
                            measure, device.number, noise, pfxPower, powerFrom[i],
                            varianceFrom, def.varianceFrom, statusFrom, baseInv
                        )
                    end

                    if statusTo != -1
                        device.number += 1
                        setLabel(device, missing, def.label, label; prefix = "To ")

                        device.layout.index[device.number] = i
                        device.layout.to[device.number] = true

                        add!(
                            measure, device.number, noise, pfxPower, powerTo[i],
                            varianceTo, def.varianceTo, statusTo, baseInv
                        )
                    end
                end
            end
        end
        device.layout.label = device.number
    end
end

"""
    updateWattmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

The function allows for the alteration of parameters for a wattmeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement` type
only. However, when including the `Analysis` type, it updates both the `Measurement` and
`Analysis` types. This streamlined process avoids the need to completely rebuild vectors
and matrices when adjusting these parameters.

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
function updateWattmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    wattmeter = device.wattmeter
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idx = wattmeter.label[getLabel(wattmeter, label, "wattmeter")]

    updateMeter(
        wattmeter.active, idx, active, key.variance, key.status, key.noise,
        pfx.activePower, 1 / (system.base.power.value * system.base.power.prefix)
    )
end

function updateWattmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    ac = system.model.ac
    nodal = ac.nodalMatrix
    watt = device.wattmeter
    se = analysis.method
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idxWatt = watt.label[getLabel(watt, label, "wattmeter")]
    idxBusBrch = watt.layout.index[idxWatt]
    idx = device.voltmeter.number + device.ammeter.number + idxWatt

    updateMeter(
        watt.active, idxWatt, active, key.variance, key.status, key.noise,
        pfx.activePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    if watt.active.status[idxWatt] == 1
        if watt.layout.bus[idxWatt]
            se.type[idx] = 6
        elseif watt.layout.from[idxWatt]
            se.type[idx] = 7
        else
            se.type[idx] = 8
        end
        se.mean[idx] = watt.active.mean[idxWatt]
    else
        if watt.layout.bus[idxWatt]
            for ptr in nodal.colptr[idxBusBrch]:(nodal.colptr[idxBusBrch + 1] - 1)
                j = nodal.rowval[ptr]
                se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
            end
        else
            i, j = fromto(system, idxBusBrch)
            se.jacobian[idx, i] = se.jacobian[idx, bus.number + i] = 0.0
            se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
        end
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(key.variance)
        se.precision[idx, idx] = 1 / watt.active.variance[idxWatt]
    end
end

function updateWattmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{LAV};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    watt = device.wattmeter
    se = analysis.method
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idxWatt = watt.label[getLabel(watt, label, "wattmeter")]
    idxBusBrch = watt.layout.index[idxWatt]
    idx = device.voltmeter.number + device.ammeter.number + idxWatt

    updateMeter(
        watt.active, idxWatt, active, key.variance, key.status, key.noise,
        pfx.activePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    if watt.active.status[idxWatt] == 1
        add!(se, idx)

        if watt.layout.bus[idxWatt]
            expr = Pi(system, se, idxBusBrch)
        else
            if watt.layout.from[idxWatt]
                expr = Pij(system, se, idxBusBrch)
            else
                expr = Pji(system, se, idxBusBrch)
            end
        end
        addConstrLav!(se, expr, watt.active.mean[idxWatt], idx)
    else
        remove!(se, idx)
    end
end

function updateWattmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation{WLS{T}};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    dc = system.model.dc
    nodal = dc.nodalMatrix
    watt = device.wattmeter
    se = analysis.method
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idxWatt = watt.label[getLabel(watt, label, "wattmeter")]
    oldStatus = watt.active.status[idxWatt]
    oldVariance = watt.active.variance[idxWatt]

    updateMeter(
        watt.active, idxWatt, active, key.variance, key.status, key.noise,
        pfx.activePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    newStatus = watt.active.status[idxWatt]
    if oldStatus != newStatus || oldVariance != watt.active.variance[idxWatt]
        se.run = true
    end

    if isset(key.status, active)
        if watt.layout.bus[idxWatt]
            idxBus = watt.layout.index[idxWatt]
            if isset(key.status)
                for ptr in nodal.colptr[idxBus]:(nodal.colptr[idxBus + 1] - 1)
                    j = nodal.rowval[ptr]
                    se.coefficient[idxWatt, j] = newStatus * nodal.nzval[ptr]
                end
            end
            se.mean[idxWatt] =
                newStatus * (watt.active.mean[idxWatt] - dc.shiftPower[idxBus] -
                system.bus.shunt.conductance[idxBus])
        else
            idxBrch = watt.layout.index[idxWatt]
            newStatus *= system.branch.layout.status[idxBrch]
            if watt.layout.from[idxWatt]
                addmitance = newStatus * dc.admittance[idxBrch]
            else
                addmitance = -newStatus * dc.admittance[idxBrch]
            end
            if isset(key.status)
                i, j = fromto(system, idxBrch)
                se.coefficient[idxWatt, i] = addmitance
                se.coefficient[idxWatt, j] = -addmitance
            end
            se.mean[idxWatt] =
                newStatus * (watt.active.mean[idxWatt] +
                system.branch.parameter.shiftAngle[idxBrch] * addmitance)
        end
    end

    if isset(key.variance)
        se.precision.nzval[idxWatt] = 1 / watt.active.variance[idxWatt]
    end
end

function updateWattmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation{LAV};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    bus = system.bus
    branch = system.branch
    dc = system.model.dc
    watt = device.wattmeter
    se = analysis.method
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idxWatt = watt.label[getLabel(watt, label, "wattmeter")]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)

    updateMeter(
        watt.active, idxWatt, active, key.variance,
        key.status, key.noise, pfx.activePower, basePowerInv
    )

    if isset(key.status, active)
        if watt.layout.bus[idxWatt]
            idxBus = watt.layout.index[idxWatt]
        else
            idxBrch = watt.layout.index[idxWatt]
            if watt.layout.from[idxWatt]
                admittance = dc.admittance[idxBrch]
            else
                admittance = -dc.admittance[idxBrch]
            end
        end
    end

    if isset(key.status, active)
        if watt.active.status[idxWatt] == 1
            add!(se, idxWatt)

            if watt.layout.bus[idxWatt]
                mean = meanPi(bus, dc, watt, idxBus, idxWatt)
                expr = Pi(dc, se, idxWatt)
                addConstrLav!(se, expr, mean, idxWatt)
            elseif branch.layout.status[idxBrch] == 1
                if watt.layout.from[idxWatt]
                    admittance = dc.admittance[idxBrch]
                else
                    admittance = -dc.admittance[idxBrch]
                end
                mean = meanPij(branch, watt, admittance, idxWatt, idxBrch)
                expr = Pij(system, se.state, admittance, idxBrch)
                addConstrLav!(se, expr, mean, idxWatt)
            else
                remove!(se, idxWatt)
            end
        else
            remove!(se, idxWatt)
        end
    end
end

"""
    updateVarmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

The function allows for the alteration of parameters for a varmeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
type only. However, when including the `Analysis` type, it updates both the `Measurement`
and `Analysis` types. This streamlined process avoids the need to completely rebuild vectors
and matrices when adjusting these parameters.

# Keywords
To update a specific varmeter, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addVarmeter!`](@ref addVarmeter!) function, along
with their respective values. Ensure that the `label` keyword matches the `label` of the
existing varmeter you want to modify. If any keywords are omitted, their corresponding
values will remain unchanged.

# Updates
The function updates the `varmeter` field within the `Measurement` type. Furthermore, it
guarantees that any modifications to the parameters are transmitted to the `Analysis` type.

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
function updateVarmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
)
    var = device.varmeter
    key = meterkwargs(template.varmeter.noise; kwargs...)

    idx = var.label[getLabel(var, label, "varmeter")]

    updateMeter(
        var.reactive, idx, reactive, key.variance, key.status, key.noise,
        pfx.reactivePower, 1 / (system.base.power.value * system.base.power.prefix)
    )
end

function updateVarmeter!(
    system::PowerSystem, device::Measurement,
    analysis::ACStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    nodal = system.model.ac.nodalMatrix
    var = device.varmeter
    se = analysis.method
    key = meterkwargs(template.varmeter.noise; kwargs...)

    idxVar = var.label[getLabel(var, label, "varmeter")]
    idxBusBrch = var.layout.index[idxVar]
    idx = device.voltmeter.number + device.ammeter.number + device.wattmeter.number + idxVar

    updateMeter(
        var.reactive, idxVar, reactive, key.variance, key.status, key.noise,
        pfx.reactivePower,  1 / (system.base.power.value * system.base.power.prefix)
    )

    if var.reactive.status[idxVar] == 1
        if var.layout.bus[idxVar]
            se.type[idx] = 9
        elseif var.layout.from[idxVar]
            se.type[idx] = 10
        else
            se.type[idx] = 11
        end
        se.mean[idx] = var.reactive.mean[idxVar]
    else
        if var.layout.bus[idxVar]
            for ptr in nodal.colptr[idxBusBrch]:(nodal.colptr[idxBusBrch + 1] - 1)
                j = nodal.rowval[ptr]
                se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
            end
        else
            i, j = fromto(system, idxBusBrch)
            se.jacobian[idx, i] = se.jacobian[idx, bus.number + i] = 0.0
            se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
        end
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(key.variance)
        se.precision[idx, idx] = 1 / var.reactive.variance[idxVar]
    end
end

function updateVarmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{LAV};
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
)
    var = device.varmeter
    se = analysis.method
    key = meterkwargs(template.varmeter.noise; kwargs...)

    idxVar = var.label[getLabel(var, label, "varmeter")]
    idxBusBrch = var.layout.index[idxVar]
    idx = device.voltmeter.number + device.ammeter.number + device.wattmeter.number + idxVar

    updateMeter(
        var.reactive, idxVar, reactive, key.variance, key.status, key.noise,
        pfx.reactivePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    if var.reactive.status[idxVar] == 1
        add!(se, idx)

        if var.layout.bus[idxVar]
            expr = Qi(system, se, idxBusBrch)
        else
            if var.layout.from[idxVar]
                expr = Qij(system, se, idxBusBrch)
            else
                expr = Qji(system, se, idxBusBrch)
            end
        end
        addConstrLav!(se, expr, var.reactive.mean[idxVar], idx)
    else
        remove!(se, idx)
    end
end

"""
    @wattmeter(label, varianceBus, statusBus, varianceFrom, statusFrom,
        varianceTo, statusTo, noise)

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
per-units. However, users can choose to use watts as the units by applying the
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
@power(MW, pu)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-4)
addWattmeter!(system, device; bus = "Bus 2", active = 40.0)
addWattmeter!(system, device; from = "Branch 1", active = 10.0)
```
"""
macro wattmeter(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(WattmeterTemplate, parameter)
                if parameter in [:varianceBus, :varianceFrom, :varianceTo]
                    container::ContainerTemplate = getfield(template.wattmeter, parameter)
                    val = Float64(eval(kwarg.args[2]))
                    if pfx.activePower != 0.0
                        setfield!(container, :value, pfx.activePower * val)
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, val)
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
                        errorTemplateLabel()
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end

"""
    @varmeter(label, varinaceBus, statusBus, varianceFrom, statusFrom,
        varianceTo, statusTo, noise)

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
per-units. However, users can choose to usevolt-amperes reactive as the units by applying
the [`@power`](@ref @power) macro.

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
@power(pu, MVAr)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@varmeter(label = "Varmeter ?", varianceBus = 1e-1, varianceFrom = 1e-4)
addVarmeter!(system, device; bus = "Bus 2", reactive = 40.0)
addVarmeter!(system, device; from = "Branch 1", reactive = 10.0)
```
"""
macro varmeter(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(VarmeterTemplate, parameter)
                if parameter in [:varianceBus, :varianceFrom, :varianceTo]
                    container::ContainerTemplate = getfield(template.varmeter, parameter)
                    val = Float64(eval(kwarg.args[2]))
                    if pfx.reactivePower != 0.0
                        setfield!(container, :value, pfx.reactivePower * val)
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, val)
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
                        errorTemplateLabel()
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end