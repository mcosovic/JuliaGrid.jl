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

######### Error Voltage ##########
@inline function errorVoltage(voltage)
    if isempty(voltage)
        error("The voltage values are missing.")
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
function topu(value, default, prefixLive, baseInv)
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
function topu(value, prefixLive, baseInv)
    if prefixLive != 0.0
       value = (value * prefixLive) * baseInv
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
function setLabel(component, label::Missing, default::String, key::String; prefix::String = "")
    component.layout.label += 1

    if key in ["bus"; "branch"; "generator"]
        label = replace(default, r"\?" => string(component.layout.label))
    else
        label = replace(default, r"\?" => string(component.layout.label), r"\!" => string(prefix, key))
        if haskey(component.label, label)
            count = 1
            labelOld = label
            while haskey(component.label, label)
                label = string(labelOld, " ($count)")
                count += 1
            end
        end
    end

    setindex!(component.label, component.number, label)
end

function setLabel(component, label::String, default::String, key::String; prefix::String = "")
    if haskey(component.label, label)
        throw(ErrorException("The label $label is not unique."))
    end

    labelInt64 = tryparse(Int64, label)
    if labelInt64 !== nothing
        if component.layout.label < labelInt64
            component.layout.label = labelInt64
        end
    end
    setindex!(component.label, component.number, label)
end

function setLabel(component, label::Int64, default::String, key::String; prefix::String = "")
    labelString = string(label)
    if haskey(component.label, labelString)
        throw(ErrorException("The label $label is not unique."))
    end

    if component.layout.label < label
        component.layout.label = label
    end
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

######### Check Location ##########
function checkLocation(from, to)
    if isset(from) && isset(to)
        throw(ErrorException("The concurrent definition of the location keywords is not allowed."))
    elseif ismissing(from) && ismissing(to)
        throw(ErrorException("At least one of the location keywords must be provided."))
    end

    fromFlag = false
    toFlag = false

    if isset(from)
        location = from
        fromFlag = true
    else
        location = to
        toFlag = true
    end

    return location, fromFlag, toFlag
end

function checkLocation(device, bus, from, to)
    if count(==(true), [isset(bus); isset(from); isset(to)]) > 1
        throw(ErrorException("The concurrent definition of the location keywords is not allowed."))
    elseif ismissing(bus) && ismissing(from) && ismissing(to)
        throw(ErrorException("At least one of the location keywords must be provided."))
    end

    busFlag = false
    fromFlag = false
    toFlag = false

    if isset(bus)
        location = bus
        busFlag = true
    elseif isset(from)
        location = from
        fromFlag = true
    else
        location = to
        toFlag = true
    end

    return location, busFlag, fromFlag, toFlag
end

######### Set Mean, Variance, and Status ##########
function setMeter(device::GaussMeter, mean::A, variance::A, status::A, noise::Bool,
    defVariance::ContainerTemplate, defStatus::Int8, prefixLive::Float64, baseInv::Float64)

    push!(device.variance, topu(variance, defVariance, prefixLive, baseInv))

    if noise
        measure = topu(mean, prefixLive, baseInv) + device.variance[end]^(1/2) * randn(1)[1]
    else
        measure = topu(mean, prefixLive, baseInv)
    end
    push!(device.mean, measure)

    push!(device.status, unitless(status, defStatus))
    checkStatus(device.status[end])
end

function updateMeter(device::GaussMeter, index::Int64, mean::A, variance::A,
    status::A, noise::Bool, prefixLive::Float64, baseInv::Float64)

    if isset(variance)
        device.variance[index] = topu(variance, prefixLive, baseInv)
    end

    if isset(mean)
        if noise
            device.mean[index] = topu(mean, prefixLive, baseInv) + device.variance[index]^(1/2) * randn(1)[1]
        else
            device.mean[index] = topu(mean, prefixLive, baseInv)
        end
    end

    if isset(status)
        checkStatus(status)
        device.status[index] = status
    end
end

function removeDeviceLAV(method::LAV, indexDevice::Int64)
    remove!(method.jump, method.residual, indexDevice)

    if !is_fixed(method.residualx[indexDevice])
        fix(method.residualx[indexDevice], 0.0; force = true)
        fix(method.residualy[indexDevice], 0.0; force = true)

        set_objective_coefficient(method.jump, method.residualx[indexDevice], 0)
        set_objective_coefficient(method.jump, method.residualy[indexDevice], 0)
    end
end

function addDeviceLAV(method::LAV, indexDevice::Int64)
    if is_fixed(method.residualx[indexDevice])
        unfix(method.residualx[indexDevice])
        unfix(method.residualy[indexDevice])
        set_lower_bound(method.residualx[indexDevice], 0.0)
        set_lower_bound(method.residualy[indexDevice], 0.0)

        set_objective_coefficient(method.jump, method.residualx[indexDevice], 1)
        set_objective_coefficient(method.jump, method.residualy[indexDevice], 1)
    end
end

######### Factorizations ##########
function sparseFactorization(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64})
    return lu(A)
end

function sparseFactorization!(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64})
    lu!(factorization, A)
end

function sparseFactorization(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.CHOLMOD.Factor{Float64})
    return ldlt(A)
end

function sparseFactorization!(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.CHOLMOD.Factor{Float64})
    return ldlt!(factorization, A)
end

function sparseFactorization(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64})
    return qr(A)
end

function sparseFactorization!(A::SparseMatrixCSC{Float64,Int64}, factorization::SuiteSparse.SPQR.QRSparse{Float64, Int64})
    return qr(A)
end

########### Solutions ###########
function sparseSolution(x::Array{Float64,1}, b::Array{Float64,1}, factor::SuiteSparse.UMFPACK.UmfpackLU{Float64, Int64})
    if isempty(x)
        x = fill(0.0, size(factor.L, 2))
    end

    ldiv!(x, factor, b)
end

function sparseSolution(x::Array{Float64,1}, b::Array{Float64,1}, factor::Union{SuiteSparse.SPQR.QRSparse{Float64, Int64}, SuiteSparse.CHOLMOD.Factor{Float64}})
    return x = factor \ b
end

######### Print Data ##########
import Base.print

function print(io::IO, label::OrderedDict{String, Int64}, data::Union{Array{Float64,1}, Array{Int64,1}, Array{Int8,1}})
    for (key, value) in label
        println(io::IO, key, ": ", data[value])
    end
end

function print(io::IO, label::OrderedDict{String, Int64}, data1::Union{Array{Float64,1}, Array{Int64,1}, Array{Int8,1}}, data2::Union{Array{Float64,1}, Array{Int64,1}, Array{Int8,1}})
    for (key, value) in label
        println(io::IO, key, ": ", data1[value], ", ", data2[value])
    end
end

function print(io::IO, label::OrderedDict{String, Int64}, obj::Dict{Int64, JuMP.ConstraintRef})
    for (key, value) in label
        try
            println(io::IO, key, ": ", obj[value])
        catch
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

function print(io::IO, label::OrderedDict{String, Int64}, obj::Dict{Int64, Array{JuMP.ConstraintRef,1}})
    names = collect(keys(label))
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
function isset(input::Union{A, String, Bool})
    return !ismissing(input)
end

######### Drop Zeros ##########
function dropZeros!(dc::DCModel)
    filledElements = nnz(dc.nodalMatrix)
    dropzeros!(dc.nodalMatrix)

    if filledElements != nnz(dc.nodalMatrix)
        dc.pattern += 1
    end
end

function dropZeros!(ac::ACModel)
    filledElements = nnz(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrix)
    dropzeros!(ac.nodalMatrixTranspose)

    if filledElements != nnz(ac.nodalMatrix)
        ac.pattern += 1
    end
end