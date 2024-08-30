"""
    printBusConstraint(system::PowerSystem, analysis::OptimalPowerFlow, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints constraint data related to buses. Optionally, an `IO` may be passed as the
last argument to redirect the output.

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
    The function [`printBusConstraint`](@ref printBusConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all buses
fmt = Dict("Active Power Balance" => "%.2e", "Reactive Power Balance Dual" => "%.4e")
show = Dict("Voltage Magnitude" => false, "Reactive Power Balance Solution" => false)
printBusConstraint(system, analysis; fmt, show, repeat = 10)

# Print data for specific buses
delimiter = " "
width = Dict("Voltage Magnitude" => 8, "Active Power Balance Solution" => 12)
printBusConstraint(system, analysis; label = 2, delimiter, width, header = true)
printBusConstraint(system, analysis; label = 10, delimiter, width)
printBusConstraint(system, analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.bus, system.bus.label, label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusConstraint(system, analysis, unitList, prefix, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Bus Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.voltage.magnitude, constraint.balance.active, constraint.balance.reactive)
                scaleVolt = scaleVoltage(prefix, system, i)

                printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                printf(io, pfmt, width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.voltage.magnitude, i)
                    printf(io, pfmt, width, show, i, scaleVolt, system.bus.voltage.minMagnitude, "Voltage Magnitude Minimum")
                    printf(io, pfmt, width, show, i, scaleVolt, analysis.voltage.magnitude, "Voltage Magnitude Solution")
                    printf(io, pfmt, width, show, i, scaleVolt, system.bus.voltage.maxMagnitude, "Voltage Magnitude Maximum")
                    printf(io, pfmt, width, show, i, scaleVolt, dual.voltage.magnitude, "Voltage Magnitude Dual")
                else
                    printf(io, hfmt, width, show, "", "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Maximum", "Voltage Magnitude Dual")
                end

                if isValid(analysis.method.jump, constraint.balance.active, i)
                    printf(io, pfmt, width, show, i, scale["P"], constraint.balance.active, "Active Power Balance Solution")
                    printf(io, pfmt, width, show, i, scale["P"], dual.balance.active, "Active Power Balance Dual")
                else
                    printf(io, hfmt, width, show, "", "Active Power Balance Solution", "Active Power Balance Dual")
                end

                if isValid(analysis.method.jump, constraint.balance.reactive, i)
                    printf(io, pfmt, width, show, i, scale["Q"], constraint.balance.reactive, "Reactive Power Balance Solution")
                    printf(io, pfmt, width, show, i, scale["Q"], dual.balance.reactive, "Reactive Power Balance Dual")
                else
                    printf(io, hfmt, width, show, "", "Reactive Power Balance Solution", "Reactive Power Balance Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    title::Bool, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual
    bus = system.bus

    _show = OrderedDict(
        "Voltage Magnitude"      => true,
        "Active Power Balance"   => true,
        "Reactive Power Balance" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                           => _header_("", "Label", style),
        "Voltage Magnitude Minimum"       => _header_("Minimum", "Voltage Magnitude Minimum", style),
        "Voltage Magnitude Solution"      => _header_("Solution", "Voltage Magnitude Solution", style),
        "Voltage Magnitude Maximum"       => _header_("Maximum", "Voltage Magnitude Maximum", style),
        "Voltage Magnitude Dual"          => _header_("Dual", "Voltage Magnitude Dual", style),
        "Active Power Balance Solution"   => _header_("Solution", "Active Power Balance Solution", style),
        "Active Power Balance Dual"       => _header_("Dual", "Active Power Balance Dual", style),
        "Reactive Power Balance Solution" => _header_("Solution", "Reactive Power Balance Solution", style),
        "Reactive Power Balance Dual"     => _header_("Dual", "Reactive Power Balance Dual", style),
    )
    unit = Dict(
        "Label"                           => "",
        "Voltage Magnitude Minimum"       => "[$(unitList.voltageMagnitudeLive)]",
        "Voltage Magnitude Solution"      => "[$(unitList.voltageMagnitudeLive)]",
        "Voltage Magnitude Maximum"       => "[$(unitList.voltageMagnitudeLive)]",
        "Voltage Magnitude Dual"          => "[\$/$(unitList.voltageMagnitudeLive)-hr]",
        "Active Power Balance Solution"   => "[$(unitList.activePowerLive)]",
        "Active Power Balance Dual"       => "[\$/$(unitList.activePowerLive)-hr]",
        "Reactive Power Balance Solution" => "[$(unitList.reactivePowerLive)]",
        "Reactive Power Balance Dual"     => "[\$/$(unitList.reactivePowerLive)-hr]"
    )
    _fmt = Dict(
        "Label"                           => "%-*s",
        "Voltage Magnitude Minimum"       => _fmt_(_fmt["Voltage Magnitude"]),
        "Voltage Magnitude Solution"      => _fmt_(_fmt["Voltage Magnitude"]),
        "Voltage Magnitude Maximum"       => _fmt_(_fmt["Voltage Magnitude"]),
        "Voltage Magnitude Dual"          => _fmt_(_fmt["Voltage Magnitude"]),
        "Active Power Balance Solution"   => _fmt_(_fmt["Active Power Balance"]),
        "Active Power Balance Dual"       => _fmt_(_fmt["Active Power Balance"]),
        "Reactive Power Balance Solution" => _fmt_(_fmt["Reactive Power Balance"]),
        "Reactive Power Balance Dual"     => _fmt_(_fmt["Reactive Power Balance"])
    )
    _width = Dict(
        "Label"                           => 5 * style,
        "Voltage Magnitude Minimum"       => _width_(_width["Voltage Magnitude"], 7, style),
        "Voltage Magnitude Solution"      => _width_(_width["Voltage Magnitude"], 8, style),
        "Voltage Magnitude Maximum"       => _width_(_width["Voltage Magnitude"], 7, style),
        "Voltage Magnitude Dual"          => _width_(_width["Voltage Magnitude"], textwidth(unit["Voltage Magnitude Dual"]), style),
        "Active Power Balance Solution"   => _width_(_width["Active Power Balance"], 8, style),
        "Active Power Balance Dual"       => _width_(_width["Active Power Balance"], textwidth(unit["Active Power Balance Dual"]), style),
        "Reactive Power Balance Solution" => _width_(_width["Reactive Power Balance"], 8, style),
        "Reactive Power Balance Dual"     => _width_(_width["Reactive Power Balance"], textwidth(unit["Reactive Power Balance Dual"]), style)
    )
    _show = OrderedDict(
        "Label"                           => anycons(analysis.method.jump, constraint.voltage.magnitude, constraint.balance.active, constraint.balance.reactive),
        "Voltage Magnitude Minimum"       => _show_(_show["Voltage Magnitude"], constraint.voltage.magnitude),
        "Voltage Magnitude Solution"      => _show_(_show["Voltage Magnitude"], constraint.voltage.magnitude),
        "Voltage Magnitude Maximum"       => _show_(_show["Voltage Magnitude"], constraint.voltage.magnitude),
        "Voltage Magnitude Dual"          => _show_(_show["Voltage Magnitude"], dual.voltage.magnitude),
        "Active Power Balance Solution"   => _show_(_show["Active Power Balance"], constraint.balance.active),
        "Active Power Balance Dual"       => _show_(_show["Active Power Balance"], dual.balance.active),
        "Reactive Power Balance Solution" => _show_(_show["Reactive Power Balance"], constraint.balance.reactive),
        "Reactive Power Balance Dual"     => _show_(_show["Reactive Power Balance"], dual.balance.reactive)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(bus, label, "bus")
            i = bus.label[label]

            scaleVoltg = scaleVoltage(prefix, system, i)

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.voltage.magnitude, i)
                fmax(fmt, width, show, i, scaleVoltg, bus.voltage.minMagnitude, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, i, scaleVoltg, voltage.magnitude, "Voltage Magnitude Solution")
                fmax(fmt, width, show, i, scaleVoltg, bus.voltage.maxMagnitude, "Voltage Magnitude Maximum")
                fmax(fmt, width, show, i, scaleVoltg, dual.voltage.magnitude, "Voltage Magnitude Dual")
            end

            if isValid(analysis.method.jump, constraint.balance.active, i)
                fmax(fmt, width, show, i, scale["P"], constraint.balance.active, "Active Power Balance Solution")
                fmax(fmt, width, show, i, scale["P"], dual.balance.active, "Active Power Balance Dual")
            end

            if isValid(analysis.method.jump, constraint.balance.reactive, i)
                fmax(fmt, width, show, i, scale["Q"], constraint.balance.reactive, "Reactive Power Balance Solution")
                fmax(fmt, width, show, i, scale["Q"], dual.balance.reactive, "Reactive Power Balance Dual")
            end
        else
            Vmin = -Inf; Vopt = -Inf; Vmax = -Inf; Vdul = [-Inf; Inf]
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]; Qdul = [-Inf; Inf]

            @inbounds for (label, i) in bus.label
                scaleVoltg = scaleVoltage(prefix, system, i)

                fmax(width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.voltage.magnitude, i)
                    fminmax(show, i, scaleVoltg, Vdul, dual.voltage.magnitude, "Voltage Magnitude Dual")
                end

                if isValid(analysis.method.jump, constraint.balance.active, i)
                    fminmax(show, i, scale["P"], Popt, constraint.balance.active, "Active Power Balance Solution")
                    fminmax(show, i, scale["P"], Pdul, dual.balance.active, "Active Power Balance Dual")
                end

                if isValid(analysis.method.jump, constraint.balance.reactive, i)
                    fminmax(show, i, scale["Q"], Qopt, constraint.balance.reactive, "Reactive Power Balance Solution")
                    fminmax(show, i, scale["Q"], Qdul, dual.balance.reactive, "Reactive Power Balance Dual")
                end

                if prefix.voltageMagnitude != 0.0
                    Vmin = fmax(show, i, scaleVoltg, Vmin, bus.voltage.minMagnitude, "Voltage Magnitude Minimum")
                    Vopt = fmax(show, i, scaleVoltg, Vopt, voltage.magnitude, "Voltage Magnitude Solution")
                    Vmax = fmax(show, i, scaleVoltg, Vmax, bus.voltage.maxMagnitude, "Voltage Magnitude Maximum")
                end
            end

            if prefix.voltageMagnitude == 0.0
                fmax(fmt, width, show, bus.voltage.minMagnitude, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, voltage.magnitude, "Voltage Magnitude Solution")
                fmax(fmt, width, show, bus.voltage.minMagnitude, "Voltage Magnitude Maximum")
            else
                fmax(fmt, width, show, Vmin, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, Vopt, "Voltage Magnitude Solution")
                fmax(fmt, width, show, Vmax, "Voltage Magnitude Maximum")
            end
            fminmax(fmt, width, show, Vdul, "Voltage Magnitude Dual")

            fminmax(fmt, width, show, Popt, "Active Power Balance Solution")
            fminmax(fmt, width, show, Pdul, "Active Power Balance Dual")

            fminmax(fmt, width, show, Qopt, "Reactive Power Balance Solution")
            fminmax(fmt, width, show, Qdul, "Reactive Power Balance Dual")
        end
    end
    printing = howManyPrint(width, show, title, style, "Bus Constraint Data")

    heading = OrderedDict(
        "Label"                  => _blank_(width, show, "Label"),
        "Voltage Magnitude"      => _blank_(width, show, style, "Voltage Magnitude", "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Maximum", "Voltage Magnitude Dual"),
        "Active Power Balance"   => _blank_(width, show, style, "Active Power Balance", "Active Power Balance Solution", "Active Power Balance Dual"),
        "Reactive Power Balance" => _blank_(width, show, style, "Reactive Power Balance", "Reactive Power Balance Solution", "Reactive Power Balance Dual")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printBusConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.bus, system.bus.label, label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusConstraint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Bus Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.balance.active)
                printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                printf(io, pfmt, width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.balance.active, i)
                    printf(io, pfmt, width, show, i, scale["P"], constraint.balance.active, "Active Power Balance Solution")
                    printf(io, pfmt, width, show, i, scale["P"], dual.balance.active, "Active Power Balance Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBusConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, unitList::UnitList, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.angle)
    constraint = analysis.method.constraint
    dual = analysis.method.dual
    bus = system.bus

    _show = OrderedDict("Active Power Balance" => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                         => _header_("", "Label", style),
        "Active Power Balance Solution" => _header_("Solution", "Active Power Balance Solution", style),
        "Active Power Balance Dual"     => _header_("Dual", "Active Power Balance Dual", style),
    )
    unit = Dict(
        "Label"                         => "",
        "Active Power Balance Solution" => "[$(unitList.activePowerLive)]",
        "Active Power Balance Dual"     => "[\$/$(unitList.activePowerLive)-hr]",
    )
    _fmt = Dict(
        "Label"                         => "%-*s",
        "Active Power Balance Solution" => _fmt_(_fmt["Active Power Balance"]),
        "Active Power Balance Dual"     => _fmt_(_fmt["Active Power Balance"])
    )
    _width = Dict(
        "Label"                         => 5 * style,
        "Active Power Balance Solution" => _width_(_width["Active Power Balance"], 8, style),
        "Active Power Balance Dual"     => _width_(_width["Active Power Balance"], textwidth("[\$/$(unitList.activePowerLive)-hr]"), style)
    )
    _show = OrderedDict(
        "Label"                         => anycons(analysis.method.jump, constraint.balance.active),
        "Active Power Balance Solution" => _show_(_show["Active Power Balance"], constraint.balance.active),
        "Active Power Balance Dual"     => _show_(_show["Active Power Balance"], dual.balance.active)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(bus, label, "bus")
            i = bus.label[label]

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.balance.active, i)
                fmax(fmt, width, show, i, scale["P"], constraint.balance.active, "Active Power Balance Solution")
                fmax(fmt, width, show, i, scale["P"], dual.balance.active, "Active Power Balance Dual")
            end
        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]

            @inbounds for (label, i) in bus.label
                fmax(width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.balance.active, i)
                    fminmax(show, i, scale["P"], Popt, constraint.balance.active, "Active Power Balance Solution")
                    fminmax(show, i, scale["P"], Pdul, dual.balance.active, "Active Power Balance Dual")
                end
            end
            fminmax(fmt, width, show, Popt, "Active Power Balance Solution")
            fminmax(fmt, width, show, Pdul, "Active Power Balance Dual")
        end
    end
    printing = howManyPrint(width, show, title, style, "Bus Constraint Data")

    heading = OrderedDict(
        "Label"                => _blank_(width, show, "Label"),
        "Active Power Balance" => _blank_(width, show, style, "Active Power Balance", "Active Power Balance Solution", "Active Power Balance Dual"),
    )

    return fmt, width, show, heading, subheading, unit, printing
end

"""
    printBranchConstraint(system::PowerSystem, analysis::OptimalPowerFlow, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints constraint data related to branches. Optionally, an `IO` may be passed as
the last argument to redirect the output.

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
    The function [`printBranchConstraint`](@ref printBranchConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")
updateBranch!(system; label = 3, minDiffAngle = 0.05, maxDiffAngle = 1.5)
updateBranch!(system; label = 4, minDiffAngle = 0.05, maxDiffAngle = 1.1)
updateBranch!(system; label = 4, maxFromBus = 0.4, maxToBus = 0.5)
updateBranch!(system; label = 9, minFromBus = 0.1, maxFromBus = 0.3)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all branches
fmt = Dict("Voltage Angle Difference" => "%.2f")
show = Dict("To-Bus Apparent Power Flow Dual" => false)
printBranchConstraint(system, analysis; fmt, show, repeat = 2)

# Print data for specific branches
delimiter = " "
width = Dict("From-Bus Apparent Power Flow" => 13, "Voltage Angle Difference Dual" => 12)
printBranchConstraint(system, analysis; label = 3, delimiter, width, header = true)
printBranchConstraint(system, analysis; label = 4, delimiter, width)
printBranchConstraint(system, analysis; label = 9, delimiter, width, footer = true)
```
"""
function printBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    types, typeVec = checkFlowType(system, analysis.method.jump, constraint.voltage.angle, constraint.flow.from, constraint.flow.to)

    for (k, type) in enumerate(types)
        flow, unitFlow = flowType(type, unitList)
        labels, title, header, footer = formPrint(system.branch, system.branch.label, label, title, header, footer, "branch")
        _fmt, _width, _show, heading, subheading, unit, flow, printing = formatBranchConstraint(system, analysis, unitList, prefix, scale, label, fmt, width, show, title, style, type, typeVec, flow, unitFlow)

        if printing
            pfmt, hfmt, maxLine = setupPrint(_fmt, _width, _show, delimiter, style)
            titlePrint(io, delimiter, title, header, style, maxLine, "Branch Constraint Data")

            if type != 3
                scaleFrom, scaleTo = flowScale(scale, type)
            end
            cnt = 1
            @inbounds for (label, i) in labels
                if typeVec[i] == type
                    if checkLine(analysis.method.jump, i, constraint.voltage.angle, constraint.flow.from, constraint.flow.to)
                        if type == 3
                            scaleFrom, scaleTo = flowScale(system, prefix, i)
                        end

                        printing = headerPrint(io, hfmt, _width, _show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                        printf(io, pfmt, _width, _show, label, "Label")

                        if isValid(analysis.method.jump, constraint.voltage.angle, i)
                            printf(io, pfmt, _width, _show, i, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
                            printf(io, pfmt, _width, _show, i, scale["θ"], constraint.voltage.angle, "Voltage Angle Difference Solution")
                            printf(io, pfmt, _width, _show, i, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
                            printf(io, pfmt, _width, _show, i, scale["θ"], dual.voltage.angle, "Voltage Angle Difference Dual")
                        else
                            printf(io, hfmt, _width, _show, "", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual")
                        end

                        if isValid(analysis.method.jump, constraint.flow.from, i)
                            if system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2
                                printf(io, pfmt, _width, _show, 0.0, flow[1])
                            else
                                printf(io, pfmt, _width, _show, i, scaleFrom, system.branch.flow.minFromBus, flow[1])
                            end
                            printf(io, pfmt, _width, _show, i, scaleFrom, constraint.flow.from, flow[2])
                            printf(io, pfmt, _width, _show, i, scaleFrom, system.branch.flow.maxFromBus, flow[3])
                            printf(io, pfmt, _width, _show, i, scaleFrom, dual.flow.from, flow[4])
                        else
                            printf(io, hfmt, _width, _show, "", flow[1], flow[2], flow[3], flow[4])
                        end

                        if isValid(analysis.method.jump, constraint.flow.to, i)
                            if system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2
                                printf(io, pfmt, _width, _show, 0.0, flow[5])
                            else
                                printf(io, pfmt, _width, _show, i, scaleTo, system.branch.flow.minToBus, flow[5])
                            end
                            printf(io, pfmt, _width, _show, i, scaleTo, constraint.flow.to, flow[6])
                            printf(io, pfmt, _width, _show, i, scaleTo, system.branch.flow.maxToBus, flow[7])
                            printf(io, pfmt, _width, _show, i, scaleTo, dual.flow.to, flow[8])
                        else
                            printf(io, hfmt, _width, _show, "", flow[5], flow[6], flow[7], flow[8])
                        end

                        @printf io "\n"
                        cnt += 1
                    end
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end
    end
end

function formatBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, unitList::UnitList, prefix::PrefixLive,
    scale::Dict{String, Float64}, label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    title::Bool, style::Bool, type::Int64, typeVec::Array{Int8,1}, flow::String, unitFlow::String)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    flow = ["From-Bus $flow Minimum"; "From-Bus $flow Solution"; "From-Bus $flow Maximum"; "From-Bus $flow Dual";
            "To-Bus $flow Minimum"; "To-Bus $flow Solution"; "To-Bus $flow Maximum"; "To-Bus $flow Dual";
            "From-Bus $flow"; "To-Bus $flow"]

    _show = OrderedDict(
        "Voltage Angle Difference" => true,
        flow[9]                    => true,
        flow[10]                   => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                             => _header_("", "Label", style),
        "Voltage Angle Difference Minimum"  => _header_("Minimum", "Voltage Angle Difference Minimum", style),
        "Voltage Angle Difference Solution" => _header_("Solution", "Voltage Angle Difference Solution", style),
        "Voltage Angle Difference Maximum"  => _header_("Maximum", "Voltage Angle Difference Maximum", style),
        "Voltage Angle Difference Dual"     => _header_("Dual", "Voltage Angle Difference Dual", style),
        flow[1]                             => _header_("Minimum", flow[1], style),
        flow[2]                             => _header_("Solution", flow[2], style),
        flow[3]                             => _header_("Maximum", flow[3], style),
        flow[4]                             => _header_("Dual", flow[4], style),
        flow[5]                             => _header_("Minimum", flow[5], style),
        flow[6]                             => _header_("Solution", flow[6], style),
        flow[7]                             => _header_("Maximum", flow[7], style),
        flow[8]                             => _header_("Dual", flow[8], style)
    )
    unit = Dict(
        "Label"                             => "",
        "Voltage Angle Difference Minimum"  => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Solution" => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Maximum"  => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Dual"     => "[\$/$(unitList.voltageAngleLive)-hr]",
        flow[1]                             => "[$unitFlow]",
        flow[2]                             => "[$unitFlow]",
        flow[3]                             => "[$unitFlow]",
        flow[4]                             => "[\$/$unitFlow-hr]",
        flow[5]                             => "[$unitFlow]",
        flow[6]                             => "[$unitFlow]",
        flow[7]                             => "[$unitFlow]",
        flow[8]                             => "[\$/$unitFlow-hr]"
    )
    _fmt = Dict(
        "Label"                             => "%-*s",
        "Voltage Angle Difference Minimum"  => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Solution" => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Maximum"  => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Dual"     => _fmt_(_fmt["Voltage Angle Difference"]),
        flow[1]                             => _fmt_(_fmt[flow[9]]),
        flow[2]                             => _fmt_(_fmt[flow[9]]),
        flow[3]                             => _fmt_(_fmt[flow[9]]),
        flow[4]                             => _fmt_(_fmt[flow[9]]),
        flow[5]                             => _fmt_(_fmt[flow[10]]),
        flow[6]                             => _fmt_(_fmt[flow[10]]),
        flow[7]                             => _fmt_(_fmt[flow[10]]),
        flow[8]                             => _fmt_(_fmt[flow[10]]),
    )
    _width = Dict(
        "Label"                             => 5 * style,
        "Voltage Angle Difference Minimum"  => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Solution" => _width_(_width["Voltage Angle Difference"], 8, style),
        "Voltage Angle Difference Maximum"  => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Dual"     => _width_(_width["Voltage Angle Difference"], textwidth(unit["Voltage Angle Difference Dual"]), style),
        flow[1]                             => _width_(_width[flow[9]], 7, style),
        flow[2]                             => _width_(_width[flow[9]], 8, style),
        flow[3]                             => _width_(_width[flow[9]], 7, style),
        flow[4]                             => _width_(_width[flow[9]], textwidth(unit[flow[4]]), style),
        flow[5]                             => _width_(_width[flow[10]], 7, style),
        flow[6]                             => _width_(_width[flow[10]], 8, style),
        flow[7]                             => _width_(_width[flow[10]], 7, style),
        flow[8]                             => _width_(_width[flow[10]], textwidth(unit[flow[8]]), style)
    )
    _show = OrderedDict(
        "Label"                             => anycons(analysis.method.jump, constraint.voltage.angle, constraint.flow.from, constraint.flow.to),
        "Voltage Angle Difference Minimum"  => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Solution" => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Maximum"  => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Dual"     => _show_(_show["Voltage Angle Difference"], dual.voltage.angle),
        flow[1]                             => _show_(_show[flow[9]], constraint.flow.from),
        flow[2]                             => _show_(_show[flow[9]], constraint.flow.from),
        flow[3]                             => _show_(_show[flow[9]], constraint.flow.from),
        flow[4]                             => _show_(_show[flow[9]], dual.flow.from),
        flow[5]                             => _show_(_show[flow[10]], constraint.flow.to),
        flow[6]                             => _show_(_show[flow[10]], constraint.flow.to),
        flow[7]                             => _show_(_show[flow[10]], constraint.flow.to),
        flow[8]                             => _show_(_show[flow[10]], dual.flow.to)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            scaleFrom, scaleTo = flowScale(system, prefix, scale, i, type)

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.voltage.angle, i)
                fmax(fmt, width, show, i, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
                fmax(fmt, width, show, i, scale["θ"], constraint.voltage.angle, "Voltage Angle Difference Solution")
                fmax(fmt, width, show, i, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
                fmax(fmt, width, show, i, scale["θ"], dual.voltage.angle, "Voltage Angle Difference Dual")
            end

            if isValid(analysis.method.jump, constraint.flow.from, i)
                if !(system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2)
                    fmax(fmt, width, show, i, scaleFrom, system.branch.flow.minFromBus, flow[1])
                end
                fmax(fmt, width, show, i, scaleFrom, constraint.flow.from, flow[2])
                fmax(fmt, width, show, i, scaleFrom, system.branch.flow.maxFromBus, flow[3])
                fmax(fmt, width, show, i, scaleFrom, dual.flow.from, flow[4])
            end

            if isValid(analysis.method.jump, constraint.flow.to, i)
                if !(system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2)
                    fmax(fmt, width, show, i, scaleTo, system.branch.flow.minToBus, flow[5])
                end
                fmax(fmt, width, show, i, scaleTo, constraint.flow.to, flow[6])
                fmax(fmt, width, show, i, scaleTo, system.branch.flow.maxToBus, flow[7])
                fmax(fmt, width, show, i, scaleTo, dual.flow.to, flow[8])
            end
        else
            θopt = [-Inf; Inf]; θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]; Fopt = [-Inf; Inf]; Fmax = [-Inf; Inf]; Fdul = [-Inf; Inf]
            Tmin = [-Inf; Inf]; Topt = [-Inf; Inf]; Tmax = [-Inf; Inf]; Tdul = [-Inf; Inf]

            if type != 3
                scaleFrom, scaleTo = flowScale(scale, type)
            end
            @inbounds for (label, i) in system.branch.label
                if typeVec[i] == type
                    if type == 3
                        scaleFrom, scaleTo = flowScale(system, prefix, i)
                    end

                    fmax(width, show, label, "Label")

                    if isValid(analysis.method.jump, constraint.voltage.angle, i)
                        fminmax(show, i, scale["θ"], θopt, constraint.voltage.angle, "Voltage Angle Difference Solution")
                        fminmax(show, i, scale["θ"], θdul, dual.voltage.angle, "Voltage Angle Difference Dual")
                    end

                    if isValid(analysis.method.jump, constraint.flow.from, i)
                        if !(system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2)
                            fminmax(show, i, scaleFrom, Fmin, system.branch.flow.minFromBus, flow[1])
                        end
                        fminmax(show, i, scaleFrom, Fopt, constraint.flow.from, flow[2])
                        fminmax(show, i, scaleFrom, Fmax, system.branch.flow.maxFromBus, flow[3])
                        fminmax(show, i, scaleFrom, Fdul, dual.flow.from, flow[4])
                    end

                    if isValid(analysis.method.jump, constraint.flow.to, i)
                        if !(system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2)
                            fminmax(show, i, scaleTo, Tmin, system.branch.flow.minToBus, flow[5])
                        end
                        fminmax(show, i, scaleTo, Topt, constraint.flow.to, flow[6])
                        fminmax(show, i, scaleTo, Tmax, system.branch.flow.maxToBus, flow[7])
                        fminmax(show, i, scaleTo, Tdul, dual.flow.to, flow[8])
                    end
                end
            end

            fminmax(fmt, width, show, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, θopt, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, θdul, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, Fmin, flow[1])
            fminmax(fmt, width, show, Fopt, flow[2])
            fminmax(fmt, width, show, Fmax, flow[3])
            fminmax(fmt, width, show, Fdul, flow[4])

            fminmax(fmt, width, show, Tmin, flow[5])
            fminmax(fmt, width, show, Topt, flow[6])
            fminmax(fmt, width, show, Tmax, flow[7])
            fminmax(fmt, width, show, Tdul, flow[8])
        end
    end
    printing = howManyPrint(width, show, title, style, "Branch Constraint Data")

    heading = OrderedDict(
        "Label"                    => _blank_(width, show, "Label"),
        "Voltage Angle Difference" => _blank_(width, show, style, "Voltage Angle Difference", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual"),
        flow[9]                    => _blank_(width, show, style, flow[9], flow[1], flow[2], flow[3], flow[4]),
        flow[10]                   => _blank_(width, show, style, flow[10], flow[5], flow[6], flow[7], flow[8])
    )

    return fmt, width, show, heading, subheading, unit, flow, printing
end

function printBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.branch, system.branch.label, label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, printing = formatBranchConstraint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Branch Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.voltage.angle, constraint.flow.active)
                printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                printf(io, pfmt, width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.voltage.angle, i)
                    printf(io, pfmt, width, show, i, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
                    printf(io, pfmt, width, show, i, scale["θ"], constraint.voltage.angle, "Voltage Angle Difference Solution")
                    printf(io, pfmt, width, show, i, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
                    printf(io, pfmt, width, show, i, scale["θ"], dual.voltage.angle, "Voltage Angle Difference Dual")
                else
                    printf(io, hfmt, width, show, "", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual")
                end

                if isValid(analysis.method.jump, constraint.flow.active, i)
                    printf(io, pfmt, width, show, i, scale["P"], system.branch.flow.minFromBus, "From-Bus Active Power Flow Minimum")
                    printf(io, pfmt, width, show, i, scale["P"], constraint.flow.active, "From-Bus Active Power Flow Solution")
                    printf(io, pfmt, width, show, i, scale["P"], system.branch.flow.maxFromBus, "From-Bus Active Power Flow Maximum")
                    printf(io, pfmt, width, show, i, scale["P"], dual.flow.active, "From-Bus Active Power Flow Dual")
                else
                    printf(io, hfmt, width, show, "", "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual")

                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, unitList::UnitList,
    scale::Dict{String, Float64}, label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    title::Bool, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _show = OrderedDict(
        "Voltage Angle Difference"   => true,
        "From-Bus Active Power Flow" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                               => _header_("", "Label", style),
        "Voltage Angle Difference Minimum"    => _header_("Minimum", "Voltage Angle Difference Minimum", style),
        "Voltage Angle Difference Solution"   => _header_("Solution", "Voltage Angle Difference Solution", style),
        "Voltage Angle Difference Maximum"    => _header_("Maximum", "Voltage Angle Difference Maximum", style),
        "Voltage Angle Difference Dual"       => _header_("Dual", "Voltage Angle Difference Dual", style),
        "From-Bus Active Power Flow Minimum"  => _header_("Minimum", "From-Bus Active Power Flow Minimum", style),
        "From-Bus Active Power Flow Solution" => _header_("Solution", "From-Bus Active Power Flow Solution", style),
        "From-Bus Active Power Flow Maximum"  => _header_("Maximum", "From-Bus Active Power Flow Maximum", style),
        "From-Bus Active Power Flow Dual"     => _header_("Dual", "From-Bus Active Power Flow Dual", style),
    )
    unit = Dict(
        "Label"                               => "",
        "Voltage Angle Difference Minimum"    => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Solution"   => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Maximum"    => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Dual"       => "[\$/$(unitList.voltageAngleLive)-hr]",
        "From-Bus Active Power Flow Minimum"  => "[$(unitList.activePowerLive)]",
        "From-Bus Active Power Flow Solution" => "[$(unitList.activePowerLive)]",
        "From-Bus Active Power Flow Maximum"  => "[$(unitList.activePowerLive)]",
        "From-Bus Active Power Flow Dual"     => "[\$/$(unitList.activePowerLive)-hr]",
    )
    _fmt = Dict(
        "Label"                               => "%-*s",
        "Voltage Angle Difference Minimum"    => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Solution"   => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Maximum"    => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Dual"       => _fmt_(_fmt["Voltage Angle Difference"]),
        "From-Bus Active Power Flow Minimum"  => _fmt_(_fmt["From-Bus Active Power Flow"]),
        "From-Bus Active Power Flow Solution" => _fmt_(_fmt["From-Bus Active Power Flow"]),
        "From-Bus Active Power Flow Maximum"  => _fmt_(_fmt["From-Bus Active Power Flow"]),
        "From-Bus Active Power Flow Dual"     => _fmt_(_fmt["From-Bus Active Power Flow"])
    )
    _width = Dict(
        "Label"                               => 5 * style,
        "Voltage Angle Difference Minimum"    => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Solution"   => _width_(_width["Voltage Angle Difference"], 8, style),
        "Voltage Angle Difference Maximum"    => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Dual"       => _width_(_width["Voltage Angle Difference"], textwidth(unit["Voltage Angle Difference Dual"]), style),
        "From-Bus Active Power Flow Minimum"  => _width_(_width["From-Bus Active Power Flow"], 7, style),
        "From-Bus Active Power Flow Solution" => _width_(_width["From-Bus Active Power Flow"], 8, style),
        "From-Bus Active Power Flow Maximum"  => _width_(_width["From-Bus Active Power Flow"], 7, style),
        "From-Bus Active Power Flow Dual"     => _width_(_width["From-Bus Active Power Flow"], textwidth(unit["From-Bus Active Power Flow Dual"]), style)
    )
    _show = OrderedDict(
        "Label"                               => anycons(analysis.method.jump, constraint.voltage.angle, constraint.flow.active),
        "Voltage Angle Difference Minimum"    => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Solution"   => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Maximum"    => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Dual"       => _show_(_show["Voltage Angle Difference"], dual.voltage.angle),
        "From-Bus Active Power Flow Minimum"  => _show_(_show["From-Bus Active Power Flow"], constraint.flow.active),
        "From-Bus Active Power Flow Solution" => _show_(_show["From-Bus Active Power Flow"], constraint.flow.active),
        "From-Bus Active Power Flow Maximum"  => _show_(_show["From-Bus Active Power Flow"], constraint.flow.active),
        "From-Bus Active Power Flow Dual"     => _show_(_show["From-Bus Active Power Flow"], dual.flow.active)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.voltage.angle, i)
                fmax(fmt, width, show, i, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
                fmax(fmt, width, show, i, scale["θ"], constraint.voltage.angle, "Voltage Angle Difference Solution")
                fmax(fmt, width, show, i, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
                fmax(fmt, width, show, i, scale["θ"], dual.voltage.angle, "Voltage Angle Difference Dual")
            end

            if isValid(analysis.method.jump, constraint.flow.active, i)
                fmax(fmt, width, show, i, scale["P"], system.branch.flow.minFromBus, "From-Bus Active Power Flow Minimum")
                fmax(fmt, width, show, i, scale["P"], constraint.flow.active, "From-Bus Active Power Flow Solution")
                fmax(fmt, width, show, i, scale["P"], system.branch.flow.maxFromBus, "From-Bus Active Power Flow Maximum")
                fmax(fmt, width, show, i, scale["P"], dual.flow.active, "From-Bus Active Power Flow Dual")
            end
        else
            θopt = [-Inf; Inf]; θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]; Fopt = [-Inf; Inf]
            Fmax = [-Inf; Inf]; Fdul = [-Inf; Inf]

            @inbounds for (label, i) in system.branch.label
                fmax(width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.voltage.angle, i)
                    fminmax(show, i, scale["θ"], θopt, constraint.voltage.angle, "Voltage Angle Difference Solution")
                    fminmax(show, i, scale["θ"], θdul, dual.voltage.angle, "Voltage Angle Difference Dual")
                end

                if isValid(analysis.method.jump, constraint.flow.active, i)
                    fminmax(show, i, scale["P"], Fmin, system.branch.flow.minFromBus, "From-Bus Active Power Flow Minimum")
                    fminmax(show, i, scale["P"], Fopt, constraint.flow.active, "From-Bus Active Power Flow Solution")
                    fminmax(show, i, scale["P"], Fmax, system.branch.flow.maxFromBus, "From-Bus Active Power Flow Maximum")
                    fminmax(show, i, scale["P"], Fdul, dual.flow.active, "From-Bus Active Power Flow Dual")
                end
            end

            fminmax(fmt, width, show, scale["θ"], system.branch.voltage.minDiffAngle, "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, θopt, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, scale["θ"], system.branch.voltage.maxDiffAngle, "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, θdul, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, Fmin, "From-Bus Active Power Flow Minimum")
            fminmax(fmt, width, show, Fopt, "From-Bus Active Power Flow Solution")
            fminmax(fmt, width, show, Fmax, "From-Bus Active Power Flow Maximum")
            fminmax(fmt, width, show, Fdul, "From-Bus Active Power Flow Dual")
        end
    end
    printing = howManyPrint(width, show, title, style, "Branch Constraint Data")

    heading = OrderedDict(
        "Label"                      => _blank_(width, show, "Label"),
        "Voltage Angle Difference"   => _blank_(width, show, style, "Voltage Angle Difference", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual"),
        "From-Bus Active Power Flow" => _blank_(width, show, style, "From-Bus Active Power Flow", "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual"),
    )

    return fmt, width, show, heading, subheading, unit, printing
end

"""
    printGeneratorConstraint(system::PowerSystem, analysis::OptimalPowerFlow, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints constraint data related to generators. Optionally, an `IO` may be passed as
the last argument to redirect the output.

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
    The function [`printGeneratorConstraint`](@ref printGeneratorConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all generators
fmt = Dict("Active Power Capability" => "%.2f")
show = Dict("Reactive Power Capability" => false, "Active Power Capability Dual" => false)
printGeneratorConstraint(system, analysis; fmt, show, repeat = 3)

# Print data for specific generators
delimiter = " "
width = Dict("Active Power Capability" => 11, "Reactive Power Capability Dual" => 10)
printGeneratorConstraint(system, analysis; label = 2, delimiter, width, header = true)
printGeneratorConstraint(system, analysis; label = 3, delimiter, width)
printGeneratorConstraint(system, analysis; label = 5, delimiter, width, footer = true)
```
"""
function printGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.generator, system.generator.label, label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorConstraint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Generator Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.capability.active, constraint.capability.reactive)
                printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                printf(io, pfmt, width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.capability.active, i)
                    printf(io, pfmt, width, show, i, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
                    printf(io, pfmt, width, show, i, scale["P"], constraint.capability.active, "Active Power Capability Solution")
                    printf(io, pfmt, width, show, i, scale["P"], system.generator.capability.maxActive, "Active Power Capability Maximum")
                    printf(io, pfmt, width, show, i, scale["P"], dual.capability.active, "Active Power Capability Dual")
                else
                    printf(io, hfmt, width, show, "", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual")
                end

                if isValid(analysis.method.jump, constraint.capability.reactive, i)
                    printf(io, pfmt, width, show, i, scale["Q"], system.generator.capability.minReactive, "Reactive Power Capability Minimum")
                    printf(io, pfmt, width, show, i, scale["Q"], constraint.capability.reactive, "Reactive Power Capability Solution")
                    printf(io, pfmt, width, show, i, scale["Q"], system.generator.capability.maxReactive, "Reactive Power Capability Maximum")
                    printf(io, pfmt, width, show, i, scale["Q"], dual.capability.reactive, "Reactive Power Capability Dual")
                else
                    printf(io, hfmt, width, show, "", "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Maximum", "Reactive Power Capability Dual")
                end

                @printf io "\n"
                cnt += 1
            end

        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, unitList::UnitList, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _show = OrderedDict(
        "Active Power Capability"   => true,
        "Reactive Power Capability" => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                              => _header_("", "Label", style),
        "Active Power Capability Minimum"    => _header_("Minimum", "Active Power Capability Minimum", style),
        "Active Power Capability Solution"   => _header_("Solution", "Active Power Capability Solution", style),
        "Active Power Capability Maximum"    => _header_("Maximum", "Active Power Capability Maximum", style),
        "Active Power Capability Dual"       => _header_("Dual", "Active Power Capability Dual", style),
        "Reactive Power Capability Minimum"  => _header_("Minimum", "Reactive Power Capability Minimum", style),
        "Reactive Power Capability Solution" => _header_("Solution", "Reactive Power Capability Solution", style),
        "Reactive Power Capability Maximum"  => _header_("Maximum", "Reactive Power Capability Maximum", style),
        "Reactive Power Capability Dual"     => _header_("Dual", "Reactive Power Capability Dual", style)
    )
    unit = Dict(
        "Label"                              => "",
        "Active Power Capability Minimum"    => "[$(unitList.activePowerLive)]",
        "Active Power Capability Solution"   => "[$(unitList.activePowerLive)]",
        "Active Power Capability Maximum"    => "[$(unitList.activePowerLive)]",
        "Active Power Capability Dual"       => "[\$/$(unitList.activePowerLive)-hr]",
        "Reactive Power Capability Minimum"  => "[$(unitList.reactivePowerLive)]",
        "Reactive Power Capability Solution" => "[$(unitList.reactivePowerLive)]",
        "Reactive Power Capability Maximum"  => "[$(unitList.reactivePowerLive)]",
        "Reactive Power Capability Dual"     => "[\$/$(unitList.reactivePowerLive)-hr]"
    )
    _fmt = Dict(
        "Label"                              => "%-*s",
        "Active Power Capability Minimum"    => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Solution"   => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Maximum"    => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Dual"       => _fmt_(_fmt["Active Power Capability"]),
        "Reactive Power Capability Minimum"  => _fmt_(_fmt["Reactive Power Capability"]),
        "Reactive Power Capability Solution" => _fmt_(_fmt["Reactive Power Capability"]),
        "Reactive Power Capability Maximum"  => _fmt_(_fmt["Reactive Power Capability"]),
        "Reactive Power Capability Dual"     => _fmt_(_fmt["Reactive Power Capability"])
    )
    _width = Dict(
        "Label"                              => 5 * style,
        "Active Power Capability Minimum"    => _width_(_width["Active Power Capability"], 7, style),
        "Active Power Capability Solution"   => _width_(_width["Active Power Capability"], 8, style),
        "Active Power Capability Maximum"    => _width_(_width["Active Power Capability"], 7, style),
        "Active Power Capability Dual"       => _width_(_width["Active Power Capability"], textwidth("[\$/$(unitList.activePowerLive)-hr]"), style),
        "Reactive Power Capability Minimum"  => _width_(_width["Reactive Power Capability"], 7, style),
        "Reactive Power Capability Solution" => _width_(_width["Reactive Power Capability"], 8, style),
        "Reactive Power Capability Maximum"  => _width_(_width["Reactive Power Capability"], 7, style),
        "Reactive Power Capability Dual"     => _width_(_width["Reactive Power Capability"], textwidth("[\$/$(unitList.reactivePowerLive)-hr]"), style)
    )
    _show = OrderedDict(
        "Label"                              => anycons(analysis.method.jump, constraint.capability.active, constraint.capability.reactive),
        "Active Power Capability Minimum"    => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Solution"   => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Maximum"    => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Dual"       => _show_(_show["Active Power Capability"], dual.capability.active),
        "Reactive Power Capability Minimum"  => _show_(_show["Reactive Power Capability"], constraint.capability.reactive),
        "Reactive Power Capability Solution" => _show_(_show["Reactive Power Capability"], constraint.capability.reactive),
        "Reactive Power Capability Maximum"  => _show_(_show["Reactive Power Capability"], constraint.capability.reactive),
        "Reactive Power Capability Dual"     => _show_(_show["Reactive Power Capability"], dual.capability.reactive)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.capability.active, i)
                fmax(fmt, width, show, i, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
                fmax(fmt, width, show, i, scale["P"], constraint.capability.active, "Active Power Capability Solution")
                fmax(fmt, width, show, i, scale["P"], system.generator.capability.maxActive, "Active Power Capability Maximum")
                fmax(fmt, width, show, i, scale["P"], dual.capability.active, "Active Power Capability Dual")
            end

            if isValid(analysis.method.jump, constraint.capability.reactive, i)
                fmax(fmt, width, show, i, scale["Q"], system.generator.capability.minReactive, "Reactive Power Capability Minimum")
                fmax(fmt, width, show, i, scale["Q"], constraint.capability.reactive, "Reactive Power Capability Solution")
                fmax(fmt, width, show, i, scale["Q"], system.generator.capability.maxReactive, "Reactive Power Capability Maximum")
                fmax(fmt, width, show, i, scale["Q"], dual.capability.reactive, "Reactive Power Capability Dual")
            end
        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]; Qdul = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                fmax(width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.capability.active, i)
                    fminmax(show, i, scale["P"], Popt, constraint.capability.active, "Active Power Capability Solution")
                    fminmax(show, i, scale["P"], Pdul, dual.capability.active, "Active Power Capability Dual")
                end

                if isValid(analysis.method.jump, constraint.capability.reactive, i)
                    fminmax(show, i, scale["Q"], Qopt, constraint.capability.reactive, "Reactive Power Capability Solution")
                    fminmax(show, i, scale["Q"], Qdul, dual.capability.reactive, "Reactive Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
            fminmax(fmt, width, show, Popt, "Active Power Capability Solution")
            fminmax(fmt, width, show, scale["P"], system.generator.capability.maxActive,"Active Power Capability Maximum")
            fminmax(fmt, width, show, Pdul, "Active Power Capability Dual")

            fminmax(fmt, width, show, scale["Q"], system.generator.capability.minReactive, "Reactive Power Capability Minimum")
            fminmax(fmt, width, show, Qopt, "Reactive Power Capability Solution")
            fminmax(fmt, width, show, scale["Q"], system.generator.capability.maxReactive, "Reactive Power Capability Maximum")
            fminmax(fmt, width, show, Qdul, "Reactive Power Capability Dual")
        end
    end
    printing = howManyPrint(width, show, title, style, "Generator Constraint Data")

    heading = OrderedDict(
        "Label"                     => _blank_(width, show, "Label"),
        "Active Power Capability"   => _blank_(width, show, style, "Active Power Capability", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual"),
        "Reactive Power Capability" => _blank_(width, show, style, "Reactive Power Capability", "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Maximum", "Reactive Power Capability Dual"),
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printGeneratorConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(system.generator, system.generator.label, label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorConstraint(system, analysis, unitList, scale, label, fmt, width, show, title, style)

    if printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Generator Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.capability.active)
                printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                printf(io, pfmt, width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.capability.active, i)
                    printf(io, pfmt, width, show, i, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
                    printf(io, pfmt, width, show, i, scale["P"], constraint.capability.active, "Active Power Capability Solution")
                    printf(io, pfmt, width, show, i, scale["P"], system.generator.capability.maxActive, "Active Power Capability Maximum")
                    printf(io, pfmt, width, show, i, scale["P"], dual.capability.active, "Active Power Capability Dual")
                else
                    printf(io, hfmt, width, show, "", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, unitList::UnitList, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.angle)
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _show = OrderedDict("Active Power Capability" => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                            => _header_("", "Label", style),
        "Active Power Capability Minimum"  => _header_("Minimum", "Active Power Capability Minimum", style),
        "Active Power Capability Solution" => _header_("Solution", "Active Power Capability Solution", style),
        "Active Power Capability Maximum"  => _header_("Maximum", "Active Power Capability Maximum", style),
        "Active Power Capability Dual"     => _header_("Dual", "Active Power Capability Dual", style)
    )
    unit = Dict(
        "Label"                            => "",
        "Active Power Capability Minimum"  => "[$(unitList.activePowerLive)]",
        "Active Power Capability Solution" => "[$(unitList.activePowerLive)]",
        "Active Power Capability Maximum"  => "[$(unitList.activePowerLive)]",
        "Active Power Capability Dual"     => "[\$/$(unitList.activePowerLive)-hr]"
    )
    _fmt = Dict(
        "Label"                            => "%-*s",
        "Active Power Capability Minimum"  => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Solution" => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Maximum"  => _fmt_(_fmt["Active Power Capability"]),
        "Active Power Capability Dual"     => _fmt_(_fmt["Active Power Capability"])
    )
    _width = Dict(
        "Label"                            => 5 * style,
        "Active Power Capability Minimum"  => _width_(_width["Active Power Capability"], 7, style),
        "Active Power Capability Solution" => _width_(_width["Active Power Capability"], 8, style),
        "Active Power Capability Maximum"  => _width_(_width["Active Power Capability"], 7, style),
        "Active Power Capability Dual"     => _width_(_width["Active Power Capability"], textwidth("[\$/$(unitList.activePowerLive)-hr]"), style)
    )
    _show = OrderedDict(
        "Label"                            => anycons(analysis.method.jump, constraint.capability.active),
        "Active Power Capability Minimum"  => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Solution" => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Maximum"  => _show_(_show["Active Power Capability"], constraint.capability.active),
        "Active Power Capability Dual"     => _show_(_show["Active Power Capability"], dual.capability.active)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, "Label")

            if isValid(analysis.method.jump, constraint.capability.active, i)
                fmax(fmt, width, show, i, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
                fmax(fmt, width, show, i, scale["P"], constraint.capability.active, "Active Power Capability Solution")
                fmax(fmt, width, show, i, scale["P"], system.generator.capability.maxActive, "Active Power Capability Maximum")
                fmax(fmt, width, show, i, scale["P"], dual.capability.active, "Active Power Capability Dual")
            end

        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                fmax(width, show, label, "Label")

                if isValid(analysis.method.jump, constraint.capability.active, i)
                    fminmax(show, i, scale["P"], Popt, constraint.capability.active, "Active Power Capability Solution")
                    fminmax(show, i, scale["P"], Pdul, dual.capability.active, "Active Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, scale["P"], system.generator.capability.minActive, "Active Power Capability Minimum")
            fminmax(fmt, width, show, Popt, "Active Power Capability Solution")
            fminmax(fmt, width, show, scale["P"], system.generator.capability.maxActive,"Active Power Capability Maximum")
            fminmax(fmt, width, show, Pdul, "Active Power Capability Dual")
        end
    end
    printing = howManyPrint(width, show, title, style, "Generator Constraint Data")

    heading = OrderedDict(
        "Label"                   => _blank_(width, show, "Label"),
        "Active Power Capability" => _blank_(width, show, style, "Active Power Capability", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual"),
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function checkLine(jump::JuMP.Model, i::Int64, constraints::Dict{Int64, ConstraintRef}...)
    hasInLine = false
    for constraint in constraints
        hasInLine |= haskey(constraint, i) && is_valid(jump, constraint[i])
    end

    return hasInLine
end

function flowType(type::Int64, unitList::UnitList)
    if type == 1
        flow = "Apparent Power Flow"
        unit = unitList.apparentPowerLive
    elseif type == 2
        flow = "Active Power Flow"
        unit = unitList.activePowerLive
    elseif type == 3
        flow = "Current Flow Magnitude"
        unit = unitList.currentMagnitudeLive
    end

    return flow, unit
end

function anycons(jump::JuMP.Model, constraints::Dict{Int64, ConstraintRef}...)
    existcons = false
    for constraint in constraints
        for i in keys(constraint)
            if haskey(constraint, i) && is_valid(jump, constraint[i])
                existcons = true
                break
            end
        end
        if existcons
            break
        end
    end

    return existcons
end

function checkFlowType(system::PowerSystem, jump::JuMP.Model, angle::Dict{Int64, ConstraintRef}, from::Dict{Int64, ConstraintRef}, to::Dict{Int64, ConstraintRef})
    count = [0; 0; 0]
    for (i, type) in enumerate(system.branch.flow.type)
        if haskey(from, i) && is_valid(jump, from[i]) || haskey(to, i) && is_valid(jump, to[i])
            count[type] += 1
        end
    end

    max_index = argmax(count)
    flowType = copy(system.branch.flow.type)
    for (i, type) in enumerate(system.branch.flow.type)
        if haskey(angle, i) && is_valid(jump, angle[i]) && !(haskey(from, i) && is_valid(jump, from[i])) && !(haskey(to, i) && is_valid(jump, to[i]))
            flowType[i] = max_index
        end
    end

    return findall(x -> x != 0, count), flowType
end

function flowScale(system::PowerSystem, prefix::PrefixLive, scale::Dict{String, Float64}, i::Int64, type::Int64)
    if type == 1 || type == 2
        scaleFrom, scaleTo = flowScale(scale, type)
    elseif type == 3
        scaleFrom, scaleTo = flowScale(system, prefix, i)
    end

    return scaleFrom, scaleTo
end

function flowScale(system::PowerSystem, prefix::PrefixLive, i::Int64)
    return scaleCurrent(prefix, system, system.branch.layout.from[i]), scaleCurrent(prefix, system, system.branch.layout.to[i])
end

function flowScale(scale::Dict{String, Float64}, type::Int64)
    if type == 1
        return scale["S"], scale["S"]
    elseif type == 2
        return scale["P"], scale["P"]
    end
end