######################
#  General Routines  #
######################


#-------------------------------------------------------------------------------
function numbering_generator(geni, busi, Nbus, bus, numbering)
    gen_bus = trunc.(Int, geni)

    if numbering
        println("  The new bus numbering is run.")
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
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function savedata(ARGS...; group, header1, header2, path, info = "")
    extension = match(r"\.[A-Za-z0-9]+$", path).match

    if extension == ".h5"
        h5open(path, "w") do file
            for i = 1:length(ARGS)
                write(file, group[i], ARGS[i])
                try
                    atr = Dict(string("row", k) => if !isempty(header2[i][k]) string(s, ": ", header2[i][k]) else s end for (k, s) in enumerate(header1[i]))
                    h5writeattr(path, group[i], atr)
                catch
                end
            end
            if !isempty(info)
                write(file, "info", info)
            end
        end
        println(string("  Data is successfully exported to ", path))
    elseif extension == ".xlsx"
        XLSX.openxlsx(path, mode="w") do xf
            sheet = xf[1]
            XLSX.rename!(sheet, group[1])
            sheet["A1"] = header1[1]
            sheet["A2"] = header2[1]
            sheet["A3"] = ARGS[1]
            for i = 2:length(ARGS)
                XLSX.addsheet!(xf, group[i])
                sheet = xf[i]
                sheet["A1"] = header1[i]
                sheet["A2"] = header2[i]
                sheet["A3"] = ARGS[i]
            end
            if !isempty(info)
                XLSX.addsheet!(xf, "info")
                sheet = xf[length(ARGS) + 1]
                sheet["A1"] = info
            end
        end
        println(string("  Data is successfully exported to ", path))
    else
        error("  The save data format is not supported.")
    end
end
#-------------------------------------------------------------------------------
