######################
#  Input Processing  #
######################


#-------------------------------------------------------------------------------
struct PowerSystem
    bus::Array{Float64,2}
    generator::Array{Float64,2}
    branch::Array{Float64,2}
    baseMVA::Float64
    path::String
    extension::String
end

struct FlowSettings
    algorithm::String
    solve::String
    main::Bool
    flow::Bool
    generator::Bool
    save::String
    maxIter::Int64
    stopping::Float64
    reactive::Array{Bool,1}
end

struct GeneratorSettings
    algorithm::String
    solve::String
    main::Bool
    flow::Bool
    generator::Bool
    save::String
    path::String
    maxIter::Int64
    stopping::Float64
    reactive::Array{Bool,1}
    set::Dict{String, Array{Any,1}}
    variance::Dict{String, Array{Any,1}}
end

struct StateEstimation
    legFlow::Array{Float64,2}
    legCurrent::Array{Float64,2}
    legInjection::Array{Float64,2}
    legVoltage::Array{Float64,2}
    pmuCurrent::Array{Float64,2}
    pmuVoltage::Array{Float64,2}
end

struct EstimationSettings
    algorithm::String
end
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
function loadsystem(args)
    extension = ""
    path = ""
    data = ""
    fullpath = ""
    for i = 1:length(args)
        try
            extension = match(r"\.[A-Za-z0-9]+$", args[i]).match
            if extension == ".h5" || extension == ".xlsx"
                fullpath = args[i]
                path = dirname(args[i])
                data = basename(args[i])
                break
            end
        catch
        end
    end
    if isempty(extension)
       error("The input data format is not supported.")
    end

    if path == ""
        package_dir = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."))
        path = joinpath(package_dir, "src/data/")
        fullpath = joinpath(package_dir, "src/data/", data)
    end

    input_data = cd(readdir, path)
    for i = 1:length(args)
        if any(input_data .== args[i])
            data = args[i]
        end
    end

    if isempty(data)
        error("The input power system data is not found.")
    else
        println(string("  Input Power System: ", data))
    end

    if extension == ".h5"
        read_data = h5read(fullpath, "/")
    end

    if extension == ".xlsx"
        read_data = Dict()
        sheet = ["bus", "branch", "generator", "basePower"]
        for i in sheet
            try
                xf = XLSX.readxlsx(fullpath)
                sh = xf[i]
                table = sh[:]
                push!(read_data, i => Float64.(table[3:end, :]))
            catch
            end
        end
    end

    bus = Array{Float64}(undef, 0, 0)
    generator = Array{Float64}(undef, 0, 0)
    branch = Array{Float64}(undef, 0, 0)
    if !any(keys(read_data) .== "basePower")
        baseMVA = 100.0
        @info("The variable 'baseMVA' not found. The algorithm proceeds with default value: 100 MVA")
    end

    if !any(keys(read_data) .== "bus")
        error("Invalid power flow data structure, variable 'bus' not found.")
    end
    if !any(keys(read_data) .== "branch")
        error("Invalid power flow data structure, variable 'branch' not found.")
    end

    for i in keys(read_data)
        if i == "bus"
           bus = read_data[i]
        end
        if i == "generator"
            generator = read_data[i]
        end
        if i == "branch"
            branch = read_data[i]
        end
        if i == "basePower"
            baseMVA = read_data[i][1]
        end
    end

    return PowerSystem(bus, generator, branch, baseMVA, fullpath, extension)
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function pfsettings(args, max, stop, react, solve, save)
    algorithm = "false"
    algorithm_type = ["nr", "gs", "fnrxb", "fnrbx", "dc"]
    main = false
    flow = false
    generator = false
    reactive = [false; true; false]

    for i = 1:length(args)
        if any(algorithm_type .== args[i])
            algorithm = args[i]
        end
        if args[i] == "main"
            main = true
        end
        if args[i] == "flow"
            flow = true
        end
        if args[i] == "generator"
            generator = true
        end
    end

    if react == 1
        reactive = [true; true; false]
    end

    if algorithm == "false"
        algorithm = "nr"
        @info("Invalid power flow algorithm key. The algorithm proceeds with the AC power flow.")
    end

    return FlowSettings(algorithm, solve, main, flow, generator, save, max, stop, reactive)
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function gesettings(args, max, stop, react, solve, save, pmuset, pmuvariance, legacyset, legacyvariance)
    savepf = ""
    algorithm = "nr"
    main = false
    flow = false
    generator = false

    reactive = [false; true; false]
    if react == 1
        reactive = [true; true; false]
    end

    set = Dict("pmu" => ["name", 0, 0, 0, 0], "legacy" => ["name", 0, 0, 0, 0, 0, 0])
    pmuSetOptions = ["all", "Iij", "Dij", "Vi", "Ti", "redundancy", "device", "optimal"]
    for i in pmuSetOptions
        if any(i .== pmuset)
            set["pmu"][1] = i
        end
    end
    if !isa(set["pmu"][1], String)
        set["pmu"][1] = pmuSetOptions[1]
    end
    if any(set["pmu"][1] .== ["Iij", "Dij", "Vi", "Ti"])
          set["pmu"][1] = "onebyone"
    end
    for (k, i) in enumerate(pmuset)
        try
            if i == "optimal" && set["pmu"][1] == "optimal"
                set["pmu"][2] = pmuset[k + 1]
            end
            if i == "device" && set["pmu"][1] == "device"
                set["pmu"][2] = pmuset[k + 1]
            end
            if i == "redundancy" && set["pmu"][1] == "redundancy"
                set["pmu"][2] = pmuset[k + 1]
            end
            if i == "Iij" &&set["pmu"][1] == "onebyone"
                set["pmu"][2] = pmuset[k + 1]
            end
            if i == "Dij" && set["pmu"][1] == "onebyone"
                set["pmu"][3] = pmuset[k + 1]
            end
            if i == "Vi" && set["pmu"][1] == "onebyone"
                set["pmu"][4] = pmuset[k + 1]
            end
            if i == "Ti" && set["pmu"][1] == "onebyone"
                set["pmu"][5] = pmuset[k + 1]
            end
        catch
        end
    end

    legacySetOptions = ["all", "Pij", "Qij", "Iij", "Pi", "Qi", "Vi", "redundancy"]
    for i in legacySetOptions
        if any(i .== legacyset)
            set["legacy"][1] = i
        end
    end
    if !isa(set["legacy"][1], String)
        set["legacy"][1] = legacySetOptions[1]
    end
    if any(set["legacy"][1] .== ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"])
        set["legacy"][1] = "onebyone"
    end
    for (k, i) in enumerate(legacyset)
        try
            if i == "redundancy" && set["legacy"][1] == "redundancy"
                set["legacy"][2] = legacyset[k + 1]
            end
            if i == "Pij" && set["legacy"][1] == "onebyone"
                set["legacy"][2] = legacyset[k + 1]
            end
            if i == "Qij" && set["legacy"][1] == "onebyone"
                set["legacy"][3] = legacyset[k + 1]
            end
            if i == "Iij" && set["legacy"][1] == "onebyone"
                set["legacy"][4] = legacyset[k + 1]
            end
            if i == "Pi" && set["legacy"][1] == "onebyone"
                set["legacy"][5] = legacyset[k + 1]
            end
            if i == "Qi" && set["legacy"][1] == "onebyone"
                set["legacy"][6] = legacyset[k + 1]
            end
            if i == "Vi" && set["legacy"][1] == "onebyone"
                set["legacy"][7] = legacyset[k + 1]
            end
        catch
        end
    end

    variance = Dict("pmu" => ["name", 0, 0, 0, 0], "legacy" => ["name", 0, 0, 0, 0, 0, 0])
    pmuVarianceOptions = ["all", "Iij", "Dij", "Vi", "Ti", "random"]
    for i in pmuVarianceOptions
        if any(i .== pmuvariance)
            variance["pmu"][1] = i
        end
    end
    if !isa(variance["pmu"][1], String)
        variance["pmu"][1] = pmuVarianceOptions[1]
    end
    if any(variance["pmu"][1] .== ["Iij", "Dij", "Vi", "Ti"])
          variance["pmu"][1] = "onebyone"
    end
    for (k, i) in enumerate(pmuvariance)
        try
            if i == "all" && variance["pmu"][1] == "all"
                variance["pmu"][2] = pmuvariance[k + 1]
            end
            if i == "random" && variance["pmu"][1] == "random"
                variance["pmu"][2] = pmuvariance[k + 1]
                variance["pmu"][3] = pmuvariance[k + 2]
            end
            if i == "Iij" && variance["pmu"][1] == "onebyone"
                variance["pmu"][2] = pmuvariance[k + 1]
            end
            if i == "Dij" && variance["pmu"][1] == "onebyone"
                variance["pmu"][3] = pmuvariance[k + 1]
            end
            if i == "Vi" && variance["pmu"][1] == "onebyone"
                variance["pmu"][4] = pmuvariance[k + 1]
            end
            if i == "Ti" && variance["pmu"][1] == "onebyone"
                variance["pmu"][5] = pmuvariance[k + 1]
            end
        catch
        end
    end

    legacyVarianceOptions = ["all", "Pij", "Qij", "Iij", "Pi", "Qi", "Vi", "random"]
    for i in legacyVarianceOptions
        if any(i .== legacyvariance)
            variance["legacy"][1] = i
        end
    end
    if !isa(variance["legacy"][1], String)
        variance["legacy"][1] = legacyVarianceOptions[1]
    end
    if any(variance["legacy"][1] .== ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"])
          variance["legacy"][1] = "onebyone"
    end
    for (k, i) in enumerate(legacyvariance)
        try
            if i == "all" && variance["legacy"][1] == "all"
                variance["legacy"][2] = legacyvariance[k + 1]
            end
            if i == "random" && variance["legacy"][1] == "random"
                variance["legacy"][2] = legacyvariance[k + 1]
                variance["legacy"][3] = legacyvariance[k + 2]
            end
            if i == "Pij" && variance["legacy"][1] == "onebyone"
                variance["legacy"][2] = legacyvariance[k + 1]
            end
            if i == "Qij" && variance["legacy"][1] == "onebyone"
                variance["legacy"][3] = legacyvariance[k + 1]
            end
            if i == "Iij" && variance["legacy"][1] == "onebyone"
                variance["legacy"][4] = legacyvariance[k + 1]
            end
            if i == "Pi" && variance["legacy"][1] == "onebyone"
                variance["legacy"][5] = legacyvariance[k + 1]
            end
            if i == "Qi" && variance["legacy"][1] == "onebyone"
                variance["legacy"][6] = legacyvariance[k + 1]
            end
            if i == "Vi" && variance["legacy"][1] == "onebyone"
                variance["legacy"][7] = legacyvariance[k + 1]
            end
        catch
        end
    end

    return GeneratorSettings(algorithm, solve, main, flow, generator, savepf, save, max, stop, reactive, set, variance)
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function loadmeasurement(data, path)
    system = string(path, data)
    read_data = h5read(system, "/")

    legFlow = Array{Float64}(undef, 0, 0)
    legCurrent = Array{Float64}(undef, 0, 0)
    legInjection = Array{Float64}(undef, 0, 0)
    legVoltage = Array{Float64}(undef, 0, 0)
    pmuCurrent = Array{Float64}(undef, 0, 0)
    pmuVoltage = Array{Float64}(undef, 0, 0)

    for i in keys(read_data)
        if i == "legacy"
            for j in keys(read_data[i])
                if j == "flow"
                    legFlow = read_data[i][j]
                end
                if j == "current"
                    legCurrent = read_data[i][j]
                end
                if j == "injection"
                    legInjection = read_data[i][j]
                end
                if j == "voltage"
                    legVoltage = read_data[i][j]
                end
            end
        end
        if i == "pmu"
            for j in keys(read_data[i])
                if j == "current"
                    pmuCurrent = read_data[i][j]
                end
                if j == "voltage"
                    pmuVoltage = read_data[i][j]
                end
            end
        end
    end

    return StateEstimation(legFlow, legCurrent, legInjection, legVoltage, pmuCurrent, pmuVoltage)
end
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function sesettings(ARGS, MAX, STOP, SOLVE)
    algorithm = "false"
    algorithm_type = ["dc", "nonlinear"]

    for i = 1:length(ARGS)
        if any(algorithm_type .== ARGS[i])
            algorithm = ARGS[i]
        end
    end

    if algorithm == "false"
        algorithm = "nonlinear"
        @info("Invalid power flow algorithm key. The algorithm proceeds with the nonlinear state estimation.")
    end

    return EstimationSettings(algorithm)
end
#-------------------------------------------------------------------------------
