@testset "Load and Save Measurements with String Labels" begin
    ########## Build Measurement Data ##########
    system, monitoring = ems(path * "case14test.m")

    @voltmeter(label = "Voltmeter ?")
    addVoltmeter!(monitoring; bus = 1, magnitude = 1.1, noise = true, status = 0)
    addVoltmeter!(monitoring; bus = 14, magnitude = 1.0, variance = 1e-4)

    addAmmeter!(monitoring; from = 10, magnitude = 0.2, variance = 1e-5)
    addAmmeter!(monitoring; to = 10, magnitude = 0.1, status = 0, noise = true)
    addAmmeter!(monitoring; to = 12, magnitude = 0.1, status = 0, square = true)

    @wattmeter(label = "Wattmeter ?: !", statusBus = 0, varianceFrom = 1e-5, noise = true)
    addWattmeter!(monitoring; bus = 3, active = 1.1, status = 1)
    addWattmeter!(monitoring; from = 14, active = 1.0, variance = 1e-4, noise = true)
    addWattmeter!(monitoring; to = 2, active = 0.8, status = 0, noise = true)

    @varmeter(statusFrom = 0, varianceBus = 1e-5)
    addVarmeter!(monitoring; bus = 4, reactive = 0.6,status = 1)
    addVarmeter!(monitoring; from = 14, reactive = 1.2, variance = 1e-4, noise = true)
    addVarmeter!(monitoring; to = 2, reactive = 0.1, status = 0, noise = true)

    @pmu(label = "!", statusTo = 0, varianceMagnitudeTo = 1e-3)
    addPmu!(monitoring; bus = 9, magnitude = 1.6, angle = -0.1, status = 1, polar = true)
    addPmu!(monitoring; from = 14, magnitude = 1.2, angle = -0.2, polar = false, noise = true)
    addPmu!(monitoring; to = 19, magnitude = 0.3, angle = 0.1, correlated = true, polar = true)
    addPmu!(monitoring; to = 5, magnitude = 0.2, angle = 0.2, square = true, polar = true)

    ########## Save Measurement Data ##########
    saveMeasurement(monitoring; path = path * "measurement14.h5")

    ########## Load Measurement Data ##########
    hdf5 = measurement(system, path * "measurement14.h5")

    @testset "Measurement Data" begin
        teststruct(monitoring.voltmeter, hdf5.voltmeter)
        teststruct(monitoring.ammeter, hdf5.ammeter)
        teststruct(monitoring.wattmeter, hdf5.wattmeter)
        teststruct(monitoring.varmeter, hdf5.varmeter)
        teststruct(monitoring.pmu, hdf5.pmu)
    end
end

@testset "Load and Save Measurements with Integer Labels" begin
    @config(label = Integer)

    ########## Build Measurement Data ##########
    system, monitoring = ems(path * "case14test.m")

    addVoltmeter!(monitoring; bus = 1, magnitude = 1.1, noise = true, status = 0)
    addVoltmeter!(monitoring; bus = 14, magnitude = 1.0, variance = 1e-4)

    addAmmeter!(monitoring; from = 10, magnitude = 0.2, variance = 1e-5)
    addAmmeter!(monitoring; to = 10, magnitude = 0.1, status = 0, noise = true)
    addAmmeter!(monitoring; to = 12, magnitude = 0.1, status = 0, square = true)

    @wattmeter(statusBus = 0, varianceFrom = 1e-5, noise = true)
    addWattmeter!(monitoring; bus = 3, active = 1.1, status = 1)
    addWattmeter!(monitoring; from = 14, active = 1.0, variance = 1e-4, noise = true)
    addWattmeter!(monitoring; to = 2, active = 0.8, status = 0, noise = true)

    @varmeter(statusFrom = 0, varianceBus = 1e-5)
    addVarmeter!(monitoring; bus = 4, reactive = 0.6,status = 1)
    addVarmeter!(monitoring; from = 14, reactive = 1.2, variance = 1e-4, noise = true)
    addVarmeter!(monitoring; to = 2, reactive = 0.1, status = 0, noise = true)

    @pmu(statusTo = 0, varianceMagnitudeTo = 1e-3)
    addPmu!(monitoring; bus = 9, magnitude = 1.6, angle = -0.1, status = 1, polar = true)
    addPmu!(monitoring; from = 14, magnitude = 1.2, angle = -0.2, polar = false)
    addPmu!(monitoring; to = 19, magnitude = 0.3, angle = 0.1, status = 0, noise = true)
    addPmu!(monitoring; to = 5, magnitude = 0.2, angle = 0.2, square = true, polar = true)

    ########## Save Measurement Data ##########
    saveMeasurement(monitoring; path = path * "measurement14Int.h5")

    ########## Load Measurement Data ##########
    hdf5 = measurement(system, path * "measurement14Int.h5")

    @testset "Measurement Data" begin
        teststruct(monitoring.voltmeter, hdf5.voltmeter)
        teststruct(monitoring.ammeter, hdf5.ammeter)
        teststruct(monitoring.wattmeter, hdf5.wattmeter)
        teststruct(monitoring.varmeter, hdf5.varmeter)
        teststruct(monitoring.pmu, hdf5.pmu)
    end
end