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

######### Base Data ##########
mutable struct BasePower
    threePhase::Float64
    unit::String
end

mutable struct BaseVoltage
    lineToLine::Array{Float64,1}
    unit::String
end

mutable struct Base
    power::BasePower
    voltage::BaseVoltage
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
    base::Base
    acModel::ACModel
    dcModel::DCModel
end

"""
To use the `powerSystem()` function, the path to the HDF5 file with the .h5 extension can 
be passed as arguments. For example: 
    
    powerSystem("pathToExternalData/name.h5")

Similarly, the path to the Matpower file with the `.m` extension can be passed to the same 
function:

    powerSystem("pathToExternalData/name.m")

Alternatively, the `PowerSystem` composite type can be initialized by calling the function 
without any arguments: 

    powerSystem()

This allows the model to be built from scratch and modified as needed.

In general, once the composite type `PowerSystem` has been created, it is possible to add 
new buses, branches, or generators, or modify the parameters of existing ones.

# Example
```jldoctest
system = powerSystem("case14.h5")
```
"""
function powerSystem()
    af = Array{Float64,1}(undef, 0)
    ai = Array{Int64,1}(undef, 0)
    sp = spzeros(1, 1)
    ac = Array{ComplexF64,1}(undef, 0)
    label = Dict{Int64,Int64}()

    demand = BusDemand(af, copy(af))
    supply = BusSupply(copy(af), copy(af), copy(af))
    shunt = BusShunt(copy(af), copy(af))
    voltageBus = BusVoltage(copy(af), copy(af), copy(af), copy(af))
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

    basePower = BasePower(1e8, "VA")
    baseVoltage = BaseVoltage(copy(af), "V")

    acModel = ACModel(copy(sp), copy(sp), ac, copy(ac), copy(ac), copy(ac), copy(ac), copy(ac))
    dcModel = DCModel(sp, copy(af), copy(af))

    return PowerSystem(
        Bus(label, demand, supply, shunt, voltageBus, layoutBus, 0),
        Branch(copy(label), parameter, rating, voltageBranch, layoutBranch, 0),
        Generator(copy(label), output, capability, ramping, voltageGenerator, cost, layoutGenerator, 0),
        Base(basePower, baseVoltage),
        acModel, dcModel)
end

function powerSystem(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)
    system = powerSystem()

    # if extension == ".h5"
    #     system = h5open(fullpath, "r")
    #         basePower = loadBasePower(system)
    #         @time bus = loadBus(system)
    #         @time branch = loadBranch(system, bus)
    #         generator = loadGenerator(system, bus)
    #     close(system)
    # end

    if extension == ".m"
        busLine, branchLine, generatorLine, generatorcostLine = readMATLAB(system, fullpath)
        loadBus(system, busLine)
        loadBranch(system, branchLine)
        loadGenerator(system, generatorLine, generatorcostLine)
    end

    return system
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
@inline function readMATLAB(system::PowerSystem, fullpath::String)
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

    system.base.power.threePhase = 0.0
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
            system.base.power.threePhase = parse(Float64, line)
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

    if system.base.power.threePhase == 0
        system.base.power.threePhase = 1e8
        @info("The variable basePower not found. The algorithm proceeds with default value of 1e8 VA.")
    end

    return busLine, branchLine, generatorLine, generatorcostLine
end

######## Load Bus Data from MATLAB File ##########
function loadBus(system::PowerSystem, busLine::Array{String,1})
    if isempty(busLine)
        throw(ErrorException("The bus data is missing."))
    end

    bus = system.bus
    basePowerInv = 1 / system.base.power.threePhase
    deg2rad = pi / 180

    bus.number = length(busLine)
    bus.label = Dict{Int64,Int64}(); sizehint!(bus.label, bus.number)

    bus.demand.active = fill(0.0, bus.number)
    bus.demand.reactive = similar(bus.demand.active)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    bus.supply.inService = fill(0, bus.number)

    bus.shunt.conductance = similar(bus.demand.active)
    bus.shunt.susceptance = similar(bus.demand.active)

    bus.voltage.magnitude = similar(bus.demand.active)
    bus.voltage.angle = similar(bus.demand.active)
    bus.voltage.minMagnitude = similar(bus.demand.active)
    bus.voltage.maxMagnitude = similar(bus.demand.active)

    bus.layout.type = fill(0, bus.number)
    bus.layout.area = similar(bus.layout.type)
    bus.layout.lossZone = similar(bus.layout.type)
    bus.layout.slackIndex = 0
    bus.layout.renumbering = false

    system.base.voltage.lineToLine = similar(bus.demand.active)
    @inbounds for (k, line) in enumerate(busLine)
        data = split(line)

        busIndex = parse(Int64, data[1])
        if !bus.layout.renumbering && k != busIndex
            bus.layout.renumbering = true
        end
        bus.label[busIndex] = k

        bus.demand.active[k] = parse(Float64, data[3]) * basePowerInv
        bus.demand.reactive[k] = parse(Float64, data[4]) * basePowerInv

        bus.shunt.conductance[k] = parse(Float64, data[5]) * basePowerInv
        bus.shunt.susceptance[k] = parse(Float64, data[6]) * basePowerInv

        bus.voltage.magnitude[k] = parse(Float64, data[8])
        bus.voltage.angle[k] = parse(Float64, data[9]) * deg2rad
        bus.voltage.minMagnitude[k] = parse(Float64, data[13])
        bus.voltage.maxMagnitude[k] = parse(Float64, data[12])

        bus.layout.type[k] = parse(Int64, data[2])
        bus.layout.area[k] = parse(Int64, data[7])
        bus.layout.lossZone[k] = parse(Int64, data[11])

        if bus.layout.type[k] == 3
            bus.layout.slackIndex = k
        end

        system.base.voltage.lineToLine[k] = parse(Float64, data[10]) * 1e3
    end

    if bus.layout.slackIndex == 0
        bus.layout.slackIndex = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end
end

######## Load Branch Data from MATLAB File ##########
function loadBranch(system::PowerSystem, branchLine::Array{String,1})
    if isempty(branchLine)
        throw(ErrorException("The branch data is missing."))
    end

    branch = system.branch
    basePowerInv = 1 / system.base.power.threePhase
    deg2rad = pi / 180

    branch.number = length(branchLine)
    branch.label = Dict{Int64,Int64}(); sizehint!(branch.label, branch.number)

    branch.parameter.resistance = fill(0.0, branch.number)
    branch.parameter.reactance = similar(branch.parameter.resistance)
    branch.parameter.susceptance = similar(branch.parameter.resistance)
    branch.parameter.turnsRatio = similar(branch.parameter.resistance)
    branch.parameter.shiftAngle = similar(branch.parameter.resistance)

    branch.rating.longTerm = similar(branch.parameter.resistance)
    branch.rating.shortTerm = similar(branch.parameter.resistance)
    branch.rating.emergency = similar(branch.parameter.resistance)

    branch.voltage.minAngleDifference = similar(branch.parameter.resistance)
    branch.voltage.maxAngleDifference = similar(branch.parameter.resistance)

    branch.layout.from = fill(0, branch.number)
    branch.layout.to = similar( branch.layout.from)
    branch.layout.status = similar(branch.layout.from)
    branch.layout.renumbering = false

    @inbounds for (k, line) in enumerate(branchLine)
        data = split(line)

        branch.label[k] = k

        branch.parameter.resistance[k] = parse(Float64, data[3])
        branch.parameter.reactance[k] = parse(Float64, data[4])
        branch.parameter.susceptance[k] = parse(Float64, data[5])
        branch.parameter.turnsRatio[k] = parse(Float64, data[9])
        branch.parameter.shiftAngle[k] = parse(Float64, data[10]) * deg2rad

        branch.rating.longTerm[k] = parse(Float64, data[6]) * basePowerInv
        branch.rating.shortTerm[k] = parse(Float64, data[7]) * basePowerInv
        branch.rating.emergency[k] = parse(Float64, data[8]) * basePowerInv

        branch.voltage.minAngleDifference[k] = parse(Float64, data[12]) * deg2rad
        branch.voltage.maxAngleDifference[k] = parse(Float64, data[13]) * deg2rad

        branch.layout.status[k] = parse(Int64, data[11])
        branch.layout.from[k] = system.bus.label[parse(Int64, data[1])]
        branch.layout.to[k] = system.bus.label[parse(Int64, data[2])]
    end
end

######## Load Generator Data from MATLAB File ##########
function loadGenerator(system::PowerSystem, generatorLine::Array{String,1}, generatorCostLine::Array{String,1})
    if isempty(generatorLine)
        throw(ErrorException("The branch data is missing."))
    end

    generator = system.generator
    basePowerInv = 1 / system.base.power.threePhase

    generator.number = length(generatorLine)
    generator.label = Dict{Int64,Int64}(); sizehint!(generator.label, generator.number)

    generator.output.active = fill(0.0, generator.number)
    generator.output.reactive = similar(generator.output.active)

    generator.capability.minActive = similar(generator.output.active)
    generator.capability.maxActive = similar(generator.output.active)
    generator.capability.minReactive = similar(generator.output.active)
    generator.capability.maxReactive = similar(generator.output.active)
    generator.capability.lowerActive = similar(generator.output.active)
    generator.capability.minReactiveLower = similar(generator.output.active)
    generator.capability.maxReactiveLower = similar(generator.output.active)
    generator.capability.upperActive = similar(generator.output.active)
    generator.capability.minReactiveUpper = similar(generator.output.active)
    generator.capability.maxReactiveUpper = similar(generator.output.active)

    generator.ramping.loadFollowing = similar(generator.output.active)
    generator.ramping.reserve10minute = similar(generator.output.active)
    generator.ramping.reserve30minute = similar(generator.output.active)
    generator.ramping.reactiveTimescale = similar(generator.output.active)

    generator.voltage.magnitude = similar(generator.output.active)

    generator.layout.bus = fill(0, generator.number)
    generator.layout.area = similar(generator.output.active)
    generator.layout.status = similar(generator.layout.bus)

    @inbounds for (k, line) in enumerate(generatorLine)
        data = split(line)

        generator.label[k] = k

        generator.output.active[k] = parse(Float64, data[2]) * basePowerInv
        generator.output.reactive[k] = parse(Float64, data[3]) * basePowerInv

        generator.capability.minActive[k] = parse(Float64, data[10]) * basePowerInv
        generator.capability.maxActive[k] = parse(Float64, data[9]) * basePowerInv
        generator.capability.minReactive[k] = parse(Float64, data[5]) * basePowerInv
        generator.capability.maxReactive[k] = parse(Float64, data[4]) * basePowerInv
        generator.capability.lowerActive[k] = parse(Float64, data[11]) * basePowerInv
        generator.capability.minReactiveLower[k] = parse(Float64, data[13]) * basePowerInv
        generator.capability.maxReactiveLower[k] = parse(Float64, data[14]) * basePowerInv
        generator.capability.upperActive[k] = parse(Float64, data[12]) * basePowerInv
        generator.capability.minReactiveUpper[k] = parse(Float64, data[15]) * basePowerInv
        generator.capability.maxReactiveUpper[k] = parse(Float64, data[16]) * basePowerInv

        generator.ramping.loadFollowing[k] = parse(Float64, data[17]) * basePowerInv
        generator.ramping.reserve10minute[k] = parse(Float64, data[18]) * basePowerInv
        generator.ramping.reserve30minute[k] = parse(Float64, data[19]) * basePowerInv
        generator.ramping.reactiveTimescale[k] = parse(Float64, data[20]) * basePowerInv

        generator.voltage.magnitude[k] = parse(Float64, data[6])

        generator.layout.bus[k] = system.bus.label[parse(Int64, data[1])]
        generator.layout.area[k] = parse(Float64, data[21])
        generator.layout.status[k] = parse(Int64, data[8])

        if generator.layout.status[k] == 1
            i = generator.layout.bus[k]

            system.bus.layout.type[i] = 2
            system.bus.supply.inService[i] += 1
            system.bus.supply.active[i] += generator.output.active[k]
            system.bus.supply.reactive[i] += generator.output.reactive[k]
        end
    end
    system.bus.layout.type[system.bus.layout.slackIndex] = 3

    generator.cost.active.model = fill(0, system.generator.number)
    generator.cost.active.polynomial = [Array{Float64}(undef, 0) for i = 1:system.generator.number]
    generator.cost.active.piecewise = [Array{Float64}(undef, 0, 0) for i = 1:system.generator.number]

    generator.cost.reactive.model = fill(0, system.generator.number)
    generator.cost.reactive.polynomial = [Array{Float64}(undef, 0) for i = 1:system.generator.number]
    generator.cost.reactive.piecewise = [Array{Float64}(undef, 0, 0) for i = 1:system.generator.number]

    if !isempty(generatorCostLine)
        generatorCostParser(system, system.generator.cost.active, generatorCostLine, 0)
    end

    if size(generatorCostLine, 1) == 2 * generator.number
        generatorCostParser(system, system.generator.cost.reactive, generatorCostLine, generator.number)
    end

    system.base.power.threePhase *= 1e6
end

######## Parser Generator Cost Model ##########
@inline function generatorCostParser(system::PowerSystem, cost::Cost, generatorCostLine::Array{String,1}, start::Int64)
    basePowerInv = 1 / system.base.power.threePhase
    pointNumber = length(split(generatorCostLine[1])) - 4

    @inbounds for i = 1:system.generator.number
        data = split(generatorCostLine[i + start])
        cost.model[i] = parse(Int64, data[1])

        if cost.model[i] == 1
            cost.piecewise[i] = zeros(Int64(pointNumber / 2), 2)
            for (k, p) in enumerate(1:2:pointNumber)
                cost.piecewise[i][k, 1] = parse(Float64, data[4 + p]) * basePowerInv
            end
            for (k, p) in enumerate(2:2:pointNumber)
                cost.piecewise[i][k, 2] = parse(Float64, data[4 + p])
            end
        end

        if cost.model[i] == 2
            cost.polynomial[i] = fill(0.0, 3)
            if pointNumber >= 3
                cost.polynomial[i][1] = parse(Float64, data[5]) * system.base.power.threePhase^2
                cost.polynomial[i][2] = parse(Float64, data[6]) * system.base.power.threePhase
                cost.polynomial[i][3] = parse(Float64, data[7])
            elseif pointNumber == 2
                cost.polynomial[i][2] = parse(Float64, data[5]) * system.base.power.threePhase
                cost.polynomial[i][3] = parse(Float64, data[6])
            end
        end
    end
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