"""
    measurement(file::String)

The function builds the composite type `Measurement` and populates `voltmeter`, `ammeter`,
`wattmeter`, `varmeter`, and `pmu` fields. In general, once the composite type `Measurement`
has been created, it is possible to add new measurement devices, or modify the parameters
of existing ones.

# Argument
It requires a string path to the HDF5 file with the `.h5` extension.

# Returns
The `Measurement` composite type with the following fields:
- `voltmeter`: bus voltage magnitude measurements;
- `ammeter`: branch current magnitude measurements;
- `wattmeter`: active power injection and active power flow measurements;
- `varmeter`: reactive power injection and reactive power flow measurements;
- `pmu`: bus voltage and branch current phasor measurements.

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
    device = measurement()

    if extension == ".h5"
        hdf5 = h5open(fullpath, "r")
            loadVoltmeter(device, hdf5)
            loadAmmeter(device, hdf5)
            loadWattmeter(device, hdf5)
            loadVarmeter(device, hdf5)
            loadPmu(device, hdf5)
        close(hdf5)
    end

    if extension == ".m"
        throw(DomainError(extension, "The extension $extension is not supported."))
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
    label = OrderedDict{String, Int64}()
    af = Array{Float64,1}(undef, 0)
    ai = Array{Int64,1}(undef, 0)
    ai8 = Array{Int8,1}(undef, 0)
    ab = Array{Bool,1}(undef, 0)

    voltLayout = VoltmeterLayout(copy(ai), 0)
    ammLayout = AmmeterLayout(copy(ai), copy(ai), copy(ab), 0)
    powerLayout = PowermeterLayout(copy(ai), copy(ab), copy(ab), copy(ab), 0)
    pmuLayout = PmuLayout(copy(ai), copy(ab), copy(ab), copy(ab), copy(ab), copy(ab), 0)
    gauss = GaussMeter(copy(af), copy(af), copy(ai8))

    return Measurement(
        Voltmeter(copy(label), deepcopy(gauss), voltLayout, 0),
        Ammeter(copy(label), deepcopy(gauss), ammLayout, 0),
        Wattmeter(copy(label), deepcopy(gauss), deepcopy(powerLayout), 0),
        Varmeter(copy(label), deepcopy(gauss), deepcopy(powerLayout), 0),
        PMU(copy(label), deepcopy(gauss), deepcopy(gauss), deepcopy(pmuLayout), 0)
    )
end

######## Load Label ##########
function loadLabel(device, hdf5::HDF5.File; meter = "")
    label::Array{String,1} = read(hdf5[string(meter, "/label")])
    device.number = length(label)

    device.label = OrderedDict{String,Int64}(); sizehint!(device.label, device.number)
    @inbounds for i = 1:device.number
        device.label[label[i]] = i
    end

    device.layout.label = read(hdf5[string(meter, "/layout/label")])
end

######## Load Mean, Variance, and Status ##########
function loadMeter(meter, hdf5, number)
    meter.mean = readHDF5(hdf5, "mean", number)
    meter.variance = readHDF5(hdf5, "variance", number)
    meter.status = readHDF5(hdf5, "status", number)
end

######## Load Voltmeter ##########
function loadVoltmeter(device::Measurement, hdf5::HDF5.File)
    if haskey(hdf5, "voltmeter")
        voltmeter = device.voltmeter
        loadLabel(voltmeter, hdf5; meter = "voltmeter")
        loadMeter(voltmeter.magnitude, hdf5["voltmeter/magnitude"], voltmeter.number)

        layout = hdf5["voltmeter/layout"]
        voltmeter.layout.index = readHDF5(layout, "index", voltmeter.number)
    end
end

######## Load Ammeter ##########
function loadAmmeter(device::Measurement, hdf5::HDF5.File)
    if haskey(hdf5, "ammeter")
        ammeter = device.ammeter
        loadLabel(ammeter, hdf5; meter = "ammeter")
        loadMeter(ammeter.magnitude, hdf5["ammeter/magnitude"], ammeter.number)

        layout = hdf5["ammeter/layout"]
        ammeter.layout.index = readHDF5(layout, "index", ammeter.number)
        ammeter.layout.from = readHDF5(layout, "from", ammeter.number)
        ammeter.layout.to = readHDF5(layout, "to", ammeter.number)
    end
end

######## Load Wattmeter ##########
function loadWattmeter(device::Measurement, hdf5::HDF5.File)
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

######## Load Varmeter ##########
function loadVarmeter(device::Measurement, hdf5::HDF5.File)
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

######## Load PMU ##########
function loadPmu(device::Measurement, hdf5::HDF5.File)
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
    end
end