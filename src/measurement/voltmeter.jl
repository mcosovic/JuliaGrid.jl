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
function addVoltmeter!(
    monitoring::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    magnitude::FltIntMiss,
    kwargs...
)
    system = monitoring.system
    volt = monitoring.voltmeter
    def = template.voltmeter
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    volt.number += 1
    lblBus = getLabel(system.bus, bus, "bus")
    setLabel(volt, label, def.label, lblBus)

    idxBus = system.bus.label[lblBus]
    push!(volt.layout.index, idxBus)

    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    setMeter(
        volt.magnitude, magnitude, key.variance, key.status, key.noise,
        def.variance, def.status, pfx.voltageMagnitude, baseInv
    )
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
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    status = givenOrDefault(key.status, def.status)
    checkWideStatus(status)

    if status != -1
        volt.layout.index = collect(1:system.bus.number)
        volt.label = OrderedDict{template.config.monitoring, Int64}()
        sizehint!(volt.label, volt.number)

        volt.magnitude.mean = similar(analysis.voltage.magnitude)
        volt.magnitude.variance = similar(analysis.voltage.magnitude)
        volt.magnitude.status = fill(Int8(status), system.bus.number)

        label = collect(keys(system.bus.label))
        @inbounds for i = 1:system.bus.number
            volt.number += 1

            lblBus = getLabel(system.bus, label[i], "bus")
            setLabel(volt, missing, def.label, lblBus)
            baseInv = sqrt(3) / (baseVoltg.prefix * baseVoltg.value[i])

            add!(
                volt.magnitude, i, key.noise, pfx.voltageMagnitude,
                analysis.voltage.magnitude[i], key.variance, def.variance, status, baseInv
            )
        end

        volt.layout.label = system.bus.number
    end
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
function updateVoltmeter!(
    monitoring::Measurement;
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    system = monitoring.system
    volt = monitoring.voltmeter
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    idx = getIndex(volt, label, "voltmeter")
    idxBus = volt.layout.index[idx]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    updateMeter(
        volt.magnitude, idx, magnitude, key.variance,
        key.status, key.noise, pfx.voltageMagnitude, baseInv
    )
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
function updateVoltmeter!(
    analysis::AcStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    volt = analysis.monitoring.voltmeter
    wls = analysis.method

    updateVoltmeter!(analysis.monitoring; label, magnitude, kwargs...)

    idx = getIndex(volt, label, "voltmeter")
    idxBus = volt.layout.index[idx]

    idxBus += analysis.system.bus.number
    status = volt.magnitude.status[idx]

    wls.mean[idx] = status * volt.magnitude.mean[idx]
    wls.precision[idx, idx] = 1 / volt.magnitude.variance[idx]
    wls.jacobian[idx, idxBus] = status * 1.0
    wls.residual[idx] = 0.0

    wls.type[idx] = status * 1
end

function updateVoltmeter!(
    analysis::AcStateEstimation{LAV};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    volt = analysis.monitoring.voltmeter
    lav = analysis.method

    updateVoltmeter!(analysis.monitoring; label, magnitude, kwargs...)

    idx = getIndex(volt, label, "voltmeter")
    idxBus = volt.layout.index[idx]

    remove!(lav, idx)
    if volt.magnitude.status[idx] == 1
        add!(lav, idx)
        addConstrLav!(lav, lav.variable.voltage.magnitude[idxBus], volt.magnitude.mean[idx], idx)
    end
end

"""
    @voltmeter(label, variance, noise, status)

The macro generates a template for a voltmeter.

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
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(VoltmeterTemplate, parameter)
                if parameter == :variance
                    container::ContainerTemplate = getfield(template.voltmeter, parameter)
                    val = Float64(eval(kwarg.args[2]))
                    if pfx.voltageMagnitude != 0.0
                        setfield!(container, :value, pfx.voltageMagnitude * val)
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, val)
                        setfield!(container, :pu, true)
                    end
                elseif parameter == :status
                    setfield!(template.voltmeter, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter == :noise
                    setfield!(template.voltmeter, parameter, Bool(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?") || contains(label, "!")
                        setfield!(template.voltmeter, parameter, label)
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