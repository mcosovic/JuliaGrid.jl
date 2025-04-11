"""
    saveMeasurement(monitoring::Measurement; path::String, reference::String, note::String)

The function saves the measurement's data in the HDF5 file using the fields `voltmeter`, `ammeter`,
`wattmeter`, `varmeter`, and `pmu` from the `Measurement` type.

# Keywords
The location and file name of the HDF5 file is specified by the mandatory keyword `path` in the
format of `"path/name.h5"`. Additional information can be provided by the optional keywords
`reference` and `note`, which can be saved along with the power system data.

# View HDF5 File
To view the saved HDF5 file, you can use the [HDFView](https://www.hdfgroup.org/downloads/hdfview/)
software.

# Example
```jldoctest
using Ipopt

system, monitoring = ems("case14.m")

analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
powerFlow!(analysis; power = true)

addVoltmeter!(monitoring, analysis)
addWattmeter!(monitoring, analysis)

saveMeasurement(monitoring; path = "D:/monitoring.h5")
```
"""
function saveMeasurement(
    monitoring::Measurement;
    path::String,
    reference::String = "",
    note::String = ""
)
    file = h5open(path, "w")
        saveVoltmeter(monitoring.voltmeter, file)
        saveAmmeter(monitoring.ammeter, file)
        saveWattmeter(monitoring.wattmeter, file)
        saveVarmeter(monitoring.varmeter, file)
        savePmu(monitoring.pmu, file)
        saveAttribute(monitoring, file, reference, note)
    close(file)
end

##### Save Voltmeter #####
function saveVoltmeter(voltmeter::Voltmeter, file::File)
    if voltmeter.number != 0
        saveLabel(voltmeter, file; fid = "voltmeter")
        saveMeter(voltmeter.magnitude, file; name = "voltmeter/magnitude", si = "V")
        saveLayout(voltmeter.layout.index, file; fid = "voltmeter/layout/index")
    end
end

##### Save Ammeter #####
function saveAmmeter(ammeter::Ammeter, file::File)
    if ammeter.number != 0
        saveLabel(ammeter, file; fid = "ammeter")
        saveMeter(ammeter.magnitude, file; name = "ammeter/magnitude", si = "A")
        saveLayout(ammeter.layout.index, file; fid = "ammeter/layout/index")
        saveLayout(ammeter.layout.from, file; fid = "ammeter/layout/from")
        saveLayout(ammeter.layout.to, file; fid = "ammeter/layout/to")
        saveLayout(ammeter.layout.square, file; fid = "ammeter/layout/square")
    end
end

##### Save Wattmeter #####
function saveWattmeter(wattmeter::Wattmeter, file::File)
    if wattmeter.number != 0
        saveLabel(wattmeter, file; fid = "wattmeter")
        saveMeter(wattmeter.active, file; name = "wattmeter/active", si = "W")
        saveLayout(wattmeter.layout.index, file; fid = "wattmeter/layout/index")
        saveLayout(wattmeter.layout.bus, file; fid = "wattmeter/layout/bus")
        saveLayout(wattmeter.layout.from, file; fid = "wattmeter/layout/from")
        saveLayout(wattmeter.layout.to, file; fid = "wattmeter/layout/to")
    end
end

##### Save Varmeter #####
function saveVarmeter(varmeter::Varmeter, file::File)
    if varmeter.number != 0
        saveLabel(varmeter, file; fid = "varmeter")
        saveMeter(varmeter.reactive, file; name = "varmeter/reactive", si = "VAr")
        saveLayout(varmeter.layout.index, file; fid = "varmeter/layout/index")
        saveLayout(varmeter.layout.bus, file; fid = "varmeter/layout/bus")
        saveLayout(varmeter.layout.from, file; fid = "varmeter/layout/from")
        saveLayout(varmeter.layout.to, file; fid = "varmeter/layout/to")
    end
end

##### Save PMU #####
function savePmu(pmu::PMU, file::File)
    if pmu.number != 0
        saveLabel(pmu, file; fid = "pmu")
        saveMeter(pmu.magnitude, file; name = "pmu/magnitude", si = "V or A")
        saveMeter(pmu.angle, file; name = "pmu/angle", pu = "rad")
        saveLayout(pmu.layout.index, file; fid = "pmu/layout/index")
        saveLayout(pmu.layout.bus, file; fid = "pmu/layout/bus")
        saveLayout(pmu.layout.from, file; fid = "pmu/layout/from")
        saveLayout(pmu.layout.to, file; fid = "pmu/layout/to")
        saveLayout(pmu.layout.correlated, file; fid = "pmu/layout/correlated")
        saveLayout(pmu.layout.polar, file; fid = "pmu/layout/polar")
        saveLayout(pmu.layout.square, file; fid = "pmu/layout/square")
    end
end

##### Save Main Attributes #####
function saveAttribute(monitoring::Measurement, file::File, reference::String, note::String)
    attrs(file)["number of voltmeters"] = monitoring.voltmeter.number
    attrs(file)["number of ammeters"] = monitoring.ammeter.number
    attrs(file)["number of wattmeters"] = monitoring.wattmeter.number
    attrs(file)["number of varmeters"] = monitoring.varmeter.number
    attrs(file)["number of pmus"] = monitoring.pmu.number

    if !isempty(reference)
        attrs(file)["reference"] = reference
    end

    if !isempty(note)
        attrs(file)["note"] = note
    end
end


##### Save Label #####
function saveLabel(monitoring::M, file::File; fid::String = "")
    fidLabel = fid * "/label"

    write(file, fidLabel, collect(keys(monitoring.label)))
    attrs(file[fidLabel])["format"] = "expand"

    write(file, fid * "/layout/label", monitoring.layout.label)
end

##### Save Layout #####
function saveLayout(layout, file::File; fid::String = "")
    write(file, fid, layout)
    attrs(file[fid])["format"] = "expand"
end

##### Save Mean, Variance, and Status #####
function saveMeter(
    meter::GaussMeter,
    file::File;
    name::String = "",
    si::String = "",
    pu::String = "pu"
)
    fid = string(name, "/mean")
    format = compresseArray(file, meter.mean, fid)
    attrs(file[fid])["unit"] = pu
    if !isempty(si)
        attrs(file[fid])["SI unit"] = si
    end
    attrs(file[fid])["format"] = format

    fid = string(name, "/variance")
    format = compresseArray(file, meter.variance, fid)
    attrs(file[fid])["unit"] = pu
    attrs(file[fid])["SI unit"] = si
    attrs(file[fid])["format"] = format

    fid = string(name, "/status")
    format = compresseArray(file, meter.status, fid)
    attrs(file[fid])["in-service"] = 1
    attrs(file[fid])["out-of-service"] = 0
    attrs(file[fid])["format"] = format
end