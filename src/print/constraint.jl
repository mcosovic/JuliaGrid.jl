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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.bus, system.bus.label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusConstraint(system, analysis, label, scale, prefix, fmt, width, show, title, style)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Bus Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.voltage.magnitude, constraint.balance.active, constraint.balance.reactive)
                printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                printf(io, pfmt, show, width, label, "Label")

                if haskey(constraint.voltage.magnitude, i) && is_valid(analysis.method.jump, constraint.voltage.magnitude[i])
                    printf(io, pfmt, show, width, system.bus.voltage.minMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Minimum")
                    printf(io, pfmt, show, width, analysis.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Solution")
                    printf(io, pfmt, show, width, system.bus.voltage.maxMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Maximum")
                    printf(io, pfmt, show, width, dual.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Dual")
                else
                    printf(io, hfmt, show, width, "", "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Maximum", "Voltage Magnitude Dual")
                end

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    printf(io, pfmt, show, width, constraint.balance.active, i, scale["P"], "Active Power Balance Solution")
                    printf(io, pfmt, show, width, dual.balance.active, i, scale["P"], "Active Power Balance Dual")
                else
                    printf(io, hfmt, show, width, "", "Active Power Balance Solution", "Active Power Balance Dual")
                end

                if haskey(constraint.balance.reactive, i) && is_valid(analysis.method.jump, constraint.balance.reactive[i])
                    printf(io, pfmt, show, width, constraint.balance.reactive, i, scale["Q"], "Reactive Power Balance Solution")
                    printf(io, pfmt, show, width, dual.balance.reactive, i, scale["Q"], "Reactive Power Balance Dual")
                else
                    printf(io, hfmt, show, width, "", "Reactive Power Balance Solution", "Reactive Power Balance Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

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
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            fmax(width, show, label, "Label")

            if haskey(constraint.voltage.magnitude, i) && is_valid(analysis.method.jump, constraint.voltage.magnitude[i])
                fmax(fmt, width, show, system.bus.voltage.minMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Minimum")
                fmax(fmt, width, show, voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Solution")
                fmax(fmt, width, show, system.bus.voltage.maxMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Maximum")
                if haskey(dual.voltage.magnitude, i)
                    fmax(fmt, width, show, dual.voltage.magnitude[i] / scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Dual")
                end
            end

            if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                fmax(fmt, width, show, value(constraint.balance.active[i]) * scale["P"], "Active Power Balance Solution")
                if haskey(dual.balance.active, i)
                    fmax(fmt, width, show, dual.balance.active[i] / scale["P"], "Active Power Balance Dual")
                end
            end

            if haskey(constraint.balance.reactive, i) && is_valid(analysis.method.jump, constraint.balance.reactive[i])
                fmax(fmt, width, show, value(constraint.balance.reactive[i]) * scale["Q"], "Reactive Power Balance Solution")
                if haskey(dual.balance.reactive, i)
                    fmax(fmt, width, show, dual.balance.reactive[i] / scale["Q"], "Reactive Power Balance Dual")
                end
            end
        else
            Vmin = -Inf
            Vopt = -Inf
            Vmax = -Inf
            Vdul = [-Inf; Inf]
            Popt = [-Inf; Inf]
            Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]
            Qdul = [-Inf; Inf]

            @inbounds for (label, i) in system.bus.label
                fmax(width, show, label, "Label")

                if haskey(constraint.voltage.magnitude, i) && is_valid(analysis.method.jump, constraint.voltage.magnitude[i])
                    minmaxDual(show, dual.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), Vdul, "Voltage Magnitude Dual")
                end

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    minmaxPrimal(show, constraint.balance.active[i], scale["P"], Popt, "Active Power Balance Solution")
                    minmaxDual(show, dual.balance.active, i, scale["P"], Pdul, "Active Power Balance Dual")
                end

                if haskey(constraint.balance.reactive, i) && is_valid(analysis.method.jump, constraint.balance.reactive[i])
                    minmaxPrimal(show, constraint.balance.reactive[i], scale["Q"], Qopt, "Reactive Power Balance Solution")
                    minmaxDual(show, dual.balance.reactive, i, scale["Q"], Qdul, "Reactive Power Balance Dual")
                end

                if prefix.voltageMagnitude != 0.0
                    Vmin = max(system.bus.voltage.minMagnitude[i] * scaleVoltage(system.base.voltage, prefix, i), Vmin)
                    Vopt = max(voltage.magnitude[i] * scaleVoltage(system.base.voltage, prefix, i), Vopt)
                    Vmax = max(system.bus.voltage.maxMagnitude[i] * scaleVoltage(system.base.voltage, prefix, i), Vmax)
                end
            end

            if prefix.voltageMagnitude == 0.0
                fmax(fmt, width, show, system.bus.voltage.minMagnitude, 1.0, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, voltage.magnitude, 1.0, "Voltage Magnitude Solution")
                fmax(fmt, width, show, system.bus.voltage.minMagnitude, 1.0, "Voltage Magnitude Maximum")
            else
                fmax(fmt, width, show, Vmin, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, Vopt, "Voltage Magnitude Solution")
                fmax(fmt, width, show, Vmax, "Voltage Magnitude Maximum")
            end
            fminmax(fmt, width, show, Vdul, 1.0, "Voltage Magnitude Dual")

            fminmax(fmt, width, show, Popt, 1.0, "Active Power Balance Solution")
            fminmax(fmt, width, show, Pdul, 1.0, "Active Power Balance Dual")

            fminmax(fmt, width, show, Qopt, 1.0, "Reactive Power Balance Solution")
            fminmax(fmt, width, show, Qdul, 1.0, "Reactive Power Balance Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Bus Constraint Data")

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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.bus, system.bus.label, title, header, footer, "bus")
    fmt, width, show, heading, subheading, unit, printing = formatBusConstraint(system, analysis, label, scale, prefix, fmt, width, show, title, style)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Bus Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.balance.active)
                printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                printf(io, pfmt, show, width, label, "Label")

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    printf(io, pfmt, show, width, constraint.balance.active, i, scale["P"], "Active Power Balance Solution")
                    printf(io, pfmt, show, width, dual.balance.active, i, scale["P"], "Active Power Balance Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatBusConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

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
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            fmax(width, show, label, "Label")

            if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                fmax(fmt, width, show, value(constraint.balance.active[i]) * scale["P"], "Active Power Balance Solution")
                if haskey(dual.balance.active, i)
                    fmax(fmt, width, show, dual.balance.active[i] / scale["P"], "Active Power Balance Dual")
                end
            end
        else
            Popt = [-Inf; Inf]
            Pdul = [-Inf; Inf]

            @inbounds for (label, i) in system.bus.label
                fmax(width, show, label, "Label")

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    minmaxPrimal(show, constraint.balance.active[i], scale["P"], Popt, "Active Power Balance Solution")
                    minmaxDual(show, dual.balance.active, i, scale["P"], Pdul, "Active Power Balance Dual")
                end
            end
            fminmax(fmt, width, show, Popt, 1.0, "Active Power Balance Solution")
            fminmax(fmt, width, show, Pdul, 1.0, "Active Power Balance Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Bus Constraint Data")

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

    scale = printScale(system, prefix)
    types, typeVec = checkFlowType(system, analysis.method.jump, constraint.voltage.angle, constraint.flow.from, constraint.flow.to)

    for (k, type) in enumerate(types)
        flow, unitFlow = flowType(type, unitList)
        labels, title, header, footer = formPrint(label, system.branch, system.branch.label, title, header, footer, "branch")
        _fmt, _width, _show, heading, subheading, unit, printing = formatBranchConstraint(system, analysis, label, scale, prefix, fmt, width, show, style, title, type, typeVec, flow, unitFlow)

        if printing
            maxLine, pfmt, hfmt = setupPrint(_fmt, _width, _show, delimiter, style)

            printTitle(io, maxLine, delimiter, title, header, style, "Branch Constraint Data")

            if type == 1
                scaleFlowFrom = scale["S"]
                scaleFlowTo = scale["S"]
            elseif type == 2
                scaleFlowFrom = scale["P"]
                scaleFlowTo = scale["P"]
            end

            cnt = 1
            @inbounds for (label, i) in labels
                if typeVec[i] == type
                    if checkLine(analysis.method.jump, i, constraint.voltage.angle, constraint.flow.from, constraint.flow.to)
                        printing = printHeader(io, hfmt, _width, _show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                        if type == 3
                            scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                            scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
                        end

                        printf(io, pfmt, _show, _width, label, "Label")

                        if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                            printf(io, pfmt, _show, _width, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                            printf(io, pfmt, _show, _width, constraint.voltage.angle, i, scale["θ"], "Voltage Angle Difference Solution")
                            printf(io, pfmt, _show, _width, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                            printf(io, pfmt, _show, _width, dual.voltage.angle, i, scale["θ"], "Voltage Angle Difference Dual")
                        else
                            printf(io, hfmt, _show, _width, "", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual")
                        end

                        if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                            if system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2
                                printf(io, pfmt, _show, _width, 0.0, "From-Bus $flow Minimum")
                            else
                                printf(io, pfmt, _show, _width, system.branch.flow.minFromBus, i, scaleFlowFrom, "From-Bus $flow Minimum")
                            end
                            printf(io, pfmt, _show, _width, constraint.flow.from, i, scaleFlowFrom, "From-Bus $flow Solution")
                            printf(io, pfmt, _show, _width, system.branch.flow.maxFromBus, i, scaleFlowFrom, "From-Bus $flow Maximum")
                            printf(io, pfmt, _show, _width, dual.flow.from, i, scaleFlowFrom, "From-Bus $flow Dual")
                        else
                            printf(io, hfmt, _show, _width, "", "From-Bus $flow Minimum", "From-Bus $flow Solution", "From-Bus $flow Maximum", "From-Bus $flow Dual")
                        end

                        if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                            if system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2
                                printf(io, pfmt, _show, _width, 0.0, "To-Bus $flow Minimum")
                            else
                                printf(io, pfmt, _show, _width, system.branch.flow.minToBus, i, scaleFlowTo, "To-Bus $flow Minimum")
                            end
                            printf(io, pfmt, _show, _width, constraint.flow.to, i, scaleFlowTo, "To-Bus $flow Solution")
                            printf(io, pfmt, _show, _width, system.branch.flow.maxToBus, i, scaleFlowTo, "To-Bus $flow Maximum")
                            printf(io, pfmt, _show, _width, dual.flow.to, i, scaleFlowTo, "To-Bus $flow Dual")
                        else
                            printf(io, hfmt, _show, _width, "", "To-Bus $flow Minimum", "To-Bus $flow Solution", "To-Bus $flow Maximum", "To-Bus $flow Dual")
                        end

                        @printf io "\n"
                        cnt += 1
                    end
                end
            end
            printf(io, delimiter, maxLine, style, footer)
        end
    end
end

function formatBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool, title::Bool, type::Int64, typeVec::Array{Int8,1}, flow::String, unitFlow::String)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _show = OrderedDict(
        "Voltage Angle Difference" => true,
        "From-Bus $flow"           => true,
        "To-Bus $flow"             => true
    )
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"                             => _header_("", "Label", style),
        "Voltage Angle Difference Minimum"  => _header_("Minimum", "Voltage Angle Difference Minimum", style),
        "Voltage Angle Difference Solution" => _header_("Solution", "Voltage Angle Difference Solution", style),
        "Voltage Angle Difference Maximum"  => _header_("Maximum", "Voltage Angle Difference Maximum", style),
        "Voltage Angle Difference Dual"     => _header_("Dual", "Voltage Angle Difference Dual", style),
        "From-Bus $flow Minimum"            => _header_("Minimum", "From-Bus $flow Minimum", style),
        "From-Bus $flow Solution"           => _header_("Solution", "From-Bus $flow Solution", style),
        "From-Bus $flow Maximum"            => _header_("Maximum", "From-Bus $flow Maximum", style),
        "From-Bus $flow Dual"               => _header_("Dual", "From-Bus $flow Dual", style),
        "To-Bus $flow Minimum"              => _header_("Minimum", "To-Bus $flow Minimum", style),
        "To-Bus $flow Solution"             => _header_("Solution", "To-Bus $flow Solution", style),
        "To-Bus $flow Maximum"              => _header_("Maximum", "To-Bus $flow Maximum", style),
        "To-Bus $flow Dual"                 => _header_("Dual", "To-Bus $flow Dual", style)
    )
    unit = Dict(
        "Label"                             => "",
        "Voltage Angle Difference Minimum"  => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Solution" => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Maximum"  => "[$(unitList.voltageAngleLive)]",
        "Voltage Angle Difference Dual"     => "[\$/$(unitList.voltageAngleLive)-hr]",
        "From-Bus $flow Minimum"            => "[$unitFlow]",
        "From-Bus $flow Solution"           => "[$unitFlow]",
        "From-Bus $flow Maximum"            => "[$unitFlow]",
        "From-Bus $flow Dual"               => "[\$/$unitFlow-hr]",
        "To-Bus $flow Minimum"              => "[$unitFlow]",
        "To-Bus $flow Solution"             => "[$unitFlow]",
        "To-Bus $flow Maximum"              => "[$unitFlow]",
        "To-Bus $flow Dual"                 => "[\$/$unitFlow-hr]"
    )
    _fmt = Dict(
        "Label"                             => "%-*s",
        "Voltage Angle Difference Minimum"  => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Solution" => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Maximum"  => _fmt_(_fmt["Voltage Angle Difference"]),
        "Voltage Angle Difference Dual"     => _fmt_(_fmt["Voltage Angle Difference"]),
        "From-Bus $flow Minimum"            => _fmt_(_fmt["From-Bus $flow"]),
        "From-Bus $flow Solution"           => _fmt_(_fmt["From-Bus $flow"]),
        "From-Bus $flow Maximum"            => _fmt_(_fmt["From-Bus $flow"]),
        "From-Bus $flow Dual"               => _fmt_(_fmt["From-Bus $flow"]),
        "To-Bus $flow Minimum"              => _fmt_(_fmt["To-Bus $flow"]),
        "To-Bus $flow Solution"             => _fmt_(_fmt["To-Bus $flow"]),
        "To-Bus $flow Maximum"              => _fmt_(_fmt["To-Bus $flow"]),
        "To-Bus $flow Dual"                 => _fmt_(_fmt["To-Bus $flow"])

    )
    _width = Dict(
        "Label"                             => 5 * style,
        "Voltage Angle Difference Minimum"  => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Solution" => _width_(_width["Voltage Angle Difference"], 8, style),
        "Voltage Angle Difference Maximum"  => _width_(_width["Voltage Angle Difference"], 7, style),
        "Voltage Angle Difference Dual"     => _width_(_width["Voltage Angle Difference"], textwidth(unit["Voltage Angle Difference Dual"]), style),
        "From-Bus $flow Minimum"            => _width_(_width["From-Bus $flow"], 7, style),
        "From-Bus $flow Solution"           => _width_(_width["From-Bus $flow"], 8, style),
        "From-Bus $flow Maximum"            => _width_(_width["From-Bus $flow"], 7, style),
        "From-Bus $flow Dual"               => _width_(_width["From-Bus $flow"], textwidth(unit["From-Bus $flow Dual"]), style),
        "To-Bus $flow Minimum"              => _width_(_width["To-Bus $flow"], 7, style),
        "To-Bus $flow Solution"             => _width_(_width["To-Bus $flow"], 8, style),
        "To-Bus $flow Maximum"              => _width_(_width["To-Bus $flow"], 7, style),
        "To-Bus $flow Dual"                 => _width_(_width["To-Bus $flow"], textwidth(unit["To-Bus $flow Dual"]), style)
    )
    _show = OrderedDict(
        "Label"                             => anycons(analysis.method.jump, constraint.voltage.angle, constraint.flow.from, constraint.flow.to),
        "Voltage Angle Difference Minimum"  => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Solution" => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Maximum"  => _show_(_show["Voltage Angle Difference"], constraint.voltage.angle),
        "Voltage Angle Difference Dual"     => _show_(_show["Voltage Angle Difference"], dual.voltage.angle),
        "From-Bus $flow Minimum"            => _show_(_show["From-Bus $flow"], constraint.flow.from),
        "From-Bus $flow Solution"           => _show_(_show["From-Bus $flow"], constraint.flow.from),
        "From-Bus $flow Maximum"            => _show_(_show["From-Bus $flow"], constraint.flow.from),
        "From-Bus $flow Dual"               => _show_(_show["From-Bus $flow"], dual.flow.from),
        "To-Bus $flow Minimum"              => _show_(_show["To-Bus $flow"], constraint.flow.to),
        "To-Bus $flow Solution"             => _show_(_show["To-Bus $flow"], constraint.flow.to),
        "To-Bus $flow Maximum"              => _show_(_show["To-Bus $flow"], constraint.flow.to),
        "To-Bus $flow Dual"                 => _show_(_show["To-Bus $flow"], dual.flow.to)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            if system.branch.flow.type[i] == 1
                scaleFlowFrom = scale["S"]
                scaleFlowTo = scale["S"]
            elseif system.branch.flow.type[i] == 2
                scaleFlowFrom = scale["P"]
                scaleFlowTo = scale["P"]
            elseif system.branch.flow.type[i] == 3
                scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
            end

            fmax(width, show, label, "Label")

            if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                fmax(fmt, width, show, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                fmax(fmt, width, show, value(constraint.voltage.angle[i]) * scale["θ"], "Voltage Angle Difference Solution")
                fmax(fmt, width, show, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                if haskey(dual.voltage.angle, i)
                    fmax(fmt, width, show, dual.voltage.angle[i] / scale["θ"], "Voltage Angle Difference Dual")
                end
            end

            if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                if !(system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2)
                    fmax(fmt, width, show, system.branch.flow.minFromBus, i, scaleFlowFrom, "From-Bus $flow Minimum")
                end
                fmax(fmt, width, show, value(constraint.flow.from[i]) * scaleFlowFrom, "From-Bus $flow Solution")
                fmax(fmt, width, show,system.branch.flow.maxFromBus, i, scaleFlowFrom, "From-Bus $flow Maximum")
                if haskey(dual.flow.from, i)
                    fmax(fmt, width, show, dual.flow.from[i] / scaleFlowFrom, "From-Bus $flow Dual")
                end
            end

            if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                if !(system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2)
                    fmax(fmt, width, show, system.branch.flow.minToBus, i, scaleFlowTo, "To-Bus $flow Minimum")
                end
                fmax(fmt, width, show, value(constraint.flow.to[i]) * scaleFlowTo, "To-Bus $flow Solution")
                fmax(fmt, width, show,system.branch.flow.maxToBus, i, scaleFlowTo, "To-Bus $flow Maximum")
                if haskey(dual.flow.to, i)
                    fmax(fmt, width, show, dual.flow.to[i] / scaleFlowTo, "To-Bus $flow Dual")
                end
            end
        else
            θopt = [-Inf; Inf]
            θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]
            Fopt = [-Inf; Inf]
            Fmax = [-Inf; Inf]
            Fdul = [-Inf; Inf]
            Tmin = [-Inf; Inf]
            Topt = [-Inf; Inf]
            Tmax = [-Inf; Inf]
            Tdul = [-Inf; Inf]

            if type == 1
                scaleFlowFrom = scale["S"]
                scaleFlowTo = scale["S"]
            elseif type == 2
                scaleFlowFrom = scale["P"]
                scaleFlowTo = scale["P"]
            end

            @inbounds for (label, i) in system.branch.label
                if typeVec[i] == type
                    fmax(width, show, label, "Label")

                    if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                        minmaxPrimal(show, constraint.voltage.angle[i], scale["θ"], θopt, "Voltage Angle Difference Solution")
                        minmaxDual(show, dual.voltage.angle, i, scale["θ"], θdul, "Voltage Angle Difference Dual")
                    end

                    if type == 3
                        scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                        scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
                    end

                    if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                        if !(system.branch.flow.minFromBus[i] < 0 && system.branch.flow.type[i] != 2)
                            minmaxValue(show, system.branch.flow.minFromBus, i, scaleFlowFrom, Fmin, "From-Bus $flow Minimum")
                        end
                        minmaxPrimal(show, constraint.flow.from[i], scaleFlowFrom, Fopt, "From-Bus $flow Solution")
                        minmaxValue(show, system.branch.flow.maxFromBus, i, scaleFlowFrom, Fmax, "From-Bus $flow Maximum")
                        minmaxDual(show, dual.flow.from, i, scaleFlowFrom, Fdul, "From-Bus $flow Dual")
                    end

                    if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                        if !(system.branch.flow.minToBus[i] < 0 && system.branch.flow.type[i] != 2)
                            minmaxValue(show, system.branch.flow.minToBus, i, scaleFlowTo, Tmin, "To-Bus $flow Minimum")
                        end
                        minmaxPrimal(show, constraint.flow.to[i], scaleFlowTo, Topt, "To-Bus $flow Solution")
                        minmaxValue(show, system.branch.flow.maxToBus, i, scaleFlowTo, Tmax, "To-Bus $flow Maximum")
                        minmaxDual(show, dual.flow.to, i, scaleFlowTo, Tdul, "To-Bus $flow Dual")
                    end
                end
            end

            fminmax(fmt, width, show, system.branch.voltage.minDiffAngle, scale["θ"], "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, θopt, 1.0, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, system.branch.voltage.maxDiffAngle, scale["θ"], "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, θdul, 1.0, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, Fmin, 1.0, "From-Bus $flow Minimum")
            fminmax(fmt, width, show, Fopt, 1.0, "From-Bus $flow Solution")
            fminmax(fmt, width, show, Fmax, 1.0, "From-Bus $flow Maximum")
            fminmax(fmt, width, show, Fdul, 1.0, "From-Bus $flow Dual")

            fminmax(fmt, width, show, Tmin, 1.0, "To-Bus $flow Minimum")
            fminmax(fmt, width, show, Topt, 1.0, "To-Bus $flow Solution")
            fminmax(fmt, width, show, Tmax, 1.0, "To-Bus $flow Maximum")
            fminmax(fmt, width, show, Tdul, 1.0, "To-Bus $flow Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Branch Constraint Data")

    heading = OrderedDict(
        "Label"                    => _blank_(width, show, "Label"),
        "Voltage Angle Difference" => _blank_(width, show, style, "Voltage Angle Difference", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual"),
        "From-Bus $flow"           => _blank_(width, show, style, "From-Bus $flow", "From-Bus $flow Minimum", "From-Bus $flow Solution", "From-Bus $flow Maximum", "From-Bus $flow Dual"),
        "To-Bus $flow"             => _blank_(width, show, style, "To-Bus $flow", "To-Bus $flow Minimum", "To-Bus $flow Solution", "To-Bus $flow Maximum", "To-Bus $flow Dual")
    )

    return fmt, width, show, heading, subheading, unit, printing
end

function printBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = typemax(Int64))

    constraint = analysis.method.constraint
    dual = analysis.method.dual

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.branch, system.branch.label, title, header, footer, "branch")
    fmt, width, show, heading, subheading, unit, printing = formatBranchConstraint(system, analysis, label, scale, prefix, fmt, width, show, title, style)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Branch Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.voltage.angle, constraint.flow.active)
                printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                printf(io, pfmt, show, width, label, "Label")

                if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                    printf(io, pfmt, show, width, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                    printf(io, pfmt, show, width, constraint.voltage.angle, i, scale["θ"], "Voltage Angle Difference Solution")
                    printf(io, pfmt, show, width, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                    printf(io, pfmt, show, width, dual.voltage.angle, i, scale["θ"], "Voltage Angle Difference Dual")
                else
                    printf(io, hfmt, show, width, "", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual")
                end

                if haskey(constraint.flow.active, i) && is_valid(analysis.method.jump, constraint.flow.active[i])
                    printf(io, pfmt, show, width, system.branch.flow.minFromBus, i, scale["P"], "From-Bus Active Power Flow Minimum")
                    printf(io, pfmt, show, width, constraint.flow.active, i, scale["P"], "From-Bus Active Power Flow Solution")
                    printf(io, pfmt, show, width, system.branch.flow.maxFromBus, i, scale["P"], "From-Bus Active Power Flow Maximum")
                    printf(io, pfmt, show, width, dual.flow.active, i, scale["P"], "From-Bus Active Power Flow Dual")
                else
                    printf(io, hfmt, show, width, "", "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual")

                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, maxLine, style, footer)
    end

end

function formatBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

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

            if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                fmax(fmt, width, show, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                fmax(fmt, width, show, value(constraint.voltage.angle[i]) * scale["θ"], "Voltage Angle Difference Solution")
                fmax(fmt, width, show, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                if haskey(dual.voltage.angle, i)
                    fmax(fmt, width, show, dual.voltage.angle[i] / scale["θ"], "Voltage Angle Difference Dual")
                end
            end

            if haskey(constraint.flow.active, i) && is_valid(analysis.method.jump, constraint.flow.active[i])
                fmax(fmt, width, show, system.branch.flow.minFromBus, i, scale["P"], "From-Bus Active Power Flow Minimum")
                fmax(fmt, width, show, value(constraint.flow.active[i]) * scale["P"], "From-Bus Active Power Flow Solution")
                fmax(fmt, width, show,system.branch.flow.maxFromBus, i, scale["P"], "From-Bus Active Power Flow Maximum")
                if haskey(dual.flow.active, i)
                    fmax(fmt, width, show, dual.flow.active[i] / scale["P"], "From-Bus Active Power Flow Dual")
                end
            end
        else
            θopt = [-Inf; Inf]
            θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]
            Fopt = [-Inf; Inf]
            Fmax = [-Inf; Inf]
            Fdul = [-Inf; Inf]

            @inbounds for (label, i) in system.branch.label
                fmax(width, show, label, "Label")

                if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                    minmaxPrimal(show, constraint.voltage.angle[i], scale["θ"], θopt, "Voltage Angle Difference Solution")
                    minmaxDual(show, dual.voltage.angle, i, scale["θ"], θdul, "Voltage Angle Difference Dual")
                end

                if haskey(constraint.flow.active, i) && is_valid(analysis.method.jump, constraint.flow.active[i])
                    minmaxValue(show, system.branch.flow.minFromBus, i, scale["P"], Fmin, "From-Bus Active Power Flow Minimum")
                    minmaxPrimal(show, constraint.flow.active[i], scale["P"], Fopt, "From-Bus Active Power Flow Solution")
                    minmaxValue(show, system.branch.flow.maxFromBus, i, scale["P"], Fmax, "From-Bus Active Power Flow Maximum")
                    minmaxDual(show, dual.flow.active, i, scale["P"], Fdul, "From-Bus Active Power Flow Dual")
                end
            end

            fminmax(fmt, width, show, system.branch.voltage.minDiffAngle, scale["θ"], "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, θopt, 1.0, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, system.branch.voltage.maxDiffAngle, scale["θ"], "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, θdul, 1.0, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, Fmin, 1.0, "From-Bus Active Power Flow Minimum")
            fminmax(fmt, width, show, Fopt, 1.0, "From-Bus Active Power Flow Solution")
            fminmax(fmt, width, show, Fmax, 1.0, "From-Bus Active Power Flow Maximum")
            fminmax(fmt, width, show, Fdul, 1.0, "From-Bus Active Power Flow Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Branch Constraint Data")

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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.generator, system.generator.label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorConstraint(system, analysis, label, scale, prefix, fmt, width, show, title, style)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Generator Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.capability.active, constraint.capability.reactive)
                printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                printf(io, pfmt, show, width, label, "Label")

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    printf(io, pfmt, show, width, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
                    printf(io, pfmt, show, width, constraint.capability.active, i, scale["P"], "Active Power Capability Solution")
                    printf(io, pfmt, show, width, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
                    printf(io, pfmt, show, width, dual.capability.active, i, scale["P"], "Active Power Capability Dual")
                else
                    printf(io, hfmt, show, width, "", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual")
                end

                if haskey(constraint.capability.reactive, i) && is_valid(analysis.method.jump, constraint.capability.reactive[i])
                    printf(io, pfmt, show, width, system.generator.capability.minReactive, i, scale["Q"], "Reactive Power Capability Minimum")
                    printf(io, pfmt, show, width, constraint.capability.reactive, i, scale["Q"], "Reactive Power Capability Solution")
                    printf(io, pfmt, show, width, system.generator.capability.maxReactive, i, scale["Q"], "Reactive Power Capability Maximum")
                    printf(io, pfmt, show, width, dual.capability.reactive, i, scale["Q"], "Reactive Power Capability Dual")
                else
                    printf(io, hfmt, show, width, "", "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Maximum", "Reactive Power Capability Dual")

                end

                @printf io "\n"
                cnt += 1
            end

        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

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

            if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                fmax(fmt, width, show, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
                fmax(fmt, width, show, value(constraint.capability.active[i]) * scale["P"], "Active Power Capability Solution")
                fmax(fmt, width, show, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
                if haskey(dual.capability.active, i)
                    fmax(fmt, width, show, dual.capability.active[i] / scale["P"], "Active Power Capability Dual")
                end
            end

            if haskey(constraint.capability.reactive, i) && is_valid(analysis.method.jump, constraint.capability.reactive[i])
                fmax(fmt, width, show, system.generator.capability.minReactive, i, scale["Q"], "Reactive Power Capability Minimum")
                fmax(fmt, width, show, value(constraint.capability.reactive[i]) * scale["Q"], "Reactive Power Capability Solution")
                fmax(fmt, width, show, system.generator.capability.maxReactive, i, scale["Q"], "Reactive Power Capability Maximum")
                if haskey(dual.capability.reactive, i)
                    fmax(fmt, width, show, dual.capability.reactive[i] / scale["Q"], "Reactive Power Capability Dual")
                end
            end
        else
            Popt = [-Inf; Inf]
            Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]
            Qdul = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                fmax(width, show, label, "Label")

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    minmaxPrimal(show, constraint.capability.active[i], scale["P"], Popt, "Active Power Capability Solution")
                    minmaxDual(show, dual.capability.active, i, scale["P"], Pdul, "Active Power Capability Dual")
                end

                if haskey(constraint.capability.reactive, i) && is_valid(analysis.method.jump, constraint.capability.reactive[i])
                    minmaxPrimal(show, constraint.capability.reactive[i], scale["Q"], Qopt, "Reactive Power Capability Solution")
                    minmaxDual(show, dual.capability.reactive, i, scale["Q"], Qdul, "Reactive Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, system.generator.capability.minActive, scale["P"], "Active Power Capability Minimum")
            fminmax(fmt, width, show, Popt, 1.0, "Active Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxActive, scale["P"], "Active Power Capability Maximum")
            fminmax(fmt, width, show, Pdul, 1.0, "Active Power Capability Dual")

            fminmax(fmt, width, show, system.generator.capability.minReactive, scale["Q"], "Reactive Power Capability Minimum")
            fminmax(fmt, width, show, Qopt, 1.0, "Reactive Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxReactive, scale["Q"], "Reactive Power Capability Maximum")
            fminmax(fmt, width, show, Qdul, 1.0, "Reactive Power Capability Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Generator Constraint Data")

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

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, system.generator, system.generator.label, title, header, footer, "generator")
    fmt, width, show, heading, subheading, unit, printing = formatGeneratorConstraint(system, analysis, label, scale, prefix, fmt, width, show, title, style)

    if printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Generator Constraint Data")

        cnt = 1
        @inbounds for (label, i) in labels
            if checkLine(analysis.method.jump, i, constraint.capability.active)
                printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                printf(io, pfmt, show, width, label, "Label")

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    printf(io, pfmt, show, width, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
                    printf(io, pfmt, show, width, constraint.capability.active, i, scale["P"], "Active Power Capability Solution")
                    printf(io, pfmt, show, width, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
                    printf(io, pfmt, show, width, dual.capability.active, i, scale["P"], "Active Power Capability Dual")
                else
                    printf(io, hfmt, show, width, "", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual")
                end

                @printf io "\n"
                cnt += 1
            end
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

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

            if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                fmax(fmt, width, show, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
                fmax(fmt, width, show, value(constraint.capability.active[i]) * scale["P"], "Active Power Capability Solution")
                fmax(fmt, width, show, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
                if haskey(dual.capability.active, i)
                    fmax(fmt, width, show, dual.capability.active[i] / scale["P"], "Active Power Capability Dual")
                end
            end
        else
            Popt = [-Inf; Inf]
            Pdul = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                fmax(width, show, label, "Label")

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    minmaxPrimal(show, constraint.capability.active[i], scale["P"], Popt, "Active Power Capability Solution")
                    minmaxDual(show, dual.capability.active, i, scale["P"], Pdul, "Active Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, system.generator.capability.minActive, scale["P"], "Active Power Capability Minimum")
            fminmax(fmt, width, show, Popt, 1.0, "Active Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxActive, scale["P"], "Active Power Capability Maximum")
            fminmax(fmt, width, show, Pdul, 1.0, "Active Power Capability Dual")
        end
    end

    printing = howManyPrint(width, show, style, title, "Generator Constraint Data")

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