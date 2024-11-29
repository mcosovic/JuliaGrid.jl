@testset "Load and Save Measurements with String Labels" begin
    ########## Build Measurement Data ##########
    system = powerSystem(path * "case14test.m")
    device = measurement()

    @voltmeter(label = "Voltmeter ?")
    addVoltmeter!(system, device; bus = 1, magnitude = 1.1, noise = true, status = 0)
    addVoltmeter!(system, device; bus = 14, magnitude = 1.0, variance = 1e-4)

    addAmmeter!(system, device; from = 10, magnitude = 0.2, variance = 1e-5)
    addAmmeter!(system, device; to = 10, magnitude = 0.1, status = 0, noise = true)

    @wattmeter(label = "Wattmeter ?: !", statusBus = 0, varianceFrom = 1e-5, noise = true)
    addWattmeter!(system, device; bus = 3, active = 1.1, status = 1)
    addWattmeter!(system, device; from = 14, active = 1.0, variance = 1e-4, noise = true)
    addWattmeter!(system, device; to = 2, active = 0.8, status = 0, noise = true)

    @varmeter(statusFrom = 0, varianceBus = 1e-5)
    addVarmeter!(system, device; bus = 4, reactive = 0.6,status = 1)
    addVarmeter!(system, device; from = 14, reactive = 1.2, variance = 1e-4, noise = true)
    addVarmeter!(system, device; to = 2, reactive = 0.1, status = 0, noise = true)

    @pmu(label = "!", statusAngleTo = 0, varianceMagnitudeTo = 1e-3)
    addPmu!(
        system, device;
        bus = 9, magnitude = 1.6, angle = -0.1, statusAngle = 1, polar = true
    )
    addPmu!(
        system, device; from = 14, magnitude = 1.2, angle = -0.2,
        varianceMagnitude = 1e-4, polar = false, noise = true
    )
    addPmu!(
        system, device; to = 19, magnitude = 0.3, angle = 0.1, statusMagnitude = 0,
        correlated = true, noise = true, polar = true
    )

    ########## Save Measurement Data ##########
    saveMeasurement(device; path = path * "measurement14.h5")

    ########## Load Measurement Data ##########
    hdf5 = measurement(path * "measurement14.h5")

    ##### Test Measurement Data #####
    compstruct(device.voltmeter, hdf5.voltmeter)
    compstruct(device.ammeter, hdf5.ammeter)
    compstruct(device.wattmeter, hdf5.wattmeter)
    compstruct(device.varmeter, hdf5.varmeter)
    compstruct(device.pmu, hdf5.pmu)
end

@testset "Load and Save Measurements with Integer Labels" begin
    @labels(Integer)

    ########## Build Measurement Data ##########
    system = powerSystem(path * "case14test.m")
    device = measurement()

    addVoltmeter!(system, device; bus = 1, magnitude = 1.1, noise = true, status = 0)
    addVoltmeter!(system, device; bus = 14, magnitude = 1.0, variance = 1e-4)

    addAmmeter!(system, device; from = 10, magnitude = 0.2, variance = 1e-5)
    addAmmeter!(system, device; to = 10, magnitude = 0.1, status = 0, noise = true)

    @wattmeter(statusBus = 0, varianceFrom = 1e-5, noise = true)
    addWattmeter!(system, device; bus = 3, active = 1.1, status = 1)
    addWattmeter!(system, device; from = 14, active = 1.0, variance = 1e-4, noise = true)
    addWattmeter!(system, device; to = 2, active = 0.8, status = 0, noise = true)

    @varmeter(statusFrom = 0, varianceBus = 1e-5)
    addVarmeter!(system, device; bus = 4, reactive = 0.6,status = 1)
    addVarmeter!(system, device; from = 14, reactive = 1.2, variance = 1e-4, noise = true)
    addVarmeter!(system, device; to = 2, reactive = 0.1, status = 0, noise = true)

    @pmu(statusAngleTo = 0, varianceMagnitudeTo = 1e-3)
    addPmu!(
        system, device;
        bus = 9, magnitude = 1.6, angle = -0.1, statusAngle = 1, polar = true
    )
    addPmu!(
        system, device; from = 14, magnitude = 1.2, angle = -0.2,
        varianceMagnitude = 1e-4, polar = false, noise = true
    )
    addPmu!(
        system, device; to = 19, magnitude = 0.3, angle = 0.1, statusMagnitude = 0,
        correlated = true, noise = true, polar = true
    )

    ########## Save Measurement Data ##########
    saveMeasurement(device; path = path * "measurement14Int.h5")

    ########## Load Measurement Data ##########
    hdf5 = measurement(path * "measurement14Int.h5")

    ##### Test Measurement Data #####
    compstruct(device.voltmeter, hdf5.voltmeter)
    compstruct(device.ammeter, hdf5.ammeter)
    compstruct(device.wattmeter, hdf5.wattmeter)
    compstruct(device.varmeter, hdf5.varmeter)
    compstruct(device.pmu, hdf5.pmu)
end