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

function plosg(word::String, count::Int; pl = "es")
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

function justifyLine(words::Vector{String}, max_length::Int)
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

function cutSentenceParts(sentence::String, max_points::Int)
    words = split(sentence)
    parts = String[]
    current_part = String[]
    current_length = 0

    for word in words
        word_length = length(word)
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

function formatSummary!(data::SummaryData, unitLive::String, span::Array{Int64,1}, label, scale, device; total = true)
    if device != 0
        data.labelmin = iterate(label, data.idxMin)[1][1]
        data.strmin = Printf.@sprintf("%.4f", data.min * scale)

        data.labelmax = iterate(label, data.idxMax)[1][1]
        data.strmax = Printf.@sprintf("%.4f", data.max * scale)

        span[1] = max(span[1], length(data.labelmin))
        span[2] = max(span[2], length(data.strmin))
        span[3] = max(span[3], length(data.labelmax))
        span[4] = max(span[4], length(data.strmax))

        if total
            data.strtotal = Printf.@sprintf("%.4f", data.total * scale)
            span[5] = max(span[5], length(data.strtotal))
        end

        span[5] = max(span[5], length(Printf.@sprintf("%i", device)))
        span[6] = max(span[6], length(unitLive))

        if !isempty(data.title)
            span[6] = max(span[6], length(data.title))
        end
    end
end

function summaryHeader(io::IO, maxLine::Int64, sentence::Array{String,1}, header::String)
    Printf.@printf(io, "|%s|\n", "-"^maxLine)
    Printf.@printf(io, "| %s %*s |\n", header, maxLine - length(header) - 3, "")
    for part in sentence
        Printf.@printf(io, "| %s %*s|\n", part, maxLine - 2 - length(part), "")
    end
    Printf.@printf(io, "|%s|\n", "-"^maxLine)
end

function summarySubheader(io::IO, maxLine::Int64, span::Array{Int64,1})
    Printf.@printf(io, "| %*s | %*s%s%*s | %*s%s%*s | %*s%s%*s |\n",
        span[6], "",
        floor(Int, (span[1] + span[2] - 4) / 2), "", "Minimum", ceil(Int, (span[1] + span[2] - 4) / 2) , "",
        floor(Int, (span[3] + span[4] - 4) / 2), "", "Maximum", ceil(Int, (span[3] + span[4] - 4) / 2) , "",
        floor(Int, (span[5] - 5) / 2), "", "Total", ceil(Int, (span[5] - 5) / 2) , "",
    )
    Printf.@printf(io, "|%s|\n", "-"^maxLine)
end

function summaryBlockHeader(io::IO, span::Array{Int64,1}, header::String, total::Int64)
    Printf.@printf(io, "| %s | %*s%s%*s | %*s%s%*s | %*i |\n",
        header * " "^(span[6] - length(header)),
        floor(Int, (span[1] + span[2] + 3) / 2), "", "", ceil(Int, (span[1] + span[2] + 3) / 2) , "",
        floor(Int, (span[3] + span[4] + 3) / 2), "", "", ceil(Int, (span[3] + span[4] + 3) / 2) , "",
        span[5], total,
    )
end

function summaryBlock(io::IO, data1::SummaryData, unitLive::String, span::Array{Int64,1}; line = false)
    Printf.@printf(io, "| %s | %*s | %*s | %*s | %*s | %*s |\n",
        unitLive * " "^(span[6] - length(unitLive)),
        span[1], data1.labelmin,
        span[2], data1.strmin,
        span[3], data1.labelmax,
        span[4], data1.strmax,
        span[5], data1.strtotal,
    )

    if line
        Printf.@printf(io, "|%s|\n", "-"^(sum(span[:]) + 17))
    end
end

function printTitle(maxLine::Int64, title::String, header::Bool, io::IO)
    if header
        Printf.@printf(io, "\n|%s|\n", "-"^maxLine)
        Printf.@printf(io, "| %s%*s|\n", title, maxLine - length(title) - 1, "")
    end
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

function toggleLabelHeader(label::L, container, labels::OrderedDict{String, Int64}, header::B, component::String)
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

function toggleLabel(label::L, container, labels::OrderedDict{String, Int64}, component::String)
    if isset(label)
        dictIterator = Dict(getLabel(container, label, component) => labels[getLabel(container, label, component)])
    else
        dictIterator = labels
    end

    return dictIterator
end

function formatWidth(format, width::Dict{String, Int64})
    @inbounds for (key, value) in width
        if haskey(format, key)
            format[key] = value
        end
    end

    return format
end