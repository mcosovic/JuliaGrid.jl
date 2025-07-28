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
    @inbounds for i = 1:system.branch.number
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

            nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
            nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
        end
    end

    idxBus = collect(1:system.bus.number)
    ac.nodalMatrix = sparse(
        [idxBus; layout.from; layout.to], [idxBus; layout.to; layout.from],
        [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom],
        system.bus.number, system.bus.number
    )
    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

##### Update AC Nodal Matrix #####
function acNodalUpdate!(system::PowerSystem, idx::Int64)
    ac = system.model.ac

    filledElements = nnz(ac.nodalMatrix)
    ac.model += 1

    i, j = fromto(system, idx)

    ac.nodalMatrix[i, i] += ac.nodalFromFrom[idx]
    ac.nodalMatrix[j, j] += ac.nodalToTo[idx]
    ac.nodalMatrixTranspose[i, i] += ac.nodalFromFrom[idx]
    ac.nodalMatrixTranspose[j, j] += ac.nodalToTo[idx]

    ac.nodalMatrix[i, j] += ac.nodalFromTo[idx]
    ac.nodalMatrix[j, i] += ac.nodalToFrom[idx]
    ac.nodalMatrixTranspose[j, i] += ac.nodalFromTo[idx]
    ac.nodalMatrixTranspose[i, j] += ac.nodalToFrom[idx]

    if filledElements != nnz(ac.nodalMatrix)
        ac.pattern += 1
    end
end

##### Update AC Parameters #####
function acParameterUpdate!(system::PowerSystem, idx::Int64)
    ac = system.model.ac
    param = system.branch.parameter

    impedance = complex(param.resistance[idx], param.reactance[idx])
    ac.admittance[idx] = 1 / impedance

    turnsRatioInv = 1 / param.turnsRatio[idx]
    transformerRatio = turnsRatioInv * cis(-param.shiftAngle[idx])
    shunt = complex(param.conductance[idx], param.susceptance[idx])

    ac.nodalToTo[idx] = ac.admittance[idx] + 0.5 * shunt
    ac.nodalFromFrom[idx] = turnsRatioInv^2 * ac.nodalToTo[idx]
    ac.nodalFromTo[idx] = -conj(transformerRatio) * ac.admittance[idx]
    ac.nodalToFrom[idx] = -transformerRatio * ac.admittance[idx]
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
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            dc.admittance[i] = 1 / (param.turnsRatio[i] * param.reactance[i])

            from, to = fromto(system, i)

            shift = param.shiftAngle[i] * dc.admittance[i]
            dc.shiftPower[from] -= shift
            dc.shiftPower[to] += shift

            nodalDiagonals[from] += dc.admittance[i]
            nodalDiagonals[to] += dc.admittance[i]
        end
    end

    idxBus = collect(1:system.bus.number)
    dc.nodalMatrix = sparse(
        [idxBus; branch.layout.from; branch.layout.to], [idxBus; branch.layout.to; branch.layout.from],
        [nodalDiagonals; -dc.admittance; -dc.admittance],
        system.bus.number, system.bus.number
    )
end

##### Update DC Nodal Matrix #####
function dcNodalUpdate!(system::PowerSystem, idx::Int64)
    dc = system.model.dc

    filledElements = nnz(dc.nodalMatrix)
    dc.model += 1

    i, j = fromto(system, idx)

    admittance = dc.admittance[idx]

    dc.nodalMatrix[i, i] += admittance
    dc.nodalMatrix[j, j] += admittance
    dc.nodalMatrix[i, j] -= admittance
    dc.nodalMatrix[j, i] -= admittance

    if filledElements != nnz(dc.nodalMatrix)
        dc.pattern += 1
    end
end

##### Update DC Shift Power #####
function dcShiftUpdate!(system::PowerSystem, idx::Int64)
    dc = system.model.dc

    shift = system.branch.parameter.shiftAngle[idx] * dc.admittance[idx]
    dc.shiftPower[system.branch.layout.from[idx]] -= shift
    dc.shiftPower[system.branch.layout.to[idx]] += shift
end

##### Update DC Admittance #####
function dcAdmittanceUpdate!(system::PowerSystem, status::Union{Int8, Int64}, idx::Int64)
    dc = system.model.dc
    param = system.branch.parameter

    dc.admittance[idx] = status / (param.turnsRatio[idx] * param.reactance[idx])
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

function acSubtractAdmittances!(ac::AcModel, idx::Int64)
    ac.nodalFromFrom[idx] = -ac.nodalFromFrom[idx]
    ac.nodalFromTo[idx] = -ac.nodalFromTo[idx]
    ac.nodalToTo[idx] = -ac.nodalToTo[idx]
    ac.nodalToFrom[idx] = -ac.nodalToFrom[idx]
    ac.admittance[idx] = -ac.admittance[idx]
end

function acSetZeros!(ac::AcModel, idx::Int64)
    ac.nodalFromFrom[idx] = 0.0 + 0.0im
    ac.nodalFromTo[idx] = 0.0 + 0.0im
    ac.nodalToTo[idx] = 0.0 + 0.0im
    ac.nodalToFrom[idx] = 0.0 + 0.0im
    ac.admittance[idx] = 0.0 + 0.0im
end

function acModelEmpty!(ac::AcModel)
    ac.model += 1
    ac.pattern += 1

    ac.nodalMatrix = spzeros(0, 0)
    ac.nodalMatrixTranspose = spzeros(0, 0)
    ac.nodalToTo = ComplexF64[]
    ac.nodalFromFrom = ComplexF64[]
    ac.nodalFromTo = ComplexF64[]
    ac.nodalToFrom = ComplexF64[]
    ac.admittance = ComplexF64[]
end

function dcModelEmpty!(dc::DcModel)
    dc.model += 1
    dc.pattern += 1

    dc.nodalMatrix = spzeros(0, 0)
    dc.admittance = Float64[]
    dc.shiftPower = Float64[]
end

##### Drop Zeros #####
function dropZeros!(dc::DcModel)
    filledElements = nnz(dc.nodalMatrix)
    dropzeros!(dc.nodalMatrix)

    if filledElements != nnz(dc.nodalMatrix)
        dc.pattern += 1
    end
end

function dropZeros!(ac::AcModel)
    filledElements = nnz(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrixTranspose)

    if filledElements != nnz(ac.nodalMatrix)
        ac.pattern += 1
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

    maxnnz = branch.number * 4
    row = Vector{Int64}(undef, maxnnz)
    col = Vector{Int64}(undef, maxnnz)
    idx = 0
    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            row[idx + 1] = row[idx + 2] = branch.layout.from[i]
            row[idx + 3] = row[idx + 4] = branch.layout.to[i]

            col[idx + 1] = col[idx + 4] = branch.layout.to[i]
            col[idx + 2] = col[idx + 3] = branch.layout.from[i]

            idx += 4
        end
    end

    resize!(row, idx)
    resize!(col, idx)
    gainFlow = sparse(row, col, fill(1, idx), bus.number, bus.number)

    observe = fill(0, bus.number)
    queue = Vector{Int64}()
    comp = 0
    for i = 1:bus.number
        if observe[i] == 0
            comp += 1
            push!(queue, i)
            while !isempty(queue)
                v = pop!(queue)
                observe[v] = comp
                for index in nzrange(gainFlow, v)
                    n = gainFlow.rowval[index]
                    if observe[n] == 0
                        observe[n] = comp
                        push!(queue, n)
                    end
                end
            end
        end
    end

    if label
        island = [Vector{keytype(typeof(system.bus.label))}() for i = 1:comp]
        @inbounds for (k, i) in enumerate(observe)
            push!(island[i], getLabel(system.bus.label, k))
        end
    else
        island = [Vector{Int64}() for i = 1:comp]
        @inbounds for (k, i) in enumerate(observe)
            push!(island[i], k)
        end
    end

    return island
end