### Numbering
@inbounds function renumber(change, Nchange, old, new, Noldnew, numbering)
    if numbering
        for i = 1:Nchange
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


### Save data in h5-file or xlsx-file
@inbounds function savedata(args...; group, header, path, info = "", skip = [])
    extension = match(r"\.[A-Za-z0-9]+$", path).match

    if extension == ".h5"
        h5open(path, "w") do file
            for i in keys(group)
                if group[i] != 0
                    write(file, String(i), getfield(args[group[i]], i))
                    try
                        head = header[i]
                        N = size(getfield(args[group[i]], i), 2)
                        if N == 1
                            N = size(getfield(args[group[i]], i), 1)
                        end
                        atr = Dict(string("row", k) => string(head[1, k], ": ", head[2, k]) for k = 1:N)
                        h5writeattr(path, String(i), atr)
                    catch
                    end
                end
            end
            if !isempty(info)
                write(file, "info", info)
            end
        end
        println("Data is successfully exported to $path")
    elseif extension == ".xlsx"
        k = 1
        XLSX.openxlsx(path, mode = "w") do xf
            for i in keys(group)
                if group[i] != 0
                    if k == 1
                        sheet = xf[k]
                        XLSX.rename!(sheet, String(i))
                    else
                        XLSX.addsheet!(xf, String(i))
                        sheet = xf[k]
                    end
                    N = size(getfield(args[group[i]], i), 2)
                    if N == 1
                        N = size(getfield(args[group[i]], i), 1)
                    end
                    sheet["A1"] = header[i][:, 1:N]
                    sheet["A3"] = getfield(args[group[i]], i)
                    k += 1
                end
            end
            if !isempty(info)
                XLSX.addsheet!(xf, "info")
                sheet = xf[k]
                sheet["A1"] = info
            end
        end
        println("Data is successfully exported to $path")
    else
        throw(ErrorException("the SAVE data format is not supported"))
    end

end


### Start row in xlsx-file
function startxlsx(xf)
    start = 1
    for r in XLSX.eachrow(xf)
        if !isa(r[1], String)
            start = XLSX.row_number(r)
            break
        end
    end
    return start
end


### Weighted least-squares method
@inbounds function wls(A, G, H, W, b, method)
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


### Least-squares method
@inbounds function ls(A, b, method)
    if method == "lu"
        F = lu(A)
        x = F.U \  (F.L \ ((F.Rs .* b)[F.p]))
        x = x[sortperm(F.q)]
    else
        x = A \ b
    end

    return x
end


### Least absolute value method
@inbounds function lav(A, b, Nvar, Nequ, settings)
    c = [zeros(2 * Nvar); ones(2 * Nequ)]
    E = spdiagm(0 => ones(Nequ))
    Aeq = [A -A E -E]
    lb = zeros(2 * (Nvar + Nequ))

    if settings.lav[:optimize] == 2
        model = Model(Ipopt.Optimizer)
    else
        model = Model(GLPK.Optimizer)
    end

    @variable(model, x[i = 1:(2 * (Nvar + Nequ))])
    @constraint(model, lb .<= x)
    if settings.lav[:constraint] == 2
        @constraint(model, Aeq * x .<= b)
    else
        @constraint(model, Aeq * x .== b)
    end
    @objective(model, Min, sum(x))
    optimize!(model)
    println("Least Aabsolute value state estimation status: $(JuMP.termination_status(model))")

    return JuMP.value.(x)
end


### Try-catch next element
function nextelement(set, current)
    value = 0.0
    try
        value = set[current + 1]
        if value == "all"
            value = -200.0
        end
        value = Float64(value)
    catch
        throw(ErrorException("the name-value pair setting is missing"))
    end

    return value
end


### Data structure
function datastruct(data, max; var = "")
    Nrow, Ncol = size(data)
    if Ncol < max
        throw(DomainError(var, "dimension mismatch"))
    end

    return Nrow
end


### The sparse inverse subset of a real sparse square matrix
# Copyright (c) 2014, Tim Davis
# Adopt the function SPARSEINV for Julia
function sparseinv(A)

end
