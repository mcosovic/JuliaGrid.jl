######### Check Package Path ##########
@inline function checkPackagePath()
    pathtoJuliaGrid = pathof(JuliaGrid)
    if pathtoJuliaGrid === nothing
        throw(ErrorException("JuliaGrid not found in install packages."))
    end
    packagePath = abspath(joinpath(dirname(pathtoJuliaGrid), ".."))

    return packagePath
end

######### Check File Format ##########
@inline function checkFileFormat(inputFile::String, packagePath::String)
    extension = ""; path = ""; dataname = ""; fullpath = ""
    try
        extension = string(match(r"\.[A-Za-z0-9]+$", inputFile).match)
    catch
        extension = ""
    end
    if extension == ".h5" || extension == ".m"
        fullpath = inputFile
        path = dirname(inputFile)
        dataname = basename(inputFile)
    end

    if isempty(extension)
        throw(ErrorException("The extension is missing."))
    elseif extension != ".h5" && extension != ".m"
        throw(DomainError(extension, "The extension $extension is not supported."))
    end

    if path == ""
        path = joinpath(packagePath, "src/data/")
        fullpath = joinpath(packagePath, "src/data/", dataname)
    end

    if !(dataname in cd(readdir, path))
        throw(DomainError(dataname, "The input data $dataname is not found."))
    end

    return fullpath, extension
end

######### Renumbering #########
@inline function runRenumbering(newIndex::Array{Int64,1}, indexNumber::Int64, lookup::Dict{Int64,Int64})
    @inbounds for i = 1:indexNumber
        newIndex[i] = lookup[newIndex[i]]
    end

    return newIndex
end

######### Error Voltage ##########
@inline function errorVoltage(voltage)
    if isempty(voltage)
        error("The voltage values are missing.")
    end
end

######### Power System Live State ##########
function setUUID()
    id = uuid4()
    systemList[id.value] = Dict(
        "bus" => 0,
        "branch" => 0,
        "generator" => 0
    )

    return id
end

######### Check UUID ##########
function checkUUID(uuidSystem, uuid)
    if uuidSystem.value != uuid.value
        throw(ErrorException("The composite types do not match."))
    end
end

######### Impedance Base Value ##########
function baseImpedance(baseVoltage::Float64, basePowerInv::Float64, turnsRatio::Float64)
    base = 1.0
    if prefix.impedance != 0.0 || prefix.admittance != 0.0
        base = (baseVoltage * turnsRatio)^2 * basePowerInv
    end

    return base
end

######### Current Magnitude Base Value ##########
function baseCurrentInverse(basePowerInv::Float64, baseVoltage::Float64)
    base = 1.0
    if prefix.currentMagnitude != 0.0
        base = sqrt(3) * baseVoltage * basePowerInv
    end

    return base
end

######### To Per-Units with Default Values ##########
function topu(value, default, baseInv, prefixLive)
    if ismissing(value)
        if default.pu
            value = default.value
        else
            value = default.value * baseInv
        end
    else
        if prefixLive != 0.0
            value = (value * prefixLive) * baseInv
        end
    end

    return value
end

######### To Per-Units Live ##########
function topu(value, baseInv, prefixLive)
    if prefixLive != 0.0
       value = (value * prefixLive) * baseInv
    end

    return value
end

######### To Radians or Volts with Default Values ##########
function tosi(value, default, prefixLive)
    if ismissing(value)
        value = default
    else
        value = value * prefixLive
    end

    return value
end

######### Unitless Quantities with Default Values ##########
function unitless(value, default)
    if ismissing(value)
        value = default
    end

    return value
end

######### Set Label ##########
function setLabel(component, id::UUID, label::Missing, key::String)
    systemList[id.value][key] += 1
    setindex!(component.label, component.number, string(systemList[id.value][key]))
end

function setLabel(component, id::UUID, label::String, key::String)
    if haskey(component.label, label)
        throw(ErrorException("The label $label is not unique."))
    end

    labelInt64 = tryparse(Int64, label)
    if labelInt64 !== nothing
        systemList[id.value][key] = max(systemList[id.value][key], labelInt64)
    end
    setindex!(component.label, component.number, label)
end

function setLabel(component, id::UUID, label::Int64, key::String)
    labelString = string(label)
    if haskey(component.label, labelString)
        throw(ErrorException("The label $label is not unique."))
    end

    systemList[id.value][key] = max(systemList[id.value][key], label)

    setindex!(component.label, component.number, labelString)
end

######### Get Label ##########
function getLabel(container, label::String, name::String)
    if !haskey(container.label, label)
        throw(ErrorException("The $name label $label that has been specified does not exist within the available $name labels."))
    end

    return label
end

function getLabel(container, label::Int64, name::String)
    label = string(label)
    if !haskey(container.label, label)
        throw(ErrorException("The $name label $label that has been specified does not exist within the available $name labels."))
    end

    return label
end

######### Check Status ##########
function checkStatus(status)
    if !(status in [0; 1])
        throw(ErrorException("The status $status is not allowed; it should be either in-service (1) or out-of-service (0)."))
    end
end

######### Print Data ##########
import Base.print

function print(io::IO, label::Dict{String, Int64}, data::Union{Array{Float64,1}, Array{Int64,1}, Array{Int8,1}})
    names = collect(keys(sort(label; byvalue = true)))
    for (k, i) in enumerate(data)
        println(io::IO, names[k], ": ", i)
    end
end

function print(io::IO, label::Dict{String, Int64}, data1::Array{Float64,1}, data2::Array{Float64,1})
    names = collect(keys(sort(label; byvalue = true)))
    for i = 1:lastindex(names)
        println(io::IO, names[i], ": ", data1[i], ", ", data2[i])
    end
end

function print(io::IO, label::Dict{String, Int64}, obj::Dict{Int64, JuMP.ConstraintRef})
    names = collect(keys(sort(label; byvalue = true)))
    for key in keys(sort(obj))
        try
            println(io::IO, names[key], ": ", obj[key])
        catch
            println(io::IO, "undefined")
        end
    end
end

function print(io::IO, obj::Dict{Int64, JuMP.ConstraintRef})
    for key in keys(sort(obj))
        try
            println(io::IO, obj[key])
        catch
            println(io::IO, "undefined")
        end
    end
end

function print(io::IO, label::Dict{String, Int64}, obj::Dict{Int64, Array{JuMP.ConstraintRef,1}})
    names = collect(keys(sort(label; byvalue = true)))
    for key in keys(sort(obj))
        for cons in obj[key]
            try
                println(io::IO, names[key], ": ", cons)
            catch
                println(io::IO, "undefined")
            end
        end
    end
end

function print(io::IO, obj::Dict{Int64, Array{JuMP.ConstraintRef,1}})
    for key in keys(sort(obj))
        for cons in obj[key]
            try
                println(io::IO, cons)
            catch
                println(io::IO, "undefined")
            end
        end
    end
end

######### Check Input Data ##########
function isset(input::T)
    return !ismissing(input)
end