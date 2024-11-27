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
function printBusConstraint(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    bus = system.bus
    jump = analysis.method.jump
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    prt = busCons(system, analysis, unitList, pfx, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Bus Constraint Data")

    @inbounds for (label, i) in pickLabel(bus, bus.label, label, "bus")
        if notLine(jump, i, cons.voltage.magnitude, cons.balance.active, cons.balance.reactive)
            continue
        end

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        if isValid(jump, cons.voltage.magnitude, i)
            scaleV = scaleVoltage(pfx, system, i)
            printf(io, prt, i, scaleV, bus.voltage.minMagnitude, :Vmin)
            printf(io, prt, i, scaleV, analysis.voltage.magnitude, :Vopt)
            printf(io, prt, i, scaleV, bus.voltage.maxMagnitude, :Vmax)
            printf(io, prt, i, scaleV, dual.voltage.magnitude, :Vdul)
        else
            printf(io, prt.hfmt, prt, "", :Vmin, :Vopt, :Vmax, :Vdul)
        end

        if isValid(jump, cons.balance.active, i)
            printf(io, prt, i, scale[:P], cons.balance.active, :Popt)
            printf(io, prt, i, scale[:P], dual.balance.active, :Pdul)
        else
            printf(io, prt.hfmt, prt, "", :Popt, :Pdul)
        end

        if isValid(jump, cons.balance.reactive, i)
            printf(io, prt, i, scale[:Q], cons.balance.reactive, :Qopt)
            printf(io, prt, i, scale[:Q], dual.balance.reactive, :Qdul)
        else
            printf(io, prt.hfmt, prt, "", :Qopt, :Qdul)
        end

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function busCons(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.magnitude)
    voltg = analysis.voltage
    cons = analysis.method.constraint
    dual = analysis.method.dual
    bus = system.bus
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :Vmag => "Voltage Magnitude",
        :Pblc => "Active Power Balance",
        :Qblc => "Reactive Power Balance",
        :Vmin => "Voltage Magnitude Minimum",
        :Vopt => "Voltage Magnitude Solution",
        :Vmax => "Voltage Magnitude Maximum",
        :Vdul => "Voltage Magnitude Dual",
        :Popt => "Active Power Balance Solution",
        :Pdul => "Active Power Balance Dual",
        :Qopt => "Reactive Power Balance Solution",
        :Qdul => "Reactive Power Balance Dual"
    )
    show = OrderedDict(
        head[:Vmag] => true,
        head[:Pblc] => true,
        head[:Qblc] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl] => _header("", head[:labl], style),
        head[:Vmin] => _header("Minimum", head[:Vmin], style),
        head[:Vopt] => _header("Solution", head[:Vopt], style),
        head[:Vmax] => _header("Maximum", head[:Vmax], style),
        head[:Vdul] => _header("Dual", head[:Vdul], style),
        head[:Popt] => _header("Solution", head[:Popt], style),
        head[:Pdul] => _header("Dual", head[:Pdul], style),
        head[:Qopt] => _header("Solution", head[:Qopt], style),
        head[:Qdul] => _header("Dual", head[:Qdul], style)
    )
    unit = Dict(
        head[:labl] => "",
        head[:Vmin] => "[" * unitList.voltageMagnitudeLive * "]",
        head[:Vopt] => "[" * unitList.voltageMagnitudeLive * "]",
        head[:Vmax] => "[" * unitList.voltageMagnitudeLive * "]",
        head[:Vdul] => "[\$/" * unitList.voltageMagnitudeLive * "-hr]",
        head[:Popt] => "[" * unitList.activePowerLive * "]",
        head[:Pdul] => "[\$/" * unitList.activePowerLive * "-hr]",
        head[:Qopt] => "[" * unitList.reactivePowerLive * "]",
        head[:Qdul] => "[\$/" * unitList.reactivePowerLive * "-hr]"
    )
    fmt = Dict(
        head[:labl] => "%-*s",
        head[:Vmin] => _fmt(fmt[head[:Vmag]]),
        head[:Vopt] => _fmt(fmt[head[:Vmag]]),
        head[:Vmax] => _fmt(fmt[head[:Vmag]]),
        head[:Vdul] => _fmt(fmt[head[:Vmag]]),
        head[:Popt] => _fmt(fmt[head[:Pblc]]),
        head[:Pdul] => _fmt(fmt[head[:Pblc]]),
        head[:Qopt] => _fmt(fmt[head[:Qblc]]),
        head[:Qdul] => _fmt(fmt[head[:Qblc]])
    )
    width = Dict(
        head[:labl] => 5 * style,
        head[:Vmin] => _width(width[head[:Vmag]], 7, style),
        head[:Vopt] => _width(width[head[:Vmag]], 8, style),
        head[:Vmax] => _width(width[head[:Vmag]], 7, style),
        head[:Vdul] => _width(width[head[:Vmag]], textwidth(unit[head[:Vdul]]), style),
        head[:Popt] => _width(width[head[:Pblc]], 8, style),
        head[:Pdul] => _width(width[head[:Pblc]], textwidth(unit[head[:Pdul]]), style),
        head[:Qopt] => _width(width[head[:Qblc]], 8, style),
        head[:Qdul] => _width(width[head[:Qblc]], textwidth(unit[head[:Qdul]]), style)
    )
    show = OrderedDict(
        head[:labl] => false,
        head[:Vmin] => _show(show[head[:Vmag]], cons.voltage.magnitude),
        head[:Vopt] => _show(show[head[:Vmag]], cons.voltage.magnitude),
        head[:Vmax] => _show(show[head[:Vmag]], cons.voltage.magnitude),
        head[:Vdul] => _show(show[head[:Vmag]], dual.voltage.magnitude),
        head[:Popt] => _show(show[head[:Pblc]], cons.balance.active),
        head[:Pdul] => _show(show[head[:Pblc]], dual.balance.active),
        head[:Qopt] => _show(show[head[:Qblc]], cons.balance.reactive),
        head[:Qdul] => _show(show[head[:Qblc]], dual.balance.reactive)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(bus, label, "bus")
            i = bus.label[label]

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.voltage.magnitude, i)
                scaleV = scaleVoltage(pfx, system, i)
                fmax(fmt, width, show, i, scaleV, bus.voltage.minMagnitude, head[:Vmin])
                fmax(fmt, width, show, i, scaleV, voltg.magnitude, head[:Vopt])
                fmax(fmt, width, show, i, scaleV, bus.voltage.maxMagnitude, head[:Vmax])
                fmax(fmt, width, show, i, scaleV, dual.voltage.magnitude, head[:Vdul])
            end

            if isValid(analysis.method.jump, cons.balance.active, i)
                fmax(fmt, width, show, i, scale[:P], cons.balance.active, head[:Popt])
                fmax(fmt, width, show, i, scale[:P], dual.balance.active, head[:Pdul])
            end

            if isValid(analysis.method.jump, cons.balance.reactive, i)
                fmax(fmt, width, show, i, scale[:Q], cons.balance.reactive, head[:Qopt])
                fmax(fmt, width, show, i, scale[:Q], dual.balance.reactive, head[:Qdul])
            end
        else
            Vmin = -Inf; Vopt = -Inf; Vmax = -Inf; Vdul = [-Inf; Inf]
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]; Qdul = [-Inf; Inf]

            @inbounds for (label, i) in bus.label
                scaleV = scaleVoltage(pfx, system, i)

                fmax(width, show, label, head[:labl])

                if isValid(analysis.method.jump, cons.voltage.magnitude, i)
                    fminmax(show, i, scaleV, Vdul, dual.voltage.magnitude, head[:Vdul])
                end

                if isValid(analysis.method.jump, cons.balance.active, i)
                    fminmax(show, i, scale[:P], Popt, cons.balance.active, head[:Popt])
                    fminmax(show, i, scale[:P], Pdul, dual.balance.active, head[:Pdul])
                end

                if isValid(analysis.method.jump, cons.balance.reactive, i)
                    fminmax(show, i, scale[:Q], Qopt, cons.balance.reactive, head[:Qopt])
                    fminmax(show, i, scale[:Q], Qdul, dual.balance.reactive, head[:Qdul])
                end

                if pfx.voltageMagnitude != 0.0
                    Vmin = fmax(show, i, scaleV, Vmin, bus.voltage.minMagnitude, head[:Vmin])
                    Vopt = fmax(show, i, scaleV, Vopt, voltg.magnitude, head[:Vopt])
                    Vmax = fmax(show, i, scaleV, Vmax, bus.voltage.maxMagnitude, head[:Vmax])
                end
            end

            if pfx.voltageMagnitude == 0.0
                fmax(fmt, width, show, bus.voltage.minMagnitude, head[:Vmin])
                fmax(fmt, width, show, voltg.magnitude, head[:Vopt])
                fmax(fmt, width, show, bus.voltage.minMagnitude, head[:Vmax])
            else
                fmax(fmt, width, show, Vmin, head[:Vmin])
                fmax(fmt, width, show, Vopt, head[:Vopt])
                fmax(fmt, width, show, Vmax, head[:Vmax])
            end
            fminmax(fmt, width, show, Vdul, head[:Vdul])

            fminmax(fmt, width, show, Popt, head[:Popt])
            fminmax(fmt, width, show, Pdul, head[:Pdul])

            fminmax(fmt, width, show, Qopt, head[:Qopt])
            fminmax(fmt, width, show, Qdul, head[:Qdul])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Bus Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:Vmag] => _blank(width, show, delimiter, style, head, :Vmag, :Vmin, :Vopt, :Vmax, :Vdul),
        head[:Pblc] => _blank(width, show, delimiter, style, head, :Pblc, :Popt, :Pdul),
        head[:Qblc] => _blank(width, show, delimiter, style, head, :Qblc, :Qopt, :Qdul)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printBusConstraint(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    bus = system.bus
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    prt = busCons(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Bus Constraint Data")

    @inbounds for (label, i) in pickLabel(bus, bus.label, label, "bus")
        if notLine(analysis.method.jump, i, cons.balance.active)
            continue
        end

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        if isValid(analysis.method.jump, cons.balance.active, i)
            printf(io, prt, i, scale[:P], cons.balance.active, :Popt)
            printf(io, prt, i, scale[:P], dual.balance.active, :Pdul)
        end

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function busCons(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.angle)
    bus = system.bus
    cons = analysis.method.constraint
    dual = analysis.method.dual
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :Pblc => "Active Power Balance",
        :Popt => "Active Power Balance Solution",
        :Pdul => "Active Power Balance Dual",
    )
    show = OrderedDict(head[:Pblc] => true)

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl] => _header("", head[:labl], style),
        head[:Popt] => _header("Solution", head[:Popt], style),
        head[:Pdul] => _header("Dual", head[:Pdul], style),
    )
    unit = Dict(
        head[:labl] => "",
        head[:Popt] => "[" * unitList.activePowerLive * "]",
        head[:Pdul] => "[\$/" * unitList.activePowerLive * "-hr]"
    )
    fmt = Dict(
        head[:labl] => "%-*s",
        head[:Popt] => _fmt(fmt[head[:Pblc]]),
        head[:Pdul] => _fmt(fmt[head[:Pblc]])
    )
    width = Dict(
        head[:labl] => 5 * style,
        head[:Popt] => _width(width[head[:Pblc]], 8, style),
        head[:Pdul] => _width(width[head[:Pblc]], textwidth(unit[head[:Pdul]]), style)
    )
    show = OrderedDict(
        head[:labl] => false,
        head[:Popt] => _show(show[head[:Pblc]], cons.balance.active),
        head[:Pdul] => _show(show[head[:Pblc]], dual.balance.active)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(bus, label, "bus")
            i = bus.label[label]

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.balance.active, i)
                fmax(fmt, width, show, i, scale[:P], cons.balance.active, head[:Popt])
                fmax(fmt, width, show, i, scale[:P], dual.balance.active, head[:Pdul])
            end
        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]

            @inbounds for (label, i) in bus.label
                fmax(width, show, label, head[:labl])

                if isValid(analysis.method.jump, cons.balance.active, i)
                    fminmax(show, i, scale[:P], Popt, cons.balance.active, head[:Popt])
                    fminmax(show, i, scale[:P], Pdul, dual.balance.active, head[:Pdul])
                end
            end
            fminmax(fmt, width, show, Popt, head[:Popt])
            fminmax(fmt, width, show, Pdul, head[:Pdul])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Bus Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:Pblc] => _blank(width, show, delimiter, style, head, :Pblc, :Popt, :Pdul)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter,
        style, title, header, footer, repeat, notprint, line, 1
    )
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
function printBranchConstraint(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    brch = system.branch
    jump = analysis.method.jump
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    types, idxType = checkFlowType(system, analysis)

    for type in types
        prt = branchCons(
            system, analysis, unitList, pfx, scale, type, idxType, label, repeat; kwargs...
        )

        if prt.notprint
            break
        end


        if type in (1, 2, 3)
            scaleFrom, scaleTo = flowScale(scale, type)
        end

        title(io, prt, "Branch Constraint Data")

        @inbounds for (label, i) in pickLabel(brch, brch.label, label, "branch")
            if idxType[i] == type
                if notLine(jump, i, cons.voltage.angle, cons.flow.from, cons.flow.to)
                    continue
                end

                if type == 4 || type == 5
                    scaleFrom, scaleTo = flowScale(system, pfx, i)
                end

                header(io, prt)
                printf(io, prt.pfmt, prt, label, :labl)

                if isValid(jump, cons.voltage.angle, i)
                    printf(io, prt, i, scale[:θ], brch.voltage.minDiffAngle, :θijmin)
                    printf(io, prt, i, scale[:θ], cons.voltage.angle, :θijopt)
                    printf(io, prt, i, scale[:θ], brch.voltage.maxDiffAngle, :θijmax)
                    printf(io, prt, i, scale[:θ], dual.voltage.angle, :θijdul)
                else
                    printf(io, prt.hfmt, prt, "", :θijmin, :θijopt, :θijmax, :θijdul)
                end

                if isValid(jump, cons.flow.from, i)
                    if brch.flow.minFromBus[i] < 0 && brch.flow.type[i] != 1
                        printf(io, prt, 0.0, :Pijmin)
                    else
                        printf(io, prt, i, scaleFrom, brch.flow.minFromBus, :Pijmin)
                    end
                    if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                        printf(io, prt, i, scaleFrom, cons.flow.from, :Pijopt; native = false)
                        printf(io, prt, i, scaleFrom, brch.flow.maxFromBus, :Pijmax)
                        printf(io, prt, i, scaleFrom, dual.flow.from, cons.flow.from, :Pijdul)
                    else
                        printf(io, prt, i, scaleFrom, cons.flow.from, :Pijopt)
                        printf(io, prt, i, scaleFrom, brch.flow.maxFromBus, :Pijmax)
                        printf(io, prt, i, scaleFrom, dual.flow.from, :Pijdul)
                    end
                else
                    printf(io, prt.hfmt, prt, "", :Pijmin, :Pijopt, :Pijmax, :Pijdul)
                end

                if isValid(jump, cons.flow.to, i)
                    if brch.flow.minToBus[i] < 0 && brch.flow.type[i] != 1
                        printf(io, prt, 0.0, :Pjimin)
                    else
                        printf(io, prt, i, scaleTo, brch.flow.minToBus, :Pjimin)
                    end
                    if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                        printf(io, prt, i, scaleTo, cons.flow.to, :Pjiopt; native = false)
                        printf(io, prt, i, scaleTo, brch.flow.maxToBus, :Pjimax)
                        printf(io, prt, i, scaleTo, dual.flow.to, cons.flow.from, :Pjidul)
                    else
                        printf(io, prt, i, scaleTo, cons.flow.to, :Pjiopt)
                        printf(io, prt, i, scaleTo, brch.flow.maxToBus, :Pjimax)
                        printf(io, prt, i, scaleTo, dual.flow.to, :Pjidul)
                    end
                else
                    printf(io, prt.hfmt, prt, "", :Pjimin, :Pijopt, :Pijmax, :Pjidul)
                end

                @printf io "\n"
            end
        end
        printf(io, prt.footer, prt)
        prt.cnt = 1
    end
end

function branchCons(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    type::Int64,
    idxType::Vector{Int8},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.magnitude)
    brch = system.branch
    cons = analysis.method.constraint
    dual = analysis.method.dual
    style, delimiter, key = printkwargs(; kwargs...)

    flow, unitFlow = flowType(type, unitList)

    head = Dict(
        :labl   => "Label",
        :θij    => "Voltage Angle Difference",
        :θijmin => "Voltage Angle Difference Minimum",
        :θijopt => "Voltage Angle Difference Solution",
        :θijmax => "Voltage Angle Difference Maximum",
        :θijdul => "Voltage Angle Difference Dual",
        :Pij    => "From-Bus " * flow,
        :Pijmin => "From-Bus " * flow * " Minimum",
        :Pijopt => "From-Bus " * flow * " Solution",
        :Pijmax => "From-Bus " * flow * " Maximum",
        :Pijdul => "From-Bus " * flow * " Dual",
        :Pji    => "To-Bus " * flow,
        :Pjimin => "To-Bus " * flow * " Minimum",
        :Pjiopt => "To-Bus " * flow * " Solution",
        :Pjimax => "To-Bus " * flow * " Maximum",
        :Pjidul => "To-Bus " * flow * " Dual"
    )
    show = OrderedDict(
        head[:θij] => true,
        head[:Pij] => true,
        head[:Pji] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl]   => _header("", head[:labl], style),
        head[:θijmin] => _header("Minimum", head[:θijmin], style),
        head[:θijopt] => _header("Solution", head[:θijopt], style),
        head[:θijmax] => _header("Maximum", head[:θijmax], style),
        head[:θijdul] => _header("Dual", head[:θijdul], style),
        head[:Pijmin] => _header("Minimum", head[:Pijmin], style),
        head[:Pijopt] => _header("Solution", head[:Pijopt], style),
        head[:Pijmax] => _header("Maximum", head[:Pijmax], style),
        head[:Pijdul] => _header("Dual", head[:Pijdul], style),
        head[:Pjimin] => _header("Minimum", head[:Pjimin], style),
        head[:Pjiopt] => _header("Solution", head[:Pjiopt], style),
        head[:Pjimax] => _header("Maximum", head[:Pjimax], style),
        head[:Pjidul] => _header("Dual", head[:Pjidul], style)
    )
    unit = Dict(
        head[:labl]   => "",
        head[:θijmin] => "[" * unitList.voltageAngleLive * "]",
        head[:θijopt] => "[" * unitList.voltageAngleLive * "]",
        head[:θijmax] => "[" * unitList.voltageAngleLive * "]",
        head[:θijdul] => "[\$/" * unitList.voltageAngleLive * "-hr]",
        head[:Pijmin] => "[" * unitFlow * "]",
        head[:Pijopt] => "[" * unitFlow * "]",
        head[:Pijmax] => "[" * unitFlow * "]",
        head[:Pijdul] => "[\$/" * unitFlow * "-hr]",
        head[:Pjimin] => "[" * unitFlow * "]",
        head[:Pjiopt] => "[" * unitFlow * "]",
        head[:Pjimax] => "[" * unitFlow * "]",
        head[:Pjidul] => "[\$/" * unitFlow * "-hr]"
    )
    fmt = Dict(
        head[:labl]   => "%-*s",
        head[:θijmin] => _fmt(fmt[head[:θij]]),
        head[:θijopt] => _fmt(fmt[head[:θij]]),
        head[:θijmax] => _fmt(fmt[head[:θij]]),
        head[:θijdul] => _fmt(fmt[head[:θij]]),
        head[:Pijmin] => _fmt(fmt[head[:Pij]]),
        head[:Pijopt] => _fmt(fmt[head[:Pij]]),
        head[:Pijmax] => _fmt(fmt[head[:Pij]]),
        head[:Pijdul] => _fmt(fmt[head[:Pij]]),
        head[:Pjimin] => _fmt(fmt[head[:Pji]]),
        head[:Pjiopt] => _fmt(fmt[head[:Pji]]),
        head[:Pjimax] => _fmt(fmt[head[:Pji]]),
        head[:Pjidul] => _fmt(fmt[head[:Pji]])
    )
    width = Dict(
        head[:labl]   => 5 * style,
        head[:θijmin] => _width(width[head[:θij]], 7, style),
        head[:θijopt] => _width(width[head[:θij]], 8, style),
        head[:θijmax] => _width(width[head[:θij]], 7, style),
        head[:θijdul] => _width(width[head[:θij]], textwidth(unit[head[:θijdul]]), style),
        head[:Pijmin] => _width(width[head[:Pij]], 7, style),
        head[:Pijopt] => _width(width[head[:Pij]], 8, style),
        head[:Pijmax] => _width(width[head[:Pij]], 7, style),
        head[:Pijdul] => _width(width[head[:Pij]], textwidth(unit[head[:Pijdul]]), style),
        head[:Pjimin] => _width(width[head[:Pji]], 7, style),
        head[:Pjiopt] => _width(width[head[:Pji]], 8, style),
        head[:Pjimax] => _width(width[head[:Pji]], 7, style),
        head[:Pjidul] => _width(width[head[:Pji]], textwidth(unit[head[:Pjidul]]), style)
    )
    show = OrderedDict(
        head[:labl]   => false,
        head[:θijmin] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijopt] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijmax] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijdul] => _show(show[head[:θij]], dual.voltage.angle),
        head[:Pijmin] => _show(show[head[:Pij]], cons.flow.from),
        head[:Pijopt] => _show(show[head[:Pij]], cons.flow.from),
        head[:Pijmax] => _show(show[head[:Pij]], cons.flow.from),
        head[:Pijdul] => _show(show[head[:Pij]], dual.flow.from),
        head[:Pjimin] => _show(show[head[:Pji]], cons.flow.to),
        head[:Pjiopt] => _show(show[head[:Pji]], cons.flow.to),
        head[:Pjimax] => _show(show[head[:Pji]], cons.flow.to),
        head[:Pjidul] => _show(show[head[:Pji]], dual.flow.to)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(brch, label, "branch")
            i = brch.label[label]

            scaleFrom, scaleTo = flowScale(system, pfx, scale, i, type)

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.voltage.angle, i)
                fmax(fmt, width, show, i, scale[:θ], brch.voltage.minDiffAngle, head[:θijmin])
                fmax(fmt, width, show, i, scale[:θ], cons.voltage.angle, head[:θijopt])
                fmax(fmt, width, show, i, scale[:θ], brch.voltage.maxDiffAngle, head[:θijmax])
                fmax(fmt, width, show, i, scale[:θ], dual.voltage.angle, head[:θijdul])
            end

            if isValid(analysis.method.jump, cons.flow.from, i)
                if !(brch.flow.minFromBus[i] < 0 && brch.flow.type[i] != 1)
                    fmax(fmt, width, show, i, scaleFrom, brch.flow.minFromBus, head[:Pijmin])
                end
                if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                    fmax(fmt, width, show, i, scaleFrom, cons.flow.from, head[:Pijopt]; native = false)
                    fmax(fmt, width, show, i, scaleFrom, dual.flow.from, cons.flow.from, head[:Pijdul])
                else
                    fmax(fmt, width, show, i, scaleFrom, cons.flow.from, head[:Pijopt])
                    fmax(fmt, width, show, i, scaleFrom, dual.flow.from, head[:Pijdul])
                end
                fmax(fmt, width, show, i, scaleFrom, brch.flow.maxFromBus, head[:Pijmax])
            end

            if isValid(analysis.method.jump, cons.flow.to, i)
                if !(brch.flow.minToBus[i] < 0 && brch.flow.type[i] != 1)
                    fmax(fmt, width, show, i, scaleTo, brch.flow.minToBus, head[:Pjimin])
                end
                if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                    fmax(fmt, width, show, i, scaleTo, cons.flow.to, head[:Pjiopt]; native = false)
                    fmax(fmt, width, show, i, scaleTo, dual.flow.to, cons.flow.to, head[:Pjidul])
                else
                    fmax(fmt, width, show, i, scaleTo, cons.flow.to, head[:Pjiopt])
                    fmax(fmt, width, show, i, scaleTo, dual.flow.to, head[:Pjidul])
                end
                fmax(fmt, width, show, i, scaleTo, brch.flow.maxToBus, head[:Pjimax])
            end
        else
            θopt = [-Inf; Inf]; θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]; Fopt = [-Inf; Inf]; Fmax = [-Inf; Inf]; Fdul = [-Inf; Inf]
            Tmin = [-Inf; Inf]; Topt = [-Inf; Inf]; Tmax = [-Inf; Inf]; Tdul = [-Inf; Inf]

            if type in (1, 2, 3)
                scaleFrom, scaleTo = flowScale(scale, type)
            end
            @inbounds for (label, i) in brch.label
                if idxType[i] == type
                    if type in (4, 5)
                        scaleFrom, scaleTo = flowScale(system, pfx, i)
                    end

                    fmax(width, show, label, head[:labl])

                    if isValid(analysis.method.jump, cons.voltage.angle, i)
                        fminmax(show, i, scale[:θ], θopt, cons.voltage.angle, head[:θijopt])
                        fminmax(show, i, scale[:θ], θdul, dual.voltage.angle, head[:θijdul])
                    end

                    if isValid(analysis.method.jump, cons.flow.from, i)
                        if !(brch.flow.minFromBus[i] < 0 && brch.flow.type[i] != 1)
                            fminmax(show, i, scaleFrom, Fmin, brch.flow.minFromBus, head[:Pijmin])
                        end
                        if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                            fminmax(show, i, scaleFrom, Fopt, cons.flow.from, head[:Pijopt]; native = false)
                            fminmax(show, i, scaleFrom, Fdul, dual.flow.from, cons.flow.from, head[:Pijdul])
                        else
                            fminmax(show, i, scaleFrom, Fopt, cons.flow.from, head[:Pijopt])
                            fminmax(show, i, scaleFrom, Fdul, dual.flow.from, head[:Pijdul])
                        end
                        fminmax(show, i, scaleFrom, Fmax, brch.flow.maxFromBus, head[:Pijmax])
                    end

                    if isValid(analysis.method.jump, cons.flow.to, i)
                        if !(brch.flow.minToBus[i] < 0 && brch.flow.type[i] != 1)
                            fminmax(show, i, scaleTo, Tmin, brch.flow.minToBus, head[:Pjimin])
                        end
                        if brch.flow.type[i] == 3 || brch.flow.type[i] == 5
                            fminmax(show, i, scaleTo, Topt, cons.flow.to, head[:Pjiopt]; native = false)
                            fminmax(show, i, scaleTo, Tdul, dual.flow.to, cons.flow.from, head[:Pjidul])
                        else
                            fminmax(show, i, scaleTo, Topt, cons.flow.to, head[:Pjiopt])
                            fminmax(show, i, scaleTo, Tdul, dual.flow.to, head[:Pjidul])
                        end
                        fminmax(show, i, scaleTo, Tmax, brch.flow.maxToBus, head[:Pjimax])
                    end
                end
            end

            fminmax(fmt, width, show, scale[:θ], brch.voltage.minDiffAngle, head[:θijmin])
            fminmax(fmt, width, show, θopt, head[:θijopt])
            fminmax(fmt, width, show, scale[:θ], brch.voltage.maxDiffAngle, head[:θijmax])
            fminmax(fmt, width, show, θdul, head[:θijdul])

            fminmax(fmt, width, show, Fmin, head[:Pijmin])
            fminmax(fmt, width, show, Fopt, head[:Pijopt])
            fminmax(fmt, width, show, Fmax, head[:Pijmax])
            fminmax(fmt, width, show, Fdul, head[:Pijdul])

            fminmax(fmt, width, show, Tmin, head[:Pjimin])
            fminmax(fmt, width, show, Topt, head[:Pjiopt])
            fminmax(fmt, width, show, Tmax, head[:Pjimax])
            fminmax(fmt, width, show, Tdul, head[:Pjidul])
        end
    end
    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Branch Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:θij]  => _blank(width, show, delimiter, style, head, :θij, :θijmin, :θijopt, :θijmax, :θijdul),
        head[:Pij]  => _blank(width, show, delimiter, style, head, :Pij, :Pijmin, :Pijopt, :Pijmax, :Pijdul),
        head[:Pji]  => _blank(width, show, delimiter, style, head, :Pji, :Pjimin, :Pjiopt, :Pjimax, :Pjidul)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printBranchConstraint(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    brch = system.branch
    jump = analysis.method.jump
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    prt = branchCons(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Branch Constraint Data")

    @inbounds for (label, i) in pickLabel(brch, brch.label, label, "branch")
        if notLine(jump, i, cons.voltage.angle, cons.flow.active)
            continue
        end

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        if isValid(jump, cons.voltage.angle, i)
            printf(io, prt, i, scale[:θ], brch.voltage.minDiffAngle, :θijmin)
            printf(io, prt, i, scale[:θ], cons.voltage.angle, :θijopt)
            printf(io, prt, i, scale[:θ], brch.voltage.maxDiffAngle, :θijmax)
            printf(io, prt, i, scale[:θ], dual.voltage.angle, :θijdul)
        else
            printf(io, prt.hfmt, prt, "", :θijmin, :θijopt, :θijmax, :θijdul)
        end

        if isValid(jump, cons.flow.active, i)
            printf(io, prt, i, scale[:P], brch.flow.minFromBus, :Pijmin)
            printf(io, prt, i, scale[:P], cons.flow.active, :Pijopt)
            printf(io, prt, i, scale[:P], brch.flow.maxFromBus, :Pijmax)
            printf(io, prt, i, scale[:P], dual.flow.active, :Pijdul)
        else
            printf(io, prt.hfmt, prt, "", :Pijmin, :Pijopt, :Pijmax, :Pijdul)
        end

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function branchCons(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.angle)
    brch = system.branch
    cons = analysis.method.constraint
    dual = analysis.method.dual
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl   => "Label",
        :θij    => "Voltage Angle Difference",
        :θijmin => "Voltage Angle Difference Minimum",
        :θijopt => "Voltage Angle Difference Solution",
        :θijmax => "Voltage Angle Difference Maximum",
        :θijdul => "Voltage Angle Difference Dual",
        :Pij    => "From-Bus Active Power Flow",
        :Pijmin => "From-Bus Active Power Flow Minimum",
        :Pijopt => "From-Bus Active Power Flow Solution",
        :Pijmax => "From-Bus Active Power Flow Maximum",
        :Pijdul => "From-Bus Active Power Flow Dual"
    )

    show = OrderedDict(
        head[:θij] => true,
        head[:Pij] => true
    )
    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl]   => _header("", head[:labl], style),
        head[:θijmin] => _header("Minimum", head[:θijmin], style),
        head[:θijopt] => _header("Solution", head[:θijopt], style),
        head[:θijmax] => _header("Maximum", head[:θijmax], style),
        head[:θijdul] => _header("Dual", head[:θijdul], style),
        head[:Pijmin] => _header("Minimum", head[:Pijmin], style),
        head[:Pijopt] => _header("Solution", head[:Pijopt], style),
        head[:Pijmax] => _header("Maximum", head[:Pijmax], style),
        head[:Pijdul] => _header("Dual", head[:Pijdul], style),
    )
    unit = Dict(
        head[:labl]   => "",
        head[:θijmin] => "[" * unitList.voltageAngleLive * "]",
        head[:θijopt] => "[" * unitList.voltageAngleLive * "]",
        head[:θijmax] => "[" * unitList.voltageAngleLive * "]",
        head[:θijdul] => "[\$/" * unitList.voltageAngleLive * "-hr]",
        head[:Pijmin] => "[" * unitList.activePowerLive * "]",
        head[:Pijopt] => "[" * unitList.activePowerLive * "]",
        head[:Pijmax] => "[" * unitList.activePowerLive * "]",
        head[:Pijdul] => "[\$/" * unitList.activePowerLive * "-hr]",
    )
    fmt = Dict(
        head[:labl]   => "%-*s",
        head[:θijmin] => _fmt(fmt[head[:θij]]),
        head[:θijopt] => _fmt(fmt[head[:θij]]),
        head[:θijmax] => _fmt(fmt[head[:θij]]),
        head[:θijdul] => _fmt(fmt[head[:θij]]),
        head[:Pijmin] => _fmt(fmt[head[:Pij]]),
        head[:Pijopt] => _fmt(fmt[head[:Pij]]),
        head[:Pijmax] => _fmt(fmt[head[:Pij]]),
        head[:Pijdul] => _fmt(fmt[head[:Pij]])
    )
    width = Dict(
        head[:labl]   => 5 * style,
        head[:θijmin] => _width(width[head[:θij]], 7, style),
        head[:θijopt] => _width(width[head[:θij]], 8, style),
        head[:θijmax] => _width(width[head[:θij]], 7, style),
        head[:θijdul] => _width(width[head[:θij]], textwidth(unit[head[:θijdul]]), style),
        head[:Pijmin] => _width(width[head[:Pij]], 7, style),
        head[:Pijopt] => _width(width[head[:Pij]], 8, style),
        head[:Pijmax] => _width(width[head[:Pij]], 7, style),
        head[:Pijdul] => _width(width[head[:Pij]], textwidth(unit[head[:Pijdul]]), style)
    )
    show = OrderedDict(
        head[:labl]   => false,
        head[:θijmin] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijopt] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijmax] => _show(show[head[:θij]], cons.voltage.angle),
        head[:θijdul] => _show(show[head[:θij]], dual.voltage.angle),
        head[:Pijmin] => _show(show[head[:Pij]], cons.flow.active),
        head[:Pijopt] => _show(show[head[:Pij]], cons.flow.active),
        head[:Pijmax] => _show(show[head[:Pij]], cons.flow.active),
        head[:Pijdul] => _show(show[head[:Pij]], dual.flow.active)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(brch, label, "branch")
            i = brch.label[label]

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.voltage.angle, i)
                fmax(fmt, width, show, i, scale[:θ], brch.voltage.minDiffAngle, head[:θijmin])
                fmax(fmt, width, show, i, scale[:θ], cons.voltage.angle, head[:θijopt])
                fmax(fmt, width, show, i, scale[:θ], brch.voltage.maxDiffAngle, head[:θijmax])
                fmax(fmt, width, show, i, scale[:θ], dual.voltage.angle, head[:θijdul])
            end

            if isValid(analysis.method.jump, cons.flow.active, i)
                fmax(fmt, width, show, i, scale[:P], brch.flow.minFromBus, head[:Pijmin])
                fmax(fmt, width, show, i, scale[:P], cons.flow.active, head[:Pijopt])
                fmax(fmt, width, show, i, scale[:P], brch.flow.maxFromBus, head[:Pijmax])
                fmax(fmt, width, show, i, scale[:P], dual.flow.active, head[:Pijdul])
            end
        else
            θopt = [-Inf; Inf]; θdul = [-Inf; Inf]
            Fmin = [-Inf; Inf]; Fopt = [-Inf; Inf]
            Fmax = [-Inf; Inf]; Fdul = [-Inf; Inf]

            @inbounds for (label, i) in brch.label
                fmax(width, show, label, head[:labl])

                if isValid(analysis.method.jump, cons.voltage.angle, i)
                    fminmax(show, i, scale[:θ], θopt, cons.voltage.angle, head[:θijopt])
                    fminmax(show, i, scale[:θ], θdul, dual.voltage.angle, head[:θijdul])
                end

                if isValid(analysis.method.jump, cons.flow.active, i)
                    fminmax(show, i, scale[:P], Fmin, brch.flow.minFromBus, head[:Pijmin])
                    fminmax(show, i, scale[:P], Fopt, cons.flow.active, head[:Pijopt])
                    fminmax(show, i, scale[:P], Fmax, brch.flow.maxFromBus, head[:Pijmax])
                    fminmax(show, i, scale[:P], Fdul, dual.flow.active, head[:Pijdul])
                end
            end

            fminmax(fmt, width, show, scale[:θ], brch.voltage.minDiffAngle, head[:θijmin])
            fminmax(fmt, width, show, θopt, head[:θijopt])
            fminmax(fmt, width, show, scale[:θ], brch.voltage.maxDiffAngle, head[:θijmax])
            fminmax(fmt, width, show, θdul, head[:θijdul])

            fminmax(fmt, width, show, Fmin, head[:Pijmin])
            fminmax(fmt, width, show, Fopt, head[:Pijopt])
            fminmax(fmt, width, show, Fmax, head[:Pijmax])
            fminmax(fmt, width, show, Fdul, head[:Pijdul])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Branch Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:θij]  => _blank(width, show, delimiter, style, head, :θij, :θijmin, :θijopt, :θijmax, :θijdul),
        head[:Pij]  => _blank(width, show, delimiter, style, head, :Pij, :Pijmin, :Pijopt, :Pijmax, :Pijdul),
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
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
function printGeneratorConstraint(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    prt = genCons(system, analysis, unitList, pfx, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Generator Constraint Data")

    @inbounds for (label, i) in pickLabel(gen, gen.label, label, "generator")
        if notLine(jump, i, cons.capability.active, cons.capability.reactive)
            continue
        end

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        if isValid(jump, cons.capability.active, i)
            printf(io, prt, i, scale[:P], gen.capability.minActive, :Pmin)
            printf(io, prt, i, scale[:P], cons.capability.active, :Popt)
            printf(io, prt, i, scale[:P], gen.capability.maxActive, :Pmax)
            printf(io, prt, i, scale[:P], dual.capability.active, :Pdul)
        else
            printf(io, prt.hfmt, prt, "", :Pmin, :Popt, :Pmax, :Pdul)
        end

        if isValid(jump, cons.capability.reactive, i)
            printf(io, prt, i, scale[:Q], gen.capability.minReactive, :Qmin)
            printf(io, prt, i, scale[:Q], cons.capability.reactive, :Qopt)
            printf(io, prt, i, scale[:Q], gen.capability.maxReactive, :Qmax)
            printf(io, prt, i, scale[:Q], dual.capability.reactive, :Qdul)
        else
            printf(io, prt.hfmt, prt, "", :Qmin, :Qopt, :Qmax, :Qdul)
        end

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function genCons(
    system::PowerSystem,
    analysis::ACOptimalPowerFlow,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.magnitude)
    gen = system.generator
    cons = analysis.method.constraint
    dual = analysis.method.dual
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :Pcpb => "Active Power Capability",
        :Pmin => "Active Power Capability Minimum",
        :Popt => "Active Power Capability Solution",
        :Pmax => "Active Power Capability Maximum",
        :Pdul => "Active Power Capability Dual",
        :Qcpb => "Reactive Power Capability",
        :Qmin => "Reactive Power Capability Minimum",
        :Qopt => "Reactive Power Capability Solution",
        :Qmax => "Reactive Power Capability Maximum",
        :Qdul => "Reactive Power Capability Dual",
    )

    show = OrderedDict(
        head[:Pcpb] => true,
        head[:Qcpb] => true
    )
    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl] => _header("", head[:labl], style),
        head[:Pmin] => _header("Minimum", head[:Pmin], style),
        head[:Popt] => _header("Solution", head[:Popt], style),
        head[:Pmax] => _header("Maximum", head[:Pmax], style),
        head[:Pdul] => _header("Dual", head[:Pdul], style),
        head[:Qmin] => _header("Minimum", head[:Qmin], style),
        head[:Qopt] => _header("Solution", head[:Qopt], style),
        head[:Qmax] => _header("Maximum", head[:Qmax], style),
        head[:Qdul] => _header("Dual", head[:Qdul], style)
    )
    unit = Dict(
        head[:labl] => "",
        head[:Pmin] => "[" * unitList.activePowerLive * "]",
        head[:Popt] => "[" * unitList.activePowerLive * "]",
        head[:Pmax] => "[" * unitList.activePowerLive * "]",
        head[:Pdul] => "[\$/" * unitList.activePowerLive * "-hr]",
        head[:Qmin] => "[" * unitList.reactivePowerLive * "]",
        head[:Qopt] => "[" * unitList.reactivePowerLive * "]",
        head[:Qmax] => "[" * unitList.reactivePowerLive * "]",
        head[:Qdul] => "[\$/" * unitList.reactivePowerLive * "-hr]"
    )
    fmt = Dict(
        head[:labl] => "%-*s",
        head[:Pmin] => _fmt(fmt[head[:Pcpb]]),
        head[:Popt] => _fmt(fmt[head[:Pcpb]]),
        head[:Pmax] => _fmt(fmt[head[:Pcpb]]),
        head[:Pdul] => _fmt(fmt[head[:Pcpb]]),
        head[:Qmin] => _fmt(fmt[head[:Qcpb]]),
        head[:Qopt] => _fmt(fmt[head[:Qcpb]]),
        head[:Qmax] => _fmt(fmt[head[:Qcpb]]),
        head[:Qdul] => _fmt(fmt[head[:Qcpb]])
    )
    width = Dict(
        head[:labl] => 5 * style,
        head[:Pmin] => _width(width[head[:Pcpb]], 7, style),
        head[:Popt] => _width(width[head[:Pcpb]], 8, style),
        head[:Pmax] => _width(width[head[:Pcpb]], 7, style),
        head[:Pdul] => _width(width[head[:Pcpb]], textwidth(unit[head[:Pdul]]), style),
        head[:Qmin] => _width(width[head[:Qcpb]], 7, style),
        head[:Qopt] => _width(width[head[:Qcpb]], 8, style),
        head[:Qmax] => _width(width[head[:Qcpb]], 7, style),
        head[:Qdul] => _width(width[head[:Qcpb]], textwidth(unit[head[:Qdul]]), style),
    )
    show = OrderedDict(
        head[:labl] => false,
        head[:Pmin] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Popt] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Pmax] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Pdul] => _show(show[head[:Pcpb]], dual.capability.active),
        head[:Qmin] => _show(show[head[:Qcpb]], cons.capability.reactive),
        head[:Qopt] => _show(show[head[:Qcpb]], cons.capability.reactive),
        head[:Qmax] => _show(show[head[:Qcpb]], cons.capability.reactive),
        head[:Qdul] => _show(show[head[:Qcpb]], dual.capability.reactive)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(gen, label, "generator")
            i = gen.label[label]

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.capability.active, i)
                fmax(fmt, width, show, i, scale[:P], gen.capability.minActive, head[:Pmin])
                fmax(fmt, width, show, i, scale[:P], cons.capability.active, head[:Popt])
                fmax(fmt, width, show, i, scale[:P], gen.capability.maxActive, head[:Pmax])
                fmax(fmt, width, show, i, scale[:P], dual.capability.active, head[:Pdul])
            end

            if isValid(analysis.method.jump, cons.capability.reactive, i)
                fmax(fmt, width, show, i, scale[:Q], gen.capability.minReactive, head[:Qmin])
                fmax(fmt, width, show, i, scale[:Q], cons.capability.reactive, head[:Qopt])
                fmax(fmt, width, show, i, scale[:Q], gen.capability.maxReactive, head[:Qmax])
                fmax(fmt, width, show, i, scale[:Q], dual.capability.reactive, head[:Qdul])
            end
        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]
            Qopt = [-Inf; Inf]; Qdul = [-Inf; Inf]

            @inbounds for (label, i) in gen.label
                fmax(width, show, label, head[:labl])

                if isValid(analysis.method.jump, cons.capability.active, i)
                    fminmax(show, i, scale[:P], Popt, cons.capability.active, head[:Popt])
                    fminmax(show, i, scale[:P], Pdul, dual.capability.active, head[:Pdul])
                end

                if isValid(analysis.method.jump, cons.capability.reactive, i)
                    fminmax(show, i, scale[:Q], Qopt, cons.capability.reactive, head[:Qopt])
                    fminmax(show, i, scale[:Q], Qdul, dual.capability.reactive, head[:Qdul])
                end
            end

            fminmax(fmt, width, show, scale[:P], gen.capability.minActive, head[:Pmin])
            fminmax(fmt, width, show, Popt, head[:Popt])
            fminmax(fmt, width, show, scale[:P], gen.capability.maxActive,head[:Pmax])
            fminmax(fmt, width, show, Pdul, head[:Pdul])

            fminmax(fmt, width, show, scale[:Q], gen.capability.minReactive, head[:Qmin])
            fminmax(fmt, width, show, Qopt, head[:Qopt])
            fminmax(fmt, width, show, scale[:Q], gen.capability.maxReactive, head[:Qmax])
            fminmax(fmt, width, show, Qdul, head[:Qdul])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Generator Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:Pcpb] => _blank(width, show, delimiter, style, head, :Pcpb, :Pmin, :Popt, :Pmax, :Pdul),
        head[:Qcpb] => _blank(width, show, delimiter, style, head, :Qcpb, :Qmin, :Qopt, :Qmax, :Qdul),
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printGeneratorConstraint(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = typemax(Int64),
    kwargs...
)
    gen = system.generator
    jump = analysis.method.jump
    cons = analysis.method.constraint
    dual = analysis.method.dual

    scale = scalePrint(system, pfx)
    prt = genCons(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Generator Constraint Data")

    @inbounds for (label, i) in pickLabel(gen, gen.label, label, "generator")
        if notLine(jump, i, cons.capability.active)
            continue
        end

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        if isValid(jump, cons.capability.active, i)
            printf(io, prt, i, scale[:P], gen.capability.minActive, :Pmin)
            printf(io, prt, i, scale[:P], cons.capability.active, :Popt)
            printf(io, prt, i, scale[:P], gen.capability.maxActive, :Pmax)
            printf(io, prt, i, scale[:P], dual.capability.active, :Pdul)
        else
            printf(io, prt.hfmt, prt, "", :Pmin, :Popt, :Pmax, :Pdul)
        end

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function genCons(
    system::PowerSystem,
    analysis::DCOptimalPowerFlow,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.angle)
    gen = system.generator
    cons = analysis.method.constraint
    dual = analysis.method.dual
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :Pcpb => "Active Power Capability",
        :Pmin => "Active Power Capability Minimum",
        :Popt => "Active Power Capability Solution",
        :Pmax => "Active Power Capability Maximum",
        :Pdul => "Active Power Capability Dual",
    )

    show = OrderedDict(head[:Pcpb] => true)
    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:labl] => _header("", head[:labl], style),
        head[:Pmin] => _header("Minimum", head[:Pmin], style),
        head[:Popt] => _header("Solution", head[:Popt], style),
        head[:Pmax] => _header("Maximum", head[:Pmax], style),
        head[:Pdul] => _header("Dual", head[:Pdul], style)
    )
    unit = Dict(
        head[:labl] => "",
        head[:Pmin] => "[" * unitList.activePowerLive * "]",
        head[:Popt] => "[" * unitList.activePowerLive * "]",
        head[:Pmax] => "[" * unitList.activePowerLive * "]",
        head[:Pdul] => "[\$/" * unitList.activePowerLive * "-hr]"
    )
    fmt = Dict(
        head[:labl] => "%-*s",
        head[:Pmin] => _fmt(fmt[head[:Pcpb]]),
        head[:Popt] => _fmt(fmt[head[:Pcpb]]),
        head[:Pmax] => _fmt(fmt[head[:Pcpb]]),
        head[:Pdul] => _fmt(fmt[head[:Pcpb]])
    )
    width = Dict(
        head[:labl] => 5 * style,
        head[:Pmin] => _width(width[head[:Pcpb]], 7, style),
        head[:Popt] => _width(width[head[:Pcpb]], 8, style),
        head[:Pmax] => _width(width[head[:Pcpb]], 7, style),
        head[:Pdul] => _width(width[head[:Pcpb]], textwidth(unit[head[:Pdul]]), style),
    )
    show = OrderedDict(
        head[:labl] => false,
        head[:Pmin] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Popt] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Pmax] => _show(show[head[:Pcpb]], cons.capability.active),
        head[:Pdul] => _show(show[head[:Pcpb]], dual.capability.active)
    )
    anycons!(show)

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(gen, label, "generator")
            i = gen.label[label]

            fmax(width, show, label, head[:labl])

            if isValid(analysis.method.jump, cons.capability.active, i)
                fmax(fmt, width, show, i, scale[:P], gen.capability.minActive, head[:Pmin])
                fmax(fmt, width, show, i, scale[:P], cons.capability.active, head[:Popt])
                fmax(fmt, width, show, i, scale[:P], gen.capability.maxActive, head[:Pmax])
                fmax(fmt, width, show, i, scale[:P], dual.capability.active, head[:Pdul])
            end

        else
            Popt = [-Inf; Inf]; Pdul = [-Inf; Inf]

            @inbounds for (label, i) in gen.label
                fmax(width, show, label, head[:labl])

                if isValid(analysis.method.jump, cons.capability.active, i)
                    fminmax(show, i, scale[:P], Popt, cons.capability.active, head[:Popt])
                    fminmax(show, i, scale[:P], Pdul, dual.capability.active, head[:Pdul])
                end
            end

            fminmax(fmt, width, show, scale[:P], gen.capability.minActive, head[:Pmin])
            fminmax(fmt, width, show, Popt, head[:Popt])
            fminmax(fmt, width, show, scale[:P], gen.capability.maxActive,head[:Pmax])
            fminmax(fmt, width, show, Pdul, head[:Pdul])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Generator Constraint Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:Pcpb] => _blank(width, show, delimiter, style, head, :Pcpb, :Pmin, :Popt, :Pmax, :Pdul),
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function notLine(jump::JuMP.Model, i::Int64, constraints::Dict{Int64, ConstraintRef}...)
    hasInLine = false
    for constraint in constraints
        if haskey(constraint, i) && is_valid(jump, constraint[i])
            hasInLine = true
            break
        end
    end

    return !hasInLine
end

function flowType(type::Int64, unitList::UnitList)
    if type == 1
        return "Active Power Flow", unitList.activePowerLive
    elseif type == 2 || type == 3
        return "Apparent Power Flow", unitList.apparentPowerLive
    elseif type == 4 || type == 5
        return "Current Flow Magnitude", unitList.currentMagnitudeLive
    end
end

function anycons!(show::OrderedDict{String, Bool})
    for (key, value) in show
        if value == true
            show["Label"] = true
            break
        end
    end
end

function checkFlowType(system::PowerSystem, analysis::ACOptimalPowerFlow)
    jump = analysis.method.jump
    from = analysis.method.constraint.flow.from
    to = analysis.method.constraint.flow.to
    angle = analysis.method.constraint.voltage.angle

    count = [0; 0; 0; 0; 0]
    for (i, type) in enumerate(system.branch.flow.type)
        fromFlag = haskey(from, i) && is_valid(jump, from[i])
        toFlag = haskey(to, i) && is_valid(jump, to[i])
        if fromFlag || toFlag
            count[type] += 1
        end
    end

    max_index = argmax(count)
    flowType = copy(system.branch.flow.type)
    for (i, type) in enumerate(system.branch.flow.type)
        fromFlag = !(haskey(from, i) && is_valid(jump, from[i]))
        toFlag = !(haskey(to, i) && is_valid(jump, to[i]))
        angleFlag = haskey(angle, i) && is_valid(jump, angle[i])

        if angleFlag && fromFlag && toFlag
            flowType[i] = max_index
        end
    end

    return findall(x -> x != 0, count), flowType
end

function flowScale(
    system::PowerSystem,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    i::Int64,
    type::Int64
)
    if type in (1, 2, 3)
        return flowScale(scale, type)
    elseif type in (4, 5)
        return flowScale(system, pfx, i)
    end

end

function flowScale(system::PowerSystem, pfx::PrefixLive, i::Int64)
    return scaleCurrent(pfx, system, system.branch.layout.from[i]),
        scaleCurrent(pfx, system, system.branch.layout.to[i])
end

function flowScale(scale::Dict{Symbol, Float64}, type::Int64)
    if type == 1
        return scale[:P], scale[:P]
    elseif type == 2 || type == 3
        return scale[:S], scale[:S]
    end
end