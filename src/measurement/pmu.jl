"""
    addPmu!(monitoring::Measurement;
        label, bus, from, to, magnitude, varianceMagnitude, angle, varianceAngle,
        noise, correlated, polar, square, status)

The function adds a PMU to the `Measurement` type. The PMU can be added to an already defined bus or
branch. When defining the PMU, it is essential to provide the bus voltage magnitude and angle if the
PMU is located at a bus or the branch current magnitude and angle if the PMU is located at a branch.

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
* `square`: Specifies how the current magnitude is included in the model when using the polar system:
  * `square = true`: included in squared form,
  * `square = false`: included in its original form.
* `status`: Operating status of the phasor measurement:
  * `status = 1`: in-service,
  * `status = 0`: out-of-service.

Note that all voltage values are referenced to line-to-neutral voltages.

# Updates
The function updates the `pmu` field of the `Measurement` type.

# Default Settings
Default settings for certain keywords are as follows: `varianceMagnitude = 1e-8`,
`varianceAngle = 1e-8`, `noise = false`, `correlated = false`, `polar = false`, `square = false`,
and `status = 1` which apply to PMUs located at the bus, as well as at both the from-bus and to-bus
ends. Users can fine-tune these settings by explicitly specifying the variance and status for PMUs
positioned at the buses, from-bus ends, or to-bus ends of branches using the [`@pmu`](@ref @pmu)
macro.

# Units
The default units for the `magnitude`, `varianceMagnitude`, and `angle`, `varianceAngle` keywords
are per-units and radians. However, users have the option to switch to volts and degrees when the
PMU is located at a bus using the [`@voltage`](@ref @voltage) macro, or amperes and degrees when the
PMU is located at a branch through the use of the [`@current`](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 131.8e3)
addBus!(system; label = "Bus 2", base = 131.8e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 1.1, angle = -0.1)
addPmu!(monitoring; label = "PMU 2", from = "Branch 1", magnitude = 1.1, angle = 0.1)
```

Adding PMUs using a custom unit system:
```jldoctest
@voltage(kV, deg, kV)
@current(A, deg)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 131.8)
addBus!(system; label = "Bus 2", base = 131.8)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 145, angle = -5.7)
addPmu!(monitoring; label = "PMU 2", from = "Branch 1", magnitude = 481, angle = 5.7)
```
"""
function addPmu!(
    monitoring::Measurement;
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
    polar::Bool = template.pmu.polar,
    square::Bool = template.pmu.square
)
    system = monitoring.system
    baseVoltg = system.base.voltage
    branch = system.branch
    pmu = monitoring.pmu
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
            push!(pmu.layout.square, false)

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
            push!(pmu.layout.square, square)

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
    addPmu!(monitoring::Measurement, analysis::AC;
        varianceMagnitudeBus, varianceAngleBus, statusBus,
        varianceMagnitudeFrom, varianceAngleFrom, statusFrom,
        varianceMagnitudeTo, varianceAngleTo, statusTo,
        noise, correlated, polar, square)

The function incorporates PMUs into the `Measurement` type for every branch within the `PowerSystem`
type from which `Measurement` was created. These measurements are derived from the exact bus voltage
magnitudes and angles, as well as branch current magnitudes and angles defined in the `AC` type.

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
* `square`: Specifies how current magnitudes are included in the model when using the polar system:
  * `square = true`: included in squared form,
  * `square = false`: included in its original form.

# Updates
The function updates the `pmu` field of the `Measurement` type.

# Default Settings
Default settings for variance keywords are established at `1e-8`, with all statuses set to `1`,
`polar = false`, `correlated = false`, `noise = false`, and `square = false`. Users can change these
default settings using the [`@pmu`](@ref @pmu) macro.

# Units
The default units for the variance keywords are in per-units and radians. However, users have the
option to switch to volts and degrees when the PMU is located at a bus using the
[`@voltage`](@ref @voltage) macro, or amperes and degrees when the PMU is located at a branch through
the use of the [`@current`](@ref @current) macro.

# Example
```jldoctest
@pmu(label = "PMU ?")

system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; current = true)

addPmu!(monitoring, analysis; varianceMagnitudeBus = 1e-3)
```
"""
function addPmu!(
    monitoring::Measurement,
    analysis::AC;
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
    square::Bool = template.pmu.square,
    noise::Bool = template.pmu.noise
)
    system = monitoring.system
    errorVoltage(analysis.voltage.magnitude)

    baseVoltg = system.base.voltage
    pmu = monitoring.pmu
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
            errorCurrent(analysis.current.from.magnitude)
            pmuNumber += system.branch.layout.inservice
        end
        if statusTo != -1
            errorCurrent(analysis.current.from.magnitude)
            pmuNumber += system.branch.layout.inservice
        end

        pmu.label = OrderedDict{template.pmu.key, Int64}()
        sizehint!(pmu.label, pmuNumber)

        pmu.layout.index = fill(0, pmuNumber)
        pmu.layout.bus = fill(false, pmuNumber)
        pmu.layout.from = fill(false, pmuNumber)
        pmu.layout.to = fill(false, pmuNumber)
        pmu.layout.correlated = fill(correlated, pmuNumber)
        pmu.layout.polar = fill(polar, pmuNumber)
        pmu.layout.square = fill(square, pmuNumber)

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
                pmu.layout.square[i] = false

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
    updatePmu!(monitoring::Measurement; kwargs...)

The function allows for the alteration of parameters for a PMU.

# Keywords
To update a specific PMU, provide the necessary `kwargs` input arguments in accordance with the
keywords specified in the [`addPmu!`](@ref addPmu!) function, along with their respective values.
Ensure that the `label` keyword matches the `label` of the existing PMU you want to modify. If any
keywords are omitted, their corresponding values will remain unchanged.

# Updates
The function updates the `pmu` field within the `Measurement` type.

# Units
Units for input parameters can be changed using the same method as described for the
[`addPmu!`](@ref addPmu!) function.

# Example
```jldoctest
system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)

addPmu!(monitoring; label = "PMU 1", bus = "Bus 1", magnitude = 1.1, angle = -0.1)
updatePmu!(monitoring; label = "PMU 1", magnitude = 1.05)
```
"""
function updatePmu!(
    monitoring::Measurement;
    label::IntStr,
    square::BoolMiss = missing,
    kwargs...
)
    system = monitoring.system
    baseVoltg = system.base.voltage
    pmu = monitoring.pmu
    key = pmukwargs(template.pmu; kwargs...)

    idx = pmu.label[getLabel(pmu, label, "PMU")]
    idxBusBrch = pmu.layout.index[idx]

    if pmu.layout.bus[idx]
        pfxMagnitude = pfx.voltageMagnitude
        pfxAngle = pfx.voltageAngle

        baseInv = sqrt(3) / (baseVoltg.value[idxBusBrch] * baseVoltg.prefix)
    else
        if isset(square)
            pmu.layout.square[idx] = square
        end

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

    if !pmu.layout.bus[idx]
        idxBrch = pmu.layout.index[idx]
        pmu.magnitude.status[idx] &= system.branch.layout.status[idxBrch]
        pmu.angle.status[idx] &= system.branch.layout.status[idxBrch]
    end
end

"""
    updatePmu!(analysis::Analysis; kwargs...)

The function extends the [`updatePmu!`](@ref updatePmu!(::Measurement)) function. By passing the
`Analysis` type, the function first updates the specific PMU within the `Measurement` type using the
provided `kwargs`, and then updates the `Analysis` type with all parameters associated with that PMU.

A key feature of this function is that any prior modifications made to the specified PMU are preserved
and applied to the `Analysis` type when the function is executed, ensuring consistency throughout the
update process.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

analysis = gaussNewton(monitoring)
stateEstimation!(analysis)

updatePmu!(analysis; label = 4, magnitude = 0.95, angle = -0.1)
```
"""
function updatePmu!(
    analysis::AcStateEstimation{GaussNewton{T}};
    label::IntStrMiss,
    square::BoolMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    bus = analysis.system.bus
    pmu = analysis.monitoring.pmu
    wls = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idxPmu = getIndex(pmu, label, "PMU")
    idxBusBrch = pmu.layout.index[idxPmu]

    idx = wls.range[5] + 2 * (idxPmu - 1)
    idq = idx + 1

    v = pmu.magnitude.status[idxPmu]
    t = pmu.angle.status[idxPmu]

    wls.precision[idx, idq] = 0.0
    wls.precision[idq, idx] = 0.0

    if !pmu.layout.polar[idxPmu]
        cosθ = cos(pmu.angle.mean[idxPmu])
        sinθ = sin(pmu.angle.mean[idxPmu])

        varRe, varIm = variancePmu(pmu, cosθ, sinθ, idxPmu)

        if pmu.layout.correlated[idxPmu]
            if !isstored(wls.precision, idx, idq)
                wls.signature[:pattern] = -1
            end
            precision!(wls.precision, pmu, cosθ, sinθ, varRe, varIm, idxPmu, idx)
        else
            wls.precision[idx, idx] = 1 / varRe
            wls.precision[idq, idq] = 1 / varIm
        end
    end

    if pmu.layout.bus[idxPmu]
        if pmu.layout.polar[idxPmu] # PMU Polar Bus

            wls.mean[idx] = v * pmu.magnitude.mean[idxPmu]
            wls.mean[idq] = t * pmu.angle.mean[idxPmu]

            wls.precision[idx, idx] = 1 / pmu.magnitude.variance[idxPmu]
            wls.precision[idq, idq] = 1 / pmu.angle.variance[idxPmu]

            wls.jacobian[idx, bus.number + idxBusBrch] = v * 1.0
            wls.jacobian[idq, idxBusBrch] = t * 1.0

            wls.residual[idx] *= v
            wls.residual[idq] *= t

            wls.type[idx] = v * 12
            wls.type[idq] = t * 13

            wls.jacobian[idx, idxBusBrch] = 0.0
            wls.jacobian[idq, bus.number + idxBusBrch] = 0.0
        else # PMU Rectangular Bus
            p = v * t

            if !isstored(wls.jacobian, idx, idxBusBrch)
                wls.signature[:pattern] = -1
            end

            wls.mean[idx] = p * pmu.magnitude.mean[idxPmu] * cosθ
            wls.mean[idq] = p * pmu.magnitude.mean[idxPmu] * sinθ

            wls.jacobian[idx, idxBusBrch] = eps(Float64)
            wls.jacobian[idx, bus.number + idxBusBrch] = eps(Float64)
            wls.jacobian[idq, idxBusBrch] = eps(Float64)
            wls.jacobian[idq, bus.number + idxBusBrch] = eps(Float64)

            wls.residual[idx] *= p
            wls.residual[idq] *= p

            wls.type[idx] = p * 16
            wls.type[idq] = p * 17
        end
    else # PMU Branch
        i, j = fromto(analysis.system, idxBusBrch)

        wls.jacobian[idx, i] = wls.jacobian[idx, bus.number + i] = 0.0
        wls.jacobian[idx, j] = wls.jacobian[idx, bus.number + j] = 0.0

        wls.jacobian[idq, i] = wls.jacobian[idq, bus.number + i] = 0.0
        wls.jacobian[idq, j] = wls.jacobian[idq, bus.number + j] = 0.0

        if pmu.layout.polar[idxPmu] # PMU Polar Branch
            sq = if2exp(pmu.layout.square[idxPmu])

            wls.mean[idx] = v * pmu.magnitude.mean[idxPmu]^sq
            wls.mean[idq] = t * pmu.angle.mean[idxPmu]

            wls.precision[idx, idx] = 1 / (sq * pmu.magnitude.variance[idxPmu])
            wls.precision[idq, idq] = 1 / pmu.angle.variance[idxPmu]

            wls.residual[idx] *= v
            wls.residual[idx] *= t

            ty = if2type(pmu.layout.square[idxPmu])
            if pmu.layout.from[idxPmu]
                wls.type[idx] = v * (2 + ty)
                wls.type[idq] = t * 14
            else
                wls.type[idx] = v * (3 + ty)
                wls.type[idq] = t * 15
            end
        else # PMU Rectangular Branch
            p = v * t

            wls.mean[idx] = p * (pmu.magnitude.mean[idxPmu] * cosθ)
            wls.mean[idq] = p * (pmu.magnitude.mean[idxPmu] * sinθ)

            wls.residual[idx] *= p
            wls.residual[idq] *= p

            if pmu.layout.from[idxPmu]
                wls.type[idx] = p * 18
                wls.type[idq] = p * 20
            else
                wls.type[idx] = p * 19
                wls.type[idq] = p * 21
            end
        end
    end
end

function updatePmu!(
    analysis::AcStateEstimation{LAV};
    label::IntStrMiss,
    square::BoolMiss = missing,
    kwargs...
)
    system = analysis.system
    pmu = analysis.monitoring.pmu
    lav = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idxPmu = getIndex(pmu, label, "PMU")
    idxBusBrch = pmu.layout.index[idxPmu]

    idx = lav.range[5] + 2 * (idxPmu - 1)

    remove!(lav, idx)
    remove!(lav, idx + 1)

    if pmu.layout.polar[idxPmu] # PMU Polar Bus and Branch
        if pmu.magnitude.status[idxPmu] == 1
            add!(lav, idx)

            if pmu.layout.bus[idxPmu]
                expr = lav.variable.voltage.magnitude[idxBusBrch]
                sq = 1
            else
                if pmu.layout.from[idxPmu]
                    expr = Iij(system, lav.variable.voltage, pmu.layout.square[idxPmu], idxBusBrch)
                else
                    expr = Iji(system, lav.variable.voltage, pmu.layout.square[idxPmu], idxBusBrch)
                end
                sq = if2exp(pmu.layout.square[idxPmu])
            end

            addConstrLav!(lav, expr, pmu.magnitude.mean[idxPmu]^sq, idx)
        end

        if pmu.angle.status[idxPmu] == 1
            add!(lav, idx + 1)

            if pmu.layout.bus[idxPmu]
                expr = lav.variable.voltage.angle[idxBusBrch]
            elseif pmu.layout.from[idxPmu]
                expr = ψij(system, lav.variable.voltage, idxBusBrch)
            else
                expr = ψji(system, lav.variable.voltage, idxBusBrch)
            end

            addConstrLav!(lav, expr, pmu.angle.mean[idxPmu], idx + 1)
        end
    else # PMU Rectangular Bus and Branch
        if pmu.magnitude.status[idxPmu] == 1 && pmu.angle.status[idxPmu] == 1
            add!(lav, idx)
            add!(lav, idx + 1)

            if pmu.layout.bus[idxPmu]
                ReExpr, ImExpr = ReImVi(lav.variable.voltage, idxBusBrch)
            elseif pmu.layout.from[idxPmu]
                ReExpr, ImExpr = ReImIij(system, lav.variable.voltage, idxBusBrch)
            else
                ReExpr, ImExpr = ReImIji(system, lav.variable.voltage, idxBusBrch)
            end
            ReMean = pmu.magnitude.mean[idxPmu] * cos(pmu.angle.mean[idxPmu])
            ImMean = pmu.magnitude.mean[idxPmu] * sin(pmu.angle.mean[idxPmu])

            addConstrLav!(lav, ReExpr, ReMean, idx)
            addConstrLav!(lav, ImExpr, ImMean, idx + 1)
        end
    end
end

function updatePmu!(
    analysis::PmuStateEstimation{WLS{T}};
    label::IntStrMiss,
    square::BoolMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    pmu = analysis.monitoring.pmu
    wls = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idx = getIndex(pmu, label, "PMU")
    row = 2 * idx - 1
    rox = row + 1

    wls.precision[row, rox] = 0.0
    wls.precision[rox, row] = 0.0

    cosθ = cos(pmu.angle.mean[idx])
    sinθ = sin(pmu.angle.mean[idx])

    varRe, varIm = variancePmu(pmu, cosθ, sinθ, idx)
    if pmu.layout.correlated[idx]
        if !isstored(wls.precision, row, rox)
            wls.signature[:pattern] = -1
        end
        precision!(wls.precision, pmu, cosθ, sinθ, varRe, varIm, idx, row)
    else
        wls.precision[row, row] = 1 / varRe
        wls.precision[rox, rox] = 1 / varIm
    end

    status = pmu.magnitude.status[idx] * pmu.angle.status[idx]

    k = pmu.layout.index[idx]
    if pmu.layout.bus[idx]
        wls.mean[row] = status * (pmu.magnitude.mean[idx] * cosθ)
        wls.mean[rox] = status * (pmu.magnitude.mean[idx] * sinθ)

        wls.coefficient[row, k] = status * 1.0
        wls.coefficient[rox, k + analysis.system.bus.number] = status * 1.0
    else
        wls.mean[row] = status * (pmu.magnitude.mean[idx] * cosθ)
        wls.mean[rox] = status * (pmu.magnitude.mean[idx] * sinθ)

        i, j = fromto(analysis.system, k)
        m = i + analysis.system.bus.number
        n = j + analysis.system.bus.number

        if status == 1
            if pmu.layout.from[idx]
                p = ReImIijCoefficient(analysis.system.branch, analysis.system.model.ac, k)
            else
                p = ReImIjiCoefficient(analysis.system.branch, analysis.system.model.ac, k)
            end
            wls.coefficient[row, i] = wls.coefficient[rox, m] = p.A
            wls.coefficient[row, j] = wls.coefficient[rox, n] = p.C
            wls.coefficient[row, m] = p.B
            wls.coefficient[row, n] = p.D
            wls.coefficient[rox, i] = -p.B
            wls.coefficient[rox, j] = -p.D
        else
            wls.coefficient[row, i] = wls.coefficient[rox, m] = 0.0
            wls.coefficient[row, j] = wls.coefficient[rox, n] = 0.0
            wls.coefficient[row, m] = wls.coefficient[rox, i] = 0.0
            wls.coefficient[row, n] = wls.coefficient[rox, j] = 0.0
        end
    end
end

function updatePmu!(
    analysis::PmuStateEstimation{LAV};
    label::IntStrMiss,
    square::BoolMiss = missing,
    kwargs...
)
    pmu = analysis.monitoring.pmu
    lav = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idx = getIndex(pmu, label, "PMU")
    idxBusBrch = pmu.layout.index[idx]
    idxRe = 2 * idx - 1
    idxIm = idxRe + 1

    status = pmu.magnitude.status[idx] * pmu.angle.status[idx]

    remove!(lav, idxRe)
    remove!(lav, idxIm)
    if status == 1
        add!(lav, idxRe)
        add!(lav, idxIm)

        sinθ, cosθ = sincos(pmu.angle.mean[idx])
        reMean = pmu.magnitude.mean[idx] * cosθ
        imMean = pmu.magnitude.mean[idx] * sinθ

        if pmu.layout.bus[idx]
            reExpr = lav.variable.voltage.real[idxBusBrch]
            imExpr = lav.variable.voltage.imag[idxBusBrch]
        else
            if pmu.layout.from[idx]
                p = ReImIijCoefficient(analysis.system.branch, analysis.system.model.ac, idxBusBrch)

            else
                p = ReImIjiCoefficient(analysis.system.branch, analysis.system.model.ac, idxBusBrch)
            end
            reExpr, imExpr = ReImIij(analysis.system, lav.variable.voltage, p, idxBusBrch)
        end
        addConstrLav!(lav, reExpr, reMean, idxRe)
        addConstrLav!(lav, imExpr, imMean, idxIm)
    end
end

function updatePmu!(
    analysis::DcStateEstimation{WLS{T}};
    label::IntStr,
    square::BoolMiss = missing,
    kwargs...
) where T <: Union{Normal, Orthogonal}

    slack = analysis.system.bus.layout.slack
    pmu = analysis.monitoring.pmu
    wls = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idxPmu = getIndex(pmu, label, "PMU")

    if pmu.layout.bus[idxPmu]
        idx = analysis.method.index[idxPmu]

        oldCoef = wls.coefficient[idx, pmu.layout.index[idxPmu]]
        oldPrec = wls.precision.nzval[idx]

        status = pmu.angle.status[idxPmu]

        wls.mean[idx] = status * (pmu.angle.mean[idxPmu] - analysis.system.bus.voltage.angle[slack])
        wls.coefficient[idx, pmu.layout.index[idxPmu]] = status
        wls.precision.nzval[idx] = 1 / pmu.angle.variance[idxPmu]

        if oldCoef != status || oldPrec != wls.precision.nzval[idx]
            wls.signature[:run] = true
        end
    end
end

function updatePmu!(
    analysis::DcStateEstimation{LAV};
    label::IntStr,
    square::BoolMiss = missing,
    kwargs...
)
    pmu = analysis.monitoring.pmu
    lav = analysis.method

    updatePmu!(analysis.monitoring; label, square, kwargs...)

    idxPmu = pmu.label[getLabel(pmu, label, "PMU")]

    if pmu.layout.bus[idxPmu]
        idx = lav.index[idxPmu]

        remove!(lav, idx)
        if pmu.angle.status[idxPmu] == 1
            add!(lav, idx)
            mean = meanθi(pmu, analysis.system.bus, idxPmu)
            addConstrLav!(lav, lav.variable.voltage.angle[pmu.layout.index[idxPmu]], mean, idx)
        end
    end
end

"""
    @pmu(label, noise, correlated, polar, square,
        varianceMagnitudeBus, varianceAngleBus, statusBus,
        varianceMagnitudeFrom, varianceAngleFrom, statusFrom,
        varianceMagnitudeTo, varianceAngleTo, statusTo)

The macro generates a template for a PMU.

# Keywords
To establish the PMU template, users can configure the pattern for labels using the `label` keyword,
specify the type of `noise`, and indicate the `correlated, `polar`, and `square` system utilized for
managing phasors during state estimation.

Users have the option to set default values for magnitude and angle variances, as well as statuses.
This can be done for PMUs located at the buses using the `varianceMagnitudeBus`, `varianceAngleBus`,
and `statusBus` keywords.

The same configuration can be applied at both the from-bus ends of the branches using the
`varianceMagnitudeFrom`, `varianceAngleFrom`, and `statusFrom` keywords.

For PMUs located at the to-bus ends of the branches, users can use the `varianceMagnitudeTo`,
`varianceAngleTo`, and `statusTo` keywords.

# Units
By default, the units for variances are per-units and radians. However, users have the option to
switch to volts and degrees as the units for PMUs located at the buses by using the
[`@voltage`](@ref @voltage) macro, or they can switch to amperes  and degrees as the units for PMUs
located at the branches by using the [`@current`](@ref @current) macro.

# Examples
Adding PMUs using the default unit system:
```jldoctest
@pmu(label = "PMU ?", varianceAngleBus = 1e-6, varianceMagnitudeFrom = 1e-4)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132e3)
addBus!(system; label = "Bus 2", base = 132e3)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(monitoring; bus = "Bus 1", magnitude = 1.1, angle = -0.1)
addPmu!(monitoring; from = "Branch 1", magnitude = 1.1, angle = -0.2)
```

Adding PMUs using a custom unit system:
```jldoctest
@voltage(kV, deg, kV)
@current(A, deg)
@pmu(label = "PMU ?", varianceAngleBus = 5.73e-5, varianceMagnitudeFrom = 0.0481)

system, monitoring = ems()

addBus!(system; label = "Bus 1", base = 132.0)
addBus!(system; label = "Bus 2", base = 132.0)
addBranch!(system; label = "Branch 1", from = "Bus 1", to = "Bus 2", reactance = 0.2)

addPmu!(monitoring; bus = "Bus 1", magnitude = 145.2, angle = -5.73)
addPmu!(monitoring; from = "Branch 1", magnitude = 481.125, angle = -11.46)
```
"""
macro pmu(kwargs...)
    quote
        for kwarg in $(esc(kwargs))
            parameter::Symbol = kwarg.args[1]

            if hasfield(PmuTemplate, parameter)
                if parameter in (
                        :varianceMagnitudeBus, :varianceAngleBus, :varianceMagnitudeFrom,
                        :varianceAngleFrom, :varianceMagnitudeTo, :varianceAngleTo
                        )
                    container::ContainerTemplate = getfield(template.pmu, parameter)
                    if parameter == :varianceMagnitudeBus
                        prefixLive = pfx.voltageMagnitude
                    elseif parameter in (:varianceMagnitudeFrom, :varianceMagnitudeTo)
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
                    if parameter in (:statusBus, :statusFrom, :statusTo)
                        setfield!(template.pmu, parameter, Int8(eval(kwarg.args[2])))
                    elseif parameter in (:noise, :correlated, :polar, :square)
                        setfield!(template.pmu, parameter, Bool(eval(kwarg.args[2])))
                    elseif parameter == :label
                        macroLabel(template.pmu, kwarg.args[2], "[?!]")
                    end
                end
            else
                errorTemplateKeyword(parameter)
            end
        end
    end
end