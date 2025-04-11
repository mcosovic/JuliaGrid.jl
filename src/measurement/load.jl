"""
    measurement(system::PowerSystem, file::String)

The function builds a `Measurement` composite type for the provided `PowerSystem`, using data stored
in the specified file. It populates the `voltmeter`, `ammeter`, `wattmeter`, `varmeter`, and `pmu`
fields. Once the `Measurement` type is created, additional measurement devices can be added, or the
parameters of existing ones can be modified.

# Argument
The function requires an existing `PowerSystem` instance and a string specifying the path to an HDF5
file with a `.h5` extension.

# Returns
The `Measurement` type with the following fields:
- `voltmeter`: Bus voltage magnitude measurements.
- `ammeter`: Branch current magnitude measurements.
- `wattmeter`: Active power injection and active power flow measurements.
- `varmeter`: Reactive power injection and reactive power flow measurements.
- `pmu`: Bus voltage and branch current phasor measurements.
- `system`: The reference to the power system.

# Units
JuliaGrid stores all data in per-units and radians format.

# Example
```jldoctest
system = powerSystem("case14.h5")
monitoring = measurement(system, "monitoring.h5")
```
"""
function measurement(system::PowerSystem, inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)

    if extension == ".h5"
        hdf5 = h5open(fullpath, "r")
            checkLabelMeasurement(hdf5, template)

            monitoring = measurement(system)
            loadVoltmeter(monitoring, hdf5)
            loadAmmeter(monitoring, hdf5)
            loadWattmeter(monitoring, hdf5)
            loadVarmeter(monitoring, hdf5)
            loadPmu(monitoring, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        throw(DomainError(extension, "The extension .m is not supported."))
    end

    return monitoring
end

"""
    measurement(system::PowerSystem)

Alternatively, the `Measurement` composite type can be initialized without any data for the specified
`PowerSystem` type. This allows the model to be built from scratch and modified as needed.

# Example
```jldoctest
system = powerSystem("case14.h5")
monitoring = measurement(system)
```
"""
function measurement(system::PowerSystem)
    Measurement(
        Voltmeter(
            OrderedDict{template.config.monitoring, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            VoltmeterLayout(Int64[], 0),
            0
        ),
        Ammeter(
            OrderedDict{template.config.monitoring, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            AmmeterLayout(Int64[], Int64[], Bool[], Bool[], 0),
            0
        ),
        Wattmeter(
            OrderedDict{template.config.monitoring, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            PowermeterLayout(Int64[], Bool[], Bool[], Bool[], 0),
            0
        ),
        Varmeter(
            OrderedDict{template.config.monitoring, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            PowermeterLayout(Int64[], Bool[], Bool[], Bool[], 0),
            0
        ),
        PMU(
            OrderedDict{template.config.monitoring, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            GaussMeter(Float64[], Float64[], Int8[]),
            PmuLayout(Int64[], Bool[], Bool[], Bool[], Bool[], Bool[], Bool[], 0),
            0
        ),
        system
    )
end

"""
    ems(system::String, monitoring::Vararg{String})

This function builds the `PowerSystem` and `Measurement` composite types using data from the
provided files. It acts as a wrapper that includes both [`powerSystem`](@ref powerSystem) and
[`measurement`](@ref measurement) functions.

# Arguments
The function requires a string path to the power `system` data, which can either be stored in an
HDF5 file with the `.h5` extension or a Matpower file with the `.m` extension. It also needs a
string path to the `monitoring` data, which should be in an HDF5 file with the `.h5` extension.

Additionally, users can ignore the path to the `monitoring` data to build and populate only the
`PowerSystem` type, while initializing an empty `Measurement` type.

# Returns
The function returns the `PowerSystem` and `Measurement` types.

# Examples
Build the power system and the measurement model:
```jldoctest
system, monitoring = ems("case14.m", "monitoring.h5")
```

Build the power system and multiple measurement models:
```jldoctest
system, monitoring, pseudo = ems("case14.m", "monitoring.h5", "pseudo.h5")
```
"""
function ems(systemFile::String, deviceFiles::Vararg{String})
    system = powerSystem(systemFile)
    monitoring = Tuple(measurement(system, df) for df in deviceFiles)
    return (system, monitoring...)
end

function ems(systemFile::String)
    system = powerSystem(systemFile)
    monitoring = measurement(system)

    return system, monitoring
end

"""
    ems()

Alternatively, the `PowerSystem` and `Measurement` composite types can be initialized without any
data. This provides the flexibility to build and modify the models from the ground up.

# Example
```jldoctest
system, monitoring = ems()
```
"""
function ems()
    system = powerSystem()
    monitoring = measurement(system)

    return system, monitoring
end

##### Check Label Type from HDF5 File #####
function checkLabelMeasurement(hdf5::File, template::Template)
    for monitoring in hdf5
        labelType = eltype(monitoring["label"])
        if labelType === Cstring
            template.config.monitoring = String
        else
            template.config.monitoring = Int64
        end
        break
    end
end

##### Load Label #####
function loadLabel(monitoring::M, hdf5::File; meter::String = "")
    label = read(hdf5[string(meter, "/label")])
    monitoring.number = length(label)

    monitoring.label = OrderedDict(zip(label, collect(1:monitoring.number)))
    monitoring.layout.label = read(hdf5[string(meter, "/layout/label")])
end

##### Load Mean, Variance, and Status #####
function loadMeter(meter::GaussMeter, hdf5::Group, number::Int64)
    meter.mean = readHDF5(hdf5, "mean", number)
    meter.variance = readHDF5(hdf5, "variance", number)
    meter.status = readHDF5(hdf5, "status", number)
end

##### Load Voltmeter #####
function loadVoltmeter(monitoring::Measurement, hdf5::File)
    if haskey(hdf5, "voltmeter")
        voltmeter = monitoring.voltmeter
        loadLabel(voltmeter, hdf5; meter = "voltmeter")
        loadMeter(voltmeter.magnitude, hdf5["voltmeter/magnitude"], voltmeter.number)

        layout = hdf5["voltmeter/layout"]
        voltmeter.layout.index = readHDF5(layout, "index", voltmeter.number)
    end
end

##### Load Ammeter #####
function loadAmmeter(monitoring::Measurement, hdf5::File)
    if haskey(hdf5, "ammeter")
        ammeter = monitoring.ammeter
        loadLabel(ammeter, hdf5; meter = "ammeter")
        loadMeter(ammeter.magnitude, hdf5["ammeter/magnitude"], ammeter.number)

        layout = hdf5["ammeter/layout"]
        ammeter.layout.index = readHDF5(layout, "index", ammeter.number)
        ammeter.layout.from = readHDF5(layout, "from", ammeter.number)
        ammeter.layout.to = readHDF5(layout, "to", ammeter.number)
        ammeter.layout.square = readHDF5(layout, "square", ammeter.number)
    end
end

##### Load Wattmeter #####
function loadWattmeter(monitoring::Measurement, hdf5::File)
    if haskey(hdf5, "wattmeter")
        wattmeter = monitoring.wattmeter
        loadLabel(wattmeter, hdf5; meter = "wattmeter")
        loadMeter(wattmeter.active, hdf5["wattmeter/active"], wattmeter.number)

        layout = hdf5["wattmeter/layout"]
        wattmeter.layout.index = readHDF5(layout, "index", wattmeter.number)
        wattmeter.layout.bus = readHDF5(layout, "bus", wattmeter.number)
        wattmeter.layout.from = readHDF5(layout, "from", wattmeter.number)
        wattmeter.layout.to = readHDF5(layout, "to", wattmeter.number)
    end
end

##### Load Varmeter #####
function loadVarmeter(monitoring::Measurement, hdf5::File)
    if haskey(hdf5, "varmeter")
        varmeter = monitoring.varmeter
        loadLabel(varmeter, hdf5; meter = "varmeter")
        loadMeter(varmeter.reactive, hdf5["varmeter/reactive"], varmeter.number)

        layout = hdf5["varmeter/layout"]
        varmeter.layout.index = readHDF5(layout, "index", varmeter.number)
        varmeter.layout.bus = readHDF5(layout, "bus", varmeter.number)
        varmeter.layout.from = readHDF5(layout, "from", varmeter.number)
        varmeter.layout.to = readHDF5(layout, "to", varmeter.number)
    end
end

##### Load PMU #####
function loadPmu(monitoring::Measurement, hdf5::File)
    if haskey(hdf5, "pmu")
        pmu = monitoring.pmu
        loadLabel(pmu, hdf5; meter = "pmu")
        loadMeter(pmu.magnitude, hdf5["pmu/magnitude"], pmu.number)
        loadMeter(pmu.angle, hdf5["pmu/angle"], pmu.number)

        layout = hdf5["pmu/layout"]
        pmu.layout.index = readHDF5(layout, "index", pmu.number)
        pmu.layout.bus = readHDF5(layout, "bus", pmu.number)
        pmu.layout.from = readHDF5(layout, "from", pmu.number)
        pmu.layout.to = readHDF5(layout, "to", pmu.number)
        pmu.layout.correlated = readHDF5(layout, "correlated", pmu.number)
        pmu.layout.polar = readHDF5(layout, "polar", pmu.number)
        pmu.layout.square = readHDF5(layout, "square", pmu.number)
    end
end