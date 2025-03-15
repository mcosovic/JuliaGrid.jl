"""
    addPmu!(system::PowerSystem, device::Measurement;
        label, bus, from, to,
        magnitude, varianceMagnitude, angle, varianceAngle,
        noise, correlated, polar, status)

The function adds a PMU to the `Measurement` type within a given `PowerSystem` type. The
PMU can be added to an already defined bus or branch. When defining the PMU, it is essential
to provide the bus voltage magnitude and angle if the PMU is located at a bus or the branch
current magnitude and angle if the PMU is located at a branch.

# Keywords
The PMU is defined with the following keywords:
* `label`: Unique label for the PMU.
* `bus`: Label of the bus if the PMU is located at the bus.
* `from`: Label of the branch if the PMU is located at the from-bus end.
* `to`: Label of the branch if the PMU is located at the to-bus end.
* `magnitude` (pu or V, A): Bus voltage or branch current magnitude value.
* `varianceMagnitude` (pu or V, A): Magnitude measurement variance.
* `angle` (rad or deg): Bus voltage or branch current angle value.
* `varianceAngle` (rad or deg): Angle measurement variance.
* `noise`: Specifies how to generate the measurement means:
  * `noise = true`: adds white Gaussian noises with variances to the `magnitude` and `angle`,
  * `noise = false`: uses the `magnitude` and `angle` values only.
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.
* `status`: Operating status of the phasor measurement:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

Note that all voltage values are referenced to line-to-neutral voltages.

# Updates
The function updates the `pmu` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `varianceMagnitude = 1e-8`,
`varianceAngle = 1e-8`, `status = 1`, `noise = false`, `correlated = false`, and
`polar = false`, which apply to PMUs located at the bus, as well as at both the from-bus
and to-bus ends. Users can fine-tune these settings by explicitly specifying the variance
and status for PMUs positioned at the buses, from-bus ends, or to-bus ends of branches
using the [`@pmu`](@ref @pmu) macro.

# Units
The default units for the `magnitude`, `varianceMagnitude`, and `angle`, `varianceAngle`
keywords are per-units and radians. However, users have the option to switch to volts and
degrees when the PMU is located at a bus using the [`@voltage`](@ref @voltage) macro, or
amperes and degrees when the PMU is located at a branch through the use of the
[`@current`](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
system = powerSystem()
device = measurement()

addBus!(system; label = "Bus 1", base = 131.8e3)
addBus!(system; label = "Bus 2", base = 131.8e3)
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

addBus!(system; label = "Bus 1", base = 131.8)
addBus!(system; label = "Bus 2", base = 131.8)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(system, device; label = "PMU 1", bus = "Bus 1", magnitude = 145, angle = -5.7)
addPmu!(system, device; label = "PMU 2", from = "Branch 1", magnitude = 481, angle = 5.7)
```
"""
function addPmu!(
    system::PowerSystem,
    device::Measurement;
    label::IntStrMiss = missing,
    bus::IntStrMiss = missing,
    from::IntStrMiss = missing,
    to::IntStrMiss = missing,
    magnitude::FltIntMiss,
    angle::FltIntMiss,
    varianceMagnitude::FltIntMiss = missing,
    varianceAngle::FltIntMiss = missing,
    status::FltIntMiss = missing,
    noise::Bool = template.pmu.noise,
    correlated::Bool = template.pmu.correlated,
    polar::Bool = template.pmu.polar
)
    baseVoltg = system.base.voltage
    branch = system.branch
    pmu = device.pmu
    def = template.pmu

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
        pmu.number += 1
        push!(pmu.layout.bus, busFlag)
        push!(pmu.layout.from, fromFlag)
        push!(pmu.layout.to, toFlag)

        if busFlag
            lblBus = getLabel(system.bus, location, "bus")
            idx = system.bus.label[lblBus]

            setLabel(pmu, label, def.label, lblBus)

            defVarianceMagnitude = def.varianceMagnitudeBus
            defVarianceAngle = def.varianceAngleBus
            defStatus = def.statusBus

            pfxMagnitude = pfx.voltageMagnitude
            pfxAngle = pfx.voltageAngle

            baseInv = sqrt(3) / (baseVoltg.value[idx] * baseVoltg.prefix)
        else
            if fromFlag
                setLabel(pmu, label, def.label, lblBrch; prefix = "From ")

                defVarianceMagnitude = def.varianceMagnitudeFrom
                defVarianceAngle = def.varianceAngleFrom
                defStatus = def.statusFrom

                baseVoltage = baseVoltg.value[branch.layout.from[idx]] * baseVoltg.prefix
            else
                setLabel(pmu, label, def.label, lblBrch; prefix = "To ")

                defVarianceMagnitude = def.varianceMagnitudeTo
                defVarianceAngle = def.varianceAngleTo
                defStatus = def.statusTo

                baseVoltage = baseVoltg.value[branch.layout.to[idx]] * baseVoltg.prefix
            end
            pfxMagnitude = pfx.currentMagnitude
            pfxAngle = pfx.currentAngle

            basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
            baseInv = baseCurrentInv(basePowerInv, baseVoltage)
        end
        push!(pmu.layout.index, idx)
        push!(pmu.layout.correlated, correlated)
        push!(pmu.layout.polar, polar)

        setMeter(
            pmu.magnitude, magnitude, varianceMagnitude, status, noise,
            defVarianceMagnitude, defStatus, pfxMagnitude, baseInv
        )
        setMeter(
            pmu.angle, angle, varianceAngle, status, noise,
            defVarianceAngle, defStatus, pfxAngle, 1.0
        )
    end
end

"""
    addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
        varianceMagnitudeBus, varianceAngleBus, statusBus,
        varianceMagnitudeFrom, varianceAngleFrom, statusFrom,
        varianceMagnitudeTo, varianceAngleTo, statusTo,
        noise, correlated, polar)

The function incorporates PMUs into the `Measurement` type for every bus and branch within
the `PowerSystem` type. These measurements are derived from the exact bus voltage magnitudes
and angles, as well as branch current magnitudes and angles defined in the `AC` type.

# Keywords
PMUs at the buses can be configured using:
* `varianceMagnitudeBus` (pu or V): Variance of bus voltage magnitude measurements.
* `varianceAngleBus` (rad or deg): Variance of bus voltage angle measurements.
* `statuseBus`: Operating status:
  * `statusBus = 1`: in-service,
  * `statusBus = 0`: out-of-service,
  * `statusBus = -1`: not included in the `Measurement` type.
PMUs at the from-bus ends of the branches can be configured using:
* `varianceMagnitudeFrom` (pu or A): Variance of current magnitude measurements.
* `varianceAngleFrom` (rad or deg): Variance of current angle measurements.
* `statusFrom`: Operating status:
  * `statusFrom = 1`: in-service,
  * `statusFrom = 0`: out-of-service,
  * `statusFrom = -1`: not included in the `Measurement` type.
PMUs at the to-bus ends of the branches can be configured using:
* `varianceMagnitudeTo` (pu or A): Variance of current magnitude measurements.
* `varianceAngleTo` (rad or deg): Variance of current angle measurements.
* `statusTo`: Operating status:
  * `statusTo = 1`: in-service,
  * `statusTo = 0`: out-of-service,
  * `statusTo = -1`: not included in the `Measurement` type.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the phasor values using defined variances,
  * `noise = false`: uses the exact phasor values without adding noise.
Settings for handling phasor measurements include:
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.

# Updates
The function updates the `pmu` field of the `Measurement` type.

# Default Settings
Default settings for variance keywords are established at `1e-8`, with all statuses set to
`1`, `polar = false`, `correlated = false`, and `noise = false`. Users can change these
default settings using the [`@pmu`](@ref @pmu) macro.

# Units
The default units for the variance keywords are in per-units and radians. However, users
have the option to switch to volts and degrees when the PMU is located at a bus using the
[`@voltage`](@ref @voltage) macro, or amperes and degrees when the PMU is located at a
branch through the use of the [`@current`](@ref @current) macro.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement()

acModel!(system)
analysis = newtonRaphson(system)
powerFlow!(system, analysis; current = true)

@pmu(label = "PMU ?")
addPmu!(system, device, analysis; varianceMagnitudeBus = 1e-3)
```
"""
function addPmu!(
    system::PowerSystem,
    device::Measurement, analysis::AC;
    varianceMagnitudeBus::FltIntMiss = missing,
    varianceAngleBus::FltIntMiss = missing,
    statusBus::FltIntMiss = missing,
    varianceMagnitudeFrom::FltIntMiss = missing,
    varianceAngleFrom::FltIntMiss = missing,
    statusFrom::FltIntMiss = missing,
    varianceMagnitudeTo::FltIntMiss = missing,
    varianceAngleTo::FltIntMiss = missing,
    statusTo::FltIntMiss = missing,
    correlated::Bool = template.pmu.correlated,
    polar::Bool = template.pmu.polar,
    noise::Bool = template.pmu.noise
)
    errorVoltage(analysis.voltage.magnitude)
    errorCurrent(analysis.current.from.magnitude)

    baseVoltg = system.base.voltage
    pmu = device.pmu
    current = analysis.current
    def = template.pmu

    pmu.number = 0

    statusBus = givenOrDefault(statusBus, def.statusBus)
    checkWideStatus(statusBus)

    statusFrom = givenOrDefault(statusFrom, def.statusFrom)
    checkWideStatus(statusFrom)

    statusTo = givenOrDefault(statusTo, def.statusTo)
    checkWideStatus(statusTo)

    if statusBus != -1 || statusFrom != -1 || statusTo != -1
        pmuNumber = 0
        if statusBus != -1
            pmuNumber += system.bus.number
        end
        if statusFrom != -1
            pmuNumber += system.branch.layout.inservice
        end
        if statusTo != -1
            pmuNumber += system.branch.layout.inservice
        end

        pmu.label = OrderedDict{template.config.device, Int64}()
        sizehint!(pmu.label, pmuNumber)

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

        if statusBus != -1
            @inbounds for (label, i) in system.bus.label
                pmu.number += 1
                setLabel(pmu, missing, def.label, label)

                pmu.layout.index[i] = i
                pmu.layout.bus[i] = true

                baseInv = sqrt(3) / (baseVoltg.prefix * baseVoltg.value[i])

                add!(
                    pmu.magnitude, i, noise, pfx.voltageMagnitude, analysis.voltage.magnitude[i],
                    varianceMagnitudeBus, def.varianceMagnitudeBus, statusBus, baseInv
                )
                add!(
                    pmu.angle, i, noise, pfx.voltageAngle, analysis.voltage.angle[i],
                    varianceAngleBus, def.varianceAngleBus, statusBus, 1.0
                )
            end
        end

        if statusFrom != -1 || statusTo != -1
            baseInv = 1 / (system.base.power.value * system.base.power.prefix)
            @inbounds for (label, k) in system.branch.label
                if system.branch.layout.status[k] == 1
                    i, j = fromto(system, k)

                    if statusFrom != -1
                        pmu.number += 1
                        setLabel(pmu, missing, def.label, label; prefix = "From ")

                        pmu.layout.index[pmu.number] = k
                        pmu.layout.from[pmu.number] = true

                        baseFromInv = baseCurrentInv(baseInv, baseVoltg.value[i] * baseVoltg.prefix)
                        add!(
                            pmu.magnitude, pmu.number, noise, pfx.currentMagnitude,
                            current.from.magnitude[k], varianceMagnitudeFrom,
                            def.varianceMagnitudeFrom, statusFrom, baseFromInv,
                        )
                        add!(
                            pmu.angle, pmu.number, noise, pfx.currentAngle,
                            current.from.angle[k], varianceAngleFrom,
                            def.varianceAngleFrom, statusFrom, 1.0
                        )
                    end

                    if statusTo != -1
                        pmu.number += 1
                        setLabel(pmu, missing, def.label, label; prefix = "To ")

                        pmu.layout.index[pmu.number] = k
                        pmu.layout.to[pmu.number] = true

                        baseToInv = baseCurrentInv(baseInv, baseVoltg.value[j] * baseVoltg.prefix)
                        add!(
                            pmu.magnitude, pmu.number, noise, pfx.currentMagnitude,
                            current.to.magnitude[k], varianceMagnitudeTo,
                            def.varianceMagnitudeTo, statusTo, baseToInv,
                        )
                        add!(
                            pmu.angle, pmu.number, noise, pfx.currentAngle,
                            current.to.angle[k], varianceAngleTo,
                            def.varianceAngleTo, statusTo, 1.0
                        )
                    end
                end
            end
        end
        pmu.layout.label = pmu.number
    end
end

"""
    updatePmu!(system::PowerSystem, device::Measurement, [analysis::Analysis];
        kwargs...)

The function allows for the alteration of parameters for a PMU.

# Arguments
If the `Analysis` type is omitted, the function applies changes to the `Measurement` type
only. However, when including the `Analysis` type, it updates both the `Measurement` and
`Analysis` types. This streamlined process avoids the need to completely rebuild vectors
and matrices when adjusting these parameters.

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
function updatePmu!(
    system::PowerSystem,
    device::Measurement;
    label::IntStr,
    kwargs...
)
    baseVoltg = system.base.voltage
    pmu = device.pmu
    key = pmukwargs(template.pmu; kwargs...)

    idx = pmu.label[getLabel(pmu, label, "PMU")]
    idxBusBrch = pmu.layout.index[idx]

    if pmu.layout.bus[idx]
        pfxMagnitude = pfx.voltageMagnitude
        pfxAngle = pfx.voltageAngle

        baseInv = sqrt(3) / (baseVoltg.value[idxBusBrch] * baseVoltg.prefix)
    else
        pfxMagnitude = pfx.currentMagnitude
        pfxAngle = pfx.currentAngle

        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseVoltage = baseVoltageEnd(system, baseVoltg, pmu.layout.from[idx], idxBusBrch)
        baseInv = baseCurrentInv(basePowerInv, baseVoltage)
    end

    if isset(key.correlated)
        pmu.layout.correlated[idx] = key.correlated
    end
    if isset(key.polar)
        pmu.layout.polar[idx] = key.polar
    end

    updateMeter(
        pmu.magnitude, idx, key.magnitude, key.varianceMagnitude,
        key.status, key.noise, pfxMagnitude, baseInv
    )
    updateMeter(
        pmu.angle, idx, key.angle, key.varianceAngle,
        key.status, key.noise, pfxAngle, 1.0
    )
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation{WLS{T}};
    label::IntStr,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    slack = system.bus.layout.slack
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    idxPmu = pmu.label[getLabel(pmu, label, "PMU")]
    oldStatus = pmu.angle.status[idxPmu]
    oldVariance = pmu.angle.variance[idxPmu]

    updatePmu!(system, device; label, key...)

    if pmu.layout.bus[idxPmu]
        newStatus = pmu.angle.status[idxPmu]
        idxBus = pmu.layout.index[idxPmu]
        idx = analysis.method.index[idxPmu]

        if oldStatus != newStatus || oldVariance != pmu.angle.variance[idxPmu]
            se.run = true
        end

        if isset(key.status, key.angle)
            se.mean[idx] =
                newStatus * (pmu.angle.mean[idxPmu] - system.bus.voltage.angle[slack])

            if isset(key.status)
                se.coefficient[idx, idxBus] = newStatus
            end
        end

        if isset(key.varianceAngle)
            se.precision.nzval[idx] = 1 / pmu.angle.variance[idxPmu]
        end
    end
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation{LAV};
    label::IntStr,
    kwargs...
)
    bus = system.bus
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    idxPmu = pmu.label[getLabel(pmu, label, "PMU")]

    updatePmu!(system, device; label, key...)

    if pmu.layout.bus[idxPmu]
        idx = se.index[idxPmu]
        if pmu.angle.status[idxPmu] == 1
            add!(se, idx)

            mean = meanθi(pmu, bus, idxPmu)
            expr = θi(se, pmu.layout.index[idxPmu])
            addConstrLav!(se, expr, mean, idx)
        else
            remove!(se, idx)
        end
    end
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::PMUStateEstimation{WLS{T}};
    label::IntStrMiss,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    idx = pmu.label[getLabel(pmu, label, "PMU")]
    statusOld = pmu.magnitude.status[idx] & pmu.angle.status[idx]
    correlatedOld = pmu.layout.correlated[idx]

    updatePmu!(system, device; label, key...)

    statusNew = pmu.magnitude.status[idx] & pmu.angle.status[idx]
    mean = isset(key.magnitude, key.angle)
    variance = isset(key.varianceMagnitude, key.varianceAngle)

    cosθ = cos(pmu.angle.mean[idx])
    sinθ = sin(pmu.angle.mean[idx])
    row = 2 * idx - 1
    rox = row + 1

    if mean || variance || (pmu.layout.correlated[idx] != correlatedOld)
        varRe, varIm = variancePmu(pmu, cosθ, sinθ, idx)

        if pmu.layout.correlated[idx]
            precision!(se.precision, pmu, cosθ, sinθ, varRe, varIm, idx, row)
        else
            se.precision[row, row] = 1 / varRe
            se.precision[rox, rox] = 1 / varIm
            if correlatedOld
                se.precision[row, rox] = 0.0
                se.precision[rox, row] = 0.0
            end
        end
    end

    k = pmu.layout.index[idx]
    if statusNew != statusOld || mean
        if statusNew == 1 && (pmu.layout.bus[idx] || branch.layout.status[k] == 1)
            se.mean[row] = pmu.magnitude.mean[idx] * cosθ
            se.mean[rox] = pmu.magnitude.mean[idx] * sinθ
        else
            se.mean[row] = 0.0
            se.mean[rox] = 0.0
        end
    end

    if statusNew != statusOld
        if pmu.layout.bus[idx]
            if statusNew == 1
                se.coefficient[row, k] = 1.0
                se.coefficient[rox, k + bus.number] = 1.0
            else
                se.coefficient[row, k] = 0.0
                se.coefficient[rox, k + bus.number] = 0.0
            end
        else
            i, j = fromto(system, k)
            m = i + bus.number
            n = j + bus.number

            if statusNew == 1 && branch.layout.status[k] == 1
                if pmu.layout.from[idx]
                    p = ReImIijCoefficient(branch, ac, k)
                else
                    p = ReImIjiCoefficient(branch, ac, k)
                end
                se.coefficient[row, i] = se.coefficient[rox, m] = p.A
                se.coefficient[row, j] = se.coefficient[rox, n] = p.C
                se.coefficient[row, m] = p.B
                se.coefficient[row, n] = p.D
                se.coefficient[rox, i] = -p.B
                se.coefficient[rox, j] = -p.D
            else
                se.coefficient[row, i] = se.coefficient[rox, m] = 0.0
                se.coefficient[row, j] = se.coefficient[rox, n] = 0.0
                se.coefficient[row, m] = se.coefficient[rox, i] = 0.0
                se.coefficient[row, n] = se.coefficient[rox, j] = 0.0
            end
        end
    end
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::PMUStateEstimation{LAV};
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    idx = pmu.label[getLabel(pmu, label, "PMU")]
    statusOld = pmu.magnitude.status[idx] & pmu.angle.status[idx]

    updatePmu!(system, device; label, key...)

    statusNew = pmu.magnitude.status[idx] & pmu.angle.status[idx]

    sinθ, cosθ = sincos(pmu.angle.mean[idx])

    idxRe = 2 * idx - 1
    idxIm = idxRe + 1
    if statusOld == 0 && statusNew == 1
        add!(se, idxRe)
        add!(se, idxIm)

        idxBusBrch = pmu.layout.index[idx]
        if pmu.layout.bus[idx]
            reExpr, imExpr = ReImVi(se, idxBusBrch, bus.number)
        else
            if branch.layout.status[idxBusBrch] == 1
                if pmu.layout.from[idxBusBrch]
                    state = ReImIijCoefficient(branch, ac, idxBusBrch)
                else
                    state = ReImIjiCoefficient(branch, ac, idxBusBrch)
                end
                reExpr, imExpr = ReImIij(system, se, state, idxBusBrch)
            end
        end
        addConstrLav!(se, reExpr, 0.0, idxRe)
        addConstrLav!(se, imExpr, 0.0, idxIm)
    end

    if statusOld == 1 && statusNew == 0
        remove!(se, idxRe)
        remove!(se, idxIm)
    end

    if statusNew == 1 || isset(key.magnitude, key.angle)
        reMean = pmu.magnitude.mean[idx] * cosθ
        imMean = pmu.magnitude.mean[idx] * sinθ

        set_normalized_rhs(se.residual[idxRe], reMean)
        set_normalized_rhs(se.residual[idxIm], imMean)
    end
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = system.bus
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    idxPmu = pmu.label[getLabel(pmu, label, "PMU")]
    idxBusBrch = pmu.layout.index[idxPmu]
    correlatedOld = pmu.layout.correlated[idxPmu]

    updatePmu!(system, device; label, key...)

    idx =
        device.voltmeter.number + device.wattmeter.number +
        device.varmeter.number + device.ammeter.number + (2 * idxPmu - 1)
    idq = idx + 1

    if pmu.layout.polar[idxPmu]
        if pmu.magnitude.status[idxPmu] == 1
            if pmu.layout.bus[idxPmu]
                se.jacobian[idx, bus.number + idxBusBrch] = 1.0
                se.type[idx] = 10
            elseif pmu.layout.from[idxPmu]
                se.type[idx] = 8
            else
                se.type[idx] = 9
            end
            se.mean[idx] = pmu.magnitude.mean[idxPmu]
        else
            if pmu.layout.bus[idxPmu]
                se.jacobian[idx, bus.number + idxBusBrch] = 0.0
            else
                i, j = fromto(system, idxBusBrch)

                se.jacobian[idx, i] = se.jacobian[idx, bus.number + i] = 0.0
                se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
            end
            se.mean[idx] = 0.0
            se.residual[idx] = 0.0
            se.type[idx] = 0
        end

        if pmu.angle.status[idxPmu] == 1
            if pmu.layout.bus[idxPmu]
                se.jacobian[idq, idxBusBrch] = 1.0
                se.type[idq] = 11
            elseif pmu.layout.from[idxPmu]
                se.type[idq] = 12
            else
                se.type[idq] = 13
            end
            se.mean[idq] = pmu.angle.mean[idxPmu]
        else
            if pmu.layout.bus[idxPmu]
                se.jacobian[idq, idxBusBrch] = 0.0
            else
                i, j = fromto(system, idxBusBrch)

                se.jacobian[idq, i] = se.jacobian[idq, bus.number + i] = 0.0
                se.jacobian[idq, j] = se.jacobian[idq, bus.number + j] = 0.0
            end
            se.mean[idq] = 0.0
            se.residual[idq] = 0.0
            se.type[idq] = 0
        end
    else
        if pmu.magnitude.status[idxPmu] == 1 && pmu.angle.status[idxPmu] == 1
            se.mean[idx] = pmu.magnitude.mean[idxPmu] * cos(pmu.angle.mean[idxPmu])
            se.mean[idq] = pmu.magnitude.mean[idxPmu] * sin(pmu.angle.mean[idxPmu])
            if pmu.layout.bus[idxPmu]
                se.type[idx] = 14
                se.type[idq] = 15
            elseif pmu.layout.from[idxPmu]
                se.type[idx] = 16
                se.type[idq] = 18
            else
                se.type[idx] = 17
                se.type[idq] = 19
            end
        else
            if pmu.layout.bus[idxPmu]
                se.jacobian[idx, idxBusBrch] = 0.0
                se.jacobian[idx, bus.number + idxBusBrch] = 0.0
                se.jacobian[idq, idxBusBrch] = 0.0
                se.jacobian[idq, bus.number + idxBusBrch] = 0.0
            else
                i, j = fromto(system, idxBusBrch)

                se.jacobian[idx, i] = se.jacobian[idx, bus.number + i] = 0.0
                se.jacobian[idx, j] = se.jacobian[idx, bus.number + j] = 0.0
                se.jacobian[idq, i] = se.jacobian[idq, bus.number + i] = 0.0
                se.jacobian[idq, j] = se.jacobian[idq, bus.number + j] = 0.0
            end
            se.mean[idx] = se.mean[idq] = 0.0
            se.residual[idx] = se.residual[idq] = 0.0
            se.type[idx] = se.type[idq] = 0
        end
    end

    if pmu.layout.polar[idxPmu]
        se.precision[idx, idx] = 1 / pmu.magnitude.variance[idxPmu]
        se.precision[idq, idq] = 1 / pmu.angle.variance[idxPmu]

        if correlatedOld
            se.precision[idx, idq] = 0.0
            se.precision[idq, idx] = 0.0
        end
    else
        cosθ = cos(pmu.angle.mean[idxPmu])
        sinθ = sin(pmu.angle.mean[idxPmu])

        varRe, varIm = variancePmu(pmu, cosθ, sinθ, idxPmu)

        if pmu.layout.correlated[idxPmu]
            precision!(se.precision, pmu, cosθ, sinθ, varRe, varIm, idxPmu, idx)
        else
            se.precision[idx, idx] = 1 / varRe
            se.precision[idq, idq] = 1 / varIm
            se.precision[idx, idq] = 0.0
            se.precision[idq, idx] = 0.0
        end
    end
end

function updatePmu!(
    system::PowerSystem,
    device::Measurement,
    analysis::ACStateEstimation{LAV};
    label::IntStrMiss,
    kwargs...
)
    bus = system.bus
    pmu = device.pmu
    se = analysis.method
    key = pmukwargs(template.pmu; kwargs...)

    updatePmu!(system, device; label, key...)

    idxPmu = pmu.label[getLabel(pmu, label, "PMU")]
    idxBusBrch = pmu.layout.index[idxPmu]
    idx =
        device.voltmeter.number + device.wattmeter.number +
        device.varmeter.number + device.ammeter.number + (2 * idxPmu - 1)

    if pmu.layout.polar[idxPmu]
        if pmu.layout.bus[idxPmu]
            if pmu.magnitude.status[idxPmu] == 1
                add!(se, idx)
                addConstrLav!(se, se.state.V[idxBusBrch], pmu.magnitude.mean[idxPmu], idx)
            else
                remove!(se, idx)
            end

            if pmu.angle.status[idxPmu] == 1
                add!(se, idx + 1)
                expr = @expression(se.jump, se.statex[idxBusBrch] - se.statey[idxBusBrch])
                addConstrLav!(se, expr, pmu.angle.mean[idxPmu], idx + 1)
            else
                remove!(se, idx + 1)
            end
        else
            if pmu.magnitude.status[idxPmu] == 1
                add!(se, idx)
                if pmu.layout.from[idxPmu]
                    expr = Iij(system, se, idxBusBrch)
                else
                    expr = Iji(system, se, idxBusBrch)
                end
                addConstrLav!(se, expr, pmu.magnitude.mean[idxPmu], idx)
            else
                remove!(se, idx)
            end

            if pmu.angle.status[idxPmu] == 1
                add!(se, idx + 1)
                if pmu.layout.from[idxPmu]
                    expr = ψij(system, se, idxBusBrch)
                else
                    expr = ψji(system, se, idxBusBrch)
                end
                addConstrLav!(se, expr, pmu.angle.mean[idxPmu], idx + 1)
            else
                remove!(se, idx + 1)
            end
        end
    else
        if pmu.magnitude.status[idxPmu] == 1 && pmu.angle.status[idxPmu] == 1
            add!(se, idx)
            add!(se, idx + 1)

            if pmu.layout.bus[idxPmu]
                ReExpr, ImExpr = ReImVi(se, idxBusBrch)
            else
                if pmu.layout.from[idxPmu]
                    ReExpr, ImExpr = ReImIij(system, se, idxBusBrch)
                else
                    ReExpr, ImExpr = ReImIji(system, se, idxBusBrch)
                end
            end
            ReMean = pmu.magnitude.mean[idxPmu] * cos(pmu.angle.mean[idxPmu])
            ImMean = pmu.magnitude.mean[idxPmu] * sin(pmu.angle.mean[idxPmu])

            addConstrLav!(se, ReExpr, ReMean, idx)
            addConstrLav!(se, ImExpr, ImMean, idx + 1)
        else
            remove!(se, idx)
            remove!(se, idx + 1)
        end
    end
end

"""
    @pmu(label, noise, correlated, polar,
        varianceMagnitudeBus, varianceAngleBus, statusBus,
        varianceMagnitudeFrom, varianceAngleFrom, statusFrom,
        varianceMagnitudeTo, varianceAngleTo, statusTo)

The macro generates a template for a PMU, which can be utilized to define a PMU using the
[`addPmu!`](@ref addPmu!) function.

# Keywords
To establish the PMU template, users can configure the pattern for labels using the `label`
keyword, specify the type of `noise`, and indicate the `correlated` and `polar` system
utilized for managing phasors during state estimation.

Users have the option to set default values for magnitude and angle variances, as well as
statuses. This can be done for PMUs located at the buses using the `varianceMagnitudeBus`,
`varianceAngleBus`, and `statusBus` keywords.

The same configuration can be applied at both the from-bus ends of the branches using the
`varianceMagnitudeFrom`, `varianceAngleFrom`, and `statusFrom` keywords.

For PMUs located at the to-bus ends of the branches, users can use the `varianceMagnitudeTo`,
`varianceAngleTo`, and `statusTo` keywords.

# Units
By default, the units for variances are per-units and radians. However, users have the
option to switch to volts and degrees as the units for PMUs located at the buses by using
the [`@voltage`](@ref @voltage) macro, or they can switch to amperes  and degrees as the
units for PMUs located at the branches by using the [`@current`](@ref @current) macro.

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
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(PmuTemplate, parameter)
                if parameter in [
                        :varianceMagnitudeBus; :varianceAngleBus; :varianceMagnitudeFrom;
                        :varianceAngleFrom; :varianceMagnitudeTo; :varianceAngleTo
                        ]
                    container::ContainerTemplate = getfield(template.pmu, parameter)
                    if parameter == :varianceMagnitudeBus
                        prefixLive = pfx.voltageMagnitude
                    elseif parameter in [:varianceMagnitudeFrom; :varianceMagnitudeTo]
                        prefixLive = pfx.currentMagnitude
                    elseif parameter == :varianceAngleBus
                        prefixLive = pfx.voltageAngle
                    else
                        prefixLive = pfx.currentAngle
                    end
                    val = Float64(eval(kwarg.args[2]))
                    if prefixLive != 0.0
                        setfield!(container, :value, prefixLive * val)
                        setfield!(container, :pu, false)
                    else
                        setfield!(container, :value, val)
                        setfield!(container, :pu, true)
                    end
                else
                    if parameter in [:statusBus; :statusFrom; :statusTo]
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
                            errorTemplateLabel()
                        end
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end