"""
    addPmu!(system::PowerSystem, device::Measurement; label, bus, from, to,
        magnitude, varianceMagnitude, statusMagnitude,
        angle, varianceAngle, statusAngle, noise)
        
The function adds a new PMU to the `Measurement` composite type within a given `PowerSystem` 
type. The PMU can be added to an already defined bus or branch. When defining the PMU, it 
is essential to provide the voltage magnitude and angle if the PMU is located at a bus or 
the current magnitude and angle if the PMU is located at a branch.

# Keywords
The PMU is defined with the following keywords:
* `label`: a unique label for the PMU;
* `bus`: the label of the bus if the PMU is located at the bus;
* `from`: the label of the branch if the PMU is located at the "from" bus end;
* `to`: the label of the branch if the PMU is located at the "to" bus end;
* `magnitude` (pu or V, A): the magnitude value of the bus voltage or branch current;
* `varianceMagnitude` (pu or V, A): the magnitude measurement variance;
* `statusMagnitude`: the operating status of the magnitude measurement of the PMU:
  * `statusMagnitude = 1`: in-service;
  * `statusMagnitude = 0`: out-of-service;
* `angle` (rad or deg): the angle value of the bus voltage or branch current;
* `varianceAngle` (rad or deg): the angle measurement variance;
* `statusAngle`: the operating status of the angle measurement of the PMU:
  * `statusAngle = 1`: in-service;
  * `statusAngle = 0`: out-of-service;
* `noise`:
  * `noise = true`: AWGNs with variances influence `magnitude` and `angle` to define the measurement means;
  * `noise = false`: the values of `magnitude` and `angle` are used as the means of the measurements.

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `varianceMagnitude = 1e-5`, 
`statusMagnitude = 1`, `varianceAngle = 1e-5`,  `statusAngle = 1`, and `noise = true`, 
which apply to PMUs located at the bus, as well as at both the "from" and "to" bus ends. 
Users can fine-tune these settings by explicitly specifying the variance and status for 
PMUs positioned at the bus, "from" bus ends, or "to" bus ends of branches using the 
[@pmu](@ref @pmu) macro.

# Units
The default units for the `magnitude`, `varianceMagnitude`, and `angle`, `varianceAngle`
keywords are per-units (pu) and radians (rad). However, users have the option to switch
to volts (V) and degrees (deg) when the PMU is located at a bus using the
[`@voltage`](@ref @voltage) macro, or amperes (A) and degrees (deg) when the PMU is located
at a branch through the use of the [`@current`](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 1.1, angle = -0.1)
addPmu!(system, device; label = "PMU 2", from = "Branch 1", magnitude = 1.1, angle = -0.2)
```

Adding PMUs using a custom unit system:
```jldoctest``
@voltage(kV, deg, kV)
@current(A, deg)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132.0)
addBus!(system; label = "Bus 2", base = 132.0)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 145.2, angle = -5.73)
addPmu!(system, device; label = "PMU 2", from = "Branch 1", magnitude = 481.125, angle = -11.46)
```
"""
function addPmu!(system::PowerSystem, device::Measurement;
    label::L = missing, bus::L = missing, from::L = missing, to::L = missing,
    magnitude::T, angle::T, varianceMagnitude::T = missing, varianceAngle::T = missing,
    statusMagnitude::T = missing, statusAngle::T = missing, noise::Bool = template.pmu.noise)

    pmu = device.pmu
    default = template.pmu

    location = checkLocation(pmu, bus, from, to)

    pmu.number += 1
    setLabel(pmu, label, default.label, "PMU")

    if pmu.layout.bus[end]
        index = system.bus.label[getLabel(system.bus, location, "bus")]

        defaultVarianceMagnitude = default.varianceMagnitudeBus
        defaultVarianceAngle = default.varianceAngleBus
        defaultMagnitudeStatus = default.statusMagnitudeBus
        defaultAngleStatus = default.statusAngleBus

        prefixMagnitude = prefix.voltageMagnitude
        prefixAngle = prefix.voltageAngle
        baseInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
    else
        index = system.branch.label[getLabel(system.branch, location, "branch")]
        if pmu.layout.from[end]
            defaultVarianceMagnitude = default.varianceMagnitudeFrom
            defaultVarianceAngle = default.varianceAngleFrom
            defaultMagnitudeStatus = default.statusMagnitudeFrom
            defaultAngleStatus = default.statusAngleFrom

            baseVoltage = system.base.voltage.value[system.branch.layout.from[index]] * system.base.voltage.prefix
        else
            defaultVarianceMagnitude = default.varianceMagnitudeTo
            defaultVarianceAngle = default.varianceAngleTo
            defaultMagnitudeStatus = default.statusMagnitudeTo
            defaultAngleStatus = default.statusAngleTo

            baseVoltage = system.base.voltage.value[system.branch.layout.to[index]] * system.base.voltage.prefix
        end
        prefixMagnitude = prefix.currentMagnitude
        prefixAngle = prefix.currentAngle
        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseInv = baseCurrentInverse(basePowerInv, baseVoltage)
    end
    push!(pmu.layout.index, index)

    setMeter(pmu.magnitude, magnitude, varianceMagnitude, statusMagnitude, noise,
        defaultVarianceMagnitude, defaultMagnitudeStatus, prefixMagnitude, baseInv)

    setMeter(pmu.angle, angle, varianceAngle, statusAngle, noise, defaultVarianceAngle,
        defaultAngleStatus, prefixAngle, 1.0)
end

"""
    addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceMagnitudeBus, statusMagnitudeBus, varianceAngleBus, statusAngleBus,
        varianceMagnitudeFrom, statusMagnitudeFrom, varianceAngleFrom, statusAngleFrom,
        varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo)

The function incorporates PMUs into the `Measurement` composite type for every bus and
branch within the `PowerSystem` type. These measurements are derived from the exact bus
voltage magnitudes and angles, as well as branch current magnitudes and angles defined in
the `AC` abstract type. These exact values are then perturbed by AWGN with the specified
`varianceMagnitude` and `varianceAngle` to obtain measurement data.

# Keywords
Users have the option to configure the following keywords:
* `varianceMagnitudeBus` (pu or V): the magnitude measurement variance for PMUs at the buses;
* `statusMagnitudeBus`: the operating status of the magnitude measurements of the PMUs at the buses:
  * `statusMagnitudeBus = 1`: in-service;
  * `statusMagnitudeBus = 0`: out-of-service;
* `varianceAngleBus` (rad or deg): the angle measurement variance for PMUs at the buses;
* `statusAngleBus`: the operating status of the angle measurements of the PMUs at the buses:
  * `statusAngleBus = 1`: in-service;
  * `statusAngleBus = 0`: out-of-service;
* `varianceMagnitudeFrom` (pu or A): the magnitude measurement variance for PMUs at the "from" bus ends of branches;
* `statusMagnitudeFrom`: the operating status of the magnitude measurements of the PMUs at the "from" bus ends of branches;
  * `statusMagnitudeFrom = 1`: in-service;
  * `statusMagnitudeFrom = 0`: out-of-service;
* `varianceAngleFrom` (rad or deg): the angle measurement variance for PMUs at the "from" bus ends of branches;
* `statusAngleFrom`: the operating status of the angle measurements of the PMUs at the "from" bus ends of branches;
  * `statusAngleFrom = 1`: in-service;
  * `statusAngleFrom = 0`: out-of-service;
* `varianceMagnitudeTo` (pu or A): the magnitude measurement variance for PMUs at the "to" bus ends of branches;
* `statusMagnitudeTo`: the operating status of the magnitude measurements of the PMUs at the "to" bus ends of branches;
  * `statusMagnitudeTo = 1`: in-service;
  * `statusMagnitudeTo = 0`: out-of-service;
* `varianceAngleTo` (rad or deg): the angle measurement variance for PMUs at the "to" bus ends of branches;
* `statusAngleTo`: the operating status of the angle measurements of the PMUs at the "to" bus ends of branches;
  * `statusAngleTo = 1`: in-service;
  * `statusAngleTo = 0`: out-of-service.

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

# Default Settings
Default settings for variance keywords are established at `1e-5`, with all statuses set to 
`1`. Users can change these default settings using the [`@pmu`](@ref @pmu) macro.

# Units
The default units for the variance keywords are in per-units (pu) and radians (rad). However, 
users have the option to switch to volts (V) and degrees (deg) when the PMU is located at 
a bus using the [`@voltage`](@ref @voltage) macro, or amperes (A) and degrees (deg) when 
the PMU is located at a branch through the use of the [`@current`](@ref @current) macro.

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

device = measurement()

@ammeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; variance = 1e-3)
```

Adding ammeters using exact values from the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

device = measurement()

@ammeter(label = "Wattmeter ?")
addWattmeter!(system, device, analysis; variance = 1e-3)
```
"""
function addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceMagnitude::T = missing, varianceAngle::T = missing,
    statusMagnitude::T = missing, statusAngle::T = missing)

    pmu = device.pmu
    default = template.pmu

    statusMagnitudeBus = unitless(statusMagnitude, default.statusMagnitudeBus)
    checkStatus(statusMagnitudeBus)
    statusAngleBus = unitless(statusAngle, default.statusAngleBus)
    checkStatus(statusAngleBus)

    statusMagnitudeFrom = unitless(statusMagnitude, default.statusMagnitudeFrom)
    checkStatus(statusMagnitudeFrom)
    statusAngleFrom = unitless(statusAngle, default.statusAngleFrom)
    checkStatus(statusAngleFrom)

    statusMagnitudeTo = unitless(statusMagnitude, default.statusMagnitudeTo)
    checkStatus(statusMagnitudeTo)
    statusAngleTo = unitless(statusAngle, default.statusAngleTo)
    checkStatus(statusAngleTo)

    pmu.number = system.bus.number + 2 * system.branch.number
    pmu.label = Dict{String,Int64}(); sizehint!(pmu.label, pmu.number)

    pmu.layout.index = fill(0, pmu.number)
    pmu.layout.bus = fill(false, pmu.number)
    pmu.layout.from = fill(false, pmu.number)
    pmu.layout.to = fill(false, pmu.number)

    pmu.magnitude.mean = fill(0.0, pmu.number)
    pmu.magnitude.variance = similar(pmu.magnitude.mean)
    pmu.magnitude.status = fill(Int8(0), pmu.number)

    pmu.angle.mean = similar(pmu.magnitude.mean)
    pmu.angle.variance = similar(pmu.magnitude.mean)
    pmu.angle.status = similar(pmu.magnitude.status)

    prefixInv = 1 / system.base.voltage.prefix
    @inbounds for i = 1:system.bus.number
        pmu.label[replace(default.label, r"\?" => string(i))] = i

        pmu.layout.index[i] = i
        pmu.layout.bus[i] = true

        pmu.magnitude.variance[i] = topu(varianceMagnitude, default.varianceMagnitudeBus, prefix.voltageMagnitude, prefixInv / system.base.voltage.value[i])
        pmu.magnitude.mean[i] = analysis.voltage.magnitude[i] + pmu.magnitude.variance[i]^(1/2) * randn(1)[1]
        pmu.magnitude.status[i] = statusMagnitudeBus

        pmu.angle.variance[i] = topu(varianceAngle, default.varianceAngleBus, prefix.voltageAngle, 1.0)
        pmu.angle.mean[i] = analysis.voltage.angle[i] + pmu.angle.variance[i]^(1/2) * randn(1)[1]
        pmu.angle.status[i] = statusAngleBus
    end

    count = 1
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for i = (system.bus.number + 1):2:pmu.number
        pmu.label[replace(default.label, r"\?" => string(i))] = i
        pmu.label[replace(default.label, r"\?" => string(i + 1))] = i + 1

        pmu.layout.index[i] = count
        pmu.layout.index[i + 1] = count
        pmu.layout.from[i] = true
        pmu.layout.to[i + 1] = true
        pmu.magnitude.status[i] = statusMagnitudeFrom
        pmu.magnitude.status[i + 1] = statusMagnitudeTo
        pmu.angle.status[i] = statusAngleFrom
        pmu.angle.status[i + 1] = statusAngleTo

        baseVoltage = system.base.voltage.value[system.branch.layout.from[count]] * system.base.voltage.prefix
        baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
        pmu.magnitude.variance[i] = topu(varianceMagnitude, default.varianceMagnitudeFrom, prefix.currentMagnitude, baseCurrentInv)
        pmu.magnitude.mean[i] = analysis.current.from.magnitude[count] + pmu.magnitude.variance[i]^(1/2) * randn(1)[1]

        pmu.angle.variance[i] = topu(varianceAngle, default.varianceAngleFrom, prefix.currentAngle, 1.0)
        pmu.angle.mean[i] = analysis.current.from.angle[count] + pmu.angle.variance[i]^(1/2) * randn(1)[1]

        baseVoltage = system.base.voltage.value[system.branch.layout.to[count]] * system.base.voltage.prefix
        baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
        pmu.magnitude.variance[i + 1] = topu(varianceMagnitude, default.varianceMagnitudeTo, prefix.currentMagnitude, baseCurrentInv)
        pmu.magnitude.mean[i + 1] = analysis.current.to.magnitude[count] + pmu.magnitude.variance[i + 1]^(1/2) * randn(1)[1]

        pmu.angle.variance[i + 1] = topu(varianceAngle, default.varianceAngleTo, prefix.currentAngle, 1.0)
        pmu.angle.mean[i + 1] = analysis.current.to.angle[count] + pmu.angle.variance[i + 1]^(1/2) * randn(1)[1]

        count += 1
    end

    pmu.layout.label = pmu.number
end

"""
    updatePmu!(system::PowerSystem, device::Measurement, analysis::Analysis; kwargs...)

The function allows for the alteration of parameters for a PMU.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement`
composite type only. However, when including the `Analysis` type, it updates both the
`Measurement` and `Analysis` types. This streamlined process avoids the need to completely
rebuild vectors and matrices when adjusting these parameters.

# Keywords
To update a specific PMU, provide the necessary `kwargs` input arguments in accordance
with the keywords specified in the [`addPmu!`](@ref addPmu!) function, along with their
respective values. Ensure that the `label` keyword matches the `label` of the existing PMU
you want to modify. If any keywords are omitted, their corresponding values will remain
unchanged.

# Updates
The function updates the `pmu` field within the `Measurement` composite type. Furthermore,
it guarantees that any modifications to the parameters are transmitted to the `Analysis`
type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addPmu!`](@ref addPmu!) function.

# Example
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)

addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 1.1, angle = -0.1)
updatePmu!(system, device; label = "PMU 1", magnitude = 1.05, noise = false)
```
"""
function updatePmu!(system::PowerSystem, device::Measurement; label::L,
    magnitude::T = missing, angle::T = missing, varianceMagnitude::T = missing,
    varianceAngle::T = missing, statusMagnitude::T = missing, statusAngle::T = missing,
    noise::Bool = template.pmu.noise)

    pmu = device.pmu

    index = pmu.label[getLabel(pmu, label, "PMU")]
    indexBusBranch = pmu.layout.index[index]

    if pmu.layout.bus[index]
        prefixMagnitude = prefix.voltageMagnitude
        prefixAngle = prefix.voltageAngle
        baseInv = 1 / (system.base.voltage.value[indexBusBranch] * system.base.voltage.prefix)
    else
        if pmu.layout.from[index]
            baseVoltage = system.base.voltage.value[system.branch.layout.from[indexBusBranch]] * system.base.voltage.prefix
        else
            baseVoltage = system.base.voltage.value[system.branch.layout.to[indexBusBranch]] * system.base.voltage.prefix
        end
        prefixMagnitude = prefix.currentMagnitude
        prefixAngle = prefix.currentAngle
        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseInv = baseCurrentInverse(basePowerInv, baseVoltage)
    end

    updateMeter(pmu.magnitude, index, magnitude, varianceMagnitude, statusMagnitude, noise,
        prefixMagnitude, baseInv)

    updateMeter(pmu.angle, index, angle, varianceAngle, statusAngle, noise,
        prefixAngle, 1.0)
end

"""
    @pmu(label, varianceMagnitudeBus, statusMagnitudeBus, varianceAngleBus, statusAngleBus,
        varianceMagnitudeFrom, statusMagnitudeFrom, varianceAngleFrom, statusAngleFrom, 
        ,varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo, noise)

The macro generates a template for a PMU, which can be utilized to define a PMU using the
[`addPmu!`](@ref addPmu!) function.

# Keywords
To establish the PMU template, users have the option to set default values for magnitude
and angle variances, as well as statuses for each component of the phasor. This can be
done for PMUs located at the buses using the `varianceMagnitudeBus`, `varianceAngleBus`,
`statusMagnitudeBus`, and `statusAngleBus` keywords. The same configuration can be applied
at both the "from" bus ends of the branches using the `varianceMagnitudeFrom`,
`varianceAngleFrom`, `statusMagnitudeFrom`, and `statusAngleFrom` keywords. For PMUs 
located at the "to" bus ends of the branches, users can use the `varianceMagnitudeTo`,
`varianceAngleTo`, `statusMagnitudeTo`, and `statusAngleTo` keywords. Additionally, users
can configure the pattern for labels using the `label` keyword and specify the type of
`noise`.

# Units
By default, the units for variances are per-units (pu) and radians (rad). However, users 
have the option to switch to volts (V) and degrees (deg) as the units for PMUs located at 
the buses by using the [@voltage](@ref @voltage) macro, or they can switch to amperes (A) 
and degrees (deg) as the units for PMUs located at the branches by using the
[@current](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@pmu(label = "PMU ?", varianceAngleBus = 1e-6, varianceMagnitudeFrom = 1e-4)
addPmu!(system, device; bus = "Bus 1", magnitude = 1.1, angle = -0.1, noise = false)
addPmu!(system, device; from = "Branch 1", magnitude = 1.1, angle = -0.2, noise = false)
```

Adding PMUs using a custom unit system:
```jldoctest
@voltage(kV, deg, kV)
@current(A, deg)
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132.0)
addBus!(system; label = "Bus 2", base = 132.0)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@pmu(label = "PMU ?", varianceAngleBus = 5.73e-5, varianceMagnitudeFrom = 0.0481)
addPmu!(system, device; bus = "Bus 1", magnitude = 145.2, angle = -5.73, noise = false)
addPmu!(system, device; from = "Branch 1", magnitude = 481.125, angle = -11.46, noise = false)
```
"""
macro pmu(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]

        if hasfield(PmuTemplate, parameter)
            if parameter in [:varianceMagnitudeBus; :varianceAngleBus; :varianceMagnitudeFrom; :varianceAngleFrom; :varianceMagnitudeTo; :varianceAngleTo]
                container::ContainerTemplate = getfield(template.pmu, parameter)
                if parameter == :varianceMagnitudeBus
                    prefixLive = prefix.voltageMagnitude
                elseif parameter in [:varianceMagnitudeFrom; :varianceMagnitudeTo]
                    prefixLive = prefix.currentMagnitude
                elseif parameter == :varianceAngleBus
                    prefixLive = prefix.voltageAngle
                else
                    prefixLive = prefix.currentAngle
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, Float64(eval(kwarg.args[2])))
                    setfield!(container, :pu, true)
                end
            else
                if parameter in [:statusMagnitudeBus; :statusAngleBus; :statusMagnitudeFrom; :statusAngleFrom; :statusMagnitudeTo; :statusAngleTo]
                    setfield!(template.pmu, parameter, Int8(eval(kwarg.args[2])))
                elseif parameter == :noise
                    setfield!(template.pmu, parameter, Bool(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?")
                        setfield!(template.pmu, parameter, label)
                    else
                        throw(ErrorException("The label template lacks the '?' symbol to indicate integer placement."))
                    end
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end