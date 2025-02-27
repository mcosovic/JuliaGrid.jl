"""
    addVoltmeter!(system::PowerSystem, device::Measurement;
        label, bus, magnitude, variance, noise, status)

The function adds a new voltmeter that measures bus voltage magnitude to the `Measurement`
type within a given `PowerSystem` type. The voltmeter can be added to an already
defined bus.

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
The function updates the `voltmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `variance = 1e-4`, `noise = false`,
`status = 1`, and users can modify these default settings using the
[`@voltmeter`](@ref @voltmeter) macro.

# Units
The default units for the `magnitude` and `variance` keywords are per-units (pu). However,
users can choose to use volts (V) as the units by applying the [`@voltage`](@ref @voltage)
macro.

# Examples
Adding a voltmeter using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)

addVoltmeter!(system, device; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.1)
```

Adding a voltmeter using a custom unit system:
```jldoctest
@voltage(kV, rad, kV)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132.0)

addVoltmeter!(system, device; label = "Voltmeter 1", bus = "Bus 1", magnitude = 145.2)
```
"""
function addVoltmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss,
    magnitude::FltIntMiss,
    kwargs...
)
    volt = device.voltmeter
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
    addVoltmeter!(system::PowerSystem, device::Measurement, analysis::AC;
        variance, status, noise)

The function incorporates voltmeters into the `Measurement` composite type for every bus
within the `PowerSystem` type. These measurements are derived from the exact bus voltage
magnitudes defined in the `AC` type.

# Keywords
Voltmeters can be configured using:
* `variance` (pu or V): Measurements Variance.
* `status`: Operating status:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the voltage magnitudes, using the defined variance,
  * `noise = false`: uses the exact voltage magnitude values without adding noise.

# Updates
The function updates the `voltmeter` field of the `Measurement` composite type.

# Default Settings
Default settings for keywords are as follows: `variance = 1e-4`, `noise = false`, and
`status = 1`, and users can modify these default settings using the
[`@voltmeter`](@ref @voltmeter) macro.

# Units
By default, the unit for `variance` is per-unit (pu). However, users can choose to use
volts (V) as the units by applying the [`@voltage`](@ref @voltage) macro.

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

@voltmeter(label = "Voltmeter ?")
addVoltmeter!(system, device, analysis; variance = 1e-3, noise = true)
```
"""
function addVoltmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::AC;
    kwargs...
)
    volt = device.voltmeter
    def = template.voltmeter
    baseVoltg = system.base.voltage
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    status = givenOrDefault(key.status, def.status)
    checkWideStatus(status)

    if status != -1
        volt.layout.index = collect(1:system.bus.number)
        volt.label = OrderedDict{template.device, Int64}()
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
    updateVoltmeter!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

The function allows for the alteration of parameters for a voltmeter.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
composite type only. However, when including the `Analysis` type, it updates both the
`Measurement` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific voltmeter, provide the necessary `kwargs` input arguments in
accordance with the keywords specified in the [`addVoltmeter!`](@ref addVoltmeter!)
function, along with their respective values. Ensure that the `label` keyword matches the
`label` of the existing voltmeter you want to modify. If any keywords are omitted, their
corresponding values will remain unchanged.

# Updates
The function updates the `voltmeter` field within the `Measurement` composite type.
Furthermore, it guarantees that any modifications to the parameters are transmitted to the
`Analysis` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addVoltmeter!`](@ref addVoltmeter!) function.

# Example
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)

addVoltmeter!(system, device; label = "Voltmeter 1", bus = "Bus 1", magnitude = 1.1)
updateVoltmeter!(system, device; label = "Voltmeter 1", magnitude = 0.9)
```
"""
function updateVoltmeter!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    volt = device.voltmeter
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    idx = volt.label[getLabel(volt, label, "voltmeter")]
    idxBus = volt.layout.index[idx]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    updateMeter(
        volt.magnitude, idx, magnitude, key.variance,
        key.status, key.noise, pfx.voltageMagnitude, baseInv
    )
end

function updateVoltmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{NonlinearWLS{T}};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    voltmeter = device.voltmeter
    se = analysis.method
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    idx = voltmeter.label[getLabel(voltmeter, label, "voltmeter")]
    idxBus = voltmeter.layout.index[idx]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    updateMeter(
        voltmeter.magnitude, idx, magnitude, key.variance,
        key.status, key.noise, pfx.voltageMagnitude, baseInv
    )

    idxBus += system.bus.number
    if voltmeter.magnitude.status[idx] == 1
        se.jacobian[idx, idxBus] = 1.0
        se.mean[idx] = voltmeter.magnitude.mean[idx]
        se.type[idx] = 1
    else
        se.jacobian[idx, idxBus] = 0.0
        se.mean[idx] = 0.0
        se.residual[idx] = 0.0
        se.type[idx] = 0
    end

    if isset(key.variance)
        se.precision[idx, idx] = 1 / voltmeter.magnitude.variance[idx]
    end
end

function updateVoltmeter!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{LAV};
    label::IntStrMiss,
    magnitude::FltIntMiss = missing,
    kwargs...
)
    volt = device.voltmeter
    se = analysis.method
    key = meterkwargs(template.voltmeter.noise; kwargs...)

    idx = volt.label[getLabel(volt, label, "voltmeter")]
    idxBus = volt.layout.index[idx]
    baseInv = sqrt(3) / (system.base.voltage.value[idxBus] * system.base.voltage.prefix)

    updateMeter(
        volt.magnitude, idx, magnitude, key.variance,
        key.status, key.noise, pfx.voltageMagnitude, baseInv
    )

    if volt.magnitude.status[idx] == 1
        add!(se, idx)
        addConstrLav!(se, se.state.V[idxBus], volt.magnitude.mean[idx], idx)
    else
        remove!(se, idx)
    end
end

"""
    @voltmeter(label, variance, status, noise)

The macro generates a template for a voltmeter, which can be utilized to define a voltmeter
using the [`addVoltmeter!`](@ref addVoltmeter!) function.

# Keywords
To establish the voltmeter template, users can specify default values for the `variance`,
`noise`, and `status` keywords, along with pattern for labels using the `label` keyword.

# Units
By default, the unit for `variance` is per-unit (pu). However, users can choose to use
volts (V) as the units by applying the [`@voltage`](@ref @voltage) macro.

# Examples
Adding a voltmeter using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)

@voltmeter(label = "Voltmeter ?", variance = 1e-5)
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 1.1)
```

Adding a voltmeter using a custom unit system:
```jldoctest
@voltage(kV, rad, kV)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132.0)

@voltmeter(label = "Voltmeter ?", variance = 0.00132)
addVoltmeter!(system, device; bus = "Bus 1", magnitude = 145.2)
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