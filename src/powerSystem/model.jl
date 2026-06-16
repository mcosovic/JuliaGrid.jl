"""
    acModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and parameters
associated with AC analyses.

# Updates
The function updates the `model.ac` field within the `PowerSystem` type, populating the variables:
- `nodalMatrix`: The nodal matrix.
- `nodalMatrixTranspose`: The transpose of the nodal matrix.
- `nodalFromFrom`: The Y-parameters of the two-port branches.
- `nodalFromTo`: The Y-parameters of the two-port branches.
- `nodalToTo`: The Y-parameters of the two-port branches.
- `nodalToFrom`: The Y-parameters of the two-port branches.
- `admittance`: The branch admittances.

# Example
```jldoctest
system = powerSystem("case14.h5")
acModel!(system)
```
"""
function acModel!(system::PowerSystem)
    ac = system.model.ac
    layout = system.branch.layout
    param = system.branch.parameter

    ac.admittance = zeros(ComplexF64, system.branch.number)
    ac.nodalToTo = zeros(ComplexF64, system.branch.number)
    ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
    ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
    ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
    nodalDiagonals = complex.(system.bus.shunt.conductance, system.bus.shunt.susceptance)

    nnzModel = system.bus.number + 2 * system.branch.number
    row = Vector{Int64}(undef, nnzModel)
    col = Vector{Int64}(undef, nnzModel)
    val = Vector{ComplexF64}(undef, nnzModel)

    @inbounds for i = 1:system.branch.number
        from = layout.from[i]
        to = layout.to[i]

        if layout.status[i] == 1
            impedance = complex(param.resistance[i], param.reactance[i])
            ac.admittance[i] = 1 / impedance

            turnsRatioInv = 1 / param.turnsRatio[i]
            transformerRatio = turnsRatioInv * cis(-param.shiftAngle[i])
            shunt = complex(param.conductance[i], param.susceptance[i])

            ac.nodalToTo[i] = ac.admittance[i] + 0.5 * shunt
            ac.nodalFromFrom[i] = turnsRatioInv^2 * ac.nodalToTo[i]
            ac.nodalFromTo[i] = -conj(transformerRatio) * ac.admittance[i]
            ac.nodalToFrom[i] = -transformerRatio * ac.admittance[i]

            nodalDiagonals[from] += ac.nodalFromFrom[i]
            nodalDiagonals[to] += ac.nodalToTo[i]
        end

        fromToIdx = system.bus.number + i
        toFromIdx = system.bus.number + system.branch.number + i

        row[fromToIdx] = from
        col[fromToIdx] = to
        val[fromToIdx] = ac.nodalFromTo[i]

        row[toFromIdx] = to
        col[toFromIdx] = from
        val[toFromIdx] = ac.nodalToFrom[i]
    end

    @inbounds for i = 1:system.bus.number
        row[i] = i
        col[i] = i
        val[i] = nodalDiagonals[i]
    end

    ac.nodalMatrix = sparse(row, col, val, system.bus.number, system.bus.number)
    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

##### Update AC Nodal Matrix #####
function acNodalUpdate!(system::PowerSystem, idx::Int64)
    ac = system.model.ac

    filledElements = nnz(ac.nodalMatrix)

    i, j = fromto(system, idx)

    fromFrom = ac.nodalFromFrom[idx]
    toTo = ac.nodalToTo[idx]
    fromTo = ac.nodalFromTo[idx]
    toFrom = ac.nodalToFrom[idx]

    ac.nodalMatrix[i, i] += fromFrom
    ac.nodalMatrix[j, j] += toTo
    ac.nodalMatrixTranspose[i, i] += fromFrom
    ac.nodalMatrixTranspose[j, j] += toTo

    ac.nodalMatrix[i, j] += fromTo
    ac.nodalMatrix[j, i] += toFrom
    ac.nodalMatrixTranspose[j, i] += fromTo
    ac.nodalMatrixTranspose[i, j] += toFrom

    if filledElements != nnz(ac.nodalMatrix)
        acPatternChanged!(system)
    else
        acModelChanged!(system)
    end
end

##### Update AC Parameters #####
function acParameterUpdate!(system::PowerSystem, idx::Int64)
    ac = system.model.ac
    param = system.branch.parameter

    impedance = complex(param.resistance[idx], param.reactance[idx])
    admittance = 1 / impedance

    turnsRatioInv = 1 / param.turnsRatio[idx]
    transformerRatio = turnsRatioInv * cis(-param.shiftAngle[idx])
    shunt = complex(param.conductance[idx], param.susceptance[idx])
    nodalToTo = admittance + 0.5 * shunt

    ac.admittance[idx] = admittance
    ac.nodalToTo[idx] = nodalToTo
    ac.nodalFromFrom[idx] = turnsRatioInv^2 * nodalToTo
    ac.nodalFromTo[idx] = -conj(transformerRatio) * admittance
    ac.nodalToFrom[idx] = -transformerRatio * admittance
end

##### Check AC Model #####
function model!(system::PowerSystem, model::AcModel)
    if isempty(model.nodalMatrix)
        acModel!(system)
    end
end

"""
    dcModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and parameters
associated with DC analyses.

# Updates
The function updates the `model.dc` field within the `PowerSystem` type, populating the variables:
- `nodalMatrix`: The nodal matrix.
- `admittance`: The branch admittances.
- `shiftPower`: The active powers related to phase-shifting transformers.

# Example
```jldoctest
system = powerSystem("case14.h5")
dcModel!(system)
```
"""
function dcModel!(system::PowerSystem)
    dc = system.model.dc
    branch = system.branch
    param = system.branch.parameter

    dc.shiftPower = fill(0.0, system.bus.number)
    dc.admittance = fill(0.0, branch.number)
    nodalDiagonals = fill(0.0, system.bus.number)

    nnzModel = system.bus.number + 2 * branch.number
    row = Vector{Int64}(undef, nnzModel)
    col = Vector{Int64}(undef, nnzModel)
    val = Vector{Float64}(undef, nnzModel)

    @inbounds for i = 1:branch.number
        from = branch.layout.from[i]
        to = branch.layout.to[i]
        admittance = 0.0

        if branch.layout.status[i] == 1
            admittance = 1 / (param.turnsRatio[i] * param.reactance[i])
            dc.admittance[i] = admittance

            shift = param.shiftAngle[i] * admittance
            dc.shiftPower[from] -= shift
            dc.shiftPower[to] += shift

            nodalDiagonals[from] += admittance
            nodalDiagonals[to] += admittance
        end

        fromToIdx = system.bus.number + i
        toFromIdx = system.bus.number + branch.number + i

        row[fromToIdx] = from
        col[fromToIdx] = to
        val[fromToIdx] = -admittance

        row[toFromIdx] = to
        col[toFromIdx] = from
        val[toFromIdx] = -admittance
    end

    @inbounds for i = 1:system.bus.number
        row[i] = i
        col[i] = i
        val[i] = nodalDiagonals[i]
    end

    dc.nodalMatrix = sparse(row, col, val, system.bus.number, system.bus.number)
end

##### Update DC Nodal Matrix #####
function dcNodalUpdate!(system::PowerSystem, idx::Int64)
    dc = system.model.dc

    filledElements = nnz(dc.nodalMatrix)

    i, j = fromto(system, idx)

    admittance = dc.admittance[idx]

    dc.nodalMatrix[i, i] += admittance
    dc.nodalMatrix[j, j] += admittance
    dc.nodalMatrix[i, j] -= admittance
    dc.nodalMatrix[j, i] -= admittance

    if filledElements != nnz(dc.nodalMatrix)
        dcPatternChanged!(system)
    else
        dcModelChanged!(system)
    end
end

##### Update DC Shift Power #####
function dcShiftUpdate!(system::PowerSystem, idx::Int64)
    dc = system.model.dc

    shift = system.branch.parameter.shiftAngle[idx] * dc.admittance[idx]
    dc.shiftPower[system.branch.layout.from[idx]] -= shift
    dc.shiftPower[system.branch.layout.to[idx]] += shift
    dcModelChanged!(system)
end

##### Update DC Admittance #####
@inline function dcAdmittanceUpdate!(system::PowerSystem, status::Union{Int8, Int64}, idx::Int64)
    dc = system.model.dc
    param = system.branch.parameter

    if status == 0
        dc.admittance[idx] = 0.0
    else
        dc.admittance[idx] = 1 / (param.turnsRatio[idx] * param.reactance[idx])
    end
end

##### Check AC and DC Model #####
function model!(system::PowerSystem, model::DcModel)
    if isempty(model.nodalMatrix)
        dcModel!(system)
    end
end

##### Expelling Elements from the AC or DC Model #####
function acPushZeros!(ac::AcModel)
    push!(ac.admittance, 0.0 + 0.0im)
    push!(ac.nodalToTo, 0.0 + 0.0im)
    push!(ac.nodalFromFrom, 0.0 + 0.0im)
    push!(ac.nodalFromTo, 0.0 + 0.0im)
    push!(ac.nodalToFrom, 0.0 + 0.0im)
end

@inline function acSubtractAdmittances!(ac::AcModel, idx::Int64)
    ac.nodalFromFrom[idx] = -ac.nodalFromFrom[idx]
    ac.nodalFromTo[idx] = -ac.nodalFromTo[idx]
    ac.nodalToTo[idx] = -ac.nodalToTo[idx]
    ac.nodalToFrom[idx] = -ac.nodalToFrom[idx]
    ac.admittance[idx] = -ac.admittance[idx]
end

@inline function acSetZeros!(ac::AcModel, idx::Int64)
    ac.nodalFromFrom[idx] = 0.0 + 0.0im
    ac.nodalFromTo[idx] = 0.0 + 0.0im
    ac.nodalToTo[idx] = 0.0 + 0.0im
    ac.nodalToFrom[idx] = 0.0 + 0.0im
    ac.admittance[idx] = 0.0 + 0.0im
end

function acModelEmpty!(system::PowerSystem)
    ac = system.model.ac
    acPatternChanged!(system)

    ac.nodalMatrix = spzeros(0, 0)
    ac.nodalMatrixTranspose = spzeros(0, 0)
    ac.nodalToTo = ComplexF64[]
    ac.nodalFromFrom = ComplexF64[]
    ac.nodalFromTo = ComplexF64[]
    ac.nodalToFrom = ComplexF64[]
    ac.admittance = ComplexF64[]
end

function dcModelEmpty!(system::PowerSystem)
    dc = system.model.dc
    dcPatternChanged!(system)

    dc.nodalMatrix = spzeros(0, 0)
    dc.admittance = Float64[]
    dc.shiftPower = Float64[]
end

##### Drop Zeros #####
function dropZeros!(system::PowerSystem, dc::DcModel)
    filledElements = nnz(dc.nodalMatrix)
    dropzeros!(dc.nodalMatrix)

    if filledElements != nnz(dc.nodalMatrix)
        dcPatternChanged!(system)
    end
end

function dropZeros!(system::PowerSystem, ac::AcModel)
    filledElements = nnz(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrixTranspose)

    if filledElements != nnz(ac.nodalMatrix)
        acPatternChanged!(system)
    end
end

"""
    physicalIsland(system::PowerSystem; label = false)

Identifies physical islands within the power system. Each island represents a connected component
of the network, where connectivity is determined by in-service transmission lines and transformers.

# Keyword
If `label` is set to `false`, the function returns a list of islands with bus indices; if set to
`true`, it returns a list of islands with bus labels.

# Returns
A list of physical islands, where each island is represented by a list of electrically connected
buses.

# Example
```jldoctest
system = powerSystem("case14.h5")

island = physicalIsland(system)
```
"""
function physicalIsland(system::PowerSystem; label::Bool = false)
    bus = system.bus
    branch = system.branch

    degree = zeros(Int64, bus.number)
    inservice = 0
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            degree[branch.layout.from[i]] += 1
            degree[branch.layout.to[i]] += 1
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
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            from = branch.layout.from[i]
            to = branch.layout.to[i]

            idx = offset[from] + degree[from]
            neighbor[idx] = to
            degree[from] += 1

            idx = offset[to] + degree[to]
            neighbor[idx] = from
            degree[to] += 1
        end
    end

    observe = fill(0, bus.number)
    queue = Vector{Int64}(undef, bus.number)
    comp = 0
    @inbounds for i = 1:bus.number
        if observe[i] == 0
            comp += 1
            head = 1
            tail = 1
            queue[tail] = i
            observe[i] = comp

            while head <= tail
                v = queue[head]
                head += 1

                for index = offset[v]:(offset[v + 1] - 1)
                    n = neighbor[index]
                    if observe[n] == 0
                        observe[n] = comp
                        tail += 1
                        queue[tail] = n
                    end
                end
            end
        end
    end

    fill!(degree, 0)
    @inbounds for i = 1:bus.number
        degree[observe[i]] += 1
    end

    if label
        island = [Vector{keytype(typeof(system.bus.label))}(undef, degree[i]) for i = 1:comp]
        fill!(degree, 0)
        @inbounds for k = 1:bus.number
            i = observe[k]
            degree[i] += 1
            island[i][degree[i]] = getLabel(system.bus.label, k)
        end
    else
        island = [Vector{Int64}(undef, degree[i]) for i = 1:comp]
        fill!(degree, 0)
        @inbounds for k = 1:bus.number
            i = observe[k]
            degree[i] += 1
            island[i][degree[i]] = k
        end
    end

    return island
end