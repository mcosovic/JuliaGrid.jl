"""
    printBusData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, fmt, width, show)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.

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
fmt = Dict("Voltage Angle" => "%.2f")
show = Dict("Power Generation Reactive" => false)
printBusData(system, analysis; fmt, show)

# Print data for specific buses
width = Dict("Power Injection Active" => 8)
printBusData(system, analysis; label = 2, width, header = true)
printBusData(system, analysis; label = 10, width)
printBusData(system, analysis; label = 12, width)
printBusData(system, analysis; label = 14, width, footer = true)
```
"""
function printBusData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBusData(system, analysis, label, scale, prefix, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Bus Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtVol = printf(io, width, show, "Voltage Magnitude", "Voltage Angle", "Voltage")
        fmtGen = printf(io, width, show, "Power Generation Active", "Power Generation Reactive", "Power Generation")
        fmtDem = printf(io, width, show, "Power Demand Active", "Power Demand Reactive", "Power Demand")
        fmtInj = printf(io, width, show, "Power Injection Active", "Power Injection Reactive", "Power Injection")
        fmtShu = printf(io, width, show, "Shunt Power Active", "Shunt Power Reactive", "Shunt Power")
        fmtCur = printf(io, width, show, "Current Injection Magnitude", "Current Injection Angle", "Current Injection")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[1], width, show, "Voltage Magnitude", "", "Voltage Angle", "")
        printf(io, fmtGen[1], width, show, "Power Generation Active", "", "Power Generation Reactive", "")
        printf(io, fmtDem[1], width, show, "Power Demand Active", "", "Power Demand Reactive", "")
        printf(io, fmtInj[1], width, show, "Power Injection Active", "", "Power Injection Reactive", "")
        printf(io, fmtShu[1], width, show, "Shunt Power Active", "", "Shunt Power Reactive", "")
        printf(io, fmtCur[1], width, show, "Current Injection Magnitude", "", "Current Injection Angle", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[2], width, show, "Voltage Magnitude", "Magnitude", "Voltage Angle", "Angle")
        printf(io, fmtGen[2], width, show, "Power Generation Active", "Active", "Power Generation Reactive", "Reactive")
        printf(io, fmtDem[2], width, show, "Power Demand Active", "Active", "Power Demand Reactive", "Reactive")
        printf(io, fmtInj[2], width, show, "Power Injection Active", "Active", "Power Injection Reactive", "Reactive")
        printf(io, fmtShu[2], width, show, "Shunt Power Active", "Active", "Shunt Power Reactive", "Reactive")
        printf(io, fmtCur[2], width, show, "Current Injection Magnitude", "Magnitude", "Current Injection Angle", "Angle")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[2], width, show, "Voltage Magnitude", unitData["V"], "Voltage Angle", unitData["θ"])
        printf(io, fmtGen[2], width, show, "Power Generation Active", unitData["P"], "Power Generation Reactive", unitData["Q"])
        printf(io, fmtDem[2], width, show, "Power Demand Active", unitData["P"], "Power Demand Reactive", unitData["Q"])
        printf(io, fmtInj[2], width, show, "Power Injection Active", unitData["P"], "Power Injection Reactive", unitData["Q"])
        printf(io, fmtShu[2], width, show, "Shunt Power Active", unitData["P"], "Shunt Power Reactive", unitData["Q"])
        printf(io, fmtCur[2], width, show, "Current Injection Magnitude", unitData["I"], "Current Injection Angle", unitData["ψ"])
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtVol[3], width, show, "Voltage Magnitude", "-"^width["Voltage Magnitude"], "Voltage Angle", "-"^width["Voltage Angle"])
        printf(io, fmtGen[3], width, show, "Power Generation Active", "-"^width["Power Generation Active"], "Power Generation Reactive", "-"^width["Power Generation Reactive"])
        printf(io, fmtDem[3], width, show, "Power Demand Active", "-"^width["Power Demand Active"], "Power Demand Reactive", "-"^width["Power Demand Reactive"])
        printf(io, fmtInj[3], width, show, "Power Injection Active", "-"^width["Power Injection Active"], "Power Injection Reactive", "-"^width["Power Injection Reactive"])
        printf(io, fmtShu[3], width, show, "Shunt Power Active", "-"^width["Shunt Power Active"], "Shunt Power Reactive", "-"^width["Shunt Power Reactive"])
        printf(io, fmtCur[3], width, show, "Current Injection Magnitude", "-"^width["Current Injection Magnitude"], "Current Injection Angle", "-"^width["Current Injection Angle"])
        @printf io "\n"

    elseif !isset(label)
        @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

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

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    errorVoltage(analysis.voltage.magnitude)
    voltage = analysis.voltage
    power = analysis.power
    current = analysis.current

    _width = Dict(
        "Label" => 5,
        "Voltage Magnitude" => 9,
        "Voltage Angle" => 5,
        "Power Generation Active" => 6,
        "Power Generation Reactive" => 8,
        "Power Demand Active" => 6,
        "Power Demand Reactive" => 8,
        "Power Injection Active" => 6,
        "Power Injection Reactive" => 8,
        "Shunt Power Active" => 6,
        "Shunt Power Reactive" => 8,
        "Current Injection Magnitude" => 9,
        "Current Injection Angle" => 5
    )

    _fmt = Dict(
        "Voltage Magnitude" => "%*.4f",
        "Voltage Angle" => "%*.4f",
        "Power Generation Active" => "%*.4f",
        "Power Generation Reactive" => "%*.4f",
        "Power Demand Active" => "%*.4f",
        "Power Demand Reactive" => "%*.4f",
        "Power Injection Active" => "%*.4f",
        "Power Injection Reactive" => "%*.4f",
        "Shunt Power Active" => "%*.4f",
        "Shunt Power Reactive" => "%*.4f",
        "Current Injection Magnitude" => "%*.4f",
        "Current Injection Angle" => "%*.4f"
    )

    _show = Dict(
        "Voltage Magnitude" => true,
        "Voltage Angle" => true,
        "Power Generation Active" => !isempty(power.supply.active),
        "Power Generation Reactive" => !isempty(power.supply.reactive),
        "Power Demand Active" => !isempty(power.injection.active),
        "Power Demand Reactive" => !isempty(power.injection.reactive),
        "Power Injection Active" => !isempty(power.injection.active),
        "Power Injection Reactive" => !isempty(power.injection.reactive),
        "Shunt Power Active" => !isempty(power.shunt.active),
        "Shunt Power Reactive" => !isempty(power.shunt.reactive),
        "Current Injection Magnitude" => !isempty(current.injection.magnitude),
        "Current Injection Angle" => !isempty(current.injection.angle)
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

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
        maxV = initMax(prefix.currentMagnitude)
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

    hasMorePrint(width, show, "Bus Data")
    titlemax(width, show, "Voltage Magnitude", "Voltage Angle", "Voltage")
    titlemax(width, show, "Power Generation Active", "Power Generation Reactive", "Power Generation")
    titlemax(width, show, "Power Demand Active", "Power Demand Reactive", "Power Demand")
    titlemax(width, show, "Power Injection Active", "Power Injection Reactive", "Power Injection")
    titlemax(width, show, "Shunt Power Active", "Shunt Power Reactive", "Shunt Power")
    titlemax(width, show, "Current Injection Magnitude", "Current Injection Angle", "Current Injection")

    return fmt, width, show
end

function printBusData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, width::Dict{String, Int64} = Dict{String, Int64}(),
    fmt::Dict{String, String} = Dict{String, String}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBusData(system, analysis, label, scale, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Bus Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtVol = printf(io, width, show, "Voltage Angle", "Voltage")
        fmtGen = printf(io, width, show, "Power Generation Active", "Power Generation")
        fmtDem = printf(io, width, show, "Power Demand Active", "Power Demand")
        fmtInj = printf(io, width, show, "Power Injection Active", "Power Injection")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[1], width, show, "Voltage Angle", "")
        printf(io, fmtGen[1], width, show, "Power Generation Active", "")
        printf(io, fmtDem[1], width, show, "Power Demand Active", "")
        printf(io, fmtInj[1], width, show, "Power Injection Active", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[2], width, show, "Voltage Angle", "Angle")
        printf(io, fmtGen[2], width, show, "Power Generation Active", "Active")
        printf(io, fmtDem[2], width, show, "Power Demand Active", "Active")
        printf(io, fmtInj[2], width, show, "Power Injection Active", "Active")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtVol[2], width, show, "Voltage Angle", unitData["θ"])
        printf(io, fmtGen[2], width, show, "Power Generation Active", unitData["P"])
        printf(io, fmtDem[2], width, show, "Power Demand Active", unitData["P"])
        printf(io, fmtInj[2], width, show, "Power Injection Active", unitData["P"])
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtVol[3], width, show, "Voltage Angle", "-"^width["Voltage Angle"])
        printf(io, fmtGen[3], width, show, "Power Generation Active", "-"^width["Power Generation Active"])
        printf(io, fmtDem[3], width, show, "Power Demand Active", "-"^width["Power Demand Active"])
        printf(io, fmtInj[3], width, show, "Power Injection Active", "-"^width["Power Injection Active"])
        @printf io "\n"
    elseif !isset(label)
        @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        printf(io, pfmt, show, width, analysis.voltage.angle, i, scale["θ"], "Voltage Angle")

        printf(io, pfmt, show, width, analysis.power.supply.active, i, scale["P"], "Power Generation Active")
        printf(io, pfmt, show, width, system.bus.demand.active, i, scale["P"], "Power Demand Active")
        printf(io, pfmt, show, width, analysis.power.injection.active, i, scale["P"], "Power Injection Active")

        @printf io "\n"
    end

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64},
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    errorVoltage(analysis.voltage.angle)
    voltage = analysis.voltage
    power = analysis.power

    _width = Dict(
        "Label" => 5,
        "Voltage Angle" => 11,
        "Power Generation Active" => 16,
        "Power Demand Active" => 12,
        "Power Injection Active" => 15
    )

    _fmt = Dict(
        "Voltage Angle" => "%*.4f",
        "Power Generation Active" => "%*.4f",
        "Power Demand Active" => "%*.4f",
        "Power Injection Active" => "%*.4f"
    )

    _show = Dict(
        "Voltage Angle" => true,
        "Power Generation Active" => !isempty(power.supply.active),
        "Power Demand Active" => !isempty(power.injection.active),
        "Power Injection Active" => !isempty(power.injection.active),
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

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

    hasMorePrint(width, show, "Bus Data")

    return fmt, width, show
end

"""
    printBranchData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, fmt, width, show)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.

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
fmt = Dict("From-Bus Power Active" => "%.2f", "From-Bus Power Reactive" => "%.2f")
show = Dict("From-Bus Power Reactive" => false, "To-Bus Power Reactive" => false)
printBranchData(system, analysis; fmt, show)

# Print data for specific branches
width = Dict("From-Bus Power Active" => 7, "To-Bus Power Active" => 7)
printBranchData(system, analysis; label = 2, width, header = true)
printBranchData(system, analysis; label = 10, width)
printBranchData(system, analysis; label = 12, width)
printBranchData(system, analysis; label = 14, width, footer = true)
```
"""
function printBranchData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBranchData(system, analysis, label, scale, prefix, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Branch Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtFromPow = printf(io, width, show, "From-Bus Power Active", "From-Bus Power Reactive", "From-Bus Power")
        fmtToPow = printf(io, width, show, "To-Bus Power Active", "To-Bus Power Reactive", "To-Bus Power")
        fmtShuPow = printf(io, width, show, "Shunt Power Active", "Shunt Power Reactive", "Shunt Power")
        fmtSerPow = printf(io, width, show, "Series Power Active", "Series Power Reactive", "Series Power")
        fmtFromCur = printf(io, width, show, "From-Bus Current Magnitude", "From-Bus Current Angle", "From-Bus Current")
        fmtToCur = printf(io, width, show, "To-Bus Current Magnitude", "To-Bus Current Angle", "To-Bus Current")
        fmtSerCur = printf(io, width, show, "Series Current Magnitude", "Series Current Angle", "Series Current")
        fmtStatus = printf(io, width, show, "Status", "Status")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFromPow[1], width, show, "From-Bus Power Active", "", "From-Bus Power Reactive", "")
        printf(io, fmtToPow[1], width, show, "To-Bus Power Active", "", "To-Bus Power Reactive", "")
        printf(io, fmtShuPow[1], width, show, "Shunt Power Active", "", "Shunt Power Reactive", "")
        printf(io, fmtSerPow[1], width, show, "Series Power Active", "", "Series Power Reactive", "")
        printf(io, fmtFromCur[1], width, show, "From-Bus Current Magnitude", "", "From-Bus Current Angle", "")
        printf(io, fmtToCur[1], width, show, "To-Bus Current Magnitude", "", "To-Bus Current Angle", "")
        printf(io, fmtSerCur[1], width, show, "Series Current Magnitude", "", "Series Current Angle", "")
        printf(io, fmtStatus[1], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFromPow[2], width, show, "From-Bus Power Active", "Active", "From-Bus Power Reactive", "Reactive")
        printf(io, fmtToPow[2], width, show, "To-Bus Power Active", "Active", "To-Bus Power Reactive", "Reactive")
        printf(io, fmtShuPow[2], width, show, "Shunt Power Active", "Active", "Shunt Power Reactive", "Reactive")
        printf(io, fmtSerPow[2], width, show, "Series Power Active", "Active", "Series Power Reactive", "Reactive")
        printf(io, fmtFromCur[2], width, show, "From-Bus Current Magnitude", "Magnitude", "From-Bus Current Angle", "Angle")
        printf(io, fmtToCur[2], width, show, "To-Bus Current Magnitude", "Magnitude", "To-Bus Current Angle", "Angle")
        printf(io, fmtSerCur[2], width, show, "Series Current Magnitude", "Magnitude", "Series Current Angle", "Angle")
        printf(io, fmtStatus[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFromPow[2], width, show, "From-Bus Power Active", unitData["P"], "From-Bus Power Reactive", unitData["Q"])
        printf(io, fmtToPow[2], width, show, "To-Bus Power Active", unitData["P"], "To-Bus Power Reactive", unitData["Q"])
        printf(io, fmtShuPow[2], width, show, "Shunt Power Active", unitData["P"], "Shunt Power Reactive", unitData["Q"])
        printf(io, fmtSerPow[2], width, show, "Series Power Active", unitData["P"], "Series Power Reactive", unitData["Q"])
        printf(io, fmtFromCur[2], width, show, "From-Bus Current Magnitude", unitData["I"], "From-Bus Current Angle", unitData["ψ"])
        printf(io, fmtToCur[2], width, show, "To-Bus Current Magnitude", unitData["I"], "To-Bus Current Angle", unitData["ψ"])
        printf(io, fmtSerCur[2], width, show, "Series Current Magnitude", unitData["I"], "Series Current Angle", unitData["ψ"])
        printf(io, fmtStatus[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtFromPow[3], width, show, "From-Bus Power Active", "-"^width["From-Bus Power Active"], "From-Bus Power Reactive", "-"^width["From-Bus Power Reactive"])
        printf(io, fmtToPow[3], width, show, "To-Bus Power Active", "-"^width["To-Bus Power Active"], "To-Bus Power Reactive", "-"^width["To-Bus Power Reactive"])
        printf(io, fmtShuPow[3], width, show, "Shunt Power Active", "-"^width["Shunt Power Active"], "Shunt Power Reactive", "-"^width["Shunt Power Reactive"])
        printf(io, fmtSerPow[3], width, show, "Series Power Active", "-"^width["Series Power Active"], "Series Power Reactive", "-"^width["Series Power Reactive"])
        printf(io, fmtFromCur[3], width, show, "From-Bus Current Magnitude", "-"^width["From-Bus Current Magnitude"], "From-Bus Current Angle", "-"^width["From-Bus Current Angle"])
        printf(io, fmtToCur[3], width, show, "To-Bus Current Magnitude", "-"^width["To-Bus Current Magnitude"], "To-Bus Current Angle", "-"^width["To-Bus Current Angle"])
        printf(io, fmtSerCur[3], width, show, "Series Current Magnitude", "-"^width["Series Current Magnitude"], "Series Current Angle", "-"^width["Series Current Angle"])
        printf(io, fmtStatus[3], width, show, "Status", "-"^width["Status"])
        @printf io "\n"

    elseif !isset(label)
            @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

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

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBranchData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})
    power = analysis.power
    current = analysis.current

    _width = Dict(
        "Label" => 5,
        "From-Bus Power Active" => 6,
        "From-Bus Power Reactive" => 8,
        "To-Bus Power Active" => 6,
        "To-Bus Power Reactive" => 8,
        "Shunt Power Active" => 6,
        "Shunt Power Reactive" => 8,
        "Series Power Active" => 6,
        "Series Power Reactive" => 8,
        "From-Bus Current Magnitude" => 9,
        "From-Bus Current Angle" => 5,
        "To-Bus Current Magnitude" => 9,
        "To-Bus Current Angle" => 5,
        "Series Current Magnitude" => 9,
        "Series Current Angle" => 5,
        "Status" => 6
    )

    _fmt = Dict(
        "From-Bus Power Active" => "%*.4f",
        "From-Bus Power Reactive" => "%*.4f",
        "To-Bus Power Active" => "%*.4f",
        "To-Bus Power Reactive" => "%*.4f",
        "Shunt Power Active" => "%*.4f",
        "Shunt Power Reactive" => "%*.4f",
        "Series Power Active" => "%*.4f",
        "Series Power Reactive" => "%*.4f",
        "From-Bus Current Magnitude" => "%*.4f",
        "From-Bus Current Angle" => "%*.4f",
        "To-Bus Current Magnitude" => "%*.4f",
        "To-Bus Current Angle" => "%*.4f",
        "Series Current Magnitude" => "%*.4f",
        "Series Current Angle" => "%*.4f",
        "Status" => "%*i"
    )

    _show = Dict(
        "From-Bus Power Active" => !isempty(power.from.active),
        "From-Bus Power Reactive" => !isempty(power.from.reactive),
        "To-Bus Power Active" => !isempty(power.to.active),
        "To-Bus Power Reactive" => !isempty(power.to.reactive),
        "Shunt Power Active" => !isempty(power.charging.active),
        "Shunt Power Reactive" => !isempty(power.charging.reactive),
        "Series Power Active" => !isempty(power.series.active),
        "Series Power Reactive" => !isempty(power.series.reactive),
        "From-Bus Current Magnitude" => !isempty(current.from.magnitude),
        "From-Bus Current Angle" => !isempty(current.from.angle),
        "To-Bus Current Magnitude" => !isempty(current.to.magnitude),
        "To-Bus Current Angle" => !isempty(current.to.angle),
        "Series Current Magnitude" => !isempty(current.series.magnitude),
        "Series Current Angle" => !isempty(current.series.angle),
        "Status" => true
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

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

    hasMorePrint(width, show, "Branch Data")
    titlemax(width, show, "From-Bus Power Active", "From-Bus Power Reactive", "From-Bus Power")
    titlemax(width, show, "To-Bus Power Active", "To-Bus Power Reactive", "To-Bus Power")
    titlemax(width, show, "Shunt Power Active", "Shunt Power Reactive", "Shunt Power")
    titlemax(width, show, "Series Power Active", "Series Power Reactive", "Series Power")
    titlemax(width, show, "From-Bus Current Magnitude", "From-Bus Current Angle", "From-Bus Current")
    titlemax(width, show, "To-Bus Current Magnitude", "To-Bus Current Angle", "To-Bus Current")
    titlemax(width, show, "Series Current Magnitude", "Series Current Angle", "Series Current")

    return fmt, width, show
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatBranchData(system, analysis, label, scale, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Branch Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtFr = printf(io, width, show, "From-Bus Power Active", "From-Bus Power")
        fmtTo = printf(io, width, show, "To-Bus Power Active", "To-Bus Power")
        fmtSt = printf(io, width, show, "Status", "Status")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFr[1], width, show, "From-Bus Power Active", "")
        printf(io, fmtTo[1], width, show, "To-Bus Power Active", "")
        printf(io, fmtSt[1], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFr[2], width, show, "From-Bus Power Active", "Active")
        printf(io, fmtTo[2], width, show, "To-Bus Power Active", "Active")
        printf(io, fmtSt[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtFr[2], width, show, "From-Bus Power Active", unitData["P"])
        printf(io, fmtTo[2], width, show, "To-Bus Power Active", unitData["P"])
        printf(io, fmtSt[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtFr[3], width, show, "From-Bus Power Active", "-"^width["From-Bus Power Active"])
        printf(io, fmtTo[3], width, show, "To-Bus Power Active", "-"^width["To-Bus Power Active"])
        printf(io, fmtSt[3], width, show, "Status", "-"^width["Status"])
        @printf io "\n"

    elseif !isset(label)
        @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))

        printf(io, pfmt, show, width, analysis.power.from.active, i, scale["P"], "From-Bus Power Active")
        printf(io, pfmt, show, width, analysis.power.to.active, i, scale["P"], "To-Bus Power Active")

        printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")

        @printf io "\n"
    end

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBranchData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64}, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})
    power = analysis.power

    _width = Dict(
        "Label" => 5,
        "From-Bus Power Active" => 14,
        "To-Bus Power Active" => 12,
        "Status" => 6
    )

    _fmt = Dict(
        "From-Bus Power Active" => "%*.4f",
        "To-Bus Power Active" => "%*.4f",
        "Status" => "%*i"
    )

    _show = Dict(
        "From-Bus Power Active" => !isempty(power.from.active),
        "To-Bus Power Active" => !isempty(power.to.active),
        "Status" => true
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

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

    hasMorePrint(width, show, "Branch Data")

    return fmt, width, show
end

"""
    printGeneratorData(system::PowerSystem, analysis::Analysis, [io::IO];
        label, header, footer, fmt, width, show)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.

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
fmt = Dict("Output Power Active" => "%.2f")
show = Dict("Output Power Reactive" => false)
printGeneratorData(system, analysis; fmt, show)

# Print data for specific generators
width = Dict("Output Power Active" => 7)
printGeneratorData(system, analysis; label = 1, width, header = true)
printGeneratorData(system, analysis; label = 4, width)
printGeneratorData(system, analysis; label = 5, width, footer = true)
```
"""
function printGeneratorData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatGeneratorData(system, analysis, label, scale, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Generator Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtOut = printf(io, width, show, "Output Power Active", "Output Power Reactive", "Output Power")
        fmtSta = printf(io, width, show, "Status", "Status")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[1], width, show, "Output Power Active", "", "Output Power Reactive", "")
        printf(io, fmtSta[1], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[2], width, show, "Output Power Active", "Active", "Output Power Reactive", "Reactive")
        printf(io, fmtSta[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[2], width, show, "Output Power Active", unitData["P"], "Output Power Reactive", unitData["Q"])
        printf(io, fmtSta[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtOut[3], width, show, "Output Power Active", "-"^width["Output Power Active"], "Output Power Reactive", "-"^width["Output Power Reactive"])
        printf(io, fmtSta[3], width, show, "Status", "-"^width["Status"])
        @printf io "\n"

    elseif !isset(label)
        @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))
        printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Output Power Active")
        printf(io, pfmt, show, width, analysis.power.generator.reactive, i, scale["Q"], "Output Power Reactive")
        printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")
        @printf io "\n"
    end

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::AC, label::L, scale::Dict{String, Float64}, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String,Bool})
    power = analysis.power

    _width = Dict(
        "Label" => 5,
        "Output Power Active" => 6,
        "Output Power Reactive" => 8,
        "Status" => 6
    )

    _fmt = Dict(
        "Output Power Active" => "%*.4f",
        "Output Power Reactive" => "%*.4f",
        "Status" => "%*i"
    )

    _show = Dict(
        "Output Power Active" => !isempty(power.generator.active),
        "Output Power Reactive" => !isempty(power.generator.reactive),
        "Status" => true
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

    if isset(label)
        label = getLabel(system.generator, label, "generator")
        i = system.generator.label[label]
        width["Label"] = max(textwidth(label), width["Label"])

        fmax(fmt, width, show, power.generator.active, i, scale["P"], "Output Power Active")
        fmax(fmt, width, show, power.generator.reactive, i, scale["Q"], "Output Power Reactive")
    else
        fminmax(fmt, width, show, power.generator.active, scale["P"], "Output Power Active")
        fminmax(fmt, width, show, power.generator.reactive, scale["Q"], "Output Power Reactive")

        @inbounds for (label, i) in system.generator.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    hasMorePrint(width, show, "Generator Data")
    titlemax(width, show, "Output Power Active", "Output Power Reactive", "Output Power")

    return fmt, width, show
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    fmt, width, show = formatGeneratorData(system, analysis, label, scale, fmt, width, show)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")
    maxLine, pfmt = setupPrintSystem(fmt, width, show)

    if header
        printTitle(io, maxLine, "Generator Data")

        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "")
        fmtOut = printf(io, width, show, "Output Power Active", "Output Power")
        fmtSta = printf(io, width, show, "Status", "Status")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[1], width, show, "Output Power Active", "")
        printf(io, fmtSta[1], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[2], width, show, "Output Power Active", "Active")
        printf(io, fmtSta[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "| %*s |", width["Label"], "")
        printf(io, fmtOut[2], width, show, "Output Power Active", unitData["P"])
        printf(io, fmtSta[2], width, show, "Status", "")
        @printf io "\n"

        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
        printf(io, fmtOut[3], width, show, "Output Power Active", "-"^width["Output Power Active"])
        printf(io, fmtSta[3], width, show, "Status", "-"^width["Status"])
        @printf io "\n"

    elseif !isset(label)
        @printf(io, "|%s|\n", "-"^maxLine)
    end

    @inbounds for (label, i) in labels
        print(io, format(pfmt["Label"], width["Label"], label))
        printf(io, pfmt, show, width, analysis.power.generator.active, i, scale["P"], "Output Power Active")
        printf(io, pfmt, show, width, system.branch.layout.status, i, "Status")
        @printf io "\n"
    end

    if !isset(label) || footer
        @printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatGeneratorData(system::PowerSystem, analysis::DC, label::L, scale::Dict{String, Float64}, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})
    power = analysis.power

    _width = Dict(
        "Label" => 5,
        "Output Power Active" => 12,
        "Status" => 6
    )

    _fmt = Dict(
        "Output Power Active" => "%*.4f",
        "Status" => "%*i"
    )

    _show = Dict(
        "Output Power Active" => !isempty(power.generator.active),
        "Status" => true
    )

    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)

    if isset(label)
        label = getLabel(system.generator, label, "generator")
        i = system.generator.label[label]
        width["Label"] = max(textwidth(label), width["Label"])

        fmax(fmt, width, show, power.generator.active, i, scale["P"], "Output Power Active")
    else
        fminmax(fmt, width, show, power.generator.active, scale["P"], "Output Power Active")

        @inbounds for (label, i) in system.generator.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    hasMorePrint(width, show, "Generator Data")

    return fmt, width, show
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

    @printf io "\n"

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
        "V" => SummaryData(title = "Bus Voltage"),
        "θ" => SummaryData(),
        "Ps" => SummaryData(title = "Power Generation"),
        "Qs" => SummaryData(),
        "Pl" => SummaryData(title = "Power Demand"),
        "Ql" => SummaryData(),
        "Pi" => SummaryData(title = "Power Injection"),
        "Qi" => SummaryData(),
        "Ph" => SummaryData(title = "Shunt Power"),
        "Qh" => SummaryData(),
        "I" => SummaryData(title = "Current Injection"),
        "ψ" => SummaryData(),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "supply" => 0,
        "demand" => 0,
        "shunt" => 0
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

    @printf io "\n"

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
        "θ" => SummaryData(title = "Bus Voltage"),
        "Ps" => SummaryData(title = "Power Generation"),
        "Pl" => SummaryData(title = "Power Demand"),
        "Pi" => SummaryData(title = "Power Injection"),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "supply" => 0,
        "demand" => 0,
        "shunt" => 0
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

    @printf io "\n"

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
        "Pline" => SummaryData(title = "Transmission Line Power"),
        "Qline" => SummaryData(),
        "Pintr" => SummaryData(title = "In-Phase Transformer Power"),
        "Qintr" => SummaryData(),
        "Pshtr" => SummaryData(title = "Phase-Shifting Transformer Power"),
        "Qshtr" => SummaryData(),
        "Ptie" => SummaryData(title = "Inter-Tie Power"),
        "Qtie" => SummaryData(),
        "Pshunt" => SummaryData(title = "Shunt Power"),
        "Qshunt" => SummaryData(),
        "Ploss" => SummaryData(title = "Series Power (Loss)"),
        "Qloss" => SummaryData(),
        "Iline" => SummaryData(title = "Transmission Line Current"),
        "ψline" => SummaryData(),
        "Iintr" => SummaryData(title = "In-Phase Transformer Current"),
        "ψintr" => SummaryData(),
        "Ishtr" => SummaryData(title = "Phase-Shifting Transformer Current"),
        "ψshtr" => SummaryData(),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "line" => 0,
        "inline" => 0,
        "shift" => 0,
        "inshift" => 0,
        "transformer" => 0,
        "intransformer" => 0,
        "shunt" => 0,
        "tie" => 0
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

    @printf io "\n"

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
        "Ptie" => SummaryData(title = "Inter-Tie Power"),
        "Pij" => SummaryData(),
        "Pji" => SummaryData(),
    )

    width = [0; 0; 0; 0; 5; 0]

    device = Dict(
        "line" => 0,
        "inline" => 0,
        "shift" => 0,
        "inshift" => 0,
        "transformer" => 0,
        "intransformer" => 0,
        "shunt" => 0,
        "tie" => 0
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

    @printf io "\n"

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
        "Pg" => SummaryData(title = "Output Power"),
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

    @printf io "\n"

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
        "Pg" => SummaryData(title = "Output Power"),
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

function printf(io::IO, fmt::Dict{String, Format}, show::Dict{String, Bool}, width::Dict{String, Int64}, vector::Array{Float64,1}, i::Int64, scale::Float64, key::String)
    if show[key]
        print(io, format(fmt[key], width[key], vector[i] * scale))
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

function printf(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, key1::String, key2::String, title::String)
    if show[key1] && show[key2]
        @printf(io, " %*s%s%*s |", floor(Int, (width[key1] + width[key2] - textwidth(title) + 3) / 2), "", title, ceil(Int, (width[key1] + width[key2] - textwidth(title) + 3) / 2) , "")
        pfmt1 = Format(" %*s   %*s |")
        pfmt2 = Format(" %*s | %*s |")
        pfmt3 = Format("-%*s-|-%*s-|")
    elseif show[key1]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, key1, title)
    elseif show[key2]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, key2, title)
    else
        pfmt1, pfmt2, pfmt3 = emptyFormat()
    end

    return pfmt1, pfmt2, pfmt3
end

function printf(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, key::String, title::String)
    if show[key]
        pfmt1, pfmt2, pfmt3 = singleprintf(io, width, key, title)
    else
        pfmt1, pfmt2, pfmt3 = emptyFormat()
    end

    return pfmt1, pfmt2, pfmt3
end

function singleprintf(io::IO, width::Dict{String, Int64}, key::String, title::String)
    @printf(io, " %*s%s%*s |", floor(Int, (width[key] - textwidth(title)) / 2), "", title, ceil(Int, (width[key] - textwidth(title)) / 2) , "")
    pfmt1 = Format(" %*s |")
    pfmt2 = Format(" %*s |")
    pfmt3 = Format("-%*s-|")

    return pfmt1, pfmt2, pfmt3
end

function emptyFormat()
    return Format(""), Format(""), Format("")
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

function printf(io::IO, fmt::Format, width::Dict{String, Int64}, show::Dict{String, Bool}, key::String, value::String)
    if show[key]
        print(io, format(fmt, width[key], value))
    end
end

function setupPrintSystem(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}; label = true, dash = false)
    pfmt = Dict{String, Format}()
    maxLine = 0

    if label
        pfmt["Label"] = Format("| %-*s |")
        maxLine += width["Label"] + 2
    end

    for (key, value) in show
        if value
            pfmt[key] = Format(" $(fmt[key]) |")
            maxLine += width[key] + 3
        end
    end

    if dash
        pfmt["Dash"] = Format(" %*s |")
    end

    return maxLine, pfmt
end