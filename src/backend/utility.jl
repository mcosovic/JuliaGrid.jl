##### Check Package Path #####
@inline function checkPackagePath()
    pathtoJuliaGrid = pathof(JuliaGrid)
    if pathtoJuliaGrid === nothing
        throw(ErrorException("JuliaGrid not found in install packages."))
    end

    return abspath(joinpath(dirname(pathtoJuliaGrid), ".."))
end

##### Check File Format #####
@inline function checkFileFormat(inputFile::String, packagePath::String)
    extension = ""; path = ""; dataname = ""; fullpath = ""
    try
        extension = string(match(r"\.[A-Za-z0-9]+$", inputFile).match)
    catch
        extension = ""
    end
    if extension ∈ (".h5", ".m", ".raw")
        fullpath = inputFile
        path = dirname(inputFile)
        dataname = basename(inputFile)
    end

    if isempty(extension)
        throw(ErrorException("The extension is missing."))
    elseif extension ∉ (".h5", ".m", ".raw")
        throw(DomainError(extension, "The extension "  * extension * " is not supported."))
    end

    if path == ""
        path = joinpath(packagePath, "src/data/")
        fullpath = joinpath(packagePath, "src/data/", dataname)
    end

    if dataname ∉ cd(readdir, path)
        throw(DomainError(dataname, "The input data " * dataname * " is not found."))
    end

    return fullpath, extension
end

##### Check File Format #####
function macroLabel(container::Templates, label::Union{Symbol, String}, sym::String)
    if label == :Int64 || label == :Integer
        setfield!(container, :key, Int64)
    elseif label == :String
        setfield!(container, :key, String)
    else
        label = string(label)
        if contains(label, Regex(sym))
            setfield!(container, :label, label)
            setfield!(container, :key, String)
        else
            errorTemplateSymbol(sym)
        end
    end
end

##### Set String Label #####
function setLabel(
    component::Union{P, M},
    label::String,
    ::String,
    ::String;
    prefix::String = ""
)
    labelStr, labelInt = typeLabel(component.label, label)
    if haskey(component.label, labelStr)
        throw(ErrorException("The label " * labelStr * " is not unique."))
    end

    if !isnothing(labelInt)
        component.layout.label = max(component.layout.label, labelInt)
    end

    setindex!(component.label, component.number, labelStr)
end

function typeLabel(::OrderedDict{String, Int64}, label::String)
    label, tryparse(Int64, label)
end

function typeLabel(::OrderedDict{String, Int64}, label::Int64)
    string(label)
end

##### Set Integer Label #####
function setLabel(
    component::Union{P, M},
    label::Int64,
    ::String,
    ::IntStr;
    prefix::String = ""
)
    labelStrInt = typeLabel(component.label, label)
    if haskey(component.label, labelStrInt)
        throw(ErrorException("The label $label is not unique."))
    end

    component.layout.label = max(component.layout.label, label)
    setindex!(component.label, component.number, labelStrInt)
end

function typeLabel(::OrderedDict{Int64, Int64}, label::String)
    throw(ErrorException("The label type is not valid."))
end

function typeLabel(::OrderedDict{Int64, Int64}, label::Int64)
    label
end

##### Set Missing Label #####
function setLabel(
    component::Union{P, M},
    ::Missing,
    default::String,
    key::IntStr;
    prefix::String = ""
)
    component.layout.label += 1

    if key in ("bus", "branch", "generator")
        label = typeLabel(component.label, default, component.layout.label)
    else
        label = typeLabel(component.label, default, component.layout.label, prefix, key)
    end

    setindex!(component.label, component.number, label)
end

function typeLabel(::OrderedDict{String, Int64}, default::String, idx::Int64)
    replace(default, r"\?" => string(idx))
end

function typeLabel(::OrderedDict{Int64, Int64}, default::String, idx::Int64)
    idx
end

function typeLabel(
    componentLabel::OrderedDict{String, Int64},
    default::String,
    idx::Int64,
    prefix::String,
    key::IntStr
)
    label = replace(default, r"\?" => string(idx), r"\!" => string(prefix, key))

    if haskey(componentLabel, label)
        count = 1
        labelOld = label
        while haskey(componentLabel, label)
            label = string(labelOld, " ($count)")
            count += 1
        end
    end

    return label
end

function typeLabel(::OrderedDict{Int64, Int64}, ::String, idx::Int64, ::String, ::IntStr)
    idx
end

##### Get Label #####
function getLabel(container::Union{P, M}, label::String, name::String)
    if haskey(container.label, label)
        return label
    else
        errorGetLabel(name, label)
    end
end

function getLabel(container::Union{P, M}, label::Int64, name::String)
    label = typeLabel(container.label, label)
    if haskey(container.label, label)
        return label
    else
        errorGetLabel(name, label)
    end
end

function getLabel(container::LabelDict, idx::Int64)
    iterate(container, idx)[1][1]
end

##### Get Index #####
function getIndex(container::Union{P, M}, label::String, name::String)
    container.label[getLabel(container, label, name)]
end

function getIndex(container::Union{P, M}, label::Int64, name::String)
    container.label[getLabel(container, label, name)]
end

function getIndex(lbl::OrderedDict{String, Int64}, label::SubString{String})
    lbl[label]
end

function getIndex(lbl::OrderedDict{Int64, Int64}, label::SubString{String})
    lbl[parse(Int64, label)]
end

function getIndex(lbl::OrderedDict{Int64, Int64}, label::Int64)
    lbl[label]
end

function getIndex(lbl::OrderedDict{String, Int64}, label::Int64)
    lbl[string(label)]
end

##### Get Label and Index #####
function getLabelIdx(container::LabelDict, idx::Int64)
    (label, idx),_ = iterate(container, idx)

    return label, idx
end

##### From-To Indices #####
function fromto(system::PowerSystem, idx::Int64)
    system.branch.layout.from[idx], system.branch.layout.to[idx]
end

##### Find Angle and Magnitude #####
function absang(z::ComplexF64)
    abs(z), angle(z)
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
    vector::Vector{Float64},
    value::FltIntMiss,
    default::ContainerTemplate,
    pfxLive::Float64,
    baseInv::Float64,
    shadow::Float64,
)
    if ismissing(value) && isnan(default.value)
        value = 5 * shadow
    end

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

##### Check if the Value is Stored #####
function isstored(A::SparseMatrixCSC{Float64, Int64}, i::Int64, j::Int64)
    startIdx = A.colptr[j]
    endIdx = A.colptr[j + 1] - 1

    startIdx <= endIdx && i in A.rowval[startIdx:endIdx]
end

##### Check if Values are Provided #####
function isset(keys::Vararg{Union{FltIntMiss, String, Bool}})
    any(!ismissing, keys)
end

##### Check Status #####
function checkStatus(status::Union{Int64, Int8})
    if status ∉ (0, 1)
        throw(ErrorException(
            "The status $status is not allowed; it should be in-service (1) or out-of-service (0).")
        )
    end
end

function checkWideStatus(status::Union{Int64, Int8})
    if status ∉ (-1, 0, 1)
        throw(ErrorException(
            "The status $status is not allowed; it should be " *
            "in-service (1), out-of-service but retained (0), or out-of-service and removed (-1).")
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
function factorization(A::SparseMatrixCSC{Float64, Int64}, ::UMFPACK.UmfpackLU{Float64, Int64})
    lu(A)
end

function factorization!(A::SparseMatrixCSC{Float64, Int64}, F::UMFPACK.UmfpackLU{Float64, Int64})
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
    label::LabelDict,
    data::Vararg{Union{Vector{Float64}, Vector{Int64}, Vector{Int8}}}
)
    for (key, idx) in label
        println(io::IO, key, ": ", join([d[idx] for d in data], ", "))
    end
end

function print(io::IO, label::LabelDict, data::Dict{Int64, Float64})
    for (key, idx) in label
        if haskey(data, idx)
            println(io::IO, key, ": ", data[idx])
        end
    end
end

function print(io::IO, label::LabelDict, obj::Dict{Int64, ConstraintRef})
    for (key, idx) in label
        if haskey(obj, idx) && is_valid(owner_model(obj[idx]), obj[idx])
            expr = constraint_string(MIME("text/plain"), obj[idx])
            println(io::IO, key, ": ", simplifyExpression(expr))
        end
    end
end

function print(io::IO, obj::Dict{Int64, ConstraintRef})
    for key in sort(collect(keys(obj)))
        if is_valid(owner_model(obj[key]), obj[key])
            expr = constraint_string(MIME("text/plain"), obj[key])
            println(io::IO, simplifyExpression(expr))
        end
    end
end

function print(io::IO, label::LabelDict, obj::Dict{Int64, Vector{ConstraintRef}})
    for (key, idx) in label
        if haskey(obj, idx)
            for cons in obj[idx]
                if is_valid(owner_model(cons), cons)
                    println(io::IO, key, ": ", cons)
                end
            end
        end
    end
end

function print(io::IO, obj::Dict{Int64, Vector{ConstraintRef}})
    for key in sort(collect(keys(obj)))
        for cons in obj[key]
            if is_valid(owner_model(cons), cons)
                println(io::IO, cons)
            end
        end
    end
end

function simplifyExpression(expr::String)
    expr = replace(expr, r"[-]?0\.0\s*\*\s*(cos|sin)\(\s*[^()]*\s*\)" => "0")
    expr = replace(expr, r"\(\s*[-]?0[.0]?\s*\)" => "")
    expr = replace(expr, r"\(\s*[+]\s*\(" => "((")
    expr = replace(expr, r"^\((.*)\)" => s"\1")

    return expr
end

##### JuMP Settings #####
function silentJump(jump::JuMP.Model, verbose::Int64)
    if verbose == 0 || verbose == 1
        JuMP.set_silent(jump)
    else
        JuMP.unset_silent(jump)
    end
end

function setAttribute(jump::JuMP.Model, iter::IntMiss, tol::FltIntMiss, verbose::Int64)
    if !ismissing(iter)
        set_attribute(jump, "max_iter", iter)
    end
    if !ismissing(tol)
        set_attribute(jump, "tol", tol)
    end
    if verbose == 2
        verbose = 3
    end
    jump.ext[:verbose] = verbose
end

function setJumpVerbose(jump::JuMP.Model, template::Template, verbose::IntMiss)
    if ismissing(verbose) && haskey(jump.ext, :verbose)
        verbose = jump.ext[:verbose]
    end
    if ismissing(verbose)
        verbose = template.config.verbose
    end

    return verbose
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

function errorTemplateSymbol(sym::String)
    throw(ErrorException("The label template lacks the " * sym * " symbol required to create a template."))
end

function errorTemplateKeyword(parameter::Symbol)
    throw(ErrorException("The keyword $(parameter) is illegal."))
end

function errorGetLabel(name::IntStr, label::IntStr)
    throw(ErrorException(
        "The $name label $label that has been specified does " *
        "not exist within the available $name labels.")
    )
end

function errorAssignCost(cost::String)
    throw(ErrorException(
        "An attempt to assign a " * cost * " function, but the function does not exist.")
    )
end

function errorTypeConversion(a::Int64, b::Int64)
    if a != b
        errorTypeConversion()
    end
end

function errorTypeConversion()
    throw(ErrorException(
        "The power flow model cannot be reused because the bus type configuration has changed.")
        )
end


function errorStatusDevice()
    throw(ErrorException(
        "The total number of available devices is less than the requested number for a status change.")
    )
end

function errorSlackDefinition()
    throw(ErrorException(
        "No generator buses with an in-service generator found in the power system. " *
        "Slack bus definition not possible.")
    )
end

function errorOnePoint(label::IntStr)
    throw(ErrorException(
        "The generator labeled $label has a piecewise linear cost function with only one defined point.")
    )
end

function errorSlope(label::IntStr, slope::Float64)
    throw(ErrorException(
        "The piecewise linear cost function's slope of the generator labeled $label has $slope value.")
    )
end

function errorTransfer(a::Vector{Float64}, b::Vector{Float64})
    if lastindex(a) != lastindex(b)
        throw(DimensionMismatch("Voltages could not be transferred because of mismatched array sizes."))
    end
end

function checkVariance(variance::Float64)
    if variance == 0.0
        throw(ErrorException("The variance cannot be zero."))
    end
end

function errorVariance(pmu::PMU, varianceRe::Float64, varianceIm::Float64, idx::Int64)
    if varianceRe == 0.0 || varianceIm == 0.0
        throw(ErrorException(
            "The variance associated with the PMU labeled $(getLabel(pmu.label, idx)) is zero.")
        )
    end
end

function errorCovariance(pmu::PMU, varianceIm::Float64, L2::Float64, idx::Int64)
    if varianceIm == L2^2
        throw(ErrorException(
            "The covariances associated with the PMU labeled " *
            "$(getLabel(pmu.label, idx)) have invalid values.")
        )
    end
end

##### Info Messages #####
function infoObjective(label::IntStr)
    @info(
        "The generator labeled $label has an undefined polynomial " *
        "cost function, which is not included in the objective."
    )
end