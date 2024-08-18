"""
    printVoltmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, delimiter, fmt, width, show, style)

The function prints data related to voltmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding voltmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

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
fmt = Dict("Measurement" => "%.2f", "State Estimation Estimate" => "%.6f")
show = Dict("State Estimation Residual" => false)
printVoltmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific voltmeters
width = Dict("Measurement Variance" => 9)
printVoltmeterData(system, device, analysis; label = 1, width, header = true)
printVoltmeterData(system, device, analysis; label = 6, width)
printVoltmeterData(system, device, analysis; label = 8, width, footer = true)
```
"""
function printVoltmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    voltage = Polar(Float64[], Float64[])

    _printVoltmeterData(system, device, voltage, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printVoltmeterData(system, device, analysis.voltage, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function _printVoltmeterData(system::PowerSystem, device::Measurement, voltage::Polar, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    voltmeter = device.voltmeter
    fmt, width, show = formatVoltmeterData(system, voltmeter, voltage, label, prefix, fmt, width, show, style)

    if !isempty(voltmeter.label)
        maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
        labels, header, footer = toggleLabelHeader(label, voltmeter, voltmeter.label, header, footer, "voltmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Voltmeter Data")
                headerDevice(io, width, show, delimiter, unitList.voltageMagnitudeLive)
            else
                headerDevice(io, show, delimiter, unitList.voltageMagnitudeLive, "Voltmeter")
            end
        end

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end
            printDevice(io, pfmt, width, show, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus)
        end

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, minval, maxval = formatDevice(fmt, show, voltmeter.magnitude, voltage.magnitude, style)
    if !isempty(voltmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)
        labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

        if style
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
    end

    return fmt, width, show
end

"""
    printAmmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, delimiter, fmt, width, show, style)

The function prints data related to ammeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding ammeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

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
fmt = Dict("Measurement" => "%.2f", "State Estimation Estimate" => "%.6f")
show = Dict("State Estimation Residual" => false)
printAmmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific ammeters
width = Dict("Measurement Variance" => 9)
printAmmeterData(system, device, analysis; label = "From 1", width, header = true)
printAmmeterData(system, device, analysis; label = "From 4", width)
printAmmeterData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printAmmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printAmmeterData(system, device, current, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printAmmeterData(system, device, analysis.current, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function _printAmmeterData(system::PowerSystem, device::Measurement, current::ACCurrent, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    ammeter = device.ammeter
    fmt, width, show = formatAmmeterData(system, ammeter, current, label, prefix, fmt, width, show, style)

    if !isempty(ammeter.label)
        maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
        labels, header, footer = toggleLabelHeader(label, ammeter, ammeter.label, header, footer, "ammeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Ammeter Data")
                headerDevice(io, width, show, delimiter, unitList.currentMagnitudeLive)
            else
                headerDevice(io, show, delimiter, unitList.currentMagnitudeLive, "Ammeter")
            end
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

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, minval, maxval = formatDevice(fmt, show, ammeter.magnitude, current.from.magnitude, style)
    if !isempty(ammeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)
        labels = toggleLabel(label, ammeter, ammeter.label, "ammeter")

        if style
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
    end

    return fmt, width, show
end

"""
    printWattmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, delimiter, fmt, width, show, style)

The function prints data related to wattmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding wattmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

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
fmt = Dict("Measurement" => "%.2f", "State Estimation Estimate" => "%.6f")
show = Dict("State Estimation Residual" => false)
printWattmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific wattmeters
width = Dict("Measurement Mean" => 7)
printWattmeterData(system, device, analysis; label = 2, width, header = true)
printWattmeterData(system, device, analysis; label = 5, width)
printWattmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printWattmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printWattmeterData(system, device, power, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printWattmeterData(system, device, analysis.power, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function _printWattmeterData(system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower}, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    fmt, width, show = formatWattmeterData(wattmeter, power, scale, label, fmt, width, show, style)

    if !isempty(wattmeter.label)
        maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
        labels, header, footer = toggleLabelHeader(label, wattmeter, wattmeter.label, header, footer, "wattmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Wattmeter Data")
                headerDevice(io, width, show, delimiter, unitList.activePowerLive)
            else
                headerDevice(io, show, delimiter, unitList.activePowerLive, "Wattmeter")
            end
        end

        @inbounds for (label, i) in labels
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, pfmt, width, show, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i])
        end

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatWattmeterData(wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, mival, maxval = formatDevice(fmt, show, wattmeter.active, power.injection.active, style)
    if !isempty(wattmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)
        labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
                formatDevice(width, show, mival, maxval, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i])
            end
            formatDevice(fmt, width, show, mival, maxval, "Wattmeter Data")
        end
    end

    return fmt, width, show
end

"""
    printVarmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, delimiter, fmt, width, show, style)

The function prints data related to varmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding varmeter.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

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
fmt = Dict("Measurement" => "%.2f", "State Estimation Estimate" => "%.6f")
show = Dict("State Estimation Residual" => false)
printVarmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific varmeters
width = Dict("Measurement Mean" => 7)
printVarmeterData(system, device, analysis; label = 2, width, header = true)
printVarmeterData(system, device, analysis; label = 5, width)
printVarmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printVarmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printVarmeterData(system, device, power, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printVarmeterData(system, device, analysis.power, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function _printVarmeterData(system::PowerSystem, device::Measurement, power::ACPower, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    varmeter = device.varmeter

    scale = printScale(system, prefix)
    fmt, width, show = formatVarmeterData(varmeter, power, scale, label, fmt, width, show, style)

    if !isempty(varmeter.label)
        maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
        labels, header, footer = toggleLabelHeader(label, varmeter, varmeter.label, header, footer, "varmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Varmeter Data")
                headerDevice(io, width, show, delimiter, unitList.reactivePowerLive)
            else
                headerDevice(io, show, delimiter, unitList.reactivePowerLive, "Varmeter")
            end
        end

        @inbounds for (label, i) in labels
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, pfmt, width, show, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i])
        end

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatVarmeterData(varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, mival, maxval = formatDevice(fmt, show, varmeter.reactive, power.injection.reactive, style)
    if !isempty(varmeter.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)
        labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
                formatDevice(width, show, mival, maxval, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i])
            end
            formatDevice(fmt, width, show, mival, maxval, "Varmeter Data")
        end
    end

    return fmt, width, show
end

"""
    printPmuData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, header, footer, delimiter, fmt, width, show, style)

The function prints data related to PMUs. Optionally, an `IO` may be passed as the last
argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding PMU.
* `header`: Toggles the printing of the header.
* `footer`: Toggles the printing of the footer.
* `delimiter`: Sets the column delimiter.
* `fmt`: Specifies the preferred numeric format of each column.
* `width`: Specifies the preferred width of each column.
* `show`: Toggles the printing of each column.
* `style`: Prints either a stylish table or a simple table suitable for easy export.

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
fmt = Dict("Measurement" => "%.2f", "State Estimation Estimate" => "%.6f")
show = Dict("State Estimation Residual" => false)
printPmuData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific PMUs
width = Dict("Measurement Mean" => 7)
printPmuData(system, device, analysis; label = "From 1", width, header = true)
printPmuData(system, device, analysis; label = "From 4", width)
printPmuData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printPmuData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printPmuData(system, device, voltage, current, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printPmuData(system, device, analysis.voltage, analysis.current, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout; label::L = missing,
    header::B = missing, footer::B = missing, delimiter::String = "|", fmt::Dict{String, String} = Dict{String, String}(),
    width::Dict{String, Int64} = Dict{String, Int64}(), show::Dict{String, Bool} = Dict{String, Bool}(), style::Bool = true)

    _printPmuData(system, device, analysis.voltage, io, label, prefix, header, footer, fmt, width, show, delimiter, style)
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    pmu = device.pmu

    scale = printScale(system, prefix)
    fmt, widthV, widthθ, widthI, widthψ, showV, showθ, showI, showψ, _show = formatPmuData(system, pmu, voltage, current, scale, label, prefix, fmt, width, show, style)
    labels, header, footer = toggleLabelHeader(label, pmu, pmu.label, header, footer, "pmu")

    if _show["Voltage"]
        maxLineV, pfmtV = setupPrintSystem(fmt, widthV, showV, delimiter, style; dash = true)
        maxLineθ, pfmtθ = setupPrintSystem(fmt, widthθ, showθ, delimiter, style; label = false, dash = true)

        if header
            if style
                printTitle(io, maxLineV + maxLineθ, delimiter, "PMU Voltage Data")
                if _show["PMU Voltage Data"]
                    print(io, format(Format("$delimiter %-*s $delimiter % -*s $delimiter\n"), maxLineV - 2, "Magnitude", maxLineθ - 3, "Angle"))
                end
                headerDevice(io, widthV, widthθ, showV, showθ, delimiter, maxLineV, maxLineθ, unitList.voltageMagnitudeLive, unitList.voltageAngleLive, _show["PMU Voltage Data"])
            else
                headerDevice(io, showV, showθ, delimiter, unitList.voltageMagnitudeLive, unitList.voltageAngleLive, _show["PMU Voltage Data"], "PMU Voltage")
            end
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

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter"), "-"^maxLineV))
            if _show["PMU Voltage Data"]
                print(io, format(Format("%s$delimiter"), "-"^(maxLineθ - 1)))
            end
            @printf(io, "\n")
        end
    end

    if _show["Current"]
        maxLineI, pfmtI = setupPrintSystem(fmt, widthI, showI, delimiter, style; dash = true)
        maxLineψ, pfmtψ, = setupPrintSystem(fmt, widthψ, showψ, delimiter, style; label = false, dash = true)

        if header
            if style
                printTitle(io, maxLineI + maxLineψ, delimiter, "PMU Current Data")
                if _show["PMU Current Data"]
                    print(io, format(Format("$delimiter %-*s $delimiter % -*s $delimiter\n"), maxLineI - 2, "Magnitude", maxLineψ - 3, "Angle"))
                end
                headerDevice(io, widthI, widthψ, showI, showψ, delimiter, maxLineI, maxLineψ, unitList.currentMagnitudeLive, unitList.currentAngleLive, _show["PMU Current Data"])
            else
                headerDevice(io, showI, showψ, delimiter, unitList.currentMagnitudeLive, unitList.currentAngleLive, _show["PMU Current Data"], "PMU Current")
            end
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

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter"), "-"^maxLineI))
            if _show["PMU Current Data"]
                print(io, format(Format("%s$delimiter"), "-"^(maxLineψ - 1)))
            end
            @printf(io, "\n")
        end
    end
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    pmu = device.pmu

    scale = printScale(system, prefix)
    fmt, width, show, _show = formatPmuData(system, pmu, voltage, scale, label, prefix, fmt, width, show, style)

    if _show["Voltage"]
        maxLine, pfmt = setupPrintSystem(fmt, width, show, delimiter, style; dash = true)
        labels, header, footer = toggleLabelHeader(label, pmu, pmu.label, header, footer, "pmu")

        if header
            if style
                printTitle(io, maxLine, delimiter, "PMU Voltage Data")
                if _show["PMU Voltage Data"]
                    print(io, format(Format("$delimiter %-*s $delimiter\n"),  maxLine - 2, "Angle"))
                    print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
                end
                headerDevice(io, width, show, delimiter, unitList.voltageAngleLive)
            else
                headerDevice(io, show, delimiter, unitList.voltageAngleLive, "PMU Voltage")
            end
        end

        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]
                printDevice(io, pfmt, width, show, label, pmu.angle, voltage.angle, scale["θ"], i, indexBus)
            end
        end

        if footer && style
            print(io, format(Format("$delimiter%s$delimiter\n"), "-"^maxLine))
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L,
    prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, minV, maxV = formatDevice(fmt, show, pmu.magnitude, voltage.magnitude, style)
    fmt, widthV, showV = printFormat(_fmt, fmt, _width, width, _show, show, style)
    _, _width, _show, minθ, maxθ = formatDevice(fmt, show, pmu.angle, voltage.angle, style)
    _, widthθ, showθ = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show, style)

    _, _width, _show, minI, maxI = formatDevice(fmt, show, pmu.magnitude, current.from.magnitude, style)
    _, widthI, showI = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show, style)
    _, _width, _show, minψ, maxψ = formatDevice(fmt, show, pmu.angle, current.from.angle, style)
    _, widthψ, showψ = printFormat(Dict{String, String}(), Dict{String, String}(), _width, width, _show, show, style)

    if !isempty(pmu.label)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")
        _show = Dict("Voltage" => true, "Current" => true, "PMU Voltage Data" => true, "PMU Current Data" => true)

        if style
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

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    formatDevice(widthψ, showψ, minψ, maxψ, label, pmu.angle, estimate, scale["ψ"], i, indexBusBranch)
                end
            end

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
        else
            if !any(pmu.layout.bus)
                _show["Voltage"] = false
            end
            if !any(pmu.layout.from) || !any(pmu.layout.from)
                _show["Current"] = false
            end
        end
    end

    return fmt, widthV, widthθ, widthI, widthψ, showV, showθ, showI, showψ, _show
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, style::Bool)

    _fmt, _width, _show, minval, maxval = formatDevice(fmt, show, pmu.angle, voltage.angle, style)

    if !isempty(pmu.label)
        fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")
        _show = Dict("Voltage" => true, "PMU Voltage Data" => true)

        if style
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    formatDevice(width, show, minval, maxval, label, pmu.angle, voltage.angle, scale["θ"], i, pmu.layout.index[i])
                end
            end

            if width["Label"] == 0
                _show["Voltage"] = false
            else
                formatDevice(fmt, width, show, minval, maxval, "PMU Voltage Data"; _show)
            end
        else
            if !any(pmu.layout.bus)
                _show["Voltage"] = false
            end
        end
    end

    return fmt, width, show, _show
end

function formatDevice(fmt::Dict{String, String}, show::Dict{String, Bool}, meter::GaussMeter, analysisArray::Array{Float64,1}, style::Bool)
    mshow = Dict(
        "Measurement" => true,
        "State Estimation" => true,
    )
    mfmt = Dict(
        "Measurement" => "",
        "State Estimation" => "",
    )
    mshow, mfmt = printFormat(mshow, show, mfmt, fmt)

    width = Dict(
        "Label" => 0,
        "Measurement Mean" => 4 * style,
        "Measurement Variance" => 8 * style,
        "State Estimation Estimate" => 8 * style,
        "State Estimation Residual" => 8 * style,
        "Status" => 6 * style
    )
    fmt = Dict(
        "Measurement Mean" => isempty(mfmt["Measurement"]) ? "%*.4f" : mfmt["Measurement"],
        "Measurement Variance" => isempty(mfmt["Measurement"]) ? "%*.2e" : mfmt["Measurement"],
        "State Estimation Estimate" => isempty(mfmt["State Estimation"]) ? "%*.4f" : mfmt["State Estimation"],
        "State Estimation Residual" => isempty(mfmt["State Estimation"]) ? "%*.4f" : mfmt["State Estimation"],
        "Status" => "%*i"
    )
    show = Dict(
        "Measurement Mean" => !isempty(meter.mean) & mshow["Measurement"],
        "Measurement Variance" => !isempty(meter.variance) & mshow["Measurement"],
        "State Estimation Estimate" => !isempty(analysisArray) & mshow["State Estimation"],
        "State Estimation Residual" => !isempty(analysisArray) & mshow["State Estimation"],
        "Status" => !isempty(meter.status)
    )

    minval = Dict(
        "Measurement Mean" => Inf,
        "Measurement Variance" => Inf,
        "State Estimation Estimate" => Inf,
        "State Estimation Residual" => Inf,
    )
    maxval = Dict(
        "Measurement Mean" => -Inf,
        "Measurement Variance" => -Inf,
        "State Estimation Estimate" => -Inf,
        "State Estimation Residual" => -Inf,
    )

    return fmt, width, show, minval, maxval
end

function headerDevice(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, unitLive::String)
    fmtMes, fmtEst, fmtSta = printHeader1(io, width, show, delimiter)
    printHeader2(io, width, show, fmtMes, fmtEst, fmtSta, delimiter)
    printHeader3(io, width, show, fmtMes, fmtEst, fmtSta, delimiter)
    printHeader4(io, width, show, unitLive, fmtMes, fmtEst, fmtSta, delimiter)
    printHeader5(io, width, show, fmtMes, fmtEst, fmtSta, delimiter)
end

function headerDevice(io::IO, show::Dict{String, Bool}, delimiter::String, unitLive::String, device::String)
    print(io, format(Format("%s"), "$device Label"))
    printf(io, show, delimiter, "Measurement Mean", "Measurement Mean", "Measurement Variance", "Measurement Variance")
    printf(io, show, delimiter, "State Estimation Estimate", "State Estimation Estimate", "State Estimation Residual", "State Estimation Residual")
    printf(io, show, delimiter, "Status", "Status")
    @printf io "\n"

    print(io, format(Format("%s"), ""))
    printf(io, show, delimiter, "Measurement Mean", "[$unitLive]", "Measurement Variance", "[$unitLive]")
    printf(io, show, delimiter, "State Estimation Estimate", "[$unitLive]", "State Estimation Residual", "[$unitLive]")
    printf(io, show, delimiter, "Status", "")
    @printf io "\n"
end

function headerDevice(io::IO, width1::Dict{String, Int64}, width2::Dict{String, Int64}, show1::Dict{String, Bool}, show2::Dict{String, Bool},
    delimiter::String, maxLine1::Int64, maxLine2::Int64, unitLive1::String, unitLive2::String, hasMore::Bool)

    if hasMore
        print(io, format(Format("$delimiter%s$delimiter%s$delimiter\n"), "-"^maxLine1, "-"^(maxLine2 - 1)))
    end

    fmtMes1, fmtEst1, fmtSta1 = printHeader1(io, width1, show1, delimiter; newLine = !hasMore)
    if hasMore
        fmtMes2, fmtEst2, fmtSta2 = printHeader1(io, width2, show2, delimiter; label = false)
    end

    if hasMore
        printHeader2(io, width1, show1, fmtMes1, fmtEst1, fmtSta1, delimiter; newLine = !hasMore)
        printHeader2(io, width2, show2, fmtMes2, fmtEst2, fmtSta2, delimiter; label = false)
    end

    if hasMore
        printHeader3(io, width1, show1, fmtMes1, fmtEst1, fmtSta1, delimiter; newLine = !hasMore)
        printHeader3(io, width2, show2, fmtMes2, fmtEst2, fmtSta2, delimiter; label = false)
    end

    if hasMore
        printHeader4(io, width1, show1, unitLive1, fmtMes1, fmtEst1, fmtSta1, delimiter; newLine = !hasMore)
        printHeader4(io, width2, show2, unitLive2, fmtMes2, fmtEst2, fmtSta2, delimiter; label = false)
    end

    printHeader5(io, width1, show1, fmtMes1, fmtEst1, fmtSta1, delimiter; newLine = !hasMore)
    if hasMore
        printHeader5(io, width2, show2, fmtMes2, fmtEst2, fmtSta2, delimiter; label = false)
    end
end

function headerDevice(io::IO, show1::Dict{String, Bool}, show2::Dict{String, Bool}, delimiter::String, unitLive1::String, unitLive2::String,
    hasMore::Bool, device::String)

    print(io, format(Format("%s"), "$device Label"))
    printf(io, show1, delimiter, "Measurement Mean", "Magnitude Measurement Mean", "Measurement Variance", "Magnitude Measurement Variance")
    printf(io, show1, delimiter, "State Estimation Estimate", "Magnitude State Estimation Estimate", "State Estimation Residual", "Magnitude State Estimation Residual")
    printf(io, show1, delimiter, "Status", "Magnitude Status")
    if hasMore
        printf(io, show2, delimiter, "Measurement Mean", "Angle Measurement Mean", "Measurement Variance", "Angle Measurement Variance")
        printf(io, show2, delimiter, "State Estimation Estimate", "Angle State Estimation Estimate", "State Estimation Residual", "Angle State Estimation Residual")
        printf(io, show2, delimiter, "Status", "Angle Status")
    end
    @printf io "\n"

    print(io, format(Format("%s"), ""))
    printf(io, show1, delimiter, "Measurement Mean", "[$unitLive1]", "Measurement Variance", "[$unitLive1]")
    printf(io, show1, delimiter, "State Estimation Estimate", "[$unitLive1]", "State Estimation Residual", "[$unitLive1]")
    printf(io, show1, delimiter, "Status", "")
    if hasMore
        printf(io, show2, delimiter, "Measurement Mean", "[$unitLive2]", "Measurement Variance", "[$unitLive2]")
        printf(io, show2, delimiter, "State Estimation Estimate", "[$unitLive2]", "State Estimation Residual", "[$unitLive2]")
        printf(io, show2, delimiter, "Status", "")
    end
    @printf io "\n"
end

function printHeader1(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String; label::Bool = true, newLine::Bool = true)
    if label
        print(io, format(Format("$delimiter %*s%s%*s $delimiter"), floor(Int, (width["Label"] - 5) / 2), "", "Label", ceil(Int, (width["Label"] - 5) / 2) , ""))
    end

    fmtMes = printf(io, width, show, delimiter, "Measurement Mean", "Measurement Variance", "Measurement")
    fmtEst = printf(io, width, show, delimiter, "State Estimation Estimate", "State Estimation Residual", "State Estimation")
    fmtSta = printf(io, width, show, delimiter, "Status", "Status")

    if newLine
        @printf io "\n"
    end

    return fmtMes, fmtEst, fmtSta
end

function printHeader2(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}, delimiter::String; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
    end

    printf(io, fmtMes[1], width, show, "Measurement Mean", "", "Measurement Variance", "")
    printf(io, fmtEst[1], width, show, "State Estimation Estimate", "", "State Estimation Residual", "")
    printf(io, fmtSta[1], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader3(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}, delimiter::String; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
    end

    printf(io, fmtMes[2], width, show, "Measurement Mean", "Mean", "Measurement Variance", "Variance")
    printf(io, fmtEst[2], width, show, "State Estimation Estimate", "Estimate", "State Estimation Residual", "Residual")
    printf(io, fmtSta[2], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader4(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, unitLive::String, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}, delimiter::String; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        print(io, format(Format("$delimiter %*s $delimiter"), width["Label"], ""))
    end

    printf(io, fmtMes[2], width, show, "Measurement Mean", "[$unitLive]", "Measurement Variance", "[$unitLive]")
    printf(io, fmtEst[2], width, show, "State Estimation Estimate", "[$unitLive]", "State Estimation Residual", "[$unitLive]")
    printf(io, fmtSta[2], width, show, "Status", "")

    if newLine
        @printf io "\n"
    end
end

function printHeader5(io::IO, width::Dict{String, Int64}, show::Dict{String, Bool}, fmtMes::Tuple{Format, Format, Format},
    fmtEst::Tuple{Format, Format, Format}, fmtSta::Tuple{Format, Format, Format}, delimiter::String; label::Bool = true, newLine::Bool = true, last::Bool = true)

    if label
        print(io, format(Format("$delimiter-%*s-$delimiter"), width["Label"], "-"^width["Label"]))
    end

    printf(io, fmtMes[3], width, show, "Measurement Mean", "-"^width["Measurement Mean"], "Measurement Variance", "-"^width["Measurement Variance"])
    printf(io, fmtEst[3], width, show, "State Estimation Estimate", "-"^width["State Estimation Estimate"], "State Estimation Residual", "-"^width["State Estimation Residual"])
    printf(io, fmtSta[3], width, show, "Status", "-"^width["Status"])

    if newLine
        @printf io "\n"
    end
end

function printDevice(io::IO, pfmt::Dict{String, Format}, width::Dict{String, Int64}, show::Dict{String, Bool}, label::String,
    meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64; printLabel::Bool = true, newLine::Bool = true)

    if printLabel
        print(io, format(pfmt["Label"], width["Label"], label))
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
            width[key] = max(textwidth(format(Format(fmt[key]), 0, minval[key])), textwidth(format(Format(fmt[key]), 0, maxval[key])), width[key])
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