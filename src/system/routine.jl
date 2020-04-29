###############
#  Numbering  #
###############
function renumber(change, Nchange, old, new, Noldnew, numbering)
    change = trunc.(Int, change)

    if numbering
        @inbounds for i = 1:Nchange
            for j = 1:Noldnew
                if change[i] == old[j]
                    change[i] = new[j]
                    break
                end
            end
        end
    end

    return change
end


#######################################
#  Save data in h5-file or xlsx-file  #
#######################################
function savedata(args; group, header, path, info = "", label = Dict())
    extension = match(r"\.[A-Za-z0-9]+$", path).match

    if extension == ".h5"
        h5open(path, "w") do file
            for i in group
                write(file, i, args[i])
                try
                    atr = Dict(string("row", k) => string(header[i][1, k], ": ", header[i][2, k]) for k = 1:size(header[i], 2))
                    if haskey(label, i)
                        atr1 = Dict(string("column", k) => label[i][k] for k = 1:size(label[i], 1))
                        merge!(atr, atr1)
                    end
                    h5writeattr(path, i, atr)
                catch
                end
            end
            if !isempty(info)
                write(file, "info", info)
            end
        end
        println("Data is successfully exported to $path")
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
        println("Data is successfully exported to $path")
    else
        throw(ErrorException("the SAVE data format is not supported"))
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


###################################
#  Weighted least-squares method  #
###################################
function wls(A, G, H, W, b, method)
    r = W * b
    if method == "lu"
        F = lu(G)
        x = F.U \  (F.L \ ((F.Rs .* (transpose(H) * r))[F.p]))
        x = x[sortperm(F.q)]
    else
        x = G \ (transpose(H) * r)
    end

    return x
end


##########################
#  Least-squares method  #
##########################
function ls(A, b, method)
    if method == "lu"
        F = lu(A)
        x = F.U \  (F.L \ ((F.Rs .* b)[F.p]))
        x = x[sortperm(F.q)]
    else
        x = A \ b
    end

    return x
end


##################################
#  Least absolute value method  #
##################################
function lav(A, b, Nvar, Nequ, settings)
    c = [zeros(2 * Nvar); ones(2 * Nequ)]
    E = spdiagm(0 => ones(Nequ))
    Aeq = [A -A E -E]
    lb = zeros(2 * (Nvar + Nequ))

    if settings.lavoptimize == "Ipopt"
        model = Model(Ipopt.Optimizer)
    else
        model = Model(GLPK.Optimizer)
    end

    @variable(model, x[i = 1:(2 * (Nvar + Nequ))])
    @constraint(model, lb .<= x)
    if settings.lavconstraint == "equality"
        @constraint(model, Aeq * x .== b)
    else
        @constraint(model, Aeq * x .<= b)
    end
    @objective(model, Min, sum(x))
    optimize!(model)
    println("Least Aabsolute value state estimation status: $(JuMP.termination_status(model))")

    return JuMP.value.(x)
end


###########################
#  Try-catch next element #
###########################
function nextelement(set, current)
    value = 0
    try
        value = set[current + 1]
    catch
        throw(ErrorException("the name-value pair setting is missing"))
    end

    return value
end


####################
#  Data Structure  #
####################
function datastruct(data, max; var = "")
    Nrow, Ncol = size(data)
    if Ncol < max
        throw(DomainError(var, "dimension mismatch"))
    end

    return Nrow
end


##############################################################
#  The sparse inverse subset of a real sparse square matrix  #
#  Copyright (c) 2014, Tim Davis                             #
#  Adopt the function SPARSEINV for Julia                    #
##############################################################
function sparseinv(A)

end
