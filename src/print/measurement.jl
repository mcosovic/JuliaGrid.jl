"""
    printVoltmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints data related to voltmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding voltmeter.
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
fmt = Dict("Voltage Magnitude" => "%.2f", "Voltage Magnitude Estimate" => "%.6f")
show = Dict("Voltage Magnitude Residual" => false)
printVoltmeterData(system, device, analysis; fmt, show, delimiter = " ", repeat = 10)

# Print data for specific voltmeters
width = Dict("Voltage Magnitude Estimate" => 11)
printVoltmeterData(system, device, analysis; label = 1, width, header = true)
printVoltmeterData(system, device, analysis; label = 6, width)
printVoltmeterData(system, device, analysis; label = 8, width, footer = true)
```
"""
function printVoltmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.voltmeter.number + 1)

    voltage = Polar(Float64[], Float64[])

    _printVoltmeterData(io, system, device, analysis.voltage, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true, title::B = missing, header::B = missing,
    footer::B = missing, repeat::Int64 = device.voltmeter.number + 1)

    _printVoltmeterData(io, system, device, analysis.voltage, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function _printVoltmeterData(io::IO, system::PowerSystem, device::Measurement, voltage::Polar, unitList::UnitList,
    prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    type = "Voltage Magnitude"
    voltmeter = device.voltmeter

    labels, title, header, footer = formPrint(voltmeter, voltmeter.label, label, title, header, footer, "voltmeter")
    fmt, width, show, heading, subheading, unit, type, printing = formatVoltmeterData(system, voltage, voltmeter, unitList, prefix, label, fmt, width, show, title, style, type)

    if !isempty(voltmeter.label) && printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Voltmeter Data")

        @inbounds for (label, i) in labels
            indexBus = voltmeter.layout.index[i]
            scale = scaleVoltage(prefix, system, indexBus)

            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label")

            printDevice(io, voltmeter.magnitude, voltage.magnitude, scale, pfmt, hfmt, width, show, indexBus, i, type)

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatVoltmeterData(system::PowerSystem, voltage::Polar, voltmeter::Voltmeter, unitList::UnitList, prefix::PrefixLive,
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool, type::String)

    device = !isempty(voltmeter.label)
    state = !isempty(voltage.magnitude)

    fmt, width, show, subheading, unit, type, minval, maxval = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, device, state, style, type)
    if device
        labels = toggleLabel(voltmeter, voltmeter.label, label, "voltmeter")

        if style
            @inbounds for (label, i) in labels
                indexBus = voltmeter.layout.index[i]
                scale = scaleVoltage(prefix, system, indexBus)
                formatDevice(voltmeter.magnitude, voltage.magnitude, scale, label, width, show, minval, maxval, indexBus, i, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, title, style, "Voltmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, type, printing
end

"""
    printAmmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints data related to ammeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding ammeter.
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
fmt = Dict("Current Magnitude" => "%.2f", "Current Magnitude Estimate" => "%.6f")
show = Dict("Current Magnitude Residual" => false)
printAmmeterData(system, device, analysis; fmt, show, delimiter = " ", repeat = 10)

# Print data for specific ammeters
width = Dict("Current Magnitude" => 10)
printAmmeterData(system, device, analysis; label = "From 1", width, header = true)
printAmmeterData(system, device, analysis; label = "From 4", width)
printAmmeterData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printAmmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.ammeter.number + 1)

    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printAmmeterData(io, system, device, current, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.ammeter.number + 1)

    _printAmmeterData(io, system, device, analysis.current, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function _printAmmeterData(io::IO, system::PowerSystem, device::Measurement, current::ACCurrent, unitList::UnitList,
    prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    type = "Current Magnitude"
    ammeter = device.ammeter

    labels, title, header, footer = formPrint(ammeter, ammeter.label, label, title, header, footer, "ammeter")
    fmt, width, show, heading, subheading, unit, type, printing = formatAmmeterData(system, ammeter, current, unitList, prefix, label, fmt, width, show, title, style, type)

    if !isempty(ammeter.label) && printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Ammeter Data")

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

            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label")

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, ammeter.magnitude, estimate, scale, pfmt, hfmt, width, show, indexBranch, i, type)

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, unitList::UnitList, prefix::PrefixLive,
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool, type::String)

    device = !isempty(ammeter.label)
    state = !isempty(current.from.magnitude)

    fmt, width, show, subheading, unit, type, minval, maxval = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, device, state, style, type)
    if device
        labels = toggleLabel(ammeter, ammeter.label, label, "ammeter")

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
                formatDevice(ammeter.magnitude, estimate, scale, label, width, show, minval, maxval, indexBranch, i, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, title, style, "Ammeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, type, printing
end

"""
    printWattmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints data related to wattmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding wattmeter.
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
fmt = Dict("Active Power" => "%.2f", "Active Power Estimate" => "%.6f")
show = Dict("Active Power Status" => false)
printWattmeterData(system, device, analysis; fmt, show, delimiter = " ", repeat = 14)

# Print data for specific wattmeters
width = Dict("Active Power Residual" => 11)
printWattmeterData(system, device, analysis; label = 2, width, header = true)
printWattmeterData(system, device, analysis; label = 5, width)
printWattmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printWattmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.wattmeter.number + 1)

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printWattmeterData(io, system, device, power, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.wattmeter.number + 1)

    _printWattmeterData(io, system, device, analysis.power, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function _printWattmeterData(io::IO, system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower},
    unitList::UnitList, prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64},
    show::Dict{String, Bool}, delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    type = "Active Power"
    wattmeter = device.wattmeter

    scale = scalePrint(system, prefix)
    labels, title, header, footer = formPrint(wattmeter, wattmeter.label, label, title, header, footer, "wattmeter")
    fmt, width, show, heading, subheading, unit, type, printing = formatWattmeterData(wattmeter, power, unitList, scale, label, fmt, width, show, title, style, type)

    if !isempty(wattmeter.label) && printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Wattmeter Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label")

            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, wattmeter.active, estimate, scale["P"], pfmt, hfmt, width, show, wattmeter.layout.index[i], i, type)

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatWattmeterData(wattmeter::Wattmeter, power::Union{ACPower, DCPower}, unitList::UnitList, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool, type::String)

    device = !isempty(wattmeter.label)
    state = !isempty(power.injection.active)

    fmt, width, show, subheading, unit, type, minval, maxval = formatDevice(fmt, width, show, unitList.activePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(wattmeter, wattmeter.label, label, "wattmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
                formatDevice(wattmeter.active, estimate, scale["P"], label, width, show, minval, maxval, wattmeter.layout.index[i], i, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, title, style, "Wattmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, type, printing
end

"""
    printVarmeterData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints data related to varmeters. Optionally, an `IO` may be passed as the
last argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding varmeter.
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
fmt = Dict("Reactive Power" => "%.2f", "Reactive Power Estimate" => "%.6f")
show = Dict("Reactive Power Status" => false)
printVarmeterData(system, device, analysis; fmt, show, delimiter = " ", repeat = 14)

# Print data for specific wattmeters
width = Dict("Reactive Power Residual" => 11)
printVarmeterData(system, device, analysis; label = 2, width, header = true)
printVarmeterData(system, device, analysis; label = 5, width)
printVarmeterData(system, device, analysis; label = 9, width, footer = true)
```
"""
function printVarmeterData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.varmeter.number + 1)

    power = ACPower(Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]), Cartesian(Float64[], Float64[]))

    _printVarmeterData(io, system, device, power, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.varmeter.number + 1)

    _printVarmeterData(io, system, device, analysis.power, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function _printVarmeterData(io::IO, system::PowerSystem, device::Measurement, power::ACPower,
    unitList::UnitList, prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64},
    show::Dict{String, Bool}, delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    type = "Reactive Power"
    varmeter = device.varmeter

    scale = scalePrint(system, prefix)

    labels, title, header, footer = formPrint(varmeter, varmeter.label, label, title, header, footer, "varmeter")
    fmt, width, show, heading, subheading, unit, type, printing = formatVarmeterData(varmeter, power, unitList, scale, label, fmt, width, show, title, style, type)

    if !isempty(varmeter.label) && printing
        pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
        titlePrint(io, delimiter, title, header, style, maxLine, "Varmeter Data")

        @inbounds for (label, i) in labels
            printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, i)
            printf(io, pfmt, width, show, label, "Label")

            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, varmeter.reactive, estimate, scale["Q"], pfmt, hfmt, width, show, varmeter.layout.index[i], i, type)

            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatVarmeterData(varmeter::Varmeter, power::ACPower, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool, type::String)

    device = !isempty(varmeter.label)
    state = !isempty(power.injection.reactive)

    fmt, width, show, subheading, unit, type, minval, maxval = formatDevice(fmt, width, show, unitList.reactivePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(varmeter, varmeter.label, label, "varmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
                formatDevice(varmeter.reactive, estimate, scale["Q"], label, width, show, minval, maxval, varmeter.layout.index[i], i, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, title, style, "Varmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, type, printing
end

"""
    printPmuData(system::PowerSystem, device::Measurement, [analysis::Analysis],
        [io::IO]; label, fmt, width, show, delimiter, title, header, footer, repeat, style)

The function prints data related to PMUs. Optionally, an `IO` may be passed as the last
argument to redirect the output. Users can also omit the `Analysis` type to print
only data related to the `Measurement` type.

# Keywords
The following keywords control the printed data:
* `label`: Prints only the data for the corresponding PMU.
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
fmt = Dict("Current Magnitude" => "%.2f", "Current Magnitude Variance" => "%.5f")
show = Dict("Current Angle" => false, "Current Magnitude Status" => false)
printPmuData(system, device, analysis; fmt, show, delimiter = " ", repeat = 10)

# Print data for specific PMUs
width = Dict("Current Magnitude" => 10, "Current Angle Status" => 8)
printPmuData(system, device, analysis; label = "From 1", width, header = true)
printPmuData(system, device, analysis; label = "From 4", width)
printPmuData(system, device, analysis; label = "From 6", width, footer = true)
```
"""
function printPmuData(system::PowerSystem, device::Measurement, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.pmu.number + 1)

    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]), Polar(Float64[], Float64[]))

    _printPmuData(io, system, device, voltage, current, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.pmu.number + 1)

    _printPmuData(io, system, device, analysis.voltage, analysis.current, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.pmu.number + 1)

    _printPmuData(io, system, device, analysis.voltage, unitList, prefix, label, fmt, width, show, delimiter, title, header, footer, repeat, style)
end

function _printPmuData(io::IO, system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent,
    unitList::UnitList, prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64},
    show::Dict{String, Bool}, delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    pmu = device.pmu
    if !isempty(pmu.label)
        scale = scalePrint(system, prefix)
        labels, title, header, footer = formPrint(pmu, pmu.label, label, title, header, footer, "pmu")
        fmtV, fmtI, widthV, widthI, showV, showI, headingV, headingI, subheadingV, subheadingI, unitV, unitI, typeV, typeθ, typeI, typeψ,
        printingV, printingI = formatPmuData(system, pmu, voltage, current, unitList, scale, label, fmt, width, show, title, style)

        if printingV
            pfmt, hfmt, maxLine = setupPrint(fmtV, widthV, showV, delimiter, style)
            titlePrint(io, delimiter, title, header, style, maxLine, "PMU Data")

            cnt = 1
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    indexBus = pmu.layout.index[i]
                    scaleV = scaleVoltage(prefix, system, indexBus)

                    printingV = headerPrint(io, hfmt, widthV, showV, headingV, subheadingV, unitV, delimiter, header, repeat, style, printingV, maxLine, cnt)
                    printf(io, pfmt, widthV, showV, label, "Label")

                    printDevice(io, pmu.magnitude, voltage.magnitude, scaleV, pfmt, hfmt, widthV, showV, indexBus, i, typeV)
                    printDevice(io, pmu.angle, voltage.angle, scale["θ"], pfmt, hfmt, widthV, showV, indexBus, i, typeθ)

                    @printf io "\n"
                    cnt += 1
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end

        if printingI
            pfmt, hfmt, maxLine = setupPrint(fmtI, widthI, showI, delimiter, style)
            titlePrint(io, delimiter, title, header, style, maxLine, "PMU Data")

            scaleI = 1.0
            cnt = 1
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

                    printingI = headerPrint(io, hfmt, widthI, showI, headingI, subheadingI, unitI, delimiter, header, repeat, style, printingI, maxLine, cnt)
                    printf(io, pfmt, widthI, showI, label, "Label")

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    printDevice(io, pmu.magnitude, estimate, scaleI, pfmt, hfmt, widthI, showI, indexBranch, i, typeI)

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    printDevice(io, pmu.angle, estimate, scale["ψ"], pfmt, hfmt, widthI, showI, indexBranch, i, typeψ)

                    @printf io "\n"
                    cnt += 1
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, unitList::UnitList, scale::Dict{String, Float64},
    label::L, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool)

    deviceV = any(pmu.layout.bus)
    stateV = !isempty(voltage.magnitude) & deviceV
    deviceI = any(pmu.layout.from) || any(pmu.layout.to)
    stateI = !isempty(current.from.magnitude) & deviceI

    fmtV, widthV, showV, subheadingV, unitV, typeV, minV, maxV = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, deviceV, stateV, style, "Voltage Magnitude")
    fmtθ, widthθ, showθ, subheadingθ, unitθ, typeθ, minθ, maxθ = formatDevice(fmt, width, show, unitList.voltageAngleLive, deviceV, stateV, style, "Voltage Angle")
    fmtV, widthV, showV, subheadingV, unitV = mergeDict(fmtV, fmtθ, widthV, widthθ, showV, showθ, subheadingV, subheadingθ, unitV, unitθ)

    fmtI, widthI, showI, subheadingI, unitI, typeI, minI, maxI = formatDevice(fmt, width, show, unitList.currentMagnitudeLive, deviceI, stateI, style, "Current Magnitude")
    fmtψ, widthψ, showψ, subheadingψ, unitψ, typeψ, minψ, maxψ = formatDevice(fmt, width, show, unitList.currentAngleLive, deviceI, stateI, style, "Current Angle")
    fmtI, widthI, showI, subheadingI, unitI = mergeDict(fmtI, fmtψ, widthI, widthψ, showI, showψ, subheadingI, subheadingψ, unitI, unitψ)

    isVol = false
    isCur = false
    if !isempty(pmu.label)
        labels = toggleLabel(pmu, pmu.label, label, "pmu")

        if style
            scaleI = 1.0
            @inbounds for (label, i) in labels
                indexBusBranch = pmu.layout.index[i]

                if pmu.layout.bus[i]
                    isVol = true
                    scaleV = scaleVoltage(prefix, system, indexBusBranch)

                    formatDevice(pmu.magnitude, voltage.magnitude, scaleV, label, widthV, showV, minV, maxV, indexBusBranch, i, typeV)
                    formatDevice(pmu.angle, voltage.angle, scale["θ"], label, widthV, showV, minθ, maxθ, indexBusBranch, i, typeθ)
                else
                    isCur = true
                    if prefix.currentMagnitude != 0.0
                        if pmu.layout.from[i]
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBusBranch])
                        else
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBusBranch])
                        end
                    end

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    formatDevice(pmu.magnitude, estimate, scaleI, label, widthI, showI, minI, maxI, indexBusBranch, i, typeI)

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    formatDevice(pmu.angle, estimate, scale["ψ"], label, widthI, showI, minψ, maxψ, indexBusBranch, i, typeψ)
                end
            end
            formatDevice(fmtV, widthV, showV, [minV; minθ[2:end]], [maxV; maxθ[2:end]])
            formatDevice(fmtI, widthI, showI, [minI; minψ[2:end]], [minI; maxψ[2:end]])
        end
    end
    printingV = howManyPrint(widthV, showV, title, style, "PMU Data")
    printingI = howManyPrint(widthI, showI, title, style, "PMU Data")

    headingV = headingDevice(widthV, showV, style, typeV)
    headingθ = headingDevice(widthV, showV, style, typeθ)
    headingV["Voltage Angle"] = headingθ["Voltage Angle"]

    headingI = headingDevice(widthI, showI, style, typeI)
    headingψ = headingDevice(widthψ, showψ, style, typeψ)
    headingI["Current Angle"] = headingψ["Current Angle"]

    return fmtV, fmtI, widthV, widthI, showV, showI, headingV, headingI, subheadingV, subheadingI, unitV, unitI, typeV, typeθ, typeI, typeψ, printingV & isVol, printingI & isCur
end

function _printPmuData(io::IO, system::PowerSystem, device::Measurement, voltage::PolarAngle,
    unitList::UnitList, prefix::PrefixLive, label::L, fmt::Dict{String, String}, width::Dict{String, Int64},
    show::Dict{String, Bool}, delimiter::String, title::B, header::B, footer::B, repeat::Int64, style::Bool)

    type = "Voltage Angle"
    pmu = device.pmu

    if !isempty(pmu.label)
        scale = scalePrint(system, prefix)
        labels, title, header, footer = formPrint(pmu, pmu.label, label, title, header, footer, "pmu")
        fmt, width, show, heading, subheading, unit, type, printing = formatPmuData(pmu, voltage, unitList, scale, label, fmt, width, show, title, style, type)

        if printing
            pfmt, hfmt, maxLine = setupPrint(fmt, width, show, delimiter, style)
            titlePrint(io, delimiter, title, header, style, maxLine, "PMU Data")

            cnt = 1
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    indexBus = pmu.layout.index[i]

                    printing = headerPrint(io, hfmt, width, show, heading, subheading, unit, delimiter, header, repeat, style, printing, maxLine, cnt)
                    printf(io, pfmt, width, show, label, "Label")

                    printDevice(io, pmu.angle, voltage.angle, scale["θ"], pfmt, hfmt, width, show, indexBus, i, type)

                    @printf io "\n"
                    cnt += 1
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end
    end
end

function formatPmuData(pmu::PMU, voltage::PolarAngle, unitList::UnitList, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, title::Bool, style::Bool, type::String)

    device = any(pmu.layout.bus)
    state = !isempty(voltage.angle) && device

    fmt, width, show, subheading, unit, type, minval, maxval = formatDevice(fmt, width, show, unitList.voltageAngleLive, device, state, style, type)
    if !isempty(pmu.label)
        labels = toggleLabel(pmu, pmu.label, label, "pmu")

        if style
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    formatDevice(pmu.angle, voltage.angle, scale["θ"], label, width, show, minval, maxval, pmu.layout.index[i], i, type)
                end
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, title, style, "PMU Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, type, printing
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    unitMeter::String, device::Bool, estimate::Bool, style::Bool, type::String)

    type = [type; "$type Measurement"; "$type Variance"; "$type Estimate"; "$type Residual"; "$type Status"]

    _show = OrderedDict(type[1] => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label" => _header_("", "Label", style),
        type[2] => _header_("Measurement", type[2], style),
        type[3] => _header_("Variance", type[3], style),
        type[4] => _header_("Estimate", type[4], style),
        type[5] => _header_("Residual", type[5], style),
        type[6] => _header_("Status", "Status", style)
    )
    unit = Dict(
        "Label" => "",
        type[2] => "[$unitMeter]",
        type[3] => "[$unitMeter]",
        type[4] => "[$unitMeter]",
        type[5] => "[$unitMeter]",
        type[6] => ""
    )
    _fmt = Dict(
        "Label" => "%-*s",
        type[2] => _fmt_(_fmt[type[1]]),
        type[3] => _fmt_(_fmt[type[1]]; format = "%*.2e"),
        type[4] => _fmt_(_fmt[type[1]]),
        type[5] => _fmt_(_fmt[type[1]]),
        type[6] => "%*i"
    )
    _width = Dict(
        "Label" => 5 * style,
        type[2] => _width_(_width[type[1]], 11, style),
        type[3] => _width_(_width[type[1]], 8, style),
        type[4] => _width_(_width[type[1]], 8, style),
        type[5] => _width_(_width[type[1]], 8, style),
        type[6] => _width_(_width[type[1]], 6, style),
    )
    _show = OrderedDict(
        "Label" => device,
        type[2] => _show_(_show[type[1]], device),
        type[3] => _show_(_show[type[1]], device),
        type[4] => _show_(_show[type[1]], estimate),
        type[5] => _show_(_show[type[1]], estimate),
        type[6] => _show_(_show[type[1]], device)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    minval = [0; Inf; Inf; Inf; Inf; 0]
    maxval = [0; -Inf; -Inf; -Inf; -Inf; 0]

    return fmt, width, show, subheading, unit, type, minval, maxval
end

function headingDevice(width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, type::Array{String, 1})
    heading = OrderedDict(
        "Label" => _blank_(width, show, "Label"),
        type[1] => _blank_(width, show, style, type[1], type[2], type[3], type[4], type[5], type[6]),
    )

    return heading
end

function formatDevice(meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, label::String, width::Dict{String, Int64},
    show::OrderedDict{String, Bool}, minval::Array{Float64,1}, maxval::Array{Float64,1}, indexBusBranch::Int64, idxDevice::Int64,
    type::Array{String, 1})

    fmax(width, show, label, "Label")

    if show[type[2]]
        minval[2] = min(meter.mean[idxDevice] * scale, minval[2])
        maxval[2] = max(meter.mean[idxDevice] * scale, maxval[2])
    end

    if show[type[3]]
        minval[3] = min(meter.variance[idxDevice] * scale, minval[3])
        maxval[3] = max(meter.variance[idxDevice] * scale, maxval[3])
    end

    if show[type[4]]
        minval[4] = min(estimate[indexBusBranch] * scale, minval[4])
        maxval[4] = max(estimate[indexBusBranch] * scale, maxval[4])
    end

    if show[type[5]] && meter.status[idxDevice] == 1
        minval[5] = min((meter.mean[idxDevice] - estimate[indexBusBranch]) * scale, minval[5])
        maxval[5] = max((meter.mean[idxDevice] - estimate[indexBusBranch]) * scale, maxval[5])
    end
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::OrderedDict{String, Bool},
    minval::Array{Float64,1}, maxval::Array{Float64,1})

    for (i, key) in enumerate(keys(show))
        if show[key]
            width[key] = max(textwidth(format(Format(fmt[key]), 0, minval[i])), textwidth(format(Format(fmt[key]), 0, maxval[i])), width[key])
        end
    end
end

function printDevice(io::IO, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, pfmt::Dict{String, Format},
    hfmt::Dict{String, Format}, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, idxBusBranch::Int64, idxDevice::Int64, type::Array{String,1})

    printf(io, pfmt, width, show, idxDevice, scale, meter.mean, type[2])
    printf(io, pfmt, width, show, idxDevice, scale, meter.variance, type[3])
    printf(io, pfmt, width, show, idxBusBranch, scale, estimate, type[4])

    if meter.status[idxDevice] == 1
        printf(io, pfmt, width, show, idxBusBranch, idxDevice, scale, meter.mean, estimate, type[5])
    else
        printf(io, hfmt, width, show, "", type[5])
    end

    printf(io, pfmt, width, show, idxDevice, meter.status, type[6])
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

function mergeDict(fmt::Dict{String, String}, fmt1::Dict{String, String}, width::Dict{String, Int64}, width1::Dict{String, Int64},
    show::OrderedDict{String, Bool}, show1::OrderedDict{String, Bool}, subheader::Dict{String, String}, subheader1::Dict{String, String},
    unit::Dict{String, String}, unit1::Dict{String, String})

    merge!(fmt, fmt1)
    merge!(width, width1)
    merge!(show, show1)
    merge!(subheader, subheader1)
    merge!(unit, unit1)

    return fmt, width, show, subheader, unit
end