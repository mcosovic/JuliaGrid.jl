"""
    printBusData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `repeat`: Prints the header again after a specified number of lines have been printed.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBusData`](@ref printBusData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

# Print data for all buses
fmt = Dict("Power Demand" => "%.2f", "Voltage Magnitude" => "%.2f", "Label" => "%s")
show = Dict("Power Injection" => false, "Power Generation Reactive" => false)
printBusData(system, analysis; fmt, show, repeat = 10)

# Print data for specific buses
delimiter = " "
width = Dict("Voltage" => 9, "Power Injection Active" => 9)
printBusData(system, analysis; label = 2, delimiter, width, title = true, header = true)
printBusData(system, analysis; label = 10, delimiter, width)
printBusData(system, analysis; label = 12, delimiter, width)
printBusData(system, analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBusData(system::PowerSystem, analysis::AC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.bus.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.bus, system.bus.label, label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = busPrint(system, analysis, unitList, prefix, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Bus Data")

        @inbounds for (label, i) in labels
            scaleVoltg = scaleVoltage(prefix, system, i)
            scaleCurrt = scaleCurrent(prefix, system, i)

            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Bus")

            printf(io, pfmt, width, show, i, scaleVoltg, analysis.voltage.magnitude, "Voltage Magnitude")
            printf(io, pfmt, width, show, i, scale["θ"], analysis.voltage.angle, "Voltage Angle")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.supply.active, "Power Generation Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.supply.reactive, "Power Generation Reactive")
            printf(io, pfmt, width, show, i, scale["P"], system.bus.demand.active, "Power Demand Active")
            printf(io, pfmt, width, show, i, scale["Q"], system.bus.demand.reactive, "Power Demand Reactive")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.injection.active, "Power Injection Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.injection.reactive, "Power Injection Reactive")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.shunt.active, "Shunt Power Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.shunt.reactive, "Shunt Power Reactive")
            printf(io, pfmt, width, show, i, scaleCurrt, analysis.current.injection.magnitude, "Current Injection Magnitude")
            printf(io, pfmt, width, show, i, scale["ψ"], analysis.current.injection.angle, "Current Injection Angle")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function busPrint(system::PowerSystem, analysis::AC, unitList::UnitList, prefix::PrefixLive, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current

    _show = OrderedDict(
        "Label"             => true,
        "Voltage"           => true,
        "Power Generation"  => true,
        "Power Demand"      => true,
        "Power Injection"   => true,
        "Shunt Power"       => true,
        "Current Injection" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Bus"                   => _header_("Bus", "Bus Label", style),
        "Voltage Magnitude"           => _header_("Magnitude", "Voltage Magnitude", style),
        "Voltage Angle"               => _header_("Angle", "Voltage Angle", style),
        "Power Generation Active"     => _header_("Active", "Active Power Generation", style),
        "Power Generation Reactive"   => _header_("Reactive", "Reactive Power Generation", style),
        "Power Demand Active"         => _header_("Active", "Active Power Demand", style),
        "Power Demand Reactive"       => _header_("Reactive", "Reactive Power Demand", style),
        "Power Injection Active"      => _header_("Active", "Active Power Injection", style),
        "Power Injection Reactive"    => _header_("Reactive", "Reactive Power Injection", style),
        "Shunt Power Active"          => _header_("Active", "Shunt Active Power", style),
        "Shunt Power Reactive"        => _header_("Reactive", "Shunt Reactive Power", style),
        "Current Injection Magnitude" => _header_("Magnitude", "Current Injection Magnitude", style),
        "Current Injection Angle"     => _header_("Angle", "Current Injection Angle", style)
    )
    unit = Dict(
        "Label Bus"                   => "",
        "Voltage Magnitude"           => "[$(unitList.voltageMagnitudeLive)]",
        "Voltage Angle"               => "[$(unitList.voltageAngleLive)]",
        "Power Generation Active"     => "[$(unitList.activePowerLive)]",
        "Power Generation Reactive"   => "[$(unitList.reactivePowerLive)]",
        "Power Demand Active"         => "[$(unitList.activePowerLive)]",
        "Power Demand Reactive"       => "[$(unitList.reactivePowerLive)]",
        "Power Injection Active"      => "[$(unitList.activePowerLive)]",
        "Power Injection Reactive"    => "[$(unitList.reactivePowerLive)]",
        "Shunt Power Active"          => "[$(unitList.activePowerLive)]",
        "Shunt Power Reactive"        => "[$(unitList.reactivePowerLive)]",
        "Current Injection Magnitude" => "[$(unitList.currentMagnitudeLive)]",
        "Current Injection Angle"     => "[$(unitList.currentAngleLive)]"
    )
    _fmt = Dict(
        "Label Bus"                   => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Voltage Magnitude"           => _fmt_(_fmt["Voltage"]),
        "Voltage Angle"               => _fmt_(_fmt["Voltage"]),
        "Power Generation Active"     => _fmt_(_fmt["Power Generation"]),
        "Power Generation Reactive"   => _fmt_(_fmt["Power Generation"]),
        "Power Demand Active"         => _fmt_(_fmt["Power Demand"]),
        "Power Demand Reactive"       => _fmt_(_fmt["Power Demand"]),
        "Power Injection Active"      => _fmt_(_fmt["Power Injection"]),
        "Power Injection Reactive"    => _fmt_(_fmt["Power Injection"]),
        "Shunt Power Active"          => _fmt_(_fmt["Shunt Power"]),
        "Shunt Power Reactive"        => _fmt_(_fmt["Shunt Power"]),
        "Current Injection Magnitude" => _fmt_(_fmt["Current Injection"]),
        "Current Injection Angle"     => _fmt_(_fmt["Current Injection"])
    )
    _width = Dict(
        "Label Bus"                   => _width_(_width["Label"], 5, style),
        "Voltage Magnitude"           => _width_(_width["Voltage"], 9, style),
        "Voltage Angle"               => _width_(_width["Voltage"], 5, style),
        "Power Generation Active"     => _width_(_width["Power Generation"], 6, style),
        "Power Generation Reactive"   => _width_(_width["Power Generation"], 8, style),
        "Power Demand Active"         => _width_(_width["Power Demand"], 6, style),
        "Power Demand Reactive"       => _width_(_width["Power Demand"], 8, style),
        "Power Injection Active"      => _width_(_width["Power Injection"], 6, style),
        "Power Injection Reactive"    => _width_(_width["Power Injection"], 8, style),
        "Shunt Power Active"          => _width_(_width["Shunt Power"], 6, style),
        "Shunt Power Reactive"        => _width_(_width["Shunt Power"], 8, style),
        "Current Injection Magnitude" => _width_(_width["Current Injection"], 9, style),
        "Current Injection Angle"     => _width_(_width["Current Injection"], 5, style)
    )
    _show = OrderedDict(
        "Label Bus"                   => _show_(_show["Label"], true),
        "Voltage Magnitude"           => _show_(_show["Voltage"], voltage.magnitude),
        "Voltage Angle"               => _show_(_show["Voltage"], voltage.angle),
        "Power Generation Active"     => _show_(_show["Power Generation"], power.supply.active),
        "Power Generation Reactive"   => _show_(_show["Power Generation"], power.supply.reactive),
        "Power Demand Active"         => _show_(_show["Power Demand"], power.injection.active),
        "Power Demand Reactive"       => _show_(_show["Power Demand"], power.injection.reactive),
        "Power Injection Active"      => _show_(_show["Power Injection"], power.injection.active),
        "Power Injection Reactive"    => _show_(_show["Power Injection"], power.injection.reactive),
        "Shunt Power Active"          => _show_(_show["Shunt Power"], power.shunt.active),
        "Shunt Power Reactive"        => _show_(_show["Shunt Power"], power.shunt.reactive),
        "Current Injection Magnitude" => _show_(_show["Current Injection"], current.injection.magnitude),
        "Current Injection Angle"     => _show_(_show["Current Injection"], current.injection.angle)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            scaleVoltg = scaleVoltage(prefix, system, i)
            scaleCurrt = scaleCurrent(prefix, system, i)

            fmax(width, show, label, "Label Bus")

            fmax(fmt, width, show, i, scaleVoltg, voltage.magnitude, "Voltage Magnitude")
            fmax(fmt, width, show, i, scale["θ"], voltage.angle, "Voltage Angle")
            fmax(fmt, width, show, i, scale["P"], power.supply.active, "Power Generation Active")
            fmax(fmt, width, show, i, scale["Q"], power.supply.reactive, "Power Generation Reactive")
            fmax(fmt, width, show, i, scale["P"], system.bus.demand.active, "Power Demand Active")
            fmax(fmt, width, show, i, scale["Q"], system.bus.demand.reactive, "Power Demand Reactive")
            fmax(fmt, width, show, i, scale["P"], power.injection.active, "Power Injection Active")
            fmax(fmt, width, show, i, scale["Q"], power.injection.reactive, "Power Injection Reactive")
            fmax(fmt, width, show, i, scale["P"], power.shunt.active, "Shunt Power Active")
            fmax(fmt, width, show, i, scale["Q"], power.shunt.reactive, "Shunt Power Reactive")
            fmax(fmt, width, show, i, scaleCurrt, current.injection.magnitude, "Current Injection Magnitude")
            fmax(fmt, width, show, i, scale["ψ"], current.injection.angle, "Current Injection Angle")
        else
            fmax(width, show, system.bus.label, "Label Bus")

            fminmax(fmt, width, show, scale["θ"], voltage.angle, "Voltage Angle")
            fminmax(fmt, width, show, scale["P"], power.supply.active, "Power Generation Active")
            fminmax(fmt, width, show, scale["Q"], power.supply.reactive, "Power Generation Reactive")
            fminmax(fmt, width, show, scale["P"], system.bus.demand.active, "Power Demand Active")
            fminmax(fmt, width, show, scale["Q"], system.bus.demand.reactive, "Power Demand Reactive")
            fminmax(fmt, width, show, scale["P"], power.injection.active, "Power Injection Active")
            fminmax(fmt, width, show, scale["Q"], power.injection.reactive, "Power Injection Reactive")
            fminmax(fmt, width, show, scale["P"], power.shunt.active, "Shunt Power Active")
            fminmax(fmt, width, show, scale["Q"], power.shunt.reactive, "Shunt Power Reactive")
            fminmax(fmt, width, show, scale["ψ"], current.injection.angle, "Current Injection Angle")

            maxV = -Inf; maxI = -Inf
            @inbounds for (label, i) in system.bus.label
                if prefix.voltageMagnitude != 0.0
                    scale = scaleVoltage(system, prefix, i)
                    maxV = fmax(show, i, scale, maxV, voltage.magnitude, "Voltage Magnitude")
                end
                if prefix.currentMagnitude != 0.0
                    scale = scaleCurrent(system, prefix, i)
                    maxI = fmax(show, i, scale, maxI, current.injection.magnitude, "Current Injection Magnitude")
                end
            end

            if prefix.voltageMagnitude == 0.0
                fmax(fmt, width, show, voltage.magnitude, "Voltage Magnitude")
            else
                fmax(fmt, width, show, maxV, "Voltage Magnitude")
            end
            if prefix.currentMagnitude == 0.0
                fmax(fmt, width, show, current.injection.magnitude, "Current Injection Magnitude")
            else
                fmax(fmt, width, show, maxI, "Current Injection Magnitude")
            end
        end
    end
    printing = howManyPrint(width, show, title, style, "Bus Data")

    heading = OrderedDict(
        "Label"             => _blank_(width, show, "Label Bus"),
        "Voltage"           => _blank_(width, show, style, "Voltage", "Voltage Magnitude", "Voltage Angle"),
        "Power Generation"  => _blank_(width, show, style, "Power Generation", "Power Generation Active", "Power Generation Reactive"),
        "Power Demand"      => _blank_(width, show, style, "Power Demand", "Power Demand Active", "Power Demand Reactive"),
        "Power Injection"   => _blank_(width, show, style, "Power Injection", "Power Injection Active", "Power Injection Reactive"),
        "Shunt Power"       => _blank_(width, show, style, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive"),
        "Current Injection" => _blank_(width, show, style, "Current Injection", "Current Injection Magnitude", "Current Injection Angle")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printBusData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.bus.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.bus, system.bus.label, label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = busPrint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Bus Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Bus")

            printf(io, pfmt, width, show, i, scale["θ"], analysis.voltage.angle, "Voltage Angle")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.supply.active, "Power Generation Active")
            printf(io, pfmt, width, show, i, scale["P"], system.bus.demand.active, "Power Demand Active")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.injection.active, "Power Injection Active")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function busPrint(system::PowerSystem, analysis::DC, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    power = analysis.power

    _show = OrderedDict(
        "Label"            => true,
        "Voltage"          => true,
        "Power Generation" => true,
        "Power Demand"     => true,
        "Power Injection"  => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Bus"               => _header_("Bus", "Bus Label", style),
        "Voltage Angle"           => _header_("Angle", "Voltage Angle", style),
        "Power Generation Active" => _header_("Active", "Active Power Generation", style),
        "Power Demand Active"     => _header_("Active", "Active Power Demand", style),
        "Power Injection Active"  => _header_("Active", "Active Power Injection", style)
    )
    unit = Dict(
        "Label Bus"               => "",
        "Voltage Angle"           => "[$(unitList.voltageAngleLive)]",
        "Power Generation Active" => "[$(unitList.activePowerLive)]",
        "Power Demand Active"     => "[$(unitList.activePowerLive)]",
        "Power Injection Active"  => "[$(unitList.activePowerLive)]"
    )
    _fmt = Dict(
        "Label Bus"               => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Voltage Angle"           => _fmt_(_fmt["Voltage"]),
        "Power Generation Active" => _fmt_(_fmt["Power Generation"]),
        "Power Demand Active"     => _fmt_(_fmt["Power Demand"]),
        "Power Injection Active"  => _fmt_(_fmt["Power Injection"])
    )
    _width = Dict(
        "Label Bus"               => _width_(_width["Label"], 5, style),
        "Voltage Angle"           => _width_(_width["Voltage"], 7, style),
        "Power Generation Active" => _width_(_width["Power Generation"], 16, style),
        "Power Demand Active"     => _width_(_width["Power Demand"], 12, style),
        "Power Injection Active"  => _width_(_width["Power Injection"], 15, style)
    )
    _show = OrderedDict(
        "Label Bus"               => _show_(_show["Label"], true),
        "Voltage Angle"           => _show_(_show["Voltage"], voltage.angle),
        "Power Generation Active" => _show_(_show["Power Generation"], power.supply.active),
        "Power Demand Active"     => _show_(_show["Power Demand"], power.injection.active),
        "Power Injection Active"  => _show_(_show["Power Injection"], power.injection.active)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            fmax(width, show, label, "Label Bus")
            fmax(fmt, width, show, i, scale["θ"], voltage.angle, "Voltage Angle")
            fmax(fmt, width, show, i, scale["P"], power.supply.active, "Power Generation Active")
            fmax(fmt, width, show, i, scale["P"], system.bus.demand.active, "Power Demand Active")
            fmax(fmt, width, show, i, scale["P"], power.injection.active, "Power Injection Active")
        else
            fmax(width, show, system.bus.label, "Label Bus")
            fminmax(fmt, width, show, scale["θ"], voltage.angle, "Voltage Angle")
            fminmax(fmt, width, show, scale["P"], power.supply.active, "Power Generation Active")
            fminmax(fmt, width, show, scale["P"], system.bus.demand.active, "Power Demand Active")
            fminmax(fmt, width, show, scale["P"], power.injection.active, "Power Injection Active")
        end
    end
    printing = howManyPrint(width, show, title, style, "Bus Data")

    heading = OrderedDict(
        "Label"             => _blank_(width, show, "Label Bus"),
        "Voltage"           => _blank_(width, show, "Voltage Angle"),
        "Power Generation"  => _blank_(width, show, "Power Generation Active"),
        "Power Demand"      => _blank_(width, show, "Power Demand Active"),
        "Power Injection"   => _blank_(width, show, "Power Injection Active")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

"""
    printBranchData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `repeat`: Prints the header again after a specified number of lines have been printed.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBranchData`](@ref printBranchData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

# Print data for all branches
fmt = Dict("Shunt Power" => "%.2f", "Series Power Reactive" => "%.2f")
show = Dict("From-Bus Power" => false, "To-Bus Power Reactive" => false)
printBranchData(system, analysis; fmt, show, repeat = 11, title = false)

# Print data for specific branches
delimiter = " "
width = Dict("From-Bus Power" => 9, "To-Bus Power Active" => 9)
printBranchData(system, analysis; label = 2, delimiter, width, header = true)
printBranchData(system, analysis; label = 10, delimiter, width)
printBranchData(system, analysis; label = 12, delimiter, width)
printBranchData(system, analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBranchData(system::PowerSystem, analysis::AC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.branch.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.branch, system.branch.label, label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, buses, printing = branchPrint(system, analysis, unitList, prefix, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Branch Data")

        @inbounds for (label, i) in labels
            scaleCurrf = scaleCurrent(prefix, system, system.branch.layout.from[i])
            scaleCurrt = scaleCurrent(prefix, system, system.branch.layout.to[i])

            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Branch")
            printf(io, pfmt, width, show, buses, system.branch.layout.from[i], "Label From-Bus")
            printf(io, pfmt, width, show, buses, system.branch.layout.to[i], "Label To-Bus")

            printf(io, pfmt, width, show, i, scale["P"], analysis.power.from.active, "From-Bus Power Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.from.reactive, "From-Bus Power Reactive")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.to.active, "To-Bus Power Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.to.reactive, "To-Bus Power Reactive")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.charging.active, "Shunt Power Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.charging.reactive, "Shunt Power Reactive")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.series.active, "Series Power Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.series.reactive, "Series Power Reactive")
            printf(io, pfmt, width, show, i, scaleCurrf, analysis.current.from.magnitude, "From-Bus Current Magnitude")
            printf(io, pfmt, width, show, i, scale["ψ"], analysis.current.from.angle, "From-Bus Current Angle")
            printf(io, pfmt, width, show, i, scaleCurrt, analysis.current.to.magnitude, "To-Bus Current Magnitude")
            printf(io, pfmt, width, show, i, scale["ψ"], analysis.current.to.angle, "To-Bus Current Angle")
            printf(io, pfmt, width, show, i, scaleCurrf, analysis.current.series.magnitude, "Series Current Magnitude")
            printf(io, pfmt, width, show, i, scale["ψ"], analysis.current.series.angle, "Series Current Angle")

            printf(io, pfmt, width, show, i, system.branch.layout.status, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function branchPrint(system::PowerSystem, analysis::AC, unitList::UnitList, prefix::PrefixLive, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power
    current = analysis.current

    _show = OrderedDict(
        "Label"            => true,
        "From-Bus Power"   => true,
        "To-Bus Power"     => true,
        "Shunt Power"      => true,
        "Series Power"     => true,
        "From-Bus Current" => true,
        "To-Bus Current"   => true,
        "Series Current"   => true,
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Branch"               => _header_("Branch", "Branch Label", style),
        "Label From-Bus"             => _header_("From-Bus", "From-Bus Label", style),
        "Label To-Bus"               => _header_("To-Bus", "To-Bus Label", style),
        "From-Bus Power Active"      => _header_("Active", "From-Bus Active Power", style),
        "From-Bus Power Reactive"    => _header_("Reactive", "From-Bus Reactive Power", style),
        "To-Bus Power Active"        => _header_("Active", "To-Bus Active Power", style),
        "To-Bus Power Reactive"      => _header_("Reactive", "To-Bus Reactive Power", style),
        "Shunt Power Active"         => _header_("Active", "Shunt Active Power", style),
        "Shunt Power Reactive"       => _header_("Reactive", "Shunt Reactive Power", style),
        "Series Power Active"        => _header_("Active", "Series Active Power", style),
        "Series Power Reactive"      => _header_("Reactive", "Series Reactive Power", style),
        "From-Bus Current Magnitude" => _header_("Magnitude", "From-Bus Current Magnitude", style),
        "From-Bus Current Angle"     => _header_("Angle", "From-Bus Current Angle", style),
        "To-Bus Current Magnitude"   => _header_("Magnitude", "To-Bus Current Magnitude", style),
        "To-Bus Current Angle"       => _header_("Angle", "To-Bus Current Angle", style),
        "Series Current Magnitude"   => _header_("Magnitude", "Series Current Magnitude", style),
        "Series Current Angle"       => _header_("Angle", "Series Current Angle", style),
        "Status"                     => _header_("", "Status", style),
    )
    unit = Dict(
        "Label Branch"               => "",
        "Label From-Bus"             => "",
        "Label To-Bus"               => "",
        "From-Bus Power Active"      => "[$(unitList.activePowerLive)]",
        "From-Bus Power Reactive"    => "[$(unitList.reactivePowerLive)]",
        "To-Bus Power Active"        => "[$(unitList.activePowerLive)]",
        "To-Bus Power Reactive"      => "[$(unitList.reactivePowerLive)]",
        "Shunt Power Active"         => "[$(unitList.activePowerLive)]",
        "Shunt Power Reactive"       => "[$(unitList.reactivePowerLive)]",
        "Series Power Active"        => "[$(unitList.activePowerLive)]",
        "Series Power Reactive"      => "[$(unitList.reactivePowerLive)]",
        "From-Bus Current Magnitude" => "[$(unitList.currentMagnitudeLive)]",
        "From-Bus Current Angle"     => "[$(unitList.currentAngleLive)]",
        "To-Bus Current Magnitude"   => "[$(unitList.currentMagnitudeLive)]",
        "To-Bus Current Angle"       => "[$(unitList.currentAngleLive)]",
        "Series Current Magnitude"   => "[$(unitList.currentMagnitudeLive)]",
        "Series Current Angle"       => "[$(unitList.currentAngleLive)]",
        "Status"                     => ""
    )
    _fmt = Dict(
        "Label Branch"               => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label From-Bus"             => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label To-Bus"               => _fmt_(_fmt["Label"]; format = "%-*s"),
        "From-Bus Power Active"      => _fmt_(_fmt["From-Bus Power"]),
        "From-Bus Power Reactive"    => _fmt_(_fmt["From-Bus Power"]),
        "To-Bus Power Active"        => _fmt_(_fmt["To-Bus Power"]),
        "To-Bus Power Reactive"      => _fmt_(_fmt["To-Bus Power"]),
        "Shunt Power Active"         => _fmt_(_fmt["Shunt Power"]),
        "Shunt Power Reactive"       => _fmt_(_fmt["Shunt Power"]),
        "Series Power Active"        => _fmt_(_fmt["Series Power"]),
        "Series Power Reactive"      => _fmt_(_fmt["Series Power"]),
        "From-Bus Current Magnitude" => _fmt_(_fmt["From-Bus Current"]),
        "From-Bus Current Angle"     => _fmt_(_fmt["From-Bus Current"]),
        "To-Bus Current Magnitude"   => _fmt_(_fmt["To-Bus Current"]),
        "To-Bus Current Angle"       => _fmt_(_fmt["To-Bus Current"]),
        "Series Current Magnitude"   => _fmt_(_fmt["Series Current"]),
        "Series Current Angle"       => _fmt_(_fmt["Series Current"]),
        "Status"                     => "%*i"
    )
    _width = Dict(
        "Label Branch"               => _width_(_width["Label"], 6, style),
        "Label From-Bus"             => _width_(_width["Label"], 8, style),
        "Label To-Bus"               => _width_(_width["Label"], 6, style),
        "From-Bus Power Active"      => _width_(_width["From-Bus Power"], 6, style),
        "From-Bus Power Reactive"    => _width_(_width["From-Bus Power"], 8, style),
        "To-Bus Power Active"        => _width_(_width["To-Bus Power"], 6, style),
        "To-Bus Power Reactive"      => _width_(_width["To-Bus Power"], 8, style),
        "Shunt Power Active"         => _width_(_width["Shunt Power"], 6, style),
        "Shunt Power Reactive"       => _width_(_width["Shunt Power"], 8, style),
        "Series Power Active"        => _width_(_width["Series Power"], 6, style),
        "Series Power Reactive"      => _width_(_width["Series Power"], 8, style),
        "From-Bus Current Magnitude" => _width_(_width["From-Bus Current"], 9, style),
        "From-Bus Current Angle"     => _width_(_width["From-Bus Current"], 5, style),
        "To-Bus Current Magnitude"   => _width_(_width["To-Bus Current"], 9, style),
        "To-Bus Current Angle"       => _width_(_width["To-Bus Current"], 5, style),
        "Series Current Magnitude"   => _width_(_width["Series Current"], 9, style),
        "Series Current Angle"       => _width_(_width["Series Current"], 5, style),
        "Status"                     => 6 * style
    )
    _show = OrderedDict(
        "Label Branch"               => _show_(_show["Label"], true),
        "Label From-Bus"             => _show_(_show["Label"], true),
        "Label To-Bus"               => _show_(_show["Label"], true),
        "From-Bus Power Active"      => _show_(_show["From-Bus Power"], power.from.active),
        "From-Bus Power Reactive"    => _show_(_show["From-Bus Power"], power.from.reactive),
        "To-Bus Power Active"        => _show_(_show["To-Bus Power"], power.to.active),
        "To-Bus Power Reactive"      => _show_(_show["To-Bus Power"], power.to.reactive),
        "Shunt Power Active"         => _show_(_show["Shunt Power"], power.charging.active),
        "Shunt Power Reactive"       => _show_(_show["Shunt Power"], power.charging.reactive),
        "Series Power Active"        => _show_(_show["Series Power"], power.series.active),
        "Series Power Reactive"      => _show_(_show["Series Power"], power.series.reactive),
        "From-Bus Current Magnitude" => _show_(_show["From-Bus Current"], current.from.magnitude),
        "From-Bus Current Angle"     => _show_(_show["From-Bus Current"], current.from.angle),
        "To-Bus Current Magnitude"   => _show_(_show["To-Bus Current"], current.to.magnitude),
        "To-Bus Current Angle"       => _show_(_show["To-Bus Current"], current.to.angle),
        "Series Current Magnitude"   => _show_(_show["Series Current"], current.series.magnitude),
        "Series Current Angle"       => _show_(_show["Series Current"], current.series.angle),
        "Status"                     => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    buses = getLabel(system.bus.label, label, show, "Label From-Bus", "Label To-Bus")
    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            scaleCurrf = scaleCurrent(prefix, system, system.branch.layout.from[i])
            scaleCurrt = scaleCurrent(prefix, system, system.branch.layout.to[i])

            fmax(width, show, label, "Label Branch")
            fmax(width, show, getLabel(buses, system.branch.layout.from[i]), "Label From-Bus")
            fmax(width, show, getLabel(buses, system.branch.layout.to[i]), "Label To-Bus")

            fmax(fmt, width, show, i, scale["P"], power.from.active, "From-Bus Power Active")
            fmax(fmt, width, show, i, scale["Q"], power.from.reactive,"From-Bus Power Reactive")
            fmax(fmt, width, show, i, scale["P"], power.to.active, "To-Bus Power Active")
            fmax(fmt, width, show, i, scale["Q"], power.to.reactive, "To-Bus Power Reactive")
            fmax(fmt, width, show, i, scale["P"], power.charging.active, "Shunt Power Active")
            fmax(fmt, width, show, i, scale["Q"], power.charging.reactive, "Shunt Power Reactive")
            fmax(fmt, width, show, i, scale["P"], power.series.active, "Series Power Active")
            fmax(fmt, width, show, i, scale["Q"], power.series.reactive, "Series Power Reactive")
            fmax(fmt, width, show, i, scaleCurrf, current.from.magnitude, "From-Bus Current Magnitude")
            fmax(fmt, width, show, i, scale["ψ"], current.from.angle, "From-Bus Current Angle")
            fmax(fmt, width, show, i, scaleCurrt, current.to.magnitude, "To-Bus Current Magnitude")
            fmax(fmt, width, show, i, scale["ψ"], current.to.angle, "To-Bus Current Angle")
            fmax(fmt, width, show, i, scaleCurrt, current.series.magnitude, "Series Current Magnitude")
            fmax(fmt, width, show, i, scale["ψ"], current.series.angle, "Series Current Angle")
        else
            fmax(width, show, system.branch.label, "Label Branch")
            fmax(width, show, buses, "Label From-Bus", "Label To-Bus")

            fminmax(fmt, width, show, scale["P"], power.from.active, "From-Bus Power Active")
            fminmax(fmt, width, show, scale["Q"], power.from.reactive, "From-Bus Power Reactive")
            fminmax(fmt, width, show, scale["P"], power.to.active, "To-Bus Power Active")
            fminmax(fmt, width, show, scale["Q"], power.to.reactive, "To-Bus Power Reactive")
            fminmax(fmt, width, show, scale["P"], power.charging.active, "Shunt Power Active")
            fminmax(fmt, width, show, scale["Q"], power.charging.reactive, "Shunt Power Reactive")
            fminmax(fmt, width, show, scale["P"], power.series.active, "Series Power Active")
            fminmax(fmt, width, show, scale["Q"], power.series.reactive, "Series Power Reactive")
            fminmax(fmt, width, show, scale["ψ"], current.from.angle, "From-Bus Current Angle")
            fminmax(fmt, width, show, scale["ψ"], current.to.angle, "To-Bus Current Angle")
            fminmax(fmt, width, show, scale["ψ"], current.series.angle, "Series Current Angle")

            if prefix.currentMagnitude == 0.0
                fmax(fmt, width, show, current.from.magnitude, "From-Bus Current Magnitude")
                fmax(fmt, width, show, current.to.magnitude, "To-Bus Current Magnitude")
                fmax(fmt, width, show, current.series.magnitude, "Series Current Magnitude")
            else
                maxF = -Inf; maxT = -Inf; maxS = -Inf
                @inbounds for (label, i) in system.branch.label
                    currf = scaleCurrent(system, prefix, system.branch.layout.from[i])
                    currt = scaleCurrent(system, prefix, system.branch.layout.to[i])

                    maxF = fmax(show, i, currf, maxF, current.from.magnitude, "From-Bus Current Magnitude")
                    maxT = fmax(show, i, currt, maxT, current.to.magnitude, "To-Bus Current Magnitude")
                    maxS = fmax(show, i, currf, maxS, current.series.magnitude, "Series Current Magnitude")
                end
                fmax(fmt, width, show, maxF, "From-Bus Current Magnitude")
                fmax(fmt, width, show, maxT, "To-Bus Current Magnitude")
                fmax(fmt, width, show, maxS, "Series Current Magnitude")
            end
        end
    end
    printing = howManyPrint(width, show, title, style, "Branch Data")

    heading = OrderedDict(
        "Label"            => _blank_(width, show, "Label Branch", "Label From-Bus", "Label To-Bus"),
        "From-Bus Power"   => _blank_(width, show, style, "From-Bus Power", "From-Bus Power Active", "From-Bus Power Reactive"),
        "To-Bus Power"     => _blank_(width, show, style, "To-Bus Power", "To-Bus Power Active", "To-Bus Power Reactive"),
        "Shunt Power"      => _blank_(width, show, style, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive"),
        "Series Power"     => _blank_(width, show, style, "Series Power", "Series Power Active", "Series Power Reactive"),
        "From-Bus Current" => _blank_(width, show, style, "From-Bus Current", "From-Bus Current Magnitude", "From-Bus Current Angle"),
        "To-Bus Current"   => _blank_(width, show, style, "To-Bus Current", "To-Bus Current Magnitude", "To-Bus Current Angle"),
        "Series Current"   => _blank_(width, show, style, "Series Current", "Series Current Magnitude", "Series Current Angle"),
        "Status"           => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, buses, printing
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.branch.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.branch, system.branch.label, label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, buses, printing = branchPrint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Branch Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Branch")
            printf(io, pfmt, width, show, buses, system.branch.layout.from[i], "Label From-Bus")
            printf(io, pfmt, width, show, buses, system.branch.layout.to[i], "Label To-Bus")

            printf(io, pfmt, width, show, i, scale["P"], analysis.power.from.active, "From-Bus Power Active")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.to.active, "To-Bus Power Active")
            printf(io, pfmt, width, show, i, system.branch.layout.status, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function branchPrint(system::PowerSystem, analysis::DC, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power

    _show = OrderedDict(
        "Label"          => true,
        "From-Bus Power" => true,
        "To-Bus Power"   => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Branch"          => _header_("Branch", "Branch Label", style),
        "Label From-Bus"        => _header_("From-Bus", "From-Bus Label", style),
        "Label To-Bus"          => _header_("To-Bus", "To-Bus Label", style),
        "From-Bus Power Active" => _header_("Active", "From-Bus Active Power", style),
        "To-Bus Power Active"   => _header_("Active", "To-Bus Active Power", style),
        "Status"                => _header_("", "Status", style),
    )
    unit = Dict(
        "Label Branch"           => "",
        "Label From-Bus"         => "",
        "Label To-Bus"           => "",
        "From-Bus Power Active"  => "[$(unitList.activePowerLive)]",
        "To-Bus Power Active"    => "[$(unitList.activePowerLive)]",
        "Status"                 => ""
    )
    _fmt = Dict(
        "Label Branch"          => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label From-Bus"        => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label To-Bus"          => _fmt_(_fmt["Label"]; format = "%-*s"),
        "From-Bus Power Active" => _fmt_(_fmt["From-Bus Power"]),
        "To-Bus Power Active"   => _fmt_(_fmt["To-Bus Power"]),
        "Status"                => "%*i"
    )
    _width = Dict(
        "Label Branch"          => _width_(_width["Label"], 6, style),
        "Label From-Bus"        => _width_(_width["Label"], 8, style),
        "Label To-Bus"          => _width_(_width["Label"], 6, style),
        "From-Bus Power Active" => _width_(_width["From-Bus Power"], 14, style),
        "To-Bus Power Active"   => _width_(_width["To-Bus Power"], 12, style),
        "Status"                => 6 * style
    )
    _show = OrderedDict(
        "Label Branch"          => _show_(_show["Label"], true),
        "Label From-Bus"        => _show_(_show["Label"], true),
        "Label To-Bus"          => _show_(_show["Label"], true),
        "From-Bus Power Active" => _show_(_show["From-Bus Power"], power.from.active),
        "To-Bus Power Active"   => _show_(_show["To-Bus Power"], power.to.active),
        "Status"                => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    buses = getLabel(system.bus.label, label, show, "Label From-Bus", "Label To-Bus")
    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            fmax(width, show, label, "Label Branch")
            fmax(width, show, getLabel(buses, system.branch.layout.from[i]), "Label From-Bus")
            fmax(width, show, getLabel(buses, system.branch.layout.to[i]), "Label To-Bus")

            fmax(fmt, width, show, i, scale["P"],  power.from.active, "From-Bus Power Active")
            fmax(fmt, width, show, i, scale["P"], power.to.active, "To-Bus Power Active")
        else
            fmax(width, show, system.branch.label, "Label Branch")
            fmax(width, show, buses, "Label From-Bus", "Label To-Bus")

            fminmax(fmt, width, show, scale["P"], power.from.active, "From-Bus Power Active")
            fminmax(fmt, width, show, scale["P"], power.to.active, "To-Bus Power Active")
        end
    end
    printing = howManyPrint(width, show, title, style, "Branch Data")

    heading = OrderedDict(
        "Label"          => _blank_(width, show, "Label Branch", "Label From-Bus", "Label To-Bus"),
        "From-Bus Power" => _blank_(width, show, "From-Bus Power Active"),
        "To-Bus Power"   => _blank_(width, show, "To-Bus Power Active"),
        "Status"         => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, buses, printing
end

"""
    printGeneratorData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `repeat`: Prints the header again after a specified number of lines have been printed.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printGeneratorData`](@ref printGeneratorData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

# Print data for all generators
fmt = Dict("Power Output Active" => "%.2f")
show = Dict("Power Output Reactive" => false)
printGeneratorData(system, analysis; fmt, show, title = false)

# Print data for specific generators
delimiter = " "
width = Dict("Power Output Active" => 7)
printGeneratorData(system, analysis; label = 1, delimiter, width, header = true)
printGeneratorData(system, analysis; label = 4, delimiter, width)
printGeneratorData(system, analysis; label = 5, delimiter, width, footer = true)
```
"""
function printGeneratorData(system::PowerSystem, analysis::AC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.generator.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.generator, system.generator.label, label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, buses, printing = generatorPrint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Generator Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Generator")

            printf(io, pfmt, width, show, buses, system.generator.layout.bus[i], "Label Bus")
            printf(io, pfmt, width, show, i, scale["P"], analysis.power.generator.active, "Power Output Active")
            printf(io, pfmt, width, show, i, scale["Q"], analysis.power.generator.reactive, "Power Output Reactive")
            printf(io, pfmt, width, show, i, system.branch.layout.status, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function generatorPrint(system::PowerSystem, analysis::AC, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power

    _show = OrderedDict(
        "Label"        => true,
        "Power Output" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Generator"       => _header_("Generator", "Generator Label", style),
        "Label Bus"             => _header_("Bus", "Bus Label", style),
        "Power Output Active"   => _header_("Active", "Active Power Output", style),
        "Power Output Reactive" => _header_("Reactive", "Reactive Power Output", style),
        "Status"                => _header_("", "Status", style),
    )
    unit = Dict(
        "Label Generator"       => "",
        "Label Bus"             => "",
        "Power Output Active"   => "[$(unitList.activePowerLive)]",
        "Power Output Reactive" => "[$(unitList.reactivePowerLive)]",
        "Status"                => ""
    )
    _fmt = Dict(
        "Label Generator"       => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label Bus"             => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Power Output Active"   => _fmt_(_fmt["Power Output"]),
        "Power Output Reactive" => _fmt_(_fmt["Power Output"]),
        "Status"                => "%*i"
    )
    _width = Dict(
        "Label Generator"       => _width_(_width["Label"], 9, style),
        "Label Bus"             => _width_(_width["Label"], 3, style),
        "Power Output Active"   => _width_(_width["Power Output"], 6, style),
        "Power Output Reactive" => _width_(_width["Power Output"], 8, style),
        "Status"                => 6 * style
    )
    _show = OrderedDict(
        "Label Generator"       => _show_(_show["Label"], true),
        "Label Bus"             => _show_(_show["Label"], true),
        "Power Output Active"   => _show_(_show["Power Output"], power.generator.active),
        "Power Output Reactive" => _show_(_show["Power Output"], power.generator.reactive),
        "Status"                => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    buses = getLabel(system.bus.label, label, show, "Label Bus")
    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, "Label Generator")
            fmax(width, show, getLabel(buses, system.generator.layout.bus[i]), "Label Bus")

            fmax(fmt, width, show, i, scale["P"], power.generator.active, "Power Output Active")
            fmax(fmt, width, show, i, scale["Q"], power.generator.reactive, "Power Output Reactive")
        else
            fmax(width, show, system.generator.label, "Label Generator")
            fmax(width, show, buses, "Label Bus")

            fminmax(fmt, width, show, scale["P"], power.generator.active, "Power Output Active")
            fminmax(fmt, width, show, scale["Q"], power.generator.reactive, "Power Output Reactive")
        end
    end
    printing = howManyPrint(width, show, title, style, "Generator Data")

    heading = OrderedDict(
        "Label"        => _blank_(width, show, "Label Generator", "Label Bus"),
        "Power Output" => _blank_(width, show, style, "Power Output", "Power Output Active", "Power Output Reactive"),
        "Status"       => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, buses, printing
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.generator.number + 1)

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.generator, system.generator.label, label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, buses, printing = generatorPrint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Generator Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label Generator")
            printf(io, pfmt, width, show, buses, system.generator.layout.bus[i], "Label Bus")

            printf(io, pfmt, width, show, i, scale["P"], analysis.power.generator.active, "Power Output Active")
            printf(io, pfmt, width, show, i, system.branch.layout.status, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function generatorPrint(system::PowerSystem, analysis::DC, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power

    _show = OrderedDict(
        "Label"        => true,
        "Power Output" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label Generator"     => _header_("Generator", "Generator Label", style),
        "Label Bus"           => _header_("Bus", "Bus Label", style),
        "Power Output Active" => _header_("Active", "Active Power Output", style),
        "Status"              => _header_("", "Status", style),
    )
    unit = Dict(
        "Label Generator"     => "",
        "Label Bus"           => "",
        "Power Output Active" => "[$(unitList.activePowerLive)]",
        "Status"              => ""
    )
    _fmt = Dict(
        "Label Generator"     => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Label Bus"           => _fmt_(_fmt["Label"]; format = "%-*s"),
        "Power Output Active" => _fmt_(_fmt["Power Output"]),
        "Status"              => "%*i"
    )
    _width = Dict(
        "Label Generator"       => _width_(_width["Label"], 9, style),
        "Label Bus"             => _width_(_width["Label"], 3, style),
        "Power Output Active" => _width_(_width["Power Output"], 12, style),
        "Status"              => 6 * style
    )
    _show = OrderedDict(
        "Label Generator"     => _show_(_show["Label"], true),
        "Label Bus"           => _show_(_show["Label"], true),
        "Power Output Active" => _show_(_show["Power Output"], power.generator.active),
        "Status"              => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    buses = getLabel(system.bus.label, label, show, "Label Bus")
    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, "Label Generator")
            fmax(width, show, getLabel(buses, system.generator.layout.bus[i]), "Label Bus")

            fmax(fmt, width, show, i, scale["P"], power.generator.active, "Power Output Active")
        else
            fmax(width, show, system.generator.label, "Label Generator")
            fmax(width, show, buses, "Label Bus")

            fminmax(fmt, width, show, scale["P"], power.generator.active, "Power Output Active")
        end
    end
    printing = howManyPrint(width, show, title, style, "Generator Data")

    heading = OrderedDict(
        "Label"        => _blank_(width, show, "Label Generator", "Label Bus"),
        "Power Output" => _blank_(width, show, "Power Output Active"),
        "Status"       => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, buses, printing
end

"""
    printBusSummary(system::PowerSystem, analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style)

The function prints a summary of the electrical quantities related to buses. Optionally,
an `IO` may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBusSummary`](@ref printBusSummary) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

show = Dict("In-Use" => false)
printBusSummary(system, analysis; show, delimiter = " ", title = false)
```
"""
function printBusSummary(system::PowerSystem, analysis::Union{AC, DC}, io::IO = stdout;
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::Bool = true, header::Bool = true, footer::Bool = true)

    errorVoltage(analysis.voltage.angle)

    scale = scalePrint(system, prefix)
    fmt, width, show, subheading = summaryFormat(fmt, width, show, style)
    type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, cnt = busSummary(system, analysis, unitList, prefix, scale, width, show, title, style)

    if printing
        heading = summaryFormat(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)

        titlePrint(io, delimiter, title, header, style, maxLine, "Bus Summary")
        headerPrint(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        summaryPrint(io, pfmt, hfmt, width, show, type, minLabel, minValue, maxLabel, maxValue, inuse, total, delimiter, footer, style, maxLine, cnt)
    end
end

function busSummary(system::PowerSystem, analysis::AC, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    title::Bool, style::Bool)

    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current
    bus = system.bus

    type = OrderedDict{String, String}()
    if !isempty(voltage.magnitude)
        type["Voltage"] = "Voltage"
        type["Voltage Magnitude"] = " Magnitude [$(unitList.voltageMagnitudeLive)]"
        type["Voltage Angle"] = " Angle [$(unitList.voltageAngleLive)]"
    end
    if !isempty(power.supply.active)
        type["Power Generation"] = "Power Generation"
        type["Power Generation Active"] = " Active [$(unitList.activePowerLive)]"
        type["Power Generation Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.supply.active)
        type["Power Demand"] = "Power Demand"
        type["Power Demand Active"] = " Active [$(unitList.activePowerLive)]"
        type["Power Demand Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.injection.active)
        type["Power Injection"] = "Power Injection"
        type["Power Injection Active"] = " Active [$(unitList.activePowerLive)]"
        type["Power Injection Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.shunt.active)
        type["Shunt Power"] = "Shunt Power"
        type["Shunt Power Active"] = " Active [$(unitList.activePowerLive)]"
        type["Shunt Power Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(current.injection.magnitude)
        type["Current Injection"] = "Current Injection"
        type["Current Injection Magnitude"] = " Magnitude [$(unitList.currentMagnitudeLive)]"
        type["Current Injection Angle"] = " Angle [$(unitList.currentAngleLive)]"
    end
    inuse = Dict{String, Float64}(
        "Voltage"           => bus.number,
        "Power Generation"  => 0.0,
        "Power Demand"      => 0.0,
        "Power Injection"   => bus.number,
        "Shunt Power"       => 0.0,
        "Current Injection" => bus.number,
    )
    total = Dict{String, Float64}(
        "Power Generation Active" => 0.0,
        "Power Generation Reactive" => 0.0,
        "Power Demand Active" => 0.0,
        "Power Demand Reactive" => 0.0,
        "Power Injection Active" => 0.0,
        "Power Injection Reactive" => 0.0,
        "Shunt Power Active" => 0.0,
        "Shunt Power Reactive" => 0.0,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:bus.number
        scaleVoltg = scaleVoltage(prefix, system, i)
        summaryData(minIndex, minValue, maxIndex, maxValue, i, scaleVoltg, voltage.magnitude[i], "Voltage Magnitude")
        summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["θ"], voltage.angle[i], "Voltage Angle")

        if !isempty(bus.supply.generator[i]) && haskey(type, "Power Generation")
            inuse["Power Generation"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.supply.active[i], "Power Generation Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.supply.reactive[i], "Power Generation Reactive")
        end

        if (bus.demand.active[i] != 0.0 || bus.demand.reactive[i] != 0.0) && haskey(type, "Power Demand")
            inuse["Power Demand"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], bus.demand.active[i], "Power Demand Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], bus.demand.reactive[i], "Power Demand Reactive")
        end

        if haskey(type, "Power Injection")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.injection.active[i], "Power Injection Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.injection.reactive[i], "Power Injection Reactive")
        end

        if (bus.shunt.conductance[i] != 0.0 || bus.shunt.susceptance[i] != 0.0) && haskey(type, "Shunt Power")
            inuse["Shunt Power"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.shunt.active[i], "Shunt Power Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.shunt.reactive[i], "Shunt Power Reactive")
        end

        if haskey(type, "Current Injection")
            scaleCurrt = scaleCurrent(prefix, system, i)
            summaryData(minIndex, minValue, maxIndex, maxValue, i, scaleCurrt, current.injection.magnitude[i], "Current Injection Magnitude")
            summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["ψ"], current.injection.angle[i], "Current Injection Angle")
        end
    end
    summaryType(type, inuse)
    summaryLabel(bus.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Bus Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 3
end

function busSummary(system::PowerSystem, analysis::DC, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    title::Bool, style::Bool)

    voltage = analysis.voltage
    power = analysis.power
    bus = system.bus

    type = OrderedDict{String, String}()
    if !isempty(voltage.angle)
        type["Voltage"] = "Voltage"
        type["Voltage Angle"] = " Angle [$(unitList.voltageAngleLive)]"
    end
    if !isempty(power.supply.active)
        type["Power Generation"] = "Power Generation"
        type["Power Generation Active"] = " Active [$(unitList.activePowerLive)]"
    end
    if !isempty(power.supply.active)
        type["Power Demand"] = "Power Demand"
        type["Power Demand Active"] = " Active [$(unitList.activePowerLive)]"
    end
    if !isempty(power.injection.active)
        type["Power Injection"] = "Power Injection"
        type["Power Injection Active"] = " Active [$(unitList.activePowerLive)]"
    end
    inuse = Dict{String, Float64}(
        "Voltage"           => bus.number,
        "Power Generation"  => 0.0,
        "Power Demand"      => 0.0,
        "Power Injection"   => bus.number,
    )
    total = Dict{String, Float64}(
        "Power Generation Active" => 0.0,
        "Power Demand Active" => 0.0,
        "Power Injection Active" => 0.0,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:bus.number
        summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["θ"], voltage.angle[i], "Voltage Angle")

        if power.supply.active[i] != 0.0 && haskey(type, "Power Generation")
            inuse["Power Generation"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.supply.active[i], "Power Generation Active")
        end

        if bus.demand.active[i] != 0.0 && haskey(type, "Power Demand")
            inuse["Power Demand"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], bus.demand.active[i], "Power Demand Active")
        end

        if haskey(type, "Power Injection")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.injection.active[i], "Power Injection Active")
        end
    end
    summaryType(type, inuse)
    summaryLabel(bus.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Bus Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 2
end

"""
    printBranchSummary(system::PowerSystem, analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style))

The function prints a summary of the electrical quantities related to branches. Optionally,
an `IO` may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBranchSummary`](@ref printBranchSummary) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

show = Dict("Total" => false)
printBranchSummary(system, analysis; show, delimiter = " ", title = false)
```
"""
function printBranchSummary(system::PowerSystem, analysis::Union{AC, DC}, io::IO = stdout;
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::Bool = true, header::Bool = true, footer::Bool = true)

    errorVoltage(analysis.voltage.angle)

    scale = scalePrint(system, prefix)
    fmt, width, show, subheading = summaryFormat(fmt, width, show, style)
    type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, cnt = branchSummary(system, analysis, unitList, prefix, scale, width, show, title, style)

    if printing && !isempty(type)
        heading = summaryFormat(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)

        titlePrint(io, delimiter, title, header, style, maxLine, "Branch Summary")
        headerPrint(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        summaryPrint(io, pfmt, hfmt, width, show, type, minLabel, minValue, maxLabel, maxValue, inuse, total, delimiter, footer, style, maxLine, cnt)
    end
end

function branchSummary(system::PowerSystem, analysis::AC, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    title::Bool, style::Bool)

    power = analysis.power
    current = analysis.current
    branch = system.branch

    type = OrderedDict{String, String}()
    if !isempty(power.from.active)
        type["Line From-Bus Power Flow Magnitude"] = "Line From-Bus Power Flow Magnitude"
        type["Line From-Bus Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
        type["Line From-Bus Power Flow Magnitude Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.from.active)
        type["Transformer From-Bus Power Flow Magnitude"] = "Transformer From-Bus Power Flow Magnitude"
        type["Transformer From-Bus Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
        type["Transformer From-Bus Power Flow Magnitude Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.to.active)
        type["Line To-Bus Power Flow Magnitude"] = "Line To-Bus Power Flow Magnitude"
        type["Line To-Bus Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
        type["Line To-Bus Power Flow Magnitude Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.to.active)
        type["Transformer To-Bus Power Flow Magnitude"] = "Transformer To-Bus Power Flow Magnitude"
        type["Transformer To-Bus Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
        type["Transformer To-Bus Power Flow Magnitude Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.charging.active)
        type["Shunt Power"] = "Shunt Power"
        type["Shunt Power Active"] = " Active [$(unitList.activePowerLive)]"
        type["Shunt Power Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(power.series.active)
        type["Series Power"] = "Series Power"
        type["Series Power Active"] = " Active [$(unitList.activePowerLive)]"
        type["Series Power Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    if !isempty(current.from.magnitude)
        type["From-Bus Current"] = "From-Bus Current"
        type["From-Bus Current Magnitude"] = " Magnitude [$(unitList.currentMagnitudeLive)]"
        type["From-Bus Current Angle"] = " Angle [$(unitList.currentAngleLive)]"
    end
    if !isempty(current.to.magnitude)
        type["To-Bus Current"] = "To-Bus Current"
        type["To-Bus Current Magnitude"] = " Magnitude [$(unitList.currentMagnitudeLive)]"
        type["To-Bus Current Angle"] = " Angle [$(unitList.currentAngleLive)]"
    end
    if !isempty(current.series.magnitude)
        type["Series Current"] = "Series Current"
        type["Series Current Magnitude"] = " Magnitude [$(unitList.currentMagnitudeLive)]"
        type["Series Current Angle"] = " Angle [$(unitList.currentAngleLive)]"
    end
    inuse = Dict{String, Float64}(
        "Line From-Bus Power Flow Magnitude" => 0,
        "Transformer From-Bus Power Flow Magnitude" => 0,
        "Line To-Bus Power Flow Magnitude" => 0,
        "Transformer To-Bus Power Flow Magnitude" => 0,
        "Shunt Power" => 0.0,
        "Series Power" => branch.layout.inservice,
        "From-Bus Current" => branch.layout.inservice,
        "To-Bus Current" => branch.layout.inservice,
    )
    total = Dict{String, Float64}(
        "Shunt Power Active" => 0.0,
        "Shunt Power Reactive" => 0.0,
        "Series Power Active" => 0.0,
        "Series Power Reactive" => 0.0
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            if haskey(type, "Line From-Bus Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line From-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.from.active[i]), "Line From-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["Q"], abs(power.from.reactive[i]), "Line From-Bus Power Flow Magnitude Reactive")
                else
                    inuse["Transformer From-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.from.active[i]), "Transformer From-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["Q"], abs(power.from.reactive[i]), "Transformer From-Bus Power Flow Magnitude Reactive")
                end
            end

            if haskey(type, "Line To-Bus Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line To-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.to.active[i]), "Line To-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["Q"], abs(power.to.reactive[i]), "Line To-Bus Power Flow Magnitude Reactive")
                else
                    inuse["Transformer To-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.to.active[i]), "Transformer To-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["Q"], abs(power.to.reactive[i]), "Transformer To-Bus Power Flow Magnitude Reactive")
                end
            end

            if (branch.parameter.conductance[i] != 0.0 || branch.parameter.susceptance[i] != 0.0) && haskey(type, "Shunt Power")
                inuse["Shunt Power"] += 1
                summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.charging.active[i], "Shunt Power Active")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.charging.reactive[i], "Shunt Power Reactive")
            end

            if haskey(type, "Series Power")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.series.active[i], "Series Power Active")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.series.reactive[i], "Series Power Reactive")
            end

            if haskey(type, "From-Bus Current")
                scaleCurrt = scaleCurrent(prefix, system, branch.layout.from[i])
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scaleCurrt, current.from.magnitude[i], "From-Bus Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["ψ"], current.from.angle[i], "From-Bus Current Angle")
            end

            if haskey(type, "To-Bus Current")
                scaleCurrt = scaleCurrent(prefix, system, branch.layout.to[i])
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scaleCurrt, current.to.magnitude[i], "To-Bus Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["ψ"], current.to.angle[i], "To-Bus Current Angle")
            end

            if haskey(type, "Series Current")
                scaleCurrt = scaleCurrent(prefix, system, branch.layout.from[i])
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scaleCurrt, current.series.magnitude[i], "Series Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["ψ"], current.series.angle[i], "Series Current Angle")
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Branch Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 3
end

function branchSummary(system::PowerSystem, analysis::DC, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    title::Bool, style::Bool)

    power = analysis.power
    branch = system.branch

    type = OrderedDict{String, String}()
    if !isempty(power.from.active)
        type["Line Power Flow Magnitude"] = "Line Power Flow Magnitude"
        type["Line Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
    end
    if !isempty(power.from.active)
        type["Transformer Power Flow Magnitude"] = "Transformer Power Flow Magnitude"
        type["Transformer Power Flow Magnitude Active"] = " Active [$(unitList.activePowerLive)]"
    end
    inuse = Dict{String, Float64}(
        "Line Power Flow Magnitude" => 0,
        "Transformer Power Flow Magnitude" => 0,
    )
    total = Dict{String, Float64}()

    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] == 1
            if haskey(type, "Line Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.from.active[i]), "Line Power Flow Magnitude Active")
                else
                    inuse["Transformer Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale["P"], abs(power.from.active[i]), "Transformer Power Flow Magnitude Active")
                end
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Branch Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 2
end

"""
    printGeneratorSummary(system::PowerSystem, analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style)

The function prints a summary of the electrical quantities related to generators.
Optionally, an `IO` may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
* `delimiter`: Sets the column delimiter.
* `title`: Toggles the printing of the table title.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printGeneratorSummary`](@ref printGeneratorSummary) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
for i = 1:10
    stopping = mismatch!(system, analysis)
    if all(stopping .< 1e-8)
        break
    end
    solve!(system, analysis)
end
power!(system, analysis)

show = Dict("Minimum" => false)
printGeneratorSummary(system, analysis; show, delimiter = " ", title = false)
```
"""
function printGeneratorSummary(system::PowerSystem, analysis::Union{AC, DC}, io::IO = stdout;
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::Bool = true, header::Bool = true, footer::Bool = true)

    errorVoltage(analysis.voltage.angle)

    scale = scalePrint(system, prefix)
    fmt, width, show, subheading = summaryFormat(fmt, width, show, style)
    type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, cnt = generatorSummary(system, analysis, unitList, scale, width, show, title, style)

    if printing && !isempty(type)
        heading = summaryFormat(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)

        titlePrint(io, delimiter, title, header, style, maxLine, "Generator Summary")
        headerPrint(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        summaryPrint(io, pfmt, hfmt, width, show, type, minLabel, minValue, maxLabel, maxValue, inuse, total, delimiter, footer, style, maxLine, cnt)
    end
end

function generatorSummary(system::PowerSystem, analysis::AC, unitList::UnitList, scale::Dict{String, Float64},
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power
    generator = system.generator

    type = OrderedDict{String, String}()
    if !isempty(power.generator.active)
        type["Power Output"] = "Power Output"
        type["Power Output Active"] = " Active [$(unitList.activePowerLive)]"
        type["Power Output Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    inuse = Dict{String, Float64}(
        "Power Output" => generator.layout.inservice,
    )
    total = Dict{String, Float64}(
        "Power Output Active" => 0.0,
        "Power Output Reactive" => 0.0,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 && haskey(type, "Power Output")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.generator.active[i], "Power Output Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["Q"], power.generator.reactive[i], "Power Output Reactive")
        end
    end
    summaryType(type, inuse)
    summaryLabel(generator.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Generator Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 3
end

function generatorSummary(system::PowerSystem, analysis::DC, unitList::UnitList, scale::Dict{String, Float64},
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, title::Bool, style::Bool)

    power = analysis.power
    generator = system.generator

    type = OrderedDict{String, String}()
    if !isempty(power.generator.active)
        type["Power Output"] = "Power Output"
        type["Power Output Active"] = " Active [$(unitList.activePowerLive)]"
    end
    inuse = Dict{String, Float64}(
        "Power Output" => generator.layout.inservice,
    )
    total = Dict{String, Float64}(
        "Power Output Active" => 0.0,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 && haskey(type, "Power Output")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, i, scale["P"], power.generator.active[i], "Power Output Active")
        end
    end
    summaryType(type, inuse)
    summaryLabel(generator.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, title, style, "Generator Summary")

    return type, minLabel, minValue, maxLabel, maxValue, inuse, total, printing, 2
end

function summaryFormat(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)
    _show = OrderedDict(
        "Minimum" => true,
        "Maximum" => true,
    )
    _, _width = fmtwidth(_show)
    _, _width, _show = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show, style)

    subheading = Dict(
        "Type"          => _header_("", "Type", style),
        "In-Use"        => _header_("", "In-Use", style),
        "Minimum Label" => _header_("Label", "Label", style),
        "Minimum Value" => _header_("Value", "Minimum", style),
        "Maximum Label" => _header_("Label", "Label", style),
        "Maximum Value" => _header_("Value", "Maximum", style),
        "Total"         => _header_("", "Total", style),
    )
    _fmt = Dict(
        "Type"          => "%-*s",
        "In-Use"        => "%*i",
        "Minimum Label" => "%-*s",
        "Minimum Value" => "%*.4f",
        "Maximum Label" => "%-*s",
        "Maximum Value" => "%*.4f",
        "Total"         => "%*.4f",
    )
    _width = Dict(
        "Type"          => 4 * style,
        "In-Use"        => 6 * style,
        "Minimum Label" => _width_(_width["Minimum"], 5, style),
        "Minimum Value" => _width_(_width["Minimum"], 5, style),
        "Maximum Label" => _width_(_width["Maximum"], 5, style),
        "Maximum Value" => _width_(_width["Maximum"], 5, style),
        "Total"         => 5 * style,
    )
    _show = OrderedDict(
        "Type"          => true,
        "Minimum Label" => _show_(_show["Minimum"], true),
        "Minimum Value" => _show_(_show["Minimum"], true),
        "Maximum Label" => _show_(_show["Maximum"], true),
        "Maximum Value" => _show_(_show["Maximum"], true),
        "In-Use"        => true,
        "Total"         => true,
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    return fmt, width, show, subheading
end

function summaryFormat(fmt::Dict{String, String}, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, type::OrderedDict{String, String},
    inuse::Dict{String, Float64}, minLabel::Dict{String, String}, minValue::Dict{String, Float64}, maxLabel::Dict{String, String}, maxValue::Dict{String, Float64},
    total::Dict{String, Float64}, style::Bool)

    if style
        for (key, caption) in type
            fmax(width, show, caption, "Type")

            if haskey(minLabel, key)
                fmax(width, show, minLabel[key], "Minimum Label")
                fmax(fmt, width, show, minValue[key], "Minimum Value")
            end

            if haskey(maxLabel, key)
                fmax(width, show, maxLabel[key], "Maximum Label")
                fmax(fmt, width, show, maxValue[key], "Maximum Value")
            end

            if haskey(inuse, key)
                fmax(fmt, width, show, inuse[key], "In-Use")
            end

            if haskey(total, key)
                fmax(fmt, width, show, total[key], "Total")
            end
        end
    end

    heading = OrderedDict(
        "Type"    => _blank_(width, show, "Type"),
        "Minimum" => _blank_(width, show, style, "Minimum", "Minimum Label", "Minimum Value"),
        "Maximum" => _blank_(width, show, style, "Maximum", "Maximum Label", "Maximum Value"),
        "In-Use"  => _blank_(width, show, "In-Use"),
        "Total"   => _blank_(width, show, "Total")
    )

    return heading
end

function summaryPrint(io::IO, pfmt::Dict{String, Format}, hfmt::Dict{String, Format}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    type::OrderedDict{String, String}, minLabel::Dict{String, String}, minValue::Dict{String, Float64}, maxLabel::Dict{String, String},
    maxValue::Dict{String, Float64}, inuse::Dict{String, Float64}, total::Dict{String, Float64}, delimiter::String, footer::Bool,
    style::Bool, maxLine::Int64, breakLine::Int64)

    cnt = 1
    @inbounds for (key, caption) in type
        if (cnt - 1) % breakLine == 0 && cnt != 1
            printf(io, hfmt, width, show, delimiter, style)
        end

        printf(io, pfmt, width, show, caption, "Type")

        if haskey(minLabel, key)
            printf(io, pfmt, width, show, minLabel[key], "Minimum Label")
            printf(io, pfmt, width, show, minValue[key], "Minimum Value")
        else
            printf(io, hfmt, width, show, "", "Minimum Label")
            printf(io, hfmt, width, show, "", "Minimum Value")
        end

        if haskey(maxLabel, key)
            printf(io, pfmt, width, show, maxLabel[key], "Maximum Label")
            printf(io, pfmt, width, show, maxValue[key], "Maximum Value")
        else
            printf(io, hfmt, width, show, "", "Maximum Label")
            printf(io, hfmt, width, show, "", "Maximum Value")
        end

        if haskey(inuse, key)
            printf(io, pfmt, width, show, inuse[key], "In-Use")
        else
            printf(io, hfmt, width, show, "", "In-Use")
        end

        if haskey(total, key)
            printf(io, pfmt, width, show, total[key], "Total")
        else
            printf(io, hfmt, width, show, "", "Total")
        end

        @printf io "\n"
        cnt += 1
    end
    printf(io, delimiter, footer, style, maxLine)
end

function summaryDict(type::OrderedDict{String, String})
    minIndex = Dict{String, Int64}()
    minLabel = Dict{String, String}()
    minValue = Dict{String, Float64}()

    maxIndex = Dict{String, Int64}()
    maxLabel = Dict{String, String}()
    maxValue = Dict{String, Float64}()

    for (key, value) in type
        if value[1] == ' '
            minIndex[key] = 0
            minLabel[key] = ""
            minValue[key] = Inf

            maxIndex[key] = 0
            maxLabel[key] = ""
            maxValue[key] = -Inf
        end
    end

    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue
end

function summaryData(minIndex::Dict{String, Int64}, minValue::Dict{String, Float64}, maxIndex::Dict{String, Int64},
    maxValue::Dict{String, Float64}, total::Dict{String, Float64}, i::Int64, scale::Float64, value::Float64, key::String)

    summaryData(minIndex, minValue, maxIndex, maxValue, i, scale, value, key)
    total[key] += value
end

function summaryData(minIndex::Dict{String, Int64}, minValue::Dict{String, Float64}, maxIndex::Dict{String, Int64},
    maxValue::Dict{String, Float64}, i::Int64, scale::Float64, value::Float64, key::String)

    value *= scale

    if value < minValue[key]
        minIndex[key] = i
        minValue[key] = value
    end

    if value > maxValue[key]
        maxIndex[key] = i
        maxValue[key] = value
    end
end

function summaryType(type::OrderedDict{String, String}, inuse::Dict{String, Float64})
    for (key, value) in inuse
        if value == 0
            for label in keys(type)
                if occursin(key, label)
                    delete!(type, label)
                end
            end
        end
    end
end

function summaryLabel(label::OrderedDict{String, Int64}, minIndex::Dict{String, Int64}, minLabel::Dict{String, String},
    maxIndex::Dict{String, Int64}, maxLabel::Dict{String, String})

    for (key, index) in minIndex
        if index != 0
            (minLabel[key], _), _ = iterate(label, index)
        end
    end
    for (key, index) in maxIndex
        if index != 0
            (maxLabel[key], _), _ = iterate(label, index)
        end
    end
end