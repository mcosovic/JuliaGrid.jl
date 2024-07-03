"""
    printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints data related to voltmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding voltmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

!!! compat "Julia 1.10"
    The function [`printBusData`](@ref printBusData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
power!(system, analysis)

# Print data for all voltmeters
printVoltmeterData(system, device, analysis)

# Print data for specific voltmeters
width = Dict("Measurement Variance" => 9)
printVoltmeterData(system, device, analysis; label = 1, width, header = true)
printVoltmeterData(system, device, analysis; label = 6, width)
printVoltmeterData(system, device, analysis; label = 8, width, footer = true)
```
"""
function printVoltmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    voltage = Polar(Float64[], Float64[])

    _printVoltmeterData(system, device, voltage, io, label, header, footer, width)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printVoltmeterData(system, device, analysis.voltage, io, label, header, footer, width)
end

function _printVoltmeterData(system::PowerSystem, device::Measurement, voltage::Polar, io::IO,
    label::L, header::B, footer::Bool, width::Dict{String, Int64})

    voltmeter = device.voltmeter

    format = formatVoltmeterData(system, voltmeter, voltage, label, width)
    labels, header = toggleLabelHeader(label, voltmeter, voltmeter.label, header, "voltmeter")

    if format["device"]
        maxLine = maxLineDevice(format)
        printTitle(maxLine, "Voltmeter Data", header, io)
        headerDevice(io, format, header, maxLine, label, unitList.voltageMagnitudeLive)

        scale = 1.0
        for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = (system.base.voltage.value[indexBus] * system.base.voltage.prefix) / prefix.voltageMagnitude
            end

            printDevice(io, format, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, width::Dict{String,Int64})
    format, minmax = formatDevice(voltmeter.magnitude.mean, voltage.magnitude)
    format = formatWidth(format, width)
    labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

    if format["device"]
        scale = 1.0
        for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = (system.base.voltage.value[indexBus] * system.base.voltage.prefix) / prefix.voltageMagnitude
            end

            formatDevice(format, minmax, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus)
        end
        formatDevice(format, minmax)
    end

    return format
end

"""
    printAmmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints data related to ammeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding ammeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

!!! compat "Julia 1.10"
    The function [`printBusData`](@ref printBusData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
current!(system, analysis)

# Print data for all ammeters
printAmmeterData(system, device, analysis)

# Print data for specific ammeters
width = Dict("Measurement Variance" => 9)
printAmmeterData(system, device, analysis; label = "From 1", width, header = true)
printAmmeterData(system, device, analysis; label = "From 4", width)
printAmmeterData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printAmmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printAmmeterData(system, device, current, io, label, header, footer, width)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printAmmeterData(system, device, analysis.current, io, label, header, footer, width)
end

function _printAmmeterData(system::PowerSystem, device::Measurement, current::ACCurrent, io::IO,
    label::L, header::B, footer::Bool, width::Dict{String, Int64})

    ammeter = device.ammeter

    format = formatAmmeterData(system, ammeter, current, label, width)
    labels, header = toggleLabelHeader(label, ammeter, ammeter.label, header, "ammeter")

    if format["device"]
        maxLine = maxLineDevice(format)
        printTitle(maxLine, "Ammeter Data", header, io)
        headerDevice(io, format, header, maxLine, label, unitList.currentMagnitudeLive)

        scale = 1.0
        for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    j = system.branch.layout.from[indexBranch]
                else
                    j = system.branch.layout.to[indexBranch]
                end
                scale = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, format, label, ammeter.magnitude, estimate, scale, i, indexBranch)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, width::Dict{String,Int64})
    format, minmax = formatDevice(ammeter.magnitude.mean, current.from.magnitude)
    format = formatWidth(format, width)
    labels = toggleLabel(label, ammeter, ammeter.label, "ammeter")

    if format["device"]
        scale = 1.0
        for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    j = system.branch.layout.from[indexBranch]
                else
                    j = system.branch.layout.to[indexBranch]
                end
                scale = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            formatDevice(format, minmax, label, ammeter.magnitude, estimate, scale, i, indexBranch)
        end
        formatDevice(format, minmax)
    end

    return format
end

"""
    printWattmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints data related to wattmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding wattmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

!!! compat "Julia 1.10"
    The function [`printBusData`](@ref printBusData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
power!(system, analysis)

# Print data for all wattmeters
printWattmeterData(system, device, analysis)

# Print data for specific wattmeters
width = Dict("Measurement Mean" => 7)
printWattmeterData(system, device, analysis; label = 2, width, header = tsrue)
printWattmeterData(system, device, analysis; label = 5, width)
printWattmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printWattmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), nothing)

    _printWattmeterData(system, device, power, io, label, header, footer, width)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printWattmeterData(system, device, analysis.power, io, label, header, footer, width)
end

function _printWattmeterData(system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower}, io::IO,
    label::L, header::B, footer::Bool, width::Dict{String, Int64})

    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    format = formatWattmeterData(system, wattmeter, power, scale, label, width)
    labels, header = toggleLabelHeader(label, wattmeter, wattmeter.label, header, "wattmeter")

    if format["device"]
        maxLine = maxLineDevice(format)
        printTitle(maxLine, "Wattmeter Data", header, io)
        headerDevice(io, format, header, maxLine, label, unitList.activePowerLive)

        for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, format, label, wattmeter.active, estimate, scale["activePower"], i, wattmeter.layout.index[i])
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatWattmeterData(system::PowerSystem, wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format, minmax = formatDevice(wattmeter.active.mean, power.injection.active)
    format = formatWidth(format, width)
    labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

    if format["device"]
        for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            formatDevice(format, minmax, label, wattmeter.active, estimate, scale["activePower"], i, wattmeter.layout.index[i])
        end
        formatDevice(format, minmax)
    end

    return format
end

"""
    printVarmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints data related to varmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding varmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

!!! compat "Julia 1.10"
    The function [`printBusData`](@ref printBusData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
power!(system, analysis)

# Print data for all varmeters
printVarmeterData(system, device, analysis)

# Print data for specific varmeters
width = Dict("Measurement Mean" => 7)
printVarmeterData(system, device, analysis; label = 2, width, header = true)
printVarmeterData(system, device, analysis; label = 5, width)
printVarmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printVarmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), nothing)

    _printVarmeterData(system, device, power, io, label, header, footer, width)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printVarmeterData(system, device, analysis.power, io, label, header, footer, width)
end

function _printVarmeterData(system::PowerSystem, device::Measurement, power::ACPower, io::IO,
    label::L, header::B, footer::Bool, width::Dict{String, Int64})

    varmeter = device.varmeter

    scale = printScale(system, prefix)
    format = formatVarmeterData(system, varmeter, power, scale, label, width)
    labels, header = toggleLabelHeader(label, varmeter, varmeter.label, header, "varmeter")

    if format["device"]
        maxLine = maxLineDevice(format)
        printTitle(maxLine, "Varmeter Data", header, io)
        headerDevice(io, format, header, maxLine, label, unitList.reactivePowerLive)

        for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, format, label, varmeter.reactive, estimate, scale["reactivePower"], i, varmeter.layout.index[i])
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVarmeterData(system::PowerSystem, varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format, minmax = formatDevice(varmeter.reactive.mean, power.injection.reactive)
    format = formatWidth(format, width)
    labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

    if format["device"]
        for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            formatDevice(format, minmax, label, varmeter.reactive, estimate, scale["reactivePower"], i, varmeter.layout.index[i])
        end

        formatDevice(format, minmax)
    end

    return format
end

"""
    printPmuData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width)

The function prints data related to PMUs. Optionally, an `IO` may be passed as the last
argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding PMU.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.

!!! compat "Julia 1.10"
    The function [`printPmuData`](@ref printPmuData) requires Julia 1.10 or later.

# Example
```jldoctest
system = powerSystem("case14.h5")
device = measurement("measurement14.h5")

analysis = gaussNewton(system, device)
for iteration = 1:20
    stopping = solve!(system, analysis)
    if stopping < 1e-8
        break
    end
end
current!(system, analysis)

# Print data for all PMUs
printPmuData(system, device, analysis)

# Print data for specific PMUs
width = Dict("Measurement Mean" => 7)
printPmuData(system, device, analysis; label = "From 1", width, header = true)
printPmuData(system, device, analysis; label = "From 4", width)
printPmuData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printPmuData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printPmuData(system, device, voltage, current, io, label, header, footer, width)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printPmuData(system, device, analysis.voltage, analysis.current, io, label, header, footer, width)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}())

    _printPmuData(system, device, analysis.voltage, io, label, header, footer, width)
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent, io::IO,
    label, header, footer, width::Dict{String, Int64})

    pmu = device.pmu

    scale = printScale(system, prefix)
    formatV, formatθ, formatI, formatψ = formatPmuData(system, pmu, voltage, current, scale, label, width)
    labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")

    if formatV["device"]
        maxLineV = maxLineDevice(formatV)
        maxLineθ = maxLineDevice(formatθ, label = false)
        if header
            Printf.@printf(io, "\n|%s|%s|\n", "-"^maxLineV, "-"^(maxLineθ))
            Printf.@printf(io, "| %s%*s| %s%*s|\n", "PMU Voltage Magnitude Data", maxLineV - length("PMU Voltage Magnitude Data") - 1, "", "PMU Voltage Angle Data", maxLineθ - length("PMU Voltage Angle Data") - 1, "")
        end

        headerDevice(io, formatV, formatθ, header, maxLineV, maxLineθ, label, unitList.voltageMagnitudeLive, unitList.voltageAngleLive)

        scaleV = 1.0
        for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]
                if prefix.voltageMagnitude != 0.0
                    scaleV = (system.base.voltage.value[indexBus] * system.base.voltage.prefix) / prefix.voltageMagnitude
                end

                printDevice(io, formatV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBus; newLine = false, last = false)
                printDevice(io, formatθ, label, pmu.angle, voltage.angle, scale["voltageAngle"], i, indexBus; printLabel = false)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|", "-"^maxLineV)
            Printf.@printf(io, "%s|\n", "-"^maxLineθ)
        end
    end

    if formatI["device"]
        maxLineI = maxLineDevice(formatI)
        maxLineψ = maxLineDevice(formatψ; label = false)
        if header
            Printf.@printf(io, "\n|%s|%s|\n", "-"^maxLineI, "-"^(maxLineψ ))
            Printf.@printf(io, "| %s%*s| %s%*s|\n", "PMU Current Magnitude Data", maxLineI - length("PMU Current Magnitude Data") - 1, "", "PMU Current Angle Data", maxLineψ - length("PMU Current Angle Data") - 1, "")
        end

        headerDevice(io, formatI, formatψ, header, maxLineI, maxLineψ, label, unitList.currentMagnitudeLive, unitList.currentAngleLive)

        scaleI = 1.0
        for (label, i) in labels
            if !pmu.layout.bus[i]
                indexBranch = pmu.layout.index[i]

                if prefix.currentMagnitude != 0.0
                    if pmu.layout.from[i]
                        j = system.branch.layout.from[indexBranch]
                    else
                        j = system.branch.layout.to[indexBranch]
                    end
                    scaleI = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
                end

                estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                printDevice(io, formatI, label, pmu.magnitude, estimate, scaleI, i, indexBranch; newLine = false, last = false)

                estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                printDevice(io, formatψ, label, pmu.angle, estimate, scale["currentAngle"], i, indexBranch; printLabel = false)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|", "-"^maxLineI)
            Printf.@printf(io, "%s|\n", "-"^(maxLineψ))
        end

    end
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO,
    label, header, footer, width::Dict{String, Int64})

    pmu = device.pmu

    scale = printScale(system, prefix)
    format = formatPmuData(system, pmu, voltage, scale, label, width)
    labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")

    if format["device"]
        maxLine = maxLineDevice(format)
        printTitle(maxLine, "PMU Voltage Angle Data", header, io)
        headerDevice(io, format, header, maxLine, label, unitList.voltageAngleLive)

        for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]
                printDevice(io, format, label, pmu.angle, voltage.angle, scale["voltageAngle"], i, indexBus)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    formatV, minmaxV = formatDevice(pmu.magnitude.mean, voltage.magnitude)
    formatV = formatWidth(formatV, width)

    formatθ, minmaxθ = formatDevice(pmu.magnitude.mean, voltage.angle)
    formatθ = formatWidth(formatθ, width)

    formatI, minmaxI = formatDevice(pmu.magnitude.mean, current.from.magnitude)
    formatI = formatWidth(formatI, width)

    formatψ, minmaxψ = formatDevice(pmu.magnitude.mean, current.from.angle)
    formatψ = formatWidth(formatψ, width)

    labels = toggleLabel(label, pmu, pmu.label, "pmu")

    if formatV["device"]
        scaleV = 1.0
        scaleI = 1.0
        for (label, i) in labels
            indexBusBranch = pmu.layout.index[i]

            if pmu.layout.bus[i]
                if prefix.voltageMagnitude != 0.0
                    scaleV = (system.base.voltage.value[indexBusBranch] * system.base.voltage.prefix) / prefix.voltageMagnitude
                end
                formatDevice(formatV, minmaxV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBusBranch)
                formatDevice(formatθ, minmaxθ, label, pmu.angle, voltage.angle, scale["voltageAngle"], i, indexBusBranch)
            else
                if prefix.currentMagnitude != 0.0
                    if pmu.layout.from[i]
                        j = system.branch.layout.from[indexBusBranch]
                    else
                        j = system.branch.layout.to[indexBusBranch]
                    end
                    scaleI = system.base.power.value * system.base.power.prefix / (sqrt(3) * system.base.voltage.value[j] * system.base.voltage.prefix * prefix.currentMagnitude)
                end

                estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                formatDevice(formatI, minmaxI, label, pmu.magnitude, estimate, scaleI, i, indexBusBranch)

                estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                formatDevice(formatψ, minmaxψ, label, pmu.angle, estimate, scale["currentAngle"], i, indexBusBranch)
            end

        end

        if formatV["Label"] == 0
            formatV["device"] = false
        else
            formatDevice(formatV, minmaxV)
            formatDevice(formatθ, minmaxθ)
        end

        if formatI["Label"] == 0
            formatI["device"] = false
        else
            formatDevice(formatI, minmaxI)
            formatDevice(formatψ, minmaxψ)
        end
    end

    return formatV, formatθ, formatI, formatψ
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L, width::Dict{String,Int64})
    format, minmax = formatDevice(pmu.magnitude.mean, voltage.angle)
    format = formatWidth(format, width)

    labels = toggleLabel(label, pmu, pmu.label, "pmu")

    if format["device"]
        for (label, i) in labels
            if pmu.layout.bus[i]
                formatDevice(format, minmax, label, pmu.angle, voltage.angle, scale["voltageAngle"], i, pmu.layout.index[i])
            end
        end

        if format["Label"] == 0
            format["device"] = false
        else
            formatDevice(format, minmax)
        end
    end

    return format
end

function formatDevice(deviceMean::Array{Float64,1}, analysisArray::Array{Float64,1})
    format = Dict(
            "Label" => 0,
            "Measurement Mean" => 4,
            "Measurement Variance" => 8,
            "State Estimation Estimate" => 8,
            "State Estimation Residual" => 8,
            "Status" => 6,
            "device" => !isempty(deviceMean),
            "analysis" => !isempty(analysisArray),
        )

    minmax = Dict(
        "minMean" => 0.0,
        "maxMean" => 0.0,
        "maxVariance" => 0.0,
        "minEstimate" => 0.0,
        "maxEstimate" => 0.0,
        "minResidual" => 0.0,
        "maxResidual" => 0.0,
    )

    return format, minmax
end

function headerDevice(io::IO, format::Dict{String, Integer}, header::Bool, maxLine::Int64, labelSet::L, unitLive::String)
    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
        printHeader1(io, format)
        printHeader2(io, format)
        printHeader3(io, format)
        printHeader4(io, format, unitLive)
        printHeader5(io, format)
    elseif !isset(labelSet)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

function headerDevice(io::IO, format1::Dict{String, Integer}, format2::Dict{String, Integer}, header::Bool, maxLine1::Int64, maxLine2::Int64, labelSet::L, unitLive1::String, unitLive2::String)
    if header
        Printf.@printf(io, "|%s|%s|\n", "-"^maxLine1, "-"^maxLine2)
        printHeader1(io, format1; newLine = false, last = false)
        printHeader1(io, format2; label = false)
        printHeader2(io, format1; newLine = false, last = false)
        printHeader2(io, format2; label = false)
        printHeader3(io, format1; newLine = false, last = false)
        printHeader3(io, format2; label = false)
        printHeader4(io, format1, unitLive1; newLine = false, last = false)
        printHeader4(io, format2, unitLive2; label = false)
        printHeader5(io, format1; newLine = false, last = false)
        printHeader5(io, format2; label = false)
    elseif !isset(labelSet)
        Printf.@printf(io, "|%s|%s|\n", "-"^maxLine1, "-"^(maxLine2 - 8))
    end
end

function printHeader1(io::IO, format::Dict{String, Integer}; label = true, newLine = true, last = true)
    if label
        Printf.@printf(io, "| %*s%s%*s ",
            floor(Int, (format["Label"] - 5) / 2), "", "Label", ceil(Int, (format["Label"]  - 5) / 2) , "",
        )
    end

    Printf.@printf(io, "| %*s%s%*s |",
        floor(Int, (format["Measurement Mean"] + format["Measurement Variance"] - 8) / 2), "", "Measurement", ceil(Int, (format["Measurement Mean"] + format["Measurement Variance"] - 8) / 2) , "",
    )

    if format["analysis"]
        Printf.@printf(io, " %*s%s%*s |",
            floor(Int, (format["State Estimation Estimate"] + format["State Estimation Residual"] - 13) / 2), "", "State Estimation", ceil(Int, (format["State Estimation Estimate"] + format["State Estimation Residual"] - 13) / 2) , "",
        )
    end

    Printf.@printf io " %s " "Status"

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader2(io::IO, format::Dict{String, Integer}; label = true, newLine = true, last = true)
    if label
        Printf.@printf(io, "| %*s ", format["Label"], "")
    end

    Printf.@printf(io, "| %*s |",
        format["Measurement Mean"] + format["Measurement Variance"] + 3, "",
    )
    if format["analysis"]
        Printf.@printf(io, " %*s |",
            format["State Estimation Estimate"] + format["State Estimation Residual"] + 3, "",
        )
    end

    Printf.@printf io " %*s " format["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader3(io::IO, format::Dict{String, Integer}; label = true, newLine = true, last = true)
    if label
        Printf.@printf(io, "| %*s ", format["Label"], "")
    end

    Printf.@printf(io, "| %*s | %*s |",
        format["Measurement Mean"], "Mean",
        format["Measurement Variance"], "Variance",
    )

    if format["analysis"]
        Printf.@printf(io, " %*s | %*s |",
            format["State Estimation Estimate"], "Estimate",
            format["State Estimation Residual"], "Residual",
        )
    end

    Printf.@printf io " %*s " format["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader4(io::IO, format::Dict{String, Integer}, unitLive::String; label = true, newLine = true, last = true)
    if label
        Printf.@printf(io, "| %*s ", format["Label"], "")
    end

    Printf.@printf(io, "| %*s | %*s |",
        format["Measurement Mean"], "[$unitLive]",
        format["Measurement Variance"], "[$unitLive]",
    )

    if format["analysis"]
        Printf.@printf(io, " %*s | %*s |",
            format["State Estimation Estimate"], "[$unitLive]",
            format["State Estimation Residual"], "[$unitLive]",
        )
    end

    Printf.@printf io " %*s " format["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader5(io::IO, format::Dict{String, Integer}; label = true, newLine = true, last = true)
    if label
        Printf.@printf(io, "|-%*s-", format["Label"], "-"^format["Label"])
    end

    Printf.@printf(io, "|-%*s-|-%*s-",
        format["Measurement Mean"], "-"^format["Measurement Mean"],
        format["Measurement Variance"], "-"^format["Measurement Variance"],
    )
    if format["analysis"]
        Printf.@printf(io, "|-%*s-|-%*s-",
            format["State Estimation Estimate"], "-"^format["State Estimation Estimate"],
            format["State Estimation Residual"], "-"^format["State Estimation Residual"],
        )
    end

    Printf.@printf io "|-%*s-" format["Status"] "-"^format["Status"]

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function maxLineDevice(format::Dict{String,Integer}; label = true)
    maxLine = format["Measurement Mean"] + format["Measurement Variance"] + format["Status"] + 8

    if format["analysis"]
        maxLine += format["State Estimation Estimate"] + format["State Estimation Residual"] + 6
    end

    if label
        maxLine += format["Label"] + 3
    end

    return maxLine
end

function printDevice(io::IO, format::Dict{String,Integer}, label::L, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64; printLabel = true, newLine = true, last = true)
    if printLabel
        Printf.@printf(io, "| %-*s ", format["Label"], label)
    end

    Printf.@printf(io, "| %*.4f | %*.4e |",
        format["Measurement Mean"], meter.mean[i] * scale,
        format["Measurement Variance"], meter.variance[i]  * scale,
    )

    if format["analysis"]
        Printf.@printf(io, " %*.4f |",
            format["State Estimation Estimate"], estimate[j] * scale,
        )
        if meter.status[i]  == 1
            Printf.@printf(io, " %*.4f |",
                format["State Estimation Residual"], (meter.mean[i] - estimate[j]) * scale,
            )
        else
            Printf.@printf(io, " %*s |",
                format["State Estimation Residual"], "-",
            )
        end
    end

    Printf.@printf(io, " %*i ", format["Status"], meter.status[i])

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function findEstimate(device, analysisBus::Array{Float64,1}, analysisFrom::Array{Float64,1}, analysisTo::Array{Float64,1}, i::Int64)
    if device.layout.bus[i]
        return analysisBus
    elseif device.layout.from[i]
        return analysisFrom
    else
        return analysisTo
    end
end

function formatDevice(format::Dict{String,Integer}, minmax::Dict{String, Float64}, label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64)
    minmax["maxMean"] = max(meter.mean[i] * scale, minmax["maxMean"])
    minmax["minMean"] = min(meter.mean[i] * scale, minmax["minMean"])
    minmax["maxVariance"] = max(meter.variance[i] * scale, minmax["maxVariance"])

    if format["analysis"]
        minmax["maxEstimate"] = max(estimate[j] * scale, minmax["maxEstimate"])
        minmax["minEstimate"] = min(estimate[j] * scale, minmax["minEstimate"])

        if meter.status[i] == 1
            minmax["minResidual"] = min((meter.mean[i] - estimate[j]) * scale, minmax["minResidual"])
            minmax["maxResidual"] = max((meter.mean[i] - estimate[j]) * scale, minmax["maxResidual"])
        end
    end

    format["Label"] = max(length(label), format["Label"])
end

function formatDevice(format::Dict{String,Integer}, minmax::Dict{String, Float64})
    format["Label"] = max(format["Label"], 5)
    format["Measurement Mean"] = max(length(Printf.@sprintf("%.4f", minmax["maxMean"])), length(Printf.@sprintf("%.4f", minmax["minMean"])), format["Measurement Mean"])
    format["Measurement Variance"] = max(length(Printf.@sprintf("%.4e", minmax["maxVariance"])), format["Measurement Variance"])

    if format["analysis"]
        format["State Estimation Estimate"] = max(length(Printf.@sprintf("%.4f", minmax["maxEstimate"])), length(Printf.@sprintf("%.4f", minmax["minEstimate"])), format["State Estimation Estimate"])
        format["State Estimation Residual"] = max(length(Printf.@sprintf("%.4f",  minmax["maxResidual"])), length(Printf.@sprintf("%.4f",  minmax["minResidual"])), format["State Estimation Residual"])
    end
end

function findEstimate(device, analysisFrom::Array{Float64,1}, analysisTo::Array{Float64,1}, i::Int64)
    if device.layout.from[i]
        return analysisFrom
    else
        return analysisTo
    end
end