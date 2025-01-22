"""
    islandTopologicalFlow(system::PowerSystem, device::Measurement)

The function utilizes a topological approach to detect flow observable islands, resulting
in the formation of disconnected and loop-free subgraphs. It is assumed that active and
reactive power measurements are paired, indicating a standard observability analysis. In
this analysis, islands formed by active power measurements correspond to those formed by
reactive power measurements.

# Arguments
To define flow observable islands, this function necessitates the composite types
`PowerSystem` and `Measurement`.

# Returns
The function returns an `Island` type, containing information about the islands:
* `island`: List enumerating observable islands with indices of buses.
* `bus`: Positions of buses in relation to each island.
* `tie`: Tie data associated with buses and branches.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

statusWattmeter!(system, device; inservice = 15)
device.varmeter.reactive.status = copy(device.wattmeter.active.status)

islands = islandTopologicalFlow(system, device)
```
"""
function islandTopologicalFlow(system::PowerSystem, device::Measurement)
    observe = Island([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Set{Int64}()))
    rowval, colptr = connectionObservability(system)

    connectedComponents(system, observe, device.wattmeter)
    tieBusBranch(system, observe)
    tieInjection(observe, device.wattmeter)

    mergePairs(system.bus, observe, rowval, colptr)
    tieBusBranch(system, observe)

    return observe
end

"""
    islandTopological(system::PowerSystem, meter::Measurement)

The function employs a topological method to identify maximal observable islands.
Specifically, it employs active power measurements to pinpoint flow observable islands.
Subsequently, these islands are merged based on the available injection measurements.

It is assumed that active and reactive power measurements are paired, indicating a
standard observability analysis. In this analysis, islands formed by active power
measurements correspond to those formed by reactive power measurements.

# Arguments
To define flow observable islands, this function necessitates the composite types
`PowerSystem` and `Measurement`.

# Returns
The function returns an `Island` type, containing information about the islands:
* `island`: List enumerating observable islands with indices of buses.
* `bus`: Positions of buses in relation to each island.
* `tie`: Tie data associated with buses and branches.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

statusWattmeter!(system, device; inservice = 15)
device.varmeter.reactive.status = copy(device.wattmeter.active.status)

islands = islandTopological(system, device)
```
"""
function islandTopological(system::PowerSystem, device::Measurement)
    observe = Island([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Set{Int64}()))
    rowval, colptr = connectionObservability(system)

    connectedComponents(system, observe, device.wattmeter)
    tieBusBranch(system, observe)
    tieInjection(observe, device.wattmeter)

    mergePairs(system.bus, observe, rowval, colptr)
    mergeFlowIslands(system, observe, rowval, colptr)

    return observe
end

function connectedComponents(system::PowerSystem, observe::Island, watt::Wattmeter)
    bus = system.bus
    branch = system.branch

    nnzElement = 0
    @inbounds for (i, k) in enumerate(watt.layout.index)
        if !watt.layout.bus[i]
            if watt.active.status[i] == 1 && branch.layout.status[k] == 1
                nnzElement += 4
            end
        end
    end

    row = fill(0, nnzElement)
    col = similar(row)
    idx = 0
    @inbounds for (i, k) in enumerate(watt.layout.index)
        if !watt.layout.bus[i]
            if watt.active.status[i] == 1 && branch.layout.status[k] == 1
                row[idx + 1] = row[idx + 2] = branch.layout.from[k]
                row[idx + 3] = row[idx + 4] = branch.layout.to[k]

                col[idx + 1] = col[idx + 4] = branch.layout.to[k]
                col[idx + 2] = col[idx + 3] = branch.layout.from[k]

                idx += 4
            end
        end
    end
    gainFlow = sparse(row, col, fill(1, nnzElement), bus.number, bus.number)

    observe.bus = fill(0, bus.number)
    queue = Vector{Int64}()
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

    observe.island = [Vector{Int64}()  for i = 1:comp]
    @inbounds for (k, i) in enumerate(observe.bus)
        push!(observe.island[i], k)
    end
end

function tieBusBranch(system::PowerSystem, observe::Island)
    branch = system.branch

    observe.tie.bus = Set{Int64}()
    observe.tie.branch = Set{Int64}()
    @inbounds for i = 1:branch.number
        if observe.bus[branch.layout.from[i]] != observe.bus[branch.layout.to[i]]
            push!(observe.tie.branch, i)
            push!(observe.tie.bus, branch.layout.from[i])
            push!(observe.tie.bus, branch.layout.to[i])
        end
    end
end

function tieInjection(observe::Island, watt::Wattmeter)
    observe.tie.injection = Set{Int64}()

    @inbounds for (i, k) in enumerate(watt.layout.index)
        if watt.layout.bus[i] && watt.active.status[i] == 1 && (k in observe.tie.bus)
            push!(observe.tie.injection, k)
        end
    end
end

function mergePairs(
    bus::Bus,
    observe::Island,
    rowval::Vector{Int64},
    colptr::Vector{Int64}
)
    merge = true
    flag = false
    con = fill(false, bus.number)
    removeIsland = fill(false, size(observe.island, 1))

    @inbounds while merge
        merge = false
        for idxBus in observe.tie.injection
            island = observe.bus[idxBus]
            conection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

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
                delete!(observe.tie.injection, idxBus)
                merge = true
            end
        end
        if !merge || size(observe.island, 1) == 1
            break
        end
    end
    deleteat!(observe.island, removeIsland)

    if flag
        @inbounds for (k, island) in enumerate(observe.island)
            for i in island
                observe.bus[i] = k
            end
        end
    end
end

function mergeFlowIslands(
    system::PowerSystem,
    observe::Island,
    rowval::Vector{Int64},
    colptr::Vector{Int64}
)
    bus = system.bus
    branch = system.branch

    merge = 1
    @inbounds while merge != 0
        con = fill(false, bus.number)
        incidentToIslands = fill(Int64[], length(observe.tie.injection), 1)

        for (k, idxBus) in enumerate(observe.tie.injection)
            conection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

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
        for idxBus in observe.tie.injection

            conection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

            con[conection] .= true
            if length(Set(observe.bus[con])) == 1
                push!(removeInjection, idxBus)
            end
            con[conection] .= false
        end

        for i in removeInjection
            delete!(observe.tie.injection, i)
        end

        mergePairs(bus, observe, rowval, colptr)
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
    @inbounds for measurment in measurments
        for island in measurment
            totalIslands = max(totalIslands, island)
        end
    end

    @inbounds for t = 2:length(measurments)
        totalCombinations = combinations(length(measurments), t)
        for combination in totalCombinations
            if check(measurments, combination, totalIslands , t + 1)
                return combination
            end
        end
    end

    return false
end

function combinationsRecursive(
    position::Int64,
    value::Int64,
    result::Vector{Int64},
    maxN::Int64,
    k::Int64,
    accumulator::Vector{Vector{Int64}}
)
    @inbounds for i = value:maxN
        result[position] = position + i
        if position < k
            combinationsRecursive(position + 1, i, result, maxN, k, accumulator)
        else
            push!(accumulator, copy(result))
        end
    end
end

function combinations(n::Int64, k::Int64)
    maxN = n - k
    accumulator = Vector{Vector{Int64}}()
    result = zeros(Int64, k)
    combinationsRecursive(1, 0, result, maxN, k, accumulator)

    return accumulator
end

function check(
    measurments::Matrix{Vector{Int64}},
    indicies::Vector{Int64},
    total::Int64,
    required::Int64
)
    appeared = zeros(Bool, total)
    @inbounds for index in indicies
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
observability. This method relies on reduced coefficient matrices and the Gram matrix.

It is important to note that the device labels in the `device` and `pseudo` variables must
be different to enable the function to successfully incorporate measurements from `pseudo`
into the `device` set of measurements.

# Keyword
The keyword threshold defines the zero pivot threshold value, with a default value of `1e-5`.
More precisely, all computed pivots less than this value will be treated as zero pivots.

# Updates
The function updates the `device` variable of the `Measurement` composite type.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")
pseudo = measurement("pseudomeasurement14.h5")

statusWattmeter!(system, device; inservice = 10)
islands = islandTopological(system, device)

restorationGram!(system, device, pseudo, islands)
```
"""
function restorationGram!(
    system::PowerSystem,
    device::Measurement,
    pseudo::Measurement,
    islands::Island;
    threshold::Float64 = 1e-5
)
    bus = system.bus
    branch = system.branch

    watt = pseudo.wattmeter
    var = pseudo.varmeter
    pmu = pseudo.pmu

    rowval, colptr = connectionObservability(system)

    jcb = SparseModel(
        Vector{Int64}(),
        Vector{Int64}(),
        Vector{Float64}(),
        0,
        length(islands.tie.injection)
    )
    con = fill(false, bus.number)

    @inbounds for (k, busIndex) in enumerate(islands.tie.injection)
        jcb, con = addTie(rowval, colptr, islands, busIndex, k, jcb, con)
    end

    @inbounds for i = 1:device.pmu.number
        if device.pmu.layout.bus[i]
            if device.pmu.angle.status[i] == 1 && device.pmu.magnitude.status[i] == 1
                island = islands.bus[device.pmu.layout.index[i]]
                pushDirect!(jcb, island)
            end
        end
    end

    island = islands.bus[system.bus.layout.slack]
    pushDirect!(jcb, island)

    numberTie = copy(jcb.idx)

    pseudoDevice = Int64[]
    @inbounds for (k, idx) in enumerate(watt.layout.index)
        if watt.active.status[k] == 1
            if watt.layout.bus[k]
                if idx in islands.tie.bus
                    jcb.idx += 1
                    jcb, con = addTie(rowval, colptr, islands, idx, jcb.idx, jcb, con)
                    push!(pseudoDevice, k)
                end
            else
                if idx in islands.tie.branch && branch.layout.status[idx] == 1
                    fromIsland = islands.bus[branch.layout.from[idx]]
                    toIsland = islands.bus[branch.layout.to[idx]]
                    pushIndirect!(jcb, fromIsland, toIsland)
                    push!(pseudoDevice, k)
                end
            end
        end
    end
    numberPseudoPower = length(pseudoDevice)

    @inbounds for i = 1:pmu.number
        if pmu.layout.bus[i]
            if pmu.angle.status[i] == 1 && pmu.magnitude.status[i] == 1
                island = islands.bus[pmu.layout.index[i]]
                pushDirect!(jcb, island)
                push!(pseudoDevice, i)
            end
        end
    end

    islanNum = size(islands.island, 1)
    reducedCoefficient = sparse(jcb.row, jcb.col, jcb.val, jcb.row[end], islanNum)
    reducedGain = reducedCoefficient * reducedCoefficient'

    F = qr(Matrix(reducedGain))
    R = F.R

    @inbounds for (k, i) = enumerate((numberTie + 1):jcb.idx)
        if abs(R[i, i]) > threshold
            idx = pseudoDevice[k]
            if k <= numberPseudoPower
                indexBusBranch = watt.layout.index[idx]
                (lblWatt, _), _ = iterate(watt.label, idx)
                (lblVar, _), _ = iterate(var.label, idx)

                if watt.layout.bus[idx]
                    (lblBus, _), _ = iterate(system.bus.label, indexBusBranch)

                    addWattmeter!(
                        system, device; bus = lblBus, label = lblWatt,
                        status = 1, active = watt.active.mean[idx],
                        variance = watt.active.variance[idx], noise = false
                    )
                    addVarmeter!(
                        system, device; bus = lblBus, label = lblVar,
                        status = 1, reactive = var.reactive.mean[idx],
                        variance = var.reactive.variance[idx], noise = false
                    )
                else
                    (lblBranch, _), _ = iterate(system.branch.label, indexBusBranch)
                    if watt.layout.from[idx]
                        addWattmeter!(
                            system, device; from = lblBranch, label = lblWatt,
                            status = 1, active = watt.active.mean[idx],
                            variance = watt.active.variance[idx], noise = false
                        )
                        addVarmeter!(
                            system, device; from = lblBranch, label = lblVar,
                            status = 1, reactive = var.reactive.mean[idx],
                            variance = var.reactive.variance[idx], noise = false
                        )
                    else
                        addWattmeter!(
                            system, device; to = lblBranch, label = lblWatt,
                            status = 1, active = watt.active.mean[idx],
                            variance = watt.active.variance[idx], noise = false
                        )
                        addVarmeter!(
                            system, device; to = lblBranch, label = lblVar,
                            status = 1, reactive = var.reactive.mean[idx],
                            variance = var.reactive.variance[idx], noise = false
                        )
                    end
                end
            else
                indexBus = pmu.layout.index[idx]
                (lblPmu, _), _ = iterate(pmu.label, idx)
                (lblBus, _), _ = iterate(system.bus.label, indexBus)

                addPmu!(
                    system, device; bus = lblBus, label = lblPmu, status = 1,
                    magnitude = pmu.magnitude.mean[idx], angle = pmu.angle.mean[idx],
                    varianceMagnitude = pmu.magnitude.variance[idx],
                    varianceAngle = pmu.angle.variance[idx], noise = false
                )
            end
        end
    end
end

function addTie(
    rowval::Vector{Int64},
    colptr::Vector{Int64},
    islands::Island,
    idxBus::Int64,
    k::Int64,
    jcb::SparseModel,
    con::Vector{Bool}
)
    island = islands.bus[idxBus]
    conection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

    con[conection] .= true
    con[islands.island[island]] .= false
    incidentToIslands = islands.bus[con]

    @inbounds for i in incidentToIslands
        push!(jcb.row, k)
        push!(jcb.col, i)
        push!(jcb.val, -1)
    end

    push!(jcb.row, k)
    push!(jcb.col, island)
    push!(jcb.val, length(incidentToIslands))
    con[conection] .= false

    return jcb, con
end

function connectionObservability(system::PowerSystem)
    model = system.model

    if isempty(model.dc.nodalMatrix) && isempty(model.ac.nodalMatrix)
        acModel!(system)
    end

    if !isempty(model.dc.nodalMatrix)
        dropZeros!(model.dc)
        rowval = model.dc.nodalMatrix.rowval
        colptr = model.dc.nodalMatrix.colptr
    else
        dropZeros!(model.ac)
        rowval = model.ac.nodalMatrix.rowval
        colptr = model.ac.nodalMatrix.colptr
    end

    return rowval, colptr
end

function pushDirect!(jcb::SparseModel, island::Int64)
    jcb.idx += 1
    push!(jcb.row, jcb.idx)
    push!(jcb.col, island)
    push!(jcb.val, 1)
end

function pushIndirect!(jcb::SparseModel, fromIsland::Int64, toIsland::Int64)
    jcb.idx += 1
    push!(jcb.row, jcb.idx)
    push!(jcb.col, fromIsland)
    push!(jcb.val, 1)
    push!(jcb.row, jcb.idx)
    push!(jcb.col, toIsland)
    push!(jcb.val, -1)
end