### Struct variables
struct Path
    packagepath::String
    fullpath::String
    dataname::String
    extension::String
end

struct PowerSystem
    bus::Array{Float64,2}
    branch::Array{Float64,2}
    generator::Array{Float64,2}
    basePower::Float64
end

struct PowerSystemNum
    Nbus::Int64
    Nbranch::Int64
    Ngen::Int64
end

struct FlowSettings
    algorithm::String
    solve::String
    main::Bool
    flow::Bool
    generation::Bool
    save::String
    maxIter::Int64
    stopping::Float64
    reactive::Array{Bool,1}
end

struct Measurements
    pmuVoltage::Array{Float64,2}
    pmuCurrent::Array{Float64,2}
    legacyFlow::Array{Float64,2}
    legacyCurrent::Array{Float64,2}
    legacyInjection::Array{Float64,2}
    legacyVoltage::Array{Float64,2}
end

struct MeasurementsNum
    pmuNv::Int64
    pmuNc::Int64
    legacyNf::Int64
    legacyNc::Int64
    legacyNi::Int64
    legacyNv::Int64
end

struct GeneratorSettings
    runflow::Int64
    set::Dict{Symbol,Array{Float64,1}}
    variance::Dict{Symbol,Array{Float64,1}}
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
    bad::Dict{Symbol,Float64}
    lav::Dict{Symbol,Float64}
    observe::Dict{Symbol,Float64}
    covariance::Bool
    solve::String
    save::String
    saveextension::String
end


### Load path
function loadpath(args)
    pathtoJuliaGrid = Base.find_package("JuliaGrid")
    if pathtoJuliaGrid == nothing
        throw(ErrorException("JuliaGrid not found in install packages"))
    end
    packagepath = abspath(joinpath(dirname(pathtoJuliaGrid), ".."))
    extension = ".h5"; path = ""; dataname = ""; fullpath = ""
    for i = 1:length(args)
        try
            extension = string(match(r"\.[A-Za-z0-9]+$", args[i]).match)
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

    return Path(packagepath, fullpath, dataname, extension)
end


### Load power system data
function loadsystem(path)
    if path.extension == ".h5"
        fid = h5open(path.fullpath, "r")
            bus::Array{Float64,2} = h5read(path.fullpath, "/bus")
            branch::Array{Float64,2} = h5read(path.fullpath, "/branch")
            Nbus = datastruct(bus, 13; var = "bus")
            Nbranch = datastruct(branch, 14; var = "branch")
        if exists(fid, "generator")
            generator::Array{Float64,2} = h5read(path.fullpath, "/generator")
            Ngen = datastruct(generator, 21; var = "generator")
        else
            generator = zeros(1, 21)
            Ngen = 0
        end
        if exists(fid, "basePower")
            basePower::Float64 = h5read(path.fullpath, "/basePower")[1]
        else
            basePower = 100.0
            println("The variable basePower not found. The algorithm proceeds with default value: 100 MVA.")
        end
        if exists(fid, "info")
            info::Array{String,2} = h5read(path.fullpath, "/info")
        else
            info = Array{String}(undef, 0, 1)
        end
        close(fid)
    end

    if path.extension == ".xlsx"
        xf = XLSX.openxlsx(path.fullpath, mode = "r")
        if "bus" in XLSX.sheetnames(xf)
            start = startxlsx(xf["bus"])
            bus = xf["bus"][:][start:end, :]
            Nbus = datastruct(bus, 13; var = "bus")
        else
            throw(ErrorException("error opening sheet bus"))
        end
        if "branch" in XLSX.sheetnames(xf)
            start = startxlsx(xf["branch"])
            branch = xf["branch"][:][start:end, :]
            Nbranch = datastruct(branch, 14; var = "branch")
        else
            throw(ErrorException("error opening sheet branch"))
        end
        if "generator" in XLSX.sheetnames(xf)
            start = startxlsx(xf["generator"])
            generator = xf["generator"][:][start:end, :]
            Ngen = datastruct(generator, 21; var = "generator")
        else
            generator = zeros(1, 21)
            Ngen = 0
        end
        if "basePower" in XLSX.sheetnames(xf)
            start = startxlsx(xf["basePower"])
            basePower = Float64(xf["basePower"][:][start])
        else
            basePower = 100.0
            println("The variable basePower not found. The algorithm proceeds with default value: 100 MVA.")
        end
        if "info" in XLSX.sheetnames(xf)
            info = convert(Array{String,2}, coalesce.(xf["info"][:], ""))
        else
            info = Array{String}(undef, 0, 1)
        end
        # close(xf)
    end

    info = infogrid(bus, branch, generator, info, path.dataname, Nbranch, Nbus, Ngen)

    return PowerSystem(bus, branch, generator, basePower), PowerSystemNum(Nbus, Nbranch, Ngen), info
end


### Power flow settings
@inbounds function pfsettings(args, max, stop, react, solve, save, system, num)
    algorithm = "false"
    main = false
    flow = false
    generation = false
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
        if args[i] == "generation" && num.Ngen != 0
            generation = true
        end
    end

    if react == 1 && num.Ngen != 0
        reactive = [true; true; false]
    end

    if algorithm == "false"
        algorithm = "nr"
        println("Invalid power flow METHOD key. The algorithm proceeds with the AC power flow.")
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

    return FlowSettings(algorithm, solve, main, flow, generation, save, max, stop, reactive)
end

### Load measurement data
@inbounds function loadmeasurement(path, system, numsys; pmuvar = [], legvar = [], runflow = 0)
    if runflow == 1
        pmuNv = numsys.Nbus
        pmuNc = 2 * numsys.Nbranch
        legacyNf = 2 * numsys.Nbranch
        legacyNc = 2 * numsys.Nbranch
        legacyNi = numsys.Nbus
        legacyNv = numsys.Nbus

        pmuVoltage = fill(0.0, pmuNv, 9)
        pmuCurrent = fill(0.0, pmuNc, 11)
        legacyFlow = fill(0.0, legacyNf, 11)
        legacyCurrent = fill(0.0, legacyNc, 7)
        legacyInjection = fill(0.0, legacyNi, 9)
        legacyVoltage = fill(0.0, legacyNv, 5)
    else
        flag = isempty(pmuvar) || isempty(legvar)

        if path.extension == ".h5"
            fid = h5open(path.fullpath, "r")
            if exists(fid, "pmuVoltage")
                pmuVoltage::Array{Float64,2} = h5read(path.fullpath, "/pmuVoltage")
                if flag
                    pmuNv = datastruct(pmuVoltage, 7; var = "pmuVoltage")
                else
                    pmuNv = datastruct(pmuVoltage, 9; var = "pmuVoltage")
                end
            else
                pmuVoltage = zeros(1, 9); pmuNv = 0
            end
            if exists(fid, "pmuCurrent")
                pmuCurrent::Array{Float64,2} = h5read(path.fullpath, "/pmuCurrent")
                if flag
                    pmuNc = datastruct(pmuCurrent, 9; var = "pmuCurrent")
                else
                    pmuNc = datastruct(pmuCurrent, 11; var = "pmuCurrent")
                end
            else
                pmuCurrent = zeros(1, 11); pmuNc = 0
            end
            if exists(fid, "legacyFlow")
                legacyFlow::Array{Float64,2} = h5read(path.fullpath, "/legacyFlow")
                if flag
                    legacyNf = datastruct(legacyFlow, 9; var = "legacyFlow")
                else
                    legacyNf = datastruct(legacyFlow, 11; var = "legacyFlow")
                end
            else
                legacyFlow = zeros(1, 11); legacyNf = 0
            end
            if exists(fid, "legacyCurrent")
                legacyCurrent::Array{Float64,2} = h5read(path.fullpath, "/legacyCurrent")
                if flag
                    legacyNc = datastruct(legacyCurrent, 6; var = "legacyCurrent")
                else
                    legacyNc = datastruct(legacyCurrent, 7; var = "legacyCurrent")
                end
            else
                legacyCurrent = zeros(1, 7); legacyNc = 0
            end
            if exists(fid, "legacyInjection")
                legacyInjection::Array{Float64,2} = h5read(path.fullpath, "/legacyInjection")
                if flag
                    legacyNi = datastruct(legacyInjection, 7; var = "legacyInjection")
                else
                    legacyNi = datastruct(legacyInjection, 9; var = "legacyInjection")
                end
            else
                legacyInjection = zeros(1, 9); legacyNi = 0
            end
            if exists(fid, "legacyVoltage")
                legacyVoltage::Array{Float64,2} = h5read(path.fullpath, "/legacyVoltage")
                if flag
                    legacyNv = datastruct(legacyVoltage, 4; var = "legacyVoltage")
                else
                    legacyNv = datastruct(legacyVoltage, 5; var = "legacyVoltage")
                end
            else
                legacyVoltage = zeros(1, 9); legacyNv = 0
            end
            close(fid)
        end

        if path.extension == ".xlsx"
            xf = XLSX.openxlsx(path.fullpath, mode = "r")
            if "pmuVoltage" in XLSX.sheetnames(xf)
                start = startxlsx(xf["pmuVoltage"])
                pmuVoltage = xf["pmuVoltage"][:][start:end, :]
                if flag
                    pmuNv = datastruct(pmuVoltage, 7; var = "pmuVoltage")
                else
                    pmuNv = datastruct(pmuVoltage, 9; var = "pmuVoltage")
                end
            else
                pmuVoltage = zeros(1, 9); pmuNv = 0
            end
            if "pmuCurrent" in XLSX.sheetnames(xf)
                start = startxlsx(xf["pmuCurrent"])
                pmuCurrent = xf["pmuCurrent"][:][start:end, :]
                if flag
                    pmuNc = datastruct(pmuCurrent, 9; var = "pmuCurrent")
                else
                    pmuNc = datastruct(pmuCurrent, 11; var = "pmuCurrent")
                end
            else
                pmuCurrent = zeros(1, 11); pmuNc = 0
            end
            if "legacyFlow" in XLSX.sheetnames(xf)
                start = startxlsx(xf["legacyFlow"])
                legacyFlow = xf["legacyFlow"][:][start:end, :]
                if flag
                    legacyNf = datastruct(legacyFlow, 9; var = "legacyFlow")
                else
                    legacyNf = datastruct(legacyFlow, 11; var = "legacyFlow")
                end
            else
                legacyFlow = zeros(1, 11); legacyNf = 0
            end
            if "legacyCurrent" in XLSX.sheetnames(xf)
                start = startxlsx(xf["legacyCurrent"])
                legacyCurrent = xf["legacyCurrent"][:][start:end, :]
                if flag
                    legacyNc = datastruct(legacyCurrent, 6; var = "legacyCurrent")
                else
                    legacyNc = datastruct(legacyCurrent, 7; var = "legacyCurrent")
                end
            else
                legacyCurrent = zeros(1, 7); legacyNc = 0
            end
            if "legacyInjection" in XLSX.sheetnames(xf)
                start = startxlsx(xf["legacyInjection"])
                legacyInjection = xf["legacyInjection"][:][start:end, :]
                if flag
                    legacyNi = datastruct(legacyInjection, 7; var = "legacyInjection")
                else
                    legacyNi = datastruct(legacyInjection, 9; var = "legacyInjection")
                end
            else
                legacyInjection = zeros(1, 9); legacyNi = 0
            end
            if "legacyVoltage" in XLSX.sheetnames(xf)
                start = startxlsx(xf["legacyVoltage"])
                legacyVoltage = xf["legacyVoltage"][:][start:end, :]
                if flag
                    legacyNv = datastruct(legacyVoltage, 4; var = "legacyVoltage")
                else
                    legacyNv = datastruct(legacyVoltage, 5; var = "legacyVoltage")
                end
            else
                legacyVoltage = zeros(1, 9); legacyNv = 0
            end
            # close(xf)
        end
    end

    return Measurements(pmuVoltage, pmuCurrent, legacyFlow, legacyCurrent, legacyInjection, legacyVoltage),
        MeasurementsNum(pmuNv, pmuNc, legacyNf, legacyNc, legacyNi, legacyNv)
end


### Measurement generator power flow settings
@inbounds function gepfsettings(max, stop, react, solve)
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


#### Measurement generator settings
@inbounds function gesettings(num, pmuset, pmuvariance, legacyset, legacyvariance, runflow, save)
    set = Dict{Symbol, Array{Float64,1}}()
    variance = Dict{Symbol, Array{Float64,1}}()

    ########## PMU set ##########
    if !isa(pmuset, Array)
        pmuset = [pmuset]
    end
    pmuset = vec(pmuset)

    onebyone = false
    complete = false
    for i in pmuset
        if i in ["Vi", "Ti", "Iij", "Dij"]
            onebyone = true
        end
        if i == "complete"
            complete = true
        end
    end
    if complete && onebyone
        deleteat!(pmuset, findall(x->x=="complete", pmuset))
        miss = setdiff(["Vi", "Ti", "Iij", "Dij"], pmuset)
        for i in miss
            pmuset = [pmuset; i; -200.0]
        end
    end

    if onebyone
        for i in pmuset
            if i in ["Vi", "Ti"] && num.pmuNv != 0
                push!(set, :pmuVoltage => [-100.0, -100.0])
            end
            if i in ["Iij", "Dij"] && num.pmuNc != 0
                push!(set, :pmuCurrent => [-100.0, -100.0])
            end
        end
        for (k, i) in enumerate(pmuset)
            if i == "Vi" && num.pmuNv != 0
                set[:pmuVoltage][1] = round(nextelement(pmuset, k))
            end
            if i == "Ti" && num.pmuNv != 0
                set[:pmuVoltage][2] = round(nextelement(pmuset, k))
            end
            if i == "Iij" && num.pmuNc != 0
                set[:pmuCurrent][1] = round(nextelement(pmuset, k))
            end
            if i == "Dij" && num.pmuNc != 0
                set[:pmuCurrent][2] = round(nextelement(pmuset, k))
            end
        end
    end
    if !onebyone && (num.pmuNv != 0 || num.pmuNc != 0)
        for (k, i) in enumerate(pmuset)
            if i == "redundancy"
                push!(set, Symbol(:pmu, i) => [nextelement(pmuset, k)])
                break
            end
            if i == "device"
                push!(set, Symbol(:pmu, i) => [nextelement(pmuset, k)])
                break
            end
            if i in ["complete" "optimal"]
                push!(set, Symbol(:pmu, i) => [0.0])
                break
            end
        end
    end

    ########## Legacy set ##########
    if !isa(legacyset, Array)
        legacyset = [legacyset]
    end
    legacyset = vec(legacyset)

    onebyone = false
    complete = false
    for i in legacyset
        if i in ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"]
            onebyone = true
        end
        if i == "complete"
            complete = true
        end
    end
    if complete && onebyone
        deleteat!(legacyset, findall(x->x=="complete", legacyset))
        miss = setdiff(["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"], legacyset)
        for i in miss
            legacyset = [legacyset; i; -200.0]
        end
    end

    if onebyone
        for i in legacyset
            if i in ["Pij", "Qij"] && num.legacyNf != 0
                push!(set, :legacyFlow => [-100.0, -100.0])
            end
            if i == "Iij" && num.legacyNc != 0
                push!(set, :legacyCurrent => [-100.0])
            end
            if i in ["Pi", "Qi"] && num.legacyNi != 0
                push!(set, :legacyInjection => [-100.0, -100.0])
            end
            if i == "Vi" && num.legacyNv != 0
                push!(set, :legacyVoltage => [-100.0])
            end
        end
        for (k, i) in enumerate(legacyset)
            if i == "Pij" && num.legacyNf != 0
                set[:legacyFlow][1] = round(nextelement(legacyset, k))
            end
            if i == "Qij" && num.legacyNf != 0
                set[:legacyFlow][2] = round(nextelement(legacyset, k))
            end
            if i == "Iij" && num.legacyNc != 0
                set[:legacyCurrent] = [round(nextelement(legacyset, k))]
            end
            if i == "Pi" && num.legacyNi != 0
                set[:legacyInjection][1] = round(nextelement(legacyset, k))
            end
            if i == "Qi" && num.legacyNi != 0
                set[:legacyInjection][2] = round(nextelement(legacyset, k))
            end
            if i == "Vi" && num.legacyNv != 0
                set[:legacyVoltage] = [round(nextelement(legacyset, k))]
            end
        end
    end
    if !onebyone && any([num.legacyNf, num.legacyNc, num.legacyNi, num.legacyNv] .!= 0)
        for (k, i) in enumerate(legacyset)
            if i == "redundancy"
                push!(set, Symbol(:legacy, i) => [nextelement(legacyset, k)])
                break
            end
            if i == "complete"
                push!(set, Symbol(:legacy, i) => [0.0])
                break
            end
        end
    end

    ########## PMU variance ##########
    pmuvariance = vec(pmuvariance)
    onebyone = false
    complete = false
    for i in pmuvariance
        if i in ["Vi", "Ti", "Iij", "Dij"]
            onebyone = true
        end
        if i == "complete"
            complete = true
        end
    end
    if complete && onebyone
        valall = 0.0
        for (k, i) in enumerate(pmuvariance)
            if i == "complete"
                valall = nextelement(pmuvariance, k)
            end
        end
        miss = setdiff(["Vi", "Ti", "Iij", "Dij"], pmuvariance)
        for i in miss
            pmuvariance = [pmuvariance; i; valall]
        end
    end
    if onebyone
        for i in pmuvariance
            if i in ["Vi", "Ti"] && num.pmuNv != 0
                push!(variance, :pmuVoltage => [-100.0, -100.0])
            end
            if i in ["Iij", "Dij"] && num.pmuNc != 0
                push!(variance, :pmuCurrent => [-100.0, -100.0])
            end
        end
        for (k, i) in enumerate(pmuvariance)
            if i == "Vi" && num.pmuNv != 0
                variance[:pmuVoltage][1] = nextelement(pmuvariance, k)
            end
            if i == "Ti" && num.pmuNv != 0
                variance[:pmuVoltage][2] = nextelement(pmuvariance, k)
            end
            if i == "Iij" && num.pmuNc != 0
                variance[:pmuCurrent][1] = nextelement(pmuvariance, k)
            end
            if i == "Dij" && num.pmuNc != 0
                variance[:pmuCurrent][2] = nextelement(pmuvariance, k)
            end
        end
    end
    if !onebyone && (num.pmuNv != 0 || num.pmuNc != 0)
        for (k, i) in enumerate(pmuvariance)
            if i == "random"
                push!(variance, Symbol(:pmu, i) => [nextelement(pmuvariance, k), nextelement(pmuvariance, k + 1)])
                break
            end
            if i == "complete"
                push!(variance, Symbol(:pmu, i) => [nextelement(pmuvariance, k)])
                break
            end
        end
    end

    ########## Legacy variance ##########
    legacyvariance = vec(legacyvariance)
    onebyone = false
    complete = false
    for i in legacyvariance
        if i in ["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"]
            onebyone = true
        end
        if i == "complete"
            complete = true
        end
    end
    if complete && onebyone
        valall = 0.0
        for (k, i) in enumerate(legacyvariance)
            if i == "complete"
                valall = nextelement(legacyvariance, k)
            end
        end
        miss = setdiff(["Pij", "Qij", "Iij", "Pi", "Qi", "Vi"], legacyvariance)
        for i in miss
            legacyvariance = [legacyvariance; i; valall]
        end
    end
    if onebyone
        for i in legacyvariance
            if i in ["Pij", "Qij"] && num.legacyNf != 0
                push!(variance, :legacyFlow => [-100.0, -100.0])
            end
            if i == "Iij" && num.legacyNc != 0
                push!(variance, :legacyCurrent => [-100.0])
            end
            if i in ["Pi", "Qi"] && num.legacyNi != 0
                push!(variance, :legacyInjection => [-100.0, -100.0])
            end
            if i == "Vi" && num.legacyNi != 0
                push!(variance, :legacyVoltage => [-100.0])
            end
        end
        for (k, i) in enumerate(legacyvariance)
            if i == "Pij" && num.legacyNf != 0
                variance[:legacyFlow][1] = nextelement(legacyvariance, k)
            end
            if i == "Qij" && num.legacyNf != 0
                variance[:legacyFlow][2] = nextelement(legacyvariance, k)
            end
            if i == "Iij" && num.legacyNc != 0
                variance[:legacyCurrent] = [nextelement(legacyvariance, k)]
            end
            if i == "Pi" && num.legacyNi != 0
                variance[:legacyInjection][1] = nextelement(legacyvariance, k)
            end
            if i == "Qi" && num.legacyNi != 0
                variance[:legacyInjection][2] = nextelement(legacyvariance, k)
            end
            if i == "Vi" && num.legacyNv != 0
                variance[:legacyVoltage] = [nextelement(legacyvariance, k)]
            end
        end
    end
    if !onebyone  && any([num.legacyNf, num.legacyNc, num.legacyNi, num.legacyNv] .!= 0)
        for (k, i) in enumerate(legacyvariance)
            if i == "random"
                push!(variance, Symbol(:legacy, i) =>  [nextelement(legacyvariance, k), nextelement(legacyvariance, k + 1)])
                break
            end
            if i == "complete"
                push!(variance, Symbol(:legacy, i) => [nextelement(legacyvariance, k)])
                break
            end
        end
    end

    return GeneratorSettings(runflow, set, variance, save)
end

### Load state estimation data from generator or input data
function loadse(args)
    data = true
    for i in args
        if typeof(i) == Tuple{Measurements, PowerSystem, Array{String,2}}
            data = false
            break
        end
    end

    return data
end


### State estimation settings
@inbounds function sesettings(args, system, max, stop, start, badset, lavset, observeset, covariance, solve, save)
    algorithm = "false"
    main = false; flow = false; estimate = false; error = false
    lavkey = 0.0; badkey = 0.0; observekey = 0.0

    for i in args
        if i in ["dc", "nonlinear", "pmu"]
            algorithm = i
        end
        if i == "lav"
            lavkey = 1.0
        end
        if i == "bad"
            badkey = 1.0
        end
        if i == "observe"
            observekey = 1.0
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
        println("Invalid state estimation METHOD key. The algorithm proceeds with the nonlinear state estimation.")
    end

    threshold = 3.0; pass = 1.0; critical = 1e-10
    if !isempty(badset)
        badkey = 1.0
        for (k, i) in enumerate(badset)
            if i == "threshold"
                threshold = nextelement(badset, k)
            end
            if i == "pass"
                pass = nextelement(badset, k)
            end
            if i == "critical"
                critical = nextelement(badset, k)
            end
        end
    end
    bad = Dict(:bad => badkey, :treshold => threshold, :pass => pass, :critical => critical)

    optimize = 1.0
    if !isempty(lavset)
        lavkey = 1.0
        for i in lavset
            if i == "Ipopt"
                optimize = 2.0
            end
        end
    end
    lav = Dict(:lav => lavkey, :optimize => optimize)

    islands = 1; flow = 0; islandMax = 2000; islandBreak = 10; islandStopping = 1.0; islandTreshold = 1e5
    restoreMax = 100; pivot = 1e-10; restore = 1; Pij = 0.0; Pi = 0.0; Ti = 0.0
    if !isempty(observeset)
        observekey = 1.0
        for (k, i) in enumerate(observeset)
            if i == "islandBP"
                islands = 2
            end
            if i == "flow"
                flow = 1
            end
            if i == "islandMax"
                islandMax = trunc(Int64, nextelement(observeset, k))
            end
            if i == "islandBreak"
                islandBreak = trunc(Int64, nextelement(observeset, k))
            end
            if i == "islandStopping"
                islandStopping = nextelement(observeset, k)
            end
            if i == "islandTreshold"
                islandTreshold = nextelement(observeset, k)
            end
            if i == "restoreBP"
                restore = 2
            end
            if i == "restoreMax"
                restoreMax = trunc(Int64, nextelement(observeset, k))
            end
            if i == "pivot"
                pivot = nextelement(observeset, k)
            end
            if i == "Pij"
                Pij = nextelement(observeset, k)
            end
            if i == "Pi"
                Pi = nextelement(observeset, k)
            end
            if i == "Ti"
                Ti = nextelement(observeset, k)
            end
        end
    end
    if Pij == 0.0 && Pi == 0.0 && Ti == 0.0
        Pi = 1e5
    end
    if flow == 1
        islands = 3
    end

    observe = Dict(:observe => observekey,
                   :islands => islands, :islandMax => islandMax, :islandBreak => islandBreak, :islandStopping => islandStopping,  :islandTreshold => islandTreshold,
                   :restore => restore, :restoreMax => restoreMax, :pivot => pivot, :Pij => Pij, :Pi => Pi, :Ti => Ti)

    covarinace = false
    if algorithm == "pmu" && covariance == 1
        covarinace = true
    end


    saveextension = ""
    if !isempty(save)
        path = dirname(save)
        data = basename(save)
        if isempty(data)
            dataname = (join(replace(split(system.dataname, ""), "."=>"")))
            data = string(dataname, "_results", system.extension)
        end
        saveextension = string(match(r"\.[A-Za-z0-9]+$", data).match)
        save = joinpath(path, data)
    end

    return EstimationSettings(algorithm, main, flow, estimate, error, max, stop,
        start, bad, lav, observe, covarinace, solve, save, saveextension)
end


### Load state estimation data from measurement generator
function loadsedirect(args)
    idx = 0
    for (k, i) in enumerate(args)
        if typeof(i) == Tuple{Measurements, PowerSystem, Array{String,2}}
            idx = k
            break
        end
    end
    measurements::Measurements, system::PowerSystem, info::Array{String,2} = args[idx]

    pmuNv = size(measurements.pmuVoltage, 1)
    if pmuNv == 1 && measurements.pmuVoltage[1, 1] == 0
        pmuNv = 0
    end
    pmuNc = size(measurements.pmuCurrent, 1)
    if pmuNc == 1 && measurements.pmuCurrent[1, 1] == 0
        pmuNc = 0
    end
    legacyNf = size(measurements.legacyFlow, 1)
    if legacyNf == 1 && measurements.legacyFlow[1, 1] == 0
        legacyNf = 0
    end
    legacyNc = size(measurements.legacyCurrent, 1)
    if legacyNc == 1 && measurements.legacyCurrent[1, 1] == 0
        legacyNc = 0
    end
    legacyNi = size(measurements.legacyInjection, 1)
    if legacyNi == 1 && measurements.legacyInjection[1, 1] == 0
        legacyNi = 0
    end
    legacyNv = size(measurements.legacyVoltage, 1)
    if legacyNv == 1 && measurements.legacyVoltage[1, 1] == 0
        legacyNv = 0
    end
    Nbus = size(system.bus, 1)
    Nbranch = size(system.branch, 1)
    Ngen = size(system.generator, 1)
    if Ngen == 1 && system.generator[1, 1] == 0
        Ngen = 0
    end

    return system, PowerSystemNum(Nbus, Nbranch, Ngen),
        measurements, MeasurementsNum(pmuNv, pmuNc, legacyNf, legacyNc, legacyNi, legacyNv), info
end
