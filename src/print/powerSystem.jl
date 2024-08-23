"""
    printBusData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
fmt = Dict("Power Demand" => "%.2f", "Voltage Magnitude" => "%.2f", "Label" => "%-s")
show = Dict("Power Injection" => false, "Power Generation Reactive" => false)
printBusData(system, analysis; fmt, show)

# Print data for specific buses
delimiter = " "
width = Dict("Voltage" => 9, "Power Injection Active" => 9)
printBusData(system, analysis; label = 2, delimiter, width, header = true)
printBusData(system, analysis; label = 10, delimiter, width)
printBusData(system, analysis; label = 12, delimiter, width)
printBusData(system, analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBusData(system::PowerSystem, analysis::AC, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatBusData(system, analysis, label, scale, prefix, fmt, width, show, style)

    if printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.bus, system.bus.label, header, footer, "bus")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Bus Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthVol = printf(io, width, show, delimiter, "Voltage", "Voltage Magnitude", "Voltage Angle")
                widthGen = printf(io, width, show, delimiter, "Power Generation", "Power Generation Active", "Power Generation Reactive")
                widthDem = printf(io, width, show, delimiter, "Power Demand", "Power Demand Active", "Power Demand Reactive")
                widthInj = printf(io, width, show, delimiter, "Power Injection", "Power Injection Active", "Power Injection Reactive")
                widthShu = printf(io, width, show, delimiter, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive")
                widthCur = printf(io, width, show, delimiter, "Current Injection", "Current Injection Magnitude", "Current Injection Angle")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthVol)
                printf(io, hfmt["Empty"], widthGen)
                printf(io, hfmt["Empty"], widthDem)
                printf(io, hfmt["Empty"], widthInj)
                printf(io, hfmt["Empty"], widthShu)
                printf(io, hfmt["Empty"], widthCur)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "Voltage Magnitude", "Voltage Angle")
            printf(io, hfmt, width, show, subheader, "Power Generation Active", "Power Generation Reactive")
            printf(io, hfmt, width, show, subheader, "Power Demand Active", "Power Demand Reactive")
            printf(io, hfmt, width, show, subheader, "Power Injection Active", "Power Injection Reactive")
            printf(io, hfmt, width, show, subheader, "Shunt Power Active", "Shunt Power Reactive")
            printf(io, hfmt, width, show, subheader, "Current Injection Magnitude", "Current Injection Angle")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit,"Voltage Magnitude", "Voltage Angle")
            printf(io, hfmt, width, show, unit, "Power Generation Active", "Power Generation Reactive")
            printf(io, hfmt, width, show, unit, "Power Demand Active", "Power Demand Reactive")
            printf(io, hfmt, width, show, unit, "Power Injection Active", "Power Injection Reactive")
            printf(io, hfmt, width, show, unit, "Shunt Power Active", "Shunt Power Reactive")
            printf(io, hfmt, width, show, unit, "Current Injection Magnitude", "Current Injection Angle")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "Voltage Magnitude", "Voltage Angle")
                printf(io, hfmt["Break"], width, show, "Power Generation Active", "Power Generation Reactive")
                printf(io, hfmt["Break"], width, show, "Power Demand Active", "Power Demand Reactive")
                printf(io, hfmt["Break"], width, show, "Power Injection Active", "Power Injection Reactive")
                printf(io, hfmt["Break"], width, show, "Shunt Power Active", "Shunt Power Reactive")
                printf(io, hfmt["Break"], width, show, "Current Injection Magnitude", "Current Injection Angle")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
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

        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current

    _fmt = Dict(
        "Voltage"           => "",
        "Power Generation"  => "",
        "Power Demand"      => "",
        "Power Injection"   => "",
        "Shunt Power"       => "",
        "Current Injection" => ""
    )
    _width = Dict(
        "Voltage"           => 0,
        "Power Generation"  => 0,
        "Power Demand"      => 0,
        "Power Injection"   => 0,
        "Shunt Power"       => 0,
        "Current Injection" => 0
    )
    _show = OrderedDict(
        "Voltage"           => true,
        "Power Generation"  => true,
        "Power Demand"      => true,
        "Power Injection"   => true,
        "Shunt Power"       => true,
        "Current Injection" => true
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
            width["Label"] = max(textwidth(label), width["Label"])

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
                width["Label"] = max(textwidth(label), width["Label"])

                if prefix.voltageMagnitude != 0.0
                    maxV = max(voltage.magnitude[i] * scaleVoltage(system.base.voltage, prefix, i), maxV)
                end

                if _show["Current Injection Magnitude"] && prefix.currentMagnitude != 0.0
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

        titlemax(width, show, "Voltage", "Voltage Magnitude", "Voltage Angle")
        titlemax(width, show, "Power Generation", "Power Generation Active", "Power Generation Reactive")
        titlemax(width, show, "Power Demand", "Power Demand Active", "Power Demand Reactive")
        titlemax(width, show, "Power Injection", "Power Injection Active", "Power Injection Reactive")
        titlemax(width, show, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive")
        titlemax(width, show, "Current Injection", "Current Injection Magnitude", "Current Injection Angle")
    end
    printing = howManyPrint(width, show, style, "Bus Data")

    return fmt, width, show, subheader, unit, printing
end

function printBusData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatBusData(system, analysis, label, scale, fmt, width, show, style)

    if printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.bus, system.bus.label, header, footer, "bus")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Bus Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthVol = printf(io, width, show, delimiter, "Voltage", "Voltage Angle")
                widthGen = printf(io, width, show, delimiter, "Power Generation", "Power Generation Active")
                widthDem = printf(io, width, show, delimiter, "Power Demand", "Power Demand Active")
                widthInj = printf(io, width, show, delimiter, "Power Injection", "Power Injection Active")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthVol)
                printf(io, hfmt["Empty"], widthGen)
                printf(io, hfmt["Empty"], widthDem)
                printf(io, hfmt["Empty"], widthInj)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "Voltage Angle")
            printf(io, hfmt, width, show, subheader, "Power Generation Active")
            printf(io, hfmt, width, show, subheader, "Power Demand Active")
            printf(io, hfmt, width, show, subheader, "Power Injection Active")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit, "Voltage Angle")
            printf(io, hfmt, width, show, unit,"Power Generation Active")
            printf(io, hfmt, width, show, unit,"Power Demand Active")
            printf(io, hfmt, width, show, unit,"Power Injection Active")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "Voltage Angle")
                printf(io, hfmt["Break"], width, show, "Power Generation Active")
                printf(io, hfmt["Break"], width, show, "Power Demand Active")
                printf(io, hfmt["Break"], width, show, "Power Injection Active")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.voltage.angle, i, scale["θ"], "Voltage Angle")

            printf(io, pfmt, show, width, analysis.power.supply.active, i, scale["P"], "Power Generation Active")
            printf(io, pfmt, show, width, system.bus.demand.active, i, scale["P"], "Power Demand Active")
            printf(io, pfmt, show, width, analysis.power.injection.active, i, scale["P"], "Power Injection Active")

            @printf io "\n"
        end

        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    power = analysis.power

    _fmt = Dict(
        "Voltage"          => "",
        "Power Generation" => "",
        "Power Demand"     => "",
        "Power Injection"  => ""
    )
    _width = Dict(
        "Voltage"          => 0,
        "Power Generation" => 0,
        "Power Demand"     => 0,
        "Power Injection"  => 0
    )
    _show = OrderedDict(
        "Voltage"          => true,
        "Power Generation" => true,
        "Power Demand"     => true,
        "Power Injection"  => true
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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

            width["Label"] = max(textwidth(label), width["Label"])

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
                width["Label"] = max(textwidth(label), width["Label"])
            end
        end
    end

    printing = howManyPrint(width, show, style, "Bus Data")

    return fmt, width, show, subheader, unit, printing
end

"""
    printBranchData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printBranchData(system, analysis; fmt, show)

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
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatBranchData(system, analysis, label, scale, prefix, fmt, width, show, style)

    if printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.branch, system.branch.label, header, footer, "branch")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Branch Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthFbp = printf(io, width, show, delimiter, "From-Bus Power", "From-Bus Power Active", "From-Bus Power Reactive")
                widthTbp = printf(io, width, show, delimiter, "To-Bus Power", "To-Bus Power Active", "To-Bus Power Reactive")
                widthSht = printf(io, width, show, delimiter, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive")
                widthSrp = printf(io, width, show, delimiter, "Series Power", "Series Power Active", "Series Power Reactive")
                widthFbc = printf(io, width, show, delimiter, "From-Bus Current", "From-Bus Current Magnitude", "From-Bus Current Angle")
                widthTbc = printf(io, width, show, delimiter, "To-Bus Current", "To-Bus Current Magnitude", "To-Bus Current Angle")
                widtSrc = printf(io, width, show, delimiter, "Series Current", "Series Current Magnitude", "Series Current Angle")
                widthSts = printf(io, width, show, delimiter, "Status", "Status")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthFbp)
                printf(io, hfmt["Empty"], widthTbp)
                printf(io, hfmt["Empty"], widthSht)
                printf(io, hfmt["Empty"], widthSrp)
                printf(io, hfmt["Empty"], widthFbc)
                printf(io, hfmt["Empty"], widthTbc)
                printf(io, hfmt["Empty"], widtSrc)
                printf(io, hfmt["Empty"], widthSts)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "From-Bus Power Active", "From-Bus Power Reactive")
            printf(io, hfmt, width, show, subheader, "To-Bus Power Active", "To-Bus Power Reactive")
            printf(io, hfmt, width, show, subheader, "Shunt Power Active", "Shunt Power Reactive")
            printf(io, hfmt, width, show, subheader, "Series Power Active", "Series Power Reactive")
            printf(io, hfmt, width, show, subheader, "From-Bus Current Magnitude", "From-Bus Current Angle")
            printf(io, hfmt, width, show, subheader, "To-Bus Current Magnitude", "To-Bus Current Angle")
            printf(io, hfmt, width, show, subheader, "Series Current Magnitude", "Series Current Angle")
            printf(io, hfmt, width, show, subheader, "Status")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit, "From-Bus Power Active", "From-Bus Power Reactive")
            printf(io, hfmt, width, show, unit, "To-Bus Power Active", "To-Bus Power Reactive")
            printf(io, hfmt, width, show, unit, "Shunt Power Active", "Shunt Power Reactive")
            printf(io, hfmt, width, show, unit, "Series Power Active", "Series Power Reactive")
            printf(io, hfmt, width, show, unit, "From-Bus Current Magnitude", "From-Bus Current Angle")
            printf(io, hfmt, width, show, unit, "To-Bus Current Magnitude", "To-Bus Current Angle")
            printf(io, hfmt, width, show, unit, "Series Current Magnitude", "Series Current Angle")
            printf(io, hfmt, width, show, unit, "Status")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "From-Bus Power Active", "From-Bus Power Reactive")
                printf(io, hfmt["Break"], width, show, "To-Bus Power Active", "To-Bus Power Reactive")
                printf(io, hfmt["Break"], width, show, "Shunt Power Active", "Shunt Power Reactive")
                printf(io, hfmt["Break"], width, show, "Series Power Active", "Series Power Reactive")
                printf(io, hfmt["Break"], width, show, "From-Bus Current Magnitude", "From-Bus Current Angle")
                printf(io, hfmt["Break"], width, show, "To-Bus Current Magnitude", "To-Bus Current Angle")
                printf(io, hfmt["Break"], width, show, "Series Current Magnitude", "Series Current Angle")
                printf(io, hfmt["Break"], width, show, "Status")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
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

        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBranchData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    power = analysis.power
    current = analysis.current

    _fmt = Dict(
        "From-Bus Power"   => "",
        "To-Bus Power"     => "",
        "Shunt Power"      => "",
        "Series Power"     => "",
        "From-Bus Current" => "",
        "To-Bus Current"   => "",
        "Series Current"   => "",
    )
    _width = Dict(
        "From-Bus Power"   => 0,
        "To-Bus Power"     => 0,
        "Shunt Power"      => 0,
        "Series Power"     => 0,
        "From-Bus Current" => 0,
        "To-Bus Current"   => 0,
        "Series Current"   => 0,
    )
    _show = OrderedDict(
        "From-Bus Power"   => true,
        "To-Bus Power"     => true,
        "Shunt Power"      => true,
        "Series Power"     => true,
        "From-Bus Current" => true,
        "To-Bus Current"   => true,
        "Series Current"   => true,
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
            width["Label"] = max(textwidth(label), width["Label"])

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
                width["Label"] = max(textwidth(label), width["Label"])

                if _show["From-Bus Current Magnitude"] && prefix.currentMagnitude != 0.0
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

        titlemax(width, show, "From-Bus Power", "From-Bus Power Active", "From-Bus Power Reactive")
        titlemax(width, show, "To-Bus Power", "To-Bus Power Active", "To-Bus Power Reactive")
        titlemax(width, show, "Shunt Power", "Shunt Power Active", "Shunt Power Reactive")
        titlemax(width, show, "Series Power", "Series Power Active", "Series Power Reactive")
        titlemax(width, show, "From-Bus Current", "From-Bus Current Magnitude", "From-Bus Current Angle")
        titlemax(width, show, "To-Bus Current", "To-Bus Current Magnitude", "To-Bus Current Angle")
        titlemax(width, show, "Series Current", "Series Current Magnitude", "Series Current Angle")
    end

    printing = howManyPrint(width, show, style, "Branch Data")

    return fmt, width, show, subheader, unit, printing
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatBranchData(system, analysis, label, scale, fmt, width, show, style)

    if printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.branch, system.branch.label, header, footer, "branch")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Branch Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthFbp = printf(io, width, show, delimiter, "From-Bus Power", "From-Bus Power Active")
                widthTbp = printf(io, width, show, delimiter, "To-Bus Power", "To-Bus Power Active")
                widthSts = printf(io, width, show, delimiter, "Status", "Status")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthFbp)
                printf(io, hfmt["Empty"], widthTbp)
                printf(io, hfmt["Empty"], widthSts)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "From-Bus Power Active")
            printf(io, hfmt, width, show, subheader, "To-Bus Power Active")
            printf(io, hfmt, width, show, subheader, "Status")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit, "From-Bus Power Active")
            printf(io, hfmt, width, show, unit, "To-Bus Power Active")
            printf(io, hfmt, width, show, unit, "Status")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "From-Bus Power Active")
                printf(io, hfmt["Break"], width, show, "To-Bus Power Active")
                printf(io, hfmt["Break"], width, show, "Status")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")

            printf(io, pfmt, show, width, analysis.power.from.active, i, scale["P"], "From-Bus Power Active")
            printf(io, pfmt, show, width, analysis.power.to.active, i, scale["P"], "To-Bus Power Active")

            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBranchData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    power = analysis.power

    _fmt = Dict(
        "From-Bus Power" => "",
        "To-Bus Power"   => ""
    )
    _width = Dict(
        "From-Bus Power" => 0,
        "To-Bus Power"   => 0
    )
    _show = OrderedDict(
        "From-Bus Power" => true,
        "To-Bus Power"   => true
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
            width["Label"] = max(textwidth(label), width["Label"])

            fmax(fmt, width, show, power.from.active, i, scale["P"], "From-Bus Power Active")
            fmax(fmt, width, show, power.to.active, i, scale["P"], "To-Bus Power Active")
        else
            fminmax(fmt, width, show, power.from.active, scale["P"], "From-Bus Power Active")
            fminmax(fmt, width, show, power.to.active, scale["P"], "To-Bus Power Active")

            @inbounds for (label, i) in system.branch.label
                width["Label"] = max(textwidth(label), width["Label"])
            end
        end
    end

    printing = howManyPrint(width, show, style, "Branch Data")

    return fmt, width, show, subheader, unit, printing
end

"""
    printGeneratorData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printGeneratorData(system, analysis; fmt, show)

# Print data for specific generators
delimiter = " "
width = Dict("Power Output Active" => 7)
printGeneratorData(system, analysis; label = 1, delimiter, width, header = true)
printGeneratorData(system, analysis; label = 4, delimiter, width)
printGeneratorData(system, analysis; label = 5, delimiter, width, footer = true)
```
"""
function printGeneratorData(system::PowerSystem, analysis::AC, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatGeneratorData(system, analysis, label, scale, fmt, width, show, style)

    if printing
            maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.generator, system.generator.label, header, footer, "generator")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Generator Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthOut = printf(io, width, show, delimiter, "Power Output", "Power Output Active", "Power Output Reactive")
                widthSts = printf(io, width, show, delimiter, "Status", "Status")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthOut)
                printf(io, hfmt["Empty"], widthSts)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "Power Output Active", "Power Output Reactive")
            printf(io, hfmt, width, show, subheader, "Status")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit, "Power Output Active", "Power Output Reactive")
            printf(io, hfmt, width, show, unit, "Status")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "Power Output Active", "Power Output Reactive")
                printf(io, hfmt["Break"], width, show, "Status")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")
            printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Power Output Active")
            printf(io, pfmt, show, width, analysis.power.generator.reactive, i, scale["Q"], "Power Output Reactive")
            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")
            @printf io "\n"
        end

        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String,Bool}, style::Bool)

    power = analysis.power

    _fmt = Dict(
        "Power Output" => ""
    )
    _width = Dict(
        "Power Output" => 0
    )
    _show = OrderedDict(
        "Power Output" => true
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
            width["Label"] = max(textwidth(label), width["Label"])

            fmax(fmt, width, show, power.generator.active, i, scale["P"], "Power Output Active")
            fmax(fmt, width, show, power.generator.reactive, i, scale["Q"], "Power Output Reactive")
        else
            fminmax(fmt, width, show, power.generator.active, scale["P"], "Power Output Active")
            fminmax(fmt, width, show, power.generator.reactive, scale["Q"], "Power Output Reactive")

            @inbounds for (label, i) in system.generator.label
                width["Label"] = max(textwidth(label), width["Label"])
            end
        end
        titlemax(width, show, "Power Output", "Power Output Active", "Power Output Reactive")
    end

    printing = howManyPrint(width, show, style, "Generator Data")

    return fmt, width, show, subheader, unit, printing
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, printing = formatGeneratorData(system, analysis, label, scale, fmt, width, show, style)

    if printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, system.generator, system.generator.label, header, footer, "generator")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Generator Data")

                print(io, delimiter)
                widthLab = printf(io, width, show, delimiter, "Label", "Label")
                widthOut = printf(io, width, show, delimiter, "Power Output", "Power Output Active")
                widthSts = printf(io, width, show, delimiter, "Status", "Status")
                @printf io "\n"

                print(io, delimiter)
                printf(io, hfmt["Empty"], widthLab)
                printf(io, hfmt["Empty"], widthOut)
                printf(io, hfmt["Empty"], widthSts)
                @printf io "\n"
            end

            printf(io, hfmt, width, show, subheader, "Label")
            printf(io, hfmt, width, show, subheader, "Power Output Active")
            printf(io, hfmt, width, show, subheader, "Status")
            @printf io "\n"

            printf(io, hfmt, width, show, unit, "Label")
            printf(io, hfmt, width, show, unit, "Power Output Active")
            printf(io, hfmt, width, show, unit, "Status")
            @printf io "\n"

            if style
                print(io, delimiter)
                printf(io, hfmt["Break"], width, show, "Label")
                printf(io, hfmt["Break"], width, show, "Power Output Active")
                printf(io, hfmt["Break"], width, show, "Status")
                @printf io "\n"
            end
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")
            printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Power Output Active")
            printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")
            @printf io "\n"
        end

        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    power = analysis.power

    _fmt = Dict(
        "Power Output" => ""
    )
    _width = Dict(
        "Power Output" => 0
    )
    _show = OrderedDict(
        "Power Output" => true
    )
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
            width["Label"] = max(textwidth(label), width["Label"])

            fmax(fmt, width, show, power.generator.active, i, scale["P"], "Power Output Active")
        else
            fminmax(fmt, width, show, power.generator.active, scale["P"], "Power Output Active")

            @inbounds for (label, i) in system.generator.label
                width["Label"] = max(textwidth(label), width["Label"])
            end
        end
    end

    printing = howManyPrint(width, show, style, "Generator Data")

    return fmt, width, show, subheader, unit, printing
end

"""
    printBusSummary(system::PowerSystem, analysis::Analysis, [io::IO])

The function prints a summary of the electrical quantities related to buses. Optionally,
an `IO` may be passed as the last argument to redirect the output.

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

printBusSummary(system, analysis)
```
"""
function printBusSummary(system::PowerSystem, analysis::AC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, device, unitLive, powerFlag, currentFlag = formatBusSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(device["supply"]) $(plosg("bus", device["supply"])),
        while loads are installed at $(device["demand"]) $(plosg("bus", device["demand"])),
        and shunts are present at $(device["shunt"]) $(plosg("bus", device["shunt"]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, width)

    summaryBlockHeader(io, width, format["V"].title, system.bus.number)
    summaryBlock(io, format["V"], unitLive["V"], width)
    summaryBlock(io, format["θ"], unitLive["θ"], width; line = true)

    if powerFlag
        if device["supply"] != 0
            summaryBlockHeader(io, width, format["Ps"].title, device["supply"])
            summaryBlock(io, format["Ps"], unitLive["P"], width)
            summaryBlock(io, format["Qs"], unitLive["Q"], width; line = true)
        end

        if device["demand"] != 0
            summaryBlockHeader(io, width, format["Pl"].title, device["demand"])
            summaryBlock(io, format["Pl"], unitLive["P"], width)
            summaryBlock(io, format["Ql"], unitLive["Q"], width; line = true)
        end

        summaryBlockHeader(io, width, format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], unitLive["P"], width)
        summaryBlock(io, format["Qi"], unitLive["Q"], width; line = true)

        if device["shunt"] != 0
            summaryBlockHeader(io, width, format["Ph"].title, device["shunt"])
            summaryBlock(io, format["Ph"], unitLive["P"], width)
            summaryBlock(io, format["Qh"], unitLive["Q"], width; line = true)
        end
    end

    if currentFlag
        summaryBlockHeader(io, width, format["I"].title, system.bus.number)
        summaryBlock(io, format["I"], unitLive["I"], width)
        summaryBlock(io, format["ψ"], unitLive["ψ"], width; line = true)
    end
end

function formatBusSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "V"  => SummaryData(title = "Bus Voltage"),
        "θ"  => SummaryData(),
        "Ps" => SummaryData(title = "Power Generation"),
        "Qs" => SummaryData(),
        "Pl" => SummaryData(title = "Power Demand"),
        "Ql" => SummaryData(),
        "Pi" => SummaryData(title = "Power Injection"),
        "Qi" => SummaryData(),
        "Ph" => SummaryData(title = "Shunt Power"),
        "Qh" => SummaryData(),
        "I"  => SummaryData(title = "Current Injection"),
        "ψ"  => SummaryData(),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "supply" => 0,
        "demand" => 0,
        "shunt"  => 0
    )

    powerFlag = !isempty(analysis.power.injection.active)
    currentFlag = !isempty(analysis.current.injection.magnitude)

    for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i])
            device["supply"] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            device["demand"] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            device["shunt"] += 1
        end

        minmaxsumPrint!(format["V"], analysis.voltage.magnitude[i] * scaleVoltage(prefix, system.base.voltage, i), i)
        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if powerFlag
            if !isempty(system.bus.supply.generator[i])
                minmaxsumPrint!(format["Ps"], analysis.power.supply.active[i], i)
                minmaxsumPrint!(format["Qs"], analysis.power.supply.reactive[i], i)
            end

            if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
                minmaxsumPrint!(format["Pl"], system.bus.demand.active[i], i)
                minmaxsumPrint!(format["Ql"], system.bus.demand.reactive[i], i)
            end

            minmaxsumPrint!(format["Pi"], analysis.power.injection.active[i], i)
            minmaxsumPrint!(format["Qi"], analysis.power.injection.reactive[i], i)

            if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
                minmaxsumPrint!(format["Ph"], analysis.power.shunt.active[i], i)
                minmaxsumPrint!(format["Qh"], analysis.power.shunt.reactive[i], i)
            end
        end

        if currentFlag
            minmaxsumPrint!(format["I"], analysis.current.injection.magnitude[i] * scaleCurrent(prefix, system, i), i)
            minmaxsumPrint!(format["ψ"], analysis.current.injection.angle[i], i)
        end
    end

    formatSummary!(format["V"], unitLive["V"], width, system.bus.label, 1.0, system.bus.number; total = false)
    formatSummary!(format["θ"], unitLive["θ"], width, system.bus.label, scale["θ"], system.bus.number; total = false)

    if powerFlag
        formatSummary!(format["Ps"], unitLive["P"], width, system.bus.label, scale["P"], device["supply"])
        formatSummary!(format["Qs"], unitLive["Q"], width, system.bus.label, scale["Q"], device["supply"])

        formatSummary!(format["Pl"], unitLive["P"], width, system.bus.label, scale["P"], device["demand"])
        formatSummary!(format["Ql"], unitLive["Q"], width, system.bus.label, scale["Q"], device["demand"])

        formatSummary!(format["Pi"], unitLive["P"], width, system.bus.label, scale["P"], system.bus.number)
        formatSummary!(format["Qi"], unitLive["Q"], width, system.bus.label, scale["Q"], system.bus.number)

        formatSummary!(format["Ph"], unitLive["P"], width, system.bus.label, scale["P"], device["shunt"])
        formatSummary!(format["Qh"], unitLive["Q"], width, system.bus.label, scale["Q"], device["shunt"])
    end

    if currentFlag
        formatSummary!(format["I"], unitLive["I"], width, system.bus.label, 1.0, system.bus.number; total = false)
        formatSummary!(format["ψ"], unitLive["ψ"], width, system.bus.label, scale["ψ"], system.bus.number; total = false)
    end

    return format, width, device, unitLive, powerFlag, currentFlag
end

function printBusSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, device, unitLive, powerFlag = formatBusSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(device["supply"]) $(plosg("bus", device["supply"])),
        while loads are installed at $(device["demand"]) $(plosg("bus", device["demand"])),
        and shunts are present at $(device["shunt"]) $(plosg("bus", device["shunt"]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, width)

    summaryBlockHeader(io, width, format["θ"].title, system.bus.number)
    summaryBlock(io, format["θ"], unitLive["θ"], width; line = true)

    if powerFlag
        if device["supply"] != 0
            summaryBlockHeader(io, width, format["Ps"].title, device["supply"] )
            summaryBlock(io, format["Ps"], unitLive["P"], width; line = true)
        end

        if device["demand"] != 0
            summaryBlockHeader(io, width, format["Pl"].title, device["demand"])
            summaryBlock(io, format["Pl"], unitLive["P"], width; line = true)
        end

        summaryBlockHeader(io, width, format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], unitLive["P"], width; line = true)
    end
end

function formatBusSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "θ"  => SummaryData(title = "Bus Voltage"),
        "Ps" => SummaryData(title = "Power Generation"),
        "Pl" => SummaryData(title = "Power Demand"),
        "Pi" => SummaryData(title = "Power Injection"),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "supply" => 0,
        "demand" => 0,
        "shunt"  => 0
    )

    powerFlag = !isempty(analysis.power.injection.active)

    for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i])
            device["supply"] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            device["demand"] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            device["shunt"] += 1
        end

        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if powerFlag
            if !isempty(system.bus.supply.generator[i])
                minmaxsumPrint!(format["Ps"], analysis.power.supply.active[i], i)
            end

            if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
                minmaxsumPrint!(format["Pl"], system.bus.demand.active[i], i)
            end

            minmaxsumPrint!(format["Pi"], analysis.power.injection.active[i], i)
        end
    end

    formatSummary!(format["θ"], unitLive["θ"], width, system.bus.label, scale["θ"], system.bus.number; total = false)

    if powerFlag
        formatSummary!(format["Ps"], unitLive["P"], width, system.bus.label, scale["P"], device["supply"])
        formatSummary!(format["Pl"], unitLive["P"], width, system.bus.label, scale["P"], device["demand"])
        formatSummary!(format["Pi"], unitLive["P"], width, system.bus.label, scale["P"], system.bus.number)
    end

    return format, width, device, unitLive, powerFlag
end

"""
    printBranchSummary(system::PowerSystem, analysis::Analysis, [io::IO])

The function prints a summary of the electrical quantities related to branches. Optionally,
an `IO` may be passed as the last argument to redirect the output.

The summary includes average net active and reactive power flows, focusing on the minimum
and maximum branch power flows. For instance, the average net active power flow is calculated
as follows:
```math
  \\bar {P}_{ij} = \\frac{|{P}_{ij} - {P}_{ji}|}{2}.
```

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

printBranchSummary(system, analysis)
```
"""
function printBranchSummary(system::PowerSystem, analysis::AC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, device, unitLive, powerFlag, currentFlag = formatBranchSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "The power system comprises $(system.branch.number) $(plosg("branch", system.branch.number)), of which $(system.branch.layout.inservice) $(isare(system.branch.layout.inservice)) in-service.
        These include $(device["line"]) transmission $(plosg("line", device["line"]; pl = "s")) ($(device["inline"]) in-service),
        $(device["transformer"]) $(plosg("in-phase transformer", device["transformer"]; pl = "s")) ($(device["intransformer"]) in-service),
        and $(device["shift"]) $(plosg("phase-shifting transformer", device["shift"]; pl = "s")) ($(device["inshift"]) in-service)."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Branch Summary")
    summarySubheader(io, maxLine, width)

    if powerFlag
        if device["inline"] != 0
            summaryBlockHeader(io, width, format["Pline"].title, device["inline"])
            summaryBlock(io, format["Pline"], " Net" * unitLive["P"], width)
            summaryBlock(io, format["Qline"], " Net" * unitLive["Q"], width; line = true)
        end

        if device["intransformer"] != 0
            summaryBlockHeader(io, width, format["Pintr"].title, device["intransformer"])
            summaryBlock(io, format["Pintr"], " Net" * unitLive["P"], width)
            summaryBlock(io, format["Qintr"], " Net" * unitLive["Q"], width; line = true)
        end

        if device["inshift"] != 0
            summaryBlockHeader(io, width, format["Pshtr"].title, device["inshift"])
            summaryBlock(io, format["Pshtr"], " Net" * unitLive["P"], width)
            summaryBlock(io, format["Qshtr"], " Net" * unitLive["Q"], width; line = true)
        end

        if device["tie"] != 0
            summaryBlockHeader(io, width, format["Ptie"].title, device["tie"])
            summaryBlock(io, format["Ptie"], " Net" * unitLive["P"], width)
            summaryBlock(io, format["Qtie"], " Net" * unitLive["Q"], width; line = true)
        end

        if device["shunt"] != 0
            summaryBlockHeader(io, width, format["Pshunt"].title, device["shunt"])
            summaryBlock(io, format["Pshunt"], unitLive["P"], width)
            summaryBlock(io, format["Qshunt"], unitLive["Q"], width; line = true)
        end

        if system.branch.layout.inservice != 0
            summaryBlockHeader(io, width, format["Ploss"].title, system.branch.layout.inservice)
            summaryBlock(io, format["Ploss"], unitLive["P"], width)
            summaryBlock(io, format["Qloss"], unitLive["Q"], width; line = true)
        end
    end

    if currentFlag
        if device["inline"] != 0
            summaryBlockHeader(io, width, format["Iline"].title, device["inline"])
            summaryBlock(io, format["Iline"], unitLive["I"], width)
            summaryBlock(io, format["ψline"], unitLive["ψ"], width; line = true)
        end

        if device["intransformer"] != 0
            summaryBlockHeader(io, width, format["Iintr"].title, device["intransformer"])
            summaryBlock(io, format["Iintr"], unitLive["I"], width)
            summaryBlock(io, format["ψintr"], unitLive["ψ"], width; line = true)
        end

        if device["inshift"] != 0
            summaryBlockHeader(io, width, format["Ishtr"].title, device["inshift"])
            summaryBlock(io, format["Ishtr"], unitLive["I"], width)
            summaryBlock(io, format["ψshtr"], unitLive["ψ"], width; line = true)
        end
    end
end

function formatBranchSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pline"  => SummaryData(title = "Transmission Line Power"),
        "Qline"  => SummaryData(),
        "Pintr"  => SummaryData(title = "In-Phase Transformer Power"),
        "Qintr"  => SummaryData(),
        "Pshtr"  => SummaryData(title = "Phase-Shifting Transformer Power"),
        "Qshtr"  => SummaryData(),
        "Ptie"   => SummaryData(title = "Inter-Tie Power"),
        "Qtie"   => SummaryData(),
        "Pshunt" => SummaryData(title = "Shunt Power"),
        "Qshunt" => SummaryData(),
        "Ploss"  => SummaryData(title = "Series Power (Loss)"),
        "Qloss"  => SummaryData(),
        "Iline"  => SummaryData(title = "Transmission Line Current"),
        "ψline"  => SummaryData(),
        "Iintr"  => SummaryData(title = "In-Phase Transformer Current"),
        "ψintr"  => SummaryData(),
        "Ishtr"  => SummaryData(title = "Phase-Shifting Transformer Current"),
        "ψshtr"  => SummaryData()
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "line"          => 0,
        "inline"        => 0,
        "shift"         => 0,
        "inshift"       => 0,
        "transformer"   => 0,
        "intransformer" => 0,
        "shunt"         => 0,
        "tie"           => 0
    )

    powerFlag = !isempty(analysis.power.injection.active)
    currentFlag = !isempty(analysis.current.injection.magnitude)

    for i = 1:system.branch.number
        if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
            device["line"] += 1
            if system.branch.layout.status[i] == 1
                device["inline"] += 1
            end
        elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
            device["transformer"] += 1
            if system.branch.layout.status[i] == 1
                device["intransformer"] += 1
            end
        else
            device["shift"] += 1
            if system.branch.layout.status[i] == 1
                device["inshift"] += 1
            end
        end

        if system.branch.layout.status[i] == 1
            if powerFlag
                if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pline"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                    minmaxsumPrint!(format["Qline"], abs(analysis.power.from.reactive[i] - analysis.power.to.reactive[i]) / 2, i)
                elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pintr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                    minmaxsumPrint!(format["Qintr"], abs(analysis.power.from.reactive[i] - analysis.power.to.reactive[i]) / 2, i)
                else
                    minmaxsumPrint!(format["Pshtr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                    minmaxsumPrint!(format["Qshtr"], abs(analysis.power.from.reactive[i] - analysis.power.to.reactive[i]) / 2, i)
                end

                if system.bus.layout.area[system.branch.layout.from[i]] != system.bus.layout.area[system.branch.layout.to[i]]
                    device["tie"] += 1
                    minmaxsumPrint!(format["Ptie"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                    minmaxsumPrint!(format["Qtie"], abs(analysis.power.from.reactive[i] - analysis.power.to.reactive[i]) / 2, i)
                end

                if system.branch.parameter.conductance[i] != 0.0 || system.branch.parameter.susceptance[i] != 0.0
                    device["shunt"] += 1
                    minmaxsumPrint!(format["Pshunt"], analysis.power.charging.active[i], i)
                    minmaxsumPrint!(format["Qshunt"], analysis.power.charging.reactive[i], i)
                end

                minmaxsumPrint!(format["Ploss"], analysis.power.series.active[i], i)
                minmaxsumPrint!(format["Qloss"], analysis.power.series.reactive[i], i)
            end

            if currentFlag
                currentSeries = analysis.current.series.magnitude[i] * scaleCurrent(prefix, system, system.branch.layout.from[i])

                if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Iline"], currentSeries, i)
                    minmaxsumPrint!(format["ψline"], analysis.current.series.angle[i], i)
                elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Iintr"], currentSeries, i)
                    minmaxsumPrint!(format["ψintr"], analysis.current.series.angle[i], i)
                else
                    minmaxsumPrint!(format["Ishtr"], currentSeries, i)
                    minmaxsumPrint!(format["ψshtr"], analysis.current.series.angle[i], i)
                end
            end
        end
    end

    if powerFlag
        formatSummary!(format["Pline"], unitLive["P"], width, system.branch.label, scale["P"], device["inline"]; total = false)
        formatSummary!(format["Qline"], unitLive["Q"], width, system.branch.label, scale["Q"], device["inline"]; total = false)

        formatSummary!(format["Pintr"], unitLive["P"], width, system.branch.label, scale["P"], device["intransformer"]; total = false)
        formatSummary!(format["Qintr"], unitLive["Q"], width, system.branch.label, scale["Q"], device["intransformer"]; total = false)

        formatSummary!(format["Pshtr"], unitLive["P"], width, system.branch.label, scale["P"], device["inshift"]; total = false)
        formatSummary!(format["Qshtr"], unitLive["Q"], width, system.branch.label, scale["Q"], device["inshift"]; total = false)

        formatSummary!(format["Ptie"], unitLive["P"], width, system.branch.label, scale["P"], device["tie"])
        formatSummary!(format["Qtie"], unitLive["Q"], width, system.branch.label, scale["Q"], device["tie"])

        formatSummary!(format["Pshunt"], unitLive["P"], width, system.branch.label, scale["P"], device["shunt"])
        formatSummary!(format["Qshunt"], unitLive["Q"], width, system.branch.label, scale["Q"], device["shunt"])

        formatSummary!(format["Ploss"], unitLive["P"], width, system.branch.label, scale["P"], system.branch.layout.inservice)
        formatSummary!(format["Qloss"], unitLive["Q"], width, system.branch.label, scale["Q"], system.branch.layout.inservice)
    end

    if currentFlag
        formatSummary!(format["Iline"], unitLive["I"], width, system.branch.label, 1.0, device["inline"]; total = false)
        formatSummary!(format["ψline"], unitLive["ψ"], width, system.branch.label, scale["ψ"], device["inline"]; total = false)

        formatSummary!(format["Iintr"], unitLive["I"], width, system.branch.label, 1.0, device["intransformer"]; total = false)
        formatSummary!(format["ψintr"], unitLive["ψ"], width, system.branch.label, scale["ψ"], device["intransformer"]; total = false)

        formatSummary!(format["Ishtr"], unitLive["I"], width, system.branch.label, 1.0, device["inshift"]; total = false)
        formatSummary!(format["ψshtr"], unitLive["ψ"], width, system.branch.label, scale["ψ"], device["inshift"]; total = false)
    end

    width[6] = max(width[6], textwidth(" Net Reactive [$(unitList.reactivePowerLive)]"))

    return format, width, device, unitLive, powerFlag, currentFlag
end

function printBranchSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, device, unitLive, powerFlag = formatBranchSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "The power system comprises $(system.branch.number) $(plosg("branch", system.branch.number)), of which $(system.branch.layout.inservice) $(isare(system.branch.layout.inservice)) in-service.
        These include $(device["line"]) transmission $(plosg("line", device["line"]; pl = "s")) ($(device["inline"]) in-service),
        $(device["transformer"]) $(plosg("in-phase transformer", device["transformer"]; pl = "s")) ($(device["intransformer"]) in-service),
        and $(device["shift"]) $(plosg("phase-shifting transformer", device["shift"]; pl = "s")) ($(device["inshift"]) in-service)."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Branch Summary")
    summarySubheader(io, maxLine, width)

    if powerFlag
        if device["inline"] != 0
            summaryBlockHeader(io, width, format["Pline"].title, device["inline"])
            summaryBlock(io, format["Pline"], " Net" * unitLive["P"], width; line = true)
        end

        if device["intransformer"] != 0
            summaryBlockHeader(io, width, format["Pintr"].title, device["intransformer"])
            summaryBlock(io, format["Pintr"], " Net" * unitLive["P"], width; line = true)
        end

        if device["inshift"] != 0
            summaryBlockHeader(io, width, format["Pshtr"].title, device["inshift"])
            summaryBlock(io, format["Pshtr"], " Net" * unitLive["P"], width; line = true)
        end

        if device["tie"] != 0
            summaryBlockHeader(io, width, format["Ptie"].title, device["tie"])
            summaryBlock(io, format["Ptie"], " Net" * unitLive["P"], width; line = true)
        end
    end
end

function formatBranchSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pline" => SummaryData(title = "Transmission Line Power"),
        "Pintr" => SummaryData(title = "In-Phase Transformer Power"),
        "Pshtr" => SummaryData(title = "Phase-Shifting Transformer Power"),
        "Ptie"  => SummaryData(title = "Inter-Tie Power"),
        "Pij"   => SummaryData(),
        "Pji"   => SummaryData()
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "line"          => 0,
        "inline"        => 0,
        "shift"         => 0,
        "inshift"       => 0,
        "transformer"   => 0,
        "intransformer" => 0,
        "shunt"         => 0,
        "tie"           => 0
    )

    powerFlag = !isempty(analysis.power.injection.active)

    for i = 1:system.branch.number
        if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
            device["line"] += 1
            if system.branch.layout.status[i] == 1
                device["inline"] += 1
            end
        elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
            device["transformer"] += 1
            if system.branch.layout.status[i] == 1
                device["intransformer"] += 1
            end
        else
            device["shift"] += 1
            if system.branch.layout.status[i] == 1
                device["inshift"] += 1
            end
        end

        if powerFlag
            if system.branch.layout.status[i] == 1
                if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pline"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pintr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                else
                    minmaxsumPrint!(format["Pshtr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                end

                if system.bus.layout.area[system.branch.layout.from[i]] != system.bus.layout.area[system.branch.layout.to[i]]
                    device["tie"] += 1
                    minmaxsumPrint!(format["Ptie"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                end
            end
        end
    end

    if powerFlag
        formatSummary!(format["Pline"], unitLive["P"], width, system.branch.label, scale["P"], device["inline"]; total = false)
        formatSummary!(format["Pintr"], unitLive["P"], width, system.branch.label, scale["P"], device["intransformer"]; total = false)
        formatSummary!(format["Pshtr"], unitLive["P"], width, system.branch.label, scale["P"], device["inshift"]; total = false)
        formatSummary!(format["Ptie"], unitLive["P"], width, system.branch.label, scale["P"], device["tie"]; total = false)
    end

    width[6] = max(width[6], textwidth(" Net Active [$(unitList.activePowerLive)]"))

    return format, width, device, unitLive, powerFlag
end

"""
    printGeneratorSummary(system::PowerSystem, analysis::Analysis, [io::IO])

The function prints a summary of the electrical quantities related to generators.
Optionally, an `IO` may be passed as the last argument to redirect the output.

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

printGeneratorSummary(system, analysis)
```
"""
function printGeneratorSummary(system::PowerSystem, analysis::AC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, unitLive, powerFlag = formatGeneratorSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, width)

    if powerFlag
        summaryBlockHeader(io, width, format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], unitLive["P"], width)
        summaryBlock(io, format["Qg"], unitLive["Q"], width; line = true)
    end
end

function formatGeneratorSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pg" => SummaryData(title = "Power Output"),
        "Qg" => SummaryData()
    )

    width = [0; 0; 0; 0; 5; 0]

    powerFlag = !isempty(analysis.power.generator.active)

    if powerFlag
        for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                minmaxsumPrint!(format["Pg"], analysis.power.generator.active[i], i)
                minmaxsumPrint!(format["Qg"], analysis.power.generator.reactive[i], i)
            end
        end
        formatSummary!(format["Pg"], unitLive["P"], width, system.generator.label, scale["P"], system.generator.layout.inservice)
        formatSummary!(format["Qg"], unitLive["Q"], width, system.generator.label, scale["Q"], system.generator.layout.inservice)
    end

    return format, width, unitLive, powerFlag
end


function printGeneratorSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, width, unitLive, powerFlag = formatGeneratorSummary(system, analysis, scale)
    maxLine = sum(width[:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, width)

    if powerFlag
        summaryBlockHeader(io, width, format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], unitLive["P"], width; line = true)
    end
end

function formatGeneratorSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pg" => SummaryData(title = "Power Output"),
    )

    width = [0; 0; 0; 0; 5; 0]

    powerFlag = !isempty(analysis.power.generator.active)

    if powerFlag
        for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                minmaxsumPrint!(format["Pg"], analysis.power.generator.active[i], i)
            end
        end
        formatSummary!(format["Pg"], unitLive["P"], width, system.generator.label, scale["P"], system.generator.layout.inservice)
    end

    return format, width, unitLive, powerFlag
end