##########################
#  Numbering generators  #
##########################
function numbering_generator(geni, busi, Nbus, bus, numbering)
    gen_bus = trunc.(Int, geni)

    if numbering
        println("The new bus numbering is running.")
        @inbounds for i = 1:length(gen_bus)
            for j = 1:Nbus
                if gen_bus[i] == busi[j]
                    gen_bus[i] = bus[j]
                    break
                end
            end
        end
    end

    return gen_bus
end


########################
#  Numbering branches  #
########################
function numbering_branch(fromi, toi, busi, Nbranch, Nbus, bus, numbering)
    from = trunc.(Int, fromi)
    to = trunc.(Int, toi)

    if numbering
        @inbounds for i = 1:Nbranch
            for j = 1:Nbus
                if from[i] == busi[j]
                    from[i] = bus[j]
                    break
                end
            end
        end
        @inbounds for i = 1:Nbranch
            for j = 1:Nbus
                if to[i] == busi[j]
                    to[i] = bus[j]
                    break
                end
            end
        end
    end

    return from, to
end


#######################################
#  Save data in h5-file or xlsx-file  #
#######################################
function savedata(args; group, header, path, info = "")
    extension = match(r"\.[A-Za-z0-9]+$", path).match

    if extension == ".h5"
        h5open(path, "w") do file
            for i in group
                write(file, i, args[i])
                try
                    Nhead = size(header[i], 2)
                    atr = Dict(string("row", k) =>  string(header[i][1, k], ": ", header[i][2, k]) for k = 1:Nhead)
                    h5writeattr(path, i, atr)
                catch
                end
            end
            if !isempty(info)
                write(file, "info", info)
            end
        end
        println(string("Data is successfully exported to ", path))
    elseif extension == ".xlsx"
        XLSX.openxlsx(path, mode="w") do xf
            for (k, i) in enumerate(group)
                if k == 1
                    sheet = xf[k]
                    XLSX.rename!(sheet, i)
                else
                    XLSX.addsheet!(xf, i)
                    sheet = xf[k]
                end
                sheet["A1"] = header[i][:, 1:size(args[i], 2)]
                sheet["A3"] = args[i]
            end
            if !isempty(info)
                XLSX.addsheet!(xf, "info")
                sheet = xf[length(group) + 1]
                sheet["A1"] = info
            end
        end
        println(string("Data is successfully exported to ", path))
    else
        error("The SAVE data format is not supported.")
    end

end


########################################
#  Read data from h5-file or xlsx-file #
########################################
function readdata(fullpath, extension, type)
    read_data = Dict()

    if type == "power system"
        sheet = ["bus", "branch", "generator", "basePower", "info"]
    end
    if type == "measurements"
        sheet = ["pmuVoltage", "pmuCurrent", "legacyFlow", "legacyCurrent", "legacyInjection", "legacyVoltage"]
    end

    if extension == ".h5"
        fid = h5open(fullpath, "r")
        for i in sheet
            if exists(fid, i)
                table = h5read(fullpath, string("/", i))
                push!(read_data, i => table)
            end
        end
        close(fid)
    end

    if extension == ".xlsx"
        start = 1
        xf = XLSX.readxlsx(fullpath)
        orginal = XLSX.sheetnames(xf)
        for i in sheet
            if i in orginal
                sh = xf[i]
                table = sh[:]
                for r in XLSX.eachrow(sh)
                    if !isa(r[1], String) && i != "info"
                        start = XLSX.row_number(r)
                        break
                    end
                end
                if i != "info"
                    push!(read_data, i => Float64.(table[start:end, :]))
                else
                    push!(read_data, i => string.(coalesce.(table, "")))
                end
            end
        end
    end

    return read_data
end


###########################
#  Try-catch next element #
###########################
function nextelement(set, current)
    value = 0
    try
        value = set[current + 1]
    catch
        error("The name-value pair setting is missing.")
    end

    return value
end


####################
#  Data Structure  #
####################
function datastruct(data, max; var = "")
    Nrow, Ncol = size(data)
    if Ncol < max
        error(string("Invalid DATA structure, variable " , var, " has incorrect dimension."))
    end

    return Nrow
end
