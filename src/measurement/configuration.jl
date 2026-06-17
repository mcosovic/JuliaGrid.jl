"""
    status!(monitoring::Measurement; inservice, outservice, redundancy)

The function generates a set of measurements, assigning measurement devices randomly to either
in-service or out-of-service states based on specified keywords.

# Keywords
Only one of the following keywords can be used at a time to configure the measurement set:
* `inservice`: Sets the number of in-service devices.
* `outservice`: Sets the number of out-of-service devices.
* `redundancy`: Determines in-service devices based on redundancy.

# Updates
The function updates all the `status` fields within the `Measurement` type.

# Examples
Creating a measurement set with a specific number of in-service devices:
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

addVoltmeter!(monitoring, analysis)
addWattmeter!(monitoring, analysis)

status!(monitoring; inservice = 30)
```

Creating a measurement set using redundancy:
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

addVoltmeter!(monitoring, analysis)
addWattmeter!(monitoring, analysis)
addVarmeter!(monitoring, analysis)

status!(monitoring; redundancy = 2.5)
```
"""
function status!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    outservice::IntMiss = missing,
    redundancy::FltIntMiss = missing
)
    if isset(inservice)
        statusAll(monitoring, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(monitoring, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(monitoring, monitoring.system.bus.number, redundancy)
    end
end

"""
    statusVoltmeter!(monitoring::Measurement; inservice, outservice, redundancy)

The function generates a set of voltmeters, assigning voltmeters randomly to either in-service or
out-of-service states based on specified keywords.

# Keywords
Only one of the following keywords can be used at a time to configure the measurement set:
* `inservice`: Sets the number of in-service voltmeters.
* `outservice`: Sets the number of out-of-service voltmeters.
* `redundancy`: Determines in-service voltmeters based on redundancy.

# Updates
The function updates the `status` field within the `Voltmeter` type.

# Example
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis)

addVoltmeter!(monitoring, analysis)

statusVoltmeter!(monitoring; inservice = 10)
```
"""
function statusVoltmeter!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    outservice::IntMiss = missing,
    redundancy::FltIntMiss = missing
)
    status = monitoring.voltmeter.magnitude.status

    if isset(inservice)
        statusAll(status, monitoring.voltmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(status, monitoring.voltmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(status, monitoring.voltmeter.number, monitoring.system.bus.number, redundancy)
    end
end

"""
    statusAmmeter!(monitoring::Measurement;
        inservice, inserviceFrom, inserviceTo,
        outservice, outserviceFrom, outserviceTo,
        redundancy, redundancyFrom, redundancyTo)

The function generates a set of ammeters, assigning ammeters randomly to either in-service or
out-of-service states based on specified keywords.

# Keywords
Users can use one main keyword or two fine-tuning keywords to specify distinct locations per
function call:
* `inservice`: Sets the number of in-service ammeters or allows fine-tuning:
  * `inserviceFrom`: sets only ammeters located at the from-bus end,
  * `inserviceTo`: sets only ammeters located at the to-bus end.
* `outservice`: Sets the number of out-of-service ammeters or allows fine-tuning:
  * `outserviceFrom`: sets only ammeters located at the from-bus end,
  * `outserviceTo`: sets only ammeters located at the to-bus end.
* `redundancy`: Determines in-service ammeters based on redundancy or allows fine-tuning:
  * `redundancyFrom`: determines only ammeters located at the from-bus end,
  * `redundancyTo`: determines only ammeters located at the to-bus end.

# Updates
The function updates the `status` field within the `Ammeter` type.

# Example
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; current = true)

addAmmeter!(monitoring, analysis)

statusAmmeter!(monitoring; inserviceFrom = 5, inserviceTo = 10)
```
"""
function statusAmmeter!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    inserviceFrom::IntMiss = missing,
    inserviceTo::IntMiss = missing,
    outservice::IntMiss = missing,
    outserviceFrom::IntMiss = missing,
    outserviceTo::IntMiss = missing,
    redundancy::FltIntMiss = missing,
    redundancyFrom::FltIntMiss = missing,
    redundancyTo::FltIntMiss = missing
)
    status = monitoring.ammeter.magnitude.status
    from = monitoring.ammeter.layout.from
    to = monitoring.ammeter.layout.to

    if isset(inservice)
        statusAll(status, monitoring.ammeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(status, monitoring.ammeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(status, monitoring.ammeter.number, monitoring.system.bus.number, redundancy)
    else
        if isset(inserviceFrom)
            statusLocation(status, from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(status, from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(status, from, monitoring.system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(status, to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(status, to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(status, to, monitoring.system.bus.number, redundancyTo)
        end
    end
end

"""
    statusWattmeter!(monitoring::Measurement;
        inservice, inserviceBus, inserviceFrom, inserviceTo,
        outservice, outserviceBus, outserviceFrom, outserviceTo,
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of wattmeters, assigning wattmeters randomly to either in-service or
out-of-service states based on specified keywords.

# Keywords
Users can use one main keyword or three fine-tuning keywords to specify distinct locations per
function call:
* `inservice`: Sets the number of in-service wattmeters or allows fine-tuning:
  * `inserviceBus`: sets only wattmeters located at the bus,
  * `inserviceFrom`: sets only wattmeters located at the from-bus end,
  * `inserviceTo`: sets only wattmeters located at the to-bus end.
* `outservice`: Sets the number of out-of-service wattmeters or allows fine-tuning:
  * `outserviceBus`: sets only wattmeters located at the bus,
  * `outserviceFrom`: sets only wattmeters located at the from-bus end,
  * `outserviceTo`: sets only wattmeters located at the to-bus end.
* `redundancy`: Determines in-service wattmeters based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only wattmeters located at the bus,
  * `redundancyFrom`: determines only wattmeters located at the from-bus end,
  * `redundancyTo`: determines only wattmeters located at the to-bus end.

# Updates
The function updates the `status` field within the `Wattmeter` type.

# Example
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

addWattmeter!(monitoring, analysis)

statusWattmeter!(monitoring; outserviceBus = 14, inserviceFrom = 10, outserviceTo = 2)
```
"""
function statusWattmeter!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    inserviceBus::IntMiss = missing,
    inserviceFrom::IntMiss = missing,
    inserviceTo::IntMiss = missing,
    outservice::IntMiss = missing,
    outserviceBus::IntMiss = missing,
    outserviceFrom::IntMiss = missing,
    outserviceTo::IntMiss = missing,
    redundancy::FltIntMiss = missing,
    redundancyBus::FltIntMiss = missing,
    redundancyFrom::FltIntMiss = missing,
    redundancyTo::FltIntMiss = missing
)
    status = monitoring.wattmeter.active.status
    bus = monitoring.wattmeter.layout.bus
    from = monitoring.wattmeter.layout.from
    to = monitoring.wattmeter.layout.to

    if isset(inservice)
        statusAll(status, monitoring.wattmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(status, monitoring.wattmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(status, monitoring.wattmeter.number, monitoring.system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(status, bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(status, bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(status, bus, monitoring.system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(status, from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(status, from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(status, from, monitoring.system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(status, to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(status, to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(status, to, monitoring.system.bus.number, redundancyTo)
        end
    end
end

"""
    statusVarmeter!(monitoring::Measurement;
        inservice, inserviceBus, inserviceFrom, inserviceTo,
        outservice, outserviceBus, outserviceFrom, outserviceTo,
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of varmeters, assigning varmeters randomly to either in-service or
out-of-service states based on specified keywords.

# Keywords
Users can use one main keyword or three fine-tuning keywords to specify distinct locations per
function call:
* `inservice`: Sets the number of in-service varmeters or allows fine-tuning:
  * `inserviceBus`: sets only varmeters located at the bus,
  * `inserviceFrom`: sets only varmeters located at the from-bus end,
  * `inserviceTo`: sets only varmeters located at the to-bus end.
* `outservice`: Sets the number of out-of-service varmeters or allows fine-tuning:
  * `outserviceBus`: sets only varmeters located at the bus,
  * `outserviceFrom`: sets only varmeters located at the from-bus end,
  * `outserviceTo`: sets only varmeters located at the to-bus end.
* `redundancy`: Determines in-service varmeters based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only varmeters located at the bus,
  * `redundancyFrom`: determines only varmeters located at the from-bus end,
  * `redundancyTo`: determines only varmeters located at the to-bus end.

# Updates
The function updates the `status` field within the `Varmeter` type.

# Example
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

addVarmeter!(monitoring, analysis)

statusVarmeter!(monitoring; inserviceFrom = 20)
```
"""
function statusVarmeter!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    inserviceBus::IntMiss = missing,
    inserviceFrom::IntMiss = missing,
    inserviceTo::IntMiss = missing,
    outservice::IntMiss = missing,
    outserviceBus::IntMiss = missing,
    outserviceFrom::IntMiss = missing,
    outserviceTo::IntMiss = missing,
    redundancy::FltIntMiss = missing,
    redundancyBus::FltIntMiss = missing,
    redundancyFrom::FltIntMiss = missing,
    redundancyTo::FltIntMiss = missing
)

    status = monitoring.varmeter.reactive.status
    bus = monitoring.varmeter.layout.bus
    from = monitoring.varmeter.layout.from
    to = monitoring.varmeter.layout.to

    if isset(inservice)
        statusAll(status, monitoring.varmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(status, monitoring.varmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(status, monitoring.varmeter.number, monitoring.system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(status, bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(status, bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(status, bus, monitoring.system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(status, from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(status, from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(status, from, monitoring.system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(status, to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(status, to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(status, to, monitoring.system.bus.number, redundancyTo)
        end
    end
end

"""
    statusPmu!(monitoring::Measurement;
        inservice, inserviceBus, inserviceFrom, inserviceTo,
        outservice, outserviceBus, outserviceFrom, outserviceTo,
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of PMUs, assigning PMUs randomly to either in-service or out-of-service
states based on specified keywords. It is important to note that when we refer to PMU, we encompass
both magnitude and angle measurements.

# Keywords
Users may use either one main keyword or three fine-tuning keywords that specify distinct locations
per function call:
* `inservice`: Sets the number of in-service PMUs or allows fine-tuning:
  * `inserviceBus`: sets only PMUs located at the bus,
  * `inserviceFrom`: sets only PMUs located at the from-bus end,
  * `inserviceTo`: sets only PMUs located at the to-bus end.
* `outservice`: Sets the number of out-of-service PMUs or allows fine-tuning:
  * `outserviceBus`: sets only PMUs located at the bus,
  * `outserviceFrom`: sets only PMUs located at the from-bus end,
  * `outserviceTo`: sets only PMUs located at the to-bus end.
* `redundancy`: Determines in-service PMUs based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only PMUs located at the bus,
  * `redundancyFrom`: determines only PMUs located at the from-bus end,
  * `redundancyTo`: determines only PMUs located at the to-bus end.

# Updates
The function updates the `status` fields within the `PMU` type.

# Example
```jldoctest
system, monitoring = ems("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; current = true)

addPmu!(monitoring, analysis)

statusPmu!(monitoring; inserviceBus = 10)
```
"""
function statusPmu!(
    monitoring::Measurement;
    inservice::IntMiss = missing,
    inserviceBus::IntMiss = missing,
    inserviceFrom::IntMiss = missing,
    inserviceTo::IntMiss = missing,
    outservice::IntMiss = missing,
    outserviceBus::IntMiss = missing,
    outserviceFrom::IntMiss = missing,
    outserviceTo::IntMiss = missing,
    redundancy::FltIntMiss = missing,
    redundancyBus::FltIntMiss = missing,
    redundancyFrom::FltIntMiss = missing,
    redundancyTo::FltIntMiss = missing
)
    pmu = monitoring.pmu

    if isset(inservice)
        statusAll(pmu, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(pmu, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(pmu, monitoring.system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(pmu, pmu.layout.bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(pmu, pmu.layout.bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(pmu, pmu.layout.bus, monitoring.system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(pmu, pmu.layout.from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(pmu, pmu.layout.from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(pmu, pmu.layout.from, monitoring.system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(pmu, pmu.layout.to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(pmu, pmu.layout.to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(pmu, pmu.layout.to, monitoring.system.bus.number, redundancyTo)
        end
    end
end

function statusAll(
    status::Vector{Int8},
    numberDevice::Int64,
    service::IntMiss;
    initial::Int64,
    final::Int64
)
    if service > numberDevice
        errorStatusDevice()
    end

    indices = randperm(numberDevice)
    status .= initial

    @inbounds for k = 1:service
        status[indices[k]] = final
    end
end

function statusAll(pmu::PMU, service::IntMiss; initial::Int64, final::Int64)
    if service > pmu.number
        errorStatusDevice()
    end

    indices = randperm(pmu.number)

    @inbounds for i = 1:pmu.number
        pmu.magnitude.status[i] = initial
        pmu.angle.status[i] = initial
    end

    @inbounds for k = 1:service
        idx = indices[k]
        pmu.magnitude.status[idx] = final
        pmu.angle.status[idx] = final
    end
end

function statusAll(monitoring::Measurement, service::IntMiss; initial::Int64, final::Int64)
    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter
    pmu = monitoring.pmu

    n = volt.number + amp.number + watt.number + var.number + pmu.number
    if service > n
        errorStatusDevice()
    end

    volt.magnitude.status .= initial
    amp.magnitude.status .= initial
    watt.active.status .= initial
    var.reactive.status .= initial
    pmu.magnitude.status .= initial
    pmu.angle.status .= initial

    ampOffset = volt.number
    wattOffset = ampOffset + amp.number
    varOffset = wattOffset + watt.number
    pmuOffset = varOffset + var.number
    indices = randperm(n)

    @inbounds for k = 1:service
        idx = indices[k]
        if idx <= ampOffset
            volt.magnitude.status[idx] = final
        elseif idx <= wattOffset
            amp.magnitude.status[idx - ampOffset] = final
        elseif idx <= varOffset
            watt.active.status[idx - wattOffset] = final
        elseif idx <= pmuOffset
            var.reactive.status[idx - varOffset] = final
        else
            idxPmu = idx - pmuOffset
            pmu.magnitude.status[idxPmu] = final
            pmu.angle.status[idxPmu] = final
        end
    end
end

function statusLocation(
    status::Vector{Int8},
    location::Vector{Bool},
    service::IntMiss;
    initial::Int64,
    final::Int64
)
    indices = findall(location)

    if service > length(indices)
        errorStatusDevice()
    end

    @inbounds for i in indices
        status[i] = initial
    end
    shuffle!(indices)

    @inbounds for k = 1:service
        status[indices[k]] = final
    end
end

function statusLocation(
    pmu::PMU,
    location::Vector{Bool},
    service::IntMiss;
    initial::Int64,
    final::Int64
)
    indices = findall(location)

    if service > length(indices)
        errorStatusDevice()
    end

    @inbounds for i in indices
        pmu.magnitude.status[i] = initial
        pmu.angle.status[i] = initial
    end

    shuffle!(indices)
    @inbounds for k = 1:service
        idx = indices[k]
        pmu.magnitude.status[idx] = final
        pmu.angle.status[idx] = final
    end
end

function redundancyAll(
    status::Vector{Int8},
    numberDevice::Int64,
    busNumber::Int64,
    redundancy::FltIntMiss
)
    maxRedundancy = numberDevice / (2 * busNumber - 1)

    if redundancy > maxRedundancy
        redundancy = maxRedundancy
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    indices = randperm(numberDevice)
    service = trunc(Int64, round(measurementNumber))
    status .= 0

    @inbounds for k = 1:service
        status[indices[k]] = 1
    end
end

function redundancyAll(pmu::PMU, busNumber::Int64, redundancy::FltIntMiss)
    maxRedundancy = pmu.number / (2 * busNumber - 1)
    if redundancy > maxRedundancy
        redundancy = maxRedundancy
    end

    @inbounds for i = 1:pmu.number
        pmu.magnitude.status[i] = 0
        pmu.angle.status[i] = 0
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    indices = randperm(pmu.number)
    service = trunc(Int64, round(measurementNumber))
    @inbounds for k = 1:service
        idx = indices[k]
        pmu.magnitude.status[idx] = 1
        pmu.angle.status[idx] = 1
    end
end

function redundancyAll(monitoring::Measurement, busNumber::Int64, redundancy::FltIntMiss)
    volt = monitoring.voltmeter
    amp = monitoring.ammeter
    watt = monitoring.wattmeter
    var = monitoring.varmeter
    pmu = monitoring.pmu

    n = volt.number + amp.number + watt.number + var.number + pmu.number
    maxRedundancy = n / (2 * busNumber - 1)
    if redundancy > maxRedundancy
        redundancy = maxRedundancy
    end
    measurementNumber = redundancy * (2 * busNumber - 1)

    volt.magnitude.status .= 0
    amp.magnitude.status .= 0
    watt.active.status .= 0
    var.reactive.status .= 0
    pmu.magnitude.status .= 0
    pmu.angle.status .= 0

    ampOffset = volt.number
    wattOffset = ampOffset + amp.number
    varOffset = wattOffset + watt.number
    pmuOffset = varOffset + var.number
    indices = randperm(n)
    service = trunc(Int64, round(measurementNumber))

    @inbounds for k = 1:service
        idx = indices[k]
        if idx <= ampOffset
            volt.magnitude.status[idx] = 1
        elseif idx <= wattOffset
            amp.magnitude.status[idx - ampOffset] = 1
        elseif idx <= varOffset
            watt.active.status[idx - wattOffset] = 1
        elseif idx <= pmuOffset
            var.reactive.status[idx - varOffset] = 1
        else
            idxPmu = idx - pmuOffset
            pmu.magnitude.status[idxPmu] = 1
            pmu.angle.status[idxPmu] = 1
        end
    end
end

function redundancyLocation(
    status::Vector{Int8},
    location::Vector{Bool},
    busNumber::Int64,
    redundancy::FltIntMiss
)
    indices = findall(location)
    numberDevice = length(indices)
    maxRedundancy = numberDevice / (2 * busNumber - 1)

    if redundancy > maxRedundancy
        redundancy = maxRedundancy
    end
    @inbounds for i in indices
        status[i] = 0
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    shuffle!(indices)
    service = trunc(Int64, round(measurementNumber))

    @inbounds for k = 1:service
        status[indices[k]] = 1
    end
end

function redundancyLocation(
    pmu::PMU,
    location::Vector{Bool},
    busNumber::Int64,
    redundancy::FltIntMiss
)
    indices = findall(location)
    numberDevice = length(indices)
    maxRedundancy = numberDevice / (2 * busNumber - 1)

    if redundancy > maxRedundancy
        redundancy = maxRedundancy
    end

    @inbounds for i in indices
        pmu.magnitude.status[i] = 0
        pmu.angle.status[i] = 0
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    shuffle!(indices)
    service = trunc(Int64, round(measurementNumber))
    @inbounds for k = 1:service
        idx = indices[k]
        pmu.magnitude.status[idx] = 1
        pmu.angle.status[idx] = 1
    end
end
