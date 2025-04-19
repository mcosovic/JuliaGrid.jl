mutable struct Print
    pfmt::Dict{String, Format}
    hfmt::Dict{String, Format}
    width::Dict{String, Int64}
    show::OrderedDict{String, Bool}
    heading::OrderedDict{String, Int64}
    subheading::Dict{String, String}
    unit::Dict{String, String}
    head::Dict{Symbol, String}
    delimiter::String
    style::Bool
    title::Bool
    header::Bool
    footer::Bool
    repeat::Int64
    notprint::Bool
    line::Int64
    cnt::Int64
end

mutable struct Summary
    type::OrderedDict{String, String}
    minidx::Dict{String, Int64}
    minval::Dict{String, Float64}
    minlbl::Dict{String, String}
    maxidx::Dict{String, Int64}
    maxval::Dict{String, Float64}
    maxlbl::Dict{String, String}
    total::Dict{String, Float64}
    inuse::Dict{String, Float64}
    block::Int64
end

##### Scale Quantities #####
function scaleVoltage(system::PowerSystem, pfx::PrefixLive, i::Int64)
    (system.base.voltage.value[i] * system.base.voltage.prefix) / (sqrt(3) * pfx.voltageMagnitude)
end

function scaleVoltage(pfx::PrefixLive, system::PowerSystem, i::Int64)
    if pfx.voltageMagnitude == 0.0
        return 1.0
    else
        return scaleVoltage(system, pfx, i)
    end
end

function scaleCurrent(system::PowerSystem, pfx::PrefixLive, i::Int64)
    basePower = system.base.power
    baseVoltg = system.base.voltage

    basePower.value * basePower.prefix /
        (sqrt(3) * baseVoltg.value[i] * baseVoltg.prefix * pfx.currentMagnitude)
end

function scaleCurrent(pfx::PrefixLive, system::PowerSystem, i::Int64)
    if pfx.currentMagnitude == 0.0
        return 1.0
    else
        return scaleCurrent(system, pfx, i)
    end
end

function scaleIij(system::PowerSystem, scale::Float64, pfx::PrefixLive, from::Bool, idx::Int64)
    if pfx.currentMagnitude != 0.0
        if from
            scale = scaleCurrent(system, pfx, system.branch.layout.from[idx])
        else
            scale = scaleCurrent(system, pfx, system.branch.layout.to[idx])
        end
    end

    scale
end

function scalePrint(system::PowerSystem, pfx::PrefixLive)
    basePower = system.base.power.value * system.base.power.prefix

    Dict(
        :θ => pfx.voltageAngle != 0.0 ? 1 / pfx.voltageAngle : 1.0,
        :P => pfx.activePower != 0.0 ? basePower / pfx.activePower : 1.0,
        :Q => pfx.reactivePower != 0.0 ? basePower / pfx.reactivePower : 1.0,
        :S => pfx.apparentPower != 0.0 ? basePower / pfx.apparentPower : 1.0,
        :ψ => pfx.currentAngle != 0.0 ? 1 / pfx.currentAngle : 1.0,
    )
end

##### Print Layout #####
function layout(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    delimiter::String, style::Bool
)
    pfmt = Dict{String, Format}()
    hfmt = Dict{String, Format}(
        "Empty" => Format(" %*s " * delimiter),
        "Break" => Format("-%s-" * delimiter)
    )

    firstTrue = ""
    for (key, value) in show
        if value
            firstTrue = key
            break
        end
    end

    delwidt = textwidth(delimiter)
    maxLine = -delwidt
    if !isempty(firstTrue)
        if style
            for (key, value) in show
                if value
                    pfmt[key] = Format(" " * fmt[key] * " " * delimiter)
                    hfmt[key] = Format(" %*s " * delimiter)
                    maxLine += width[key] + delwidt + 2
                end
            end
            pfmt[firstTrue] = Format(delimiter * " " * fmt[firstTrue] * " " * delimiter)
            hfmt[firstTrue] = Format(delimiter * " %*s " * delimiter)
        else
            for (key, value) in show
                if value
                    pfmt[key] = Format(delimiter * fmt[key])
                    hfmt[key] = Format(delimiter * "%*s")
                end
            end
            pfmt[firstTrue] = Format(fmt[firstTrue])
            hfmt[firstTrue] = Format("%*s")
        end
    end

    return pfmt, hfmt, maxLine
end

function layout(label::IntStrMiss, title::BoolMiss, header::BoolMiss, footer::BoolMiss)
    if isset(label)
        if !isset(header)
            header = false
        end
        if !isset(title)
            title = false
        end
        if !isset(footer)
            footer = false
        end
    else
        if !isset(header)
            header = true
        end
        if !isset(title)
            title = true
        end
        if !isset(footer)
            footer = true
        end
    end

    return title, header, footer
end

##### Format Print #####
function transfer!(
    _fmt::Dict{String, String},
    fmt::Dict{String, String},
    _width::Dict{String, Int64},
    width::Dict{String, Int64},
    _show::OrderedDict{String, Bool},
    show::Dict{String, Bool},
    style::Bool
)
    @inbounds for (key, value) in fmt
        if haskey(_fmt, key)
            aligment, span, precision, specifier = fmtRegex(value)

            if precision !== nothing
                _fmt[key] = "%" * aligment * "*." * precision * specifier
            else
                _fmt[key] = "%" * aligment * "*" * specifier
            end

            if !isempty(span) && style
                _width[key] = max(parse(Int, span), _width[key])
            end
        end
    end

    if style
        @inbounds for (key, value) in width
            if haskey(_width, key)
                _width[key] = max(value - 2, _width[key])
            end
        end
    end

    @inbounds for (key, value) in show
        if haskey(_show, key)
            _show[key] = _show[key] && value
        end
    end

    _fmt, _width, _show
end

function _fmt(_fmt::String; format::String = "%*.4f")
    isempty(_fmt) ? format : _fmt
end

function _width(_width::Int64, span::Int64, style::Bool)
    max(span, _width) * style
end

function _show(
    _show::Bool,
    value::Union{Vector{Float64}, Dict{Int64, ConstraintRef}, Dict{Int64, Float64}}
)
    !isempty(value) & _show
end

function _show(_show::Bool, value::Bool)
    value & _show
end

function _header(headerMain::String, headerStyle::String, style::Bool)
    style ? headerMain : headerStyle
end

function _blank(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    delimiter::String,
    head::Dict{Symbol, String},
    keys::Symbol...
)
    delwidt = textwidth(delimiter)

    blankWidth = -delwidt - 2
    for key in keys
        name = head[key]
        if show[name]
            blankWidth += width[name] + delwidt + 2
        end
    end

    blankWidth::Int64
end

function _blank(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    delimiter::String,
    style::Bool,
    head::Dict{Symbol, String},
    heading::Symbol,
    keys::Symbol...
)
    if style
        countTrue = 0
        maxWidth = 0
        for key in keys
            name = head[key]
            if show[name]
                countTrue += show[name]
                maxWidth += width[name]
            end
        end

        if maxWidth < textwidth(head[heading])
            for key in keys
                name = head[key]
                if show[name]
                    width[name] = max(
                        textwidth(head[heading]) + width[name] - maxWidth -
                        3 * (countTrue - 1), width[name]
                    )
                    break
                end
            end
        end
    end

    _blank(width, show, delimiter, head, keys...)
end

function printing!(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    title::Bool, style::Bool,
    heading::String
)
    howMany = 0
    @inbounds for (key, value) in show
        if value
            howMany += 1
        end
    end

    if howMany == 1 && style && title
        @inbounds for (key, value) in show
            if value
                width[key] = max(textwidth(heading), width[key])
            end
        end
    end

    howMany <= 0
end

function fmtwidth(show::OrderedDict{String, Bool})
    fmt = Dict{String, String}()
    width = Dict{String, Int64}()

    @inbounds for key in keys(show)
        fmt[key] = ""
        width[key] = 0
    end

    fmt, width
end

function fmtRegex(fmt::String)
    regexPattern = r"%([-]?)(\d*)\.?(\d+)?([a-zA-Z])"
    mtch = match(regexPattern, fmt)

    if mtch !== nothing
        return mtch.captures[1], mtch.captures[2], mtch.captures[3], mtch.captures[4]
    else
        throw(ErrorException("Invalid format string: $fmt"))
    end
end

##### Print Title #####
function title(io::IO, prt::Print, caption::String)
    delm = prt.delimiter
    if prt.style && prt.title
        print(io, format(Format("$delm%s$delm\n"), "-"^prt.line))
        print(io, format(Format("$delm %s%*s$delm\n"), caption, prt.line - textwidth(caption) - 1, ""))
        if !prt.header
            print(io, format(Format("$delm%s$delm\n"), "-"^prt.line))
        end
    end
end

##### Print Header #####
function header(io::IO, prt::Print)
    if (prt.cnt - 1) % prt.repeat == 0 || !prt.notprint
        if prt.header
            if prt.style
                printf(io, prt.delimiter, prt.header, prt.style, prt.line)
                printf(io, prt.heading, prt.delimiter)
                printf(io, prt.hfmt["Empty"], prt.heading, prt.delimiter)
            end
            printf(io, prt, prt.subheading, prt.unit)
            prt.notprint = true
        end
    end
    prt.cnt += 1
end

function header(io::IO, prt::Print, ::Summary)
    if prt.header
        if prt.style
            printf(io, prt.delimiter, prt.header, prt.style, prt.line)
            printf(io, prt.heading, prt.delimiter)
            printf(io, prt.hfmt["Empty"], prt.heading, prt.delimiter)
        end
        printf(io, prt, prt.subheading)
    end
end

##### Print Lines #####
function printf(io::IO, flag::Bool, ptr::Print)
    if flag && ptr.style
        print(io, format(Format(ptr.delimiter * "%s" * ptr.delimiter * "\n"), "-"^ptr.line))
    end
end

function printf(io::IO, delimiter::String, flag::Bool, style::Bool, maxLine::Int64)
    if flag && style
        print(io, format(Format(delimiter * "%s" * delimiter * "\n"), "-"^maxLine))
    end
end

function printf(io::IO, heading::OrderedDict{String, Int64}, delimiter::String)
    print(io, delimiter)
    for (title, width) in heading
        if width >= 0
            fmt = Format(" %*s%s%*s $delimiter")
            print(
                io,
                format(fmt, floor(Int, (width - textwidth(title)) / 2), "", title,
                ceil(Int, (width - textwidth(title)) / 2) , "")
            )
        end
    end
    @printf io "\n"
end

function printf(io::IO, fmt::Format, heading::OrderedDict{String, Int64}, delimiter::String)
    print(io, delimiter)
    @inbounds for width in values(heading)
        if width >= 0
            print(io, format(fmt, width, ""))
        end
    end
    @printf io "\n"
end

function printf(io::IO, prt::Print, dicts::Dict{String, String}...)
    for data in dicts
        for (key, value) in prt.show
            if value
                print(io, format(prt.hfmt[key], prt.width[key], data[key]))
            end
        end
        @printf io "\n"
    end

    if prt.style
        print(io, prt.delimiter)
        for (key, value) in prt.show
            if value
                print(io, format(prt.hfmt["Break"], "-" ^ prt.width[key]))
            end
        end
        @printf io "\n"
    end
end

function printf(
    io::IO,
    fmt::Dict{String, Format},
    prt::Print,
    value::Union{String, Int64},
    keys::Symbol...
)
    for key in keys
        name = prt.head[key]
        if prt.show[name]
            print(io, format(fmt[name], prt.width[name], value))
        end
    end
end

function printf(
    io::IO,
    prt::Print,
    i::Int64,
    scale::Float64,
    vector::Vector{Float64},
    key::Symbol
)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], vector[i] * scale))
    end
end

function printf(
    io::IO,
    prt::Print,
    i::Int64,
    scale::Float64,
    constr::Dict{Int64, ConstraintRef},
    key::Symbol;
    native::Bool = true
)
    name = prt.head[key]
    if prt.show[name]
        if native
            print(io, format(prt.pfmt[name], prt.width[name], value(constr[i]) * scale))
        else
            print(io, format(prt.pfmt[name], prt.width[name], sqrt(value(constr[i])) * scale))
        end
    end
end

function printf(
    io::IO,
    prt::Print,
    i::Int64,
    scale::Float64,
    dual::Dict{Int64, Float64},
    key::Symbol;
)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], dual[i] / scale))
    end
end

function printf(
    io::IO,
    prt::Print,
    i::Int64,
    scale::Float64,
    dual::Dict{Int64, Float64},
    constr::Dict{Int64, ConstraintRef},
    key::Symbol;
)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], 2 * dual[i] * sqrt(value(constr[i])) / scale))
    end
end

function printf(io::IO, prt::Print, value::Float64, key::Symbol)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], value))
    end
end

function printf(io::IO, prt::Print, i::Int64, vector::Vector{Int8}, key::Symbol)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], vector[i]))
    end
end

function printf(
    io::IO,
    prt::Print,
    i::Int64,
    j::Int64,
    scale::Float64,
    v1::Vector{Float64},
    v2::Vector{Float64},
    key::Symbol
)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], (v1[j] - v2[i]) * scale))
    end
end

function printf(
    io::IO,
    prt::Print,
    value::Union{Vector{String}, Vector{Int64}},
    i::Int64,
    key::Symbol
)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], value[i]))
    end
end

function printf(io::IO, prt::Print, value::OrderedDict{String, Int64}, i::Int64, key::Symbol)
    name = prt.head[key]
    if prt.show[name]
        print(io, format(prt.pfmt[name], prt.width[name], getLabel(value, i)))
    end
end

function printf(io::IO, prt::Print)
    if prt.style
        print(io, prt.delimiter)
        for (key, value) in prt.show
            if value
                print(io, format(prt.hfmt["Break"], "-" ^prt.width[key]))
            end
        end
        @printf io "\n"
    end
end

##### Find Maximum Values #####
function fmax(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    value::IntStr,
    key::String
)
    if show[key]
        width[key] = max(textwidth(string(value)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    value::Float64,
    key::String
)
    if show[key]
        width[key] = max(textwidth(format(Format(fmt[key]), 0, value)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    scale::Float64,
    vector::Vector{Float64},
    key::String
)
    if show[key]
        maxVal = maximum(vector)
        width[key] = max(textwidth(format(Format(fmt[key]), 0, maxVal * scale)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    vector::Vector{Float64},
    key::String
)
    if show[key]
        maxVal = maximum(vector)
        width[key] = max(textwidth(format(Format(fmt[key]), 0, maxVal)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    vector::Vector{Float64},
    key::String
)
    if show[key]
        width[key] = max(textwidth(format(Format(fmt[key]), 0, vector[i] * scale)), width[key])
    end
end

function fmax(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    label::OrderedDict{String, Int64},
    heading::String
)
    if show[heading]
        width[heading] = max(maximum(textwidth, collect(keys(label))), width[heading])
    end
end

function fmax(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    label::OrderedDict{Int64, Int64},
    heading::String
)
    if show[heading]
        minmax = extrema(collect(keys(label)))
        width[heading] = max(maximum(textwidth, string.(minmax)), width[heading])
    end
end

function fmax(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    label::Vector{String},
    headings::String...
)
    if !isempty(label)
        maxWidth = maximum(textwidth, label)

        for heading in headings
            if show[heading]
                width[heading] = max(maxWidth, width[heading])
            end
        end
    end
end

function fmax(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    label::Vector{Int64},
    headings::String...
)
    if !isempty(label)
        maxWidth = extrema(label)

        for heading in headings
            if show[heading]
                width[heading] = max(maximum(textwidth, string.(maxWidth)), width[heading])
            end
        end
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    dual::Dict{Int64, Float64},
    key::String
)
    if haskey(dual, i) && show[key]
        width[key] = max(textwidth(format(Format(fmt[key]), 0, dual[i] / scale)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    dual::Dict{Int64, Float64},
    constraint::Dict{Int64, ConstraintRef},
    key::String
)
    if haskey(dual, i) && show[key]
        dul = 2 * dual[i] * sqrt(value(constraint[i])) / scale
        width[key] = max(textwidth(format(Format(fmt[key]), 0, dul)), width[key])
    end
end

function fmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    constraint::Dict{Int64, ConstraintRef},
    key::String;
    native::Bool = true
)
    if show[key]
        if native
            val = value(constraint[i]) * scale
        else
            val = sqrt(value(constraint[i])) * scale
        end
        width[key] = max(
            textwidth(format(Format(fmt[key]), 0, val)), width[key]
        )
    end
end

function fmax(
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    maxValue::Float64,
    vector::Vector{Float64},
    key::String
)
    if show[key]
        maxValue = max(maxValue, vector[i] * scale)
    end

    return maxValue
end

##### Find Minimum and Maximum Values #####
function fminmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    scale::Float64,
    vector::Vector{Float64},
    key::String
)
    if show[key]
        minmax = extrema(vector)
        pfmt = Format(fmt[key])
        width[key] = max(
            textwidth(format(pfmt, 0, minmax[1] * scale)),
            textwidth(format(pfmt, 0, minmax[2] * scale)), width[key]
        )
    end
end

function fminmax(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    vector::Vector{Float64},
    key::String
)
    if show[key]
        minmax = extrema(vector)
        pfmt = Format(fmt[key])
        width[key] = max(
            textwidth(format(pfmt, 0, minmax[1])),
            textwidth(format(pfmt, 0, minmax[2])), width[key]
        )
    end
end

function fminmax(
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    vminmax::Vector{Float64},
    constraint::Dict{Int64, ConstraintRef},
    key::String;
    native::Bool = true
)
    if show[key]
        if native
            primalValue = value(constraint[i]) * scale
        else
            primalValue = sqrt(value(constraint[i])) * scale
        end
        vminmax[1] = max(primalValue, vminmax[1])
        vminmax[2] = min(primalValue, vminmax[2])
    end

    minmax
end

function fminmax(
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    vminmax::Vector{Float64},
    dual::Dict{Int64, Float64},
    key::String
)
    if show[key] && haskey(dual, i)
        dualValue = dual[i] / scale
        vminmax[1] = max(dualValue, vminmax[1])
        vminmax[2] = min(dualValue, vminmax[2])
    end

    vminmax
end

function fminmax(
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    vminmax::Vector{Float64},
    dual::Dict{Int64, Float64},
    constraint::Dict{Int64, ConstraintRef},
    key::String
)
    if show[key] && haskey(dual, i)
        dualValue = 2 * dual[i] * sqrt(value(constraint[i])) / scale
        vminmax[1] = max(dualValue, vminmax[1])
        vminmax[2] = min(dualValue, vminmax[2])
    end

    vminmax
end

function fminmax(
    show::OrderedDict{String, Bool},
    i::Int64,
    scale::Float64,
    vminmax::Vector{Float64},
    vector::Vector{Float64},
    key::String
)
    if show[key]
        val = vector[i] * scale
        vminmax[1] = max(val, vminmax[1])
        vminmax[2] = min(val, vminmax[2])
    end

    vminmax
end

##### Utility Functions #####
function pickLabel(
    container::Union{P,M},
    labels::LabelDict,
    label::IntStrMiss,
    component::String
)
    if isset(label)
        dictIterator = OrderedDict(
            getLabel(container, label, component) => labels[getLabel(container, label, component)]
        )
    else
        dictIterator = labels
    end

    dictIterator
end

function getLabel(
    labelComponent::LabelDict,
    label::IntStrMiss,
    show::OrderedDict{String, Bool},
    headings::String...
)
    if isset(label)
        busLabel = labelComponent
    else
        anyshow = false
        for heading in headings
            if show[heading]
                anyshow = true
                break
            end
        end

        if anyshow
            busLabel = collect(keys(labelComponent))
        else
            busLabel = String[]
        end
    end

    busLabel
end

function isValid(jump::JuMP.Model, constraint::Dict{Int64, ConstraintRef}, i::Int64)
    haskey(constraint, i) && is_valid(jump, constraint[i])
end

##### Print Keywords #####
function printkwargs(;
    fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(),
    delimiter::String = "|",
    title::BoolMiss = missing,
    header::BoolMiss = missing,
    footer::BoolMiss = missing,
    style::Bool = true
)
    return style, delimiter, (fmt = fmt, width = width, show = show,
        title = title, header = header, footer = footer)
end

function summarykwargs(;
    fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(),
    delimiter::String = "|",
    title::Bool = true,
    header::Bool = true,
    footer::Bool = true,
    style::Bool = true
)
    return style, delimiter, (fmt = fmt, width = width, show = show,
        title = title, header = header, footer = footer)
end

function print(
    system::PowerSystem;
    bus::IntStrMiss = missing,
    branch::IntStrMiss = missing,
    generator::IntStrMiss = missing
)
    if isset(bus)
        printBus(system, bus)
    elseif isset(branch)
        printBranch(system, branch)
    elseif isset(generator)
        printGenerator(system, generator)
    end
end

function printBus(system::PowerSystem, bus::IntStr)
    idx = getIndex(system.bus, bus, "bus")
    type = system.bus.layout.type

    println("📁 " * "$bus")
    println("├── 📂 Demand Power")
    println("│   ├── Active: ", system.bus.demand.active[idx])
    println("│   └── Reactive: ", system.bus.demand.reactive[idx])
    println("├── 📂 Supply Power")
    println("│   ├── Active: ", system.bus.supply.active[idx])
    println("│   └── Reactive: ", system.bus.supply.reactive[idx])
    println("├── 📂 Shunt Power")
    println("│   ├── Conductance: ", system.bus.shunt.conductance[idx])
    println("│   └── Susceptance: ", system.bus.shunt.susceptance[idx])
    println("├── 📂 Initial Voltage")
    println("│   ├── Magnitude: ", system.bus.voltage.magnitude[idx])
    println("│   └── Angle: ", system.bus.voltage.angle[idx])
    println("├── 📂 Voltage Magnitude Limit")
    println("│   ├── Minimum: ", system.bus.voltage.minMagnitude[idx])
    println("│   └── Maximum: ", system.bus.voltage.maxMagnitude[idx])
    println("└── 📂 Layout")
    println("    ├── Type: ", type[idx] == 1 ? "demand" : type[idx] == 2 ? "generator" : "slack")
    println("    ├── Area: ", system.bus.layout.area[idx])
    println("    ├── Loss Zone: ", system.bus.layout.lossZone[idx])
    println("    └── Index: ", idx)
end

function printBranch(system::PowerSystem, branch::IntStr)
    idx = getIndex(system.branch, branch, "branch")

    if system.branch.flow.type[idx] == 1
        flowType = "Active Power Limit"
    elseif system.branch.flow.type[idx] in (2, 3)
        flowType = "Apparent Power Limit"
    elseif system.branch.flow.type[idx] in (4, 5)
        flowType = "Current Magnitude Limit"
    end

    println("📁 " * "$branch")
    println("├── 📂 Parameter")
    println("│   ├── Resistance: ", system.branch.parameter.resistance[idx])
    println("│   ├── Reactance: ", system.branch.parameter.reactance[idx])
    println("│   ├── Conductance: ", system.branch.parameter.conductance[idx])
    println("│   ├── Susceptance: ", system.branch.parameter.susceptance[idx])
    println("│   ├── Turns Ratio: ", system.branch.parameter.turnsRatio[idx])
    println("│   └── Phase Shift Angle: ", system.branch.parameter.shiftAngle[idx])
    println("├── 📂 " * flowType)
    println("│   ├── From-Bus Minimum: ", system.branch.flow.minFromBus[idx])
    println("│   ├── From-Bus Maximum: ", system.branch.flow.maxFromBus[idx])
    println("│   ├── To-Bus Minimum: ", system.branch.flow.minToBus[idx])
    println("│   ├── To-Bus Maximum: ", system.branch.flow.maxToBus[idx])
    println("├── 📂 Voltage Angle Difference Limit")
    println("│   ├── Minimum: ", system.branch.voltage.minDiffAngle[idx])
    println("│   └── Maximum: ", system.branch.voltage.maxDiffAngle[idx])
    println("└── 📂 Layout")
    println("    ├── From-Bus: ", getLabel(system.bus.label, system.branch.layout.from[idx]))
    println("    ├── To-Bus: ", getLabel(system.bus.label, system.branch.layout.to[idx]))
    println("    ├── Status: ", system.branch.layout.status[idx])
    println("    └── Index: ", idx)
end

function printGenerator(system::PowerSystem, generator::IntStr)
    idx = getIndex(system.generator, generator, "generator")

    p = system.generator.cost.active
    q = system.generator.cost.reactive
    c = system.generator.capability

    println("📁 " * "$generator")
    println("├── 📂 Output Power")
    println("│   ├── Active: ", system.generator.output.active[idx])
    println("│   └── Reactive: ", system.generator.output.reactive[idx])
    println("├── 📂 Output Power Limit")
    println("│   ├── Minimum Active: ", c.minActive[idx])
    println("│   ├── Maximum Active: ", c.maxActive[idx])
    println("│   ├── Minimum Reactive: ", c.minReactive[idx])
    println("│   └── Maximum Reactive: ", c.maxReactive[idx])

    if any(x -> x != 0, (
        c.lowActive[idx], c.minLowReactive[idx], c.maxLowReactive[idx],
        c.upActive[idx], c.minUpReactive[idx], c.maxUpReactive[idx]))

        println("├── 📂 Capability Curve")
        println("│   ├── Low Active: ", c.lowActive[idx])
        println("│   ├── Minimum Reactive: ", c.minLowReactive[idx])
        println("│   ├── Maximum Reactive: ", c.maxLowReactive[idx])
        println("│   ├── Up Active: ", c.upActive[idx])
        println("│   ├── Minimum Reactive: ", c.minUpReactive[idx])
        println("│   └── Maximum Reactive: ", c.maxUpReactive[idx])
    end

    println("├── 📂 Voltage")
    println("│   └── Magnitude: ", system.generator.voltage.magnitude[idx])

    if haskey(p.polynomial, idx) || haskey(p.piecewise, idx)
        println("├── 📂 Active Power Cost")
        println("│   ├── Polynomial: ", get(p.polynomial, idx, "undefined"))
        println("│   ├── Piecewise: ", get(p.piecewise, idx, "undefined"))
        println("│   ├── In-Use: ", p.model[idx] == 1 ? "piecewise" : p.model[idx] == 2 ? "polynomial" : "undefined")
    end

    if haskey(q.polynomial, idx) || haskey(q.piecewise, idx)
        println("├── 📂 Reactive Power Cost")
        println("│   ├── Polynomial: ", get(q.polynomial, idx, "undefined"))
        println("│   ├── Piecewise: ", get(q.piecewise, idx, "undefined"))
        println("│   ├── In-Use: ", q.model[idx] == 1 ? "piecewise" : q.model[idx] == 2 ? "polynomial" : "undefined")
    end

    println("└── 📂 Layout")
    println("    ├── Bus: ", getLabel(system.bus.label, system.generator.layout.bus[idx]))
    println("    ├── Status: ", system.generator.layout.status[idx])
    println("    └── Index: ", idx)
end