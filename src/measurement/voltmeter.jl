"""
    addVoltmeter!(monitoring::Measurement; label, bus, magnitude, variance, noise, status)

The function adds a voltmeter that measures bus voltage magnitude to the `Measurement` type. The
voltmeter can be added to an already defined bus.

# Keywords
The voltmeter is defined with the following keywords:
* `label`: Unique label for the voltmeter.
* `bus`: Label of the bus to which the voltmeter is connected.
* `magnitude` (pu or V): Bus voltage magnitude value.
* `variance` (pu or V): Variance of the bus voltage magnitude measurement.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the `magnitude`,
  * `noise = false`: uses the `magnitude` value only.
* `status`: Operating status of the voltmeter:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

Note that all voltage values are referenced to line-to-neutral voltages.

# Updates
The function updates the `voltmeter` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`,
`status = 1`, and users can modify these default settings using the [`@voltmeter`](@ref @voltmeter)
macro.

# Units
The default units for the `magnitude` and `variance` keywords are per-units. However, users can
choose to use volts as the units by applying the [`@voltage`](@ref @voltage) macro.

# Examples
Adding voltmeters using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)

addVoltmeter!(monitoring; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.1)
addVoltmeter!(monitoring; label = "Voltmeter 2", bus = "Bus 1", magnitude = 1.0)
```

Adding voltmeters using a custom unit system:
```jldoctest
@voltage(kV, rad, kV)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132.0)

addVoltmeter!(monitoring; label = "Voltmeter 1", bus = "Bus 1", magnitude = 145.2)
addVoltmeter!(monitoring; label = "Voltmeter 2", bus = "Bus 1", magnitude = 132.0)
```
"""
function addVoltmeter!(monitoring::Measurement; bus::IntStr, magnitude::FltInt, kwargs...)
    system = monitoring.system
    volt = monitoring.voltmeter
    def = template.voltmeter
    key = VoltmeterKey(; kwargs...)

    idx = volt.number + 1
    lblBus = getLabel(system.bus, bus, "bus")

    idxBus = system.bus.label[lblBus]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)
    measure, variance, status = meterValue(
        magnitude, key.variance, key.status, key.noise,
        def.variance, def.status, pfx.voltageMagnitude, baseInv
    )

    setLabel(volt, idx, key.label, def.label, lblBus)
    push!(volt.layout.index, idxBus)
    push!(volt.magnitude.variance, variance)
    push!(volt.magnitude.mean, measure)
    push!(volt.magnitude.status, status)
    volt.number = idx

    return nothing
end

"""
    addVoltmeter!(monitoring::Measurement, analysis::AC; variance, noise, status)

The function incorporates voltmeters into the `Measurement` type for every bus within the
`PowerSystem` type from which `Measurement` was created. These measurements are derived from the
exact bus voltage magnitudes defined in the `AC` type.

# Keywords
Voltmeters can be configured using:
* `variance` (pu or V): Measurements variance.
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the voltage magnitudes using the defined variance,
  * `noise = false`: uses the exact voltage magnitude values without adding noise.
* `status`: Operating status:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

# Updates
The function updates the `voltmeter` field of the `Measurement` type.

# Default Settings
Default settings for keywords are as follows: `variance = 1e-4`, `noise = false`, and `status = 1`,
and users can modify these default settings using the [`@voltmeter`](@ref @voltmeter) macro.

# Units
By default, the unit for `variance` is per-unit. However, users can choose to use volts as the units
by applying the [`@voltage`](@ref @voltage) macro.

# Example
```jldoctest
@voltmeter(label = "Voltmeter ?")

system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis)

addVoltmeter!(monitoring, analysis; variance = 1e-3, noise = true)
```
"""
function addVoltmeter!(monitoring::Measurement, analysis::AC; kwargs...)
    system = monitoring.system
    volt = monitoring.voltmeter
    def = template.voltmeter
    baseVoltg = system.base.voltage
    key = VoltmeterKey(; kwargs...)

    status = coalesce(key.status, def.status)
    checkWideStatus(status)

    if status != -1
        if isempty(volt.label)
            volt.label = OrderedDict{template.voltmeter.key, Int64}()
            sizehint!(volt.label, system.bus.number)
        end

        stop = volt.number + system.bus.number
        resize!(volt.magnitude.mean, stop)
        resize!(volt.magnitude.variance, stop)
        resize!(volt.magnitude.status, stop)
        resize!(volt.layout.index, stop)

        @inbounds for (label, i) in system.bus.label
            idx = volt.number + 1

            lblBus = getLabel(system.bus, label, "bus")
            setLabel(volt, idx, missing, def.label, lblBus)
            baseInv = sqrt(3) / (baseVoltg.prefix * baseVoltg.value[i])
            volt.layout.index[idx] = i

            add!(
                volt.magnitude, idx, key.noise, pfx.voltageMagnitude,
                analysis.voltage.magnitude[i], key.variance, def.variance, status, baseInv
            )
            volt.number = idx
        end

        volt.layout.label = system.bus.number
    end

    return nothing
end

"""
    updateVoltmeter!(monitoring::Measurement; kwargs...)

The function allows for the alteration of parameters for a voltmeter.

# Keywords
To update a specific voltmeter, provide the necessary `kwargs` input arguments in accordance with
the keywords specified in the [`addVoltmeter!`](@ref addVoltmeter!) function, along with their
respective values. Ensure that the `label` keyword matches the `label` of the existing voltmeter.
If any keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `voltmeter` field within the `Measurement` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addVoltmeter!`](@ref addVoltmeter!) function.

# Example
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)

addVoltmeter!(monitoring; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.1)
updateVoltmeter!(monitoring; label = "Voltmeter 1", magnitude = 0.9)
```
"""
function updateVoltmeter!(monitoring::Measurement; label::IntStr, kwargs...)
    updateVoltmeterMain!(monitoring, label, VoltmeterKey(; kwargs...))

    return nothing
end

function updateVoltmeterMain!(monitoring::Measurement, label::IntStr, key::VoltmeterKey)
    system = monitoring.system
    voltmeter = monitoring.voltmeter

    idx = getIndex(voltmeter, label, "voltmeter")
    idxBus = voltmeter.layout.index[idx]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    varianceNew = voltmeter.magnitude.variance[idx]
    if isset(key.variance)
        varianceNew = Float64(topu(key.variance, pfx.voltageMagnitude, baseInv))
    end

    statusNew = voltmeter.magnitude.status[idx]
    if isset(key.status)
        statusNew = Int8(key.status)
    end

    meanNew = voltmeter.magnitude.mean[idx]
    if isset(key.magnitude)
        meanNew = Float64(topu(key.magnitude, pfx.voltageMagnitude, baseInv))
        if key.noise
            meanNew += sqrt(varianceNew) * randn()
        end
    end

    checkStatus(statusNew)
    checkVariance(varianceNew)

    voltmeter.magnitude.variance[idx] = varianceNew
    voltmeter.magnitude.mean[idx] = meanNew
    voltmeter.magnitude.status[idx] = statusNew

    return nothing
end

"""
    updateVoltmeter!(analysis::Analysis; kwargs...)

The function extends the [`updateVoltmeter!`](@ref updateVoltmeter!(::Measurement)) function. By
passing the `Analysis` type, the function first updates the specific voltmeter within the
`Measurement` type using the provided `kwargs`, and then updates the `Analysis` type with all
parameters associated with that voltmeter.

A key feature of this function is that any prior modifications made to the specified voltmeter are
preserved and applied to the `Analysis` type when the function is executed, ensuring consistency
throughout the update process.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

updateVoltmeter!(analysis; label = 2, magnitude = 0.9)
```
"""
function updateVoltmeter!(analysis::AcStateEstimation; label::IntStr, kwargs...)
    updateVoltmeterMain!(analysis.monitoring, label, VoltmeterKey(; kwargs...))
    _updateVoltmeter!(analysis, getIndex(analysis.monitoring.voltmeter, label, "voltmeter"))

    return nothing
end

function _updateVoltmeter!(analysis::AcStateEstimation{<:GaussNewton}, idx::Int64)
    volt = analysis.monitoring.voltmeter
    wls = analysis.method

    idxBus = volt.layout.index[idx]

    idxBus += analysis.system.bus.number
    status = volt.magnitude.status[idx]

    wls.mean[idx] = status * volt.magnitude.mean[idx]
    wls.precision[idx, idx] = 1 / volt.magnitude.variance[idx]
    wls.jacobian[idx, idxBus] = status * 1.0
    wls.residual[idx] = 0.0

    wls.type[idx] = status * 1
end

function _updateVoltmeter!(analysis::AcStateEstimation{LAV}, idx::Int64)
    volt = analysis.monitoring.voltmeter
    lav = analysis.method

    idxBus = volt.layout.index[idx]

    remove!(lav, idx)
    if volt.magnitude.status[idx] == 1
        add!(lav, idx)
        addConstrLav!(lav, lav.variable.voltage.magnitude[idxBus], volt.magnitude.mean[idx], idx)
    end
end

function setVoltmeterTemplate!(parameter::Symbol, value)
    if hasfield(VoltmeterTemplate, parameter)
        if parameter == :variance
            container::ContainerTemplate = getfield(template.voltmeter, parameter)
            setContainerTemplate!(container, value, pfx.voltageMagnitude)
        elseif parameter == :status
            setfield!(template.voltmeter, parameter, Int8(value))
        elseif parameter == :noise
            setfield!(template.voltmeter, parameter, Bool(value))
        elseif parameter == :label
            macroLabel(template.voltmeter, value, "[?!]")
        end
    else
        errorTemplateKeyword(parameter)
    end

    return nothing
end

"""
    @voltmeter(label, variance, noise, status)

The macro generates a template for a voltmeter.

The macro modifies global JuliaGrid settings that remain active until changed again.

# Keywords
To establish the voltmeter template, users can specify default values for the `variance`, `noise`,
and `status` keywords, along with pattern for labels using the `label` keyword.

# Units
By default, the unit for `variance` is per-unit. However, users can choose to use volts as the units
by applying the [`@voltage`](@ref @voltage) macro.

# Examples
Adding a voltmeter using the default unit system:
```jldoctest
@voltmeter(label = "Voltmeter ?", variance = 1e-5)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 1.1)
```

Adding a voltmeter using a custom unit system:
```jldoctest
@voltage(kV, rad, kV)
@voltmeter(label = "Voltmeter ?", variance = 0.00132)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132.0)

addVoltmeter!(monitoring; bus = "Bus 1", magnitude = 145.2)
```
"""
macro voltmeter(kwargs...)
    exprs = map(kwargs) do kwarg
        if !(kwarg isa Expr) || kwarg.head != :(=)
            return :(errorTemplateKeyword($(QuoteNode(kwarg))))
        end

        parameter = kwarg.args[1]
        value = kwarg.args[2]

        :(setVoltmeterTemplate!($(QuoteNode(parameter)), $(esc(value))))
    end

    return Expr(:block, exprs...)
end
