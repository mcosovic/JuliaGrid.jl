"""
    printBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints constraint data related to buses. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBusConstraint`](@ref printBusConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all buses
fmt = Dict("Active Power Balance Solution" => "%.2e")
show = Dict("Voltage Magnitude Minimum" => false)
printBusConstraint(system, analysis; fmt, show)

# Print data for specific buses
delimiter = " "
width = Dict("Voltage Magnitude Dual" => 8)
printBusConstraint(system, analysis; label = 2, delimiter, width, header = true)
printBusConstraint(system, analysis; label = 10, delimiter, width)
printBusConstraint(system, analysis; label = 14, delimiter, width, footer = true)
```
"""
function printBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBusConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.bus, system.bus.label, header, footer, "bus")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header
        if style
            printTitle(io, maxLine, delimiter, "Bus Constraint Data")

            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            span = printf(io, width, show, delimiter, "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Maximum", "Voltage Magnitude Dual", "Voltage Magnitude")
            fmtAct = printf(io, width, show, delimiter, "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance")
            fmtRea = printf(io, width, show, delimiter, "Reactive Power Balance Solution", "Reactive Power Balance Dual", "Reactive Power Balance")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, span)
            printf(io, fmtAct[1], width, show, "Active Power Balance Solution", "", "Active Power Balance Dual", "")
            printf(io, fmtRea[1], width, show, "Reactive Power Balance Solution", "", "Reactive Power Balance Dual", "")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Magnitude Minimum", "Minimum")
            printf(io, fmt, width, show, "Voltage Magnitude Solution", "Solution")
            printf(io, fmt, width, show, "Voltage Magnitude Maximum", "Maximum")
            printf(io, fmt, width, show, "Voltage Magnitude Dual", "Dual")
            printf(io, fmtAct[2], width, show, "Active Power Balance Solution", "Solution", "Active Power Balance Dual", "Dual")
            printf(io, fmtRea[2], width, show, "Reactive Power Balance Solution", "Solution", "Reactive Power Balance Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Magnitude Minimum", unitData["V"])
            printf(io, fmt, width, show, "Voltage Magnitude Solution", unitData["V"])
            printf(io, fmt, width, show, "Voltage Magnitude Maximum", unitData["V"])
            printf(io, fmt, width, show, "Voltage Magnitude Dual", "[\$/$(unitList.voltageMagnitudeLive)-hr]")
            printf(io, fmtAct[2], width, show, "Active Power Balance Solution", unitData["P"], "Active Power Balance Dual", "[\$/$(unitList.activePowerLive)-hr]")
            printf(io, fmtRea[2], width, show, "Reactive Power Balance Solution", unitData["Q"], "Reactive Power Balance Dual", "[\$/$(unitList.reactivePowerLive)-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmt, width, show, "Voltage Magnitude Minimum", "-"^width["Voltage Magnitude Minimum"])
            printf(io, fmt, width, show, "Voltage Magnitude Solution", "-"^width["Voltage Magnitude Solution"])
            printf(io, fmt, width, show, "Voltage Magnitude Maximum", "-"^width["Voltage Magnitude Maximum"])
            printf(io, fmt, width, show, "Voltage Magnitude Dual", "-"^width["Voltage Magnitude Dual"])
            printf(io, fmtAct[3], width, show, "Active Power Balance Solution", "-"^width["Active Power Balance Solution"], "Active Power Balance Dual", "-"^width["Active Power Balance Dual"])
            printf(io, fmtRea[3], width, show, "Reactive Power Balance Solution", "-"^width["Reactive Power Balance Solution"], "Reactive Power Balance Dual", "-"^width["Reactive Power Balance Dual"])
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Voltage Magnitude Minimum", "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Solution")
            printf(io, show, delimiter, "Voltage Magnitude Maximum", "Voltage Magnitude Maximum", "Voltage Magnitude Dual", "Voltage Magnitude Dual")
            printf(io, show, delimiter, "Active Power Balance Solution", "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance Dual")
            printf(io, show, delimiter, "Reactive Power Balance Solution", "Reactive Power Balance Solution", "Reactive Power Balance Dual", "Reactive Power Balance Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Voltage Magnitude Minimum", unitData["V"], "Voltage Magnitude Solution", unitData["V"])
            printf(io, show, delimiter, "Voltage Magnitude Maximum", unitData["V"], "Voltage Magnitude Dual", "[\$/$(unitList.voltageMagnitudeLive)-hr]")
            printf(io, show, delimiter, "Active Power Balance Solution", unitData["P"], "Active Power Balance Dual", "[\$/$(unitList.activePowerLive)-hr]")
            printf(io, show, delimiter, "Reactive Power Balance Solution", unitData["P"], "Reactive Power Balance Dual", "[\$/$(unitList.reactivePowerLive)-hr]")
        end
        @printf io "\n"
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        if haskey(constraint.voltage.magnitude, i) && is_valid(analysis.method.jump, constraint.voltage.magnitude[i])
            printf(io, pfmt, show, width, system.bus.voltage.minMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Minimum")
            printf(io, pfmt, show, width, analysis.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Solution")
            printf(io, pfmt, show, width, system.bus.voltage.maxMagnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Maximum")
            printf(io, pfmt, show, width, dual.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), "Voltage Magnitude Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Voltage Magnitude Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Magnitude Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Magnitude Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Magnitude Dual", "-")
        end

        if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
            printf(io, pfmt, show, width, constraint.balance.active, i, scale["P"], "Active Power Balance Solution")
            printf(io, pfmt, show, width, dual.balance.active, i, scale["P"], "Active Power Balance Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Active Power Balance Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Balance Dual", "-")
        end

        if haskey(constraint.balance.reactive, i) &&  is_valid(analysis.method.jump, constraint.balance.reactive[i])
            printf(io, pfmt, show, width, constraint.balance.reactive, i, scale["Q"], "Reactive Power Balance Solution")
            printf(io, pfmt, show, width, dual.balance.reactive, i, scale["Q"], "Reactive Power Balance Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Reactive Power Balance Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Reactive Power Balance Dual", "-")
        end

        @printf io "\n"
    end

    if footer && style
        print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    end
end

function formatBusConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Voltage Magnitude Minimum" => 7 * style,
        "Voltage Magnitude Solution" => 8 * style,
        "Voltage Magnitude Maximum" => 7 * style,
        "Voltage Magnitude Dual" => textwidth("[\$/$(unitList.voltageMagnitudeLive)-hr]") * style,
        "Active Power Balance Solution" => 8 * style,
        "Active Power Balance Dual" => textwidth("[\$/$(unitList.activePowerLive)-hr]") * style,
        "Reactive Power Balance Solution" => 8 * style,
        "Reactive Power Balance Dual" => textwidth("[\$/$(unitList.reactivePowerLive)-hr]") * style
    )

    _fmt = Dict(
        "Voltage Magnitude Minimum" => "%*.4f",
        "Voltage Magnitude Solution" => "%*.4f",
        "Voltage Magnitude Maximum" => "%*.4f",
        "Voltage Magnitude Dual" => "%*.4f",
        "Active Power Balance Solution" => "%*.4f",
        "Active Power Balance Dual" => "%*.4f",
        "Reactive Power Balance Solution" => "%*.4f",
        "Reactive Power Balance Dual" => "%*.4f"
    )

    _show = Dict(
        "Voltage Magnitude Minimum" => !isempty(constraint.voltage.magnitude),
        "Voltage Magnitude Solution" => !isempty(constraint.voltage.magnitude),
        "Voltage Magnitude Maximum" => !isempty(constraint.voltage.magnitude),
        "Voltage Magnitude Dual" => !isempty(dual.voltage.magnitude),
        "Active Power Balance Solution" => !isempty(constraint.balance.active),
        "Active Power Balance Dual" => !isempty(dual.balance.active),
        "Reactive Power Balance Solution" => !isempty(constraint.balance.reactive),
        "Reactive Power Balance Dual" => !isempty(dual.balance.reactive)
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            width["Label"] = max(textwidth(label), width["Label"])

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
            maxVmin = initMax(prefix.voltageMagnitude)
            maxVopt = initMax(prefix.voltageMagnitude)
            maxVmax = initMax(prefix.voltageMagnitude)
            minmaxVdual = [-Inf; Inf]
            minmaxPprimal = [-Inf; Inf]
            minmaxPdual = [-Inf; Inf]
            minmaxQprimal = [-Inf; Inf]
            minmaxQdual = [-Inf; Inf]

            @inbounds for (label, i) in system.bus.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.voltage.magnitude, i) && is_valid(analysis.method.jump, constraint.voltage.magnitude[i])
                    minmaxDual(show, dual.voltage.magnitude, i, scaleVoltage(prefix, system.base.voltage, i), minmaxVdual, "Voltage Magnitude Dual")
                end

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    minmaxPrimal(show, constraint.balance.active[i], scale["P"], minmaxPprimal, "Active Power Balance Solution")
                    minmaxDual(show, dual.balance.active, i, scale["P"], minmaxPdual, "Active Power Balance Dual")
                end

                if haskey(constraint.balance.reactive, i) && is_valid(analysis.method.jump, constraint.balance.reactive[i])
                    minmaxPrimal(show, constraint.balance.reactive[i], scale["Q"], minmaxQprimal, "Reactive Power Balance Solution")
                    minmaxDual(show, dual.balance.reactive, i, scale["Q"], minmaxQdual, "Reactive Power Balance Dual")
                end

                if prefix.voltageMagnitude != 0.0
                    maxVmin = max(system.bus.voltage.minMagnitude[i] * scaleVoltage(system.base.voltage, prefix, i), maxVmin)
                    maxVopt = max(voltage.magnitude[i] * scaleVoltage(system.base.voltage, prefix, i), maxVopt)
                    maxVmax = max(system.bus.voltage.maxMagnitude[i] * scaleVoltage(system.base.voltage, prefix, i), maxVmax)
                end
            end

            if prefix.voltageMagnitude == 0.0
                fmax(fmt, width, show, system.bus.voltage.minMagnitude, 1.0, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, voltage.magnitude, 1.0, "Voltage Magnitude Solution")
                fmax(fmt, width, show, system.bus.voltage.minMagnitude, 1.0, "Voltage Magnitude Maximum")
            else
                fmax(fmt, width, show, maxVmin, "Voltage Magnitude Minimum")
                fmax(fmt, width, show, maxVopt, "Voltage Magnitude Solution")
                fmax(fmt, width, show, maxVmax, "Voltage Magnitude Maximum")
            end
            fminmax(fmt, width, show, minmaxVdual, 1.0, "Voltage Magnitude Dual")

            fminmax(fmt, width, show, minmaxPprimal, 1.0, "Active Power Balance Solution")
            fminmax(fmt, width, show, minmaxPdual, 1.0, "Active Power Balance Dual")

            fminmax(fmt, width, show, minmaxQprimal, 1.0, "Reactive Power Balance Solution")
            fminmax(fmt, width, show, minmaxQdual, 1.0, "Reactive Power Balance Dual")
        end

        hasMorePrint(width, show, "Bus Constraint Data")
        titlemax(width, show, "Voltage Magnitude Minimum", "Voltage Magnitude Solution", "Voltage Magnitude Maximum", "Voltage Magnitude Dual", "Voltage Magnitude")
        titlemax(width, show, "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance")
        titlemax(width, show, "Reactive Power Balance Solution", "Reactive Power Balance Dual", "Reactive Power Balance")
    end

    return fmt, width, show
end

function printBusConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBusConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.bus, system.bus.label, header, footer, "bus")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header
        if style
            printTitle(io, maxLine, delimiter, "Bus Constraint Data")

            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            fmtAct = printf(io, width, show, delimiter, "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmtAct[1], width, show, "Active Power Balance Solution", "", "Active Power Balance Dual", "")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmtAct[2], width, show, "Active Power Balance Solution", "Solution", "Active Power Balance Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmtAct[2], width, show, "Active Power Balance Solution", unitData["P"], "Active Power Balance Dual", "[\$/$(unitList.activePowerLive)-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmtAct[3], width, show, "Active Power Balance Solution", "-"^width["Active Power Balance Solution"], "Active Power Balance Dual", "-"^width["Active Power Balance Dual"])
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Active Power Balance Solution", "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Active Power Balance Solution", unitData["P"], "Active Power Balance Dual", "[\$/$(unitList.activePowerLive)-hr]")
        end
        @printf io "\n"
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
            printf(io, pfmt, show, width, constraint.balance.active, i, scale["P"], "Active Power Balance Solution")
            printf(io, pfmt, show, width, dual.balance.active, i, scale["P"], "Active Power Balance Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Active Power Balance Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Balance Dual", "-")
        end

        @printf io "\n"
    end

    if footer && style
        print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    end
end

function formatBusConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Active Power Balance Solution" => 8 * style,
        "Active Power Balance Dual" => textwidth("[\$/$(unitList.activePowerLive)-hr]") * style,
    )

    _fmt = Dict(
        "Active Power Balance Solution" => "%*.4f",
        "Active Power Balance Dual" => "%*.4f",
    )

    _show = Dict(
        "Active Power Balance Solution" => !isempty(constraint.balance.active),
        "Active Power Balance Dual" => !isempty(dual.balance.active),
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.bus, label, "bus")
            i = system.bus.label[label]

            width["Label"] = max(textwidth(label), width["Label"])

            if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                fmax(fmt, width, show, value(constraint.balance.active[i]) * scale["P"], "Active Power Balance Solution")
                if haskey(dual.balance.active, i)
                    fmax(fmt, width, show, dual.balance.active[i] / scale["P"], "Active Power Balance Dual")
                end
            end
        else
            minmaxPprimal = [-Inf; Inf]
            minmaxPdual = [-Inf; Inf]

            @inbounds for (label, i) in system.bus.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.balance.active, i) && is_valid(analysis.method.jump, constraint.balance.active[i])
                    minmaxPrimal(show, constraint.balance.active[i], scale["P"], minmaxPprimal, "Active Power Balance Solution")
                    minmaxDual(show, dual.balance.active, i, scale["P"], minmaxPdual, "Active Power Balance Dual")
                end
            end

            fminmax(fmt, width, show, minmaxPprimal, 1.0, "Active Power Balance Solution")
            fminmax(fmt, width, show, minmaxPdual, 1.0, "Active Power Balance Dual")

        end

        hasMorePrint(width, show, "Bus Constraint Data")
        titlemax(width, show, "Active Power Balance Solution", "Active Power Balance Dual", "Active Power Balance")
    end

    return fmt, width, show
end

"""
    printBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints constraint data related to branches. Optionally, an `IO` may be passed as
the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printBranchConstraint`](@ref printBranchConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
updateBranch!(system; label = 4, maxFromBus = 0.4, maxToBus = 0.5)
updateBranch!(system; label = 9, minFromBus = 0.1, maxFromBus = 0.3)

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all branches
fmt = Dict("From-Bus Flow Dual" => "%.2f")
show = Dict("To-Bus Flow Minimum" => false)
printBranchConstraint(system, analysis; fmt, show)

# Print data for specific branches
delimiter = " "
width = Dict("From-Bus Flow Dual" => 11)
printBranchConstraint(system, analysis; label = 4, delimiter, width, header = true)
printBranchConstraint(system, analysis; label = 9, delimiter, width, footer = true)
```
"""
function printBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show, typeFlow = formatBranchConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.branch, system.branch.label, header, footer, "branch")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header && style
        printTitle(io, maxLine, delimiter, "Branch Constraint Data")
    end

    for (key, value) in typeFlow
        if value == 1
            scaleFlowFrom = scale["S"]
            scaleFlowTo = scale["S"]
            unitFlow = unitList.apparentPowerLive
        elseif value == 2
            scaleFlowFrom = scale["P"]
            scaleFlowTo = scale["P"]
            unitFlow = unitList.activePowerLive
        elseif value == 3
            unitFlow = unitList.currentMagnitudeLive
        end
        branchConstraintHeader(io, width, show, delimiter, unitData, unitList, unitFlow, key, header, style)

        @inbounds for (label, i) in labels
            if system.branch.flow.type[i] == value
                if value == 3
                    scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                    scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
                end
                print(io, format(pfmt["Label"], width["Label"], label))

                if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                    printf(io, pfmt, show, width, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                    printf(io, pfmt, show, width, constraint.voltage.angle, i, scale["θ"], "Voltage Angle Difference Solution")
                    printf(io, pfmt, show, width, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                    printf(io, pfmt, show, width, dual.voltage.angle, i, scale["θ"], "Voltage Angle Difference Dual")
                else
                    printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Minimum", "-")
                    printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Solution", "-")
                    printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Maximum", "-")
                    printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Dual", "-")
                end

                if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                    if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minFromBus[i] < 0)
                        printf(io, pfmt, show, width, system.branch.flow.minFromBus, i, scaleFlowFrom, "From-Bus Flow Minimum")
                    else
                        printf(io, pfmt, show, width, 0.0, "From-Bus Flow Minimum")
                    end
                    printf(io, pfmt, show, width, constraint.flow.from, i, scaleFlowFrom, "From-Bus Flow Solution")
                    printf(io, pfmt, show, width, system.branch.flow.maxFromBus, i, scaleFlowFrom, "From-Bus Flow Maximum")
                    printf(io, pfmt, show, width, dual.flow.from, i, scaleFlowFrom, "From-Bus Flow Dual")
                else
                    printf(io, pfmt["Dash"], width, show, "From-Bus Flow Minimum", "-")
                    printf(io, pfmt["Dash"], width, show, "From-Bus Flow Solution", "-")
                    printf(io, pfmt["Dash"], width, show, "From-Bus Flow Maximum", "-")
                    printf(io, pfmt["Dash"], width, show, "From-Bus Flow Dual", "-")
                end

                if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                    if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minToBus[i] < 0)
                        printf(io, pfmt, show, width, system.branch.flow.minToBus, i, scaleFlowTo, "To-Bus Flow Minimum")
                    else
                        printf(io, pfmt, show, width, 0.0, "To-Bus Flow Minimum")
                    end

                    printf(io, pfmt, show, width, constraint.flow.to, i, scaleFlowTo, "To-Bus Flow Solution")
                    printf(io, pfmt, show, width, system.branch.flow.maxToBus, i, scaleFlowTo, "To-Bus Flow Maximum")
                    printf(io, pfmt, show, width, dual.flow.to, i, scaleFlowTo, "To-Bus Flow Dual")
                else
                    printf(io, pfmt["Dash"], width, show, "To-Bus Flow Minimum", "-")
                    printf(io, pfmt["Dash"], width, show, "To-Bus Flow Solution", "-")
                    printf(io, pfmt["Dash"], width, show, "To-Bus Flow Maximum", "-")
                    printf(io, pfmt["Dash"], width, show, "To-Bus Flow Dual", "-")
                end

                @printf io "\n"
            end
        end
        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatBranchConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Voltage Angle Difference Minimum" => 7 * style,
        "Voltage Angle Difference Solution" => 8 * style,
        "Voltage Angle Difference Maximum" => 7 * style,
        "Voltage Angle Difference Dual" => textwidth("[\$/$(unitList.voltageAngleLive)-hr]") * style,
        "From-Bus Flow Minimum" => 7 * style,
        "From-Bus Flow Solution" => 8 * style,
        "From-Bus Flow Maximum" => 7 * style,
        "From-Bus Flow Dual" => 10 * style,
        "To-Bus Flow Minimum" => 7 * style,
        "To-Bus Flow Solution" => 8 * style,
        "To-Bus Flow Maximum" => 7 * style,
        "To-Bus Flow Dual" => 10 * style,
    )

    _fmt = Dict(
        "Voltage Angle Difference Minimum" => "%*.4f",
        "Voltage Angle Difference Solution" => "%*.4f",
        "Voltage Angle Difference Maximum" => "%*.4f",
        "Voltage Angle Difference Dual" => "%*.4f",
        "From-Bus Flow Minimum" => "%*.4f",
        "From-Bus Flow Solution" => "%*.4f",
        "From-Bus Flow Maximum" => "%*.4f",
        "From-Bus Flow Dual" => "%*.4f",
        "To-Bus Flow Minimum" => "%*.4f",
        "To-Bus Flow Solution" => "%*.4f",
        "To-Bus Flow Maximum" => "%*.4f",
        "To-Bus Flow Dual" => "%*.4f",
    )

    _show = Dict(
        "Voltage Angle Difference Minimum" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Solution" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Maximum" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Dual" => !isempty(dual.voltage.angle),
        "From-Bus Flow Minimum" => !isempty(constraint.flow.from),
        "From-Bus Flow Solution" => !isempty(constraint.flow.from),
        "From-Bus Flow Maximum" => !isempty(constraint.flow.from),
        "From-Bus Flow Dual" => !isempty(dual.flow.from),
        "To-Bus Flow Minimum" => !isempty(constraint.flow.to),
        "To-Bus Flow Solution" => !isempty(constraint.flow.to),
        "To-Bus Flow Maximum" => !isempty(constraint.flow.to),
        "To-Bus Flow Dual" => !isempty(dual.flow.to),
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    apparent = false
    active = false
    current = false
    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            if system.branch.flow.type[i] == 1
                scaleFlowFrom = scale["S"]
                scaleFlowTo = scale["S"]
                apparent = true
            elseif system.branch.flow.type[i] == 2
                scaleFlowFrom = scale["P"]
                scaleFlowTo = scale["P"]
                active = true
            elseif system.branch.flow.type[i] == 3
                scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
                current = true
            end

            width["Label"] = max(textwidth(label), width["Label"])

            if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                fmax(fmt, width, show, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
                fmax(fmt, width, show, value(constraint.voltage.angle[i]) * scale["θ"], "Voltage Angle Difference Solution")
                fmax(fmt, width, show, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
                if haskey(dual.voltage.angle, i)
                    fmax(fmt, width, show, dual.voltage.angle[i] / scale["θ"], "Voltage Angle Difference Dual")
                end
            end

            if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minFromBus[i] < 0)
                    fmax(fmt, width, show, system.branch.flow.minFromBus, i, scaleFlowFrom, "From-Bus Flow Minimum")
                end
                fmax(fmt, width, show, value(constraint.flow.from[i]) * scaleFlowFrom, "From-Bus Flow Solution")
                fmax(fmt, width, show,system.branch.flow.maxFromBus, i, scaleFlowFrom, "From-Bus Flow Maximum")
                if haskey(dual.flow.from, i)
                    fmax(fmt, width, show, dual.flow.from[i] / scaleFlowFrom, "From-Bus Flow Dual")
                end
            end

            if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minToBus[i] < 0)
                    fmax(fmt, width, show, system.branch.flow.minToBus, i, scaleFlowTo, "To-Bus Flow Minimum")
                end
                fmax(fmt, width, show, value(constraint.flow.to[i]) * scaleFlowTo, "To-Bus Flow Solution")
                fmax(fmt, width, show,system.branch.flow.maxToBus, i, scaleFlowTo, "To-Bus Flow Maximum")
                if haskey(dual.flow.to, i)
                    fmax(fmt, width, show, dual.flow.to[i] / scaleFlowTo, "To-Bus Flow Dual")
                end
            end
        else
            minmaxθprimal = [-Inf; Inf]
            minmaxθdual = [-Inf; Inf]
            minmaxFmin = [-Inf; Inf]
            minmaxFmax = [-Inf; Inf]
            minmaxFprimal = [-Inf; Inf]
            minmaxFdual = [-Inf; Inf]
            minmaxTmin = [-Inf; Inf]
            minmaxTmax = [-Inf; Inf]
            minmaxTprimal = [-Inf; Inf]
            minmaxTdual = [-Inf; Inf]

            @inbounds for (label, i) in system.branch.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                    minmaxPrimal(show, constraint.voltage.angle[i], scale["θ"], minmaxθprimal, "Voltage Angle Difference Solution")
                    minmaxDual(show, dual.voltage.angle, i, scale["θ"], minmaxθdual, "Voltage Angle Difference Dual")
                end

                if system.branch.flow.type[i] == 1
                    scaleFlowFrom = scale["S"]
                    scaleFlowTo = scale["S"]
                    apparent = true
                elseif system.branch.flow.type[i] == 2
                    scaleFlowFrom = scale["P"]
                    scaleFlowTo = scale["P"]
                    active = true
                elseif system.branch.flow.type[i] == 3
                    scaleFlowFrom = scaleCurrent(prefix, system, system.branch.layout.from[i])
                    scaleFlowTo = scaleCurrent(prefix, system, system.branch.layout.to[i])
                    current = true
                end

                if haskey(constraint.flow.from, i) && is_valid(analysis.method.jump, constraint.flow.from[i])
                    if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minFromBus[i] < 0)
                        minmaxValue(show, system.branch.flow.minFromBus, i, scaleFlowFrom, minmaxFmin, "From-Bus Flow Minimum")
                    end
                    minmaxPrimal(show, constraint.flow.from[i], scaleFlowFrom, minmaxFprimal, "From-Bus Flow Solution")
                    minmaxValue(show, system.branch.flow.maxFromBus, i, scaleFlowFrom, minmaxFmax, "From-Bus Flow Maximum")
                    minmaxDual(show, dual.flow.from, i, scaleFlowFrom, minmaxFdual, "From-Bus Flow Dual")
                end

                if haskey(constraint.flow.to, i) && is_valid(analysis.method.jump, constraint.flow.to[i])
                    if !((system.branch.flow.type[i] == 1 || system.branch.flow.type[i] == 3) && system.branch.flow.minFromBus[i] < 0)
                        minmaxValue(show, system.branch.flow.minToBus, i, scaleFlowTo, minmaxTmin, "To-Bus Flow Minimum")
                    end
                    minmaxPrimal(show, constraint.flow.to[i], scaleFlowTo, minmaxTprimal, "To-Bus Flow Solution")
                    minmaxValue(show, system.branch.flow.maxToBus, i, scaleFlowTo, minmaxTmax, "To-Bus Flow Maximum")
                    minmaxDual(show, dual.flow.to, i, scaleFlowTo, minmaxTdual, "To-Bus Flow Dual")
                end
            end

            fminmax(fmt, width, show, system.branch.voltage.minDiffAngle, scale["θ"], "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, minmaxθprimal, 1.0, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, system.branch.voltage.maxDiffAngle, scale["θ"], "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, minmaxθdual, 1.0, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, minmaxFmin, 1.0, "From-Bus Flow Minimum")
            fminmax(fmt, width, show, minmaxFprimal, 1.0, "From-Bus Flow Solution")
            fminmax(fmt, width, show, minmaxFmax, 1.0, "From-Bus Flow Maximum")
            fminmax(fmt, width, show, minmaxFdual, 1.0, "From-Bus Flow Dual")

            fminmax(fmt, width, show, minmaxTmin, 1.0, "To-Bus Flow Minimum")
            fminmax(fmt, width, show, minmaxTprimal, 1.0, "To-Bus Flow Solution")
            fminmax(fmt, width, show, minmaxTmax, 1.0, "To-Bus Flow Maximum")
            fminmax(fmt, width, show, minmaxTdual, 1.0, "To-Bus Flow Dual")
        end

        hasMorePrint(width, show, "Branch Constraint Data")
        titlemax(width, show, "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference")

        typeFlow = OrderedDict{String, Int64}()
        if apparent
            typeFlow["Apparent Power"] = 1
        end
        if active
            typeFlow["Active Power"] = 2
        end
        if current
            typeFlow["Current Magnitude"] = 3
        end

        for key in keys(typeFlow)
            titlemax(width, show, "From-Bus Flow Minimum", "From-Bus Flow Solution", "From-Bus Flow Maximum", "From-Bus Flow Dual", "From-Bus Flow: $key")
            titlemax(width, show, "To-Bus Flow Minimum", "To-Bus Flow Solution", "To-Bus Flow Maximum", "To-Bus Flow Dual", "To-Bus Flow: $key")
        end
    end

    return fmt, width, show, typeFlow
end

function printBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBranchConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.branch, system.branch.label, header, footer, "branch")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header
        if style
            printTitle(io, maxLine, delimiter, "Branch Constraint Data")

            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            spanAng = printf(io, width, show, delimiter, "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference")
            spanFrom = printf(io, width, show, delimiter, "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual", "From-Bus Active Power Flow")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, spanAng)
            printf(io, fmt, spanFrom)
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", "Minimum")
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", "Solution")
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", "Maximum")
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "Dual")
            printf(io, fmt, width, show, "From-Bus Active Power Flow Minimum", "Minimum")
            printf(io, fmt, width, show, "From-Bus Active Power Flow Solution", "Solution")
            printf(io, fmt, width, show, "From-Bus Active Power Flow Maximum", "Maximum")
            printf(io, fmt, width, show, "From-Bus Active Power Flow Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "[\$/$(unitList.voltageAngleLive)-hr]")
            printf(io, fmt, width, show, "From-Bus Active Power Flow Minimum", unitData["P"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Solution", unitData["P"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Maximum", unitData["P"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Dual", "[\$/$(unitList.activePowerLive)-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", "-"^width["Voltage Angle Difference Minimum"])
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", "-"^width["Voltage Angle Difference Solution"])
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", "-"^width["Voltage Angle Difference Maximum"])
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "-"^width["Voltage Angle Difference Dual"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Minimum", "-"^width["From-Bus Active Power Flow Minimum"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Solution", "-"^width["From-Bus Active Power Flow Solution"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Maximum", "-"^width["From-Bus Active Power Flow Maximum"])
            printf(io, fmt, width, show, "From-Bus Active Power Flow Dual", "-"^width["From-Bus Active Power Flow Dual"])
            @printf io "\n"
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Voltage Angle Difference Minimum", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Solution")
            printf(io, show, delimiter, "Voltage Angle Difference Maximum", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference Dual")
            printf(io, show, delimiter, "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Solution")
            printf(io, show, delimiter, "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual", "From-Bus Active Power Flow Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Voltage Angle Difference Minimum", unitData["θ"], "Voltage Angle Difference Solution", unitData["θ"])
            printf(io, show, delimiter, "Voltage Angle Difference Maximum", unitData["θ"], "Voltage Angle Difference Dual", "[\$/$(unitList.voltageAngleLive)-hr]")
            printf(io, show, delimiter, "From-Bus Active Power Flow Minimum",  unitData["P"], "From-Bus Active Power Flow Solution",  unitData["P"])
            printf(io, show, delimiter, "From-Bus Active Power Flow Maximum",  unitData["P"], "From-Bus Active Power Flow Dual", "[\$/$(unitList.activePowerLive)-hr]")
            @printf io "\n"
        end
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
            printf(io, pfmt, show, width, system.branch.voltage.minDiffAngle, i, scale["θ"], "Voltage Angle Difference Minimum")
            printf(io, pfmt, show, width, constraint.voltage.angle, i, scale["θ"], "Voltage Angle Difference Solution")
            printf(io, pfmt, show, width, system.branch.voltage.maxDiffAngle, i, scale["θ"], "Voltage Angle Difference Maximum")
            printf(io, pfmt, show, width, dual.voltage.angle, i, scale["θ"], "Voltage Angle Difference Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "Voltage Angle Difference Dual", "-")
        end

        if haskey(constraint.flow.active, i) && is_valid(analysis.method.jump, constraint.flow.active[i])
            printf(io, pfmt, show, width, system.branch.flow.minFromBus, i, scale["P"], "From-Bus Active Power Flow Minimum")
            printf(io, pfmt, show, width, constraint.flow.active, i, scale["P"], "From-Bus Active Power Flow Solution")
            printf(io, pfmt, show, width, system.branch.flow.maxFromBus, i, scale["P"], "From-Bus Active Power Flow Maximum")
            printf(io, pfmt, show, width, dual.flow.active, i, scale["P"], "From-Bus Active Power Flow Dual")
        else
            printf(io, pfmt["Dash"], width, show, "From-Bus Active Power Flow Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "From-Bus Active Power Flow Solution", "-")
            printf(io, pfmt["Dash"], width, show, "From-Bus Active Power Flow Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "From-Bus Active Power Flow Dual", "-")
        end

        @printf io "\n"
    end

    if footer && style
        print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    end
end

function formatBranchConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Voltage Angle Difference Minimum" => 7 * style,
        "Voltage Angle Difference Solution" => 8 * style,
        "Voltage Angle Difference Maximum" => 7 * style,
        "Voltage Angle Difference Dual" => textwidth("[\$/$(unitList.voltageAngleLive)-hr]") * style,
        "From-Bus Active Power Flow Minimum" => 7 * style,
        "From-Bus Active Power Flow Solution" => 8 * style,
        "From-Bus Active Power Flow Maximum" => 7 * style,
        "From-Bus Active Power Flow Dual" => textwidth("[\$/$(unitList.activePowerLive)-hr]") * style,
    )

    _fmt = Dict(
        "Voltage Angle Difference Minimum" => "%*.4f",
        "Voltage Angle Difference Solution" => "%*.4f",
        "Voltage Angle Difference Maximum" => "%*.4f",
        "Voltage Angle Difference Dual" => "%*.4f",
        "From-Bus Active Power Flow Minimum" => "%*.4f",
        "From-Bus Active Power Flow Solution" => "%*.4f",
        "From-Bus Active Power Flow Maximum" => "%*.4f",
        "From-Bus Active Power Flow Dual" => "%*.4f",
    )

    _show = Dict(
        "Voltage Angle Difference Minimum" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Solution" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Maximum" => !isempty(constraint.voltage.angle),
        "Voltage Angle Difference Dual" => !isempty(dual.voltage.angle),
        "From-Bus Active Power Flow Minimum" => !isempty(constraint.flow.active),
        "From-Bus Active Power Flow Solution" => !isempty(constraint.flow.active),
        "From-Bus Active Power Flow Maximum" => !isempty(constraint.flow.active),
        "From-Bus Active Power Flow Dual" => !isempty(dual.flow.active),
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.branch, label, "branch")
            i = system.branch.label[label]

            width["Label"] = max(textwidth(label), width["Label"])

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
            minmaxθprimal = [-Inf; Inf]
            minmaxθdual = [-Inf; Inf]
            minmaxFmin = [-Inf; Inf]
            minmaxFmax = [-Inf; Inf]
            minmaxFprimal = [-Inf; Inf]
            minmaxFdual = [-Inf; Inf]

            @inbounds for (label, i) in system.branch.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.voltage.angle, i) && is_valid(analysis.method.jump, constraint.voltage.angle[i])
                    minmaxPrimal(show, constraint.voltage.angle[i], scale["θ"], minmaxθprimal, "Voltage Angle Difference Solution")
                    minmaxDual(show, dual.voltage.angle, i, scale["θ"], minmaxθdual, "Voltage Angle Difference Dual")
                end

                if haskey(constraint.flow.active, i) && is_valid(analysis.method.jump, constraint.flow.active[i])
                    minmaxValue(show, system.branch.flow.minFromBus, i, scale["P"], minmaxFmin, "From-Bus Active Power Flow Minimum")
                    minmaxPrimal(show, constraint.flow.active[i], scale["P"], minmaxFprimal, "From-Bus Active Power Flow Solution")
                    minmaxValue(show, system.branch.flow.maxFromBus, i, scale["P"], minmaxFmax, "From-Bus Active Power Flow Maximum")
                    minmaxDual(show, dual.flow.active, i, scale["P"], minmaxFdual, "From-Bus Active Power Flow Dual")
                end
            end

            fminmax(fmt, width, show, system.branch.voltage.minDiffAngle, scale["θ"], "Voltage Angle Difference Minimum")
            fminmax(fmt, width, show, minmaxθprimal, 1.0, "Voltage Angle Difference Solution")
            fminmax(fmt, width, show, system.branch.voltage.maxDiffAngle, scale["θ"], "Voltage Angle Difference Maximum")
            fminmax(fmt, width, show, minmaxθdual, 1.0, "Voltage Angle Difference Dual")

            fminmax(fmt, width, show, minmaxFmin, 1.0, "From-Bus Active Power Flow Minimum")
            fminmax(fmt, width, show, minmaxFprimal, 1.0, "From-Bus Active Power Flow Solution")
            fminmax(fmt, width, show, minmaxFmax, 1.0, "From-Bus Active Power Flow Maximum")
            fminmax(fmt, width, show, minmaxFdual, 1.0, "From-Bus Active Power Flow Dual")
        end

        hasMorePrint(width, show, "Branch Constraint Data")
        titlemax(width, show, "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference")
        titlemax(width, show, "From-Bus Active Power Flow Minimum", "From-Bus Active Power Flow Solution", "From-Bus Active Power Flow Maximum", "From-Bus Active Power Flow Dual", "From-Bus Active Power Flow")
    end

    return fmt, width, show
end

function branchConstraintHeader(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, unitData::Dict{String, String}, unitList::UnitList, unitFlow::String, type::String, header::Bool, style::Bool)
    if header
        if style
            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            spanAng = printf(io, width, show, delimiter, "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference")
            spanFrom = printf(io, width, show, delimiter, "From-Bus Flow Minimum", "From-Bus Flow Solution", "From-Bus Flow Maximum", "From-Bus Flow Dual", "From-Bus Flow: $type")
            spanTo = printf(io, width, show, delimiter, "To-Bus Flow Minimum", "To-Bus Flow Solution", "To-Bus Flow Maximum", "To-Bus Flow Dual", "To-Bus Flow: $type")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, spanAng)
            printf(io, fmt, spanFrom)
            printf(io, fmt, spanTo)
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", "Minimum")
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", "Solution")
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", "Maximum")
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "Dual")
            printf(io, fmt, width, show, "From-Bus Flow Minimum", "Minimum")
            printf(io, fmt, width, show, "From-Bus Flow Solution", "Solution")
            printf(io, fmt, width, show, "From-Bus Flow Maximum", "Maximum")
            printf(io, fmt, width, show, "From-Bus Flow Dual", "Dual")
            printf(io, fmt, width, show, "To-Bus Flow Minimum", "Minimum")
            printf(io, fmt, width, show, "To-Bus Flow Solution", "Solution")
            printf(io, fmt, width, show, "To-Bus Flow Maximum", "Maximum")
            printf(io, fmt, width, show, "To-Bus Flow Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", unitData["θ"])
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "[\$/$(unitList.voltageAngleLive)-hr]")
            printf(io, fmt, width, show, "From-Bus Flow Minimum", "[$unitFlow]")
            printf(io, fmt, width, show, "From-Bus Flow Solution", "[$unitFlow]")
            printf(io, fmt, width, show, "From-Bus Flow Maximum", "[$unitFlow]")
            printf(io, fmt, width, show, "From-Bus Flow Dual", "[\$/$unitFlow-hr]")
            printf(io, fmt, width, show, "To-Bus Flow Minimum", "[$unitFlow]")
            printf(io, fmt, width, show, "To-Bus Flow Solution", "[$unitFlow]")
            printf(io, fmt, width, show, "To-Bus Flow Maximum", "[$unitFlow]")
            printf(io, fmt, width, show, "To-Bus Flow Dual", "[\$/$unitFlow-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmt, width, show, "Voltage Angle Difference Minimum", "-"^width["Voltage Angle Difference Minimum"])
            printf(io, fmt, width, show, "Voltage Angle Difference Solution", "-"^width["Voltage Angle Difference Solution"])
            printf(io, fmt, width, show, "Voltage Angle Difference Maximum", "-"^width["Voltage Angle Difference Maximum"])
            printf(io, fmt, width, show, "Voltage Angle Difference Dual", "-"^width["Voltage Angle Difference Dual"])
            printf(io, fmt, width, show, "From-Bus Flow Minimum", "-"^width["From-Bus Flow Minimum"])
            printf(io, fmt, width, show, "From-Bus Flow Solution", "-"^width["From-Bus Flow Solution"])
            printf(io, fmt, width, show, "From-Bus Flow Maximum", "-"^width["From-Bus Flow Maximum"])
            printf(io, fmt, width, show, "From-Bus Flow Dual", "-"^width["From-Bus Flow Dual"])
            printf(io, fmt, width, show, "To-Bus Flow Minimum", "-"^width["To-Bus Flow Minimum"])
            printf(io, fmt, width, show, "To-Bus Flow Solution", "-"^width["To-Bus Flow Solution"])
            printf(io, fmt, width, show, "To-Bus Flow Maximum", "-"^width["To-Bus Flow Maximum"])
            printf(io, fmt, width, show, "To-Bus Flow Dual", "-"^width["To-Bus Flow Dual"])
            @printf io "\n"
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Voltage Angle Difference Minimum", "Voltage Angle Difference Minimum", "Voltage Angle Difference Solution", "Voltage Angle Difference Solution")
            printf(io, show, delimiter, "Voltage Angle Difference Maximum", "Voltage Angle Difference Maximum", "Voltage Angle Difference Dual", "Voltage Angle Difference Dual")
            printf(io, show, delimiter, "From-Bus Flow Minimum", "From-Bus $type Flow Minimum", "From-Bus Flow Solution", "From-Bus $type Flow Solution")
            printf(io, show, delimiter, "From-Bus Flow Maximum", "From-Bus $type Flow Maximum", "From-Bus Flow Dual", "From-Bus $type Flow Dual")
            printf(io, show, delimiter, "To-Bus Flow Minimum", "To-Bus $type Flow Minimum", "To-Bus Flow Solution", "To-Bus $type Flow Solution")
            printf(io, show, delimiter, "To-Bus Flow Maximum", "To-Bus $type Flow Maximum", "To-Bus Flow Dual", "To-Bus $type Flow Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Voltage Angle Difference Minimum", unitData["θ"], "Voltage Angle Difference Solution", unitData["θ"])
            printf(io, show, delimiter, "Voltage Angle Difference Maximum", unitData["θ"], "Voltage Angle Difference Dual", "[\$/$(unitList.voltageAngleLive)-hr]")
            printf(io, show, delimiter, "From-Bus Flow Minimum", "[$unitFlow]", "From-Bus Flow Solution", "[$unitFlow]")
            printf(io, show, delimiter, "From-Bus Flow Maximum", "[$unitFlow]", "From-Bus Flow Dual", "[\$/$unitFlow-hr]")
            printf(io, show, delimiter, "To-Bus Flow Minimum", "[$unitFlow]", "To-Bus Flow Solution", "[$unitFlow]")
            printf(io, show, delimiter, "To-Bus Flow Maximum", "[$unitFlow]", "To-Bus Flow Dual", "[\$/$unitFlow-hr]")
            @printf io "\n"
        end
    end
end

"""
    printGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, [io::IO];
        label, header, footer, delimiter, fmt, width, show, style)

The function prints constraint data related to generators. Optionally, an `IO` may be passed as
the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

!!! compat "Julia 1.10"
    The function [`printGeneratorConstraint`](@ref printGeneratorConstraint) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)

# Print data for all generators
fmt = Dict("Active Power Capability Solution" => "%.2f")
show = Dict("Active Power Capability Minimum" => false)
printGeneratorConstraint(system, analysis; fmt, show)

# Print data for specific generators
delimiter = " "
width = Dict("Reactive Power Capability Dual" => 10)
printGeneratorConstraint(system, analysis; label = 2, delimiter, width, header = true)
printGeneratorConstraint(system, analysis; label = 3, delimiter, width)
printGeneratorConstraint(system, analysis; label = 5, delimiter, width, footer = true)
```
"""
function printGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatGeneratorConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.generator, system.generator.label, header, footer, "generator")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header
        if style
            printTitle(io, maxLine, delimiter, "Generator Constraint Data")

            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            spanAct = printf(io, width, show, delimiter, "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability")
            spanReact = printf(io, width, show, delimiter, "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Maximum", "Reactive Power Capability Dual", "Reactive Power Capability")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, spanAct)
            printf(io, fmt, spanReact)
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Active Power Capability Minimum", "Minimum")
            printf(io, fmt, width, show, "Active Power Capability Solution", "Solution")
            printf(io, fmt, width, show, "Active Power Capability Maximum", "Maximum")
            printf(io, fmt, width, show, "Active Power Capability Dual", "Dual")
            printf(io, fmt, width, show, "Reactive Power Capability Minimum", "Minimum")
            printf(io, fmt, width, show, "Reactive Power Capability Solution", "Solution")
            printf(io, fmt, width, show, "Reactive Power Capability Maximum", "Maximum")
            printf(io, fmt, width, show, "Reactive Power Capability Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Active Power Capability Minimum", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Solution", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Maximum", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Dual", "[\$/$(unitList.activePowerLive)-hr]")
            printf(io, fmt, width, show, "Reactive Power Capability Minimum", unitData["Q"])
            printf(io, fmt, width, show, "Reactive Power Capability Solution", unitData["Q"])
            printf(io, fmt, width, show, "Reactive Power Capability Maximum", unitData["Q"])
            printf(io, fmt, width, show, "Reactive Power Capability Dual", "[\$/$(unitList.reactivePowerLive)-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmt, width, show, "Active Power Capability Minimum", "-"^width["Active Power Capability Minimum"])
            printf(io, fmt, width, show, "Active Power Capability Solution", "-"^width["Active Power Capability Solution"])
            printf(io, fmt, width, show, "Active Power Capability Maximum", "-"^width["Active Power Capability Maximum"])
            printf(io, fmt, width, show, "Active Power Capability Dual", "-"^width["Active Power Capability Dual"])
            printf(io, fmt, width, show, "Reactive Power Capability Minimum", "-"^width["Reactive Power Capability Minimum"])
            printf(io, fmt, width, show, "Reactive Power Capability Solution", "-"^width["Reactive Power Capability Solution"])
            printf(io, fmt, width, show, "Reactive Power Capability Maximum", "-"^width["Reactive Power Capability Maximum"])
            printf(io, fmt, width, show, "Reactive Power Capability Dual", "-"^width["Reactive Power Capability Dual"])
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Active Power Capability Minimum", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Solution")
            printf(io, show, delimiter, "Active Power Capability Maximum", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability Dual")
            printf(io, show, delimiter, "Reactive Power Capability Minimum", "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Solution")
            printf(io, show, delimiter, "Reactive Power Capability Maximum", "Reactive Power Capability Maximum", "Reactive Power Capability Dual", "Reactive Power Capability Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Active Power Capability Minimum", unitData["P"], "Active Power Capability Solution", unitData["P"])
            printf(io, show, delimiter, "Active Power Capability Maximum", unitData["P"], "Active Power Capability Dual", "[\$/$(unitList.activePowerLive)-hr]")
            printf(io, show, delimiter, "Reactive Power Capability Minimum", unitData["Q"], "Reactive Power Capability Solution", unitData["Q"])
            printf(io, show, delimiter, "Reactive Power Capability Maximum", unitData["Q"], "Reactive Power Capability Dual", "[\$/$(unitList.reactivePowerLive)-hr]")
        end
        @printf io "\n"
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
            printf(io, pfmt, show, width, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
            printf(io, pfmt, show, width, constraint.capability.active, i, scale["P"], "Active Power Capability Solution")
            printf(io, pfmt, show, width, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
            printf(io, pfmt, show, width, dual.capability.active, i, scale["P"], "Active Power Capability Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Dual", "-")
        end

        if haskey(constraint.capability.reactive, i) && is_valid(analysis.method.jump, constraint.capability.reactive[i])
            printf(io, pfmt, show, width, system.generator.capability.minReactive, i, scale["Q"], "Reactive Power Capability Minimum")
            printf(io, pfmt, show, width, constraint.capability.reactive, i, scale["Q"], "Reactive Power Capability Solution")
            printf(io, pfmt, show, width, system.generator.capability.maxReactive, i, scale["Q"], "Reactive Power Capability Maximum")
            printf(io, pfmt, show, width, dual.capability.reactive, i, scale["Q"], "Reactive Power Capability Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Reactive Power Capability Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "Reactive Power Capability Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Reactive Power Capability Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "Reactive Power Capability Dual", "-")
        end

        @printf io "\n"
    end

    if footer && style
        print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::ACOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Active Power Capability Minimum" => 7 * style,
        "Active Power Capability Solution" => 8 * style,
        "Active Power Capability Maximum" => 7 * style,
        "Active Power Capability Dual" => textwidth("[\$/$(unitList.activePowerLive)-hr]") * style,
        "Reactive Power Capability Minimum" => 7 * style,
        "Reactive Power Capability Solution" => 8 * style,
        "Reactive Power Capability Maximum" => 7 * style,
        "Reactive Power Capability Dual" => textwidth("[\$/$(unitList.reactivePowerLive)-hr]") * style
    )

    _fmt = Dict(
        "Active Power Capability Minimum" => "%*.4f",
        "Active Power Capability Solution" => "%*.4f",
        "Active Power Capability Maximum" => "%*.4f",
        "Active Power Capability Dual" => "%*.4f",
        "Reactive Power Capability Minimum" => "%*.4f",
        "Reactive Power Capability Solution" => "%*.4f",
        "Reactive Power Capability Maximum" => "%*.4f",
        "Reactive Power Capability Dual" => "%*.4f"
    )

    _show = Dict(
        "Active Power Capability Minimum" => !isempty(constraint.capability.active),
        "Active Power Capability Solution" => !isempty(constraint.capability.active),
        "Active Power Capability Maximum" => !isempty(constraint.capability.active),
        "Active Power Capability Dual" => !isempty(dual.capability.active),
        "Reactive Power Capability Minimum" => !isempty(constraint.capability.reactive),
        "Reactive Power Capability Solution" => !isempty(constraint.capability.reactive),
        "Reactive Power Capability Maximum" => !isempty(constraint.capability.reactive),
        "Reactive Power Capability Dual" => !isempty(dual.capability.reactive)
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            width["Label"] = max(textwidth(label), width["Label"])

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
            minmaxPprimal = [-Inf; Inf]
            minmaxPdual = [-Inf; Inf]
            minmaxQprimal = [-Inf; Inf]
            minmaxQdual = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    minmaxPrimal(show, constraint.capability.active[i], scale["P"], minmaxPprimal, "Active Power Capability Solution")
                    minmaxDual(show, dual.capability.active, i, scale["P"], minmaxPdual, "Active Power Capability Dual")
                end

                if haskey(constraint.capability.reactive, i) && is_valid(analysis.method.jump, constraint.capability.reactive[i])
                    minmaxPrimal(show, constraint.capability.reactive[i], scale["Q"], minmaxQprimal, "Reactive Power Capability Solution")
                    minmaxDual(show, dual.capability.reactive, i, scale["Q"], minmaxQdual, "Reactive Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, system.generator.capability.minActive, scale["P"], "Active Power Capability Minimum")
            fminmax(fmt, width, show, minmaxPprimal, 1.0, "Active Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxActive, scale["P"], "Active Power Capability Maximum")
            fminmax(fmt, width, show, minmaxPdual, 1.0, "Active Power Capability Dual")

            fminmax(fmt, width, show, system.generator.capability.minReactive, scale["Q"], "Reactive Power Capability Minimum")
            fminmax(fmt, width, show, minmaxQprimal, 1.0, "Reactive Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxReactive, scale["Q"], "Reactive Power Capability Maximum")
            fminmax(fmt, width, show, minmaxQdual, 1.0, "Reactive Power Capability Dual")
        end

        hasMorePrint(width, show, "Generator Constraint Data")
        titlemax(width, show, "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability")
        titlemax(width, show, "Reactive Power Capability Minimum", "Reactive Power Capability Solution", "Reactive Power Capability Maximum", "Reactive Power Capability Dual", "Reactive Power Capability")
    end

    return fmt, width, show
end

function printGeneratorConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatGeneratorConstraint(system, analysis, label, scale, prefix, fmt, width, show, style)
    maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
    labels, header, footer = toggleLabelHeader(label, system.generator, system.generator.label, header, footer, "generator")

    constraint = analysis.method.constraint
    dual = analysis.method.dual
    if header
        if style
            printTitle(io, maxLine, delimiter, "Generator Constraint Data")

            print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
            spanAct = printf(io, width, show, delimiter, "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability")
            @printf io "\n"

            fmt = Format(" %*s $delimiter")
            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, spanAct)
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Active Power Capability Minimum", "Minimum")
            printf(io, fmt, width, show, "Active Power Capability Solution", "Solution")
            printf(io, fmt, width, show, "Active Power Capability Maximum", "Maximum")
            printf(io, fmt, width, show, "Active Power Capability Dual", "Dual")
            @printf io "\n"

            print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
            printf(io, fmt, width, show, "Active Power Capability Minimum", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Solution", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Maximum", unitData["P"])
            printf(io, fmt, width, show, "Active Power Capability Dual", "[\$/$(unitList.activePowerLive)-hr]")
            @printf io "\n"

            fmt =  Format("-%*s-$delimiter")
            print(io, format(Format("$delimiter-%s-$delimiter"), "-"^width["Label"]))
            printf(io, fmt, width, show, "Active Power Capability Minimum", "-"^width["Active Power Capability Minimum"])
            printf(io, fmt, width, show, "Active Power Capability Solution", "-"^width["Active Power Capability Solution"])
            printf(io, fmt, width, show, "Active Power Capability Maximum", "-"^width["Active Power Capability Maximum"])
            printf(io, fmt, width, show, "Active Power Capability Dual", "-"^width["Active Power Capability Dual"])
        else
            print(io, format(Format("%s"), "Bus Label"))
            printf(io, show, delimiter, "Active Power Capability Minimum", "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Solution")
            printf(io, show, delimiter, "Active Power Capability Maximum", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability Dual")
            @printf io "\n"

            print(io, format(Format("%s"), ""))
            printf(io, show, delimiter, "Active Power Capability Minimum", unitData["P"], "Active Power Capability Solution", unitData["P"])
            printf(io, show, delimiter, "Active Power Capability Maximum", unitData["P"], "Active Power Capability Dual", "[\$/$(unitList.activePowerLive)-hr]")
        end
        @printf io "\n"
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
            printf(io, pfmt, show, width, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
            printf(io, pfmt, show, width, constraint.capability.active, i, scale["P"], "Active Power Capability Solution")
            printf(io, pfmt, show, width, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
            printf(io, pfmt, show, width, dual.capability.active, i, scale["P"], "Active Power Capability Dual")
        else
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Minimum", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Solution", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Maximum", "-")
            printf(io, pfmt["Dash"], width, show, "Active Power Capability Dual", "-")
        end

        @printf io "\n"
    end

    if footer && style
        print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
    end
end

function formatGeneratorConstraint(system::PowerSystem, analysis::DCOptimalPowerFlow, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    errorVoltage(analysis.voltage.angle)
    constraint = analysis.method.constraint
    dual = analysis.method.dual

    _width = Dict(
        "Label" => 5 * style,
        "Active Power Capability Minimum" => 7 * style,
        "Active Power Capability Solution" => 8 * style,
        "Active Power Capability Maximum" => 7 * style,
        "Active Power Capability Dual" => textwidth("[\$/$(unitList.activePowerLive)-hr]") * style,
    )

    _fmt = Dict(
        "Active Power Capability Minimum" => "%*.4f",
        "Active Power Capability Solution" => "%*.4f",
        "Active Power Capability Maximum" => "%*.4f",
        "Active Power Capability Dual" => "%*.4f",
    )

    _show = Dict(
        "Active Power Capability Minimum" => !isempty(constraint.capability.active),
        "Active Power Capability Solution" => !isempty(constraint.capability.active),
        "Active Power Capability Maximum" => !isempty(constraint.capability.active),
        "Active Power Capability Dual" => !isempty(dual.capability.active),
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    if style
        if isset(label)
            label = getLabel(system.generator, label, "generator")
            i = system.generator.label[label]

            width["Label"] = max(textwidth(label), width["Label"])

            if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                fmax(fmt, width, show, system.generator.capability.minActive, i, scale["P"], "Active Power Capability Minimum")
                fmax(fmt, width, show, value(constraint.capability.active[i]) * scale["P"], "Active Power Capability Solution")
                fmax(fmt, width, show, system.generator.capability.maxActive, i, scale["P"], "Active Power Capability Maximum")
                if haskey(dual.capability.active, i)
                    fmax(fmt, width, show, dual.capability.active[i] / scale["P"], "Active Power Capability Dual")
                end
            end
        else
            minmaxPprimal = [-Inf; Inf]
            minmaxPdual = [-Inf; Inf]

            @inbounds for (label, i) in system.generator.label
                width["Label"] = max(textwidth(label), width["Label"])

                if haskey(constraint.capability.active, i) && is_valid(analysis.method.jump, constraint.capability.active[i])
                    minmaxPrimal(show, constraint.capability.active[i], scale["P"], minmaxPprimal, "Active Power Capability Solution")
                    minmaxDual(show, dual.capability.active, i, scale["P"], minmaxPdual, "Active Power Capability Dual")
                end
            end

            fminmax(fmt, width, show, system.generator.capability.minActive, scale["P"], "Active Power Capability Minimum")
            fminmax(fmt, width, show, minmaxPprimal, 1.0, "Active Power Capability Solution")
            fminmax(fmt, width, show, system.generator.capability.maxActive, scale["P"], "Active Power Capability Maximum")
            fminmax(fmt, width, show, minmaxPdual, 1.0, "Active Power Capability Dual")
        end

        hasMorePrint(width, show, "Generator Constraint Data")
        titlemax(width, show, "Active Power Capability Minimum", "Active Power Capability Solution", "Active Power Capability Maximum", "Active Power Capability Dual", "Active Power Capability")
    end

    return fmt, width, show
end
