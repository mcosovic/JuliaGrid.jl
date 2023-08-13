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
    type::Array{Int8,1}
    area::Array{Int64,1}
    lossZone::Array{Int64,1}
    slack::Int64
    renumbering::Bool
end

mutable struct BusSupply
    active::Array{Float64,1}
    reactive::Array{Float64,1}
    generator::Array{Array{Int64,1},1}
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
    conductance::Array{Float64,1}
    susceptance::Array{Float64,1}
    turnsRatio::Array{Float64,1}
    shiftAngle::Array{Float64,1}
end

mutable struct BranchRating
    longTerm::Array{Float64,1}
    shortTerm::Array{Float64,1}
    emergency::Array{Float64,1}
    type::Array{Int8,1}
end

mutable struct BranchVoltage
    minDiffAngle::Array{Float64,1}
    maxDiffAngle::Array{Float64,1}
end

mutable struct BranchLayout
    from::Array{Int64,1}
    to::Array{Int64,1}
    status::Array{Int8,1}
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
    lowActive::Array{Float64,1}
    minLowReactive::Array{Float64,1}
    maxLowReactive::Array{Float64,1}
    upActive::Array{Float64,1}
    minUpReactive::Array{Float64,1}
    maxUpReactive::Array{Float64,1}
end

mutable struct GeneratorRamping
    loadFollowing::Array{Float64,1}
    reserve10min::Array{Float64,1}
    reserve30min::Array{Float64,1}
    reactiveTimescale::Array{Float64,1}
end

mutable struct Cost
    model::Array{Int8,1}
    polynomial::Array{Array{Float64,1},1}
    piecewise::Array{Array{Float64,2},1}
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
    status::Array{Int8,1}
    renumbering::Bool
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
    value::Float64
    unit::String
    prefix::Float64
end

mutable struct BaseVoltage
    value::Array{Float64,1}
    unit::String
    prefix::Float64
end

mutable struct BaseData
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
end

mutable struct Model
    ac::ACModel
    dc::DCModel
end

######### Power System ##########
mutable struct PowerSystem
    bus::Bus
    branch::Branch
    generator::Generator
    base::BaseData
    model::Model
end

"""
    powerSystem(file::String)

The function builds the composite type `PowerSystem` and populates `bus`, `branch`, `generator`
and `base` fields. In general, once the composite type `PowerSystem` has been created, it is
possible to add new buses, branches, or generators, or modify the parameters of existing ones.

# Argument
- passing the path to the HDF5 file with the `.h5` extension,
- passing the path to Matpower file with the `.m` extension.

# Returns
The `PowerSystem` composite type with the following fields:
- `bus`: data related to buses;
- `branch`: data related to branches;
- `generator`: data related to generators;
- `base`: base power and base voltages;
- `model`: data associated with AC (nonlinear) or DC (linear) analyses.

# Units
JuliaGrid stores all data in per-units and radians format which are fixed, the exceptions are
base values in volt-amperes and volts. The prefixes for these base values can be changed using
the [`@base`](@ref @base) macro.

# Examples
Load power system data:
```jldoctest
system = powerSystem("case14.h5")
```

Load power system data and build AC and DC models:
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)
dcModel!(system)
```
"""
function powerSystem(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)
    system = powerSystem()

    if extension == ".h5"
        hdf5 = h5open(fullpath, "r")
            loadBus(system, hdf5)
            loadBranch(system, hdf5)
            loadGenerator(system, hdf5)
            loadBase(system, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        busLine, branchLine, generatorLine, generatorcostLine = readMATLAB(system, fullpath)
        loadBus(system, busLine)
        loadBranch(system, branchLine)
        loadGenerator(system, generatorLine, generatorcostLine)
    end

    return system
end

"""
Alternatively, the `PowerSystem` composite type can be initialized by calling the function
without any arguments.

    powerSystem()

This allows the model to be built from scratch and modified as needed. This generates an empty
`PowerSystem` type, with only the base power initialized to 1.0e8 volt-amperes (VA).

# Example
```jldoctest
system = powerSystem()
```
"""
function powerSystem()
    af = Array{Float64,1}(undef, 0)
    ai = Array{Int64,1}(undef, 0)
    ai8 = Array{Int8,1}(undef, 0)
    sp = spzeros(0, 0)
    ac = Array{ComplexF64,1}(undef, 0)
    label = Dict{Int64,Int64}()

    demand = BusDemand(af, copy(af))
    supply = BusSupply(copy(af), copy(af), copy(af))
    shunt = BusShunt(copy(af), copy(af))
    voltageBus = BusVoltage(copy(af), copy(af), copy(af), copy(af))
    layoutBus = BusLayout(ai8, copy(ai), copy(ai), 0, false)

    parameter = BranchParameter(copy(af), copy(af), copy(af), copy(af), copy(af), copy(af))
    rating = BranchRating(copy(af), copy(af), copy(af), copy(ai8))
    voltageBranch = BranchVoltage(copy(af), copy(af))
    layoutBranch = BranchLayout(copy(ai), copy(ai), copy(ai8), false)

    output = GeneratorOutput(copy(af), copy(af))
    capability = GeneratorCapability(copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af), copy(af))
    ramping = GeneratorRamping(copy(af), copy(af), copy(af), copy(af))
    cost = GeneratorCost(Cost(copy(ai8), [], []), Cost(copy(ai), [], []))
    voltageGenerator =  GeneratorVoltage(copy(af))
    layoutGenerator = GeneratorLayout(copy(ai), copy(af), copy(ai8), false)

    basePower = BasePower(1e8, "VA", 1.0)
    baseVoltage = BaseVoltage(copy(af), "V", 1.0)

    acModel = ACModel(copy(sp), copy(sp), ac, copy(ac), copy(ac), copy(ac), copy(ac))
    dcModel = DCModel(sp, copy(af), copy(af))

    return PowerSystem(
        Bus(label, demand, supply, shunt, voltageBus, layoutBus, 0),
        Branch(copy(label), parameter, rating, voltageBranch, layoutBranch, 0),
        Generator(copy(label), output, capability, ramping, voltageGenerator, cost, layoutGenerator, 0),
        BaseData(basePower, baseVoltage),
        Model(acModel, dcModel))
end

######## Load Bus Data from HDF5 File ##########
function loadBus(system::PowerSystem, hdf5::HDF5.File)
    if !haskey(hdf5, "bus")
        throw(ErrorException("The bus data is missing."))
    end
    bus = system.bus

    layouth5 = hdf5["bus/layout"]
    label::Array{Int64,1} = HDF5.readmmap(layouth5["label"])
    bus.layout.type = read(layouth5["type"])

    bus.number = length(label)
    bus.label = Dict{Int64,Int64}(); sizehint!(bus.label, bus.number)
    @inbounds for i = 1:bus.number
        j = label[i]
        if !bus.layout.renumbering && i != j
            bus.layout.renumbering = true
        end
        bus.label[j] = i

        if bus.layout.type[i] == 3
            bus.layout.slack = i
        end
    end

    demandh5 = hdf5["bus/demand"]
    bus.demand.active = readHDF5(demandh5, "active", bus.number)
    bus.demand.reactive = readHDF5(demandh5, "reactive", bus.number)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    bus.supply.generator = [Array{Int64}(undef, 0) for i = 1:bus.number]

    shunth5 = hdf5["bus/shunt"]
    bus.shunt.conductance = readHDF5(shunth5, "conductance", bus.number)
    bus.shunt.susceptance = readHDF5(shunth5, "susceptance", bus.number)

    voltageh5 = hdf5["bus/voltage"]
    bus.voltage.magnitude = readHDF5(voltageh5, "magnitude", bus.number)
    bus.voltage.angle = readHDF5(voltageh5, "angle", bus.number)
    bus.voltage.minMagnitude = readHDF5(voltageh5, "minMagnitude", bus.number)
    bus.voltage.maxMagnitude = readHDF5(voltageh5, "maxMagnitude", bus.number)

    bus.layout.area = readHDF5(layouth5, "area", bus.number)
    bus.layout.lossZone = readHDF5(layouth5, "lossZone", bus.number)
end

######## Load Branch Data from HDF5 File ##########
function loadBranch(system::PowerSystem, hdf5::HDF5.File)
    if !haskey(hdf5, "branch")
        throw(ErrorException("The branch data is missing."))
    end
    branch = system.branch

    layouth5 = hdf5["branch/layout"]
    labelOriginal::Array{Int64,1} = HDF5.readmmap(layouth5["label"])

    branch.number = length(labelOriginal)
    branch.label = Dict{Int64,Int64}(); sizehint!(branch.label, branch.number)
    @inbounds for i = 1:branch.number
        j = labelOriginal[i]
        if !branch.layout.renumbering && i != j
            branch.layout.renumbering = true
        end
        branch.label[j] = i
    end

    parameterh5 = hdf5["branch/parameter"]
    branch.parameter.resistance = readHDF5(parameterh5, "resistance", branch.number)
    branch.parameter.reactance = readHDF5(parameterh5, "reactance", branch.number)
    branch.parameter.conductance = readHDF5(parameterh5, "conductance", branch.number)
    branch.parameter.susceptance = readHDF5(parameterh5, "susceptance", branch.number)
    branch.parameter.turnsRatio = readHDF5(parameterh5, "turnsRatio", branch.number)
    branch.parameter.shiftAngle = readHDF5(parameterh5, "shiftAngle", branch.number)

    voltageh5 = hdf5["branch/voltage"]
    branch.voltage.minDiffAngle = readHDF5(voltageh5, "minDiffAngle", branch.number)
    branch.voltage.maxDiffAngle = readHDF5(voltageh5, "maxDiffAngle", branch.number)

    ratingh5 = hdf5["branch/rating"]
    branch.rating.longTerm = readHDF5(ratingh5, "longTerm", branch.number)
    branch.rating.shortTerm = readHDF5(ratingh5, "shortTerm", branch.number)
    branch.rating.emergency = readHDF5(ratingh5, "emergency", branch.number)
    branch.rating.type = readHDF5(ratingh5, "type", branch.number)

    branch.layout.status = readHDF5(layouth5, "status", branch.number)
    branch.layout.from::Array{Int64,1} = read(layouth5["from"])
    branch.layout.to::Array{Int64,1} = read(layouth5["to"])
    if system.bus.layout.renumbering
        from = runRenumbering(branch.layout.from, branch.number, system.bus.label)
        to = runRenumbering(branch.layout.to, branch.number, system.bus.label)
    end
end

######## Load Generator Data from HDF5 File ##########
function loadGenerator(system::PowerSystem, hdf5::HDF5.File)
    if !haskey(hdf5, "generator")
        throw(ErrorException("The generator data is missing."))
    end
    generator = system.generator

    layouth5 = hdf5["generator/layout"]
    labelOriginal::Array{Int64,1} = HDF5.readmmap(layouth5["label"])
    generator.number = length(labelOriginal)

    outputh5 = hdf5["generator/output"]
    generator.output.active = readHDF5(outputh5, "active", generator.number)
    generator.output.reactive = readHDF5(outputh5, "reactive", generator.number)

    capabilityh5 = hdf5["generator/capability"]
    generator.capability.minActive = readHDF5(capabilityh5, "minActive", generator.number)
    generator.capability.maxActive = readHDF5(capabilityh5, "maxActive", generator.number)
    generator.capability.minReactive = readHDF5(capabilityh5, "minReactive", generator.number)
    generator.capability.maxReactive = readHDF5(capabilityh5, "maxReactive", generator.number)
    generator.capability.lowActive = readHDF5(capabilityh5, "lowActive", generator.number)
    generator.capability.minLowReactive = readHDF5(capabilityh5, "minLowReactive", generator.number)
    generator.capability.maxLowReactive = readHDF5(capabilityh5, "maxLowReactive", generator.number)
    generator.capability.upActive = readHDF5(capabilityh5, "upActive", generator.number)
    generator.capability.minUpReactive = readHDF5(capabilityh5, "minUpReactive", generator.number)
    generator.capability.maxUpReactive = readHDF5(capabilityh5, "maxUpReactive", generator.number)

    rampingh5 = hdf5["generator/ramping"]
    generator.ramping.loadFollowing = readHDF5(rampingh5, "loadFollowing", generator.number)
    generator.ramping.reserve10min = readHDF5(rampingh5, "reserve10min", generator.number)
    generator.ramping.reserve30min = readHDF5(rampingh5, "reserve30min", generator.number)
    generator.ramping.reactiveTimescale = readHDF5(rampingh5, "reactiveTimescale", generator.number)

    generator.voltage.magnitude = readHDF5(hdf5["generator/voltage"], "magnitude", generator.number)

    costh5 = hdf5["generator/cost/active"]
    generator.cost.active.model = readHDF5(costh5, "model", generator.number)
    generator.cost.active.polynomial = loadPolynomial(costh5, "polynomial", generator.number)
    generator.cost.active.piecewise = loadPiecewise(costh5, "piecewise", generator.number)

    costh5 = hdf5["generator/cost/reactive"]
    generator.cost.reactive.model = readHDF5(costh5, "model", generator.number)
    generator.cost.reactive.polynomial = loadPolynomial(costh5, "polynomial", generator.number)
    generator.cost.reactive.piecewise = loadPiecewise(costh5, "piecewise", generator.number)

    generator.layout.bus::Array{Int64,1} = read(layouth5["bus"])
    if system.bus.layout.renumbering
        generator.layout.bus = runRenumbering(generator.layout.bus, generator.number, system.bus.label)
    end
    generator.layout.area = readHDF5(layouth5, "area", generator.number)
    generator.layout.status = readHDF5(layouth5, "status", generator.number)

    generator.label = Dict{Int64,Int64}()
    sizehint!(generator.label, generator.number)
    @inbounds for (k, i) in enumerate(generator.layout.bus)
        generator.label[labelOriginal[k]] = k
        if generator.layout.status[k] == 1
            push!(system.bus.supply.generator[i], k)
            system.bus.supply.active[i] += generator.output.active[k]
            system.bus.supply.reactive[i] += generator.output.reactive[k]
        end
    end
end

######## Load Base Power from HDF5 File ##########
function loadBase(system::PowerSystem, hdf5::HDF5.File)
    if !haskey(hdf5, "base")
        throw(ErrorException("The base data is missing."))
    end

    base = hdf5["base"]
    system.base.power.value = read(base["power"])
    system.base.voltage.value = readHDF5(base, "voltage", system.bus.number)
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

    system.base.power.value = 0.0
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
            system.base.power.value = parse(Float64, line)
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

    if system.base.power == 0
        system.base.power.value = 100
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
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    bus.number = length(busLine)
    bus.label = Dict{Int64,Int64}(); sizehint!(bus.label, bus.number)

    bus.demand.active = fill(0.0, bus.number)
    bus.demand.reactive = similar(bus.demand.active)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)
    bus.supply.generator = [Array{Int64}(undef, 0) for i = 1:bus.number]

    bus.shunt.conductance = similar(bus.demand.active)
    bus.shunt.susceptance = similar(bus.demand.active)

    bus.voltage.magnitude = similar(bus.demand.active)
    bus.voltage.angle = similar(bus.demand.active)
    bus.voltage.minMagnitude = similar(bus.demand.active)
    bus.voltage.maxMagnitude = similar(bus.demand.active)

    bus.layout.type = Array{Int8}(undef, bus.number)
    bus.layout.area = fill(0, bus.number)
    bus.layout.lossZone = similar(bus.layout.area)
    bus.layout.slack = 0
    bus.layout.renumbering = false

    system.base.voltage.value = similar(bus.demand.active)
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

        bus.layout.type[k] = parse(Int8, data[2])
        bus.layout.area[k] = parse(Int64, data[7])
        bus.layout.lossZone[k] = parse(Int64, data[11])

        if bus.layout.type[k] == 3
            bus.layout.slack = k
        end

        system.base.voltage.value[k] = parse(Float64, data[10]) * 1e3
    end

    if bus.layout.slack == 0
        bus.layout.slack = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end
end

######## Load Branch Data from MATLAB File ##########
function loadBranch(system::PowerSystem, branchLine::Array{String,1})
    if isempty(branchLine)
        throw(ErrorException("The branch data is missing."))
    end

    branch = system.branch
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    branch.number = length(branchLine)
    branch.label = Dict{Int64,Int64}(); sizehint!(branch.label, branch.number)

    branch.parameter.conductance = fill(0.0, branch.number)
    branch.parameter.resistance = similar(branch.parameter.conductance)
    branch.parameter.reactance = similar(branch.parameter.conductance)
    branch.parameter.susceptance = similar(branch.parameter.conductance)
    branch.parameter.turnsRatio = similar(branch.parameter.conductance)
    branch.parameter.shiftAngle = similar(branch.parameter.conductance)

    branch.voltage.minDiffAngle = similar(branch.parameter.conductance)
    branch.voltage.maxDiffAngle = similar(branch.parameter.resistance)

    branch.rating.longTerm = similar(branch.parameter.conductance)
    branch.rating.shortTerm = similar(branch.parameter.conductance)
    branch.rating.emergency = similar(branch.parameter.conductance)
    branch.rating.type = fill(Int8(1), branch.number)

    branch.layout.from = fill(0, branch.number)
    branch.layout.to = similar( branch.layout.from)
    branch.layout.status = similar(branch.rating.type)
    branch.layout.renumbering = false

    @inbounds for (k, line) in enumerate(branchLine)
        data = split(line)

        branch.label[k] = k

        branch.parameter.resistance[k] = parse(Float64, data[3])
        branch.parameter.reactance[k] = parse(Float64, data[4])
        branch.parameter.susceptance[k] = parse(Float64, data[5])

        turnsRatio = parse(Float64, data[9])
        if turnsRatio == 0
            branch.parameter.turnsRatio[k] = 1.0
        else
            branch.parameter.turnsRatio[k] = turnsRatio
        end
        branch.parameter.shiftAngle[k] = parse(Float64, data[10]) * deg2rad

        branch.rating.longTerm[k] = parse(Float64, data[6]) * basePowerInv
        branch.rating.shortTerm[k] = parse(Float64, data[7]) * basePowerInv
        branch.rating.emergency[k] = parse(Float64, data[8]) * basePowerInv

        branch.voltage.minDiffAngle[k] = parse(Float64, data[12]) * deg2rad
        branch.voltage.maxDiffAngle[k] = parse(Float64, data[13]) * deg2rad

        branch.layout.status[k] = parse(Int8, data[11])
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
    basePowerInv = 1 / system.base.power.value

    generator.number = length(generatorLine)
    generator.label = Dict{Int64,Int64}(); sizehint!(generator.label, generator.number)

    generator.output.active = fill(0.0, generator.number)
    generator.output.reactive = similar(generator.output.active)

    generator.capability.minActive = similar(generator.output.active)
    generator.capability.maxActive = similar(generator.output.active)
    generator.capability.minReactive = similar(generator.output.active)
    generator.capability.maxReactive = similar(generator.output.active)
    generator.capability.lowActive = similar(generator.output.active)
    generator.capability.minLowReactive = similar(generator.output.active)
    generator.capability.maxLowReactive = similar(generator.output.active)
    generator.capability.upActive = similar(generator.output.active)
    generator.capability.minUpReactive = similar(generator.output.active)
    generator.capability.maxUpReactive = similar(generator.output.active)

    generator.ramping.loadFollowing = similar(generator.output.active)
    generator.ramping.reserve10min = similar(generator.output.active)
    generator.ramping.reserve30min = similar(generator.output.active)
    generator.ramping.reactiveTimescale = similar(generator.output.active)

    generator.voltage.magnitude = similar(generator.output.active)

    generator.layout.bus = fill(0, generator.number)
    generator.layout.area = similar(generator.output.active)
    generator.layout.status = Array{Int8}(undef, generator.number)

    @inbounds for (k, line) in enumerate(generatorLine)
        data = split(line)

        generator.label[k] = k

        generator.output.active[k] = parse(Float64, data[2]) * basePowerInv
        generator.output.reactive[k] = parse(Float64, data[3]) * basePowerInv

        generator.capability.minActive[k] = parse(Float64, data[10]) * basePowerInv
        generator.capability.maxActive[k] = parse(Float64, data[9]) * basePowerInv
        generator.capability.minReactive[k] = parse(Float64, data[5]) * basePowerInv
        generator.capability.maxReactive[k] = parse(Float64, data[4]) * basePowerInv
        generator.capability.lowActive[k] = parse(Float64, data[11]) * basePowerInv
        generator.capability.minLowReactive[k] = parse(Float64, data[13]) * basePowerInv
        generator.capability.maxLowReactive[k] = parse(Float64, data[14]) * basePowerInv
        generator.capability.upActive[k] = parse(Float64, data[12]) * basePowerInv
        generator.capability.minUpReactive[k] = parse(Float64, data[15]) * basePowerInv
        generator.capability.maxUpReactive[k] = parse(Float64, data[16]) * basePowerInv

        generator.ramping.loadFollowing[k] = parse(Float64, data[17]) * basePowerInv
        generator.ramping.reserve10min[k] = parse(Float64, data[18]) * basePowerInv
        generator.ramping.reserve30min[k] = parse(Float64, data[19]) * basePowerInv
        generator.ramping.reactiveTimescale[k] = parse(Float64, data[20]) * basePowerInv

        generator.voltage.magnitude[k] = parse(Float64, data[6])

        generator.layout.bus[k] = system.bus.label[parse(Int64, data[1])]
        generator.layout.area[k] = parse(Float64, data[21])
        generator.layout.status[k] = parse(Int8, data[8])

        if generator.layout.status[k] == 1
            i = generator.layout.bus[k]

            push!(system.bus.supply.generator[i], k)
            system.bus.supply.active[i] += generator.output.active[k]
            system.bus.supply.reactive[i] += generator.output.reactive[k]
        end
    end

    generator.cost.active.model = fill(Int8(1), system.generator.number)
    generator.cost.active.polynomial = [Array{Float64}(undef, 0) for i = 1:system.generator.number]
    generator.cost.active.piecewise = [Array{Float64}(undef, 0, 0) for i = 1:system.generator.number]

    generator.cost.reactive.model = fill(Int8(1), system.generator.number)
    generator.cost.reactive.polynomial = [Array{Float64}(undef, 0) for i = 1:system.generator.number]
    generator.cost.reactive.piecewise = [Array{Float64}(undef, 0, 0) for i = 1:system.generator.number]

    if !isempty(generatorCostLine)
        generatorCostParser(system, system.generator.cost.active, generatorCostLine, 0)
    end

    if size(generatorCostLine, 1) == 2 * generator.number
        generatorCostParser(system, system.generator.cost.reactive, generatorCostLine, generator.number)
    end

    system.base.power.value *= 1e6
end

######## Parser Generator Cost Model ##########
@inline function generatorCostParser(system::PowerSystem, cost::Cost, generatorCostLine::Array{String,1}, start::Int64)
    basePowerInv = 1 / system.base.power.value

    @inbounds for i = 1:system.generator.number
        data = split(generatorCostLine[i + start])
        pointNumber = parse(Int64, data[4])
        cost.model[i] = parse(Int8, data[1])

        if cost.model[i] == 1
            cost.piecewise[i] = zeros(pointNumber, 2)
            for (k, p) in enumerate(1:2:(2 * pointNumber))
                cost.piecewise[i][k, 1] = parse(Float64, data[4 + p]) * basePowerInv
            end
            for (k, p) in enumerate(2:2:(2 * pointNumber))
                cost.piecewise[i][k, 2] = parse(Float64, data[4 + p])
            end
        end

        if cost.model[i] == 2
            cost.polynomial[i] = fill(0.0, pointNumber)
            for k = 1:pointNumber
                cost.polynomial[i][k] = parse(Float64, data[4 + k]) * system.base.power.value^(pointNumber - k)
            end
        end
    end
end

######## Read Data From HDF5 File ##########
@inline function readHDF5(group, key::String, number::Int64)
    if length(group[key]) != 1
        data::Union{Array{Float64,1}, Array{Int64,1}, Array{Int8,1}} = read(group[key])
    else
        data = fill(read(group[key])::Union{Float64, Int64, Int8}, number)
    end

    return data
end

######## Check Matrix Float64 Data ##########
@inline function loadPolynomial(group, key::String, number::Int64)
    data = [Array{Float64}(undef, 0) for i = 1:number]

    if !isempty(group[key])
        datah5 = HDF5.readmmap(group[key])
        @inbounds for polynomial in eachcol(datah5)
            index = trunc(Int64, polynomial[1])
            indexCoeff = 2 + trunc(Int64, polynomial[2])

            data[index] = polynomial[3:indexCoeff]
        end
    end

    return data
end

######## Check Matrix Float64 Data ##########
@inline function loadPiecewise(group, key::String, number::Int64)
    data = [Array{Float64}(undef, 0, 0) for i = 1:number]

    if !isempty(group[key])
        datah5 = HDF5.readmmap(group[key])

        Nrow = size(datah5, 1)
        current_index = 1
        indexBus = 0
        @inbounds for i = 2:Nrow
            if datah5[i, 1] != datah5[i - 1, 1]
                indexBus = trunc(Int64, datah5[i - 1, 1])
                data[indexBus] = datah5[current_index:(i - 1), 2:3]

                current_index = i
            end
        end
        indexBus = trunc(Int64, datah5[current_index, 1])
        data[indexBus] = datah5[current_index:end, 2:3]
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