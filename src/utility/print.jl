"""
    printBus(system::PowerSystem, analysis::Analysis, io::IO)

The function prints voltages, powers, and currents related to buses. Optionally, an `IO`
may be passed as the last argument to redirect output.

!!! compat "Julia 1.10"
    The function [`printBus`](@ref printBus) requires Julia 1.10 or later.

# Examples
Print bus data after AC power flow analysis:
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

printBus(system, analysis)
```

Print bus data after DC power flow analysis:
```jldoctest
system = powerSystem("case14.h5")

analysis = dcPowerFlow(system)
solve!(system, analysis)
power!(system, analysis)

printBus(system, analysis)
```
"""
function printBus(system::PowerSystem, analysis::AC, io::IO = stdout)
    format = printFormatBus(system, analysis)
    Printf.@printf "\n"

    printBusLine(format, analysis)

    Printf.@printf("| %*s%s%*s | %*s%s%*s |",
        floor(Int, (format["length"][1] - 3) / 2), "", "Bus", ceil(Int, (format["length"][1] - 3) / 2) , "",
        floor(Int, (format["length"][2] + format["length"][3] - 4) / 2), "", "Voltage", ceil(Int, (format["length"][2] + format["length"][3] - 4) / 2) , "",
    )
    if format["power"]
        Printf.@printf(" %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s |",
            floor(Int, (format["length"][4] + format["length"][5] - 13) / 2), "", "Power Generation", ceil(Int, (format["length"][4] + format["length"][5] - 13) / 2) , "",
            floor(Int, (format["length"][6] + format["length"][7] - 9) / 2), "", "Power Demand", ceil(Int, (format["length"][6] + format["length"][7] - 9) / 2) , "",
            floor(Int, (format["length"][8] + format["length"][9] - 12) / 2), "", "Power Injection", ceil(Int, (format["length"][8] + format["length"][9] - 12) / 2) , "",
            floor(Int, (format["length"][10] + format["length"][11] - 8) / 2), "", "Shunt Power", ceil(Int, (format["length"][10] + format["length"][11] - 8) / 2) , "",
        )
    end
    if format["current"]
        Printf.@printf(" %*s%s%*s |",
            floor(Int, (format["length"][12] + format["length"][13] - 14) / 2), "", "Current Injection", ceil(Int, (format["length"][12] + format["length"][13] - 14) / 2) , ""
        )
    end
    Printf.@printf "\n"

    Printf.@printf("| %*s | %*s |",
        format["length"][1], "",
        format["length"][2] + format["length"][3] + 3, "",
    )
    if format["power"]
        Printf.@printf(" %*s | %*s | %*s | %*s |",
            format["length"][4] + format["length"][5] + 3, "",
            format["length"][6] + format["length"][7] + 3, "",
            format["length"][8] + format["length"][9] + 3, "",
            format["length"][10] + format["length"][11] + 3, "",
        )
    end
    if format["current"]
        Printf.@printf(" %*s |",
            format["length"][12] + format["length"][13] + 3, "",
        )
    end
    Printf.@printf "\n"

    Printf.@printf("| %*s | %*s | %*s ",
        format["length"][1], "",
        format["length"][2], "Magnitude",
        format["length"][3], "Angle",
    )
    if format["power"]
        Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
            format["length"][4], "Active",
            format["length"][5], "Reactive",
            format["length"][6], "Active",
            format["length"][7], "Reactive",
            format["length"][8], "Active",
            format["length"][9], "Reactive",
            format["length"][10], "Active",
            format["length"][11], "Reactive",
        )
    end
    if format["current"]
        Printf.@printf("| %*s | %*s ",
            format["length"][12], "Magnitude",
            format["length"][13], "Angle",
        )
    end
    Printf.@printf "|\n"

    Printf.@printf("| %*s | %*s | %*s ",
        format["length"][1], "",
        format["length"][2], "$(format["unit"][2])",
        format["length"][3], "$(format["unit"][3])",
    )
    if format["power"]
        Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
            format["length"][4], "$(format["unit"][4])",
            format["length"][5], "$(format["unit"][5])",
            format["length"][6], "$(format["unit"][4])",
            format["length"][7], "$(format["unit"][5])",
            format["length"][8], "$(format["unit"][4])",
            format["length"][9], "$(format["unit"][5])",
            format["length"][10], "$(format["unit"][4])",
            format["length"][11], "$(format["unit"][5])",
        )
    end
    if format["current"]
        Printf.@printf("| %*s | %*s ",
            format["length"][12], "$(format["unit"][6])",
            format["length"][13], "$(format["unit"][7])",
        )
    end
    Printf.@printf "|\n"

    Printf.@printf("|-%*s-|-%*s-|-%*s-",
        format["length"][1], "-"^format["length"][1],
        format["length"][2], "-"^format["length"][2],
        format["length"][3], "-"^format["length"][3],
    )
    if format["power"]
        Printf.@printf("|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
            format["length"][4], "-"^format["length"][4],
            format["length"][5], "-"^format["length"][5],
            format["length"][6], "-"^format["length"][6],
            format["length"][7], "-"^format["length"][7],
            format["length"][8], "-"^format["length"][8],
            format["length"][9], "-"^format["length"][9],
            format["length"][10], "-"^format["length"][10],
            format["length"][11], "-"^format["length"][11],
        )
    end
    if format["current"]
        Printf.@printf("|-%*s-|-%*s-",
        format["length"][12], "-"^format["length"][12],
        format["length"][13], "-"^format["length"][13]
        )
    end
    Printf.@printf "|\n"

    for (label, i) in system.bus.label
        if prefix.voltageMagnitude != 0.0
            voltageMagnitude = (analysis.voltage.magnitude[i] ) * (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
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

        Printf.@printf("| %*s | %*.4f | %*.4f ",
            format["length"][1], label,
            format["length"][2], voltageMagnitude,
            format["length"][3], analysis.voltage.angle[i] * format["scale"][3],
        )
        if format["power"]
            Printf.@printf("| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                format["length"][4], analysis.power.supply.active[i] * format["scale"][4],
                format["length"][5], analysis.power.supply.reactive[i] * format["scale"][5],
                format["length"][6], system.bus.demand.active[i] * format["scale"][4],
                format["length"][7], system.bus.demand.reactive[i] * format["scale"][5],
                format["length"][8], analysis.power.injection.active[i] * format["scale"][4],
                format["length"][9], analysis.power.injection.reactive[i] * format["scale"][5],
                format["length"][10], analysis.power.shunt.active[i] * format["scale"][4],
                format["length"][11], analysis.power.shunt.reactive[i] * format["scale"][5],
            )
        end
        if format["current"]
            Printf.@printf("| %*.4f | %*.4f ",
            format["length"][12], currentMagnitude * format["scale"][6],
            format["length"][13], analysis.current.injection.angle[i] * format["scale"][7]
            )
        end
        Printf.@printf "|\n"
    end

    printBusLine(format, analysis)
end

function printBus(system::PowerSystem, analysis::DC, io::IO = stdout)
    format = printFormatBus(system, analysis)
    Printf.@printf "\n"

    printBusLine(format, analysis)

    Printf.@printf("| %*s | %*s ",
        format["length"][1], "Bus",
        format["length"][2], "Voltage Angle",
    )
    if format["power"]
        Printf.@printf("| %*s | %*s | %*s ",
            format["length"][3], "Power Generation",
            format["length"][4], "Power Demand",
            format["length"][5], "Power Injection",
        )
    end
    Printf.@printf "|\n"

    Printf.@printf("| %*s | %*s ",
        format["length"][1], "",
        format["length"][2], "$(format["unit"][1])",
    )
    if format["power"]
        Printf.@printf("| %*s | %*s | %*s ",
            format["length"][3], "$(format["unit"][2])",
            format["length"][4], "$(format["unit"][2])",
            format["length"][5], "$(format["unit"][2])",
        )
    end
    Printf.@printf "|\n"

    Printf.@printf("|-%*s-|-%*s-",
        format["length"][1], "-"^format["length"][1],
        format["length"][2], "-"^format["length"][2],
    )
    if format["power"]
        Printf.@printf("|-%*s-|-%*s-|-%*s-",
            format["length"][3], "-"^format["length"][3],
            format["length"][4], "-"^format["length"][4],
            format["length"][5], "-"^format["length"][5],
        )
    end
    Printf.@printf "|\n"

    for (label, i) in system.bus.label
        Printf.@printf("| %*s | %*.4f ",
            format["length"][1], label,
            format["length"][2], analysis.voltage.angle[i] * format["scale"][1],
        )
        if format["power"]
            Printf.@printf("| %*.4f | %*.4f | %*.4f ",
                format["length"][3], analysis.power.supply.active[i] * format["scale"][2],
                format["length"][4], system.bus.demand.active[i] * format["scale"][2],
                format["length"][5], analysis.power.injection.active[i] * format["scale"][2],
            )
        end
        Printf.@printf "|\n"
    end

    printBusLine(format, analysis)
end

"""
    printBranch(system::PowerSystem, analysis::Analysis, io::IO)

The function prints powers and currents related to branches. Optionally, an `IO` may be
passed as the last argument to redirect output.

!!! compat "Julia 1.10"
    The function [`printBranch`](@ref printBranch) requires Julia 1.10 or later.

# Examples
Print branch data after AC power flow analysis:
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

printBranch(system, analysis)
```

Print branch data after DC power flow analysis:
```jldoctest
system = powerSystem("case14.h5")

analysis = dcPowerFlow(system)
solve!(system, analysis)
power!(system, analysis)

printBranch(system, analysis)
```
"""
function printBranch(system::PowerSystem, analysis::AC, io::IO = stdout)
    format = printFormatBranch(system, analysis)

    if format["power"] || format["current"]
        Printf.@printf "\n"

        printBranchLine(format)

        Printf.@printf("| %*s%s%*s ", floor(Int, (format["length"][1] - 6) / 2), "", "Branch", ceil(Int, (format["length"][1] - 6) / 2) , "",)

        if format["power"]
            Printf.@printf("| %*s%s%*s | %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                floor(Int, (format["length"][2] + format["length"][3] - 11) / 2), "", "From-Bus Power", ceil(Int, (format["length"][2] + format["length"][3] - 11) / 2) , "",
                floor(Int, (format["length"][4] + format["length"][5] - 9) / 2), "", "To-Bus Power", ceil(Int, (format["length"][4] + format["length"][5] - 9) / 2) , "",
                floor(Int, (format["length"][6] + format["length"][7] - 8) / 2), "", "Shunt Power", ceil(Int, (format["length"][6] + format["length"][7] - 8) / 2) , "",
                floor(Int, (format["length"][8] + format["length"][9] - 9) / 2), "", "Series Power", ceil(Int, (format["length"][8] + format["length"][9] - 9) / 2) , "",
            )
        end
        if format["current"]
            Printf.@printf("| %*s%s%*s | %*s%s%*s | %*s%s%*s ",
                floor(Int, (format["length"][10] + format["length"][11] - 13) / 2), "", "From-Bus Current", ceil(Int, (format["length"][10] + format["length"][11] - 13) / 2) , "",
                floor(Int, (format["length"][12] + format["length"][13] - 11) / 2), "", "To-Bus Current", ceil(Int, (format["length"][12] + format["length"][13] - 11) / 2) , "",
                floor(Int, (format["length"][14] + format["length"][15] - 11) / 2), "", "Series Current", ceil(Int, (format["length"][14] + format["length"][15] - 11) / 2) , "",
            )
        end
        Printf.@printf "|\n"

        Printf.@printf("| %*s |",
            format["length"][1], "",
        )
        if format["power"]
            Printf.@printf(" %*s | %*s | %*s | %*s |",
                format["length"][2] + format["length"][3] + 3, "",
                format["length"][4] + format["length"][5] + 3, "",
                format["length"][6] + format["length"][7] + 3, "",
                format["length"][8] + format["length"][9] + 3, "",
            )
        end
        if format["current"]
            Printf.@printf(" %*s | %*s | %*s |",
                format["length"][10] + format["length"][11] + 3, "",
                format["length"][12] + format["length"][13] + 3, "",
                format["length"][14] + format["length"][15] + 3, "",
            )
        end
        Printf.@printf "\n"

        Printf.@printf("| %*s ", format["length"][1], "")

        if format["power"]
            Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                format["length"][2], "Active",
                format["length"][3], "Reactive",
                format["length"][4], "Active",
                format["length"][5], "Reactive",
                format["length"][6], "Active",
                format["length"][7], "Reactive",
                format["length"][8], "Active",
                format["length"][9], "Reactive",
            )
        end
        if format["current"]
            Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s ",
                format["length"][10], "Magnitude",
                format["length"][11], "Angle",
                format["length"][12], "Magnitude",
                format["length"][13], "Angle",
                format["length"][14], "Magnitude",
                format["length"][15], "Angle",
            )
        end
        Printf.@printf "|\n"

        Printf.@printf("| %*s ", format["length"][1], "")

        if format["power"]
            Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s | %*s | %*s ",
                format["length"][2], "$(format["unit"][2])",
                format["length"][3], "$(format["unit"][3])",
                format["length"][4], "$(format["unit"][2])",
                format["length"][5], "$(format["unit"][3])",
                format["length"][6], "$(format["unit"][2])",
                format["length"][7], "$(format["unit"][3])",
                format["length"][8], "$(format["unit"][2])",
                format["length"][9], "$(format["unit"][3])",
            )
        end
        if format["current"]
            Printf.@printf("| %*s | %*s | %*s | %*s | %*s | %*s ",
                format["length"][10], "$(format["unit"][4])",
                format["length"][11], "$(format["unit"][5])",
                format["length"][12], "$(format["unit"][4])",
                format["length"][13], "$(format["unit"][5])",
                format["length"][14], "$(format["unit"][4])",
                format["length"][15], "$(format["unit"][5])",
            )
        end
        Printf.@printf "|\n"

        Printf.@printf("|-%*s-", format["length"][1], "-"^format["length"][1]
        )
        if format["power"]
            Printf.@printf("|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                format["length"][2], "-"^format["length"][2],
                format["length"][3], "-"^format["length"][3],
                format["length"][4], "-"^format["length"][4],
                format["length"][5], "-"^format["length"][5],
                format["length"][6], "-"^format["length"][6],
                format["length"][7], "-"^format["length"][7],
                format["length"][8], "-"^format["length"][8],
                format["length"][9], "-"^format["length"][9],
            )
        end
        if format["current"]
            Printf.@printf("|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-|-%*s-",
                format["length"][10], "-"^format["length"][10],
                format["length"][11], "-"^format["length"][11],
                format["length"][12], "-"^format["length"][12],
                format["length"][13], "-"^format["length"][13],
                format["length"][14], "-"^format["length"][14],
                format["length"][15], "-"^format["length"][15],
            )
        end
        Printf.@printf "|\n"

        for (label, i) in system.branch.label
            Printf.@printf("| %*s ", format["length"][1], label)

            if format["power"]
                Printf.@printf("| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                    format["length"][2], analysis.power.from.active[i] * format["scale"][2],
                    format["length"][3], analysis.power.from.reactive[i] * format["scale"][3],
                    format["length"][4], analysis.power.to.active[i] * format["scale"][2],
                    format["length"][5], analysis.power.to.reactive[i] * format["scale"][3],
                    format["length"][6], analysis.power.charging.active[i] * format["scale"][2],
                    format["length"][7], analysis.power.charging.reactive[i] * format["scale"][3],
                    format["length"][8], analysis.power.series.active[i] * format["scale"][2],
                    format["length"][9], analysis.power.series.reactive[i] * format["scale"][3],
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

                Printf.@printf("| %*.4f | %*.4f | %*.4f | %*.4f | %*.4f | %*.4f ",
                    format["length"][10], currentMagnitudeFrom * format["scale"][4],
                    format["length"][11], analysis.current.from.angle[i] * format["scale"][5],
                    format["length"][12], currentMagnitudeTo * format["scale"][4],
                    format["length"][13], analysis.current.to.angle[i] * format["scale"][5],
                    format["length"][14], currentMagnitudeS * format["scale"][4],
                    format["length"][15], analysis.current.series.angle[i] * format["scale"][5]
                )
            end

            Printf.@printf "|\n"
        end
        printBranchLine(format)
    end
end

function printBranch(system::PowerSystem, analysis::DC, io::IO = stdout)
    format = printFormatBranch(system, analysis)

    if format["power"]
        Printf.@printf "\n"

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 8)

        Printf.@printf("| %*s | %*s | %*s |\n",
            format["length"][1], "Branch",
            format["length"][2], "From-Bus Power",
            format["length"][3], "To-Bus Power",
        )

        Printf.@printf("| %*s | %*s | %*s |\n",
            format["length"][1], "",
            format["length"][2], "$(format["unit"])",
            format["length"][3], "$(format["unit"])",
        )

        Printf.@printf("|-%*s-|-%*s-|-%*s-|\n",
            format["length"][1], "-"^format["length"][1],
            format["length"][2], "-"^format["length"][2],
            format["length"][3], "-"^format["length"][3],
        )

        for (label, i) in system.branch.label
            Printf.@printf("| %*s | %*.4f | %*.4f |\n",
                format["length"][1], label,
                format["length"][2], analysis.power.from.active[i] * format["scale"],
                format["length"][3], analysis.power.to.active[i] * format["scale"],
            )
        end

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 8)
    end
end

"""
    printGenerator(system::PowerSystem, analysis::Analysis, io::IO)

The function prints powers related to generators. Optionally, an `IO` may be passed as the
last argument to redirect output.

!!! compat "Julia 1.10"
    The function [`printGenerator`](@ref printGenerator) requires Julia 1.10 or later.

# Examples
Print generator data after AC power flow analysis:
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

printGenerator(system, analysis)
```

Print generator data after DC power flow analysis:
```jldoctest
system = powerSystem("case14.h5")

analysis = dcPowerFlow(system)
solve!(system, analysis)
power!(system, analysis)

printGenerator(system, analysis)
```
"""
function printGenerator(system::PowerSystem, analysis::AC, io::IO = stdout)
    format = printFormatGenerator(system, analysis)

    if format["power"]
        Printf.@printf "\n"

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 8)

        Printf.@printf("| %*s%s%*s | %*s%s%*s |\n",
            floor(Int, (format["length"][1] - 9) / 2), "", "Generator", ceil(Int, (format["length"][1] - 9) / 2) , "",
            floor(Int, (format["length"][2] + format["length"][3] - 9) / 2), "", "Output Power", ceil(Int, (format["length"][2] + format["length"][3] - 9) / 2) , "",
        )

        Printf.@printf("| %*s | %*s |\n",
            format["length"][1], "",
            format["length"][2] + format["length"][3] + 3, "")

        Printf.@printf("| %*s | %*s | %*s |\n",
            format["length"][1], "",
            format["length"][2], "Active",
            format["length"][3], "Reactive",
        )

        Printf.@printf("| %*s | %*s | %*s |\n",
            format["length"][1], "",
            format["length"][2], "$(format["unit"][1])",
            format["length"][3], "$(format["unit"][2])",
        )

        Printf.@printf("|-%*s-|-%*s-|-%*s-|\n",
            format["length"][1], "-"^format["length"][1],
            format["length"][2], "-"^format["length"][2],
            format["length"][3], "-"^format["length"][3],
        )

        for (label, i) in system.generator.label
            Printf.@printf("| %*s | %*.4f | %*.4f |\n",
                format["length"][1], label,
                format["length"][2], analysis.power.generator.active[i] * format["scale"][1],
                format["length"][3], analysis.power.generator.reactive[i] * format["scale"][2],
            )
        end

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 8)
    end
end

function printGenerator(system::PowerSystem, analysis::DC, io::IO = stdout)
    format = printFormatGenerator(system, analysis)

    if format["power"]
        Printf.@printf "\n"

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 5)

        Printf.@printf("| %*s | %*s |\n",
            format["length"][1], "Generator",
            format["length"][2], "Output Power",
        )

        Printf.@printf("| %*s | %*s |\n",
            format["length"][1], "",
            format["length"][2], "$(format["unit"])",
        )

        Printf.@printf("|-%*s-|-%*s-|\n",
            format["length"][1], "-"^format["length"][1],
            format["length"][2], "-"^format["length"][2],
        )

        for (label, i) in system.generator.label
            Printf.@printf("| %*s | %*.4f |\n",
                format["length"][1], label,
                format["length"][2], analysis.power.generator.active[i] * format["scale"],
            )
        end

        Printf.@printf "|%s|\n" "-"^(sum(format["length"]) + 5)
    end
end

function printFormatBus(system::PowerSystem, analysis::AC)
    errorVoltage(analysis.voltage.magnitude)

    format = Dict(
        "length" => [3; 9; 5; 6; 8; 6; 8; 6; 8; 6; 8; 9; 5],
        "unit" => [""; "[pu]"; "[rad]"; "[pu]"; "[pu]"; "[pu]"; "[rad]"],
        "scale" => [0.0; 0.0; 1.0; 1.0; 1.0; 1.0; 1.0],
        "power" => !isempty(analysis.power.injection.active),
        "current" => !isempty(analysis.current.injection.magnitude)
    )

    if prefix.voltageMagnitude != 0.0
        format["unit"][2] = "[$(findKey(prefixList, prefix.voltageMagnitude))V]"
    else
        maxV = maximum(analysis.voltage.magnitude)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", maxV)), format["length"][2])
    end

    if prefix.voltageAngle != 0.0
        format["unit"][3] = "[deg]"
        format["scale"][3] = 1 / prefix.voltageAngle
    end
    minmaxT = extrema(analysis.voltage.angle)
    format["length"][3] = max(length(Printf.@sprintf("%.4f", minmaxT[1] * format["scale"][3])), length(Printf.@sprintf("%.4f", minmaxT[2] * format["scale"][3])), format["length"][3])

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"][4] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"][4] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPg = extrema(analysis.power.supply.active)
        format["length"][4] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * format["scale"][4])), length(Printf.@sprintf("%.4f", minmaxPg[2] * format["scale"][4])), format["length"][4])

        minmaxPl = extrema(system.bus.demand.active)
        format["length"][6] = max(length(Printf.@sprintf("%.4f", minmaxPl[1] * format["scale"][4])), length(Printf.@sprintf("%.4f", minmaxPl[2] * format["scale"][4])), format["length"][6])

        minmaxPi = extrema(analysis.power.injection.active)
        format["length"][8] = max(length(Printf.@sprintf("%.4f", minmaxPi[1] * format["scale"][4])), length(Printf.@sprintf("%.4f", minmaxPi[2] * format["scale"][4])), format["length"][8])

        minmaxPsi = extrema(analysis.power.shunt.active)
        format["length"][10] = max(length(Printf.@sprintf("%.4f", minmaxPsi[1] * format["scale"][4])), length(Printf.@sprintf("%.4f", minmaxPsi[2] * format["scale"][4])), format["length"][10])

        if prefix.reactivePower != 0.0
            format["unit"][5] = "[$(findKey(prefixList, prefix.reactivePower))VAr]"
            format["scale"][5] = system.base.power.value * system.base.power.prefix / prefix.reactivePower
        end

        minmaxQg = extrema(analysis.power.supply.reactive)
        format["length"][5] = max(length(Printf.@sprintf("%.4f", minmaxQg[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxQg[2] * format["scale"][5])), format["length"][5])

        minmaxQl = extrema(system.bus.demand.reactive)
        format["length"][7] = max(length(Printf.@sprintf("%.4f", minmaxQl[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxQl[2] * format["scale"][5])), format["length"][7])

        minmaxQi = extrema(analysis.power.injection.reactive)
        format["length"][9] = max(length(Printf.@sprintf("%.4f", minmaxQi[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxQi[2] * format["scale"][5])), format["length"][9])

        minmaxQsi = extrema(analysis.power.shunt.reactive)
        format["length"][11] = max(length(Printf.@sprintf("%.4f", minmaxQsi[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxQsi[2] * format["scale"][5])), format["length"][11])
    end

    if format["current"]
        if prefix.currentMagnitude != 0.0
            format["unit"][6] = "[$(findKey(prefixList, prefix.currentMagnitude))A]"
        else
            maxI = maximum(analysis.current.injection.magnitude)
            format["length"][12] = max(length(Printf.@sprintf("%.4f", maxI)), format["length"][12])
        end

        if prefix.currentAngle != 0.0
            format["unit"][7] = "[deg]"
            format["scale"][7] = 1 / prefix.currentAngle
        end
        minmaxW = extrema(analysis.current.injection.angle)
        format["length"][13] = max(length(Printf.@sprintf("%.4f", minmaxW[1] * format["scale"][7])), length(Printf.@sprintf("%.4f", minmaxW[2] * format["scale"][7])), format["length"][13])
    end

    @inbounds for (label, i) in system.bus.label
        format["length"][1] = max(length(label), format["length"][1])

        if prefix.voltageMagnitude != 0.0
            scaleV = (system.base.voltage.value[i] * system.base.voltage.prefix) / prefix.voltageMagnitude
            format["length"][2] = max(length(Printf.@sprintf("%.4f", analysis.voltage.magnitude[i] * scaleV)), format["length"][2])
        end

        if format["current"] && prefix.currentMagnitude != 0.0
            scaleI = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[i] * system.base.voltage.prefix * prefix.currentMagnitude)
            format["length"][12] = max(length(Printf.@sprintf("%.4f", analysis.current.injection.magnitude[i] * scaleI)), format["length"][12])
        end
    end

    return format
end

function printFormatBus(system::PowerSystem, analysis::DC)
    errorVoltage(analysis.voltage.angle)

    format = Dict(
        "length" => [3; 13; 16; 12; 16],
        "unit" => ["[rad]"; "[pu]"],
        "scale" => [1.0; 1.0],
        "power" => !isempty(analysis.power.injection.active),
    )

    if prefix.voltageAngle != 0.0
        format["unit"][1] = "[deg]"
        format["scale"][1] = 1 / prefix.voltageAngle
    end
    minmaxT = extrema(analysis.voltage.angle)
    format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxT[1] * format["scale"][1])), length(Printf.@sprintf("%.4f", minmaxT[2] * format["scale"][1])), format["length"][2])

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"][2] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"][2] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPg = extrema(analysis.power.supply.active)
        format["length"][3] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPg[2] * format["scale"][2])), format["length"][3])

        minmaxPl = extrema(system.bus.demand.active)
        format["length"][4] = max(length(Printf.@sprintf("%.4f", minmaxPl[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPl[2] * format["scale"][2])), format["length"][4])

        minmaxPi = extrema(analysis.power.injection.active)
        format["length"][5] = max(length(Printf.@sprintf("%.4f", minmaxPi[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPi[2] * format["scale"][2])), format["length"][5])
    end

    @inbounds for (label, i) in system.bus.label
        format["length"][1] = max(length(label), format["length"][1])
    end

    return format
end

function printFormatBranch(system::PowerSystem, analysis::AC)
    format = Dict(
        "length" => [6; 6; 8; 6; 8; 6; 8; 6; 8; 9; 5; 9; 5; 9; 5],
        "unit" => [""; "[pu]"; "[pu]"; "[pu]"; "[rad]"],
        "scale" => [0.0; 1.0; 1.0; 1.0; 1.0],
        "power" => !isempty(analysis.power.injection.active),
        "current" => !isempty(analysis.current.injection.magnitude)
    )

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"][2] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"][2] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPij = extrema(analysis.power.from.active)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxPij[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPij[2] * format["scale"][2])), format["length"][2])

        minmaxPji = extrema(analysis.power.to.active)
        format["length"][4] = max(length(Printf.@sprintf("%.4f", minmaxPji[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPji[2] * format["scale"][2])), format["length"][4])

        minmaxPsi = extrema(analysis.power.charging.active)
        format["length"][6] = max(length(Printf.@sprintf("%.4f", minmaxPsi[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPsi[2] * format["scale"][2])), format["length"][6])

        minmaxPli = extrema(analysis.power.series.active)
        format["length"][8] = max(length(Printf.@sprintf("%.4f", minmaxPli[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxPli[2] * format["scale"][2])), format["length"][8])

        if prefix.reactivePower != 0.0
            format["unit"][3] = "[$(findKey(prefixList, prefix.reactivePower))VAr]"
            format["scale"][3] = system.base.power.value * system.base.power.prefix / prefix.reactivePower
        end

        minmaxQij = extrema(analysis.power.from.reactive)
        format["length"][3] = max(length(Printf.@sprintf("%.4f", minmaxQij[1] * format["scale"][3])), length(Printf.@sprintf("%.4f", minmaxQij[2] * format["scale"][3])), format["length"][3])

        minmaxQji = extrema(analysis.power.to.reactive)
        format["length"][5] = max(length(Printf.@sprintf("%.4f", minmaxQji[1] * format["scale"][3])), length(Printf.@sprintf("%.4f", minmaxQji[2] * format["scale"][3])), format["length"][5])

        minmaxQsi = extrema(analysis.power.charging.reactive)
        format["length"][7] = max(length(Printf.@sprintf("%.4f", minmaxQsi[1] * format["scale"][3])), length(Printf.@sprintf("%.4f", minmaxQsi[2] * format["scale"][3])), format["length"][7])

        minmaxQli = extrema(analysis.power.series.reactive)
        format["length"][9] = max(length(Printf.@sprintf("%.4f", minmaxQli[1] * format["scale"][3])), length(Printf.@sprintf("%.4f", minmaxQli[2] * format["scale"][3])), format["length"][9])
    end

    if format["current"]
        if prefix.currentMagnitude != 0.0
            format["unit"][4] = "[$(findKey(prefixList, prefix.currentMagnitude))A]"
        else
            maxIij = maximum(analysis.current.from.magnitude)
            format["length"][10] = max(length(Printf.@sprintf("%.4f", maxIij)), format["length"][10])

            maxIji = maximum(analysis.current.to.magnitude)
            format["length"][12] = max(length(Printf.@sprintf("%.4f", maxIji)), format["length"][12])

            maxIs = maximum(analysis.current.series.magnitude)
            format["length"][14] = max(length(Printf.@sprintf("%.4f", maxIs)), format["length"][14])
        end

        if prefix.currentAngle != 0.0
            format["unit"][5] = "[deg]"
            format["scale"][5] = 1 / prefix.currentAngle
        end

        minmaxWij = extrema(analysis.current.from.angle)
        format["length"][11] = max(length(Printf.@sprintf("%.4f", minmaxWij[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxWij[2] * format["scale"][5])), format["length"][11])

        minmaxWji = extrema(analysis.current.to.angle)
        format["length"][13] = max(length(Printf.@sprintf("%.4f", minmaxWji[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxWji[2] * format["scale"][5])), format["length"][13])

        minmaxWs = extrema(analysis.current.series.angle)
        format["length"][15] = max(length(Printf.@sprintf("%.4f", minmaxWs[1] * format["scale"][5])), length(Printf.@sprintf("%.4f", minmaxWs[2] * format["scale"][5])), format["length"][15])
    end

    @inbounds for (label, i) in system.branch.label
        format["length"][1] = max(length(label), format["length"][1])

        if format["current"] && prefix.currentMagnitude != 0.0
            from = system.branch.layout.from[i]
            scaleIij = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[from] * system.base.voltage.prefix * prefix.currentMagnitude)
            format["length"][10] = max(length(Printf.@sprintf("%.4f", analysis.current.from.magnitude[i] * scaleIij)), format["length"][10])

            to = system.branch.layout.to[i]
            scaleIji = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[to] * system.base.voltage.prefix * prefix.currentMagnitude)
            format["length"][12] = max(length(Printf.@sprintf("%.4f", analysis.current.to.magnitude[i] * scaleIji)), format["length"][12])

            format["length"][14] = max(length(Printf.@sprintf("%.4f", analysis.current.series.magnitude[i] * scaleIij)), format["length"][14])
        end
    end

    return format
end

function printFormatBranch(system::PowerSystem, analysis::DC)
    format = Dict(
        "length" => [6; 14; 12],
        "unit" => "[pu]",
        "scale" => 1.0,
        "power" => !isempty(analysis.power.from.active),
    )

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPij = extrema(analysis.power.from.active)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxPij[1] * format["scale"])), length(Printf.@sprintf("%.4f", minmaxPij[2] * format["scale"])), format["length"][2])

        minmaxPji = extrema(analysis.power.to.active)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxPji[1] * format["scale"])), length(Printf.@sprintf("%.4f", minmaxPji[2] * format["scale"])), format["length"][2])
    end

    @inbounds for (label, i) in system.branch.label
        format["length"][1] = max(length(label), format["length"][1])
    end

    return format
end

function printFormatGenerator(system::PowerSystem, analysis::AC)
    format = Dict(
        "length" => [9; 6; 8],
        "unit" => ["[pu]"; "[pu]"],
        "scale" => [1.0; 1.0],
        "power" => !isempty(analysis.power.generator.active)
    )

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"][1] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"][1] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPg = extrema(analysis.power.generator.active)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * format["scale"][1])), length(Printf.@sprintf("%.4f", minmaxPg[2] * format["scale"][1])), format["length"][2])

        if prefix.reactivePower != 0.0
            format["unit"][2] = "[$(findKey(prefixList, prefix.reactivePower))VAr]"
            format["scale"][2] = system.base.power.value * system.base.power.prefix / prefix.reactivePower
        end

        minmaxQg = extrema(analysis.power.generator.reactive)
        format["length"][3] = max(length(Printf.@sprintf("%.4f", minmaxQg[1] * format["scale"][2])), length(Printf.@sprintf("%.4f", minmaxQg[2] * format["scale"][2])), format["length"][3])
    end

    @inbounds for (label, i) in system.generator.label
        format["length"][1] = max(length(label), format["length"][1])
    end

    return format
end

function printFormatGenerator(system::PowerSystem, analysis::DC)
    format = Dict(
        "length" => [9; 12],
        "unit" => "[pu]",
        "scale" => 1.0,
        "power" => !isempty(analysis.power.generator.active)
    )

    if format["power"]
        if prefix.activePower != 0.0
            format["unit"] = "[$(findKey(prefixList, prefix.activePower))W]"
            format["scale"] = system.base.power.value * system.base.power.prefix / prefix.activePower
        end

        minmaxPg = extrema(analysis.power.generator.active)
        format["length"][2] = max(length(Printf.@sprintf("%.4f", minmaxPg[1] * format["scale"][1])), length(Printf.@sprintf("%.4f", minmaxPg[2] * format["scale"][1])), format["length"][2])
    end

    @inbounds for (label, i) in system.generator.label
        format["length"][1] = max(length(label), format["length"][1])
    end

    return format
end

function printBusLine(format::Dict{String, Any}, analysis::AC)
    Printf.@printf "|%s" "-"^(sum(format["length"][1:3]) + 8)
    if format["power"]
        Printf.@printf "%s" "-"^(sum(format["length"][4:11]) + 24)
    end
    if format["current"]
        Printf.@printf "%s" "-"^(sum(format["length"][12:13]) + 6)
    end
    Printf.@printf "|\n"
end

function printBusLine(format::Dict{String, Any}, analysis::DC)
    Printf.@printf "|%s" "-"^(sum(format["length"][1:2]) + 5)
    if format["power"]
        Printf.@printf "%s" "-"^(sum(format["length"][3:5]) + 9)
    end
    Printf.@printf "|\n"
end

function printBranchLine(format::Dict{String, Any})
    Printf.@printf "|%s" "-"^(format["length"][1] + 2)
    if format["power"]
        Printf.@printf "%s" "-"^(sum(format["length"][2:9]) + 24)
    end
    if format["current"]
        Printf.@printf "%s" "-"^(sum(format["length"][10:15]) + 18)
    end
    Printf.@printf "|\n"
end