######### Bus ##########
mutable struct BusDemand
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct BusShunt
    conductance::Array{Float64,1}
    susceptance::Array{Float64,1}
end

mutable struct BusVoltage
    magnitude::Array{Float64,1}
    angle::Array{Float64,1}
    minMagnitude::Array{Float64,1}
    maxMagnitude::Array{Float64,1}
    base::Array{Float64,1}
end

mutable struct BusLayout
    type::Array{Int64,1}
    area::Array{Int64,1}
    lossZone::Array{Int64,1}
    slackIndex::Int64
    slackImmutable::Int64
    renumbering::Bool
end

mutable struct BusSupply
    active::Array{Float64,1}
    reactive::Array{Float64,1}
    inService::Array{Int64,1}
end

mutable struct Bus
    label::Dict{Int64, Int64}
    demand::BusDemand
    shunt::BusShunt
    voltage::BusVoltage
    layout::BusLayout
    supply::BusSupply
    number::Int64
end

######### Branch ##########
mutable struct BranchParameter
    resistance::Array{Float64,1}
    reactance::Array{Float64,1}
    susceptance::Array{Float64,1}
    turnsRatio::Array{Float64,1}
    shiftAngle::Array{Float64,1}
end

mutable struct BranchRating
    longTerm::Array{Float64,1}
    shortTerm::Array{Float64,1}
    emergency::Array{Float64,1}
end

mutable struct BranchVoltage
    minAngleDifference::Array{Float64,1}
    maxAngleDifference::Array{Float64,1}
end

mutable struct BranchLayout
    from::Array{Int64,1}
    to::Array{Int64,1}
    status::Array{Int64,1}
    renumbering::Bool
end

mutable struct Branch
    label::Dict{Int64, Int64}
    parameter::BranchParameter
    rating::BranchRating
    voltage::BranchVoltage
    layout::BranchLayout
    number::Int64
end

######### Generator ##########
mutable struct GeneratorOutput
    active::Array{Float64,1}
    reactive::Array{Float64,1}
end

mutable struct GeneratorCapability
    minActive::Array{Float64,1}
    maxActive::Array{Float64,1}
    minReactive::Array{Float64,1}
    maxReactive::Array{Float64,1}
    lowerActive::Array{Float64,1}
    minReactiveLower::Array{Float64,1}
    maxReactiveLower::Array{Float64,1}
    upperActive::Array{Float64,1}
    minReactiveUpper::Array{Float64,1}
    maxReactiveUpper::Array{Float64,1}
end

mutable struct GeneratorRampRate
    loadFollowing ::Array{Float64,1}
    reserve10minute::Array{Float64,1}
    reserve30minute::Array{Float64,1}
    reactiveTimescale::Array{Float64,1}
end

mutable struct GeneratorCost
    activeModel::Array{Int64,1}
    activeStartup::Array{Float64,1}
    activeShutdown::Array{Float64,1}
    activeDataPoint::Array{Int64,1}
    activeCoefficient::Array{Float64,2}
    reactiveModel::Array{Int64,1}
    reactiveStartup::Array{Float64,1}
    reactiveShutdown::Array{Float64,1}
    reactiveDataPoint::Array{Int64,1}
    reactiveCoefficient::Array{Float64,2}
end

mutable struct GeneratorVoltage
    magnitude::Array{Float64,1}
end

mutable struct GeneratorLayout
    bus::Array{Int64,1}
    area::Array{Float64,1}
    status::Array{Int64,1}
    violate::Array{Int64,1}
end

mutable struct Generator
    label::Dict{Int64, Int64}
    output::GeneratorOutput
    capability::GeneratorCapability
    rampRate::GeneratorRampRate
    cost::GeneratorCost
    voltage::GeneratorVoltage
    layout::GeneratorLayout
    number::Int64
end

######### DC Model ##########
mutable struct DCModel
    nodalMatrix::SparseMatrixCSC{Float64,Int64}
    admittance::Array{Float64,1}
    shiftActivePower::Array{Float64,1}
end

######### AC Model ##########
mutable struct ACModel
    nodalMatrix::SparseMatrixCSC{ComplexF64,Int64}
    nodalMatrixTranspose::SparseMatrixCSC{ComplexF64,Int64}
    nodalFromFrom::Array{ComplexF64,1}
    nodalFromTo::Array{ComplexF64,1}
    nodalToTo::Array{ComplexF64,1}
    nodalToFrom::Array{ComplexF64,1}
    admittance::Array{ComplexF64,1}
    transformerRatio::Array{ComplexF64,1}
end

######### Power System ##########
mutable struct PowerSystem
    bus::Bus
    branch::Branch
    generator::Generator
    acModel::ACModel
    dcModel::DCModel
    basePower::Float64
end


"""
The path to the HDF5 file with `.h5` extension should be passed to the function:

    powerSystem("pathToExternalData/name.h5")

The path to the HDF5 file with `.h5` extension should be passed to the function.  Similarly,
the path to the Matpower file with `.m` extension should be passed to the same function.
Then, it is possible to add new power system elements and manipulate the existing ones.
"""
function powerSystem(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)
    acModel, dcModel = makeModel()

    if extension == ".h5"
        system = h5open(fullpath, "r")
            basePower = loadBasePower(system)
            bus = loadBus(system)
            branch = loadBranch(system, bus)
            generator = loadGenerator(system, bus)
        close(system)
    end

    if extension == ".m"
        busLine, branchLine, generatorLine, generatorcostLine, basePower = readMATLAB(fullpath)
        bus = loadBus(busLine, basePower)
        branch = loadBranch(branchLine, bus, basePower)
        generator = loadGenerator(generatorLine, generatorcostLine, bus, basePower)
        basePower *= 1e6
    end

    return PowerSystem(bus, branch, generator, acModel, dcModel, basePower)
end

######## Load Base Power from HDF5 File ##########
function loadBasePower(system)
    if exists(system, "basePower")
        basePower::Float64 = read(system["basePower"])
    else
        basePower = 1e8
        @info("The variable basePower not found. The algorithm proceeds with default value of 1e8 VA.")
    end

    return basePower
end

######## Load Bus Data from HDF5 File ##########
function loadBus(system)
    if !exists(system, "bus")
        throw(ErrorException("The bus data is missing."))
    end
    renumbering = false

    layout = system["bus/layout"]
    labelOriginal::Array{Int64,1} = readmmap(layout["label"])

    busNumber = length(labelOriginal)
    label = Dict{Int64, Int64}(); sizehint!(label, busNumber)
    @inbounds for i = 1:busNumber
        j = labelOriginal[i]
        if !renumbering && i != j
            renumbering = true
        end
        label[j] = i
    end

    area = arrayInteger(layout, "area", busNumber)
    lossZone = arrayInteger(layout, "lossZone", busNumber)
    type = fill(1, busNumber)

    demand = system["bus/demand"]
    active = arrayFloat(demand, "active", busNumber)
    reactive = arrayFloat(demand, "reactive", busNumber)

    shunt = system["bus/shunt"]
    conductance = arrayFloat(shunt, "conductance", busNumber)
    susceptance = arrayFloat(shunt, "susceptance", busNumber)

    voltage = system["bus/voltage"]
    magnitude = arrayFloat(voltage, "magnitude", busNumber)
    angle = arrayFloat(voltage, "angle", busNumber)
    minMagnitude = arrayFloat(voltage, "minMagnitude", busNumber)
    maxMagnitude = arrayFloat(voltage, "maxMagnitude", busNumber)
    base = arrayFloat(voltage, "base", busNumber)

    slackIndex = label[read(layout["slackLabel"])]

    return Bus(label,
        BusDemand(active, reactive),
        BusShunt(conductance, susceptance),
        BusVoltage(magnitude, angle, minMagnitude, maxMagnitude, base),
        BusLayout(type, area, lossZone, slackIndex, copy(slackIndex), renumbering),
        BusSupply(fill(0.0, busNumber), fill(0.0, busNumber), fill(0, busNumber)), busNumber)
end

######## Load Branch Data from HDF5 File ##########
function loadBranch(system, bus::Bus)
    if !exists(system, "branch")
        throw(ErrorException("The branch data is missing."))
    end
    renumbering = false

    layout = system["branch/layout"]
    labelOriginal::Array{Int64,1} = readmmap(layout["label"])

    branchNumber = length(labelOriginal)
    label = Dict{Int64, Int64}(); sizehint!(label, branchNumber)
    @inbounds for i = 1:branchNumber
        j = labelOriginal[i]
        if !renumbering && i != j
            renumbering = true
        end
        label[j] = i
    end

    status = arrayInteger(layout, "status", branchNumber)
    from::Array{Int64,1} = read(layout["from"])
    to::Array{Int64,1} = read(layout["to"])

    if bus.layout.renumbering
        from = runRenumbering(from, branchNumber, bus.label)
        to = runRenumbering(to, branchNumber, bus.label)
    end

    parameter = system["branch/parameter"]
    resistance = arrayFloat(parameter, "resistance", branchNumber)
    reactance = arrayFloat(parameter, "reactance", branchNumber)
    susceptance = arrayFloat(parameter, "susceptance", branchNumber)
    turnsRatio = arrayFloat(parameter, "turnsRatio", branchNumber)
    shiftAngle = arrayFloat(parameter, "shiftAngle", branchNumber)

    rating = system["branch/rating"]
    longTerm = arrayFloat(rating, "longTerm", branchNumber)
    shortTerm = arrayFloat(rating, "shortTerm", branchNumber)
    emergency = arrayFloat(rating, "emergency", branchNumber)

    voltage = system["branch/voltage"]
    minAngleDifference = arrayFloat(voltage, "minAngleDifference", branchNumber)
    maxAngleDifference = arrayFloat(voltage, "maxAngleDifference", branchNumber)

    return Branch(label,
        BranchParameter(resistance, reactance, susceptance, turnsRatio, shiftAngle),
        BranchRating(longTerm, shortTerm, emergency),
        BranchVoltage(minAngleDifference, maxAngleDifference),
        BranchLayout(from, to, status, renumbering), branchNumber)
end

######## Load Generator Data from HDF5 File ##########
function loadGenerator(system, bus::Bus)
    if !exists(system, "generator")
        throw(ErrorException("The generator data is missing."))
    end

    layout = system["generator/layout"]
    labelOriginal::Array{Int64,1} = readmmap(layout["label"])
    busIndex::Array{Int64,1} = read(layout["bus"])

    generatorNumber = length(busIndex)
    if bus.layout.renumbering
        busIndex = runRenumbering(busIndex, generatorNumber, bus.label)
    end

    area = arrayFloat(layout, "area", generatorNumber)
    status = arrayInteger(layout, "status", generatorNumber)

    output = system["generator/output"]
    active = arrayFloat(output, "active", generatorNumber)
    reactive = arrayFloat(output, "reactive", generatorNumber)

    capability = system["generator/capability"]
    minActive = arrayFloat(capability, "minActive", generatorNumber)
    maxActive = arrayFloat(capability, "maxActive", generatorNumber)
    minReactive = arrayFloat(capability, "minReactive", generatorNumber)
    maxReactive = arrayFloat(capability, "maxReactive", generatorNumber)
    lowerActive = arrayFloat(capability, "lowerActive", generatorNumber)
    minReactiveLower = arrayFloat(capability, "minReactiveLower", generatorNumber)
    maxReactiveLower = arrayFloat(capability, "maxReactiveLower", generatorNumber)
    upperActive = arrayFloat(capability, "upperActive", generatorNumber)
    minReactiveUpper = arrayFloat(capability, "minReactiveUpper", generatorNumber)
    maxReactiveUpper = arrayFloat(capability, "maxReactiveUpper", generatorNumber)

    rampRate = system["generator/rampRate"]
    loadFollowing = arrayFloat(rampRate, "loadFollowing", generatorNumber)
    reserve10minute = arrayFloat(rampRate, "reserve10minute", generatorNumber)
    reserve30minute = arrayFloat(rampRate, "reserve30minute", generatorNumber)
    reactiveTimescale = arrayFloat(rampRate, "reactiveTimescale", generatorNumber)

    voltage = system["generator/voltage"]
    magnitude = arrayFloat(voltage, "magnitude", generatorNumber)

    cost = system["generator/cost"]
    if exists(cost, "activeModel")
        activeModel = arrayInteger(cost, "activeModel", generatorNumber)
        activeStartup = arrayFloat(cost, "activeStartup", generatorNumber)
        activeShutdown = arrayFloat(cost, "activeShutdown", generatorNumber)
        activeDataPoint = arrayInteger(cost, "activeDataPoint", generatorNumber)
        activeCoefficient = matrixFloat(cost, "activeCoefficient", generatorNumber)
    else
        activeModel, activeStartup, activeShutdown, activeDataPoint, activeCoefficient = generatorCostDataEmpty()
    end

    if exists(cost, "reactiveModel")
        reactiveModel = arrayInteger(cost, "reactiveModel", generatorNumber)
        reactiveStartup = arrayFloat(cost, "reactiveStartup", generatorNumber)
        reactiveShutdown = arrayFloat(cost, "reactiveShutdown", generatorNumber)
        reactiveDataPoint = arrayInteger(cost, "reactiveDataPoint", generatorNumber)
        reactiveCoefficient = matrixFloat(cost, "reactiveCoefficient", generatorNumber)
    else
        reactiveModel, reactiveStartup, reactiveShutdown, reactiveDataPoint, reactiveCoefficient = generatorCostDataEmpty()
    end

    label = Dict{Int64, Int64}(); sizehint!(label, generatorNumber)
    @inbounds for (k, i) in enumerate(busIndex)
        label[labelOriginal[k]] = k
        if status[k] == 1
            bus.layout.type[i] = 2
            bus.supply.inService[i] += 1
            bus.supply.active[i] += active[k]
            bus.supply.reactive[i] += reactive[k]
        end
    end
    bus.layout.type[bus.layout.slackIndex] = 3

    return Generator(label,
        GeneratorOutput(active, reactive),
        GeneratorCapability(minActive, maxActive, minReactive, maxReactive, lowerActive, minReactiveLower, maxReactiveLower,
        upperActive, minReactiveUpper, maxReactiveUpper),
        GeneratorRampRate(loadFollowing, reserve10minute, reserve30minute, reactiveTimescale),
        GeneratorCost(activeModel, activeStartup, activeShutdown, activeDataPoint, activeCoefficient,
        reactiveModel, reactiveStartup, reactiveShutdown, reactiveDataPoint, reactiveCoefficient),
        GeneratorVoltage(magnitude),
        GeneratorLayout(busIndex, area, status, Int64[]), generatorNumber)
end

######### Load Power System Data from MATLAB File ##########
@inline function readMATLAB(fullpath::String)
    busLine = String[]; busFlag = false
    branchLine = String[]; branchFlag = false
    generatorLine = String[]; generatorFlag = false
    generatorcostLine = String[]; generatorcostFlag = false

    datafile = open(fullpath, "r")
        lines = readlines(datafile)
    close(datafile)

    basePower = 0.0
    @inbounds for (i, line) in enumerate(lines)
        if occursin("mpc.branch", line) && occursin("[", line)
            branchFlag = true
        elseif occursin("mpc.bus", line) && occursin("[", line)
            busFlag = true
        elseif occursin("mpc.gen", line) && occursin("[", line) && !occursin("mpc.gencost", line)
            generatorFlag = true
        elseif occursin("mpc.gencost", line) && occursin("[", line)
            generatorcostFlag = true
        elseif occursin("mpc.baseMVA", line)
            line = split(line, "=")[end]
            line = split(line, ";")[1]
            basePower = parse(Float64, line)
        end

        if branchFlag
            branchFlag, branchLine = parseLine(line, branchFlag, branchLine)
        elseif busFlag
            busFlag, busLine = parseLine(line, busFlag, busLine)
        elseif generatorFlag
            generatorFlag, generatorLine = parseLine(line, generatorFlag, generatorLine)
        elseif generatorcostFlag
            generatorcostFlag, generatorcostLine = parseLine(line, generatorcostFlag, generatorcostLine)
        end
    end

    if basePower == 0
        basePower = 1e8
        @info("The variable basePower not found. The algorithm proceeds with default value of 1e8 VA.")
    end

    return busLine, branchLine, generatorLine, generatorcostLine, basePower
end

######## Load Bus Data from MATLAB File ##########
function loadBus(busLine::Array{String,1}, basePower::Float64)
    if isempty(busLine)
        throw(ErrorException("The bus data is missing."))
    end
    basePowerInv = 1 / basePower
    deg2rad = pi / 180
    renumbering = false
    slackIndex = 0
    busNumber = length(busLine)

    label = Dict{Int64, Int64}(); sizehint!(label, busNumber)
    type = fill(0, busNumber)
    area = similar(type)
    lossZone = similar(type)

    active = fill(0.0, busNumber)
    reactive = similar(active)

    conductance = similar(active)
    susceptance = similar(active)

    magnitude = similar(active)
    angle = similar(active)
    maxMagnitude = similar(active)
    minMagnitude = similar(active)
    base = similar(active)

    @inbounds for (k, line) in enumerate(busLine)
        data = split(line)

        j = parse(Int64, data[1])
        if !renumbering && k != j
            renumbering = true
        end
        label[j] = k

        type[k] = parse(Int64, data[2])
        if type[k] == 3
            slackIndex = k
        end

        area[k] = parse(Int64, data[7])
        lossZone[k] = parse(Int64, data[11])

        active[k] = parse(Float64, data[3]) * basePowerInv
        reactive[k] = parse(Float64, data[4]) * basePowerInv

        conductance[k] = parse(Float64, data[5]) * basePowerInv
        susceptance[k] = parse(Float64, data[6]) * basePowerInv

        magnitude[k] = parse(Float64, data[8])
        angle[k] = parse(Float64, data[9]) * deg2rad
        minMagnitude[k] = parse(Float64, data[13])
        maxMagnitude[k] = parse(Float64, data[12])
        base[k] = parse(Float64, data[10]) * 1e3
    end

    if slackIndex == 0
        slackIndex = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end

    return Bus(label,
        BusDemand(active, reactive),
        BusShunt(conductance, susceptance),
        BusVoltage(magnitude, angle, minMagnitude, maxMagnitude, base),
        BusLayout(type, area, lossZone, slackIndex, copy(slackIndex), renumbering),
        BusSupply(fill(0.0, busNumber), fill(0.0, busNumber), fill(0, busNumber)), busNumber)
end

######## Load Branch Data from MATLAB File ##########
function loadBranch(branchLine::Array{String,1}, bus::Bus, basePower::Float64)
    if isempty(branchLine)
        throw(ErrorException("The branch data is missing."))
    end
    deg2rad = pi / 180
    basePowerInv = 1 / basePower
    renumbering = false
    branchNumber = length(branchLine)

    label = Dict{Int64, Int64}(); sizehint!(label, branchNumber)
    from = fill(0, branchNumber)
    to = similar(from)
    status = similar(from)

    resistance = fill(0.0, branchNumber)
    reactance = similar(resistance)
    susceptance = similar(resistance)
    turnsRatio = similar(resistance)
    shiftAngle = similar(resistance)

    longTerm = similar(resistance)
    shortTerm = similar(resistance)
    emergency = similar(resistance)

    minAngleDifference = similar(resistance)
    maxAngleDifference = similar(resistance)

    @inbounds for (k, line) in enumerate(branchLine)
        data = split(line)

        label[k] = k
        status[k] = parse(Int64, data[11])

        fromOriginal = parse(Int64, data[1])
        from[k] = bus.label[fromOriginal]
        toOriginal = parse(Int64, data[2])
        to[k] = bus.label[toOriginal]

        resistance[k] = parse(Float64, data[3])
        reactance[k] = parse(Float64, data[4])
        susceptance[k] = parse(Float64, data[5])
        turnsRatio[k] = parse(Float64, data[9])
        shiftAngle[k] = parse(Float64, data[10]) * deg2rad

        longTerm[k] = parse(Float64, data[6]) * basePowerInv
        shortTerm[k] = parse(Float64, data[7]) * basePowerInv
        emergency[k] = parse(Float64, data[8]) * basePowerInv

        minAngleDifference[k] = parse(Float64, data[12]) * deg2rad
        maxAngleDifference[k] = parse(Float64, data[13]) * deg2rad
    end

    return Branch(label,
        BranchParameter(resistance, reactance, susceptance, turnsRatio, shiftAngle),
        BranchRating(longTerm, shortTerm, emergency),
        BranchVoltage(minAngleDifference, maxAngleDifference),
        BranchLayout(from, to, status, renumbering), branchNumber)
end

######## Load Generator Data from MATLAB File ##########
function loadGenerator(generatorLine::Array{String,1}, generatorcostLine::Array{String,1}, bus::Bus, basePower::Float64)
    if isempty(generatorLine)
        throw(ErrorException("The branch data is missing."))
    end
    basePowerInv = 1 / basePower
    generatorNumber = length(generatorLine)

    label = Dict{Int64, Int64}(); sizehint!(label, generatorNumber)
    busIndex = fill(0, generatorNumber)

    active = fill(0.0, generatorNumber)
    reactive = similar(active)

    minActive = similar(active)
    maxActive = similar(active)
    minReactive = similar(active)
    maxReactive = similar(active)
    lowerActive = similar(active)
    minReactiveLower = similar(active)
    maxReactiveLower = similar(active)
    upperActive = similar(active)
    minReactiveUpper = similar(active)
    maxReactiveUpper = similar(active)

    loadFollowing = similar(active)
    reserve10minute = similar(active)
    reserve30minute = similar(active)
    reactiveTimescale = similar(active)

    magnitude = similar(active)

    area = similar(active)
    status = similar(busIndex)

    @inbounds for (k, line) in enumerate(generatorLine)
        data = split(line)

        label[k] = k
        busOriginal = parse(Int64, data[1])
        busIndex[k] = bus.label[busOriginal]
        area[k] = parse(Float64, data[21])
        status[k] = parse(Int64, data[8])

        active[k] = parse(Float64, data[2]) * basePowerInv
        reactive[k] = parse(Float64, data[3]) * basePowerInv

        minActive[k] = parse(Float64, data[10]) * basePowerInv
        maxActive[k] = parse(Float64, data[9]) * basePowerInv
        minReactive[k] = parse(Float64, data[5]) * basePowerInv
        maxReactive[k] = parse(Float64, data[4]) * basePowerInv
        lowerActive[k] = parse(Float64, data[11]) * basePowerInv
        minReactiveLower[k] = parse(Float64, data[13]) * basePowerInv
        maxReactiveLower[k] = parse(Float64, data[14]) * basePowerInv
        upperActive[k] = parse(Float64, data[12]) * basePowerInv
        minReactiveUpper[k] = parse(Float64, data[15]) * basePowerInv
        maxReactiveUpper[k] = parse(Float64, data[16]) * basePowerInv

        loadFollowing[k] = parse(Float64, data[17]) * basePowerInv
        reserve10minute[k] = parse(Float64, data[18]) * basePowerInv
        reserve30minute[k] = parse(Float64, data[19]) * basePowerInv
        reactiveTimescale[k] = parse(Float64, data[20]) * basePowerInv

        magnitude[k] = parse(Float64, data[6])

        if status[k] == 1
            i = busIndex[k]

            bus.layout.type[i] = 2
            bus.supply.inService[i] += 1
            bus.supply.active[i] += active[k]
            bus.supply.reactive[i] += reactive[k]
        end
    end
    bus.layout.type[bus.layout.slackIndex] = 3

    if !isempty(generatorcostLine)
        activeModel, activeStartup, activeShutdown, activeDataPoint, activeCoefficient = generatorCostData(generatorcostLine, generatorNumber)
    else
        activeModel, activeStartup, activeShutdown, activeDataPoint, activeCoefficient = generatorCostDataEmpty()
    end

    if !isempty(generatorcostLine) && size(generatorcostLine) == 2 * generatorNumber
        reactiveModel, reactiveStartup, reactiveShutdown, reactiveDataPoint, reactiveCoefficient = generatorCostData(generatorcostLine[generatorNumber + 1:end], generatorNumber)
    else
        reactiveModel, reactiveStartup, reactiveShutdown, reactiveDataPoint, reactiveCoefficient = generatorCostDataEmpty()
    end

    return Generator(label,
        GeneratorOutput(active, reactive),
        GeneratorCapability(minActive, maxActive, minReactive, maxReactive, lowerActive, minReactiveLower, maxReactiveLower,
        upperActive, minReactiveUpper, maxReactiveUpper),
        GeneratorRampRate(loadFollowing, reserve10minute, reserve30minute, reactiveTimescale),
        GeneratorCost(activeModel, activeStartup, activeShutdown, activeDataPoint, activeCoefficient,
        reactiveModel, reactiveStartup, reactiveShutdown, reactiveDataPoint, reactiveCoefficient),
        GeneratorVoltage(magnitude),
        GeneratorLayout(busIndex, area, status, Int64[]), generatorNumber)
end

######## Load Generator Cost Data from MATLAB File ##########
function generatorCostData(generatorCostLine::Array{String, 1}, generatorNumber::Int64)
    pointNumber = length(split(generatorCostLine[1])) - 4
    costModel = fill(0, generatorNumber)
    startup = fill(0.0, generatorNumber)
    shutdown = fill(0.0, generatorNumber)
    dataPoint = fill(0, generatorNumber)
    coefficient = zeros(generatorNumber, pointNumber)

    for i = 1:generatorNumber
        data = split(generatorCostLine[i])

        costModel[i] = parse(Int64, data[1])
        startup[i] = parse(Float64, data[2])
        shutdown[i] = parse(Float64, data[3])
        dataPoint[i] = parse(Int64, data[4])

        for p = 1:pointNumber
            if costModel[i] == 1
                if isodd(p)
                    coefficient[i, p] = parse(Float64, data[4+p]) * basePowerInv
                else
                    coefficient[i, p] = parse(Float64, data[4+p])
                end
            end
            if costModel[i] == 2
                coefficient[i, p] = parse(Float64, data[4+p])
            end
        end
    end

    return costModel, startup, shutdown, dataPoint, coefficient
end

######## Load Generator Cost Empty Model ##########
@inline function generatorCostDataEmpty()
    costModel = Array{Int64,1}(undef, 0)
    startup =  Array{Float64,1}(undef, 0)
    shutdown = Array{Float64,1}(undef, 0)
    dataPoint =  Array{Int64,1}(undef, 0)
    coefficient = Array{Float64,2}(undef, 0, 0)

    return costModel, startup, shutdown, dataPoint, coefficient
end

######### Initialize DC and AC Model #########
@inline function makeModel()
    ac = Array{ComplexF64,1}(undef, 0); af = Array{Float64,1}(undef, 0); sp = spzeros(1, 1)

    return ACModel(copy(sp), copy(sp), ac, copy(ac), copy(ac), copy(ac), copy(ac), copy(ac)), DCModel(sp, copy(af), copy(af))
end

######### Initialize Power System Model #########
function powerSystem()
    af = Array{Float64,1}(undef, 0); ai = Array{Int64,1}(undef, 0); mf = Array{Float64,2}(undef, 0, 0); di = Dict{Int64, Int64}()
    acModel, dcModel = makeModel()

    return PowerSystem(
        Bus(di,
        BusDemand(af, copy(af)),
        BusShunt(copy(af), copy(af)),
        BusVoltage(copy(af), copy(af), copy(af), copy(af), copy(af)),
        BusLayout(ai, copy(ai), copy(ai), 0, 0, false),
        BusSupply(copy(af), copy(af), copy(af)), 0),
        Branch(copy(di),
        BranchParameter(copy(af), copy(af), copy(af), copy(af), copy(af)),
        BranchRating(copy(af), copy(af), copy(af)),
        BranchVoltage(copy(af), copy(af)),
        BranchLayout(copy(ai), copy(ai), copy(ai), false), 0),
        Generator(copy(di),
        GeneratorOutput(copy(af), copy(af)),
        GeneratorCapability(copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af)),
        GeneratorRampRate(copy(af), copy(af), copy(af), copy(af)),
        GeneratorCost(copy(ai), copy(af), copy(af), copy(ai), mf, copy(ai), copy(af), copy(af), copy(ai), copy(mf)),
        GeneratorVoltage(copy(af)),
        GeneratorLayout(copy(ai), copy(af), copy(ai), copy(ai)), 0),
        acModel, dcModel, 1e8)
end

######## Check Array Float64 Data ##########
@inline function arrayFloat(group, key::String, number::Int64)
    if length(group[key]) != 1
        data::Array{Base.Float64,1} = read(group[key])
    else
        data = fill(read(group[key])::Float64, number)
    end

    return data
end

######## Check Array Int64 Data ##########
@inline function arrayInteger(group, key::String, number::Int64)
    if length(group[key]) != 1
        data::Array{Int64,1} = read(group[key])
    else
        data = fill(read(group[key])::Int64, number)
    end

    return data
end

######## Check Matrix Float64 Data ##########
@inline function matrixFloat(group, key::String, number::Int64)
    if size(group[key], 2) != 1
        data::Array{Float64,2} = read(group[key])
    else
        data = repeat(transpose(read(group[key])::Array{Float64,1}), number)
    end

    return data
end

######### Matpower Input Data Parse Lines #########
@inline function parseLine(line::String, flag::Bool, str::Array{String, 1})
    sublines = split(line, "[")[end]
    sublines = split(sublines, ";")

    @inbounds for k in eachindex(sublines)
        subline = strip(sublines[k])
        if !isempty(subline)
            push!(str, subline)
        end
    end

    if occursin("]", line)
        lastlines = split(line, "]")[1]
        lastlines = split(lastlines, ";")
        @inbounds for k in eachindex(lastlines)
            last = lastlines[k]
            if isempty(strip(last))
                pop!(str)
            end
        end
        flag = false
    end

    return flag, str
end