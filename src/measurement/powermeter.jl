"""
    addWattmeter!(monitoring::Measurement;
        label, bus, from, to, active, variance, noise, status)

The function adds a wattmeter that measures active power injection or active power flow to the
`Measurement` type. The wattmeter can be added to an already defined bus or branch.

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
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`, and
`status = 1`, which apply to wattmeters located at the bus, as well as at both the from-bus and
to-bus ends. Users can fine-tune these settings by explicitly specifying the variance and status for
wattmeters positioned at the buses, from-bus ends, or to-bus ends of branches using the
[`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `active` and `variance` keywords are per-units. However, users can choose
to use watts as the units by applying the [`@power`](@ref @power) macro.

# Examples
Adding wattmeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(monitoring; label = "Wattmeter 1", bus = "Bus 2", active = 0.4)
addWattmeter!(monitoring; label = "Wattmeter 2", from = "Branch 1", active = 0.1)
```

Adding wattmeters using a custom unit system:
```jldoctest
@power(MW, pu)

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(monitoring; label = "Wattmeter 1", bus = "Bus 2", active = 40.0)
addWattmeter!(monitoring; label = "Wattmeter 2", from = "Branch 1", active = 10.0)
```
"""
function addWattmeter!(
    monitoring::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    active::FltInt,
    kwargs...
)
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    addPowerMeter!(
        monitoring.system, monitoring.wattmeter, monitoring.wattmeter.active, template.wattmeter,
        pfx.activePower, label, bus, from, to, active, key.variance, key.status, key.noise
    )
end

"""
    addVarmeter!(monitoring::Measurement;
        label, bus, from, to, reactive, variance, noise, status)

The function adds a varmeter that measures reactive power injection or reactive power flow to the
`Measurement` type. The varmeter can be added to an already defined bus or branch.

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
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`, and
`status = 1`, which apply to varmeters located at the bus, as well as at both the from-bus and to-bus
ends. Users can fine-tune these settings by explicitly specifying the variance and status for
varmeters positioned at the buses, from-bus ends, or to-bus ends of branches using the
[`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `reactive` and `variance` keywords are per-units. However, users can
choose to use volt-amperes reactive as the units by applying the [`@power`](@ref @power) macro.

# Examples
Adding varmeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(monitoring; label = "Varmeter 1", bus = "Bus 2", reactive = 0.4)
addVarmeter!(monitoring; label = "Varmeter 2", from = "Branch 1", reactive = 0.1)
```

Adding varmeters using a custom unit system:
```jldoctest
@power(pu, MVAr)

system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(monitoring; label = "Varmeter 1", bus = "Bus 2", reactive = 40.0)
addVarmeter!(monitoring; label = "Varmeter 2", from = "Branch 1", reactive = 10.0)
```
"""
function addVarmeter!(
    monitoring::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    reactive::FltInt,
    kwargs...
)
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    addPowerMeter!(
        monitoring.system, monitoring.varmeter, monitoring.varmeter.reactive, template.varmeter,
        pfx.reactivePower, label, bus, from, to, reactive, key.variance, key.status, key.noise
    )
end

######### Add Wattmeter or Varmeter ##########
function addPowerMeter!(
    system::PowerSystem,
    monitoring::Union{Wattmeter, Varmeter},
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
        monitoring.number += 1
        push!(monitoring.layout.bus, busFlag)
        push!(monitoring.layout.from, fromFlag)
        push!(monitoring.layout.to, toFlag)

        if busFlag
            lblBus = getLabel(system.bus, location, "bus")
            idx = system.bus.label[lblBus]

            setLabel(monitoring, label, def.label, lblBus)

            defVariance = def.varianceBus
            defStatus = def.statusBus
        elseif fromFlag
            setLabel(monitoring, label, def.label, lblBrch; prefix = "From ")

            defVariance = def.varianceFrom
            defStatus = def.statusFrom
        else
            setLabel(monitoring, label, def.label, lblBrch; prefix = "To ")

            defVariance = def.varianceTo
            defStatus = def.statusTo
        end
        push!(monitoring.layout.index, idx)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)
        setMeter(
            measure, power, variance, status, noise,
            defVariance, defStatus, pfxPower, baseInv
        )
    end
end

"""
    addWattmeter!(monitoring::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates wattmeters into the `Measurement` type for every branch within the
`PowerSystem` type from which `Measurement` was created. These measurements are derived from the
exact active power injections at buses and active power flows in branches defined in the `AC` type.

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
`varianceFrom = 1e-4`, `statusFrom = 1`, `varianceTo = 1e-4`, `statusTo = 1`, and `noise = false`.
Users can change these default settings using the [`@wattmeter`](@ref @wattmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are per-units.
However, users can choose to use watts as the units by applying the [`@power`](@ref @power) macro.

# Example
```jldoctest
@wattmeter(label = "Wattmeter ?")

system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(system, analysis; power = true)

addWattmeter!(monitoring, analysis; varianceBus = 1e-3, statusFrom = 0)
```
"""
function addWattmeter!(
    monitoring::Measurement,
    analysis::AC;
    varianceBus::FltIntMiss = missing,
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusBus::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    noise::Bool = template.wattmeter.noise
)
    wattmeter = monitoring.wattmeter
    power = analysis.power

    addPowermeter!(
        monitoring.system, wattmeter, wattmeter.active, power.injection.active,
        power.from.active, power.to.active, template.wattmeter, pfx.activePower,
        varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo, noise
    )
end

"""
    addVarmeter!(monitoring::Measurement, analysis::AC;
        varianceBus, statusBus, varianceFrom, statusFrom, varianceTo, statusTo, noise)

The function incorporates varmeters into the `Measurement` type for every branch within the
`PowerSystem` type from which `Measurement` was created. These measurements are derived from the
exact reactive power injections at buses and reactive power flows in branches defined in the `AC`
type.

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
`varianceFrom = 1e-4`, `statusFrom = 1`, `varianceTo = 1e-4`, `statusTo = 1`, and `noise = false`.
Users can change these default settings using the [`@varmeter`](@ref @varmeter) macro.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are per-units.
However, users can choose to use volt-amperes reactive as the units by applying the
[`@power`](@ref @power) macro.

# Example
```jldoctest
@varmeter(label = "Varmeter ?")

system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(system, analysis; power = true)

addVarmeter!(monitoring, analysis; varianceFrom = 1e-3, statusBus = 0)
```
"""
function addVarmeter!(
    monitoring::Measurement,
    analysis::AC;
    varianceBus::FltIntMiss = missing,
    varianceFrom::FltIntMiss = missing,
    varianceTo::FltIntMiss = missing,
    statusBus::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    noise::Bool = template.varmeter.noise
)
    varmeter = monitoring.varmeter
    power = analysis.power

    addPowermeter!(
        monitoring.system, varmeter, varmeter.reactive, power.injection.reactive,
        power.from.reactive, power.to.reactive, template.varmeter, pfx.reactivePower,
        varianceBus, varianceFrom, varianceTo, statusBus, statusFrom, statusTo, noise
    )
end

######### Add Group of Wattmeters or Varmeters ##########
function addPowermeter!(
    system::PowerSystem,
    monitoring::Union{Wattmeter, Varmeter},
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

        monitoring.label = OrderedDict{template.config.monitoring, Int64}()
        sizehint!(monitoring.label, deviceNumber)
        monitoring.number = 0

        monitoring.layout.index = fill(0, deviceNumber)
        monitoring.layout.bus = fill(false, deviceNumber)
        monitoring.layout.from = fill(false, deviceNumber)
        monitoring.layout.to = fill(false, deviceNumber)

        measure.mean = fill(0.0, deviceNumber)
        measure.variance = similar(measure.mean)
        measure.status = fill(Int8(0), deviceNumber)

        baseInv = 1 / (system.base.power.value * system.base.power.prefix)

        if statusBus != -1
            @inbounds for (label, i) in system.bus.label
                monitoring.number += 1
                setLabel(monitoring, missing, def.label, label)

                monitoring.layout.index[i] = i
                monitoring.layout.bus[i] = true

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
                        monitoring.number += 1
                        setLabel(monitoring, missing, def.label, label; prefix = "From ")

                        monitoring.layout.index[monitoring.number] = i
                        monitoring.layout.from[monitoring.number] = true

                        add!(
                            measure, monitoring.number, noise, pfxPower, powerFrom[i],
                            varianceFrom, def.varianceFrom, statusFrom, baseInv
                        )
                    end

                    if statusTo != -1
                        monitoring.number += 1
                        setLabel(monitoring, missing, def.label, label; prefix = "To ")

                        monitoring.layout.index[monitoring.number] = i
                        monitoring.layout.to[monitoring.number] = true

                        add!(
                            measure, monitoring.number, noise, pfxPower, powerTo[i],
                            varianceTo, def.varianceTo, statusTo, baseInv
                        )
                    end
                end
            end
        end
        monitoring.layout.label = monitoring.number
    end
end

"""
    updateWattmeter!(monitoring::Measurement; kwargs...)

The function allows for the alteration of parameters for a wattmeter.

# Keywords
To update a specific wattmeter, provide the necessary `kwargs` input arguments in accordance with
the keywords specified in the [`addWattmeter!`](@ref addWattmeter!) function, along with their
respective values. Ensure that the `label` keyword matches the `label` of the existing wattmeter you
want to modify. If any keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `wattmeter` field within the `Measurement` composite type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addWattmeter!`](@ref addWattmeter!) function.

# Example
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addWattmeter!(monitoring; label = "Wattmeter 1", from = "Branch 1", active = 1.1)
updateWattmeter!(monitoring; label = "Wattmeter 1", active = 1.2, variance = 1e-4)
```
"""
function updateWattmeter!(
    monitoring::Measurement;
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    system = monitoring.system
    watt = monitoring.wattmeter
    key = meterkwargs(template.wattmeter.noise; kwargs...)

    idx = getIndex(watt, label, "wattmeter")

    updateMeter(
        watt.active, idx, active, key.variance, key.status, key.noise,
        pfx.activePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    if !watt.layout.bus[idx]
        idxBrch = watt.layout.index[idx]
        watt.active.status[idx] &= system.branch.layout.status[idxBrch]
    end
end

"""
    updateWattmeter!(analysis::Analysis; kwargs...)

The function extends the [`updateWattmeter!`](@ref updateWattmeter!(::Measurement)) function. By
passing the `Analysis` type, the function first updates the specific wattmeter within the
`Measurement` type using the provided `kwargs`, and then updates the `Analysis` type with all
parameters associated with that wattmeter.

A key feature of this function is that any prior modifications made to the specified wattmeter are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

updateWattmeter!(analysis; label = 4, active = 0.5, variance = 1e-4)
```
"""
function updateWattmeter!(
    analysis::AcStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = analysis.system.bus
    nodal = analysis.system.model.ac.nodalMatrix
    watt = analysis.monitoring.wattmeter
    wls = analysis.method

    updateWattmeter!(analysis.monitoring; label, active, kwargs...)

    idxWatt = getIndex(watt, label, "wattmeter")
    idxBusBrch = watt.layout.index[idxWatt]
    idx = wls.range[3] + idxWatt - 1

    status = watt.active.status[idxWatt]

    wls.mean[idx] = status * watt.active.mean[idxWatt]
    wls.residual[idx] = 0.0

    if watt.layout.bus[idxWatt]
        for ptr in nodal.colptr[idxBusBrch]:(nodal.colptr[idxBusBrch + 1] - 1)
            j = nodal.rowval[ptr]
            wls.jacobian[idx, j] = wls.jacobian[idx, bus.number + j] = 0.0
        end
    else
        i, j = fromto(analysis.system, idxBusBrch)
        wls.jacobian[idx, i] = wls.jacobian[idx, bus.number + i] = 0.0
        wls.jacobian[idx, j] = wls.jacobian[idx, bus.number + j] = 0.0
    end

    if watt.layout.bus[idxWatt]
        wls.type[idx] = status * 6
    elseif watt.layout.from[idxWatt]
        wls.type[idx] = status * 7
    else
        wls.type[idx] = status * 8
    end

    wls.precision[idx, idx] = 1 / watt.active.variance[idxWatt]
end

function updateWattmeter!(
    analysis::AcStateEstimation{LAV};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    watt = analysis.monitoring.wattmeter
    lav = analysis.method

    updateWattmeter!(analysis.monitoring; label, active, kwargs...)

    idxWatt = getIndex(watt, label, "wattmeter")
    idxBusBrch = watt.layout.index[idxWatt]
    idx = lav.range[3] + idxWatt - 1

    remove!(lav, idx)
    if watt.active.status[idxWatt] == 1
        add!(lav, idx)

        if watt.layout.bus[idxWatt]
            expr = Pi(system, lav.variable.voltage, idxBusBrch)
        elseif watt.layout.from[idxWatt]
            expr = Pij(system, lav.variable.voltage, idxBusBrch)
        else
            expr = Pji(system, lav.variable.voltage, idxBusBrch)
        end

        addConstrLav!(lav, expr, watt.active.mean[idxWatt], idx)
    end
end

function updateWattmeter!(
    analysis::DcStateEstimation{WLS{T}};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    system = analysis.system
    dc = system.model.dc
    nodal = dc.nodalMatrix
    watt = analysis.monitoring.wattmeter
    wls = analysis.method

    updateWattmeter!(analysis.monitoring; label, active, kwargs...)

    idxWatt = getIndex(watt, label, "wattmeter")
    idxBusBrch = watt.layout.index[idxWatt]

    oldCoeff = wls.coefficient[idxWatt, :]
    oldPrec = wls.precision.nzval[idxWatt]
    status = watt.active.status[idxWatt]

    if watt.layout.bus[idxWatt]
        for ptr in nodal.colptr[idxBusBrch]:(nodal.colptr[idxBusBrch + 1] - 1)
            j = nodal.rowval[ptr]
            wls.coefficient[idxWatt, j] = status * nodal.nzval[ptr]
        end

        wls.mean[idxWatt] =
            status * (watt.active.mean[idxWatt] - dc.shiftPower[idxBusBrch] -
                system.bus.shunt.conductance[idxBusBrch])
    else
        if watt.layout.from[idxWatt]
            addmitance = status * dc.admittance[idxBusBrch]
        else
            addmitance = -status * dc.admittance[idxBusBrch]
        end

        i, j = fromto(system, idxBusBrch)
        wls.coefficient[idxWatt, i] = addmitance
        wls.coefficient[idxWatt, j] = -addmitance

        wls.mean[idxWatt] =
            status * (watt.active.mean[idxWatt] +
                system.branch.parameter.shiftAngle[idxBusBrch] * addmitance)
    end

    wls.precision.nzval[idxWatt] = 1 / watt.active.variance[idxWatt]

    if oldCoeff != wls.coefficient[idxWatt, :] || oldPrec != wls.precision.nzval[idxWatt]
        wls.signature[:run] = true
    end
end

function updateWattmeter!(
    analysis::DcStateEstimation{LAV};
    label::IntStrMiss,
    active::FltIntMiss = missing,
    kwargs...
)
    dc = analysis.system.model.dc
    watt = analysis.monitoring.wattmeter
    lav = analysis.method

    updateWattmeter!(analysis.monitoring; label, active, kwargs...)

    idxWatt = getIndex(watt, label, "wattmeter")
    idxBusBrch = watt.layout.index[idxWatt]

    remove!(lav, idxWatt)
    if watt.active.status[idxWatt] == 1
        add!(lav, idxWatt)

        if watt.layout.bus[idxWatt]
            mean = meanPi(analysis.system.bus, dc, watt, idxWatt, idxBusBrch)
            expr = Pi(analysis.system, lav.variable.voltage, idxBusBrch)
        else
            if watt.layout.from[idxWatt]
                admittance = dc.admittance[idxBusBrch]
            else
                admittance = -dc.admittance[idxBusBrch]
            end
            mean = meanPij(analysis.system.branch, watt, admittance, idxWatt, idxBusBrch)
            expr = Pij(analysis.system,  lav.variable.voltage, admittance, idxBusBrch)
        end

        addConstrLav!(lav, expr, mean, idxWatt)
    end
end

"""
    updateVarmeter!(monitoring::Measurement; kwargs...)

The function allows for the alteration of parameters for a varmeter.

# Keywords
To update a specific varmeter, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addVarmeter!`](@ref addVarmeter!) function, along with their respective
values. Ensure that the `label` keyword matches the `label` of the existing varmeter you want to
modify. If any keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `varmeter` field within the `Measurement` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addVarmeter!`](@ref addVarmeter!) function.

# Example
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addVarmeter!(monitoring; label = "Varmeter 1", from = "Branch 1", reactive = 1.1)
updateVarmeter!(monitoring; label = "Varmeter 1", reactive = 1.2, variance = 1e-4)
```
"""
function updateVarmeter!(
    monitoring::Measurement;
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
)
    system = monitoring.system
    var = monitoring.varmeter
    key = meterkwargs(template.varmeter.noise; kwargs...)

    idx = getIndex(var, label, "varmeter")

    updateMeter(
        var.reactive, idx, reactive, key.variance, key.status, key.noise,
        pfx.reactivePower, 1 / (system.base.power.value * system.base.power.prefix)
    )

    if !var.layout.bus[idx]
        idxBrch = var.layout.index[idx]
        var.reactive.status[idx] &= system.branch.layout.status[idxBrch]
    end
end

"""
    updateVarmeter!(analysis::Analysis; kwargs...)

The function extends the [`updateVarmeter!`](@ref updateVarmeter!(::Measurement)) function. By
passing the `Analysis` type, the function first updates the specific varmeter within the
`Measurement` type using the provided `kwargs`, and then updates the `Analysis` type with all
parameters associated with that varmeter.

A key feature of this function is that any prior modifications made to the specified varmeter are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

updateVarmeter!(analysis; label = 4, reactive = 0.3, variance = 1e-3)
```
"""
function updateVarmeter!(
    analysis::AcStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = analysis.system.bus
    nodal = analysis.system.model.ac.nodalMatrix
    var = analysis.monitoring.varmeter
    wls = analysis.method

    updateVarmeter!(analysis.monitoring; label, reactive, kwargs...)

    idxVar = getIndex(var, label, "varmeter")
    idxBusBrch = var.layout.index[idxVar]
    idx = wls.range[4] + idxVar - 1

    status = var.reactive.status[idxVar]

    wls.mean[idx] = status * var.reactive.mean[idxVar]
    wls.residual[idx] = 0.0

    if var.layout.bus[idxVar]
        for ptr in nodal.colptr[idxBusBrch]:(nodal.colptr[idxBusBrch + 1] - 1)
            j = nodal.rowval[ptr]
            wls.jacobian[idx, j] = wls.jacobian[idx, bus.number + j] = 0.0
        end
    else
        i, j = fromto(analysis.system, idxBusBrch)
        wls.jacobian[idx, i] = wls.jacobian[idx, bus.number + i] = 0.0
        wls.jacobian[idx, j] = wls.jacobian[idx, bus.number + j] = 0.0
    end

    if var.layout.bus[idxVar]
        wls.type[idx] = status * 9
    elseif var.layout.from[idxVar]
        wls.type[idx] = status * 10
    else
        wls.type[idx] = status * 11
    end

    wls.precision[idx, idx] = 1 / var.reactive.variance[idxVar]
end

function updateVarmeter!(
    analysis::AcStateEstimation{LAV};
    label::IntStrMiss,
    reactive::FltIntMiss = missing,
    kwargs...
)
    var = analysis.monitoring.varmeter
    lav = analysis.method

    updateVarmeter!(analysis.monitoring; label, reactive, kwargs...)

    idxVar = getIndex(var, label, "varmeter")
    idxBusBrch = var.layout.index[idxVar]
    idx = lav.range[4] + idxVar - 1

    remove!(lav, idx)
    if var.reactive.status[idxVar] == 1
        add!(lav, idx)

        if var.layout.bus[idxVar]
            expr = Qi(analysis.system, lav.variable.voltage, idxBusBrch)
        elseif var.layout.from[idxVar]
            expr = Qij(analysis.system, lav.variable.voltage, idxBusBrch)
        else
            expr = Qji(analysis.system, lav.variable.voltage, idxBusBrch)
        end
        addConstrLav!(lav, expr, var.reactive.mean[idxVar], idx)
    end
end

"""
    @wattmeter(label, varianceBus, statusBus, varianceFrom, statusFrom,
        varianceTo, statusTo, noise)

The macro generates a template for a wattmeter.

# Keywords
To establish the wattmeter template, users can set default variance and status values for wattmeters
at buses using `varianceBus` and `statusBus`, and at both the from-bus and to-bus ends of branches
using `varianceFrom` and `statusFrom` for the former and `varianceTo` and `statusTo` for the latter.
Users can also configure label patterns with the `label` keyword, as well as specify the `noise` type.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are per-units.
However, users can choose to use watts as the units by applying the [`@power`](@ref @power) macro.

# Examples
Adding wattmeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4)
addWattmeter!(monitoring; bus = "Bus 2", active = 0.4)
addWattmeter!(monitoring; from = "Branch 1", active = 0.1)
```

Adding wattmeters using a custom unit system:
```jldoctest
@power(MW, pu)
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@wattmeter(label = "Wattmeter ?", varianceBus = 1e-1, varianceFrom = 1e-4)
addWattmeter!(monitoring; bus = "Bus 2", active = 40.0)
addWattmeter!(monitoring; from = "Branch 1", active = 10.0)
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

The macro generates a template for a varmeter.

# Keywords
To establish the varmeter template, users can set default variance and status values for varmeters
at buses using `varianceBus` and `statusBus`, and at both the from-bus and to-bus ends of branches
using `varianceFrom` and `statusFrom` for the former and `varianceTo` and `statusTo` for the latter.
Users can also configure label patterns with the `label` keyword, as well as specify the `noise` type.

# Units
The default units for the `varianceBus`, `varianceFrom`, and `varianceTo` keywords are per-units.
However, users can choose to usevolt-amperes reactive as the units by applying the
[`@power`](@ref @power) macro.

# Examples
Adding varmeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@varmeter(label = "Varmeter ?", varianceBus = 1e-3, varianceFrom = 1e-4)
addVarmeter!(monitoring; bus = "Bus 2", reactive = 0.4)
addVarmeter!(monitoring; from = "Branch 1", reactive = 0.1)
```

Adding varmeters using a custom unit system:
```jldoctest
@power(pu, MVAr)
system, monitoring = ems()

addBus!(system; label = "Bus 1")
addBus!(system; label = "Bus 2")
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@varmeter(label = "Varmeter ?", varianceBus = 1e-1, varianceFrom = 1e-4)
addVarmeter!(monitoring; bus = "Bus 2", reactive = 40.0)
addVarmeter!(monitoring; from = "Branch 1", reactive = 10.0)
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