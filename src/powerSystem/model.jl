"""
    acModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and
parameters associated with AC analyses.

# Updates
The function updates the `model.ac` field within the `PowerSystem` composite type,
populating the following variables:
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
    parameter = system.branch.parameter

    ac.admittance = zeros(ComplexF64, system.branch.number)
    ac.nodalToTo = zeros(ComplexF64, system.branch.number)
    ac.nodalFromFrom = zeros(ComplexF64, system.branch.number)
    ac.nodalFromTo = zeros(ComplexF64, system.branch.number)
    ac.nodalToFrom = zeros(ComplexF64, system.branch.number)
    nodalDiagonals = complex.(system.bus.shunt.conductance, system.bus.shunt.susceptance)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            ac.admittance[i] = 1 / (parameter.resistance[i] + im * parameter.reactance[i])
            turnsRatioInv = 1 / parameter.turnsRatio[i]
            transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[i])

            ac.nodalToTo[i] = ac.admittance[i] + 0.5 * complex(parameter.conductance[i], parameter.susceptance[i])
            ac.nodalFromFrom[i] = turnsRatioInv^2 * ac.nodalToTo[i]
            ac.nodalFromTo[i] = -conj(transformerRatio) * ac.admittance[i]
            ac.nodalToFrom[i] = -transformerRatio * ac.admittance[i]

            nodalDiagonals[layout.from[i]] += ac.nodalFromFrom[i]
            nodalDiagonals[layout.to[i]] += ac.nodalToTo[i]
        end
    end

    busIndex = collect(1:system.bus.number)
    ac.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; ac.nodalFromTo; ac.nodalToFrom], system.bus.number, system.bus.number)

    ac.nodalMatrixTranspose = copy(transpose(ac.nodalMatrix))
end

######### Update AC Nodal Matrix ##########
@inline function acNodalUpdate!(system::PowerSystem, index::Int64)
    ac = system.model.ac
    layout = system.branch.layout
    filledElements = nnz(ac.nodalMatrix)
    ac.model += 1

    from = layout.from[index]
    to = layout.to[index]

    ac.nodalMatrix[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrix[to, to] += ac.nodalToTo[index]
    ac.nodalMatrixTranspose[from, from] += ac.nodalFromFrom[index]
    ac.nodalMatrixTranspose[to, to] += ac.nodalToTo[index]

    ac.nodalMatrix[from, to] += ac.nodalFromTo[index]
    ac.nodalMatrix[to, from] += ac.nodalToFrom[index]
    ac.nodalMatrixTranspose[to, from] += ac.nodalFromTo[index]
    ac.nodalMatrixTranspose[from, to] += ac.nodalToFrom[index]

    if filledElements != nnz(ac.nodalMatrix)
        ac.pattern += 1
    end
end

######### Update AC Parameters ##########
@inline function acParameterUpdate!(system::PowerSystem, index::Int64)
    ac = system.model.ac
    parameter = system.branch.parameter

    ac.admittance[index] = 1 / (parameter.resistance[index] + im * parameter.reactance[index])
    turnsRatioInv = 1 / parameter.turnsRatio[index]
    transformerRatio = turnsRatioInv * exp(-im * parameter.shiftAngle[index])

    ac.nodalToTo[index] = ac.admittance[index] + 0.5 * complex(parameter.conductance[index], parameter.susceptance[index])
    ac.nodalFromFrom[index] = turnsRatioInv^2 * ac.nodalToTo[index]
    ac.nodalFromTo[index] = -conj(transformerRatio) * ac.admittance[index]
    ac.nodalToFrom[index] = -transformerRatio * ac.admittance[index]
end

"""
    dcModel!(system::PowerSystem)

The function generates vectors and matrices based on the power system topology and
parameters associated with DC analyses.

# Updates
The function updates the `model.dc` field within the `PowerSystem` composite type,
populating the following variables:
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
    layout = system.branch.layout
    parameter = system.branch.parameter

    dc.shiftPower = fill(0.0, system.bus.number)
    dc.admittance = fill(0.0, system.branch.number)
    nodalDiagonals = fill(0.0, system.bus.number)
    @inbounds for i = 1:system.branch.number
        if layout.status[i] == 1
            dc.admittance[i] = 1 / (parameter.turnsRatio[i] * parameter.reactance[i])

            from = layout.from[i]
            to = layout.to[i]

            shift = parameter.shiftAngle[i] * dc.admittance[i]
            dc.shiftPower[from] -= shift
            dc.shiftPower[to] += shift

            nodalDiagonals[from] += dc.admittance[i]
            nodalDiagonals[to] += dc.admittance[i]
        end
    end

    busIndex = collect(1:system.bus.number)
    dc.nodalMatrix = sparse([busIndex; layout.from; layout.to], [busIndex; layout.to; layout.from],
        [nodalDiagonals; -dc.admittance; -dc.admittance], system.bus.number, system.bus.number)
end

######### Update DC Nodal Matrix ##########
function dcNodalUpdate!(system, index::Int64)
    dc = system.model.dc
    layout = system.branch.layout
    filledElements = nnz(dc.nodalMatrix)
    dc.model += 1

    from = layout.from[index]
    to = layout.to[index]
    admittance = dc.admittance[index]

    dc.nodalMatrix[from, from] += admittance
    dc.nodalMatrix[to, to] += admittance
    dc.nodalMatrix[from, to] -= admittance
    dc.nodalMatrix[to, from] -= admittance

    if filledElements != nnz(dc.nodalMatrix)
        dc.pattern += 1
    end
end

######### Update DC Shift Power ##########
function dcShiftUpdate!(system, index::Int64)
    dc = system.model.dc
    layout = system.branch.layout

    shift = system.branch.parameter.shiftAngle[index] * dc.admittance[index]
    dc.shiftPower[layout.from[index]] -= shift
    dc.shiftPower[layout.to[index]] += shift
end

######### Update DC Admittance ##########
@inline function dcAdmittanceUpdate!(system::PowerSystem, status::Union{Int8, Int64}, index::Int64)
    dc = system.model.dc
    parameter = system.branch.parameter

    dc.admittance[index] = status / (parameter.turnsRatio[index] * parameter.reactance[index])
end

######### Expelling Elements from the AC or DC Model ##########
function acPushZeros!(ac::ACModel)
    push!(ac.admittance, 0.0 + im * 0.0)
    push!(ac.nodalToTo, 0.0 + im * 0.0)
    push!(ac.nodalFromFrom, 0.0 + im * 0.0)
    push!(ac.nodalFromTo, 0.0 + im * 0.0)
    push!(ac.nodalToFrom, 0.0 + im * 0.0)
end

function acSubtractAdmittances!(ac::ACModel, index::Int64)
    ac.nodalFromFrom[index] = -ac.nodalFromFrom[index]
    ac.nodalFromTo[index] = -ac.nodalFromTo[index]
    ac.nodalToTo[index] = -ac.nodalToTo[index]
    ac.nodalToFrom[index] = -ac.nodalToFrom[index]
    ac.admittance[index] = -ac.admittance[index]
end

function acSetZeros!(ac::ACModel, index::Int64)
    ac.nodalFromFrom[index] = 0.0 + im * 0.0
    ac.nodalFromTo[index] = 0.0 + im * 0.0
    ac.nodalToTo[index] = 0.0 + im * 0.0
    ac.nodalToFrom[index] = 0.0 + im * 0.0
    ac.admittance[index] = 0.0 + im * 0.0
end

function acModelEmpty!(ac::ACModel)
    ac.model += 1
    ac.pattern += 1

    ac.nodalMatrix = spzeros(0, 0)
    ac.nodalMatrixTranspose = spzeros(0, 0)
    ac.nodalToTo =  Array{ComplexF64,1}(undef, 0)
    ac.nodalFromFrom = Array{ComplexF64,1}(undef, 0)
    ac.nodalFromTo = Array{ComplexF64,1}(undef, 0)
    ac.nodalToFrom = Array{ComplexF64,1}(undef, 0)
    ac.admittance = Array{ComplexF64,1}(undef, 0)
end

function dcModelEmpty!(dc::DCModel)
    dc.model += 1
    dc.pattern += 1

    dc.nodalMatrix = spzeros(0, 0)
    dc.admittance =  Array{Float64,1}(undef, 0)
    dc.shiftPower = Array{Float64,1}(undef, 0)
end