"""
    islandTopologicalFlow(system::PowerSystem, meter::Union{Wattmeter, Varmeter})

The function employs a topological method to identify observable islands solely through 
active power flow measurements from the `Wattmeter` composite type or reactive power flow 
measurements from the `Varmeter` composite type. This results in the formation of 
disconnected and loop-free subgraphs. To be more specific, the function utilizes wattmeters 
or varmeters strategically placed on the branches to detect observable islands. To elaborate 
further, this approach detects islands based on the linear decoupled measurement model.

# Arguments
To define flow observable islands, this function requires the composite types `PowerSystem` 
and either `Wattmeter` or `Varmeter`.

# Returns
The function returns an abstract type `Island`, containing information about the islands:
* `island`: a list enumerating observable islands with indices of buses;
* `bus`: the positions of buses in relation to each island;
* `tie`: tie data associated with buses and branches.
     
# Examples
Find flow islands for the given set of measurement data using wattmeters:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
statusWattmeter!(system, device; inservice = 15)

islands = islandTopologicalFlow(system, device.wattmeter)
```

Find flow islands for the given set of measurement data using varmeters:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
statusVarmeter!(system, device; inservice = 15)

islands = islandTopologicalFlow(system, device.varmeter)
```
"""
function islandTopologicalFlow(system::PowerSystem, wattmeter::Wattmeter)
    observe = IslandWatt([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Int64[]))
    rowval, colptr = connectionObservability(system)

    commponetTie(system, observe, wattmeter)
    mergePairs(system.bus, wattmeter.layout, observe, rowval, colptr)

    return observe 
end

function islandTopologicalFlow(system::PowerSystem, varmeter::Varmeter)
    observe = IslandVar([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Int64[]))
    rowval, colptr = connectionObservability(system)

    commponetTie(system, observe, device.varmeter)
    mergePairs(system.bus, device.varmeter.layout, observe, rowval, colptr)

    return observe 
end

"""
    islandTopological(system::PowerSystem, meter::Union{Wattmeter, Varmeter})

The function employs a topological method to identify maximal observable islands solely 
through active power measurements from the `Wattmeter` composite type or reactive power  
measurements from the `Varmeter` composite type. Specifically, it employs wattmeters or 
varmeters positioned on the branches to pinpoint flow observable islands. Subsequently, 
these islands are merged based on the available injection measurements obtained from the 
wattmeters or varmeters. To elaborate further, this approach detects islands based on the 
linear decoupled measurement model.

# Arguments
To define maximal flow observable islands, this function requires the composite types 
`PowerSystem` and either `Wattmeter` or `Varmeter`.

# Returns
The function returns an abstract type `Island`, containing information about the islands:
* `island`: a list enumerating observable islands with indices of buses;
* `bus`: the positions of buses in relation to each island;
* `tie`: tie data associated with buses and branches.
     
# Examples
Find maximal islands for the given set of measurement data using wattmeters:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
statusWattmeter!(system, device; inservice = 12)

islands = islandTopological(system, device.wattmeter)
```

Find maximal islands for the given set of measurement data using varmeters:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
statusVarmeter!(system, device; inservice = 12)

islands = islandTopological(system, device.varmeter)
```
"""
function islandTopological(system::PowerSystem, wattmeter::Wattmeter)
    observe = IslandWatt([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Int64[]))
    rowval, colptr = connectionObservability(system)

    commponetTie(system, observe, wattmeter)
    mergePairs(system.bus, wattmeter.layout, observe, rowval, colptr)
    mergeFlowIslands(system, wattmeter.layout, observe, rowval, colptr)

    return observe 
end

function commponetTie(system::PowerSystem, observe::Island, device::Wattmeter)
    bus = system.bus
    branch = system.branch

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
end

function mergePairs(bus::Bus, layout::MultiLayoutMeter, observe::Island, rowval::Array{Int64,1}, colptr::Array{Int64,1})
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

function mergeFlowIslands(system::PowerSystem, layout::MultiLayoutMeter, observe::Island, rowval::Array{Int64,1}, colptr::Array{Int64,1})
    bus = system.bus
    branch = system.branch

    merge = 1 
    @inbounds while merge != 0
        con = fill(false, bus.number)
        incidentToIslands = fill(Int64[], length(observe.tie.injection), 1)

        for (k, i) in enumerate(observe.tie.injection)
            busIndex = layout.index[i]
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
            busIndex = layout.index[i]
            conection = rowval[colptr[busIndex]:(colptr[busIndex + 1] - 1)]
        
            con[conection] .= true
            if length(Set(observe.bus[con])) == 1
                push!(removeInjection, k)
            end
            con[conection] .= false
        end
        deleteat!(observe.tie.injection, removeInjection)

        mergePairs(bus, layout, observe, rowval, colptr)
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

"""
    restorationGram!(system::PowerSystem, device::Measurement, pseudo::Measurement, 
        islands::Island; threshold)

Upon identifying the `islands`, the function incorporates measurements from the available 
pseudo-measurements in the `pseudo` variable into the `device` variable to reinstate 
observability. If the abstract type `Island` is derived from wattmeters, candidates for 
restoring observability include active power measurements and bus voltage angle measurements 
from the `pseudo` variable. Conversely, if the abstract type `Island` is derived from 
varmeters, candidates for restoring observability encompass reactive power measurements 
and bus voltage magnitude measurements from the `pseudo` variable. This method relies on 
reduced coefficient matrices and the Gram matrix. 

It is important to note that the device labels in the `device` and `pseudo` variables must 
be different to enable the function to successfully incorporate measurements from `pseudo` 
into the `device` set of measurements.

# Arguments
This function requires the composite types `PowerSystem` and `device`, which holds 
measurements from which the `islands` variable is obtained. To restore observability, the 
function uses measurements from the `pseudo` variable and adds a non-redundant set from it 
to the `device` variable.

# Keyword
The keyword threshold defines the zero pivot threshold value with a default value of `1e-5`. 
More precisely, all computed pivots less than this value will be treated as zero pivots.

# Updates
The function updates the `device` variable of the `Measurement` composite type.

# Example
Restore observability for DC state estimation:
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
statusWattmeter!(system, device; inservice = 10)
statusPmu!(system, device; inservice = 0)

pseudo = measurement("pseudomeasurement14.h5")
islands = islandTopological(system, device.wattmeter)
restorationGram!(system, device, pseudo, islands)

analysis = dcStateEstimation(system, device)
solve!(system, analysis)
```
"""
function restorationGram!(system::PowerSystem, device::Measurement, pseudo::Measurement, islands::IslandWatt; threshold::N = 1e-5)
    bus = system.bus
    branch = system.branch
    wattmeter = device.wattmeter
    rowval, colptr = connectionObservability(system)

    row = Array{Int64,1}()
    col = Array{Int64,1}()
    jac = Array{Float64,1}()
    con = fill(false, bus.number) 
    for (k, i) in enumerate(islands.tie.injection)
        busIndex = wattmeter.layout.index[i]
        row, col, jac, con = addTieInjection(rowval, colptr, islands, busIndex, k, con, row, col, jac)
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
                    row, col, jac, con = addTieInjection(rowval, colptr, islands, index, rowIndex, con, row, col, jac)
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
    reducedCoefficient = sparse(row, col, jac, row[end], numberIsland)
    reducedGain = reducedCoefficient * reducedCoefficient'

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

function addTieInjection(rowval, colptr, islands, busIndex, k, con, row, col, jac)
    island = islands.bus[busIndex]
    conection = rowval[colptr[busIndex]:(colptr[busIndex + 1] - 1)]
        
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

function connectionObservability(system::PowerSystem)
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

    return rowval, colptr
end