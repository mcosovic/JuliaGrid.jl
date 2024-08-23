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
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printVoltmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific voltmeters
width = Dict("Voltage Magnitude Estimate" => 11)
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

    type = "Voltage Magnitude"
    voltmeter = device.voltmeter

    fmt, width, show, subheader, unit, empty, printing = formatVoltmeterData(system, voltmeter, voltage, label, prefix, fmt, width, show, unitList, style, type)

    if !isempty(voltmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, voltmeter, voltmeter.label, header, footer, "voltmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Voltmeter Data")
            end
            headerDevice(io, width, show, subheader, unit, hfmt, delimiter, style, type)
        end

        scale = 1.0
        @inbounds for (label, i) in labels
            indexBus = voltmeter.layout.index[i]

            if prefix.voltageMagnitude != 0.0
                scale = scaleVoltage(system.base.voltage, prefix, indexBus)
            end
            printf(io, pfmt, show, width, label, "Label")
            printDevice(io, pfmt, hfmt, width, show, empty, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, type)
            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatVoltmeterData(system::PowerSystem, voltmeter::Voltmeter, voltage::Polar, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, type::String)

    device = !isempty(voltmeter.label)
    state = !isempty(voltmeter.magnitude.mean)

    fmt, width, show, subheader, unit, empty, minval, maxval = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, device, state, style, type)
    if device
        labels = toggleLabel(label, voltmeter, voltmeter.label, "voltmeter")

        if style
            scale = 1.0
            @inbounds for (label, i) in labels
                indexBus = voltmeter.layout.index[i]

                if prefix.voltageMagnitude != 0.0
                    scale = scaleVoltage(system.base.voltage, prefix, indexBus)
                end

                formatDevice(width, show, minval, maxval, label, voltmeter.magnitude, voltage.magnitude, scale, i, indexBus, type)
            end
            formatDevice(fmt, width, show, minval, maxval, type)
        end
    end
    printing = howManyPrint(width, show, style, "Voltmeter Data")

    return fmt, width, show, subheader, unit, empty, printing
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
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printAmmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific ammeters
width = Dict("Current Magnitude" => 10)
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

    type = "Current Magnitude"
    ammeter = device.ammeter

    fmt, width, show, subheader, unit, empty, printing = formatAmmeterData(system, ammeter, current, label, prefix, fmt, width, show, unitList, style, type)

    if !isempty(ammeter.label) && printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, ammeter, ammeter.label, header, footer, "ammeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Ammeter Data")
            end
            headerDevice(io, width, show, subheader, unit, hfmt, delimiter, style, type)
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

            printf(io, pfmt, show, width, label, "Label")
            estimate = findEstimate(ammeter, current.from.magnitude, current.to.magnitude, i)
            printDevice(io, pfmt, hfmt, width, show, empty, ammeter.magnitude, estimate, scale, i, indexBranch, type)
            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatAmmeterData(system::PowerSystem, ammeter::Ammeter, current::ACCurrent, label::L, prefix::PrefixLive,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, type::String)

    device = !isempty(ammeter.label)
    state = !isempty(current.from.magnitude)

    fmt, width, show, subheader, unit, empty, minval, maxval = formatDevice(fmt, width, show, unitList.currentMagnitudeLive, device, state, style, type)

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
                formatDevice(width, show, minval, maxval, label, ammeter.magnitude, estimate, scale, i, indexBranch, type)
            end
            formatDevice(fmt, width, show, minval, maxval, type)
        end
    end

    printing = howManyPrint(width, show, style, "Ammeter Data")

    return fmt, width, show, subheader, unit, empty, printing
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
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printWattmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific wattmeters
width = Dict("Active Power Residual" => 11)
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

    type = "Active Power"
    wattmeter = device.wattmeter

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, empty, printing = formatWattmeterData(wattmeter, power, scale, label, fmt, width, show, unitList, style, type)

    if !isempty(wattmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, wattmeter, wattmeter.label, header, footer, "wattmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Wattmeter Data")
            end
            headerDevice(io, width, show, subheader, unit, hfmt, delimiter, style, type)
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")
            estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
            printDevice(io, pfmt, hfmt, width, show, empty, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], type)
            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatWattmeterData(wattmeter::Wattmeter, power::Union{ACPower, DCPower}, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, type::String)

    device = !isempty(wattmeter.label)
    state = !isempty(power.injection.active)

    fmt, width, show, subheader, unit, empty, minval, maxval = formatDevice(fmt, width, show, unitList.activePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(label, wattmeter, wattmeter.label, "wattmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(wattmeter, power.injection.active, power.from.active, power.to.active, i)
                formatDevice(width, show, minval, maxval, label, wattmeter.active, estimate, scale["P"], i, wattmeter.layout.index[i], type)
            end
            formatDevice(fmt, width, show, minval, maxval, type)
        end
    end

    printing = howManyPrint(width, show, style, "Wattmeter Data")

    return fmt, width, show, subheader, unit, empty, printing
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
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printVarmeterData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific wattmeters
width = Dict("Reactive Power Residual" => 11)
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

    type = "Reactive Power"
    varmeter = device.varmeter

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, empty, printing = formatVarmeterData(varmeter, power, scale, label, fmt, width, show, unitList, style, type)

    if !isempty(varmeter.label) && printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, varmeter, varmeter.label, header, footer, "varmeter")

        if header
            if style
                printTitle(io, maxLine, delimiter, "Varmeter Data")
            end
            headerDevice(io, width, show, subheader, unit, hfmt, delimiter, style, type)
        end

        @inbounds for (label, i) in labels
            printf(io, pfmt, show, width, label, "Label")
            estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
            printDevice(io, pfmt, hfmt, width, show, empty, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], type)
            @printf io "\n"
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatVarmeterData(varmeter::Varmeter, power::ACPower, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String,Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, type::String)

    device = !isempty(varmeter.label)
    state = !isempty(power.injection.reactive)

    fmt, width, show, subheader, unit, empty, minval, maxval = formatDevice(fmt, width, show, unitList.reactivePowerLive, device, state, style, type)
    if device
        labels = toggleLabel(label, varmeter, varmeter.label, "varmeter")

        if style
            @inbounds for (label, i) in labels
                estimate = findEstimate(varmeter, power.injection.reactive, power.from.reactive, power.to.reactive, i)
                formatDevice(width, show, minval, maxval, label, varmeter.reactive, estimate, scale["Q"], i, varmeter.layout.index[i], type)
            end
            formatDevice(fmt, width, show, minval, maxval, type)
        end
    end

    printing = howManyPrint(width, show, style, "Varmeter Data")

    return fmt, width, show, subheader, unit, empty, printing
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
* `fmt`: Specifies the preferred numeric formats or alignments for the columns.
* `width`: Specifies the preferred widths for the columns.
* `show`: Toggles the printing of the columns.
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
printPmuData(system, device, analysis; fmt, show, delimiter = " ")

# Print data for specific PMUs
width = Dict("Current Magnitude" => 10, "Current Angle Status" => 8)
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
    fmtV, fmtI, widthV, widthI, showV, showI, unitV, unitI, subheaderV, subheaderI, emptyV, emptyI, printingV, printingI = formatPmuData(system, pmu, voltage, current, scale, label, prefix, fmt, width, show, unitList, style)

    if !isempty(pmu.label)
        labels, header, footer = toggleLabelHeader(label, pmu, pmu.label, header, footer, "pmu")
        if printingV
            maxLine, pfmt, hfmt = setupPrintSystem(fmtV, widthV, showV, delimiter, style)

            if header
                if style
                    printTitle(io, maxLine, delimiter, "PMU Data")
                end
                headerDevice(io, widthV, showV, subheaderV, unitV, hfmt, delimiter, style, "Voltage Magnitude"; angle = "Voltage Angle")
            end

            scaleV = 1.0
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    indexBus = pmu.layout.index[i]

                    if prefix.voltageMagnitude != 0.0
                        scaleV = scaleVoltage(system.base.voltage, prefix, indexBus)
                    end
                    printf(io, pfmt, showV, widthV, label, "Label")
                    printDevice(io, pfmt, hfmt, widthV, showV, emptyV, pmu.magnitude, voltage.magnitude, scaleV, i, indexBus, "Voltage Magnitude")
                    printDevice(io, pfmt, hfmt, widthV, showV, emptyV, pmu.angle, voltage.angle, scale["θ"], i, indexBus, "Voltage Angle")
                    @printf io "\n"
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end

        if printingI
            maxLine, pfmt, hfmt = setupPrintSystem(fmtI, widthI, showI, delimiter, style)

            if header
                if style
                    printTitle(io, maxLine, delimiter, "PMU Data")
                end
                headerDevice(io, widthI, showI, subheaderI, unitI, hfmt, delimiter, style, "Current Magnitude"; angle = "Current Angle")
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

                    printf(io, pfmt, showI, widthI, label, "Label")

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    printDevice(io, pfmt, hfmt, widthI, showI, emptyI, pmu.magnitude, estimate, scaleI, i, indexBranch, "Current Magnitude")
                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    printDevice(io, pfmt, hfmt, widthI, showI, emptyI, pmu.angle, estimate, scale["ψ"], i, indexBranch, "Current Angle")

                    @printf io "\n"
                end
            end
            printf(io, delimiter, footer, style, maxLine)
        end
    end
end

function formatPmuData(system::PowerSystem, pmu::PMU, voltage::Polar, current::ACCurrent, scale::Dict{String, Float64}, label::L,
    prefix::PrefixLive, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool)

    deviceV = any(pmu.layout.bus)
    stateV = !isempty(voltage.magnitude)
    deviceI = any(pmu.layout.from) || any(pmu.layout.to)
    stateI = !isempty(current.from.magnitude)

    fmtV, widthV, showV, subheaderV, unitV, emptyV, minV, maxV = formatDevice(fmt, width, show, unitList.voltageMagnitudeLive, deviceV, stateV, style, "Voltage Magnitude")
    fmtθ, widthθ, showθ, subheaderθ, unitθ, emptyθ, minθ, maxθ = formatDevice(fmt, width, show, unitList.voltageAngleLive, deviceV, stateV, style, "Voltage Angle")
    fmtV, widthV, showV, subheaderV, unitV, emptyV = mergeDict(fmtV, fmtθ, widthV, widthθ, showV, showθ, subheaderV, subheaderθ, unitV, unitθ, emptyV, emptyθ)

    fmtI, widthI, showI, subheaderI, unitI, emptyI, minI, maxI = formatDevice(fmt, width, show, unitList.currentMagnitudeLive, deviceI, stateI, style, "Current Magnitude")
    fmtψ, widthψ, showψ, subheaderψ, unitψ, emptyψ, minψ, maxψ = formatDevice(fmt, width, show, unitList.currentAngleLive, deviceI, stateI, style, "Current Angle")
    fmtI, widthI, showI, subheaderI, unitI, emptyI = mergeDict(fmtI, fmtψ, widthI, widthψ, showI, showψ, subheaderI, subheaderψ, unitI, unitψ, emptyI, emptyψ)

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

                    formatDevice(widthV, showV, minV, maxV, label, pmu.magnitude, voltage.magnitude, scaleV, i, indexBusBranch, "Voltage Magnitude")
                    formatDevice(widthV, showV, minθ, maxθ, label, pmu.angle, voltage.angle, scale["θ"], i, indexBusBranch, "Voltage Angle")
                else
                    if prefix.currentMagnitude != 0.0
                        if pmu.layout.from[i]
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.from[indexBusBranch])
                        else
                            scaleI = scaleCurrent(system, prefix, system.branch.layout.to[indexBusBranch])
                        end
                    end

                    estimate = findEstimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    formatDevice(widthI, showI, minI, maxI, label, pmu.magnitude, estimate, scaleI, i, indexBusBranch, "Current Magnitude")

                    estimate = findEstimate(pmu, current.from.angle, current.to.angle, i)
                    formatDevice(widthI, showI, minψ, maxψ, label, pmu.angle, estimate, scale["ψ"], i, indexBusBranch, "Current Magnitude")
                end
            end
        end
    end

    printingV = howManyPrint(widthV, showV, style, "PMU Data")
    printingI = howManyPrint(widthI, showI, style, "PMU Data")

    return fmtV, fmtI, widthV, widthI, showV, showI, unitV, unitI, subheaderV, subheaderI, emptyV, emptyI, printingV, printingI
end

function _printPmuData(system::PowerSystem, device::Measurement, voltage::PolarAngle, io::IO, label::L, prefix::PrefixLive,
    header::B, footer::B, fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, delimiter::String, style::Bool)

    type = "Voltage Angle"
    pmu = device.pmu

    scale = printScale(system, prefix)
    fmt, width, show, subheader, unit, empty, printing = formatPmuData(pmu, voltage, scale, label, fmt, width, show, unitList, style, type)

    if !isempty(pmu.label) && printing
        maxLine, pfmt, hfmt = setupPrintSystem(fmt, width, show, delimiter, style)
        labels, header, footer = toggleLabelHeader(label, pmu, pmu.label, header, footer, "pmu")

        if header
            if style
                printTitle(io, maxLine, delimiter, "PMU Data")
            end
            headerDevice(io, width, show, subheader, unit, hfmt, delimiter, style, type)
        end

        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                indexBus = pmu.layout.index[i]

                printf(io, pfmt, show, width, label, "Label")
                printDevice(io, pfmt, hfmt, width, show, empty, pmu.angle, voltage.angle, scale["θ"], i, indexBus, type)
                @printf io "\n"
            end
        end
        printf(io, delimiter, footer, style, maxLine)
    end
end

function formatPmuData(pmu::PMU, voltage::PolarAngle, scale::Dict{String, Float64}, label::L,
    fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool}, unitList::UnitList, style::Bool, type::String)

    device = any(pmu.layout.bus)
    state = !isempty(voltage.angle)

    fmt, width, show, subheader, unit, empty, minval, maxval = formatDevice(fmt, width, show, unitList.voltageAngleLive, device, state, style, type)
    if !isempty(pmu.label)
        labels = toggleLabel(label, pmu, pmu.label, "pmu")

        if style
            @inbounds for (label, i) in labels
                if pmu.layout.bus[i]
                    formatDevice(width, show, minval, maxval, label, pmu.angle, voltage.angle, scale["θ"], i, pmu.layout.index[i], type)
                end
            end
            formatDevice(fmt, width, show, minval, maxval, type)
        end
    end

    printing = howManyPrint(width, show, style, "PMU Data")

    return fmt, width, show, subheader, unit, empty, printing
end

function formatDevice(fmt::Dict{String, String}, width::Dict{String, Int64}, show::Dict{String, Bool},
    unitMeter::String, device::Bool, estimate::Bool, style::Bool, type::String)

    _fmt = Dict("$type" => "")
    _width = Dict("$type" => 0)
    _show = OrderedDict("$type" => true)
    _fmt, _width, _show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    subheader = Dict(
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
    empty = Dict(
        "Label"             => "",
        "$type Measurement" => "",
        "$type Variance"    => "",
        "$type Estimate"    => "",
        "$type Residual"    => "",
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
        "Label"             => true,
        "$type Measurement" => _show_(_show["$type"], device),
        "$type Variance"    => _show_(_show["$type"], device),
        "$type Estimate"    => _show_(_show["$type"], estimate),
        "$type Residual"    => _show_(_show["$type"], estimate),
        "$type Status"      => _show_(_show["$type"], device)
    )
    fmt, width, show = printFormat(_fmt, fmt, _width, width, _show, show, style)

    minval = [0; Inf; Inf; Inf; Inf; 0]
    maxval = [0; -Inf; -Inf; -Inf; -Inf; 0]

    return fmt, width, show, subheader, unit, empty, minval, maxval
end

function formatDevice(width::Dict{String, Int64}, show::OrderedDict{String, Bool}, minval::Array{Float64,1}, maxval::Array{Float64,1},
    label::String, meter::GaussMeter, estimate::Array{Float64,1}, scale::Float64, i::Int64, j::Int64, type::String)

    width["Label"] = max(textwidth(label), width["Label"])

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
    minval::Array{Float64,1}, maxval::Array{Float64,1}, type::String)
    for (i, key) in enumerate(keys(show))
        if show[key]
            width[key] = max(textwidth(format(Format(fmt[key]), 0, minval[i])), textwidth(format(Format(fmt[key]), 0, maxval[i])), width[key])
        end
    end

    titlemax(width, show, "$type", "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status")
end

function headerDevice(io::IO, width::Dict{String, Int64}, show::OrderedDict{String, Bool}, subheader::Dict{String, String},
    unit::Dict{String, String}, hfmt::Dict{String, Format}, delimiter::String, style::Bool, type::String; angle::String = "")
    if style
        print(io, delimiter)
        widthLab = printf(io, width, show, delimiter, "Label", "Label")
        widthSet = printf(io, width, show, delimiter, "$type", "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status")
        if !isempty(angle)
            widthSea = printf(io, width, show, delimiter, "$angle", "$angle Measurement", "$angle Variance", "$angle Estimate", "$angle Residual", "$angle Status")
        end
        @printf io "\n"

        print(io, delimiter)
        printf(io, hfmt["Empty"], widthLab)
        printf(io, hfmt["Empty"], widthSet)
        if !isempty(angle)
            printf(io, hfmt["Empty"], widthSea)
        end
        @printf io "\n"
    end

    printf(io, hfmt, width, show, subheader, "Label")
    printf(io, hfmt, width, show, subheader, "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status")
    if !isempty(angle)
        printf(io, hfmt, width, show, subheader, "$angle Measurement", "$angle Variance", "$angle Estimate", "$angle Residual", "$angle Status")
    end
    @printf io "\n"

    printf(io, hfmt, width, show, unit, "Label")
    printf(io, hfmt, width, show, unit, "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status")
    if !isempty(angle)
        printf(io, hfmt, width, show, unit, "$angle Measurement", "$angle Variance", "$angle Estimate", "$angle Residual", "$angle Status")
    end
    @printf io "\n"

    if style
        print(io, delimiter)
        printf(io, hfmt["Break"], width, show, "Label")
        printf(io, hfmt["Break"], width, show, "$type Measurement", "$type Variance", "$type Estimate", "$type Residual", "$type Status")
        if !isempty(angle)
            printf(io, hfmt["Break"], width, show, "$angle Measurement", "$angle Variance", "$angle Estimate", "$angle Residual", "$angle Status")
        end
        @printf io "\n"
    end
end

function printDevice(io::IO, pfmt::Dict{String, Format}, hfmt::Dict{String, Format}, width::Dict{String, Int64},
    show::OrderedDict{String, Bool}, empty::Dict{String, String}, meter::GaussMeter, estimate::Array{Float64,1},
    scale::Float64, i::Int64, j::Int64, type::String)

    printf(io, pfmt, show, width, meter.mean, i, scale, "$type Measurement")
    printf(io, pfmt, show, width, meter.variance, i, scale, "$type Variance")
    printf(io, pfmt, show, width, estimate, j, scale, "$type Estimate")

    if meter.status[i] == 1
        printf(io, pfmt, show, width, meter.mean, estimate, i, j, scale, "$type Residual")
    else
        printf(io, hfmt, width, show, empty, "$type Residual")
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
    unit::Dict{String, String}, unit1::Dict{String, String}, empty::Dict{String, String}, empty1::Dict{String, String})

    merge!(fmt, fmt1)
    merge!(width, width1)
    merge!(show, show1)
    merge!(subheader, subheader1)
    merge!(unit, unit1)
    merge!(empty, empty1)

    return fmt, width, show, subheader, unit, empty
end

function isPmuData(show::OrderedDict{String, Bool}, flag::Bool)
    if flag
        for key in keys(show)
            show[key] = false
        end
    end
end