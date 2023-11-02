"""
    status!(system::PowerSystem, device::Measurement; inservice, outservice, redundancy)

The function generates a set of measurements, assigning measurement devices randomly to 
either in-service or out-of-service states based on specified keywords.
    
# Keywords
These keywords allow the user to configure the measurement set as follows:
* `inservice`: sets the number of in-service devices;
* `outservice`: sets the number of out-of-service devices;
* `redundancy`: determines in-service devices based on redundancy.

If a user employs multiple keywords for configuration, only the first keyword in the 
hierarchical order will be considered, and the other keywords will be disregarded.

# Updates
The function updates all the `status` fields within the `Measurement` composite type.

# Examples
Creating a measurement set with a specific number of in-service devices:
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
power!(system, analysis)

device = measurement()

addVoltmeter!(system, device, analysis)
addWattmeter!(system, device, analysis)

status!(system, device; inservice = 30)
```

Creating a measurement set using redundancy:
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
power!(system, analysis)

device = measurement()

addVoltmeter!(system, device, analysis)
addWattmeter!(system, device, analysis)
addVarmeter!(system, device, analysis)

status!(system, device; redundancy = 2.5)
```
"""
function status!(system::PowerSystem, device::Measurement;
    inservice::S = missing, outservice::S = missing, redundancy::T = missing)

    if isset(inservice) 
        statusAll(device, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(device, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundacyAll(device, system.bus.number, redundancy)
    end
end

"""
    statusVoltmeter!(system::PowerSystem, device::Measurement; inservice, outservice, 
        redundancy)

The function generates a set of voltmeters, assigning voltmeters randomly to either 
in-service or out-of-service states based on specified keywords.
    
# Keywords
These keywords allow the user to configure the voltmeter set as follows:
* `inservice`: sets the number of in-service devices;
* `outservice`: sets the number of out-of-service devices;
* `redundancy`: determines in-service devices based on redundancy.

If a user employs multiple keywords for configuration, only the first keyword in the 
hierarchical order will be considered, and the other keywords will be disregarded.

# Updates
The function updates the `status` field within the `Voltmeter` composite type.

# Examples
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

addVoltmeter!(system, device, analysis)
statusVoltmeter!(system, device; inservice = 10)
```
"""
function statusVoltmeter!(system::PowerSystem, device::Measurement;
    inservice::S = missing, outservice::S = missing, redundancy::T = missing)

    voltmeter = device.voltmeter
    if isset(inservice) 
        statusAll(voltmeter.magnitude.status, voltmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice)
        statusAll(voltmeter.magnitude.status, voltmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy)
        redundancyAll(voltmeter.magnitude.status, voltmeter.number, system.bus.number, redundancy)
    end
end

"""
    statusAmmeter!(system::PowerSystem, ammeter::Ammeter; inservice, inserviceFrom, 
        inserviceTo, outservice, outserviceFrom, outserviceTo, redundancy, redundancyFrom, 
        redundancyTo)

The function generates a set of ammeters, assigning ammeters randomly to either in-service 
or out-of-service states based on specified keywords.
    
# Keywords
These keywords allow the user to configure the ammeter set as follows:
* `inservice`: sets the number of in-service ammeters or allows fine-tuning:
  * `inserviceFrom`: sets only ammeters loacted at the "from" bus end;
  * `inserviceTo`: sets only ammeters loacted at the "to" bus end;
* `outservice`: sets the number of out-of-service ammeters or allows fine-tuning:
  * `outserviceFrom`: sets only ammeters loacted at the "from" bus end;
  * `outserviceTo`: sets only ammeters loacted at the "to" bus end;
* `redundancy`: determines in-service ammeters based on redundancy or allows fine-tuning:
  * `redundancyFrom`: determines only ammeters loacted at the "from" bus end;
  * `redundancyTo`: determines only ammeters loacted at the "to" bus end.
 
In case a user employs multiple keywords from the set `inservice`, `outservice`, and 
`redundancy`, only the first keyword in the hierarchical order will be taken into 
consideration, and the remaining keywords will be ignored. Furthermore, in this scenario, 
all fine-tuning keywords will not be considered.

If a user chooses fine-tuning without specifying any of the primary keywords, only one 
keyword from each of the two sets will be executed, and the remaining keywords within each 
set will be ignored. These sets are as follows:
* `inserviceFrom`, `outserviceFrom`, `redundancyFrom`;
* `inserviceTo`, `outserviceTo`, `redundancyTo`.

# Updates
The function updates the `status` field within the `Ammeter` composite type.

# Examples
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

addAmmeter!(system, device, analysis)
statusAmmeter!(system, device; inserviceFrom = 5, inserviceTo = 10)
```
"""
function statusAmmeter!(system::PowerSystem, device::Measurement;
    inservice::S = missing, inserviceFrom::S = missing, inserviceTo::S = missing, 
    outservice::S = missing, outserviceFrom::S = missing, outserviceTo::S = missing, 
    redundancy::T = missing, redundancyFrom::T = missing, redundancyTo::T = missing)

    ammeter = device.ammeter
    if isset(inservice) 
        statusAll(ammeter.magnitude.status, ammeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice) 
        statusAll(ammeter.magnitude.status, ammeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy) 
        redundancyAll(ammeter.magnitude.status, ammeter.number, system.bus.number, redundancy)
    else
        if isset(inserviceFrom)
            statusLocation(ammeter.magnitude.status, ammeter.layout.from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(ammeter.magnitude.status, ammeter.layout.from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(ammeter.magnitude.status, ammeter.layout.from, system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(ammeter.magnitude.status, ammeter.layout.to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(ammeter.magnitude.status, ammeter.layout.to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(ammeter.magnitude.status, ammeter.layout.to, system.bus.number, redundancyTo)
        end
    end
end

"""
    statusWattmeter!(system::PowerSystem, device::Measurement; inservice, inserviceBus, 
        inserviceFrom, inserviceTo, outservice, outserviceBus outserviceFrom, outserviceTo, 
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of wattmeters, assigning wattmeters randomly to either 
in-service or out-of-service states based on specified keywords.
    
# Keywords
These keywords allow the user to configure the wattmeter set as follows:
* `inservice`: sets the number of in-service wattmeters or allows fine-tuning:
  * `inserviceBus`: sets only wattmeters loacted at the bus;
  * `inserviceFrom`: sets only wattmeters loacted at the "from" bus end;
  * `inserviceTo`: sets only wattmeters loacted at the "to" bus end;
* `outservice`: sets the number of out-of-service wattmeters or allows fine-tuning:
  * `outserviceBus`: sets only wattmeters loacted at the bus;
  * `outserviceFrom`: sets only wattmeters loacted at the "from" bus end;
  * `outserviceTo`: sets only wattmeters loacted at the "to" bus end;
* `redundancy`: determines in-service wattmeters based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only wattmeters loacted at the bus;
  * `redundancyFrom`: determines only wattmeters loacted at the "from" bus end;
  * `redundancyTo`: determines only wattmeters loacted at the "to" bus end.

In case a user employs multiple keywords from the set `inservice`, `outservice`, and 
`redundancy`, only the first keyword in the hierarchical order will be taken into 
consideration, and the remaining keywords will be ignored. Furthermore, in this scenario, 
all fine-tuning keywords will not be considered.
  
If a user chooses fine-tuning without specifying any of the primary keywords, only one 
keyword from each of the three sets will be executed, and the remaining keywords within 
each set will be ignored. These sets are as follows:
* `inserviceBus`, `outserviceBus`, `redundancyBus`;
* `inserviceFrom`, `outserviceFrom`, `redundancyFrom`;
* `inserviceTo`, `outserviceTo`, `redundancyTo`.

# Updates
The function updates the `status` field within the `Wattmeter` composite type.

# Examples
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
power!(system, analysis)

device = measurement()

addWattmeter!(system, device, analysis)
statusWattmeter!(system, device; outserviceBus = 14, inserviceFrom = 10, outserviceTo = 2)
```
"""
function statusWattmeter!(system::PowerSystem, device::Measurement;
    inservice::S = missing, inserviceBus::S = missing, inserviceFrom::S = missing, inserviceTo::S = missing, 
    outservice::S = missing, outserviceBus::S = missing, outserviceFrom::S = missing, outserviceTo::S = missing, 
    redundancy::T = missing, redundancyBus::T = missing, redundancyFrom::T = missing, redundancyTo::T = missing)

    wattmeter = device.wattmeter
    if isset(inservice) 
        statusAll(wattmeter.active.status, wattmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice) 
        statusAll(wattmeter.active.status, wattmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy) 
        redundancyAll(wattmeter.active.status, wattmeter.number, system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(wattmeter.active.status, wattmeter.layout.bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(wattmeter.active.status, wattmeter.layout.bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(wattmeter.active.status, wattmeter.layout.bus, system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(wattmeter.active.status, wattmeter.layout.from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(wattmeter.active.status, wattmeter.layout.from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(wattmeter.active.status, wattmeter.layout.from, system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(wattmeter.active.status, wattmeter.layout.to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(wattmeter.active.status, wattmeter.layout.to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(wattmeter.active.status, wattmeter.layout.to, system.bus.number, redundancyTo)
        end
    end 
end

"""
    statusVarmeter!(system::PowerSystem, device::Measurement; inservice, inserviceBus, 
        inserviceFrom, inserviceTo, outservice, outserviceBus outserviceFrom, outserviceTo, 
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of varmeters, assigning varmeters randomly to either 
in-service or out-of-service states based on specified keywords.
    
# Keywords
These keywords allow the user to configure the varmeter set as follows:
* `inservice`: sets the number of in-service varmeters or allows fine-tuning:
  * `inserviceBus`: sets only varmeters loacted at the bus;
  * `inserviceFrom`: sets only varmeters loacted at the "from" bus end;
  * `inserviceTo`: sets only varmeters loacted at the "to" bus end;
* `outservice`: sets the number of out-of-service varmeters or allows fine-tuning:
  * `outserviceBus`: sets only varmeters loacted at the bus;
  * `outserviceFrom`: sets only varmeters loacted at the "from" bus end;
  * `outserviceTo`: sets only varmeters loacted at the "to" bus end;
* `redundancy`: determines in-service varmeters based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only varmeters loacted at the bus;
  * `redundancyFrom`: determines only varmeters loacted at the "from" bus end;
  * `redundancyTo`: determines only varmeters loacted at the "to" bus end.

In case a user employs multiple keywords from the set `inservice`, `outservice`, and 
`redundancy`, only the first keyword in the hierarchical order will be taken into 
consideration, and the remaining keywords will be ignored. Furthermore, in this scenario, 
all fine-tuning keywords will not be considered.
  
If a user chooses fine-tuning without specifying any of the primary keywords, only one 
keyword from each of the three sets will be executed, and the remaining keywords within 
each set will be ignored. These sets are as follows:
* `inserviceBus`, `outserviceBus`, `redundancyBus`;
* `inserviceFrom`, `outserviceFrom`, `redundancyFrom`;
* `inserviceTo`, `outserviceTo`, `redundancyTo`.

# Updates
The function updates the `status` field within the `Varmeter` composite type.

# Examples
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
power!(system, analysis)

device = measurement()

addVarmeter!(system, device, analysis)
statusVarmeter!(system, device; inserviceFrom = 20)
```
"""
function statusVarmeter!(system::PowerSystem, device::Measurement;
    inservice::S = missing, inserviceBus::S = missing, inserviceFrom::S = missing, inserviceTo::S = missing, 
    outservice::S = missing, outserviceBus::S = missing, outserviceFrom::S = missing, outserviceTo::S = missing, 
    redundancy::T = missing, redundancyBus::T = missing, redundancyFrom::T = missing, redundancyTo::T = missing)

    varmeter = device.varmeter
    if isset(inservice) 
        statusAll(varmeter.reactive.status, varmeter.number, inservice; initial = 0, final = 1)
    elseif isset(outservice) 
        statusAll(varmeter.reactive.status, varmeter.number, outservice; initial = 1, final = 0)
    elseif isset(redundancy) 
        redundancyAll(varmeter.reactive.status, varmeter.number, system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(varmeter.reactive.status, varmeter.layout.bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(varmeter.reactive.status, varmeter.layout.bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(varmeter.reactive.status, varmeter.layout.bus, system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(varmeter.reactive.status, varmeter.layout.from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(varmeter.reactive.status, varmeter.layout.from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(varmeter.reactive.status, varmeter.layout.from, system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(varmeter.reactive.status, varmeter.layout.to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(varmeter.reactive.status, varmeter.layout.to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(varmeter.reactive.status, varmeter.layout.to, system.bus.number, redundancyTo)
        end
    end 
end

"""
    statusPmu!(system::PowerSystem, device::Measurement; inservice, inserviceBus, 
        inserviceFrom, inserviceTo, outservice, outserviceBus outserviceFrom, outserviceTo, 
        redundancy, redundancyBus, redundancyFrom, redundancyTo)

The function generates a set of PMUs, assigning PMUs randomly to either in-service or 
out-of-service states based on specified keywords. It is important to note that when we 
refer to PMU, we encompass both magnitude and angle measurements.
    
# Keywords
These keywords allow the user to configure the PMU set as follows:
* `inservice`: sets the number of in-service PMUs or allows fine-tuning:
  * `inserviceBus`: sets only PMUs loacted at the bus;
  * `inserviceFrom`: sets only PMUs loacted at the "from" bus end;
  * `inserviceTo`: sets only PMUs loacted at the "to" bus end;
* `outservice`: sets the number of out-of-service PMUs or allows fine-tuning:
  * `outserviceBus`: sets only PMUs loacted at the bus;
  * `outserviceFrom`: sets only PMUs loacted at the "from" bus end;
  * `outserviceTo`: sets only PMUs loacted at the "to" bus end;
* `redundancy`: determines in-service PMUs based on redundancy or allows fine-tuning:
  * `redundancyBus`: determines only PMUs loacted at the bus;
  * `redundancyFrom`: determines only PMUs loacted at the "from" bus end;
  * `redundancyTo`: determines only PMUs loacted at the "to" bus end.

In case a user employs multiple keywords from the set `inservice`, `outservice`, and 
`redundancy`, only the first keyword in the hierarchical order will be taken into 
consideration, and the remaining keywords will be ignored. Furthermore, in this scenario, 
all fine-tuning keywords will not be considered.
  
If a user chooses fine-tuning without specifying any of the primary keywords, only one 
keyword from each of the three sets will be executed, and the remaining keywords within 
each set will be ignored. These sets are as follows:
* `inserviceBus`, `outserviceBus`, `redundancyBus`;
* `inserviceFrom`, `outserviceFrom`, `redundancyFrom`;
* `inserviceTo`, `outserviceTo`, `redundancyTo`.

# Updates
The function updates the `status` fields within the `PMU` composite type.

# Examples
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

addPmu!(system, device, analysis)
statusPmu!(system, device; inserviceBus = 14)
```
"""
function statusPmu!(system::PowerSystem, device::Measurement;
    inservice::S = missing, inserviceBus::S = missing, inserviceFrom::S = missing, inserviceTo::S = missing, 
    outservice::S = missing, outserviceBus::S = missing, outserviceFrom::S = missing, outserviceTo::S = missing, 
    redundancy::T = missing, redundancyBus::T = missing, redundancyFrom::T = missing, redundancyTo::T = missing)

    pmu = device.pmu
    if isset(inservice) 
        statusAll(pmu, inservice; initial = 0, final = 1)
    elseif isset(outservice) 
        statusAll(pmu, outservice; initial = 1, final = 0)
    elseif isset(redundancy) 
        redundancyAll(pmu, system.bus.number, redundancy)
    else
        if isset(inserviceBus)
            statusLocation(pmu, pmu.layout.bus, inserviceBus; initial = 0, final = 1)
        elseif isset(outserviceBus)
            statusLocation(pmu, pmu.layout.bus, outserviceBus; initial = 1, final = 0)
        elseif isset(redundancyBus)
            redundancyLocation(pmu, pmu.layout.bus, system.bus.number, redundancyBus)
        end

        if isset(inserviceFrom)
            statusLocation(pmu, pmu.layout.from, inserviceFrom; initial = 0, final = 1)
        elseif isset(outserviceFrom)
            statusLocation(pmu, pmu.layout.from, outserviceFrom; initial = 1, final = 0)
        elseif isset(redundancyFrom)
            redundancyLocation(pmu, pmu.layout.from, system.bus.number, redundancyFrom)
        end

        if isset(inserviceTo)
            statusLocation(pmu, pmu.layout.to, inserviceTo; initial = 0, final = 1)
        elseif isset(outserviceTo)
            statusLocation(pmu, pmu.layout.to, outserviceTo; initial = 1, final = 0)
        elseif isset(redundancyTo)
            redundancyLocation(pmu, pmu.layout.to, system.bus.number, redundancyTo)
        end
    end  
end

function statusAll(status::Array{Int8,1}, numberDevice::Int64, service::S; initial::Int64, final::Int64)
    if service > numberDevice
        throw(ErrorException("The total number of available devices is less than the requested number for a status change."))
    end

    indices = randperm(numberDevice)[1:service]
    status .= initial
    status[indices] .= final
end

function statusAll(pmu::PMU, service::S; initial::Int64, final::Int64)
    if service > pmu.number
        throw(ErrorException("The total number of available devices is less than the requested number for a status change."))
    end

    indices = randperm(pmu.number)[1:service]

    @inbounds for i = 1:pmu.number
        pmu.magnitude.status[i] = initial
        pmu.angle.status[i] = initial
    end

    @inbounds for i in indices
        pmu.magnitude.status[i] = final
        pmu.angle.status[i] = final
    end
end

function statusAll(device::Measurement, service::S; initial::Int64, final::Int64)
    voltmeter = device.voltmeter
    ammeter = device.ammeter
    wattmeter = device.wattmeter
    varmeter = device.varmeter
    pmu = device.pmu

    indices = [fill(1, voltmeter.number) collect(1:voltmeter.number); 
       fill(2, ammeter.number) collect(1:ammeter.number);
       fill(3, wattmeter.number) collect(1:wattmeter.number);
       fill(4, varmeter.number) collect(1:varmeter.number);
       fill(5, pmu.number) collect(1:pmu.number)] 

    indices = indices[shuffle(1:end), :]
    indices = indices[1:service, :]

    voltmeter.magnitude.status .= initial
    ammeter.magnitude.status .= initial
    wattmeter.active.status .= initial
    varmeter.reactive.status .= initial
    pmu.magnitude.status .= initial
    pmu.angle.status .= initial

    for row in eachrow(indices)
        if row[1] == 1
            voltmeter.magnitude.status[row[2]] = final
        elseif row[1] == 2
            ammeter.magnitude.status[row[2]] = final
        elseif row[1] == 3
            wattmeter.active.status[row[2]] = final
        elseif row[1] == 4
            varmeter.reactive.status[row[2]] = final
        else
            pmu.magnitude.status[row[2]] = final
            pmu.angle.status[row[2]] = final
        end
    end
end

function statusLocation(status::Array{Int8,1}, location::Array{Bool,1}, service::S; initial::Int64, final::Int64)
    indices = findall(x->x==true, location)
    if service > length(indices)
        throw(ErrorException("The total number of available devices is less than the requested number for a status change."))
    end

    status[indices] .= initial
    shuffle!(indices)
    status[indices[1:service]] .= final
end

function statusLocation(pmu::PMU, location::Array{Bool,1}, service::S; initial::Int64, final::Int64)
    indices = findall(x->x==true, location)
    if service > length(indices)
        throw(ErrorException("The total number of available devices is less than the requested number for a status change."))
    end

    @inbounds for i in indices
        pmu.magnitude.status[i] = initial
        pmu.angle.status[i] = initial
    end

    shuffle!(indices)
    @inbounds for i in indices[1:service]
        pmu.magnitude.status[i] = final
        pmu.angle.status[i] = final
    end
end

function redundancyAll(status::Array{Int8,1}, numberDevice::Int64, busNumber::Int64, redundancy::T)
    maxRedundancy = numberDevice / (2 * busNumber - 1)
    if redundancy > maxRedundancy 
        redundancy = maxRedundancy
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    indices = randperm(numberDevice)[1:trunc(Int64, round(measurementNumber))]
    status .= 0
    status[indices] .= 1
end

function redundancyAll(pmu::PMU, busNumber::Int64, redundancy::T)
    maxRedundancy = pmu.number / (2 * busNumber - 1)
    if redundancy > maxRedundancy 
        redundancy = maxRedundancy
    end

    @inbounds for i = 1:pmu.number
        pmu.magnitude.status[i] = 0
        pmu.angle.status[i] = 0
    end

    measurementNumber = redundancy * (2 * busNumber - 1)
    indices = randperm(pmu.number)[1:trunc(Int64, round(measurementNumber))]
    @inbounds for i in indices
        pmu.magnitude.status[i] = 1
        pmu.angle.status[i] = 1
    end
end

function redundacyAll(device::Measurement, busNumber::Int64, redundancy::T)
    voltmeter = device.voltmeter
    ammeter = device.ammeter
    wattmeter = device.wattmeter
    varmeter = device.varmeter
    pmu = device.pmu

    numberDevice = voltmeter.number + ammeter.number + wattmeter.number + varmeter.number + pmu.number
    maxRedundancy = numberDevice / (2 * busNumber - 1)
    if redundancy > maxRedundancy 
        redundancy = maxRedundancy
    end
    measurementNumber = redundancy * (2 * busNumber - 1)

    indices = [fill(1, voltmeter.number) collect(1:voltmeter.number); 
       fill(2, ammeter.number) collect(1:ammeter.number);
       fill(3, wattmeter.number) collect(1:wattmeter.number);
       fill(4, varmeter.number) collect(1:varmeter.number);
       fill(5, pmu.number) collect(1:pmu.number)] 

    indices = indices[shuffle(1:end), :]
    indices = indices[1:trunc(Int64, round(measurementNumber)), :]

    voltmeter.magnitude.status .= 0
    ammeter.magnitude.status .= 0
    wattmeter.active.status .= 0
    varmeter.reactive.status .= 0
    pmu.magnitude.status .= 0
    pmu.angle.status .= 0

    for row in eachrow(indices)
        if row[1] == 1
            voltmeter.magnitude.status[row[2]] = 1
        elseif row[1] == 2
            ammeter.magnitude.status[row[2]] = 1
        elseif row[1] == 3
            wattmeter.active.status[row[2]] = 1
        elseif row[1] == 4
            varmeter.reactive.status[row[2]] = 1
        else
            pmu.magnitude.status[row[2]] = 1
            pmu.angle.status[row[2]] = 1
        end
    end
end

function redundancyLocation(status, location::Array{Bool,1}, busNumber::Int64, redundancy::T)
    indices = findall(x->x==true, location)
    numberDevice = length(indices)
    maxRedundancy = numberDevice / (2 * busNumber - 1)
    if redundancy > maxRedundancy 
        redundancy = maxRedundancy
    end
    status[indices] .= 0

    measurementNumber = redundancy * (2 * busNumber - 1)
    shuffle!(indices)
    status[indices[1:trunc(Int64, round(measurementNumber))]] .= 1
end

function redundancyLocation(pmu::PMU, location::Array{Bool,1}, busNumber::Int64, redundancy::T)
    indices = findall(x->x==true, location)
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
    @inbounds for i in indices[1:trunc(Int64, round(measurementNumber))]
        pmu.magnitude.status[i] = 1
        pmu.angle.status[i] = 1
    end
end