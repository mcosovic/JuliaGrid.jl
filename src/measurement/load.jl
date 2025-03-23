"""
    measurement(file::String)

The function builds the composite type `Measurement` and populates `voltmeter`, `ammeter`,
`wattmeter`, `varmeter`, and `pmu` fields. In general, once the type `Measurement` has
been created, it is possible to add new measurement devices, or modify the parameters of
existing ones.

# Argument
It requires a string path to the HDF5 file with the `.h5` extension.

# Returns
The `Measurement` composite type with the following fields:
- `voltmeter`: Bus voltage magnitude measurements.
- `ammeter`: Branch current magnitude measurements.
- `wattmeter`: Active power injection and active power flow measurements.
- `varmeter`: Reactive power injection and reactive power flow measurements.
- `pmu`: Bus voltage and branch current phasor measurements.

# Units
JuliaGrid stores all data in per-units and radians format.

# Example
```jldoctest
device = measurement("measurement14.h5")
```
"""
function measurement(inputFile::String)
    packagePath = checkPackagePath()
    fullpath, extension = checkFileFormat(inputFile, packagePath)

    if extension == ".h5"
        hdf5 = h5open(fullpath, "r")
            checkLabelMeasurement(hdf5, template)

            device = measurement()
            loadVoltmeter(device, hdf5)
            loadAmmeter(device, hdf5)
            loadWattmeter(device, hdf5)
            loadVarmeter(device, hdf5)
            loadPmu(device, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        throw(DomainError(extension, "The extension .m is not supported."))
    end

    return device
end

"""
    measurement()

Alternatively, the `Measurement` composite type can be initialized by calling the function
without any arguments. This allows the model to be built from scratch and modified as
needed.

# Example
```jldoctest
device = measurement()
```
"""
function measurement()
    Measurement(
        Voltmeter(
            OrderedDict{template.config.device, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            VoltmeterLayout(Int64[], 0),
            0
        ),
        Ammeter(
            OrderedDict{template.config.device, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            AmmeterLayout(Int64[], Int64[], Bool[], Bool[], 0),
            0
        ),
        Wattmeter(
            OrderedDict{template.config.device, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            PowermeterLayout(Int64[], Bool[], Bool[], Bool[], 0),
            0
        ),
        Varmeter(
            OrderedDict{template.config.device, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            PowermeterLayout(Int64[], Bool[], Bool[], Bool[], 0),
            0
        ),
        PMU(
            OrderedDict{template.config.device, Int64}(),
            GaussMeter(Float64[], Float64[], Int8[]),
            GaussMeter(Float64[], Float64[], Int8[]),
            PmuLayout(Int64[], Bool[], Bool[], Bool[], Bool[], Bool[], Bool[], 0),
            0
        )
    )
end

##### Check Label Type from HDF5 File #####
function checkLabelMeasurement(hdf5::File, template::Template)
    for device in hdf5
        labelType = eltype(device["label"])
        if labelType === Cstring
            template.config.device = String
        else
            template.config.device = Int64
        end
        break
    end
end

##### Load Label #####
function loadLabel(device::M, hdf5::File; meter::String = "")
    label = read(hdf5[string(meter, "/label")])
    device.number = length(label)

    device.label = OrderedDict(zip(label, collect(1:device.number)))
    device.layout.label = read(hdf5[string(meter, "/layout/label")])
end

##### Load Mean, Variance, and Status #####
function loadMeter(meter::GaussMeter, hdf5::Group, number::Int64)
    meter.mean = readHDF5(hdf5, "mean", number)
    meter.variance = readHDF5(hdf5, "variance", number)
    meter.status = readHDF5(hdf5, "status", number)
end

##### Load Voltmeter #####
function loadVoltmeter(device::Measurement, hdf5::File)
    if haskey(hdf5, "voltmeter")
        voltmeter = device.voltmeter
        loadLabel(voltmeter, hdf5; meter = "voltmeter")
        loadMeter(voltmeter.magnitude, hdf5["voltmeter/magnitude"], voltmeter.number)

        layout = hdf5["voltmeter/layout"]
        voltmeter.layout.index = readHDF5(layout, "index", voltmeter.number)
    end
end

##### Load Ammeter #####
function loadAmmeter(device::Measurement, hdf5::File)
    if haskey(hdf5, "ammeter")
        ammeter = device.ammeter
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
function loadWattmeter(device::Measurement, hdf5::File)
    if haskey(hdf5, "wattmeter")
        wattmeter = device.wattmeter
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
function loadVarmeter(device::Measurement, hdf5::File)
    if haskey(hdf5, "varmeter")
        varmeter = device.varmeter
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
function loadPmu(device::Measurement, hdf5::File)
    if haskey(hdf5, "pmu")
        pmu = device.pmu
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