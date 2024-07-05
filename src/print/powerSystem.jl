"""
    printBusData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
printBusData(system, analysis; fmt)

# Print data for specific buses
width = Dict("Power Injection Active" => 8)
printBusData(system, analysis; label = 2, width, header = true)
printBusData(system, analysis; label = 10, width)
printBusData(system, analysis; label = 12, width)
printBusData(system, analysis; label = 14, width, footer = true)
```
"""
function printBusData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, powerFlag, currentFlag = formatBusData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")

    maxLine = width["Label"] + width["Voltage Magnitude"] + width["Voltage Angle"] + 8
    if powerFlag
        maxLine += width["Power Generation Active"] + width["Power Generation Reactive"] +
                   width["Power Demand Active"] + width["Power Demand Reactive"] +
                   width["Power Injection Active"] + width["Power Injection Reactive"] +
                   width["Shunt Power Active"] + width["Shunt Power Reactive"] + 24
    end
    if currentFlag
        maxLine += width["Current Injection Magnitude"] + width["Current Injection Angle"] + 6
    end

    printTitle(maxLine, "Bus Data", header, io)

    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)

        Printf.@printf(io, "| %*s%s%*s | %*s%s%*s |",
            floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"]  - 5) / 2) , "",
            floor(Int, (width["Voltage Magnitude"] + width["Voltage Angle"] - 4) / 2), "", "Voltage", ceil(Int, (width["Voltage Magnitude"] + width["Voltage Angle"] - 4) / 2) , "",
        )
        if powerFlag
            Printf.@printf(io, " %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s |",
                floor(Int, (width["Power Generation Active"] + width["Power Generation Reactive"] - 13) / 2), "", "Power Generation", ceil(Int, (width["Power Generation Active"] + width["Power Generation Reactive"] - 13) / 2) , "",
                floor(Int, (width["Power Demand Active"] + width["Power Demand Reactive"] - 9) / 2), "", "Power Demand", ceil(Int, (width["Power Demand Active"] + width["Power Demand Reactive"] - 9) / 2) , "",
                floor(Int, (width["Power Injection Active"] + width["Power Injection Reactive"] - 12) / 2), "", "Power Injection", ceil(Int, (width["Power Injection Active"] + width["Power Injection Reactive"] - 12) / 2) , "",
                floor(Int, (width["Shunt Power Active"] + width["Shunt Power Reactive"] - 8) / 2), "", "Shunt Power", ceil(Int, (width["Shunt Power Active"] + width["Shunt Power Reactive"] - 8) / 2) , "",
            )
        end
        if currentFlag
            Printf.@printf(io, " %*s%s%*s |",
                floor(Int, (width["Current Injection Magnitude"] + width["Current Injection Angle"] - 14) / 2), "", "Current Injection", ceil(Int, (width["Current Injection Magnitude"] + width["Current Injection Angle"] - 14) / 2) , ""
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s |",
            width["Label"], "",
            width["Voltage Magnitude"] + width["Voltage Angle"] + 3, "",
        )
        if powerFlag
            Printf.@printf(io, " %*s | %*s | %*s | %*s |",
                width["Power Generation Active"] + width["Power Generation Reactive"] + 3, "",
                width["Power Demand Active"] + width["Power Demand Reactive"] + 3, "",
                width["Power Injection Active"] + width["Power Injection Reactive"] + 3, "",
                width["Shunt Power Active"] + width["Shunt Power Reactive"] + 3, "",
            )
        end
        if currentFlag
            Printf.@printf(io, " %*s |",
                width["Current Injection Magnitude"] + width["Current Injection Angle"] + 3, "",
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s | %*s ",
            width["Label"], "",
            width["Voltage Magnitude"], "Magnitude",
            width["Voltage Angle"], "Angle",
        )
        if powerFlag
            Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                width["Power Generation Active"], "Active",
                width["Power Generation Reactive"], "Reactive",
                width["Power Demand Active"], "Active",
                width["Power Demand Reactive"], "Reactive",
                width["Power Injection Active"], "Active",
                width["Power Injection Reactive"], "Reactive",
                width["Shunt Power Active"], "Active",
                width["Shunt Power Reactive"], "Reactive",
            )
        end
        if currentFlag
            Printf.@printf(io, "| %*s | %*s ",
                width["Current Injection Magnitude"], "Magnitude",
                width["Current Injection Angle"], "Angle",
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "| %*s | %*s | %*s ",
            width["Label"], "",
            width["Voltage Magnitude"], unitData["V"],
            width["Voltage Angle"], unitData["θ"],
        )
        if powerFlag
            Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                width["Power Generation Active"], unitData["P"],
                width["Power Generation Reactive"], unitData["Q"],
                width["Power Demand Active"], unitData["P"],
                width["Power Demand Reactive"], unitData["Q"],
                width["Power Injection Active"], unitData["P"],
                width["Power Injection Reactive"], unitData["Q"],
                width["Shunt Power Active"], unitData["P"],
                width["Shunt Power Reactive"], unitData["Q"],
            )
        end
        if currentFlag
            Printf.@printf(io, "| %*s | %*s ",
                width["Current Injection Magnitude"], unitData["I"],
                width["Current Injection Angle"], unitData["ψ"],
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "|-%*s-|-%*s-|-%*s-",
            width["Label"], "-"^width["Label"],
            width["Voltage Magnitude"], "-"^width["Voltage Magnitude"],
            width["Voltage Angle"], "-"^width["Voltage Angle"],
        )
        if powerFlag
            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                width["Power Generation Active"], "-"^width["Power Generation Active"],
                width["Power Generation Reactive"], "-"^width["Power Generation Reactive"],
                width["Power Demand Active"], "-"^width["Power Demand Active"],
                width["Power Demand Reactive"], "-"^width["Power Demand Reactive"],
                width["Power Injection Active"], "-"^width["Power Injection Active"],
                width["Power Injection Reactive"], "-"^width["Power Injection Reactive"],
                width["Shunt Power Active"], "-"^width["Shunt Power Active"],
                width["Shunt Power Reactive"], "-"^width["Shunt Power Reactive"],
            )
        end
        if currentFlag
            Printf.@printf(io, "|-%*s-|-%*s-",
            width["Current Injection Magnitude"], "-"^width["Current Injection Magnitude"],
            width["Current Injection Angle"], "-"^width["Current Injection Angle"]
            )
        end
        Printf.@printf io "|\n"
    elseif !isset(label)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end

    for (label, i) in labels
        print(io, Printf.format(
            Printf.Format(
                "| %-*s | $(fmt["Voltage Magnitude"]) | $(fmt["Voltage Angle"]) "
            ),
            width["Label"], label,
            width["Voltage Magnitude"], analysis.voltage.magnitude[i] * scaleMagnitude(prefix, system.base.voltage, i),
            width["Voltage Angle"], analysis.voltage.angle[i] * scale["θ"])
        )

        if powerFlag
            print(io, Printf.format(
                Printf.Format(
                    "| $(fmt["Power Generation Active"]) | $(fmt["Power Generation Reactive"]) " *
                    "| $(fmt["Power Demand Active"]) | $(fmt["Power Demand Reactive"]) " *
                    "| $(fmt["Power Injection Active"]) | $(fmt["Power Injection Reactive"]) " *
                    "| $(fmt["Shunt Power Active"]) | $(fmt["Shunt Power Reactive"]) "
                ),
                width["Power Generation Active"], analysis.power.supply.active[i] * scale["P"],
                width["Power Generation Reactive"], analysis.power.supply.reactive[i] * scale["Q"],
                width["Power Demand Active"], system.bus.demand.active[i] * scale["P"],
                width["Power Demand Reactive"], system.bus.demand.reactive[i] * scale["Q"],
                width["Power Injection Active"], analysis.power.injection.active[i] * scale["P"],
                width["Power Injection Reactive"], analysis.power.injection.reactive[i] * scale["Q"],
                width["Shunt Power Active"], analysis.power.shunt.active[i] * scale["P"],
                width["Shunt Power Reactive"], analysis.power.shunt.reactive[i] * scale["Q"])
            )
        end
        if currentFlag
            print(io, Printf.format(
                Printf.Format(
                    "| $(fmt["Current Injection Magnitude"]) | $(fmt["Current Injection Angle"]) "
                ),
                width["Current Injection Magnitude"], analysis.current.injection.magnitude[i] * scaleMagnitude(prefix, system, i),
                width["Current Injection Angle"], analysis.current.injection.angle[i] * scale["ψ"])
            )
        end
        Printf.@printf io "|\n"
    end

    if !isset(label) || footer
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64}, fmt::Dict{String,String})
    errorVoltage(analysis.voltage.magnitude)

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

    width, fmt = printFormat(_width, width, _fmt, fmt)

    powerFlag = !isempty(analysis.power.injection.active)
    currentFlag = !isempty(analysis.current.injection.magnitude)

    if isset(label)
        label = getLabel(system.bus, label, "bus")
        i = system.bus.label[label]

        width["Label"] = max(textwidth(label), width["Label"])

        fmax(analysis.voltage.magnitude[i], scaleMagnitude(prefix, system.base.voltage, i), width, fmt, "Voltage Magnitude")
        fmax(analysis.voltage.angle[i], scale["θ"], width, fmt, "Voltage Angle")

        if powerFlag
            fmax(analysis.power.supply.active[i], scale["P"], width, fmt, "Power Generation Active")
            fmax(system.bus.demand.active[i], scale["P"], width, fmt, "Power Demand Active")
            fmax(analysis.power.injection.active[i], scale["P"], width, fmt, "Power Injection Active")
            fmax(analysis.power.shunt.active[i], scale["P"], width, fmt, "Shunt Power Active")

            fmax(analysis.power.supply.reactive[i], scale["Q"], width, fmt, "Power Generation Reactive")
            fmax(system.bus.demand.reactive[i], scale["Q"], width, fmt, "Power Demand Reactive")
            fmax(analysis.power.injection.reactive[i], scale["Q"], width, fmt, "Power Injection Reactive")
            fmax(analysis.power.shunt.reactive[i], scale["Q"], width, fmt, "Shunt Power Reactive")
        end

        if currentFlag
            fmax(analysis.current.injection.magnitude[i], scaleMagnitude(prefix, system, i), width, fmt, "Current Injection Magnitude")
            fmax(analysis.current.injection.angle[i], scale["ψ"], width, fmt, "Current Injection Angle")
        end
    else
        if prefix.voltageMagnitude == 0.0
            fmax(analysis.voltage.magnitude, 1.0, width, fmt, "Voltage Magnitude")
        end
        fminmax(analysis.voltage.angle, scale["θ"], width, fmt, "Voltage Angle")

        if powerFlag
            fminmax(analysis.power.supply.active, scale["P"], width, fmt, "Power Generation Active")
            fminmax(system.bus.demand.active, scale["P"], width, fmt, "Power Demand Active")
            fminmax(analysis.power.injection.active, scale["P"], width, fmt, "Power Injection Active")
            fminmax(analysis.power.shunt.active, scale["P"], width, fmt, "Shunt Power Active")

            fminmax(analysis.power.supply.reactive, scale["Q"], width, fmt, "Power Generation Reactive")
            fminmax(system.bus.demand.reactive, scale["Q"], width, fmt, "Power Demand Reactive")
            fminmax(analysis.power.injection.reactive, scale["Q"], width, fmt, "Power Injection Reactive")
            fminmax(analysis.power.shunt.reactive, scale["Q"], width, fmt, "Shunt Power Reactive")
        end

        if currentFlag
            if prefix.currentMagnitude == 0.0
                fmax(analysis.current.injection.magnitude, 1.0, width, fmt, "Current Injection Magnitude")
            end
            fminmax(analysis.current.injection.angle, scale["ψ"], width, fmt, "Current Injection Angle")
        end

        @inbounds for (label, i) in system.bus.label
            width["Label"] = max(textwidth(label), width["Label"])

            if prefix.voltageMagnitude != 0.0
                fmax(analysis.voltage.magnitude[i], scaleMagnitude(system.base.voltage, i), width, fmt, "Voltage Magnitude")
            end

            if currentFlag && prefix.currentMagnitude != 0.0
                fmax(analysis.current.injection.magnitude[i], scaleMagnitude(system, i), width, fmt, "Current Injection Magnitude")
            end
        end
    end

    return width, fmt, powerFlag, currentFlag
end

function printBusData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, flag = formatBusData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")

    maxLine = width["Label"] + width["Voltage Angle"] + 5
    if flag
        maxLine += width["Power Generation Active"] + width["Power Demand Active"] +
            width["Power Injection Active"] + 9
    end

    printTitle(maxLine, "Bus Data", header, io)

    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)

        Printf.@printf(io, "| %*s%s%*s | %*s |",
            floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "",
            width["Voltage Angle"], "Voltage",
        )

        if flag
            Printf.@printf(io, " %*s | %*s | %*s |",
                width["Power Generation Active"], "Power Generation",
                width["Power Demand Active"], "Power Demand",
                width["Power Injection Active"], "Power Injection",
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s ",
            width["Label"], "",
            width["Voltage Angle"], "Angle $(unitData["θ"])",
        )
        if flag
            Printf.@printf(io, "| %*s | %*s | %*s ",
                width["Power Generation Active"], "Active $(unitData["P"])",
                width["Power Demand Active"], "Active $(unitData["P"])",
                width["Power Injection Active"], "Active $(unitData["P"])",
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "|-%*s-|-%*s-",
            width["Label"], "-"^width["Label"],
            width["Voltage Angle"], "-"^width["Voltage Angle"],
        )
        if flag
            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-",
                width["Power Generation Active"], "-"^width["Power Generation Active"],
                width["Power Demand Active"], "-"^width["Power Demand Active"],
                width["Power Injection Active"], "-"^width["Power Injection Active"],
            )
        end
        Printf.@printf io "|\n"
    elseif !isset(label)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end

    for (label, i) in labels
        print(io, Printf.format(
            Printf.Format(
                "| %-*s | $(fmt["Voltage Angle"]) "
            ),
            width["Label"], label,
            width["Voltage Angle"], analysis.voltage.angle[i] * scale["θ"])
        )

        if flag
            print(io, Printf.format(
                Printf.Format(
                    "| $(fmt["Power Generation Active"]) | $(fmt["Power Demand Active"]) | $(fmt["Power Injection Active"]) "
                ),
                width["Power Generation Active"], analysis.power.supply.active[i] * scale["P"],
                width["Power Demand Active"], system.bus.demand.active[i] * scale["P"],
                width["Power Injection Active"], analysis.power.injection.active[i] * scale["P"])
            )
        end
        Printf.@printf io "|\n"
    end

    if !isset(label) || footer
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

function formatBusData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String, Int64}, fmt::Dict{String, String})
    errorVoltage(analysis.voltage.angle)

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

    width, fmt = printFormat(_width, width, _fmt, fmt)
    powerFlag = !isempty(analysis.power.injection.active)

    if isset(label)
        label = getLabel(system.bus, label, "bus")
        i = system.bus.label[label]

        width["Label"] = max(textwidth(label), width["Label"])
        fmax(analysis.voltage.angle[i], scale["θ"], width, fmt, "Voltage Angle")

        if powerFlag
            fmax(analysis.power.supply.active[i], scale["P"], width, fmt, "Power Generation Active")
            fmax(system.bus.demand.active[i], scale["P"], width, fmt, "Power Demand Active")
            fmax(analysis.power.injection.active[i], scale["P"], width, fmt, "Power Injection Active")
        end
    else
        fminmax(analysis.voltage.angle, scale["θ"], width, fmt, "Voltage Angle")

        if powerFlag
            fminmax(analysis.power.supply.active, scale["P"], width, fmt, "Power Generation Active")
            fminmax(system.bus.demand.active, scale["P"], width, fmt, "Power Demand Active")
            fminmax(analysis.power.injection.active, scale["P"], width, fmt, "Power Injection Active")
        end

        @inbounds for (label, i) in system.bus.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    return width, fmt, powerFlag
end

"""
    printBranchData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
printBranchData(system, analysis; fmt)

# Print data for specific branches
width = Dict("From-Bus Power Active" => 7, "To-Bus Power Active" => 7)
printBranchData(system, analysis; label = 2, width, header = true)
printBranchData(system, analysis; label = 10, width)
printBranchData(system, analysis; label = 12, width)
printBranchData(system, analysis; label = 14, width, footer = true)
```
"""
function printBranchData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, powerFlag, currentFlag = formatBranchData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")

    if powerFlag || currentFlag
        maxLine = width["Label"] + width["Status"] + 5
        if powerFlag
            maxLine += width["From-Bus Power Active"] + width["From-Bus Power Reactive"] +
                       width["To-Bus Power Active"] + width["To-Bus Power Reactive"] +
                       width["Shunt Power Active"] + width["Shunt Power Reactive"] +
                       width["Series Power Active"] + width["Series Power Reactive"] + 24
        end
        if currentFlag
            maxLine += width["From-Bus Current Magnitude"] + width["From-Bus Current Angle"] +
                       width["To-Bus Current Magnitude"] + width["To-Bus Current Angle"] +
                       width["Series Current Magnitude"] + width["Series Current Angle"] + 18
        end

        printTitle(maxLine, "Branch Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s ", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "",)

            if powerFlag
                Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                    floor(Int, (width["From-Bus Power Active"] + width["From-Bus Power Reactive"] - 11) / 2), "", "From-Bus Power", ceil(Int, (width["From-Bus Power Active"] + width["From-Bus Power Reactive"] - 11) / 2) , "",
                    floor(Int, (width["To-Bus Power Active"] + width["To-Bus Power Reactive"] - 9) / 2), "", "To-Bus Power", ceil(Int, (width["To-Bus Power Active"] + width["To-Bus Power Reactive"] - 9) / 2) , "",
                    floor(Int, (width["Shunt Power Active"] + width["Shunt Power Reactive"] - 8) / 2), "", "Shunt Power", ceil(Int, (width["Shunt Power Active"] + width["Shunt Power Reactive"] - 8) / 2) , "",
                    floor(Int, (width["Series Power Active"] + width["Series Power Reactive"] - 9) / 2), "", "Series Power", ceil(Int, (width["Series Power Active"] + width["Series Power Reactive"] - 9) / 2) , "",
                )
            end
            if currentFlag
                Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                    floor(Int, (width["From-Bus Current Magnitude"] + width["From-Bus Current Angle"] - 13) / 2), "", "From-Bus Current", ceil(Int, (width["From-Bus Current Magnitude"] + width["From-Bus Current Angle"] - 13) / 2) , "",
                    floor(Int, (width["To-Bus Current Magnitude"] + width["To-Bus Current Angle"] - 11) / 2), "", "To-Bus Current", ceil(Int, (width["To-Bus Current Magnitude"] + width["To-Bus Current Angle"] - 11) / 2) , "",
                    floor(Int, (width["Series Current Magnitude"] + width["Series Current Angle"] - 11) / 2), "", "Series Current", ceil(Int, (width["Series Current Magnitude"] + width["Series Current Angle"] - 11) / 2) , "",
                )
            end
            Printf.@printf io "| %s |\n" "Status"

            Printf.@printf(io, "| %*s |",
                width["Label"], "",
            )
            if powerFlag
                Printf.@printf(io, " %*s | %*s | %*s | %*s |",
                    width["From-Bus Power Active"] + width["From-Bus Power Reactive"] + 3, "",
                    width["To-Bus Power Active"] + width["To-Bus Power Reactive"] + 3, "",
                    width["Shunt Power Active"] + width["Shunt Power Reactive"] + 3, "",
                    width["Series Power Active"] + width["Series Power Reactive"] + 3, "",
                )
            end
            if currentFlag
                Printf.@printf(io, " %*s | %*s | %*s |",
                    width["From-Bus Current Magnitude"] + width["From-Bus Current Angle"] + 3, "",
                    width["To-Bus Current Magnitude"] + width["To-Bus Current Angle"] + 3, "",
                    width["Series Current Magnitude"] + width["Series Current Angle"] + 3, "",
                )
            end
            Printf.@printf io " %*s |\n" width["Status"] ""

            Printf.@printf(io, "| %*s ", width["Label"], "")

            if powerFlag
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                    width["From-Bus Power Active"], "Active",
                    width["From-Bus Power Reactive"], "Reactive",
                    width["To-Bus Power Active"], "Active",
                    width["To-Bus Power Reactive"], "Reactive",
                    width["Shunt Power Active"], "Active",
                    width["Shunt Power Reactive"], "Reactive",
                    width["Series Power Active"], "Active",
                    width["Series Power Reactive"], "Reactive",
                )
            end
            if currentFlag
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s ",
                    width["From-Bus Current Magnitude"], "Magnitude",
                    width["From-Bus Current Angle"], "Angle",
                    width["To-Bus Current Magnitude"], "Magnitude",
                    width["To-Bus Current Angle"], "Angle",
                    width["Series Current Magnitude"], "Magnitude",
                    width["Series Current Angle"], "Angle",
                )
            end
            Printf.@printf io "| %*s |\n" width["Status"] ""

            Printf.@printf(io, "| %*s ", width["Label"], "")

            if powerFlag
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                    width["From-Bus Power Active"], unitData["P"],
                    width["From-Bus Power Reactive"], unitData["Q"],
                    width["To-Bus Power Active"], unitData["P"],
                    width["To-Bus Power Reactive"], unitData["Q"],
                    width["Shunt Power Active"], unitData["P"],
                    width["Shunt Power Reactive"], unitData["Q"],
                    width["Series Power Active"], unitData["P"],
                    width["Series Power Reactive"], unitData["Q"],
                )
            end
            if currentFlag
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s ",
                    width["From-Bus Current Magnitude"], unitData["I"],
                    width["From-Bus Current Angle"], unitData["ψ"],
                    width["To-Bus Current Magnitude"], unitData["I"],
                    width["To-Bus Current Angle"], unitData["ψ"],
                    width["Series Current Magnitude"], unitData["I"],
                    width["Series Current Angle"], unitData["ψ"],
                )
            end
            Printf.@printf io "| %*s |\n" width["Status"] ""

            Printf.@printf(io, "|-%*s-", width["Label"], "-"^width["Label"]
            )
            if powerFlag
                Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                    width["From-Bus Power Active"], "-"^width["From-Bus Power Active"],
                    width["From-Bus Power Reactive"], "-"^width["From-Bus Power Reactive"],
                    width["To-Bus Power Active"], "-"^width["To-Bus Power Active"],
                    width["To-Bus Power Reactive"], "-"^width["To-Bus Power Reactive"],
                    width["Shunt Power Active"], "-"^width["Shunt Power Active"],
                    width["Shunt Power Reactive"], "-"^width["Shunt Power Reactive"],
                    width["Series Power Active"], "-"^width["Series Power Active"],
                    width["Series Power Reactive"], "-"^width["Series Power Reactive"],
                )
            end
            if currentFlag
                Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                    width["From-Bus Current Magnitude"], "-"^width["From-Bus Current Magnitude"],
                    width["From-Bus Current Angle"], "-"^width["From-Bus Current Angle"],
                    width["To-Bus Current Magnitude"], "-"^width["To-Bus Current Magnitude"],
                    width["To-Bus Current Angle"], "-"^width["To-Bus Current Angle"],
                    width["Series Current Magnitude"], "-"^width["Series Current Magnitude"],
                    width["Series Current Angle"], "-"^width["Series Current Angle"],
                )
            end
            Printf.@printf io "|-%*s-|\n" width["Status"] "-"^width["Status"]
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            Printf.@printf(io, "| %-*s ", width["Label"], label)

            if powerFlag
                print(io, Printf.format(
                    Printf.Format(
                        "| $(fmt["From-Bus Power Active"]) | $(fmt["From-Bus Power Reactive"]) " *
                        "| $(fmt["To-Bus Power Active"]) | $(fmt["To-Bus Power Reactive"]) " *
                        "| $(fmt["Shunt Power Active"]) | $(fmt["Shunt Power Reactive"]) " *
                        "| $(fmt["Series Power Active"]) | $(fmt["Series Power Reactive"]) "
                    ),
                    width["From-Bus Power Active"], analysis.power.from.active[i] * scale["P"],
                    width["From-Bus Power Reactive"], analysis.power.from.reactive[i] * scale["Q"],
                    width["To-Bus Power Active"], analysis.power.to.active[i] * scale["P"],
                    width["To-Bus Power Reactive"], analysis.power.to.reactive[i] * scale["Q"],
                    width["Shunt Power Active"], analysis.power.charging.active[i] * scale["P"],
                    width["Shunt Power Reactive"], analysis.power.charging.reactive[i] * scale["Q"],
                    width["Series Power Active"], analysis.power.series.active[i] * scale["P"],
                    width["Series Power Reactive"], analysis.power.series.reactive[i] * scale["Q"])
                )
            end

            if currentFlag
                print(io, Printf.format(
                    Printf.Format(
                        "| $(fmt["From-Bus Current Magnitude"]) | $(fmt["From-Bus Current Angle"]) " *
                        "| $(fmt["To-Bus Current Magnitude"]) | $(fmt["To-Bus Current Angle"]) " *
                        "| $(fmt["Series Current Magnitude"]) | $(fmt["Series Current Angle"]) "
                    ),
                    width["From-Bus Current Magnitude"], analysis.current.from.magnitude[i] * scaleMagnitude(prefix, system, system.branch.layout.from[i]),
                    width["From-Bus Current Angle"], analysis.current.from.angle[i] * scale["ψ"],
                    width["To-Bus Current Magnitude"], analysis.current.to.magnitude[i] * scaleMagnitude(prefix, system, system.branch.layout.to[i]),
                    width["To-Bus Current Angle"], analysis.current.to.angle[i] * scale["ψ"],
                    width["Series Current Magnitude"], analysis.current.series.magnitude[i] * scaleMagnitude(prefix, system, system.branch.layout.from[i]),
                    width["Series Current Angle"], analysis.current.series.angle[i] * scale["ψ"])
                )
            end

            Printf.@printf(io, "| %*i |\n", width["Status"], system.branch.layout.status[i])
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatBranchData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String, Int64}, fmt::Dict{String, String})
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
        "Series Current Angle" => "%*.4f"
    )

    width, fmt = printFormat(_width, width, _fmt, fmt)

    powerFlag = !isempty(analysis.power.from.active)
    currentFlag = !isempty(analysis.current.from.magnitude)

    if isset(label)
        label = getLabel(system.branch, label, "branch")
        i = system.branch.label[label]

        width["Label"] = max(textwidth(label), width["Label"])

        if powerFlag
            fmax(analysis.power.from.active[i], scale["P"], width, fmt, "From-Bus Power Active")
            fmax(analysis.power.to.active[i], scale["P"], width, fmt, "To-Bus Power Active")
            fmax(analysis.power.charging.active[i], scale["P"], width, fmt, "Shunt Power Active")
            fmax(analysis.power.series.active[i], scale["P"], width, fmt, "Series Power Active")

            fmax(analysis.power.from.reactive[i], scale["Q"], width, fmt, "From-Bus Power Reactive")
            fmax(analysis.power.to.reactive[i], scale["Q"], width, fmt, "To-Bus Power Reactive")
            fmax(analysis.power.charging.reactive[i], scale["Q"], width, fmt, "Shunt Power Reactive")
            fmax( analysis.power.series.reactive[i], scale["Q"], width, fmt, "Series Power Reactive")
        end

        if currentFlag
            fmax(analysis.current.from.magnitude[i], scaleMagnitude(prefix, system, system.branch.layout.from[i]), width, fmt, "From-Bus Current Magnitude")
            fmax(analysis.current.to.magnitude[i], scaleMagnitude(prefix, system, system.branch.layout.to[i]), width, fmt, "To-Bus Current Magnitude")
            fmax(analysis.current.series.magnitude[i], scaleMagnitude(prefix, system, system.branch.layout.from[i]), width, fmt, "Series Current Magnitude")

            fmax(analysis.current.from.angle[i], scale["ψ"], width, fmt, "From-Bus Current Angle")
            fmax(analysis.current.to.angle[i], scale["ψ"], width, fmt, "To-Bus Current Angle")
            fmax(analysis.current.series.angle[i], scale["ψ"], width, fmt, "Series Current Angle")
        end
    else
        if powerFlag
            fminmax(analysis.power.from.active, scale["P"], width, fmt, "From-Bus Power Active")
            fminmax(analysis.power.to.active, scale["P"], width, fmt, "To-Bus Power Active")
            fminmax(analysis.power.charging.active, scale["P"], width, fmt, "Shunt Power Active")
            fminmax(analysis.power.series.active, scale["P"], width, fmt, "Series Power Active")

            fminmax(analysis.power.from.reactive, scale["Q"], width, fmt, "From-Bus Power Reactive")
            fminmax(analysis.power.to.reactive, scale["Q"], width, fmt, "To-Bus Power Reactive")
            fminmax(analysis.power.charging.reactive, scale["Q"], width, fmt, "Shunt Power Reactive")
            fminmax( analysis.power.series.reactive, scale["Q"], width, fmt, "Series Power Reactive")
        end

        if currentFlag
            if prefix.currentMagnitude == 0.0
                fmax(analysis.current.from.magnitude, 1.0, width, fmt, "From-Bus Current Magnitude")
                fmax(analysis.current.to.magnitude, 1.0, width, fmt, "To-Bus Current Magnitude")
                fmax(analysis.current.series.magnitude, 1.0, width, fmt, "Series Current Magnitude")
            end
            fminmax(analysis.current.from.angle, scale["ψ"], width, fmt, "From-Bus Current Angle")
            fminmax(analysis.current.to.angle, scale["ψ"], width, fmt, "To-Bus Current Angle")
            fminmax(analysis.current.series.angle, scale["ψ"], width, fmt, "Series Current Angle")
        end

        @inbounds for (label, i) in system.branch.label
            width["Label"] = max(textwidth(label), width["Label"])

            if currentFlag && prefix.currentMagnitude != 0.0
                fmax(analysis.current.from.magnitude[i], scaleMagnitude(system, system.branch.layout.from[i]), width, fmt, "From-Bus Current Magnitude")
                fmax(analysis.current.series.magnitude[i], scaleMagnitude(system, system.branch.layout.from[i]), width, fmt, "Series Current Magnitude")
                fmax(analysis.current.to.magnitude[i], scaleMagnitude(system, system.branch.layout.to[i]), width, fmt, "To-Bus Current Magnitude")
            end
        end
    end

    return width, fmt, powerFlag, currentFlag
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, flag = formatBranchData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")

    if flag
        maxLine = width["Label"] + width["From-Bus Power Active"] + width["To-Bus Power Active"] + width["Status"] + 11

        printTitle(maxLine, "Branch Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s | %*s | %*s |\n",
                floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "",
                width["From-Bus Power Active"], "From-Bus Power",
                width["To-Bus Power Active"], "To-Bus Power",
                width["Status"], "Status",
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                width["Label"], "",
                width["From-Bus Power Active"], "Active $(unitData["P"])",
                width["To-Bus Power Active"], "Active $(unitData["P"])",
                width["Status"], "",
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|\n",
                width["Label"], "-"^width["Label"],
                width["From-Bus Power Active"], "-"^width["From-Bus Power Active"],
                width["To-Bus Power Active"], "-"^width["To-Bus Power Active"],
                width["Status"], "-"^width["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            print(io, Printf.format(
                Printf.Format(
                    "| %-*s | $(fmt["From-Bus Power Active"]) | $(fmt["To-Bus Power Active"]) | %*i |\n"
                ),
                width["Label"], label,
                width["From-Bus Power Active"], analysis.power.from.active[i] * scale["P"],
                width["To-Bus Power Active"], analysis.power.to.active[i] * scale["P"],
                width["Status"], system.branch.layout.status[i])
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatBranchData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String, Int64}, fmt::Dict{String, String})
    _width = Dict(
        "Label" => 5,
        "From-Bus Power Active" => 14,
        "To-Bus Power Active" => 12,
        "Status" => 6
    )

    _fmt = Dict(
        "From-Bus Power Active" => "%*.4f",
        "To-Bus Power Active" => "%*.4f"
    )

    width, fmt = printFormat(_width, width, _fmt, fmt)
    flag = !isempty(analysis.power.from.active)

    if isset(label)
        label = getLabel(system.branch, label, "branch")
        i = system.branch.label[label]

        width["Label"] = max(textwidth(label), width["Label"])

        fmax(analysis.power.from.active[i], scale["P"], width, fmt, "From-Bus Power Active")
        fmax(analysis.power.to.active[i], scale["P"], width, fmt, "To-Bus Power Active")
    else
        if flag
            fminmax(analysis.power.from.active, scale["P"], width, fmt, "From-Bus Power Active")
            fminmax(analysis.power.to.active, scale["P"], width, fmt, "To-Bus Power Active")
        end

        @inbounds for (label, i) in system.branch.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    return width, fmt, flag
end

"""
    printGeneratorData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
printGeneratorData(system, analysis; fmt)

# Print data for specific generators
width = Dict("Output Power Active" => 7)
printGeneratorData(system, analysis; label = 1, width, header = true)
printGeneratorData(system, analysis; label = 4, width)
printGeneratorData(system, analysis; label = 5, width, footer = true)
```
"""
function printGeneratorData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, flag = formatGeneratorData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")

    if flag
        maxLine = width["Label"] + width["Output Power Active"] + width["Output Power Reactive"] + width["Status"] + 11
        printTitle(maxLine, "Generator Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %s |\n",
                floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "",
                floor(Int, (width["Output Power Active"] + width["Output Power Reactive"] - 9) / 2), "", "Output Power", ceil(Int, (width["Output Power Active"] + width["Output Power Reactive"] - 9) / 2) , "",
                "Status"
            )

            Printf.@printf(io, "| %*s | %*s | %*s |\n",
                width["Label"], "",
                width["Output Power Active"] + width["Output Power Reactive"] + 3, "",
                width["Status"], ""
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                width["Label"], "",
                width["Output Power Active"], "Active",
                width["Output Power Reactive"], "Reactive",
                width["Status"], ""
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                width["Label"], "",
                width["Output Power Active"], unitData["P"],
                width["Output Power Reactive"], unitData["Q"],
                width["Status"], ""
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|\n",
                width["Label"], "-"^width["Label"],
                width["Output Power Active"], "-"^width["Output Power Active"],
                width["Output Power Reactive"], "-"^width["Output Power Reactive"],
                width["Status"], "-"^width["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            print(io, Printf.format(
                Printf.Format(
                    "| %-*s | $(fmt["Output Power Active"]) | $(fmt["Output Power Reactive"]) | %*i |\n"
                ),
                width["Label"], label,
                width["Output Power Active"], analysis.power.generator.active[i] * scale["P"],
                width["Output Power Reactive"], analysis.power.generator.reactive[i] * scale["Q"],
                width["Status"], system.generator.layout.status[i])
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatGeneratorData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String, Int64}, fmt::Dict{String,String})
    _width = Dict(
        "Label" => 5,
        "Output Power Active" => 6,
        "Output Power Reactive" => 8,
        "Status" => 6
    )

    _fmt = Dict(
        "Output Power Active" => "%*.4f",
        "Output Power Reactive" => "%*.4f"
    )

    width, fmt = printFormat(_width, width, _fmt, fmt)
    flag = !isempty(analysis.power.generator.active)

    if isset(label)
        label = getLabel(system.generator, label, "generator")
        i = system.generator.label[label]

        width["Label"] = max(textwidth(label), width["Label"])

        if flag
            fmax(analysis.power.generator.active[i], scale["P"], width, fmt, "Output Power Active")
            fmax(analysis.power.generator.reactive[i], scale["Q"], width, fmt, "Output Power Reactive")
        end
    else
        if flag
            fminmax(analysis.power.generator.active, scale["P"], width, fmt, "Output Power Active")
            fminmax(analysis.power.generator.reactive, scale["Q"], width, fmt, "Output Power Reactive")
        end

        @inbounds for (label, i) in system.generator.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    return width, fmt, flag
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    scale = printScale(system, prefix)
    unitData = printUnitData(unitList)
    width, fmt, flag = formatGeneratorData(system, analysis, scale, label, width, fmt)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")

    if flag
        maxLine = width["Label"] + width["Output Power Active"] + width["Status"] + 8
        printTitle(maxLine, "Generator Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s | %s |\n",
                floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , "",
                width["Output Power Active"], "Output Power",
                "Status"
            )

            Printf.@printf(io, "| %*s | %*s | %*s |\n",
                width["Label"], "",
                width["Output Power Active"], "Active $(unitData["P"])",
                width["Status"], "",
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|\n",
                width["Label"], "-"^width["Label"],
                width["Output Power Active"], "-"^width["Output Power Active"],
                width["Status"], "-"^width["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            print(io, Printf.format(
                Printf.Format(
                    "| %-*s | $(fmt["Output Power Active"]) | %*i |\n"
                ),
                width["Label"], label,
                width["Output Power Active"], analysis.power.generator.active[i] * scale["P"],
                width["Status"], system.generator.layout.status[i])
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatGeneratorData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String, Int64}, fmt::Dict{String, String})
    _width = Dict(
        "Label" => 5,
        "Output Power Active" => 12,
        "Status" => 6
    )

    _fmt = Dict(
        "Output Power Active" => "%*.4f"
    )

    width, fmt = printFormat(_width, width, _fmt, fmt)
    flag = !isempty(analysis.power.generator.active)

    if isset(label)
        label = getLabel(system.generator, label, "generator")
        i = system.generator.label[label]

        width["Label"] = max(textwidth(label), width["Label"])

        if flag
            fmax(analysis.power.generator.active[i], scale["P"], width, fmt, "Output Power Active")
        end
    else
        if flag
            fminmax(analysis.power.generator.active, scale["P"], width, fmt, "Output Power Active")
        end

        @inbounds for (label, i) in system.generator.label
            width["Label"] = max(textwidth(label), width["Label"])
        end
    end

    return width, fmt, flag
end

"""
    printBusSummary(system::PowerSystem, analysis::Analysis, io::IO)

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
    format, unitLive = formatBusSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(format["device"][1]) $(plosg("bus", format["device"][1])),
        while loads are installed at $(format["device"][2]) $(plosg("bus", format["device"][2])),
        and shunts are present at $(format["device"][3]) $(plosg("bus", format["device"][3]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, format["length"])

    summaryBlockHeader(io, format["length"], format["V"].title, system.bus.number)
    summaryBlock(io, format["V"], unitLive["V"], format["length"])
    summaryBlock(io, format["θ"], unitLive["θ"], format["length"]; line = true)

    if format["power"]
        if format["device"][1] != 0
            summaryBlockHeader(io, format["length"], format["Ps"].title, format["device"][1])
            summaryBlock(io, format["Ps"], unitLive["P"], format["length"])
            summaryBlock(io, format["Qs"], unitLive["Q"], format["length"]; line = true)
        end

        if format["device"][2] != 0
            summaryBlockHeader(io, format["length"], format["Pl"].title, format["device"][2])
            summaryBlock(io, format["Pl"], unitLive["P"], format["length"])
            summaryBlock(io, format["Ql"], unitLive["Q"], format["length"]; line = true)
        end

        summaryBlockHeader(io, format["length"], format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], unitLive["P"], format["length"])
        summaryBlock(io, format["Qi"], unitLive["Q"], format["length"]; line = true)

        if format["device"][3] != 0
            summaryBlockHeader(io, format["length"], format["Ph"].title, format["device"][3])
            summaryBlock(io, format["Ph"], unitLive["P"], format["length"])
            summaryBlock(io, format["Qh"], unitLive["Q"], format["length"]; line = true)
        end
    end

    if format["current"]
        summaryBlockHeader(io, format["length"], format["I"].title, system.bus.number)
        summaryBlock(io, format["I"], unitLive["I"], format["length"])
        summaryBlock(io, format["ψ"], unitLive["ψ"], format["length"]; line = true)
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
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0],
        "power" => !isempty(analysis.power.injection.active),
        "current" => !isempty(analysis.current.injection.magnitude)
    )

    for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i])
            format["device"][1] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            format["device"][2] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            format["device"][3] += 1
        end

        minmaxsumPrint!(format["V"], analysis.voltage.magnitude[i] * scaleMagnitude(prefix, system.base.voltage, i), i)
        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if format["power"]
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

        if format["current"]
            minmaxsumPrint!(format["I"], analysis.current.injection.magnitude[i] * scaleMagnitude(prefix, system, i), i)
            minmaxsumPrint!(format["ψ"], analysis.current.injection.angle[i], i)
        end
    end

    formatSummary!(format["V"], unitLive["V"], format["length"], system.bus.label, 1.0, system.bus.number; total = false)
    formatSummary!(format["θ"], unitLive["θ"], format["length"], system.bus.label, scale["θ"], system.bus.number; total = false)

    if format["power"]
        if format["device"][1] != 0
            formatSummary!(format["Ps"], unitLive["P"], format["length"], system.bus.label, scale["P"], format["device"][1])
            formatSummary!(format["Qs"], unitLive["Q"], format["length"], system.bus.label, scale["Q"], format["device"][1])
        end

        if format["device"][2] != 0
            formatSummary!(format["Pl"], unitLive["P"], format["length"], system.bus.label, scale["P"], format["device"][2])
            formatSummary!(format["Ql"], unitLive["Q"], format["length"], system.bus.label, scale["Q"], format["device"][2])
        end

        formatSummary!(format["Pi"], unitLive["P"], format["length"], system.bus.label, scale["P"], system.bus.number)
        formatSummary!(format["Qi"], unitLive["Q"], format["length"], system.bus.label, scale["Q"], system.bus.number)

        if format["device"][3] != 0
            formatSummary!(format["Ph"], unitLive["P"], format["length"], system.bus.label, scale["P"], format["device"][3])
            formatSummary!(format["Qh"], unitLive["Q"], format["length"], system.bus.label, scale["Q"], format["device"][3])
        end
    end

    if format["current"]
        formatSummary!(format["I"], unitLive["I"], format["length"], system.bus.label, 1.0, system.bus.number; total = false)
        formatSummary!(format["ψ"], unitLive["ψ"], format["length"], system.bus.label, scale["ψ"], system.bus.number; total = false)
    end

    return format, unitLive
end

function printBusSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, unitLive = formatBusSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(format["device"][1]) $(plosg("bus", format["device"][1])),
        while loads are installed at $(format["device"][2]) $(plosg("bus", format["device"][2])),
        and shunts are present at $(format["device"][3]) $(plosg("bus", format["device"][3]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, format["length"])

    summaryBlockHeader(io, format["length"], format["θ"].title, system.bus.number)
    summaryBlock(io, format["θ"], unitLive["θ"], format["length"]; line = true)

    if format["power"]
        if format["device"][1] != 0
            summaryBlockHeader(io, format["length"], format["Ps"].title, format["device"][1])
            summaryBlock(io, format["Ps"], unitLive["P"], format["length"]; line = true)
        end

        if format["device"][2] != 0
            summaryBlockHeader(io, format["length"], format["Pl"].title, format["device"][2])
            summaryBlock(io, format["Pl"], unitLive["P"], format["length"]; line = true)
        end

        summaryBlockHeader(io, format["length"], format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], unitLive["P"], format["length"]; line = true)
    end
end

function formatBusSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "θ" => SummaryData(title = "Bus Voltage"),
        "Ps" => SummaryData(title = "Power Generation"),
        "Pl" => SummaryData(title = "Power Demand"),
        "Pi" => SummaryData(title = "Power Injection"),
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0],
        "power" => !isempty(analysis.power.injection.active),
    )

    for i = 1:system.bus.number
        if !isempty(system.bus.supply.generator[i])
            format["device"][1] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            format["device"][2] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            format["device"][3] += 1
        end

        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if format["power"]
            if !isempty(system.bus.supply.generator[i])
                minmaxsumPrint!(format["Ps"], analysis.power.supply.active[i], i)
            end

            if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
                minmaxsumPrint!(format["Pl"], system.bus.demand.active[i], i)
            end

            minmaxsumPrint!(format["Pi"], analysis.power.injection.active[i], i)
        end
    end

    formatSummary!(format["θ"], unitLive["θ"], format["length"], system.bus.label, scale["θ"], system.bus.number; total = false)

    if format["power"]
        if format["device"][1] != 0
            formatSummary!(format["Ps"], unitLive["P"], format["length"], system.bus.label, scale["P"], format["device"][1])
        end

        if format["device"][2] != 0
            formatSummary!(format["Pl"], unitLive["P"], format["length"], system.bus.label, scale["P"], format["device"][2])
        end

        formatSummary!(format["Pi"], unitLive["P"], format["length"], system.bus.label, scale["P"], system.bus.number)
    end

    return format, unitLive
end

"""
    printBranchSummary(system::PowerSystem, analysis::Analysis, io::IO)

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
    format, unitLive = formatBranchSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.branch.number) $(plosg("branch", system.branch.number)), of which $(system.branch.layout.inservice) $(isare(system.branch.layout.inservice)) in-service.
        These include $(format["device"][1]) transmission $(plosg("line", format["device"][1]; pl = "s")) ($(format["device"][4]) in-service),
        $(format["device"][2]) $(plosg("in-phase transformer", format["device"][2]; pl = "s")) ($(format["device"][5]) in-service),
        and $(format["device"][3]) $(plosg("phase-shifting transformer", format["device"][3]; pl = "s")) ($(format["device"][6]) in-service)."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Branch Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        if format["device"][4] != 0
            summaryBlockHeader(io, format["length"], format["Pline"].title, format["device"][4])
            summaryBlock(io, format["Pline"], " Net" * unitLive["P"], format["length"])
            summaryBlock(io, format["Qline"], " Net" * unitLive["Q"], format["length"]; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Pintr"].title, format["device"][5])
            summaryBlock(io, format["Pintr"], " Net" * unitLive["P"], format["length"])
            summaryBlock(io, format["Qintr"], " Net" * unitLive["Q"], format["length"]; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Pshtr"].title, format["device"][6])
            summaryBlock(io, format["Pshtr"], " Net" * unitLive["P"], format["length"])
            summaryBlock(io, format["Qshtr"], " Net" * unitLive["Q"], format["length"]; line = true)
        end

        if format["device"][8] != 0
            summaryBlockHeader(io, format["length"], format["Ptie"].title, format["device"][8])
            summaryBlock(io, format["Ptie"], " Net" * unitLive["P"], format["length"])
            summaryBlock(io, format["Qtie"], " Net" * unitLive["Q"], format["length"]; line = true)
        end

        if format["device"][7] != 0
            summaryBlockHeader(io, format["length"], format["Pshunt"].title, format["device"][7])
            summaryBlock(io, format["Pshunt"], unitLive["P"], format["length"])
            summaryBlock(io, format["Qshunt"], unitLive["Q"], format["length"]; line = true)
        end

        if system.branch.layout.inservice != 0
            summaryBlockHeader(io, format["length"], format["Ploss"].title, system.branch.layout.inservice)
            summaryBlock(io, format["Ploss"], unitLive["P"], format["length"])
            summaryBlock(io, format["Qloss"], unitLive["Q"], format["length"]; line = true)
        end
    end

    if format["current"]
        if format["device"][4] != 0
            summaryBlockHeader(io, format["length"], format["Iline"].title, format["device"][4])
            summaryBlock(io, format["Iline"], unitLive["I"], format["length"])
            summaryBlock(io, format["ψline"], unitLive["ψ"], format["length"]; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Iintr"].title, format["device"][5])
            summaryBlock(io, format["Iintr"], unitLive["I"], format["length"])
            summaryBlock(io, format["ψintr"], unitLive["ψ"], format["length"]; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Ishtr"].title, format["device"][6])
            summaryBlock(io, format["Ishtr"], unitLive["I"], format["length"])
            summaryBlock(io, format["ψshtr"], unitLive["ψ"], format["length"]; line = true)
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
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0; 0; 0; 0; 0; 0],
        "power" => !isempty(analysis.power.injection.active),
        "current" => !isempty(analysis.current.injection.magnitude)
    )

    for i = 1:system.branch.number
        if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
            format["device"][1] += 1
            if system.branch.layout.status[i] == 1
                format["device"][4] += 1
            end
        elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
            format["device"][2] += 1
            if system.branch.layout.status[i] == 1
                format["device"][5] += 1
            end
        else
            format["device"][3] += 1
            if system.branch.layout.status[i] == 1
                format["device"][6] += 1
            end
        end

        if system.branch.layout.status[i] == 1
            if format["power"]
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
                    format["device"][8] += 1
                    minmaxsumPrint!(format["Ptie"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                    minmaxsumPrint!(format["Qtie"], abs(analysis.power.from.reactive[i] - analysis.power.to.reactive[i]) / 2, i)
                end

                if system.branch.parameter.conductance[i] != 0.0 || system.branch.parameter.susceptance[i] != 0.0
                    format["device"][7] += 1
                    minmaxsumPrint!(format["Pshunt"], analysis.power.charging.active[i], i)
                    minmaxsumPrint!(format["Qshunt"], analysis.power.charging.reactive[i], i)
                end

                minmaxsumPrint!(format["Ploss"], analysis.power.series.active[i], i)
                minmaxsumPrint!(format["Qloss"], analysis.power.series.reactive[i], i)
            end

            if format["current"]
                currentSeries = analysis.current.series.magnitude[i] * scaleMagnitude(prefix, system,system.branch.layout.from[i])

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

    if format["power"]
        formatSummary!(format["Pline"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][4]; total = false)
        formatSummary!(format["Qline"], unitLive["Q"], format["length"], system.branch.label, scale["Q"], format["device"][4]; total = false)

        formatSummary!(format["Pintr"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][5]; total = false)
        formatSummary!(format["Qintr"], unitLive["Q"], format["length"], system.branch.label, scale["Q"], format["device"][5]; total = false)

        formatSummary!(format["Pshtr"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][6]; total = false)
        formatSummary!(format["Qshtr"], unitLive["Q"], format["length"], system.branch.label, scale["Q"], format["device"][6]; total = false)

        formatSummary!(format["Ptie"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][8])
        formatSummary!(format["Qtie"], unitLive["Q"], format["length"], system.branch.label, scale["Q"], format["device"][8])

        formatSummary!(format["Pshunt"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][7])
        formatSummary!(format["Qshunt"], unitLive["Q"], format["length"], system.branch.label, scale["Q"],format["device"][7])

        formatSummary!(format["Ploss"], unitLive["P"], format["length"], system.branch.label, scale["P"], system.branch.layout.inservice)
        formatSummary!(format["Qloss"], unitLive["Q"], format["length"], system.branch.label, scale["Q"], system.branch.layout.inservice)
    end

    if format["current"]
        formatSummary!(format["Iline"], unitLive["I"], format["length"], system.branch.label, 1.0, format["device"][4]; total = false)
        formatSummary!(format["ψline"], unitLive["ψ"], format["length"], system.branch.label, scale["ψ"], format["device"][4]; total = false)

        formatSummary!(format["Iintr"], unitLive["I"], format["length"], system.branch.label, 1.0, format["device"][5]; total = false)
        formatSummary!(format["ψintr"], unitLive["ψ"], format["length"], system.branch.label, scale["ψ"], format["device"][5]; total = false)

        formatSummary!(format["Ishtr"], unitLive["I"], format["length"], system.branch.label, 1.0, format["device"][6]; total = false)
        formatSummary!(format["ψshtr"], unitLive["ψ"], format["length"], system.branch.label, scale["ψ"], format["device"][6]; total = false)
    end

    format["length"][6] = max(format["length"][6], textwidth(" Net Reactive [$(unitList.reactivePowerLive)]"))

    return format, unitLive
end

function printBranchSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, unitLive = formatBranchSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.branch.number) $(plosg("branch", system.branch.number)), of which $(system.branch.layout.inservice) $(isare(system.branch.layout.inservice)) in-service.
        These include $(format["device"][1]) transmission $(plosg("line", format["device"][1]; pl = "s")) ($(format["device"][4]) in-service),
        $(format["device"][2]) $(plosg("in-phase transformer", format["device"][2]; pl = "s")) ($(format["device"][5]) in-service),
        and $(format["device"][3]) $(plosg("phase-shifting transformer", format["device"][3]; pl = "s")) ($(format["device"][6]) in-service)."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Branch Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        if format["device"][4] != 0
            summaryBlockHeader(io, format["length"], format["Pline"].title, format["device"][4])
            summaryBlock(io, format["Pline"], " Net" * unitLive["P"], format["length"]; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Pintr"].title, format["device"][5])
            summaryBlock(io, format["Pintr"], " Net" * unitLive["P"], format["length"]; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Pshtr"].title, format["device"][6])
            summaryBlock(io, format["Pshtr"], " Net" * unitLive["P"], format["length"]; line = true)
        end

        if format["device"][7] != 0
            summaryBlockHeader(io, format["length"], format["Ptie"].title, format["device"][7])
            summaryBlock(io, format["Ptie"], " Net" * unitLive["P"], format["length"]; line = true)
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
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0; 0; 0; 0; 0],
        "power" => !isempty(analysis.power.injection.active),
    )

    for i = 1:system.branch.number
        if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
            format["device"][1] += 1
            if system.branch.layout.status[i] == 1
                format["device"][4] += 1
            end
        elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
            format["device"][2] += 1
            if system.branch.layout.status[i] == 1
                format["device"][5] += 1
            end
        else
            format["device"][3] += 1
            if system.branch.layout.status[i] == 1
                format["device"][6] += 1
            end
        end

        if format["power"]
            if system.branch.layout.status[i] == 1
                if system.branch.parameter.turnsRatio[i] == 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pline"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                elseif system.branch.parameter.turnsRatio[i] != 1 && system.branch.parameter.shiftAngle[i] == 0
                    minmaxsumPrint!(format["Pintr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                else
                    minmaxsumPrint!(format["Pshtr"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                end

                if system.bus.layout.area[system.branch.layout.from[i]] != system.bus.layout.area[system.branch.layout.to[i]]
                    format["device"][7] += 1
                    minmaxsumPrint!(format["Ptie"], abs(analysis.power.from.active[i] - analysis.power.to.active[i]) / 2, i)
                end
            end
        end
    end

    if format["power"]
        formatSummary!(format["Pline"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][4]; total = false)
        formatSummary!(format["Pintr"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][5]; total = false)
        formatSummary!(format["Pshtr"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][6]; total = false)
        formatSummary!(format["Ptie"], unitLive["P"], format["length"], system.branch.label, scale["P"], format["device"][7]; total = false)
    end

    format["length"][6] = max(format["length"][6], textwidth(" Net Active [$(unitList.activePowerLive)]"))

    return format, unitLive
end

"""
    printGeneratorSummary(system::PowerSystem, analysis::Analysis, io::IO)

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
    format, unitLive = formatGeneratorSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        summaryBlockHeader(io, format["length"], format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], unitLive["P"], format["length"])
        summaryBlock(io, format["Qg"], unitLive["Q"], format["length"]; line = true)
    end
end

function formatGeneratorSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pg" => SummaryData(title = "Output Power"),
        "Qg" => SummaryData(),
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0],
        "power" => !isempty(analysis.power.generator.active),
    )

    if format["power"]
        for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                minmaxsumPrint!(format["Pg"], analysis.power.generator.active[i], i)
                minmaxsumPrint!(format["Qg"], analysis.power.generator.reactive[i], i)
            end
        end
        formatSummary!(format["Pg"], unitLive["P"], format["length"], system.generator.label, scale["P"], system.generator.layout.inservice)
        formatSummary!(format["Qg"], unitLive["Q"], format["length"], system.generator.label, scale["Q"], system.generator.layout.inservice)
    end

    return format, unitLive
end


function printGeneratorSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format, unitLive = formatGeneratorSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        summaryBlockHeader(io, format["length"], format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], unitLive["P"], format["length"]; line = true)
    end
end

function formatGeneratorSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
    unitLive = printUnitSummary(unitList)

    format = Dict(
        "Pg" => SummaryData(title = "Output Power"),
        "length" => [0; 0; 0; 0; 5; 0],
        "device" => [0; 0; 0],
        "power" => !isempty(analysis.power.generator.active),
    )

    if format["power"]
        for i = 1:system.generator.number
            if system.generator.layout.status[i] == 1
                minmaxsumPrint!(format["Pg"], analysis.power.generator.active[i], i)
            end
        end
        formatSummary!(format["Pg"], unitLive["P"], format["length"], system.generator.label, scale["P"], system.generator.layout.inservice)
    end

    return format, unitLive
end


function containerFormatData(analysis::DC)
    width = Dict(
        "Label" => 5,
        "Voltage Angle" => 11,
        "Power Generation Active" => 16,
        "Power Demand Active" => 12,
        "Power Injection Active" => 15,
    )

    fmt = Dict(
        "Voltage Angle" => "%*.4f",
        "Power Generation Active" => "%*.4f",
        "Power Demand Active" => "%*.4f",
        "Power Injection Active" => "%*.4f"
    )

    flag = Dict("power" => !isempty(analysis.power.injection.active))

    return width, fmt, flag
end