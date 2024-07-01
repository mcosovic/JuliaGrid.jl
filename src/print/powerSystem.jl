"""
    printBusData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding bus.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

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
printBusData(system, analysis)

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
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatBusData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")

    maxLine = format["Label"] + format["Voltage Magnitude"] + format["Voltage Angle"] + 8
    if format["power"]
        maxLine += format["Power Generation Active"] + format["Power Generation Reactive"] +
                   format["Power Demand Active"] + format["Power Demand Reactive"] +
                   format["Power Injection Active"] + format["Power Injection Reactive"] +
                   format["Shunt Power Active"] + format["Shunt Power Reactive"] + 24
    end
    if format["current"]
        maxLine += format["Current Injection Magnitude"] + format["Current Injection Angle"] + 6
    end

    printTitle(maxLine, "Bus Data", header, io)

    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)

        Printf.@printf(io, "| %*s%s%*s | %*s%s%*s |",
            floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"]  - 5) / 2) , "",
            floor(Int, (format["Voltage Magnitude"] + format["Voltage Angle"] - 4) / 2), "", "Voltage", ceil(Int, (format["Voltage Magnitude"] + format["Voltage Angle"] - 4) / 2) , "",
        )
        if format["power"]
            Printf.@printf(io, " %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s |",
                floor(Int, (format["Power Generation Active"] + format["Power Generation Reactive"] - 13) / 2), "", "Power Generation", ceil(Int, (format["Power Generation Active"] + format["Power Generation Reactive"] - 13) / 2) , "",
                floor(Int, (format["Power Demand Active"] + format["Power Demand Reactive"] - 9) / 2), "", "Power Demand", ceil(Int, (format["Power Demand Active"] + format["Power Demand Reactive"] - 9) / 2) , "",
                floor(Int, (format["Power Injection Active"] + format["Power Injection Reactive"] - 12) / 2), "", "Power Injection", ceil(Int, (format["Power Injection Active"] + format["Power Injection Reactive"] - 12) / 2) , "",
                floor(Int, (format["Shunt Power Active"] + format["Shunt Power Reactive"] - 8) / 2), "", "Shunt Power", ceil(Int, (format["Shunt Power Active"] + format["Shunt Power Reactive"] - 8) / 2) , "",
            )
        end
        if format["current"]
            Printf.@printf(io, " %*s%s%*s |",
                floor(Int, (format["Current Injection Magnitude"] + format["Current Injection Angle"] - 14) / 2), "", "Current Injection", ceil(Int, (format["Current Injection Magnitude"] + format["Current Injection Angle"] - 14) / 2) , ""
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s |",
            format["Label"], "",
            format["Voltage Magnitude"] + format["Voltage Angle"] + 3, "",
        )
        if format["power"]
            Printf.@printf(io, " %*s | %*s | %*s | %*s |",
                format["Power Generation Active"] + format["Power Generation Reactive"] + 3, "",
                format["Power Demand Active"] + format["Power Demand Reactive"] + 3, "",
                format["Power Injection Active"] + format["Power Injection Reactive"] + 3, "",
                format["Shunt Power Active"] + format["Shunt Power Reactive"] + 3, "",
            )
        end
        if format["current"]
            Printf.@printf(io, " %*s |",
                format["Current Injection Magnitude"] + format["Current Injection Angle"] + 3, "",
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s | %*s ",
            format["Label"], "",
            format["Voltage Magnitude"], "Magnitude",
            format["Voltage Angle"], "Angle",
        )
        if format["power"]
            Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                format["Power Generation Active"], "Active",
                format["Power Generation Reactive"], "Reactive",
                format["Power Demand Active"], "Active",
                format["Power Demand Reactive"], "Reactive",
                format["Power Injection Active"], "Active",
                format["Power Injection Reactive"], "Reactive",
                format["Shunt Power Active"], "Active",
                format["Shunt Power Reactive"], "Reactive",
            )
        end
        if format["current"]
            Printf.@printf(io, "| %*s | %*s ",
                format["Current Injection Magnitude"], "Magnitude",
                format["Current Injection Angle"], "Angle",
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "| %*s | %*s | %*s ",
            format["Label"], "",
            format["Voltage Magnitude"], "[$(unitList.voltageMagnitudeLive)]",
            format["Voltage Angle"], "[$(unitList.voltageAngleLive)]",
        )
        if format["power"]
            Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                format["Power Generation Active"], "[$(unitList.activePowerLive)]",
                format["Power Generation Reactive"], "[$(unitList.reactivePowerLive)]",
                format["Power Demand Active"], "[$(unitList.activePowerLive)]",
                format["Power Demand Reactive"], "[$(unitList.reactivePowerLive)]",
                format["Power Injection Active"], "[$(unitList.activePowerLive)]",
                format["Power Injection Reactive"], "[$(unitList.reactivePowerLive)]",
                format["Shunt Power Active"], "[$(unitList.activePowerLive)]",
                format["Shunt Power Reactive"], "[$(unitList.reactivePowerLive)]",
            )
        end
        if format["current"]
            Printf.@printf(io, "| %*s | %*s ",
                format["Current Injection Magnitude"], "[$(unitList.currentMagnitudeLive)]",
                format["Current Injection Angle"], "[$(unitList.currentAngleLive)]",
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "|-%*s-|-%*s-|-%*s-",
            format["Label"], "-"^format["Label"],
            format["Voltage Magnitude"], "-"^format["Voltage Magnitude"],
            format["Voltage Angle"], "-"^format["Voltage Angle"],
        )
        if format["power"]
            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                format["Power Generation Active"], "-"^format["Power Generation Active"],
                format["Power Generation Reactive"], "-"^format["Power Generation Reactive"],
                format["Power Demand Active"], "-"^format["Power Demand Active"],
                format["Power Demand Reactive"], "-"^format["Power Demand Reactive"],
                format["Power Injection Active"], "-"^format["Power Injection Active"],
                format["Power Injection Reactive"], "-"^format["Power Injection Reactive"],
                format["Shunt Power Active"], "-"^format["Shunt Power Active"],
                format["Shunt Power Reactive"], "-"^format["Shunt Power Reactive"],
            )
        end
        if format["current"]
            Printf.@printf(io, "|-%*s-|-%*s-",
            format["Current Injection Magnitude"], "-"^format["Current Injection Magnitude"],
            format["Current Injection Angle"], "-"^format["Current Injection Angle"]
            )
        end
        Printf.@printf io "|\n"
    elseif !isset(label)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end

    for (label, i) in labels
        if prefix.voltageMagnitude != 0.0
            voltageMagnitude = (analysis.voltage.magnitude[i]) * (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
        else
            voltageMagnitude = analysis.voltage.magnitude[i]
        end

        if format["current"]
            if  prefix.currentMagnitude != 0.0
                currentMagnitude = analysis.current.injection.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
            else
                currentMagnitude = analysis.current.injection.magnitude[i]
            end
        end

        Printf.@printf(io, "| %-*s | %*.4f | %*.4f ",
            format["Label"], label,
            format["Voltage Magnitude"], voltageMagnitude,
            format["Voltage Angle"], analysis.voltage.angle[i] * scale["voltageAngle"],
        )
        if format["power"]
            Printf.@printf(io, "| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                format["Power Generation Active"], analysis.power.supply.active[i] * scale["activePower"],
                format["Power Generation Reactive"], analysis.power.supply.reactive[i] * scale["reactivePower"],
                format["Power Demand Active"], system.bus.demand.active[i] * scale["activePower"],
                format["Power Demand Reactive"], system.bus.demand.reactive[i] * scale["reactivePower"],
                format["Power Injection Active"], analysis.power.injection.active[i] * scale["activePower"],
                format["Power Injection Reactive"], analysis.power.injection.reactive[i] * scale["reactivePower"],
                format["Shunt Power Active"], analysis.power.shunt.active[i] * scale["activePower"],
                format["Shunt Power Reactive"], analysis.power.shunt.reactive[i] * scale["reactivePower"],
            )
        end
        if format["current"]
            Printf.@printf(io, "| %*.4f | %*.4f ",
            format["Current Injection Magnitude"], currentMagnitude,
            format["Current Injection Angle"], analysis.current.injection.angle[i] * scale["currentAngle"]
            )
        end
        Printf.@printf io "|\n"
    end

    if !isset(label) || footer
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

function printBusData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatBusData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.bus, system.bus.label, header, "bus")

    maxLine = format["Label"] + format["Voltage Angle"] + 5
    if format["power"]
        maxLine += format["Power Generation Active"] + format["Power Demand Active"] +
                   format["Power Injection Active"] + 9
    end

    printTitle(maxLine, "Bus Data", header, io)

    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)

        Printf.@printf(io, "| %*s%s%*s | %*s |",
            floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"] - 5) / 2) , "",
            format["Voltage Angle"], "Voltage",
        )

        if format["power"]
            Printf.@printf(io, " %*s | %*s | %*s |",
                format["Power Generation Active"], "Power Generation",
                format["Power Demand Active"], "Power Demand",
                format["Power Injection Active"], "Power Injection",
            )
        end
        Printf.@printf io "\n"

        Printf.@printf(io, "| %*s | %*s ",
            format["Label"], "",
            format["Voltage Angle"], "Angle [$(unitList.voltageAngleLive)]",
        )
        if format["power"]
            Printf.@printf(io, "| %*s | %*s | %*s ",
                format["Power Generation Active"], "Active [$(unitList.activePowerLive)]",
                format["Power Demand Active"], "Active [$(unitList.activePowerLive)]",
                format["Power Injection Active"], "Active [$(unitList.activePowerLive)]",
            )
        end
        Printf.@printf io "|\n"

        Printf.@printf(io, "|-%*s-|-%*s-",
            format["Label"], "-"^format["Label"],
            format["Voltage Angle"], "-"^format["Voltage Angle"],
        )
        if format["power"]
            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-",
                format["Power Generation Active"], "-"^format["Power Generation Active"],
                format["Power Demand Active"], "-"^format["Power Demand Active"],
                format["Power Injection Active"], "-"^format["Power Injection Active"],
            )
        end
        Printf.@printf io "|\n"
    elseif !isset(label)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end

    for (label, i) in labels
        Printf.@printf(io, "| %-*s | %*.4f ",
            format["Label"], label,
            format["Voltage Angle"], analysis.voltage.angle[i] * scale["voltageAngle"],
        )
        if format["power"]
            Printf.@printf(io, "| %*.4f | %*.4f | %*.4f ",
                format["Power Generation Active"], analysis.power.supply.active[i] * scale["activePower"],
                format["Power Demand Active"], system.bus.demand.active[i] * scale["activePower"],
                format["Power Injection Active"], analysis.power.injection.active[i] * scale["activePower"],
            )
        end
        Printf.@printf io "|\n"
    end

    if !isset(label) || footer
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

"""
    printBranchData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding branch.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

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
printBranchData(system, analysis)

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
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatBranchData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")

    if format["power"] || format["current"]
        maxLine = format["Label"] + format["Status"] + 5
        if format["power"]
            maxLine += format["From-Bus Power Active"] + format["From-Bus Power Reactive"] +
                       format["To-Bus Power Active"] + format["To-Bus Power Reactive"] +
                       format["Shunt Power Active"] + format["Shunt Power Reactive"] +
                       format["Series Power Active"] + format["Series Power Reactive"] + 24
        end
        if format["current"]
            maxLine += format["From-Bus Current Magnitude"] + format["From-Bus Current Angle"] +
                       format["To-Bus Current Magnitude"] + format["To-Bus Current Angle"] +
                       format["Series Current Magnitude"] + format["Series Current Angle"] + 18
        end

        printTitle(maxLine, "Branch Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s ", floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"] - 5) / 2) , "",)

            if format["power"]
                Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                    floor(Int, (format["From-Bus Power Active"] + format["From-Bus Power Reactive"] - 11) / 2), "", "From-Bus Power", ceil(Int, (format["From-Bus Power Active"] + format["From-Bus Power Reactive"] - 11) / 2) , "",
                    floor(Int, (format["To-Bus Power Active"] + format["To-Bus Power Reactive"] - 9) / 2), "", "To-Bus Power", ceil(Int, (format["To-Bus Power Active"] + format["To-Bus Power Reactive"] - 9) / 2) , "",
                    floor(Int, (format["Shunt Power Active"] + format["Shunt Power Reactive"] - 8) / 2), "", "Shunt Power", ceil(Int, (format["Shunt Power Active"] + format["Shunt Power Reactive"] - 8) / 2) , "",
                    floor(Int, (format["Series Power Active"] + format["Series Power Reactive"] - 9) / 2), "", "Series Power", ceil(Int, (format["Series Power Active"] + format["Series Power Reactive"] - 9) / 2) , "",
                )
            end
            if format["current"]
                Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                    floor(Int, (format["From-Bus Current Magnitude"] + format["From-Bus Current Angle"] - 13) / 2), "", "From-Bus Current", ceil(Int, (format["From-Bus Current Magnitude"] + format["From-Bus Current Angle"] - 13) / 2) , "",
                    floor(Int, (format["To-Bus Current Magnitude"] + format["To-Bus Current Angle"] - 11) / 2), "", "To-Bus Current", ceil(Int, (format["To-Bus Current Magnitude"] + format["To-Bus Current Angle"] - 11) / 2) , "",
                    floor(Int, (format["Series Current Magnitude"] + format["Series Current Angle"] - 11) / 2), "", "Series Current", ceil(Int, (format["Series Current Magnitude"] + format["Series Current Angle"] - 11) / 2) , "",
                )
            end
            Printf.@printf io "| %s |\n" "Status"

            Printf.@printf(io, "| %*s |",
                format["Label"], "",
            )
            if format["power"]
                Printf.@printf(io, " %*s | %*s | %*s | %*s |",
                    format["From-Bus Power Active"] + format["From-Bus Power Reactive"] + 3, "",
                    format["To-Bus Power Active"] + format["To-Bus Power Reactive"] + 3, "",
                    format["Shunt Power Active"] + format["Shunt Power Reactive"] + 3, "",
                    format["Series Power Active"] + format["Series Power Reactive"] + 3, "",
                )
            end
            if format["current"]
                Printf.@printf(io, " %*s | %*s | %*s |",
                    format["From-Bus Current Magnitude"] + format["From-Bus Current Angle"] + 3, "",
                    format["To-Bus Current Magnitude"] + format["To-Bus Current Angle"] + 3, "",
                    format["Series Current Magnitude"] + format["Series Current Angle"] + 3, "",
                )
            end
            Printf.@printf io " %*s |\n" format["Status"] ""

            Printf.@printf(io, "| %*s ", format["Label"], "")

            if format["power"]
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                    format["From-Bus Power Active"], "Active",
                    format["From-Bus Power Reactive"], "Reactive",
                    format["To-Bus Power Active"], "Active",
                    format["To-Bus Power Reactive"], "Reactive",
                    format["Shunt Power Active"], "Active",
                    format["Shunt Power Reactive"], "Reactive",
                    format["Series Power Active"], "Active",
                    format["Series Power Reactive"], "Reactive",
                )
            end
            if format["current"]
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s ",
                    format["From-Bus Current Magnitude"], "Magnitude",
                    format["From-Bus Current Angle"], "Angle",
                    format["To-Bus Current Magnitude"], "Magnitude",
                    format["To-Bus Current Angle"], "Angle",
                    format["Series Current Magnitude"], "Magnitude",
                    format["Series Current Angle"], "Angle",
                )
            end
            Printf.@printf io "| %*s |\n" format["Status"] ""

            Printf.@printf(io, "| %*s ", format["Label"], "")

            if format["power"]
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                    format["From-Bus Power Active"], "[$(unitList.activePowerLive)]",
                    format["From-Bus Power Reactive"], "[$(unitList.reactivePowerLive)]",
                    format["To-Bus Power Active"], "[$(unitList.activePowerLive)]",
                    format["To-Bus Power Reactive"], "[$(unitList.reactivePowerLive)]",
                    format["Shunt Power Active"], "[$(unitList.activePowerLive)]",
                    format["Shunt Power Reactive"], "[$(unitList.reactivePowerLive)]",
                    format["Series Power Active"], "[$(unitList.activePowerLive)]",
                    format["Series Power Reactive"], "[$(unitList.reactivePowerLive)]",
                )
            end
            if format["current"]
                Printf.@printf(io, "| %*s | %*s | %*s | %*s | %*s | %*s ",
                    format["From-Bus Current Magnitude"], "[$(unitList.currentMagnitudeLive)]",
                    format["From-Bus Current Angle"], "[$(unitList.currentAngleLive)]",
                    format["To-Bus Current Magnitude"], "[$(unitList.currentMagnitudeLive)]",
                    format["To-Bus Current Angle"], "[$(unitList.currentAngleLive)]",
                    format["Series Current Magnitude"], "[$(unitList.currentMagnitudeLive)]",
                    format["Series Current Angle"], "[$(unitList.currentAngleLive)]",
                )
            end
            Printf.@printf io "| %*s |\n" format["Status"] ""

            Printf.@printf(io, "|-%*s-", format["Label"], "-"^format["Label"]
            )
            if format["power"]
                Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                    format["From-Bus Power Active"], "-"^format["From-Bus Power Active"],
                    format["From-Bus Power Reactive"], "-"^format["From-Bus Power Reactive"],
                    format["To-Bus Power Active"], "-"^format["To-Bus Power Active"],
                    format["To-Bus Power Reactive"], "-"^format["To-Bus Power Reactive"],
                    format["Shunt Power Active"], "-"^format["Shunt Power Active"],
                    format["Shunt Power Reactive"], "-"^format["Shunt Power Reactive"],
                    format["Series Power Active"], "-"^format["Series Power Active"],
                    format["Series Power Reactive"], "-"^format["Series Power Reactive"],
                )
            end
            if format["current"]
                Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                    format["From-Bus Current Magnitude"], "-"^format["From-Bus Current Magnitude"],
                    format["From-Bus Current Angle"], "-"^format["From-Bus Current Angle"],
                    format["To-Bus Current Magnitude"], "-"^format["To-Bus Current Magnitude"],
                    format["To-Bus Current Angle"], "-"^format["To-Bus Current Angle"],
                    format["Series Current Magnitude"], "-"^format["Series Current Magnitude"],
                    format["Series Current Angle"], "-"^format["Series Current Angle"],
                )
            end
            Printf.@printf io "|-%*s-|\n" format["Status"] "-"^format["Status"]
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            Printf.@printf(io, "| %*s ", format["Label"], label)

            if format["power"]
                Printf.@printf(io, "| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                    format["From-Bus Power Active"], analysis.power.from.active[i] * scale["activePower"],
                    format["From-Bus Power Reactive"], analysis.power.from.reactive[i] * scale["reactivePower"],
                    format["To-Bus Power Active"], analysis.power.to.active[i] * scale["activePower"],
                    format["To-Bus Power Reactive"], analysis.power.to.reactive[i] * scale["reactivePower"],
                    format["Shunt Power Active"], analysis.power.charging.active[i] * scale["activePower"],
                    format["Shunt Power Reactive"], analysis.power.charging.reactive[i] * scale["reactivePower"],
                    format["Series Power Active"], analysis.power.series.active[i] * scale["activePower"],
                    format["Series Power Reactive"], analysis.power.series.reactive[i] * scale["reactivePower"],
                )
            end
            if format["current"]
                if prefix.currentMagnitude != 0.0
                    j = system.branch.layout.from[i]
                    currentMagnitudeFrom = analysis.current.from.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
                    currentMagnitudeS = analysis.current.series.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)

                    j = system.branch.layout.to[i]
                    currentMagnitudeTo = analysis.current.to.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
                else
                    currentMagnitudeFrom = analysis.current.from.magnitude[i]
                    currentMagnitudeTo = analysis.current.to.magnitude[i]
                    currentMagnitudeS = analysis.current.series.magnitude[i]
                end

                Printf.@printf(io, "| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                    format["From-Bus Current Magnitude"], currentMagnitudeFrom,
                    format["From-Bus Current Angle"], analysis.current.from.angle[i] * scale["currentAngle"],
                    format["To-Bus Current Magnitude"], currentMagnitudeTo,
                    format["To-Bus Current Angle"], analysis.current.to.angle[i] * scale["currentAngle"],
                    format["Series Current Magnitude"], currentMagnitudeS,
                    format["Series Current Angle"], analysis.current.series.angle[i] * scale["currentAngle"]
                )
            end

            Printf.@printf(io, "| %*i |\n", format["Status"], system.branch.layout.status[i])
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function printBranchData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatBranchData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.branch, system.branch.label, header, "branch")

    if format["power"]
        maxLine = format["Label"] + format["From-Bus Power Active"] + format["To-Bus Power Active"] + format["Status"] + 11

        printTitle(maxLine, "Branch Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s | %*s | %*s |\n",
                floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"] - 5) / 2) , "",
                format["From-Bus Power Active"], "From-Bus Power",
                format["To-Bus Power Active"], "To-Bus Power",
                format["Status"], "Status",
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                format["Label"], "",
                format["From-Bus Power Active"], "Active [$(unitList.activePowerLive)]",
                format["To-Bus Power Active"], "Active [$(unitList.activePowerLive)]",
                format["Status"], "",
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|\n",
                format["Label"], "-"^format["Label"],
                format["From-Bus Power Active"], "-"^format["From-Bus Power Active"],
                format["To-Bus Power Active"], "-"^format["To-Bus Power Active"],
                format["Status"], "-"^format["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            Printf.@printf(io, "| %-*s | %*.4f | %*.4f | %*i |\n",
                format["Label"], label,
                format["From-Bus Power Active"], analysis.power.from.active[i] * scale["activePower"],
                format["To-Bus Power Active"], analysis.power.to.active[i] * scale["activePower"],
                format["Status"], system.branch.layout.status[i],
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

"""
    printGeneratorData(system::PowerSystem, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect the output.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding generator.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

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
printGeneratorData(system, analysis)

# Print data for specific generators
width = Dict("Output Power Active" => 7)
printGeneratorData(system, analysis; label = 1, width, header = true)
printGeneratorData(system, analysis; label = 4, width)
printGeneratorData(system, analysis; label = 5, width, footer = true)
```
"""
function printGeneratorData(system::PowerSystem, analysis::AC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatGeneratorData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")

    if format["power"]
        maxLine = format["Label"] + format["Output Power Active"] + format["Output Power Reactive"] + format["Status"] + 11
        printTitle(maxLine, "Generator Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s%s%*s | %s |\n",
                floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"] - 5) / 2) , "",
                floor(Int, (format["Output Power Active"] + format["Output Power Reactive"] - 9) / 2), "", "Output Power", ceil(Int, (format["Output Power Active"] + format["Output Power Reactive"] - 9) / 2) , "",
                "Status"
            )

            Printf.@printf(io, "| %*s | %*s | %*s |\n",
                format["Label"], "",
                format["Output Power Active"] + format["Output Power Reactive"] + 3, "",
                format["Status"], ""
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                format["Label"], "",
                format["Output Power Active"], "Active",
                format["Output Power Reactive"], "Reactive",
                format["Status"], ""
            )

            Printf.@printf(io, "| %*s | %*s | %*s | %*s |\n",
                format["Label"], "",
                format["Output Power Active"], "[$(unitList.activePowerLive)]",
                format["Output Power Reactive"], "[$(unitList.reactivePowerLive)]",
                format["Status"], ""
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|-%*s-|\n",
                format["Label"], "-"^format["Label"],
                format["Output Power Active"], "-"^format["Output Power Active"],
                format["Output Power Reactive"], "-"^format["Output Power Reactive"],
                format["Status"], "-"^format["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            Printf.@printf(io, "| %-*s | %*.4f | %*.4f | %*i |\n",
                format["Label"], label,
                format["Output Power Active"], analysis.power.generator.active[i] * scale["activePower"],
                format["Output Power Reactive"], analysis.power.generator.reactive[i] * scale["reactivePower"],
                format["Status"], system.generator.layout.status[i]
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function printGeneratorData(system::PowerSystem, analysis::DC, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    scale = printScale(system, prefix)
    format = formatGeneratorData(system, analysis, scale, label, width)
    labels, header = toggleLabelHeader(label, system.generator, system.generator.label, header, "generator")

    if format["power"]
        maxLine = format["Label"] + format["Output Power Active"] + format["Status"] + 8
        printTitle(maxLine, "Generator Data", header, io)

        if header
            Printf.@printf(io, "|%s|\n", "-"^maxLine)

            Printf.@printf(io, "| %*s%s%*s | %*s | %s |\n",
                floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"] - 5) / 2) , "",
                format["Output Power Active"], "Output Power",
                "Status"
            )

            Printf.@printf(io, "| %*s | %*s | %*s |\n",
                format["Label"], "",
                format["Output Power Active"], "Active [$(unitList.activePowerLive)]",
                format["Status"], "",
            )

            Printf.@printf(io, "|-%*s-|-%*s-|-%*s-|\n",
                format["Label"], "-"^format["Label"],
                format["Output Power Active"], "-"^format["Output Power Active"],
                format["Status"], "-"^format["Status"],
            )
        elseif !isset(label)
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end

        for (label, i) in labels
            Printf.@printf(io, "| %-*s | %*.4f | %*i |\n",
                format["Label"], label,
                format["Output Power Active"], analysis.power.generator.active[i] * scale["activePower"],
                format["Status"], system.generator.layout.status[i]
            )
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatBusData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    errorVoltage(analysis.voltage.magnitude)

    format = Dict(
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
        "Current Injection Angle" => 5,
        "power" => !isempty(analysis.power.injection.active),
        "current" => !isempty(analysis.current.injection.magnitude)
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.bus.label[getLabel(system.bus, label, "bus")]
        format["Label"] = max(length(label), format["Label"])

        if prefix.voltageMagnitude == 0.0
            scaleV = 1.0
        else
            scaleV = (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
        end

        format["Voltage Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.voltage.magnitude[i] * scaleV)), format["Voltage Magnitude"])
        format["Voltage Angle"] = max(length(Printf.@sprintf("%.4f", analysis.voltage.angle[i] * scale["voltageAngle"])), format["Voltage Angle"])

        if format["power"]
            format["Power Generation Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.supply.active[i] * scale["activePower"])), format["Power Generation Active"])
            format["Power Demand Active"] = max(length(Printf.@sprintf("%.4f", system.bus.demand.active[i] * scale["activePower"])), format["Power Demand Active"])
            format["Power Injection Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.injection.active[i] * scale["activePower"])), format["Power Injection Active"])
            format["Shunt Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.shunt.active[i] * scale["activePower"])), format["Shunt Power Active"])

            format["Power Generation Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.supply.reactive[i] * scale["reactivePower"])), format["Power Generation Reactive"])
            format["Power Demand Reactive"] = max(length(Printf.@sprintf("%.4f", system.bus.demand.reactive[i] * scale["reactivePower"])), format["Power Demand Reactive"])
            format["Power Injection Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.injection.reactive[i] * scale["reactivePower"])), format["Power Injection Reactive"])
            format["Shunt Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.shunt.reactive[i] * scale["reactivePower"])), format["Shunt Power Reactive"])
        end

        if format["current"]
            if prefix.currentMagnitude == 0.0
                scaleI = 1.0
            else
                scaleI = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
            end

            format["Current Injection Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.injection.magnitude[i] * scaleI)), format["Current Injection Magnitude"])
            format["Current Injection Angle"] = max(length(Printf.@sprintf("%.4f", analysis.current.injection.angle[i] * scale["currentAngle"])), format["Current Injection Angle"])
        end
    else
        if prefix.voltageMagnitude == 0.0
            maxV = maximum(analysis.voltage.magnitude)
            format["Voltage Magnitude"] = max(length(Printf.@sprintf("%.4f", maxV)), format["Voltage Magnitude"])
        end

        minmaxT = extrema(analysis.voltage.angle)
        format["Voltage Angle"] = max(length(Printf.@sprintf("%.4f", minmaxT[1] * scale["voltageAngle"])), length(Printf.@sprintf("%.4f", minmaxT[2] * scale["voltageAngle"])), format["Voltage Angle"])

        if format["power"]
            minmaxPg = extrema(analysis.power.supply.active)
            format["Power Generation Active"] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPg[2] * scale["activePower"])), format["Power Generation Active"])

            minmaxPl = extrema(system.bus.demand.active)
            format["Power Demand Active"] = max(length(Printf.@sprintf("%.4f", minmaxPl[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPl[2] * scale["activePower"])), format["Power Demand Active"])

            minmaxPi = extrema(analysis.power.injection.active)
            format["Power Injection Active"] = max(length(Printf.@sprintf("%.4f", minmaxPi[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPi[2] * scale["activePower"])), format["Power Injection Active"])

            minmaxPsi = extrema(analysis.power.shunt.active)
            format["Shunt Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPsi[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPsi[2] * scale["activePower"])), format["Shunt Power Active"])

            minmaxQg = extrema(analysis.power.supply.reactive)
            format["Power Generation Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQg[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQg[2] * scale["reactivePower"])), format["Power Generation Reactive"])

            minmaxQl = extrema(system.bus.demand.reactive)
            format["Power Demand Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQl[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQl[2] * scale["reactivePower"])), format["Power Demand Reactive"])

            minmaxQi = extrema(analysis.power.injection.reactive)
            format["Power Injection Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQi[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQi[2] * scale["reactivePower"])), format["Power Injection Reactive"])

            minmaxQsi = extrema(analysis.power.shunt.reactive)
            format["Shunt Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQsi[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQsi[2] * scale["reactivePower"])), format["Shunt Power Reactive"])
        end

        if format["current"]
            if prefix.currentMagnitude == 0.0
                maxI = maximum(analysis.current.injection.magnitude)
                format["Current Injection Magnitude"] = max(length(Printf.@sprintf("%.4f", maxI)), format["Current Injection Magnitude"])
            end

            minmaxW = extrema(analysis.current.injection.angle)
            format["Current Injection Angle"] = max(length(Printf.@sprintf("%.4f", minmaxW[1] * scale["currentAngle"])), length(Printf.@sprintf("%.4f", minmaxW[2] * scale["currentAngle"])), format["Current Injection Angle"])
        end

        @inbounds for (label, i) in system.bus.label
            format["Label"] = max(length(label), format["Label"])

            if prefix.voltageMagnitude != 0.0
                scaleV = (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
                format["Voltage Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.voltage.magnitude[i] * scaleV)), format["Voltage Magnitude"])
            end

            if format["current"] && prefix.currentMagnitude != 0.0
                scaleI = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
                format["Current Injection Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.injection.magnitude[i] * scaleI)), format["Current Injection Magnitude"])
            end
        end
    end

    return format
end

function formatBusData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    errorVoltage(analysis.voltage.angle)

    format = Dict(
        "Label" => 5,
        "Voltage Angle" => 11,
        "Power Generation Active" => 16,
        "Power Demand Active" => 12,
        "Power Injection Active" => 15,
        "power" => !isempty(analysis.power.injection.active),
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.bus.label[getLabel(system.bus, label, "bus")]
        format["Label"] = max(length(label), format["Label"])
        format["Voltage Angle"] = max(length(Printf.@sprintf("%.4f", analysis.voltage.angle[i] * scale["voltageAngle"])), format["Voltage Angle"])

        if format["power"]
            format["Power Generation Active"] = max(length(Printf.@sprintf("%.4f",analysis.power.supply.active[i] * scale["activePower"])), format["Power Generation Active"])
            format["Power Demand Active"] = max(length(Printf.@sprintf("%.4f", system.bus.demand.active[i] * scale["activePower"])), format["Power Demand Active"])
            format["Power Injection Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.injection.active[i] * scale["activePower"])), format["Power Injection Active"])
        end
    else
        minmaxT = extrema(analysis.voltage.angle)
        format["Voltage Angle"] = max(length(Printf.@sprintf("%.4f", minmaxT[1] * scale["voltageAngle"])), length(Printf.@sprintf("%.4f", minmaxT[2] * scale["voltageAngle"])), format["Voltage Angle"])

        if format["power"]
            minmaxPg = extrema(analysis.power.supply.active)
            format["Power Generation Active"] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPg[2] * scale["activePower"])), format["Power Generation Active"])

            minmaxPl = extrema(system.bus.demand.active)
            format["Power Demand Active"] = max(length(Printf.@sprintf("%.4f", minmaxPl[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPl[2] * scale["activePower"])), format["Power Demand Active"])

            minmaxPi = extrema(analysis.power.injection.active)
            format["Power Injection Active"] = max(length(Printf.@sprintf("%.4f", minmaxPi[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPi[2] * scale["activePower"])), format["Power Injection Active"])
        end

        @inbounds for (label, i) in system.bus.label
            format["Label"] = max(length(label), format["Label"])
        end
    end

    return format
end

function formatBranchData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format = Dict(
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
        "Status" => 6,
        "power" => !isempty(analysis.power.from.active),
        "current" => !isempty(analysis.current.from.magnitude)
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.branch.label[getLabel(system.branch, label, "branch")]
        format["Label"] = max(length(label), format["Label"])

        if format["power"]
            format["From-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.from.active[i] * scale["activePower"])), format["From-Bus Power Active"])
            format["To-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.to.active[i] * scale["activePower"])), format["To-Bus Power Active"])
            format["Shunt Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.charging.active[i] * scale["activePower"])), format["Shunt Power Active"])
            format["Series Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.series.active[i] * scale["activePower"])), format["Series Power Active"])

            format["From-Bus Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.from.reactive[i] * scale["reactivePower"])), format["From-Bus Power Reactive"])
            format["To-Bus Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.to.reactive[i] * scale["reactivePower"])), format["To-Bus Power Reactive"])
            format["Shunt Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.charging.reactive[i] * scale["reactivePower"])), format["Shunt Power Reactive"])
            format["Series Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.series.reactive[i] * scale["reactivePower"])), format["Series Power Reactive"])
        end

        if format["current"]
            if prefix.currentMagnitude == 0.0
                scaleIij = 1.0
                scaleIji = 1.0
            else
                scaleIij = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[system.branch.layout.from[i]] * system.base.voltage.prefix * prefix.currentMagnitude)
                scaleIji = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[system.branch.layout.to[i]] * system.base.voltage.prefix * prefix.currentMagnitude)
            end

            format["From-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.from.magnitude[i] * scaleIij)), format["From-Bus Current Magnitude"])
            format["To-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.to.magnitude[i] * scaleIji)), format["To-Bus Current Magnitude"])
            format["Series Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.series.magnitude[i] * scaleIij)), format["Series Current Magnitude"])

            format["From-Bus Current Angle"] = max(length(Printf.@sprintf("%.4f", analysis.current.from.angle[i] * scale["currentAngle"])), format["From-Bus Current Angle"])
            format["To-Bus Current Angle"] = max(length(Printf.@sprintf("%.4f", analysis.current.to.angle[i] * scale["currentAngle"])), format["To-Bus Current Angle"])
            format["Series Current Angle"] = max(length(Printf.@sprintf("%.4f", analysis.current.series.angle[i] * scale["currentAngle"])), format["Series Current Angle"])
        end
    else
        if format["power"]
            minmaxPij = extrema(analysis.power.from.active)
            format["From-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPij[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPij[2] * scale["activePower"])), format["From-Bus Power Active"])

            minmaxPji = extrema(analysis.power.to.active)
            format["To-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPji[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPji[2] * scale["activePower"])), format["To-Bus Power Active"])

            minmaxPsi = extrema(analysis.power.charging.active)
            format["Shunt Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPsi[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPsi[2] * scale["activePower"])), format["Shunt Power Active"])

            minmaxPli = extrema(analysis.power.series.active)
            format["Series Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPli[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPli[2] * scale["activePower"])), format["Series Power Active"])

            minmaxQij = extrema(analysis.power.from.reactive)
            format["From-Bus Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQij[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQij[2] * scale["reactivePower"])), format["From-Bus Power Reactive"])

            minmaxQji = extrema(analysis.power.to.reactive)
            format["To-Bus Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQji[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQji[2] * scale["reactivePower"])), format["To-Bus Power Reactive"])

            minmaxQsi = extrema(analysis.power.charging.reactive)
            format["Shunt Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQsi[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQsi[2] * scale["reactivePower"])), format["Shunt Power Reactive"])

            minmaxQli = extrema(analysis.power.series.reactive)
            format["Series Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQli[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQli[2] * scale["reactivePower"])), format["Series Power Reactive"])
        end

        if format["current"]
            if prefix.currentMagnitude == 0.0
                maxIij = maximum(analysis.current.from.magnitude)
                format["From-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", maxIij)), format["From-Bus Current Magnitude"])

                maxIji = maximum(analysis.current.to.magnitude)
                format["To-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", maxIji)), format["To-Bus Current Magnitude"])

                maxIs = maximum(analysis.current.series.magnitude)
                format["Series Current Magnitude"] = max(length(Printf.@sprintf("%.4f", maxIs)), format["Series Current Magnitude"])
            end

            minmaxWij = extrema(analysis.current.from.angle)
            format["From-Bus Current Angle"] = max(length(Printf.@sprintf("%.4f", minmaxWij[1] * scale["currentAngle"])), length(Printf.@sprintf("%.4f", minmaxWij[2] * scale["currentAngle"])), format["From-Bus Current Angle"])

            minmaxWji = extrema(analysis.current.to.angle)
            format["To-Bus Current Angle"] = max(length(Printf.@sprintf("%.4f", minmaxWji[1] * scale["currentAngle"])), length(Printf.@sprintf("%.4f", minmaxWji[2] * scale["currentAngle"])), format["To-Bus Current Angle"])

            minmaxWs = extrema(analysis.current.series.angle)
            format["Series Current Angle"] = max(length(Printf.@sprintf("%.4f", minmaxWs[1] * scale["currentAngle"])), length(Printf.@sprintf("%.4f", minmaxWs[2] * scale["currentAngle"])), format["Series Current Angle"])
        end

        @inbounds for (label, i) in system.branch.label
            format["Label"] = max(length(label), format["Label"])

            if format["current"] && prefix.currentMagnitude != 0.0
                from = system.branch.layout.from[i]
                scaleIij = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[from] * system.base.voltage.prefix * prefix.currentMagnitude)
                format["From-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.from.magnitude[i] * scaleIij)), format["From-Bus Current Magnitude"])

                to = system.branch.layout.to[i]
                scaleIji = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[to] * system.base.voltage.prefix * prefix.currentMagnitude)
                format["To-Bus Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.to.magnitude[i] * scaleIji)), format["To-Bus Current Magnitude"])

                format["Series Current Magnitude"] = max(length(Printf.@sprintf("%.4f", analysis.current.series.magnitude[i] * scaleIij)), format["Series Current Magnitude"])
            end
        end
    end

    return format
end

function formatBranchData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format = Dict(
        "Label" => 5,
        "From-Bus Power Active" => 14,
        "To-Bus Power Active" => 12,
        "Status" => 6,
        "power" => !isempty(analysis.power.from.active),
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.branch.label[getLabel(system.branch, label, "branch")]
        format["Label"] = max(length(label), format["Label"])

        format["From-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.from.active[i] * scale["activePower"])), format["From-Bus Power Active"])
        format["To-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.to.active[i] * scale["activePower"])), format["To-Bus Power Active"])
    else
        if format["power"]
            minmaxPij = extrema(analysis.power.from.active)
            format["From-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPij[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPij[2] * scale["activePower"])), format["From-Bus Power Active"])

            minmaxPji = extrema(analysis.power.to.active)
            format["To-Bus Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPji[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPji[2] * scale["activePower"])), format["To-Bus Power Active"])
        end

        @inbounds for (label, i) in system.branch.label
            format["Label"] = max(length(label), format["Label"])
        end
    end

    return format
end

function formatGeneratorData(system::PowerSystem, analysis::AC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format = Dict(
        "Label" => 5,
        "Output Power Active" => 6,
        "Output Power Reactive" => 8,
        "Status" => 6,
        "power" => !isempty(analysis.power.generator.active)
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.generator.label[getLabel(system.generator, label, "generator")]
        format["Label"] = max(length(label), format["Label"])

        if format["power"]
            format["Output Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.generator.active[i] * scale["activePower"])), format["Output Power Active"])
            format["Output Power Reactive"] = max(length(Printf.@sprintf("%.4f", analysis.power.generator.reactive[i] * scale["reactivePower"])), format["Output Power Reactive"])
        end
    else
        if format["power"]
            minmaxPg = extrema(analysis.power.generator.active)
            format["Output Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPg[2] * scale["activePower"])), format["Output Power Active"])

            minmaxQg = extrema(analysis.power.generator.reactive)
            format["Output Power Reactive"] = max(length(Printf.@sprintf("%.4f", minmaxQg[1] * scale["reactivePower"])), length(Printf.@sprintf("%.4f", minmaxQg[2] * scale["reactivePower"])), format["Output Power Reactive"])
        end

        @inbounds for (label, i) in system.generator.label
            format["Label"] = max(length(label), format["Label"])
        end
    end

    return format
end

function formatGeneratorData(system::PowerSystem, analysis::DC, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format = Dict(
        "Label" => 5,
        "Output Power Active" => 12,
        "Status" => 6,
        "power" => !isempty(analysis.power.generator.active)
    )
    format = formatWidth(format, width)

    if isset(label)
        i = system.generator.label[getLabel(system.generator, label, "generator")]
        format["Label"] = max(length(label), format["Label"])
        if format["power"]
            format["Output Power Active"] = max(length(Printf.@sprintf("%.4f", analysis.power.generator.active[i] * scale["activePower"])), format["Output Power Active"])
        end
    else
        if format["power"]
            minmaxPg = extrema(analysis.power.generator.active)
            format["Output Power Active"] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * scale["activePower"])), length(Printf.@sprintf("%.4f", minmaxPg[2] * scale["activePower"])), format["Output Power Active"])
        end

        @inbounds for (label, i) in system.generator.label
            format["Label"] = max(length(label), format["Label"])
        end
    end

    return format
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
    format = formatBusSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(format["device"][1]) $(plosg("bus", format["device"][1])),
        while loads are installed at $(format["device"][2]) $(plosg("bus", format["device"][2])),
        and shunts are present at $(format["device"][3]) $(plosg("bus", format["device"][3]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, format["length"])

    summaryBlockHeader(io, format["length"], format["V"].title, system.bus.number)
    summaryBlock(io, format["V"], format["length"], unitList.voltageMagnitudeLive, "Magnitude")
    summaryBlock(io, format["θ"], format["length"], unitList.voltageAngleLive, "Angle"; line = true)

    if format["power"]
        if format["device"][1] != 0
            summaryBlockHeader(io, format["length"], format["Ps"].title, format["device"][1])
            summaryBlock(io, format["Ps"], format["length"], unitList.activePowerLive, "Active")
            summaryBlock(io, format["Qs"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
        end

        if format["device"][2] != 0
            summaryBlockHeader(io, format["length"], format["Pl"].title, format["device"][2])
            summaryBlock(io, format["Pl"], format["length"], unitList.activePowerLive, "Active")
            summaryBlock(io, format["Ql"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
        end

        summaryBlockHeader(io, format["length"], format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], format["length"], unitList.activePowerLive, "Active")
        summaryBlock(io, format["Qi"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)

        if format["device"][3] != 0
            summaryBlockHeader(io, format["length"], format["Ph"].title, format["device"][3])
            summaryBlock(io, format["Ph"], format["length"], unitList.activePowerLive, "Active")
            summaryBlock(io, format["Qh"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
        end
    end

    if format["current"]
        summaryBlockHeader(io, format["length"], format["I"].title, system.bus.number)
        summaryBlock(io, format["I"], format["length"], unitList.currentMagnitudeLive, "Magnitude")
        summaryBlock(io, format["ψ"], format["length"], unitList.currentAngleLive, "Angle"; line = true)
    end
end

function printBusSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format = formatBusSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "In the power system with $(system.bus.number) $(plosg("bus", system.bus.number)),
        in-service generators are located at $(format["device"][1]) $(plosg("bus", format["device"][1])),
        while loads are installed at $(format["device"][2]) $(plosg("bus", format["device"][2])),
        and shunts are present at $(format["device"][3]) $(plosg("bus", format["device"][3]))."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Bus Summary")
    summarySubheader(io, maxLine, format["length"])

    summaryBlockHeader(io, format["length"], format["θ"].title, system.bus.number)
    summaryBlock(io, format["θ"], format["length"], unitList.voltageAngleLive, "Angle"; line = true)

    if format["power"]
        if format["device"][1] != 0
            summaryBlockHeader(io, format["length"], format["Ps"].title, format["device"][1])
            summaryBlock(io, format["Ps"], format["length"], unitList.activePowerLive, "Active"; line = true)
        end

        if format["device"][2] != 0
            summaryBlockHeader(io, format["length"], format["Pl"].title, format["device"][2])
            summaryBlock(io, format["Pl"], format["length"], unitList.activePowerLive, "Active"; line = true)
        end

        summaryBlockHeader(io, format["length"], format["Pi"].title, system.bus.number)
        summaryBlock(io, format["Pi"], format["length"], unitList.activePowerLive, "Active"; line = true)
    end
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
    format = formatBranchSummary(system, analysis, scale)

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
            summaryBlock(io, format["Pline"], format["length"], unitList.activePowerLive, "Net Active")
            summaryBlock(io, format["Qline"], format["length"], unitList.reactivePowerLive, "Net Reactive"; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Pintr"].title, format["device"][5])
            summaryBlock(io, format["Pintr"], format["length"], unitList.activePowerLive, "Net Active")
            summaryBlock(io, format["Qintr"], format["length"], unitList.reactivePowerLive, "Net Reactive"; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Pshtr"].title, format["device"][6])
            summaryBlock(io, format["Pshtr"], format["length"], unitList.activePowerLive, "Net Active")
            summaryBlock(io, format["Qshtr"], format["length"], unitList.reactivePowerLive, "Net Reactive"; line = true)
        end

        if format["device"][8] != 0
            summaryBlockHeader(io, format["length"], format["Ptie"].title, format["device"][8])
            summaryBlock(io, format["Ptie"], format["length"], unitList.activePowerLive, "Net Active")
            summaryBlock(io, format["Qtie"], format["length"], unitList.reactivePowerLive, "Net Reactive"; line = true)
        end

        if format["device"][7] != 0
            summaryBlockHeader(io, format["length"], format["Pshunt"].title, format["device"][7])
            summaryBlock(io, format["Pshunt"], format["length"], unitList.activePowerLive, "Active")
            summaryBlock(io, format["Qshunt"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
        end

        if system.branch.layout.inservice != 0
            summaryBlockHeader(io, format["length"], format["Ploss"].title, system.branch.layout.inservice)
            summaryBlock(io, format["Ploss"], format["length"], unitList.activePowerLive, "Active")
            summaryBlock(io, format["Qloss"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
        end
    end

    if format["current"]
        if format["device"][4] != 0
            summaryBlockHeader(io, format["length"], format["Iline"].title, format["device"][4])
            summaryBlock(io, format["Iline"], format["length"], unitList.currentMagnitudeLive, "Magnitude")
            summaryBlock(io, format["ψline"], format["length"], unitList.currentAngleLive, "Angle"; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Iintr"].title, format["device"][5])
            summaryBlock(io, format["Iintr"], format["length"], unitList.currentMagnitudeLive, "Magnitude")
            summaryBlock(io, format["ψintr"], format["length"], unitList.currentAngleLive, "Angle"; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Ishtr"].title, format["device"][6])
            summaryBlock(io, format["Ishtr"], format["length"], unitList.currentMagnitudeLive, "Magnitude")
            summaryBlock(io, format["ψshtr"], format["length"], unitList.currentAngleLive, "Angle"; line = true)
        end
    end
end

function printBranchSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format = formatBranchSummary(system, analysis, scale)

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
            summaryBlock(io, format["Pline"], format["length"], unitList.activePowerLive, "Net Active"; line = true)
        end

        if format["device"][5] != 0
            summaryBlockHeader(io, format["length"], format["Pintr"].title, format["device"][5])
            summaryBlock(io, format["Pintr"], format["length"], unitList.activePowerLive, "Net Active"; line = true)
        end

        if format["device"][6] != 0
            summaryBlockHeader(io, format["length"], format["Pshtr"].title, format["device"][6])
            summaryBlock(io, format["Pshtr"], format["length"], unitList.activePowerLive, "Net Active"; line = true)
        end

        if format["device"][7] != 0
            summaryBlockHeader(io, format["length"], format["Ptie"].title, format["device"][7])
            summaryBlock(io, format["Ptie"], format["length"], unitList.activePowerLive, "Net Active"; line = true)
        end
    end
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
    format = formatGeneratorSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        summaryBlockHeader(io, format["length"], format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], format["length"], unitList.activePowerLive, "Active")
        summaryBlock(io, format["Qg"], format["length"], unitList.reactivePowerLive, "Reactive"; line = true)
    end
end

function printGeneratorSummary(system::PowerSystem, analysis::DC, io::IO = stdout)
    scale = printScale(system, prefix)
    format = formatGeneratorSummary(system, analysis, scale)

    Printf.@printf io "\n"

    maxLine = sum(format["length"][:]) + 17

    sentence = "The power system comprises $(system.generator.number) $(plosg("generator", system.generator.number; pl = "s")),
        of which $(system.generator.layout.inservice) $(isare(system.generator.layout.inservice)) in-service."

    summaryHeader(io, maxLine, cutSentenceParts(sentence, maxLine - 2), "Generator Summary")
    summarySubheader(io, maxLine, format["length"])

    if format["power"]
        summaryBlockHeader(io, format["length"], format["Pg"].title, system.generator.layout.inservice)
        summaryBlock(io, format["Pg"], format["length"], unitList.activePowerLive, "Active"; line = true)
    end
end

Base.@kwdef mutable struct SummaryData
    idxMin::Int64 = -1
    min::Float64 = Inf
    idxMax::Int64 = -1
    max::Float64 = -Inf
    total::Float64 = 0.0
    strmin::String = ""
    labelmin::String = ""
    strmax::String = ""
    labelmax::String = ""
    strtotal::String = "-"
    title::String = ""
end

function formatBusSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
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
        if prefix.voltageMagnitude != 0.0
            voltageMagnitude = (analysis.voltage.magnitude[i]) * (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
        else
            voltageMagnitude = analysis.voltage.magnitude[i]
        end

        minmaxsumPrint!(format["V"], voltageMagnitude, i)
        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if !isempty(system.bus.supply.generator[i])
            format["device"][1] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            format["device"][2] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            format["device"][3] += 1
        end

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
            if prefix.currentMagnitude != 0.0
                currentMagnitude = analysis.current.injection.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
            else
                currentMagnitude = analysis.current.injection.magnitude[i]
            end

            minmaxsumPrint!(format["I"], currentMagnitude, i)
            minmaxsumPrint!(format["ψ"], analysis.current.injection.angle[i], i)
        end
    end

    formatSummary!(format["V"], format["length"], system.bus.label, 1.0, system.bus.number; total = false)
    formatSummary!(format["θ"], format["length"], system.bus.label, scale["voltageAngle"], system.bus.number; total = false)

    if format["power"]
        if format["device"][1] != 0
            formatSummary!(format["Ps"], format["length"], system.bus.label, scale["activePower"], format["device"][1])
            formatSummary!(format["Qs"], format["length"], system.bus.label, scale["reactivePower"], format["device"][1])
        end

        if format["device"][2] != 0
            formatSummary!(format["Pl"], format["length"], system.bus.label, scale["activePower"], format["device"][2])
            formatSummary!(format["Ql"], format["length"], system.bus.label, scale["reactivePower"], format["device"][2])
        end

        formatSummary!(format["Pi"], format["length"], system.bus.label, scale["activePower"], system.bus.number)
        formatSummary!(format["Qi"], format["length"], system.bus.label, scale["reactivePower"], system.bus.number)

        if format["device"][3] != 0
            formatSummary!(format["Ph"], format["length"], system.bus.label, scale["activePower"], format["device"][3])
            formatSummary!(format["Qh"], format["length"], system.bus.label, scale["reactivePower"], format["device"][3])
        end
    end

    if format["current"]
        formatSummary!(format["I"], format["length"], system.bus.label, 1.0, system.bus.number; total = false)
        formatSummary!(format["ψ"], format["length"], system.bus.label, scale["currentAngle"], system.bus.number; total = false)
    end

    return format
end

function formatBusSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
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
        minmaxsumPrint!(format["θ"], analysis.voltage.angle[i], i)

        if !isempty(system.bus.supply.generator[i])
            format["device"][1] += 1
        end

        if system.bus.demand.active[i] != 0.0 || system.bus.demand.reactive[i] != 0.0
            format["device"][2] += 1
        end

        if system.bus.shunt.conductance[i] != 0.0 || system.bus.shunt.susceptance[i] != 0.0
            format["device"][3] += 1
        end

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

    formatSummary!(format["θ"], format["length"], system.bus.label, scale["voltageAngle"], system.bus.number; total = false)

    if format["power"]
        if format["device"][1] != 0
            formatSummary!(format["Ps"], format["length"], system.bus.label, scale["activePower"], format["device"][1])
        end

        if format["device"][2] != 0
            formatSummary!(format["Pl"], format["length"], system.bus.label, scale["activePower"], format["device"][2])
        end

        formatSummary!(format["Pi"], format["length"], system.bus.label, scale["activePower"], system.bus.number)
    end

    return format
end

function formatBranchSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
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
                from = system.branch.layout.from[i]
                if prefix.currentMagnitude != 0.0
                    currentSeries = analysis.current.series.magnitude[i] * system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[from] * system.base.voltage.prefix * prefix.currentMagnitude)
                else
                    currentSeries = analysis.current.series.magnitude[i]
                end

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
        formatSummary!(format["Pline"], format["length"], system.branch.label, scale["activePower"], format["device"][4]; total = false)
        formatSummary!(format["Qline"], format["length"], system.branch.label, scale["reactivePower"], format["device"][4]; total = false)

        formatSummary!(format["Pintr"], format["length"], system.branch.label, scale["activePower"], format["device"][5]; total = false)
        formatSummary!(format["Qintr"], format["length"], system.branch.label, scale["reactivePower"], format["device"][5]; total = false)

        formatSummary!(format["Pshtr"], format["length"], system.branch.label, scale["activePower"], format["device"][6]; total = false)
        formatSummary!(format["Qshtr"], format["length"], system.branch.label, scale["reactivePower"], format["device"][6]; total = false)

        formatSummary!(format["Ptie"], format["length"], system.branch.label, scale["activePower"], format["device"][8])
        formatSummary!(format["Qtie"], format["length"], system.branch.label, scale["reactivePower"], format["device"][8])

        formatSummary!(format["Pshunt"], format["length"], system.branch.label, scale["activePower"], format["device"][7])
        formatSummary!(format["Qshunt"], format["length"], system.branch.label, scale["reactivePower"],format["device"][7])

        formatSummary!(format["Ploss"], format["length"], system.branch.label, scale["activePower"], system.branch.layout.inservice)
        formatSummary!(format["Qloss"], format["length"], system.branch.label, scale["reactivePower"], system.branch.layout.inservice)
    end

    if format["current"]
        formatSummary!(format["Iline"], format["length"], system.branch.label, 1.0, format["device"][4]; total = false)
        formatSummary!(format["ψline"], format["length"], system.branch.label, scale["currentAngle"], format["device"][4]; total = false)

        formatSummary!(format["Iintr"], format["length"], system.branch.label, 1.0, format["device"][5]; total = false)
        formatSummary!(format["ψintr"], format["length"], system.branch.label, scale["currentAngle"], format["device"][5]; total = false)

        formatSummary!(format["Ishtr"], format["length"], system.branch.label, 1.0, format["device"][6]; total = false)
        formatSummary!(format["ψshtr"], format["length"], system.branch.label, scale["currentAngle"], format["device"][6]; total = false)
    end

    format["length"][6] = max(format["length"][6], length(" Net Reactive [$(unitList.reactivePowerLive)]"))

    return format
end

function formatBranchSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
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
        formatSummary!(format["Pline"], format["length"], system.branch.label, scale["activePower"], format["device"][4]; total = false)
        formatSummary!(format["Pintr"], format["length"], system.branch.label, scale["activePower"], format["device"][5]; total = false)
        formatSummary!(format["Pshtr"], format["length"], system.branch.label, scale["activePower"], format["device"][6]; total = false)
        formatSummary!(format["Ptie"], format["length"], system.branch.label, scale["activePower"], format["device"][7]; total = false)
    end

    format["length"][6] = max(format["length"][6], length(" Net Active [$(unitList.activePowerLive)]"))

    return format
end

function formatGeneratorSummary(system::PowerSystem, analysis::AC, scale::Dict{String, Float64})
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
        formatSummary!(format["Pg"], format["length"], system.generator.label, scale["activePower"], system.generator.layout.inservice)
        formatSummary!(format["Qg"], format["length"], system.generator.label, scale["reactivePower"], system.generator.layout.inservice)
    end

    format["length"][6] = max(format["length"][6], length(" Reactive [$(unitList.reactivePowerLive)]"))

    return format
end

function formatGeneratorSummary(system::PowerSystem, analysis::DC, scale::Dict{String, Float64})
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
        formatSummary!(format["Pg"], format["length"], system.generator.label, scale["activePower"], system.generator.layout.inservice)
    end

    format["length"][6] = max(format["length"][6], length(" Active [$(unitList.activePowerLive)]"))

    return format
end
