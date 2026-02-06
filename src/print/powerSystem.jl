"""
    printBusData(analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO` may be
passed as the last argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Examples
Print data for all buses:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

fmt = Dict("Power Demand" => "%.2f", "Voltage Magnitude" => "%.2f", "Label" => "%s")
show = Dict("Power Injection" => false, "Power Generation Reactive" => false)

printBusData(analysis; fmt, show, repeat = 10)
```

Print data for specific buses:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

delimiter = " "
width = Dict("Voltage" => 9, "Power Injection Active" => 9)

printBusData(analysis; label = "Bus 2 HV", delimiter, width, title = true, header = true)
printBusData(analysis; label = "Bus 10 LV", delimiter, width)
printBusData(analysis; label = "Bus 12 LV", delimiter, width, footer = true)
```
"""
function printBusData(
    analysis::AC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.bus.number + 1,
    kwargs...
)
    system = analysis.system
    bus = system.bus

    scale = scalePrint(system, pfx)
    prt = busData(system, analysis, unitList, pfx, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Bus Data")

    @inbounds for (label, i) in pickLabel(bus, bus.label, label, "bus")
        scaleVolt = scaleVoltage(pfx, system, i)
        scaleCurr = scaleCurrent(pfx, system, i)

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lblB)

        printf(io, prt, i, scaleVolt, analysis.voltage.magnitude, :Vmag)
        printf(io, prt, i, scale[:θ], analysis.voltage.angle, :Vang)
        printf(io, prt, i, scale[:P], analysis.power.supply.active, :Pgen)
        printf(io, prt, i, scale[:Q], analysis.power.supply.reactive, :Qgen)
        printf(io, prt, i, scale[:P], system.bus.demand.active, :Pdem)
        printf(io, prt, i, scale[:Q], system.bus.demand.reactive, :Qdem)
        printf(io, prt, i, scale[:P], analysis.power.injection.active, :Pinj)
        printf(io, prt, i, scale[:Q], analysis.power.injection.reactive, :Qinj)
        printf(io, prt, i, scale[:P], analysis.power.shunt.active, :Pshu)
        printf(io, prt, i, scale[:Q], analysis.power.shunt.reactive, :Qshu)
        printf(io, prt, i, scaleCurr, analysis.current.injection.magnitude, :Imag)
        printf(io, prt, i, scale[:ψ], analysis.current.injection.angle, :Iang)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function busData(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :lblB => "Label Bus",
        :Volt => "Voltage",
        :Vmag => "Voltage Magnitude",
        :Vang => "Voltage Angle",
        :Gene => "Power Generation",
        :Pgen => "Power Generation Active",
        :Qgen => "Power Generation Reactive",
        :Demd => "Power Demand",
        :Pdem => "Power Demand Active",
        :Qdem => "Power Demand Reactive",
        :Injc => "Power Injection",
        :Pinj => "Power Injection Active",
        :Qinj => "Power Injection Reactive",
        :Shun => "Shunt Power",
        :Pshu => "Shunt Power Active",
        :Qshu => "Shunt Power Reactive",
        :Iinj => "Current Injection",
        :Imag => "Current Injection Magnitude",
        :Iang => "Current Injection Angle",
    )
    show = OrderedDict(
        head[:labl] => true,
        head[:Volt] => true,
        head[:Gene] => true,
        head[:Demd] => true,
        head[:Injc] => true,
        head[:Shun] => true,
        head[:Iinj] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lblB] => _header("Bus", "Bus Label", style),
        head[:Vmag] => _header("Magnitude", head[:Vmag], style),
        head[:Vang] => _header("Angle", head[:Vang], style),
        head[:Pgen] => _header("Active", "Power Generation Active", style),
        head[:Qgen] => _header("Reactive", "Power Generation Reactive", style),
        head[:Pdem] => _header("Active", "Active Power Demand", style),
        head[:Qdem] => _header("Reactive", "Reactive Power Demand", style),
        head[:Pinj] => _header("Active", "Active Power Injection", style),
        head[:Qinj] => _header("Reactive", "Reactive Power Injection", style),
        head[:Pshu] => _header("Active", "Shunt Active Power", style),
        head[:Qshu] => _header("Reactive", "Shunt Reactive Power", style),
        head[:Imag] => _header("Magnitude", head[:Imag], style),
        head[:Iang] => _header("Angle", head[:Iang], style)
    )
    unit = Dict(
        head[:lblB] => "",
        head[:Vmag] => "[" * unitList.voltageMagnitudeLive * "]",
        head[:Vang] => "[" * unitList.voltageAngleLive * "]",
        head[:Pgen] => "[" * unitList.activePowerLive * "]",
        head[:Qgen] => "[" * unitList.reactivePowerLive * "]",
        head[:Pdem] => "[" * unitList.activePowerLive * "]",
        head[:Qdem] => "[" * unitList.reactivePowerLive * "]",
        head[:Pinj] => "[" * unitList.activePowerLive * "]",
        head[:Qinj] => "[" * unitList.reactivePowerLive * "]",
        head[:Pshu] => "[" * unitList.activePowerLive * "]",
        head[:Qshu] => "[" * unitList.reactivePowerLive * "]",
        head[:Imag] => "[" * unitList.currentMagnitudeLive * "]",
        head[:Iang] => "[" * unitList.currentAngleLive * "]"
    )
    fmt = Dict(
        head[:lblB] => _fmt(fmt[head[:labl]]; format = "%-*s"),
        head[:Vmag] => _fmt(fmt[head[:Volt]]),
        head[:Vang] => _fmt(fmt[head[:Volt]]),
        head[:Pgen] => _fmt(fmt[head[:Gene]]),
        head[:Qgen] => _fmt(fmt[head[:Gene]]),
        head[:Pdem] => _fmt(fmt[head[:Demd]]),
        head[:Qdem] => _fmt(fmt[head[:Demd]]),
        head[:Pinj] => _fmt(fmt[head[:Injc]]),
        head[:Qinj] => _fmt(fmt[head[:Injc]]),
        head[:Pshu] => _fmt(fmt[head[:Shun]]),
        head[:Qshu] => _fmt(fmt[head[:Shun]]),
        head[:Imag] => _fmt(fmt[head[:Iinj]]),
        head[:Iang] => _fmt(fmt[head[:Iinj]])
    )
    width = Dict(
        head[:lblB] => _width(width[head[:labl]], 5, style),
        head[:Vmag] => _width(width[head[:Volt]], 9, style),
        head[:Vang] => _width(width[head[:Volt]], 5, style),
        head[:Pgen] => _width(width[head[:Gene]], 6, style),
        head[:Qgen] => _width(width[head[:Gene]], 8, style),
        head[:Pdem] => _width(width[head[:Demd]], 6, style),
        head[:Qdem] => _width(width[head[:Demd]], 8, style),
        head[:Pinj] => _width(width[head[:Injc]], 6, style),
        head[:Qinj] => _width(width[head[:Injc]], 8, style),
        head[:Pshu] => _width(width[head[:Shun]], 6, style),
        head[:Qshu] => _width(width[head[:Shun]], 8, style),
        head[:Imag] => _width(width[head[:Iinj]], 9, style),
        head[:Iang] => _width(width[head[:Iinj]], 5, style)
    )
    show = OrderedDict(
        head[:lblB] => _show(show[head[:labl]], true),
        head[:Vmag] => _show(show[head[:Volt]], voltage.magnitude),
        head[:Vang] => _show(show[head[:Volt]], voltage.angle),
        head[:Pgen] => _show(show[head[:Gene]], power.supply.active),
        head[:Qgen] => _show(show[head[:Gene]], power.supply.reactive),
        head[:Pdem] => _show(show[head[:Demd]], power.injection.active),
        head[:Qdem] => _show(show[head[:Demd]], power.injection.reactive),
        head[:Pinj] => _show(show[head[:Injc]], power.injection.active),
        head[:Qinj] => _show(show[head[:Injc]], power.injection.reactive),
        head[:Pshu] => _show(show[head[:Shun]], power.shunt.active),
        head[:Qshu] => _show(show[head[:Shun]], power.shunt.reactive),
        head[:Imag] => _show(show[head[:Iinj]], current.injection.magnitude),
        head[:Iang] => _show(show[head[:Iinj]], current.injection.angle)
    )
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            scaleVolg = scaleVoltage(pfx, system, i)
            scaleCurr = scaleCurrent(pfx, system, i)

            fmax(width, show, label, head[:lblB])

            fmax(fmt, width, show, i, scaleVolg, voltage.magnitude, head[:Vmag])
            fmax(fmt, width, show, i, scale[:θ], voltage.angle, head[:Vang])
            fmax(fmt, width, show, i, scale[:P], power.supply.active, head[:Pgen])
            fmax(fmt, width, show, i, scale[:Q], power.supply.reactive, head[:Qgen])
            fmax(fmt, width, show, i, scale[:P], system.bus.demand.active, head[:Pdem])
            fmax(fmt, width, show, i, scale[:Q], system.bus.demand.reactive, head[:Qdem])
            fmax(fmt, width, show, i, scale[:P], power.injection.active, head[:Pinj])
            fmax(fmt, width, show, i, scale[:Q], power.injection.reactive, head[:Qinj])
            fmax(fmt, width, show, i, scale[:P], power.shunt.active, head[:Pshu])
            fmax(fmt, width, show, i, scale[:Q], power.shunt.reactive, head[:Qshu])
            fmax(fmt, width, show, i, scaleCurr, current.injection.magnitude, head[:Imag])
            fmax(fmt, width, show, i, scale[:ψ], current.injection.angle, head[:Iang])
        else
            fmax(width, show, system.bus.label, head[:lblB])

            fminmax(fmt, width, show, scale[:θ], voltage.angle, head[:Vang])
            fminmax(fmt, width, show, scale[:P], power.supply.active, head[:Pgen])
            fminmax(fmt, width, show, scale[:Q], power.supply.reactive, head[:Qgen])
            fminmax(fmt, width, show, scale[:P], system.bus.demand.active, head[:Pdem])
            fminmax(fmt, width, show, scale[:Q], system.bus.demand.reactive, head[:Qdem])
            fminmax(fmt, width, show, scale[:P], power.injection.active, head[:Pinj])
            fminmax(fmt, width, show, scale[:Q], power.injection.reactive, head[:Qinj])
            fminmax(fmt, width, show, scale[:P], power.shunt.active, head[:Pshu])
            fminmax(fmt, width, show, scale[:Q], power.shunt.reactive, head[:Qshu])
            fminmax(fmt, width, show, scale[:ψ], current.injection.angle, head[:Iang])

            maxV = -Inf; maxI = -Inf
            @inbounds for (label, i) in system.bus.label
                if pfx.voltageMagnitude != 0.0
                    scale = scaleVoltage(system, pfx, i)
                    maxV = fmax(show, i, scale, maxV, voltage.magnitude, head[:Vmag])
                end
                if pfx.currentMagnitude != 0.0
                    scale = scaleCurrent(system, pfx, i)
                    maxI = fmax(show, i, scale, maxI, current.injection.magnitude, head[:Imag])
                end
            end

            if pfx.voltageMagnitude == 0.0
                fmax(fmt, width, show, voltage.magnitude, head[:Vmag])
            else
                fmax(fmt, width, show, maxV, head[:Vmag])
            end
            if pfx.currentMagnitude == 0.0
                fmax(fmt, width, show, current.injection.magnitude, head[:Imag])
            else
                fmax(fmt, width, show, maxI, head[:Imag])
            end
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Bus Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :lblB),
        head[:Volt] => _blank(width, show, delimiter, style, head, :Volt, :Vmag, :Vang),
        head[:Gene] => _blank(width, show, delimiter, style, head, :Gene, :Pgen, :Qgen),
        head[:Demd] => _blank(width, show, delimiter, style, head, :Demd, :Pdem, :Qdem),
        head[:Injc] => _blank(width, show, delimiter, style, head, :Injc, :Pinj, :Qinj),
        head[:Shun] => _blank(width, show, delimiter, style, head, :Shun, :Pshu, :Qshu),
        head[:Iinj] => _blank(width, show, delimiter, style, head, :Iinj, :Imag, :Iang)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printBusData(
    analysis::DC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.bus.number + 1,
    kwargs...
)
    system = analysis.system
    bus = system.bus

    scale = scalePrint(system, pfx)
    prt = busData(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Bus Data")

    @inbounds for (label, i) in pickLabel(bus, bus.label, label, "bus")
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lblB)

        printf(io, prt, i, scale[:θ], analysis.voltage.angle, :Vang)
        printf(io, prt, i, scale[:P], analysis.power.supply.active, :Pgen)
        printf(io, prt, i, scale[:P], system.bus.demand.active, :Pdem)
        printf(io, prt, i, scale[:P], analysis.power.injection.active, :Pinj)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function busData(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    power = analysis.power
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :labl => "Label",
        :lblB => "Label Bus",
        :Volt => "Voltage",
        :Vang => "Voltage Angle",
        :Gene => "Power Generation",
        :Pgen => "Power Generation Active",
        :Demd => "Power Demand",
        :Pdem => "Power Demand Active",
        :Injc => "Power Injection",
        :Pinj => "Power Injection Active"
    )
    show = OrderedDict(
        head[:labl] => true,
        head[:Volt] => true,
        head[:Gene] => true,
        head[:Demd] => true,
        head[:Injc] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lblB] => _header("Bus", "Bus Label", style),
        head[:Vang] => _header("Angle", head[:Vang], style),
        head[:Pgen] => _header("Active", "Active Power Generation", style),
        head[:Pdem] => _header("Active", "Active Power Demand", style),
        head[:Pinj] => _header("Active", "Active Power Injection", style)
    )
    unit = Dict(
        head[:lblB] => "",
        head[:Vang] => "[" * unitList.voltageAngleLive * "]",
        head[:Pgen] => "[" * unitList.activePowerLive * "]",
        head[:Pdem] => "[" * unitList.activePowerLive * "]",
        head[:Pinj] => "[" * unitList.activePowerLive * "]"
    )
    fmt = Dict(
        head[:lblB] => _fmt(fmt[head[:labl]]; format = "%-*s"),
        head[:Vang] => _fmt(fmt[head[:Volt]]),
        head[:Pgen] => _fmt(fmt[head[:Gene]]),
        head[:Pdem] => _fmt(fmt[head[:Demd]]),
        head[:Pinj] => _fmt(fmt[head[:Injc]])
    )
    width = Dict(
        head[:lblB] => _width(width[head[:labl]], 5, style),
        head[:Vang] => _width(width[head[:Volt]], 7, style),
        head[:Pgen] => _width(width[head[:Gene]], 16, style),
        head[:Pdem] => _width(width[head[:Demd]], 12, style),
        head[:Pinj] => _width(width[head[:Injc]], 15, style)
    )
    show = OrderedDict(
        head[:lblB] => _show(show[head[:labl]], true),
        head[:Vang] => _show(show[head[:Volt]], voltage.angle),
        head[:Pgen] => _show(show[head[:Gene]], power.supply.active),
        head[:Pdem] => _show(show[head[:Demd]], power.injection.active),
        head[:Pinj] => _show(show[head[:Injc]], power.injection.active)
    )

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            fmax(width, show, label, head[:lblB])
            fmax(fmt, width, show, i, scale[:θ], voltage.angle, head[:Vang])
            fmax(fmt, width, show, i, scale[:P], power.supply.active, head[:Pgen])
            fmax(fmt, width, show, i, scale[:P], system.bus.demand.active, head[:Pdem])
            fmax(fmt, width, show, i, scale[:P], power.injection.active, head[:Pinj])
        else
            fmax(width, show, system.bus.label, head[:lblB])
            fminmax(fmt, width, show, scale[:θ], voltage.angle, head[:Vang])
            fminmax(fmt, width, show, scale[:P], power.supply.active, head[:Pgen])
            fminmax(fmt, width, show, scale[:P], system.bus.demand.active, head[:Pdem])
            fminmax(fmt, width, show, scale[:P], power.injection.active, head[:Pinj])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Bus Data")

    heading = OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :lblB),
        head[:Volt] => _blank(width, show, delimiter, head, :Vang),
        head[:Gene] => _blank(width, show, delimiter, head, :Pgen),
        head[:Demd] => _blank(width, show, delimiter, head, :Pdem),
        head[:Injc] => _blank(width, show, delimiter, head, :Pinj)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

"""
    printBranchData(analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints powers and currents related to branches. Optionally, an `IO` may be passed as the
last argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Examples
Print data for all branches:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

fmt = Dict("Shunt Power" => "%.2f", "Series Power Reactive" => "%.2f")
show = Dict("From-Bus Power" => false, "To-Bus Power Reactive" => false)

printBranchData(analysis; fmt, show, repeat = 11, title = false)
```

Print data for specific branches:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

delimiter = " "
width = Dict("From-Bus Power" => 9, "To-Bus Power Active" => 9)

printBranchData(analysis; label = 2, delimiter, width, header = true)
printBranchData(analysis; label = 12, delimiter, width)
printBranchData(analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBranchData(
    analysis::AC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.branch.number + 1,
    kwargs...
)
    system = analysis.system
    brch = system.branch

    scale = scalePrint(system, pfx)
    buses, prt = branchData(system, analysis, unitList, pfx, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Branch Data")

    @inbounds for (label, i) in pickLabel(brch, brch.label, label, "branch")
        scaleCurf = scaleCurrent(pfx, system, system.branch.layout.from[i])
        scaleCurt = scaleCurrent(pfx, system, system.branch.layout.to[i])

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lbB)

        printf(io, prt, system.branch.layout.from[i], buses, :lbF)
        printf(io, prt, system.branch.layout.to[i], buses, :lbT)

        printf(io, prt, i, scale[:P], analysis.power.from.active, :Pij)
        printf(io, prt, i, scale[:Q], analysis.power.from.reactive, :Qij)
        printf(io, prt, i, scale[:P], analysis.power.to.active, :Pji)
        printf(io, prt, i, scale[:Q], analysis.power.to.reactive, :Qji)
        printf(io, prt, i, scale[:P], analysis.power.charging.active, :Psh)
        printf(io, prt, i, scale[:Q], analysis.power.charging.reactive, :Qsh)
        printf(io, prt, i, scale[:P], analysis.power.series.active, :Pse)
        printf(io, prt, i, scale[:Q], analysis.power.series.reactive, :Qse)
        printf(io, prt, i, scaleCurf, analysis.current.from.magnitude, :Iij)
        printf(io, prt, i, scale[:ψ], analysis.current.from.angle, :ψij)
        printf(io, prt, i, scaleCurt, analysis.current.to.magnitude, :Iji)
        printf(io, prt, i, scale[:ψ], analysis.current.to.angle, :ψji)
        printf(io, prt, i, scaleCurt, analysis.current.series.magnitude, :Ise)
        printf(io, prt, i, scale[:ψ], analysis.current.series.angle, :ψse)

        printf(io, prt, i, system.branch.layout.status, :sts)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function branchData(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    power = analysis.power
    current = analysis.current
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :lbl => "Label",
        :lbB => "Label Branch",
        :lbF => "Label From-Bus",
        :lbT => "Label To-Bus",
        :Sij => "From-Bus Power",
        :Pij => "From-Bus Power Active",
        :Qij => "From-Bus Power Reactive",
        :Sji => "To-Bus Power",
        :Pji => "To-Bus Power Active",
        :Qji => "To-Bus Power Reactive",
        :Ssh => "Shunt Power",
        :Psh => "Shunt Power Active",
        :Qsh => "Shunt Power Reactive",
        :Sse => "Series Power",
        :Pse => "Series Power Active",
        :Qse => "Series Power Reactive",
        :Cij => "From-Bus Current",
        :Iij => "From-Bus Current Magnitude",
        :ψij => "From-Bus Current Angle",
        :Cji => "To-Bus Current",
        :Iji => "To-Bus Current Magnitude",
        :ψji => "To-Bus Current Angle",
        :Cse => "Series Current",
        :Ise => "Series Current Magnitude",
        :ψse => "Series Current Angle",
        :sts => "Status"
    )
    show = OrderedDict(
        head[:lbl] => true,
        head[:Sij] => true,
        head[:Sji] => true,
        head[:Ssh] => true,
        head[:Sse] => true,
        head[:Cij] => true,
        head[:Cji] => true,
        head[:Cse] => true,
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lbB] => _header("Branch", "Branch Label", style),
        head[:lbF] => _header("From-Bus", "From-Bus Label", style),
        head[:lbT] => _header("To-Bus", "To-Bus Label", style),
        head[:Pij] => _header("Active", "From-Bus Active Power", style),
        head[:Qij] => _header("Reactive", "From-Bus Reactive Power", style),
        head[:Pji] => _header("Active", "To-Bus Active Power", style),
        head[:Qji] => _header("Reactive", "To-Bus Reactive Power", style),
        head[:Psh] => _header("Active", "Shunt Active Power", style),
        head[:Qsh] => _header("Reactive", "Shunt Reactive Power", style),
        head[:Pse] => _header("Active", "Series Active Power", style),
        head[:Qse] => _header("Reactive", "Series Reactive Power", style),
        head[:Iij] => _header("Magnitude", head[:Iij], style),
        head[:ψij] => _header("Angle", head[:ψij], style),
        head[:Iji] => _header("Magnitude", head[:Iji], style),
        head[:ψji] => _header("Angle", head[:ψji], style),
        head[:Ise] => _header("Magnitude", head[:Ise], style),
        head[:ψse] => _header("Angle", head[:ψse], style),
        head[:sts] => _header("", head[:sts], style),
    )
    unit = Dict(
        head[:lbB] => "",
        head[:lbF] => "",
        head[:lbT] => "",
        head[:Pij] => "[" * unitList.activePowerLive * "]",
        head[:Qij] => "[" * unitList.reactivePowerLive * "]",
        head[:Pji] => "[" * unitList.activePowerLive * "]",
        head[:Qji] => "[" * unitList.reactivePowerLive * "]",
        head[:Psh] => "[" * unitList.activePowerLive * "]",
        head[:Qsh] => "[" * unitList.reactivePowerLive * "]",
        head[:Pse] => "[" * unitList.activePowerLive * "]",
        head[:Qse] => "[" * unitList.reactivePowerLive * "]",
        head[:Iij] => "[" * unitList.currentMagnitudeLive * "]",
        head[:ψij] => "[" * unitList.currentAngleLive * "]",
        head[:Iji] => "[" * unitList.currentMagnitudeLive * "]",
        head[:ψji] => "[" * unitList.currentAngleLive * "]",
        head[:Ise] => "[" * unitList.currentMagnitudeLive * "]",
        head[:ψse] => "[" * unitList.currentAngleLive * "]",
        head[:sts] => ""
    )
    fmt = Dict(
        head[:lbB] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:lbF] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:lbT] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:Pij] => _fmt(fmt[head[:Sij]]),
        head[:Qij] => _fmt(fmt[head[:Sij]]),
        head[:Pji] => _fmt(fmt[head[:Sji]]),
        head[:Qji] => _fmt(fmt[head[:Sji]]),
        head[:Psh] => _fmt(fmt[head[:Ssh]]),
        head[:Qsh] => _fmt(fmt[head[:Ssh]]),
        head[:Pse] => _fmt(fmt[head[:Sse]]),
        head[:Qse] => _fmt(fmt[head[:Sse]]),
        head[:Iij] => _fmt(fmt[head[:Cij]]),
        head[:ψij] => _fmt(fmt[head[:Cij]]),
        head[:Iji] => _fmt(fmt[head[:Cji]]),
        head[:ψji] => _fmt(fmt[head[:Cji]]),
        head[:Ise] => _fmt(fmt[head[:Cse]]),
        head[:ψse] => _fmt(fmt[head[:Cse]]),
        head[:sts] => "%*i"
    )
    width = Dict(
        head[:lbB] => _width(width[head[:lbl]], 6, style),
        head[:lbF] => _width(width[head[:lbl]], 8, style),
        head[:lbT] => _width(width[head[:lbl]], 6, style),
        head[:Pij] => _width(width[head[:Sij]], 6, style),
        head[:Qij] => _width(width[head[:Sij]], 8, style),
        head[:Pji] => _width(width[head[:Sji]], 6, style),
        head[:Qji] => _width(width[head[:Sji]], 8, style),
        head[:Psh] => _width(width[head[:Ssh]], 6, style),
        head[:Qsh] => _width(width[head[:Ssh]], 8, style),
        head[:Pse] => _width(width[head[:Sse]], 6, style),
        head[:Qse] => _width(width[head[:Sse]], 8, style),
        head[:Iij] => _width(width[head[:Cij]], 9, style),
        head[:ψij] => _width(width[head[:Cij]], 5, style),
        head[:Iji] => _width(width[head[:Cji]], 9, style),
        head[:ψji] => _width(width[head[:Cji]], 5, style),
        head[:Ise] => _width(width[head[:Cse]], 9, style),
        head[:ψse] => _width(width[head[:Cse]], 5, style),
        head[:sts] => 6 * style
    )
    show = OrderedDict(
        head[:lbB] => _show(show[head[:lbl]], true),
        head[:lbF] => _show(show[head[:lbl]], true),
        head[:lbT] => _show(show[head[:lbl]], true),
        head[:Pij] => _show(show[head[:Sij]], power.from.active),
        head[:Qij] => _show(show[head[:Sij]], power.from.reactive),
        head[:Pji] => _show(show[head[:Sji]], power.to.active),
        head[:Qji] => _show(show[head[:Sji]], power.to.reactive),
        head[:Psh] => _show(show[head[:Ssh]], power.charging.active),
        head[:Qsh] => _show(show[head[:Ssh]], power.charging.reactive),
        head[:Pse] => _show(show[head[:Sse]], power.series.active),
        head[:Qse] => _show(show[head[:Sse]], power.series.reactive),
        head[:Iij] => _show(show[head[:Cij]], current.from.magnitude),
        head[:ψij] => _show(show[head[:Cij]], current.from.angle),
        head[:Iji] => _show(show[head[:Cji]], current.to.magnitude),
        head[:ψji] => _show(show[head[:Cji]], current.to.angle),
        head[:Ise] => _show(show[head[:Cse]], current.series.magnitude),
        head[:ψse] => _show(show[head[:Cse]], current.series.angle),
        head[:sts] => true
    )

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    buses = getLabel(system.bus.label, label, show, head[:lbF], head[:lbT])
    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            scaleCurf = scaleCurrent(pfx, system, system.branch.layout.from[i])
            scaleCurt = scaleCurrent(pfx, system, system.branch.layout.to[i])

            fmax(width, show, label, head[:lbB])
            fmax(width, show, getLabel(buses, system.branch.layout.from[i]), head[:lbF])
            fmax(width, show, getLabel(buses, system.branch.layout.to[i]), head[:lbT])

            fmax(fmt, width, show, i, scale[:P], power.from.active, head[:Pij])
            fmax(fmt, width, show, i, scale[:Q], power.from.reactive,head[:Qij])
            fmax(fmt, width, show, i, scale[:P], power.to.active, head[:Pji])
            fmax(fmt, width, show, i, scale[:Q], power.to.reactive, head[:Qji])
            fmax(fmt, width, show, i, scale[:P], power.charging.active, head[:Psh])
            fmax(fmt, width, show, i, scale[:Q], power.charging.reactive, head[:Qsh])
            fmax(fmt, width, show, i, scale[:P], power.series.active, head[:Pse])
            fmax(fmt, width, show, i, scale[:Q], power.series.reactive, head[:Qse])
            fmax(fmt, width, show, i, scaleCurf, current.from.magnitude, head[:Iij])
            fmax(fmt, width, show, i, scale[:ψ], current.from.angle, head[:ψij])
            fmax(fmt, width, show, i, scaleCurt, current.to.magnitude, head[:Iji])
            fmax(fmt, width, show, i, scale[:ψ], current.to.angle, head[:ψji])
            fmax(fmt, width, show, i, scaleCurt, current.series.magnitude, head[:Ise])
            fmax(fmt, width, show, i, scale[:ψ], current.series.angle, head[:ψse])
        else
            fmax(width, show, system.branch.label, head[:lbB])
            fmax(width, show, buses, head[:lbF], head[:lbT])

            fminmax(fmt, width, show, scale[:P], power.from.active, head[:Pij])
            fminmax(fmt, width, show, scale[:Q], power.from.reactive, head[:Qij])
            fminmax(fmt, width, show, scale[:P], power.to.active, head[:Pji])
            fminmax(fmt, width, show, scale[:Q], power.to.reactive, head[:Qji])
            fminmax(fmt, width, show, scale[:P], power.charging.active, head[:Psh])
            fminmax(fmt, width, show, scale[:Q], power.charging.reactive, head[:Qsh])
            fminmax(fmt, width, show, scale[:P], power.series.active, head[:Pse])
            fminmax(fmt, width, show, scale[:Q], power.series.reactive, head[:Qse])
            fminmax(fmt, width, show, scale[:ψ], current.from.angle, head[:ψij])
            fminmax(fmt, width, show, scale[:ψ], current.to.angle, head[:ψji])
            fminmax(fmt, width, show, scale[:ψ], current.series.angle, head[:ψse])

            if pfx.currentMagnitude == 0.0
                fmax(fmt, width, show, current.from.magnitude, head[:Iij])
                fmax(fmt, width, show, current.to.magnitude, head[:Iji])
                fmax(fmt, width, show, current.series.magnitude, head[:Ise])
            else
                maxF = -Inf; maxT = -Inf; maxS = -Inf
                @inbounds for (label, i) in system.branch.label
                    currf = scaleCurrent(system, pfx, system.branch.layout.from[i])
                    currt = scaleCurrent(system, pfx, system.branch.layout.to[i])

                    maxF = fmax(show, i, currf, maxF, current.from.magnitude, head[:Iij])
                    maxT = fmax(show, i, currt, maxT, current.to.magnitude, head[:Iji])
                    maxS = fmax(show, i, currt, maxS, current.series.magnitude, head[:Ise])
                end
                fmax(fmt, width, show, maxF, head[:Iij])
                fmax(fmt, width, show, maxT, head[:Iji])
                fmax(fmt, width, show, maxS, head[:Ise])
            end
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Branch Data")

    heading = OrderedDict(
        head[:lbl] => _blank(width, show, delimiter, style, head, :lbl, :lbB, :lbF, :lbT),
        head[:Sij] => _blank(width, show, delimiter, style, head, :Sij, :Pij, :Qij),
        head[:Sji] => _blank(width, show, delimiter, style, head, :Sji, :Pji, :Qji),
        head[:Ssh] => _blank(width, show, delimiter, style, head, :Ssh, :Psh, :Qsh),
        head[:Sse] => _blank(width, show, delimiter, style, head, :Sse, :Pse, :Qse),
        head[:Cij] => _blank(width, show, delimiter, style, head, :Cij, :Iij, :ψij),
        head[:Cji] => _blank(width, show, delimiter, style, head, :Cji, :Iji, :ψji),
        head[:Cse] => _blank(width, show, delimiter, style, head, :Cse, :Ise, :ψse),
        head[:sts] => _blank(width, show, delimiter, head, :sts)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    return buses, Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printBranchData(
    analysis::DC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.branch.number + 1,
    kwargs...
)
    system = analysis.system
    brch = system.branch

    scale = scalePrint(system, pfx)
    buses, prt = branchData(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Branch Data")

    @inbounds for (label, i) in pickLabel(brch, brch.label, label, "branch")
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lbB)

        printf(io, prt, system.branch.layout.from[i], buses, :lbF)
        printf(io, prt, system.branch.layout.to[i], buses, :lbT)

        printf(io, prt, i, scale[:P], analysis.power.from.active, :Pij)
        printf(io, prt, i, scale[:P], analysis.power.to.active, :Pji)
        printf(io, prt, i, system.branch.layout.status, :sts)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function branchData(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    power = analysis.power
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :lbl => "Label",
        :lbB => "Label Branch",
        :lbF => "Label From-Bus",
        :lbT => "Label To-Bus",
        :Sij => "From-Bus Power",
        :Pij => "From-Bus Power Active",
        :Sji => "To-Bus Power",
        :Pji => "To-Bus Power Active",
        :sts => "Status"
    )
    show = OrderedDict(
        head[:lbl] => true,
        head[:Sij] => true,
        head[:Sji] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lbB] => _header("Branch", "Branch Label", style),
        head[:lbF] => _header("From-Bus", "From-Bus Label", style),
        head[:lbT] => _header("To-Bus", "To-Bus Label", style),
        head[:Pij] => _header("Active", "From-Bus Active Power", style),
        head[:Pji] => _header("Active", "To-Bus Active Power", style),
        head[:sts] => _header("", head[:sts], style),
    )
    unit = Dict(
        head[:lbB] => "",
        head[:lbF] => "",
        head[:lbT] => "",
        head[:Pij] => "[" * unitList.activePowerLive * "]",
        head[:Pji] => "[" * unitList.activePowerLive * "]",
        head[:sts] => ""
    )
    fmt = Dict(
        head[:lbB] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:lbF] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:lbT] => _fmt(fmt[head[:lbl]]; format = "%-*s"),
        head[:Pij] => _fmt(fmt[head[:Sij]]),
        head[:Pji] => _fmt(fmt[head[:Sji]]),
        head[:sts] => "%*i"
    )
    width = Dict(
        head[:lbB] => _width(width[head[:lbl]], 6, style),
        head[:lbF] => _width(width[head[:lbl]], 8, style),
        head[:lbT] => _width(width[head[:lbl]], 6, style),
        head[:Pij] => _width(width[head[:Sij]], 14, style),
        head[:Pji] => _width(width[head[:Sji]], 12, style),
        head[:sts] => 6 * style
    )
    show = OrderedDict(
        head[:lbB] => _show(show[head[:lbl]], true),
        head[:lbF] => _show(show[head[:lbl]], true),
        head[:lbT] => _show(show[head[:lbl]], true),
        head[:Pij] => _show(show[head[:Sij]], power.from.active),
        head[:Pji] => _show(show[head[:Sji]], power.to.active),
        head[:sts] => true
    )

    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    buses = getLabel(system.bus.label, label, show, head[:lbF], head[:lbT])
    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            fmax(width, show, label, head[:lbB])
            fmax(width, show, getLabel(buses, system.branch.layout.from[i]), head[:lbF])
            fmax(width, show, getLabel(buses, system.branch.layout.to[i]), head[:lbT])

            fmax(fmt, width, show, i, scale[:P],  power.from.active, head[:Pij])
            fmax(fmt, width, show, i, scale[:P], power.to.active, head[:Pji])
        else
            fmax(width, show, system.branch.label, head[:lbB])
            fmax(width, show, buses, head[:lbF], head[:lbT])

            fminmax(fmt, width, show, scale[:P], power.from.active, head[:Pij])
            fminmax(fmt, width, show, scale[:P], power.to.active, head[:Pji])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Branch Data")

    heading = OrderedDict(
        head[:lbl] => _blank(width, show, delimiter, style, head, :lbl, :lbB, :lbF, :lbT),
        head[:Sij] => _blank(width, show, delimiter, head, :Pij),
        head[:Sji] => _blank(width, show, delimiter, head, :Pji),
        head[:sts] => _blank(width, show, delimiter, head, :sts)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    return buses, Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

"""
    printGeneratorData(analysis::Analysis, [io::IO];
        label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints powers related to generators. Optionally, an `IO` may be passed as the last
argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Examples
Print data for all generators:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

fmt = Dict("Power Output Active" => "%.2f")
show = Dict("Power Output Reactive" => false)

printGeneratorData(analysis; fmt, show, title = false)
```

Print data for specific generators:
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

delimiter = " "
width = Dict("Power Output Active" => 7)

printGeneratorData(analysis; label = 1, delimiter, width, header = true)
printGeneratorData(analysis; label = 4, delimiter, width)
printGeneratorData(analysis; label = 5, delimiter, width, footer = true)
```
"""
function printGeneratorData(
    analysis::AC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.generator.number + 1,
    kwargs...
)
    system = analysis.system
    gen = system.generator

    scale = scalePrint(system, pfx)
    buses, prt = genData(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Generator Data")

    @inbounds for (label, i) in pickLabel(gen, gen.label, label, "generator")
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lbG)

        printf(io, prt, system.generator.layout.bus[i], buses, :lbB)
        printf(io, prt, i, scale[:P], analysis.power.generator.active, :Pge)
        printf(io, prt, i, scale[:Q], analysis.power.generator.reactive, :Qge)
        printf(io, prt, i, system.generator.layout.status, :sts)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function genData(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    power = analysis.power
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :lab => "Label",
        :lbG => "Label Generator",
        :lbB => "Label Bus",
        :Gen => "Power Output",
        :Pge => "Power Output Active",
        :Qge => "Power Output Reactive",
        :sts => "Status",
    )
    show = OrderedDict(
        head[:lab] => true,
        head[:Gen] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lbG] => _header("Generator", "Generator Label", style),
        head[:lbB] => _header("Bus", "Bus Label", style),
        head[:Pge] => _header("Active", "Active Power Output", style),
        head[:Qge] => _header("Reactive", "Reactive Power Output", style),
        head[:sts] => _header("", head[:sts], style),
    )
    unit = Dict(
        head[:lbG] => "",
        head[:lbB] => "",
        head[:Pge] => "[" * unitList.activePowerLive * "]",
        head[:Qge] => "[" * unitList.reactivePowerLive * "]",
        head[:sts] => ""
    )
    fmt = Dict(
        head[:lbG] => _fmt(fmt[head[:lab]]; format = "%-*s"),
        head[:lbB] => _fmt(fmt[head[:lab]]; format = "%-*s"),
        head[:Pge] => _fmt(fmt[head[:Gen]]),
        head[:Qge] => _fmt(fmt[head[:Gen]]),
        head[:sts] => "%*i"
    )
    width = Dict(
        head[:lbG] => _width(width[head[:lab]], 9, style),
        head[:lbB] => _width(width[head[:lab]], 3, style),
        head[:Pge] => _width(width[head[:Gen]], 6, style),
        head[:Qge] => _width(width[head[:Gen]], 8, style),
        head[:sts] => 6 * style
    )
    show = OrderedDict(
        head[:lbG] => _show(show[head[:lab]], true),
        head[:lbB] => _show(show[head[:lab]], true),
        head[:Pge] => _show(show[head[:Gen]], power.generator.active),
        head[:Qge] => _show(show[head[:Gen]], power.generator.reactive),
        head[:sts] => true
    )
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    buses = getLabel(system.bus.label, label, show, head[:lbB])
    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, head[:lbG])
            fmax(width, show, getLabel(buses, system.generator.layout.bus[i]), head[:lbB])

            fmax(fmt, width, show, i, scale[:P], power.generator.active, head[:Pge])
            fmax(fmt, width, show, i, scale[:Q], power.generator.reactive, head[:Qge])
        else
            fmax(width, show, system.generator.label, head[:lbG])
            fmax(width, show, buses, head[:lbB])

            fminmax(fmt, width, show, scale[:P], power.generator.active, head[:Pge])
            fminmax(fmt, width, show, scale[:Q], power.generator.reactive, head[:Qge])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Generator Data")

    heading = OrderedDict(
        head[:lab] => _blank(width, show, delimiter, style, head, :lab, :lbG, :lbB),
        head[:Gen] => _blank(width, show, delimiter, style, head, :Gen, :Pge, :Qge),
        head[:sts] => _blank(width, show, delimiter, head, :sts)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    return buses, Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function printGeneratorData(
    analysis::DC,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = analysis.system.generator.number + 1,
    kwargs...
)
    system = analysis.system
    gen = system.generator

    scale = scalePrint(system, pfx)
    buses, prt = genData(system, analysis, unitList, scale, label, repeat; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Generator Data")

    @inbounds for (label, i) in pickLabel(gen, gen.label, label, "generator")
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :lbG)

        printf(io, prt, system.generator.layout.bus[i], buses, :lbB)
        printf(io, prt, i, scale[:P], analysis.power.generator.active, :Pge)
        printf(io, prt, i, system.generator.layout.status, :sts)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function genData(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    power = analysis.power
    style, delimiter, key = printkwargs(; kwargs...)

    head = Dict(
        :lab => "Label",
        :lbG => "Label Generator",
        :lbB => "Label Bus",
        :Gen => "Power Output",
        :Pge => "Power Output Active",
        :sts => "Status",
    )
    show = OrderedDict(
        head[:lab] => true,
        head[:Gen] => true
    )

    fmt, width = fmtwidth(show)
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:lbG] => _header("Generator", "Generator Label", style),
        head[:lbB] => _header("Bus", "Bus Label", style),
        head[:Pge] => _header("Active", "Active Power Output", style),
        head[:sts] => _header("", head[:sts], style),
    )
    unit = Dict(
        head[:lbG] => "",
        head[:lbB] => "",
        head[:Pge] => "[" * unitList.activePowerLive * "]",
        head[:sts] => ""
    )
    fmt = Dict(
        head[:lbG] => _fmt(fmt[head[:lab]]; format = "%-*s"),
        head[:lbB] => _fmt(fmt[head[:lab]]; format = "%-*s"),
        head[:Pge] => _fmt(fmt[head[:Gen]]),
        head[:sts] => "%*i"
    )
    width = Dict(
        head[:lbG] => _width(width[head[:lab]], 9, style),
        head[:lbB] => _width(width[head[:lab]], 3, style),
        head[:Pge] => _width(width[head[:Gen]], 12, style),
        head[:sts] => 6 * style
    )
    show = OrderedDict(
        head[:lbG] => _show(show[head[:lab]], true),
        head[:lbB] => _show(show[head[:lab]], true),
        head[:Pge] => _show(show[head[:Gen]], power.generator.active),
        head[:sts] => true
    )
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    buses = getLabel(system.bus.label, label, show, head[:lbB])
    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            fmax(width, show, label, head[:lbG])
            fmax(width, show, getLabel(buses, system.generator.layout.bus[i]), head[:lbB])

            fmax(fmt, width, show, i, scale[:P], power.generator.active, head[:Pge])
        else
            fmax(width, show, system.generator.label, head[:lbG])
            fmax(width, show, buses, head[:lbB])

            fminmax(fmt, width, show, scale[:P], power.generator.active, head[:Pge])
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)
    notprint = printing!(width, show, title, style, "Generator Data")

    heading = OrderedDict(
        head[:lab] => _blank(width, show, delimiter, style, head, :lab, :lbG, :lbB),
        head[:Gen] => _blank(width, show, delimiter, head, :Pge),
        head[:sts] => _blank(width, show, delimiter, head, :sts)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    return buses, Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

"""
    printBusSummary(analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style)

The function prints a summary of the electrical quantities related to buses. Optionally, an `IO` may
be passed as the last argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

show = Dict("In-Use" => false)

printBusSummary(analysis; show, delimiter = " ", title = false)
```
"""
function printBusSummary(
    analysis::Union{AC, DC},
    io::IO = stdout;
    kwargs...
)
    system = analysis.system
    errorVoltage(analysis.voltage.angle)

    scale = scalePrint(system, pfx)
    smr = busSummary(system, analysis, unitList, pfx, scale)
    prt = summaryData(smr, "Bus Summary"; kwargs...)

    if prt.notprint
        return
    end

    title(io, prt, "Bus Summary")
    header(io, prt, smr)
    summaryPrint(io, prt, smr)
end

function busSummary(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
)
    voltage = analysis.voltage
    power = analysis.power
    currinj = analysis.current.injection
    bus = system.bus
    smr = summary()

    V = " Magnitude [" * unitList.voltageMagnitudeLive * "]"
    θ = " Angle [" * unitList.voltageAngleLive * "]"
    P = " Active [" * unitList.activePowerLive * "]"
    Q = " Reactive [" * unitList.reactivePowerLive * "]"
    I = " Magnitude [" * unitList.currentMagnitudeLive * "]"
    ψ = " Angle [" * unitList.currentAngleLive * "]"

    if !isempty(voltage.magnitude)
        smr.type["Voltage"] = "Voltage"
        smr.type["Voltage Magnitude"] = V
        smr.type["Voltage Angle"] = θ
    end
    if !isempty(power.supply.active)
        smr.type["Power Generation"] = "Power Generation"
        smr.type["Power Generation Active"] = P
        smr.type["Power Generation Reactive"] = Q
    end
    if !isempty(power.supply.active)
        smr.type["Power Demand"] = "Power Demand"
        smr.type["Power Demand Active"] = P
        smr.type["Power Demand Reactive"] = Q
    end
    if !isempty(power.injection.active)
        smr.type["Power Injection"] = "Power Injection"
        smr.type["Power Injection Active"] = P
        smr.type["Power Injection Reactive"] = Q
    end
    if !isempty(power.shunt.active)
        smr.type["Shunt Power"] = "Shunt Power"
        smr.type["Shunt Power Active"] = P
        smr.type["Shunt Power Reactive"] = Q
    end
    if !isempty(currinj.magnitude)
        smr.type["Current Injection"] = "Current Injection"
        smr.type["Current Injection Magnitude"] = I
        smr.type["Current Injection Angle"] = ψ
    end

    smr.inuse["Voltage"] = bus.number
    smr.inuse["Power Generation"] = 0.0
    smr.inuse["Power Demand"] = 0.0
    smr.inuse["Power Injection"] = bus.number
    smr.inuse["Shunt Power"] = 0.0
    smr.inuse["Current Injection"] = bus.number

    smr.total["Power Generation Active"] = 0.0
    smr.total["Power Generation Reactive"] = 0.0
    smr.total["Power Demand Active"] = 0.0
    smr.total["Power Demand Reactive"] = 0.0
    smr.total["Power Injection Active"] = 0.0
    smr.total["Power Injection Reactive"] = 0.0
    smr.total["Shunt Power Active"] = 0.0
    smr.total["Shunt Power Reactive"] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:bus.number
        scaleVolg = scaleVoltage(pfx, system, i)
        evaldata(smr, i, scaleVolg, voltage.magnitude[i], "Voltage Magnitude")
        evaldata(smr, i, scale[:θ], voltage.angle[i], "Voltage Angle")

        if haskey(bus.supply.generator, i)
            if haskey(smr.type, "Power Generation")
                smr.inuse["Power Generation"] += 1
                evaldata(smr, i, scale[:P], power.supply.active[i], "Power Generation Active")
                evaldata(smr, i, scale[:Q], power.supply.reactive[i], "Power Generation Reactive")
            end
        end

        if bus.demand.active[i] != 0.0 || bus.demand.reactive[i] != 0.0
            if haskey(smr.type, "Power Demand")
                smr.inuse["Power Demand"] += 1
                evaldata(smr, i, scale[:P], bus.demand.active[i], "Power Demand Active")
                evaldata(smr, i, scale[:Q], bus.demand.reactive[i], "Power Demand Reactive")
            end
        end

        if haskey(smr.type, "Power Injection")
            evaldata(smr, i, scale[:P], power.injection.active[i], "Power Injection Active")
            evaldata(smr, i, scale[:Q], power.injection.reactive[i], "Power Injection Reactive")
        end

        if bus.shunt.conductance[i] != 0.0 || bus.shunt.susceptance[i] != 0.0
            if haskey(smr.type, "Shunt Power")
                smr.inuse["Shunt Power"] += 1
                evaldata(smr, i, scale[:P], power.shunt.active[i], "Shunt Power Active")
                evaldata(smr, i, scale[:Q], power.shunt.reactive[i], "Shunt Power Reactive")
            end
        end

        if haskey(smr.type, "Current Injection")
            scaleCurt = scaleCurrent(pfx, system, i)
            evaldata(smr, i, scaleCurt, currinj.magnitude[i], "Current Injection Magnitude")
            evaldata(smr, i, scale[:ψ], currinj.angle[i], "Current Injection Angle")
        end
    end
    notexist!(smr)
    addlabel!(smr, bus.label)

   return smr
end

function busSummary(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    ::PrefixLive,
    scale::Dict{Symbol, Float64},
)
    voltage = analysis.voltage
    power = analysis.power
    bus = system.bus
    smr = summary()

    θ = " Angle [" * unitList.voltageAngleLive * "]"
    P = " Active [" * unitList.activePowerLive * "]"

    if !isempty(voltage.angle)
        smr.type["Voltage"] = "Voltage"
        smr.type["Voltage Angle"] = θ
    end
    if !isempty(power.supply.active)
        smr.type["Power Generation"] = "Power Generation"
        smr.type["Power Generation Active"] = P
    end
    if !isempty(power.supply.active)
        smr.type["Power Demand"] = "Power Demand"
        smr.type["Power Demand Active"] = P
    end
    if !isempty(power.injection.active)
        smr.type["Power Injection"] = "Power Injection"
        smr.type["Power Injection Active"] = P
    end

    smr.inuse["Voltage"] = bus.number
    smr.inuse["Power Generation"] = 0.0
    smr.inuse["Power Demand"] = 0.0
    smr.inuse["Power Injection"] = bus.number

    smr.total["Power Generation Active"] = 0.0
    smr.total["Power Demand Active"] = 0.0
    smr.total["Power Injection Active"] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:bus.number
        evaldata(smr, i, scale[:θ], voltage.angle[i], "Voltage Angle")

        if haskey(bus.supply.generator, i)
            if haskey(smr.type, "Power Generation")
                smr.inuse["Power Generation"] += 1
                evaldata(smr, i, scale[:P], power.supply.active[i], "Power Generation Active")
            end
        end

        if bus.demand.active[i] != 0.0
            if haskey(smr.type, "Power Demand")
                smr.inuse["Power Demand"] += 1
                evaldata(smr, i, scale[:P], bus.demand.active[i], "Power Demand Active")
            end
        end

        if haskey(smr.type, "Power Injection")
            evaldata(smr, i, scale[:P], power.injection.active[i], "Power Injection Active")
        end
    end
    notexist!(smr)
    addlabel!(smr, bus.label)
    smr.block = 2

    return smr
end

"""
    printBranchSummary(analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style))

The function prints a summary of the electrical quantities related to branches. Optionally, an `IO`
may be passed as the last argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

show = Dict("Total" => false)

printBranchSummary(analysis; show, delimiter = " ", title = false)
```
"""
function printBranchSummary(
    analysis::Union{AC, DC},
    io::IO = stdout;
    kwargs...
)
    system = analysis.system
    errorVoltage(analysis.voltage.angle)


    scale = scalePrint(system, pfx)
    smr = branchSummary(system, analysis, unitList, pfx, scale)
    prt = summaryData(smr, "Branch Summary"; kwargs...)

    if prt.notprint && isempty(smr.type)
        return
    end

    title(io, prt, "Branch Summary")
    header(io, prt, smr)
    summaryPrint(io, prt, smr)
end

function branchSummary(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    pfx::PrefixLive,
    scale::Dict{Symbol, Float64},
)
    power = analysis.power
    current = analysis.current
    branch = system.branch
    smr = summary()

    P = " Active [" * unitList.activePowerLive * "]"
    Q = " Reactive [" * unitList.reactivePowerLive * "]"
    I = " Magnitude [" * unitList.currentMagnitudeLive * "]"
    ψ = " Angle [" * unitList.currentAngleLive * "]"

    head = Dict(
        :Sijl => "Line From-Bus Power Flow Magnitude",
        :Pijl => "Line From-Bus Power Flow Magnitude Active",
        :Qijl => "Line From-Bus Power Flow Magnitude Reactive",
        :Sijt => "Transformer From-Bus Power Flow Magnitude",
        :Pijt => "Transformer From-Bus Power Flow Magnitude Active",
        :Qijt => "Transformer From-Bus Power Flow Magnitude Reactive",
        :Sjil => "Line To-Bus Power Flow Magnitude",
        :Pjil => "Line To-Bus Power Flow Magnitude Active",
        :Qjil => "Line To-Bus Power Flow Magnitude Reactive",
        :Sjit => "Transformer To-Bus Power Flow Magnitude",
        :Pjit => "Transformer To-Bus Power Flow Magnitude Active",
        :Qjit => "Transformer To-Bus Power Flow Magnitude Reactive",
        :Sshu => "Shunt Power",
        :Pshu => "Shunt Power Active",
        :Qshu => "Shunt Power Reactive",
        :Sser => "Series Power",
        :Pser => "Series Power Active",
        :Qser => "Series Power Reactive",
    )

    if !isempty(power.from.active)
        smr.type[head[:Sijl]] = head[:Sijl]
        smr.type[head[:Pijl]] = P
        smr.type[head[:Qijl]] = Q
    end
    if !isempty(power.from.active)
        smr.type[head[:Sijt]] = head[:Sijt]
        smr.type[head[:Pijt]] = P
        smr.type[head[:Qijt]] = Q
    end
    if !isempty(power.to.active)
        smr.type[head[:Sjil]] = head[:Sjil]
        smr.type[head[:Pjil]] = P
        smr.type[head[:Qjil]] = Q
    end
    if !isempty(power.to.active)
        smr.type[head[:Sjit]] = head[:Sjit]
        smr.type[head[:Pjit]] = P
        smr.type[head[:Qjit]] = Q
    end
    if !isempty(power.charging.active)
        smr.type[head[:Sshu]] = head[:Sshu]
        smr.type[head[:Pshu]] = P
        smr.type[head[:Qshu]] = Q
    end
    if !isempty(power.series.active)
        smr.type[head[:Sser]] = head[:Sser]
        smr.type[head[:Pser]] = P
        smr.type[head[:Qser]] = Q
    end
    if !isempty(current.from.magnitude)
        smr.type["From-Bus Current"] = "From-Bus Current"
        smr.type["From-Bus Current Magnitude"] = I
        smr.type["From-Bus Current Angle"] = ψ
    end
    if !isempty(current.to.magnitude)
        smr.type["To-Bus Current"] = "To-Bus Current"
        smr.type["To-Bus Current Magnitude"] = I
        smr.type["To-Bus Current Angle"] = ψ
    end
    if !isempty(current.series.magnitude)
        smr.type["Series Current"] = "Series Current"
        smr.type["Series Current Magnitude"] = I
        smr.type["Series Current Angle"] = ψ
    end

    smr.inuse[head[:Sijl]] = 0
    smr.inuse[head[:Sijt]] = 0
    smr.inuse[head[:Sjil]] = 0
    smr.inuse[head[:Sjit]] = 0
    smr.inuse[head[:Sshu]] = 0.0
    smr.inuse[head[:Sser]] = branch.layout.inservice
    smr.inuse["From-Bus Current"] = branch.layout.inservice
    smr.inuse["To-Bus Current"] = branch.layout.inservice
    smr.inuse["Series Current"] = branch.layout.inservice

    smr.total[head[:Pshu]] = 0.0
    smr.total[head[:Qshu]] = 0.0
    smr.total[head[:Pser]] = 0.0
    smr.total[head[:Qser]] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] != 1
            continue
        end

        if haskey(smr.type, head[:Sijl])
            if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                smr.inuse[head[:Sijl]] += 1
                evaldata(smr, i, scale[:P], abs(power.from.active[i]), head[:Pijl])
                evaldata(smr, i, scale[:Q], abs(power.from.reactive[i]), head[:Qijl])
            else
                smr.inuse[head[:Sijt]] += 1
                evaldata(smr, i, scale[:P], abs(power.from.active[i]), head[:Pijt])
                evaldata(smr, i, scale[:Q], abs(power.from.reactive[i]), head[:Qijt])
            end
        end

        if haskey(smr.type, head[:Sjil])
            if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                smr.inuse[head[:Sjil]] += 1
                evaldata(smr, i, scale[:P], abs(power.to.active[i]), head[:Pjil])
                evaldata(smr, i, scale[:Q], abs(power.to.reactive[i]), head[:Qjil])
            else
                smr.inuse[head[:Sjit]] += 1
                evaldata(smr, i, scale[:P], abs(power.to.active[i]), head[:Pjit])
                evaldata(smr, i, scale[:Q], abs(power.to.reactive[i]), head[:Qjit])
            end
        end

        if haskey(smr.type, head[:Sshu])
            if branch.parameter.conductance[i] != 0.0 || branch.parameter.susceptance[i] != 0.0
                smr.inuse[head[:Sshu]] += 1
                evaldata(smr, i, scale[:P], power.charging.active[i], head[:Pshu])
                evaldata(smr, i, scale[:Q], power.charging.reactive[i], head[:Qshu])
            end
        end

        if haskey(smr.type, head[:Sser])
            evaldata(smr, i, scale[:P], power.series.active[i], head[:Pser])
            evaldata(smr, i, scale[:Q], power.series.reactive[i], head[:Qser])
        end

        if haskey(smr.type, "From-Bus Current")
            scaleCurrf = scaleCurrent(pfx, system, branch.layout.from[i])
            evaldata(smr, i, scaleCurrf, current.from.magnitude[i], "From-Bus Current Magnitude")
            evaldata(smr, i, scale[:ψ], current.from.angle[i], "From-Bus Current Angle")
        end

        if haskey(smr.type, "To-Bus Current")
            scaleCurrt = scaleCurrent(pfx, system, branch.layout.to[i])
            evaldata(smr, i, scaleCurrt, current.to.magnitude[i], "To-Bus Current Magnitude")
            evaldata(smr, i, scale[:ψ], current.to.angle[i], "To-Bus Current Angle")
        end

        if haskey(smr.type, "Series Current")
            scaleCurrt = scaleCurrent(pfx, system, branch.layout.to[i])
            evaldata(smr, i, scaleCurrt, current.series.magnitude[i], "Series Current Magnitude")
            evaldata(smr, i, scale[:ψ], current.series.angle[i], "Series Current Angle")
        end
    end
    notexist!(smr)
    addlabel!(smr, branch.label)

   return smr
end

function branchSummary(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    ::PrefixLive,
    scale::Dict{Symbol, Float64},
)
    power = analysis.power
    branch = system.branch
    smr = summary()

    P = " Active [" * unitList.activePowerLive * "]"

    head = Dict(
        :Sijl => "Line Power Flow Magnitude",
        :Pijl => "Line Power Flow Magnitude Active",
        :Sijt => "Transformer Power Flow Magnitude",
        :Pijt => "Transformer Power Flow Magnitude Active",
    )

    if !isempty(power.from.active)
        smr.type[head[:Sijl]] = head[:Sijl]
        smr.type[head[:Pijl]] = P
    end
    if !isempty(power.from.active)
        smr.type[head[:Sijt]] = head[:Sijt]
        smr.type[head[:Pijt]] = P
    end

    smr.inuse[head[:Sijl]] = 0.0
    smr.inuse[head[:Sijt]] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:branch.number
        if branch.layout.status[i] != 1
            continue
        end

        if haskey(smr.type, head[:Sijl])
            if branch.parameter.turnsRatio[i] == 1 && branch.parameter.shiftAngle[i] == 0
                smr.inuse[head[:Sijl]] += 1
                evaldata(smr, i, scale[:P], abs(power.from.active[i]), head[:Pijl])
            else
                smr.inuse[head[:Sijt]] += 1
                evaldata(smr, i, scale[:P], abs(power.from.active[i]), head[:Pijt])
            end
        end

    end
    notexist!(smr)
    addlabel!(smr, branch.label)
    smr.block = 2

   return smr
end

"""
    printGeneratorSummary(analysis::Analysis, [io::IO];
        fmt, width, show, delimiter, title, header, footer, style)

The function prints a summary of the electrical quantities related to generators. Optionally, an `IO`
may be passed as the last argument to redirect the output.

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
    The function requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = newtonRaphson(system)
powerFlow!(analysis; power = true)

show = Dict("Minimum" => false)

printGeneratorSummary(analysis; show, delimiter = " ", title = false)
```
"""
function printGeneratorSummary(analysis::Union{AC, DC}, io::IO = stdout; kwargs...)
    system = analysis.system
    errorVoltage(analysis.voltage.angle)

    scale = scalePrint(system, pfx)
    smr = generatorSummary(system, analysis, unitList, scale)
    prt = summaryData(smr, "Generator Summary"; kwargs...)

    if prt.notprint && isempty(smr.type)
        return
    end

    title(io, prt, "Generator Summary")
    header(io, prt, smr)
    summaryPrint(io, prt, smr)
end

function generatorSummary(
    system::PowerSystem,
    analysis::AC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
)
    power = analysis.power
    generator = system.generator
    smr = summary()

    P = " Active [" * unitList.activePowerLive * "]"
    Q = " Reactive [" * unitList.reactivePowerLive * "]"

    if !isempty(power.generator.active)
        smr.type["Power Output"] = "Power Output"
        smr.type["Power Output Active"] = P
        smr.type["Power Output Reactive"] = Q
    end

    smr.inuse["Power Output"] = generator.layout.inservice
    smr.total["Power Output Active"] = 0.0
    smr.total["Power Output Reactive"] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 && haskey(smr.type, "Power Output")
            evaldata(smr, i, scale[:P], power.generator.active[i], "Power Output Active")
            evaldata(smr, i, scale[:Q], power.generator.reactive[i], "Power Output Reactive")
        end
    end
    notexist!(smr)
    addlabel!(smr, generator.label)

   return smr
end

function generatorSummary(
    system::PowerSystem,
    analysis::DC,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
)
    power = analysis.power
    generator = system.generator
    smr = summary()

    P = " Active [" * unitList.activePowerLive * "]"

    if !isempty(power.generator.active)
        smr.type["Power Output"] = "Power Output"
        smr.type["Power Output Active"] = P
    end

    smr.inuse["Power Output"] = generator.layout.inservice
    smr.total["Power Output Active"] = 0.0

    evaluate!(smr)

    @inbounds for i = 1:generator.number
        if generator.layout.status[i] == 1 && haskey(smr.type, "Power Output")
            evaldata(smr, i, scale[:P], power.generator.active[i], "Power Output Active")
        end
    end
    notexist!(smr)
    addlabel!(smr, generator.label)
    smr.block = 2

   return smr
end

function summaryData(smr::Summary, title::String; kwargs...)
    style, delimiter, key = summarykwargs(; kwargs...)

    head = Dict(
        :min => "Minimum",
        :max => "Maximum",
        :typ => "Type",
        :inu => "In-Use",
        :mnL => "Minimum Label",
        :mnV => "Minimum Value",
        :mxL => "Maximum Label",
        :mxV => "Maximum Value",
        :tot => "Total",
    )
    show = OrderedDict(
        head[:min] => true,
        head[:max] => true,
    )
    _, width = fmtwidth(show)
    temp = Dict{String, String}()
    transfer!(temp, temp, width, key.width, show, key.show, style)

    subheading = Dict(
        head[:typ] => _header("", head[:typ], style),
        head[:inu] => _header("", head[:inu], style),
        head[:mnL] => _header("Label", "Label", style),
        head[:mnV] => _header("Value", head[:min], style),
        head[:mxL] => _header("Label", "Label", style),
        head[:mxV] => _header("Value", head[:max], style),
        head[:tot] => _header("", head[:tot], style),
    )
    fmt = Dict(
        head[:typ] => "%-*s",
        head[:inu] => "%*i",
        head[:mnL] => "%-*s",
        head[:mnV] => "%*.4f",
        head[:mxL] => "%-*s",
        head[:mxV] => "%*.4f",
        head[:tot] => "%*.4f",
    )
    width = Dict(
        head[:typ] => 4 * style,
        head[:inu] => 6 * style,
        head[:mnL] => _width(width[head[:min]], 5, style),
        head[:mnV] => _width(width[head[:min]], 5, style),
        head[:mxL] => _width(width[head[:max]], 5, style),
        head[:mxV] => _width(width[head[:max]], 5, style),
        head[:tot] => 5 * style,
    )
    show = OrderedDict(
        head[:typ] => true,
        head[:mnL] => _show(show[head[:min]], true),
        head[:mnV] => _show(show[head[:min]], true),
        head[:mxL] => _show(show[head[:max]], true),
        head[:mxV] => _show(show[head[:max]], true),
        head[:inu] => true,
        head[:tot] => true,
    )
    transfer!(fmt, key.fmt, width, key.width, show, key.show, style)

    if style
        for (key, caption) in smr.type
            fmax(width, show, caption, head[:typ])

            if haskey(smr.minlbl, key)
                fmax(width, show, smr.minlbl[key], head[:mnL])
                fmax(fmt, width, show, smr.minval[key], head[:mnV])
            end

            if haskey(smr.maxlbl, key)
                fmax(width, show, smr.maxlbl[key], head[:mxL])
                fmax(fmt, width, show, smr.maxval[key], head[:mxV])
            end

            if haskey(smr.inuse, key)
                fmax(fmt, width, show, smr.inuse[key], head[:inu])
            end

            if haskey(smr.total, key)
                fmax(fmt, width, show, smr.total[key], head[:tot])
            end
        end
    end

    notprint = printing!(width, show, key.title, style, title)

    heading = OrderedDict(
        head[:typ] => _blank(width, show, delimiter, head, :typ),
        head[:min] => _blank(width, show, delimiter, style, head, :min, :mnL, :mnV),
        head[:max] => _blank(width, show, delimiter, style, head, :max, :mxL, :mxV),
        head[:inu] => _blank(width, show, delimiter, head, :inu),
        head[:tot] => _blank(width, show, delimiter, head, :tot)
    )

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    unit = Dict{String, String}()

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        key.title, key.header, key.footer, 0, notprint, line, 1
    )
end

function summaryPrint(io::IO, prt::Print, smr::Summary)
    @inbounds for (key, caption) in smr.type
        if (prt.cnt - 1) % smr.block == 0 && prt.cnt != 1
            printf(io, prt)
        end

        printf(io, prt.pfmt, prt, caption, :typ)

        if haskey(smr.minlbl, key)
            printf(io, prt.pfmt, prt, smr.minlbl[key], :mnL)
            printf(io, prt, smr.minval[key], :mnV)
        else
            printf(io, prt.hfmt, prt, "", :mnL)
            printf(io, prt.hfmt, prt, "", :mnV)
        end

        if haskey(smr.maxlbl, key)
            printf(io, prt.pfmt, prt, smr.maxlbl[key], :mxL)
            printf(io, prt, smr.maxval[key], :mxV)
        else
            printf(io, prt.hfmt, prt, "", :mxL)
            printf(io, prt.hfmt, prt, "", :mxV)
        end

        if haskey(smr.inuse, key)
            printf(io, prt, smr.inuse[key], :inu)
        else
            printf(io, prt.hfmt, prt, "", :inu)
        end

        if haskey(smr.total, key)
            printf(io, prt, smr.total[key], :tot)
        else
            printf(io, prt.hfmt, prt, "", :tot)
        end

        @printf io "\n"
        prt.cnt += 1
    end
    printf(io, prt.footer, prt)
end

function summary()
    Summary(
        OrderedDict{String, String}(),
        Dict{String, Int64}(),
        Dict{String, Float64}(),
        Dict{String, String}(),
        Dict{String, Int64}(),
        Dict{String, Float64}(),
        Dict{String, String}(),
        Dict{String, Float64}(),
        Dict{String, Float64}(),
        3
    )
end

function evaluate!(smr::Summary)
    for (key, value) in smr.type
        if value[1] == ' '
            smr.minidx[key] = 0
            smr.minval[key] = Inf
            smr.minlbl[key] = ""

            smr.maxidx[key] = 0
            smr.maxval[key] = -Inf
            smr.maxlbl[key] = ""
        end
    end
end

function evaldata(smr::Summary, i::Int64, scale::Float64, value::Float64, key::String)
    value *= scale

    if value < smr.minval[key]
        smr.minidx[key] = i
        smr.minval[key] = value
    end

    if value > smr.maxval[key]
        smr.maxidx[key] = i
        smr.maxval[key] = value
    end

    if haskey(smr.total, key)
        smr.total[key] += value
    end
end

function notexist!(smr::Summary)
    for (key, value) in smr.inuse
        if value == 0
            for label in keys(smr.type)
                if occursin(key, label)
                    delete!(smr.type, label)
                end
            end
        end
    end
end

function addlabel!(smr::Summary, label::LabelDict)
    for (key, index) in smr.minidx
        if index != 0
            smr.minlbl[key] = string(getLabel(label, index))
        end
    end
    for (key, index) in smr.maxidx
        if index != 0
            smr.maxlbl[key] = string(getLabel(label, index))
        end
    end
end