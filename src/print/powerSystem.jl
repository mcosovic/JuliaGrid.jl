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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.bus, system.bus.label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusData(system, analysis, label, scale, prefix, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Bus Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude")
            printf(io, pfmt, show, width, analysis.voltage.angle, i, scale["θ"], "Voltage Angle")

            printf(io, pfmt, show, width, analysis.power.supply.active, i, scale["P"], "Power Generation Active")
            printf(io, pfmt, show, width, analysis.power.supply.reactive, i, scale["Q"], "Power Generation Reactive")
            printf(io, pfmt, show, width, system.bus.demand.active, i, scale["P"], "Power Demand Active")
            printf(io, pfmt, show, width, system.bus.demand.reactive, i, scale["Q"], "Power Demand Reactive")
            printf(io, pfmt, show, width, analysis.power.injection.active, i, scale["P"], "Power Injection Active")
            printf(io, pfmt, show, width, analysis.power.injection.reactive, i, scale["Q"], "Power Injection Reactive")
            printf(io, pfmt, show, width, analysis.power.shunt.active, i, scale["P"], "Shunt Power Active")
            printf(io, pfmt, show, width, analysis.power.shunt.reactive, i, scale["Q"], "Shunt Power Reactive")

            printf(io, pfmt, show, width, analysis.current.injection.magnitude, i, scaleCurrent(prefix, system, i), "Current Injection Magnitude")
            printf(io, pfmt, show, width, analysis.current.injection.angle, i, scale["ψ"], "Current Injection Angle")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBusData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current

    _show = OrderedDict(
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
        "Label"                       => _header_("", "Label", style),
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
        "Label"                       => "",
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
        "Label"                       => "%-*s",
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
        "Label"                       => 5 * style,
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
        "Label"                       => true,
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

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude")
            fmax(fmt, width, show, voltage.angle, i, scale["θ"], "Voltage Angle")

            fmax(fmt, width, show, power.supply.active, i, scale["P"], "Power Generation Active")
            fmax(fmt, width, show, power.supply.reactive, i, scale["Q"], "Power Generation Reactive")
            fmax(fmt, width, show, system.bus.demand.active, i, scale["P"], "Power Demand Active")
            fmax(fmt, width, show, system.bus.demand.reactive, i, scale["Q"], "Power Demand Reactive")
            fmax(fmt, width, show, power.injection.active, i, scale["P"], "Power Injection Active")
            fmax(fmt, width, show, power.injection.reactive, i, scale["Q"], "Power Injection Reactive")
            fmax(fmt, width, show, power.shunt.active, i, scale["P"], "Shunt Power Active")
            fmax(fmt, width, show, power.shunt.reactive, i, scale["Q"], "Shunt Power Reactive")

            fmax(fmt, width, show, current.injection.magnitude, i, scaleCurrent(prefix, system, i), "Current Injection Magnitude")
            fmax(fmt, width, show, current.injection.angle, i, scale["ψ"], "Current Injection Angle")
        else
            maxV = initMax(prefix.voltageMagnitude)
            maxI = initMax(prefix.currentMagnitude)

            @inbounds for (label, i) in system.bus.label
                fmax(fmt, width, show, label, "Label")

                if show["Voltage Magnitude"] && prefix.voltageMagnitude != 0.0
                    maxV = max(voltage.magnitude[i] * scaleVoltage(system.base.voltage, prefix, i), maxV)
                end

                if show["Current Injection Magnitude"] && prefix.currentMagnitude != 0.0
                    maxI = max(current.injection.magnitude[i] * scaleCurrent(system, prefix, i), maxI)
                end
            end

            fminmax(fmt, width, show, power.supply.active, scale["P"], "Power Generation Active")
            fminmax(fmt, width, show, power.supply.reactive, scale["Q"], "Power Generation Reactive")
            fminmax(fmt, width, show, system.bus.demand.active, scale["P"], "Power Demand Active")
            fminmax(fmt, width, show, system.bus.demand.reactive, scale["Q"], "Power Demand Reactive")
            fminmax(fmt, width, show, power.injection.active, scale["P"], "Power Injection Active")
            fminmax(fmt, width, show, power.injection.reactive, scale["Q"], "Power Injection Reactive")
            fminmax(fmt, width, show, power.shunt.active, scale["P"], "Shunt Power Active")
            fminmax(fmt, width, show, power.shunt.reactive, scale["Q"], "Shunt Power Reactive")

            if prefix.voltageMagnitude == 0.0
                fmax(fmt, width, show, voltage.magnitude, 1.0, "Voltage Magnitude")
            else
                fmax(fmt, width, show, maxV, "Voltage Magnitude")
            end
            fminmax(fmt, width, show, voltage.angle, scale["θ"], "Voltage Angle")


            if prefix.currentMagnitude == 0.0
                fmax(fmt, width, show, current.injection.magnitude, 1.0, "Current Injection Magnitude")
            else
                fmax(fmt, width, show, maxI, "Current Injection Magnitude")
            end
            fminmax(fmt, width, show, current.injection.angle, scale["ψ"], "Current Injection Angle")
        end
    end

    printing = howManyPrint(width, show, style, title, "Bus Data")

    heading = OrderedDict(
        "Label"             => _blank_(width, show, "Label"),
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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.bus, system.bus.label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusData(system, analysis, label, scale, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Bus Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.voltage.angle, i, scale["θ"], "Voltage Angle")

            printf(io, pfmt, show, width, analysis.power.supply.active, i, scale["P"], "Power Generation Active")
            printf(io, pfmt, show, width, system.bus.demand.active, i, scale["P"], "Power Demand Active")
            printf(io, pfmt, show, width, analysis.power.injection.active, i, scale["P"], "Power Injection Active")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBusData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    power = analysis.power

    _show = OrderedDict(
        "Voltage"          => true,
        "Power Generation" => true,
        "Power Demand"     => true,
        "Power Injection"  => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                   => _header_("", "Label", style),
        "Voltage Angle"           => _header_("Angle", "Voltage Angle", style),
        "Power Generation Active" => _header_("Active", "Active Power Generation", style),
        "Power Demand Active"     => _header_("Active", "Active Power Demand", style),
        "Power Injection Active"  => _header_("Active", "Active Power Injection", style),
    )
    unit = Dict(
        "Label"                   => "",
        "Voltage Angle"           => "[$(unitList.voltageAngleLive)]",
        "Power Generation Active" => "[$(unitList.activePowerLive)]",
        "Power Demand Active"     => "[$(unitList.activePowerLive)]",
        "Power Injection Active"  => "[$(unitList.activePowerLive)]"
    )
    _fmt = Dict(
        "Label"                   => "%-*s",
        "Voltage Angle"           => _fmt_(_fmt["Voltage"]),
        "Power Generation Active" => _fmt_(_fmt["Power Generation"]),
        "Power Demand Active"     => _fmt_(_fmt["Power Demand"]),
        "Power Injection Active"  => _fmt_(_fmt["Power Injection"])
    )
    _width = Dict(
        "Label"                   => 5 * style,
        "Voltage Angle"           => _width_(_width["Voltage"], 7, style),
        "Power Generation Active" => _width_(_width["Power Generation"], 16, style),
        "Power Demand Active"     => _width_(_width["Power Demand"], 12, style),
        "Power Injection Active"  => _width_(_width["Power Injection"], 15, style)
    )
    _show = OrderedDict(
        "Label"                   => true,
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

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, voltage.angle, i, scale["θ"], "Voltage Angle")

            fmax(fmt, width, show, power.supply.active, i, scale["P"], "Power Generation Active")
            fmax(fmt, width, show, system.bus.demand.active, i, scale["P"], "Power Demand Active")
            fmax(fmt, width, show, power.injection.active, i, scale["P"], "Power Injection Active")
        else
            fminmax(fmt, width, show, voltage.angle, scale["θ"], "Voltage Angle")

            fminmax(fmt, width, show, power.supply.active, scale["P"], "Power Generation Active")
            fminmax(fmt, width, show, system.bus.demand.active, scale["P"], "Power Demand Active")
            fminmax(fmt, width, show, power.injection.active, scale["P"], "Power Injection Active")

            @inbounds for (label, i) in system.bus.label
                fmax(fmt, width, show, label, "Label")
            end
        end
    end

    printing = howManyPrint(width, show, style, title, "Bus Data")

    heading = OrderedDict(
        "Label"             => _blank_(width, show, "Label"),
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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.branch, system.branch.label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, printing = formatBranchData(system, analysis, label, scale, prefix, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Branch Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.power.from.active, i, scale["P"], "From-Bus Power Active")
            printf(io, pfmt, show, width, analysis.power.from.reactive, i, scale["Q"], "From-Bus Power Reactive")
            printf(io, pfmt, show, width, analysis.power.to.active, i, scale["P"], "To-Bus Power Active")
            printf(io, pfmt, show, width, analysis.power.to.reactive, i, scale["Q"], "To-Bus Power Reactive")
            printf(io, pfmt, show, width, analysis.power.charging.active, i, scale["P"], "Shunt Power Active")
            printf(io, pfmt, show, width, analysis.power.charging.reactive, i, scale["Q"], "Shunt Power Reactive")
            printf(io, pfmt, show, width, analysis.power.series.active, i, scale["P"], "Series Power Active")
            printf(io, pfmt, show, width, analysis.power.series.reactive, i, scale["Q"], "Series Power Reactive")

            printf(io, pfmt, show, width, analysis.current.from.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.from[i]), "From-Bus Current Magnitude")
            printf(io, pfmt, show, width, analysis.current.from.angle, i, scale["ψ"], "From-Bus Current Angle")
            printf(io, pfmt, show, width, analysis.current.to.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.to[i]), "To-Bus Current Magnitude")
            printf(io, pfmt, show, width, analysis.current.to.angle, i, scale["ψ"], "To-Bus Current Angle")
            printf(io, pfmt, show, width, analysis.current.series.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.from[i]), "Series Current Magnitude")
            printf(io, pfmt, show, width, analysis.current.series.angle, i, scale["ψ"], "Series Current Angle")

            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBranchData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)

    power = analysis.power
    current = analysis.current

    _show = OrderedDict(
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
        "Label"                      => _header_("", "Label", style),
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
        "Label"                      => "",
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
        "Label"                      => "%-*s",
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
        "Label"                      => 5 * style,
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
        "Label"                      => true,
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

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, power.from.active, i, scale["P"], "From-Bus Power Active")
            fmax(fmt, width, show, power.from.reactive, i, scale["Q"], "From-Bus Power Reactive")
            fmax(fmt, width, show, power.to.active, i, scale["P"], "To-Bus Power Active")
            fmax(fmt, width, show, power.to.reactive, i, scale["Q"], "To-Bus Power Reactive")
            fmax(fmt, width, show, power.charging.active, i, scale["P"], "Shunt Power Active")
            fmax(fmt, width, show, power.charging.reactive, i, scale["Q"], "Shunt Power Reactive")
            fmax(fmt, width, show, power.series.active, i, scale["P"], "Series Power Active")
            fmax(fmt, width, show, power.series.reactive, i, scale["Q"], "Series Power Reactive")
            fmax(fmt, width, show, current.from.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.from[i]), "From-Bus Current Magnitude")
            fmax(fmt, width, show, current.from.angle, i, scale["ψ"], "From-Bus Current Angle")

            fmax(fmt, width, show, current.to.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.to[i]), "To-Bus Current Magnitude")
            fmax(fmt, width, show, current.to.angle, i, scale["ψ"], "To-Bus Current Angle")
            fmax(fmt, width, show, current.series.magnitude, i, scaleCurrent(prefix, system, system.branch.layout.from[i]), "Series Current Magnitude")
            fmax(fmt, width, show, current.series.angle, i, scale["ψ"], "Series Current Angle")
        else
            maxFrom = initMax(prefix.currentMagnitude)
            maxTo = initMax(prefix.currentMagnitude)
            maxSeries = initMax(prefix.currentMagnitude)

            @inbounds for (label, i) in system.branch.label
                fmax(fmt, width, show, label, "Label")

                if show["From-Bus Current Magnitude"] && prefix.currentMagnitude != 0.0
                    maxFrom = max(current.from.magnitude[i] * scaleCurrent(system, prefix, system.branch.layout.from[i]), maxFrom)
                    maxTo = max(current.to.magnitude[i] * scaleCurrent(system, prefix, system.branch.layout.to[i]), maxTo)
                    maxSeries = max(current.series.magnitude[i] * scaleCurrent(system, prefix, system.branch.layout.from[i]), maxSeries)
                end
            end

            fminmax(fmt, width, show, power.from.active, scale["P"], "From-Bus Power Active")
            fminmax(fmt, width, show, power.from.reactive, scale["Q"], "From-Bus Power Reactive")

            fminmax(fmt, width, show, power.to.active, scale["P"], "To-Bus Power Active")
            fminmax(fmt, width, show, power.to.reactive, scale["Q"], "To-Bus Power Reactive")

            fminmax(fmt, width, show, power.charging.active, scale["P"], "Shunt Power Active")
            fminmax(fmt, width, show, power.charging.reactive, scale["Q"], "Shunt Power Reactive")

            fminmax(fmt, width, show, power.series.active, scale["P"], "Series Power Active")
            fminmax(fmt, width, show, power.series.reactive, scale["Q"], "Series Power Reactive")

            if prefix.currentMagnitude == 0.0
                fmax(fmt, width, show, current.from.magnitude, 1.0, "From-Bus Current Magnitude")
                fmax(fmt, width, show, current.to.magnitude, 1.0, "To-Bus Current Magnitude")
                fmax(fmt, width, show, current.series.magnitude, 1.0, "Series Current Magnitude")
            else
                fmax(fmt, width, show, maxFrom, "From-Bus Current Magnitude")
                fmax(fmt, width, show, maxTo, "To-Bus Current Magnitude")
                fmax(fmt, width, show, maxSeries, "Series Current Magnitude")
            end
            fminmax(fmt, width, show, current.from.angle, scale["ψ"], "From-Bus Current Angle")
            fminmax(fmt, width, show, current.to.angle, scale["ψ"], "To-Bus Current Angle")
            fminmax(fmt, width, show, current.series.angle, scale["ψ"], "Series Current Angle")
        end
    end

    printing = howManyPrint(width, show, style, title, "Branch Data")

    heading = OrderedDict(
        "Label"            => _blank_(width, show, "Label"),
        "From-Bus Power"   => _blank_(width, show, style, "From-Bus Power", "From-Bus Power Active", "From-Bus Power Reactive"),
        "To-Bus Power"     => _blank_(width, show, style, "To-Bus Power", "To-Bus Power Active", "To-Bus Power Reactive"),
        "Shunt Power"      => _blank_(width, show, style, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive"),
        "Series Power"     => _blank_(width, show, style, "Series Power", "Series Power Active", "Series Power Reactive"),
        "From-Bus Current" => _blank_(width, show, style, "From-Bus Current", "From-Bus Current Magnitude", "From-Bus Current Angle"),
        "To-Bus Current"   => _blank_(width, show, style, "To-Bus Current", "To-Bus Current Magnitude", "To-Bus Current Angle"),
        "Series Current"   => _blank_(width, show, style, "Series Current", "Series Current Magnitude", "Series Current Angle"),
        "Status"           => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.branch.number + 1)

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.branch, system.branch.label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, printing = formatBranchData(system, analysis, label, scale, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Branch Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.power.from.active, i, scale["P"], "From-Bus Power Active")
            printf(io, pfmt, show, width, analysis.power.to.active, i, scale["P"], "To-Bus Power Active")

            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBranchData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)

    power = analysis.power

    _show = OrderedDict(
        "From-Bus Power" => true,
        "To-Bus Power"   => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                 => _header_("", "Label", style),
        "From-Bus Power Active" => _header_("Active", "From-Bus Active Power", style),
        "To-Bus Power Active"   => _header_("Active", "To-Bus Active Power", style),
        "Status"                => _header_("", "Status", style),
    )
    unit = Dict(
        "Label"                  => "",
        "From-Bus Power Active"  => "[$(unitList.activePowerLive)]",
        "To-Bus Power Active"    => "[$(unitList.activePowerLive)]",
        "Status"                 => ""
    )
    _fmt = Dict(
        "Label"                 => "%-*s",
        "From-Bus Power Active" => _fmt_(_fmt["From-Bus Power"]),
        "To-Bus Power Active"   => _fmt_(_fmt["To-Bus Power"]),
        "Status"                => "%*i"
    )
    _width = Dict(
        "Label"                 => 5 * style,
        "From-Bus Power Active" => _width_(_width["From-Bus Power"], 14, style),
        "To-Bus Power Active"   => _width_(_width["To-Bus Power"], 12, style),
        "Status"                => 6 * style
    )
    _show = OrderedDict(
        "Label"                 => true,
        "From-Bus Power Active" => _show_(_show["From-Bus Power"], power.from.active),
        "To-Bus Power Active"   => _show_(_show["To-Bus Power"], power.to.active),
        "Status"                => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, power.from.active, i, scale["P"], "From-Bus Power Active")
            fmax(fmt, width, show, power.to.active, i, scale["P"], "To-Bus Power Active")
        else
            fminmax(fmt, width, show, power.from.active, scale["P"], "From-Bus Power Active")
            fminmax(fmt, width, show, power.to.active, scale["P"], "To-Bus Power Active")

            @inbounds for (label, i) in system.branch.label
                fmax(fmt, width, show, label, "Label")
            end
        end
    end

    printing = howManyPrint(width, show, style, title, "Branch Data")

    heading = OrderedDict(
        "Label"          => _blank_(width, show, "Label"),
        "From-Bus Power" => _blank_(width, show, "From-Bus Power Active"),
        "To-Bus Power"   => _blank_(width, show, "To-Bus Power Active"),
        "Status"         => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, printing
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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.generator, system.generator.label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorData(system, analysis, label, scale, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Generator Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Power Output Active")
            printf(io, pfmt, show, width, analysis.power.generator.reactive, i, scale["Q"], "Power Output Reactive")
            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String,Bool}, style::Bool, title::Bool)

    power = analysis.power

    _show = OrderedDict("Power Output" => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                 => _header_("", "Label", style),
        "Power Output Active"   => _header_("Active", "Active Power Output", style),
        "Power Output Reactive" => _header_("Reactive", "Reactive Power Output", style),
        "Status"                => _header_("", "Status", style),
    )
    unit = Dict(
        "Label"                 => "",
        "Power Output Active"   => "[$(unitList.activePowerLive)]",
        "Power Output Reactive" => "[$(unitList.reactivePowerLive)]",
        "Status"                => ""
    )
    _fmt = Dict(
        "Label"                 => "%-*s",
        "Power Output Active"   => _fmt_(_fmt["Power Output"]),
        "Power Output Reactive" => _fmt_(_fmt["Power Output"]),
        "Status"                => "%*i"
    )
    _width = Dict(
        "Label"                 => 5 * style,
        "Power Output Active"   => _width_(_width["Power Output"], 6, style),
        "Power Output Reactive" => _width_(_width["Power Output"], 8, style),
        "Status"                => 6 * style
    )
    _show = OrderedDict(
        "Label"                 => true,
        "Power Output Active"   => _show_(_show["Power Output"], power.generator.active),
        "Power Output Reactive" => _show_(_show["Power Output"], power.generator.reactive),
        "Status"                => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, power.generator.active, i, scale["P"], "Power Output Active")
            fmax(fmt, width, show, power.generator.reactive, i, scale["Q"], "Power Output Reactive")
        else
            fminmax(fmt, width, show, power.generator.active, scale["P"], "Power Output Active")
            fminmax(fmt, width, show, power.generator.reactive, scale["Q"], "Power Output Reactive")

            @inbounds for (label, i) in system.generator.label
                fmax(fmt, width, show, label, "Label")
            end
        end
    end

    printing = howManyPrint(width, show, style, title, "Generator Data")

    heading = OrderedDict(
        "Label"        => _blank_(width, show, "Label"),
        "Power Output" => _blank_(width, show, style, "Power Output", "Power Output Active", "Power Output Reactive"),
        "Status"       => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = system.generator.number + 1)

    scale = printScale(system, prefix)
    labels, header, title, footer = formPrint(label, system.generator, system.generator.label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorData(system, analysis, label, scale, fmt, width, show, style, title)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Generator Data")
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Power Output Active")
            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)

    power = analysis.power

    _show = OrderedDict("Power Output" => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"               => _header_("", "Label", style),
        "Power Output Active" => _header_("Active", "Active Power Output", style),
        "Status"              => _header_("", "Status", style),
    )
    unit = Dict(
        "Label"               => "",
        "Power Output Active" => "[$(unitList.activePowerLive)]",
        "Status"              => ""
    )
    _fmt = Dict(
        "Label"               => "%-*s",
        "Power Output Active" => _fmt_(_fmt["Power Output"]),
        "Status"              => "%*i"
    )
    _width = Dict(
        "Label"               => 5 * style,
        "Power Output Active" => _width_(_width["Power Output"], 12, style),
        "Status"              => 6 * style
    )
    _show = OrderedDict(
        "Label"               => true,
        "Power Output Active" => _show_(_show["Power Output"], power.generator.active),
        "Status"              => true
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(fmt, width, show, label, "Label")

            fmax(fmt, width, show, power.generator.active, i, scale["P"], "Power Output Active")
        else
            fminmax(fmt, width, show, power.generator.active, scale["P"], "Power Output Active")

            @inbounds for (label, i) in system.generator.label
                fmax(fmt, width, show, label, "Label")
            end
        end
    end

    printing = howManyPrint(width, show, style, title, "Generator Data")

    heading = OrderedDict(
        "Label"        => _blank_(width, show, "Label"),
        "Power Output" => _blank_(width, show, "Power Output Active"),
        "Status"       => _blank_(width, show, "Status")
    )

    return fmt, width, show, heading, subheading, unit, printing
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

    scale = printScale(system, prefix)
    fmt, width, show, subheading = formatSummary(fmt, width, show, style, title)
    type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing = formatBusSummary(system, analysis, scale, prefix, width, show, style, title)

    if printing
        heading = formatSummary(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Bus Summary")
        printHeader(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        printSummary(io, pfmt, hfmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, delimiter, maxLine, style, footer, lineBreak(analysis))
    end
end

function formatBusSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current

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
    inuse = Dict{String, Float64}(
        "Voltage"           => system.bus.number,
        "Power Generation"  => 0.0,
        "Power Demand"      => 0.0,
        "Power Injection"   => system.bus.number,
        "Shunt Power"       => 0.0,
        "Current Injection" => system.bus.number,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.bus.number
        summaryData(minIndex, minValue, maxIndex, maxValue, voltage.magnitude[i] * scaleVoltage(prefix, system.base.voltage, i), i, "Voltage Magnitude")
        summaryData(minIndex, minValue, maxIndex, maxValue, voltage.angle[i] * scale["θ"], i, "Voltage Angle")

        if !isempty(system.bus.supply.generator[i]) && haskey(type, "Power Generation")
            inuse["Power Generation"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.supply.active[i] * scale["P"], i, "Power Generation Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.supply.reactive[i] * scale["Q"], i, "Power Generation Reactive")
        end

        if (system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0) && haskey(type, "Power Demand")
            inuse["Power Demand"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, system.bus.demand.active[i] * scale["P"], i, "Power Demand Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, system.bus.demand.reactive[i] * scale["Q"], i, "Power Demand Reactive")
        end

        if haskey(type, "Power Injection")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.injection.active[i] * scale["P"], i, "Power Injection Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.injection.reactive[i] * scale["Q"], i, "Power Injection Reactive")
        end

        if (system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0) && haskey(type, "Shunt Power")
            inuse["Shunt Power"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.shunt.active[i] * scale["P"], i, "Shunt Power Active")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.shunt.reactive[i] * scale["Q"], i, "Shunt Power Reactive")
        end
        if haskey(type, "Current Injection")
            summaryData(minIndex, minValue, maxIndex, maxValue, current.injection.magnitude[i] * scaleCurrent(prefix, system, i), i, "Current Injection Magnitude")
            summaryData(minIndex, minValue, maxIndex, maxValue, current.injection.angle[i] * scale["ψ"], i, "Current Injection Angle")
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.bus.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Bus Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
end

function formatBusSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    voltage = analysis.voltage
    power = analysis.power

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
    total = Dict{String, Float64}(
        "Power Generation Active" => 0.0,
        "Power Demand Active" => 0.0,
        "Power Injection Active" => 0.0,
    )
    inuse = Dict{String, Float64}(
        "Voltage"           => system.bus.number,
        "Power Generation"  => 0.0,
        "Power Demand"      => 0.0,
        "Power Injection"   => system.bus.number,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.bus.number
        summaryData(minIndex, minValue, maxIndex, maxValue, voltage.angle[i] * scale["θ"], i, "Voltage Angle")

        if !isempty(system.bus.supply.generator[i]) && haskey(type, "Power Generation")
            inuse["Power Generation"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.supply.active[i] * scale["P"], i, "Power Generation Active")
        end

        if (system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0) && haskey(type, "Power Demand")
            inuse["Power Demand"] += 1
            summaryData(minIndex, minValue, maxIndex, maxValue, total, system.bus.demand.active[i] * scale["P"], i, "Power Demand Active")
        end

        if haskey(type, "Power Injection")
            summaryData(minIndex, minValue, maxIndex, maxValue, total, power.injection.active[i] * scale["P"], i, "Power Injection Active")
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.bus.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Bus Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
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

    scale = printScale(system, prefix)
    fmt, width, show, subheading = formatSummary(fmt, width, show, style, title)
    type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing = formatBranchSummary(system, analysis, scale, prefix, width, show, style, title)

    if printing && !isempty(type)
        heading = formatSummary(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Branch Summary")
        printHeader(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        printSummary(io, pfmt, hfmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, delimiter, maxLine, style, footer, lineBreak(analysis))
    end
end

function formatBranchSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    voltage = analysis.voltage
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
    total = Dict{String, Float64}(
        "Shunt Power Active" => 0.0,
        "Shunt Power Reactive" => 0.0,
        "Series Power Active" => 0.0,
        "Series Power Reactive" => 0.0
    )
    inuse = Dict{String, Float64}(
        "Line From-Bus Power Flow Magnitude" => 0,
        "Transformer From-Bus Power Flow Magnitude" => 0,
        "Line To-Bus Power Flow Magnitude" => 0,
        "Transformer To-Bus Power Flow Magnitude" => 0,
        "Shunt Power" => 0.0,
        "Series Power" => system.branch.layout.inservice,
        "From-Bus Current" => system.branch.layout.inservice,
        "To-Bus Current" => system.branch.layout.inservice,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            if haskey(type, "Line From-Bus Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line From-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.active[i]) * scale["P"], i, "Line From-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.reactive[i]) * scale["Q"], i, "Line From-Bus Power Flow Magnitude Reactive")
                else
                    inuse["Transformer From-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.active[i]) * scale["P"], i, "Transformer From-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.reactive[i]) * scale["Q"], i, "Transformer From-Bus Power Flow Magnitude Reactive")
                end
            end

            if haskey(type, "Line To-Bus Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line To-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.to.active[i]) * scale["P"], i, "Line To-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.to.reactive[i]) * scale["Q"], i, "Line To-Bus Power Flow Magnitude Reactive")
                else
                    inuse["Transformer To-Bus Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.to.active[i]) * scale["P"], i, "Transformer To-Bus Power Flow Magnitude Active")
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.to.reactive[i]) * scale["Q"], i, "Transformer To-Bus Power Flow Magnitude Reactive")
                end
            end

            if (system.branch.parameter.conductance[i] != 0.0 || system.branch.parameter.susceptance[i] != 0.0) && haskey(type, "Shunt Power")
                inuse["Shunt Power"] += 1
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.charging.active[i] * scale["P"], i, "Shunt Power Active")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.charging.reactive[i] * scale["Q"], i, "Shunt Power Reactive")
            end

            if haskey(type, "Series Power")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.series.active[i] * scale["P"], i, "Series Power Active")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.series.reactive[i] * scale["Q"], i, "Series Power Reactive")
            end

            if haskey(type, "From-Bus Current")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.from.magnitude[i] * scaleCurrent(prefix, system, system.branch.layout.from[i]), i, "From-Bus Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.from.angle[i] * scale["ψ"], i, "From-Bus Current Angle")
            end

            if haskey(type, "To-Bus Current")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.to.magnitude[i] * scaleCurrent(prefix, system, system.branch.layout.to[i]), i, "To-Bus Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.to.angle[i] * scale["ψ"], i, "To-Bus Current Angle")
            end

            if haskey(type, "Series Current")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.series.magnitude[i] * scaleCurrent(prefix, system, system.branch.layout.from[i]), i, "Series Current Magnitude")
                summaryData(minIndex, minValue, maxIndex, maxValue, current.series.angle[i] * scale["ψ"], i, "Series Current Angle")
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Branch Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
end

function formatBranchSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    voltage = analysis.voltage
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

    total = Dict{String, Float64}()
    inuse = Dict{String, Float64}(
        "Line Power Flow Magnitude" => 0,
        "Transformer Power Flow Magnitude" => 0,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.branch.number
        if system.branch.layout.status[i] == 1
            if haskey(type, "Line Power Flow Magnitude")
                if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                    inuse["Line Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.active[i]) * scale["P"], i, "Line Power Flow Magnitude Active")
                else
                    inuse["Transformer Power Flow Magnitude"] += 1
                    summaryData(minIndex, minValue, maxIndex, maxValue, abs(power.from.active[i]) * scale["P"], i, "Transformer Power Flow Magnitude Active")
                end
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Branch Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
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

    scale = printScale(system, prefix)
    fmt, width, show, subheading = formatSummary(fmt, width, show, style, title)
    type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing = formatGeneratorSummary(system, analysis, scale, prefix, width, show, style, title)

    if printing && !isempty(type)
        heading = formatSummary(fmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, style)
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Generator Summary")
        printHeader(io, hfmt, width, show, heading, subheading, delimiter, header, style, maxLine)
        printSummary(io, pfmt, hfmt, width, show, type, inuse, minLabel, minValue, maxLabel, maxValue, total, delimiter, maxLine, style, footer, lineBreak(analysis))
    end
end

function formatGeneratorSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    power = analysis.power

    type = OrderedDict{String, String}()
    if !isempty(power.generator.active)
        type["Power Output"] = "Power Output"
        type["Power Output Active"] = " Active [$(unitList.activePowerLive)]"
        type["Power Output Reactive"] = " Reactive [$(unitList.reactivePowerLive)]"
    end
    total = Dict{String, Float64}(
        "Power Output Active" => 0.0,
        "Power Output Reactive" => 0.0,
    )
    inuse = Dict{String, Float64}(
        "Power Output" => system.generator.layout.inservice,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            if haskey(type, "Power Output")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.generator.active[i] * scale["P"], i, "Power Output Active")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.generator.reactive[i] * scale["Q"], i, "Power Output Reactive")
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Generator Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
end

function formatGeneratorSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, prefix::PrefixLive,
    width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, title::Bool)

    power = analysis.power

    type = OrderedDict{String, String}()
    if !isempty(power.generator.active)
        type["Power Output"] = "Power Output"
        type["Power Output Active"] = " Active [$(unitList.activePowerLive)]"
    end
    total = Dict{String, Float64}(
        "Power Output Active" => 0.0,
    )
    inuse = Dict{String, Float64}(
        "Power Output" => system.generator.layout.inservice,
    )
    minIndex, minLabel, minValue, maxIndex, maxLabel, maxValue = summaryDict(type)

    @inbounds for i = 1:system.generator.number
        if system.generator.layout.status[i] == 1
            if haskey(type, "Power Output")
                summaryData(minIndex, minValue, maxIndex, maxValue, total, power.generator.active[i] * scale["P"], i, "Power Output Active")
            end
        end
    end
    summaryType(type, inuse)
    summaryLabel(system.branch.label, minIndex, minLabel, maxIndex, maxLabel)

    printing = howManyPrint(width, show, style, title, "Generator Summary")

    return type, inuse, minLabel, minValue, maxLabel, maxValue, total, printing
end

function formatSummary(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool)
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

    printing = howManyPrint(width, show, style, title, "Bus Summary")

    return fmt, width, show, subheading
end

function formatSummary(fmt::Dict{String, String}, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, type::OrderedDict{String, String},
    inuse::Dict{String, Float64}, minLabel::Dict{String, String}, minValue::Dict{String, Float64}, maxLabel::Dict{String, String}, maxValue::Dict{String, Float64},
    total::Dict{String, Float64}, style::Bool)

    if style
        for (key, caption) in type
            fmax(fmt, width, show, caption, "Type")

            if haskey(minLabel, key)
                fmax(fmt, width, show, minLabel[key], "Minimum Label")
                fmax(fmt, width, show, minValue[key], "Minimum Value")
            end

            if haskey(maxLabel, key)
                fmax(fmt, width, show, maxLabel[key], "Maximum Label")
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

function printHeader(io::IO, hfmt::Dict{String, Format}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    heading::OrderedDict{String, Int64}, subheading::Dict{String, String}, delimiter::String,
    header::Bool, style::Bool, maxLine::Int64)

    if header
        if style
            printf(io, delimiter, maxLine, style, header)
            printf(io, heading, delimiter)
            printf(io, hfmt["Empty"], heading, delimiter)
        end
        printf(io, hfmt, width, show, delimiter, style, subheading)
    end
end

function printSummary(io::IO, pfmt::Dict{String, Format}, hfmt::Dict{String, Format}, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, type::OrderedDict{String, String},
    inuse::Dict{String, Float64}, minLabel::Dict{String, String}, minValue::Dict{String, Float64}, maxLabel::Dict{String, String}, maxValue::Dict{String, Float64},
    total::Dict{String, Float64}, delimiter::String, maxLine::Int64, style::Bool, footer::Bool, breakLine::Int64)

    cnt = 1
    @inbounds for (key, caption) in type
        if (cnt - 1) % breakLine == 0 && cnt != 1
            printf(io, hfmt, width, show, delimiter, style)
        end

        printf(io, pfmt, show, width, caption, "Type")

        if haskey(minLabel, key)
            printf(io, pfmt, show, width, minLabel[key], "Minimum Label")
            printf(io, pfmt, show, width, minValue[key], "Minimum Value")
        else
            printf(io, hfmt, show, width, "", "Minimum Label")
            printf(io, hfmt, show, width, "", "Minimum Value")
        end

        if haskey(maxLabel, key)
            printf(io, pfmt, show, width, maxLabel[key], "Maximum Label")
            printf(io, pfmt, show, width, maxValue[key], "Maximum Value")
        else
            printf(io, hfmt, show, width, "", "Maximum Label")
            printf(io, hfmt, show, width, "", "Maximum Value")
        end

        if haskey(inuse, key)
            printf(io, pfmt, show, width, inuse[key], "In-Use")
        else
            printf(io, hfmt, show, width, "", "In-Use")
        end

        if haskey(total, key)
            printf(io, pfmt, show, width, total[key], "Total")
        else
            printf(io, hfmt, show, width, "", "Total")
        end

        @printf io "\n"
        cnt += 1
    end
    printf(io, delimiter, maxLine, style, footer)
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
    maxValue::Dict{String, Float64}, total::Dict{String, Float64}, value::Float64, i::Int64, key::String)

    summaryData(minIndex, minValue, maxIndex, maxValue, value, i, key)
    total[key] += value
end

function summaryData(minIndex::Dict{String, Int64}, minValue::Dict{String, Float64}, maxIndex::Dict{String, Int64},
    maxValue::Dict{String, Float64}, value::Float64, i::Int64, key::String)

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

function lineBreak(analysis::AC)
    return 3
end

function lineBreak(analysis::DC)
    return 2
end