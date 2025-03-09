"""
    powerSystem(file::String)

The function builds the composite type `PowerSystem` and populates `bus`, `branch`,
`generator` and `base` fields. Once the type `PowerSystem` has been created, it is
possible to add new buses, branches, or generators, or modify the parameters of
existing ones.

# Argument
It requires a string path to:
- the HDF5 file with the `.h5` extension,
- the Matpower file with the `.m` extension.

# Returns
The `PowerSystem` composite type with the following fields:
- `bus`: Data related to buses.
- `branch`: Data related to branches.
- `generator`: Data related to generators.
- `base`: Base power and base voltages.
- `model`: Data associated with AC and DC analyses.

# Units
JuliaGrid stores all data in per-units and radians format which are fixed, the exceptions
are base values in volt-amperes and volts. The prefixes for these base values can be
changed using the [`@base`](@ref @base) macro.

# Example
```jldoctest
system = powerSystem("case14.h5")
```
"""
function powerSystem(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)

    if extension == ".h5"
        hdf5 = h5open(fullpath, "r")
            checkLabel(hdf5, template)

            system = powerSystem()
            loadBus(system, hdf5)
            loadBranch(system, hdf5)
            loadGenerator(system, hdf5)
            loadBase(system, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        system = powerSystem()

        busLine, branchLine, genLine, costLine = readMATLAB(system, fullpath)
        loadBus(system, busLine)
        loadBranch(system, branchLine)
        loadGenerator(system, genLine, costLine)
    end

    return system
end

"""
    powerSystem()

Alternatively, the `PowerSystem` type can be initialized by calling the function without
any arguments. This allows the model to be built from scratch and modified as needed.
This generates an empty `PowerSystem` type, with only the base power initialized to 1.0e8
volt-amperes.

# Example
```jldoctest
system = powerSystem()
```
"""
function powerSystem()
    PowerSystem(
        Bus(
            OrderedDict{template.config.system, Int64}(),
            BusDemand(Float64[], Float64[]),
            BusSupply(Float64[], Float64[], Dict{Int64, Vector{Int64}}()),
            BusShunt(Float64[], Float64[]),
            BusVoltage(Float64[], Float64[], Float64[], Float64[]),
            BusLayout(Int8[], Int64[], Int64[], 0, 0),
            0
        ),
        Branch(
            OrderedDict{template.config.system, Int64}(),
            BranchParameter(
                Float64[], Float64[], Float64[], Float64[], Float64[], Float64[]
            ),
            BranchFlow(Float64[], Float64[], Float64[], Float64[], Int8[]),
            BranchVoltage(Float64[], Float64[]),
            BranchLayout(Int64[], Int64[], Int8[], 0, 0),
            0
        ),
        Generator(
            OrderedDict{template.config.system, Int64}(),
            GeneratorOutput(Float64[], Float64[]),
            GeneratorCapability(
                Float64[], Float64[], Float64[], Float64[], Float64[],
                Float64[], Float64[], Float64[], Float64[], Float64[]
            ),
            GeneratorRamping(Float64[], Float64[], Float64[], Float64[]),
            GeneratorVoltage(Float64[]),
            GeneratorCost(
                Cost(
                    Int8[],
                    OrderedDict{Int64, Vector{Float64}}(),
                    OrderedDict{Int64, Matrix{Float64}}()
                ),
                Cost(
                    Int8[],
                    OrderedDict{Int64, Vector{Float64}}(),
                    OrderedDict{Int64, Matrix{Float64}}()
                ),            ),
            GeneratorLayout(Int64[], Float64[], Int8[], 0, 0),
            0
        ),
        BaseData(
            BasePower(1e8, "VA", 1.0),
            BaseVoltage(Float64[], "V", 1.0)
        ),
        Model(
            ACModel(
                spzeros(0, 0), spzeros(0, 0), ComplexF64[], ComplexF64[],
                ComplexF64[], ComplexF64[], ComplexF64[], 0, 0
            ),
            DCModel(spzeros(0, 0), Float64[], Float64[], 0, 0)
        )
    )
end

##### Check Label Type from HDF5 File #####
function checkLabel(hdf5::File, template::Template)
    labelType = eltype(hdf5["bus/label"])
    if labelType === Cstring
        template.config.system = String
    else
        template.config.system = Int64
    end
end

##### Load Bus Data from HDF5 File #####
function loadBus(system::PowerSystem, hdf5::File)
    if !haskey(hdf5, "bus")
        throw(ErrorException("The bus data is missing."))
    end
    bus = system.bus

    layouth5 = hdf5["bus/layout"]
    bus.layout.type = read(layouth5["type"])
    bus.number = length(bus.layout.type)

    bus.layout.area = readHDF5(layouth5, "area", bus.number)
    bus.layout.lossZone = readHDF5(layouth5, "lossZone", bus.number)

    bus.label = OrderedDict(zip(read(hdf5["bus/label"]), collect(1:bus.number)))
    @inbounds for i = 1:bus.number
        if bus.layout.type[i] == 3
            bus.layout.slack = i
            break
        end
    end
    bus.layout.label = read(layouth5["label"])

    demandh5 = hdf5["bus/demand"]
    bus.demand.active = readHDF5(demandh5, "active", bus.number)
    bus.demand.reactive = readHDF5(demandh5, "reactive", bus.number)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)

    shunth5 = hdf5["bus/shunt"]
    bus.shunt.conductance = readHDF5(shunth5, "conductance", bus.number)
    bus.shunt.susceptance = readHDF5(shunth5, "susceptance", bus.number)

    voltageh5 = hdf5["bus/voltage"]
    bus.voltage.magnitude = readHDF5(voltageh5, "magnitude", bus.number)
    bus.voltage.angle = readHDF5(voltageh5, "angle", bus.number)
    bus.voltage.minMagnitude = readHDF5(voltageh5, "minMagnitude", bus.number)
    bus.voltage.maxMagnitude = readHDF5(voltageh5, "maxMagnitude", bus.number)
end

##### Load Branch Data from HDF5 File #####
function loadBranch(system::PowerSystem, hdf5::File)
    if !haskey(hdf5, "branch")
        throw(ErrorException("The branch data is missing."))
    end
    branch = system.branch

    layouth5 = hdf5["branch/layout"]
    branch.layout.from = read(layouth5, "from")
    branch.layout.to = read(layouth5, "to")
    branch.number = length(branch.layout.to)
    branch.layout.inservice = attributes(hdf5)["number of in-service branches"][]

    branch.layout.status = readHDF5(layouth5, "status", branch.number)
    branch.label = OrderedDict(zip(read(hdf5["branch/label"]), collect(1:branch.number)))
    branch.layout.label = read(layouth5["label"])

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

    flowh5 = hdf5["branch/flow"]
    branch.flow.minFromBus = readHDF5(flowh5, "minFromBus", branch.number)
    branch.flow.maxFromBus = readHDF5(flowh5, "maxFromBus", branch.number)
    branch.flow.minToBus = readHDF5(flowh5, "minToBus", branch.number)
    branch.flow.maxToBus = readHDF5(flowh5, "maxToBus", branch.number)
    branch.flow.type = readHDF5(flowh5, "type", branch.number)
end

##### Load Generator Data from HDF5 File #####
function loadGenerator(system::PowerSystem, hdf5::File)
    if !haskey(hdf5, "generator")
        throw(ErrorException("The generator data is missing."))
    end
    gen = system.generator

    layouth5 = hdf5["generator/layout"]
    gen.layout.bus = read(layouth5, "bus")
    gen.number = length(gen.layout.bus)

    gen.layout.area = readHDF5(layouth5, "area", gen.number)
    gen.layout.status = readHDF5(layouth5, "status", gen.number)
    gen.layout.inservice = attributes(hdf5)["number of in-service generators"][]
    gen.label = OrderedDict(zip(read(hdf5["generator/label"]), collect(1:gen.number)))
    gen.layout.label = read(layouth5["label"])

    outputh5 = hdf5["generator/output"]
    gen.output.active = readHDF5(outputh5, "active", gen.number)
    gen.output.reactive = readHDF5(outputh5, "reactive", gen.number)

    capabilityh5 = hdf5["generator/capability"]
    gen.capability.minActive = readHDF5(capabilityh5, "minActive", gen.number)
    gen.capability.maxActive = readHDF5(capabilityh5, "maxActive", gen.number)
    gen.capability.minReactive = readHDF5(capabilityh5, "minReactive", gen.number)
    gen.capability.maxReactive = readHDF5(capabilityh5, "maxReactive", gen.number)
    gen.capability.lowActive = readHDF5(capabilityh5, "lowActive", gen.number)
    gen.capability.minLowReactive = readHDF5(capabilityh5, "minLowReactive", gen.number)
    gen.capability.maxLowReactive = readHDF5(capabilityh5, "maxLowReactive", gen.number)
    gen.capability.upActive = readHDF5(capabilityh5, "upActive", gen.number)
    gen.capability.minUpReactive = readHDF5(capabilityh5, "minUpReactive", gen.number)
    gen.capability.maxUpReactive = readHDF5(capabilityh5, "maxUpReactive", gen.number)

    rampingh5 = hdf5["generator/ramping"]
    gen.ramping.loadFollowing = readHDF5(rampingh5, "loadFollowing", gen.number)
    gen.ramping.reserve10min = readHDF5(rampingh5, "reserve10min", gen.number)
    gen.ramping.reserve30min = readHDF5(rampingh5, "reserve30min", gen.number)
    gen.ramping.reactiveRamp = readHDF5(rampingh5, "reactiveRamp", gen.number)

    gen.voltage.magnitude = readHDF5(hdf5["generator/voltage"], "magnitude", gen.number)

    costh5 = hdf5["generator/cost/active"]
    gen.cost.active.model = readHDF5(costh5, "model", gen.number)
    loadPolynomial!(gen.cost.active, costh5)
    loadPiecewise!(gen.cost.active, costh5)

    costh5 = hdf5["generator/cost/reactive"]
    gen.cost.reactive.model = readHDF5(costh5, "model", gen.number)
    loadPolynomial!(gen.cost.reactive, costh5)
    loadPiecewise!(gen.cost.reactive, costh5)

    @inbounds for (k, i) in enumerate(gen.layout.bus)
        if gen.layout.status[k] == 1
            addGenInBus!(system, i, k)
            system.bus.supply.active[i] += gen.output.active[k]
            system.bus.supply.reactive[i] += gen.output.reactive[k]
        end
    end
end

##### Load Base Power from HDF5 File #####
function loadBase(system::PowerSystem, hdf5::File)
    if !haskey(hdf5, "base")
        throw(ErrorException("The base data is missing."))
    end

    base = hdf5["base"]
    system.base.power.value = read(base["power"])
    system.base.voltage.value = readHDF5(base, "voltage", system.bus.number)
end

##### Load Power System Data from MATLAB File #####
@inline function readMATLAB(system::PowerSystem, fullpath::String)
    busLine = String[]
    busFlag = false
    branchLine = String[]
    branchFlag = false
    genLine = String[]
    genFlag = false
    costLine = String[]
    costFlag = false

    system.base.power.value = 0.0
    @inbounds for line in eachline(fullpath)
        if occursin("mpc.branch", line) && occursin("[", line)
            branchFlag = true
        elseif occursin("mpc.bus", line) && occursin("[", line)
            busFlag = true
        elseif occursin("mpc.gen", line) && occursin("[", line) && !occursin("mpc.gencost", line)
            genFlag = true
        elseif occursin("mpc.gencost", line) && occursin("[", line)
            costFlag = true
        elseif occursin("mpc.baseMVA", line)
            line = split(line, "=")[end]
            line = split(line, ";")[1]
            system.base.power.value = parse(Float64, line)
        end

        if busFlag
            busFlag, busLine = parseLine(line, busFlag, busLine)
        elseif branchFlag
            branchFlag, branchLine = parseLine(line, branchFlag, branchLine)
        elseif genFlag
            genFlag, genLine = parseLine(line, genFlag, genLine)
        elseif costFlag
            costFlag, costLine = parseLine(line, costFlag, costLine)
        end
    end

    if system.base.power == 0
        system.base.power.value = 100
        @info("The variable basePower not found. The algorithm proceeds with value of 1e8 VA.")
    end

    return busLine, branchLine, genLine, costLine
end

##### Load Bus Data from MATLAB File #####
function loadBus(system::PowerSystem, busLine::Vector{String})
    if isempty(busLine)
        throw(ErrorException("The bus data is missing."))
    end

    bus = system.bus
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    bus.number = length(busLine)
    bus.label = OrderedDict{template.config.system, Int64}()
    sizehint!(bus.label, bus.number)

    bus.demand.active = fill(0.0, bus.number)
    bus.demand.reactive = similar(bus.demand.active)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)

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

    system.base.voltage.value = similar(bus.demand.active)

    bus.layout.label = 0
    data = Array{SubString{String}}(undef, 13)
    @inbounds for (k, line) in enumerate(eachsplit.(busLine))
        for (i, s) in enumerate(line)
            if i == 14
                break
            end
            data[i] = SubString(s)
        end

        labelInt = parse(Int64, data[1])
        busLabel!(bus.label, data[1], labelInt, k)
        if bus.layout.label < labelInt
            bus.layout.label = labelInt
        end

        bus.layout.type[k] = parse(Int8, data[2])

        bus.demand.active[k] = parse(Float64, data[3]) * basePowerInv
        bus.demand.reactive[k] = parse(Float64, data[4]) * basePowerInv
        bus.shunt.conductance[k] = parse(Float64, data[5]) * basePowerInv
        bus.shunt.susceptance[k] = parse(Float64, data[6]) * basePowerInv

        bus.layout.area[k] = parse(Int64, data[7])

        bus.voltage.magnitude[k] = parse(Float64, data[8])
        bus.voltage.angle[k] = parse(Float64, data[9]) * deg2rad
        system.base.voltage.value[k] = parse(Float64, data[10]) * 1e3

        bus.layout.lossZone[k] = parse(Int64, data[11])

        bus.voltage.maxMagnitude[k] = parse(Float64, data[12])
        bus.voltage.minMagnitude[k] = parse(Float64, data[13])

        if bus.layout.type[k] == 3
            bus.layout.slack = k
        end
    end

    if bus.layout.slack == 0
        bus.layout.slack = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end
end

##### Load Branch Data from MATLAB File #####
function loadBranch(system::PowerSystem, branchLine::Vector{String})
    if isempty(branchLine)
        throw(ErrorException("The branch data is missing."))
    end

    branch = system.branch
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    branch.number = length(branchLine)
    branch.label = OrderedDict{template.config.system, Int64}()
    sizehint!(branch.label, branch.number)

    branch.parameter.conductance = fill(0.0, branch.number)
    branch.parameter.resistance = similar(branch.parameter.conductance)
    branch.parameter.reactance = similar(branch.parameter.conductance)
    branch.parameter.susceptance = similar(branch.parameter.conductance)
    branch.parameter.turnsRatio = similar(branch.parameter.conductance)
    branch.parameter.shiftAngle = similar(branch.parameter.conductance)

    branch.voltage.minDiffAngle = similar(branch.parameter.conductance)
    branch.voltage.maxDiffAngle = similar(branch.parameter.resistance)

    branch.flow.minFromBus = similar(branch.parameter.conductance)
    branch.flow.maxFromBus = similar(branch.parameter.conductance)
    branch.flow.minToBus = similar(branch.parameter.conductance)
    branch.flow.maxToBus = similar(branch.parameter.conductance)
    branch.flow.type = fill(Int8(3), branch.number)

    branch.layout.from = fill(0, branch.number)
    branch.layout.to = similar( branch.layout.from)
    branch.layout.status = similar(branch.flow.type)

    data = Array{SubString{String}}(undef, 13)
    @inbounds for (k, line) in enumerate(eachsplit.(branchLine))
        for (i, s) in enumerate(line)
            if i == 14
                break
            end
            data[i] = SubString(s)
        end

        label!(branch.label, k, k)

        branch.layout.from[k] = getLabelIdx(system.bus.label, data[1])
        branch.layout.to[k] = getLabelIdx(system.bus.label, data[2])

        branch.parameter.resistance[k] = parse(Float64, data[3])
        branch.parameter.reactance[k] = parse(Float64, data[4])
        branch.parameter.susceptance[k] = parse(Float64, data[5])

        longTerm = parse(Float64, data[6]) * basePowerInv
        branch.flow.minFromBus[k] = -longTerm
        branch.flow.maxFromBus[k] = longTerm
        branch.flow.minToBus[k] = -longTerm
        branch.flow.maxToBus[k] = longTerm

        branch.parameter.turnsRatio[k] = parse(Float64, data[9])
        if branch.parameter.turnsRatio[k] == 0.0
            branch.parameter.turnsRatio[k] = 1.0
        end
        branch.parameter.shiftAngle[k] = parse(Float64, data[10]) * deg2rad

        branch.layout.status[k] = parse(Int8, data[11])

        branch.voltage.minDiffAngle[k] = parse(Float64, data[12]) * deg2rad
        branch.voltage.maxDiffAngle[k] = parse(Float64, data[13]) * deg2rad

        if branch.layout.status[k] == 1
            branch.layout.inservice += 1
        end
    end
    branch.layout.label = branch.number
end

##### Load Generator Data from MATLAB File #####
function loadGenerator(system::PowerSystem, genLine::Vector{String}, costLine::Vector{String})
    if isempty(genLine)
        throw(ErrorException("The generator data is missing."))
    end

    gen = system.generator
    basePowerInv = 1 / system.base.power.value

    gen.number = length(genLine)
    gen.label = OrderedDict{template.config.system, Int64}()
    sizehint!(gen.label, gen.number)

    gen.output.active = fill(0.0, gen.number)
    gen.output.reactive = similar(gen.output.active)

    gen.capability.minActive = similar(gen.output.active)
    gen.capability.maxActive = similar(gen.output.active)
    gen.capability.minReactive = similar(gen.output.active)
    gen.capability.maxReactive = similar(gen.output.active)
    gen.capability.lowActive = similar(gen.output.active)
    gen.capability.minLowReactive = similar(gen.output.active)
    gen.capability.maxLowReactive = similar(gen.output.active)
    gen.capability.upActive = similar(gen.output.active)
    gen.capability.minUpReactive = similar(gen.output.active)
    gen.capability.maxUpReactive = similar(gen.output.active)

    gen.ramping.loadFollowing = similar(gen.output.active)
    gen.ramping.reserve10min = similar(gen.output.active)
    gen.ramping.reserve30min = similar(gen.output.active)
    gen.ramping.reactiveRamp = similar(gen.output.active)

    gen.voltage.magnitude = similar(gen.output.active)

    gen.layout.bus = fill(0, gen.number)
    gen.layout.area = similar(gen.output.active)
    gen.layout.status = Array{Int8}(undef, gen.number)

    data = Array{SubString{String}}(undef, 21)
    @inbounds for (k, line) in enumerate(eachsplit.(genLine))
        for (i, s) in enumerate(line)
            if i == 22
                break
            end
            data[i] = SubString(s)
        end

        label!(gen.label, k, k)
        gen.layout.bus[k] = getLabelIdx(system.bus.label, data[1])

        gen.output.active[k] = parse(Float64, data[2]) * basePowerInv
        gen.output.reactive[k] = parse(Float64, data[3]) * basePowerInv

        gen.capability.maxReactive[k] = parse(Float64, data[4]) * basePowerInv
        gen.capability.minReactive[k] = parse(Float64, data[5]) * basePowerInv

        gen.voltage.magnitude[k] = parse(Float64, data[6])

        gen.layout.status[k] = parse(Int8, data[8])

        gen.capability.maxActive[k] = parse(Float64, data[9]) * basePowerInv
        gen.capability.minActive[k] = parse(Float64, data[10]) * basePowerInv

        gen.capability.lowActive[k] = parse(Float64, data[11]) * basePowerInv
        gen.capability.upActive[k] = parse(Float64, data[12]) * basePowerInv
        gen.capability.minLowReactive[k] = parse(Float64, data[13]) * basePowerInv
        gen.capability.maxLowReactive[k] = parse(Float64, data[14]) * basePowerInv
        gen.capability.minUpReactive[k] = parse(Float64, data[15]) * basePowerInv
        gen.capability.maxUpReactive[k] = parse(Float64, data[16]) * basePowerInv

        gen.ramping.loadFollowing[k] = parse(Float64, data[17]) * basePowerInv
        gen.ramping.reserve10min[k] = parse(Float64, data[18]) * basePowerInv
        gen.ramping.reserve30min[k] = parse(Float64, data[19]) * basePowerInv
        gen.ramping.reactiveRamp[k] = parse(Float64, data[20]) * basePowerInv

        gen.layout.area[k] = parse(Float64, data[21])

        if gen.layout.status[k] == 1
            i = gen.layout.bus[k]
            addGenInBus!(system, i, k)

            system.bus.supply.active[i] += gen.output.active[k]
            system.bus.supply.reactive[i] += gen.output.reactive[k]
            gen.layout.inservice += 1
        end
    end
    gen.layout.label = gen.number

    gen.cost.active.model = fill(Int8(0), gen.number)
    gen.cost.reactive.model = fill(Int8(0), gen.number)

    if !isempty(costLine)
        data = Array{SubString{String}}(undef, length(split(costLine[1])))

        costLines = eachsplit.(costLine[1:gen.number])
        costParser(system, gen.cost.active, costLines, data)

        if size(costLine, 1) == 2 * gen.number
            costLines = eachsplit.(costLine[gen.number + 1:end])
            costParser(system, gen.cost.reactive, costLines, data)
        end
    end

    system.base.power.value *= 1e6
end

##### Parser Generator Cost Model #####
@inline function costParser(
    system::PowerSystem,
    cost::Cost,
    costLines::Vector{Base.SplitIterator{String, typeof(isspace)}},
    data::Vector{SubString{String}}
)
    basePowerInv = 1 / system.base.power.value

    @inbounds for (i, line) in enumerate(costLines)
        for (idx, s) in enumerate(line)
            data[idx] = SubString(s)
        end

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
                cost.polynomial[i][k] =
                    parse(Float64, data[4 + k]) * system.base.power.value^(pointNumber - k)
            end
        end
    end
end

##### Read Data From HDF5 File #####
@inline function readHDF5(group::Group, key::String, number::Int64)
    if length(group[key]) != 1
        return read(group[key])::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}, Vector{Bool}}
    else
        return fill(read(group[key])::Union{Float64, Int64, Int8, Bool}, number)
    end
end

##### Read Polynomial Cost Function #####
function loadPolynomial!(cost::Cost, group::Group)
    if !isempty(group["polynomial"])
        datah5 = readmmap(group["polynomial"])
        @inbounds for polynomial in eachcol(datah5)
            index = trunc(Int64, polynomial[1])
            indexCoeff = 2 + trunc(Int64, polynomial[2])

            cost.polynomial[index] = polynomial[3:indexCoeff]
        end
    end
end

##### Read Piecewise Cost Function #####
function loadPiecewise!(cost::Cost, group::Group)
    if !isempty(group["piecewise"])
        datah5 = readmmap(group["piecewise"])

        Nrow = size(datah5, 1)
        idx = 1
        idxBus = 0
        @inbounds for i = 2:Nrow
            if datah5[i, 1] != datah5[i - 1, 1]
                idxBus = trunc(Int64, datah5[i - 1, 1])
                cost.piecewise[idxBus] = datah5[idx:(i - 1), 2:3]

                idx = i
            end
        end
        idxBus = trunc(Int64, datah5[idx, 1])
        cost.piecewise[idxBus] = datah5[idx:end, 2:3]
    end
end

##### Matpower Input Data Parse Lines #####
@inline function parseLine(line::String, flag::Bool, str::Vector{String})
    if occursin("[", line)
        line = split(line, "[")[end]
    end

    if occursin("]", line)
        line = split(line, "]")[1]
        flag = false
    end

    @inbounds for line in eachsplit(line, ";")
        addLine!(line, str)
    end

    return flag, str
end

function addLine!(subline::SubString{String}, str::Vector{String})
    subline = strip(subline)
    if !isempty(subline)
        push!(str, subline)
    end
end

##### Add Label for Matpower Input Data #####
function busLabel!(lbl::OrderedDict{String, Int64}, label::SubString{String}, ::Int64, idx::Int64)
    lbl[label] = idx
end

function busLabel!(lbl::OrderedDict{Int64, Int64}, ::SubString{String}, label::Int64, idx::Int64)
    lbl[label] = idx
end

function label!(lbl::OrderedDict{String, Int64}, label::Int64, idx::Int64)
    lbl[string(label)] = idx
end

function label!(lbl::OrderedDict{Int64, Int64}, label::Int64, idx::Int64)
    lbl[label] = idx
end

##### Get Label Index for Matpower Input Data #####
function getLabelIdx(lbl::OrderedDict{String, Int64}, label::SubString{String})
    lbl[label]
end

function getLabelIdx(lbl::OrderedDict{Int64, Int64}, label::SubString{String})
    lbl[parse(Int64, label)]
end