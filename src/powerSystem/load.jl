"""
    powerSystem(file::String)

The function builds the composite type `PowerSystem` and populates `bus`, `branch`,  `generator` and
`base` fields. Once the type `PowerSystem` has been created, it is possible  to add new buses,
branches, or generators, or modify the parameters of existing ones.

# Argument
It requires a string path to:
- the HDF5 file with the `.h5` extension,
- the Matpower file with the `.m` extension,
- the PSSE v33 file with the `.raw` extension.

# Returns
The `PowerSystem` composite type with the following fields:
- `bus`: Data related to buses.
- `branch`: Data related to branches.
- `generator`: Data related to generators.
- `base`: Base power and base voltages.
- `model`: Data associated with AC and DC analyses.

# Units
JuliaGrid stores all data in per-units and radians format which are fixed, the exceptions are base
values in volt-amperes and volts. The prefixes for these base values can be changed using the
[`@base`](@ref @base) macro.

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
            setTypeLabel(hdf5, template)

            system = powerSystem()
            hdf5Bus(system, hdf5)
            hdf5Branch(system, hdf5)
            hdf5Generator(system, hdf5)
            hdf5Base(system, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        system = powerSystem()

        lines = matpowerRead(system, fullpath)
        master = matpowerBus(system, lines)
        matpowerBranch(system, lines, master)
        matpowerGenerator(system, lines, master)
    end

    if extension == ".raw"
        system = powerSystem()

        lines = psseRead(system, fullpath)
        master = psseBus(system, lines)
        psseBranch(system, lines, master)
        psseGenerator(system, lines, master)
    end

    return system
end

"""
    powerSystem()

Alternatively, the `PowerSystem` type can be initialized by calling the function without any
arguments. This allows the model to be built from scratch and modified as needed. This generates an
empty `PowerSystem` type, with only the base power initialized to 1.0e8 volt-amperes.

# Example
```jldoctest
system = powerSystem()
```
"""
function powerSystem()
    PowerSystem(
        Bus(
            OrderedDict{template.bus.key, Int64}(),
            BusDemand(Float64[], Float64[]),
            BusSupply(Float64[], Float64[], Dict{Int64, Vector{Int64}}()),
            BusShunt(Float64[], Float64[]),
            BusVoltage(Float64[], Float64[], Float64[], Float64[]),
            BusLayout(Int8[], Int64[], Int64[], 0, 0, 0),
            0
        ),
        Branch(
            OrderedDict{template.branch.key, Int64}(),
            BranchParameter(
                Float64[], Float64[], Float64[], Float64[], Float64[], Float64[]
            ),
            BranchFlow(Float64[], Float64[], Float64[], Float64[], Int8[]),
            BranchVoltage(Float64[], Float64[]),
            BranchLayout(Int64[], Int64[], Int8[], 0, 0),
            0
        ),
        Generator(
            OrderedDict{template.generator.key, Int64}(),
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
            AcModel(
                spzeros(0, 0), spzeros(0, 0), ComplexF64[], ComplexF64[],
                ComplexF64[], ComplexF64[], ComplexF64[], 0, 0
            ),
            DcModel(spzeros(0, 0), Float64[], Float64[], 0, 0)
        )
    )
end

##### Load Bus Data from HDF5 File #####
function hdf5Bus(system::PowerSystem, hdf5::File)
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
function hdf5Branch(system::PowerSystem, hdf5::File)
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
function hdf5Generator(system::PowerSystem, hdf5::File)
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
function hdf5Base(system::PowerSystem, hdf5::File)
    if !haskey(hdf5, "base")
        throw(ErrorException("The base data is missing."))
    end

    base = hdf5["base"]
    system.base.power.value = read(base["power"])
    system.base.voltage.value = readHDF5(base, "voltage", system.bus.number)
end

##### Load Power System Data from MATLAB File #####
function matpowerRead(system::PowerSystem, fullpath::String)
    lines = [String[], String[], String[], String[], String[]]
    busFlag = false
    branchFlag = false
    genFlag = false
    costFlag = false
    nameFlag = false
    name = typeofLabel(template.bus.key)

    system.base.power.value = 0.0
    @inbounds for line in eachline(fullpath)
        if !branchFlag && occursin("mpc.branch", line) && occursin("[", line)
            branchFlag = true
        elseif !busFlag && occursin("mpc.bus", line) && occursin("[", line)
            busFlag = true
        elseif !genFlag && occursin("mpc.gen", line) && occursin("[", line) && !occursin("mpc.gencost", line)
            genFlag = true
        elseif !costFlag && occursin("mpc.gencost", line) && occursin("[", line)
            costFlag = true
        elseif name && !nameFlag && occursin("mpc.bus_name", line) && occursin("{", line)
            nameFlag = true
        elseif occursin("mpc.baseMVA", line)
            line = split(line, "=")[end]
            line = split(line, ";")[1]
            system.base.power.value = parse(Float64, line)
        end

        if busFlag
            busFlag = parseLine(line, busFlag, lines[1], "[", "]")
        elseif branchFlag
            branchFlag = parseLine(line, branchFlag, lines[2], "[", "]")
        elseif genFlag
            genFlag = parseLine(line, genFlag, lines[3], "[", "]")
        elseif costFlag
            costFlag = parseLine(line, costFlag, lines[4], "[", "]")
        elseif nameFlag
            nameFlag = parseLine(line, nameFlag, lines[5], "{", "}")
        end
    end

    if system.base.power == 0
        system.base.power.value = 100
        @info("The variable basePower not found. The algorithm proceeds with value of 1e8 VA.")
    end

    return lines
end

##### Load Bus Data from MATLAB File #####
function matpowerBus(system::PowerSystem, lines::Vector{Vector{String}})
    if isempty(lines[1])
        throw(ErrorException("The bus data is missing."))
    end

    bus = system.bus
    def = template.bus
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    bus.number = length(lines[1])
    bus.label = OrderedDict{template.bus.key, Int64}()
    sizehint!(bus.label, bus.number)

    labeltype = typeofLabel(lines[5], template.bus.key, template.bus.label, bus.number)
    master = OrderedDict{Int64, Int64}()
    sizehint!(master, bus.number)

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
    @inbounds for (k, line) in enumerate(eachsplit.(lines[1]))
        splitLine!(line, data, 13)

        labelInt = parse(Int64, data[1])
        bus.layout.label = max(bus.layout.label, labelInt)

        if labeltype == 1
            busLabel!(bus.label, data[1], labelInt, k)
        else
            if labeltype == 2
                bus.label[typeLabel(bus.label, template.bus.label, labelInt)] = k
            else
                bus.label[replace(lines[5][k], "'" => "")] = k
            end
            master[labelInt] = k
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

        if isassigned(data, 12) && isassigned(data, 13)
            bus.voltage.maxMagnitude[k] = parse(Float64, data[12])
            bus.voltage.minMagnitude[k] = parse(Float64, data[13])
        else
            baseInv = sqrt(3) / system.base.voltage.value[k]
            bus.voltage.minMagnitude[k] = topu(missing, def.minMagnitude, 1.0, baseInv)
            bus.voltage.maxMagnitude[k] = topu(missing, def.maxMagnitude, 1.0, baseInv)
        end

        if bus.layout.type[k] == 3
            bus.layout.slack = k
        end
    end

    if bus.layout.slack == 0
        bus.layout.slack = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end

    return master
end

##### Load Branch Data from MATLAB File #####
function matpowerBranch(system::PowerSystem, lines::Vector{Vector{String}}, master::OrderedDict{Int64, Int64})
    if isempty(lines[2])
        throw(ErrorException("The branch data is missing."))
    end

    branch = system.branch
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    branch.number = length(lines[2])
    branch.label = OrderedDict{template.branch.key, Int64}()
    sizehint!(branch.label, branch.number)

    labeltype = typeofLabel(template.branch.key, template.branch.label)
    buslabel = labelbus(system.bus.label, master)

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
    branch.layout.to = similar(branch.layout.from)
    branch.layout.status = similar(branch.flow.type)

    data = Array{SubString{String}}(undef, 13)
    @inbounds for (k, line) in enumerate(eachsplit.(lines[2]))
        splitLine!(line, data, 13)

        setLabel!(branch.label, template.branch.label, labeltype, k)

        branch.layout.from[k] = getIndex(buslabel, data[1])
        branch.layout.to[k] = getIndex(buslabel, data[2])

        branch.parameter.resistance[k] = parse(Float64, data[3])
        branch.parameter.reactance[k] = parse(Float64, data[4])
        branch.parameter.susceptance[k] = parse(Float64, data[5])

        longTerm = parse(Float64, data[6]) * basePowerInv
        branch.flow.minFromBus[k] = branch.flow.minToBus[k] = -longTerm
        branch.flow.maxFromBus[k] = branch.flow.maxToBus[k] = longTerm

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
function matpowerGenerator(system::PowerSystem, lines::Vector{Vector{String}}, master::OrderedDict{Int64, Int64})
    if isempty(lines[3])
        throw(ErrorException("The generator data is missing."))
    end

    gen = system.generator
    basePowerInv = 1 / system.base.power.value

    gen.number = length(lines[3])
    gen.label = OrderedDict{template.generator.key, Int64}()
    sizehint!(gen.label, gen.number)

    labeltype = typeofLabel(template.generator.key, template.generator.label)
    buslabel = labelbus(system.bus.label, master)

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
    @inbounds for (k, line) in enumerate(eachsplit.(lines[3]))
        splitLine!(line, data, 21)

        setLabel!(gen.label, template.generator.label, labeltype, k)

        gen.layout.bus[k] = getIndex(buslabel, data[1])

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

    costLine = lines[4]
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
function costParser(
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

##### Load Power System Data from PSSE File #####
function psseRead(system::PowerSystem, fullpath::String)
    basePower = true
    findingStart = true
    lines = [String[], String[], String[], String[], String[], String[], String[]]

    idx = 0
    for line in eachline(fullpath)
        if !isempty(line)

            if basePower
                header = split(line, ",")
                system.base.power.value = parse(Float64, header[2])
                basePower = false
                continue
            end

            if findingStart
                findingStart, idx = psseStartBus(line)
            end

            flag, idx = psseBreakStart(line, idx)
            psseParse(line, lines, flag, idx)
        end
    end

    if system.base.power == 0
        system.base.power.value = 100
        @info("The variable basePower not found. The algorithm proceeds with value of 1e8 VA.")
    end

    return lines
end

function psseStartBus(line::String)
    bus = split(line, ",")
    try
        parse(Int64, bus[1])
        parse(Float64, bus[3])
        parse(Float64, bus[9])

        return false, 1
    catch
        return true, 0
    end
end

function psseBreakStart(line::String, idx::Int64)
    if occursin(r"^(Q|\s*0)\s*(/.*)?$", line)

        if occursin("BEGIN LOAD DATA", line)
            return false, 2
        end

        if occursin("BEGIN FIXED SHUNT DATA", line)
            return false, 3
        end

        if occursin("BEGIN SWITCHED SHUNT DATA", line)
            return false, 4
        end

        if occursin("BEGIN BRANCH DATA", line)
            return false, 5
        end

        if occursin("BEGIN TRANSFORMER DATA", line)
            return false, 6
        end

        if occursin("BEGIN GENERATOR DATA", line)
            return false, 7
        end

        return false, 0
    end

    return true, idx
end

function psseParse(line::String, str::Vector{Vector{String}}, flag::Bool, idx::Int64)
    if flag && idx != 0
        addLine!(line, str[idx])
    end
end

##### Load Bus Data from PSEE File #####
function psseBus(system::PowerSystem, lines::Vector{Vector{String}})
    if isempty(lines[1])
        throw(ErrorException("The bus data is missing."))
    end

    def = template.bus
    bus = system.bus
    basePowerInv = 1 / system.base.power.value
    deg2rad = pi / 180

    bus.number = length(lines[1])
    bus.label = OrderedDict{template.bus.key, Int64}()
    sizehint!(bus.label, bus.number)

    labeltype = typeofLabel(template.bus.key)
    master = OrderedDict{Int64, Int64}()
    sizehint!(master, bus.number)

    bus.supply.active = fill(0.0, bus.number)
    bus.supply.reactive = fill(0.0, bus.number)

    bus.voltage.magnitude = similar(bus.supply.active)
    bus.voltage.angle = similar(bus.supply.active)
    bus.voltage.minMagnitude = similar(bus.supply.active)
    bus.voltage.maxMagnitude = similar(bus.supply.active)

    bus.layout.type = Array{Int8}(undef, bus.number)
    bus.layout.area = fill(0, bus.number)
    bus.layout.lossZone = similar(bus.layout.area)
    bus.layout.slack = 0

    system.base.voltage.value = similar(bus.supply.active)

    bus.layout.label = 0
    data = Array{SubString{String}}(undef, 11)
    for (k, line) in enumerate(eachsplit.(lines[1], ","))
        splitLine!(line, data, 11)

        labelInt = parse(Int64, data[1])
        bus.layout.label = max(bus.layout.label, labelInt)

        if labeltype
            label = replace(strip(data[2]), "'" => "")
            if isempty(strip(label))
                bus.label[typeLabel(bus.label, template.bus.label, labelInt)] = k
            else
                bus.label[label] = k
            end
            master[labelInt] = k
        else
            busLabel!(bus.label, data[1], labelInt, k)
        end

        bus.voltage.magnitude[k] = parse(Float64, data[8])
        bus.voltage.angle[k] = parse(Float64, data[9]) * deg2rad

        system.base.voltage.value[k] = parse(Float64, data[3]) * 1e3

        if isassigned(data, 10) && isassigned(data, 11)
            bus.voltage.maxMagnitude[k] = parse(Float64, data[10])
            bus.voltage.minMagnitude[k] = parse(Float64, data[11])
        else
            baseInv = sqrt(3) / system.base.voltage.value[k]
            bus.voltage.minMagnitude[k] = topu(missing, def.minMagnitude, 1.0, baseInv)
            bus.voltage.maxMagnitude[k] = topu(missing, def.maxMagnitude, 1.0, baseInv)
        end

        bus.layout.type[k] = parse(Int8, data[4])
        bus.layout.area[k] = parse(Int64, data[5])
        bus.layout.lossZone[k] = parse(Int64, data[6])

        if bus.layout.type[k] == 3
            bus.layout.slack = k
        end
    end

    bus.demand.active = fill(0.0, bus.number)
    bus.demand.reactive = fill(0.0, bus.number)

    data = Array{SubString{String}}(undef, 11)
    for line in eachsplit.(lines[2], ",")
        splitLine!(line, data, 11)

        if parse(Int64, data[3]) == 1
            idx = parse(Int64, data[1])

            constPower = parse(Float64, data[6])
            constCurrent = parse(Float64, data[8]) * bus.voltage.magnitude[idx]
            constImpedance = parse(Float64, data[10]) * bus.voltage.magnitude[idx]^2
            bus.demand.active[idx] += (constPower + constCurrent + constImpedance) * basePowerInv

            constPower = parse(Float64, data[7])
            constCurrent = parse(Float64, data[9]) * bus.voltage.magnitude[idx]
            constImpedance = parse(Float64, data[11]) * bus.voltage.magnitude[idx]^2
            bus.demand.reactive[idx] += (constPower + constCurrent - constImpedance) * basePowerInv
        end
    end

    bus.shunt.conductance = fill(0.0, bus.number)
    bus.shunt.susceptance = fill(0.0, bus.number)

    data = Array{SubString{String}}(undef, 5)
    for line in eachsplit.(lines[3], ",")
        splitLine!(line, data, 5)

        if parse(Int64, data[3]) == 1
            idx = parse(Int64, data[1])
            bus.shunt.conductance[idx] += parse(Float64, data[4]) * basePowerInv
            bus.shunt.susceptance[idx] += parse(Float64, data[5]) * basePowerInv
        end
    end

    data = Array{SubString{String}}(undef, 10)
    for line in eachsplit.(lines[4], ",")
        splitLine!(line, data, 10)

        if parse(Int64, data[4]) == 1
            idx = parse(Int64, data[1])
            bus.shunt.susceptance[idx] += parse(Float64, data[10]) * basePowerInv
        end
    end

    if bus.layout.slack == 0
        bus.layout.slack = 1
        @info("The slack bus is not found. The first bus is set to be the slack.")
    end

    return master
end

##### Load Branch Data from PSSE File #####
function psseBranch(system::PowerSystem, lines::Vector{Vector{String}}, master::OrderedDict{Int64, Int64})
    if isempty(lines[5])
        throw(ErrorException("The branch data is missing."))
    end

    def = template.branch
    bus = system.bus
    branch = system.branch
    basePowerInv = 1 / system.base.power.value
    baseV = system.base.voltage
    deg2rad = pi / 180

    branch.number = length(lines[5])
    branch.label = OrderedDict{template.branch.key, Int64}()
    sizehint!(branch.label, branch.number)

    labeltype = typeofLabel(template.branch.key, template.branch.label)
    buslabel = labelbus(system.bus.label, master)

    branch.parameter.conductance = fill(0.0, branch.number)
    branch.parameter.resistance = similar(branch.parameter.conductance)
    branch.parameter.reactance = similar(branch.parameter.conductance)
    branch.parameter.susceptance = similar(branch.parameter.conductance) * basePowerInv
    branch.parameter.turnsRatio = fill(1.0, branch.number)
    branch.parameter.shiftAngle = fill(0.0, branch.number)

    branch.voltage.minDiffAngle = similar(branch.parameter.conductance)
    branch.voltage.maxDiffAngle = similar(branch.parameter.resistance)

    branch.flow.minFromBus = similar(branch.parameter.conductance)
    branch.flow.maxFromBus = similar(branch.parameter.conductance)
    branch.flow.minToBus = similar(branch.parameter.conductance)
    branch.flow.maxToBus = similar(branch.parameter.conductance)
    branch.flow.type = fill(Int8(3), branch.number)

    branch.layout.from = fill(0, branch.number)
    branch.layout.to = similar(branch.layout.from)
    branch.layout.status = similar(branch.flow.type)

    data = Array{SubString{String}}(undef, 14)
    for (k, line) in enumerate(eachsplit.(lines[5], ","))
        splitLine!(line, data, 14)

        setLabel!(branch.label, template.branch.label, labeltype, k)

        branch.layout.from[k] = getIndex(buslabel, parse(Int64, data[1]))
        branch.layout.to[k] = getIndex(buslabel, abs(parse(Int64, data[2])))

        branch.parameter.resistance[k] = parse(Float64, data[4])
        branch.parameter.reactance[k] = parse(Float64, data[5])
        branch.parameter.susceptance[k] = parse(Float64, data[6])

        longTerm = parse(Float64, data[7]) * basePowerInv
        branch.flow.minFromBus[k] = branch.flow.minToBus[k] = -longTerm
        branch.flow.maxFromBus[k] = branch.flow.maxToBus[k] = longTerm

        branch.layout.status[k] = parse(Int8, data[14])

        branch.voltage.minDiffAngle[k] = topu(missing, def.minDiffAngle, pfx.voltageAngle, 1.0)
        branch.voltage.maxDiffAngle[k] = topu(missing, def.maxDiffAngle, pfx.voltageAngle, 1.0)

        if branch.layout.status[k] == 1
            branch.layout.inservice += 1

            bus.shunt.conductance[branch.layout.from[k]] += parse(Float64, data[10])
            bus.shunt.susceptance[branch.layout.from[k]] += parse(Float64, data[11])

            bus.shunt.conductance[branch.layout.to[k]] += parse(Float64, data[12])
            bus.shunt.susceptance[branch.layout.to[k]] += parse(Float64, data[13])
        end
    end
    branch.layout.label = branch.number

    block = 0
    cntLine = 0
    cnt = 1
    data = Array{SubString{String}}(undef, 83)
    for line in eachsplit.(lines[6], ",")

        if cntLine == 0
            cnt = 1

            for s in line
                data[cnt] = SubString(s)
                cnt += 1
            end

            if parse(Int64, data[3]) == 0
                block = 4
            else
                block = 5
            end

            cntLine += 1

        elseif cntLine < block
            for s in line
                data[cnt] = SubString(s)
                cnt += 1
            end
            cntLine += 1
        end

        if cntLine == block
            if block == 4
                i = getIndex(buslabel, parse(Int64, data[1]))
                j = getIndex(buslabel, parse(Int64, data[2]))

                τ1 = parse(Float64, data[25])
                τ2 = parse(Float64, data[42])

                addBranch!(
                    system; from = getLabel(system.bus.label, i), to = getLabel(system.bus.label, j),
                    reactance = 1.0, status = parse(Int64, data[12]),
                    turnsRatio = τ1 / τ2
                )

                longTerm = parse(Float64, data[28]) * basePowerInv
                branch.flow.minFromBus[end] = branch.flow.minToBus[end] = -longTerm
                branch.flow.maxFromBus[end] = branch.flow.maxToBus[end] = longTerm

                branch.parameter.resistance[end] = parse(Float64, data[22])
                branch.parameter.reactance[end] = parse(Float64, data[23])
                branch.parameter.shiftAngle[end] = parse(Float64, data[27]) * deg2rad

                Vb1 = parse(Float64, data[26])
                Vb2 = parse(Float64, data[43])

                cw = parse(Float64, data[5])
                cz = parse(Float64, data[6])

                R = branch.parameter.resistance
                X = branch.parameter.reactance
                τ = branch.parameter.turnsRatio

                if cz ∈ (2, 3)
                    Sbinv = 1 / parse(Float64, data[24])

                    if cz == 3
                        R[end] *= Sbinv * 1e-6
                        X[end] = sqrt(X[end]^2 - R[end]^2)
                    end

                    if isapprox(Vb1, 0.0)
                        R[end] *= system.base.power.value * Sbinv
                        X[end] *= system.base.power.value * Sbinv
                    else
                        Zn = (Vb1^2 * Sbinv) / ((baseV.value[i] * baseV.prefix)^2 * basePowerInv * 1e-6)

                        R[end] *= Zn
                        X[end] *= Zn
                    end
                end

                if cw == 1
                    R[end] *= τ2^2
                    X[end] *= τ2^2
                elseif cw == 2
                    R[end] *= (1e3 * τ2 / baseV.value[j])^2
                    X[end] *= (1e3 * τ2 / baseV.value[j])^2
                    τ[end] *= baseV.value[j] / baseV.value[i]
                elseif cw == 3
                    if isapprox(Vb2, 0.0)
                        R[end] *= τ2^2
                        X[end] *= τ2^2
                    else
                        R[end] *= (1e3 * τ2 * Vb2 / baseV.value[j])^2
                        X[end] *= (1e3 * τ2 * Vb2 / baseV.value[j])^2
                    end

                    if Vb1 != 0.0 && Vb2 != 0.0
                        τ[end] *= (baseV.value[j] / baseV.value[i]) * (Vb1 / Vb2)
                    end
                end
            else
                i = getIndex(buslabel, parse(Int64, data[1]))
                j = getIndex(buslabel, parse(Int64, data[2]))
                q = getIndex(buslabel, parse(Int64, data[3]))

                addBus!(
                    system; base = 1e3 * system.base.voltage.prefix / pfx.baseVoltage,
                    area = bus.layout.area[i], lossZone = bus.layout.lossZone[i]
                )

                bus.voltage.magnitude[end] = parse(Float64, data[31])
                bus.voltage.angle[end] = parse(Float64, data[32]) * deg2rad

                status = parse(Int8, data[12])

                addBranch!(
                    system; from = getLabel(system.bus.label, i),
                    to = getLabel(system.bus.label, bus.number),
                    reactance = 1.0, turnsRatio = parse(Float64, data[33]),
                    status = (status == 0 || status == 4) ? 0 : 1
                )

                addBranch!(
                    system; from = getLabel(system.bus.label, j),
                    to = getLabel(system.bus.label, bus.number),
                    reactance = 1.0, turnsRatio = parse(Float64, data[50]),
                    status = (status == 0 || status == 2) ? 0 : 1
                )

                addBranch!(
                    system; from = getLabel(system.bus.label, q),
                    to = getLabel(system.bus.label, bus.number),
                    reactance = 1.0, turnsRatio = parse(Float64, data[67]),
                    status = (status == 0 || status == 3) ? 0 : 1
                )

                branch.parameter.shiftAngle[end - 2] = parse(Float64, data[35]) * deg2rad
                branch.parameter.shiftAngle[end - 1] = parse(Float64, data[52]) * deg2rad
                branch.parameter.shiftAngle[end] = parse(Float64, data[69]) * deg2rad

                longTerm = parse(Float64, data[36]) * basePowerInv
                branch.flow.minFromBus[end - 2] = branch.flow.minToBus[end - 2] = -longTerm
                branch.flow.maxFromBus[end - 2] = branch.flow.maxToBus[end - 2] = longTerm

                longTerm = parse(Float64, data[53]) * basePowerInv
                branch.flow.minFromBus[end - 1] = branch.flow.minToBus[end - 1] = -longTerm
                branch.flow.maxFromBus[end - 1] = branch.flow.maxToBus[end - 1] = longTerm

                longTerm = parse(Float64, data[70]) * basePowerInv
                branch.flow.minFromBus[end] = branch.flow.minToBus[end] = -longTerm
                branch.flow.maxFromBus[end] = branch.flow.maxToBus[end] = longTerm

                cw = parse(Float64, data[5])
                cz = parse(Float64, data[6])

                R12 = parse(Float64, data[22])
                R23 = parse(Float64, data[25])
                R31 = parse(Float64, data[28])

                X12 = parse(Float64, data[23])
                X23 = parse(Float64, data[26])
                X31 = parse(Float64, data[29])

                Vb1 = parse(Float64, data[34])
                Vb2 = parse(Float64, data[51])
                Vb3 = parse(Float64, data[68])

                if cz ∈ (2, 3)
                    Sbinv1 = 1 / parse(Float64, data[24])
                    Sbinv2 = 1 / parse(Float64, data[27])
                    Sbinv3 = 1 / parse(Float64, data[30])

                    if cz == 3
                        R12 *= Sbinv1 * 1e-6
                        X12 = sqrt(X12^2 - R12^2)

                        R23 *= Sbinv2 * 1e-6
                        X23 = sqrt(X23^2 - R23^2)

                        R31 *= Sbinv3 * 1e-6
                        X31 = sqrt(X31^2 - R31^2)
                    end

                    if isapprox(Vb1, 0.0)
                        R12 *= system.base.power.value * Sbinv1
                        X12 *= system.base.power.value * Sbinv1
                    else
                        Zn = (Vb1^2 * Sbinv1) / ((baseV.value[i] * baseV.prefix)^2 * basePowerInv * 1e-6)

                        R12 *= Zn
                        X12 *= Zn
                    end

                    if isapprox(Vb2, 0.0)
                        R23 *= system.base.power.value * Sbinv2
                        X23 *= system.base.power.value * Sbinv2
                    else
                        Zn = (Vb2^2 * Sbinv2) / ((baseV.value[j] * baseV.prefix)^2 * basePowerInv * 1e-6)

                        R23 *= Zn
                        X23 *= Zn
                    end

                    if isapprox(Vb3, 0.0)
                        R31 *= system.base.power.value * Sbinv3
                        X31 *= system.base.power.value * Sbinv3
                    else
                        Zn = (Vb3^2 * Sbinv3) / ((baseV.value[q] * baseV.prefix)^2 * basePowerInv * 1e-6)

                        R31 *= Zn
                        X31 *= Zn
                    end
                end

                if cw == 2
                    branch.parameter.turnsRatio[end - 2] /= baseV.value[i] * 1e-3
                    branch.parameter.turnsRatio[end - 1] /= baseV.value[j] * 1e-3
                    branch.parameter.turnsRatio[end] /= baseV.value[q] * 1e-3
                end

                if cw == 3
                    if  Vb1 != 0.0
                        branch.parameter.turnsRatio[end - 2] *= Vb1 / (baseV.value[i] * 1e-3)
                    end

                    if Vb2 != 0.0
                        branch.parameter.turnsRatio[end - 1] *= Vb2 / (baseV.value[j] * 1e-3)
                    end

                    if Vb3 != 0.0
                        branch.parameter.turnsRatio[end] *= Vb3 / (baseV.value[q] * 1e-3)
                    end
                end

                branch.parameter.resistance[end - 2] = (R12 - R23 + R31) / 2
                branch.parameter.reactance[end - 2] = (X12 - X23 + X31) / 2

                branch.parameter.resistance[end - 1] = (R12 + R23 - R31) / 2
                branch.parameter.reactance[end - 1] = (X12 + X23 - X31) / 2

                branch.parameter.resistance[end] = (-R12 + R23 + R31) / 2
                branch.parameter.reactance[end] = (-X12 + X23 + X31) / 2
            end

            cntLine = 0
        end
    end
end

function psseGenerator(system::PowerSystem, lines::Vector{Vector{String}}, master::OrderedDict{Int64, Int64})
    if isempty(lines[7])
        throw(ErrorException("The generator data is missing."))
    end

    gen = system.generator
    basePowerInv = 1 / system.base.power.value

    gen.number = length(lines[7])
    gen.label = OrderedDict{template.generator.key, Int64}()
    sizehint!(gen.label, gen.number)

    labeltype = typeofLabel(template.generator.key, template.generator.label)
    buslabel = labelbus(system.bus.label, master)

    gen.output.active = fill(0.0, gen.number)
    gen.output.reactive = similar(gen.output.active)

    gen.capability.minActive = similar(gen.output.active)
    gen.capability.maxActive = similar(gen.output.active)
    gen.capability.minReactive = similar(gen.output.active)
    gen.capability.maxReactive = similar(gen.output.active)
    gen.capability.lowActive = fill(0.0, gen.number)
    gen.capability.minLowReactive = fill(0.0, gen.number)
    gen.capability.maxLowReactive = fill(0.0, gen.number)
    gen.capability.upActive = fill(0.0, gen.number)
    gen.capability.minUpReactive = fill(0.0, gen.number)
    gen.capability.maxUpReactive = fill(0.0, gen.number)

    gen.ramping.loadFollowing = fill(0.0, gen.number)
    gen.ramping.reserve10min = fill(0.0, gen.number)
    gen.ramping.reserve30min = fill(0.0, gen.number)
    gen.ramping.reactiveRamp = fill(0.0, gen.number)

    gen.voltage.magnitude = similar(gen.output.active)

    gen.layout.bus = fill(0, gen.number)
    gen.layout.area = fill(0.0, gen.number)
    gen.layout.status = Array{Int8}(undef, gen.number)

    gen.cost.active.model = fill(Int8(0), gen.number)
    gen.cost.reactive.model = fill(Int8(0), gen.number)

    data = Array{SubString{String}}(undef, 18)
    for (k, line) in enumerate(eachsplit.(lines[7], ","))
        splitLine!(line, data, 18)

        setLabel!(gen.label, template.generator.label, labeltype, k)

        gen.layout.bus[k] = getIndex(buslabel, parse(Int64, data[1]))

        gen.output.active[k] = parse(Float64, data[3]) * basePowerInv
        gen.output.reactive[k] = parse(Float64, data[4]) * basePowerInv

        gen.capability.maxReactive[k] = parse(Float64, data[5]) * basePowerInv
        gen.capability.minReactive[k] = parse(Float64, data[6]) * basePowerInv

        gen.capability.maxActive[k] = parse(Float64, data[17]) * basePowerInv
        gen.capability.minActive[k] = parse(Float64, data[18]) * basePowerInv

        gen.voltage.magnitude[k] = parse(Float64, data[7])

        gen.layout.status[k] = parse(Int8, data[15])

        if gen.layout.status[k] == 1
            i = gen.layout.bus[k]
            addGenInBus!(system, i, k)

            system.bus.supply.active[i] += gen.output.active[k]
            system.bus.supply.reactive[i] += gen.output.reactive[k]
            gen.layout.inservice += 1
        end
    end

    gen.layout.label = gen.number
    system.base.power.value *= 1e6
end

##### Read Data From HDF5 File #####
function readHDF5(group::Group, key::String, number::Int64)
    if length(group[key]) == 1
        return fill(read(group[key])::Union{Float64, Int64, Int8, Bool}, number)
    else
        return read(group[key])::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}, Vector{Bool}}
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

##### Matpower and PSSE Parse Lines #####
function parseLine(line::String, flag::Bool, str::Vector{String}, start::String, last::String)
    if occursin(start, line)
        line = split(line, start)[end]
    end

    if occursin(last, line)
        line = split(line, last)[1]
        flag = false
    end

    @inbounds for line in eachsplit(line, ";")
        addLine!(line, str)
    end

    return flag
end

function addLine!(subline::SubString{String}, str::Vector{String})
    subline = strip(subline)
    if !isempty(subline)
        push!(str, subline)
    end
end

function addLine!(subline::String, str::Vector{String})
    subline = strip(subline)
    if !isempty(subline)
        push!(str, subline)
    end
end

##### Split Line #####
function splitLine!(
    line::Base.SplitIterator{String, T},
    data::Array{SubString{String}},
    idx::Int64
) where T <: Union{typeof(isspace), String}

    @inbounds for (i, s) in enumerate(Iterators.take(line, idx))
        data[i] = SubString(s)
    end
end

##### Add Label for Matpower and PSSE Input Data #####
function busLabel!(lbl::OrderedDict{String, Int64}, label::SubString{String}, ::Int64, idx::Int64)
    lbl[label] = idx
end

function busLabel!(lbl::OrderedDict{Int64, Int64}, ::SubString{String}, label::Int64, idx::Int64)
    lbl[label] = idx
end

function setLabel!(container::LabelDict, def::String, type::Bool, idx::Int64)
    if type
        label!(container, idx, idx)
    else
        container[typeLabel(container, def, idx)] = idx
    end
end

function label!(lbl::OrderedDict{String, Int64}, label::Int64, idx::Int64)
    lbl[string(label)] = idx
end

function label!(lbl::OrderedDict{Int64, Int64}, label::Int64, idx::Int64)
    lbl[label] = idx
end

##### Type of Labels #####
function setTypeLabel(hdf5::File, template::Template)
    template.bus.key = eltype(hdf5["bus/label"]) === Cstring ? String : Int64
    template.branch.key = eltype(hdf5["branch/label"]) === Cstring ? String : Int64
    template.generator.key = eltype(hdf5["generator/label"]) === Cstring ? String : Int64
end

function typeofLabel(name::Vector{String}, key::DataType, label::String, busNumber::Int64)
    if key == String
        if !isempty(name) || lastindex(name) == busNumber
            return 3
        elseif label != "?"
            return 2
        end
    end

    1
end

function typeofLabel(key::DataType, label::String)
    if key == String && label != "?"
        return false
    end

    return true
end

function typeofLabel(key::DataType)
    if key == String
        return true
    end

    false
end

##### Choose Label Container #####
function labelbus(systemlabel::LabelDict, masterlabel::OrderedDict{Int64, Int64})
    if isempty(masterlabel)
        return systemlabel
    end

    return masterlabel
end