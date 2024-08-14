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

function printTitle(io::IO, maxLine::Int64, delimiter::String, title::String)
    print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    print(io, format(Format("$delimiter %s%*s$delimiter\n"), title, maxLine - textwidth(title) - 1, ""))
    print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
end

function printScale(system::PowerSystem, prefix::PrefixLive)
    return scale = Dict(
        "θ" => prefix.voltageAngle != 0.0 ? 1 / prefix.voltageAngle : 1.0,
        "P" => prefix.activePower != 0.0 ? system.base.power.value * system.base.power.prefix / prefix.activePower : 1.0,
        "Q" => prefix.reactivePower != 0.0 ? system.base.power.value * system.base.power.prefix / prefix.reactivePower : 1.0,
        "S" => prefix.apparentPower != 0.0 ? system.base.power.value * system.base.power.prefix / prefix.apparentPower : 1.0,
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

function toggleLabelHeader(label::L, container::Union{P,M}, labels::OrderedDict{String, Int64}, header::B, footer::B, component::String)
    if isset(label)
        dictIterator = Dict(getLabel(container, label, component) => labels[getLabel(container, label, component)])
        if !isset(header)
            header = false
        end
        if !isset(footer)
            footer = false
        end
    else
        dictIterator = labels
        if !isset(header)
            header = true
        end
        if !isset(footer)
            footer = true
        end
    end

    return dictIterator, header, footer
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

function printFormat(_fmt::Dict{String, String}, fmt::Dict{String, String}, _width::Dict{String, Int64}, width::Dict{String, Int64}, _show::Dict{String, Bool}, show::Dict{String, Bool}, style::Bool)
    @inbounds for (key, value) in fmt
        if haskey(_fmt, key)
            span, precision, specifier = fmtRegex(value)
            _fmt[key] = "%*." * precision * specifier

            if !isempty(span) && style
                _width[key] = max(parse(Int, span), _width[key])
            end
        end
    end

    if style
        @inbounds for (key, value) in width
            if haskey(_width, key)
                _width[key] = max(value, _width[key])
            end
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

function setupPrintSystem(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool; label::Bool = true, dash::Bool = false)
    pfmt = Dict{String, Format}()
    maxLine = 0

    if style
        if label
            pfmt["Label"] = Format("$delimiter %-*s $delimiter")
            maxLine += width["Label"] + 2
        end

        for (key, value) in show
            if value
                pfmt[key] = Format(" $(fmt[key]) $delimiter")
                maxLine += width[key] + 3
            end
        end

        if dash
            pfmt["Dash"] = Format(" %*s $delimiter")
        end
    else
        if label
            pfmt["Label"] = Format("%-*s")
        end

        for (key, value) in show
            if value
                pfmt[key] = Format("$delimiter$(fmt[key])")
            end
        end

        if dash
            pfmt["Dash"] = Format("$delimiter%*s")
        end
    end

    return maxLine, pfmt
end

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, vector::Array{Float64,1}, i::Int64, scale::Float64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], vector[i] * scale))
    end
end

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, dual::Dict{Int64, Float64}, i::Int64, scale::Float64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], dual[i] / scale))
    end
end

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, constraint::Dict{Int64, ConstraintRef}, i::Int64, scale::Float64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], value(constraint[i]) * scale))
    end
end

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, vector::Array{Int8,1}, i::Int64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], vector[i]))
    end
end

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, vector1::Array{Float64,1}, vector2::Array{Float64,1}, i::Int64, j::Int64, scale::Float64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], (vector1[i] - vector2[j]) * scale))
    end
end

function printf(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, key1::String, key2::String, title::String)
    if show[key1] && show[key2]
        print(io, format(Format(" %*s%s%*s $delimiter"), floor(Int, (width[key1] + width[key2] - textwidth(title) + 3) / 2), "", title, ceil(Int, (width[key1] + width[key2] - textwidth(title) + 3) / 2) , ""))
        pfmt1 = Format(" %*s   %*s $delimiter")
        pfmt2 = Format(" %*s $delimiter %*s $delimiter")
        pfmt3 = Format("-%*s-$delimiter-%*s-$delimiter")
    elseif show[key1]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, delimiter, key1, title)
    elseif show[key2]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, delimiter, key2, title)
    else
        pfmt1, pfmt2, pfmt3 = Format(""), Format(""), Format("")
    end

    return pfmt1, pfmt2, pfmt3
end

function printf(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, key::String, title::String)
    if show[key]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, delimiter, key, title)
    else
        pfmt1, pfmt2, pfmt3 = Format(""), Format(""), Format("")
    end

    return pfmt1, pfmt2, pfmt3
end

function singleprintf(io::IO, width::Dict{String, Int64}, delimiter::String, key::String, title::String)
    print(io, format(Format(" %*s%s%*s $delimiter"), floor(Int, (width[key] - textwidth(title)) / 2), "", title, ceil(Int, (width[key] - textwidth(title)) / 2) , ""))
    pfmt1 = Format(" %*s $delimiter")
    pfmt2 = Format(" %*s $delimiter")
    pfmt3 = Format("-%*s-$delimiter")

    return pfmt1, pfmt2, pfmt3
end

function printf(io::IO, fmt::Format, width::Dict{String, Int64}, show::Dict{String, Bool}, key1::String, value1::String, key2::String, value2::String)
    if show[key1] && show[key2]
        print(io, format(fmt, width[key1], value1, width[key2], value2))
    elseif show[key1]
        print(io, format(fmt, width[key1], value1))
    elseif show[key2]
        print(io, format(fmt, width[key2], value2))
    end
end

function printf(io::IO, show::Dict{String, Bool}, delimiter::String, key1::String, value1::String, key2::String, value2::String)
    if show[key1] && show[key2]
        print(io, format(Format("$delimiter%s$delimiter%s"), value1, value2))
    elseif show[key1]
        print(io, format(Format("$delimiter%s"), value1))
    elseif show[key2]
        print(io, format(Format("$delimiter%s"), value2))
    end
end


function printf(io::IO, fmt::Format, width::Dict{String, Int64}, show::Dict{String, Bool}, key::String, value::String)
    if show[key]
        print(io, format(fmt, width[key], value))
    end
end

function printf(io::IO, show::Dict{String, Bool}, delimiter::String, key::String, value::String)
    if show[key]
        print(io, format(Format("$delimiter%s"), value))
    end
end

function printf(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, key1::String, key2::String, key3::String, key4::String, title::String)
    countTrue = show[key1] + show[key2] + show[key3] + show[key4]
    span = width[key1] * show[key1] + width[key2] * show[key2] + width[key3] * show[key3] + width[key4] * show[key4]

    if countTrue == 4
        span += 9
    elseif countTrue == 3
        span += 6
    elseif countTrue == 2
        span += 3
    end

    if countTrue != 0
        print(io, format(Format(" %*s%s%*s $delimiter"), floor(Int, (span - textwidth(title)) / 2), "", title, ceil(Int, (span - textwidth(title)) / 2) , ""))
    end

    return span
end

function printf(io::IO, fmt::Format, span::Int64)
    if span != 0
        print(io, format(fmt, span, ""))
    end
end

function titlemax(width::Dict{String, Int64}, show::Dict{String, Bool}, key1::String, key2::String, title::String)
    if show[key1] && !show[key2]
        width[key1] = max(textwidth(title), width[key1])
    elseif !show[key1] && show[key2]
        width[key2] = max(textwidth(title), width[key2])
    elseif show[key1] && show[key2]
        if width[key1] + width[key2] < textwidth(title)
            width[key2] = max(textwidth(title) - width[key1] - 3, width[key2])
        end
   end
end

function titlemax(width::Dict{String, Int64}, show::Dict{String, Bool}, key1::String, key2::String, key3::String, key4::String, title::String)
    countTrue = show[key1] + show[key2] + show[key3] + show[key4]

    if countTrue == 1
        if show[key1]
            width[key1] = max(textwidth(title), width[key1])
        elseif show[key2]
            width[key2] = max(textwidth(title), width[key2])
        elseif show[key3]
            width[key3] = max(textwidth(title), width[key3])
        elseif show[key4]
            width[key4] = max(textwidth(title), width[key4])
        end
    elseif countTrue == 2
        if width[key1] * show[key1] +  width[key2] * show[key2] + width[key3] * show[key3] +  width[key4] * show[key4] < textwidth(title)
            if show[key4]
                width[key4] = max(textwidth(title) - width[key1] * show[key1] - width[key2] * show[key2] - width[key3] * show[key3] - 3, width[key4])
            elseif show[key3]
                width[key3] = max(textwidth(title) - width[key1] * show[key1] - width[key2] * show[key2] - width[key4] * show[key4] - 3, width[key3])
            elseif show[key2]
                width[key2] = max(textwidth(title) - width[key1] * show[key1] - width[key3] * show[key3] - width[key4] * show[key4] - 3, width[key2])
            end
        end
    end
end

function minmaxPrimal(show::Dict{String, Bool}, constraint::ConstraintRef, scale::Float64, minmaxprimal::Array{Float64,1}, key::String)
    if show[key]
        primalValue = value(constraint) * scale
        minmaxprimal[1] = max(primalValue, minmaxprimal[1])
        minmaxprimal[2] = min(primalValue, minmaxprimal[2])
    end

    return minmaxprimal
end

function minmaxDual(show::Dict{String, Bool}, dual::Float64, scale::Float64, minmaxdual::Array{Float64,1}, key::String)
    if show[key]
        dualValue = dual / scale
        minmaxdual[1] = max(dualValue, minmaxdual[1])
        minmaxdual[2] = min(dualValue, minmaxdual[2])
    end

    return minmaxdual
end

function minmaxValue(show::Dict{String, Bool}, vector::Array{Float64,1}, i::Int64, scale::Float64, minmavalue::Array{Float64,1}, key::String)
    if show[key]
        val = vector[i] * scale
        minmavalue[1] = max(val, minmavalue[1])
        minmavalue[2] = min(val, minmavalue[2])
    end

    return minmavalue
end