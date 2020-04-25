######################
#  Struct Variables  #
######################
struct PowerSystem
    bus::Array{Float64,2}
    generator::Array{Float64,2}
    branch::Array{Float64,2}
    baseMVA::Float64
    info::Union{Array{String,1}, Array{String,2}}
    Nbus::Int64
    Ngen::Int64
    Nbra::Int64
    packagepath::String
    path::String
    dataname::String
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
    runflow::Int64
    maxIter::Int64
    stopping::Float64
    reactive::Array{Bool,1}
    set::Dict{Any, Any}
    variance::Dict{Any, Any}
end

struct StateEstimation
    pmuCurrent::Array{Float64,2}
    pmuVoltage::Array{Float64,2}
    legacyFlow::Array{Float64,2}
    legacyCurrent::Array{Float64,2}
    legacyInjection::Array{Float64,2}
    legacyVoltage::Array{Float64,2}
    type::Array{String,1}
end

struct EstimationSettings
    algorithm::String
end


############################
#  Load power system data  #
############################
function loadsystem(args)
    packagepath = abspath(joinpath(dirname(Base.find_package("JuliaGrid")), ".."))
    extension = ""; path = ""; dataname = ""; fullpath = ""
    for i = 1:length(args)
        try
            extension = match(r"\.[A-Za-z0-9]+$", args[i]).match
            if extension == ".h5" || extension == ".xlsx"
                fullpath = args[i]
                path = dirname(args[i])
                dataname = basename(args[i])
                break
            end
        catch
        end
    end

    if isempty(extension)
        error("The input DATA format is not supported.")
    end

    if path == ""
        path = joinpath(packagepath, "src/data/")
        fullpath = joinpath(packagepath, "src/data/", dataname)
    end

    input_data = cd(readdir, path)
    if dataname in input_data
        println(string("The input power system: ", dataname))
    else
        error("The input DATA is not found.")
    end

    read_data = readdata(fullpath, extension; type = "pf")

    if !("bus" in keys(read_data))
        error("Invalid DATA structure, variable bus not found.")
    end
    if !("branch" in keys(read_data))
        error("Invalid DATA structure, variable branch not found.")
    end

    bus = Array{Float64}(undef, 0, 0)
    branch = Array{Float64}(undef, 0, 0)
    generator = zeros(1, 21)
    baseMVA = 0.0
    info = Array{String}(undef, 0)
    Nbus = 0; Ngen = 0; Nbra = 0

    for i in keys(read_data)
        if i == "bus"
           bus = read_data[i]
           Nbus = datastruct(bus, 13; var = i)
        end
        if i == "generator"
            generator = read_data[i]
            Ngen = datastruct(generator, 21; var = i)
        end
        if i == "branch"
            branch = read_data[i]
            Nbra = datastruct(branch, 14; var = i)
        end
        if i == "basePower"
            baseMVA = read_data[i][1]
        end
        if i == "info"
            info = read_data[i]
        end
    end

    if baseMVA == 0
        baseMVA = 100.0
        @info("The variable basePower not found. The algorithm proceeds with default value: 100 MVA")
    end

    info = infogrid(bus, branch, generator, info, dataname, Nbra, Nbus, Ngen)

    return PowerSystem(bus, generator, branch, baseMVA, info, Nbus, Ngen, Nbra, packagepath, fullpath, dataname, extension)
end


###############################
#  Set power system settings  #
###############################
function pfsettings(args, max, stop, react, solve, save, system)
    algorithm = "false"
    algorithm_type = ["nr", "gs", "fnrxb", "fnrbx", "dc"]
    main = false
    flow = false
    generator = false
    reactive = [false; true; false]

    for i = 1:length(args)
        if args[i] in algorithm_type
            algorithm = args[i]
        end
        if args[i] == "main"
            main = true
        end
        if args[i] == "flow"
            flow = true
        end
        if args[i] == "generator" && system.Ngen != 0
            generator = true
        end
    end

    if react == 1 && system.Ngen != 0
        reactive = [true; true; false]
    end

    if algorithm == "false"
        algorithm = "nr"
        @info("Invalid power flow METHOD key. The algorithm proceeds with the AC power flow.")
    end

    if !isempty(save)
        path = dirname(save)
        data = basename(save)
        if isempty(data)
            dataname = join(replace(split(system.dataname, ""), "."=>""))
            data = string(dataname, "_results", system.extension)
        end
        save = joinpath(path, data)
    end

    return FlowSettings(algorithm, solve, main, flow, generator, save, max, stop, reactive)
end


###########################
#  Load measurement data  #
###########################
function loadmeasurement(system, runflow)
    if runflow == 1
        measurement = Dict()
        push!(measurement, "pmuVoltage" => fill(0.0, system.Nbus, 9))
        push!(measurement, "pmuCurrent" => fill(0.0, 2 * system.Nbra, 11))
        push!(measurement, "legacyFlow" => fill(0.0, 2 * system.Nbra, 11))
        push!(measurement, "legacyCurrent" => fill(0.0, 2 * system.Nbra, 7))
        push!(measurement, "legacyInjection" => fill(0.0, system.Nbus, 9))
        push!(measurement, "legacyVoltage" => fill(0.0, system.Nbus, 5))
    else
        measurement = readdata(system.path, system.extension; type = "se")
    end

    return measurement
end


########################################
#  Set measurement generator settings  #
########################################
function gesettings(runflow, max, stop, react, solve, save, pmuset, pmuvariance, legacyset, legacyvariance, measurement)
    savepf = ""
    algorithm = "nr"
    main = false
    flow = false
    generator = false

    reactive = [false; true; false]
    if react == 1
        reactive = [true; true; false]
    end

    names = keys(measurement)
    set = Dict()
    variance = Dict()

    ################## PMU Set ##################
    if !isa(pmuset, Array)
        pmuset = [pmuset]
    end

    onebyone = false
    for i in pmuset
        if i in ["Vi", "Ti", "Iij", "Dij"]
            onebyone = true
            break
        end
    end
    if onebyone
        for i in pmuset
            if i in ["Vi", "Ti"] && "pmuVoltage" in names
                push!(set, "pmuVoltage" => convert(Array{Any}, ["no"; "no"]))
            end
            if i in ["Iij", "Dij"] && "pmuCurrent" in names
                push!(set, "pmuCurrent" => convert(Array{Any}, ["no"; "no"]))
            end
        end
        for (k, i) in enumerate(pmuset)
            if i == "Vi" && "pmuVoltage" in names
                set["pmuVoltage"][1] = nextelement(pmuset, k)
            end
            if i == "Ti" && "pmuVoltage" in names
                set["pmuVoltage"][2] = nextelement(pmuset, k)
            end
            if i == "Iij" && "pmuCurrent" in names
                set["pmuCurrent"][1] = nextelement(pmuset, k)
            end
            if i == "Dij" && "pmuCurrent" in names
                set["pmuCurrent"][2] = nextelement(pmuset, k)
            end
        end
    end
    if !onebyone && any(names .== ["pmuVoltage" "pmuCurrent"])
        for (k, i) in enumerate(pmuset)
            if i in ["redundancy" "device"]
                push!(set, string("pmu", i) => nextelement(pmuset, k))
                break
            end
            if i in ["all" "optimal"]
                push!(set, string("pmu", i) => i)
                break
            end
        end
    end

    ################## Legacy Set ##################
    if !isa(legacyset, Array)
        legacyset = [legacyset]
    end

    onebyone = false
    for i in legacyset
        if i in ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"]
            onebyone = true
            break
        end
    end
    if onebyone
        for i in legacyset
            if i in ["Pij", "Qij"] && "legacyFlow" in names
                push!(set, "legacyFlow" => convert(Array{Any}, ["no"; "no"]))
            end
            if i == "Iij" && "legacyCurrent" in names
                push!(set, "legacyCurrent" => convert(Array{Any}, ["no"]))
            end
            if i in ["Pi", "Qi"] && "legacyInjection" in names
                push!(set, "legacyInjection" => convert(Array{Any}, ["no"; "no"]))
            end
            if i == "Vi" && "legacyVoltage" in names
                push!(set, "legacyVoltage" => convert(Array{Any}, ["no"]))
            end
        end
        for (k, i) in enumerate(legacyset)
            if i == "Pij" && "legacyFlow" in names
                set["legacyFlow"][1] = nextelement(legacyset, k)
            end
            if i == "Qij" && "legacyFlow" in names
                set["legacyFlow"][2] = nextelement(legacyset, k)
            end
            if i == "Iij" && "legacyCurrent" in names
                set["legacyCurrent"][1] = nextelement(legacyset, k)
            end
            if i == "Pi" && "legacyInjection" in names
                set["legacyInjection"][1] = nextelement(legacyset, k)
            end
            if i == "Qi" && "legacyInjection" in names
                set["legacyInjection"][2] = nextelement(legacyset, k)
            end
            if i == "Vi" && "legacyVoltage" in names
                set["legacyVoltage"][1] = nextelement(legacyset, k)
            end
        end
    end
    if !onebyone && any(names .== ["legacyFlow" "legacyCurrent" "legacyInjection" "legacyVoltage"])
        for (k, i) in enumerate(legacyset)
            if i == "redundancy"
                push!(set, string("legacy", i) => nextelement(legacyset, k))
                break
            end
            if i == "all"
                push!(set, string("legacy", i) => i)
                break
            end
        end
    end

    ################## PMU Variance ##################
    onebyone = false
    all = false
    for i in pmuvariance
        if i in ["Vi", "Ti", "Iij", "Dij"]
            onebyone = true
        end
        if i == "all"
            all = true
        end
    end
    if all && onebyone
        valall = 0.0
        for (k, i) in enumerate(pmuvariance)
            if i == "all"
                valall = nextelement(pmuvariance, k)
            end
        end
        miss = setdiff(["Vi", "Ti", "Iij", "Dij"], pmuvariance)
        for i in miss
            pmuvariance = [pmuvariance i valall]
        end
    end
    if onebyone
        for i in pmuvariance
            if i in ["Vi", "Ti"] && "pmuVoltage" in names
                push!(variance, "pmuVoltage" => convert(Array{Any}, ["no"; "no"]))
            end
            if i in ["Iij", "Dij"] && "pmuCurrent" in names
                push!(variance, "pmuCurrent" => convert(Array{Any}, ["no"; "no"]))
            end
        end
        for (k, i) in enumerate(pmuvariance)
            if i == "Vi" && "pmuVoltage" in names
                variance["pmuVoltage"][1] = nextelement(pmuvariance, k)
            end
            if i == "Ti" && "pmuVoltage" in names
                variance["pmuVoltage"][2] = nextelement(pmuvariance, k)
            end
            if i == "Iij" && "pmuCurrent" in names
                variance["pmuCurrent"][1] = nextelement(pmuvariance, k)
            end
            if i == "Dij" && "pmuCurrent" in names
                variance["pmuCurrent"][2] = nextelement(pmuvariance, k)
            end
        end
    end
    if !onebyone && any(names .== ["pmuVoltage" "pmuCurrent"])
        for (k, i) in enumerate(pmuvariance)
            if i == "random"
                push!(variance, string("pmu", i) => [nextelement(pmuvariance, k); nextelement(pmuvariance, k + 1)])
                break
            end
            if i == "all"
                push!(variance, string("pmu", i) => nextelement(pmuvariance, k))
                break
            end
        end
    end

    ################## Legacy Variance ##################
    onebyone = false
    all = false
    for i in legacyvariance
        if i in ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"]
            onebyone = true
        end
        if i == "all"
            all = true
        end
    end
    if all && onebyone
        valall = 0.0
        for (k, i) in enumerate(legacyvariance)
            if i == "all"
                valall = nextelement(legacyvariance, k)
            end
        end
        miss = setdiff(["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"], legacyvariance)
        for i in miss
            legacyvariance = [legacyvariance i valall]
        end
    end
    if onebyone
        for i in legacyvariance
            if i in ["Pij", "Qij"] && "legacyFlow" in names
                push!(variance, "legacyFlow" => convert(Array{Any}, ["no"; "no"]))
            end
            if i == "Iij" && "legacyCurrent" in names
                push!(variance, "legacyCurrent" => convert(Array{Any}, ["no"]))
            end
            if i in ["Pi", "Qi"] && "legacyInjection" in names
                push!(variance, "legacyInjection" => convert(Array{Any}, ["no"; "no"]))
            end
            if i == "Vi" && "legacyVoltage" in names
                push!(variance, "legacyVoltage" => convert(Array{Any}, ["no"]))
            end
        end
        for (k, i) in enumerate(legacyvariance)
            if i == "Pij" && "legacyFlow" in names
                variance["legacyFlow"][1] = nextelement(legacyvariance, k)
            end
            if i == "Qij" && "legacyFlow" in names
                variance["legacyFlow"][2] = nextelement(legacyvariance, k)
            end
            if i == "Iij" && "legacyCurrent" in names
                variance["legacyCurrent"][1] = nextelement(legacyvariance, k)
            end
            if i == "Pi" && "legacyInjection" in names
                variance["legacyInjection"][1] = nextelement(legacyvariance, k)
            end
            if i == "Qi" && "legacyInjection" in names
                variance["legacyInjection"][2] = nextelement(legacyvariance, k)
            end
            if i == "Vi" && "legacyVoltage" in names
                variance["legacyVoltage"][1] = nextelement(legacyvariance, k)
            end
        end
    end
    if !onebyone  && any(names .== ["legacyFlow" "legacyCurrent" "legacyInjection" "legacyVoltage"])
        for (k, i) in enumerate(legacyvariance)
            if i == "random"
                push!(variance, string("legacy", i) =>  [nextelement(legacyvariance, k); nextelement(legacyvariance, k + 1)])
                break
            end
            if i == "all"
                push!(variance, string("legacy", i) => nextelement(legacyvariance, k))
                break
            end
        end
    end

    return GeneratorSettings(algorithm, solve, main, flow, generator, savepf, save, runflow, max, stop, reactive, set, variance)
end


###################################
#  Set state estimation settings  #
###################################
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
