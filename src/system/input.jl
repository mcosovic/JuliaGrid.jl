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
    runflow::Int64
    set::Dict{Any, Any}
    variance::Dict{Any, Any}
    save::String
end

struct EstimationSettings
    algorithm::String
    main::Bool
    flow::Bool
    estimate::Bool
    error::Bool
    maxIter::Int64
    stopping::Float64
    start::String
    bad::Int64
    lav::Int64
    solve::String
    save::String
end

struct StateEstimation
    pmuVoltage::Array{Float64,2}
    pmuCurrent::Array{Float64,2}
    legacyFlow::Array{Float64,2}
    legacyCurrent::Array{Float64,2}
    legacyInjection::Array{Float64,2}
    legacyVoltage::Array{Float64,2}
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
        catch
            extension = ""
        end
        if extension == ".h5" || extension == ".xlsx"
            fullpath = args[i]
            path = dirname(args[i])
            dataname = basename(args[i])
            break
        end
    end

    if isempty(extension)
        throw(ErrorException("the input DATA extension is not found"))
    elseif extension != ".h5" && extension != ".xlsx"
        throw(DomainError(extension, "the input DATA extension is not supported"))
    end

    if path == ""
        path = joinpath(packagepath, "src/data/")
        fullpath = joinpath(packagepath, "src/data/", dataname)
    end

    if dataname in cd(readdir, path)
        println("The input power system: $dataname")
    else
        throw(DomainError(dataname, "the input DATA is not found"))
    end

    read_data = readdata(fullpath, extension, "power system")
    if !("bus" in keys(read_data))
        throw(UndefVarError(:bus))
    end
    if !("branch" in keys(read_data))
        throw(UndefVarError(:branch))
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


#########################
#  Power flow settings  #
#########################
function pfsettings(args, max, stop, react, solve, save, system)
    algorithm = "false"
    main = false
    flow = false
    generator = false
    reactive = [false; true; false]

    for i = 1:length(args)
        if args[i] in ["nr", "gs", "fnrxb", "fnrbx", "dc"]
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
function loadmeasurement(system, pmuvariance, legacyvariance; runflow = 0)
    if runflow == 1
        measurement = Dict()
        push!(measurement, "pmuVoltage" => fill(0.0, system.Nbus, 9))
        push!(measurement, "pmuCurrent" => fill(0.0, 2 * system.Nbra, 11))
        push!(measurement, "legacyFlow" => fill(0.0, 2 * system.Nbra, 11))
        push!(measurement, "legacyCurrent" => fill(0.0, 2 * system.Nbra, 7))
        push!(measurement, "legacyInjection" => fill(0.0, system.Nbus, 9))
        push!(measurement, "legacyVoltage" => fill(0.0, system.Nbus, 5))
    else
        measurement = readdata(system.path, system.extension, "measurements")
        col = Dict("pmuVoltage" => [9 7], "pmuCurrent" => [11 9], "legacyFlow" => [11 9],
        "legacyCurrent" => [7 6], "legacyInjection" => [9 7], "legacyVoltage" => [5 4])
        if !isempty(pmuvariance) || !isempty(legacyvariance)
            for i in keys(measurement)
                Ncol = size(measurement[i], 2)
                if Ncol < col[i][1]
                    throw(DomainError(i, "dimension mismatch, invoking the arguments for variances requires exact values"))
                end
            end
        else
            for i in keys(measurement)
                Ncol = size(measurement[i], 2)
                if Ncol < col[i][2]
                    throw(DomainError(i, "dimension mismatch"))
                end
            end
        end
    end

    return measurement
end


###############################################
#  Measurement generator power flow settings  #
###############################################
function gepfsettings(max, stop, react, solve)
    save = ""
    algorithm = "nr"
    main = false
    flow = false
    generator = false

    reactive = [false; true; false]
    if react == 1
        reactive = [true; true; false]
    end

    return FlowSettings(algorithm, solve, main, flow, generator, save, max, stop, reactive)
end


####################################
#  Measurement generator settings  #
####################################
function gesettings(pmuset, pmuvariance, legacyset, legacyvariance, measurement; runflow = 0, save = "")
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

    return GeneratorSettings(runflow, set, variance, save)
end


###############################
#  State estimation settings  #
###############################
function sesettings(args, max, stop, start, bad, lav, solve, save)
    algorithm = "false"
    main = false; flow = false; estimate = false; error = false

    for i in args
        if i in ["dc", "nonlinear"]
            algorithm = i
        end
        if i == "main"
            main = true
        end
        if i == "flow"
            flow = true
        end
        if i == "estimate"
            estimate = true
        end
        if i == "error"
            error = true
        end
    end

    if algorithm == "false"
        algorithm = "nonlinear"
        @info("Invalid state estimation METHOD key. The algorithm proceeds with the nonlinear state estimation.")
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

    return EstimationSettings(algorithm, main, flow, estimate, error, max, stop, start, bad, lav, solve, save)
end


################################
#  Load state estimation data  #
################################
function loadestimation(measurement)
    pmuVoltage = zeros(1, 9)
    pmuCurrent = zeros(1, 11)
    legacyFlow = zeros(1, 11)
    legacyCurrent = zeros(1, 7)
    legacyInjection = zeros(1, 9)
    legacyVoltage = zeros(1, 5)
    pmuNv = 0; pmuNc = 0; legacyNf = 0; legacyNc = 0; legacyNi = 0; legacyNv = 0

    if !any(keys(measurement) .== ["pmuVoltage" "pmuCurrent" "legacyFlow" "legacyCurrent" "legacyInjection" "legacyVoltage"])
        throw(ErrorException("invalid DATA structure, measurements not found"))
    end

    for i in keys(measurement)
        if i == "pmuVoltage"
           pmuVoltage = measurement[i]
        end
        if i == "pmuCurrent"
            pmuCurrent = measurement[i]
        end
        if i == "legacyFlow"
            legacyFlow = measurement[i]
        end
        if i == "legacyCurrent"
            legacyCurrent = measurement[i]
        end
        if i == "legacyInjection"
            legacyInjection = measurement[i]
        end
        if i == "legacyVoltage"
            legacyVoltage = measurement[i]
        end
    end

    return StateEstimation(pmuVoltage, pmuCurrent, legacyFlow, legacyCurrent, legacyInjection, legacyVoltage)
end
