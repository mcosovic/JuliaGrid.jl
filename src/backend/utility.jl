##### Check Package Path #####
@inline function checkPackagePath()
    pathtoJuliaGrid = pathof(JuliaGrid)
    if pathtoJuliaGrid === nothing
        throw(ErrorException("JuliaGrid not found in install packages."))
    end
    packagePath = abspath(joinpath(dirname(pathtoJuliaGrid), ".."))

    return packagePath
end

##### Check File Format #####
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
        throw(DomainError(extension, "The extension "  * extension * " is not supported."))
    end

    if path == ""
        path = joinpath(packagePath, "src/data/")
        fullpath = joinpath(packagePath, "src/data/", dataname)
    end

    if !(dataname in cd(readdir, path))
        throw(DomainError(dataname, "The input data " * dataname * " is not found."))
    end

    return fullpath, extension
end

##### Set Label #####
function setLabel(
    component::Union{P, M},
    label::String,
    ::String,
    ::String;
    prefix::String = ""
)
    if haskey(component.label, label)
        throw(ErrorException("The label " * label * " is not unique."))
    end

    labelInt64 = tryparse(Int64, label)
    if labelInt64 !== nothing
        if component.layout.label < labelInt64
            component.layout.label = labelInt64
        end
    end

    setindex!(component.label, component.number, label)
end

function setLabel(
    component::Union{P, M},
    label::Int64,
    ::String,
    ::String;
    prefix::String = ""
)
    labelString = string(label)
    if haskey(component.label, labelString)
        throw(ErrorException("The label " * labelString * " is not unique."))
    end

    if component.layout.label < label
        component.layout.label = label
    end
    setindex!(component.label, component.number, labelString)
end

function setLabel(
    component::Union{P, M},
    label::Missing,
    default::String,
    key::String;
    prefix::String = ""
)
    component.layout.label += 1

    if key in ["bus"; "branch"; "generator"]
        label = replace(default, r"\?" => string(component.layout.label))
    else
        label = replace(
            default, r"\?" => string(component.layout.label), r"\!" => string(prefix, key)
        )
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

##### Get Label #####
function getLabel(container::Union{P, M}, label::String, name::String)
    if !haskey(container.label, label)
        errorGetLabel(name, label)
    end

    return label
end

function getLabel(container::Union{P, M}, label::Int64, name::String)
    label = string(label)
    if !haskey(container.label, label)
        errorGetLabel(name, label)
    end

    return label
end

##### From-To Indices #####
function fromto(system::PowerSystem, idx::Int64)
    return system.branch.layout.from[idx], system.branch.layout.to[idx]
end

##### Find Angle and Magnitude #####
function absang(z::ComplexF64)
    return abs(z), angle(z)
end

##### To Per-Unit Values #####
function topu(value::FltIntMiss, def::ContainerTemplate, pfxLive::Float64, baseInv::Float64)
    if ismissing(value)
        if def.pu
            value = def.value
        else
            value = def.value * baseInv
        end
    else
        if pfxLive != 0.0
            value = (value * pfxLive) * baseInv
        end
    end

    return value
end

function topu(value::FltIntMiss, pfxLive::Float64, baseInv::Float64)
    if pfxLive != 0.0
       value = (value * pfxLive) * baseInv
    end

    return value
end

function givenOrDefault(value::Union{FltIntMiss, Int8}, default::Union{FltIntMiss, Int8})
    if ismissing(value)
        value = default
    end

    return value
end


##### Add Values #####
function add!(
    vector::Vector{Float64},
    value::FltIntMiss,
    default::ContainerTemplate,
    pfxLive::Float64,
    baseInv::Float64
)
    push!(vector, topu(value, default, pfxLive, baseInv))
end

function add!(
    vector::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}},
    value::Union{FltIntMiss, Int8},
    default::Union{FltIntMiss, Int8}
)
    push!(vector, givenOrDefault(value, default))
end

function addGenInBus!(system::PowerSystem, busIdx::Int64, genIdx::Int64)
    if haskey(system.bus.supply.generator, busIdx)
        push!(system.bus.supply.generator[busIdx], genIdx)
    else
        system.bus.supply.generator[busIdx] = [genIdx]
    end
end

##### Update Values #####
function update!(
    vector::Vector{Float64},
    value::FltIntMiss,
    pfxLive::Float64,
    baseInv::Float64,
    idx::Int64
)
    if isset(value)
        vector[idx] = topu(value, pfxLive, baseInv)
    end
end

function update!(
    vector::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}},
    value::FltIntMiss,
    idx::Int64
)
    if isset(value)
        vector[idx] = value
    end
end

##### Check if Values are Provided #####
function isset(keys::Union{FltIntMiss, String, Bool}...)
    return any(!ismissing(k) for k in keys)
end

##### Check Status #####
function checkStatus(status::Union{Int64, Int8})
    if !(status in [0; 1])
        throw(ErrorException(
            "The status $status is not allowed; it should be " *
            "in-service (1) or out-of-service (0).")
        )
    end
end

##### Impedance Base Value #####
function baseImpedance(baseVoltage::Float64, basePowerInv::Float64, turnsRatio::Float64)
    if pfx.impedance != 0.0 || pfx.admittance != 0.0
        return (baseVoltage * turnsRatio)^2 * basePowerInv
    else
        return 1.0
    end
end

##### Current Magnitude Base Value #####
function baseCurrentInv(basePowerInv::Float64, baseVoltage::Float64)
    if pfx.currentMagnitude != 0.0
        return sqrt(3) * baseVoltage * basePowerInv
    else
        return 1.0
    end
end

##### Factorizations #####
function factorization(A::SparseMatrixCSC{Float64, Int64}, ::UMFPACK.UmfpackLU{Float64, Int64}
)
    lu(A)
end

function factorization!(A::SparseMatrixCSC{Float64, Int64}, F::UMFPACK.UmfpackLU{Float64, Int64}
)
    lu!(F, A)
end

function factorization(A::SparseMatrixCSC{Float64, Int64}, ::CHOLMOD.Factor{Float64})
    ldlt(A)
end

function factorization!(A::SparseMatrixCSC{Float64, Int64}, F::CHOLMOD.Factor{Float64})
    ldlt!(F, A)
end

function factorization(A::SparseMatrixCSC{Float64, Int64}, ::SPQR.QRSparse{Float64, Int64})
    return qr(A)
end

function factorization!(A::SparseMatrixCSC{Float64, Int64}, ::SPQR.QRSparse{Float64, Int64})
    qr(A)
end

##### Solutions #####
function solution(x::Vector{Float64}, b::Vector{Float64}, F::UMFPACK.UmfpackLU{Float64, Int64})
    if isempty(x)
        x = fill(0.0, size(F.L, 2))
    end

    ldiv!(x, F, b)
end

function solution(
    ::Vector{Float64},
    b::Vector{Float64},
    factor::Union{SPQR.QRSparse{Float64, Int64}, CHOLMOD.Factor{Float64}}
)
    factor \ b
end

##### Check AC and DC Model #####
function model!(system::PowerSystem, model::ACModel)
    if isempty(model.nodalMatrix)
        acModel!(system)
    end
end

function model!(system::PowerSystem, model::DCModel)
    if isempty(model.nodalMatrix)
        dcModel!(system)
    end
end

##### Check Slack Bus #####
function checkSlackBus(system::PowerSystem)
    if system.bus.layout.slack == 0
        throw(ErrorException("The slack bus is missing."))
    end
end

##### Print Data #####
import Base.print

function print(
    io::IO,
    label::OrderedDict{String, Int64},
    data::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}}
)
    for (key, value) in label
        println(io::IO, key, ": ", data[value])
    end
end

function print(
    io::IO,
    label::OrderedDict{String, Int64},
    data1::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}},
    data2::Union{Vector{Float64}, Vector{Int64}, Vector{Int8}}
)
    for (key, value) in label
        println(io::IO, key, ": ", data1[value], ", ", data2[value])
    end
end

function print(
    io::IO,
    label::OrderedDict{String, Int64},
    obj::Union{Dict{Int64, ConstraintRef}, Dict{Int64, Float64}}
)
    for (key, value) in label
        try
            println(io::IO, key, ": ", obj[value])
        catch
        end
    end
end

function print(io::IO, obj::Dict{Int64, ConstraintRef})
    for key in keys(sort(obj))
        try
            println(io::IO, obj[key])
        catch
            println(io::IO, "undefined")
        end
    end
end

function print(
    io::IO,
    label::OrderedDict{String, Int64},
    obj::Dict{Int64, Vector{ConstraintRef}}
)
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

function print(io::IO, obj::Dict{Int64, Vector{ConstraintRef}})
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

##### Error Messages #####
function errorVoltage(voltage::Vector{Float64})
    if isempty(voltage)
        throw(ErrorException(("The voltage values are missing.")))
    end
end

function errorCurrent(current::Vector{Float64})
    if isempty(current)
        throw(ErrorException(("The current values are missing.")))
    end
end

function errorPower(power::Vector{Float64})
    if isempty(power)
        throw(ErrorException(("The power values are missing.")))
    end
end

function errorTemplateSymbol()
    throw(ErrorException(
        "The label template lacks the '?' symbol to indicate integer placement.")
    )
end

function errorTemplateLabel()
    throw(ErrorException(
        "The label template is missing the required '?' or '!' symbols.")
    )
end

function errorTemplateKeyword(parameter::Symbol)
    throw(ErrorException("The keyword $(parameter) is illegal."))
end

function errorGetLabel(name::Union{Int64, String}, label::String)
    throw(ErrorException(
        "The $name label " * label * " that has been specified does " *
        "not exist within the available $name labels.")
    )
end

function errorAssignCost(cost::String)
    throw(ErrorException(
        "An attempt to assign a " * cost * " function, but the function does not exist.")
    )
end

function errorTypeConversion()
    throw(ErrorException(
        "The power flow model cannot be reused due to required bus type conversion.")
    )
end

function errorStatusDevice()
    throw(ErrorException(
        "The total number of available devices is less " *
        "than the requested number for a status change.")
    )
end

function errorSlackDefinition()
    throw(ErrorException(
        "No generator buses with an in-service generator found in the power system. " *
        "Slack bus definition not possible.")
    )
end

function errorOnePoint(label::String)
    throw(
        ErrorException(
            "The generator labeled " * label * " has a piecewise " *
            "linear cost function with only one defined point."
        )
    )
end

function errorInfSlope(label::String)
    throw(
        ErrorException(
            "The piecewise linear cost function's slope of the generator " *
            "labeled " * label * " has infinite value."
        )
    )
end

##### Info Messages #####
function infoObjective(label::String, term::Int64)
    @info(
        "The generator labeled " * label * " has a polynomial cost function " *
        "of degree $(term-1), which is not included in the objective."
    )
end

function infoObjective(label::String)
    @info(
        "The generator labeled " * label * " has an undefined polynomial " *
        "cost function, which is not included in the objective."
    )
end