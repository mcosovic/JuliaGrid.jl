"""
The function add a new bus. Names, descriptions and units of keywords are given
in the table [bus group](@ref busGroup).

    addBus!(system::PowerSystem; label, slackLabel, area, lossZone, active, reactive,
        conductance, susceptance, magnitude, angle, minMagnitude, maxMagnitude, base)

The keyword `label` is mandatory. Default keyword values are set to zero, except for keywords
`lossZone = 1`, `area = 1`, `magnitude = 1.0`, `minMagnitude = 0.9`, and `maxMagnitude = 1.1`.

The slack bus, using the keyword `slackLabel`, can be specified in each function call with the
label of the bus being defined or already existing. If the bus is not defined as the slack, the
function `addBus!()` automatically defines the bus as the demand bus (PQ). If a generator is
connected to a bus, using the function `addGenerator!()`, the bus becomes a generator bus (PV).
"""
function addBus!(system::PowerSystem; label::Int64, slackLabel::Int64 = 0, area::Int64 = 1, lossZone::Int64 = 1,
    active::Float64 = 0.0, reactive::Float64 = 0.0, conductance::Float64 = 0.0, susceptance::Float64 = 0.0,
    magnitude::Float64 = 1.0, angle::Float64 = 0.0, minMagnitude::Float64 = 0.9, maxMagnitude::Float64 = 1.1, base::Float64 = 0.0)

    demand = system.bus.demand
    shunt = system.bus.shunt
    voltage = system.bus.voltage
    layout = system.bus.layout
    supply = system.bus.supply

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if haskey(system.bus.label, label)
        throw(ErrorException("The value $label of the label keyword is not unique."))
    end

    system.bus.number += 1
    setindex!(system.bus.label, system.bus.number, label)
    push!(layout.type, 1)

    if slackLabel != 0
        if !haskey(system.bus.label, slackLabel)
            throw(ErrorException("The value $slackLabel of the slackLabel keyword does not exist in bus labels."))
        end
        if layout.slackIndex != 0
            layout.type[layout.slackIndex] = 1
        end

        layout.slackIndex = system.bus.label[slackLabel]
        layout.slackImmutable = system.bus.label[slackLabel]

        layout.type[layout.slackIndex] = 3
    end

    if system.bus.number != label
        layout.renumbering = true
    end

    push!(demand.active, active)
    push!(demand.reactive, reactive)

    push!(shunt.conductance, conductance)
    push!(shunt.susceptance, susceptance)

    push!(voltage.magnitude, magnitude)
    push!(voltage.angle, angle)
    push!(voltage.maxMagnitude, maxMagnitude)
    push!(voltage.minMagnitude, minMagnitude)
    push!(voltage.base, base)


    push!(layout.area, area)
    push!(layout.lossZone, lossZone)

    push!(supply.inService, 0)
    push!(supply.active, 0.0)
    push!(supply.reactive, 0.0)

    if !isempty(system.dcModel.admittance)
        nilModel!(system, :dcModelEmpty)
    end

    if !isempty(system.acModel.admittance)
        nilModel!(system, :acModelEmpty)
    end
end

"""
The function allows changing `conductance` and `susceptance` parameters of the shunt element
connected to the bus.

    shuntBus!(system::PowerSystem; label, conductance, susceptance)

The keyword `label` should correspond to the already defined bus label. Keywords `conductance`
or `susceptance`can be omitted, then the value of the omitted parameter remains unchanged.
The function also updates the field `acModel`, if field exist.
"""
function shuntBus!(system::PowerSystem; user...)
    ac = system.acModel
    shunt = system.bus.shunt

    if !haskey(user, :label) || user[:label]::Int64 <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.bus.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in bus labels."))
    end

    index = system.bus.label[user[:label]]
    if haskey(user, :conductance) || haskey(user, :susceptance)
        ac.nodalMatrix
        if !isempty(system.acModel.admittance)
            ac.nodalMatrix[index, index] -= shunt.conductance[index] + im * shunt.susceptance[index]
        end

        if haskey(user, :conductance)
            shunt.conductance[index] = user[:conductance]::Float64
        end
        if haskey(user, :reactance)
            shunt.susceptance[index] = user[:susceptance]::Float64
        end


        if !isempty(system.acModel.admittance)
            ac.nodalMatrix[index, index] += shunt.conductance[index] + im * shunt.susceptance[index]
        end
    end
end

"""
The function add a new branch. Names, descriptions and units of keywords are given in the
table [branch group](@ref branchGroup). A branch can be added between already defined buses.

    addBranch!(system::PowerSystem; label, from, to, status, resistance, reactance, susceptance,
        turnsRatio, shiftAngle, longTerm, shortTerm, emergency, minAngleDifference, maxAngleDifference)

The keywords `label`, `from`, `to`, and one of the parameters `resistance` or `reactance` are
mandatory. Default keyword values are set to zero, except for keywords `status = 1`,
`minAngleDifference = -2*pi`, `maxAngleDifference = 2*pi`.
"""
function addBranch!(system::PowerSystem; label::Int64, from::Int64, to::Int64, status::Int64 = 1,
    resistance::Float64 = 0.0, reactance::Float64 = 0.0, susceptance::Float64 = 0.0, turnsRatio::Float64 = 0.0, shiftAngle::Float64 = 0.0,
    longTerm::Float64 = 0.0, shortTerm::Float64 = 0.0, emergency::Float64 = 0.0,
    minAngleDifference::Float64 = -2 * pi, maxAngleDifference::Float64 = 2 * pi)

    parameter = system.branch.parameter
    rating = system.branch.rating
    voltage = system.branch.voltage
    layout = system.branch.layout

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if from <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if to <= 0
        throw(ErrorException("The value of the to keyword must be given as a positive integer."))
    end
    if resistance == 0.0 && reactance == 0.0
        throw(ErrorException("At least one of the keywords resistance and reactance must be defined."))
    end
    if from == to
        throw(ErrorException("Keywords from and to cannot contain the same positive integer."))
    end
    if haskey(system.branch.label, label)
        throw(ErrorException("The branch label $label is not unique."))
    end
    if !haskey(system.bus.label, from)
        throw(ErrorException("The value $from of the from keyword is not unique."))
    end
    if !haskey(system.bus.label, to)
        throw(ErrorException("The value $to of the to keyword is not unique."))
    end
    if !(status in [0; 1])
        throw(ErrorException("The value $status of the status keyword is illegal, it can be in-service (1) or out-of-service (0)."))
    end

    system.branch.number += 1

    setindex!(system.branch.label, system.branch.number, label)
    if system.branch.number != label
        layout.renumbering = true
    end

    push!(parameter.resistance, resistance)
    push!(parameter.reactance, reactance)
    push!(parameter.susceptance, susceptance)
    push!(parameter.turnsRatio, turnsRatio)
    push!(parameter.shiftAngle, shiftAngle)

    push!(rating.longTerm, longTerm)
    push!(rating.shortTerm, shortTerm)
    push!(rating.emergency, emergency)

    push!(voltage.minAngleDifference, minAngleDifference)
    push!(voltage.maxAngleDifference, maxAngleDifference)

    push!(layout.from, system.bus.label[from])
    push!(layout.to, system.bus.label[to])
    push!(layout.status, status)

    index = system.branch.number
    if !isempty(system.dcModel.admittance)
        nilModel!(system, :dcModelPushZeros)
        if layout.status[index] == 1
            dcParameterUpdate!(system, index)
            dcNodalShiftUpdate!(system, index)
        end
    end

    if !isempty(system.acModel.admittance)
        nilModel!(system, :acModelPushZeros)
        if layout.status[index] == 1
            acParameterUpdate!(system, index)
            acNodalUpdate!(system, index)
        end
    end
end

"""
The function allows changing the operating `status` of the branch, from in-service to
out-of-service, and vice versa.

    statusBranch!(system::PowerSystem; label, status)

The keywords `label` should correspond to the already defined branch label.
"""
function statusBranch!(system::PowerSystem; label::Int64, status::Int64 = 0)
    layout = system.branch.layout

    if label <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if !haskey(system.branch.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in branch labels."))
    end
    if !(status in [0; 1])
        throw(ErrorException("The value $status of the status keyword is illegal, it can be in-service (1) or out-of-service (0)."))
    end
    index = system.branch.label[label]

    if layout.status[index] != status
        if !isempty(system.dcModel.admittance)
            if status == 1
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end
            if status == 0
                nilModel!(system, :dcModelDeprive; index = index)
                dcNodalShiftUpdate!(system, index)
                nilModel!(system, :dcModelZeros; index = index)
            end
        end

        if !isempty(system.acModel.admittance)
            if status == 1
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
            if status == 0
                nilModel!(system, :acModelDeprive; index = index)
                acNodalUpdate!(system, index)
                nilModel!(system, :acModelZeros; index = index)
            end
        end
    end
    layout.status[index] = status
end

"""
The function `parameterBranch!` allows changing `resistance`, `reactance`, `susceptance`,
`turnsRatio` and `shiftAngle` parameters of the branch.

    parameterBranch!(system::PowerSystem; label, resistance, reactance, susceptance, turnsRatio, shiftAngle)

The keywords `label` should correspond to the already defined branch label. Keywords `resistance`,
`reactance`, `susceptance`, `turnsRatio` or `shiftAngle` can be omitted, then the value of the omitted
parameter remains unchanged.
"""
function parameterBranch!(system::PowerSystem; user...)
    parameter = system.branch.parameter
    layout = system.branch.layout

    if !haskey(user, :label) || user[:label]::Int64 <= 0
        throw(ErrorException("The value of the from keyword must be given as a positive integer."))
    end
    if !haskey(system.branch.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in branch labels."))
    end

    index = system.branch.label[user[:label]]
    if haskey(user, :resistance) || haskey(user, :reactance) || haskey(user, :susceptance) || haskey(user, :turnsRatio) || haskey(user, :shiftAngle)
        if layout.status[index] == 1
            if !isempty(system.dcModel.admittance)
                nilModel!(system, :dcModelDeprive; index = index)
                dcNodalShiftUpdate!(system, index)
            end
            if !isempty(system.acModel.admittance)
                nilModel!(system, :acModelDeprive; index = index)
                acNodalUpdate!(system, index)
            end
        end

        if haskey(user, :resistance)
            parameter.resistance[index] = user[:resistance]::Float64
        end
        if haskey(user, :reactance)
            parameter.reactance[index] = user[:reactance]::Float64
        end
        if haskey(user, :susceptance)
            parameter.susceptance[index] = user[:susceptance]::Float64
        end
        if haskey(user, :turnsRatio)
            parameter.turnsRatio[index] = user[:turnsRatio]::Float64
        end
        if haskey(user, :shiftAngle)
            parameter.shiftAngle[index] = user[:shiftAngle]::Float64
        end

        if layout.status[index] == 1
            if !isempty(system.dcModel.admittance)
                dcParameterUpdate!(system, index)
                dcNodalShiftUpdate!(system, index)
            end

            if !isempty(system.acModel.admittance)
                acParameterUpdate!(system, index)
                acNodalUpdate!(system, index)
            end
        end
    end
end

"""
The function add a new generator. Names, descriptions and units of keywords are given in the
table [generator group](@ref generatorGroup). A generator can be added at already defined bus.

    addGenerator!(system::PowerSystem; label, bus, area, status, active, reactive, magnitude,
        minActive, maxActive, minReactive, maxReactive, lowerActive, minReactiveLower,
        maxReactiveLower, upperActive, minReactiveUpper, maxReactiveUpper, loadFollowing,
        reserve10minute, reserve30minute, reactiveTimescale, activeModel, activeStartup,
        activeShutdown, activeDataPoint, activeCoefficient, reactiveModel, reactiveStartup,
        reactiveShutdown, reactiveDataPoint, reactiveCoefficient)

The keywords `label` and `bus` are mandatory. Default keyword values are set to zero, except for keywords
`status = 1`, `magnitude = 1.0`, `maxActive = Inf`, `minReactive = -Inf`, `maxReactive = Inf`, `activeModel = 2`,
`activeDataPoint = 3`, `reactiveModel = 2`, and `reactiveDataPoint = 3`.
"""
function addGenerator!(system::PowerSystem; label::Int64, bus::Int64, area::Float64 = 0.0, status::Int64 = 1,
    active::Float64 = 0.0, reactive::Float64 = 0.0, magnitude::Float64 = 1.0,
    minActive::Float64 = 0.0, maxActive::Float64 = Inf64, minReactive::Float64 = -Inf64, maxReactive::Float64 = Inf64,
    lowerActive::Float64 = 0.0, minReactiveLower::Float64 = 0.0, maxReactiveLower::Float64 = 0.0,
    upperActive::Float64 = 0.0, minReactiveUpper::Float64 = 0.0, maxReactiveUpper::Float64 = 0.0,
    loadFollowing::Float64 = 0.0, reserve10minute::Float64 = 0.0, reserve30minute::Float64 = 0.0, reactiveTimescale::Float64 = 0.0,
    activeModel::Int64 = 2, activeStartup::Float64 = 0.0, activeShutdown::Float64 = 0.0, activeDataPoint::Int64 = 3,
    activeCoefficient::Array{Float64,1} = Float64[],
    reactiveModel::Int64 = 2, reactiveStartup::Float64 = 0.0, reactiveShutdown::Float64 = 0.0, reactiveDataPoint::Int64 = 3,
    reactiveCoefficient::Array{Float64,1} = Float64[])

    output = system.generator.output
    capability = system.generator.capability
    rampRate = system.generator.rampRate
    cost = system.generator.cost
    voltage = system.generator.voltage
    layout = system.generator.layout

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if bus <= 0
        throw(ErrorException("The value of the bus keyword must be given as a positive integer."))
    end
    if haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword is not unique."))
    end
    if !haskey(system.bus.label, bus)
        throw(ErrorException("The value $bus of the bus keyword does not exist in bus labels."))
    end

    flagActive = false
    colNumberActive = size(cost.activeCoefficient, 2)
    if isempty(cost.activeModel) && (system.generator.number + 1) == 1
        flagActive = true
    end
    if !isempty(cost.activeModel)
        if length(activeCoefficient) != 0 && colNumberActive != length(activeCoefficient)
            throw(ErrorException("The vector of the activeCoefficient keyword must be dimension of $colNumberActive."))
        end
        flagActive = true
    end

    flagReactive = false
    colNumberReactive = size(cost.reactiveCoefficient, 2)
    if isempty(cost.reactiveModel) && (system.generator.number + 1) == 1
        flagReactive = true
    end
    if !isempty(cost.reactiveModel)
        if length(reactiveCoefficient) != 0 && colNumberReactive != length(reactiveCoefficient)
            throw(ErrorException("The vector of the reactiveCoefficient keyword must be dimension of $colNumberReactive."))
        end
        flagReactive = true
    end

    system.generator.number += 1
    setindex!(system.generator.label, system.generator.number, label)

    busIndex = system.bus.label[bus]
    if status == 1
        system.bus.layout.type[busIndex] = 2
        system.bus.supply.inService[busIndex] += 1
        system.bus.supply.active[busIndex] += active
        system.bus.supply.reactive[busIndex] += reactive
    end

    push!(output.active, active)
    push!(output.reactive, reactive)

    push!(capability.minActive, minActive)
    push!(capability.maxActive, maxActive)
    push!(capability.minReactive, minReactive)
    push!(capability.maxReactive, maxReactive)
    push!(capability.lowerActive, lowerActive)
    push!(capability.minReactiveLower, minReactiveLower)
    push!(capability.maxReactiveLower, maxReactiveLower)
    push!(capability.upperActive, upperActive)
    push!(capability.minReactiveUpper, minReactiveUpper)
    push!(capability.maxReactiveUpper, maxReactiveUpper)

    push!(rampRate.loadFollowing, loadFollowing)
    push!(rampRate.reserve10minute, reserve10minute)
    push!(rampRate.reserve30minute, reserve30minute)
    push!(rampRate.reactiveTimescale, reactiveTimescale)

    push!(voltage.magnitude, magnitude)

    push!(layout.bus, busIndex)
    push!(layout.area, area)
    push!(layout.status, status)

    if flagActive
        push!(cost.activeModel, activeModel)
        push!(cost.activeStartup, activeStartup)
        push!(cost.activeShutdown, activeShutdown)
        push!(cost.activeDataPoint, activeDataPoint)

        if isempty(activeCoefficient)
            activeCoefficient = zeros(3)
        end
        if colNumberActive == 0
            cost.activeCoefficient = activeCoefficient'
        else
            cost.activeCoefficient = [cost.activeCoefficient; activeCoefficient']
        end
    end

    if flagReactive
        push!(cost.reactiveModel, reactiveModel)
        push!(cost.reactiveStartup, reactiveStartup)
        push!(cost.reactiveShutdown, reactiveShutdown)
        push!(cost.reactiveDataPoint, reactiveDataPoint)

        if isempty(reactiveCoefficient)
            reactiveCoefficient = zeros(3)
        end
        if colNumberReactive == 0
            cost.reactiveCoefficient = reactiveCoefficient'
        else
            cost.reactiveCoefficient = [cost.reactiveCoefficient; reactiveCoefficient']
        end
    end
end

"""
The function allows changing the operating `status` of the generator, from in-service
to out-of-service, and vice versa.

    statusGenerator!(system::PowerSystem; label, status)

The keywords `label` should correspond to the already defined generator label.
"""
function statusGenerator!(system::PowerSystem; label::Int64, status::Int64 = 0)
    layout = system.generator.layout
    output = system.generator.output

    if label <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.generator.label, label)
        throw(ErrorException("The value $label of the label keyword does not exist in generator labels."))
    end

    index = system.generator.label[label]
    indexBus = layout.bus[index]

    if layout.status[index] != status
        if status == 0
            system.bus.supply.inService[indexBus] -= 1
            system.bus.supply.active[indexBus] -= output.active[index]
            system.bus.supply.reactive[indexBus] -= output.reactive[index]
            if system.bus.supply.inService[indexBus] == 0
                system.bus.layout.type[indexBus] = 1
            end
        end
        if status == 1
            system.bus.supply.inService[indexBus] += 1
            system.bus.supply.active[indexBus] += output.active[index]
            system.bus.supply.reactive[indexBus] += output.reactive[index]
            system.bus.layout.type[indexBus] = 2
        end
    end
    layout.status[index] = status
end

"""
The function allows changing `active` and `reactive` output power of the generator.

    outputGenerator!(system::PowerSystem; label, active, reactive)

The keywords `label` should correspond to the already defined generator label. Keywords `active`
or `reactive` can be omitted, then the value of the omitted parameter remains unchanged.
"""
function outputGenerator!(system::PowerSystem; user...)
    layout = system.generator.layout
    output = system.generator.output

    if !haskey(user, :label) || user[:label]::Int64 <= 0
        throw(ErrorException("The value of the label keyword must be given as a positive integer."))
    end
    if !haskey(system.generator.label, user[:label])
        throw(ErrorException("The value $(user[:label]) of the label keyword does not exist in generator labels."))
    end

    index = system.generator.label[user[:label]]
    indexBus = layout.bus[index]

    if haskey(user, :active) || haskey(user, :reactive)
        if layout.status[index] == 1
            system.bus.supply.active[indexBus] -= output.active[index]
            system.bus.supply.reactive[indexBus] -= output.reactive[index]
        end

        if haskey(user, :active)
            output.active[index] = user[:active]::Float64
        end
        if haskey(user, :reactive)
            output.reactive[index] = user[:reactive]::Float64
        end

        if layout.status[index] == 1
            system.bus.supply.active[indexBus] += output.active[index]
            system.bus.supply.reactive[indexBus] += output.reactive[index]
        end
    end
end

"""
We advise the reader to read the section [in-depth DC Model](@ref inDepthDCModel),
that explains all the data involved in the field `dcModel`.

    dcModel!(system::PowerSystem)

The function affects field `dcModel`. Once formed, the field will be automatically updated
when using functions `addBranch!()`, `statusBranch!()`, `parameterBranch!()`.
"""
function dcModel!(system::PowerSystem)
    dc = system.dcModel
    layout = system.branch.layout
    parameter = system.branch.parameter

    dc.shiftActivePower = fill(0.0, system.bus.number)
    dc.admittance = fill(0.0, system.branch.number)
    nodalDiagonals = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            if parameter.turnsRatio[i] == 0
                dc.admittance[i] = 1 / parameter.reactance[i]
            else
                dc.admittance[i] = 1 / (parameter.turnsRatio[i] * parameter.reactance[i])
            end

            from = layout.from[i]
            to = layout.to[i]

            shift = parameter.shiftAngle[i] * dc.admittance[i]
            dc.shiftActivePower[from] -= shift
            dc.shiftActivePower[to] += shift

            nodalDiagonals[from] += dc.admittance[i]
            nodalDiagonals[to] += dc.admittance[i]
        end
    end

    busIndex = collect(1:system.bus.number)
    dc.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; -dc.admittance; -dc.admittance], system.bus.number, system.bus.number)
end

######### Update DC Nodal Matrix ##########
function dcNodalShiftUpdate!(system, index::Int64)
    dc = system.dcModel
    layout = system.branch.layout
    parameter = system.branch.parameter

    from = layout.from[index]
    to = layout.to[index]
    admittance = dc.admittance[index]

    shift = parameter.shiftAngle[index] * admittance
    dc.shiftActivePower[from] -= shift
    dc.shiftActivePower[to] += shift

    dc.nodalMatrix[from, from] += admittance
    dc.nodalMatrix[to, to] += admittance
    dc.nodalMatrix[from, to] -= admittance
    dc.nodalMatrix[to, from] -= admittance
end

######### Update DC Parameters ##########
@inline function dcParameterUpdate!(system::PowerSystem, index::Int64)
    dc = system.dcModel
    parameter = system.branch.parameter

    if parameter.turnsRatio[index] == 0
        dc.admittance[index] = 1 / parameter.reactance[index]
    else
        dc.admittance[index] = 1 / (parameter.turnsRatio[index] * parameter.reactance[index])
    end
end

"""
We advise the reader to read the section [in-depth AC Model](@ref inDepthACModel),
that explains all the data involved in the field `acModel`.

    acModel!(system::PowerSystem)

The function affects field `acModel`. Once formed, the field will be automatically updated
when using functions `addBranch!()`, `shuntBus!()`, `statusBranch!()` `parameterBranch!()`.
"""
function acModel!(system::PowerSystem)
    ac = system.acModel
    layout = system.branch.layout
    parameter = system.branch.parameter

    ac.transformerRatio  = zeros(ComplexF64, system.branch.number)
    ac.admittance = zeros(ComplexF64, system.branch.number)
    ac.nodalToTo = zeros(ComplexF64, system.branch.number)
    ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
    ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
    ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
    nodalDiagonals = zeros(ComplexF64, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            ac.admittance[i] = 1 / (parameter.resistance[i] + im * parameter.reactance[i])

            if parameter.turnsRatio[i] == 0
                ac.transformerRatio[i] = exp(im * parameter.shiftAngle[i])
            else
                ac.transformerRatio[i] = parameter.turnsRatio[i] * exp(im * parameter.shiftAngle[i])
            end

            transformerRatioConj = conj(ac.transformerRatio[i])
            ac.nodalToTo[i] = ac.admittance[i] + im * 0.5 * parameter.susceptance[i]
            ac.nodalFromFrom[i] = ac.nodalToTo[i] / (transformerRatioConj * ac.transformerRatio[i])
            ac.nodalFromTo[i] = -ac.admittance[i] / transformerRatioConj
            ac.nodalToFrom[i] = -ac.admittance[i] / ac.transformerRatio[i]

            nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
            nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
        end
    end

    for i = 1:system.bus.number
        nodalDiagonals[i] += system.bus.shunt.conductance[i] + im * system.bus.shunt.susceptance[i]
    end

    busIndex = collect(1:system.bus.number)
    ac.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom], system.bus.number, system.bus.number)

    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

######### Update AC Nodal Matrix ##########
@inline function acNodalUpdate!(system::PowerSystem, index::Int64)
    ac = system.acModel
    layout = system.branch.layout

    from = layout.from[index]
    to = layout.to[index]

    ac.nodalMatrix[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrix[to, to] += ac.nodalToTo[index]
    ac.nodalMatrixTranspose[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrixTranspose[to, to] += ac.nodalToTo[index]

    ac.nodalMatrix[from, to] += ac.nodalFromTo[index]
    ac.nodalMatrix[to, from] += ac.nodalToFrom[index]
    ac.nodalMatrixTranspose[to, from] += ac.nodalFromTo[index]
    ac.nodalMatrixTranspose[from, to] += ac.nodalToFrom[index]
end

######### Update AC Parameters ##########
@inline function acParameterUpdate!(system::PowerSystem, index::Int64)
    ac = system.acModel
    parameter = system.branch.parameter

    ac.admittance[index] = 1 / (parameter.resistance[index] + im * parameter.reactance[index])

    if parameter.turnsRatio[index] == 0
        ac.transformerRatio[index] = exp(im * parameter.shiftAngle[index])
    else
        ac.transformerRatio[index] = parameter.turnsRatio[index] * exp(im * parameter.shiftAngle[index])
    end

    transformerRatioConj = conj(ac.transformerRatio[index])
    ac.nodalToTo[index] = ac.admittance[index] + im * 0.5 * parameter.susceptance[index]
    ac.nodalFromFrom[index] = ac.nodalToTo[index] / (transformerRatioConj * ac.transformerRatio[index])
    ac.nodalFromTo[index] = -ac.admittance[index] / transformerRatioConj
    ac.nodalToFrom[index] = -ac.admittance[index] / ac.transformerRatio[index]
end

function nilModel!(system::PowerSystem, flag::Symbol; index::Int64 = 0)
    dc = system.dcModel
    ac = system.acModel

    if flag == :dcModelEmpty
        dc.nodalMatrix = spzeros(1, 1)
        dc.admittance =  Array{Float64,1}(undef, 0)
        dc.shiftActivePower = Array{Float64,1}(undef, 0)
    end

    if flag == :acModelEmpty
        ac.nodalMatrix = spzeros(1, 1)
        ac.nodalMatrixTranspose = spzeros(1, 1)
        ac.nodalToTo =  Array{ComplexF64,1}(undef, 0)
        ac.nodalFromFrom = Array{ComplexF64,1}(undef, 0)
        ac.nodalFromTo = Array{ComplexF64,1}(undef, 0)
        ac.nodalToFrom = Array{ComplexF64,1}(undef, 0)
        ac.admittance = Array{ComplexF64,1}(undef, 0)
        ac.transformerRatio = Array{ComplexF64,1}(undef, 0)
    end

    if flag == :dcModelZeros
        dc.admittance[index] = 0.0
    end

    if flag == :acModelZeros
        ac.nodalFromFrom[index] = 0.0 + im * 0.0
        ac.nodalFromTo[index] = 0.0 + im * 0.0
        ac.nodalToTo[index] = 0.0 + im * 0.0
        ac.nodalToFrom[index] = 0.0 + im * 0.0
        ac.admittance[index] = 0.0 + im * 0.0
        ac.transformerRatio[index] = 0.0 + im * 0.0
    end

    if flag == :dcModelPushZeros
        push!(dc.admittance, 0.0)
    end

    if flag == :acModelPushZeros
        push!(ac.admittance, 0.0 + im * 0.0)
        push!(ac.nodalToTo, 0.0 + im * 0.0)
        push!(ac.nodalFromFrom, 0.0 + im * 0.0)
        push!(ac.nodalFromTo, 0.0 + im * 0.0)
        push!(ac.nodalToFrom, 0.0 + im * 0.0)
        push!(ac.transformerRatio, 0.0 + im * 0.0)
    end

    if flag == :dcModelDeprive
        dc.admittance[index] = -dc.admittance[index]
    end

    if flag == :acModelDeprive
        ac.nodalFromFrom[index] = -ac.nodalFromFrom[index]
        ac.nodalFromTo[index] = -ac.nodalFromTo[index]
        ac.nodalToTo[index] = -ac.nodalToTo[index]
        ac.nodalToFrom[index] =-ac.nodalToFrom[index]
        ac.admittance[index] = -ac.admittance[index]
        ac.transformerRatio[index] = -ac.transformerRatio[index]
    end
end

