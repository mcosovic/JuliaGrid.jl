Base.@kwdef mutable struct SummaryData
    idxMin::Int64 = -1
    min::Float64 = Inf
    idxMax::Int64 = -1
    max::Float64 = -Inf
    total::Float64 = 0.0
    strmin::String = ""
    labelmin::String = ""
    strmax::String = ""
    labelmax::String = ""
    strtotal::String = "-"
    title::String = ""
end

function plosg(word::String, count::Int; pl::String = "es")
    if count == 1
        return word
    else
        return word * pl
    end
end

function isare(count::Int)
    if count == 1
        return "is"
    else
        return "are"
    end
end

function justifyLine(words::Array{String,1}, max_length::Int64)
    if length(words) == 1
        return words[1]
    end
    total_length = sum(length, words)
    total_spaces = max_length - total_length
    num_gaps = length(words) - 1
    even_space = div(total_spaces, num_gaps)
    extra_space = mod(total_spaces, num_gaps)

    justified_line = ""
    for (i, word) in enumerate(words)
        justified_line *= word
        if i < length(words)
            justified_line *= " " ^ (even_space + (i <= extra_space ? 1 : 0))
        end
    end
    return justified_line
end

function cutSentenceParts(sentence::String, max_points::Int64)
    words = split(sentence)
    parts = String[]
    current_part = String[]
    current_length = 0

    for word in words
        word_length = textwidth(word)
        if current_length + word_length + (current_length == 0 ? 0 : 1) > max_points
            push!(parts, justifyLine(current_part, max_points))
            current_part = String[]
            current_length = 0
        end
        push!(current_part, word)
        current_length += word_length + (current_length == 0 ? 0 : 1)
    end
    if !isempty(current_part)
        push!(parts, join(current_part, " "))
    end

    return parts
end

function minmaxsumPrint!(data::SummaryData, value::Float64, i::Int64)
    if value < data.min || data.idxMin == -1
        data.min = value
        data.idxMin = i
    end

    if value > data.max || data.idxMax == -1
        data.max = value
        data.idxMax = i
    end

    data.total += value
end

function formatSummary!(data::SummaryData, unitLive::String, width::Array{Int64,1}, label::OrderedDict{String, Int64}, scale::Float64, device::Int64; total::Bool = true)
    if device != 0
        data.labelmin = iterate(label, data.idxMin)[1][1]
        data.strmin = @sprintf("%.4f", data.min * scale)

        data.labelmax = iterate(label, data.idxMax)[1][1]
        data.strmax = @sprintf("%.4f", data.max * scale)

        width[1] = max(width[1], textwidth(data.labelmin))
        width[2] = max(width[2], textwidth(data.strmin))
        width[3] = max(width[3], textwidth(data.labelmax))
        width[4] = max(width[4], textwidth(data.strmax))

        if total
            data.strtotal = @sprintf("%.4f", data.total * scale)
            width[5] = max(width[5], textwidth(data.strtotal))
        end

        width[5] = max(width[5], textwidth(@sprintf("%i", device)))
        width[6] = max(width[6], textwidth(unitLive))

        if !isempty(data.title)
            width[6] = max(width[6], textwidth(data.title))
        end
    end
end

function summaryHeader(io::IO, maxLine::Int64, sentence::Array{String,1}, header::String)
    @printf(io, "|%s|\n", "-"^maxLine)
    @printf(io, "| %s %*s |\n", header, maxLine - textwidth(header) - 3, "")
    for part in sentence
        @printf(io, "| %s %*s|\n", part, maxLine - 2 - textwidth(part), "")
    end
    @printf(io, "|%s|\n", "-"^maxLine)
end

function summarySubheader(io::IO, maxLine::Int64, span::Array{Int64,1})
    @printf(io, "| %*s | %*s%s%*s | %*s%s%*s | %*s%s%*s |\n",
        span[6], "",
        floor(Int, (span[1] + span[2] - 4) / 2), "", "Minimum", ceil(Int, (span[1] + span[2] - 4) / 2) , "",
        floor(Int, (span[3] + span[4] - 4) / 2), "", "Maximum", ceil(Int, (span[3] + span[4] - 4) / 2) , "",
        floor(Int, (span[5] - 5) / 2), "", "Total", ceil(Int, (span[5] - 5) / 2) , "",
    )
    @printf(io, "|%s|\n", "-"^maxLine)
end

function summaryBlockHeader(io::IO, span::Array{Int64,1}, header::String, total::Int64)
    @printf(io, "| %s | %*s%s%*s | %*s%s%*s | %*i |\n",
        header * " "^(span[6] - textwidth(header)),
        floor(Int, (span[1] + span[2] + 3) / 2), "", "", ceil(Int, (span[1] + span[2] + 3) / 2) , "",
        floor(Int, (span[3] + span[4] + 3) / 2), "", "", ceil(Int, (span[3] + span[4] + 3) / 2) , "",
        span[5], total,
    )
end

function summaryBlock(io::IO, data1::SummaryData, unitLive::String, span::Array{Int64,1}; line::Bool = false)
    @printf(io, "| %s | %*s | %*s | %*s | %*s | %*s |\n",
        unitLive * " "^(span[6] - textwidth(unitLive)),
        span[1], data1.labelmin,
        span[2], data1.strmin,
        span[3], data1.labelmax,
        span[4], data1.strmax,
        span[5], data1.strtotal,
    )

    if line
        @printf(io, "|%s|\n", "-"^(sum(span[:]) + 17))
    end
end

function printTitle(io::IO, maxLine::Int64, title::String)
    @printf(io, "\n|%s|\n", "-"^maxLine)
    @printf(io, "| %s%*s|\n", title, maxLine - textwidth(title) - 1, "")
    @printf(io, "|%s|\n", "-"^maxLine)
end

function printScale(system::PowerSystem, prefix::PrefixLive)
    return scale = Dict(
        "θ" => prefix.voltageAngle != 0.0 ? 1 / prefix.voltageAngle : 1.0,
        "P" => prefix.activePower != 0.0 ? system.base.power.value * system.base.power.prefix / prefix.activePower : 1.0,
        "Q" => prefix.reactivePower != 0.0 ? system.base.power.value * system.base.power.prefix / prefix.reactivePower : 1.0,
        "ψ" => prefix.currentAngle != 0.0 ? 1 / prefix.currentAngle : 1.0,
    )
end

function printUnitData(unitList::UnitList)
    return unitData = Dict(
        "V" => "[$(unitList.voltageMagnitudeLive)]",
        "θ" => "[$(unitList.voltageAngleLive)]",
        "P" => "[$(unitList.activePowerLive)]",
        "Q" => "[$(unitList.reactivePowerLive)]",
        "I" => "[$(unitList.currentMagnitudeLive)]",
        "ψ" => "[$(unitList.currentAngleLive)]"
    )
end

function printUnitSummary(unitList::UnitList)
    return unitSummury = Dict(
        "V" => " Magnitude [$(unitList.voltageMagnitudeLive)]",
        "θ" => " Angle [$(unitList.voltageAngleLive)]",
        "P" => " Active [$(unitList.activePowerLive)]",
        "Q" => " Reactive [$(unitList.reactivePowerLive)]",
        "I" => " Magnitude [$(unitList.currentMagnitudeLive)]",
        "ψ" => " Angle [$(unitList.currentAngleLive)]"
    )
end

function toggleLabelHeader(label::L, container::Union{P,M}, labels::OrderedDict{String, Int64}, header::B, component::String)
    if isset(label)
        dictIterator = Dict(getLabel(container, label, component) => labels[getLabel(container, label, component)])
        if !isset(header)
            header = false
        end
    else
        dictIterator = labels
        if !isset(header)
            header = true
        end
    end

    return dictIterator, header
end

function toggleLabel(label::L, container::Union{P,M}, labels::OrderedDict{String, Int64}, component::String)
    if isset(label)
        dictIterator = Dict(getLabel(container, label, component) => labels[getLabel(container, label, component)])
    else
        dictIterator = labels
    end

    return dictIterator
end

function fminmax(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, vector::Array{Float64,1}, scale::Float64, key::String)
    if show[key]
        minmax = extrema(vector)
        width[key] = max(textwidth(format(Format(fmt[key]), 0, minmax[1] * scale)), textwidth(format(Format(fmt[key]), 0, minmax[2] * scale)), width[key])
    end
end

function fmax(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, vector::Array{Float64,1}, scale::Float64, key::String)
    if show[key]
        maxVal = maximum(vector)
        width[key] = max(textwidth(format(Format(fmt[key]), 0, maxVal * scale)), width[key])
    end
end

function fmax(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, vector::Array{Float64,1}, i::Int64, scale::Float64, key::String)
    if show[key]
        width[key] = max(textwidth(format(Format(fmt[key]), 0, vector[i] * scale)), width[key])
    end
end

function fmax(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, value::Float64, key::String)
    if show[key]
        width[key] = max(textwidth(format(Format(fmt[key]), 0, value)), width[key])
    end
end

function scaleVoltage(voltage::BaseVoltage, prefix::PrefixLive, i::Int64)
    return (voltage.value[i] * voltage.prefix) / prefix.voltageMagnitude
end

function scaleVoltage(prefix::PrefixLive, voltage::BaseVoltage, i::Int64)
    if prefix.voltageMagnitude == 0.0
        scaleV = 1.0
    else
        scaleV = scaleVoltage(voltage, prefix, i)
    end

    return scaleV
end

function scaleCurrent(system::PowerSystem, prefix::PrefixLive, i::Int64)
    return system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
end

function scaleCurrent(prefix::PrefixLive, system::PowerSystem, i::Int64)
    if prefix.currentMagnitude == 0.0
        scaleI = 1.0
    else
        scaleI = scaleCurrent(system, prefix, i)
    end

    return scaleI
end

function printFormat(_fmt::Dict{String, String}, fmt::Dict{String, String}, _width::Dict{String, Int64}, width::Dict{String, Int64}, _show::Dict{String, Bool}, show::Dict{String, Bool})
    @inbounds for (key, value) in fmt
        if haskey(_fmt, key)
            span, precision, specifier = fmtRegex(value)
            _fmt[key] = "%*." * precision * specifier

            if !isempty(span)
                _width[key] = max(parse(Int, span), _width[key])
            end
        end
    end

    @inbounds for (key, value) in width
        if haskey(_width, key)
            _width[key] = max(value, _width[key])
        end
    end

    @inbounds for (key, value) in show
        if haskey(_show, key)
            _show[key] = _show[key] && value
        end
    end

    return _fmt, _width, _show
end

function fmtRegex(fmt::String)
    regexPattern = r"%(\d*)\.?(\d+)?([a-zA-Z])"
    matchRresult = match(regexPattern, fmt)

    if matchRresult !== nothing
        return matchRresult.captures[1], matchRresult.captures[2], matchRresult.captures[3]
    else
        throw(ErrorException("Invalid format string: $fmt"))
    end
end

function initMax(value::Float64)
    maxvalue = 0.0
    if value != 0.0
        maxvalue = -Inf
    end

    return maxvalue
end

function hasMorePrint(width::Dict{String, Int64}, show::Dict{String, Bool}, title::String)
    hasMore = false
    @inbounds for (key, value) in show
        if value == true
            hasMore = true
            break
        end
    end

    if !hasMore
        width["Label"] = max(textwidth(title), width["Label"])
    end

    return hasMore
end

function titlemax(width::Dict{String, Int64}, show::Dict{String, Bool}, key1::String, key2::String, title::String)
    if show[key1] && !show[key2]
        width[key1] = max(textwidth(title), width[key1])
    elseif !show[key1] && show[key2]
        width[key2] = max(textwidth(title), width[key2])
   end
end