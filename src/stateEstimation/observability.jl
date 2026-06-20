"""
    islandTopologicalFlow(monitoring::Measurement)

The function utilizes a topological approach to detect flow-observable islands, resulting in the
formation of disconnected and loop-free subgraphs. It is assumed that active and reactive power
measurements are paired, indicating a standard observability analysis. In this analysis, islands
formed by active power measurements correspond to those formed by reactive power measurements.

# Arguments
To define flow-observable islands, this function needs the `Measurement` type.

# Returns
The function returns an instance of the [`Island`](@ref Island) type.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

statusWattmeter!(monitoring; inservice = 15)
monitoring.varmeter.reactive.status = copy(monitoring.wattmeter.active.status)

islands = islandTopologicalFlow(monitoring)
```
"""
function islandTopologicalFlow(monitoring::Measurement)
    system = monitoring.system

    observe = Island([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Set{Int64}()))
    rowval, colptr = connectionObservability(system)

    connectedComponents(system, observe, monitoring.wattmeter)
    tieBusBranch(system, observe)
    tieInjection(observe, monitoring.wattmeter)

    mergePairs(system.bus, observe, rowval, colptr)
    tieBusBranch(system, observe)

    return observe
end

"""
    islandTopological(monitoring::Measurement)

The function employs a topological method to identify maximal-observable islands. Specifically, it
employs active power measurements to pinpoint flow-observable islands. Subsequently, these islands
are merged based on the available injection measurements.

It is assumed that active and reactive power measurements are paired, indicating a standard
observability analysis. In this analysis, islands formed by active power measurements correspond to
those formed by reactive power measurements.

# Arguments
To define maximal-observable islands, this function needs the `Measurement` type.

# Returns
The function returns an instance of the [`Island`](@ref Island) type.

# Example
```jldoctest
system, monitoring = ems("case14.h5", "monitoring.h5")

statusWattmeter!(monitoring; inservice = 15)
monitoring.varmeter.reactive.status = copy(monitoring.wattmeter.active.status)

islands = islandTopological(monitoring)
```
"""
function islandTopological(monitoring::Measurement)
    system = monitoring.system

    observe = Island([], Int64[], TieData(Set{Int64}(), Set{Int64}(), Set{Int64}()))
    rowval, colptr = connectionObservability(system)

    connectedComponents(system, observe, monitoring.wattmeter)
    tieBusBranch(system, observe)
    tieInjection(observe, monitoring.wattmeter)

    mergePairs(system.bus, observe, rowval, colptr)
    mergeFlowIslands(system, observe, rowval, colptr)

    return observe
end

function connectedComponents(system::PowerSystem, observe::Island, watt::Wattmeter)
    bus = system.bus
    branch = system.branch

    degree = zeros(Int64, bus.number)
    inservice = 0
    @inbounds for (i, k) in enumerate(watt.layout.index)
        if !watt.layout.bus[i] && watt.active.status[i] == 1 && branch.layout.status[k] == 1
            degree[branch.layout.from[k]] += 1
            degree[branch.layout.to[k]] += 1
            inservice += 1
        end
    end

    offset = Vector{Int64}(undef, bus.number + 1)
    offset[1] = 1
    @inbounds for i = 1:bus.number
        offset[i + 1] = offset[i] + degree[i]
    end

    neighbor = Vector{Int64}(undef, 2 * inservice)
    fill!(degree, 0)
    @inbounds for (i, k) in enumerate(watt.layout.index)
        if !watt.layout.bus[i] && watt.active.status[i] == 1 && branch.layout.status[k] == 1
            from = branch.layout.from[k]
            to = branch.layout.to[k]

            idx = offset[from] + degree[from]
            neighbor[idx] = to
            degree[from] += 1

            idx = offset[to] + degree[to]
            neighbor[idx] = from
            degree[to] += 1
        end
    end

    observe.bus = fill(0, bus.number)
    queue = Vector{Int64}(undef, bus.number)
    comp = 0
    @inbounds for i = 1:bus.number
        if observe.bus[i] == 0
            comp += 1
            head = 1
            tail = 1
            queue[tail] = i
            observe.bus[i] = comp

            while head <= tail
                v = queue[head]
                head += 1

                for index = offset[v]:(offset[v + 1] - 1)
                    next = neighbor[index]
                    if observe.bus[next] == 0
                        observe.bus[next] = comp
                        tail += 1
                        queue[tail] = next
                    end
                end
            end
        end
    end

    fill!(degree, 0)
    @inbounds for i = 1:bus.number
        degree[observe.bus[i]] += 1
    end

    observe.island = [Vector{Int64}(undef, degree[i]) for i = 1:comp]
    fill!(degree, 0)
    @inbounds for k = 1:bus.number
        i = observe.bus[k]
        degree[i] += 1
        observe.island[i][degree[i]] = k
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
    islandCount = size(observe.island, 1)
    removeIsland = fill(false, islandCount)
    head = zeros(Int64, islandCount)
    tail = zeros(Int64, islandCount)
    islandSize = zeros(Int64, islandCount)
    nextBus = zeros(Int64, bus.number)

    @inbounds for (k, island) in enumerate(observe.island)
        islandSize[k] = length(island)
        if !isempty(island)
            head[k] = island[1]
            tail[k] = island[end]
            for i = 1:(lastindex(island) - 1)
                nextBus[island[i]] = island[i + 1]
            end
        end
    end

    @inbounds while merge
        merge = false
        for idxBus in observe.tie.injection
            island = observe.bus[idxBus]

            index = 0
            incidentCount = 0
            for idx = colptr[idxBus]:(colptr[idxBus + 1] - 1)
                incident = observe.bus[rowval[idx]]
                if incident != island && incident != index
                    incidentCount += 1
                    if incidentCount > 1
                        break
                    end
                    index = incident
                end
            end

            if incidentCount <= 1
                if incidentCount == 1
                    nextBus[tail[island]] = head[index]
                    tail[island] = tail[index]
                    islandSize[island] += islandSize[index]

                    i = head[index]
                    while i != 0
                        observe.bus[i] = island
                        i = nextBus[i]
                    end

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

    if flag
        keep = findall(!, removeIsland)
        observe.island = [Vector{Int64}(undef, islandSize[i]) for i in keep]

        @inbounds for (k, idxIsland) in enumerate(keep)
            busIndex = head[idxIsland]
            position = 1
            while busIndex != 0
                observe.island[k][position] = busIndex
                observe.bus[busIndex] = k
                position += 1
                busIndex = nextBus[busIndex]
            end
        end
    else
        deleteat!(observe.island, removeIsland)
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
    con = fill(false, bus.number)
    @inbounds while merge != 0
        fill!(con, false)
        incidentToIslands = fill(Int64[], length(observe.tie.injection), 1)

        for (k, idxBus) in enumerate(observe.tie.injection)
            connection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

            con[connection] .= true
            incidentToIslands[k] = sort(unique(observe.bus[con]))
            con[connection] .= false
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
            connection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

            con[connection] .= true
            if length(Set(observe.bus[con])) == 1
                push!(removeInjection, idxBus)
            end
            con[connection] .= false
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

function decisionTree(measurements::Matrix{Vector{Int64}})
    totalIslands = 0
    @inbounds for measurement in measurements
        for island in measurement
            totalIslands = max(totalIslands, island)
        end
    end

    appeared = zeros(Int64, totalIslands)
    marker = Ref(1)
    @inbounds for t = 2:length(measurements)
        result = Vector{Int64}(undef, t)
        combination = searchCombination(
            measurements, result, 1, 0, length(measurements) - t, t, appeared, marker
        )
        if combination != false
            return combination
        end
    end

    return false
end

function searchCombination(
    measurements::Matrix{Vector{Int64}},
    result::Vector{Int64},
    position::Int64,
    value::Int64,
    maxN::Int64,
    k::Int64,
    appeared::Vector{Int64},
    marker::Base.RefValue{Int64}
)
    @inbounds for i = value:maxN
        result[position] = position + i
        if position < k
            combination = searchCombination(
                measurements, result, position + 1, i, maxN, k, appeared, marker
            )
            if combination != false
                return combination
            end
        elseif checkCombination(measurements, result, appeared, marker[], k + 1)
            return copy(result)
        else
            marker[] += 1
        end
    end

    return false
end

function checkCombination(
    measurements::Matrix{Vector{Int64}},
    indices::Vector{Int64},
    appeared::Vector{Int64},
    marker::Int64,
    required::Int64
)
    count = 0
    @inbounds for index in indices
        for island in measurements[index]
            if appeared[island] != marker
                appeared[island] = marker
                count += 1
            end
        end
    end

    return count == required
end

"""
    restorationGram!(monitoring::Measurement, pseudo::Measurement, islands::Island; threshold)

Upon identifying the `Island`, the function incorporates measurements from the available
pseudo-measurements in the `pseudo` variable into the `monitoring` variable to reinstate observability.
This method relies on reduced coefficient matrices and the Gram matrix.

It is important to note that the monitoring labels in the `monitoring` and `pseudo` variables must be
different to enable the function to successfully incorporate measurements from `pseudo` into the
`monitoring` set of measurements.

# Keyword
The keyword `threshold` defines the zero pivot threshold value, with a default value of `1e-5`. More
precisely, computed pivots with absolute values less than or equal to this threshold are treated as
zero pivots.

# Updates
The function updates the `monitoring` variable of the `Measurement` type.

# Example
```jldoctest
system, monitoring, pseudo = ems("case14.h5", "monitoring.h5", "pseudo.h5")

statusWattmeter!(monitoring; inservice = 10)
islands = islandTopological(monitoring)

restorationGram!(monitoring, pseudo, islands)
```
"""
function restorationGram!(
    monitoring::Measurement,
    pseudo::Measurement,
    islands::Island;
    threshold::Float64 = 1e-5
)
    system = monitoring.system
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

    @inbounds for i = 1:monitoring.pmu.number
        if monitoring.pmu.layout.bus[i]
            if monitoring.pmu.angle.status[i] == 1 && monitoring.pmu.magnitude.status[i] == 1
                island = islands.bus[monitoring.pmu.layout.index[i]]
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
                lblWatt = getLabel(watt.label, idx)
                lblVar = getLabel(var.label, idx)

                if watt.layout.bus[idx]
                    lblBus = getLabel(system.bus.label, indexBusBranch)

                    addWattmeter!(
                        monitoring; bus = lblBus, label = lblWatt,
                        status = 1, active = watt.active.mean[idx],
                        variance = watt.active.variance[idx], noise = false
                    )
                    addVarmeter!(
                        monitoring; bus = lblBus, label = lblVar,
                        status = 1, reactive = var.reactive.mean[idx],
                        variance = var.reactive.variance[idx], noise = false
                    )
                else
                    lblBranch = getLabel(system.branch.label, indexBusBranch)
                    if watt.layout.from[idx]
                        addWattmeter!(
                            monitoring; from = lblBranch, label = lblWatt,
                            status = 1, active = watt.active.mean[idx],
                            variance = watt.active.variance[idx], noise = false
                        )
                        addVarmeter!(
                            monitoring; from = lblBranch, label = lblVar,
                            status = 1, reactive = var.reactive.mean[idx],
                            variance = var.reactive.variance[idx], noise = false
                        )
                    else
                        addWattmeter!(
                            monitoring; to = lblBranch, label = lblWatt,
                            status = 1, active = watt.active.mean[idx],
                            variance = watt.active.variance[idx], noise = false
                        )
                        addVarmeter!(
                            monitoring; to = lblBranch, label = lblVar,
                            status = 1, reactive = var.reactive.mean[idx],
                            variance = var.reactive.variance[idx], noise = false
                        )
                    end
                end
            else
                indexBus = pmu.layout.index[idx]
                lblPmu = getLabel(pmu.label, idx)
                lblBus = getLabel(system.bus.label, indexBus)

                addPmu!(
                    monitoring; bus = lblBus, label = lblPmu, status = 1,
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
    connection = rowval[colptr[idxBus]:(colptr[idxBus + 1] - 1)]

    con[connection] .= true
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
    con[connection] .= false

    return jcb, con
end

function connectionObservability(system::PowerSystem)
    model = system.model

    if isempty(model.dc.nodalMatrix) && isempty(model.ac.nodalMatrix)
        acModel!(system)
    end

    if !isempty(model.dc.nodalMatrix)
        dropZeros!(system, model.dc)
        rowval = model.dc.nodalMatrix.rowval
        colptr = model.dc.nodalMatrix.colptr
    else
        dropZeros!(system, model.ac)
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

"""
    pmuPlacement(monitoring::Measurement, optimizer; legacy, bridge, name, placement, verbose)

The function determines the optimal placement of PMUs through integer linear programming. It
identifies the minimum set of PMUs required to ensure observability and a unique state estimator.

The function accepts a `Measurement` type as input to establish the framework for finding the optimal
PMU placement. If the `ac` field within the `PowerSystem` type is not yet created, the function
automatically initiates an update process.

Additionally, the `optimizer` argument is a crucial component for formulating and solving the
optimization problem. Typically, using the HiGHS or GLPK solver is sufficient. For more detailed
information, please refer to the [JuMP documentation](https://jump.dev/JuMP.jl/stable/packages/solvers/).

# Keywords
The function accepts the following keywords:
* `legacy`: Takes into account power measurements (default: `false`).
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `false`).
* `verbose`: Controls the output display, ranging from silent mode (`0`) to detailed output (`3`).

Additionally, users can modify the variable names used for printing and writing by setting the
keyword for the placement variables. For example, users may set `placement = "x"` to display the
optimization problem in a more readable format.

# Returns
The function returns an instance of the [`PmuPlacement`](@ref PmuPlacement) type.

Note that if a PMU is understood as a device that measures the bus voltage phasor and all branch
current phasors incident to the bus, users only need the results stored in the `bus` variable.
However, if a PMU is considered to measure an individual phasor, then all required phasor measurements
can be found in the `bus`, `from`, and `to` variables.

# Example
```jldoctest
using HiGHS, Ipopt

system, monitoring = ems("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; current = true)

placement = pmuPlacement(monitoring, HiGHS.Optimizer)

@pmu(label = "PMU ?: !")
for (bus, i) in placement.bus
    Vi, θi = analysis.voltage.magnitude[i], analysis.voltage.angle[i]
    addPmu!(monitoring; bus = bus, magnitude = Vi, angle = θi)
end
for branch in keys(placement.from)
    Iij, ψij = fromCurrent(analysis; label = branch)
    addPmu!(monitoring; from = branch, magnitude = Iij, angle = ψij)
end
for branch in keys(placement.to)
    Iji, ψji = toCurrent(analysis; label = branch)
    addPmu!(monitoring; to = branch, magnitude = Iji, angle = ψji)
end
```
"""
function pmuPlacement(
    monitoring::Measurement,
    (@nospecialize optimizerFactory);
    legacy::Bool = false,
    bridge::Bool = false,
    name::Bool = false,
    placement::String = "placement",
    verbose::Int64 = template.config.verbose,
)
    system = monitoring.system
    bus = system.bus
    branch = system.branch
    ac = system.model.ac

    placementPmu = PmuPlacement(
        OrderedDict{template.bus.key, Int64}(),
        OrderedDict{template.branch.key, Int64}(),
        OrderedDict{template.branch.key, Int64}()
    )

    model!(system, ac)
    dropZeros!(system, ac)

    jump = JuMP.Model(optimizerFactory; add_bridges = bridge)

    silentJump(jump, verbose)
    set_string_names_on_creation(jump, name)

    var = @variable(jump, placement[i = 1:bus.number], Bin, base_name = placement)

    expr = AffExpr()
    if legacy
        incidentBus = fill(false, bus.number)
        @inbounds for (i, k) in enumerate(monitoring.wattmeter.layout.index)
            if monitoring.wattmeter.active.status[i] == 1
                rhs = -1
                if monitoring.wattmeter.layout.bus[i]
                    for j in ac.nodalMatrix.colptr[k]:(ac.nodalMatrix.colptr[k + 1] - 1)
                        row = ac.nodalMatrix.rowval[j]
                        incidentBus[row] = true
                        rhs += 1
                        for q in ac.nodalMatrix.colptr[row]:(ac.nodalMatrix.colptr[row + 1] - 1)
                            h = ac.nodalMatrix.rowval[q]
                            add_to_expression!(expr, var[h])
                        end
                    end
                else
                    for j in (branch.layout.from[i], branch.layout.to[i])
                        incidentBus[j] = true
                        rhs += 1
                        for k in ac.nodalMatrix.colptr[j]:(ac.nodalMatrix.colptr[j + 1] - 1)
                            row = ac.nodalMatrix.rowval[k]
                            add_to_expression!(expr, var[row])
                        end
                    end
                end

                add_constraint(jump, ScalarConstraint(expr, MOI.GreaterThan(rhs)))
                empty!(expr.terms)
            end
        end

        @inbounds for (i, incident) in enumerate(incidentBus)
            if !incident
                for k in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                    row = ac.nodalMatrix.rowval[k]
                    add_to_expression!(expr, placement[row])
                end

                add_constraint(jump, ScalarConstraint(expr, MOI.GreaterThan(1)))
                empty!(expr.terms)
            end
        end
    else
        @inbounds for i = 1:bus.number
            for j in ac.nodalMatrix.colptr[i]:(ac.nodalMatrix.colptr[i + 1] - 1)
                k = ac.nodalMatrix.rowval[j]
                add_to_expression!(expr, var[k])
            end

            add_constraint(jump, ScalarConstraint(expr, MOI.GreaterThan(1)))
            empty!(expr.terms)
        end
    end

    @objective(jump, Min, sum(var))
    optimize!(jump)

    fromDegree = zeros(Int64, bus.number)
    toDegree = zeros(Int64, bus.number)
    activeBranch = 0
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            fromDegree[branch.layout.from[i]] += 1
            toDegree[branch.layout.to[i]] += 1
            activeBranch += 1
        end
    end

    fromOffset = Vector{Int64}(undef, bus.number + 1)
    toOffset = Vector{Int64}(undef, bus.number + 1)
    fromOffset[1] = 1
    toOffset[1] = 1
    @inbounds for i = 1:bus.number
        fromOffset[i + 1] = fromOffset[i] + fromDegree[i]
        toOffset[i + 1] = toOffset[i] + toDegree[i]
    end

    fromIndex = Vector{Int64}(undef, activeBranch)
    toIndex = Vector{Int64}(undef, activeBranch)
    fill!(fromDegree, 0)
    fill!(toDegree, 0)
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            from = branch.layout.from[i]
            to = branch.layout.to[i]

            idx = fromOffset[from] + fromDegree[from]
            fromIndex[idx] = i
            fromDegree[from] += 1

            idx = toOffset[to] + toDegree[to]
            toIndex[idx] = i
            toDegree[to] += 1
        end
    end

    @inbounds for i = 1:bus.number
        if value(var[i]) == 1
            placementPmu.bus[getLabel(bus.label, i)] = i
            for idx = fromOffset[i]:(fromOffset[i + 1] - 1)
                j = fromIndex[idx]
                placementPmu.from[getLabel(system.branch.label, j)] = j
            end
            for idx = toOffset[i]:(toOffset[i + 1] - 1)
                j = toIndex[idx]
                placementPmu.to[getLabel(system.branch.label, j)] = j
            end
        end
    end

    printExit(jump, verbose)

    return placementPmu
end

"""
    pmuPlacement!(monitoring::Measurement, analysis::AC, optimizer;
        varianceMagnitudeBus, varianceAngleBus,
        varianceMagnitudeFrom, varianceAngleFrom,
        varianceMagnitudeTo, varianceAngleTo,
        noise, correlated, polar,
        square, legacy, bridge, name, placement, verbose)

The function finds the optimal PMU placement by executing the [`pmuPlacement`](@ref pmuPlacement)
function. Then, based on the results from the `AC` analysis object, it generates phasor measurements and
integrates them into the `Measurement` type. If current values are missing in the `AC` analysis object, the
function calculates the associated currents required to form measurement values.

# Keywords
PMUs at the buses can be configured using:
* `varianceMagnitudeBus` (pu or V): Variance of bus voltage magnitude measurements.
* `varianceAngleBus` (rad or deg): Variance of bus voltage angle measurements.
PMUs at the from-bus ends of the branches can be configured using:
* `varianceMagnitudeFrom` (pu or A): Variance of current magnitude measurements.
* `varianceAngleFrom` (rad or deg): Variance of current angle measurements.
PMUs at the to-bus ends of the branches can be configured using:
* `varianceMagnitudeTo` (pu or A): Variance of current magnitude measurements.
* `varianceAngleTo` (rad or deg): Variance of current angle measurements.
Settings for generating measurements include:
* `noise`: Defines the method for generating the measurement means:
  * `noise = true`: adds white Gaussian noise to the phasor values, using the defined variances,
  * `noise = false`: uses the exact phasor values without adding noise.
Settings for handling phasor measurements include:
* `correlated`: Specifies error correlation for PMUs for algorithms utilizing rectangular coordinates:
  * `correlated = true`: considers correlated errors,
  * `correlated = false`: disregards correlations between errors.
* `polar`: Chooses the coordinate system for including phasor measurements in AC state estimation:
  * `polar = true`: adopts the polar coordinate system,
  * `polar = false`: adopts the rectangular coordinate system.
* `square`: Specifies how current magnitudes are included in the model when using the polar system:
  * `square = true`: included in squared form,
  * `square = false`: included in its original form.
Settings for the optimization solver include:
* `bridge`: Controls the bridging mechanism (default: `false`).
* `name`: Handles the creation of string names (default: `false`).
* `placement`: Variable names used for printing and writing.
* `verbose`: Controls the output display, ranging from silent mode (`0`) to detailed output (`3`).
Setting for the optimal PMU placement formulation:
* `legacy`: Takes into account power measurements (default: `false`).

# Updates
The function updates the `pmu` field of the `Measurement` type.

# Returns
The function returns an instance of the [`PmuPlacement`](@ref PmuPlacement) type.

# Example
```jldoctest
using HiGHS, Ipopt

system, monitoring = ems("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; current = true)

pmuPlacement!(monitoring, analysis, HiGHS.Optimizer)
```
"""
function pmuPlacement!(
    monitoring::Measurement,
    analysis::AC,
    (@nospecialize optimizerFactory);
    legacy::Bool = false,
    bridge::Bool = false,
    name::Bool = false,
    placement::String = "placement",
    verbose::Int64 = template.config.verbose,
    varianceMagnitudeBus::FltIntMiss = missing,
    varianceAngleBus::FltIntMiss = missing,
    varianceMagnitudeFrom::FltIntMiss = missing,
    varianceAngleFrom::FltIntMiss = missing,
    varianceMagnitudeTo::FltIntMiss = missing,
    varianceAngleTo::FltIntMiss = missing,
    noise::Bool = template.pmu.noise,
    correlated::Bool = template.pmu.correlated,
    polar::Bool = template.pmu.polar,
    square::Bool = template.pmu.square
)
    placement = pmuPlacement(monitoring, optimizerFactory; legacy, bridge, name, placement, verbose)
    errorVoltage(analysis.voltage.magnitude)

    for (bus, idx) in placement.bus
        Vᵢ, θᵢ = analysis.voltage.magnitude[idx], analysis.voltage.angle[idx]
        addPmu!(
            monitoring; bus = bus, magnitude = Vᵢ, angle = θᵢ,
            varianceMagnitude = varianceMagnitudeBus, varianceAngle = varianceAngleBus,
            noise, correlated, polar, square
        )
    end
    for (branch, idx) in placement.from
        if isempty(analysis.current.from.magnitude)
            Iᵢⱼ, ψᵢⱼ = fromCurrent(analysis; label = branch)
        else
            Iᵢⱼ, ψᵢⱼ = analysis.current.from.magnitude[idx], analysis.current.from.angle[idx]
        end
        addPmu!(
            monitoring; from = branch, magnitude = Iᵢⱼ, angle = ψᵢⱼ,
            varianceMagnitude = varianceMagnitudeFrom, varianceAngle = varianceAngleFrom,
            noise, correlated, polar, square
        )
    end
    for (branch, idx) in placement.to
        if isempty(analysis.current.to.magnitude)
            Iⱼᵢ, ψⱼᵢ = toCurrent(analysis; label = branch)
        else
            Iⱼᵢ, ψⱼᵢ = analysis.current.to.magnitude[idx], analysis.current.to.angle[idx]
        end
        addPmu!(
            monitoring; to = branch, magnitude = Iⱼᵢ, angle = ψⱼᵢ,
            varianceMagnitude = varianceMagnitudeTo, varianceAngle = varianceAngleTo,
            noise, correlated, polar, square
        )
    end

    return placement
end
