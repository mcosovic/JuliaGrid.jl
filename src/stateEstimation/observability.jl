function island(system::PowerSystem, device::Wattmeter)
    observe = Observability([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Int64[]))
    bus = system.bus
    branch = system.branch
    model = system.model

    if isempty(model.dc.nodalMatrix) && isempty(model.ac.nodalMatrix)
        dcModel!(system) 
    end

    if !isempty(model.dc.nodalMatrix)
        dropzeros!(model.dc.nodalMatrix)
        rowval = model.dc.nodalMatrix.rowval
        colptr = model.dc.nodalMatrix.colptr
    else
        dropzeros!(model.ac.nodalMatrix)
        rowval = model.ac.nodalMatrix.rowval
        colptr = model.ac.nodalMatrix.colptr
    end

    nonZeroElement = 0 
    @inbounds for i = 1:device.number
        if !device.layout.bus[i] && device.active.status[i] == 1 && branch.layout.status[device.layout.index[i]] == 1
            nonZeroElement += 4 
        end
    end

    row = fill(0, nonZeroElement) 
    col = similar(row)
    index = 0
    @inbounds for (i, k) in enumerate(device.layout.index)
        if !device.layout.bus[i] && device.active.status[i] == 1 && branch.layout.status[k] == 1
            row[index + 1] = branch.layout.from[k]
            row[index + 2] = branch.layout.from[k]
            row[index + 3] = branch.layout.to[k]
            row[index + 4] = branch.layout.to[k]

            col[index + 1] = branch.layout.to[k]
            col[index + 2] = branch.layout.from[k]
            col[index + 3] = branch.layout.from[k]
            col[index + 4] = branch.layout.to[k]

            index += 4
        end
    end
    gainFlow = sparse(row, col, fill(1, nonZeroElement), bus.number, bus.number)

    observe.bus = fill(0, bus.number)
    queue = Array{Int64,1}() 
    n = copy(bus.number)
    comp = 0
    @inbounds for i = 1:n
        if observe.bus[i] == 0
            comp += 1
            push!(queue, i)
            while !isempty(queue)
                v = pop!(queue)
                observe.bus[v] = comp
                for index in nzrange(gainFlow, v)
                    n = gainFlow.rowval[index]
                    if observe.bus[n] == 0
                        push!(queue, n)
                    end
                end
            end
        end
    end

    observe.island = [Array{Int64,1}()  for i = 1:comp]
    @inbounds for (k, i) in enumerate(observe.bus)
        push!(observe.island[i], k)
    end

    observe.tie.bus = Set{Int64}()
    observe.tie.branch = Set{Int64}()
    @inbounds for i = 1:branch.number
        if observe.bus[branch.layout.from[i]] != observe.bus[branch.layout.to[i]]
            push!(observe.tie.branch, i)
            push!(observe.tie.bus, branch.layout.from[i])
            push!(observe.tie.bus, branch.layout.to[i])
        end
    end

    observe.tie.injection = Array{Int64,1}()
    @inbounds for i = 1:device.number
        if device.layout.bus[i] && device.active.status[i] == 1 && (device.layout.index[i] in observe.tie.bus)
            push!(observe.tie.injection, i)
        end
    end

    mergePairs(bus, device.layout, observe, rowval, colptr)

    merge = 1 
    @inbounds while merge != 0
        con = fill(false, bus.number)
        incidentToIslands = fill(Int64[], length(observe.tie.injection), 1)

        for (k, i) in enumerate(observe.tie.injection)
            busIndex = device.layout.index[i]
            conection = rowval[colptr[busIndex]:(colptr[busIndex + 1] - 1)]
        
            con[conection] .= true
            incidentToIslands[k] = sort(unique(observe.bus[con]))
            con[conection] .= false
        end

        mergeIndex = decisionTree(incidentToIslands)
        removeIsland = fill(false, size(observe.island, 1))
        if mergeIndex != false
            mergeIslands = Int64[]
            for i in mergeIndex
                for j in incidentToIslands[i]
                    push!(mergeIslands, j)
                end
            end

            mergeIslands = unique(mergeIslands)
            start = mergeIslands[1]
            for i = 2:lastindex(mergeIslands)
                next = mergeIslands[i]
                append!(observe.island[start], observe.island[next])
                removeIsland[next] = 1
            end
            deleteat!(observe.island, removeIsland)
        else
            break
        end
   
        for (k, island) in enumerate(observe.island)
            for i in island
                observe.bus[i] = k
            end
        end

        removeInjection = Int64[]
        for (k, i) in enumerate(observe.tie.injection)
            busIndex = device.layout.index[i]
            conection = rowval[colptr[busIndex]:(colptr[busIndex + 1] - 1)]
        
            con[conection] .= true
            if length(Set(observe.bus[con])) == 1
                push!(removeInjection, k)
            end
            con[conection] .= false
        end
        deleteat!(observe.tie.injection, removeInjection)

        mergePairs(bus, device.layout, observe, rowval, colptr)
    end
    
    observe.tie.bus = Set{Int64}()
    if size(observe.island, 1) > 1
        @inbounds for (k, i) in enumerate(observe.tie.branch)
            if observe.bus[branch.layout.from[i]] == observe.bus[branch.layout.to[i]]
                delete!(observe.tie.branch, i)
            else
                push!(observe.tie.bus, branch.layout.from[i])
                push!(observe.tie.bus, branch.layout.to[i])
            end
        end
    else
        observe.tie.branch = Set{Int64}()
    end

    return observe
end

function mergePairs(bus::Bus, layout::MultiLayoutMeter, observe::Observability, rowval::Array{Int64,1}, colptr::Array{Int64,1})
    merge = true
    flag = false
    con = fill(false, bus.number)
    removeIsland = fill(false, size(observe.island, 1))
    @inbounds while merge 
        merge = false
        for (k, i) in enumerate(observe.tie.injection)
            busIndex = layout.index[i]
            island = observe.bus[busIndex]
            conection = rowval[colptr[busIndex]:(colptr[busIndex + 1] - 1)]
    
            con[conection] .= true
            con[observe.island[island]] .= false
            incidentToIslands = Set(observe.bus[con])
            con[conection] .= false
            
            if length(incidentToIslands) == 1 || length(incidentToIslands) == 0
                if length(incidentToIslands) == 1
                    index = collect(incidentToIslands)[1]
                
                    append!(observe.island[island], observe.island[index])
                    observe.bus[observe.island[index]] .= island

                    removeIsland[index] = true
                    flag = true
                end
                deleteat!(observe.tie.injection, k) 
                merge = true
            end
        end
        if !merge || size(observe.island, 1) == 1
            break
        end
    end
    deleteat!(observe.island, removeIsland)
    
    if flag && size(observe.island, 1) != 1
        @inbounds for (k, island) in enumerate(observe.island)
            for i in island
                observe.bus[i] = k
            end
        end
    end
end

function decisionTree(measurments::Matrix{Vector{Int64}})
    totalIslands = 0
    for measurment in measurments
        for island in measurment
            totalIslands = max(totalIslands, island)
        end
    end

    for t = 2:length(measurments)
        totalCombinations = combinations(length(measurments), t)
        for combination in totalCombinations
            if check(measurments, combination, totalIslands , t + 1)
                return combination
            end
        end
    end

    return false
end

function combinationsRecursive(position, value, result, max_n, k, accumulator)
    for i = value:max_n
        result[position] = position + i
        if position < k
            combinationsRecursive(position + 1, i, result, max_n, k, accumulator)
        else
            push!(accumulator, copy(result))
        end
    end
end

function combinations(n, k)
    max_n = n - k
    accumulator = Array{Array{Int64,1},1}()
    result = zeros(Int64, k)
    combinationsRecursive(1, 0, result, max_n, k, accumulator)

    return accumulator
end

function check(measurments, indicies, total, required)
    appeared = zeros(Bool, total)
    for index in indicies
        for island in measurments[index]
            appeared[island] = true
        end
    end

    return sum(appeared) == required
end

function restoration!(system::PowerSystem, device::Measurement, pseudo::Measurement, islands::Observability, threshold::N)
    dc = system.model.dc
    bus = system.bus
    branch = system.branch
    wattmeter = device.wattmeter
    pmu = device.pmu

    row = Array{Int64,1}()
    col = Array{Int64,1}()
    jac = Array{Float64,1}()
    con = fill(false, bus.number)
    for (k, i) in enumerate(islands.tie.injection)
        busIndex = wattmeter.layout.index[i]
        row, col, jac, con = addTieInjection(dc, islands, busIndex, k, con, row, col, jac)
    end

    rowIndex = length(islands.tie.injection)
    pmuIsland = Set{Int64}()
    for i = 1:device.pmu.number
        if device.pmu.layout.bus[i] && device.pmu.angle.status[i] == 1
            busIndex = device.pmu.layout.index[i]
            island = islands.bus[busIndex]

            rowIndex += 1
            push!(row, rowIndex)
            push!(col, island)
            push!(jac, 1)
            push!(pmuIsland, island)
        end
    end

    rowIndex += 1
    push!(row, rowIndex)
    push!(col, islands.bus[system.bus.layout.slack])
    push!(jac, 1)
    push!(pmuIsland, islands.bus[system.bus.layout.slack])
    
    numberTie = copy(rowIndex)
  
    pseudoDevice = Int64[]
    for (k, index) in enumerate(pseudo.wattmeter.layout.index)
        if pseudo.wattmeter.active.status[k] == 1
            if pseudo.wattmeter.layout.bus[k] 
                if index in islands.tie.bus
                    rowIndex += 1 
                    row, col, jac, con = addTieInjection(dc, islands, index, rowIndex, con, row, col, jac)
                    push!(pseudoDevice, k)
                end
            else
                if index in islands.tie.branch && branch.layout.status[index] == 1
                    fromIsland = islands.bus[branch.layout.from[index]]
                    toIsland = islands.bus[branch.layout.to[index]]

                    rowIndex += 1 
                    push!(row, rowIndex)
                    push!(col, fromIsland)
                    push!(jac, 1)
                    push!(row, rowIndex)
                    push!(col, toIsland)
                    push!(jac, -1)

                    push!(pseudoDevice, k)
                end
            end
        end
    end
    numberPseudoWattmeter = length(pseudoDevice)

    for i = 1:pseudo.pmu.number
        if pseudo.pmu.layout.bus[i] && pseudo.pmu.angle.status[i] == 1
            busIndex = pseudo.pmu.layout.index[i]
            island = islands.bus[busIndex]

            rowIndex += 1
            push!(row, rowIndex)
            push!(col, island)
            push!(jac, 1)

            push!(pseudoDevice, i)
        end
    end
    numberIsland = size(islands.island, 1)
    reducedJacobian = sparse(row, col, jac, row[end], numberIsland)
    reducedGain = reducedJacobian * reducedJacobian'

    F = qr(Matrix(reducedGain))
    R = F.R
    @inbounds for (k, i) = enumerate((numberTie + 1):rowIndex)
        if abs(R[i, i]) > threshold
            if k <= numberPseudoWattmeter
                indexDevice = pseudoDevice[k]
                indexBusBranch = pseudo.wattmeter.layout.index[indexDevice]
                (labelWattmeter,_),_ = iterate(pseudo.wattmeter.label, indexDevice)
                if pseudo.wattmeter.layout.bus[indexDevice]
                    (labelBus,_),_ = iterate(system.bus.label, indexBusBranch)
                    addWattmeter!(system, device; bus = labelBus, label = labelWattmeter, noise = false,
                        active = pseudo.wattmeter.active.mean[indexDevice], variance = pseudo.wattmeter.active.variance[indexDevice])
                else
                    (labelBranch,_),_ = iterate(system.branch.label, indexBusBranch)
                    if pseudo.wattmeter.layout.from[indexDevice]
                        addWattmeter!(system, device; from = labelBranch, label = labelWattmeter, noise = false,
                            active = pseudo.wattmeter.active.mean[indexDevice], variance = pseudo.wattmeter.active.variance[indexDevice])
                    else
                        addWattmeter!(system, device; to = labelBranch, label = labelWattmeter, noise = false,
                            active = pseudo.wattmeter.active.mean[indexDevice], variance = pseudo.wattmeter.active.variance[indexDevice])
                    end
                end 
            else
                indexDevice = pseudoDevice[k]  
                indexBus = pseudo.pmu.layout.index[indexDevice]
                (labelPmu,_),_ = iterate(pseudo.pmu.label, indexDevice)
                (labelBus,_),_ = iterate(system.bus.label, indexBus)
                addPmu!(system, device; bus = labelBus, label = labelPmu, noise = false,
                    magnitude = pseudo.pmu.magnitude.mean[indexDevice], varianceMagnitude = pseudo.pmu.magnitude.variance[indexDevice],
                    angle = pseudo.pmu.angle.mean[indexDevice], varianceAngle = pseudo.pmu.angle.variance[indexDevice])
            end
        end
    end
end

function addTieInjection(dc, islands, busIndex, k, con, row, col, jac)
    island = islands.bus[busIndex]
    conection = dc.nodalMatrix.rowval[dc.nodalMatrix.colptr[busIndex]:(dc.nodalMatrix.colptr[busIndex + 1] - 1)]
        
    con[conection] .= true
    con[islands.island[island]] .= false
    incidentToIslands = islands.bus[con]
    for i in incidentToIslands
        push!(row, k)
        push!(col, i)
        push!(jac, -1)
    end
    push!(row, k)
    push!(col, island)
    push!(jac, length(incidentToIslands))
    con[conection] .= false

    return row, col, jac, con
end