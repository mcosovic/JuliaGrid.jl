"""
    saveMeasurement(device::Measurement; path::String, reference::String, note::String)

The function saves the measurement's data in the HDF5 file using the fields `voltmeter`,
`ammeter`, `wattmeter`, `varmeter`, and `pmu` from the `Measurement` composite type.

# Keywords
The location and file name of the HDF5 file is specified by the mandatory keyword `path`
in the format of `"path/name.h5"`. Additional information can be provided by the optional
keywords `reference` and `note`, which can be saved along with the power system data.

# View HDF5 File
To view the saved HDF5 file, you can use the [HDFView](https://www.hdfgroup.org/downloads/hdfview/)
software.

# Example
```jldoctest
using Ipopt

system = powerSystem("case14.m")
device = measurement()

acModel!(system)
analysis = acOptimalPowerFlow(system, Ipopt.Optimizer)
solve!(system, analysis)
power!(system, analysis)

addVoltmeter!(system, device, analysis)
addWattmeter!(system, device, analysis)

saveMeasurement(device; path = "D:/measurement14.h5")
```
"""
function saveMeasurement(device::Measurement; path::String, reference::String = "", note::String = "")
    file = h5open(path, "w")
        saveVoltmeter(device.voltmeter, file)
        saveAmmeter(device.ammeter, file)
        saveWattmeter(device.wattmeter, file)
        saveVarmeter(device.varmeter, file)
        savePmu(device.pmu, file)
    close(file)
end

######### Save Voltmeter ##########
function saveVoltmeter(voltmeter::Voltmeter, file)
    if voltmeter.number != 0
        saveLabel(voltmeter, file; fid = "voltmeter")
        saveMeter(voltmeter, voltmeter.magnitude, file; name = "voltmeter/magnitude", si = "volt (V)")
        saveLayout(voltmeter.layout.index, file; fid = "voltmeter/layout/index")
    end
end

######### Save Ammeter ##########
function saveAmmeter(ammeter::Ammeter, file)
    if ammeter.number != 0
        saveLabel(ammeter, file; fid = "ammeter")
        saveMeter(ammeter, ammeter.magnitude, file; name = "ammeter/magnitude", si = "ampere (A)")
        saveLayout(ammeter.layout.index, file; fid = "ammeter/layout/index")
        saveLayout(ammeter.layout.from, file; fid = "ammeter/layout/from")
        saveLayout(ammeter.layout.to, file; fid = "ammeter/layout/to")
    end
end

######### Save Wattmeter ##########
function saveWattmeter(wattmeter::Wattmeter, file)
    if wattmeter.number != 0
        saveLabel(wattmeter, file; fid = "wattmeter")
        saveMeter(wattmeter, wattmeter.active, file; name = "wattmeter/active", si = "watt (W)")
        saveLayout(wattmeter.layout.index, file; fid = "wattmeter/layout/index")
        saveLayout(wattmeter.layout.bus, file; fid = "wattmeter/layout/bus")
        saveLayout(wattmeter.layout.from, file; fid = "wattmeter/layout/from")
        saveLayout(wattmeter.layout.to, file; fid = "wattmeter/layout/to")
    end
end

######### Save Varmeter ##########
function saveVarmeter(varmeter::Varmeter, file)
    if varmeter.number != 0
        saveLabel(varmeter, file; fid = "varmeter")
        saveMeter(varmeter, varmeter.reactive, file; name = "varmeter/reactive", si = "volt-amperes reactive (VAr)")
        saveLayout(varmeter.layout.index, file; fid = "varmeter/layout/index")
        saveLayout(varmeter.layout.bus, file; fid = "varmeter/layout/bus")
        saveLayout(varmeter.layout.from, file; fid = "varmeter/layout/from")
        saveLayout(varmeter.layout.to, file; fid = "varmeter/layout/to")
    end
end

######### Save PMU ##########
function savePmu(pmu::PMU, file)
    if pmu.number != 0
        saveLabel(pmu, file; fid = "pmu")
        saveMeter(pmu, pmu.magnitude, file; name = "pmu/magnitude", si = "volt (V) or ampere (A)")
        saveMeter(pmu, pmu.angle, file; name = "pmu/angle", pu = "radian (rad)")
        saveLayout(pmu.layout.index, file; fid = "pmu/layout/index")
        saveLayout(pmu.layout.bus, file; fid = "pmu/layout/bus")
        saveLayout(pmu.layout.from, file; fid = "pmu/layout/from")
        saveLayout(pmu.layout.to, file; fid = "pmu/layout/to")
        saveLayout(pmu.layout.correlated, file; fid = "pmu/layout/correlated")
        saveLayout(pmu.layout.polar, file; fid = "pmu/layout/polar")
    end
end

######### Save Label ##########
function saveLabel(device, file; fid = "")
    label = Array{String, 1}(undef, device.number)
    @inbounds for (key, value) in device.label
        label[value] = key
    end

    fidLabel = string(fid, "/label")
    write(file, fidLabel, label)
    attrs(file[fidLabel])["unit"] = "dimensionless"
    attrs(file[fidLabel])["format"] = "expand"

    fid = string(fid, "/layout/label")
    write(file, fid, device.layout.label)
end

######### Save Layout ##########
function saveLayout(layout, file; fid = "")
    write(file, fid, layout)
    attrs(file[fid])["unit"] = "dimensionless"
    attrs(file[fid])["format"] = "expand"
end

######### Save Mean, Variance, and Status ##########
function saveMeter(device, meter, file; name = "", si = "", pu = "per-unit (pu)")
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
    attrs(file[fid])["unit"] = "dimensionless"
    attrs(file[fid])["format"] = format
end