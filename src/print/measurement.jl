"""
    printVoltmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, fmt, width, show)

The function prints data related to voltmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding voltmeter.
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
fmt = Dict("Measurement Variance" => "%.4f")
show = Dict("State Estimation Residual" => false)
printVoltmeterData(system, device, analysis; fmt, show)

# Print data for specific voltmeters
width = Dict("Measurement Variance" => 9)
printVoltmeterData(system, device, analysis; label = 1, width, header = true)
printVoltmeterData(system, device, analysis; label = 6, width)
printVoltmeterData(system, device, analysis; label = 8, width, footer = true)
```
"""
function printVoltmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    voltage = Polar(Float64[], Float64[])

    _printVoltmeterData(system, device, voltage, io, label, prefix, header, footer, fmt, width, show)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printVoltmeterData(system, device, analysis.voltage, io, label, prefix, header, footer, fmt, width, show)
end

function _printVoltmeterData(system::PowerSystem, device::Measurement, voltage::Polar, io::IO, label::L,
    prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    voltmeter = device.voltmeter
    fmt, width, show = formatVoltmeterData(system, voltmeter, voltage, label, prefix, fmt, width, show)

    if !isempty(voltmeter.label)
        labels, header = toggleLabelHeader(label, voltmeter, voltmeter.label, header, "voltmeter")
        maxLine, pfmt = setupPrintSystem(fmt, width, show; dash = true)

        if header
            printTitle(io, maxLine, "Voltmeter Data")
            headerDevice(io, width, show, unitList.voltageMagnitudeLive)
        end

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end
            printDevice(io, pfmt, width, show, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus)
        end

        if !isset(label) || footer
            @printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    _fmt, _width, _show, minval, maxval = formatDevice(voltmeter.magnitude, voltage.magnitude)
    if !isempty(voltmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)
        labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end

            formatDevice(width, show, minval, maxval, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus)
        end
        formatDevice(fmt, width, show, minval, maxval, "Voltmeter Data")
    end

    return fmt, width, show
end

"""
    printAmmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, fmt, width, show)

The function prints data related to ammeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding ammeter.
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
show = Dict("State Estimation Residual" => false)
printAmmeterData(system, device, analysis; fmt, show)

# Print data for specific ammeters
width = Dict("Measurement Variance" => 9)
printAmmeterData(system, device, analysis; label = "From 1", width, header = true)
printAmmeterData(system, device, analysis; label = "From 4", width)
printAmmeterData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printAmmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printAmmeterData(system, device, current, io, label, prefix, header, footer, fmt, width, show)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printAmmeterData(system, device, analysis.current, io, label, prefix, header, footer, fmt, width, show)
end

function _printAmmeterData(system::PowerSystem, device::Measurement, current::ACCurrent, io::IO, label::L,
    prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    ammeter = device.ammeter
    fmt, width, show = formatAmmeterData(system, ammeter, current, label, prefix, fmt, width, show)

    if !isempty(ammeter.label)
        labels, header = toggleLabelHeader(label, ammeter, ammeter.label, header, "ammeter")
        maxLine, pfmt = setupPrintSystem(fmt, width, show; dash = true)

        if header
            printTitle(io, maxLine, "Ammeter Data")
            headerDevice(io, width, show, unitList.currentMagnitudeLive)
        end

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    scale = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                else
                    scale = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                end
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, pfmt, width, show, label, ammeter.magnitude, estimate, scale, i, indexBranch)
        end

        if !isset(label) || footer
            @printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})
    _fmt, _width, _show, minval, maxval = formatDevice(ammeter.magnitude, current.from.magnitude)

    if !isempty(ammeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)
        labels = toggleLabel(label, ammeter, ammeter.label, "ammeter")

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBranch = ammeter.layout.index[i]

            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    scale = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                else
                    scale = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                end
            end

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            formatDevice(width, show, minval, maxval, label, ammeter.magnitude, estimate, scale, i, indexBranch)
        end
        formatDevice(fmt, width, show, minval, maxval, "Ammeter Data")
    end

    return fmt, width, show
end

"""
    printWattmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, fmt, width, show)

The function prints data related to wattmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding wattmeter.
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
fmt = Dict("Measurement Variance" => "%.4f")
show = Dict("State Estimation Residual" => false)
printWattmeterData(system, device, analysis; fmt, show)

# Print data for specific wattmeters
width = Dict("Measurement Mean" => 7)
printWattmeterData(system, device, analysis; label = 2, width, header = true)
printWattmeterData(system, device, analysis; label = 5, width)
printWattmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printWattmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printWattmeterData(system, device, power, io, label, prefix, header, footer, fmt, width, show)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printWattmeterData(system, device, analysis.power, io, label, prefix, header, footer, fmt, width, show)
end

function _printWattmeterData(system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower}, io::IO, label::L,
    prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    fmt, width, show = formatWattmeterData(wattmeter, power, scale, label, fmt, width, show)

    if !isempty(wattmeter.label)
        labels, header = toggleLabelHeader(label, wattmeter, wattmeter.label, header, "wattmeter")
        maxLine, pfmt = setupPrintSystem(fmt, width, show; dash = true)

        if header
            printTitle(io, maxLine, "Wattmeter Data")
            headerDevice(io, width, show, unitList.activePowerLive)
        end

        @inbounds for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, pfmt, width, show, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i])
        end

        if !isset(label) || footer
            @printf(io, "|%s|\n", "-"^maxLine)
        end
    end

end

function formatWattmeterData(wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L, fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool})
    _fmt, _width, _show, mival, maxval = formatDevice(wattmeter.active, power.injection.active)

    if !isempty(wattmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)
        labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

        @inbounds for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            formatDevice(width, show, mival, maxval, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i])
        end
        formatDevice(fmt, width, show, mival, maxval, "Wattmeter Data")
    end

    return fmt, width, show
end

"""
    printVarmeterData(system::PowerSystem, device::Measurement,
        [analysis::Analysis], [io::IO]; label, header, footer, fmt, width, show)

The function prints data related to varmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding varmeter.
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
fmt = Dict("Measurement Variance" => "%.4f")
show = Dict("State Estimation Residual" => false)
printVarmeterData(system, device, analysis; fmt, show)

# Print data for specific varmeters
width = Dict("Measurement Mean" => 7)
printVarmeterData(system, device, analysis; label = 2, width, header = true)
printVarmeterData(system, device, analysis; label = 5, width)
printVarmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printVarmeterData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printVarmeterData(system, device, power, io, label, prefix, header, footer, fmt, width, show)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printVarmeterData(system, device, analysis.power, io, label, prefix, header, footer, fmt, width, show)
end

function _printVarmeterData(system::PowerSystem, device::Measurement, power::ACPower, io::IO, label::L,
    prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    varmeter = device.varmeter

    scale = printScale(system, prefix)
    fmt, width, show = formatVarmeterData(varmeter, power, scale, label, fmt, width, show)

    if !isempty(varmeter.label)
        labels, header = toggleLabelHeader(label, varmeter, varmeter.label, header, "varmeter")
        maxLine, pfmt = setupPrintSystem(fmt, width, show; dash = true)

        if header
            printTitle(io, maxLine, "Varmeter Data")
            headerDevice(io, width, show, unitList.reactivePowerLive)
        end

        @inbounds for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, pfmt, width, show, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i])
        end

        if !isset(label) || footer
            @printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatVarmeterData(varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L, fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool})
    _fmt, _width, _show, mival, maxval = formatDevice(varmeter.reactive, power.injection.reactive)

    if !isempty(varmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)
        labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

        @inbounds for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            formatDevice(width, show, mival, maxval, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i])
        end
        formatDevice(fmt, width, show, mival, maxval, "Varmeter Data")
    end

    return fmt, width, show
end

"""
    printPmuData(system::PowerSystem, device::Measurement,
        [analysis::Analysis], [io::IO]; label, header, footer, fmt, width, show)

The function prints data related to PMUs. Optionally, an `IO` may be passed as the last
argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding PMU.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.

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
fmt = Dict("Measurement Variance" => "%.5f")
show = Dict("State Estimation Residual" => false)
printPmuData(system, device, analysis; fmt, show)

# Print data for specific PMUs
width = Dict("Measurement Mean" => 7)
printPmuData(system, device, analysis; label = "From 1", width, header = true)
printPmuData(system, device, analysis; label = "From 4", width)
printPmuData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printPmuData(system::PowerSystem, device::Measurement, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printPmuData(system, device, voltage, current, io, label, prefix, header, footer, fmt, width, show)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printPmuData(system, device, analysis.voltage, analysis.current, io, label, prefix, header, footer, fmt, width, show)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout;
    label::L = missing, header::B = missing, footer::Bool = false, fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}())

    _printPmuData(system, device, analysis.voltage, io, label, prefix, header, footer, fmt, width, show)
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent, io::IO,
    label::L, prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    pmu = device.pmu

    scale = printScale(system, prefix)
    fmt, widthV, widthθ, widthI, widthψ, showV, showθ, showI, showψ, _show = formatPmuData(system, pmu, voltage, current, scale, label, prefix, fmt, width, show)
    labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")

    if _show["Voltage"]
        maxLineV, pfmtV = setupPrintSystem(fmt, widthV, showV; dash = true)
        maxLineθ, pfmtθ = setupPrintSystem(fmt, widthθ, showθ; label = false, dash = true)

        if header
            printTitle(io, maxLineV + maxLineθ, "PMU Voltage Data")
            if _show["PMU Voltage Data"]
                @printf(io, "| %-*s | % -*s |\n", maxLineV - 2, "Magnitude", maxLineθ - 3, "Angle")
            end
            headerDevice(io, widthV, widthθ, showV, showθ, maxLineV, maxLineθ, unitList.voltageMagnitudeLive, unitList.voltageAngleLive, _show["PMU Voltage Data"])
        end

        scaleV = 1.0
        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]

                if prefix.voltageMagnitude != 0.0
                    scaleV = scaleVoltage(system.base.voltage, prefix, indexBus)
                end

                printDevice(io, pfmtV, widthV, showV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBus; newLine = false)
                printDevice(io, pfmtθ, widthθ, showθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBus; printLabel = false)
            end
        end

        if !isset(label) || footer
            @printf(io, "|%s|", "-"^maxLineV)
            if _show["PMU Voltage Data"]
                @printf(io, "%s|", "-"^(maxLineθ - 1))
            end
            @printf(io, "\n")
        end
    end

    if _show["Current"]
        maxLineI, pfmtI = setupPrintSystem(fmt, widthI, showI; dash = true)
        maxLineψ, pfmtψ, = setupPrintSystem(fmt, widthψ, showψ,; label = false, dash = true)

        if header
            printTitle(io, maxLineI + maxLineψ, "PMU Current Data")
            if _show["PMU Current Data"]
                @printf(io, "| %-*s | % -*s |\n", maxLineI - 2, "Magnitude", maxLineψ - 3, "Angle")
            end
            headerDevice(io, widthI, widthψ, showI, showψ, maxLineI, maxLineψ, unitList.currentMagnitudeLive, unitList.currentAngleLive, _show["PMU Current Data"])
        end

        scaleI = 1.0
        @inbounds for (label, i) in labels
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
                printDevice(io, pfmtI, widthI, showI, label, pmu.magnitude, estimate, scaleI, i, indexBranch; newLine = false)

                estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                printDevice(io, pfmtψ, widthψ, showψ, label, pmu.angle, estimate, scale["ψ"], i, indexBranch; printLabel = false)
            end
        end

        if !isset(label) || footer
            @printf(io, "|%s|", "-"^maxLineI)
            if _show["PMU Current Data"]
                @printf(io, "%s|", "-"^(maxLineψ - 1))
            end
            @printf(io, "\n")
        end

    end
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO, label::L,
    prefix::PrefixLive, header::B, footer::Bool, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    pmu = device.pmu

    scale = printScale(system, prefix)
    fmt, width, show, _show = formatPmuData(system, pmu, voltage, scale, label, prefix, fmt, width, show)

    if _show["Voltage"]
        labels, header = toggleLabelHeader(label, pmu, pmu.label, header, "pmu")
        maxLine, pfmt = setupPrintSystem(fmt, width, show; dash = true)

        if header
            printTitle(io, maxLine, "PMU Voltage Data")
            if _show["PMU Voltage Data"]
                @printf(io, "| %-*s |\n", maxLine - 2, "Angle")
                @printf(io, "|%s|\n", "-"^maxLine)
            end
            headerDevice(io, width, show, unitList.voltageAngleLive)
        end

        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]
                printDevice(io, pfmt, width, show, label, pmu.angle, voltage.angle, scale["θ"], i, indexBus)
            end
        end

        if !isset(label) || footer
            @printf(io, "|%s|\n", "-"^maxLine)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L, prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})
    _fmt, _width, _show, minV, maxV = formatDevice(pmu.magnitude, voltage.magnitude)
    fmt, widthV, showV = printFormat(_fmt, fmt, _width, width, _show, show)
    _, _width, _show, minθ, maxθ = formatDevice(pmu.angle, voltage.angle)
    _, widthθ, showθ = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show)

    _, _width, _show, minI, maxI = formatDevice(pmu.magnitude, current.from.magnitude)
    _, widthI, showI = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show)
    _, _width, _show, minψ, maxψ = formatDevice(pmu.angle, current.from.angle)
    _, widthψ, showψ = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show)

    if !isempty(pmu.label)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")

        scaleV = 1.0
        scaleI = 1.0
        @inbounds for (label, i) in labels
            indexBusBranch = pmu.layout.index[i]

            if pmu.layout.bus[i]
                if prefix.voltageMagnitude != 0.0
                    scaleV = scaleVoltage(system.base.voltage, prefix, indexBusBranch)
                end

                formatDevice(widthV, showV, minV, maxV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBusBranch)
                formatDevice(widthθ, showθ, minθ, maxθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBusBranch)
            else
                if prefix.currentMagnitude != 0.0
                    if pmu.layout.from[i]
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBusBranch])
                    else
                        scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBusBranch])
                    end
                end

                estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                formatDevice(widthI, showI, minI, maxI, label, pmu.magnitude, estimate, scaleI, i, indexBusBranch)
                formatDevice(widthψ, showψ, minψ, maxψ, label, pmu.angle, estimate, scale["ψ"], i, indexBusBranch)
            end
        end

        _show = Dict("Voltage" => true, "Current" => true, "PMU Voltage Data" => true, "PMU Current Data" => true)
        if widthV["Label"] == 0
            _show["Voltage"] = false
        else
            formatDevice(fmt, widthV, showV, minV, maxV, "PMU Voltage Data"; _show)
            formatDevice(fmt, widthθ, showθ, minθ, maxθ, "")
        end

        if widthI["Label"] == 0
            _show["Current"] = false
        else
            formatDevice(fmt, widthI, showI, minI, maxI, "PMU Current Data"; _show)
            formatDevice(fmt, widthψ, showψ, minψ, maxψ, "")
        end
    end

    return fmt, widthV, widthθ, widthI, widthψ, showV, showθ, showI, showψ, _show
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool})

    _fmt, _width, _show, minval, maxval = formatDevice(pmu.angle, voltage.angle)

    if !isempty(pmu.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")

        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                formatDevice(width, show, minval, maxval, label, pmu.angle, voltage.angle, scale["θ"], i, pmu.layout.index[i])
            end
        end

        _show = Dict("Voltage" => true, "PMU Voltage Data" => true)
        if width["Label"] == 0
            _show["Voltage"] = false
        else
            formatDevice(fmt, width, show, minval, maxval, "PMU Voltage Data"; _show)
        end
    end

    return fmt, width, show, _show
end

function formatDevice(meter::GaussMeter, analysisArray::Array{Float64,1})
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
        "State Estimation Residual" => "%*.4f",
        "Status" => "%*i"
    )

    show = Dict(
        "Measurement Mean" => !isempty(meter.mean),
        "Measurement Variance" => !isempty(meter.variance),
        "State Estimation Estimate" => !isempty(analysisArray),
        "State Estimation Residual" => !isempty(analysisArray),
        "Status" => !isempty(meter.status)
    )

    minval = Dict(
        "Measurement Mean" => 0.0,
        "Measurement Variance" => 0.0,
        "State Estimation Estimate" => 0.0,
        "State Estimation Residual" => 0.0,
    )

    maxval = Dict(
        "Measurement Mean" => 0.0,
        "Measurement Variance" => 0.0,
        "State Estimation Estimate" => 0.0,
        "State Estimation Residual" => 0.0,
    )

    return fmt, width, show, minval, maxval
end

function headerDevice(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, unitLive::String)
    fmtMes, fmtEst, fmtSta = printHeader1(io, width, show)
    printHeader2(io, width, show, fmtMes, fmtEst, fmtSta)
    printHeader3(io, width, show, fmtMes, fmtEst, fmtSta)
    printHeader4(io, width, show, unitLive, fmtMes, fmtEst, fmtSta)
    printHeader5(io, width, show, fmtMes, fmtEst, fmtSta)
end

function headerDevice(io::IO, width1::Dict{String, Int64}, width2::Dict{String, Int64}, show1::Dict{String, Bool}, show2::Dict{String, Bool},
    maxLine1::Int64, maxLine2::Int64, unitLive1::String, unitLive2::String, hasMore::Bool)

    if hasMore
        @printf(io, "|%s|%s|\n", "-"^maxLine1, "-"^(maxLine2 - 1))
    end

    fmtMes1, fmtEst1, fmtSta1 = printHeader1(io, width1, show1; newLine = !hasMore)
    if hasMore
        fmtMes2, fmtEst2, fmtSta2 = printHeader1(io, width2, show2; label = false)
    end

    if hasMore
        printHeader2(io, width1, show1, fmtMes1, fmtEst1, fmtSta1; newLine = !hasMore)
        printHeader2(io, width2, show2, fmtMes2, fmtEst2, fmtSta2; label = false)
    end

    if hasMore
        printHeader3(io, width1, show1, fmtMes1, fmtEst1, fmtSta1; newLine = !hasMore)
        printHeader3(io, width2, show2, fmtMes2, fmtEst2, fmtSta2; label = false)
    end

    if hasMore
        printHeader4(io, width1, show1, unitLive1, fmtMes1, fmtEst1, fmtSta1; newLine = !hasMore)
        printHeader4(io, width2, show2, unitLive2, fmtMes2, fmtEst2, fmtSta2; label = false)
    end

    printHeader5(io, width1, show1, fmtMes1, fmtEst1, fmtSta1; newLine = !hasMore)
    if hasMore
        printHeader5(io, width2, show2, fmtMes2, fmtEst2, fmtSta2; label = false)
    end
end

function printHeader1(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}; label::Bool = true, newLine::Bool = true)
    if label
        @printf(io, "| %*s%s%*s |", floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"]  - 5) / 2) , "")
    end

    fmtMes = printf(io, width, show, "Measurement Mean", "Measurement Variance", "Measurement")
    fmtEst = printf(io, width, show, "State Estimation Estimate", "State Estimation Residual", "State Estimation")
    fmtSta = printf(io, width, show, "Status", "Status")

    if newLine
        @printf io "\n"
    end

    return fmtMes, fmtEst, fmtSta
end

function printHeader2(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}; label::Bool = true, newLine::Bool = true, last::Bool = true)
    if label
        @printf(io, "| %*s |", width["Label"], "")
    end

    printf(io, fmtMes[1], width, show, "Measurement Mean", "", "Measurement Variance", "")
    printf(io, fmtEst[1], width, show, "State Estimation Estimate", "", "State Estimation Residual", "")
    printf(io, fmtSta[1], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader3(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        @printf(io, "| %*s |", width["Label"], "")
    end

    printf(io, fmtMes[2], width, show, "Measurement Mean", "Mean", "Measurement Variance", "Variance")
    printf(io, fmtEst[2], width, show, "State Estimation Estimate", "Estimate", "State Estimation Residual", "Residual")
    printf(io, fmtSta[2], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader4(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, unitLive::String, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        @printf(io, "| %*s |", width["Label"], "")
    end

    printf(io, fmtMes[2], width, show, "Measurement Mean", "[$unitLive]", "Measurement Variance", "[$unitLive]")
    printf(io, fmtEst[2], width, show, "State Estimation Estimate", "[$unitLive]", "State Estimation Residual", "[$unitLive]")
    printf(io, fmtSta[2], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader5(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        @printf(io, "|-%*s-|", width["Label"], "-"^width["Label"])
    end

    printf(io, fmtMes[3], width, show, "Measurement Mean", "-"^width["Measurement Mean"], "Measurement Variance", "-"^width["Measurement Variance"])
    printf(io, fmtEst[3], width, show, "State Estimation Estimate", "-"^width["State Estimation Estimate"], "State Estimation Residual", "-"^width["State Estimation Residual"])
    printf(io, fmtSta[3], width, show, "Status", "-"^width["Status"])

    if newLine
        @printf io "\n"
    end
end

function printDevice(io::IO, pfmt::Dict{String, Format}, width::Dict{String, Int64}, show::Dict{String, Bool}, label::String, meter::GaussMeter, estimate::Array{Float64,1},
    scale::Float64, i::Int64, j::Int64; printLabel::Bool = true, newLine::Bool = true)

    if printLabel
        @printf(io, "| %-*s |", width["Label"], label)
    end

    printf(io, pfmt, show, width, meter.mean, i, scale, "Measurement Mean")
    printf(io, pfmt, show, width, meter.variance, i, scale, "Measurement Variance")
    printf(io, pfmt, show, width, estimate, j, scale, "State Estimation Estimate")

    if meter.status[i] == 1
        printf(io, pfmt, show, width, meter.mean, estimate, i, j, scale, "State Estimation Residual")
    else
        printf(io, pfmt["Dash"], width, show, "State Estimation Residual", "-")
    end

    printf(io, pfmt, show, width, meter.status, i, "Status")

    if newLine
        @printf io "\n"
    end
end

function findEstimate(device::M, analysisBus::Array{Float64,1}, analysisFrom::Array{Float64,1}, analysisTo::Array{Float64,1}, i::Int64)
    if device.layout.bus[i]
        return analysisBus
    elseif device.layout.from[i]
        return analysisFrom
    else
        return analysisTo
    end
end

function findEstimate(device::M, analysisFrom::Array{Float64,1}, analysisTo::Array{Float64,1}, i::Int64)
    if device.layout.from[i]
        return analysisFrom
    else
        return analysisTo
    end
end

function formatDevice(width::Dict{String, Int64}, show::Dict{String, Bool}, minval::Dict{String, Float64}, maxval::Dict{String, Float64},
    label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64)

    if show["Measurement Mean"]
        minval["Measurement Mean"] = min(meter.mean[i] * scale, minval["Measurement Mean"])
        maxval["Measurement Mean"] = max(meter.mean[i] * scale, maxval["Measurement Mean"])
    end

    if show["Measurement Variance"]
        minval["Measurement Variance"] = min(meter.variance[i] * scale, minval["Measurement Variance"])
        maxval["Measurement Variance"] = max(meter.variance[i] * scale, maxval["Measurement Variance"])
    end

    if show["State Estimation Estimate"]
        minval["State Estimation Estimate"] = min(estimate[j] * scale, minval["State Estimation Estimate"])
        maxval["State Estimation Estimate"] = max(estimate[j] * scale, maxval["State Estimation Estimate"])
    end

    if show["State Estimation Residual"] && meter.status[i] == 1
        minval["State Estimation Residual"] = min((meter.mean[i] - estimate[j]) * scale, minval["State Estimation Residual"])
        maxval["State Estimation Residual"] = max((meter.mean[i] - estimate[j]) * scale, maxval["State Estimation Residual"])
    end

    width["Label"] = max(textwidth(label), width["Label"])
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, minval::Dict{String, Float64}, maxval::Dict{String, Float64}, title::String; _show::Dict{String, Bool} = Dict{String, Bool}())
    width["Label"] = max(width["Label"], 5)

    pmuData = false
    for key in keys(minval)
        if show[key]
            width[key] = max( textwidth(format(Format(fmt[key]), 0, minval[key])), textwidth(format(Format(fmt[key]), 0, maxval[key])), width[key])
            pmuData = true
        end
    end

    if !pmuData
        width["Label"] = max(textwidth(title), width["Label"])
        _show[title] = pmuData
    end

    titlemax(width, show, "Measurement Mean", "Measurement Variance", "Measurement")
    titlemax(width, show, "State Estimation Estimate", "State Estimation Residual", "State Estimation")
end