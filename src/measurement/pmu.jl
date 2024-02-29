"""
    addPmu!(system::PowerSystem, device::Measurement; label, bus, from, to, magnitude,
        varianceMagnitude, statusMagnitude, angle, varianceAngle, statusAngle, noise)

The function adds a new PMU to the `Measurement` composite type within a given `PowerSystem`
type. The PMU can be added to an already defined bus or branch. When defining the PMU, it
is essential to provide the bus voltage magnitude and angle if the PMU is located at a bus 
or the branch current magnitude and angle if the PMU is located at a branch.

# Keywords
The PMU is defined with the following keywords:
* `label`: a unique label for the PMU;
* `bus`: the label of the bus if the PMU is located at the bus;
* `from`: the label of the branch if the PMU is located at the "from" bus end;
* `to`: the label of the branch if the PMU is located at the "to" bus end;
* `magnitude` (pu or V, A): the bus voltage or branch current magnitude value;
* `varianceMagnitude` (pu or V, A): the magnitude measurement variance;
* `statusMagnitude`: the operating status of PMU magnitude measurement:
  * `statusMagnitude = 1`: in-service;
  * `statusMagnitude = 0`: out-of-service;
* `angle` (rad or deg): the bus voltage or branch current angle value;
* `varianceAngle` (rad or deg): the angle measurement variance;
* `statusAngle`: the operating status of PMU angle measurement:
  * `statusAngle = 1`: in-service;
  * `statusAngle = 0`: out-of-service;
* `noise`: specifies how to generate the measurement means:
  * `noise = true`: adds white Gaussian noises with variances to the `magnitude` and `angle`;
  * `noise = false`: uses the `magnitude` and `angle` values only.

# Updates
The function updates the `pmu` field of the `Measurement` composite type.

# Default Settings
Default settings for certain keywords are as follows: `varianceMagnitude = 1e-5`,
`statusMagnitude = 1`, `varianceAngle = 1e-5`, `statusAngle = 1`, and `noise = true`,
which apply to PMUs located at the bus, as well as at both the "from" and "to" bus ends.
Users can fine-tune these settings by explicitly specifying the variance and status for
PMUs positioned at the buses, "from" bus ends, or "to" bus ends of branches using the
[`@pmu`](@ref @pmu) macro.

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
    magnitude::T, angle::T, varianceMagnitude::T = missing, varianceAngle::T = missing,
    statusMagnitude::T = missing, statusAngle::T = missing, noise::Bool = template.pmu.noise)

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
        varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo)

The function incorporates PMUs into the `Measurement` composite type for every bus and
branch within the `PowerSystem` type. These measurements are derived from the exact bus
voltage magnitudes and angles, as well as branch current magnitudes and angles defined in
the `AC` abstract type. These exact values are then perturbed by white Gaussian noise with 
the specified `varianceMagnitude` and `varianceAngle` to obtain measurement data.

# Keywords
Users have the option to configure the following keywords:
* `varianceMagnitudeBus` (pu or V): variance of PMU magnitude measurements at buses;
* `statusMagnitudeBus`: the operating status of PMU magnitude measurements at buses:
  * `statusMagnitudeBus = 1`: in-service;
  * `statusMagnitudeBus = 0`: out-of-service;
* `varianceAngleBus` (rad or deg): variance of PMU angle measurements at buses;
* `statusAngleBus`: the operating status of PMU agle measurements at buses:
  * `statusAngleBus = 1`: in-service;
  * `statusAngleBus = 0`: out-of-service;
* `varianceMagnitudeFrom` (pu or A): variance of PMU magnitude measurements at the "from" bus ends;      
* `statusMagnitudeFrom`: the operating status of PMU magnitude measurements at the "from" bus ends:
  * `statusMagnitudeFrom = 1`: in-service;
  * `statusMagnitudeFrom = 0`: out-of-service;
* `varianceAngleFrom` (rad or deg): variance of PMU angle measurements at the "from" bus ends;
* `statusAngleFrom`: the operating status of PMU angle measurements at the "from" bus ends:
  * `statusAngleFrom = 1`: in-service;
  * `statusAngleFrom = 0`: out-of-service;
* `varianceMagnitudeTo` (pu or A): variance of PMU magnitude measurements at the "to" bus ends; 
* `statusMagnitudeTo`: the operating status of PMU magnitude measurements at the "to" bus ends:
  * `statusMagnitudeTo = 1`: in-service;
  * `statusMagnitudeTo = 0`: out-of-service;
* `varianceAngleTo` (rad or deg): variance of PMU angle measurements at the "to" bus ends;
* `statusAngleTo`: the operating status of PMU angle measurements at the "to" bus ends:
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
Adding PMUs using exact values from the AC power flow:
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
current!(system, analysis)

device = measurement()

@pmu(label = "PMU ?")
addPmu!(system, device, analysis; varianceMagnitudeBus = 1e-3)
```

Adding PMUs using exact values from the AC optimal power flow:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
current!(system, analysis)

device = measurement()

@pmu(label = "PMU ?")
addPmu!(system, device, analysis; varianceMagnitudeBus = 1e-3)
```
"""
function addPmu!(system::PowerSystem, device::Measurement, analysis::AC;
    varianceMagnitudeBus::T = missing, varianceAngleBus::T = missing,
    statusMagnitudeBus::T = missing, statusAngleBus::T = missing,
    varianceMagnitudeFrom::T = missing, varianceAngleFrom::T = missing,
    statusMagnitudeFrom::T = missing, statusAngleFrom::T = missing,
    varianceMagnitudeTo::T = missing, varianceAngleTo::T = missing,
    statusMagnitudeTo::T = missing, statusAngleTo::T = missing)

    if isempty(analysis.voltage.magnitude)
        throw(ErrorException("The voltages cannot be found."))
    end
    if isempty(analysis.current.from.magnitude)
        throw(ErrorException("The currents cannot be found."))
    end

    pmu = device.pmu
    default = template.pmu

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

        pmu.magnitude.variance[i] = topu(varianceMagnitudeBus, default.varianceMagnitudeBus, prefix.voltageMagnitude, prefixInv / system.base.voltage.value[i])
        pmu.magnitude.mean[i] = analysis.voltage.magnitude[i] + pmu.magnitude.variance[i]^(1/2) * randn(1)[1]
        pmu.magnitude.status[i] = statusMagnitudeBus

        pmu.angle.variance[i] = topu(varianceAngleBus, default.varianceAngleBus, prefix.voltageAngle, 1.0)
        pmu.angle.mean[i] = analysis.voltage.angle[i] + pmu.angle.variance[i]^(1/2) * randn(1)[1]
        pmu.angle.status[i] = statusAngleBus
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for (label, i) in system.branch.label
        if system.branch.layout.status[i] == 1
            pmu.number += 1
            setLabel(pmu, missing, default.label, label; prefix = "From ")
        
            pmu.layout.index[pmu.number] = i
            pmu.layout.from[pmu.number] = true
        
            baseVoltage = system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix
            baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

            pmu.magnitude.variance[pmu.number] = topu(varianceMagnitudeFrom, default.varianceMagnitudeFrom, prefix.currentMagnitude, baseCurrentInv)
            pmu.magnitude.mean[pmu.number] = analysis.current.from.magnitude[i] + pmu.magnitude.variance[pmu.number]^(1/2) * randn(1)[1]
            pmu.magnitude.status[pmu.number] = statusMagnitudeFrom

            pmu.angle.variance[pmu.number] = topu(varianceAngleFrom, default.varianceAngleFrom, prefix.currentAngle, 1.0)
            pmu.angle.mean[pmu.number] = analysis.current.from.angle[i] + pmu.angle.variance[pmu.number]^(1/2) * randn(1)[1]
            pmu.angle.status[pmu.number] = statusAngleFrom

            pmu.number += 1
            setLabel(pmu, missing, default.label, label; prefix = "To ")

            pmu.layout.index[pmu.number] = i
            pmu.layout.to[pmu.number] = true
        
            baseVoltage = system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix
            baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

            pmu.magnitude.variance[pmu.number] = topu(varianceMagnitudeTo, default.varianceMagnitudeTo, prefix.currentMagnitude, baseCurrentInv)
            pmu.magnitude.mean[pmu.number] = analysis.current.to.magnitude[i] + pmu.magnitude.variance[pmu.number]^(1/2) * randn(1)[1]
            pmu.magnitude.status[pmu.number] = statusMagnitudeTo

            pmu.angle.variance[pmu.number] = topu(varianceAngleTo, default.varianceAngleTo, prefix.currentAngle, 1.0)
            pmu.angle.mean[pmu.number] = analysis.current.to.angle[i] + pmu.angle.variance[pmu.number]^(1/2) * randn(1)[1]
            pmu.angle.status[pmu.number] = statusAngleTo
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

function updatePmu!(system::PowerSystem, device::Measurement, analysis::DCStateEstimationWLS; 
    label::L, magnitude::T = missing, angle::T = missing, varianceMagnitude::T = missing,
    varianceAngle::T = missing, statusMagnitude::T = missing, statusAngle::T = missing,
    noise::Bool = template.pmu.noise)

    pmu = device.pmu
    method = analysis.method

    indexPmu = pmu.label[getLabel(pmu, label, "PMU")]
    oldStatus = pmu.angle.status[indexPmu]
    oldVariance = pmu.angle.variance[indexPmu]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle, 
    statusMagnitude, statusAngle, noise)

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

function updatePmu!(system::PowerSystem, device::Measurement, analysis::DCStateEstimationLAV; 
    label::L, magnitude::T = missing, angle::T = missing, varianceMagnitude::T = missing,
    varianceAngle::T = missing, statusMagnitude::T = missing, statusAngle::T = missing,
    noise::Bool = template.pmu.noise)

    pmu = device.pmu
    method = analysis.method

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle, 
    statusMagnitude, statusAngle, noise)

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

function updatePmu!(system::PowerSystem, device::Measurement, analysis::PMUStateEstimationWLS; 
    label::L, magnitude::T = missing, angle::T = missing, varianceMagnitude::T = missing,
    varianceAngle::T = missing, statusMagnitude::T = missing, statusAngle::T = missing,
    noise::Bool = template.pmu.noise)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    method = analysis.method
    index = pmu.label[getLabel(pmu, label, "PMU")]  
    statusOld = pmu.magnitude.status[index] & pmu.angle.status[index]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle, 
    statusMagnitude, statusAngle, noise)

    statusNew = pmu.magnitude.status[index] & pmu.angle.status[index]
    mean = isset(magnitude) || isset(angle)
    variance = isset(varianceMagnitude) || isset(varianceAngle)
    cosAngle = cos(pmu.angle.mean[index])
    sinAngle = sin(pmu.angle.mean[index])
    rowIndexRe = 2 * index - 1

    if mean || variance
        varianceRe = pmu.magnitude.variance[index] * cosAngle^2 + pmu.angle.variance[index] * (pmu.magnitude.mean[index] * sinAngle)^2
        varianceIm = pmu.magnitude.variance[index] * sinAngle^2 + pmu.angle.variance[index] * (pmu.magnitude.mean[index] * cosAngle)^2

        if method.correlated
            covariance = sinAngle * cosAngle * (pmu.magnitude.variance[index] - pmu.angle.variance[index] * pmu.magnitude.mean[index]^2)
            invCovarianceBlock!(method.precision, varianceRe, varianceIm, covariance, rowIndexRe)
        else
            method.precision.nzval[rowIndexRe] = 1 / varianceRe
            method.precision.nzval[rowIndexRe + 1] = 1 / varianceIm
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

function updatePmu!(system::PowerSystem, device::Measurement, analysis::PMUStateEstimationLAV; 
    label::L, magnitude::T = missing, angle::T = missing, varianceMagnitude::T = missing,
    varianceAngle::T = missing, statusMagnitude::T = missing, statusAngle::T = missing,
    noise::Bool = template.pmu.noise)

    bus = system.bus
    branch = system.branch
    ac = system.model.ac
    pmu = device.pmu
    method = analysis.method
    index = pmu.label[getLabel(pmu, label, "PMU")]  
    statusOld = pmu.magnitude.status[index] & pmu.angle.status[index]

    updatePmu!(system, device; label, magnitude, angle, varianceMagnitude, varianceAngle, 
    statusMagnitude, statusAngle, noise)

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

"""
    @pmu(label, varianceMagnitudeBus, statusMagnitudeBus, varianceAngleBus, statusAngleBus,
        varianceMagnitudeFrom, statusMagnitudeFrom, varianceAngleFrom, statusAngleFrom,
        varianceMagnitudeTo, statusMagnitudeTo, varianceAngleTo, statusAngleTo, noise)

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
addPmu!(system, device; bus = "Bus 1", magnitude = 1.1, angle = -0.1, noise = false)
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
addPmu!(system, device; bus = "Bus 1", magnitude = 145.2, angle = -5.73, noise = false)
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