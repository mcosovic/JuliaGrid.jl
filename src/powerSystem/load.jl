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
    renumbering::Bool
end

mutable struct BusSupply
    active::Array{Float64,1}
    reactive::Array{Float64,1}
    inService::Array{Int64,1}
end

mutable struct Bus
    label::Dict{Int64,Int64}
    demand::BusDemand
    supply::BusSupply
    shunt::BusShunt
    voltage::BusVoltage
    layout::BusLayout
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
    label::Dict{Int64,Int64}
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

mutable struct GeneratorRamping
    loadFollowing::Array{Float64,1}
    reserve10minute::Array{Float64,1}
    reserve30minute::Array{Float64,1}
    reactiveTimescale::Array{Float64,1}
end

mutable struct Cost
    model::Array{Int64,1}
    polynomial::Array{Array{Float64,1}}
    piecewise::Array{Array{Float64,2}}
end

mutable struct GeneratorCost
    active::Cost
    reactive::Cost
end

mutable struct GeneratorVoltage
    magnitude::Array{Float64,1}
end

mutable struct GeneratorLayout
    bus::Array{Int64,1}
    area::Array{Float64,1}
    status::Array{Int64,1}
end

mutable struct Generator
    label::Dict{Int64,Int64}
    output::GeneratorOutput
    capability::GeneratorCapability
    ramping::GeneratorRamping
    voltage::GeneratorVoltage
    cost::GeneratorCost
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
    unit::Unit
    basePower::Float64
end

"""
The path to the HDF5 file with the `.h5` extension should be passed to the function:

    powerSystem("pathToExternalData/name.h5")

Similarly, the path to the Matpower file with the `.m` extension should be passed
to the same function:

    powerSystem("pathToExternalData/name.m")

Ignoring the function argument initializes the composite type `PowerSystem`,
which enables building the model from scratch:

    powerSystem()

Once the composite type `PowerSystem` is created it is possible to add new buses,
branches or generators, and also change the parameters of the existing ones.
"""
function powerSystem(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)
    acModel, dcModel = makeModel()

    if extension == ".h5"
        system = h5open(fullpath, "r")
            basePower = loadBasePower(system)
            @time bus = loadBus(system)
            @time branch = loadBranch(system, bus)
            generator = loadGenerator(system, bus)
        close(system)
    end

    if extension == ".m"
        busLine, branchLine, generatorLine, generatorcostLine, basePower = readMATLAB(fullpath)
        @time bus = loadBus(busLine, basePower)
        @time branch = loadBranch(branchLine, bus, basePower)
        @time generator = loadGenerator(generatorLine, generatorcostLine, bus, basePower)
        basePower *= 1e6
    end

    return PowerSystem(bus, branch, generator, acModel, dcModel, unit, basePower)
end


function powerSystem()
    af = Array{Float64,1}(undef, 0)
    ai = Array{Int64,1}(undef, 0)
    label = Dict{Int64,Int64}()
    acModel, dcModel = makeModel()

    demand = BusDemand(af, copy(af))
    supply = BusSupply(copy(af), copy(af), copy(af))
    shunt = BusShunt(copy(af), copy(af))
    voltageBus = BusVoltage(copy(af), copy(af), copy(af), copy(af), copy(af))
    layoutBus = BusLayout(ai, copy(ai), copy(ai), 0, false)

    parameter = BranchParameter(copy(af), copy(af), copy(af), copy(af), copy(af))
    rating = BranchRating(copy(af), copy(af), copy(af))
    voltageBranch = BranchVoltage(copy(af), copy(af))
    layoutBranch = BranchLayout(copy(ai), copy(ai), copy(ai), false)

    output = GeneratorOutput(copy(af), copy(af))
    capability = GeneratorCapability(copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af))
    ramping = GeneratorRamping(copy(af), copy(af), copy(af), copy(af))
    cost = GeneratorCost(Cost(copy(ai), [], []), Cost(copy(ai), [], []))
    voltageGenerator =  GeneratorVoltage(copy(af))
    layoutGenerator = GeneratorLayout(copy(ai), copy(af), copy(ai))

    return PowerSystem(
        Bus(label, demand, supply, shunt, voltageBus, layoutBus, 0),
        Branch(copy(label), parameter, rating, voltageBranch, layoutBranch, 0),
        Generator(copy(label), output, capability, ramping, voltageGenerator, cost, layoutGenerator, 0),
        acModel, dcModel, 1e8)
end

######## Load Base Power from HDF5 File ##########
function loadBasePower(system::HDF5.File)
    if haskey(system, "basePower")
        basePower::Float64 = read(system["basePower"])
    else
        basePower = 1e8
        @info("The variable basePower not found. The algorithm proceeds with default value of 1e8 VA.")
    end

    return basePower
end

######## Load Bus Data from HDF5 File ##########
function loadBus(system::HDF5.File)
    if !haskey(system, "bus")
        throw(ErrorException("The bus data is missing."))
    end
    renumbering = false

    layouth5 = system["bus/layout"]
    labelOriginal::Array{Int64,1} = HDF5.readmmap(layouth5["label"])

    busNumber = length(labelOriginal)
    label = Dict{Int64,Int64}(); sizehint!(label, busNumber)
    @inbounds for i = 1:busNumber
        j = labelOriginal[i]
        if !renumbering && i != j
            renumbering = true
        end
        label[j] = i
    end

    demandh5 = system["bus/demand"]
    active = arrayFloat(demandh5, "active", busNumber)
    reactive = arrayFloat(demandh5, "reactive", busNumber)
    demand = BusDemand(active, reactive)

    supply = BusSupply(fill(0.0, busNumber), fill(0.0, busNumber), fill(0, busNumber))

    shunth5 = system["bus/shunt"]
    conductance = arrayFloat(shunth5, "conductance", busNumber)
    susceptance = arrayFloat(shunth5, "susceptance", busNumber)
    shunt = BusShunt(conductance, susceptance)

    voltageh5 = system["bus/voltage"]
    magnitude = arrayFloat(voltageh5, "magnitude", busNumber)
    angle = arrayFloat(voltageh5, "angle", busNumber)
    minMagnitude = arrayFloat(voltageh5, "minMagnitude", busNumber)
    maxMagnitude = arrayFloat(voltageh5, "maxMagnitude", busNumber)
    base = arrayFloat(voltageh5, "base", busNumber)
    voltage = BusVoltage(magnitude, angle, minMagnitude, maxMagnitude, base)

    type = fill(1, busNumber)
    area = arrayInteger(layouth5, "area", busNumber)
    lossZone = arrayInteger(layouth5, "lossZone", busNumber)
    slackIndex = label[read(layouth5["slackLabel"])]
    layout = BusLayout(type, area, lossZone, slackIndex, renumbering)

    return Bus(label, demand, supply, shunt, voltage, layout, busNumber)
end

######## Load Branch Data from HDF5 File ##########
function loadBranch(system::HDF5.File, bus::Bus)
    if !haskey(system, "branch")
        throw(ErrorException("The branch data is missing."))
    end
    renumbering = false

    layouth5 = system["branch/layout"]
    labelOriginal::Array{Int64,1} = HDF5.readmmap(layouth5["label"])

    branchNumber = length(labelOriginal)
    label = Dict{Int64,Int64}(); sizehint!(label, branchNumber)
    @inbounds for i = 1:branchNumber
        j = labelOriginal[i]
        if !renumbering && i != j
            renumbering = true
        end
        label[j] = i
    end

    parameterh5 = system["branch/parameter"]
    resistance = arrayFloat(parameterh5, "resistance", branchNumber)
    reactance = arrayFloat(parameterh5, "reactance", branchNumber)
    susceptance = arrayFloat(parameterh5, "susceptance", branchNumber)
    turnsRatio = arrayFloat(parameterh5, "turnsRatio", branchNumber)
    shiftAngle = arrayFloat(parameterh5, "shiftAngle", branchNumber)
    parameter = BranchParameter(resistance, reactance, susceptance, turnsRatio, shiftAngle)

    ratingh5 = system["branch/rating"]
    longTerm = arrayFloat(ratingh5, "longTerm", branchNumber)
    shortTerm = arrayFloat(ratingh5, "shortTerm", branchNumber)
    emergency = arrayFloat(ratingh5, "emergency", branchNumber)
    rating = BranchRating(longTerm, shortTerm, emergency)

    voltageh5 = system["branch/voltage"]
    minAngleDifference = arrayFloat(voltageh5, "minAngleDifference", branchNumber)
    maxAngleDifference = arrayFloat(voltageh5, "maxAngleDifference", branchNumber)
    voltage = BranchVoltage(minAngleDifference, maxAngleDifference)

    status = arrayInteger(layouth5, "status", branchNumber)
    from::Array{Int64,1} = read(layouth5["from"])
    to::Array{Int64,1} = read(layouth5["to"])
    if bus.layout.renumbering
        from = runRenumbering(from, branchNumber, bus.label)
        to = runRenumbering(to, branchNumber, bus.label)
    end
    layout = BranchLayout(from, to, status, renumbering)

    return Branch(label, parameter, rating, voltage, layout, branchNumber)
end

######## Load Generator Data from HDF5 File ##########
function loadGenerator(system::HDF5.File, bus::Bus)
    if !haskey(system, "generator")
        throw(ErrorException("The generator data is missing."))
    end

    layouth5 = system["generator/layout"]
    labelOriginal::Array{Int64,1} = HDF5.readmmap(layouth5["label"])
    busIndex::Array{Int64,1} = read(layouth5["bus"])
    generatorNumber = length(busIndex)

    outputh5 = system["generator/output"]
    active = arrayFloat(outputh5, "active", generatorNumber)
    reactive = arrayFloat(outputh5, "reactive", generatorNumber)
    output = GeneratorOutput(active, reactive)

    capabilityh5 = system["generator/capability"]
    minActive = arrayFloat(capabilityh5, "minActive", generatorNumber)
    maxActive = arrayFloat(capabilityh5, "maxActive", generatorNumber)
    minReactive = arrayFloat(capabilityh5, "minReactive", generatorNumber)
    maxReactive = arrayFloat(capabilityh5, "maxReactive", generatorNumber)
    lowerActive = arrayFloat(capabilityh5, "lowerActive", generatorNumber)
    minReactiveLower = arrayFloat(capabilityh5, "minReactiveLower", generatorNumber)
    maxReactiveLower = arrayFloat(capabilityh5, "maxReactiveLower", generatorNumber)
    upperActive = arrayFloat(capabilityh5, "upperActive", generatorNumber)
    minReactiveUpper = arrayFloat(capabilityh5, "minReactiveUpper", generatorNumber)
    maxReactiveUpper = arrayFloat(capabilityh5, "maxReactiveUpper", generatorNumber)
    capability = GeneratorCapability(minActive, maxActive, minReactive, maxReactive, lowerActive, minReactiveLower, maxReactiveLower,
        upperActive, minReactiveUpper, maxReactiveUpper)

    rampingh5 = system["generator/ramping"]
    loadFollowing = arrayFloat(rampingh5, "loadFollowing", generatorNumber)
    reserve10minute = arrayFloat(rampingh5, "reserve10minute", generatorNumber)
    reserve30minute = arrayFloat(rampingh5, "reserve30minute", generatorNumber)
    reactiveTimescale = arrayFloat(rampingh5, "reactiveTimescale", generatorNumber)
    ramping = GeneratorRamping(loadFollowing, reserve10minute, reserve30minute, reactiveTimescale)

    magnitude = arrayFloat(system["generator/voltage"], "magnitude", generatorNumber)
    voltage = GeneratorVoltage(magnitude)

    costh5 = system["generator/cost/active"]
    model = arrayInteger(costh5, "model", generatorNumber)
    polynomial = loadPolynomial(costh5, "polynomial", generatorNumber)
    piecewise = loadPiecewise(costh5, "piecewise", generatorNumber)
    costActive = Cost(model, polynomial, piecewise)

    costh5 = system["generator/cost/reactive"]
    model = arrayInteger(costh5, "model", generatorNumber)
    polynomial = loadPolynomial(costh5, "polynomial", generatorNumber)
    piecewise = loadPiecewise(costh5, "piecewise", generatorNumber)
    costReactive = Cost(model, polynomial, piecewise)

    cost = GeneratorCost(costActive, costReactive)

    if bus.layout.renumbering
        busIndex = runRenumbering(busIndex, generatorNumber, bus.label)
    end
    area = arrayFloat(layouth5, "area", generatorNumber)
    status = arrayInteger(layouth5, "status", generatorNumber)
    layout = GeneratorLayout(busIndex, area, status)

    label = Dict{Int64,Int64}()
    sizehint!(label, generatorNumber)
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

    return Generator(label, output, capability, ramping, voltage, cost, layout, generatorNumber)
end

######### Load Power System Data from MATLAB File ##########
@inline function readMATLAB(fullpath::String)
    busLine = String[]
    busFlag = false
    branchLine = String[]
    branchFlag = false
    generatorLine = String[]
    generatorFlag = false
    generatorcostLine = String[]
    generatorcostFlag = false

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
    type = fill(0, busNumber)
    active = fill(0.0, busNumber)

    label = Dict{Int64,Int64}(); sizehint!(label, busNumber)
    demand = BusDemand(active, similar(active))
    supply = BusSupply(fill(0.0, busNumber), fill(0.0, busNumber), fill(0, busNumber))
    shunt = BusShunt(similar(active), similar(active))
    layout = BusLayout(type, similar(type), similar(type), slackIndex, renumbering)
    voltage = BusVoltage(similar(active), similar(active), similar(active), similar(active), similar(active))

    @inbounds for (k, line) in enumerate(busLine)
        data = split(line)

        bus = parse(Int64, data[1])
        if !renumbering && k != bus
            layout.renumbering = true
        end
        label[bus] = k

        demand.active[k] = parse(Float64, data[3]) * basePowerInv
        demand.reactive[k] = parse(Float64, data[4]) * basePowerInv

        shunt.conductance[k] = parse(Float64, data[5]) * basePowerInv
        shunt.susceptance[k] = parse(Float64, data[6]) * basePowerInv

        voltage.magnitude[k] = parse(Float64, data[8])
        voltage.angle[k] = parse(Float64, data[9]) * deg2rad
        voltage.minMagnitude[k] = parse(Float64, data[13])
        voltage.maxMagnitude[k] = parse(Float64, data[12])
        voltage.base[k] = parse(Float64, data[10]) * 1e3

        layout.type[k] = parse(Int64, data[2])
        layout.area[k] = parse(Int64, data[7])
        layout.lossZone[k] = parse(Int64, data[11])

        if layout.type[k] == 3
            layout.slackIndex = k
        end
    end

    if layout.slackIndex == 0
        layout.slackIndex = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end

    return Bus(label, demand, supply, shunt, voltage, layout, busNumber)
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
    resistance = fill(0.0, branchNumber)
    from = fill(0, branchNumber)

    label = Dict{Int64,Int64}(); sizehint!(label, branchNumber)
    parameter = BranchParameter(resistance, similar(resistance), similar(resistance), similar(resistance), similar(resistance))
    rating = BranchRating(similar(resistance), similar(resistance), similar(resistance))
    voltage = BranchVoltage(similar(resistance), similar(resistance))
    layout = BranchLayout(from, similar(from), similar(from), renumbering)

    @inbounds for (k, line) in enumerate(branchLine)
        data = split(line)

        label[k] = k

        parameter.resistance[k] = parse(Float64, data[3])
        parameter.reactance[k] = parse(Float64, data[4])
        parameter.susceptance[k] = parse(Float64, data[5])
        parameter.turnsRatio[k] = parse(Float64, data[9])
        parameter.shiftAngle[k] = parse(Float64, data[10]) * deg2rad

        rating.longTerm[k] = parse(Float64, data[6]) * basePowerInv
        rating.shortTerm[k] = parse(Float64, data[7]) * basePowerInv
        rating.emergency[k] = parse(Float64, data[8]) * basePowerInv

        voltage.minAngleDifference[k] = parse(Float64, data[12]) * deg2rad
        voltage.maxAngleDifference[k] = parse(Float64, data[13]) * deg2rad

        layout.status[k] = parse(Int64, data[11])
        layout.from[k] = bus.label[parse(Int64, data[1])]
        layout.to[k] = bus.label[parse(Int64, data[2])]
    end

    return Branch(label, parameter, rating, voltage, layout, branchNumber)
end

######## Load Generator Data from MATLAB File ##########
function loadGenerator(generatorLine::Array{String,1}, generatorCostLine::Array{String,1}, bus::Bus, basePower::Float64)
    if isempty(generatorLine)
        throw(ErrorException("The branch data is missing."))
    end

    basePowerInv = 1 / basePower
    generatorNumber = length(generatorLine)
    active = fill(0.0, generatorNumber)
    busIndex = fill(0, generatorNumber)

    label = Dict{Int64,Int64}(); sizehint!(label, generatorNumber)
    output = GeneratorOutput(active, similar(active))
    capability = GeneratorCapability(similar(active), similar(active), similar(active), similar(active), similar(active),
        similar(active), similar(active), similar(active), similar(active), similar(active))
    ramping = GeneratorRamping(similar(active), similar(active), similar(active), similar(active))
    voltage = GeneratorVoltage(similar(active))
    layout = GeneratorLayout(busIndex, similar(active), similar(busIndex))

    @inbounds for (k, line) in enumerate(generatorLine)
        data = split(line)

        label[k] = k

        output.active[k] = parse(Float64, data[2]) * basePowerInv
        output.reactive[k] = parse(Float64, data[3]) * basePowerInv

        capability.minActive[k] = parse(Float64, data[10]) * basePowerInv
        capability.maxActive[k] = parse(Float64, data[9]) * basePowerInv
        capability.minReactive[k] = parse(Float64, data[5]) * basePowerInv
        capability.maxReactive[k] = parse(Float64, data[4]) * basePowerInv
        capability.lowerActive[k] = parse(Float64, data[11]) * basePowerInv
        capability.minReactiveLower[k] = parse(Float64, data[13]) * basePowerInv
        capability.maxReactiveLower[k] = parse(Float64, data[14]) * basePowerInv
        capability.upperActive[k] = parse(Float64, data[12]) * basePowerInv
        capability.minReactiveUpper[k] = parse(Float64, data[15]) * basePowerInv
        capability.maxReactiveUpper[k] = parse(Float64, data[16]) * basePowerInv

        ramping.loadFollowing[k] = parse(Float64, data[17]) * basePowerInv
        ramping.reserve10minute[k] = parse(Float64, data[18]) * basePowerInv
        ramping.reserve30minute[k] = parse(Float64, data[19]) * basePowerInv
        ramping.reactiveTimescale[k] = parse(Float64, data[20]) * basePowerInv

        voltage.magnitude[k] = parse(Float64, data[6])

        layout.bus[k] = bus.label[parse(Int64, data[1])]
        layout.area[k] = parse(Float64, data[21])
        layout.status[k] = parse(Int64, data[8])

        if layout.status[k] == 1
            i = layout.bus[k]

            bus.layout.type[i] = 2
            bus.supply.inService[i] += 1
            bus.supply.active[i] += output.active[k]
            bus.supply.reactive[i] += output.reactive[k]
        end
    end
    bus.layout.type[bus.layout.slackIndex] = 3


    costActive = generatorCostParser(generatorCostLine, generatorNumber, basePower, "active")
    costReactive = generatorCostParser(generatorCostLine, generatorNumber, basePower, "reactive")
    cost = GeneratorCost(costActive, costReactive)

    return Generator(label, output, capability, ramping, voltage, cost, layout, generatorNumber)
end

######## Parser Generator Cost Model ##########
@inline function generatorCostParser(generatorCostLine::Array{String,1}, generatorNumber::Int64, basePower::Float64, type::String)
    model = fill(0, generatorNumber)
    polynomial = [Array{Float64}(undef, 0) for i = 1:generatorNumber]
    piecewise = [Array{Float64}(undef, 0, 0) for i = 1:generatorNumber]

    flag = false
    if type == "active" && !isempty(generatorCostLine)
        start = 0
        flag = true
    end
    if type == "reactive" && size(generatorCostLine, 1) == 2 * generatorNumber
        start = generatorNumber
        flag = true
    end

    basePowerInv = 1 / basePower
    if flag
        pointNumber = length(split(generatorCostLine[1])) - 4

        @inbounds for i = 1:generatorNumber
            data = split(generatorCostLine[i + start])
            model[i] = parse(Int64, data[1])

            if model[i] == 1
                piecewise[i] = zeros(Int64(pointNumber / 2), 2)
                for (k, p) in enumerate(1:2:pointNumber)
                    piecewise[i][k, 1] = parse(Float64, data[4 + p]) * basePowerInv
                end
                for (k, p) in enumerate(2:2:pointNumber)
                    piecewise[i][k, 2] = parse(Float64, data[4 + p])
                end
            end

            if model[i] == 2
                polynomial[i] = fill(0.0, 3)
                if pointNumber >= 3
                    polynomial[i][1] = parse(Float64, data[5]) * basePower^2
                    polynomial[i][2] = parse(Float64, data[6]) * basePower
                    polynomial[i][3] = parse(Float64, data[7])
                elseif pointNumber == 2
                    polynomial[i][2] = parse(Float64, data[5]) * basePower
                    polynomial[i][3] = parse(Float64, data[6])
                end
            end
        end
    end

    return Cost(model, polynomial, piecewise)
end

######### Initialize DC and AC Model #########
@inline function makeModel()
    ac = Array{ComplexF64,1}(undef, 0)
    af = Array{Float64,1}(undef, 0)
    sp = spzeros(1, 1)

    return ACModel(copy(sp), copy(sp), ac, copy(ac), copy(ac), copy(ac), copy(ac), copy(ac)), DCModel(sp, copy(af), copy(af))
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
@inline function loadPolynomial(group, key::String, number::Int64)
    data = [Array{Float64}(undef, 0) for i = 1:number]
    if !isempty(group[key])
        datah5 = HDF5.readmmap(group[key])
        if size(datah5, 2) == 1
            data = [datah5 for i = 1:number]
        else
            for i = 1:number
                data[i] = datah5[:, i]
            end
        end
    end

    return data
end

######## Check Matrix Float64 Data ##########
@inline function loadPiecewise(group, key::String, number::Int64)
    data = [Array{Float64}(undef, 0, 0) for i = 1:number]
    if !isempty(group[key])
        datah5 = HDF5.readmmap(group[key])
        display(datah5)
        if size(datah5, 2) == 2
            data = [datah5 for i = 1:number]
        else
            for (k, i) in enumerate(collect(1:2:2*number))
                data[k] = datah5[:, i:i+1]
            end
        end
    end

    return data
end

######### Matpower Input Data Parse Lines #########
@inline function parseLine(line::String, flag::Bool, str::Array{String,1})
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