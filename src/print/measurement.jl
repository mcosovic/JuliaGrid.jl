"""
    printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints data related to voltmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding voltmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
fmt = Dict("Measurement Variance" =>"%.4f")
printVoltmeterData(system, device, analysis; fmt)

# Print data for specific voltmeters
width = Dict("Measurement Variance" => 9)
printVoltmeterData(system, device, analysis; label = 1, width, header = true)
printVoltmeterData(system, device, analysis; label = 6, width)
printVoltmeterData(system, device, analysis; label = 8, width, footer = true)
```
"""
function printVoltmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    voltage = Polar(Float64[], Float64[])

    _printVoltmeterData(system, device, voltage, io, label, prefix, header, footer, width, fmt)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printVoltmeterData(system, device, analysis.voltage, io, label, prefix, header, footer, width, fmt)
end

function _printVoltmeterData(system::PowerSystem, device::Measurement, voltage::Polar, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    voltmeter = device.voltmeter

    width, fmt, deviceFlag, analysFlag = formatVoltmeterData(system, voltmeter, voltage, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, voltmeter, voltmeter.label, header, "voltmeter")

    if deviceFlag
        maxLine = maxLineDevice(width, analysFlag)
        printTitle(maxLine, "Voltmeter Data", header, io)
        headerDevice(io, width, header, maxLine, label, unitList.voltageMagnitudeLive, analysFlag)

        scale = 1.0
        for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end

            printDevice(io, width, fmt, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, analysFlag)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, prefix::PrefixLive, width::Dict{String, Int64}, fmt::Dict{String, String})
    _width, _fmt, minmax, deviceFlag, analysFlag = formatDevice(voltmeter.magnitude.mean, voltage.magnitude)
    width, fmt = printFormat(_width, width, _fmt, fmt)
    labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

    if deviceFlag
        scale = 1.0
        for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end

            formatDevice(width, minmax, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, analysFlag)
        end
        formatDevice(width, fmt, minmax, analysFlag)
    end

    return width, fmt, deviceFlag, analysFlag
end

"""
    printAmmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints data related to ammeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding ammeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
fmt = Dict("Measurement Variance" =>"%.4f")
printAmmeterData(system, device, analysis; fmt)

# Print data for specific ammeters
width = Dict("Measurement Variance" => 9)
printAmmeterData(system, device, analysis; label = "From 1", width, header = true)
printAmmeterData(system, device, analysis; label = "From 4", width)
printAmmeterData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printAmmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printAmmeterData(system, device, current, io, label, prefix, header, footer, width, fmt)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printAmmeterData(system, device, analysis.current, io, label, prefix, header, footer, width, fmt)
end

function _printAmmeterData(system::PowerSystem, device::Measurement, current::ACCurrent, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    ammeter = device.ammeter

    width, fmt, deviceFlag, analysFlag = formatAmmeterData(system, ammeter, current, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, ammeter, ammeter.label, header, "ammeter")

    if deviceFlag
        maxLine = maxLineDevice(width, analysFlag)
        printTitle(maxLine, "Ammeter Data", header, io)
        headerDevice(io, width, header, maxLine, label, unitList.currentMagnitudeLive, analysFlag)

        scale = 1.0
        for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    scale = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                else
                    scale = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                end
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, width, fmt, label, ammeter.magnitude, estimate, scale, i, indexBranch, analysFlag)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, prefix::PrefixLive, width::Dict{String, Int64}, fmt::Dict{String, String})
    _width, _fmt, minmax, deviceFlag, analysFlag = formatDevice(ammeter.magnitude.mean, current.from.magnitude)
    width, fmt = printFormat(_width, width, _fmt, fmt)
    labels = toggleLabel(label, ammeter, ammeter.label, "ammeter")

    if deviceFlag
        scale = 1.0
        for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    scale = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                else
                    scale = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                end
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            formatDevice(width, minmax, label, ammeter.magnitude, estimate, scale, i, indexBranch, analysFlag)
        end
        formatDevice(width, fmt, minmax, analysFlag)
    end

    return width, fmt, deviceFlag, analysFlag
end

"""
    printWattmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints data related to wattmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding wattmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
fmt = Dict("Measurement Variance" =>"%.4f")
printWattmeterData(system, device, analysis; fmt)

# Print data for specific wattmeters
width = Dict("Measurement Mean" => 7)
printWattmeterData(system, device, analysis; label = 2, width, header = tsrue)
printWattmeterData(system, device, analysis; label = 5, width)
printWattmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printWattmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), nothing)

    _printWattmeterData(system, device, power, io, label, prefix, header, footer, width, fmt)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printWattmeterData(system, device, analysis.power, io, label, prefix, header, footer, width, fmt)
end

function _printWattmeterData(system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower}, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    width, fmt, deviceFlag, analysFlag = formatWattmeterData(system, wattmeter, power, scale, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, wattmeter, wattmeter.label, header, "wattmeter")

    if deviceFlag
        maxLine = maxLineDevice(width, analysFlag)
        printTitle(maxLine, "Wattmeter Data", header, io)
        headerDevice(io, width, header, maxLine, label, unitList.activePowerLive, analysFlag)

        for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, width, fmt, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], analysFlag)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatWattmeterData(system::PowerSystem, wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L, prefix::PrefixLive, width::Dict{String,Int64}, fmt::Dict{String, String})
    _width, _fmt, minmax, deviceFlag, analysFlag = formatDevice(wattmeter.active.mean, power.injection.active)
    width, fmt = printFormat(_width, width, _fmt, fmt)
    labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

    if deviceFlag
        for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            formatDevice(width, minmax, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], analysFlag)
        end
        formatDevice(width, fmt, minmax, analysFlag)
    end

    return width, fmt, deviceFlag, analysFlag
end

"""
    printVarmeterData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints data related to varmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding varmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
fmt = Dict("Measurement Variance" =>"%.4f")
printVarmeterData(system, device, analysis; fmt)

# Print data for specific varmeters
width = Dict("Measurement Mean" => 7)
printVarmeterData(system, device, analysis; label = 2, width, header = true)
printVarmeterData(system, device, analysis; label = 5, width)
printVarmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printVarmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), nothing)

    _printVarmeterData(system, device, power, io, label, prefix, header, footer, width, fmt)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printVarmeterData(system, device, analysis.power, io, label, prefix, header, footer, width, fmt)
end

function _printVarmeterData(system::PowerSystem, device::Measurement, power::ACPower, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    varmeter = device.varmeter

    scale = printScale(system, prefix)
    width, fmt, deviceFlag, analysFlag = formatVarmeterData(system, varmeter, power, scale, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, varmeter, varmeter.label, header, "varmeter")

    if deviceFlag
        maxLine = maxLineDevice(width, analysFlag)
        printTitle(maxLine, "Varmeter Data", header, io)
        headerDevice(io, width, header, maxLine, label, unitList.reactivePowerLive, analysFlag)

        for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, width, fmt, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], analysFlag)
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVarmeterData(system::PowerSystem, varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L, prefix::PrefixLive, width::Dict{String,Int64}, fmt::Dict{String, String})
    _width, _fmt, minmax, deviceFlag, analysFlag = formatDevice(varmeter.reactive.mean, power.injection.reactive)
    width, fmt = printFormat(_width, width, _fmt, fmt)
    labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

    if deviceFlag
        for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            formatDevice(width, minmax, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], analysFlag)
        end
        formatDevice(width, fmt, minmax, analysFlag)
    end

    return width, fmt, deviceFlag, analysFlag
end

"""
    printPmuData(system::PowerSystem, device::Measurement, analysis::Analysis, io::IO;
        label, header, footer, width, fmt)

The function prints data related to PMUs. Optionally, an `IO` may be passed as the last
argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding PMU.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `width`: Specifies the preferred width of each column.
* `fmt`: Specifies the preferred numeric format of each column.

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
fmt = Dict("Measurement Variance" =>"%.5f")
printPmuData(system, device, analysis; fmt)

# Print data for specific PMUs
width = Dict("Measurement Mean" => 7)
printPmuData(system, device, analysis; label = "From 1", width, header = true)
printPmuData(system, device, analysis; label = "From 4", width)
printPmuData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printPmuData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printPmuData(system, device, voltage, current, io, label, prefix, header, footer, width, fmt)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printPmuData(system, device, analysis.voltage, analysis.current, io, label, prefix, header, footer, width, fmt)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false,
    width::Dict{String, Int64} = Dict{String, Int64}(), fmt::Dict{String, String} = Dict{String, String}())

    _printPmuData(system, device, analysis.voltage, io, label, prefix, header, footer, width, fmt)
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    pmu = device.pmu

    scale = printScale(system, prefix)
    widthV, fmtV, deviceFlagV, analysFlagV, widthθ, fmtθ, widthI, fmtI, deviceFlagI, analysFlagI, widthψ, fmtψ = formatPmuData(system, pmu, voltage, current, scale, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")

    if deviceFlagV
        maxLineV = maxLineDevice(widthV, analysFlagV)
        maxLineθ = maxLineDevice(widthθ, analysFlagV; label = false)
        if header
            Printf.@printf(io, "\n|%s|%s|\n", "-"^maxLineV, "-"^(maxLineθ))
            Printf.@printf(io, "| %s%*s| %s%*s|\n", "PMU Voltage Magnitude Data", maxLineV - 27, "", "PMU Voltage Angle Data", maxLineθ - 23, "")
        end

        headerDevice(io, widthV, widthθ, header, maxLineV, maxLineθ, label, unitList.voltageMagnitudeLive, unitList.voltageAngleLive, analysFlagV)

        scaleV = 1.0
        for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]

                if prefix.voltageMagnitude != 0.0
                    scaleV = scaleVoltage(system.base.voltage, prefix, indexBus)
                end

                printDevice(io, widthV, fmtV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBus, analysFlagV; newLine = false, last = false)
                printDevice(io, widthθ, fmtθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBus, analysFlagV; printLabel = false)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|", "-"^maxLineV)
            Printf.@printf(io, "%s|\n", "-"^maxLineθ)
        end
    end

    if deviceFlagI
        maxLineI = maxLineDevice(widthI, analysFlagI)
        maxLineψ = maxLineDevice(widthψ, analysFlagI; label = false)
        if header
            Printf.@printf(io, "\n|%s|%s|\n", "-"^maxLineI, "-"^(maxLineψ ))
            Printf.@printf(io, "| %s%*s| %s%*s|\n", "PMU Current Magnitude Data", maxLineI - 27, "", "PMU Current Angle Data", maxLineψ - 23, "")
        end

        headerDevice(io, widthI, widthψ, header, maxLineI, maxLineψ, label, unitList.currentMagnitudeLive, unitList.currentAngleLive, analysFlagI)

        scaleI = 1.0
        for (label, i) in labels
            if !pmu.layout.bus[i]
                indexBranch = pmu.layout.index[i]

                if prefix.currentMagnitude != 0.0
                    if pmu.layout.from[i]
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                    else
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                    end
                end

                estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                printDevice(io, widthI, fmtI, label, pmu.magnitude, estimate, scaleI, i, indexBranch, analysFlagI; newLine = false, last = false)

                estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                printDevice(io, widthψ, fmtψ, label, pmu.angle, estimate, scale["ψ"], i, indexBranch, analysFlagI; printLabel = false)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|", "-"^maxLineI)
            Printf.@printf(io, "%s|\n", "-"^(maxLineψ))
        end

    end
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, width::Dict{String, Int64}, fmt::Dict{String, String})

    pmu = device.pmu

    scale = printScale(system, prefix)
    width, fmt, deviceFlag, analysFlag = formatPmuData(system, pmu, voltage, scale, label, prefix, width, fmt)
    labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")

    if deviceFlag
        maxLine = maxLineDevice(width, analysFlag)
        printTitle(maxLine, "PMU Voltage Angle Data", header, io)
        headerDevice(io, width, header, maxLine, label, unitList.voltageAngleLive, analysFlag)

        for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]
                printDevice(io, width, fmt, label, pmu.angle, voltage.angle, scale["θ"], i, indexBus, analysFlag)
            end
        end

        if !isset(label) || footer
            Printf.@printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L, prefix::PrefixLive, width::Dict{String,Int64}, fmt::Dict{String, String})
    _width, _fmt, minmaxV, deviceFlagV, analysFlagV = formatDevice(pmu.magnitude.mean, voltage.magnitude)
    widthV, fmtV = printFormat(_width, width, _fmt, fmt)

    _width, _fmt, minmaxθ, _, _ = formatDevice(pmu.magnitude.mean, voltage.angle)
    widthθ, fmtθ = printFormat(_width, width, _fmt, fmt)

    _width, _fmt, minmaxI, deviceFlagI, analysFlagI = formatDevice(pmu.magnitude.mean, current.from.magnitude)
    widthI, fmtI = printFormat(_width, width, _fmt, fmt)

    _width, _fmt, minmaxψ, _, _ = formatDevice(pmu.magnitude.mean, current.from.angle)
    widthψ, fmtψ = printFormat(_width, width, _fmt, fmt)

    labels = toggleLabel(label, pmu, pmu.label, "pmu")

    if deviceFlagV
        scaleV = 1.0
        scaleI = 1.0
        for (label, i) in labels
            indexBusBranch = pmu.layout.index[i]

            if pmu.layout.bus[i]
                if prefix.voltageMagnitude != 0.0
                    scaleV = scaleVoltage(system.base.voltage, prefix, indexBusBranch)
                end

                formatDevice(widthV, minmaxV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBusBranch, analysFlagV)
                formatDevice(widthθ, minmaxθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBusBranch, analysFlagV)
            else
                if prefix.currentMagnitude != 0.0
                    if pmu.layout.from[i]
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBusBranch])
                    else
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBusBranch])
                    end
                end

                estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                formatDevice(widthI, minmaxI, label, pmu.magnitude, estimate, scaleI, i, indexBusBranch, analysFlagI)

                estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                formatDevice(widthψ, minmaxψ, label, pmu.angle, estimate, scale["ψ"], i, indexBusBranch, analysFlagI)
            end
        end

        if widthV["Label"] == 0
            deviceFlagV = false
        else
            formatDevice(widthV, fmtV, minmaxV, analysFlagV)
            formatDevice(widthθ, fmtθ, minmaxθ, analysFlagV)
        end

        if widthI["Label"] == 0
            deviceFlagI = false
        else
            formatDevice(widthI, fmtI, minmaxI, analysFlagI)
            formatDevice(widthψ, fmtψ, minmaxψ, analysFlagI)
        end
    end

    return widthV, fmtV, deviceFlagV, analysFlagV, widthθ, fmtθ, widthI, fmtI, deviceFlagI, analysFlagI, widthψ, fmtψ
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L, prefix::PrefixLive, width::Dict{String,Int64}, fmt::Dict{String, String})
    _width, _fmt, minmax, deviceFlag, analysFlag = formatDevice(pmu.magnitude.mean, voltage.angle)
    width, fmt = printFormat(_width, width, _fmt, fmt)

    labels = toggleLabel(label, pmu, pmu.label, "pmu")

    if deviceFlag
        for (label, i) in labels
            if pmu.layout.bus[i]
                formatDevice(width, minmax, label, pmu.angle, voltage.angle, scale["θ"], i, pmu.layout.index[i], analysFlag)
            end
        end

        if width["Label"] == 0
            deviceFlag = false
        else
            formatDevice(width, fmt, minmax, analysFlag)
        end
    end

    return width, fmt, deviceFlag, analysFlag
end

function formatDevice(deviceMean::Array{Float64,1}, analysisArray::Array{Float64,1})
    width = Dict(
        "Label" => 0,
        "Measurement Mean" => 4,
        "Measurement Variance" => 8,
        "State Estimation Estimate" => 8,
        "State Estimation Residual" => 8,
        "Status" => 6
    )

    fmt = Dict(
        "Measurement Mean" => "%*.4f",
        "Measurement Variance" => "%*.2e",
        "State Estimation Estimate" => "%*.4f",
        "State Estimation Residual" => "%*.4f"
    )

    minmax = Dict(
        "minMean" => 0.0,
        "maxMean" => 0.0,
        "maxVariance" => 0.0,
        "minEstimate" => 0.0,
        "maxEstimate" => 0.0,
        "minResidual" => 0.0,
        "maxResidual" => 0.0
    )

    return width, fmt, minmax, !isempty(deviceMean), !isempty(analysisArray)
end

function headerDevice(io::IO, width::Dict{String, Int64}, header::Bool, maxLine::Int64, labelSet::L, unitLive::String, flag::Bool)
    if header
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
        printHeader1(io, width, flag)
        printHeader2(io, width, flag)
        printHeader3(io, width, flag)
        printHeader4(io, width, unitLive, flag)
        printHeader5(io, width, flag)
    elseif !isset(labelSet)
        Printf.@printf(io, "|%s|\n", "-"^maxLine)
    end
end

function headerDevice(io::IO, width1::Dict{String, Int64}, width2::Dict{String, Int64}, header::Bool, maxLine1::Int64, maxLine2::Int64, labelSet::L, unitLive1::String, unitLive2::String, flag::Bool)
    if header
        Printf.@printf(io, "|%s|%s|\n", "-"^maxLine1, "-"^maxLine2)
        printHeader1(io, width1, flag; newLine = false, last = false)
        printHeader1(io, width2, flag; label = false)
        printHeader2(io, width1, flag; newLine = false, last = false)
        printHeader2(io, width2, flag; label = false)
        printHeader3(io, width1, flag; newLine = false, last = false)
        printHeader3(io, width2, flag; label = false)
        printHeader4(io, width1, unitLive1, flag; newLine = false, last = false)
        printHeader4(io, width2, unitLive2, flag; label = false)
        printHeader5(io, width1, flag; newLine = false, last = false)
        printHeader5(io, width2, flag; label = false)
    elseif !isset(labelSet)
        Printf.@printf(io, "|%s|%s|\n", "-"^maxLine1, "-"^(maxLine2 - 8))
    end
end

function printHeader1(io::IO, width::Dict{String, Int64}, flag::Bool; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        Printf.@printf(io, "| %*s%s%*s ",
            floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"]  - 5) / 2) , "",
        )
    end

    Printf.@printf(io, "| %*s%s%*s |",
        floor(Int, (width["Measurement Mean"] + width["Measurement Variance"] - 8) / 2), "", "Measurement", ceil(Int, (width["Measurement Mean"] + width["Measurement Variance"] - 8) / 2) , "",
    )

    if flag
        Printf.@printf(io, " %*s%s%*s |",
            floor(Int, (width["State Estimation Estimate"] + width["State Estimation Residual"] - 13) / 2), "", "State Estimation", ceil(Int, (width["State Estimation Estimate"] + width["State Estimation Residual"] - 13) / 2) , "",
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

function printHeader2(io::IO, width::Dict{String, Int64}, flag::Bool; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        Printf.@printf(io, "| %*s ", width["Label"], "")
    end

    Printf.@printf(io, "| %*s |",
        width["Measurement Mean"] + width["Measurement Variance"] + 3, "",
    )
    if flag
        Printf.@printf(io, " %*s |",
            width["State Estimation Estimate"] + width["State Estimation Residual"] + 3, "",
        )
    end

    Printf.@printf io " %*s " width["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader3(io::IO, width::Dict{String, Int64}, flag::Bool; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        Printf.@printf(io, "| %*s ", width["Label"], "")
    end

    Printf.@printf(io, "| %*s | %*s |",
        width["Measurement Mean"], "Mean",
        width["Measurement Variance"], "Variance",
    )

    if flag
        Printf.@printf(io, " %*s | %*s |",
            width["State Estimation Estimate"], "Estimate",
            width["State Estimation Residual"], "Residual",
        )
    end

    Printf.@printf io " %*s " width["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader4(io::IO, width::Dict{String, Int64}, unitLive::String, flag::Bool; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        Printf.@printf(io, "| %*s ", width["Label"], "")
    end

    Printf.@printf(io, "| %*s | %*s |",
        width["Measurement Mean"], "[$unitLive]",
        width["Measurement Variance"], "[$unitLive]",
    )

    if flag
        Printf.@printf(io, " %*s | %*s |",
            width["State Estimation Estimate"], "[$unitLive]",
            width["State Estimation Residual"], "[$unitLive]",
        )
    end

    Printf.@printf io " %*s " width["Status"] ""

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function printHeader5(io::IO, width::Dict{String, Int64}, flag::Bool; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        Printf.@printf(io, "|-%*s-", width["Label"], "-"^width["Label"])
    end

    Printf.@printf(io, "|-%*s-|-%*s-",
        width["Measurement Mean"], "-"^width["Measurement Mean"],
        width["Measurement Variance"], "-"^width["Measurement Variance"],
    )
    if flag
        Printf.@printf(io, "|-%*s-|-%*s-",
            width["State Estimation Estimate"], "-"^width["State Estimation Estimate"],
            width["State Estimation Residual"], "-"^width["State Estimation Residual"],
        )
    end

    Printf.@printf io "|-%*s-" width["Status"] "-"^width["Status"]

    if last
        Printf.@printf io "|"
    end

    if newLine
        Printf.@printf io "\n"
    end
end

function maxLineDevice(width::Dict{String, Int64}, flag::Bool; label::Bool = true)
    maxLine = width["Measurement Mean"] + width["Measurement Variance"] + width["Status"] + 8

    if flag
        maxLine += width["State Estimation Estimate"] + width["State Estimation Residual"] + 6
    end

    if label
        maxLine += width["Label"] + 3
    end

    return maxLine
end

function printDevice(io::IO, width::Dict{String, Int64}, fmt::Dict{String, String}, label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64, flag::Bool; printLabel::Bool = true, newLine::Bool = true, last::Bool = true)
    if printLabel
        Printf.@printf(io, "| %-*s ", width["Label"], label)
    end

    print(io, Printf.format(
        Printf.Format(
            "| $(fmt["Measurement Mean"]) | $(fmt["Measurement Variance"]) |"
        ),
        width["Measurement Mean"], meter.mean[i] * scale,
        width["Measurement Variance"], meter.variance[i] * scale)
    )

    if flag
        print(io, Printf.format(
            Printf.Format(
                " $(fmt["State Estimation Estimate"]) |"
            ),
            width["State Estimation Estimate"], estimate[j] * scale)
        )

        if meter.status[i]  == 1
            print(io, Printf.format(
                Printf.Format(
                    " $(fmt["State Estimation Residual"]) |"
                ),
                width["State Estimation Residual"], (meter.mean[i] - estimate[j]) * scale)
            )
        else
            Printf.@printf(io, " %*s |",
            width["State Estimation Residual"], "-",
            )
        end
    end

    Printf.@printf(io, " %*i ", width["Status"], meter.status[i])

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

function findEstimate(device, analysisFrom::Array{Float64,1}, analysisTo::Array{Float64,1}, i::Int64)
    if device.layout.from[i]
        return analysisFrom
    else
        return analysisTo
    end
end

function formatDevice(width::Dict{String, Int64}, minmax::Dict{String, Float64}, label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64, flag::Bool)
    minmax["maxMean"] = max(meter.mean[i] * scale, minmax["maxMean"])
    minmax["minMean"] = min(meter.mean[i] * scale, minmax["minMean"])
    minmax["maxVariance"] = max(meter.variance[i] * scale, minmax["maxVariance"])

    if flag
        minmax["maxEstimate"] = max(estimate[j] * scale, minmax["maxEstimate"])
        minmax["minEstimate"] = min(estimate[j] * scale, minmax["minEstimate"])

        if meter.status[i] == 1
            minmax["minResidual"] = min((meter.mean[i] - estimate[j]) * scale, minmax["minResidual"])
            minmax["maxResidual"] = max((meter.mean[i] - estimate[j]) * scale, minmax["maxResidual"])
        end
    end

    width["Label"] = max(textwidth(label), width["Label"])
end

function formatDevice(width::Dict{String, Int64}, fmt::Dict{String, String}, minmax::Dict{String, Float64}, flag::Bool)
    width["Label"] = max(width["Label"], 5)

    width["Measurement Mean"] = max(
        textwidth(Printf.format(Printf.Format(fmt["Measurement Mean"]), 0, minmax["maxMean"])),
        textwidth(Printf.format(Printf.Format(fmt["Measurement Mean"]), 0, minmax["minMean"])),
        width["Measurement Mean"]
    )

    width["Measurement Variance"] = max(
        textwidth(Printf.format(Printf.Format(fmt["Measurement Variance"]), 0, minmax["maxVariance"])),
        width["Measurement Variance"]
    )

    if flag
        width["State Estimation Estimate"] = max(
            textwidth(Printf.format(Printf.Format(fmt["State Estimation Estimate"]), 0, minmax["maxEstimate"])),
            textwidth(Printf.format(Printf.Format(fmt["State Estimation Estimate"]), 0, minmax["minEstimate"])),
            width["State Estimation Estimate"]
        )
        width["State Estimation Residual"] = max(
            textwidth(Printf.format(Printf.Format(fmt["State Estimation Residual"]), 0, minmax["maxResidual"])),
            textwidth(Printf.format(Printf.Format(fmt["State Estimation Residual"]), 0, minmax["minResidual"])),
            width["State Estimation Residual"]
        )
    end
end