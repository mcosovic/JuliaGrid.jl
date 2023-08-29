######## Bus ##########
mutable struct MeasurementContainer
    label::Dict{Int64,Int64}
    index::Array{Int64,1}
    mean::Array{Float64,1}
    variance::Array{Float64,1}
    status::Array{Int8,1}
    number::Int64
end

mutable struct MeasurementBranch
    from::MeasurementContainer
    to::MeasurementContainer
end

mutable struct MeasurementAll
    bus::MeasurementContainer
    from::MeasurementContainer
    to::MeasurementContainer
end

mutable struct Measurement
    voltmeter::MeasurementContainer
    ammeter::MeasurementBranch
    wattmeter::MeasurementAll
    varmeter::MeasurementAll
    anglepmu::MeasurementAll
    magnitudepmu::MeasurementAll
end

function measurement()
    container = MeasurementContainer(Dict{Int64,Int64}(), Array{Int64,1}(undef, 0),
        Array{Float64,1}(undef, 0), Array{Float64,1}(undef, 0), Array{Int8,1}(undef, 0), 0)

    return Measurement(
        deepcopy(container),
        MeasurementBranch(deepcopy(container), deepcopy(container)),
        MeasurementAll(deepcopy(container), deepcopy(container), deepcopy(container)),
        MeasurementAll(deepcopy(container), deepcopy(container), deepcopy(container)),
        MeasurementAll(deepcopy(container), deepcopy(container), deepcopy(container)),
        MeasurementAll(deepcopy(container), deepcopy(container), deepcopy(container))
    )
end

macro voltmeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = kwarg.args[1]
        value::Float64 = Float64(eval(kwarg.args[2]))
        
        if hasfield(VoltmeterTemplate, parameter)
            if parameter == :variance
                container::ContainerTemplate = getfield(template.voltmeter, parameter)
                if prefix.voltageMagnitude != 0.0
                    setfield!(container, :value, prefix.voltageMagnitude * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            elseif parameter == :status
                setfield!(template.voltmeter, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addVoltmeter!(system::PowerSystem, device::Measurement;
    label::T = missing, bus::N, mean::T = missing, variance::T = missing,
    exact::T = missing, status::T = missing)

    voltmeter = device.voltmeter
    default = template.voltmeter
    
    checkLabel(system.bus, bus, "bus")
    checkMeanExact(mean, exact)

    voltmeter.number += 1
    setLabel(voltmeter, label)

    push!(voltmeter.status, unitless(status, default.status))
    checkStatus(voltmeter.status[end])
    
    index = system.bus.label[bus]
    push!(voltmeter.index, index)

    baseVoltageInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
    push!(voltmeter.variance, topu(variance, default.variance, baseVoltageInv, prefix.voltageMagnitude))
   
    if ismissing(mean)
        mean = topu(exact, baseVoltageInv, prefix.voltageMagnitude) + voltmeter.variance[end]^(1/2) * randn(1)[1]
    else
        mean = topu(mean, baseVoltageInv, prefix.voltageMagnitude)
    end
    push!(voltmeter.mean, mean)
end

function addVoltmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, status::T = missing)

    voltmeter = device.voltmeter
    default = template.voltmeter

    status = unitless(status, default.status)
    checkStatus(status)

    voltmeter.number = copy(system.bus.number)
    voltmeter.index = collect(1:system.bus.number)
    voltmeter.label = Dict(voltmeter.index .=> voltmeter.index)

    voltmeter.mean = fill(0.0, system.bus.number)
    voltmeter.variance = similar(voltmeter.mean)
    voltmeter.status = fill(Int8(status), system.bus.number)

    prefixInv = 1 / system.base.voltage.prefix
    @inbounds for i = 1:system.bus.number
        voltmeter.variance[i] = topu(variance, default.variance, prefixInv / system.base.voltage.value[i], prefix.voltageMagnitude)
        voltmeter.mean[i] = analysis.voltage.magnitude[i] + voltmeter.variance[i]^(1/2) * randn(1)[1]
    end
end

macro ammeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = Symbol(String(kwarg.args[1].args[2]), String(kwarg.args[1].args[3]))
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(AmmeterTemplate, parameter)
            if parameter in [:variancefrom, :varianceto]
                container::ContainerTemplate = getfield(template.ammeter, parameter)
                if prefix.currentMagnitude != 0.0
                    setfield!(container, :value, prefix.currentMagnitude * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                setfield!(template.ammeter, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addAmmeter!(system::PowerSystem, device::Measurement;
    label::T = missing, branch::N, location::Symbol = :from,
    mean::T = missing, variance::T = missing, exact::T = missing, status::T = missing)

    default = template.ammeter

    checkLabel(system.branch, branch, "branch")
    checkMeanExact(mean, exact)
    checkLocation(location, [:from, :to])

    index = system.branch.label[branch]
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if location == :from
        ammeter = device.ammeter.from
        defaultVariance = default.variancefrom
        defaultStatus = default.statusfrom
        baseVoltage = system.base.voltage.value[system.branch.layout.from[index]] * system.base.voltage.prefix
    else location == :to
        ammeter = device.ammeter.to
        defaultVariance = default.varianceto
        defaultStatus = default.statusto
        baseVoltage = system.base.voltage.value[system.branch.layout.to[index]] * system.base.voltage.prefix 
    end

    ammeter.number += 1
    setLabel(ammeter, label)
 
    push!(ammeter.index, index)

    push!(ammeter.status, unitless(status, defaultStatus))
    checkStatus(ammeter.status[end])
    
    baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
    push!(ammeter.variance, topu(variance, defaultVariance, baseCurrentInv, prefix.currentMagnitude))

    if ismissing(mean)
        mean = topu(exact, baseCurrentInv, prefix.currentMagnitude) + ammeter.variance[end]^(1/2) * randn(1)[1]
    else
        mean = topu(mean, baseCurrentInv, prefix.currentMagnitude)
    end
    push!(ammeter.mean, mean)
end

function addAmmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, location::Symbol = :branch, status::T = missing)

    ammeter = device.ammeter
    default = template.ammeter

    checkLocation(location, [:from, :to, :branch])
    branchFrom = (location == :from || location == :branch)
    branchTo = (location == :to || location == :branch)

    if branchFrom
        statusFrom = unitless(status, default.statusfrom)
        checkStatus(statusFrom)
        ammeter.from.status = fill(Int8(statusFrom), system.branch.number)

        ammeter.from.number = copy(system.branch.number)
        ammeter.from.index = collect(1:system.branch.number)
        ammeter.from.label = Dict(ammeter.from.index .=> ammeter.from.index)
        ammeter.from.mean = fill(0.0, system.branch.number)
        ammeter.from.variance = similar(ammeter.from.mean) 
    end
    if branchTo
        statusTo = unitless(status, default.statusto)
        checkStatus(statusTo)
        ammeter.to.status = fill(Int8(statusTo), system.branch.number)

        ammeter.to.number = copy(system.branch.number)
        ammeter.to.index = collect(1:system.branch.number)
        ammeter.to.label = Dict(ammeter.to.index .=> ammeter.to.index)
        ammeter.to.mean = fill(0.0, system.branch.number)
        ammeter.to.variance = similar(ammeter.to.mean)
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    @inbounds for i = 1:system.branch.number
        if branchFrom
            baseVoltage = system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix
            baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

            ammeter.from.variance[i] = topu(variance, default.variancefrom, baseCurrentInv, prefix.currentMagnitude)
            ammeter.from.mean[i] = analysis.current.from.magnitude[i] + ammeter.from.variance[i]^(1/2) * randn(1)[1]
        end

        if branchTo
            baseVoltage = system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix
            baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)

            ammeter.to.variance[i] = topu(variance, default.varianceto, baseCurrentInv, prefix.currentMagnitude)
            ammeter.to.mean[i] = analysis.current.to.magnitude[i] + ammeter.to.variance[i]^(1/2) * randn(1)[1]
        end
    end
end

macro wattmeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = Symbol(String(kwarg.args[1].args[2]), String(kwarg.args[1].args[3]))
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(WattmeterTemplate, parameter)
            if parameter in [:variancebus, :variancefrom, :varianceto]
                container::ContainerTemplate = getfield(template.wattmeter, parameter)
                if prefix.activePower != 0.0
                    setfield!(container, :value, prefix.activePower * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                setfield!(template.wattmeter, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addWattmeter!(system::PowerSystem, device::Measurement;
    label::T = missing, bus::T = missing, branch::T = missing, location::Symbol = :from,
    mean::T = missing, exact::T = missing, variance::T = missing, status::T = missing)

    default = template.wattmeter

    if ismissing(bus) && ismissing(branch)
        throw(ErrorException("At least one of the keywords bus or branch must be provided."))
    elseif !ismissing(bus) && !ismissing(branch)
        throw(ErrorException("The concurrent definition of the keywords bus and branch is not allowed."))
    end
    checkMeanExact(mean, exact)
    
    if !ismissing(bus) 
        checkLabel(system.bus, bus, "bus")

        wattmeter = device.wattmeter.bus
        defaultVaraince = default.variancebus
        defaultStatus = default.statusbus
        index = system.bus.label[bus]
    else
        checkLabel(system.branch, branch, "branch")
        checkLocation(location, [:from, :to])

        if location == :from
            wattmeter = device.wattmeter.from
            defaultVaraince = default.variancefrom
            defaultStatus = default.statusfrom
        else
            wattmeter = device.wattmeter.to
            defaultVaraince = default.varianceto
            defaultStatus = default.statusto
        end
        index = system.branch.label[branch]
    end
 
    wattmeter.number += 1
    setLabel(wattmeter, label)

    push!(wattmeter.index, index)

    push!(wattmeter.status, unitless(status, defaultStatus))
    checkStatus(wattmeter.status[end])
    
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    push!(wattmeter.variance, topu(variance, defaultVaraince, basePowerInv, prefix.activePower))

    if ismissing(mean)
        mean = topu(exact, basePowerInv, prefix.activePower) + wattmeter.variance[end]^(1/2) * randn(1)[1]
    else
        mean = topu(mean, basePowerInv, prefix.activePower)
    end
    push!(wattmeter.mean, mean)
end

function addWattmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, status::T = missing, location::Symbol = :all)

    wattmeter = device.wattmeter
    default = template.wattmeter

    checkLocation(location, [:from, :to, :bus, :branch, :all])
    bus = (location == :all || location == :bus) 
    branchFrom = (location == :all || location == :branch || location == :from)
    branchTo = (location == :all || location == :branch || location == :to)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if bus
        varianceBus = topu(variance, default.variancebus, basePowerInv, prefix.activePower)
        
        statusBus = unitless(status, default.statusbus)
        checkStatus(statusBus)
        wattmeter.bus.status = fill(Int8(statusBus), system.bus.number)

        wattmeter.bus.number = copy(system.bus.number)
        wattmeter.bus.index = collect(1:system.bus.number)
        wattmeter.bus.label = Dict(wattmeter.bus.index .=> wattmeter.bus.index)
        wattmeter.bus.mean = fill(0.0, system.bus.number)
        wattmeter.bus.variance = similar(wattmeter.bus.mean)

        @inbounds for i = 1:system.bus.number
            wattmeter.bus.variance[i] = varianceBus
            wattmeter.bus.mean[i] = analysis.power.injection.active[i] + varianceBus^(1/2) * randn(1)[1]
        end
    end

    if branchFrom
        varianceFrom = topu(variance, default.variancefrom, basePowerInv, prefix.activePower)

        statusFrom = unitless(status, default.statusfrom)
        checkStatus(statusFrom)
        wattmeter.from.status = fill(Int8(statusFrom), system.branch.number)

        wattmeter.from.number = copy(system.branch.number)
        wattmeter.from.index = collect(1:system.branch.number)
        wattmeter.from.label = Dict(wattmeter.from.index .=> wattmeter.from.index)
        wattmeter.from.mean = fill(0.0, system.branch.number)
        wattmeter.from.variance = similar(wattmeter.from.mean)
    end

    if branchTo
        varianceTo = topu(variance, default.varianceto, basePowerInv, prefix.activePower)

        statusTo = unitless(status, default.statusto)
        checkStatus(statusTo)
        wattmeter.to.status = fill(Int8(statusTo), system.branch.number)

        wattmeter.to.number = copy(system.branch.number)
        wattmeter.to.index = collect(1:system.branch.number)
        wattmeter.to.label = Dict(wattmeter.to.index .=> wattmeter.to.index)
        wattmeter.to.mean = fill(0.0, system.branch.number)
        wattmeter.to.variance = similar(wattmeter.to.mean)
    end

    if branchFrom || branchTo
        @inbounds for i = 1:system.branch.number
            if branchFrom
                wattmeter.from.variance[i] = varianceFrom
                wattmeter.from.mean[i] = analysis.power.from.active[i] + varianceFrom^(1/2) * randn(1)[1]
            end

            if branchTo
                wattmeter.to.variance[i] = varianceTo
                wattmeter.to.mean[i] = analysis.power.to.active[i] + varianceTo^(1/2) * randn(1)[1]
            end
        end
    end
end

macro varmeter(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = Symbol(String(kwarg.args[1].args[2]), String(kwarg.args[1].args[3]))
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(VarmeterTemplate, parameter)
            if parameter in [:variancebus, :variancefrom, :varianceto]
                container::ContainerTemplate = getfield(template.varmeter, parameter)
                if prefix.reactivePower != 0.0
                    setfield!(container, :value, prefix.reactivePower * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                setfield!(template.varmeter, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addVarmeter!(system::PowerSystem, device::Measurement;
    label::T = missing, bus::T = missing, branch::T = missing, location::Symbol = :from,
    mean::T = missing, exact::T = missing, variance::T = missing, status::T = missing)

    default = template.varmeter

    if ismissing(bus) && ismissing(branch)
        throw(ErrorException("At least one of the keywords bus or branch must be provided."))
    elseif !ismissing(bus) && !ismissing(branch)
        throw(ErrorException("The concurrent definition of the keywords bus and branch is not allowed."))
    end
    checkMeanExact(mean, exact)
    
    if !ismissing(bus) 
        checkLabel(system.bus, bus, "bus")

        varmeter = device.varmeter.bus
        defaultVaraince = default.variancebus
        defaultStatus = default.statusbus
        index = system.bus.label[bus]
    else
        checkLabel(system.branch, branch, "branch")
        checkLocation(location, [:from, :to])

        if location == :from
            varmeter = device.varmeter.from
            defaultVaraince = default.variancefrom
            defaultStatus = default.statusfrom
        else
            varmeter = device.varmeter.to
            defaultVaraince = default.varianceto
            defaultStatus = default.statusto
        end
        index = system.branch.label[branch]
    end
 
    varmeter.number += 1
    setLabel(varmeter, label)

    push!(varmeter.index, index)

    push!(varmeter.status, unitless(status, defaultStatus))
    checkStatus(varmeter.status[end])
    
    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    push!(varmeter.variance, topu(variance, defaultVaraince, basePowerInv, prefix.reactivePower))

    if ismissing(mean)
        mean = topu(exact, basePowerInv, prefix.reactivePower) + varmeter.variance[end]^(1/2) * randn(1)[1]
    else
        mean = topu(mean, basePowerInv, prefix.reactivePower)
    end
    push!(varmeter.mean, mean)
end

function addVarmeter!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, status::T = missing, location::Symbol = :all)

    varmeter = device.varmeter
    default = template.varmeter

    checkLocation(location, [:from, :to, :bus, :branch, :all])
    bus = (location == :all || location == :bus) 
    branchFrom = (location == :all || location == :branch || location == :from)
    branchTo = (location == :all || location == :branch || location == :to)

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if bus
        varianceBus = topu(variance, default.variancebus, basePowerInv, prefix.reactivePower)
        
        statusBus = unitless(status, default.statusbus)
        checkStatus(statusBus)
        varmeter.bus.status = fill(Int8(statusBus), system.bus.number)

        varmeter.bus.number = copy(system.bus.number)
        varmeter.bus.index = collect(1:system.bus.number)
        varmeter.bus.label = Dict(varmeter.bus.index .=> varmeter.bus.index)
        varmeter.bus.mean = fill(0.0, system.bus.number)
        varmeter.bus.variance = similar(varmeter.bus.mean)

        @inbounds for i = 1:system.bus.number
            varmeter.bus.variance[i] = varianceBus
            varmeter.bus.mean[i] = analysis.power.injection.reactive[i] + varianceBus^(1/2) * randn(1)[1]
        end
    end

    if branchFrom
        varianceFrom = topu(variance, default.variancefrom, basePowerInv, prefix.reactivePower)

        statusFrom = unitless(status, default.statusfrom)
        checkStatus(statusFrom)
        varmeter.from.status = fill(Int8(statusFrom), system.branch.number)

        varmeter.from.number = copy(system.branch.number)
        varmeter.from.index = collect(1:system.branch.number)
        varmeter.from.label = Dict(varmeter.from.index .=> varmeter.from.index)
        varmeter.from.mean = fill(0.0, system.branch.number)
        varmeter.from.variance = similar(varmeter.from.mean)
    end

    if branchTo
        varianceTo = topu(variance, default.varianceto, basePowerInv, prefix.reactivePower)

        statusTo = unitless(status, default.statusto)
        checkStatus(statusTo)
        varmeter.to.status = fill(Int8(statusTo), system.branch.number)

        varmeter.to.number = copy(system.branch.number)
        varmeter.to.index = collect(1:system.branch.number)
        varmeter.to.label = Dict(varmeter.to.index .=> varmeter.to.index)
        varmeter.to.mean = fill(0.0, system.branch.number)
        varmeter.to.variance = similar(varmeter.to.mean)
    end

    if branchFrom || branchTo
        @inbounds for i = 1:system.branch.number
            if branchFrom
                varmeter.from.variance[i] = varianceFrom
                varmeter.from.mean[i] = analysis.power.from.reactive[i] + varianceFrom^(1/2) * randn(1)[1]
            end

            if branchTo
                varmeter.to.variance[i] = varianceTo
                varmeter.to.mean[i] = analysis.power.to.reactive[i] + varianceTo^(1/2) * randn(1)[1]
            end
        end
    end
end

macro anglepmu(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = Symbol(String(kwarg.args[1].args[2]), String(kwarg.args[1].args[3]))
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(AnglepmuTemplate, parameter)
            if parameter in [:variancebus, :variancefrom, :varianceto]
                if parameter == :variancebus
                    prefixLive = prefix.voltageAngle
                else
                    prefixLive = prefix.currentAngle
                end
                setfield!(template.anglepmu, parameter, value * prefixLive)
            else
                setfield!(template.anglepmu, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addAnglepmu!(system::PowerSystem, device::Measurement;
    label::T = missing, bus::T = missing, branch::T = missing, location::Symbol = :from,
    mean::T = missing, exact::T = missing, variance::T = missing, status::T = missing)

    default = template.anglepmu

    if ismissing(bus) && ismissing(branch)
        throw(ErrorException("At least one of the keywords bus or branch must be provided."))
    elseif !ismissing(bus) && !ismissing(branch)
        throw(ErrorException("The concurrent definition of the keywords bus and branch is not allowed."))
    end
    checkMeanExact(mean, exact)
    
    if !ismissing(bus) 
        checkLabel(system.bus, bus, "bus")

        anglepmu = device.anglepmu.bus
        defaultVaraince = default.variancebus
        prefixLive = prefix.voltageAngle
        defaultStatus = default.statusbus
        index = system.bus.label[bus]
    else
        checkLabel(system.branch, branch, "branch")
        checkLocation(location, [:from, :to])

        if location == :from
            anglepmu = device.anglepmu.from
            defaultVaraince = default.variancefrom
            defaultStatus = default.statusfrom
        else
            anglepmu = device.anglepmu.to
            defaultVaraince = default.varianceto
            defaultStatus = default.statusto
        end
        prefixLive = prefix.currentAngle
        index = system.branch.label[branch]
    end
 
    anglepmu.number += 1
    setLabel(anglepmu, label)

    push!(anglepmu.index, index)

    push!(anglepmu.status, unitless(status, defaultStatus))
    checkStatus(anglepmu.status[end])
    
    push!(anglepmu.variance, tosi(variance, defaultVaraince, prefixLive))

    if ismissing(mean)
        mean = exact * prefixLive + anglepmu.variance[end]^(1/2) * randn(1)[1]
    else
        mean *= prefixLive
    end
    push!(anglepmu.mean, mean)
end

function addAnglepmu!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, status::T = missing, location::Symbol = :all)

    anglepmu = device.anglepmu
    default = template.anglepmu

    checkLocation(location, [:from, :to, :bus, :branch, :all])
    bus = (location == :all || location == :bus) 
    branchFrom = (location == :all || location == :branch || location == :from)
    branchTo = (location == :all || location == :branch || location == :to)

    if bus
        varianceBus = tosi(variance, default.variancebus, prefix.voltageAngle)
        
        statusBus = unitless(status, default.statusbus)
        checkStatus(statusBus)
        anglepmu.bus.status = fill(Int8(statusBus), system.bus.number)

        anglepmu.bus.number = copy(system.bus.number)
        anglepmu.bus.index = collect(1:system.bus.number)
        anglepmu.bus.label = Dict(anglepmu.bus.index .=> anglepmu.bus.index)
        anglepmu.bus.mean = fill(0.0, system.bus.number)
        anglepmu.bus.variance = similar(anglepmu.bus.mean)

        @inbounds for i = 1:system.bus.number
            anglepmu.bus.variance[i] = varianceBus
            anglepmu.bus.mean[i] = analysis.voltage.angle[i] + varianceBus^(1/2) * randn(1)[1]
        end
    end

    if branchFrom
        varianceFrom = tosi(variance, default.variancefrom, prefix.currentAngle)

        statusFrom = unitless(status, default.statusfrom)
        checkStatus(statusFrom)
        anglepmu.from.status = fill(Int8(statusFrom), system.branch.number)

        anglepmu.from.number = copy(system.branch.number)
        anglepmu.from.index = collect(1:system.branch.number)
        anglepmu.from.label = Dict(anglepmu.from.index .=> anglepmu.from.index)
        anglepmu.from.mean = fill(0.0, system.branch.number)
        anglepmu.from.variance = similar(anglepmu.from.mean)
    end

    if branchTo
        varianceTo = tosi(variance, default.varianceto, prefix.currentAngle)

        statusTo = unitless(status, default.statusto)
        checkStatus(statusTo)
        anglepmu.to.status = fill(Int8(statusTo), system.branch.number)

        anglepmu.to.number = copy(system.branch.number)
        anglepmu.to.index = collect(1:system.branch.number)
        anglepmu.to.label = Dict(anglepmu.to.index .=> anglepmu.to.index)
        anglepmu.to.mean = fill(0.0, system.branch.number)
        anglepmu.to.variance = similar(anglepmu.to.mean)
    end

    if branchFrom || branchTo
        @inbounds for i = 1:system.branch.number
            if branchFrom
                anglepmu.from.variance[i] = varianceFrom
                anglepmu.from.mean[i] = analysis.current.from.angle[i] + varianceFrom^(1/2) * randn(1)[1]
            end

            if branchTo
                anglepmu.to.variance[i] = varianceTo
                anglepmu.to.mean[i] = analysis.current.to.angle[i] + varianceTo^(1/2) * randn(1)[1]
            end
        end
    end
end

macro magnitudepmu(kwargs...)
    for kwarg in kwargs
        parameter::Symbol = Symbol(String(kwarg.args[1].args[2]), String(kwarg.args[1].args[3]))
        value::Float64 = Float64(eval(kwarg.args[2]))

        if hasfield(MagnitudepmuTemplate, parameter)
            if parameter in [:variancebus, :variancefrom, :varianceto]
                container::ContainerTemplate = getfield(template.magnitudepmu, parameter)
                if parameter == :variancebus
                    prefixLive = prefix.voltageMagnitude
                else
                    prefixLive = prefix.currentMagnitude
                end
                if prefixLive != 0.0
                    setfield!(container, :value, prefixLive * value)
                    setfield!(container, :pu, false)
                else
                    setfield!(container, :value, value)
                    setfield!(container, :pu, true)
                end
            else
                setfield!(template.magnitudepmu, parameter, Int8(value))
            end
        else
            throw(ErrorException("The keyword $(parameter) is illegal."))
        end
    end
end

function addMagnitudepmu!(system::PowerSystem, device::Measurement;
    label::T = missing, bus::T = missing, branch::T = missing, location::Symbol = :from,
    mean::T = missing, exact::T = missing, variance::T = missing, status::T = missing)

    default = template.magnitudepmu

    if ismissing(bus) && ismissing(branch)
        throw(ErrorException("At least one of the keywords bus or branch must be provided."))
    elseif !ismissing(bus) && !ismissing(branch)
        throw(ErrorException("The concurrent definition of the keywords bus and branch is not allowed."))
    end
    checkMeanExact(mean, exact)
    
    if !ismissing(bus) 
        checkLabel(system.bus, bus, "bus")

        magnitudepmu = device.magnitudepmu.bus
        defaultVaraince = default.variancebus
        prefixLive = prefix.voltageMagnitude
        defaultStatus = default.statusbus
        index = system.bus.label[bus]
        baseInv = 1 / (system.base.voltage.value[index] * system.base.voltage.prefix)
    else
        checkLabel(system.branch, branch, "branch")
        checkLocation(location, [:from, :to])

        index = system.branch.label[branch]
        if location == :from
            magnitudepmu = device.magnitudepmu.from
            defaultVaraince = default.variancefrom
            defaultStatus = default.statusfrom
            baseVoltage = system.base.voltage.value[system.branch.layout.from[index]] * system.base.voltage.prefix
        else
            magnitudepmu = device.magnitudepmu.to
            defaultVaraince = default.varianceto
            defaultStatus = default.statusto
            baseVoltage = system.base.voltage.value[system.branch.layout.to[index]] * system.base.voltage.prefix
        end
        prefixLive = prefix.currentMagnitude
        
        basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
        baseInv = baseCurrentInverse(basePowerInv, baseVoltage)
    end
 
    magnitudepmu.number += 1
    setLabel(magnitudepmu, label)

    push!(magnitudepmu.index, index)

    push!(magnitudepmu.status, unitless(status, defaultStatus))
    checkStatus(magnitudepmu.status[end])
    
    push!(magnitudepmu.variance, topu(variance, defaultVaraince, baseInv, prefixLive))

    if ismissing(mean)
        mean = topu(exact, baseInv, prefixLive) + magnitudepmu.variance[end]^(1/2) * randn(1)[1]
    else
        mean = topu(mean, baseInv, prefixLive)
    end
    push!(magnitudepmu.mean, mean)
end

function addMagnitudepmu!(system::PowerSystem, device::Measurement, analysis::AC;
    variance::T = missing, status::T = missing, location::Symbol = :all)

    magnitudepmu = device.magnitudepmu
    default = template.magnitudepmu

    checkLocation(location, [:from, :to, :bus, :branch, :all])
    bus = (location == :all || location == :bus) 
    branchFrom = (location == :all || location == :branch || location == :from)
    branchTo = (location == :all || location == :branch || location == :to)

    if bus        
        statusBus = unitless(status, default.statusbus)
        checkStatus(statusBus)
        magnitudepmu.bus.status = fill(Int8(statusBus), system.bus.number)

        magnitudepmu.bus.number = copy(system.bus.number)
        magnitudepmu.bus.index = collect(1:system.bus.number)
        magnitudepmu.bus.label = Dict(magnitudepmu.bus.index .=> magnitudepmu.bus.index)
        magnitudepmu.bus.mean = fill(0.0, system.bus.number)
        magnitudepmu.bus.variance = similar(magnitudepmu.bus.mean)

        prefixInv = 1 / system.base.voltage.prefix
        @inbounds for i = 1:system.bus.number
            magnitudepmu.bus.variance[i] = topu(variance, default.variancebus, prefixInv / system.base.voltage.value[i], prefix.voltageMagnitude)
            magnitudepmu.bus.mean[i] = analysis.voltage.magnitude[i] + magnitudepmu.bus.variance[i]^(1/2) * randn(1)[1]
        end
    end

    if branchFrom
        statusFrom = unitless(status, default.statusfrom)
        checkStatus(statusFrom)
        magnitudepmu.from.status = fill(Int8(statusFrom), system.branch.number)

        magnitudepmu.from.number = copy(system.branch.number)
        magnitudepmu.from.index = collect(1:system.branch.number)
        magnitudepmu.from.label = Dict(magnitudepmu.from.index .=> magnitudepmu.from.index)
        magnitudepmu.from.mean = fill(0.0, system.branch.number)
        magnitudepmu.from.variance = similar(magnitudepmu.from.mean)
    end

    if branchTo
        statusTo = unitless(status, default.statusto)
        checkStatus(statusTo)
        magnitudepmu.to.status = fill(Int8(statusTo), system.branch.number)

        magnitudepmu.to.number = copy(system.branch.number)
        magnitudepmu.to.index = collect(1:system.branch.number)
        magnitudepmu.to.label = Dict(magnitudepmu.to.index .=> magnitudepmu.to.index)
        magnitudepmu.to.mean = fill(0.0, system.branch.number)
        magnitudepmu.to.variance = similar(magnitudepmu.to.mean)
    end

    basePowerInv = 1 / (system.base.power.value * system.base.power.prefix)
    if branchFrom || branchTo
        @inbounds for i = 1:system.branch.number
            if branchFrom
                baseVoltage = system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix
                baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
    
                magnitudepmu.from.variance[i] = topu(variance, default.variancefrom, baseCurrentInv, prefix.currentMagnitude)
                magnitudepmu.from.mean[i] = analysis.current.from.magnitude[i] + magnitudepmu.from.variance[i]^(1/2) * randn(1)[1]
            end

            if branchTo
                baseVoltage = system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix
                baseCurrentInv = baseCurrentInverse(basePowerInv, baseVoltage)
    
                magnitudepmu.to.variance[i] = topu(variance, default.varianceto, baseCurrentInv, prefix.currentMagnitude)
                magnitudepmu.to.mean[i] = analysis.current.to.magnitude[i] + magnitudepmu.to.variance[i]^(1/2) * randn(1)[1]
            end
        end
    end
end

######### Check Mean and Exact ##########
function checkMeanExact(mean, exact)
    if ismissing(mean) && ismissing(exact)
        throw(ErrorException("At least one of the keywords mean or exact must be provided."))
    end
end

######### Check Location ##########
function checkLocation(location, allowLocation)
    if !(location in allowLocation)
        throw(ErrorException("The allowed locations for the measurement are limited to $allowLocation."))
    end
end

function saveMeasurement(device::Measurement; path::String, reference::String = "", note::String = "")
    file = h5open(path, "w")
        saveDevice(device.voltmeter, file, "voltmeter", "volt (V)")
        saveDevice(device.ammeter.from, file, "ammeter", "ampere (A)"; location = "from")
        saveDevice(device.ammeter.to, file, "ammeter", "ampere (A)"; location = "to")
        saveDevice(device.wattmeter.bus, file, "wattmeter", "watt (W)"; location = "bus")
        saveDevice(device.wattmeter.from, file, "wattmeter", "watt (W)"; location = "from")
        saveDevice(device.wattmeter.to, file, "wattmeter", "watt (W)"; location = "to")
        saveDevice(device.varmeter.bus, file, "varmeter", "volt-ampere reactive (VAr)"; location = "bus")
        saveDevice(device.varmeter.from, file, "varmeter", "volt-ampere reactive (VAr)"; location = "from")
        saveDevice(device.varmeter.to, file, "varmeter", "volt-ampere reactive (VAr)"; location = "to")
        saveDevice(device.anglepmu.bus, file, "anglepmu", "radian (rad)"; location = "bus")
        saveDevice(device.anglepmu.from, file, "anglepmu", "radian (rad)"; location = "from")
        saveDevice(device.anglepmu.to, file, "anglepmu", "radian (rad)"; location = "to")
        saveDevice(device.magnitudepmu.bus, file, "magnitudepmu", "volt (V)"; location = "bus")
        saveDevice(device.magnitudepmu.from, file, "magnitudepmu", "ampere (A)"; location = "from")
        saveDevice(device.magnitudepmu.to, file, "magnitudepmu", "ampere (A)"; location = "to")
    close(file)
end

######### Save Voltmeter Data ##########
function saveDevice(device, file, meter::String, unit::String; location = "")
    if meter != "voltmeter"
        folder = meter * "/" * location
    else
        folder = meter                 
    end
    
    label = fill(0, device.number)
    @inbounds for (key, value) in device.label
        label[value] = key
    end
    
    write(file, "$folder/label", label)
    attrs(file["$folder/label"])["type"] = "positive integer"
    attrs(file["$folder/label"])["unit"] = "dimensionless"
    attrs(file["$folder/label"])["format"] = "expand"

    format = compresseArray(file, device.index, "$folder/index")
    attrs(file["$folder/index"])["type"] = "positive integer"
    attrs(file["$folder/index"])["unit"] = "dimensionless"
    attrs(file["$folder/index"])["format"] = format

    format = compresseArray(file, device.mean, "$folder/mean")
    if meter != "anglepmu"
        attrs(file["$folder/mean"])["unit"] = "per-unit (pu)"
        attrs(file["$folder/mean"])["SI unit"] = unit
    else
        attrs(file["$folder/mean"])["unit"] = unit
    end
    attrs(file["$folder/mean"])["type"] = "float"
    attrs(file["$folder/mean"])["format"] = format

    format = compresseArray(file, device.variance, "$folder/variance")
    if meter != "anglepmu"
        attrs(file["$folder/variance"])["unit"] = "per-unit (pu)"
        attrs(file["$folder/variance"])["SI unit"] = unit
    else
        attrs(file["$folder/variance"])["unit"] = unit
    end
    attrs(file["$folder/variance"])["type"] = "float"
    attrs(file["$folder/variance"])["format"] = format

    format = compresseArray(file, device.status, "$folder/status")
    attrs(file["$folder/status"])["in-service"] = 1
    attrs(file["$folder/status"])["out-of-service"] = 0
    attrs(file["$folder/status"])["unit"] = "dimensionless"
    attrs(file["$folder/status"])["type"] = "zero-one integer"
    attrs(file["$folder/status"])["format"] = format
end