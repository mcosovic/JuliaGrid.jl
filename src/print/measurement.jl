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
function printVoltmeterData(
    system::PowerSystem,
    device::Measurement,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.voltmeter.number + 1,
    kwargs...
)
    voltage = Polar(Float64[], Float64[])

    printVolt(io, system, device, voltage, unitList, pfx, label, repeat; kwargs...)
end

function printVoltmeterData(
    system::PowerSystem,
    device::Measurement,
    analysis::Union{PMUStateEstimation, ACStateEstimation},
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.voltmeter.number + 1,
    kwargs...
)
    printVolt(io, system, device, analysis.voltage, unitList, pfx, label, repeat; kwargs...)
end

function printVolt(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    voltg::Polar,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    volt = device.voltmeter

    labels = pickLabel(volt, volt.label, label, "voltmeter")
    prt = voltData(system, voltg, volt, unitList, pfx, label, labels, repeat; kwargs...)

    if isempty(volt.label) && ptr.notprint
        return
    end

    title(io, prt, "Voltmeter Data")

    @inbounds for (label, i) in labels
        idxBus = volt.layout.index[i]
        scale = scaleVoltage(pfx, system, idxBus)

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        printDevice(io, volt.magnitude, voltg.magnitude, scale, idxBus, i, prt)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function voltData(
    system::PowerSystem,
    voltg::Polar,
    volt::Voltmeter,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    type = "Voltage Magnitude"
    unitVoltg = unitList.voltageMagnitudeLive
    device = !isempty(volt.label)
    state = !isempty(voltg.magnitude)
    style, delimiter, key = printkwargs(; kwargs...)

    fmt, width, show, subheading, unit, head, minv, maxv = layoutMeter(
        key.fmt, key.width, key.show, unitVoltg, device, state, style, type
    )

    if device && style
        @inbounds for (label, i) in labels
            idxBus = volt.layout.index[i]
            scale = scaleVoltage(pfx, system, idxBus)
            minmaxMeter!(
                volt.magnitude, voltg.magnitude, scale, label,
                width, show, minv, maxv, idxBus, i, head
            )
        end
        widthMeter(fmt, width, show, minv, maxv)
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    notprint = printing!(width, show, title, style, "Voltmeter Data")
    heading = headingMeter(width, show, delimiter, style, head)

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
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
function printAmmeterData(
    system::PowerSystem,
    device::Measurement,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.ammeter.number + 1,
    kwargs...
)
    current = ACCurrent(
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[])
    )
    printAmp(io, system, device, current, unitList, pfx, label, repeat; kwargs...)
end

function printAmmeterData(
    system::PowerSystem,
    device::Measurement,
    analysis::Union{PMUStateEstimation, ACStateEstimation},
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.ammeter.number + 1,
    kwargs...
)
    printAmp(io, system, device, analysis.current, unitList, pfx, label, repeat; kwargs...)
end

function printAmp(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    current::ACCurrent,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    amp = device.ammeter

    labels = pickLabel(amp, amp.label, label, "ammeter")
    prt = ampData(system, amp, current, unitList, pfx, label, labels, repeat; kwargs...)

    if isempty(amp.label) && ptr.notprint
        return
    end

    title(io, prt, "Ammeter Data")

    scale = 1.0
    @inbounds for (label, i) in labels
        idxBrch = amp.layout.index[i]
        scale = scaleIij(system, scale, pfx, amp.layout.from[i], idxBrch)

        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        I = estimate(amp, current.from.magnitude, current.to.magnitude, i)
        printDevice(io, amp.magnitude, I, scale, idxBrch, i, prt)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function ampData(
    system::PowerSystem,
    amp::Ammeter,
    current::ACCurrent,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    type = "Current Magnitude"
    unitAmp = unitList.currentMagnitudeLive
    device = !isempty(amp.label)
    state = !isempty(current.from.magnitude)
    style, delimiter, key = printkwargs(; kwargs...)

    fmt, width, show, subheading, unit, head, minv, maxv = layoutMeter(
        key.fmt, key.width, key.show, unitAmp, device, state, style, type
    )

    if device && style
        scale = 1.0
        @inbounds for (label, i) in labels
            idxBrch = amp.layout.index[i]
            scale = scaleIij(system, scale, pfx, amp.layout.from[i], idxBrch)

            I = estimate(amp, current.from.magnitude, current.to.magnitude, i)
            minmaxMeter!(
                amp.magnitude, I, scale, label, width, show, minv, maxv, idxBrch, i, head
            )
        end
        widthMeter(fmt, width, show, minv, maxv)
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    notprint = printing!(width, show, title, style, "Ammeter Data")
    heading = headingMeter(width, show, delimiter, style, head)

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
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
function printWattmeterData(
    system::PowerSystem,
    device::Measurement,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.wattmeter.number + 1,
    kwargs...
)
    power = ACPower(
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[])
    )
    printWatt(io, system, device, power, unitList, pfx, label, repeat; kwargs...)
end

function printWattmeterData(
    system::PowerSystem,
    device::Measurement,
    analysis::Union{PMUStateEstimation, ACStateEstimation, DCStateEstimation},
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.wattmeter.number + 1,
    kwargs...
)
    printWatt(io, system, device, analysis.power, unitList, pfx, label, repeat; kwargs...)
end

function printWatt(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    pwr::Union{ACPower, DCPower},
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    watt = device.wattmeter
    scale = scalePrint(system, pfx)

    labels = pickLabel(watt, watt.label, label, "wattmeter")
    prt = wattData(watt, pwr, unitList, scale, label, labels, repeat; kwargs...)

    if isempty(watt.label) && prt.notprint
        return
    end

    title(io, prt, "Wattmeter Data")

    @inbounds for (label, i) in labels
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        P = estimate(watt, pwr.injection.active, pwr.from.active, pwr.to.active, i)
        printDevice(io, watt.active, P, scale[:P], watt.layout.index[i], i, prt)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function wattData(
    watt::Wattmeter,
    pwr::Union{ACPower, DCPower},
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    type = "Active Power"
    unitP = unitList.activePowerLive
    device = !isempty(watt.label)
    state = !isempty(pwr.injection.active)
    style, delimiter, key = printkwargs(; kwargs...)

    fmt, width, show, subheading, unit, head, minv, maxv = layoutMeter(
        key.fmt, key.width, key.show, unitP, device, state, style, type
    )

    if device && style
        @inbounds for (label, i) in labels
            P = estimate(watt, pwr.injection.active, pwr.from.active, pwr.to.active, i)
            idx = watt.layout.index[i]
            minmaxMeter!(
                watt.active, P, scale[:P], label, width, show, minv, maxv, idx, i, head
            )
        end
        widthMeter(fmt, width, show, minv, maxv)
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    notprint = printing!(width, show, title, style, "Wattmeter Data")
    heading = headingMeter(width, show, delimiter, style, head)

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
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
function printVarmeterData(
    system::PowerSystem,
    device::Measurement,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.varmeter.number + 1,
    kwargs...
)
    power = ACPower(
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[]),
        Cartesian(Float64[], Float64[])
    )

    printVar(io, system, device, power, unitList, pfx, label, repeat; kwargs...)
end

function printVarmeterData(
    system::PowerSystem,
    device::Measurement,
    analysis::Union{PMUStateEstimation, ACStateEstimation},
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.varmeter.number + 1,
    kwargs...
)
    printVar(io, system, device, analysis.power, unitList, pfx, label, repeat; kwargs...)
end

function printVar(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    pwr::ACPower,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64 = device.varmeter.number + 1;
    kwargs...
)
    var = device.varmeter
    scale = scalePrint(system, pfx)

    labels = pickLabel(var, var.label, label, "varmeter")
    prt = varData(var, pwr, unitList, scale, label, labels, repeat; kwargs...)

    if isempty(var.label) && prt.notprint
        return
    end

    title(io, prt, "Varmeter Data")

    @inbounds for (label, i) in labels
        header(io, prt)
        printf(io, prt.pfmt, prt, label, :labl)

        Q = estimate(var, pwr.injection.reactive, pwr.from.reactive, pwr.to.reactive, i)
        printDevice(io, var.reactive, Q, scale[:Q], var.layout.index[i], i, prt)

        @printf io "\n"
    end
    printf(io, prt.footer, prt)
end

function varData(
    var::Varmeter,
    pwr::ACPower,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    type = "Reactive Power"
    unitQ = unitList.reactivePowerLive
    device = !isempty(var.label)
    state = !isempty(pwr.injection.reactive)
    style, delimiter, key = printkwargs(; kwargs...)

    fmt, width, show, subheading, unit, head, minv, maxv = layoutMeter(
        key.fmt, key.width, key.show, unitQ, device, state, style, type
    )

    if device && style
        @inbounds for (label, i) in labels
            Q = estimate(var, pwr.injection.reactive, pwr.from.reactive, pwr.to.reactive, i)
            idx = var.layout.index[i]
            minmaxMeter!(
                var.reactive, Q, scale[:Q], label, width, show, minv, maxv, idx, i, head
            )
        end
        widthMeter(fmt, width, show, minv, maxv)
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    notprint = printing!(width, show, title, style, "Varmeter Data")
    heading = headingMeter(width, show, delimiter, style, head)

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
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
function printPmuData(
    system::PowerSystem,
    device::Measurement,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.pmu.number + 1,
    kwargs...
)
    voltage = Polar(Float64[], Float64[])
    current = ACCurrent(
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[]),
        Polar(Float64[], Float64[])
    )
    printPmu(io, system, device, voltage, current, unitList, pfx, label, repeat; kwargs...)
end

function printPmuData(
    system::PowerSystem,
    device::Measurement,
    analysis::Union{PMUStateEstimation, ACStateEstimation},
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.pmu.number + 1,
    kwargs...
)
    printPmu(io, system, device, analysis.voltage, analysis.current, unitList, pfx, label, repeat; kwargs...)
end

function printPmuData(
    system::PowerSystem,
    device::Measurement,
    analysis::DCStateEstimation,
    io::IO = stdout;
    label::IntStrMiss = missing,
    repeat::Int64 = device.pmu.number + 1,
    kwargs...
)
    printPmu(io, system, device, analysis.voltage, unitList, pfx, label, repeat; kwargs...)
end

function printPmu(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    voltage::Polar,
    current::ACCurrent,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    pmu = device.pmu
    scale = scalePrint(system, pfx)

    if isempty(pmu.label)
        return
    end

    labels = pickLabel(pmu, pmu.label, label, "pmu")
    prtV, prtI, headV, headθ, headI, headψ = pmuData(system, pmu, voltage, current,
        unitList, scale, label, labels, repeat; kwargs...)

    if !prtV.notprint
        title(io, prtV, "PMU Data")
        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                idxBus = pmu.layout.index[i]
                scaleV = scaleVoltage(pfx, system, idxBus)

                header(io, prtV)
                printf(io, prtV.pfmt, prtV, label, :labl)

                prtV.head = headV
                printDevice(io, pmu.magnitude, voltage.magnitude, scaleV, idxBus, i, prtV)
                prtV.head = headθ
                printDevice(io, pmu.angle, voltage.angle, scale[:θ], idxBus, i, prtV)

                @printf io "\n"
            end
        end
        printf(io, prtV.footer, prtV)
    end

    if !prtI.notprint
        title(io, prtI, "PMU Data")

        scaleI = 1.0
        @inbounds for (label, i) in labels
            if !pmu.layout.bus[i]
                idxBusBrch = pmu.layout.index[i]
                scaleI = scaleIij(system, scaleI, pfx, pmu.layout.from[i], idxBusBrch)

                header(io, prtI)
                printf(io, prtI.pfmt, prtI, label, :labl)

                I = estimate(pmu, current.from.magnitude, current.to.magnitude, i)
                prtI.head = headI
                printDevice(io, pmu.magnitude, I, scaleI, idxBusBrch, i, prtI)

                ψ = estimate(pmu, current.from.angle, current.to.angle, i)
                prtI.head = headψ
                printDevice(io, pmu.angle, ψ, scale[:ψ], idxBusBrch, i, prtI)

                @printf io "\n"
            end
        end
        printf(io, prtI.footer, prtI)
    end
end

function pmuData(
    system::PowerSystem,
    pmu::PMU,
    voltage::Polar,
    current::ACCurrent,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    style, delimiter, key = printkwargs(; kwargs...)

    deviceV = any(pmu.layout.bus)
    stateV = !isempty(voltage.magnitude) & deviceV
    liveV = unitList.voltageMagnitudeLive
    liveθ = unitList.voltageAngleLive

    fmtV, widthV, showV, subheadV, unitV, headV, minV, maxV = layoutMeter(
        key.fmt, key.width, key.show, liveV, deviceV, stateV, style, "Voltage Magnitude"
    )
    fmtθ, widthθ, showθ, subheadθ, unitθ, headθ, minθ, maxθ = layoutMeter(
        key.fmt, key.width, key.show, liveθ, deviceV, stateV, style, "Voltage Angle"
    )

    deviceI = any(pmu.layout.from) || any(pmu.layout.to)
    stateI = !isempty(current.from.magnitude) & deviceI
    liveI = unitList.currentMagnitudeLive
    liveψ = unitList.currentAngleLive

    fmtI, widthI, showI, subheadI, unitI, headI, minI, maxI = layoutMeter(
        key.fmt, key.width, key.show, liveI, deviceI, stateI, style, "Current Magnitude"
    )
    fmtψ, widthψ, showψ, subheadψ, unitψ, headψ, minψ, maxψ = layoutMeter(
        key.fmt, key.width, key.show, liveψ, deviceI, stateI, style, "Current Angle"
    )

    notVol = true
    notCur = true
    if !isempty(pmu.label)
        if style
            scaleI = 1.0
            @inbounds for (lbl, i) in labels
                idxBusBrch = pmu.layout.index[i]
                if pmu.layout.bus[i]
                    notVol = false
                    scaleV = scaleVoltage(pfx, system, idxBusBrch)

                    minmaxMeter!(
                        pmu.magnitude, voltage.magnitude, scaleV, lbl,
                        widthV, showV, minV, maxV, idxBusBrch, i, headV
                    )
                    minmaxMeter!(pmu.angle, voltage.angle, scale[:θ], lbl,
                        widthθ, showθ, minθ, maxθ, idxBusBrch, i, headθ
                    )
                else
                    notCur = false
                    scaleI = scaleIij(system, scaleI, pfx, pmu.layout.from[i], idxBusBrch)

                    I = estimate(pmu, current.from.magnitude, current.to.magnitude, i)
                    minmaxMeter!(
                        pmu.magnitude, I, scaleI, lbl,
                        widthI, showI, minI, maxI, idxBusBrch, i, headI
                    )

                    ψ = estimate(pmu, current.from.angle, current.to.angle, i)
                    minmaxMeter!(
                        pmu.angle, ψ, scale[:ψ], lbl,
                        widthψ, showψ, minψ, maxψ, idxBusBrch, i, headψ
                    )
                end
            end
            widthMeter(fmtV, widthV, showV, minV, maxV)
            widthMeter(fmtθ, widthθ, showθ, minθ, maxθ)
            widthMeter(fmtI, widthI, showI, minI, maxI)
            widthMeter(fmtψ, widthψ, showψ, minψ, maxψ)
        else
            @inbounds for (lbl, i) in labels
                if pmu.layout.bus[i]
                    notVol = false
                else
                    notCur = false
                end
                if !notVol && !notCur
                    break
                end
            end
        end
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    mergeDict!(fmtV, fmtθ, widthV, widthθ, showV, showθ, subheadV, subheadθ, unitV, unitθ)
    mergeDict!(fmtI, fmtψ, widthI, widthψ, showI, showψ, subheadI, subheadψ, unitI, unitψ)

    notprintV = printing!(widthV, showV, title, style, "PMU Data")
    notprintI = printing!(widthI, showI, title, style, "PMU Data")

    headingV = headingMeter(widthV, showV, delimiter, style, headV)
    headingθ = headingMeter(widthθ, showθ, delimiter, style, headθ)
    headingV["Voltage Angle"] = headingθ["Voltage Angle"]

    headingI = headingMeter(widthI, showI, delimiter, style, headI)
    headingψ = headingMeter(widthψ, showψ, delimiter, style, headψ)
    headingI["Current Angle"] = headingψ["Current Angle"]

    pfmtV, hfmtV, lineV = layout(fmtV, widthV, showV, delimiter, style)
    pfmtI, hfmtI, lineI = layout(fmtI, widthI, showI, delimiter, style)

    Print(
        pfmtV, hfmtV, widthV, showV, headingV, subheadV, unitV, headV, delimiter, style,
        title, header, footer, repeat, notprintV | notVol, lineV, 1
    ),
    Print(
        pfmtI, hfmtI, widthI, showI, headingI, subheadI, unitI, headI, delimiter, style,
        title, header, footer, repeat, notprintI | notCur, lineI, 1
    ),
    headV, headθ, headI, headψ
end

function printPmu(
    io::IO,
    system::PowerSystem,
    device::Measurement,
    voltg::PolarAngle,
    unitList::UnitList,
    pfx::PrefixLive,
    label::IntStrMiss,
    repeat::Int64;
    kwargs...
)
    pmu = device.pmu
    scale = scalePrint(system, pfx)

    labels = pickLabel(pmu, pmu.label, label, "pmu")
    prt = pmuData(pmu, voltg, unitList, scale, label, labels, repeat; kwargs...)

    if !isempty(pmu.label) && prt.notprint
        return
    end

    title(io, prt, "PMU Data")

    @inbounds for (label, i) in labels
        if pmu.layout.bus[i]
            idxBus = pmu.layout.index[i]

            header(io, prt)
            printf(io, prt.pfmt, prt, label, :labl)

            printDevice(io, pmu.angle, voltg.angle, scale[:θ], idxBus, i, prt)

            @printf io "\n"
        end
    end
    printf(io, prt.footer, prt)
end

function pmuData(
    pmu::PMU,
    voltg::PolarAngle,
    unitList::UnitList,
    scale::Dict{Symbol, Float64},
    label::IntStrMiss,
    labels::Union{OrderedDict{String, Int64}, OrderedDict{Int64, Int64}},
    repeat::Int64;
    kwargs...
)
    type = "Voltage Angle"
    liveθ = unitList.voltageAngleLive
    device = any(pmu.layout.bus)
    state = !isempty(voltg.angle) && device
    style, delimiter, key = printkwargs(; kwargs...)

    fmt, width, show, subheading, unit, head, minv, maxv = layoutMeter(
        key.fmt, key.width, key.show, liveθ, device, state, style, type
    )

    if !isempty(pmu.label) && style
        @inbounds for (label, i) in labels
            if pmu.layout.bus[i]
                minmaxMeter!(
                    pmu.angle, voltg.angle, scale[:θ], label, width,
                    show, minv, maxv, pmu.layout.index[i], i, head
                )
            end
        end
        widthMeter(fmt, width, show, minv, maxv)
    end

    title, header, footer = layout(label, key.title, key.header, key.footer)

    notprint = printing!(width, show, title, style, "PMU Data")
    heading = headingMeter(width, show, delimiter, style, head)

    pfmt, hfmt, line = layout(fmt, width, show, delimiter, style)

    Print(
        pfmt, hfmt, width, show, heading, subheading, unit, head, delimiter, style,
        title, header, footer, repeat, notprint, line, 1
    )
end

function layoutMeter(
    kfmt::Dict{String, String},
    kwidth::Dict{String, Int64},
    kshow::Dict{String, Bool},
    unitMeter::String,
    device::Bool,
    estimate::Bool,
    style::Bool,
    type::String
)
    head = Dict(
        :labl => "Label",
        :metr => type,
        :mean => type * " Measurement",
        :vari => type * " Variance",
        :esti => type * " Estimate",
        :resi => type * " Residual",
        :stat => type * " Status",
    )

    show = OrderedDict(head[:metr] => true)
    fmt, width = fmtwidth(show)
    transfer!(fmt, kfmt, width, kwidth, show, kshow, style)

    subheading = Dict(
        head[:labl] => _header("", head[:labl], style),
        head[:mean] => _header("Measurement", head[:mean], style),
        head[:vari] => _header("Variance", head[:vari], style),
        head[:esti] => _header("Estimate", head[:esti], style),
        head[:resi] => _header("Residual", head[:resi], style),
        head[:stat] => _header("Status", "Status", style)
    )
    unit = Dict(
        head[:labl] => "",
        head[:mean] => "[" * unitMeter * "]",
        head[:vari] => "[" * unitMeter * "]",
        head[:esti] => "[" * unitMeter * "]",
        head[:resi] => "[" * unitMeter * "]",
        head[:stat] => ""
    )
    fmt = Dict(
        head[:labl] => "%-*s",
        head[:mean] => _fmt(fmt[head[:metr]]),
        head[:vari] => _fmt(fmt[head[:metr]]; format = "%*.2e"),
        head[:esti] => _fmt(fmt[head[:metr]]),
        head[:resi] => _fmt(fmt[head[:metr]]),
        head[:stat] => "%*i"
    )
    width = Dict(
        head[:labl] => 5 * style,
        head[:mean] => _width(width[head[:metr]], 11, style),
        head[:vari] => _width(width[head[:metr]], 8, style),
        head[:esti] => _width(width[head[:metr]], 8, style),
        head[:resi] => _width(width[head[:metr]], 8, style),
        head[:stat] => _width(width[head[:metr]], 6, style),
    )
    show = OrderedDict(
        head[:labl] => device,
        head[:mean] => _show(show[head[:metr]], device),
        head[:vari] => _show(show[head[:metr]], device),
        head[:esti] => _show(show[head[:metr]], estimate),
        head[:resi] => _show(show[head[:metr]], estimate),
        head[:stat] => _show(show[head[:metr]], device)
    )
    transfer!(fmt, kfmt, width, kwidth, show, kshow, style)

    minv = [0; Inf; Inf; Inf; Inf; 0]
    maxv = [0; -Inf; -Inf; -Inf; -Inf; 0]

    return fmt, width, show, subheading, unit, head, minv, maxv
end

function headingMeter(
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    delimiter::String,
    style::Bool,
    head::Dict{Symbol, String}
)
    OrderedDict(
        head[:labl] => _blank(width, show, delimiter, head, :labl),
        head[:metr] => _blank(width, show, delimiter, style, head, :metr, :mean, :vari, :esti, :resi, :stat)
    )
end

function minmaxMeter!(
    meter::GaussMeter,
    estimate::Vector{Float64},
    scale::Float64,
    label::IntStr,
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    minval::Vector{Float64},
    maxval::Vector{Float64},
    idxBusBrch::Int64,
    idxMeter::Int64,
    head::Dict{Symbol, String}
)
    fmax(width, show, label, head[:labl])

    if show[head[:mean]]
        minval[2] = min(meter.mean[idxMeter] * scale, minval[2])
        maxval[2] = max(meter.mean[idxMeter] * scale, maxval[2])
    end

    if show[head[:vari]]
        minval[3] = min(meter.variance[idxMeter] * scale, minval[3])
        maxval[3] = max(meter.variance[idxMeter] * scale, maxval[3])
    end

    if show[head[:esti]]
        minval[4] = min(estimate[idxBusBrch] * scale, minval[4])
        maxval[4] = max(estimate[idxBusBrch] * scale, maxval[4])
    end

    if show[head[:resi]] && meter.status[idxMeter] == 1
        minval[5] = min((meter.mean[idxMeter] - estimate[idxBusBrch]) * scale, minval[5])
        maxval[5] = max((meter.mean[idxMeter] - estimate[idxBusBrch]) * scale, maxval[5])
    end
end

function widthMeter(
    fmt::Dict{String, String},
    width::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    minval::Vector{Float64},
    maxval::Vector{Float64}
)
    for (i, key) in enumerate(keys(show))
        if show[key]
            Fmt = Format(fmt[key])
            width[key] = max(
                textwidth(format(Fmt, 0, minval[i])),
                textwidth(format(Fmt, 0, maxval[i])),
                width[key]
            )
        end
    end
end

function printDevice(
    io::IO,
    meter::GaussMeter,
    estimate::Vector{Float64},
    scale::Float64,
    idxBusBrch::Int64,
    idxDevice::Int64,
    prt::Print
)
    printf(io, prt, idxDevice, scale, meter.mean, :mean)
    printf(io, prt, idxDevice, scale, meter.variance, :vari)
    printf(io, prt, idxBusBrch, scale, estimate, :esti)

    if meter.status[idxDevice] == 1
        printf(io, prt, idxBusBrch, idxDevice, scale, meter.mean, estimate, :resi)
    else
        printf(io, prt.hfmt, prt, "", :resi)
    end

    printf(io, prt, idxDevice, meter.status, :stat)
end

function estimate(device::M,
    bus::Vector{Float64},
    from::Vector{Float64},
    to::Vector{Float64},
    i::Int64
)
    if device.layout.bus[i]
        return bus
    elseif device.layout.from[i]
        return from
    else
        return to
    end
end

function estimate(device::M, from::Vector{Float64}, to::Vector{Float64}, i::Int64)
    if device.layout.from[i]
        return from
    else
        return to
    end
end

function mergeDict!(
    fmt::Dict{String, String},
    fmt1::Dict{String, String},
    width::Dict{String, Int64},
    width1::Dict{String, Int64},
    show::OrderedDict{String, Bool},
    show1::OrderedDict{String, Bool},
    subheader::Dict{String, String},
    subheader1::Dict{String, String},
    unit::Dict{String, String},
    unit1::Dict{String, String})

    merge!(fmt, fmt1)
    merge!(width, width1)
    merge!(show, show1)
    merge!(subheader, subheader1)
    merge!(unit, unit1)
end