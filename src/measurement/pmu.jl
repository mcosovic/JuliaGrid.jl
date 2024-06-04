"""
    addPmu!(system::PowerSystem, device::Measurement; label, bus, from, to, magnitude,
        varianceMagnitude, statusMagnitude, angle, varianceAngle, statusAngle,
        noise, correlated, polar)

The function adds a new PMU to the `Measurement` type within a given `PowerSystem` type.
The PMU can be added to an already defined bus or branch. When defining the PMU, it
is essential to provide the bus voltage magnitude and angle if the PMU is located at a bus
or the branch current magnitude and angle if the PMU is located at a branch.

# Keywords
The PMU is defined with the following keywords:
* `label`: Unique label for the PMU.
* `bus`: Label of the bus if the PMU is located at the bus.
* `from`: Label of the branch if the PMU is located at the from-bus end.
* `to`: Label of the branch if the PMU is located at the to-bus end.
* `magnitude` (pu or V, A): Bus voltage or branch current magnitude value.
* `varianceMagnitude` (pu or V, A): Magnitude measurement variance.
* `statusMagnitude`: Operating status of the magnitude measurement:
  * `statusMagnitude = 1`: in-service,
  * `statusMagnitude = 0`: out-of-service.
* `angle` (rad or deg): Bus voltage or branch current angle value.
* `varianceAngle` (rad or deg): Angle measurement variance.
* `statusAngle`: Operating status of the angle measurement:
  * `statusAngle = 1`: in-service,
  * `statusAngle = 0`: out-of-service.
* `noise`: Specifies how to generate the measurement means:
  * `noise = true`: adds white Gaussian noises with variances to the `magnitude` and `angle`,
  * `noise = false`: uses the `magnitude` and `angle` values only.
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `varianceMagnitude = 1e-5`,
`statusMagnitude = 1`, `varianceAngle = 1e-5`, `statusAngle = 1`, `noise = false`,
`correlated = false`, and `polar = false`, which apply to PMUs located at the bus, as well
as at both the from-bus and to-bus ends. Users can fine-tune these settings by explicitly
specifying the variance and status for PMUs positioned at the buses, from-bus ends, or
to-bus ends of branches using the [`@pmu`](@ref @pmu) macro.

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
addPmu!(system, device; label = "PMU 2", from = "Branch 1", magnitude = 1.1, angle = 0.1)
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

addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 145.2, angle = -5.7)
addPmu!(system, device; label = "PMU 2", from = "Branch 1", magnitude = 481.1, angle = 5.7)
```
"""
function addPmu!(system::PowerSystem, device::Measurement;
    label::L = missing, bus::L = missing, from::L = missing, to::L = missing,
    magnitude::A, angle::A, varianceMagnitude::A = missing, varianceAngle::A = missing,
    statusMagnitude::A = missing, statusAngle::A = missing, noise::Bool = template.pmu.noise,
    correlated::Bool = template.pmu.correlated, polar::Bool = template.pmu.polar)

    pmu = device.pmu
    default = template.pmu

    location, busFlag, fromFlag, toFlag = checkLocation(pmu, bus, from, to)

    branchFlag = false
    if !busFlag
        labelBranch = getLabel(system.branch, location, "branch")
        index = system.branch.label[labelBranch]
        if system.branch.layout.status[index] == 1
            branchFlag = true
        end
    end

    if busFlag || branchFlag
        pmu.number += 1
        push!(pmu.layout.bus, busFlag)
        push!(pmu.layout.from, fromFlag)
        push!(pmu.layout.to, toFlag)

        if busFlag
            labelBus = getLabel(system.bus, location, "bus")
            index = system.bus.label[labelBus]
            setLabel(pmu, label, default.label, labelBus)

            defaultVarianceMagnitude = default.varianceMagnitudeBus
            defaultVarianceAngle = default.varianceAngleBus
            defaultMagnitudeStatus = default.statusMagnitudeBus
            defaultAngleStatus = default.statusAngleBus

            prefixMagnitude = prefix.voltageMagnitude
            prefixAngle = prefix.voltageAngle
            baseInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
        else
            if fromFlag
                setLabel(pmu, label, default.label, labelBranch; prefix = "From ")
                defaultVarianceMagnitude = default.varianceMagnitudeFrom
                defaultVarianceAngle = default.varianceAngleFrom
                defaultMagnitudeStatus = default.statusMagnitudeFrom
                defaultAngleStatus = default.statusAngleFrom

                baseVoltage = system.base.voltage.value[system.branch.layout.from[index]] * system.base.voltage.prefix
            else
                setLabel(pmu, label, default.label, labelBranch; prefix = "To ")
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
        push!(pmu.layout.correlated, correlated)
        push!(pmu.layout.polar, polar)

        setMeter(pmu.magnitude, magnitude, varianceMagnitude, statusMagnitude, noise,
        defaultVarianceMagnitude, defaultMagnitudeStatus, prefixMagnitude, baseInv)

        setMeter(pmu.angle, angle, varianceAngle, statusAngle, noise, defaultVarianceAngle,
        defaultAngleStatus, prefixAngle, 1.0)
    end
end

"""
    addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceMagnitudeBus, statusMagnitudeBus, varianceAngleBus, statusAngleBus,
        varianceMagnitudeFrom, statusMagnitudeFrom, varianceAngleFrom, statusAngleFrom,
        varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo,
        correlated, polar, noise)

The function incorporates PMUs into the `Measurement` composite type for every bus and
branch within the `PowerSystem` type. These measurements are derived from the exact bus
voltage magnitudes and angles, as well as branch current magnitudes and angles defined in
the `AC` type.

# Keywords
Users have the option to configure the following keywords:
* `varianceMagnitudeBus` (pu or V): Variance of magnitude measurements at buses.
* `statusMagnitudeBus`: Operating status of magnitude measurements at buses:
  * `statusMagnitudeBus = 1`: in-service,
  * `statusMagnitudeBus = 0`: out-of-service.
* `varianceAngleBus` (rad or deg): Variance of angle measurements at buses.
* `statusAngleBus`: Operating status of angle measurements at buses:
  * `statusAngleBus = 1`: in-service,
  * `statusAngleBus = 0`: out-of-service.
* `varianceMagnitudeFrom` (pu or A): Variance of magnitude measurements at the from-bus ends.
* `statusMagnitudeFrom`: Operating status of magnitude measurements at the from-bus ends:
  * `statusMagnitudeFrom = 1`: in-service,
  * `statusMagnitudeFrom = 0`: out-of-service.
* `varianceAngleFrom` (rad or deg): Variance of angle measurements at the from-bus ends.
* `statusAngleFrom`: Operating status of angle measurements at the from-bus ends:
  * `statusAngleFrom = 1`: in-service,
  * `statusAngleFrom = 0`: out-of-service.
* `varianceMagnitudeTo` (pu or A): Variance of magnitude measurements at the to-bus ends.
* `statusMagnitudeTo`: Operating status of magnitude measurements at the to-bus ends:
  * `statusMagnitudeTo = 1`: in-service,
  * `statusMagnitudeTo = 0`: out-of-service.
* `varianceAngleTo` (rad or deg): Variance of angle measurements at the to-bus ends.
* `statusAngleTo`: Operating status of angle measurements at the to-bus ends:
  * `statusAngleTo = 1`: in-service,
  * `statusAngleTo = 0`: out-of-service.
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.
* `noise`: Specifies how to generate the measurement mean:
  * `noise = true`: adds white Gaussian noise with the `variance` to the magnitudes and angles,
  * `noise = false`: uses the exact magnitude and angles values.

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

# Default Settings
Default settings for variance keywords are established at `1e-5`, with all statuses set to
`1`, `polar = false`, `correlated = false`, and `noise = false`. Users can change these
default settings using the [`@pmu`](@ref @pmu) macro.

# Units
The default units for the variance keywords are in per-units (pu) and radians (rad). However,
users have the option to switch to volts (V) and degrees (deg) when the PMU is located at
a bus using the [`@voltage`](@ref @voltage) macro, or amperes (A) and degrees (deg) when
the PMU is located at a branch through the use of the [`@current`](@ref @current) macro.

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

@pmu(label = "PMU ?")
addPmu!(system, device, analysis; varianceMagnitudeBus = 1e-3)
```
"""
function addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceMagnitudeBus::A = missing, varianceAngleBus::A = missing,
    statusMagnitudeBus::A = missing, statusAngleBus::A = missing,
    varianceMagnitudeFrom::A = missing, varianceAngleFrom::A = missing,
    statusMagnitudeFrom::A = missing, statusAngleFrom::A = missing,
    varianceMagnitudeTo::A = missing, varianceAngleTo::A = missing,
    statusMagnitudeTo::A = missing, statusAngleTo::A = missing,
    correlated::Bool = template.pmu.correlated, polar::Bool = template.pmu.polar,
    noise::Bool = template.pmu.noise)

    if isempty(analysis.voltage.magnitude)
        throw(ErrorException("The voltages cannot be found."))
    end
    if isempty(analysis.current.from.magnitude)
        throw(ErrorException("The currents cannot be found."))
    end

    pmu = device.pmu
    default = template.pmu
    pmu.number = 0

    statusMagnitudeBus = unitless(statusMagnitudeBus, default.statusMagnitudeBus)
    checkStatus(statusMagnitudeBus)
    statusAngleBus = unitless(statusAngleBus, default.statusAngleBus)
    checkStatus(statusAngleBus)

    statusMagnitudeFrom = unitless(statusMagnitudeFrom, default.statusMagnitudeFrom)
    checkStatus(statusMagnitudeFrom)
    statusAngleFrom = unitless(statusAngleFrom, default.statusAngleFrom)
    checkStatus(statusAngleFrom)

    statusMagnitudeTo = unitless(statusMagnitudeTo, default.statusMagnitudeTo)
    checkStatus(statusMagnitudeTo)
    statusAngleTo = unitless(statusAngleTo, default.statusAngleTo)
    checkStatus(statusAngleTo)

    pmuNumber = system.bus.number + 2 * system.branch.layout.inservice
    pmu.label = OrderedDict{String,Int64}(); sizehint!(pmu.label, pmuNumber)

    pmu.layout.index = fill(0, pmuNumber)
    pmu.layout.bus = fill(false, pmuNumber)
    pmu.layout.from = fill(false, pmuNumber)
    pmu.layout.to = fill(false, pmuNumber)
    pmu.layout.correlated = fill(correlated, pmuNumber)
    pmu.layout.polar = fill(polar, pmuNumber)

    pmu.magnitude.mean = fill(0.0, pmuNumber)
    pmu.magnitude.variance = similar(pmu.magnitude.mean)
    pmu.magnitude.status = fill(Int8(0), pmuNumber)

    pmu.angle.mean = similar(pmu.magnitude.mean)
    pmu.angle.variance = similar(pmu.magnitude.mean)
    pmu.angle.status = similar(pmu.magnitude.status)

    prefixInv = 1 / system.base.voltage.prefix
    @inbounds for (label, i) in system.bus.label
        pmu.number += 1
        setLabel(pmu, missing, default.label, label)

        pmu.layout.index[i] = i
        pmu.layout.bus[i] = true

        pmu.magnitude.status[i] = statusMagnitudeBus
        pmu.angle.status[i] = statusAngleBus

        pmu.magnitude.variance[i] = topu(varianceMagnitudeBus, default.varianceMagnitudeBus, prefix.voltageMagnitude, prefixInv / system.base.voltage.value[i])
        pmu.angle.variance[i] = topu(varianceAngleBus, default.varianceAngleBus, prefix.voltageAngle, 1.0)

        if noise
            pmu.magnitude.mean[i] = analysis.voltage.magnitude[i] + pmu.magnitude.variance[i]^(1/2) * randn(1)[1]
            pmu.angle.mean[i] = analysis.voltage.angle[i] + pmu.angle.variance[i]^(1/2) * randn(1)[1]
        else
            pmu.magnitude.mean[i] = analysis.voltage.magnitude[i]
            pmu.angle.mean[i] = analysis.voltage.angle[i]
        end
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for (label, i) in system.branch.label
        if system.branch.layout.status[i] == 1
            pmu.number += 1
            setLabel(pmu, missing, default.label, label; prefix = "From ")

            pmu.layout.index[pmu.number] = i
            pmu.layout.from[pmu.number] = true

            pmu.layout.index[pmu.number + 1] = i
            pmu.layout.to[pmu.number + 1] = true

            pmu.magnitude.status[pmu.number] = statusMagnitudeFrom
            pmu.angle.status[pmu.number] = statusAngleFrom

            pmu.magnitude.status[pmu.number + 1] = statusMagnitudeTo
            pmu.angle.status[pmu.number + 1] = statusAngleTo

            baseCurrentFromInv = baseCurrentInverse(basePowerInv, system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix)
            pmu.magnitude.variance[pmu.number] = topu(varianceMagnitudeFrom, default.varianceMagnitudeFrom, prefix.currentMagnitude, baseCurrentFromInv)
            pmu.angle.variance[pmu.number] = topu(varianceAngleFrom, default.varianceAngleFrom, prefix.currentAngle, 1.0)

            baseCurrentToInv = baseCurrentInverse(basePowerInv, system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix)
            pmu.magnitude.variance[pmu.number + 1] = topu(varianceMagnitudeTo, default.varianceMagnitudeTo, prefix.currentMagnitude, baseCurrentToInv)
            pmu.angle.variance[pmu.number + 1] = topu(varianceAngleTo, default.varianceAngleTo, prefix.currentAngle, 1.0)

            if noise
                pmu.magnitude.mean[pmu.number] = analysis.current.from.magnitude[i] + pmu.magnitude.variance[pmu.number]^(1/2) * randn(1)[1]
                pmu.angle.mean[pmu.number] = analysis.current.from.angle[i] + pmu.angle.variance[pmu.number]^(1/2) * randn(1)[1]

                pmu.magnitude.mean[pmu.number + 1] = analysis.current.to.magnitude[i] + pmu.magnitude.variance[pmu.number + 1]^(1/2) * randn(1)[1]
                pmu.angle.mean[pmu.number + 1] = analysis.current.to.angle[i] + pmu.angle.variance[pmu.number + 1]^(1/2) * randn(1)[1]

            else
                pmu.magnitude.mean[pmu.number] = analysis.current.from.magnitude[i]
                pmu.angle.mean[pmu.number] = analysis.current.from.angle[i]

                pmu.magnitude.mean[pmu.number + 1] = analysis.current.to.magnitude[i]
                pmu.angle.mean[pmu.number + 1] = analysis.current.to.angle[i]
            end

            pmu.number += 1
            setLabel(pmu, missing, default.label, label; prefix = "To ")
        end
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
updatePmu!(system, device; label = "PMU 1", magnitude = 1.05)
```
"""
function updatePmu!(system::PowerSystem, device::Measurement; label::L,
    magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing)

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

    if isset(correlated)
        pmu.layout.correlated[index] = correlated
    end
    if isset(polar)
        pmu.layout.polar[index] = polar
    end

    updateMeter(pmu.magnitude, index, magnitude, varianceMagnitude, statusMagnitude, noise,
    prefixMagnitude, baseInv)

    updateMeter(pmu.angle, index, angle, varianceAngle, statusAngle, noise, prefixAngle, 1.0)
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation{LinearWLS{T}};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing) where T <: Union{Normal, Orthogonal}

    pmu = device.pmu
    method = analysis.method

    indexPmu = pmu.label[getLabel(pmu, label, "PMU")]
    oldStatus = pmu.angle.status[indexPmu]
    oldVariance = pmu.angle.variance[indexPmu]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    if pmu.layout.bus[indexPmu]
        newStatus = pmu.angle.status[indexPmu]
        indexBus = pmu.layout.index[indexPmu]
        index = indexPmu + device.wattmeter.number

        if oldStatus != newStatus || oldVariance != pmu.angle.variance[indexPmu]
            method.run = true
        end

        if isset(statusAngle) || isset(angle)
            if isset(statusAngle)
                method.coefficient[index, indexBus] = newStatus
            end
            method.mean[index] = newStatus * (pmu.angle.mean[indexPmu] - system.bus.voltage.angle[system.bus.layout.slack])
        end
        if isset(varianceAngle)
            method.precision.nzval[index] = 1 / pmu.angle.variance[indexPmu]
        end
    end
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::DCStateEstimation{LAV};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing)

    pmu = device.pmu
    method = analysis.method

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    indexPmu = pmu.label[getLabel(pmu, label, "PMU")]
    index = indexPmu + device.wattmeter.number
    if pmu.layout.bus[indexPmu] && isset(statusAngle)
        if pmu.angle.status[indexPmu] == 1
            indexBus = pmu.layout.index[indexPmu]
            addDeviceLAV(method, index)

            remove!(method.jump, method.residual, index)
            method.residual[index] = @constraint(method.jump, method.statex[indexBus] - method.statey[indexBus] + method.residualy[index] - method.residualx[index] == 0.0)
        else
            removeDeviceLAV(method, index)
        end
    end

    if pmu.layout.bus[indexPmu] && pmu.angle.status[indexPmu] == 1 && (isset(statusAngle) || isset(angle))
        JuMP.set_normalized_rhs(method.residual[index], pmu.angle.mean[indexPmu] - system.bus.voltage.angle[system.bus.layout.slack])
    end
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::PMUStateEstimation{LinearWLS{T}};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    method = analysis.method
    index = pmu.label[getLabel(pmu, label, "PMU")]
    statusOld = pmu.magnitude.status[index] & pmu.angle.status[index]
    correlatedOld = pmu.layout.correlated[index]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    statusNew = pmu.magnitude.status[index] & pmu.angle.status[index]
    mean = isset(magnitude) || isset(angle)
    variance = isset(varianceMagnitude) || isset(varianceAngle)
    cosAngle = cos(pmu.angle.mean[index])
    sinAngle = sin(pmu.angle.mean[index])
    rowIndexRe = 2 * index - 1

    if mean || variance || (pmu.layout.correlated[index] != correlatedOld)
        varianceRe = pmu.magnitude.variance[index] * cosAngle^2 + pmu.angle.variance[index] * (pmu.magnitude.mean[index] * sinAngle)^2
        varianceIm = pmu.magnitude.variance[index] * sinAngle^2 + pmu.angle.variance[index] * (pmu.magnitude.mean[index] * cosAngle)^2
        if pmu.layout.correlated[index]
            L1inv = 1 / sqrt(varianceRe)
            L2 = (sinAngle * cosAngle * (pmu.magnitude.variance[index] - pmu.angle.variance[index] * pmu.magnitude.mean[index]^2)) * L1inv
            L3inv2 = 1 / (varianceIm - L2^2)

            method.precision[rowIndexRe, rowIndexRe + 1] = (- L2 * L1inv) * L3inv2
            method.precision[rowIndexRe + 1, rowIndexRe] = method.precision[rowIndexRe, rowIndexRe + 1]
            method.precision[rowIndexRe, rowIndexRe] = (L1inv - L2 * method.precision[rowIndexRe, rowIndexRe + 1]) * L1inv
            method.precision[rowIndexRe + 1, rowIndexRe + 1] = L3inv2
        else
            method.precision[rowIndexRe, rowIndexRe] = 1 / varianceRe
            method.precision[rowIndexRe + 1, rowIndexRe + 1] = 1 / varianceIm
            if correlatedOld
                method.precision[rowIndexRe, rowIndexRe + 1] = 0.0
                method.precision[rowIndexRe + 1, rowIndexRe] = 0.0
            end
        end
    end

    if statusNew != statusOld || mean
        if statusNew == 1 && (pmu.layout.bus[index] || branch.layout.status[pmu.layout.index[index]] == 1)
            method.mean[rowIndexRe] = pmu.magnitude.mean[index] * cosAngle
            method.mean[rowIndexRe + 1] = pmu.magnitude.mean[index] * sinAngle
        else
            method.mean[rowIndexRe] = 0.0
            method.mean[rowIndexRe + 1] = 0.0
        end
    end

    if statusNew != statusOld
        if pmu.layout.bus[index]
            if statusNew == 1
                method.coefficient[rowIndexRe, pmu.layout.index[index]] = 1.0
                method.coefficient[rowIndexRe + 1, pmu.layout.index[index] + bus.number] = 1.0
            else
                method.coefficient[rowIndexRe, pmu.layout.index[index]] = 0.0
                method.coefficient[rowIndexRe + 1, pmu.layout.index[index] + bus.number] = 0.0
            end
        else
            k = pmu.layout.index[index]
            from = branch.layout.from[k]
            to = branch.layout.to[k]
            if statusNew == 1 && branch.layout.status[k] == 1
                gij = real(ac.admittance[k])
                bij = imag(ac.admittance[k])
                cosShift = cos(branch.parameter.shiftAngle[k])
                sinShift = sin(branch.parameter.shiftAngle[k])
                turnsRatioInv = 1 / branch.parameter.turnsRatio[k]

                if pmu.layout.from[index]
                    method.coefficient[rowIndexRe, from] = turnsRatioInv^2 * (gij + 0.5 * branch.parameter.conductance[k])
                    method.coefficient[rowIndexRe + 1, from + bus.number] = method.coefficient[rowIndexRe, from]

                    method.coefficient[rowIndexRe, to] = -turnsRatioInv * (gij * cosShift - bij * sinShift)
                    method.coefficient[rowIndexRe + 1, to + bus.number] =  method.coefficient[rowIndexRe, to]

                    method.coefficient[rowIndexRe, from + bus.number] = -turnsRatioInv^2 * (bij + 0.5 * branch.parameter.susceptance[k])
                    method.coefficient[rowIndexRe + 1, from] = -method.coefficient[rowIndexRe, from + bus.number]

                    method.coefficient[rowIndexRe, to + bus.number] = turnsRatioInv * (bij * cosShift + gij * sinShift)
                    method.coefficient[rowIndexRe + 1, to] = -method.coefficient[rowIndexRe, to + bus.number]
                else
                    method.coefficient[rowIndexRe, from] = -turnsRatioInv * (gij * cosShift + bij * sinShift)
                    method.coefficient[rowIndexRe + 1, from + bus.number] = method.coefficient[rowIndexRe, from]

                    method.coefficient[rowIndexRe, to] = gij + 0.5 * branch.parameter.conductance[k]
                    method.coefficient[rowIndexRe + 1, to + bus.number] =  method.coefficient[rowIndexRe, to]

                    method.coefficient[rowIndexRe, from + bus.number] = turnsRatioInv * (bij * cosShift - gij * sinShift)
                    method.coefficient[rowIndexRe + 1, from] = -method.coefficient[rowIndexRe, from + bus.number]

                    method.coefficient[rowIndexRe, to + bus.number] = -bij - 0.5 * branch.parameter.susceptance[k]
                    method.coefficient[rowIndexRe + 1, to] = -method.coefficient[rowIndexRe, to + bus.number]
                end
            else
                method.coefficient[rowIndexRe, from] = 0.0
                method.coefficient[rowIndexRe + 1, from + bus.number] = 0.0
                method.coefficient[rowIndexRe, to] = 0.0
                method.coefficient[rowIndexRe + 1, to + bus.number] = 0.0
                method.coefficient[rowIndexRe, from + bus.number] = 0.0
                method.coefficient[rowIndexRe + 1, from] = 0.0
                method.coefficient[rowIndexRe, to + bus.number] = 0.0
                method.coefficient[rowIndexRe + 1, to] = 0.0
            end
        end
    end
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::PMUStateEstimation{LAV};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    method = analysis.method
    index = pmu.label[getLabel(pmu, label, "PMU")]
    statusOld = pmu.magnitude.status[index] & pmu.angle.status[index]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    statusNew = pmu.magnitude.status[index] & pmu.angle.status[index]
    mean = isset(magnitude) || isset(angle)
    cosAngle = cos(pmu.angle.mean[index])
    sinAngle = sin(pmu.angle.mean[index])
    rowIndexRe = 2 * index - 1

    if statusOld == 0 && statusNew == 1
        if pmu.layout.bus[index]
            addDeviceLAV(method, rowIndexRe)
            addDeviceLAV(method, rowIndexRe + 1)

            indexBus = pmu.layout.index[index]
            method.residual[rowIndexRe] = @constraint(method.jump, method.statex[indexBus] - method.statey[indexBus] + method.residualx[rowIndexRe] - method.residualy[rowIndexRe] == 0.0)
            method.residual[rowIndexRe + 1] = @constraint(method.jump, method.statex[indexBus + bus.number] - method.statey[indexBus + bus.number] + method.residualx[rowIndexRe + 1] - method.residualy[rowIndexRe + 1] == 0.0)
        else
            k = pmu.layout.index[index]
            if branch.layout.status[k] == 1
                from = branch.layout.from[k]
                to = branch.layout.to[k]

                addDeviceLAV(method, rowIndexRe)
                addDeviceLAV(method, rowIndexRe + 1)

                gij = real(ac.admittance[k])
                bij = imag(ac.admittance[k])
                cosShift = cos(branch.parameter.shiftAngle[k])
                sinShift = sin(branch.parameter.shiftAngle[k])
                turnsRatioInv = 1 / branch.parameter.turnsRatio[k]

                Vrei = method.statex[from] - method.statey[from]
                Vimi = method.statex[from + bus.number] - method.statey[from + bus.number]
                Vrej = method.statex[to] - method.statey[to]
                Vimj = method.statex[to + bus.number] - method.statey[to + bus.number]

                cosAngle = cos(pmu.angle.mean[index])
                sinAngle = sin(pmu.angle.mean[index])

                if pmu.layout.from[k]
                    a1 = turnsRatioInv^2 * gij
                    a2 = -turnsRatioInv^2 * (bij + 0.5 * branch.parameter.susceptance[k])
                    a3 = -turnsRatioInv * (gij * cosShift - bij * sinShift)
                    a4 = turnsRatioInv * (bij * cosShift + gij * sinShift)

                    method.residual[rowIndexRe] = @constraint(method.jump, a1 * Vrei + a2 * Vimi + a3 * Vrej + a4 * Vimj + method.residualx[rowIndexRe] - method.residualy[rowIndexRe] - pmu.magnitude.mean[index] * cosAngle == 0.0)
                    method.residual[rowIndexRe + 1] = @constraint(method.jump, -a2 * Vrei + a1 * Vimi - a4 * Vrej + a3 * Vimj + method.residualx[rowIndexRe + 1] - method.residualy[rowIndexRe + 1] - pmu.magnitude.mean[index] * sinAngle == 0.0)
                else
                    a1 = -turnsRatioInv * (gij * cosShift + bij * sinShift)
                    a2 = turnsRatioInv * (bij * cosShift - gij * sinShift)
                    a3 = gij
                    a4 = -bij - 0.5 * branch.parameter.susceptance[k]

                    method.residual[rowIndexRe] = @constraint(method.jump, a1 * Vrei + a2 * Vimi + a3 * Vrej + a4 * Vimj + method.residualx[rowIndexRe] - method.residualy[rowIndexRe] - pmu.magnitude.mean[index] * cosAngle == 0.0)
                    method.residual[rowIndexRe + 1] = @constraint(method.jump, -a2 * Vrei + a1 * Vimi - a4 * Vrej + a3 * Vimj + method.residualx[rowIndexRe + 1] - method.residualy[rowIndexRe + 1] - pmu.magnitude.mean[index] * sinAngle == 0.0)
                end
            end
        end
    end

    if statusOld == 1 && statusNew == 0
        removeDeviceLAV(method, rowIndexRe)
        removeDeviceLAV(method, rowIndexRe + 1)
    end

    if statusNew == 1 && mean
        JuMP.set_normalized_rhs(method.residual[rowIndexRe], pmu.magnitude.mean[index] * cosAngle)
        JuMP.set_normalized_rhs(method.residual[rowIndexRe + 1], pmu.magnitude.mean[index] * sinAngle)
    end
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{NonlinearWLS{T}};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    pmu = device.pmu
    se = analysis.method

    indexPmu = pmu.label[getLabel(pmu, label, "PMU")]
    indexBusBranch = pmu.layout.index[indexPmu]

    polarOld = pmu.layout.polar[indexPmu]
    correlatedOld = pmu.layout.correlated[indexPmu]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    idx = device.voltmeter.number + device.wattmeter.number + device.varmeter.number + device.ammeter.number + (2 * indexPmu - 1)

    if pmu.layout.polar[indexPmu]
        if pmu.magnitude.status[indexPmu] == 1
            if pmu.layout.bus[indexPmu]
                se.jacobian[idx, bus.number + indexBusBranch] = 1.0
                se.type[idx] = 10
            elseif pmu.layout.from[indexPmu]
                se.type[idx] = 8
            else
                se.type[idx] = 9
            end
            se.mean[idx] = pmu.magnitude.mean[indexPmu]
        else
            if pmu.layout.bus[indexPmu]
                se.jacobian[idx, bus.number + indexBusBranch] = 0.0
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

        if pmu.angle.status[indexPmu] == 1
            if pmu.layout.bus[indexPmu]
                se.jacobian[idx + 1, indexBusBranch] = 1.0
                se.type[idx + 1] = 11
            elseif pmu.layout.from[indexPmu]
                se.type[idx + 1] = 12
            else
                se.type[idx + 1] = 13
            end
            se.mean[idx + 1] = pmu.angle.mean[indexPmu]
        else
            if pmu.layout.bus[indexPmu]
                se.jacobian[idx + 1, indexBusBranch] = 0.0
            else
                se.jacobian[idx + 1, branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, bus.number + branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, branch.layout.to[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, bus.number + branch.layout.to[indexBusBranch]] = 0.0
            end
            se.mean[idx + 1] = 0.0
            se.residual[idx + 1] = 0.0
            se.type[idx + 1] = 0
        end
    else
        if pmu.magnitude.status[indexPmu] == 1 && pmu.angle.status[indexPmu] == 1
            se.mean[idx] = pmu.magnitude.mean[indexPmu] * cos(pmu.angle.mean[indexPmu])
            se.mean[idx + 1] = pmu.magnitude.mean[indexPmu] * sin(pmu.angle.mean[indexPmu])
            if pmu.layout.bus[indexPmu]
                se.type[idx] = 14
                se.type[idx + 1] = 15
            elseif pmu.layout.from[indexPmu]
                se.type[idx] = 16
                se.type[idx + 1] = 18
            else
                se.type[idx] = 17
                se.type[idx + 1] = 19
            end
        else
            if pmu.layout.bus[indexPmu]
                se.jacobian[idx, indexBusBranch] = 0.0
                se.jacobian[idx, bus.number + indexBusBranch] = 0.0

                se.jacobian[idx + 1, indexBusBranch] = 0.0
                se.jacobian[idx + 1, bus.number + indexBusBranch] = 0.0
            else
                se.jacobian[idx, branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx, bus.number + branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx, branch.layout.to[indexBusBranch]] = 0.0
                se.jacobian[idx, bus.number + branch.layout.to[indexBusBranch]] = 0.0

                se.jacobian[idx + 1, branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, bus.number + branch.layout.from[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, branch.layout.to[indexBusBranch]] = 0.0
                se.jacobian[idx + 1, bus.number + branch.layout.to[indexBusBranch]] = 0.0
            end
            se.mean[idx] = 0.0
            se.residual[idx] = 0.0
            se.type[idx] = 0

            se.mean[idx + 1] = 0.0
            se.residual[idx + 1] = 0.0
            se.type[idx + 1] = 0
        end
    end

    if pmu.layout.polar[indexPmu]
        se.precision[idx, idx] = 1 / pmu.magnitude.variance[indexPmu]
        se.precision[idx + 1, idx + 1] = 1 / pmu.angle.variance[indexPmu]

        if correlatedOld
            se.precision[idx, idx + 1] = 0.0
            se.precision[idx + 1, idx] = 0.0
        end
    else
        cosAngle = cos(pmu.angle.mean[indexPmu])
        sinAngle = sin(pmu.angle.mean[indexPmu])

        varianceRe = pmu.magnitude.variance[indexPmu] * cosAngle^2 + pmu.angle.variance[indexPmu] * (pmu.magnitude.mean[indexPmu] * sinAngle)^2
        varianceIm = pmu.magnitude.variance[indexPmu] * sinAngle^2 + pmu.angle.variance[indexPmu] * (pmu.magnitude.mean[indexPmu] * cosAngle)^2
        if pmu.layout.correlated[indexPmu]
            covariance = sinAngle * cosAngle * (pmu.magnitude.variance[indexPmu] - pmu.angle.variance[indexPmu] * pmu.magnitude.mean[indexPmu]^2)

            L1inv = 1 / sqrt(varianceRe)
            L2 = covariance * L1inv
            L3inv2 = 1 / (varianceIm - L2^2)

            se.precision[idx, idx + 1] = (- L2 * L1inv) * L3inv2
            se.precision[idx + 1, idx] = se.precision[idx, idx + 1]

            se.precision[idx, idx] = (L1inv - L2 * se.precision[idx, idx + 1]) * L1inv
            se.precision[idx + 1, idx + 1] = L3inv2
        else
            se.precision[idx, idx] = 1 / varianceRe
            se.precision[idx + 1, idx + 1] = 1 / varianceIm
            se.precision[idx, idx + 1] = 0.0
            se.precision[idx + 1, idx] = 0.0
        end
    end
end

function updatePmu!(system::PowerSystem, device::Measurement, analysis::ACStateEstimation{LAV};
    label::L, magnitude::A = missing, angle::A = missing, varianceMagnitude::A = missing,
    varianceAngle::A = missing, statusMagnitude::A = missing, statusAngle::A = missing,
    noise::Bool = template.pmu.noise, correlated::B = missing, polar::B = missing)

    bus = system.bus
    pmu = device.pmu
    se = analysis.method

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle,
    statusMagnitude, statusAngle, noise, correlated, polar)

    indexPmu = pmu.label[getLabel(pmu, label, "PMU")]
    indexBusBranch = pmu.layout.index[indexPmu]
    idx = device.voltmeter.number + device.wattmeter.number + device.varmeter.number + device.ammeter.number + (2 * indexPmu - 1)

    if pmu.layout.polar[indexPmu]
        if pmu.layout.bus[indexPmu]
            if pmu.magnitude.status[indexPmu] == 1
                addDeviceLAV(se, idx)

                remove!(se.jump, se.residual, idx)
                se.residual[idx] = @constraint(se.jump, se.statex[indexBusBranch + bus.number] - se.statey[indexBusBranch + bus.number] + se.residualx[idx] - se.residualy[idx] - pmu.magnitude.mean[indexPmu] == 0.0)
            else
                removeDeviceLAV(se, idx)
            end

            if pmu.angle.status[indexPmu] == 1
                addDeviceLAV(se, idx + 1)

                remove!(se.jump, se.residual, idx + 1)
                se.residual[idx + 1] = @constraint(se.jump, se.statex[indexBusBranch] - se.statey[indexBusBranch] + se.residualx[idx + 1] - se.residualy[idx + 1] - pmu.angle.mean[indexPmu] == 0.0)
            else
                removeDeviceLAV(se, idx + 1)
            end
        else
            if pmu.magnitude.status[indexPmu] == 1
                addDeviceLAV(se, idx)

                remove!(se.jump, se.residual, idx)
                addPmuCurrentMagnitudeResidual!(system, pmu, se, indexBusBranch, idx, indexPmu)
            else
                removeDeviceLAV(se, idx)
            end

            if pmu.angle.status[indexPmu] == 1
                addDeviceLAV(se, idx + 1)

                remove!(se.jump, se.residual, idx + 1)
                addPmuCurrentAngleResidual!(system, pmu, se, indexBusBranch, idx, indexPmu)
            else
                removeDeviceLAV(se, idx + 1)
            end
        end
    else
        if pmu.magnitude.status[indexPmu] == 1 && pmu.angle.status[indexPmu] == 1
            addDeviceLAV(se, idx)
            addDeviceLAV(se, idx + 1)

            remove!(se.jump, se.residual, idx)
            remove!(se.jump, se.residual, idx + 1)
            addPmuCartesianResidual!(system, pmu, se, indexBusBranch, idx, indexPmu)
        else
            removeDeviceLAV(se, idx)
            removeDeviceLAV(se, idx + 1)
        end
    end
end

"""
    @pmu(label, varianceMagnitudeBus, statusMagnitudeBus, varianceAngleBus, statusAngleBus,
        varianceMagnitudeFrom, statusMagnitudeFrom, varianceAngleFrom, statusAngleFrom,
        varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo, noise,
        correlated, polar)

The macro generates a template for a PMU, which can be utilized to define a PMU using the
[`addPmu!`](@ref addPmu!) function.

# Keywords
To establish the PMU template, users have the option to set default values for magnitude
and angle variances, as well as statuses for each component of the phasor. This can be
done for PMUs located at the buses using the `varianceMagnitudeBus`, `varianceAngleBus`,
`statusMagnitudeBus`, and `statusAngleBus` keywords.

The same configuration can be applied at both the from-bus ends of the branches using the
`varianceMagnitudeFrom`, `varianceAngleFrom`, `statusMagnitudeFrom`, and `statusAngleFrom`
keywords.

For PMUs located at the to-bus ends of the branches, users can use the `varianceMagnitudeTo`,
`varianceAngleTo`, `statusMagnitudeTo`, and `statusAngleTo` keywords.

Additionally, users can configure the pattern for labels using the `label` keyword, specify
the type of `noise`, and indicate the `correlated` and `polar` system utilized for
managing phasors during state estimation.

# Units
By default, the units for variances are per-units (pu) and radians (rad). However, users
have the option to switch to volts (V) and degrees (deg) as the units for PMUs located at
the buses by using the [`@voltage`](@ref @voltage) macro, or they can switch to amperes (A)
and degrees (deg) as the units for PMUs located at the branches by using the
[`@current`](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

@pmu(label = "PMU ?", varianceAngleBus = 1e-6, varianceMagnitudeFrom = 1e-4)
addPmu!(system, device; bus = "Bus 1", magnitude = 1.1, angle = -0.1)
addPmu!(system, device; from = "Branch 1", magnitude = 1.1, angle = -0.2)
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
addPmu!(system, device; bus = "Bus 1", magnitude = 145.2, angle = -5.73)
addPmu!(system, device; from = "Branch 1", magnitude = 481.125, angle = -11.46)
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
                elseif parameter == :correlated
                    setfield!(template.pmu, parameter, Bool(eval(kwarg.args[2])))
                elseif parameter == :polar
                    setfield!(template.pmu, parameter, Bool(eval(kwarg.args[2])))
                elseif parameter == :label
                    label = string(kwarg.args[2])
                    if contains(label, "?") || contains(label, "!")
                        setfield!(template.pmu, parameter, label)
                    else
                        throw(ErrorException("The label template is missing the '?' or '!' symbols."))
                    end
                end
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end