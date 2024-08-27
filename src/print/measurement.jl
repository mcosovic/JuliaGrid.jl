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

    _printVoltmeterData(system, device, voltage, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printVoltmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true, title::B = missing, header::B = missing,
    footer::B = missing, repeat::Int64 = device.voltmeter.number + 1)

    _printVoltmeterData(system, device, analysis.voltage, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function _printVoltmeterData(system::PowerSystem, device::Measurement, voltage::Polar, io::IO, label::L, prefix::PrefixLive,
    title::B, header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Voltage Magnitude"
    voltmeter = device.voltmeter

    labels, title, header, footer = formPrint(label, voltmeter, voltmeter.label, title, header, footer, "voltmeter")
    fmt, width, show, heading, subheading, unit, printing = formatVoltmeterData(system, voltmeter, voltage, label, prefix, fmt, width, show, unitList, style, title, type)

    if !isempty(voltmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Voltmeter Data")

        scale = 1.0
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            indexBus = voltmeter.layout.index[i]
            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end

            printf(io, pfmt, show, width, label, "Label")
            printDevice(io, pfmt, hfmt, width, show, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, type)

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, title::Bool, type::String)

    device = !isempty(voltmeter.label)
    state = !isempty(voltage.magnitude)

    fmt, width, show, subheading, unit, minval, maxval = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, device, state, style, type)
    if device
        labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

        if style
            scale = 1.0
            @inbounds for (label, i) in labels
                indexBus = voltmeter.layout.index[i]

                if prefix.voltageMagnitude != 0.0
                    scale = scaleVoltage(system.base.voltage, prefix, indexBus)
                end

                formatDevice(fmt, width, show, minval, maxval, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, style, title, "Voltmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, printing
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

    _printAmmeterData(system, device, current, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printAmmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.ammeter.number + 1)

    _printAmmeterData(system, device, analysis.current, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function _printAmmeterData(system::PowerSystem, device::Measurement, current::ACCurrent, io::IO, label::L, prefix::PrefixLive, title::B,
    header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Current Magnitude"
    ammeter = device.ammeter

    labels, title, header, footer = formPrint(label, ammeter, ammeter.label, title, header, footer, "ammeter")
    fmt, width, show, heading, subheading, unit, printing  = formatAmmeterData(system, ammeter, current, label, prefix, fmt, width, show, unitList, style, title, type)

    if !isempty(ammeter.label) && printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Ammeter Data")
        scale = 1.0
        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            indexBranch = ammeter.layout.index[i]
            if prefix.currentMagnitude != 0.0
                if ammeter.layout.from[i]
                    scale = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                else
                    scale = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                end
            end

            printf(io, pfmt, show, width, label, "Label")

            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, pfmt, hfmt, width, show, ammeter.magnitude, estimate, scale, i, indexBranch, type)

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, title::Bool, type::String)

    device = !isempty(ammeter.label)
    state = !isempty(current.from.magnitude)

    fmt, width, show, subheading, unit, minval, maxval = formatDevice(fmt, width, show, unitList.currentMagnitudeLive, device, state, style, type)

    if device
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
                formatDevice(fmt, width, show, minval, maxval, label, ammeter.magnitude, estimate, scale, i, indexBranch, type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, style, title, "Ammeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, printing
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

    _printWattmeterData(system, device, power, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printWattmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.wattmeter.number + 1)

    _printWattmeterData(system, device, analysis.power, io, label, prefix, title, header, footer, repeat,fmt, width, show, delimiter, style)
end

function _printWattmeterData(system::PowerSystem, device::Measurement, power::Union{ACPower, DCPower}, io::IO, label::L, prefix::PrefixLive, title::B,
    header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Active Power"
    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, wattmeter, wattmeter.label, title, header, footer, "wattmeter")
    fmt, width, show, heading, subheading, unit, printing = formatWattmeterData(wattmeter, power, scale, label, fmt, width, show, unitList, style, title, type)

    if !isempty(wattmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Wattmeter Data")

        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, pfmt, hfmt, width, show, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], type)

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatWattmeterData(wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, title::Bool, type::String)

    device = !isempty(wattmeter.label)
    state = !isempty(power.injection.active)

    fmt, width, show, subheading, unit, minval, maxval = formatDevice(fmt, width, show, unitList.activePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
                formatDevice(fmt, width, show, minval, maxval, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, style, title, "Wattmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, printing
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

    _printVarmeterData(system, device, power, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printVarmeterData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.varmeter.number + 1)

    _printVarmeterData(system, device, analysis.power, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function _printVarmeterData(system::PowerSystem, device::Measurement, power::ACPower, io::IO, label::L, prefix::PrefixLive, title::B,
    header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Reactive Power"
    varmeter = device.varmeter

    scale = printScale(system, prefix)
    labels, title, header, footer = formPrint(label, varmeter, varmeter.label, title, header, footer, "varmeter")
    fmt, width, show, heading, subheading, unit, printing = formatVarmeterData(varmeter, power, scale, label, fmt, width, show, unitList, style, title, type)

    if !isempty(varmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

        printTitle(io, maxLine, delimiter, title, header, style, "Varmeter Data")

        @inbounds for (label, i) in labels
            printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, i)

            printf(io, pfmt, show, width, label, "Label")

            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, pfmt, hfmt, width, show, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], type)

            @printf io "\n"
        end
        printf(io, delimiter, maxLine, style, footer)
    end
end

function formatVarmeterData(varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, title::Bool, type::String)

    device = !isempty(varmeter.label)
    state = !isempty(power.injection.reactive)

    fmt, width, show, subheading, unit, minval, maxval = formatDevice(fmt, width, show, unitList.reactivePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
                formatDevice(fmt, width, show, minval, maxval, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], type)
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, style, title, "Varmeter Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, printing
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

    _printPmuData(system, device, voltage, current, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::Union{PMUStateEstimation, ACStateEstimation}, io::IO = stdout;
    label::L = missing, fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.pmu.number + 1)

    _printPmuData(system, device, analysis.voltage, analysis.current, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function printPmuData(system::PowerSystem, device::Measurement, analysis::DCStateEstimation, io::IO = stdout; label::L = missing,
    fmt::Dict{String, String} = Dict{String, String}(), width::Dict{String, Int64} = Dict{String, Int64}(),
    show::Dict{String, Bool} = Dict{String, Bool}(), delimiter::String = "|", style::Bool = true,
    title::B = missing, header::B = missing, footer::B = missing, repeat::Int64 = device.pmu.number + 1)

    _printPmuData(system, device, analysis.voltage, io, label, prefix, title, header, footer, repeat, fmt, width, show, delimiter, style)
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::Polar, current::ACCurrent, io::IO, label::L, prefix::PrefixLive, title::B,
    header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    pmu = device.pmu
    if !isempty(pmu.label)
        scale = printScale(system, prefix)
        labels, title, header, footer = formPrint(label, pmu, pmu.label, title, header, footer, "pmu")
        fmtV, fmtI, widthV, widthI, showV, showI, headingV, headingI, subheadingV, subheadingI, unitV, unitI, printingV, printingI = formatPmuData(system, pmu, voltage, current, scale, label, prefix, fmt, width, show, unitList, title, style)

        if printingV
            maxLine, pfmt, hfmt = setupPrint(fmtV, widthV, showV, delimiter, style)

            printTitle(io, maxLine, delimiter, title, header, style, "PMU Data")

            scaleV = 1.0
            cnt = 1
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    printingV = printHeader(io, hfmt, widthV, showV, headingV, subheadingV, unitV, delimiter, header, style, repeat, printingV, maxLine, cnt)

                    indexBus = pmu.layout.index[i]
                    if prefix.voltageMagnitude != 0.0
                        scaleV = scaleVoltage(system.base.voltage, prefix, indexBus)
                    end

                    printf(io, pfmt, showV, widthV, label, "Label")

                    printDevice(io, pfmt, hfmt, widthV, showV, pmu.magnitude, voltage.magnitude, scaleV, i, indexBus, "Voltage Magnitude")
                    printDevice(io, pfmt, hfmt, widthV, showV, pmu.angle, voltage.angle, scale["θ"], i, indexBus, "Voltage Angle")

                    @printf io "\n"

                    cnt += 1
                end
            end
            printf(io, delimiter, maxLine, style, footer)
        end

        if printingI
            maxLine, pfmt, hfmt = setupPrint(fmtI, widthI, showI, delimiter, style)

            printTitle(io, maxLine, delimiter, title, header, style, "PMU Data")

            scaleI = 1.0
            cnt = 1
            @inbounds for (label, i) in labels
                if !pmu.layout.bus[i]
                    printingI = printHeader(io, hfmt, widthI, showI, headingI, subheadingI, unitI, delimiter, header, style, repeat, printingI, maxLine, cnt)

                    indexBranch = pmu.layout.index[i]
                    if prefix.currentMagnitude != 0.0
                        if pmu.layout.from[i]
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBranch])
                        else
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBranch])
                        end
                    end

                    printf(io, pfmt, showI, widthI, label, "Label")

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    printDevice(io, pfmt, hfmt, widthI, showI, pmu.magnitude, estimate, scaleI, i, indexBranch, "Current Magnitude")

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    printDevice(io, pfmt, hfmt, widthI, showI, pmu.angle, estimate, scale["ψ"], i, indexBranch, "Current Angle")

                    @printf io "\n"

                    cnt += 1
                end
            end
            printf(io, delimiter, maxLine, style, footer)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L,
    prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, title::Bool, style::Bool)

    deviceV = any(pmu.layout.bus)
    stateV = !isempty(voltage.magnitude) & deviceV
    deviceI = any(pmu.layout.from) || any(pmu.layout.to)
    stateI = !isempty(current.from.magnitude) & deviceI

    fmtV, widthV, showV, subheadingV, unitV, minV, maxV = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, deviceV, stateV, style, "Voltage Magnitude")
    fmtθ, widthθ, showθ, subheadingθ, unitθ, minθ, maxθ = formatDevice(fmt, width, show, unitList.voltageAngleLive, deviceV, stateV, style, "Voltage Angle")
    fmtV, widthV, showV, subheadingV, unitV = mergeDict(fmtV, fmtθ, widthV, widthθ, showV, showθ, subheadingV, subheadingθ, unitV, unitθ)

    fmtI, widthI, showI, subheadingI, unitI, minI, maxI = formatDevice(fmt, width, show, unitList.currentMagnitudeLive, deviceI, stateI, style, "Current Magnitude")
    fmtψ, widthψ, showψ, subheadingψ, unitψ, minψ, maxψ = formatDevice(fmt, width, show, unitList.currentAngleLive, deviceI, stateI, style, "Current Angle")
    fmtI, widthI, showI, subheadingI, unitI = mergeDict(fmtI, fmtψ, widthI, widthψ, showI, showψ, subheadingI, subheadingψ, unitI, unitψ)

    if !isempty(pmu.label)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")

        if style
            scaleV = 1.0
            scaleI = 1.0
            @inbounds for (label, i) in labels
                indexBusBranch = pmu.layout.index[i]

                if pmu.layout.bus[i]
                    if prefix.voltageMagnitude != 0.0
                        scaleV = scaleVoltage(system.base.voltage, prefix, indexBusBranch)
                    end

                    formatDevice(fmtV, widthV, showV, minV, maxV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBusBranch, "Voltage Magnitude")
                    formatDevice(fmtV, widthV, showV, minθ, maxθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBusBranch, "Voltage Angle")
                else
                    if prefix.currentMagnitude != 0.0
                        if pmu.layout.from[i]
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBusBranch])
                        else
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBusBranch])
                        end
                    end

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    formatDevice(fmtI, widthI, showI, minI, maxI, label, pmu.magnitude, estimate, scaleI, i, indexBusBranch, "Current Magnitude")

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    formatDevice(fmtI, widthI, showI, minψ, maxψ, label, pmu.angle, estimate, scale["ψ"], i, indexBusBranch, "Current Angle")
                end
            end
            formatDevice(fmtV, widthV, showV, [minV; minθ[2:end]], [maxV; maxθ[2:end]])
            formatDevice(fmtI, widthI, showI, [minI; minψ[2:end]], [minI; maxψ[2:end]])
        end
    end
    printingV = howManyPrint(widthV, showV, style, title, "PMU Data")
    printingI = howManyPrint(widthI, showI, style, title, "PMU Data")

    headingV = headingDevice(widthV, showV, style, "Voltage Magnitude")
    headingθ = headingDevice(widthV, showV, style, "Voltage Angle")
    headingV["Voltage Angle"] = headingθ["Voltage Angle"]

    headingI = headingDevice(widthI, showI, style, "Current Magnitude")
    headingψ = headingDevice(widthψ, showψ, style, "Current Angle")
    headingI["Current Angle"] = headingψ["Current Angle"]

    return fmtV, fmtI, widthV, widthI, showV, showI, headingV, headingI, subheadingV, subheadingI, unitV, unitI, printingV, printingI
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO, label::L, prefix::PrefixLive, title::B,
    header::B, footer::B, repeat::Int64, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Voltage Angle"
    pmu = device.pmu

    if !isempty(pmu.label)
        scale = printScale(system, prefix)
        labels, title, header, footer = formPrint(label, pmu, pmu.label, title, header, footer, "pmu")
        fmt, width, show, heading, subheading, unit, printing = formatPmuData(pmu, voltage, scale, label, fmt, width, show, unitList, style, title, type)

        if printing
            maxLine, pfmt, hfmt = setupPrint(fmt, width, show, delimiter, style)

            printTitle(io, maxLine, delimiter, title, header, style, "PMU Data")

            cnt = 1
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    printing = printHeader(io, hfmt, width, show, heading, subheading, unit, delimiter, header, style, repeat, printing, maxLine, cnt)

                    indexBus = pmu.layout.index[i]
                    printf(io, pfmt, show, width, label, "Label")
                    printDevice(io, pfmt, hfmt, width, show, pmu.angle, voltage.angle, scale["θ"], i, indexBus, type)

                    @printf io "\n"
                    cnt += 1
                end
            end
            printf(io, delimiter, maxLine, style, footer)
        end
    end
end

function formatPmuData(pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L, fmt::Dict{String, String},
    width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, title::Bool, type::String)

    device = any(pmu.layout.bus)
    state = !isempty(voltage.angle) && device

    fmt, width, show, subheading, unit, minval, maxval = formatDevice(fmt, width, show, unitList.voltageAngleLive, device, state, style, type)
    if !isempty(pmu.label)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")

        if style
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    formatDevice(fmt, width, show, minval, maxval, label, pmu.angle, voltage.angle, scale["θ"], i, pmu.layout.index[i], type)
                end
            end
            formatDevice(fmt, width, show, minval, maxval)
        end
    end
    printing = howManyPrint(width, show, style, title, "PMU Data")
    heading = headingDevice(width, show, style, type)

    return fmt, width, show, heading, subheading, unit, printing
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    unitMeter::String, device::Bool, estimate::Bool, style::Bool, type::String)

    _show = OrderedDict("$type" => true)
    _fmt, _width = fmtwidth(_show)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheading = Dict(
        "Label"             => _header_("", "Label", style),
        "$type Measurement" => _header_("Measurement", "$type Measurement Mean", style),
        "$type Variance"    => _header_("Variance", "$type Variance", style),
        "$type Estimate"    => _header_("Estimate", "$type Estimate", style),
        "$type Residual"    => _header_("Residual", "$type Residual", style),
        "$type Status"      => _header_("Status", "Status", style)
    )
    unit = Dict(
        "Label"             => "",
        "$type Measurement" => "[$unitMeter]",
        "$type Variance"    => "[$unitMeter]",
        "$type Estimate"    => "[$unitMeter]",
        "$type Residual"    => "[$unitMeter]",
        "$type Status"      => ""
    )
    _fmt = Dict(
        "Label"             => "%-*s",
        "$type Measurement" => _fmt_(_fmt["$type"]),
        "$type Variance"    => _fmt_(_fmt["$type"]; format = "%*.2e"),
        "$type Estimate"    => _fmt_(_fmt["$type"]),
        "$type Residual"    => _fmt_(_fmt["$type"]),
        "$type Status"      => "%*i"
    )
    _width = Dict(
        "Label"             => 5 * style,
        "$type Measurement" => _width_(_width["$type"], 11, style),
        "$type Variance"    => _width_(_width["$type"], 8, style),
        "$type Estimate"    => _width_(_width["$type"], 8, style),
        "$type Residual"    => _width_(_width["$type"], 8, style),
        "$type Status"      => _width_(_width["$type"], 6, style),
    )
    _show = OrderedDict(
        "Label"             => device,
        "$type Measurement" => _show_(_show["$type"], device),
        "$type Variance"    => _show_(_show["$type"], device),
        "$type Estimate"    => _show_(_show["$type"], estimate),
        "$type Residual"    => _show_(_show["$type"], estimate),
        "$type Status"      => _show_(_show["$type"], device)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    minval = [0; Inf; Inf; Inf; Inf; 0]
    maxval = [0; -Inf; -Inf; -Inf; -Inf; 0]

    return fmt, width, show, subheading, unit, minval, maxval
end

function headingDevice(width::Dict{String, Int64}, show::OrderedDict{String, Bool}, style::Bool, type::String)
    heading = OrderedDict(
        "Label" => _blank_(width, show, "Label"),
        type    => _blank_(width, show, style, type, "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status"),
    )

    return heading
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, minval::Array{Float64,1}, maxval::Array{Float64,1},
    label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64, type::String)

    fmax(fmt, width, show, label, "Label")

    if show["$type Measurement"]
        minval[2] = min(meter.mean[i] * scale, minval[2])
        maxval[2] = max(meter.mean[i] * scale, maxval[2])
    end

    if show["$type Variance"]
        minval[3] = min(meter.variance[i] * scale, minval[3])
        maxval[3] = max(meter.variance[i] * scale, maxval[3])
    end

    if show["$type Estimate"]
        minval[4] = min(estimate[j] * scale, minval[4])
        maxval[4] = max(estimate[j] * scale, maxval[4])
    end

    if show["$type Residual"] && meter.status[i] == 1
        minval[5] = min((meter.mean[i] - estimate[j]) * scale, minval[5])
        maxval[5] = max((meter.mean[i] - estimate[j]) * scale, maxval[5])
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

function printDevice(io::IO, pfmt::Dict{String, Format}, hfmt::Dict{String, Format}, width::Dict{String, Int64},
    show::OrderedDict{String, Bool}, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64,
    i::Int64, j::Int64, type::String)

    printf(io, pfmt, show, width, meter.mean, i, scale, "$type Measurement")
    printf(io, pfmt, show, width, meter.variance, i, scale, "$type Variance")
    printf(io, pfmt, show, width, estimate, j, scale, "$type Estimate")

    if meter.status[i] == 1
        printf(io, pfmt, show, width, meter.mean, estimate, i, j, scale, "$type Residual")
    else
        printf(io, hfmt, show, width, "", "$type Residual")
    end

    printf(io, pfmt, show, width, meter.status, i, "$type Status")
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